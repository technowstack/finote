import '../../assets/domain/asset_type.dart';

enum MarketStatus { open, closed, unknown }

extension MarketStatusLabel on MarketStatus {
  static MarketStatus fromApi(String? value) => switch (value?.toLowerCase()) {
    'open' => MarketStatus.open,
    'closed' => MarketStatus.closed,
    _ => MarketStatus.unknown,
  };
}

class MarketQuote {
  const MarketQuote({
    required this.symbol,
    required this.name,
    required this.assetType,
    required this.price,
    required this.currency,
    required this.change,
    required this.changePercent,
    required this.marketStatus,
    required this.isStale,
    required this.updatedAt,
  });

  final String symbol;
  final String? name;
  final AssetType assetType;
  final int price;
  final String currency;
  final int? change;
  final double? changePercent;
  final MarketStatus marketStatus;
  final bool isStale;
  final DateTime? updatedAt;
}

class MarketQuoteRequest {
  MarketQuoteRequest({required String symbol, required this.assetType})
    : symbol = symbol.trim().toUpperCase();

  final String symbol;
  final AssetType assetType;

  AssetMarketKey get key => AssetMarketKey(symbol, assetType);
}

class AssetMarketKey {
  const AssetMarketKey(this.symbol, this.assetType);

  final String symbol;
  final AssetType assetType;

  @override
  bool operator ==(Object other) =>
      other is AssetMarketKey &&
      other.symbol == symbol &&
      other.assetType == assetType;

  @override
  int get hashCode => Object.hash(symbol, assetType);
}

class MarketQuoteFailure {
  const MarketQuoteFailure({required this.key, required this.message});

  final AssetMarketKey key;
  final String message;
}

class BatchQuoteResult {
  const BatchQuoteResult({required this.quotes, required this.failures});

  const BatchQuoteResult.empty() : quotes = const {}, failures = const {};

  final Map<AssetMarketKey, MarketQuote> quotes;
  final Map<AssetMarketKey, MarketQuoteFailure> failures;
}
