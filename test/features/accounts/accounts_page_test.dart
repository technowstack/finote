import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/accounts/presentation/accounts_page.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('accounts page creates an account without transaction controls', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: AccountsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tunai'), findsAtLeastNWidgets(1));
    expect(find.text('Saldo Saat Ini Rp0'), findsOneWidget);
    await tester.tap(find.byTooltip('Tindakan akun'));
    await tester.pumpAndSettle();
    expect(find.text('Nonaktifkan'), findsNothing);
    expect(find.text('Hapus Permanen'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'DANA');
    await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
    await tester.pumpAndSettle();

    expect(find.text('DANA'), findsOneWidget);
    expect(find.text('Transaksi'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('permanently deletes an unused account', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await AccountRepository(database)
        .create(name: 'DANA', type: AccountType.eWallet);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: AccountsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_accountMenu(tester, 'DANA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus Permanen'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus akun?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus Permanen'));
    await tester.pumpAndSettle();

    expect(find.text('DANA'), findsNothing);
    expect(find.text('Akun berhasil dihapus.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('offers archive instead of deleting an account with history', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final accounts = AccountRepository(database);
    final account = await accounts.create(name: 'BCA', type: AccountType.bank);
    final category = await CategoryRepository(database)
        .create(name: 'Makan', type: TransactionType.expense);
    await TransactionRepository(database).create(
      type: TransactionType.expense,
      categoryId: category.id,
      accountId: account.id,
      amount: 25000,
      transactionDate: DateTime(2026, 9, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: AccountsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_accountMenu(tester, 'BCA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus Permanen'));
    await tester.pumpAndSettle();
    expect(find.text('Akun tidak dapat dihapus'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Nonaktifkan'));
    await tester.pumpAndSettle();

    expect(find.text('BCA'), findsOneWidget);
    expect(find.textContaining('Tidak aktif'), findsOneWidget);
    expect((await accounts.findById(account.id))?.isActive, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Finder _accountMenu(WidgetTester tester, String accountName) {
  final card = find.ancestor(
    of: find.text(accountName),
    matching: find.byType(Card),
  );
  return find.descendant(of: card, matching: find.byTooltip('Tindakan akun'));
}
