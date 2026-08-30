import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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
    final snapshot = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      final integrity = snapshot.select('PRAGMA integrity_check').single;
      if (integrity['integrity_check'] != 'ok' ||
          snapshot.userVersion != _database.schemaVersion) {
        throw StateError('Database snapshot validation failed');
      }
    } finally {
      snapshot.close();
    }
  }

  // ---------------------------------------------------------------------------
  // RESTORE — STEP 1: parse & validate
  // ---------------------------------------------------------------------------

  /// Membuka dan memvalidasi byte-byte dari file backup ZIP yang dipilih.
  ///
  /// Validasi yang dilakukan (berurutan):
  /// 1. Memastikan [zipBytes] dapat di-decode sebagai ZIP → [RestoreError.invalidZip]
  /// 2. Memastikan `manifest.json` ada dan valid → [RestoreError.invalidManifest]
  /// 3. Memastikan `backupVersion` yang didukung → [RestoreError.unsupportedVersion]
  /// 4. Memastikan `databaseVersion` cocok dengan versi live → [RestoreError.databaseMismatch]
  ///
  /// Jika semua validasi lolos, mengembalikan [RestorePreview] berisi manifest
  /// dan byte arsip yang siap dipulihkan.
  Future<RestorePreview> parseRestoreFile(Uint8List zipBytes) async {
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
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw const RestoreError.invalidManifest();
    }

    // 3. Decode JSON mentah
    Map<String, dynamic> rawJson;
    try {
      rawJson = jsonDecode(
        utf8.decode(manifestFile.content as List<int>),
      ) as Map<String, dynamic>;
    } catch (_) {
      throw const RestoreError.invalidManifest();
    }

    // 4. Periksa backupVersion SEBELUM memanggil BackupManifest.fromJson
    //    agar dapat memberikan error yang spesifik.
    final rawBackupVersion = rawJson['backupVersion'];
    if (rawBackupVersion is int &&
        rawBackupVersion != BackupManifest.currentBackupVersion) {
      throw RestoreError.unsupportedVersion(
        found: rawBackupVersion,
        required: BackupManifest.currentBackupVersion,
      );
    }

    // 5. Validasi penuh manifest
    BackupManifest manifest;
    try {
      manifest = BackupManifest.fromJson(rawJson);
    } on FormatException {
      throw const RestoreError.invalidManifest();
    } catch (_) {
      throw const RestoreError.invalidManifest();
    }

    // 6. Periksa databaseVersion
    if (manifest.databaseVersion != _database.schemaVersion) {
      throw RestoreError.databaseMismatch(
        backupVersion: manifest.databaseVersion,
        currentVersion: _database.schemaVersion,
      );
    }

    return RestorePreview(manifest: manifest, archiveBytes: bytes);
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

    final safetyFile = File(p.join(safetyDir.path, backup.fileName));
    await safetyFile.writeAsBytes(backup.bytes, flush: true);

    return BackupArchive(
      fileName: safetyFile.path,
      bytes: backup.bytes,
      manifest: backup.manifest,
    );
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
    final archive = ZipDecoder().decodeBytes(archiveBytes);
    final dbEntry = archive.findFile('database.sqlite');
    if (dbEntry == null || dbEntry.size > _maximumArchiveBytes) {
      throw const RestoreError.invalidZip();
    }

    final tempRoot = temporaryDirectory ?? await getTemporaryDirectory();
    final workingDir = await tempRoot.createTemp('finote_restore_');
    final tempDbFile = File(p.join(workingDir.path, 'database.sqlite'));

    try {
      await tempDbFile.writeAsBytes(dbEntry.content as List<int>, flush: true);

      // Integrity check pada file yang akan di-restore
      await _checkRestoredSnapshot(tempDbFile);

      final targetPath =
          databasePath ?? await AppDatabase.resolveDatabasePath();
      final targetFile = File(targetPath);
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final stagedFile = File('$targetPath.restore-$stamp');
      final rollbackFile = File('$targetPath.rollback-$stamp');
      await tempDbFile.copy(stagedFile.path);

      await _database.close();
      var movedOriginal = false;
      try {
        if (await targetFile.exists()) {
          await targetFile.rename(rollbackFile.path);
          movedOriginal = true;
        }
        await stagedFile.rename(targetPath);
        if (await rollbackFile.exists()) {
          try {
            await rollbackFile.delete();
          } catch (_) {
            // A leftover rollback file is safer than failing a completed restore.
          }
        }
      } catch (_) {
        if (await stagedFile.exists()) await stagedFile.delete();
        if (movedOriginal && await rollbackFile.exists()) {
          if (await targetFile.exists()) await targetFile.delete();
          await rollbackFile.rename(targetPath);
        }
        rethrow;
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
      if (result['integrity_check'] != 'ok' ||
          db.userVersion != _database.schemaVersion ||
          !tables.containsAll({'categories', 'transactions', 'settings'}) ||
          !_hasColumns(db, 'categories', {'id', 'name', 'type'}) ||
          !_hasColumns(db, 'transactions', {
            'id',
            'uuid',
            'type',
            'category_id',
            'amount',
            'transaction_date',
            'source',
          }) ||
          !_hasColumns(db, 'settings', {'key', 'value'}) ||
          foreignKeyErrors.isNotEmpty) {
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

  bool _hasColumns(Database db, String table, Set<String> required) {
    final columns = db
        .select('PRAGMA table_info("$table")')
        .map((row) => row['name'])
        .toSet();
    return columns.containsAll(required);
  }
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
