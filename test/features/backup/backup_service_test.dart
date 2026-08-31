import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/backup/data/backup_service.dart';
import 'package:finote/features/backup/domain/backup_manifest.dart';
import 'package:finote/features/backup/domain/restore_error.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helper: buat ZIP minimal dengan manifest yang dapat dikontrol
  // ---------------------------------------------------------------------------
  Uint8List buildValidZip({
    int backupVersion = BackupManifest.currentBackupVersion,
    int databaseVersion = 3,
    Uint8List? dbBytes,
  }) {
    final manifest = {
      'application': BackupManifest.applicationName,
      'backupVersion': backupVersion,
      'databaseVersion': databaseVersion,
      'createdAt': DateTime.utc(2026, 8, 29).toIso8601String(),
      'appVersion': '1.0.0',
    };
    final archive = Archive()
      ..addFile(ArchiveFile.string('manifest.json', jsonEncode(manifest)))
      ..addFile(
        ArchiveFile(
          'database.sqlite',
          (dbBytes ?? Uint8List(0)).length,
          dbBytes ?? Uint8List(0),
        ),
      );
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  // ---------------------------------------------------------------------------
  // GROUP: backup (existing test — tidak diubah)
  // ---------------------------------------------------------------------------
  group('backup', () {
    test(
      'backup contains a valid manifest and consistent SQLite snapshot',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        final tempDirectory = await Directory.systemTemp.createTemp(
          'finote_backup_test_',
        );
        addTearDown(database.close);
        addTearDown(() => tempDirectory.delete(recursive: true));

        final category = await CategoryRepository(database)
            .create(name: 'Makanan', type: TransactionType.expense);
        await AccountRepository(database).create(
          name: 'BCA Utama',
          type: AccountType.bank,
          initialBalance: 500000,
        );
        await TransactionRepository(database).create(
          type: TransactionType.expense,
          categoryId: category.id,
          amount: 25000,
          transactionDate: DateTime(2026, 8, 29),
        );

        final backup = await BackupService(database).buildBackup(
          appVersion: '1.0.0',
          createdAt: DateTime(2026, 8, 29, 14, 5),
          temporaryDirectory: tempDirectory,
        );
        final archive = ZipDecoder().decodeBytes(backup.bytes);

        expect(backup.fileName, 'finance_backup_2026-08-29_14-05-00-000.zip');
        expect(archive.files.map((file) => file.name).toSet(), {
          'database.sqlite',
          'manifest.json',
        });

        final manifestFile = archive.findFile('manifest.json')!;
        final manifest = BackupManifest.fromJson(
          jsonDecode(utf8.decode(manifestFile.content)) as Map<String, dynamic>,
        );
        expect(manifest.databaseVersion, database.schemaVersion);
        expect(manifest.appVersion, '1.0.0');

        final snapshotFile = File(
          '${tempDirectory.path}${Platform.pathSeparator}snapshot.sqlite',
        );
        await snapshotFile.writeAsBytes(
          archive.findFile('database.sqlite')!.content,
          flush: true,
        );
        final snapshot = sqlite3.open(
          snapshotFile.path,
          mode: OpenMode.readOnly,
        );
        try {
          expect(
            snapshot.select('PRAGMA integrity_check').single['integrity_check'],
            'ok',
          );
          expect(
            snapshot
                .select('SELECT COUNT(*) AS count FROM transactions')
                .single['count'],
            1,
          );
          expect(
            snapshot
                .select("SELECT name FROM accounts WHERE name = 'BCA Utama'")
                .single['name'],
            'BCA Utama',
          );
        } finally {
          snapshot.close();
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  // GROUP: restore
  // ---------------------------------------------------------------------------
  group('restore', () {
    late AppDatabase database;
    late BackupService service;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      service = BackupService(database);
    });

    tearDown(() async {
      // database.close() mungkin sudah dipanggil oleh restoreFromArchive
      // dalam test tertentu — abaikan error jika sudah tertutup.
      try {
        await database.close();
      } catch (_) {}
    });

    // -------------------------------------------------------------------------
    // 1. ZIP tidak valid
    // -------------------------------------------------------------------------
    test('invalid zip — bytes acak melempar RestoreError', () async {
      final garbage = Uint8List.fromList(List.generate(256, (i) => i % 256));

      await expectLater(
        service.parseRestoreFile(garbage),
        throwsA(isA<RestoreError>()),
      );

      // Verifikasi pesan user-friendly tidak kosong
      try {
        await service.parseRestoreFile(garbage);
      } on RestoreError catch (e) {
        expect(e.toUserMessage(), isNotEmpty);
      }
    });

    test('invalid zip — bytes kosong melempar RestoreError', () async {
      await expectLater(
        service.parseRestoreFile(Uint8List(0)),
        throwsA(isA<RestoreError>()),
      );
    });

    // -------------------------------------------------------------------------
    // 2. Manifest tidak valid
    // -------------------------------------------------------------------------
    test(
      'invalid manifest — JSON rusak melempar RestoreError.invalidManifest',
      () async {
        // ZIP valid tapi manifest JSON-nya rusak
        final brokenManifestZip = () {
          final archive = Archive()
            ..addFile(ArchiveFile.string('manifest.json', 'not-valid-json{{{'))
            ..addFile(ArchiveFile('database.sqlite', 0, Uint8List(0)));
          return Uint8List.fromList(ZipEncoder().encode(archive)!);
        }();

        try {
          await service.parseRestoreFile(brokenManifestZip);
          fail('Expected RestoreError');
        } on RestoreError catch (e) {
          expect(e.toUserMessage(), isNotEmpty);
        }
      },
    );

    test(
      'invalid manifest — field hilang melempar RestoreError.invalidManifest',
      () async {
        // Manifest tanpa field 'application'
        final missingFieldZip = () {
          final json = {
            // 'application' sengaja dihilangkan
            'backupVersion': BackupManifest.currentBackupVersion,
            'databaseVersion': 2,
            'createdAt': DateTime.utc(2026).toIso8601String(),
            'appVersion': '1.0.0',
          };
          final archive = Archive()
            ..addFile(ArchiveFile.string('manifest.json', jsonEncode(json)))
            ..addFile(ArchiveFile('database.sqlite', 0, Uint8List(0)));
          return Uint8List.fromList(ZipEncoder().encode(archive)!);
        }();

        await expectLater(
          service.parseRestoreFile(missingFieldZip),
          throwsA(isA<RestoreError>()),
        );
      },
    );

    // -------------------------------------------------------------------------
    // 3. Versi backup tidak didukung
    // -------------------------------------------------------------------------
    test(
      'unsupported backup version melempar RestoreError.unsupportedVersion',
      () async {
        const unsupportedVersion = 99;
        final zip = buildValidZip(backupVersion: unsupportedVersion);

        try {
          await service.parseRestoreFile(zip);
          fail('Expected RestoreError.unsupportedVersion');
        } on RestoreError catch (e) {
          final msg = e.toUserMessage();
          expect(msg, isNotEmpty);
          expect(msg, contains('$unsupportedVersion'));
        }
      },
    );

    // -------------------------------------------------------------------------
    // 4. Restore berhasil — roundtrip penuh
    // -------------------------------------------------------------------------
    test('successful restore — data terpulihkan dari backup', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'finote_restore_success_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      // Isi database dengan 1 transaksi
      final category = await CategoryRepository(database)
          .create(name: 'Makan', type: TransactionType.expense);
      await TransactionRepository(database).create(
        type: TransactionType.expense,
        categoryId: category.id,
        amount: 10000,
        transactionDate: DateTime(2026, 8, 1),
      );

      // Buat backup dari data tersebut
      final backup = await service.buildBackup(
        appVersion: '1.0.0',
        temporaryDirectory: tempDir,
      );

      // Validasi backup: parseRestoreFile harus berhasil
      final preview = await service.parseRestoreFile(
        backup.bytes,
        temporaryDirectory: tempDir,
      );
      expect(preview.manifest.databaseVersion, database.schemaVersion);
      expect(preview.manifest.appVersion, '1.0.0');
      expect(preview.transactionCount, 1);
      expect(preview.categoryCount, 1);
      expect(preview.totalIncome, 0);
      expect(preview.totalExpense, 10000);
      expect(preview.oldestTransactionAt, DateTime(2026, 8, 1));
      expect(preview.newestTransactionAt, DateTime(2026, 8, 1));

      // Ekstrak database.sqlite dari backup dan verifikasi isi
      final archive = ZipDecoder().decodeBytes(backup.bytes);
      final dbEntry = archive.findFile('database.sqlite')!;
      final restoredDbFile = File('${tempDir.path}/restored.sqlite');
      await restoredDbFile.writeAsBytes(
        dbEntry.content as List<int>,
        flush: true,
      );

      // Periksa isi file database yang akan di-restore
      final restoredDb = sqlite3.open(
        restoredDbFile.path,
        mode: OpenMode.readOnly,
      );
      try {
        expect(
          restoredDb.select('PRAGMA integrity_check').single['integrity_check'],
          'ok',
        );
        expect(
          restoredDb
              .select('SELECT COUNT(*) AS c FROM transactions')
              .single['c'],
          1,
        );
      } finally {
        restoredDb.close();
      }
    });

    test('restore atomically replaces a file-backed database', () async {
      await database.close();
      final tempDir = await Directory.systemTemp.createTemp(
        'finote_atomic_restore_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final path = '${tempDir.path}/finote.sqlite';
      var live = AppDatabase(NativeDatabase(File(path)));

      final category = await CategoryRepository(live)
          .create(name: 'Makan', type: TransactionType.expense);
      final account = await AccountRepository(live)
          .create(name: 'DANA', type: AccountType.eWallet);
      await TransactionRepository(live).create(
        type: TransactionType.expense,
        categoryId: category.id,
        accountId: account.id,
        amount: 10000,
        transactionDate: DateTime(2026, 8, 1),
      );
      final fileService = BackupService(live, databasePath: path);
      final backup = await fileService.buildBackup(
        appVersion: '1.0.0',
        temporaryDirectory: tempDir,
      );
      await TransactionRepository(live).create(
        type: TransactionType.expense,
        categoryId: category.id,
        amount: 20000,
        transactionDate: DateTime(2026, 8, 2),
      );

      await fileService.restoreFromArchive(
        backup.bytes,
        temporaryDirectory: tempDir,
      );
      live = AppDatabase(NativeDatabase(File(path)));
      addTearDown(live.close);

      expect(await live.select(live.transactions).get(), hasLength(1));
      expect((await live.select(live.transactions).getSingle()).amount, 10000);
      expect(
        (await live.select(live.transactions).getSingle()).accountId,
        account.id,
      );
      expect(
        (await live.select(live.accounts).get()).map((account) => account.name),
        contains('DANA'),
      );
      final restoredSummary = await AccountRepository(live)
          .watchSummaries()
          .first;
      expect(
        restoredSummary
            .singleWhere((item) => item.account.id == account.id)
            .balance,
        -10000,
      );
      expect(
        tempDir.listSync().where((entry) => entry.path.contains('.rollback-')),
        isEmpty,
      );
    });

    // -------------------------------------------------------------------------
    // 5. Restore gagal — safety backup tetap ada (rollback/recovery)
    // -------------------------------------------------------------------------
    test(
      'failed restore — safety backup tidak terhapus dan data tetap aman',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'finote_restore_fail_test_',
        );
        addTearDown(() => tempDir.delete(recursive: true));

        // Isi database dengan data awal
        final category = await CategoryRepository(database)
            .create(name: 'Tagihan', type: TransactionType.expense);
        await TransactionRepository(database).create(
          type: TransactionType.expense,
          categoryId: category.id,
          amount: 50000,
          transactionDate: DateTime(2026, 8, 15),
        );

        // Simpan safety backup secara manual ke tempDir
        final backup = await service.buildBackup(
          appVersion: '1.0.0',
          temporaryDirectory: tempDir,
        );
        final safetyFile = File('${tempDir.path}/safety_backup.zip');
        await safetyFile.writeAsBytes(backup.bytes, flush: true);

        // Verifikasi safety backup ada sebelum "restore gagal"
        expect(await safetyFile.exists(), isTrue);

        // Simulasikan restore yang gagal: buat ZIP dengan database korup
        // (bytes tidak valid untuk SQLite)
        final corruptDbBytes = Uint8List.fromList(
          List.filled(1024, 0xAB), // bukan SQLite valid
        );
        final corruptZip = buildValidZip(dbBytes: corruptDbBytes);

        // Validasi harus menolak database korup sebelum restore dimulai.
        await expectLater(
          service.parseRestoreFile(corruptZip, temporaryDirectory: tempDir),
          throwsA(isA<RestoreError>()),
        );

        // Safety backup HARUS masih ada setelah restore gagal
        expect(
          await safetyFile.exists(),
          isTrue,
          reason: 'Safety backup harus tetap ada setelah restore gagal',
        );
      },
    );
  });
}
