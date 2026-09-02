import 'dart:async';

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
