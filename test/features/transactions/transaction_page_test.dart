import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/core/utils/date_formatter.dart';
import 'package:finote/features/transactions/presentation/transaction_form_page.dart';
import 'package:finote/features/transactions/presentation/transactions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('fast transaction flow saves integer amount reactively', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
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

    // Type toggle should show both options
    expect(find.text('Pengeluaran'), findsOneWidget);
    expect(find.text('Pemasukan'), findsOneWidget);

    // Enter amount
    await tester.enterText(find.byType(TextFormField).first, '25000');

    // Select category via chip grid (ChoiceChip)
    await tester.tap(find.text('Belanja'));
    await tester.pumpAndSettle();

    // Save
    await tester.tap(find.text('Simpan transaksi'));
    await tester.pumpAndSettle();

    // Should navigate to transactions page showing the entry
    expect(find.text(formatDate(DateTime.now())), findsOneWidget);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Bulan ini'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
