import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/core/theme/category_style.dart';
import 'package:finote/core/theme/finote_colors.dart';
import 'package:finote/core/widgets/shared_widgets.dart';
import 'package:finote/core/widgets/temporary_badge.dart';
import 'package:finote/features/assets/data/asset_repository.dart';
import 'package:finote/features/assets/data/asset_transaction_repository.dart';
import 'package:finote/features/assets/domain/asset_quantity.dart';
import 'package:finote/features/assets/domain/asset_transaction_action.dart';
import 'package:finote/features/assets/domain/asset_type.dart';
import 'package:finote/features/assets/presentation/assets_page.dart';
import 'package:finote/features/assets/presentation/widgets/asset_composition_card.dart';
import 'package:finote/features/assets/presentation/widgets/asset_list_item.dart';
import 'package:finote/features/market/data/asset_price_repository.dart';
import 'package:finote/features/market/data/market_api_client.dart';
import 'package:finote/features/market/data/market_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fund 123.4567 unit @ 1.845 = 227.778 and gold 5.25 g @ 1.500.000 =
/// 7.875.000 (total 8.102.778). With [withUnpriced], a manual-priced "other"
/// asset has a position but no price yet, so the portfolio is partial.
Future<AppDatabase> _seed({bool withUnpriced = true}) async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final assets = AssetRepository(database);
  final transactions = AssetTransactionRepository(database);
  final prices = AssetPriceRepository(database);
  final fund = await assets.create(
    name: 'Reksadana Pasar Uang ABC',
    assetType: AssetType.mutualFund,
    pricingMode: AssetPricingMode.manual,
  );
  final gold = await assets.create(
    name: 'Emas Antam',
    assetType: AssetType.gold,
    pricingMode: AssetPricingMode.manual,
  );
  await transactions.create(
    assetId: fund.id,
    action: AssetTransactionAction.openingPosition,
    quantity: AssetQuantity.parse('123.4567'),
    transactionDate: DateTime(2026, 9, 4),
  );
  await transactions.create(
    assetId: gold.id,
    action: AssetTransactionAction.openingPosition,
    quantity: AssetQuantity.parse('5.25'),
    transactionDate: DateTime(2026, 9, 4),
  );
  await prices.setManualPrice(assetId: fund.id, price: 1845);
  await prices.setManualPrice(assetId: gold.id, price: 1500000);
  if (withUnpriced) {
    final other = await assets.create(
      name: 'Koleksi Jam Tangan',
      assetType: AssetType.other,
      pricingMode: AssetPricingMode.manual,
      unitLabel: 'unit',
    );
    await transactions.create(
      assetId: other.id,
      action: AssetTransactionAction.openingPosition,
      quantity: AssetQuantity.parse('2'),
      transactionDate: DateTime(2026, 9, 4),
    );
  }
  return database;
}

/// Pumps the Portofolio page and returns a getter for market requests made.
Future<int Function()> _pumpPortfolio(
  WidgetTester tester,
  ThemeData theme,
  AppDatabase database, {
  double height = 2600,
  double textScale = 1.3,
}) async {
  var marketCalls = 0;
  final market = MarketRepository(
    MarketApiClient(
      baseUrl: 'https://market.example/',
      post: (_, _) async {
        marketCalls++;
        return const MarketHttpResponse(200, '{"quotes":[]}');
      },
    ),
  );
  tester.view.physicalSize = Size(320, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const AssetsPage())],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        marketRepositoryProvider.overrideWithValue(market),
      ],
      child: MaterialApp.router(
        theme: theme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return () => marketCalls;
}

/// testWidgets that unmounts at the end so Drift's stream-cleanup timer is
/// flushed (the convention used by the other database-backed widget tests).
void _dbTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Finder _rowValue(String amount) => find.descendant(
  of: find.byType(AssetListItem),
  matching: find.text(amount),
);

