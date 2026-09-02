import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/features/reports/domain/report_chart_data.dart';
import 'package:finote/features/reports/presentation/financial_trend_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('renders exact Income, Expense, and signed Net series', (
    tester,
  ) async {
    final points = [
      FinancialTrendPoint(
        period: DateTime(2026, 8, 1),
        income: 2000000,
        expense: 500000,
      ),
      FinancialTrendPoint(
        period: DateTime(2026, 8, 2),
        income: 0,
        expense: 1000000,
      ),
      FinancialTrendPoint(
        period: DateTime(2026, 8, 3),
        income: 3000000,
        expense: 500000,
      ),
      FinancialTrendPoint(
        period: DateTime(2026, 8, 4),
        income: 500000,
        expense: 500000,
      ),
    ];
    await tester.pumpWidget(_app(points));
    await tester.pumpAndSettle();

    expect(find.text('Net'), findsOneWidget);
    expect(find.text('Pemasukan'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData, hasLength(3));
    expect(chart.data.lineBarsData[0].spots.map((spot) => spot.y), [
      2000000.0,
      0.0,
      3000000.0,
      500000.0,
    ]);
    expect(chart.data.lineBarsData[1].spots.map((spot) => spot.y), [
      500000.0,
      1000000.0,
      500000.0,
      500000.0,
    ]);
    expect(chart.data.lineBarsData[2].spots.map((spot) => spot.y), [
      1500000.0,
      -1000000.0,
      2500000.0,
      0.0,
    ]);
    expect(chart.data.minY, lessThan(0));
    expect(chart.data.maxY, greaterThan(0));
    expect(chart.data.extraLinesData.horizontalLines.single.y, 0);

    final touchedSpots = [
      for (final (index, line) in chart.data.lineBarsData.indexed)
        LineBarSpot(line, index, line.spots[1]),
    ];
    final tooltipItems = chart.data.lineTouchData.touchTooltipData
        .getTooltipItems(touchedSpots);
    final tooltip = tooltipItems
        .whereType<LineTooltipItem>()
        .expand(
          (item) => [item.text, ...?item.children?.map((span) => span.text)],
        )
        .join();
    expect(tooltip, contains('2 Agustus 2026'));
    expect(tooltip, contains('Pemasukan  Rp0'));
    expect(tooltip, contains('Pengeluaran  Rp1.000.000'));
    expect(tooltip, contains('Net  -Rp1.000.000'));
    final semantics = tester.getSemantics(find.byType(FinancialTrendChart));
    expect(semantics.label, contains('Tren Keuangan'));
    expect(semantics.label, contains('Net -Rp1.000.000'));
  });

  testWidgets('handles empty and all-zero data without invalid axes', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const []));
    expect(find.text('Belum ada data tren pada periode ini.'), findsOneWidget);

    await tester.pumpWidget(
      _app([
        FinancialTrendPoint(
          period: DateTime(2026, 8, 1),
          income: 0,
          expense: 0,
        ),
      ]),
    );
    expect(find.text('Belum ada data tren pada periode ini.'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renders income-only and expense-only data on a narrow dark screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          [
            FinancialTrendPoint(
              period: DateTime(2026, 8, 1),
              income: 9000000000000,
              expense: 0,
            ),
            FinancialTrendPoint(
              period: DateTime(2026, 8, 2),
              income: 0,
              expense: 7000000000000,
            ),
          ],
          dark: true,
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData[2].spots.last.y, -7000000000000.0);
      expect(chart.data.minY, lessThan(-7000000000000));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keeps all points while reducing long-range axis labels', (
    tester,
  ) async {
    final points = [
      for (var month = 1; month <= 12; month++)
        FinancialTrendPoint(
          period: DateTime(2026, month),
          income: month * 100000,
          expense: month.isEven ? 50000 : 0,
        ),
    ];
    await tester.pumpWidget(_app(points, granularity: ChartGranularity.month));
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(
      chart.data.lineBarsData.every((line) => line.spots.length == 12),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  List<FinancialTrendPoint> points, {
  ChartGranularity granularity = ChartGranularity.day,
  bool dark = false,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: SizedBox(
          width: 400,
          height: 360,
          child: FinancialTrendChart(points: points, granularity: granularity),
        ),
      ),
    ),
  );
}
