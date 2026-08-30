import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/receipt_scanner/domain/receipt_data.dart';
import 'package:finote/features/transactions/domain/transaction_source.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transactions/presentation/transaction_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('can add, edit, and remove a manual receipt item', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    const draft = TransactionFormDraft(
      type: TransactionType.expense,
      source: TransactionSource.receiptScan,
      receiptReview: ReceiptReviewData(rawOcrText: 'receipt'),
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
    await tester.tap(find.text('Tambah item'));
    await tester.pumpAndSettle();

    final nameField = find.bySemanticsLabel('Nama item');
    final quantityField = find.bySemanticsLabel('Jumlah / Quantity (opsional)');
    final unitPriceField = find.bySemanticsLabel('Harga satuan (opsional)');
    final totalField = find.bySemanticsLabel('Total item *');
    await tester.enterText(nameField, 'Roti');
    await tester.enterText(quantityField, '2');
    await tester.enterText(unitPriceField, '7500');
    await tester.pump();
    expect(totalField, findsOneWidget);
    await tester.tap(find.text('Tambahkan'));
    await tester.pumpAndSettle();

    expect(find.text('Roti'), findsOneWidget);
    expect(find.text('15.000'), findsOneWidget);
    await tester.enterText(find.bySemanticsLabel('Nominal'), '16000');
    await tester.pump();
    expect(find.text('Jumlah item: Rp16.000'), findsOneWidget);
    await tester.tap(find.byTooltip('Hapus item'));
    await tester.pump();
    expect(
      find.textContaining('Belum ada item yang berhasil dibaca.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('itemized receipt draft saves editable items atomically', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final review = ReceiptReviewData(
      merchant: 'TOKO CONTOH',
      transactionDate: DateTime(2026, 8, 30),
      total: 33000,
      items: [
        ReceiptItem(name: 'ROTI', lineTotal: 15000),
        ReceiptItem(name: 'SUSU', lineTotal: 18000),
      ],
      rawOcrText: 'TOKO CONTOH\nROTI 15.000\nSUSU 18.000\nTOTAL 33.000',
    );
    final router = GoRouter(
      initialLocation: '/transactions/new',
      routes: [
        GoRoute(
          path: '/transactions/new',
          builder: (context, state) => TransactionFormPage(
            draft: TransactionFormDraft(
              type: TransactionType.expense,
              source: TransactionSource.receiptScan,
              amount: 33000,
              title: 'TOKO CONTOH',
              date: DateTime(2026, 8, 30),
              receiptReview: review,
            ),
          ),
        ),
        GoRoute(
          path: '/transactions',
          builder: (context, state) => const Scaffold(body: Text('saved')),
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

    expect(find.text('Teks hasil OCR'), findsOneWidget);
    expect(find.text('Jumlah item: Rp33.000'), findsOneWidget);
    expect(find.text('Status: Cocok'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -100));
    await tester.pump();
    await tester.tap(find.text('Pisahkan per item'));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    final category = find.text('Belanja').last;
    await tester.tap(category);
    await tester.tap(find.text('Simpan pengeluaran'));
    await tester.pumpAndSettle();

    final saved = await database.select(database.transactions).get();
    expect(saved, hasLength(2));
    expect(saved.map((item) => item.title), containsAll(['ROTI', 'SUSU']));
    expect(saved.map((item) => item.amount), containsAll([15000, 18000]));
    expect(
      saved.every(
        (item) =>
            item.source == TransactionSource.receiptScan &&
            item.type == TransactionType.expense,
      ),
      isTrue,
    );

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
      builder: (context, state) => const Scaffold(body: Text('saved')),
    ),
  ],
);
