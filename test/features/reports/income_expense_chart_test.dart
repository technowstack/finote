import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/features/reports/domain/report_chart_data.dart';
import 'package:finote/features/reports/presentation/income_expense_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  Widget app(
    List<FinancialTrendPoint> points, {
    ThemeMode themeMode = ThemeMode.light,
    Size size = const Size(400, 300),
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: IncomeExpenseChart(
              points: points,
              granularity: ChartGranularity.day,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders grouped bars, legend, exact tooltip, and semantics', (
    tester,
  ) async {
    final points = [
      FinancialTrendPoint(
        period: DateTime(2026, 8, 1),
        income: 8500000,
        expense: 4350000,
      ),
      FinancialTrendPoint(
        period: DateTime(2026, 8, 2),
        income: 0,
        expense: 250000,
      ),
    ];

    await tester.pumpWidget(app(points));
    await tester.pumpAndSettle();

    expect(find.text('Pemasukan'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups, hasLength(2));
    expect(chart.data.barGroups.first.barRods.map((rod) => rod.toY), [
      8500000.0,
      4350000.0,
    ]);

    final group = chart.data.barGroups.first;
    final tooltip = chart.data.barTouchData.touchTooltipData.getTooltipItem(
      group,
      0,
      group.barRods.first,
      0,
    );
    final tooltipText = [
      tooltip!.text,
      ...?tooltip.children?.map((span) => span.text),
    ].join();
    expect(tooltipText, contains('1 Agustus 2026'));
    expect(tooltipText, contains('Rp8.500.000'));
    expect(tooltipText, contains('Rp4.350.000'));

    final semantics = tester.getSemantics(find.byType(IncomeExpenseChart));
    expect(semantics.label, contains('Pemasukan versus Pengeluaran'));
    expect(semantics.label, contains('Rp8.500.000'));
  });

  testWidgets('handles zero, one-sided, large, dark, and narrow data safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      app([
        FinancialTrendPoint(
          period: DateTime(2026, 8, 1),
          income: 0,
          expense: 0,
        ),
      ]),
    );
    expect(find.text('Belum ada transaksi pada periode ini.'), findsOneWidget);

    await tester.pumpWidget(
      app(
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
        themeMode: ThemeMode.dark,
        size: const Size(320, 260),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
