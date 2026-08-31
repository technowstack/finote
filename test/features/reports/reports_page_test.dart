import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/reports/presentation/reports_page.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transfers/data/transfer_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('reports separates period flow, current assets, and transfers', (
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
    final archived = await accounts.create(
      name: 'Arsip Lama',
      type: AccountType.cash,
      initialBalance: 500000,
    );
    await accounts.archive(archived.id);
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
    final date = DateTime(now.year, now.month, now.day);
    final transactions = TransactionRepository(database);
    await transactions.create(
      type: TransactionType.income,
      categoryId: income.id,
      accountId: source.id,
      amount: 10000000,
      transactionDate: date,
    );
    await transactions.create(
      type: TransactionType.expense,
      categoryId: expense.id,
      accountId: source.id,
      amount: 1000000,
      transactionDate: date,
    );
    await TransferRepository(database).create(
      fromAccountId: source.id,
      toAccountId: destination.id,
      amount: 2000000,
      transferDate: date,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: ReportsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saldo periode'), findsOneWidget);
    expect(find.text('Rp9.000.000'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Saldo akun saat ini'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('BCA Utama'), findsOneWidget);
    expect(find.text('BCA Tabungan'), findsOneWidget);
    expect(find.text('Arsip Lama'), findsNothing);
    expect(find.text('Rp9.500.000'), findsOneWidget);
    expect(find.textContaining('termasuk 1 akun diarsipkan'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Transfer antar akun'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('1 transfer'), findsOneWidget);
    expect(find.text('Rp2.000.000'), findsAtLeastNWidgets(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
