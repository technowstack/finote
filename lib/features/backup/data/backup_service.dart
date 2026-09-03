import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/app_database.dart';
import '../domain/backup_manifest.dart';
import '../domain/restore_error.dart';
import '../domain/restore_preview.dart';

class BackupService {
  BackupService(this._database, {this.databasePath});

  final AppDatabase _database;
  final String? databasePath;

  static const _maximumArchiveBytes = 100 * 1024 * 1024;

  // ---------------------------------------------------------------------------
  // BACKUP
  // ---------------------------------------------------------------------------

  Future<bool> createAndSave() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final backup = await buildBackup(appVersion: packageInfo.version);
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Simpan backup',
      fileName: backup.fileName,
      bytes: backup.bytes,
      mimeType: 'application/zip',
    );
    return uri != null;
  }

  Future<BackupArchive> buildBackup({
    required String appVersion,
    DateTime? createdAt,
    Directory? temporaryDirectory,
  }) async {
    final timestamp = createdAt ?? DateTime.now();
    final tempRoot = temporaryDirectory ?? await getTemporaryDirectory();
    final workingDirectory = await tempRoot.createTemp('finote_backup_');

    try {
      final databaseFile = File(
        '${workingDirectory.path}${Platform.pathSeparator}database.sqlite',
      );
      await _database.customStatement('VACUUM INTO ?', [databaseFile.path]);
      await _validateSnapshot(databaseFile);

      final manifest = BackupManifest.create(
        databaseVersion: _database.schemaVersion,
        createdAt: timestamp,
        appVersion: appVersion,
      );
      final databaseBytes = await databaseFile.readAsBytes();
      final archive = Archive()
        ..addFile(
          ArchiveFile('database.sqlite', databaseBytes.length, databaseBytes),
        )
        ..addFile(
          ArchiveFile.string(
            'manifest.json',
            const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
          ),
        );

      return BackupArchive(
        fileName:
            'finance_backup_${DateFormat('yyyy-MM-dd_HH-mm-ss-SSS').format(timestamp.toLocal())}.zip',
        bytes: Uint8List.fromList(ZipEncoder().encode(archive)!),
        manifest: manifest,
      );
    } finally {
      if (await workingDirectory.exists()) {
        await workingDirectory.delete(recursive: true);
      }
    }
  }

  Future<void> _validateSnapshot(File file) async {
    await _checkRestoredSnapshot(file);
  }

  // ---------------------------------------------------------------------------
  // RESTORE — STEP 1: parse & validate
  // ---------------------------------------------------------------------------

  /// Membuka dan memvalidasi byte-byte dari file backup ZIP yang dipilih.
  ///
  /// Validasi yang dilakukan (berurutan):
  /// 1. Memastikan [zipBytes] dapat di-decode sebagai ZIP → [RestoreError.invalidZip]
  /// 2. Memastikan `manifest.json` dan `database.sqlite` ada serta valid
  /// 3. Memastikan `backupVersion` yang didukung → [RestoreError.unsupportedVersion]
  /// 4. Memastikan `databaseVersion` cocok dengan versi live → [RestoreError.databaseMismatch]
  ///
  /// Jika semua validasi lolos, mengembalikan [RestorePreview] berisi manifest
  /// dan byte arsip yang siap dipulihkan.
  Future<RestorePreview> parseRestoreFile(
    Uint8List zipBytes, {
    Directory? temporaryDirectory,
  }) async {
    final bytes = zipBytes;
    if (bytes.isEmpty || bytes.length > _maximumArchiveBytes) {
      throw const RestoreError.invalidZip();
    }

    // 1. Decode ZIP
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const RestoreError.invalidZip();
    }

    // 2. Temukan manifest.json
    final manifest = _parseManifest(archive);
    final dbEntry = archive.findFile('database.sqlite');
    _checkManifestDatabaseVersion(manifest);

    if (dbEntry == null ||
        dbEntry.size == 0 ||
        dbEntry.size > _maximumArchiveBytes) {
      throw const RestoreError.invalidZip();
    }

    final tempRoot = temporaryDirectory ?? await getTemporaryDirectory();
    final workingDirectory = await tempRoot.createTemp('finote_validate_');
    final snapshot = File(p.join(workingDirectory.path, 'database.sqlite'));
    try {
      await snapshot.writeAsBytes(dbEntry.content as List<int>, flush: true);
      await _migrateSnapshot(
        snapshot,
        expectedVersion: manifest.databaseVersion,
      );
      await _checkRestoredSnapshot(snapshot);
      final stats = _readSnapshotStats(snapshot);
      return RestorePreview(
        manifest: manifest,
        archiveBytes: bytes,
        transactionCount: stats.transactionCount,
        categoryCount: stats.categoryCount,
        accountCount: stats.accountCount,
        transferCount: stats.transferCount,
        transferVolume: stats.transferVolume,
        totalIncome: stats.totalIncome,
        totalExpense: stats.totalExpense,
        oldestTransactionAt: stats.oldestTransactionAt,
        newestTransactionAt: stats.newestTransactionAt,
      );
    } on RestoreError {
      rethrow;
    } catch (_) {
      throw const RestoreError.integrityCheckFailed();
    } finally {
      if (await workingDirectory.exists()) {
        await workingDirectory.delete(recursive: true);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // RESTORE — STEP 2: buat safety backup sebelum overwrite
  // ---------------------------------------------------------------------------

  /// Membuat safety backup dari data live ke direktori dokumen aplikasi.
  ///
  /// Safety backup **tidak** dihapus secara otomatis — bahkan jika restore
  /// gagal — sehingga pengguna selalu bisa memulihkan data sebelumnya.
  Future<BackupArchive> createSafetyBackup() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final backup = await buildBackup(appVersion: packageInfo.version);

    final docsDir = await getApplicationDocumentsDirectory();
    final safetyDir = Directory(p.join(docsDir.path, 'safety_backups'));
    if (!await safetyDir.exists()) {
      await safetyDir.create(recursive: true);
    }

    final safetyName = backup.fileName.replaceFirst(
      'finance_backup_',
      'pre_restore_backup_',
    );
    final safetyFile = await _uniqueFile(safetyDir, safetyName);
    await safetyFile.writeAsBytes(backup.bytes, flush: true);

    return BackupArchive(
      fileName: safetyFile.path,
      bytes: backup.bytes,
      manifest: backup.manifest,
    );
  }

  Future<File> _uniqueFile(Directory directory, String fileName) async {
    final extension = p.extension(fileName);
    final stem = p.basenameWithoutExtension(fileName);
    var candidate = File(p.join(directory.path, fileName));
    var suffix = 2;
    while (await candidate.exists()) {
      candidate = File(p.join(directory.path, '$stem-$suffix$extension'));
      suffix++;
    }
    return candidate;
  }

  // ---------------------------------------------------------------------------
  // RESTORE — STEP 3: eksekusi restore
  // ---------------------------------------------------------------------------

  /// Memulihkan database dari [archiveBytes] milik [RestorePreview].
  ///
  /// Proses:
  /// 1. Extract `database.sqlite` dari ZIP ke direktori temp.
  /// 2. Jalankan `PRAGMA integrity_check` → [RestoreError.integrityCheckFailed]
  /// 3. Tutup koneksi database live.
  /// 4. Salin (atomic rename) file temp ke path database live.
  ///
  /// Jika langkah 4 gagal, file temp masih ada dan koneksi database
  /// belum ditutup, sehingga data sebelumnya aman.
  Future<void> restoreFromArchive(
    Uint8List archiveBytes, {
    Directory? temporaryDirectory,
  }) async {
    // Extract file SQLite ke temp
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(archiveBytes);
    } catch (_) {
      throw const RestoreError.invalidZip();
    }
    final dbEntry = archive.findFile('database.sqlite');
    final manifest = _parseManifest(archive);
    _checkManifestDatabaseVersion(manifest);
    if (dbEntry == null ||
        dbEntry.size == 0 ||
        dbEntry.size > _maximumArchiveBytes) {
      throw const RestoreError.invalidZip();
    }

    final tempRoot = temporaryDirectory ?? await getTemporaryDirectory();
    final workingDir = await tempRoot.createTemp('finote_restore_');
    final tempDbFile = File(p.join(workingDir.path, 'database.sqlite'));

    try {
      await tempDbFile.writeAsBytes(dbEntry.content as List<int>, flush: true);

      // Integrity check pada file yang akan di-restore
      await _migrateSnapshot(
        tempDbFile,
        expectedVersion: manifest.databaseVersion,
      );
      await _checkRestoredSnapshot(tempDbFile);

      final targetPath =
          databasePath ?? await AppDatabase.resolveDatabasePath();
      final targetFile = File(targetPath);
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final stagedFile = File('$targetPath.restore-$stamp');
      final rollbackFile = File('$targetPath.rollback-$stamp');
      await tempDbFile.copy(stagedFile.path);

      await _database.close();
      var copiedOriginal = false;
      try {
        if (await targetFile.exists()) {
          await targetFile.copy(rollbackFile.path);
          copiedOriginal = true;
        }
        await _deleteSqliteSidecars(targetPath);
        await stagedFile.rename(targetPath);
        await _checkRestoredSnapshot(targetFile);
      } catch (_) {
        if (await stagedFile.exists()) await stagedFile.delete();
        if (copiedOriginal && await rollbackFile.exists()) {
          if (await targetFile.exists()) await targetFile.delete();
          await rollbackFile.rename(targetPath);
        }
        rethrow;
      }
      if (await rollbackFile.exists()) {
        try {
          await rollbackFile.delete();
        } catch (_) {
          // A leftover rollback file is safer than failing a verified restore.
        }
      }
    } finally {
      if (await workingDir.exists()) {
        await workingDir.delete(recursive: true);
      }
    }
  }

  Future<void> _checkRestoredSnapshot(File file) async {
    Database? db;
    try {
      db = sqlite3.open(file.path, mode: OpenMode.readOnly);
      final result = db.select('PRAGMA integrity_check').single;
      final tables = db
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'])
          .toSet();
      final foreignKeyErrors = db.select('PRAGMA foreign_key_check');
      final indexes = db
          .select("SELECT name FROM sqlite_master WHERE type = 'index'")
          .map((row) => row['name'])
          .toSet();
      if (result['integrity_check'] != 'ok' ||
          db.userVersion != _database.schemaVersion ||
          !tables.containsAll({
            'accounts',
            'categories',
            'transactions',
            'transfers',
            'settings',
            'assets',
            'asset_transactions',
          }) ||
          !_hasColumns(db, 'categories', {
            'id',
            'uuid',
            'name',
            'type',
            'icon',
            'created_at',
            'updated_at',
            'deleted_at',
          }) ||
          !_hasColumns(db, 'transactions', {
            'id',
            'uuid',
            'type',
            'account_id',
            'category_id',
            'amount',
            'title',
            'note',
            'transaction_date',
            'source',
            'receipt_fingerprint',
            'legacy_source',
            'legacy_id',
            'created_at',
            'updated_at',
            'deleted_at',
          }) ||
          !_hasColumns(db, 'settings', {'key', 'value', 'updated_at'}) ||
          !_hasColumns(db, 'transfers', {
            'id',
            'uuid',
            'from_account_id',
            'to_account_id',
            'amount',
            'transfer_date',
            'note',
            'created_at',
            'updated_at',
            'deleted_at',
          }) ||
          !_hasColumns(db, 'accounts', {
            'id',
            'uuid',
            'name',
            'type',
            'initial_balance',
            'is_active',
            'is_default',
            'created_at',
            'updated_at',
          }) ||
          !_hasColumns(db, 'assets', {
            'id',
            'uuid',
            'symbol',
            'normalized_symbol',
            'name',
            'asset_type',
            'pricing_mode',
            'currency',
            'unit_label',
            'is_active',
            'created_at',
            'updated_at',
          }) ||
          !_hasColumns(db, 'asset_transactions', {
            'id',
            'uuid',
            'asset_id',
            'action',
            'quantity_scaled',
            'price_amount',
            'total_amount',
            'transaction_date',
            'note',
            'source_transaction_id',
            'created_at',
            'updated_at',
            'deleted_at',
          }) ||
          !indexes.containsAll({
            'accounts_active',
            'transactions_account_id',
            'assets_active',
            'assets_type_normalized_symbol',
            'asset_transactions_asset_id',
            'asset_transactions_date',
            'asset_transactions_deleted_at',
            'asset_transactions_source_transaction_id',
            'transfers_from_account_id',
            'transfers_to_account_id',
            'transfers_date',
            'transfers_deleted_at',
          }) ||
          foreignKeyErrors.isNotEmpty ||
          _count(db, 'transactions WHERE account_id IS NULL') != 0 ||
          _count(db, 'accounts WHERE is_default = 1') != 1 ||
          _count(db, 'transfers WHERE from_account_id = to_account_id') != 0) {
        throw const RestoreError.integrityCheckFailed();
      }
    } on RestoreError {
      rethrow;
    } catch (_) {
      // SqliteException (e.g. "file is not a database") atau error lain
      // saat membuka atau menjalankan integrity_check → database korup.
      throw const RestoreError.integrityCheckFailed();
    } finally {
      db?.close();
    }
  }

  Future<void> _migrateSnapshot(
    File file, {
    required int expectedVersion,
  }) async {
    AppDatabase? database;
    try {
      final raw = sqlite3.open(file.path, mode: OpenMode.readOnly);
      final version = raw.userVersion;
      raw.close();
      if (version < 1 || version != expectedVersion) {
        throw const RestoreError.integrityCheckFailed();
      }
      if (version >= _database.schemaVersion) return;

      database = AppDatabase(NativeDatabase(file));
      await database.customSelect('PRAGMA user_version').getSingle();
      await database.close();
      database = null;

      final migrated = sqlite3.open(file.path, mode: OpenMode.readOnly);
      final migratedVersion = migrated.userVersion;
      migrated.close();
      if (migratedVersion != _database.schemaVersion) {
        throw const RestoreError.integrityCheckFailed();
      }
    } on RestoreError {
      rethrow;
    } catch (_) {
      throw const RestoreError.integrityCheckFailed();
    } finally {
      await database?.close();
    }
  }

  _RestoreStats _readSnapshotStats(File file) {
    final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      final row = db.select('''
        SELECT
          COUNT(*) AS transaction_count,
          COUNT(DISTINCT category_id) AS category_count,
          COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS total_income,
          COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS total_expense,
          MIN(transaction_date) AS oldest,
          MAX(transaction_date) AS newest
        FROM transactions
        WHERE deleted_at IS NULL
      ''').single;
      final accountCount = _count(db, 'accounts');
      final transferRow = db.select('''
        SELECT COUNT(*) AS transfer_count,
               COALESCE(SUM(amount), 0) AS transfer_volume
        FROM transfers
        WHERE deleted_at IS NULL
      ''').single;
      return _RestoreStats(
        transactionCount: row['transaction_count'] as int,
        categoryCount: row['category_count'] as int,
        accountCount: accountCount,
        transferCount: transferRow['transfer_count'] as int,
        transferVolume: transferRow['transfer_volume'] as int,
        totalIncome: row['total_income'] as int,
        totalExpense: row['total_expense'] as int,
        oldestTransactionAt: _readDate(row['oldest']),
        newestTransactionAt: _readDate(row['newest']),
      );
    } finally {
      db.close();
    }
  }

  DateTime? _readDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  bool _hasColumns(Database db, String table, Set<String> required) {
    final columns = db
        .select('PRAGMA table_info("$table")')
        .map((row) => row['name'])
        .toSet();
    return columns.containsAll(required);
  }

  int _count(Database db, String from) =>
      db.select('SELECT COUNT(*) AS count FROM $from').single['count'] as int;

  BackupManifest _parseManifest(Archive archive) {
    final file = archive.findFile('manifest.json');
    if (file == null) throw const RestoreError.invalidManifest();
    try {
      final json = jsonDecode(
        utf8.decode(file.content as List<int>),
      ) as Map<String, dynamic>;
      final version = json['backupVersion'];
      if (version is int && version != BackupManifest.currentBackupVersion) {
        throw RestoreError.unsupportedVersion(
          found: version,
          required: BackupManifest.currentBackupVersion,
        );
      }
      return BackupManifest.fromJson(json);
    } on RestoreError {
      rethrow;
    } catch (_) {
      throw const RestoreError.invalidManifest();
    }
  }

  void _checkManifestDatabaseVersion(BackupManifest manifest) {
    if (manifest.databaseVersion > _database.schemaVersion) {
      throw RestoreError.databaseMismatch(
        backupVersion: manifest.databaseVersion,
        currentVersion: _database.schemaVersion,
      );
    }
  }

  Future<void> _deleteSqliteSidecars(String databasePath) async {
    for (final suffix in ['-wal', '-shm']) {
      final file = File('$databasePath$suffix');
      if (await file.exists()) await file.delete();
    }
  }
}

class _RestoreStats {
  const _RestoreStats({
    required this.transactionCount,
    required this.categoryCount,
    required this.accountCount,
    required this.transferCount,
    required this.transferVolume,
    required this.totalIncome,
    required this.totalExpense,
    required this.oldestTransactionAt,
    required this.newestTransactionAt,
  });

  final int transactionCount;
  final int categoryCount;
  final int accountCount;
  final int transferCount;
  final int transferVolume;
  final int totalIncome;
  final int totalExpense;
  final DateTime? oldestTransactionAt;
  final DateTime? newestTransactionAt;
}

class BackupArchive {
  const BackupArchive({
    required this.fileName,
    required this.bytes,
    required this.manifest,
  });

  final String fileName;
  final Uint8List bytes;
  final BackupManifest manifest;
}

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider)),
);
