import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../assets/domain/asset_type.dart';
import '../domain/market_failure.dart';
import '../domain/market_quote.dart';
import 'market_api_client.dart';

class MarketRepository {
  MarketRepository(this._client);

  final MarketApiClient _client;

  Future<MarketQuote> getQuote({
    required String symbol,
    required AssetType assetType,
    String currency = 'IDR',
  }) async {
    if (assetType != AssetType.stock && assetType != AssetType.crypto) {
      throw const MarketUnsupportedAsset(
        'Jenis aset ini menggunakan harga manual.',
      );
    }
    final normalizedSymbol = symbol.trim().toUpperCase();
    if (normalizedSymbol.isEmpty) {
      throw const MarketInvalidResponse('Symbol market tidak boleh kosong.');
    }
    final json = await _client.getQuoteJson(
      symbol: normalizedSymbol,
      assetType: assetType.databaseValue,
      currency: currency,
    );
    return _parseQuote(json);
  }

  Future<BatchQuoteResult> getQuotes(
    List<MarketQuoteRequest> requests, {
    String currency = 'IDR',
  }) async {
    final unique = <AssetMarketKey, MarketQuoteRequest>{};
    for (final request in requests) {
      if (request.assetType == AssetType.stock ||
          request.assetType == AssetType.crypto) {
        if (request.symbol.isNotEmpty) unique[request.key] = request;
      }
    }
    if (unique.isEmpty) return const BatchQuoteResult.empty();
    final json = await _client.getBatchQuotesJson(
      assets: [
        for (final request in unique.values)
          MarketQuoteRequestPayload(
            symbol: request.symbol,
            assetType: request.assetType.databaseValue,
          ),
      ],
      currency: currency,
    );
    final quoteItems =
        _listField(json, 'quotes') ??
        _listField(json, 'results') ??
        _dataList(json);
    if (quoteItems == null) {
      throw const MarketInvalidResponse('Respons batch market tidak valid.');
    }
    final quotes = <AssetMarketKey, MarketQuote>{};
    final failures = <AssetMarketKey, MarketQuoteFailure>{};
    for (final item in quoteItems) {
      if (item is! Map) continue;
      final itemJson = item.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
      final symbol = itemJson['symbol'];
      final type = _assetType(itemJson['asset_type'] ?? itemJson['type']);
      final error = itemJson['error'];
      if (error is Map && symbol is String && type != null) {
        final key = AssetMarketKey(symbol.trim().toUpperCase(), type);
        failures[key] = MarketQuoteFailure(
          key: key,
          message: error['message'] is String
              ? error['message'] as String
              : 'Harga belum tersedia.',
        );
        continue;
      }
      final nestedQuote = itemJson['quote'];
      if (nestedQuote is Map) {
        itemJson.addAll(
          nestedQuote.map<String, dynamic>(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );
      }
      if (itemJson['asset_type'] == null && type != null) {
        itemJson['asset_type'] = type.databaseValue;
      }
      if (itemJson['symbol'] == null && symbol is String) {
        itemJson['symbol'] = symbol;
      }
      try {
        final quote = _parseQuote(itemJson);
        quotes[AssetMarketKey(quote.symbol, quote.assetType)] = quote;
      } on MarketFailure {
        // An invalid item is unavailable without invalidating valid siblings.
      }
    }
    final responseFailures = _listField(json, 'failures');
    if (responseFailures != null) {
      for (final item in responseFailures) {
        if (item is! Map) continue;
        final symbol = item['symbol'];
        final type = _assetType(item['asset_type'] ?? item['type']);
        if (symbol is String && type != null) {
          final key = AssetMarketKey(symbol.trim().toUpperCase(), type);
          failures[key] = MarketQuoteFailure(
            key: key,
            message: item['message'] is String
                ? item['message'] as String
                : 'Harga belum tersedia.',
          );
        }
      }
    }
    for (final request in unique.values) {
      if (!quotes.containsKey(request.key) &&
          !failures.containsKey(request.key)) {
        failures[request.key] = MarketQuoteFailure(
          key: request.key,
          message: 'Harga belum tersedia.',
        );
      }
    }
    return BatchQuoteResult(quotes: quotes, failures: failures);
  }

  MarketQuote _parseQuote(Map<String, dynamic> json) {
    final symbol = _requiredString(json, 'symbol');
    final assetType = switch (_requiredString(json, 'asset_type')) {
      'stock' => AssetType.stock,
      'crypto' => AssetType.crypto,
      _ => throw const MarketUnsupportedAsset(
        'Jenis aset market tidak didukung.',
      ),
    };
    final price = _requiredInteger(json, 'price');
    if (price < 0) {
      throw const MarketInvalidResponse('Harga market tidak valid.');
    }
    final currency = _requiredString(json, 'currency').toUpperCase();
    return MarketQuote(
      symbol: symbol.trim().toUpperCase(),
      name: _optionalString(json, 'name'),
      assetType: assetType,
      price: price,
      currency: currency,
      change: _optionalInteger(json, 'change'),
      changePercent: _optionalDouble(json, 'change_percent'),
      marketStatus: MarketStatusLabel.fromApi(
        _optionalString(json, 'market_status'),
      ),
      isStale: _optionalBool(json, 'is_stale') ?? false,
      updatedAt: _optionalDateTime(json, 'updated_at'),
    );
  }

  AssetType? _assetType(Object? value) => switch (value) {
    'stock' => AssetType.stock,
    'crypto' => AssetType.crypto,
    _ => null,
  };

  List<Object?>? _listField(Map<String, dynamic> json, String key) =>
      json[key] is List ? (json[key] as List).cast<Object?>() : null;

  List<Object?>? _dataList(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is List) return data.cast<Object?>();
    if (data is Map) {
      return _listField(
        data.map<String, dynamic>(
          (key, value) => MapEntry(key.toString(), value),
        ),
        'quotes',
      );
    }
    return null;
  }

  String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw MarketInvalidResponse('Respons Market API tidak memiliki $key.');
    }
    return value;
  }

  int _requiredInteger(Map<String, dynamic> json, String key) {
    final value = _integer(json[key]);
    if (value == null) {
      throw MarketInvalidResponse('Respons Market API tidak memiliki $key.');
    }
    return value;
  }

  int? _optionalInteger(Map<String, dynamic> json, String key) =>
      json[key] == null ? null : _integer(json[key]);

  int? _integer(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.round()) {
      return value.toInt();
    }
    return null;
  }

  double? _optionalDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is num && value.isFinite) return value.toDouble();
    return null;
  }

  String? _optionalString(Map<String, dynamic> json, String key) =>
      json[key] is String ? json[key] as String : null;

  bool? _optionalBool(Map<String, dynamic> json, String key) =>
      json[key] is bool ? json[key] as bool : null;

  DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
    final value = _optionalString(json, key);
    return value == null ? null : DateTime.tryParse(value)?.toUtc();
  }
}

final marketApiClientProvider = Provider<MarketApiClient>(
  (ref) => MarketApiClient(baseUrl: AppConfig.marketApiBaseUrl),
);

final marketRepositoryProvider = Provider<MarketRepository>(
  (ref) => MarketRepository(ref.watch(marketApiClientProvider)),
);
