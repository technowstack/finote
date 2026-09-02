import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/reports/domain/report_chart_data.dart';
import 'package:finote/features/reports/presentation/account_balance_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active accounts sort by balance, name, then ID', () {
    final points = [
      _point(4, 'Arsip', -100, active: false),
      _point(3, 'zeta', 0),
      _point(2, 'Beta', 100),
      _point(1, 'alpha', 100),
      _point(5, 'zeta', 0),
    ];

    expect(visibleAccountBalances(points).map((point) => point.accountId), [
      1,
      2,
      3,
      5,
    ]);
    expect(points, hasLength(5));
  });

  testWidgets(
    'renders positive, negative, zero, totals, tooltip, and semantics',
    (tester) async {
      final points = [
        _point(1, 'BCA Utama', 12000000, type: AccountType.bank),
        _point(2, 'BCA Tabungan', 2450000, type: AccountType.savings),
        _point(3, 'Tunai', 0),
        _point(4, 'Dompet Minus', -500000, type: AccountType.eWallet),
      ];
      await tester.pumpWidget(
        _app(points, totalAssets: 13950000, archivedCount: 1),
      );

      expect(find.text('Total Aset'), findsOneWidget);
      expect(find.text('Rp13.950.000'), findsOneWidget);
      expect(find.text('Termasuk 1 akun diarsipkan'), findsOneWidget);
      expect(find.text('Rp12 jt'), findsOneWidget);
      expect(find.text('-Rp500 rb'), findsOneWidget);
      expect(find.text('Rp0'), findsOneWidget);

      final zero = tester.getRect(
        find.byKey(const Key('account-balance-zero-4')),
      );
      final negative = tester.getRect(
        find.byKey(const Key('account-balance-bar-4')),
      );
      final positive = tester.getRect(
        find.byKey(const Key('account-balance-bar-1')),
      );
      expect(negative.right, lessThanOrEqualTo(zero.left + 0.01));
      expect(positive.left, greaterThanOrEqualTo(zero.left - 0.01));

      final semantics = tester.getSemantics(find.byType(AccountBalanceChart));
      expect(semantics.label, contains('Dompet Minus, E-Wallet, -Rp500.000'));
      await tester.tap(find.text('Dompet Minus'));
      await tester.pumpAndSettle();
      expect(find.text('Dompet Minus\nE-Wallet\n-Rp500.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('handles empty input safely', (tester) async {
    await tester.pumpWidget(_app(const [], totalAssets: 0));
    expect(find.text('Belum ada akun untuk ditampilkan.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renders 20 accounts, long names, large values, dark, and scaled text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final points = [
        for (var index = 0; index < 20; index++)
          _point(
            index + 1,
            index == 0
                ? 'Bank Central Asia Tabungan Darurat Keluarga'
                : 'Akun ${index + 1}',
            9000000000000 - index * 100000,
          ),
      ];
      await tester.pumpWidget(
        _app(
          points,
          totalAssets: points.fold<int>(0, (sum, point) => sum + point.balance),
          dark: true,
          textScale: 1.3,
          height: 1800,
        ),
      );

      expect(find.byType(AccountBalanceChart), findsOneWidget);
      expect(find.byKey(const Key('account-balance-bar-20')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

AccountBalanceChartPoint _point(
  int id,
  String name,
  int balance, {
  AccountType type = AccountType.cash,
  bool active = true,
}) {
  return AccountBalanceChartPoint(
    accountId: id,
    accountName: name,
    accountType: type,
    balance: balance,
    isActive: active,
  );
}

Widget _app(
  List<AccountBalanceChartPoint> points, {
  required int totalAssets,
  int archivedCount = 0,
  bool dark = false,
  double textScale = 1,
  double height = 500,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            height: height,
            child: AccountBalanceChart(
              points: points,
              totalAssets: totalAssets,
              archivedCount: archivedCount,
            ),
          ),
        ),
      ),
    ),
  );
}
