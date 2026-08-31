import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transactions/presentation/transactions_page.dart';
import 'package:finote/core/utils/date_formatter.dart';
import 'package:finote/features/transfers/data/transfer_repository.dart';
import 'package:finote/features/transfers/presentation/transfers_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('history shows and filters one neutral transfer row', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final accounts = AccountRepository(database);
    final source = await accounts.create(
      name: 'BCA Utama',
      type: AccountType.bank,
    );
    final destination = await accounts.create(
      name: 'BCA Tabungan',
      type: AccountType.savings,
    );
    final categories = CategoryRepository(database);
    final salary = await categories.create(
      name: 'Gaji',
      type: TransactionType.income,
    );
    final food = await categories.create(
      name: 'Makanan',
      type: TransactionType.expense,
    );
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    final transactions = TransactionRepository(database);
    await transactions.create(
      type: TransactionType.income,
      categoryId: salary.id,
      accountId: source.id,
      amount: 10000000,
      title: 'Gaji',
      transactionDate: date,
    );
    await transactions.create(
      type: TransactionType.expense,
      categoryId: food.id,
      accountId: source.id,
      amount: 75000,
      title: 'Makan',
      transactionDate: date,
    );
    await TransferRepository(database).create(
      fromAccountId: source.id,
      toAccountId: destination.id,
      amount: 2000000,
      transferDate: date,
    );

    final router = GoRouter(
      initialLocation: '/transactions',
      routes: [
        GoRoute(
          path: '/transactions',
          builder: (context, state) => const TransactionsPage(),
        ),
        GoRoute(
          path: '/transfers',
          builder: (context, state) => TransfersPage(
            editTransferId: int.tryParse(
              state.uri.queryParameters['edit'] ?? '',
            ),
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

    expect(find.text('Gaji'), findsWidgets);
    expect(find.text('Makan'), findsOneWidget);
    expect(find.text('Transfer ke BCA Tabungan'), findsOneWidget);
    expect(find.text('BCA Utama → BCA Tabungan'), findsOneWidget);
    expect(find.text('Rp2.000.000'), findsOneWidget);
    expect(find.text(formatDate(date)), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Transfer'));
    await tester.pumpAndSettle();
    expect(find.text('Transfer ke BCA Tabungan'), findsOneWidget);
    expect(find.text('Gaji'), findsNothing);
    expect(find.text('Makan'), findsNothing);

    await tester.tap(find.text('Transfer ke BCA Tabungan'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah Transfer'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
