import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:finote/app/router.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/reports/data/report_repository.dart';
import 'package:finote/features/reports/presentation/account_balance_chart.dart';
import 'package:finote/features/reports/presentation/analytics_chart_page.dart';
import 'package:finote/features/reports/presentation/expense_category_chart.dart';
import 'package:finote/features/reports/presentation/financial_trend_chart.dart';
import 'package:finote/features/reports/presentation/report_period.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transfers/data/transfer_repository.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test(
    'route range round-trips and invalid input falls back to current month',
    () {
      final range = ReportRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      );
      final location = AnalyticsChartPage.locationFor(range);
      expect(AnalyticsChartPage.rangeFromUri(Uri.parse(location)), range);
      expect(
        AnalyticsChartPage.rangeFromUri(
          Uri.parse('/reports/analytics?start=invalid&end=2200-01-01'),
          now: DateTime(2026, 8, 15),
        ),
        resolveReportRange(ReportPeriod.month, now: DateTime(2026, 8, 15)),
      );
    },
  );

  testWidgets(
    'Reports opens Analytics with period handoff and preserves Back state',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final categories = CategoryRepository(database);
      final income = await categories.create(
        name: 'Gaji',
        type: TransactionType.income,
      );
      final expense = await categories.create(
        name: 'Makan',
        type: TransactionType.expense,
      );
      final now = DateTime.now();
      final transactions = TransactionRepository(database);
      await transactions.create(
        type: TransactionType.income,
        categoryId: income.id,
        amount: 8500000,
        transactionDate: now,
      );
      await transactions.create(
        type: TransactionType.expense,
        categoryId: expense.id,
        amount: 4350000,
        transactionDate: now,
      );
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      final router = container.read(routerProvider)..go('/reports');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tahun ini'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('open-analytics')),
        300,
        scrollable: find.byType(Scrollable).last,
      );

      final preview = _chartTotals(
        tester.widget<BarChart>(find.byType(BarChart)),
      );
      await tester.tap(find.byKey(const Key('open-analytics')));
      await tester.pumpAndSettle();

      expect(find.text('Analisis Grafik'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Tahun ini'))
            .selected,
        isTrue,
      );

      final analytics = _chartTotals(
        tester.widget<BarChart>(find.byType(BarChart)),
      );
      expect(analytics, preview);
      expect(analytics, (8500000.0, 4350000.0));
      expect(find.byType(LineChart), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Analisis Grafik'), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Tahun ini'))
            .selected,
        isTrue,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
      await database.close();
    },
  );

  testWidgets(
    'direct route defaults safely and local period control remains usable',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      final router = container.read(routerProvider)..go('/reports/analytics');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Analisis Grafik'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Bulan ini'))
            .selected,
        isTrue,
      );
      expect(
        find.text('Belum ada transaksi pada periode ini.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Hari ini'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Hari ini'))
            .selected,
        isTrue,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
      await database.close();
    },
  );

  testWidgets(
    'Analytics stays reactive and ignores transfer, initial balance, and archive',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final accounts = AccountRepository(database);
      final source = await accounts.create(
        name: 'BCA',
        type: AccountType.bank,
        initialBalance: 5000000,
      );
      final destination = await accounts.create(
        name: 'Tabungan',
        type: AccountType.savings,
      );
      final categories = CategoryRepository(database);
      final income = await categories.create(
        name: 'Gaji',
        type: TransactionType.income,
      );
      final expense = await categories.create(
        name: 'Makan',
        type: TransactionType.expense,
      );
      final now = DateTime.now();
      final range = resolveReportRange(ReportPeriod.month, now: now);
      final transactions = TransactionRepository(database);
      await transactions.create(
        type: TransactionType.income,
        categoryId: income.id,
        accountId: source.id,
        amount: 10000000,
        transactionDate: now,
      );
      final expenseTransaction = await transactions.create(
        type: TransactionType.expense,
        categoryId: expense.id,
        accountId: source.id,
        amount: 1000000,
        transactionDate: now,
      );
      final otherDay = now.day == 1
          ? DateTime(now.year, now.month, 2)
          : DateTime(now.year, now.month);
      await transactions.create(
        type: TransactionType.expense,
        categoryId: expense.id,
        accountId: source.id,
        amount: 300000,
        transactionDate: otherDay,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MaterialApp(home: AnalyticsChartPage(initialRange: range)),
        ),
      );
      await tester.pumpAndSettle();

      final report = await ReportRepository(database).watchReport(range).first;
      var totals = _chartTotals(tester.widget<BarChart>(find.byType(BarChart)));
      expect(totals, (
        report.totalIncome.toDouble(),
        report.totalExpense.toDouble(),
      ));
      var categoryChart = tester.widget<ExpenseCategoryChart>(
        find.byType(ExpenseCategoryChart),
      );
      expect(categoryChart.points.single.amount, report.totalExpense);
      var trendTotals = _trendTotals(
        tester.widget<LineChart>(find.byType(LineChart)),
      );
      expect(trendTotals, (
        report.totalIncome.toDouble(),
        report.totalExpense.toDouble(),
        report.netBalance.toDouble(),
      ));

      final addedExpense = await transactions.create(
        type: TransactionType.expense,
        categoryId: expense.id,
        accountId: source.id,
        amount: 250000,
        transactionDate: now,
      );
      await tester.pumpAndSettle();
      totals = _chartTotals(tester.widget<BarChart>(find.byType(BarChart)));
      expect(totals, (10000000.0, 1550000.0));
      categoryChart = tester.widget<ExpenseCategoryChart>(
        find.byType(ExpenseCategoryChart),
      );
      expect(categoryChart.points.single.amount, 1550000);
      trendTotals = _trendTotals(
        tester.widget<LineChart>(find.byType(LineChart)),
      );
      expect(trendTotals, (10000000.0, 1550000.0, 8450000.0));

      await transactions.update(addedExpense.copyWith(amount: 500000));
      await tester.pumpAndSettle();
      totals = _chartTotals(tester.widget<BarChart>(find.byType(BarChart)));
      expect(totals, (10000000.0, 1800000.0));
      expect(_trendTotals(tester.widget<LineChart>(find.byType(LineChart))), (
        10000000.0,
        1800000.0,
        8200000.0,
      ));

      await TransferRepository(database).create(
        fromAccountId: source.id,
        toAccountId: destination.id,
        amount: 2000000,
        transferDate: now,
      );
      await accounts.update(
        id: source.id,
        name: source.name,
        type: source.type,
        initialBalance: 9000000,
      );
      await accounts.archive(source.id);
      await tester.pumpAndSettle();
      totals = _chartTotals(tester.widget<BarChart>(find.byType(BarChart)));
      expect(totals, (10000000.0, 1800000.0));
      expect(_trendTotals(tester.widget<LineChart>(find.byType(LineChart))), (
        10000000.0,
        1800000.0,
        8200000.0,
      ));

      await transactions.softDelete(expenseTransaction.id);
      await tester.pumpAndSettle();
      totals = _chartTotals(tester.widget<BarChart>(find.byType(BarChart)));
      expect(totals, (10000000.0, 800000.0));
      categoryChart = tester.widget<ExpenseCategoryChart>(
        find.byType(ExpenseCategoryChart),
      );
      expect(categoryChart.points.single.amount, 800000);
      expect(_trendTotals(tester.widget<LineChart>(find.byType(LineChart))), (
        10000000.0,
        800000.0,
        9200000.0,
      ));

      await tester.tap(find.text('Hari ini'));
      await tester.pumpAndSettle();
      totals = _chartTotals(tester.widget<BarChart>(find.byType(BarChart)));
      categoryChart = tester.widget<ExpenseCategoryChart>(
        find.byType(ExpenseCategoryChart),
      );
      expect(totals, (10000000.0, 500000.0));
      expect(categoryChart.points.single.amount, 500000);
      expect(_trendTotals(tester.widget<LineChart>(find.byType(LineChart))), (
        10000000.0,
        500000.0,
        9500000.0,
      ));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('Analytics fits small dark screen with scaled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final category = await CategoryRepository(database)
        .create(name: 'Makan', type: TransactionType.expense);
    await TransactionRepository(database).create(
      type: TransactionType.expense,
      categoryId: category.id,
      amount: 9000000000000,
      transactionDate: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: AnalyticsChartPage(
              initialRange: resolveReportRange(ReportPeriod.month),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Analisis Grafik'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(ExpenseCategoryChart), findsOneWidget);
    expect(find.byType(FinancialTrendChart), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byType(AccountBalanceChart), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(640, 320);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'Account chart stays current and follows shared account lifecycle balances',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final accounts = AccountRepository(database);
      final accountA = await accounts.create(
        name: 'BCA Utama',
        type: AccountType.bank,
        initialBalance: 5000000,
      );
      final accountB = await accounts.create(
        name: 'BCA Tabungan',
        type: AccountType.savings,
        initialBalance: 500000,
      );
      final accountC = await accounts.create(
        name: 'Tunai',
        type: AccountType.cash,
      );
      final categories = CategoryRepository(database);
      final incomeCategory = await categories.create(
        name: 'Gaji',
        type: TransactionType.income,
      );
      final expenseCategory = await categories.create(
        name: 'Belanja',
        type: TransactionType.expense,
      );
      final transactions = TransactionRepository(database);
      final income = await transactions.create(
        type: TransactionType.income,
        categoryId: incomeCategory.id,
        accountId: accountA.id,
        amount: 10000000,
        transactionDate: DateTime(2026, 8, 1),
      );
      var expenseA = await transactions.create(
        type: TransactionType.expense,
        categoryId: expenseCategory.id,
        accountId: accountA.id,
        amount: 1000000,
        transactionDate: DateTime(2026, 8, 1),
      );
      await transactions.create(
        type: TransactionType.expense,
        categoryId: expenseCategory.id,
        accountId: accountB.id,
        amount: 50000,
        transactionDate: DateTime(2026, 8, 2),
      );
      final transfers = TransferRepository(database);
      var transfer = await transfers.create(
        fromAccountId: accountA.id,
        toAccountId: accountB.id,
        amount: 2000000,
        transferDate: DateTime(2026, 8, 2),
      );
      final range = ReportRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MaterialApp(home: AnalyticsChartPage(initialRange: range)),
        ),
      );
      await tester.pumpAndSettle();

      var chart = tester.widget<AccountBalanceChart>(
        find.byType(AccountBalanceChart),
      );
      expect(_balance(chart, accountA.id), 12000000);
      expect(_balance(chart, accountB.id), 2450000);
      expect(chart.totalAssets, 14450000);
      final report = await ReportRepository(database).watchReport(range).first;
      expect(
        (report.totalIncome, report.totalExpense, report.netBalance),
        (10000000, 1050000, 8950000),
      );

      await tester.tap(find.text('Tahun ini'));
      await tester.pumpAndSettle();
      chart = tester.widget<AccountBalanceChart>(
        find.byType(AccountBalanceChart),
      );
      expect(
        (_balance(chart, accountA.id), chart.totalAssets),
        (12000000, 14450000),
      );

      await accounts.update(
        id: accountA.id,
        name: 'BCA Utama Baru',
        type: AccountType.eWallet,
        initialBalance: 5500000,
      );
      await tester.pumpAndSettle();
      chart = tester.widget<AccountBalanceChart>(
        find.byType(AccountBalanceChart),
      );
      expect(
        (_balance(chart, accountA.id), chart.totalAssets),
        (12500000, 14950000),
      );
      expect(
        chart.points
            .singleWhere((point) => point.accountId == accountA.id)
            .accountType,
        AccountType.eWallet,
      );

      expenseA = expenseA.copyWith(accountId: Value(accountB.id));
      await transactions.update(expenseA);
      await tester.pumpAndSettle();
      chart = tester.widget<AccountBalanceChart>(
        find.byType(AccountBalanceChart),
      );
      expect(
        (_balance(chart, accountA.id), _balance(chart, accountB.id)),
        (13500000, 1450000),
      );
      expect(chart.totalAssets, 14950000);

      transfer = transfer.copyWith(toAccountId: accountC.id);
      await transfers.update(transfer);
      await tester.pumpAndSettle();
      chart = tester.widget<AccountBalanceChart>(
        find.byType(AccountBalanceChart),
      );
      expect(
        (_balance(chart, accountB.id), _balance(chart, accountC.id)),
        (-550000, 2000000),
      );
      expect(chart.totalAssets, 14950000);

      await accounts.archive(accountB.id);
      await tester.pumpAndSettle();
      chart = tester.widget<AccountBalanceChart>(
        find.byType(AccountBalanceChart),
      );
      expect(
        chart.points.any((point) => point.accountId == accountB.id),
        isFalse,
      );
      expect((chart.archivedCount, chart.totalAssets), (1, 14950000));
      await accounts.reactivate(accountB.id);
      await tester.pumpAndSettle();
      chart = tester.widget<AccountBalanceChart>(
        find.byType(AccountBalanceChart),
      );
      expect(_balance(chart, accountB.id), -550000);

      final unused = await accounts.create(
        name: 'Akun Sementara',
        type: AccountType.cash,
        initialBalance: 500000,
      );
      await tester.pumpAndSettle();
      chart = tester.widget<AccountBalanceChart>(
        find.byType(AccountBalanceChart),
      );
      expect(
        (_balance(chart, unused.id), chart.totalAssets),
        (500000, 15450000),
      );
      expect(await accounts.deleteUnusedAccount(unused.id), isTrue);
      await tester.pumpAndSettle();
      chart = tester.widget<AccountBalanceChart>(
        find.byType(AccountBalanceChart),
      );
      expect(
        chart.points.any((point) => point.accountId == unused.id),
        isFalse,
      );
      expect(chart.totalAssets, 14950000);

      await transactions.softDelete(income.id);
      await transfers.softDelete(transfer.id);
      await tester.pumpAndSettle();
      chart = tester.widget<AccountBalanceChart>(
        find.byType(AccountBalanceChart),
      );
      expect(
        (_balance(chart, accountA.id), _balance(chart, accountC.id)),
        (5500000, 0),
      );
      expect(chart.totalAssets, 4950000);
      await transactions.softDelete(expenseA.id);
      await tester.pumpAndSettle();
      chart = tester.widget<AccountBalanceChart>(
        find.byType(AccountBalanceChart),
      );
      expect(
        (_balance(chart, accountB.id), chart.totalAssets),
        (450000, 5950000),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}

int _balance(AccountBalanceChart chart, int accountId) =>
    chart.points.singleWhere((point) => point.accountId == accountId).balance;

(double, double, double) _trendTotals(LineChart chart) {
  final series = chart.data.lineBarsData;
  return (
    series[0].spots.fold<double>(0, (sum, spot) => sum + spot.y),
    series[1].spots.fold<double>(0, (sum, spot) => sum + spot.y),
    series[2].spots.fold<double>(0, (sum, spot) => sum + spot.y),
  );
}

(double, double) _chartTotals(BarChart chart) {
  var income = 0.0;
  var expense = 0.0;
  for (final group in chart.data.barGroups) {
    income += group.barRods.first.toY;
    expense += group.barRods.last.toY;
  }
  return (income, expense);
}
