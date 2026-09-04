import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/assets/data/asset_repository.dart';
import 'package:finote/features/assets/data/asset_transaction_repository.dart';
import 'package:finote/features/assets/domain/asset_quantity.dart';
import 'package:finote/features/assets/domain/asset_transaction_action.dart';
import 'package:finote/features/assets/domain/asset_type.dart';
import 'package:finote/features/assets/presentation/assets_page.dart';
import 'package:finote/features/market/data/market_api_client.dart';
import 'package:finote/features/market/data/market_repository.dart';
import 'package:finote/features/market/data/asset_price_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('creates, edits, opens, archives, and restores an asset', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.ensureDefaultAccount();
    await CategoryRepository(database).initializeDefaults();
    var marketCalls = 0;
    final marketRepository = MarketRepository(
      MarketApiClient(
        baseUrl: 'https://market.example/',
        post: (_, _) async {
          marketCalls++;
          return const MarketHttpResponse(200, '''{
          "data": [{
            "symbol": "BBCA",
            "type": "stock",
            "quote": {
              "symbol": "BBCA",
              "asset_type": "stock",
              "price": 9200,
              "currency": "IDR"
            },
            "error": null
          }]
        }''');
        },
      ),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const AssetsPage()),
        GoRoute(
          path: '/portfolio/assets/:id',
          builder: (_, state) =>
              AssetDetailPage(assetId: int.parse(state.pathParameters['id']!)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          marketRepositoryProvider.overrideWithValue(marketRepository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Belum ada aset investasi'), findsOneWidget);
    expect(marketCalls, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Tambah Aset'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'bbca');
    await tester.enterText(
      find.byType(TextFormField).last,
      'Bank Central Asia',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
    await tester.pumpAndSettle();

    expect(find.text('BBCA'), findsOneWidget);
    expect(find.textContaining('Bank Central Asia'), findsOneWidget);
    expect(find.text('Belum ada aset'), findsNothing);

    await tester.tap(find.text('BBCA'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Aset'), findsOneWidget);
    expect(find.text('Belum ada posisi'), findsAtLeastNWidgets(1));
    await tester.tap(find.widgetWithText(FilledButton, 'Tambah Posisi Awal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '12');
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan Posisi'));
    await tester.pumpAndSettle();
    expect(find.text('12 lot'), findsAtLeastNWidgets(1));
    expect(find.text('1.200 lembar'), findsAtLeastNWidgets(1));

    final editOpeningButton = find.widgetWithText(
      OutlinedButton,
      'Edit Posisi Awal',
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(editOpeningButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '15');
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan Posisi'));
    await tester.pumpAndSettle();
    expect(find.text('15 lot'), findsAtLeastNWidgets(1));
    expect(find.text('27 lot'), findsNothing);

    await tester.tap(find.byTooltip('Hapus Posisi Awal'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada posisi'), findsAtLeastNWidgets(1));
    await tester.tap(find.widgetWithText(FilledButton, 'Tambah Posisi Awal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '12');
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan Posisi'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(marketCalls, 0);
    await tester.tap(find.byTooltip('Refresh Harga'));
    await tester.pumpAndSettle();
    expect(marketCalls, 1);
    expect(find.textContaining('Harga Rp9.200'), findsOneWidget);
    expect(find.textContaining('Nilai Rp11.040.000'), findsOneWidget);

    final card = find.ancestor(
      of: find.text('BBCA'),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(of: card, matching: find.byTooltip('Tindakan aset')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).last,
      'Bank Central Asia Tbk',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bank Central Asia Tbk'), findsOneWidget);

    final editedCard = find.ancestor(
      of: find.text('BBCA'),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(
        of: editedCard,
        matching: find.byTooltip('Tindakan aset'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arsipkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Arsipkan'));
    await tester.pumpAndSettle();
    expect(find.text('Aset Diarsipkan'), findsOneWidget);

    await tester.tap(find.byTooltip('Tindakan aset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aktifkan kembali'));
    await tester.pumpAndSettle();
    expect(find.text('Saham'), findsOneWidget);
    await tester.tap(find.text('BBCA'));
    await tester.pumpAndSettle();
    expect(find.text('12 lot'), findsAtLeastNWidgets(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('portfolio renders a crypto quote and current value', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final asset = await AssetRepository(database).create(
      symbol: 'BTC',
      name: 'Bitcoin',
      assetType: AssetType.crypto,
      pricingMode: AssetPricingMode.api,
    );
    await AssetTransactionRepository(database).create(
      assetId: asset.id,
      action: AssetTransactionAction.buy,
      quantity: AssetQuantity.parse('0.015'),
      transactionDate: DateTime(2026, 9, 4),
    );
    final marketRepository = MarketRepository(
      MarketApiClient(
        baseUrl: 'https://market.example/',
        post: (_, _) async => const MarketHttpResponse(200, '''{
          "data": [{
            "symbol": "BTC",
            "type": "crypto",
            "quote": {
              "symbol": "BTC",
              "asset_type": "crypto",
              "price": 1000000,
              "currency": "IDR"
            },
            "error": null
          }]
        }'''),
      ),
    );
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const AssetsPage())],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          marketRepositoryProvider.overrideWithValue(marketRepository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BTC'), findsOneWidget);
    expect(find.textContaining('Harga belum tersedia'), findsOneWidget);
    await tester.tap(find.byTooltip('Refresh Harga'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Harga Rp1.000.000'), findsOneWidget);
    expect(find.textContaining('Nilai Rp15.000'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'portfolio renders manual fund and gold values without market calls',
    (tester) async {
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
        name: 'Emas',
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
      var marketCalls = 0;
      final marketRepository = MarketRepository(
        MarketApiClient(
          baseUrl: 'https://market.example/',
          post: (_, _) async {
            marketCalls++;
            return const MarketHttpResponse(200, '{"quotes":[]}');
          },
        ),
      );
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const AssetsPage())],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            marketRepositoryProvider.overrideWithValue(marketRepository),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reksadana'), findsOneWidget);
      expect(find.text('Total Portofolio'), findsOneWidget);
      expect(find.text('Rp8.102.778'), findsOneWidget);
      expect(find.text('2 aset aktif'), findsOneWidget);
      expect(find.textContaining('123.4567 unit'), findsOneWidget);
      expect(
        find.textContaining('Nilai per Unit Rp1.845 / unit'),
        findsOneWidget,
      );
      expect(find.textContaining('Nilai Rp227.778'), findsOneWidget);
      expect(find.text('Emas'), findsAtLeastNWidgets(1));
      expect(find.textContaining('5.25 gram'), findsOneWidget);
      expect(
        find.textContaining('Harga per Gram Rp1.500.000 / gram'),
        findsOneWidget,
      );
      expect(find.textContaining('Nilai Rp7.875.000'), findsOneWidget);
      expect(find.text('Manual'), findsNothing);
      expect(marketCalls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
