import 'dart:io';

import 'package:finote/features/assets/domain/asset_type.dart';
import 'package:finote/features/market/data/market_api_client.dart';
import 'package:finote/features/market/data/market_repository.dart';
import 'package:finote/features/market/domain/market_failure.dart';
import 'package:finote/features/market/domain/market_quote.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MarketApiClient client(
    String body, {
    int statusCode = 200,
    Duration timeout = const Duration(seconds: 1),
    void Function(Uri)? onRequest,
  }) {
    return MarketApiClient(
      baseUrl: 'https://market.example/',
      requestTimeout: timeout,
      request: (uri) async {
        onRequest?.call(uri);
        return MarketHttpResponse(statusCode, body);
      },
    );
  }

  const stockResponse = '''{
    "symbol": "BBCA",
    "name": "Bank Central Asia Tbk",
    "asset_type": "stock",
    "price": 9200,
    "currency": "IDR",
    "change": 100,
    "change_percent": 1.10,
    "market_status": "closed",
    "is_stale": false,
    "updated_at": "2026-09-03T10:00:00Z"
  }''';

  test('maps stock quote and preserves normalized request symbol', () async {
    Uri? requested;
    final repository = MarketRepository(
      client(stockResponse, onRequest: (uri) => requested = uri),
    );

    final quote = await repository.getQuote(
      symbol: ' bbca ',
      assetType: AssetType.stock,
    );

    expect(quote.symbol, 'BBCA');
    expect(quote.name, 'Bank Central Asia Tbk');
    expect(quote.assetType, AssetType.stock);
    expect(quote.price, 9200);
    expect(quote.change, 100);
    expect(quote.changePercent, 1.10);
    expect(quote.marketStatus, MarketStatus.closed);
    expect(quote.isStale, isFalse);
    expect(quote.updatedAt, DateTime.utc(2026, 9, 3, 10));
    expect(requested?.path, '/api/v1/assets/BBCA');
    expect(requested?.queryParameters, {'type': 'stock', 'currency': 'IDR'});
    expect(requested?.path, isNot(contains('.JK')));
  });

  test('maps crypto quote and preserves stale metadata', () async {
    final repository = MarketRepository(
      MarketApiClient(
        baseUrl: 'https://market.example/',
        request: (uri) async => const MarketHttpResponse(200, '''{
          "symbol":"BTC", "asset_type":"crypto", "price":650000000,
          "currency":"IDR", "is_stale":true, "market_status":"open"
        }'''),
      ),
    );

    final quote = await repository.getQuote(
      symbol: 'BTC',
      assetType: AssetType.crypto,
    );

    expect(quote.assetType, AssetType.crypto);
    expect(quote.price, 650000000);
    expect(quote.isStale, isTrue);
    expect(quote.marketStatus, MarketStatus.open);
  });

  test('rejects zero price without accepting malformed market data', () async {
    final repository = MarketRepository(
      client('''{
        "symbol":"BTC", "asset_type":"crypto", "price":0,
        "currency":"IDR", "updated_at":"not-a-date"
      }'''),
    );

    await expectLater(
      repository.getQuote(symbol: 'BTC', assetType: AssetType.crypto),
      throwsA(isA<MarketInvalidResponse>()),
    );
  });

  test('manual asset is rejected before network request', () async {
    var called = false;
    final repository = MarketRepository(
      client(stockResponse, onRequest: (_) => called = true),
    );

    await expectLater(
      repository.getQuote(symbol: 'GOLD', assetType: AssetType.gold),
      throwsA(isA<MarketUnsupportedAsset>()),
    );
    expect(called, isFalse);
  });

  test('maps HTTP and transport failures to safe domain failures', () async {
    await expectLater(
      MarketRepository(client('', statusCode: 404))
          .getQuote(symbol: 'UNKNOWN', assetType: AssetType.stock),
      throwsA(isA<MarketNotFound>()),
    );
    await expectLater(
      MarketRepository(client('', statusCode: 500))
          .getQuote(symbol: 'BBCA', assetType: AssetType.stock),
      throwsA(isA<MarketServerError>()),
    );
    await expectLater(
      MarketRepository(
        MarketApiClient(
          baseUrl: 'https://market.example/',
          request: (_) async => throw const SocketException('offline'),
        ),
      ).getQuote(symbol: 'BBCA', assetType: AssetType.stock),
      throwsA(isA<MarketNetworkUnavailable>()),
    );
  });

  test('maps timeout and malformed responses safely', () async {
    final timeoutClient = MarketApiClient(
      baseUrl: 'https://market.example/',
      requestTimeout: const Duration(milliseconds: 1),
      request: (_) => Future<MarketHttpResponse>.delayed(
        const Duration(milliseconds: 50),
        () => const MarketHttpResponse(200, '{}'),
      ),
    );
    await expectLater(
      MarketRepository(timeoutClient)
          .getQuote(symbol: 'BBCA', assetType: AssetType.stock),
      throwsA(isA<MarketTimeout>()),
    );

    await expectLater(
      MarketRepository(client('not-json'))
          .getQuote(symbol: 'BBCA', assetType: AssetType.stock),
      throwsA(isA<MarketInvalidResponse>()),
    );
    await expectLater(
      MarketRepository(
        client('{"symbol":"BBCA","asset_type":"stock","currency":"IDR"}'),
      ).getQuote(symbol: 'BBCA', assetType: AssetType.stock),
      throwsA(isA<MarketInvalidResponse>()),
    );
    await expectLater(
      MarketRepository(
        client(
          '{"symbol":"BBCA","asset_type":"stock","price":-1,"currency":"IDR"}',
        ),
      ).getQuote(symbol: 'BBCA', assetType: AssetType.stock),
      throwsA(isA<MarketInvalidResponse>()),
    );
  });

  test(
    'sends one normalized batch request and maps response order by key',
    () async {
      String? body;
      final repository = MarketRepository(
        MarketApiClient(
          baseUrl: 'https://market.example/',
          post: (uri, requestBody) async {
            body = requestBody;
            return const MarketHttpResponse(200, '''{
            "quotes": [
              {"symbol":"BTC","asset_type":"crypto","price":650000000,"currency":"IDR"},
              {"symbol":"BBCA","asset_type":"stock","price":9200,"currency":"IDR"}
            ]
          }''');
          },
        ),
      );

      final result = await repository.getQuotes([
        MarketQuoteRequest(symbol: 'bbca', assetType: AssetType.stock),
        MarketQuoteRequest(symbol: 'BTC', assetType: AssetType.crypto),
        MarketQuoteRequest(symbol: 'BBCA', assetType: AssetType.stock),
        MarketQuoteRequest(symbol: 'GOLD', assetType: AssetType.gold),
      ]);

      expect(
        result.quotes[const AssetMarketKey('BBCA', AssetType.stock)]?.price,
        9200,
      );
      expect(
        result.quotes[const AssetMarketKey('BTC', AssetType.crypto)]?.price,
        650000000,
      );
      expect(result.failures, isEmpty);
      expect(body, contains('"currency":"IDR"'));
      expect(body, contains('"symbol":"BBCA"'));
      expect(body, contains('"type":"stock"'));
      expect(body, isNot(contains('GOLD')));
      expect(body, isNot(contains('.JK')));
    },
  );

  test(
    'returns partial success and marks missing quotes unavailable',
    () async {
      final repository = MarketRepository(
        MarketApiClient(
          baseUrl: 'https://market.example/',
          post: (_, _) async => const MarketHttpResponse(200, '''{
          "data": {"quotes": [
            {"symbol":"BBCA","asset_type":"stock","price":9200,"currency":"IDR"}
          ]},
          "failures": [{"symbol":"BTC","type":"crypto","message":"Provider unavailable"}]
        }'''),
        ),
      );

      final result = await repository.getQuotes([
        MarketQuoteRequest(symbol: 'BBCA', assetType: AssetType.stock),
        MarketQuoteRequest(symbol: 'BTC', assetType: AssetType.crypto),
      ]);

      expect(result.quotes, hasLength(1));
      expect(
        result.failures[const AssetMarketKey('BTC', AssetType.crypto)]?.message,
        'Provider unavailable',
      );
      expect(
        result.quotes.containsKey(
          const AssetMarketKey('BTC', AssetType.crypto),
        ),
        isFalse,
      );
    },
  );

  test('maps the deployed nested batch response', () async {
    final repository = MarketRepository(
      MarketApiClient(
        baseUrl: 'https://market.example/',
        post: (_, _) async => const MarketHttpResponse(200, '''{
          "data": [{
            "symbol": "BBCA",
            "type": "stock",
            "quote": {
              "price": 9200,
              "currency": "IDR",
              "market_status": "closed"
            }
          }]
        }'''),
      ),
    );

    final result = await repository.getQuotes([
      MarketQuoteRequest(symbol: 'BBCA', assetType: AssetType.stock),
    ]);

    expect(
      result.quotes[const AssetMarketKey('BBCA', AssetType.stock)]?.price,
      9200,
    );
    expect(result.failures, isEmpty);
  });

  test('maps deployed provider failure items', () async {
    final repository = MarketRepository(
      MarketApiClient(
        baseUrl: 'https://market.example/',
        post: (_, _) async => const MarketHttpResponse(200, '''{
          "data": [{
            "symbol": "BBCA",
            "type": "stock",
            "quote": null,
            "error": {"message": "Too Many Requests"}
          }]
        }'''),
      ),
    );

    final result = await repository.getQuotes([
      MarketQuoteRequest(symbol: 'BBCA', assetType: AssetType.stock),
    ]);

    expect(
      result.failures[const AssetMarketKey('BBCA', AssetType.stock)]?.message,
      'Too Many Requests',
    );
    expect(result.quotes, isEmpty);
  });

  test('does not send an empty batch', () async {
    var called = false;
    final repository = MarketRepository(
      MarketApiClient(
        baseUrl: 'https://market.example/',
        post: (_, _) async {
          called = true;
          return const MarketHttpResponse(200, '{}');
        },
      ),
    );

    final result = await repository.getQuotes([
      MarketQuoteRequest(symbol: 'GOLD', assetType: AssetType.gold),
    ]);
    expect(result.quotes, isEmpty);
    expect(called, isFalse);
  });
}
