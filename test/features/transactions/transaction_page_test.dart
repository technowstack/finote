import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/core/utils/date_formatter.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
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

    expect(find.text('Masukkan nominal yang valid.'), findsNothing);
    expect(find.text('Pilih kategori transaksi.'), findsNothing);

    // Type toggle should show both options
    expect(find.text('Pengeluaran'), findsOneWidget);
    expect(find.text('Pemasukan'), findsOneWidget);

    // Enter amount
    await tester.enterText(find.byType(TextFormField).first, '25000');
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      '25.000',
    );

    await tester.tap(find.text('Pemasukan'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan pemasukan'), findsOneWidget);
    expect(find.text('Gaji'), findsOneWidget);
    expect(find.text('Belanja'), findsNothing);

    await tester.tap(find.text('Pengeluaran'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan pengeluaran'), findsOneWidget);

    // Select category via chip grid (ChoiceChip)
    await tester.tap(find.text('Belanja'));
    await tester.pumpAndSettle();

    // Save
    await tester.tap(find.text('Simpan pengeluaran'));
    await tester.pumpAndSettle();

    // Should navigate to transactions page showing the entry
    expect(find.text(formatDate(DateTime.now())), findsOneWidget);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Bulan ini'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('edit prepopulates formatted values and updates one record', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final category = await CategoryRepository(database)
        .create(name: 'Makanan', type: TransactionType.expense);
    final transaction = await TransactionRepository(database).create(
      type: TransactionType.expense,
      categoryId: category.id,
      amount: 25000,
      title: 'Makan siang',
      note: 'Kantor',
      transactionDate: DateTime(2026, 8, 30),
    );
    final router = GoRouter(
      initialLocation: '/transactions/${transaction.id}/edit',
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

    final amount = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(amount.controller!.text, '25.000');
    expect(find.text('Simpan perubahan'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '1250000');
    await tester.tap(find.text('Simpan perubahan'));
    await tester.tap(find.text('Simpan perubahan'));
    await tester.pumpAndSettle();

    final saved = await database.select(database.transactions).get();
    expect(saved, hasLength(1));
    expect(saved.single.amount, 1250000);
    expect(saved.single.title, 'Makan siang');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