double _hitHeight(WidgetTester tester, String tooltip) => tester
    .getSize(
      find
          .ancestor(
            of: find.byTooltip(tooltip).first,
            matching: find.byType(IconButton),
          )
          .first,
    )
    .height;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    final mode = theme.brightness.name;

    _dbTest('lays out at 320dp with 1.3× text ($mode)', (tester) async {
      final database = await _seed();
      final marketCalls = await _pumpPortfolio(tester, theme, database);
      expect(tester.takeException(), isNull);
      expect(marketCalls(), 0, reason: 'opening Portofolio never calls out');

      // Hero: partial value (the unpriced asset is not counted as zero).
      expect(find.text('Nilai Portofolio'), findsOneWidget);
      expect(find.text('Rp8.102.778'), findsOneWidget);
      expect(find.text('3 aset aktif'), findsOneWidget);
      expect(find.byType(TemporaryBadge), findsOneWidget);
      expect(
        find.text('Nilai sementara • 1 aset belum memiliki harga'),
        findsOneWidget,
      );

      // Composition: shares of the known value only.
      expect(find.text('Komposisi aset'), findsOneWidget);
      expect(find.text('97%'), findsOneWidget); // gold 7.875.000 / 8.102.778
      expect(find.text('3%'), findsOneWidget); // fund 227.778
      // The unpriced asset has no known value, so it has no slice; the hero
      // badge above is what flags the partial total.
      expect(find.textContaining('harga belum tersedia'), findsNothing);
    });

    _dbTest('asset rows: value on the right, info below, no invented P/L '
        '($mode)', (tester) async {
      final database = await _seed();
      await _pumpPortfolio(tester, theme, database);

      expect(find.text('Aset aktif'), findsOneWidget);
      expect(find.text('3 aset'), findsOneWidget);
      expect(_rowValue('Rp7.875.000'), findsOneWidget);
      expect(_rowValue('Rp227.778'), findsOneWidget);
      // Unknown stays unknown: never "Rp0".
      expect(find.text('Rp0'), findsNothing);
      expect(find.textContaining('Harga belum diatur'), findsOneWidget);
      expect(find.textContaining('5.25 gram'), findsOneWidget);
      expect(
        find.textContaining('Harga per Gram Rp1.500.000 / gram'),
        findsOneWidget,
      );
      // Profit/loss needs a cost basis the app does not have.
      expect(find.textContaining('%)'), findsNothing);
      expect(find.textContaining('+Rp'), findsNothing);
    });

    _dbTest('composition colors come from the category palette ($mode)', (
      tester,
    ) async {
      final database = await _seed(withUnpriced: false);
      await _pumpPortfolio(tester, theme, database);

      final context = tester.element(find.byType(AssetCompositionCard));
      final palette = theme.finote.categories;
      expect(
        assetTypeColor(context, AssetType.gold),
        palette[FinoteCategory.food]!.foreground,
      );
      expect(
        assetTypeColor(context, AssetType.mutualFund),
        palette[FinoteCategory.shopping]!.foreground,
      );
      // Fully valued portfolio: no partial badge.
      expect(find.byType(TemporaryBadge), findsNothing);
      expect(find.text('Total Portofolio'), findsOneWidget);
    });
  }

  _dbTest('hidden balance masks hero, legend and row values', (tester) async {
    SharedPreferences.setMockInitialValues({'finote_hide_balance': true});
    final database = await _seed();
    await _pumpPortfolio(tester, AppTheme.light, database);

    for (final amount in ['Rp8.102.778', 'Rp7.875.000', 'Rp227.778']) {
      expect(find.text(amount), findsNothing, reason: amount);
    }
    expect(find.text(maskedAmount), findsWidgets);
    // Shares are not amounts, so they stay readable.
    expect(find.text('97%'), findsOneWidget);
    expect(find.text('Emas Antam'), findsOneWidget);
  });

  _dbTest('stacked composition layout on a narrow phone', (tester) async {
    final database = await _seed();
    await _pumpPortfolio(tester, AppTheme.dark, database, textScale: 1.0);
    expect(tester.takeException(), isNull);
    final card = tester.getRect(find.byType(AssetCompositionCard));
    expect(card.width, lessThanOrEqualTo(320));
    expect(find.text('Komposisi aset'), findsOneWidget);
  });

  _dbTest('controls keep 48dp hit areas and the hero toggle masks', (
    tester,
  ) async {
    final database = await _seed();
    await _pumpPortfolio(tester, AppTheme.light, database);

    for (final tooltip in [
      'Refresh Harga',
      'Sembunyikan saldo',
      'Tindakan aset',
    ]) {
      expect(
        _hitHeight(tester, tooltip),
        greaterThanOrEqualTo(48),
        reason: tooltip,
      );
    }
    await tester.tap(find.byTooltip('Sembunyikan saldo'));
    await tester.pumpAndSettle();
    expect(find.text('Rp8.102.778'), findsNothing);
    expect(find.text(maskedAmount), findsWidgets);
  });

  _dbTest('empty portfolio uses AppEmptyState', (tester) async {
    final empty = AppDatabase(NativeDatabase.memory());
    addTearDown(empty.close);
    await _pumpPortfolio(tester, AppTheme.light, empty, height: 900);
    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.text('Belum ada aset investasi'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Tambah Aset'), findsOneWidget);
    expect(find.byType(AssetCompositionCard), findsNothing);
  });
}
