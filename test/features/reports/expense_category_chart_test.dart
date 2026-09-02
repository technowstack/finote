import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/features/reports/domain/report_chart_data.dart';
import 'package:finote/features/reports/presentation/expense_category_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Top 5 plus Lainnya preserves every category amount exactly once', () {
    final points = [
      for (var index = 10; index >= 1; index--)
        CategoryChartPoint(
          categoryId: index,
          categoryName: 'Kategori $index',
          amount: index * 1000,
        ),
    ];

    final visible = visibleExpenseCategories(points);

    expect(visible, hasLength(6));
    expect(visible.take(5).map((point) => point.categoryId), [10, 9, 8, 7, 6]);
    expect(visible.last.categoryName, 'Lainnya');
    expect(
      visible.fold<int>(0, (sum, point) => sum + point.amount),
      points.fold<int>(0, (sum, point) => sum + point.amount),
    );
  });

  testWidgets('renders donut, exact breakdown, center total, and semantics', (
    tester,
  ) async {
    const points = [
      CategoryChartPoint(
        categoryId: 1,
        categoryName: 'Makanan',
        amount: 2400000,
      ),
      CategoryChartPoint(
        categoryId: 2,
        categoryName: 'Transportasi',
        amount: 1500000,
      ),
      CategoryChartPoint(
        categoryId: 3,
        categoryName: 'Tagihan',
        amount: 1200000,
      ),
      CategoryChartPoint(
        categoryId: 4,
        categoryName: 'Hiburan',
        amount: 650000,
      ),
    ];

    await tester.pumpWidget(_app(points));
    await tester.pumpAndSettle();

    expect(find.byType(PieChart), findsOneWidget);
    final chart = tester.widget<PieChart>(find.byType(PieChart));
    expect(chart.data.sections.map((section) => section.value), [
      2400000.0,
      1500000.0,
      1200000.0,
      650000.0,
    ]);
    expect(find.text('Rp5,8 jt'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);
    expect(find.text('Rp2.400.000'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(ExpenseCategoryChart)).label,
      contains('Total Rp5.750.000'),
    );
  });

  testWidgets('tap a category updates center and tap again resets it', (
    tester,
  ) async {
    const points = [
      CategoryChartPoint(
        categoryId: 1,
        categoryName: 'Makanan',
        amount: 500000,
      ),
      CategoryChartPoint(
        categoryId: 2,
        categoryName: 'Transportasi',
        amount: 500000,
      ),
    ];
    await tester.pumpWidget(_app(points));

    await tester.tap(find.text('Makanan').last);
    await tester.pumpAndSettle();
    expect(find.text('Rp500 rb'), findsOneWidget);
    expect(find.text('Makanan'), findsAtLeastNWidgets(2));

    await tester.tap(find.text('Makanan').last);
    await tester.pumpAndSettle();
    expect(find.text('Pengeluaran'), findsOneWidget);
  });

  testWidgets(
    'handles empty, single, many, dark, long labels, and narrow layout',
    (tester) async {
      await tester.pumpWidget(_app(const []));
      expect(
        find.text('Belum ada pengeluaran pada periode ini.'),
        findsOneWidget,
      );
      expect(find.byType(PieChart), findsNothing);

      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(const [
          CategoryChartPoint(
            categoryId: 1,
            categoryName: 'Kategori dengan nama yang sangat panjang sekali',
            amount: 9000000000000,
          ),
        ], dark: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PieChart), findsOneWidget);
      expect(
        tester.widget<PieChart>(find.byType(PieChart)).data.sections,
        hasLength(1),
      );
      expect(find.text('100%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(List<CategoryChartPoint> points, {bool dark = false}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 500,
        child: ExpenseCategoryChart(points: points),
      ),
    ),
  );
}
