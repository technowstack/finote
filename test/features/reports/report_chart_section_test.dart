import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/features/reports/presentation/report_chart_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('chart section handles loading, data, empty, and error states', (
    tester,
  ) async {
    Future<void> pump(
      AsyncValue<List<int>> data, {
      ThemeMode mode = ThemeMode.light,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportChartSection<List<int>>(
                title: 'Grafik arus keuangan',
                subtitle: 'Pemasukan dan pengeluaran',
                data: data,
                isEmpty: (items) => items.isEmpty,
                onRetry: () {},
                builder: (_, items) =>
                    Center(child: Text('Data ${items.length}')),
              ),
            ),
          ),
        ),
      );
    }

    await pump(const AsyncLoading());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await pump(const AsyncData([1, 2]), mode: ThemeMode.dark);
    expect(find.text('Data 2'), findsOneWidget);

    await pump(const AsyncData([]));
    expect(find.text('Belum ada data untuk ditampilkan.'), findsOneWidget);

    await pump(AsyncError(StateError('database'), StackTrace.empty));
    expect(find.text('Gagal memuat grafik.'), findsOneWidget);
    expect(find.text('database'), findsNothing);
  });

  testWidgets('chart section fits a small phone with scaled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: ReportChartSection<List<int>>(
                title: 'Grafik pengeluaran berdasarkan kategori',
                data: const AsyncData([]),
                isEmpty: (items) => items.isEmpty,
                onRetry: () {},
                builder: (_, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Belum ada data untuk ditampilkan.'), findsOneWidget);
  });
}
