import 'dart:async';

import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/reports/data/report_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ReportRepository reports;
  late TransactionRepository transactions;
  late CategoryRepository categories;
  late CategoryRecord salary;
  late CategoryRecord bonus;
  late CategoryRecord food;
  late CategoryRecord transport;
  late Future<void> Function() seedAugustTransactions;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    reports = ReportRepository(database);
    transactions = TransactionRepository(database);
    categories = CategoryRepository(database);
    salary = await categories.create(
      name: 'Gaji',
      type: TransactionType.income,
    );
    bonus = await categories.create(
      name: 'Bonus',
      type: TransactionType.income,
    );
    food = await categories.create(
      name: 'Makanan',
      type: TransactionType.expense,
    );
    transport = await categories.create(
      name: 'Transportasi',
      type: TransactionType.expense,
    );
    seedAugustTransactions = () async {
      await transactions.create(
        type: TransactionType.income,
        categoryId: salary.id,
        amount: 1000000,
        transactionDate: DateTime(2026, 8, 1),
      );
      await transactions.create(
        type: TransactionType.income,
        categoryId: bonus.id,
        amount: 200000,
        transactionDate: DateTime(2026, 8, 15),
      );
      await transactions.create(
        type: TransactionType.expense,
        categoryId: food.id,
        amount: 300000,
        transactionDate: DateTime(2026, 8, 5),
      );
      await transactions.create(
        type: TransactionType.expense,
        categoryId: food.id,
        amount: 100000,
        transactionDate: DateTime(2026, 8, 20),
      );
      await transactions.create(
        type: TransactionType.expense,
        categoryId: transport.id,
        amount: 250000,
        transactionDate: DateTime(2026, 8, 25),
      );
    };
  });

  tearDown(() => database.close());

  test('report calculates totals and top categories for its range', () async {
    await seedAugustTransactions();

    final report = await reports
        .watchReport(
          ReportRange(start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 31)),
        )
        .first;

    expect(report.totalIncome, 1200000);
    expect(report.totalExpense, 650000);
    expect(report.transactionCount, 5);
    expect(report.netBalance, 550000);
    expect(
      report.topExpenseCategories.map(
        (item) => (item.categoryName, item.amount),
      ),
      [('Makanan', 400000), ('Transportasi', 250000)],
    );
    expect(
      report.topIncomeCategories.map(
        (item) => (item.categoryName, item.amount),
      ),
      [('Gaji', 1000000), ('Bonus', 200000)],
    );
  });

  test(
    'report groups monthly history and excludes soft deleted records',
    () async {
      await seedAugustTransactions();
      await transactions.create(
        type: TransactionType.income,
        categoryId: salary.id,
        amount: 500000,
        transactionDate: DateTime(2026, 7, 31),
      );
      final deleted = await transactions.create(
        type: TransactionType.expense,
        categoryId: food.id,
        amount: 999999,
        transactionDate: DateTime(2026, 8, 10),
      );
      await transactions.softDelete(deleted.id);

      final report = await reports
          .watchReport(
            ReportRange(
              start: DateTime(2026, 7, 1),
              end: DateTime(2026, 8, 31),
            ),
          )
          .first;

      expect(report.totalIncome, 1700000);
      expect(report.totalExpense, 650000);
      expect(report.monthlyHistory.map((item) => item.month), [
        '2026-08',
        '2026-07',
      ]);
      expect(report.monthlyHistory.first.income, 1200000);
      expect(report.monthlyHistory.first.expense, 650000);
    },
  );

  test('report stream reacts and top categories are limited to five', () async {
    final range = ReportRange(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 31),
    );
    final iterator = StreamIterator(reports.watchReport(range));
    addTearDown(iterator.cancel);
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current.isEmpty, isTrue);
    expect(iterator.current.transactionCount, 0);

    await transactions.create(
      type: TransactionType.expense,
      categoryId: food.id,
      amount: 500,
      transactionDate: DateTime(2026, 8, 1),
    );
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current.totalExpense, 500);
    await iterator.cancel();

    for (var index = 1; index <= 6; index++) {
      final category = await categories.create(
        name: 'Expense $index',
        type: TransactionType.expense,
      );
      await transactions.create(
        type: TransactionType.expense,
        categoryId: category.id,
        amount: index * 1000,
        transactionDate: DateTime(2026, 8, index),
      );
    }

    final report = await reports.watchReport(range).first;
    expect(report.topExpenseCategories, hasLength(5));
    expect(report.topExpenseCategories.first.categoryName, 'Expense 6');
  });

  test(
    'editing type and date moves the amount between report periods',
    () async {
      final transaction = await transactions.create(
        type: TransactionType.expense,
        categoryId: food.id,
        amount: 100000,
        transactionDate: DateTime(2026, 7, 31),
      );

      final july = ReportRange(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
      );
      expect((await reports.watchReport(july).first).totalExpense, 100000);

      await transactions.update(
        transaction.copyWith(
          type: TransactionType.income,
          categoryId: salary.id,
          transactionDate: DateTime(2026, 8, 1),
        ),
      );

      final august = ReportRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      );
      expect((await reports.watchReport(july).first).totalExpense, 0);
      final augustReport = await reports.watchReport(august).first;
      expect(augustReport.totalIncome, 100000);
      expect(augustReport.totalExpense, 0);
      expect(augustReport.balance, 100000);
    },
  );
}
