import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/transactions/domain/transaction_source.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transactions/presentation/transaction_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'receipt draft is editable and saves only after explicit review',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      const draft = TransactionFormDraft(
        type: TransactionType.expense,
        source: TransactionSource.receiptScan,
        amount: 25000,
        title: 'TOKO CONTOH',
      );
      final router = _router(draft);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tinjau pengeluaran'), findsOneWidget);
      expect(find.text('Pengeluaran dari struk'), findsOneWidget);
      expect(find.text('25.000'), findsOneWidget);
      expect(find.text('TOKO CONTOH'), findsOneWidget);
      expect(find.textContaining('Tanggal tidak terbaca'), findsOneWidget);
      expect(find.text('Simpan pengeluaran'), findsOneWidget);
      expect(await database.select(database.transactions).get(), isEmpty);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '26000');
      await tester.tap(find.text('Belanja'));
      await tester.enterText(fields.at(1), 'TOKO DIEDIT');
      await tester.enterText(fields.at(2), 'Catatan pengguna');
      await tester.tap(find.text('Simpan pengeluaran'));
      await tester.pumpAndSettle();

      final saved = await database.select(database.transactions).getSingle();
      expect(saved.type, TransactionType.expense);
      expect(saved.source, TransactionSource.receiptScan);
      expect(saved.amount, 26000);
      expect(saved.title, 'TOKO DIEDIT');
      expect(saved.note, 'Catatan pengguna');
      final now = DateTime.now();
      expect(saved.transactionDate, DateTime(now.year, now.month, now.day));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('missing total and merchant remain blank and cannot autosave', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    const draft = TransactionFormDraft(
      type: TransactionType.expense,
      source: TransactionSource.receiptScan,
    );
    final router = _router(draft);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(
      tester.widget<TextFormField>(fields.at(0)).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<TextFormField>(fields.at(1)).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<TextFormField>(fields.at(2)).controller!.text,
      isEmpty,
    );

    await tester.tap(find.text('Simpan pengeluaran'));
    await tester.pump();

    expect(find.text('Masukkan nominal yang valid.'), findsOneWidget);
    expect(find.text('Pilih kategori transaksi.'), findsOneWidget);
    expect(await database.select(database.transactions).get(), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

GoRouter _router(TransactionFormDraft draft) => GoRouter(
  initialLocation: '/transactions/new',
  routes: [
    GoRoute(
      path: '/transactions/new',
      builder: (context, state) => TransactionFormPage(draft: draft),
    ),
    GoRoute(
      path: '/transactions',
      builder: (context, state) => const Scaffold(body: Text('Transaksi')),
    ),
  ],
);
