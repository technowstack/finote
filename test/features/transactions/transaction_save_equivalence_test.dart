import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transactions/presentation/transaction_form_page.dart';
import 'package:finote/features/transactions/presentation/transactions_page.dart';
import 'package:finote/features/transfers/presentation/transfers_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guards the save paths the form redesign must not change: what gets stored
/// for a new transaction, an edit, and a transfer.

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('creating an expense stores the same row as before', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final food = await CategoryRepository(database)
        .create(name: 'Makanan & Minuman', type: TransactionType.expense);
    final router = GoRouter(
      initialLocation: '/transactions/new',
      routes: [
        GoRoute(
          path: '/transactions',
          builder: (context, state) => const TransactionsPage(),
        ),
        GoRoute(
          path: '/transactions/new',
          builder: (context, state) => const TransactionFormPage(),
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

    await tester.enterText(find.byType(TextFormField).first, '25000');
    await tester.tap(find.text(food.name));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan pengeluaran'));
    await tester.pumpAndSettle();

    final saved = await database.select(database.transactions).get();
    expect(saved, hasLength(1));
    final row = saved.single;
    expect(row.type, TransactionType.expense);
    expect(row.categoryId, food.id);
    expect(row.amount, 25000);
    expect(row.deletedAt, isNull);
    expect(row.title, isEmpty);
    expect(row.uuid, isNotEmpty);
    // Date-only: the calendar day is the day entered.
    final today = DateTime.now();
    expect(row.transactionDate.day, today.day);
    expect(row.transactionDate.month, today.month);
    expect(row.transactionDate.year, today.year);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('editing changes only the edited fields of the same row', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final category = await CategoryRepository(database)
        .create(name: 'Makanan', type: TransactionType.expense);
    final created = await TransactionRepository(database).create(
      type: TransactionType.expense,
      categoryId: category.id,
      amount: 25000,
      title: 'Makan siang',
      note: 'Kantor',
      transactionDate: DateTime(2026, 8, 30),
    );
    final router = GoRouter(
      initialLocation: '/transactions/${created.id}/edit',
      routes: [
        GoRoute(
          path: '/transactions/:id/edit',
          builder: (context, state) => TransactionFormPage(
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

    await tester.enterText(find.byType(TextFormField).first, '1250000');
    await tester.tap(find.text('Simpan perubahan'));
    await tester.pumpAndSettle();

    final saved = await database.select(database.transactions).get();
    expect(saved, hasLength(1));
    final row = saved.single;
    expect(row.id, created.id);
    expect(row.uuid, created.uuid);
    expect(row.amount, 1250000);
    expect(row.title, 'Makan siang');
    expect(row.note, 'Kantor');
    expect(row.type, TransactionType.expense);
    expect(row.categoryId, category.id);
    expect(row.transactionDate, DateTime(2026, 8, 30));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a transfer stores one neutral row and no income/expense', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final bca = await AccountRepository(database)
        .create(name: 'BCA', type: AccountType.bank);
    final tunai = (await database.select(database.accounts).get()).singleWhere(
      (account) => account.isDefault,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: TransfersPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('${tunai.name} ·').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('BCA ·').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nominal'),
      '500000',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));
    await tester.pumpAndSettle();

    final transfers = await database.select(database.transfers).get();
    expect(transfers, hasLength(1));
    expect(transfers.single.fromAccountId, tunai.id);
    expect(transfers.single.toAccountId, bca.id);
    expect(transfers.single.amount, 500000);
    expect(transfers.single.deletedAt, isNull);
    // A transfer never becomes a transaction row.
    expect(await database.select(database.transactions).get(), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
