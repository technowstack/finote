import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/reports/data/report_chart_providers.dart';
import 'package:finote/features/reports/data/report_repository.dart';
import 'package:finote/features/reports/domain/report_chart_data.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transfers/data/transfer_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ReportRepository reports;
  late TransactionRepository transactions;
  late CategoryRecord salary;
  late CategoryRecord food;
  late CategoryRecord transport;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    reports = ReportRepository(database);
    transactions = TransactionRepository(database);
    final categories = CategoryRepository(database);
    salary = await categories.create(
      name: 'Gaji',
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
  });

  tearDown(() => database.close());

  test('chart totals reconcile and exclude transfers, initial balance, and deletes', () async {
    final accounts = AccountRepository(database);
    final bca = await accounts.create(
      name: 'BCA',
      type: AccountType.bank,
      initialBalance: 5000000,
    );
    final savings = await accounts.create(
      name: 'Tabungan',
      type: AccountType.savings,
    );
    await transactions.create(
      type: TransactionType.income,
      categoryId: salary.id,
      accountId: bca.id,
      amount: 10000000,
      transactionDate: DateTime(2026, 8, 1),
    );
    await transactions.create(
      type: TransactionType.expense,
      categoryId: food.id,
      accountId: bca.id,
      amount: 500000,
      transactionDate: DateTime(2026, 8, 1),
    );
    await transactions.create(
      type: TransactionType.expense,
      categoryId: food.id,
      accountId: bca.id,
      amount: 250000,
      transactionDate: DateTime(2026, 8, 3),
    );
    await transactions.create(
      type: TransactionType.expense,
      categoryId: transport.id,
      accountId: bca.id,
      amount: 300000,
      transactionDate: DateTime(2026, 8, 3),
    );
    final deleted = await transactions.create(
      type: TransactionType.income,
      categoryId: salary.id,
      accountId: bca.id,
      amount: 1000000,
      transactionDate: DateTime(2026, 8, 2),
    );
    await transactions.softDelete(deleted.id);
    await TransferRepository(database).create(
      fromAccountId: bca.id,
      toAccountId: savings.id,
      amount: 2000000,
      transferDate: DateTime(2026, 8, 2),
    );
    final range = ReportRange(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 3),
    );

    final report = await reports.watchReport(range).first;
    final trend = await reports.watchFinancialTrend(range).first;
    final categories = await reports.watchExpenseCategories(range).first;
    final chartIncome = trend.fold<int>(0, (sum, point) => sum + point.income);
    final chartExpense = trend.fold<int>(
      0,
      (sum, point) => sum + point.expense,
    );

    expect(trend, hasLength(3));
    expect((trend[1].income, trend[1].expense), (0, 0));
    expect((chartIncome, chartExpense), (10000000, 1050000));
    expect(
      (chartIncome, chartExpense),
      (report.totalIncome, report.totalExpense),
    );
    expect(categories.map((point) => (point.categoryName, point.amount)), [
      ('Makanan', 750000),
      ('Transportasi', 300000),
    ]);
  });

  test(
    'adaptive buckets stay complete across month and year boundaries',
    () async {
      await transactions.create(
        type: TransactionType.income,
        categoryId: salary.id,
        amount: 100,
        transactionDate: DateTime(2025, 12, 31),
      );
      await transactions.create(
        type: TransactionType.expense,
        categoryId: food.id,
        amount: 50,
        transactionDate: DateTime(2026, 1, 2),
      );

      final shortRange = ReportRange(
        start: DateTime(2025, 12, 30),
        end: DateTime(2026, 1, 2),
      );
      expect(chartGranularityFor(shortRange), ChartGranularity.day);
      final daily = await reports.watchFinancialTrend(shortRange).first;
      expect(daily.map((point) => point.period), [
        DateTime(2025, 12, 30),
        DateTime(2025, 12, 31),
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 2),
      ]);

      final mediumRange = ReportRange(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 4, 30),
      );
      expect(chartGranularityFor(mediumRange), ChartGranularity.week);
      expect(
        (await reports.watchFinancialTrend(mediumRange).first)
            .first
            .period
            .weekday,
        DateTime.monday,
      );

      final yearRange = ReportRange(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 12, 31),
      );
      expect(chartGranularityFor(yearRange), ChartGranularity.month);
      final monthly = await reports.watchFinancialTrend(yearRange).first;
      expect(monthly, hasLength(12));
      expect(monthly.first.period, DateTime(2026));
      expect(monthly.last.period, DateTime(2026, 12));
    },
  );

  test('expense categories aggregate, sort, exclude non-expense sources, and reconcile', () async {
    final accounts = AccountRepository(database);
    final bca = await accounts.create(
      name: 'BCA',
      type: AccountType.bank,
      initialBalance: 5000000,
    );
    final savings = await accounts.create(
      name: 'Tabungan',
      type: AccountType.savings,
    );
    final categoryRepository = CategoryRepository(database);
    final bills = await categoryRepository.create(
      name: 'Tagihan',
      type: TransactionType.expense,
    );
    final entertainment = await categoryRepository.create(
      name: 'Hiburan',
      type: TransactionType.expense,
    );
    final date = DateTime(2026, 8, 1);
    for (final entry in [
      (food.id, TransactionType.expense, 500000),
      (food.id, TransactionType.expense, 250000),
      (transport.id, TransactionType.expense, 300000),
      (bills.id, TransactionType.expense, 1000000),
      (entertainment.id, TransactionType.expense, 150000),
      (salary.id, TransactionType.income, 10000000),
    ]) {
      await transactions.create(
        type: entry.$2,
        categoryId: entry.$1,
        accountId: bca.id,
        amount: entry.$3,
        transactionDate: date,
      );
    }
    final deleted = await transactions.create(
      type: TransactionType.expense,
      categoryId: food.id,
      accountId: bca.id,
      amount: 999999,
      transactionDate: date,
    );
    await transactions.softDelete(deleted.id);
    await TransferRepository(database).create(
      fromAccountId: bca.id,
      toAccountId: savings.id,
      amount: 2000000,
      transferDate: date,
    );
    final range = ReportRange(start: date, end: date);

    final report = await reports.watchReport(range).first;
    final trend = await reports.watchFinancialTrend(range).first;
    final categories = await reports.watchExpenseCategories(range).first;

    expect(categories.map((point) => (point.categoryName, point.amount)), [
      ('Tagihan', 1000000),
      ('Makanan', 750000),
      ('Transportasi', 300000),
      ('Hiburan', 150000),
    ]);
    final categoryExpense = categories.fold<int>(
      0,
      (sum, point) => sum + point.amount,
    );
    expect(categoryExpense, 2200000);
    expect(categoryExpense, report.totalExpense);
    expect(categoryExpense, trend.single.expense);
    expect(categories.any((point) => point.categoryName == 'Gaji'), isFalse);
  });

  test(
    'expense category stream reacts to category, type, date, and delete edits',
    () async {
      final range = ReportRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      );
      final iterator = StreamIterator(reports.watchExpenseCategories(range));
      addTearDown(iterator.cancel);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, isEmpty);

      var transaction = await transactions.create(
        type: TransactionType.expense,
        categoryId: food.id,
        amount: 500000,
        transactionDate: DateTime(2026, 8, 1),
      );
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.single.amount, 500000);

      transaction = transaction.copyWith(
        categoryId: transport.id,
        amount: 600000,
      );
      await transactions.update(transaction);
      expect(await iterator.moveNext(), isTrue);
      expect(
        (iterator.current.single.categoryName, iterator.current.single.amount),
        ('Transportasi', 600000),
      );

      transaction = transaction.copyWith(
        type: TransactionType.income,
        categoryId: salary.id,
        amount: 600000,
      );
      await transactions.update(transaction);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, isEmpty);

      transaction = transaction.copyWith(
        type: TransactionType.expense,
        categoryId: food.id,
        amount: 700000,
      );
      await transactions.update(transaction);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.single.amount, 700000);

      transaction = transaction.copyWith(transactionDate: DateTime(2026, 9, 1));
      await transactions.update(transaction);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, isEmpty);

      transaction = transaction.copyWith(transactionDate: DateTime(2026, 8, 2));
      await transactions.update(transaction);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.single.amount, 700000);

      await transactions.softDelete(transaction.id);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, isEmpty);
    },
  );

  test(
    'expense categories retain archived and missing category labels safely',
    () async {
      final category = await CategoryRepository(database)
          .create(name: 'Kategori Lama', type: TransactionType.expense);
      await transactions.create(
        type: TransactionType.expense,
        categoryId: category.id,
        amount: 100000,
        transactionDate: DateTime(2026, 8, 1),
      );
      await (database.update(database.categories)
            ..where((row) => row.id.equals(category.id)))
          .write(CategoriesCompanion(deletedAt: Value(DateTime.now().toUtc())));

      await database.customStatement('PRAGMA foreign_keys = OFF');
      await database.customStatement(
        '''
INSERT INTO transactions (
  uuid, type, category_id, amount, title, transaction_date, source,
  created_at, updated_at
) VALUES (?, 'expense', 999999, 200000, '', '2026-08-01',
          'legacy_import', 0, 0)
''',
        ['missing-category-fixture'],
      );
      await database.customStatement('PRAGMA foreign_keys = ON');
      final range = ReportRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      );

      final report = await reports.watchReport(range).first;
      final points = await reports.watchExpenseCategories(range).first;
      expect(points.map((point) => (point.categoryName, point.amount)), [
        ('Kategori tidak tersedia', 200000),
        ('Kategori Lama', 100000),
      ]);
      expect(
        points.fold<int>(0, (sum, point) => sum + point.amount),
        report.totalExpense,
      );
    },
  );

  test(
    'trend stream reacts to amount, type, date, and soft delete changes',
    () async {
      final range = ReportRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 3),
      );
      final iterator = StreamIterator(reports.watchFinancialTrend(range));
      addTearDown(iterator.cancel);
      expect(await iterator.moveNext(), isTrue);

      final transaction = await transactions.create(
        type: TransactionType.expense,
        categoryId: food.id,
        amount: 100,
        transactionDate: DateTime(2026, 8, 1),
      );
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.first.expense, 100);

      await transactions.update(
        transaction.copyWith(
          type: TransactionType.income,
          categoryId: salary.id,
          amount: 250,
          transactionDate: DateTime(2026, 8, 3),
        ),
      );
      expect(await iterator.moveNext(), isTrue);
      expect(
        (iterator.current.first.expense, iterator.current.last.income),
        (0, 250),
      );

      await transactions.softDelete(transaction.id);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.every((point) => point.income == 0), isTrue);
    },
  );

  test(
    'trend totals reconcile for today, week, month, year, and custom ranges',
    () async {
      for (final entry in [
        (DateTime(2026, 1, 1), TransactionType.income, 100),
        (DateTime(2026, 1, 2), TransactionType.expense, 30),
        (DateTime(2026, 2, 1), TransactionType.expense, 20),
        (DateTime(2026, 8, 1), TransactionType.income, 200),
      ]) {
        await transactions.create(
          type: entry.$2,
          categoryId: entry.$2 == TransactionType.income ? salary.id : food.id,
          amount: entry.$3,
          transactionDate: entry.$1,
        );
      }

      final ranges = [
        ReportRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 1)),
        ReportRange(start: DateTime(2025, 12, 29), end: DateTime(2026, 1, 4)),
        ReportRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 31)),
        ReportRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 12, 31)),
        ReportRange(start: DateTime(2026, 1, 2), end: DateTime(2026, 8, 1)),
      ];

      for (final range in ranges) {
        final report = await reports.watchReport(range).first;
        final trend = await reports.watchFinancialTrend(range).first;
        final categories = await reports.watchExpenseCategories(range).first;
        expect(
          (
            trend.fold<int>(0, (sum, point) => sum + point.income),
            trend.fold<int>(0, (sum, point) => sum + point.expense),
          ),
          (report.totalIncome, report.totalExpense),
        );
        expect(
          categories.fold<int>(0, (sum, point) => sum + point.amount),
          report.totalExpense,
        );
      }
    },
  );

  test(
    'chart providers expose exact integer data and shared account balances',
    () async {
      final accounts = AccountRepository(database);
      final bca = await accounts.create(
        name: 'BCA',
        type: AccountType.bank,
        initialBalance: 9000000000000,
      );
      final range = ReportRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      );
      await transactions.create(
        type: TransactionType.income,
        categoryId: salary.id,
        accountId: bca.id,
        amount: 8000000000000,
        transactionDate: DateTime(2026, 8, 1),
      );
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      final trend = await container.read(financialTrendProvider(range).future);
      final balances = await container.read(accountBalanceChartProvider.future);
      expect(
        trend.fold<int>(0, (sum, point) => sum + point.income),
        8000000000000,
      );
      expect(
        balances.singleWhere((point) => point.accountId == bca.id).balance,
        17000000000000,
      );
    },
  );
}
