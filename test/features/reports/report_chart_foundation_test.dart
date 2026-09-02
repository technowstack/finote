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

  test('ReportFilter uses value equality for provider family keys', () {
    final range = ReportRange(
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
    );
    final first = ReportFilter(range: range, accountId: 2, categoryId: 3);
    final equal = ReportFilter(
      range: ReportRange(
        start: DateTime(2026, 9, 1, 14),
        end: DateTime(2026, 9, 30, 23),
      ),
      accountId: 2,
      categoryId: 3,
    );

    expect(first, equal);
    expect(first.hashCode, equal.hashCode);
    expect(first, isNot(ReportFilter(range: range, accountId: 4)));
    expect(
      () => ReportFilter(
        range: ReportRange(
          start: DateTime(2026, 9, 2),
          end: DateTime(2026, 9, 1),
        ),
      ),
      throwsArgumentError,
    );
  });

  test('account and category filters reconcile without transfer or initial balance', () async {
    final accountRepository = AccountRepository(database);
    final bca = await accountRepository.create(
      name: 'BCA',
      type: AccountType.bank,
      initialBalance: 5000000,
    );
    final cash = await accountRepository.create(
      name: 'Cash',
      type: AccountType.cash,
      initialBalance: 500000,
    );
    for (final entry in [
      (bca.id, salary.id, TransactionType.income, 5000000),
      (bca.id, food.id, TransactionType.expense, 1000000),
      (bca.id, transport.id, TransactionType.expense, 500000),
      (cash.id, salary.id, TransactionType.income, 1000000),
      (cash.id, food.id, TransactionType.expense, 300000),
    ]) {
      await transactions.create(
        accountId: entry.$1,
        categoryId: entry.$2,
        type: entry.$3,
        amount: entry.$4,
        transactionDate: DateTime(2026, 9, 12),
      );
    }
    await TransferRepository(database).create(
      fromAccountId: bca.id,
      toAccountId: cash.id,
      amount: 2000000,
      transferDate: DateTime(2026, 9, 12),
    );
    final range = ReportRange(
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
    );

    Future<(int, int, int)> totals({int? accountId, int? categoryId}) async {
      final report = await reports
          .watchReport(range, accountId: accountId, categoryId: categoryId)
          .first;
      final trend = await reports
          .watchFinancialTrend(
            range,
            accountId: accountId,
            categoryId: categoryId,
          )
          .first;
      final categories = await reports
          .watchExpenseCategories(
            range,
            accountId: accountId,
            categoryId: categoryId,
          )
          .first;
      expect(
        trend.fold<int>(0, (sum, point) => sum + point.income),
        report.totalIncome,
      );
      expect(
        trend.fold<int>(0, (sum, point) => sum + point.expense),
        report.totalExpense,
      );
      expect(
        categories.fold<int>(0, (sum, point) => sum + point.amount),
        report.totalExpense,
      );
      return (report.totalIncome, report.totalExpense, report.netBalance);
    }

    expect(await totals(), (6000000, 1800000, 4200000));
    expect(await totals(accountId: bca.id), (5000000, 1500000, 3500000));
    expect(await totals(categoryId: food.id), (0, 1300000, -1300000));
    expect(await totals(accountId: bca.id, categoryId: food.id), (
      0,
      1000000,
      -1000000,
    ));
    expect(await totals(accountId: 999999), (0, 0, 0));
    final balances = await accountRepository.watchSummaries().first;
    expect(
      balances
          .where(
            (item) => item.account.id == bca.id || item.account.id == cash.id,
          )
          .fold<int>(0, (sum, item) => sum + item.balance),
      9700000,
    );
  });

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
    expect(trend.fold<int>(0, (sum, point) => sum + point.net), 8950000);
  });

  test('financial trend matches deterministic daily Net fixture', () async {
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
    for (final entry in [
      (DateTime(2026, 8, 1), TransactionType.income, salary.id, 2000000),
      (DateTime(2026, 8, 1), TransactionType.expense, food.id, 500000),
      (DateTime(2026, 8, 2), TransactionType.expense, food.id, 1000000),
      (DateTime(2026, 8, 3), TransactionType.income, salary.id, 3000000),
      (DateTime(2026, 8, 3), TransactionType.expense, food.id, 500000),
    ]) {
      await transactions.create(
        type: entry.$2,
        categoryId: entry.$3,
        accountId: bca.id,
        amount: entry.$4,
        transactionDate: entry.$1,
      );
    }
    final transfers = TransferRepository(database);
    var transfer = await transfers.create(
      fromAccountId: bca.id,
      toAccountId: savings.id,
      amount: 2000000,
      transferDate: DateTime(2026, 8, 2),
    );
    final range = ReportRange(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 3),
    );

    Future<List<(int, int, int)>> values() async =>
        (await reports.watchFinancialTrend(range).first)
            .map((point) => (point.income, point.expense, point.net))
            .toList();

    const expected = [
      (2000000, 500000, 1500000),
      (0, 1000000, -1000000),
      (3000000, 500000, 2500000),
    ];
    expect(await values(), expected);
    final report = await reports.watchReport(range).first;
    expect(
      (report.totalIncome, report.totalExpense, report.netBalance),
      (5000000, 2000000, 3000000),
    );

    transfer = transfer.copyWith(
      amount: 4000000,
      transferDate: DateTime(2026, 8, 3),
    );
    await transfers.update(transfer);
    expect(await values(), expected);
    await transfers.softDelete(transfer.id);
    expect(await values(), expected);
    await accounts.update(
      id: bca.id,
      name: bca.name,
      type: bca.type,
      initialBalance: 9000000,
    );
    await accounts.archive(bca.id);
    expect(await values(), expected);
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

      final all = await reports
          .watchFinancialTrend(
            ReportRange(start: DateTime(2000), end: DateTime(2100, 12, 31)),
          )
          .first;
      expect(all.map((point) => point.period), [
        DateTime(2025, 12),
        DateTime(2026),
      ]);
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

      final accounts = AccountRepository(database);
      final alternateAccount = await accounts.create(
        name: 'Tunai',
        type: AccountType.cash,
      );
      final bonus = await CategoryRepository(database)
          .create(name: 'Bonus', type: TransactionType.income);
      var transaction = await transactions.create(
        type: TransactionType.expense,
        categoryId: food.id,
        amount: 500000,
        transactionDate: DateTime(2026, 8, 1),
      );
      expect(await iterator.moveNext(), isTrue);
      expect(
        (
          iterator.current.first.income,
          iterator.current.first.expense,
          iterator.current.first.net,
        ),
        (0, 500000, -500000),
      );

      transaction = transaction.copyWith(
        type: TransactionType.income,
        categoryId: salary.id,
      );
      await transactions.update(transaction);
      expect(await iterator.moveNext(), isTrue);
      expect(
        (
          iterator.current.first.income,
          iterator.current.first.expense,
          iterator.current.first.net,
        ),
        (500000, 0, 500000),
      );

      transaction = transaction.copyWith(amount: 800000);
      await transactions.update(transaction);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.first.net, 800000);

      transaction = transaction.copyWith(
        categoryId: bonus.id,
        accountId: Value(alternateAccount.id),
      );
      await transactions.update(transaction);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.first.net, 800000);

      transaction = transaction.copyWith(transactionDate: DateTime(2026, 8, 3));
      await transactions.update(transaction);
      expect(await iterator.moveNext(), isTrue);
      expect(
        (iterator.current.first.net, iterator.current.last.net),
        (0, 800000),
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
        expect(
          trend.fold<int>(0, (sum, point) => sum + point.net),
          report.netBalance,
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

      final trend = await container.read(
        financialTrendProvider(ReportFilter(range: range)).future,
      );
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
