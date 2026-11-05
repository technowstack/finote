import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/core/widgets/shared_widgets.dart';
import 'package:finote/features/receipt_scanner/domain/receipt_image.dart';
import 'package:finote/features/receipt_scanner/presentation/widgets/receipt_scan_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the presentational scan view alone: no picker, no OCR, no platform
/// channel. Every phase is covered at 320dp with 1.3× text.
Future<void> _pump(
  WidgetTester tester,
  ThemeData theme,
  ReceiptScanView view,
) async {
  tester.view.physicalSize = const Size(320, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: Scaffold(body: SafeArea(child: view)),
    ),
  );
  // Not pumpAndSettle: the processing spinner animates forever.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    final mode = theme.brightness.name;

    testWidgets('idle phase lays out at 320dp with 1.3× text ($mode)', (
      tester,
    ) async {
      var camera = 0;
      await _pump(
        tester,
        theme,
        ReceiptScanView(
          phase: ReceiptScanPhase.idle,
          error: 'Izin kamera ditolak.',
          canOpenSettings: true,
          onCamera: () => camera++,
          onGallery: () {},
          onManual: () {},
          onOpenSettings: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Pilih foto struk'), findsOneWidget);
      expect(find.text('Izin kamera ditolak.'), findsOneWidget);
      expect(find.text('Buka pengaturan'), findsOneWidget);
      await tester.tap(find.text('Ambil foto'));
      expect(camera, 1);
      expect(find.byType(AppEmptyState), findsOneWidget);
    });

    testWidgets('preview phase shows the photo and actions ($mode)', (
      tester,
    ) async {
      await _pump(
        tester,
        theme,
        ReceiptScanView(
          phase: ReceiptScanPhase.preview,
          imageOrigin: ReceiptImageOrigin.camera,
          imageBuilder: (_) => const ColoredBox(
            color: Colors.grey,
            child: SizedBox(height: 200),
          ),
          onRecognize: () {},
          onReplace: () {},
          onCancel: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Pratinjau foto'), findsOneWidget);
      expect(find.text('Ambil ulang'), findsOneWidget);
      expect(find.text('Gunakan foto'), findsOneWidget);
    });

    testWidgets('unreadable preview disables recognition ($mode)', (
      tester,
    ) async {
      await _pump(
        tester,
        theme,
        ReceiptScanView(
          phase: ReceiptScanPhase.preview,
          imageOrigin: ReceiptImageOrigin.gallery,
          imageReadable: false,
          onRecognize: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Gambar tidak dapat dibaca.'), findsOneWidget);
      final use = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Gunakan foto'),
      );
      expect(use.onPressed, isNull);
      expect(find.text('Ganti foto'), findsOneWidget);
    });

    testWidgets('processing phase shows the spinner and status ($mode)', (
      tester,
    ) async {
      await _pump(
        tester,
        theme,
        const ReceiptScanView(
          phase: ReceiptScanPhase.processing,
          recognizing: true,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Membaca struk...'), findsOneWidget);
    });

    testWidgets('result phase shows the raw text for review only ($mode)', (
      tester,
    ) async {
      var draft = 0;
      await _pump(
        tester,
        theme,
        ReceiptScanView(
          phase: ReceiptScanPhase.result,
          rawText: 'KOPI KENANGAN 25.000',
          onOpenReceiptDraft: () => draft++,
          onChangePhoto: () {},
          onCancel: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('KOPI KENANGAN 25.000'), findsOneWidget);
      expect(
        find.text(
          'Teks ini hanya untuk ditinjau. Belum ada transaksi yang dibuat.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Tinjau draft pengeluaran'));
      expect(draft, 1);
      // Diagnostics only appear when the page asks for them (debug builds).
      expect(find.text('Lihat detail teknis'), findsNothing);
    });

    testWidgets('failed phase offers retry, replace and manual ($mode)', (
      tester,
    ) async {
      var retries = 0;
      await _pump(
        tester,
        theme,
        ReceiptScanView(
          phase: ReceiptScanPhase.failed,
          onRecognize: () => retries++,
          onChangePhoto: () {},
          onManual: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Struk belum berhasil dibaca.'), findsOneWidget);
      await tester.tap(find.text('Coba lagi'));
      expect(retries, 1);
      expect(find.text('Isi manual'), findsOneWidget);
    });
  }
}
