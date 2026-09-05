import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/core/finance/net_worth.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/assets/data/asset_repository.dart';
import 'package:finote/features/assets/data/asset_transaction_repository.dart';
import 'package:finote/features/assets/domain/asset_quantity.dart';
import 'package:finote/features/assets/domain/asset_transaction_action.dart';
import 'package:finote/features/assets/domain/asset_type.dart';
import 'package:finote/features/assets/presentation/assets_page.dart';
import 'package:finote/features/market/data/asset_price_repository.dart';
import 'package:finote/features/market/data/market_api_client.dart';
import 'package:finote/features/market/data/market_repository.dart';
import 'package:finote/features/market/data/portfolio_market_quotes_provider.dart';
import 'package:finote/features/market/data/portfolio_valuation_service.dart';
import 'package:finote/features/market/domain/market_quote.dart';
import 'package:finote/features/transactions/domain/transaction_source.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local Portfolio scales across 10, 25, 50, and 100 assets', () async {
    for (final count in [10, 25, 50, 100]) {
      final database = AppDatabase(NativeDatabase.memory());
      try {
        await _seedAssets(database, count);
        final stopwatch = Stopwatch()..start();
        final holdings = await AssetTransactionRepository(database)
            .watchHoldings()
            .first;
        final prices = await AssetPriceRepository(database).watchActive().first;
        final snapshot = PortfolioValuationService().buildSnapshot(
          holdings,
          prices,
        );
        stopwatch.stop();

        expect(holdings, hasLength(count));
        expect(snapshot.holdingAssetCount, count);
        expect(snapshot.totalKnownValue, isNot(equals(null)));
        // Informational only: debug timing is not a release threshold.
        // ignore: avoid_print
        print(
          'PORTFOLIO PERF $count assets: ${stopwatch.elapsedMilliseconds}ms, '
          'prices=${prices.length}, unvalued=${snapshot.unvaluedAssetCount}',
        );
        expect(snapshot.unvaluedAssetCount, (count + 9) ~/ 10);
      } finally {
        await database.close();
      }
    }
  });

  test('50 assets stay independent from 5,000 cashflow rows', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final account = await database.select(database.accounts).getSingle();
    final category = await database
        .into(database.categories)
        .insertReturning(
          CategoriesCompanion.insert(
            name: 'Performance',
            type: TransactionType.expense,
          ),
        );
    await database.batch((batch) {
      batch.insertAll(
        database.transactions,
        List.generate(
          5000,
          (index) => TransactionsCompanion.insert(
            type: TransactionType.expense,
            accountId: Value(account.id),
            categoryId: category.id,
            amount: 1000 + index,
            transactionDate: DateTime(2026, 1, 1 + index % 365),
            source: TransactionSource.manual,
          ),
        ),
      );
    });
    await _seedAssets(database, 50);

    final holdings = await AssetTransactionRepository(database)
        .watchHoldings()
        .first;
    final plan = await database.customSelect('''
EXPLAIN QUERY PLAN
SELECT a.id, COALESCE(SUM(at.quantity_scaled), 0)
FROM assets a
LEFT JOIN asset_transactions at
  ON at.asset_id = a.id AND at.deleted_at IS NULL
WHERE a.is_active = 1
GROUP BY a.id
''').get();
    final details = plan.map((row) => row.read<String>('detail')).join(' | ');

    expect(holdings, hasLength(50));
    expect(details, contains('asset_transactions_asset_id'));
    expect(details, isNot(contains('SCAN transactions')));
    expect(details, isNot(contains('SEARCH transactions')));
  });

  test(
    '30 market holdings use one request and one settled local emission',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _seedMarketAssets(database, stocks: 20, crypto: 10);
      var calls = 0;
      var sentAssets = 0;
      final repository = MarketRepository(
        MarketApiClient(
          baseUrl: 'https://market.example/',
          post: (_, body) async {
            calls++;
            final request = jsonDecode(body) as Map<String, dynamic>;
            final assets = request['assets'] as List<dynamic>;
            sentAssets = assets.length;
            return MarketHttpResponse(
              200,
              jsonEncode({
                'quotes': [
                  for (final item in assets.cast<Map<String, dynamic>>())
                    {
                      'symbol': item['symbol'],
                      'asset_type': item['type'],
                      'price': 10000,
                      'currency': 'IDR',
                    },
                ],
              }),
            );
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          marketRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      var portfolioEmissions = 0;
      var netWorthEmissions = 0;
      final portfolioSubscription = container.listen(
        portfolioValuationProvider,
        (_, _) => portfolioEmissions++,
        fireImmediately: true,
      );
      final netWorthSubscription = container.listen(
        netWorthProvider,
        (_, _) => netWorthEmissions++,
        fireImmediately: true,
      );
      addTearDown(portfolioSubscription.close);
      addTearDown(netWorthSubscription.close);
      await container.read(assetHoldingsProvider.future);
      await container.read(activeAssetPricesProvider.future);
      await container.read(accountSummariesProvider.future);
      await Future<void>.delayed(Duration.zero);
      final portfolioBeforeRefresh = portfolioEmissions;
      final netWorthBeforeRefresh = netWorthEmissions;
      var priceEmissions = 0;
      final subscription = container.listen(activeAssetPricesProvider, (_, _) {
        priceEmissions++;
      });
      addTearDown(subscription.close);

      final controller = container.read(portfolioMarketQuotesProvider.notifier);
      await Future.wait([controller.refresh(), controller.refresh()]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final settledEmissions = priceEmissions;
      final settledPortfolioEmissions = portfolioEmissions;
      final settledNetWorthEmissions = netWorthEmissions;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(calls, 1);
      expect(sentAssets, 30);
      expect(settledEmissions, lessThanOrEqualTo(1));
      expect(priceEmissions, settledEmissions);
      expect(
        settledPortfolioEmissions - portfolioBeforeRefresh,
        lessThanOrEqualTo(1),
      );
      expect(
        settledNetWorthEmissions - netWorthBeforeRefresh,
        lessThanOrEqualTo(1),
      );
      expect(portfolioEmissions, settledPortfolioEmissions);
      expect(netWorthEmissions, settledNetWorthEmissions);
      expect(
        await AssetPriceRepository(database)
            .getForAssets(List.generate(30, (index) => index + 1)),
        hasLength(30),
      );
    },
  );

  test('detail provider reacts, settles, and releases family state', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = AssetRepository(database);
    final asset = await repository.create(
      symbol: 'BBCA',
      name: 'Bank Central Asia',
      assetType: AssetType.stock,
      pricingMode: AssetPricingMode.api,
    );
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    final provider = assetByIdProvider(asset.id);
    final updated = Completer<AssetRecord>();
    var emissions = 0;
    final subscription = container.listen(provider, (_, next) {
      emissions++;
      final value = next.valueOrNull;
      if (value?.pricingMode == AssetPricingMode.manual &&
          !updated.isCompleted) {
        updated.complete(value);
      }
    }, fireImmediately: true);
    await container.read(provider.future);

    await repository.update(
      id: asset.id,
      symbol: asset.symbol,
      name: asset.name,
      assetType: asset.assetType,
      pricingMode: AssetPricingMode.manual,
    );
    expect(
      (await updated.future.timeout(const Duration(seconds: 2))).pricingMode,
      AssetPricingMode.manual,
    );
    final settledEmissions = emissions;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(emissions, settledEmissions);

    subscription.close();
    await Future<void>.delayed(Duration.zero);
    expect(container.exists(provider), isFalse);
  });

  test(
    'Asset Detail query handles 5,000 activities without global reads',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final asset = await AssetRepository(database).create(
        name: 'Activity Stress',
        assetType: AssetType.other,
        pricingMode: AssetPricingMode.manual,
      );
      await database.batch((batch) {
        batch.insertAll(
          database.assetTransactions,
          List.generate(
            5000,
            (index) => AssetTransactionsCompanion.insert(
              assetId: asset.id,
              action: AssetTransactionAction.adjustment,
              quantityScaled: 1,
              transactionDate: DateTime(2020, 1, 1 + index % 2000),
            ),
          ),
        );
      });

      final stopwatch = Stopwatch()..start();
      final activities = await AssetTransactionRepository(database)
          .watchByAsset(asset.id)
          .first;
      stopwatch.stop();
      final plan = await database
          .customSelect(
            '''
EXPLAIN QUERY PLAN
SELECT * FROM asset_transactions
WHERE asset_id = ? AND deleted_at IS NULL
ORDER BY transaction_date DESC, created_at DESC, id DESC
''',
            variables: [Variable.withInt(asset.id)],
          )
          .get();
      final details = plan.map((row) => row.read<String>('detail')).join(' | ');

      expect(activities, hasLength(5000));
      expect(details, contains('asset_transactions_asset_id'));
      // Informational only: detail history is not loaded by Portfolio root.
      // ignore: avoid_print
      print(
        'ASSET DETAIL PERF 5000 activities: ${stopwatch.elapsedMilliseconds}ms',
      );
    },
  );

  testWidgets('Portfolio paints 100 local assets without a market request', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedAssets(database, 100);
    var marketCalls = 0;
    final repository = MarketRepository(
      MarketApiClient(
        baseUrl: 'https://market.example/',
        post: (_, _) async {
          marketCalls++;
          return const MarketHttpResponse(200, '{"quotes":[]}');
        },
      ),
    );

    final stopwatch = Stopwatch()..start();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          marketRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: AssetsPage()),
      ),
    );
    await tester.pumpAndSettle();
    stopwatch.stop();

    expect(find.text('Portofolio'), findsOneWidget);
    expect(find.text('S0'), findsOneWidget);
    expect(marketCalls, 0);
    // Includes Flutter test harness startup and is not a profile-mode metric.
    // ignore: avoid_print
    print('PORTFOLIO WIDGET 100 assets: ${stopwatch.elapsedMilliseconds}ms');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Future<void> _seedAssets(AppDatabase database, int count) async {
  final assets = AssetRepository(database);
  final activities = AssetTransactionRepository(database);
  final prices = AssetPriceRepository(database);
  final quotes = <int, MarketQuote>{};
  for (var index = 0; index < count; index++) {
    final type = AssetType.values[index % AssetType.values.length];
    final market = type == AssetType.stock || type == AssetType.crypto;
    final asset = await assets.create(
      symbol: market ? '${type == AssetType.stock ? 'S' : 'C'}$index' : null,
      name: 'Asset $index',
      assetType: type,
      pricingMode: market ? AssetPricingMode.api : AssetPricingMode.manual,
    );
    await activities.create(
      assetId: asset.id,
      action: AssetTransactionAction.openingPosition,
      quantity: AssetQuantity.parse(switch (type) {
        AssetType.stock => '1300',
        AssetType.crypto => '0.012125',
        AssetType.gold => '5.25',
        _ => '10',
      }),
      transactionDate: DateTime(2026, 9, 5),
    );
    if (index % 10 == 0) continue;
    if (market) {
      quotes[asset.id] = MarketQuote(
        symbol: asset.symbol!,
        name: null,
        assetType: type,
        price: type == AssetType.stock ? 9200 : 1000000000,
        currency: 'IDR',
        change: null,
        changePercent: null,
        marketStatus: MarketStatus.unknown,
        isStale: index.isEven,
        updatedAt: DateTime.utc(2026, 9, 5),
      );
    } else {
      await prices.setManualPrice(assetId: asset.id, price: 1500000);
    }
  }
  await prices.saveQuotes(quotes);
}

Future<void> _seedMarketAssets(
  AppDatabase database, {
  required int stocks,
  required int crypto,
}) async {
  final assets = AssetRepository(database);
  final activities = AssetTransactionRepository(database);
  for (var index = 0; index < stocks + crypto; index++) {
    final type = index < stocks ? AssetType.stock : AssetType.crypto;
    final asset = await assets.create(
      symbol: '${type == AssetType.stock ? 'STK' : 'CRY'}$index',
      name: 'Market Asset $index',
      assetType: type,
      pricingMode: AssetPricingMode.api,
    );
    await activities.createOpeningPosition(
      assetId: asset.id,
      quantity: AssetQuantity.parse('1'),
      transactionDate: DateTime(2026, 9, 5),
    );
  }
}
