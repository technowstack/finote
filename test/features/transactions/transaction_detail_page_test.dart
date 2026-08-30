import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transactions/presentation/monthly_transactions_page.dart';
import 'package:finote/features/transactions/presentation/transaction_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late AppDatabase database;
  late int emptyNoteTransactionId;

  setUpAll(() => initializeDateFormatting('id_ID'));

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    final category = await CategoryRepository(database)
        .create(name: 'Makanan', type: TransactionType.expense);
    await TransactionRepository(database).create(
      type: TransactionType.expense,
      categoryId: category.id,
      amount: 25000,
      title: 'Makan siang',
      note: 'Dengan teman',
      transactionDate: DateTime(2026, 8, 20),
    );
    emptyNoteTransactionId = (await TransactionRepository(database).create(
      type: TransactionType.expense,
      categoryId: category.id,
      amount: 15000,
      transactionDate: DateTime(2026, 8, 10),
    )).id;
    await TransactionRepository(database).create(
      type: TransactionType.income,
      categoryId: await _createIncomeCategory(database),
      amount: 1000000,
      transactionDate: DateTime(2026, 8, 1),
    );
    await TransactionRepository(database).create(
      type: TransactionType.expense,
      categoryId: category.id,
      amount: 10000,
      transactionDate: DateTime(2026, 7, 31),
    );
  });

  tearDown(() => database.close());

  testWidgets('monthly history filters to the selected month', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: const MonthlyTransactionsPage(month: '2026-08'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agustus 2026'), findsOneWidget);
    expect(find.text('Makan siang'), findsOneWidget);
    expect(find.text('Dengan teman'), findsOneWidget);
    expect(find.text('31 Juli 2026'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('transaction row opens its detail page', (tester) async {
    final router = GoRouter(
      initialLocation: '/reports/history/2026-08',
      routes: [
        GoRoute(
          path: '/reports/history/:month',
          builder: (context, state) =>
              MonthlyTransactionsPage(month: state.pathParameters['month']!),
        ),
        GoRoute(
          path: '/transactions/:id',
          builder: (context, state) => TransactionDetailPage(
            transactionId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Makan siang'));
    await tester.pumpAndSettle();

    expect(find.text('Detail transaksi'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);
    expect(find.text('Makanan'), findsOneWidget);
    expect(find.text('-Rp25.000'), findsOneWidget);
    expect(find.text('Dengan teman'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('empty note shows the explicit empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: TransactionDetailPage(transactionId: emptyNoteTransactionId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada catatan'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Future<int> _createIncomeCategory(AppDatabase database) async {
  return (await CategoryRepository(
    database,
  ).create(name: 'Gaji', type: TransactionType.income)).id;
}
