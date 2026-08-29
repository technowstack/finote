import 'dart:async';

import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/dashboard/data/dashboard_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DashboardRepository dashboard;
  late TransactionRepository transactions;
  late CategoryRecord incomeCategory;
  late CategoryRecord expenseCategory;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    dashboard = DashboardRepository(database);
    transactions = TransactionRepository(database);
    final categories = CategoryRepository(database);
    incomeCategory = await categories.create(
      name: 'Gaji',
      type: TransactionType.income,
    );
    expenseCategory = await categories.create(
      name: 'Belanja',
      type: TransactionType.expense,
    );
  });

  tearDown(() => database.close());

  test('summary reacts to real transaction writes', () async {
    final summaries = StreamIterator(
      dashboard.watchSummary(DateTime(2026, 8, 29)),
    );
    addTearDown(summaries.cancel);

    expect(await summaries.moveNext(), isTrue);
    expect(summaries.current.balance, 0);

    final transaction = await transactions.create(
      type: TransactionType.income,
      categoryId: incomeCategory.id,
      amount: 1000000,
      transactionDate: DateTime(2026, 8, 29),
    );

    expect(await summaries.moveNext(), isTrue);
    expect(summaries.current.balance, 1000000);
    expect(summaries.current.monthlyIncome, 1000000);
    expect(summaries.current.todayTransactionCount, 1);

    await transactions.update(transaction.copyWith(amount: 1200000));
    expect(await summaries.moveNext(), isTrue);
    expect(summaries.current.balance, 1200000);
    expect(summaries.current.monthlyIncome, 1200000);
  });

  test(
    'summary calculates balance, current month totals, and today count',
    () async {
      await transactions.create(
        type: TransactionType.income,
        categoryId: incomeCategory.id,
        amount: 1000000,
        transactionDate: DateTime(2026, 8, 29),
      );
      final currentExpense = await transactions.create(
        type: TransactionType.expense,
        categoryId: expenseCategory.id,
        amount: 200000,
        transactionDate: DateTime(2026, 8, 29),
      );
      final oldExpense = await transactions.create(
        type: TransactionType.expense,
        categoryId: expenseCategory.id,
        amount: 100000,
        transactionDate: DateTime(2026, 7, 31),
      );

      var summary = await dashboard.watchSummary(DateTime(2026, 8, 29)).first;
      expect(summary.balance, 700000);
      expect(summary.monthlyIncome, 1000000);
      expect(summary.monthlyExpense, 200000);
      expect(summary.todayTransactionCount, 2);

      await transactions.update(currentExpense.copyWith(amount: 300000));
      await transactions.softDelete(oldExpense.id);
      summary = await dashboard.watchSummary(DateTime(2026, 8, 29)).first;
      expect(summary.balance, 700000);
      expect(summary.monthlyExpense, 300000);
    },
  );

  test('recent transaction query respects its limit', () async {
    for (var day = 1; day <= 7; day++) {
      await transactions.create(
        type: TransactionType.expense,
        categoryId: expenseCategory.id,
        amount: day,
        transactionDate: DateTime(2026, 8, day),
      );
    }

    final recent = await transactions
        .watchHistory(const TransactionHistoryQuery(limit: 5))
        .first;

    expect(recent, hasLength(5));
    expect(recent.first.transaction.transactionDate, DateTime(2026, 8, 7));
    expect(recent.last.transaction.transactionDate, DateTime(2026, 8, 3));
  });
}
