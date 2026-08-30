import 'dart:io';

import 'package:finote/features/receipt_scanner/data/device_receipt_image_picker.dart';
import 'package:finote/features/receipt_scanner/domain/receipt_image.dart';
import 'package:finote/features/receipt_scanner/presentation/receipt_scanner_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gallery image can be previewed without creating a transaction', (
    tester,
  ) async {
    final imageFile = File(
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png',
    ).absolute;
    final picker = _FakeReceiptImagePicker(
      image: ReceiptImage(
        path: imageFile.path,
        name: 'receipt.png',
        origin: ReceiptImageOrigin.gallery,
        isTemporary: false,
      ),
    );

    await tester.pumpWidget(_app(picker));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Pilih dari galeri').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(picker.origins, [ReceiptImageOrigin.gallery]);
    expect(find.text('Pratinjau foto'), findsOneWidget);
    expect(find.text('Gunakan foto'), findsOneWidget);

    await tester.tap(find.text('Gunakan foto'));
    await tester.pump();

    expect(find.text('Foto siap digunakan'), findsOneWidget);
    expect(
      find.textContaining('Belum ada transaksi yang dibuat'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('permanently denied camera permission links to settings', (
    tester,
  ) async {
    final picker = _FakeReceiptImagePicker(
      failure: const ReceiptImageFailure(
        ReceiptImageFailureReason.permissionPermanentlyDenied,
      ),
    );

    await tester.pumpWidget(_app(picker));
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

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Widget _app(ReceiptImagePicker picker) {
  return ProviderScope(
    overrides: [receiptImagePickerProvider.overrideWithValue(picker)],
    child: const MaterialApp(home: ReceiptScannerPage()),
  );
}

class _FakeReceiptImagePicker implements ReceiptImagePicker {
  _FakeReceiptImagePicker({this.image, this.failure});

  final ReceiptImage? image;
  final ReceiptImageFailure? failure;
  final List<ReceiptImageOrigin> origins = [];
  bool settingsOpened = false;

  @override
  Future<ReceiptImage?> pick(ReceiptImageOrigin origin) async {
    origins.add(origin);
    if (failure != null) throw failure!;
    return image;
  }

  @override
  Future<void> discard(ReceiptImage image) async {}

  @override
  Future<bool> openSettings() async {
    settingsOpened = true;
    return true;
  }
}
