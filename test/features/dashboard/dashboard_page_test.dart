import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/core/finance/net_worth.dart';
import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/dashboard/presentation/dashboard_page.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard shows zero summary and transaction empty state', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kekayaan Bersih'), findsOneWidget);
    expect(find.text('Kas & Dompet'), findsAtLeastNWidgets(1));
    expect(find.text('Pemasukan bulan ini'), findsOneWidget);
    expect(find.text('Pengeluaran bulan ini'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Belum ada transaksi.'), 120);
    expect(find.text('Belum ada transaksi.'), findsOneWidget);

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
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
