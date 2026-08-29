import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
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
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const TransactionFormPage(),
            ),
          ],
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

    expect(find.text('Pengeluaran'), findsOneWidget);
    expect(find.text('Pemasukan'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '25000');

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Belanja').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan transaksi'));
    await tester.pumpAndSettle();

    expect(find.text('-Rp25.000'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
