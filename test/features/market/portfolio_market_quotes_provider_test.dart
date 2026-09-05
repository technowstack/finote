import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/assets/data/asset_repository.dart';
import 'package:finote/features/assets/data/asset_transaction_repository.dart';
import 'package:finote/features/assets/domain/asset_quantity.dart';
import 'package:finote/features/assets/domain/asset_transaction_action.dart';
import 'package:finote/features/assets/domain/asset_type.dart';
import 'package:finote/features/market/data/market_api_client.dart';
import 'package:finote/features/market/data/market_repository.dart';
import 'package:finote/features/market/data/portfolio_market_quotes_provider.dart';
import 'package:finote/features/market/data/asset_price_repository.dart';
import 'package:finote/features/market/domain/market_failure.dart';
import 'package:finote/features/market/domain/market_quote.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'refreshes eligible holdings in one batch without sending quantities',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final assets = AssetRepository(database);
      final activities = AssetTransactionRepository(database);
      final stock = await assets.create(
        symbol: 'BBCA',
        name: 'Bank Central Asia',
        assetType: AssetType.stock,
        pricingMode: AssetPricingMode.api,
      );
      final crypto = await assets.create(
        symbol: 'BTC',
        name: 'Bitcoin',
        assetType: AssetType.crypto,
        pricingMode: AssetPricingMode.api,
      );
      final noPosition = await assets.create(
        symbol: 'BBRI',
        name: 'Bank Rakyat Indonesia',
        assetType: AssetType.stock,
        pricingMode: AssetPricingMode.api,
      );
      final closed = await assets.create(
        symbol: 'BMRI',
        name: 'Bank Mandiri',
        assetType: AssetType.stock,
        pricingMode: AssetPricingMode.api,
      );
      final manual = await assets.create(
        name: 'Gold',
        assetType: AssetType.gold,
        pricingMode: AssetPricingMode.manual,
      );
      final archived = await assets.create(
        symbol: 'ETH',
        name: 'Ethereum',
        assetType: AssetType.crypto,
        pricingMode: AssetPricingMode.api,
      );
      Future<void> buy(int assetId, String quantity) => activities.create(
        assetId: assetId,
        action: AssetTransactionAction.buy,
        quantity: AssetQuantity.parse(quantity),
        transactionDate: DateTime(2026, 9, 3),
      );

      await buy(stock.id, '13');
      await buy(crypto.id, '0.5');
      await activities.createOpeningPosition(
        assetId: closed.id,
        quantity: AssetQuantity.parse('5'),
        transactionDate: DateTime(2026, 9, 1),
      );
      await activities.create(
        assetId: closed.id,
        action: AssetTransactionAction.sell,
        quantity: AssetQuantity.parse('5'),
        transactionDate: DateTime(2026, 9, 2),
      );
      await buy(manual.id, '2');
      await buy(archived.id, '1');
      await assets.archive(archived.id);

      String? requestBody;
      var requestCount = 0;
      final marketRepository = MarketRepository(
        MarketApiClient(
          baseUrl: 'https://market.example/',
          post: (_, body) async {
            requestCount++;
            requestBody = body;
            return const MarketHttpResponse(200, '''{
            "quotes": [
              {"symbol":"BTC","asset_type":"crypto","price":650000000,"currency":"IDR"},
              {"symbol":"BBCA","asset_type":"stock","price":9200,"currency":"IDR"}
            ]
          }''');
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          marketRepositoryProvider.overrideWithValue(marketRepository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(assetHoldingsProvider.future);

      await container.read(portfolioMarketQuotesProvider.notifier).refresh();
      final state = container.read(portfolioMarketQuotesProvider);
      final sent = jsonDecode(requestBody!) as Map<String, dynamic>;
      final sentAssets = (sent['assets'] as List).cast<Map<String, dynamic>>();

      expect(requestCount, 1);
      expect(sentAssets, [
        {'symbol': 'BBCA', 'type': 'stock'},
        {'symbol': 'BTC', 'type': 'crypto'},
      ]);
      expect(sent.keys, {'assets', 'currency'});
      expect(sentAssets.every((asset) => asset.keys.length == 2), isTrue);
      for (final forbidden in [
        'quantity',
        'value',
        'account',
        'transaction',
        'note',
        'net_worth',
      ]) {
        expect(requestBody, isNot(contains(forbidden)));
      }
      expect(state.result.quotes, hasLength(2));
      expect(
        state
            .result
            .quotes[const AssetMarketKey('BBCA', AssetType.stock)]
            ?.price,
        9200,
      );
      expect(
        state
            .result
            .quotes[const AssetMarketKey('BTC', AssetType.crypto)]
            ?.price,
        650000000,
      );
      final cached = await AssetPriceRepository(database)
          .getForAssets([stock.id, crypto.id]);
      expect(cached.values.map((price) => price.price), contains(9200));
      expect(cached.values.map((price) => price.price), contains(650000000));
      expect(state.result.failures, isEmpty);
      expect(noPosition.id, isNot(closed.id));
    },
  );

  test(
    'in-flight refreshes are deduplicated and batch failure preserves quotes',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final assets = AssetRepository(database);
      final activities = AssetTransactionRepository(database);
      final asset = await assets.create(
        symbol: 'BBCA',
        name: 'Bank Central Asia',
        assetType: AssetType.stock,
        pricingMode: AssetPricingMode.api,
      );
      await activities.create(
        assetId: asset.id,
        action: AssetTransactionAction.buy,
        quantity: AssetQuantity.parse('1'),
        transactionDate: DateTime(2026, 9, 3),
      );
      var calls = 0;
      var shouldFail = false;
      final marketRepository = MarketRepository(
        MarketApiClient(
          baseUrl: 'https://market.example/',
          post: (_, _) async {
            calls++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            if (shouldFail) {
              throw const MarketNetworkUnavailable('offline');
            }
            return const MarketHttpResponse(200, '''{
            "quotes": [{"symbol":"BBCA","asset_type":"stock","price":9200,"currency":"IDR"}]
          }''');
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          marketRepositoryProvider.overrideWithValue(marketRepository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(assetHoldingsProvider.future);
      final controller = container.read(portfolioMarketQuotesProvider.notifier);
      await Future.wait([controller.refresh(), controller.refresh()]);
      expect(calls, 1);
      expect(
        container.read(portfolioMarketQuotesProvider).result.quotes,
        hasLength(1),
      );
      shouldFail = true;
      await controller.refresh();
      expect(calls, 2);
      expect(
        container.read(portfolioMarketQuotesProvider).result.quotes,
        hasLength(1),
      );
      expect(
        container.read(portfolioMarketQuotesProvider).failure,
        isA<MarketNetworkUnavailable>(),
      );
    },
  );

  test('disposing an in-flight refresh prevents stale price writes', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final asset = await AssetRepository(database).create(
      symbol: 'BBCA',
      name: 'Bank Central Asia',
      assetType: AssetType.stock,
      pricingMode: AssetPricingMode.api,
    );
    await AssetTransactionRepository(database).createOpeningPosition(
      assetId: asset.id,
      quantity: AssetQuantity.parse('100'),
      transactionDate: DateTime(2026, 9, 1),
    );
    final response = Completer<MarketHttpResponse>();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        marketRepositoryProvider.overrideWithValue(
          MarketRepository(
            MarketApiClient(
              baseUrl: 'https://market.example/',
              post: (_, _) => response.future,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(assetHoldingsProvider.future);
    final refresh = container
        .read(portfolioMarketQuotesProvider.notifier)
        .refresh();
    container.invalidate(portfolioMarketQuotesProvider);
    response.complete(
      const MarketHttpResponse(200, '''{
        "quotes": [{"symbol":"BBCA","asset_type":"stock","price":9000,"currency":"IDR"}]
      }'''),
    );
    await refresh;

    expect(
      await AssetPriceRepository(database).getForAssets([asset.id]),
      isEmpty,
    );
  });

  test(
    'unexpected persistence failure always releases refresh state',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final asset = await AssetRepository(database).create(
        symbol: 'BBCA',
        name: 'Bank Central Asia',
        assetType: AssetType.stock,
        pricingMode: AssetPricingMode.api,
      );
      await AssetTransactionRepository(database).createOpeningPosition(
        assetId: asset.id,
        quantity: AssetQuantity.parse('100'),
        transactionDate: DateTime(2026, 9, 1),
      );
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          assetPriceRepositoryProvider.overrideWithValue(
            _FailingAssetPriceRepository(database),
          ),
          marketRepositoryProvider.overrideWithValue(
            MarketRepository(
              MarketApiClient(
                baseUrl: 'https://market.example/',
                post: (_, _) async {
                  calls++;
                  return const MarketHttpResponse(200, '''{
                  "quotes": [{"symbol":"BBCA","asset_type":"stock","price":9200,"currency":"IDR"}]
                }''');
                },
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(assetHoldingsProvider.future);

      await container.read(portfolioMarketQuotesProvider.notifier).refresh();
      final first = container.read(portfolioMarketQuotesProvider);
      expect(first.isRefreshing, isFalse);
      expect(first.failure, isA<MarketInvalidResponse>());

      await container.read(portfolioMarketQuotesProvider.notifier).refresh();
      expect(calls, 2);
    },
  );
}

class _FailingAssetPriceRepository extends AssetPriceRepository {
  _FailingAssetPriceRepository(super.database);

  @override
  Future<void> saveQuotes(
    Map<int, MarketQuote> quotes, {
    DateTime? fetchedAt,
  }) async {
    throw StateError('synthetic persistence failure');
  }
}
