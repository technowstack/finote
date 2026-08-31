import 'dart:io';

import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
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

  Future<String> createLegacyDatabase([String name = 'legacy.db']) async {
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
    legacy.execute('CREATE TABLE TransactionDay (date INTEGER NOT NULL)');
    legacy.execute('CREATE TABLE TransactionType (id INTEGER PRIMARY KEY)');
    legacy.execute('CREATE TABLE AppSetting (key TEXT PRIMARY KEY)');
    legacy.execute(
      "INSERT INTO TransactionSubType VALUES (1, 'Makan'), (2, 'Gaji')",
    );
    legacy.execute('INSERT INTO TransactionDay VALUES (0)');
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

  test('different legacy databases do not collide on reused IDs', () async {
    final firstPath = await createLegacyDatabase('first.db');
    final secondPath = await createLegacyDatabase('second.db');
    for (final path in [firstPath, secondPath]) {
      final legacy = sqlite3.open(path);
      legacy.execute(
        'INSERT INTO "Transaction" VALUES '
        "(10, 0, 25000, 1, 1672531200000, 'Sarapan')",
      );
      legacy.close();
    }

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
