import 'dart:io';

import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/legacy_import/data/legacy_importer.dart';
import 'package:finote/features/legacy_import/domain/legacy_schema.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_source.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
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

  Future<String> createLegacyDatabase() async {
    final path = '${tempDir.path}/legacy.db';
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

  test(
    'imports mapped transactions and reports progress and summary',
    () async {
      final path = await createLegacyDatabase();
      final legacy = sqlite3.open(path);
      legacy.execute(
        'INSERT INTO "Transaction" VALUES '
        "(10, 0, 25000, 1, 1672531200000, 'Sarapan'), "
        "(11, 1, 500000, 2, 1703980800000, 'Gaji Desember')",
      );
      legacy.close();

      final progress = <(int, int)>[];
      final summary = await LegacyImporter(
        database,
      ).import(path, onProgress: (done, total) => progress.add((done, total)));
      final transactions = await database.select(database.transactions).get();
      final categories = await database.select(database.categories).get();

      expect(summary.transactionsImported, 2);
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
      expect(
        transactions.every(
          (item) =>
              item.uuid.isNotEmpty &&
              item.source == TransactionSource.legacyImport &&
              item.legacySource == LegacySchema.legacySource,
        ),
        isTrue,
      );
      expect(transactions.map((item) => item.legacyId), {10, 11});
      expect(
        transactions.firstWhere((item) => item.legacyId == 10).transactionDate,
        DateTime(2023),
      );
    },
  );

  test('rolls back categories and transactions when import fails', () async {
    final path = await createLegacyDatabase();
    final legacy = sqlite3.open(path);
    legacy.execute(
      'INSERT INTO "Transaction" VALUES '
      "(10, 0, 25000, 1, 1672531200000, 'Duplikat')",
    );
    legacy.close();

    final category = await CategoryRepository(database)
        .create(name: 'Existing', type: TransactionType.expense);
    await TransactionRepository(database).create(
      type: TransactionType.expense,
      categoryId: category.id,
      amount: 1,
      transactionDate: DateTime(2023),
      source: TransactionSource.legacyImport,
      legacySource: LegacySchema.legacySource,
      legacyId: 10,
    );

    await expectLater(LegacyImporter(database).import(path), throwsException);

    expect(await database.select(database.categories).get(), hasLength(1));
    expect(await database.select(database.transactions).get(), hasLength(1));
  });
}
