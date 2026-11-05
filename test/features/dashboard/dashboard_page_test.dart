import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/core/finance/net_worth.dart';
import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/core/theme/finote_colors.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/dashboard/presentation/dashboard_page.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('dashboard shows zero summary and transaction empty state', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(theme: AppTheme.light, home: const DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kekayaan Bersih'), findsOneWidget);
    final hero = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.text('Kekayaan Bersih'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = hero.decoration as BoxDecoration;
    expect(decoration.gradient, FinoteColors.light.heroGradient);
    expect(decoration.boxShadow, FinoteColors.light.heroShadow);
    expect(find.text('Kas & Dompet'), findsAtLeastNWidgets(1));
    expect(find.text('Pengeluaran 7 hari'), findsOneWidget);
    expect(find.text('Belum ada pengeluaran 7 hari terakhir.'), findsOneWidget);
    expect(find.text('Pemasukan bulan ini'), findsOneWidget);
    expect(find.text('Pengeluaran bulan ini'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Belum ada transaksi.'), 120);
    expect(find.text('Belum ada transaksi.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('hide balance masks hero amounts and persists', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    Widget app() => ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        netWorthProvider.overrideWithValue(
          const AsyncData(
            NetWorthSnapshot(
              cashValue: 12000000,
              portfolioKnownValue: 3000000,
              totalKnownValue: 15000000,
              completeness: NetWorthCompleteness.complete,
              unvaluedAssetCount: 0,
              integrityIssueCount: 0,
            ),
          ),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const DashboardPage()),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Rp15.000.000'), findsOneWidget);

    await tester.tap(find.byTooltip('Sembunyikan saldo'));
    await tester.pumpAndSettle();
    expect(find.text('Rp15.000.000'), findsNothing);
    expect(find.text('Rp12.000.000'), findsNothing);
    expect(find.text('Saldo disembunyikan'), findsOneWidget);

    // A fresh app session keeps the choice.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Rp15.000.000'), findsNothing);
    expect(find.byTooltip('Tampilkan saldo'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('7-day card totals only the last 7 days of expenses', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final food = await CategoryRepository(database)
        .create(name: 'Makanan & Minuman', type: TransactionType.expense);
    final transactions = TransactionRepository(database);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final (daysAgo, amount) in [(0, 50000), (6, 25000), (7, 999000)]) {
      await transactions.create(
        type: TransactionType.expense,
        categoryId: food.id,
        amount: amount,
        transactionDate: DateTime(today.year, today.month, today.day - daysAgo),
      );
    }
    final deleted = await transactions.create(
      type: TransactionType.expense,
      categoryId: food.id,
      amount: 400000,
      transactionDate: today,
    );
    await transactions.softDelete(deleted.id);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(theme: AppTheme.light, home: const DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    // Day 7-ago and the soft-deleted row are excluded.
    expect(find.text('Rp75.000'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('dashboard fits $width with large text and partial value', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(database),
              netWorthProvider.overrideWithValue(
                const AsyncData(
                  NetWorthSnapshot(
                    cashValue: 12000000,
                    portfolioKnownValue: null,
                    totalKnownValue: 12000000,
                    completeness: NetWorthCompleteness.partial,
                    unvaluedAssetCount: 2,
                    integrityIssueCount: 0,
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const DashboardPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kekayaan Bersih'), findsOneWidget);
        expect(find.text('Rp12.000.000'), findsWidgets);
        expect(find.text('Belum tersedia'), findsOneWidget);
        expect(
          find.textContaining('2 aset belum memiliki harga'),
          findsOneWidget,
        );
        final layoutError = tester.takeException();
        if (layoutError != null) {
          fail(
            layoutError is FlutterError
                ? layoutError.toStringDeep()
                : layoutError.toString(),
          );
        }
        await tester.drag(find.byType(ListView).first, const Offset(0, -460));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      });
    }
  }

  testWidgets('recent income and expense keep signed amounts at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final categories = CategoryRepository(database);
    final income = await categories.create(
      name: 'Gaji',
      type: TransactionType.income,
    );
    final expense = await categories.create(
      name: 'Makan',
      type: TransactionType.expense,
    );
    final transactions = TransactionRepository(database);
    await transactions.create(
      type: TransactionType.income,
      categoryId: income.id,
      amount: 15000000,
      transactionDate: DateTime.now(),
    );
    await transactions.create(
      type: TransactionType.expense,
      categoryId: expense.id,
      amount: 25000,
      transactionDate: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const DashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Makan'), 150);
    expect(find.text('-Rp25.000'), findsOneWidget);
    expect(find.text('+Rp15.000.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('large rupiah value remains within a narrow hero card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          netWorthProvider.overrideWithValue(
            const AsyncData(
              NetWorthSnapshot(
                cashValue: 9000000000000000,
                portfolioKnownValue: 0,
                totalKnownValue: 9000000000000000,
                completeness: NetWorthCompleteness.complete,
                unvaluedAssetCount: 0,
                integrityIssueCount: 0,
              ),
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rp9.000.000.000.000.000'), findsWidgets);
    final hero = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.text('Kekayaan Bersih'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (hero.decoration as BoxDecoration).gradient,
      FinoteColors.dark.heroGradient,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
