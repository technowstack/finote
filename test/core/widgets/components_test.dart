import 'package:finote/core/theme/app_colors.dart';
import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/core/theme/finote_colors.dart';
import 'package:finote/core/widgets/app_snackbars.dart';
import 'package:finote/core/widgets/expense_7day_card.dart';
import 'package:finote/core/widgets/finance_tiles.dart';
import 'package:finote/core/widgets/finote_controls.dart';
import 'package:finote/core/widgets/finote_hero.dart';
import 'package:finote/core/widgets/shared_widgets.dart';
import 'package:finote/core/widgets/temporary_badge.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps [child] at 320dp wide with 1.3× text, inside ProviderScope.
Future<void> _pump(
  WidgetTester tester,
  ThemeData theme,
  Widget child, {
  double height = 2400,
}) async {
  tester.view.physicalSize = Size(320, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
  // Not pumpAndSettle: AppLoadingState's spinner animates forever.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

double _height(Element element) =>
    (element.renderObject! as RenderBox).size.height;

final _today = DateTime(2026, 11, 8); // a Sunday

Widget _gallery() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const FinoteHero(
      title: 'Kekayaan Bersih',
      action: BalanceVisibilityButton(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FinoteHeroAmount(amount: 9000000000000000),
          TemporaryBadge(text: 'Nilai sementara • 1 aset', onHero: true),
          Row(
            children: [
              Expanded(
                child: FinoteHeroTile(label: 'Kas & Dompet', amount: 1000),
              ),
              Expanded(
                child: FinoteHeroTile(label: 'Portofolio', amount: null),
              ),
            ],
          ),
        ],
      ),
    ),
    Expense7DayCard(
      days: [
        for (var i = 6; i >= 0; i--)
          (
            day: DateTime(_today.year, _today.month, _today.day - i),
            expense: i * 125000,
          ),
      ],
    ),
    const TemporaryBadge(text: 'Nilai sementara • 1 aset belum ada harga'),
    const TransactionTile(
      title: 'Makan siang bersama tim proyek yang sangat panjang',
      categoryName: 'Makanan & Minuman',
      amount: 48000,
      type: TransactionType.expense,
      caption: '12.40',
    ),
    const TransactionTile(
      title: '',
      categoryName: 'Kategori Buatan Saya',
      amount: 8500000,
      type: TransactionType.income,
    ),
    const TransferTile(
      title: 'Isi dompet',
      route: 'BCA → Dompet tunai · 09.15',
      amount: 500000,
    ),
    const AssetTile(
      name: 'Bank Central Asia',
      code: 'BBCA',
      info: '50 lot · Rp 9.250/saham',
      value: 46250000,
      change: '+2,4%',
      changePositive: true,
    ),
    const AssetTile(name: 'Emas', value: null),
    const DateHeader(label: 'Hari ini · Min, 8 Nov', total: -230500),
    const DateHeader(label: 'Kemarin · Sab, 7 Nov', total: 8500000),
    const CategoryBar(name: 'Belanja', fraction: 0.23, amount: 1850000),
    FinoteChip(label: '7 hari', selected: true, onSelected: () {}),
    FinoteSegmented<int>(
      segments: const [
        FinoteSegment(0, 'Pengeluaran'),
        FinoteSegment(1, 'Pemasukan'),
        FinoteSegment(2, 'Transfer'),
      ],
      selected: 0,
      onChanged: (_) {},
    ),
    const SizedBox(height: 120, child: AppLoadingState(message: 'Memuat')),
    AppErrorState(message: 'Data belum dapat dimuat', onRetry: () {}),
    AppEmptyState(
      icon: Icons.receipt_long_outlined,
      message: 'Belum ada transaksi',
      subtitle: 'Catat pemasukan atau pengeluaran pertama Anda.',
      actionLabel: 'Tambah transaksi',
      onAction: () {},
    ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    final mode = theme.brightness.name;

    testWidgets('all components lay out at 320dp, 1.3× text ($mode)', (
      tester,
    ) async {
      await _pump(tester, theme, _gallery());
      expect(tester.takeException(), isNull);

      // Unknown values are labelled, never shown as zero.
      expect(find.text('Belum tersedia'), findsOneWidget);
      expect(find.text('Belum ada harga'), findsOneWidget);
      // Untitled transaction falls back to its category name.
      expect(find.text('Kategori Buatan Saya'), findsOneWidget);
      expect(find.text('Rp2.625.000'), findsOneWidget); // 7-day total
    });

    testWidgets('amounts: sign, color, tabular figures ($mode)', (
      tester,
    ) async {
      await _pump(tester, theme, _gallery());
      final c = theme.finote;
      final expense = tester.widget<Text>(find.text('-Rp48.000'));
      expect(expense.style?.color, c.expense);
      expect(
        expense.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      // Income tile first, then the positive daily header.
      final income = find.text('+Rp8.500.000');
      expect(tester.widget<Text>(income.first).style?.color, c.income);
      expect(
        tester.widget<Text>(income.last).style?.color,
        theme.colorScheme.incomeColor,
      );
      expect(
        tester.widget<Text>(find.text('-Rp230.500')).style?.color,
        theme.colorScheme.expenseColor,
      );
      // Transfers are neutral: neither income nor expense colors.
      final transfer = tester.widget<Text>(find.text('Rp500.000'));
      expect(transfer.style?.color, theme.colorScheme.onSurface);
      expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
      // Category icon tiles carry the category color, never red/green.
      final food = tester.widget<Icon>(find.byIcon(Icons.restaurant_rounded));
      expect(food.color, c.categoryStyle('Makanan & Minuman').foreground);
    });
  }

  testWidgets('hidden balance masks maskable amounts only', (tester) async {
    SharedPreferences.setMockInitialValues({'finote_hide_balance': true});
    await _pump(
      tester,
      AppTheme.light,
      const Column(
        children: [
          CurrencyText(amount: 15000000, maskable: true),
          CurrencyText(amount: 48000),
        ],
      ),
    );
    expect(find.text(maskedAmount), findsOneWidget);
    expect(find.text('Rp15.000.000'), findsNothing);
    expect(find.text('Rp48.000'), findsOneWidget);
    expect(find.bySemanticsLabel('Nominal disembunyikan'), findsOneWidget);
  });

  testWidgets('balance toggle flips the mask and persists', (tester) async {
    await _pump(
      tester,
      AppTheme.dark,
      const FinoteHero(
        title: 'Kekayaan Bersih',
        action: BalanceVisibilityButton(),
        child: FinoteHeroAmount(amount: 15000000),
      ),
    );
    expect(find.text('Rp15.000.000'), findsOneWidget);
    await tester.tap(find.byTooltip('Sembunyikan saldo'));
    await tester.pumpAndSettle();
    expect(find.text(maskedAmount), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('finote_hide_balance'), isTrue);
  });

  testWidgets('FinoteChip: 34dp visual, taps count across the 48dp area', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      AppTheme.light,
      Center(
        child: FinoteChip(
          label: '30 hari',
          selected: false,
          onSelected: () => taps++,
        ),
      ),
      height: 600,
    );
    final visual = tester.getRect(
      find.descendant(
        of: find.byType(FinoteChip),
        matching: find.byType(Material),
      ),
    );
    final target = tester.getRect(
      find
          .descendant(
            of: find.byType(FinoteChip),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    expect(visual.height, greaterThanOrEqualTo(34));
    expect(target.height, greaterThanOrEqualTo(48));
    expect(target.top, lessThan(visual.top));
    // A tap in the transparent band above the visual still counts.
    await tester.tapAt(Offset(visual.center.dx, target.top + 2));
    await tester.tap(find.text('30 hari'));
    expect(taps, 2);
  });

  testWidgets('FinoteSegmented: 48dp segments report the tapped value', (
    tester,
  ) async {
    String? chosen;
    await _pump(
      tester,
      AppTheme.dark,
      FinoteSegmented<String>(
        segments: const [
          FinoteSegment('expense', 'Pengeluaran'),
          FinoteSegment('income', 'Pemasukan'),
        ],
        selected: 'expense',
        onChanged: (value) => chosen = value,
      ),
      height: 600,
    );
    final segments = find.byType(InkWell).evaluate().toList();
    expect(segments, hasLength(2));
    for (final segment in segments) {
      expect(_height(segment), greaterThanOrEqualTo(48));
    }
    await tester.tap(find.text('Pemasukan'));
    expect(chosen, 'income');
  });

  testWidgets('tiles keep a 48dp minimum hit area and fire onTap', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      AppTheme.light,
      Column(
        children: [
          TransactionTile(
            title: 'Parkir',
            categoryName: 'Transportasi',
            amount: 5000,
            type: TransactionType.expense,
            onTap: () => taps++,
          ),
          TransferTile(
            title: 'Tabungan',
            route: 'BCA → Jago',
            amount: 1,
            onTap: () => taps++,
          ),
          AssetTile(name: 'BBRI', value: 1, onTap: () => taps++),
          FinoteHeroTile(label: 'Portofolio', amount: 1, onTap: () => taps++),
        ],
      ),
      height: 800,
    );
    final inks = find.byType(InkWell).evaluate().toList();
    expect(inks, hasLength(4));
    for (final ink in inks) {
      expect(_height(ink), greaterThanOrEqualTo(48));
    }
    for (final label in ['Parkir', 'Tabungan', 'BBRI', 'Portofolio']) {
      await tester.tap(find.text(label));
    }
    expect(taps, 4);
  });

  testWidgets('status states expose retry and primary action', (tester) async {
    var retries = 0;
    var actions = 0;
    await _pump(
      tester,
      AppTheme.light,
      Column(
        children: [
          AppErrorState(message: 'Gagal', onRetry: () => retries++),
          AppEmptyState(
            icon: Icons.inbox_outlined,
            message: 'Kosong',
            actionLabel: 'Tambah',
            onAction: () => actions++,
          ),
        ],
      ),
      height: 900,
    );
    await tester.tap(find.text('Coba lagi'));
    await tester.tap(find.text('Tambah'));
    expect((retries, actions), (1, 1));
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('snackbars: info and error (${theme.brightness.name})', (
      tester,
    ) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => showAppSnackBar(context, 'Tersimpan'),
                    child: const Text('info'),
                  ),
                  TextButton(
                    onPressed: () => showAppErrorSnackBar(
                      context,
                      'Gagal menyimpan transaksi',
                      onAction: () => retried = true,
                    ),
                    child: const Text('error'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('info'));
      await tester.pumpAndSettle();
      expect(find.text('Tersimpan'), findsOneWidget);

      await tester.tap(find.text('error'));
      await tester.pumpAndSettle();
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.backgroundColor, theme.colorScheme.errorContainer);
      expect(find.text('Tersimpan'), findsNothing);
      await tester.tap(find.text('Coba lagi'));
      expect(retried, isTrue);
    });
  }
}
