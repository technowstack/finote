import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/backup/data/backup_service.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/export/data/export_repository.dart';
import 'package:finote/features/export/domain/export_document.dart';
import 'package:finote/features/legacy_import/data/legacy_importer.dart';
import 'package:finote/features/legacy_import/domain/legacy_schema.dart';
import 'package:finote/features/reports/data/report_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_source.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transactions/data/financial_activity_repository.dart';
import 'package:finote/features/transfers/data/transfer_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  late AppDatabase database;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finote_import_test_');
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  Future<String> createLegacyDatabase([
    String name = 'legacy.db',
    bool includeOptionalTables = true,
  ]) async {
    final path = '${tempDir.path}/$name';
    final legacy = sqlite3.open(path);
    legacy.execute('''
      CREATE TABLE "Transaction" (
        id INTEGER PRIMARY KEY,
        type INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        subType INTEGER NOT NULL,
        date INTEGER NOT NULL,
        title TEXT
      )
    ''');
    legacy.execute('''
      CREATE TABLE TransactionSubType (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');
    if (includeOptionalTables) {
      legacy.execute('CREATE TABLE TransactionDay (date INTEGER NOT NULL)');
      legacy.execute('CREATE TABLE TransactionType (id INTEGER PRIMARY KEY)');
      legacy.execute('CREATE TABLE AppSetting (key TEXT PRIMARY KEY)');
    }
    legacy.execute(
      "INSERT INTO TransactionSubType VALUES (1, 'Makan'), (2, 'Gaji')",
    );
    if (includeOptionalTables) {
      legacy.execute('INSERT INTO TransactionDay VALUES (0)');
    }
    legacy.close();
    return path;
  }

  test('first import inserts every mapped legacy transaction', () async {
    final path = await createLegacyDatabase();
    final legacy = sqlite3.open(path);
    legacy.execute(
      'INSERT INTO "Transaction" VALUES '
      "(10, 0, 25000, 1, 1672531200000, 'Sarapan'), "
      "(11, 1, 500000, 2, 1703980800000, 'Gaji Desember')",
    );
    legacy.close();
    final sourceBytes = await File(path).readAsBytes();

    final progress = <(int, int)>[];
    final summary = await LegacyImporter(database)
        .import(path, onProgress: (done, total) => progress.add((done, total)));
    final transactions = await database.select(database.transactions).get();
    final categories = await database.select(database.categories).get();

    expect(summary.newCount, 2);
    expect(summary.duplicateCount, 0);
    expect(summary.failedCount, 0);
    expect(summary.categoriesCreated, 2);
    expect(summary.totalIncome, 500000);
    expect(summary.totalExpense, 25000);
    expect(progress, [(2, 2)]);
    expect(categories.map((item) => (item.name, item.type)), {
      ('Makan', TransactionType.expense),
      ('Gaji', TransactionType.income),
    });
    expect(transactions.map((item) => item.title), {
      'Sarapan',
      'Gaji Desember',
    });
    expect(transactions.map((item) => item.amount), {25000, 500000});
    expect(transactions.map((item) => item.type), {
      TransactionType.expense,
      TransactionType.income,
    });
    final defaultAccount = await database.select(database.accounts).getSingle();
    expect(
      transactions.every((item) => item.accountId == defaultAccount.id),
      isTrue,
    );
    expect(
      transactions.every(
        (item) =>
            item.uuid.isNotEmpty &&
            item.source == TransactionSource.legacyImport &&
            item.legacySource?.startsWith(LegacySchema.legacySource) == true,
      ),
      isTrue,
    );
    expect(transactions.map((item) => item.legacyId), {10, 11});
    expect(
      transactions.firstWhere((item) => item.legacyId == 10).transactionDate,
      DateTime(2023),
    );
    final importedSummary = await AccountRepository(database)
        .watchSummaries()
        .first;
    expect(importedSummary.single.balance, 475000);
    final history = await FinancialActivityRepository(database)
        .watch(const FinancialActivityQuery())
        .first;
    expect(history, hasLength(2));
    expect(history.every((item) => item.subtitle == 'Tunai'), isTrue);
    expect(await database.select(database.transfers).get(), isEmpty);
    final report = await ReportRepository(database)
        .watchReport(
          ReportRange(start: DateTime(2023), end: DateTime(2023, 12, 31)),
        )
        .first;
    expect(report.totalIncome, 500000);
    expect(report.totalExpense, 25000);
    expect(report.transferSummary.count, 0);
    final export = await ExportRepository(database).buildDocument(
      ExportFilter(startDate: DateTime(2023), endDate: DateTime(2023, 12, 31)),
    );
    expect(export.transactions, hasLength(2));
    expect(export.transactions.every((row) => row.account == 'Tunai'), isTrue);
    expect(export.transfers, isEmpty);
    expect(await File(path).readAsBytes(), sourceBytes);
  });

  test('empty legacy database is a safe no-op', () async {
    final path = await createLegacyDatabase('empty.db', false);

    final summary = await LegacyImporter(database).import(path);

    expect((summary.newCount, summary.duplicateCount), (0, 0));
    expect(summary.categoriesCreated, 0);
    expect(await database.select(database.transactions).get(), isEmpty);
    expect(await database.select(database.categories).get(), isEmpty);
    expect(await database.select(database.accounts).get(), hasLength(1));
  });

  test('second import of the same database skips every transaction', () async {
    final path = await createLegacyDatabase();
    final legacy = sqlite3.open(path);
    legacy.execute(
      'INSERT INTO "Transaction" VALUES '
      "(10, 0, 25000, 1, 1672531200000, 'Sarapan'), "
      "(11, 1, 500000, 2, 1703980800000, 'Gaji Desember')",
    );
    legacy.close();

    await LegacyImporter(database).import(path);
    final second = await LegacyImporter(database).import(path);

    expect(second.newCount, 0);
    expect(second.duplicateCount, 2);
    expect(second.failedCount, 0);
    expect(second.categoriesCreated, 0);
    expect(await database.select(database.transactions).get(), hasLength(2));
    expect(await database.select(database.categories).get(), hasLength(2));
  });

  test('copied legacy database keeps the same source identity', () async {
    final path = await createLegacyDatabase();
    final legacy = sqlite3.open(path);
    legacy.execute(
      'INSERT INTO "Transaction" VALUES '
      "(10, 0, 25000, 1, 1672531200000, 'Sarapan')",
    );
    legacy.close();

    await LegacyImporter(database).import(path);
    final copiedPath = '${tempDir.path}/copied.db';
    await File(path).copy(copiedPath);
    final repeated = await LegacyImporter(database).import(copiedPath);

    expect(repeated.newCount, 0);
    expect(repeated.duplicateCount, 1);
    expect(await database.select(database.transactions).get(), hasLength(1));
  });

  test('different legacy databases do not collide on reused IDs', () async {
    final firstPath = await createLegacyDatabase('first.db');
    final secondPath = await createLegacyDatabase('second.db');
    final first = sqlite3.open(firstPath);
    first.execute(
      'INSERT INTO "Transaction" VALUES '
      "(10, 0, 25000, 1, 1672531200000, 'Sarapan')",
    );
    first.close();
    final secondDatabase = sqlite3.open(secondPath);
    secondDatabase.execute(
      'INSERT INTO "Transaction" VALUES '
      "(10, 0, 30000, 1, 1672531200000, 'Makan siang')",
    );
    secondDatabase.close();

    await LegacyImporter(database).import(firstPath);
    final second = await LegacyImporter(database).import(secondPath);

    expect(second.newCount, 1);
    expect(await database.select(database.transactions).get(), hasLength(2));
  });

  test(
    'partially imported database only inserts missing transactions',
    () async {
      final path = await createLegacyDatabase();
      final legacy = sqlite3.open(path);
      legacy.execute(
        'INSERT INTO "Transaction" VALUES '
        "(10, 0, 25000, 1, 1672531200000, 'Sarapan'), "
        "(11, 1, 500000, 2, 1703980800000, 'Gaji Desember')",
      );
      legacy.close();

      final category = await CategoryRepository(database)
          .create(name: 'Makan', type: TransactionType.expense);
      await TransactionRepository(database).create(
        type: TransactionType.expense,
        categoryId: category.id,
        amount: 25000,
        transactionDate: DateTime(2023),
        source: TransactionSource.legacyImport,
        legacySource: LegacySchema.legacySource,
        legacyId: 10,
      );

      final summary = await LegacyImporter(database).import(path);

      expect(summary.newCount, 1);
      expect(summary.duplicateCount, 1);
      expect(summary.failedCount, 0);
      expect(summary.categoriesCreated, 1);
      expect(await database.select(database.transactions).get(), hasLength(2));
      expect(
        (await database.select(database.transactions).get()).map(
          (item) => item.legacyId,
        ),
        containsAll([10, 11]),
      );
    },
  );

  test(
    'reimport preserves user reassignment, edits, and soft delete',
    () async {
      final path = await createLegacyDatabase();
      final legacy = sqlite3.open(path);
      legacy.execute(
        'INSERT INTO "Transaction" VALUES '
        "(10, 0, 25000, 1, 1672531200000, 'Sarapan'), "
        "(11, 1, 500000, 2, 1703980800000, 'Gaji')",
      );
      legacy.close();
      await LegacyImporter(database).import(path);

      final accounts = AccountRepository(database);
      final bca = await accounts.create(name: 'BCA', type: AccountType.bank);
      final correctedCategory = await CategoryRepository(database)
          .create(name: 'Makan dikoreksi', type: TransactionType.expense);
      final repository = TransactionRepository(database);
      final imported = await database.select(database.transactions).get();
      final edited = imported.singleWhere((row) => row.legacyId == 10);
      await repository.update(
        edited.copyWith(
          title: 'Sarapan dikoreksi',
          accountId: Value<int?>(bca.id),
          categoryId: correctedCategory.id,
          note: const Value('Catatan pengguna'),
        ),
      );
      final deleted = imported.singleWhere((row) => row.legacyId == 11);
      await repository.softDelete(deleted.id);

      final repeated = await LegacyImporter(database).import(path);
      final after = await database.select(database.transactions).get();

      expect((repeated.newCount, repeated.duplicateCount), (0, 2));
      expect(after, hasLength(2));
      expect(
        after.singleWhere((row) => row.legacyId == 10),
        isA<TransactionRecord>()
            .having((row) => row.title, 'title', 'Sarapan dikoreksi')
            .having((row) => row.accountId, 'account', bca.id)
            .having((row) => row.categoryId, 'category', correctedCategory.id)
            .having((row) => row.note, 'note', 'Catatan pengguna'),
      );
      expect(
        after.singleWhere((row) => row.legacyId == 11).deletedAt,
        isNotNull,
      );
    },
  );

  test('import preserves existing Finote data and transfers', () async {
    final accounts = AccountRepository(database);
    final defaultAccount = await database.select(database.accounts).getSingle();
    final bca = await accounts.create(name: 'BCA', type: AccountType.bank);
    final transfer = await TransferRepository(database).create(
      fromAccountId: defaultAccount.id,
      toAccountId: bca.id,
      amount: 100000,
      transferDate: DateTime(2023),
    );
    final existingCategory = await CategoryRepository(database)
        .create(name: 'Bonus', type: TransactionType.income);
    final existingTransaction = await TransactionRepository(database).create(
      type: TransactionType.income,
      categoryId: existingCategory.id,
      accountId: bca.id,
      amount: 1000000,
      transactionDate: DateTime(2023),
    );
    final path = await createLegacyDatabase('minimal.db', false);
    final legacy = sqlite3.open(path);
    legacy.execute(
      'INSERT INTO "Transaction" VALUES '
      "(10, 0, 25000, 1, 1672531200000, 'Sarapan')",
    );
    legacy.close();

    final summary = await LegacyImporter(database).import(path);

    expect(summary.destinationAccount, defaultAccount.name);
    expect(await database.select(database.accounts).get(), hasLength(2));
    expect(
      (await database.select(database.transactions).get()).map((row) => row.id),
      contains(existingTransaction.id),
    );
    expect(
      (await database.select(database.transfers).get()).single.id,
      transfer.id,
    );
    expect(defaultAccount.initialBalance, 0);
  });

  test('repairs a missing active default before import', () async {
    final defaultAccount = await database.select(database.accounts).getSingle();
    await (database.update(database.accounts)
          ..where((account) => account.id.equals(defaultAccount.id)))
        .write(const AccountsCompanion(isActive: Value(false)));
    final path = await createLegacyDatabase();
    final legacy = sqlite3.open(path);
    legacy.execute(
      'INSERT INTO "Transaction" VALUES '
      "(10, 1, 1000, 2, 1672531200000, 'Bonus')",
    );
    legacy.close();

    await LegacyImporter(database).import(path);

    final repaired = await database.select(database.accounts).getSingle();
    expect(repaired.id, defaultAccount.id);
    expect(repaired.isActive, isTrue);
    expect(
      (await database.select(database.transactions).getSingle()).accountId,
      repaired.id,
    );
  });

  test('unsupported source leaves existing Finote data untouched', () async {
    final category = await CategoryRepository(database)
        .create(name: 'Bonus', type: TransactionType.income);
    final existing = await TransactionRepository(database).create(
      type: TransactionType.income,
      categoryId: category.id,
      amount: 1000,
      transactionDate: DateTime(2023),
    );
    final path = '${tempDir.path}/unsupported.db';
    final unsupported = sqlite3.open(path);
    unsupported.execute('CREATE TABLE unrelated (id INTEGER PRIMARY KEY)');
    unsupported.close();

    await expectLater(LegacyImporter(database).import(path), throwsException);

    final transactions = await database.select(database.transactions).get();
    expect(transactions.single.id, existing.id);
    expect(await database.select(database.categories).get(), hasLength(1));
  });

  test('imports 10000 integer transactions exactly', () async {
    final path = await createLegacyDatabase();
    final legacy = sqlite3.open(path);
    final statement = legacy.prepare(
      'INSERT INTO "Transaction" VALUES (?, 1, ?, 2, ?, ?)',
    );
    const amounts = [1, 1000, 1000000, 9000000000000];
    legacy.execute('BEGIN');
    var expectedTotal = 0;
    for (var index = 1; index <= 10000; index++) {
      final amount = amounts[index % amounts.length];
      expectedTotal += amount;
      statement.execute([
        index,
        amount,
        1672531200000 + index * 86400000,
        'Transaksi $index',
      ]);
    }
    legacy.execute('COMMIT');
    statement.close();
    legacy.close();

    final summary = await LegacyImporter(database).import(path);

    expect(summary.newCount, 10000);
    expect(summary.totalIncome, expectedTotal);
    expect(
      await database.select(database.transactions).get(),
      hasLength(10000),
    );
    expect(
      (await AccountRepository(database).watchSummaries().first).single.balance,
      expectedTotal,
    );
    expect(await database.select(database.transfers).get(), isEmpty);
  });

  test(
    'backup restore preserves legacy identity and account relation',
    () async {
      await database.close();
      final databasePath = '${tempDir.path}/finote.sqlite';
      database = AppDatabase(NativeDatabase(File(databasePath)));
      final legacyPath = await createLegacyDatabase('source.db');
      final legacy = sqlite3.open(legacyPath);
      legacy.execute(
        'INSERT INTO "Transaction" VALUES '
        "(10, 1, 500000, 2, 1672531200000, 'Gaji')",
      );
      legacy.close();
      await LegacyImporter(database).import(legacyPath);
      final before = await database.select(database.transactions).getSingle();
      final defaultBefore = await database
          .select(database.accounts)
          .getSingle();
      final service = BackupService(database, databasePath: databasePath);
      final backup = await service.buildBackup(
        appVersion: '1.1.0',
        temporaryDirectory: tempDir,
      );

      await service.restoreFromArchive(
        backup.bytes,
        temporaryDirectory: tempDir,
      );
      database = AppDatabase(NativeDatabase(File(databasePath)));
      final restored = await database.select(database.transactions).getSingle();
      final defaultAfter = await database.select(database.accounts).getSingle();

      expect(restored.uuid, before.uuid);
      expect(restored.legacySource, before.legacySource);
      expect(restored.legacyId, 10);
      expect(restored.accountId, defaultAfter.id);
      expect(defaultAfter.uuid, defaultBefore.uuid);
      expect((await LegacyImporter(database).import(legacyPath)).newCount, 0);
      expect(await database.select(database.transfers).get(), isEmpty);
    },
  );

  test('rolls back categories and transactions when import fails', () async {
    final path = await createLegacyDatabase();
    final legacy = sqlite3.open(path);
    legacy.execute(
      'INSERT INTO "Transaction" VALUES '
      "(10, 0, 25000, 1, 1672531200000, 'Valid'), "
      "(11, 0, 10000, 99, 1672617600000, 'Kategori hilang')",
    );
    legacy.close();

    await expectLater(LegacyImporter(database).import(path), throwsException);

    expect(await database.select(database.categories).get(), isEmpty);
    expect(await database.select(database.transactions).get(), isEmpty);
  });
}
