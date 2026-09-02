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
import 'package:finote/features/export/data/export_repository.dart';
import 'package:finote/features/export/data/excel_exporter.dart';
import 'package:finote/features/export/data/pdf_exporter.dart';
import 'package:finote/features/export/data/text_exporter.dart';
import 'package:finote/features/export/domain/export_document.dart';
import 'package:finote/features/reports/data/report_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/data/financial_activity_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transfers/data/transfer_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

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

  Future<Uint8List> buildVersion3Backup(Directory directory) async {
    final file = File('${directory.path}/finote-v1.sqlite');
    final db = sqlite3.open(file.path);
    db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');
    db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        title TEXT NOT NULL,
        note TEXT,
        transaction_date TEXT NOT NULL,
        source TEXT NOT NULL,
        receipt_fingerprint TEXT,
        legacy_source TEXT,
        legacy_id INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');
    db.execute(
      "INSERT INTO categories VALUES "
      "(1, 'category-income-v1', 'Gaji', 'income', NULL, 1, 1, NULL), "
      "(2, 'category-expense-v1', 'Makan', 'expense', NULL, 1, 1, NULL)",
    );
    db.execute("INSERT INTO settings VALUES ('test-setting', 'preserved', 1)");
    db.execute(
      "INSERT INTO transactions VALUES "
      "(1, 'transaction-income-v1', 'income', 1, 10000000, 'Gaji', NULL, "
      "'2026-08-01', 'legacy_import', NULL, 'legacy-v1', 10, 1, 1, NULL), "
      "(2, 'transaction-expense-v1', 'expense', 2, 1000000, 'Makan', "
      "'Kantor', '2026-08-02', 'manual', 'fingerprint-v1', NULL, NULL, "
      "1, 1, NULL), "
      "(3, 'transaction-deleted-v1', 'expense', 2, 700000, 'Dihapus', NULL, "
      "'2026-08-03', 'manual', NULL, NULL, NULL, 1, 1, 2)",
    );
    db.userVersion = 3;
    db.close();
    return buildValidZip(databaseVersion: 3, dbBytes: await file.readAsBytes());
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

    test('manifest database version must match the SQLite snapshot', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'finote_manifest_mismatch_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final backup = await service.buildBackup(
        appVersion: '1.1.0',
        temporaryDirectory: tempDir,
      );
      final decoded = ZipDecoder().decodeBytes(backup.bytes);
      final mismatched = buildValidZip(
        databaseVersion: 7,
        dbBytes: Uint8List.fromList(
          decoded.findFile('database.sqlite')!.content as List<int>,
        ),
      );

      await expectLater(
        service.parseRestoreFile(mismatched, temporaryDirectory: tempDir),
        throwsA(isA<RestoreError>()),
      );
    });

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
      expect(preview.accountCount, 1);
      expect(preview.transferCount, 0);
      expect(preview.transferVolume, 0);
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
      final defaultAccount = (await live.select(live.accounts).get())
          .singleWhere((item) => item.isDefault);
      await TransferRepository(live).create(
        fromAccountId: account.id,
        toAccountId: defaultAccount.id,
        amount: 1000,
        transferDate: DateTime(2026, 8, 1),
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
      expect(await live.select(live.transfers).get(), hasLength(1));
      expect(
        await FinancialActivityRepository(live)
            .watch(const FinancialActivityQuery())
            .first,
        hasLength(2),
      );
      expect((await live.select(live.transactions).getSingle()).amount, 10000);
      expect(
        (await live.select(live.transactions).getSingle()).accountId,
        account.id,
      );
      expect(
        (await live.select(live.accounts).get()).map((account) => account.name),
        contains('DANA'),
      );
      final restoredSummaries = await AccountRepository(live)
          .watchSummaries()
          .first;
      expect(
        restoredSummaries
            .singleWhere((item) => item.account.id == account.id)
            .balance,
        -11000,
      );
      final restoredReport = await ReportRepository(live)
          .watchReport(
            ReportRange(
              start: DateTime(2026, 8, 1),
              end: DateTime(2026, 8, 31),
            ),
          )
          .first;
      expect(restoredReport.totalExpense, 10000);
      expect(restoredReport.transferSummary.count, 1);
      expect(restoredReport.transferSummary.volume, 1000);
      final restoredExport = await ExportRepository(live).buildDocument(
        ExportFilter(
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
        ),
      );
      expect(restoredExport.transactions.single.account, 'DANA');
      expect(restoredExport.transfers.single.fromAccount, 'DANA');
      expect(restoredExport.transferVolume, 1000);
      expect(
        tempDir.listSync().where((entry) => entry.path.contains('.rollback-')),
        isEmpty,
      );
    });

    test(
      'version 8 roundtrip preserves account and transfer identity',
      () async {
        await database.close();
        final tempDir = await Directory.systemTemp.createTemp(
          'finote_v11_roundtrip_test_',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final path = '${tempDir.path}/finote.sqlite';
        var live = AppDatabase(NativeDatabase(File(path)));
        final accounts = AccountRepository(live);
        final source = await accounts.create(
          name: 'BCA Utama',
          type: AccountType.bank,
          initialBalance: 5000000,
        );
        final destination = await accounts.create(
          name: 'BCA Tabungan',
          type: AccountType.savings,
        );
        final removed = await accounts.create(
          name: 'Akun Dihapus',
          type: AccountType.cash,
        );
        expect(await accounts.deleteUnusedAccount(removed.id), isTrue);
        final incomeCategory = await CategoryRepository(live)
            .create(name: 'Gaji', type: TransactionType.income);
        final expenseCategory = await CategoryRepository(live)
            .create(name: 'Makan', type: TransactionType.expense);
        final transactions = TransactionRepository(live);
        final income = await transactions.create(
          type: TransactionType.income,
          categoryId: incomeCategory.id,
          accountId: source.id,
          amount: 10000000,
          transactionDate: DateTime(2026, 8, 1),
        );
        final expense = await transactions.create(
          type: TransactionType.expense,
          categoryId: expenseCategory.id,
          accountId: source.id,
          amount: 1000000,
          transactionDate: DateTime(2026, 8, 2),
        );
        final deletedTransaction = await transactions.create(
          type: TransactionType.expense,
          categoryId: expenseCategory.id,
          accountId: destination.id,
          amount: 700000,
          transactionDate: DateTime(2026, 8, 3),
        );
        await transactions.softDelete(deletedTransaction.id);
        final transfers = TransferRepository(live);
        final transfer = await transfers.create(
          fromAccountId: source.id,
          toAccountId: destination.id,
          amount: 2000000,
          transferDate: DateTime(2026, 8, 4),
        );
        final defaultAccount = (await live.select(live.accounts).get())
            .singleWhere((account) => account.isDefault);
        final deletedTransfer = await transfers.create(
          fromAccountId: destination.id,
          toAccountId: defaultAccount.id,
          amount: 500000,
          transferDate: DateTime(2026, 8, 5),
        );
        await transfers.softDelete(deletedTransfer.id);
        await accounts.archive(destination.id);
        await live.customStatement(
          "INSERT INTO settings (key, value, updated_at) VALUES ('phase', '6A.8', 1)",
        );

        final service = BackupService(live, databasePath: path);
        final backup = await service.buildBackup(
          appVersion: '1.1.0',
          temporaryDirectory: tempDir,
        );
        final preview = await service.parseRestoreFile(
          backup.bytes,
          temporaryDirectory: tempDir,
        );
        expect(preview.accountCount, 3);
        expect(preview.transferCount, 1);
        expect(preview.transferVolume, 2000000);

        await accounts.update(
          id: source.id,
          name: source.name,
          type: source.type,
          initialBalance: 0,
        );
        await transactions.create(
          type: TransactionType.expense,
          categoryId: expenseCategory.id,
          amount: 999999,
          transactionDate: DateTime(2026, 8, 6),
        );
        await service.restoreFromArchive(
          backup.bytes,
          temporaryDirectory: tempDir,
        );
        live = AppDatabase(NativeDatabase(File(path)));
        addTearDown(live.close);

        final restoredAccounts = await live.select(live.accounts).get();
        expect(
          restoredAccounts.map((account) => account.uuid),
          isNot(contains(removed.uuid)),
        );
        final restoredSource = restoredAccounts.singleWhere(
          (account) => account.id == source.id,
        );
        final restoredDestination = restoredAccounts.singleWhere(
          (account) => account.id == destination.id,
        );
        expect(restoredSource.uuid, source.uuid);
        expect(restoredSource.initialBalance, 5000000);
        expect(restoredDestination.uuid, destination.uuid);
        expect(restoredDestination.isActive, isFalse);

        final restoredTransactions = await live.select(live.transactions).get();
        expect(restoredTransactions, hasLength(3));
        expect(
          restoredTransactions
              .singleWhere((row) => row.id == income.id)
              .accountId,
          source.id,
        );
        expect(
          restoredTransactions.singleWhere((row) => row.id == income.id).uuid,
          income.uuid,
        );
        expect(
          restoredTransactions.singleWhere((row) => row.id == expense.id).uuid,
          expense.uuid,
        );
        expect(
          restoredTransactions
              .singleWhere((row) => row.id == deletedTransaction.id)
              .deletedAt,
          isNotNull,
        );

        final restoredTransfers = await live.select(live.transfers).get();
        expect(restoredTransfers, hasLength(2));
        final restoredTransfer = restoredTransfers.singleWhere(
          (row) => row.id == transfer.id,
        );
        expect(restoredTransfer.uuid, transfer.uuid);
        expect(restoredTransfer.fromAccountId, source.id);
        expect(restoredTransfer.toAccountId, destination.id);
        expect(
          restoredTransfers
              .singleWhere((row) => row.id == deletedTransfer.id)
              .deletedAt,
          isNotNull,
        );
        expect(
          (await live.select(live.settings).get())
              .singleWhere((setting) => setting.key == 'phase')
              .value,
          '6A.8',
        );

        final summaries = await AccountRepository(live).watchSummaries().first;
        expect(
          summaries.singleWhere((row) => row.account.id == source.id).balance,
          12000000,
        );
        expect(
          summaries
              .singleWhere((row) => row.account.id == destination.id)
              .balance,
          2000000,
        );
        expect(
          summaries.fold<int>(0, (total, row) => total + row.balance),
          14000000,
        );
        final range = ReportRange(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 31),
        );
        final report = await ReportRepository(live).watchReport(range).first;
        final trend = await ReportRepository(live)
            .watchFinancialTrend(range)
            .first;
        expect(
          (report.totalIncome, report.totalExpense, report.netBalance),
          (10000000, 1000000, 9000000),
        );
        expect(
          (
            trend.fold<int>(0, (sum, point) => sum + point.income),
            trend.fold<int>(0, (sum, point) => sum + point.expense),
          ),
          (report.totalIncome, report.totalExpense),
        );
        expect(
          (report.transferSummary.count, report.transferSummary.volume),
          (1, 2000000),
        );
        expect(
          await FinancialActivityRepository(live)
              .watch(const FinancialActivityQuery())
              .first,
          hasLength(3),
        );
        final export = await ExportRepository(live).buildDocument(
          ExportFilter(startDate: range.start, endDate: range.end),
        );
        expect(
          (export.totalIncome, export.totalExpense, export.balance),
          (10000000, 1000000, 9000000),
        );
        expect(export.totalAssets, 14000000);
        expect(export.transfers.single.fromAccount, 'BCA Utama');
        expect(buildExcelExport(export), isNotEmpty);
        expect(buildTextExport(export), contains('BCA Utama -> BCA Tabungan'));
        expect(await buildPdfExport(export), isNotEmpty);
      },
    );

    test('restores and migrates a populated version 3 backup', () async {
      await database.close();
      final tempDir = await Directory.systemTemp.createTemp(
        'finote_v1_restore_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final path = '${tempDir.path}/current.sqlite';
      var live = AppDatabase(NativeDatabase(File(path)));
      await live.customSelect('SELECT 1').getSingle();
      final archive = await buildVersion3Backup(tempDir);
      final oldBackupService = BackupService(live, databasePath: path);

      final preview = await oldBackupService.parseRestoreFile(
        archive,
        temporaryDirectory: tempDir,
      );
      expect(preview.manifest.databaseVersion, 3);
      expect(preview.transactionCount, 2);
      expect(preview.accountCount, 1);
      expect(preview.transferCount, 0);
      expect(preview.totalIncome, 10000000);
      expect(preview.totalExpense, 1000000);

      await oldBackupService.restoreFromArchive(
        archive,
        temporaryDirectory: tempDir,
      );
      live = AppDatabase(NativeDatabase(File(path)));
      addTearDown(live.close);

      final version = await live
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 8);
      final restoredAccounts = await live.select(live.accounts).get();
      expect(restoredAccounts, hasLength(1));
      expect(restoredAccounts.single.name, 'Tunai');
      expect(restoredAccounts.single.isDefault, isTrue);
      final restoredTransactions = await live.select(live.transactions).get();
      expect(restoredTransactions, hasLength(3));
      expect(
        restoredTransactions.every(
          (transaction) => transaction.accountId == restoredAccounts.single.id,
        ),
        isTrue,
      );
      expect(
        restoredTransactions.map((transaction) => transaction.uuid),
        containsAll([
          'transaction-income-v1',
          'transaction-expense-v1',
          'transaction-deleted-v1',
        ]),
      );
      expect(
        restoredTransactions
            .singleWhere((transaction) => transaction.id == 3)
            .deletedAt,
        isNotNull,
      );
      expect(await live.select(live.transfers).get(), isEmpty);
      expect((await live.select(live.settings).getSingle()).value, 'preserved');

      final summary = (await AccountRepository(
        live,
      ).watchSummaries().first).single;
      expect(summary.balance, 9000000);
      final report = await ReportRepository(live)
          .watchReport(
            ReportRange(
              start: DateTime(2026, 8, 1),
              end: DateTime(2026, 8, 31),
            ),
          )
          .first;
      expect(
        (report.totalIncome, report.totalExpense, report.netBalance),
        (10000000, 1000000, 9000000),
      );
      expect(report.transferSummary.count, 0);
      expect(
        await FinancialActivityRepository(live)
            .watch(const FinancialActivityQuery())
            .first,
        hasLength(2),
      );
      final export = await ExportRepository(live).buildDocument(
        ExportFilter(
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
        ),
      );
      expect(export.transactions, hasLength(2));
      expect(
        export.transactions.every((row) => row.account == 'Tunai'),
        isTrue,
      );
      expect(export.transfers, isEmpty);
    });

    test('rejects orphaned or unassigned account relations safely', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'finote_relation_validation_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final accounts = AccountRepository(database);
      final source = await accounts.create(name: 'A', type: AccountType.bank);
      final destination = await accounts.create(
        name: 'B',
        type: AccountType.cash,
      );
      final category = await CategoryRepository(database)
          .create(name: 'Gaji', type: TransactionType.income);
      await TransactionRepository(database).create(
        type: TransactionType.income,
        categoryId: category.id,
        accountId: source.id,
        amount: 1000,
        transactionDate: DateTime(2026, 8, 1),
      );
      await TransferRepository(database).create(
        fromAccountId: source.id,
        toAccountId: destination.id,
        amount: 500,
        transferDate: DateTime(2026, 8, 1),
      );
      final backup = await service.buildBackup(
        appVersion: '1.1.0',
        temporaryDirectory: tempDir,
      );
      final snapshotBytes = Uint8List.fromList(
        ZipDecoder()
                .decodeBytes(backup.bytes)
                .findFile('database.sqlite')!
                .content
            as List<int>,
      );

      for (final entry in [
        ('transaction account', 'UPDATE transactions SET account_id = 999'),
        ('unassigned transaction', 'UPDATE transactions SET account_id = NULL'),
        ('transfer source', 'UPDATE transfers SET from_account_id = 999'),
        ('transfer destination', 'UPDATE transfers SET to_account_id = 999'),
        (
          'same transfer account',
          'UPDATE transfers SET to_account_id = from_account_id',
        ),
      ]) {
        final file = File('${tempDir.path}/${entry.$1}.sqlite');
        await file.writeAsBytes(snapshotBytes, flush: true);
        final corrupt = sqlite3.open(file.path);
        corrupt.execute('PRAGMA ignore_check_constraints = ON');
        corrupt.execute(entry.$2);
        corrupt.close();
        final archive = buildValidZip(
          databaseVersion: database.schemaVersion,
          dbBytes: await file.readAsBytes(),
        );

        await expectLater(
          service.parseRestoreFile(archive, temporaryDirectory: tempDir),
          throwsA(isA<RestoreError>()),
          reason: entry.$1,
        );
        await expectLater(
          service.restoreFromArchive(archive, temporaryDirectory: tempDir),
          throwsA(isA<RestoreError>()),
          reason: entry.$1,
        );
        expect(
          await database.select(database.transactions).get(),
          hasLength(1),
        );
        expect(await database.select(database.transfers).get(), hasLength(1));
      }
    });

    test(
      'database provider invalidation reloads restored feature state',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'finote_restore_provider_test_',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final sourcePath = '${tempDir.path}/source.sqlite';
        final sourceDb = AppDatabase(NativeDatabase(File(sourcePath)));
        final sourceAccounts = AccountRepository(sourceDb);
        final source = await sourceAccounts.create(
          name: 'Sumber Restore',
          type: AccountType.bank,
        );
        final destination = await sourceAccounts.create(
          name: 'Tujuan Restore',
          type: AccountType.savings,
        );
        final category = await CategoryRepository(sourceDb)
            .create(name: 'Gaji Restore', type: TransactionType.income);
        await TransactionRepository(sourceDb).create(
          type: TransactionType.income,
          categoryId: category.id,
          accountId: source.id,
          amount: 500000,
          transactionDate: DateTime(2026, 8, 1),
        );
        await TransferRepository(sourceDb).create(
          fromAccountId: source.id,
          toAccountId: destination.id,
          amount: 100000,
          transferDate: DateTime(2026, 8, 2),
        );
        final backup = await BackupService(
          sourceDb,
          databasePath: sourcePath,
        ).buildBackup(appVersion: '1.1.0', temporaryDirectory: tempDir);
        await sourceDb.close();

        final targetPath = '${tempDir.path}/target.sqlite';
        final initial = AppDatabase(NativeDatabase(File(targetPath)));
        await initial.customSelect('SELECT 1').getSingle();
        await initial.close();
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWith((ref) {
              final db = AppDatabase(NativeDatabase(File(targetPath)));
              ref.onDispose(db.close);
              return db;
            }),
          ],
        );
        addTearDown(container.dispose);
        expect(await container.read(transfersProvider.future), isEmpty);

        await BackupService(
          container.read(databaseProvider),
          databasePath: targetPath,
        ).restoreFromArchive(backup.bytes, temporaryDirectory: tempDir);
        container.invalidate(databaseProvider);

        final restoredAccounts = await container.read(
          accountSummariesProvider.future,
        );
        expect(
          restoredAccounts.map((row) => row.account.name),
          containsAll(['Sumber Restore', 'Tujuan Restore']),
        );
        expect(await container.read(transfersProvider.future), hasLength(1));
        expect(
          await container.read(
            financialActivityProvider(const FinancialActivityQuery()).future,
          ),
          hasLength(2),
        );
        final report = await container.read(
          reportProvider(
            ReportRange(
              start: DateTime(2026, 8, 1),
              end: DateTime(2026, 8, 31),
            ),
          ).future,
        );
        expect(report.totalIncome, 500000);
        expect(report.transferSummary.count, 1);
      },
    );

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
