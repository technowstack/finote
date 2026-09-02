import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/features/reports/domain/report_chart_data.dart';
import 'package:finote/features/reports/presentation/expense_category_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Top 6 plus Lainnya preserves every category amount exactly once', () {
    final points = [
      for (var index = 30; index >= 1; index--)
        CategoryChartPoint(
          categoryId: index,
          categoryName: 'Kategori $index',
          amount: index * 1000,
        ),
    ];

    final visible = visibleExpenseCategories(points);

    expect(visible, hasLength(7));
    expect(visible.take(6).map((point) => point.categoryId), [
      30,
      29,
      28,
      27,
      26,
      25,
    ]);
    expect(visible.last.categoryName, 'Lainnya');
    expect(
      visible.fold<int>(0, (sum, point) => sum + point.amount),
      points.fold<int>(0, (sum, point) => sum + point.amount),
    );
  });

  testWidgets('renders names, compact values, exact tooltips, and semantics', (
    tester,
  ) async {
    const points = [
      CategoryChartPoint(
        categoryId: 1,
        categoryName: 'Kebutuhan Anak dan Pendidikan',
        amount: 2450000,
      ),
      CategoryChartPoint(
        categoryId: 2,
        categoryName: 'Transportasi',
        amount: 500000,
      ),
    ];

    await tester.pumpWidget(_app(points));

    expect(find.text('Kebutuhan Anak dan Pendidikan'), findsOneWidget);
    expect(find.text('Rp2,5 jt'), findsOneWidget);
    expect(find.text('Rp500 rb'), findsOneWidget);
    expect(
      tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((item) => item.message),
      contains('Kebutuhan Anak dan Pendidikan\nRp2.450.000'),
    );
    expect(
      find.bySemanticsLabel('Kebutuhan Anak dan Pendidikan, Rp2.450.000'),
      findsOneWidget,
    );
    await tester.longPress(find.text('Kebutuhan Anak dan Pendidikan'));
    await tester.pumpAndSettle();
    expect(
      find.text('Kebutuhan Anak dan Pendidikan\nRp2.450.000'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'handles empty, one category, large values, dark, and narrow layout',
    (tester) async {
      await tester.pumpWidget(_app(const []));
      expect(
        find.text('Belum ada pengeluaran pada periode ini.'),
        findsOneWidget,
      );

      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(const [
          CategoryChartPoint(
            categoryId: 1,
            categoryName: 'Perawatan Rumah Tangga yang Sangat Panjang',
            amount: 9000000000000,
          ),
        ], dark: true),
      );

      expect(find.byType(ExpenseCategoryChart), findsOneWidget);
      expect(find.text('Rp9000 M'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('treats supplied zero-only data as empty', (tester) async {
    await tester.pumpWidget(
      _app(const [
        CategoryChartPoint(categoryId: 1, categoryName: 'Kosong', amount: 0),
      ]),
    );

    expect(
      find.text('Belum ada pengeluaran pada periode ini.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _app(List<CategoryChartPoint> points, {bool dark = false}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 300,
        child: ExpenseCategoryChart(points: points),
      ),
    ),
  );
}
