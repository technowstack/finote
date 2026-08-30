import 'dart:io';

import 'package:finote/features/receipt_scanner/data/device_receipt_image_picker.dart';
import 'package:finote/features/receipt_scanner/data/ml_kit_receipt_ocr_service.dart';
import 'package:finote/features/receipt_scanner/domain/receipt_image.dart';
import 'package:finote/features/receipt_scanner/domain/receipt_ocr.dart';
import 'package:finote/features/receipt_scanner/presentation/receipt_scanner_page.dart';
import 'package:finote/features/receipt_scanner/data/rule_based_receipt_interpreter.dart';
import 'package:finote/features/transactions/presentation/transaction_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('rule-based interpreter keeps the provider replaceable', () async {
    final result = await RuleBasedReceiptInterpreter().interpret(
      const ReceiptOcrResult(rawText: 'TOKO LOKAL\nTOTAL 12.000'),
    );

    expect(result.merchant, 'TOKO LOKAL');
    expect(result.total, 12000);
  });

  testWidgets('shows OCR result without creating a transaction', (
    tester,
  ) async {
    final ocr = _FakeReceiptOcrService([
      const ReceiptOcrResult(rawText: 'TOKO CONTOH\nTOTAL 25000'),
    ]);

    await tester.pumpWidget(_app(_FakeReceiptImagePicker(), ocr));
    await _selectGalleryAndUse(tester);

    expect(find.text('Hasil OCR'), findsOneWidget);
    expect(find.text('TOKO CONTOH\nTOTAL 25000'), findsOneWidget);
    expect(
      find.textContaining('Belum ada transaksi yang dibuat'),
      findsOneWidget,
    );
    expect(ocr.calls, 1);

    await _dispose(tester);
  });

  testWidgets('maps parsed receipt to an expense transaction draft', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/receipt-scan',
      routes: [
        GoRoute(
          path: '/receipt-scan',
          builder: (context, state) => const ReceiptScannerPage(),
        ),
        GoRoute(
          path: '/transactions/new',
          builder: (context, state) {
            final draft = state.extra! as TransactionFormDraft;
            return Scaffold(
              body: Text(
                '${draft.type.name}|${draft.source.name}|${draft.amount}|${draft.title}|${draft.date}',
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    final ocr = _FakeReceiptOcrService([
      const ReceiptOcrResult(
        rawText: 'TOKO CONTOH\n30/08/2026\nTOTAL Rp25.000',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          receiptImagePickerProvider.overrideWithValue(
            _FakeReceiptImagePicker(),
          ),
          receiptOcrServiceProvider.overrideWithValue(ocr),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _selectGalleryAndUse(tester);
    await tester.tap(find.text('Tinjau draft pengeluaran'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'expense|receiptScan|25000|TOKO CONTOH|2026-08-30 00:00:00.000',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows OCR failure actions', (tester) async {
    final ocr = _FakeReceiptOcrService([Exception('OCR failed')]);

    await tester.pumpWidget(_app(_FakeReceiptImagePicker(), ocr));
    await _selectGalleryAndUse(tester);

    expect(find.text('Struk belum berhasil dibaca.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.text('Ganti foto'), findsOneWidget);
    expect(find.text('Isi manual'), findsOneWidget);

    await _dispose(tester);
  });

  testWidgets('treats empty OCR text as unreadable receipt', (tester) async {
    final ocr = _FakeReceiptOcrService([
      const ReceiptOcrResult(rawText: '   '),
    ]);

    await tester.pumpWidget(_app(_FakeReceiptImagePicker(), ocr));
    await _selectGalleryAndUse(tester);

    expect(find.text('Struk belum berhasil dibaca.'), findsOneWidget);
    expect(find.text('Hasil OCR'), findsNothing);

    await _dispose(tester);
  });

  testWidgets('retries OCR with the same image', (tester) async {
    final ocr = _FakeReceiptOcrService([
      Exception('OCR failed'),
      const ReceiptOcrResult(rawText: 'TOTAL 42000'),
    ]);

    await tester.pumpWidget(_app(_FakeReceiptImagePicker(), ocr));
    await _selectGalleryAndUse(tester);
    await tester.tap(find.text('Coba lagi'));
    await tester.pump();

    expect(find.text('Hasil OCR'), findsOneWidget);
    expect(find.text('TOTAL 42000'), findsOneWidget);
    expect(ocr.calls, 2);

    await _dispose(tester);
  });

  testWidgets('permanently denied camera permission links to settings', (
    tester,
  ) async {
    final picker = _FakeReceiptImagePicker(
      failure: const ReceiptImageFailure(
        ReceiptImageFailureReason.permissionPermanentlyDenied,
      ),
    );

    await tester.pumpWidget(_app(picker, _FakeReceiptOcrService([])));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Ambil foto').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Izin kamera ditolak permanen'), findsOneWidget);
    expect(find.text('Buka pengaturan'), findsOneWidget);

    await tester.tap(find.text('Buka pengaturan'));
    await tester.pump();
    expect(picker.settingsOpened, isTrue);

    await _dispose(tester);
  });
}

Future<void> _selectGalleryAndUse(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('Pilih dari galeri').last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.text('Pratinjau foto'), findsOneWidget);

  await tester.tap(find.text('Gunakan foto'));
  await tester.pump();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Widget _app(ReceiptImagePicker picker, ReceiptOcrService ocr) {
  return ProviderScope(
    overrides: [
      receiptImagePickerProvider.overrideWithValue(picker),
      receiptOcrServiceProvider.overrideWithValue(ocr),
    ],
    child: const MaterialApp(home: ReceiptScannerPage()),
  );
}

class _FakeReceiptImagePicker implements ReceiptImagePicker {
  _FakeReceiptImagePicker({this.failure});

  final ReceiptImageFailure? failure;
  bool settingsOpened = false;

  @override
  Future<ReceiptImage?> pick(ReceiptImageOrigin origin) async {
    if (failure != null) throw failure!;
    final imageFile = File(
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png',
    ).absolute;
    return ReceiptImage(
      path: imageFile.path,
      name: 'receipt.png',
      origin: origin,
      isTemporary: false,
    );
  }

  @override
  Future<void> discard(ReceiptImage image) async {}

  @override
  Future<bool> openSettings() async {
    settingsOpened = true;
    return true;
  }
}

class _FakeReceiptOcrService implements ReceiptOcrService {
  _FakeReceiptOcrService(this.responses);

  final List<Object> responses;
  int calls = 0;

  @override
  Future<ReceiptOcrResult> recognize(ReceiptImage image) async {
    calls++;
    final response = responses.removeAt(0);
    if (response is Exception) throw response;
    return response as ReceiptOcrResult;
  }
}
