import '../../assets/domain/asset_quantity.dart';
import '../../assets/domain/asset_type.dart';

enum ValuationPriceSource { api, manual }

class AssetValuation {
  const AssetValuation({
    required this.assetId,
    required this.quantity,
    required this.unitPrice,
    required this.currentValue,
    required this.pricingSource,
    required this.priceUpdatedAt,
    required this.isBackendStale,
    required this.hasPrice,
  });

  final int assetId;
  final AssetQuantity quantity;
  final int? unitPrice;
  final int? currentValue;
  final ValuationPriceSource pricingSource;
  final DateTime? priceUpdatedAt;
  final bool isBackendStale;
  final bool hasPrice;

  bool get isValued => currentValue != null;
}

class PortfolioGroupSummary {
  const PortfolioGroupSummary({
    required this.knownValue,
    required this.valuedAssetCount,
    required this.unvaluedAssetCount,
  });

  final int knownValue;
  final int valuedAssetCount;
  final int unvaluedAssetCount;

  bool get isComplete => unvaluedAssetCount == 0;
}

class PortfolioSnapshot {
  const PortfolioSnapshot({
    required this.valuations,
    required this.groups,
    required this.valuedAssetCount,
    required this.unvaluedAssetCount,
    required this.integrityIssueCount,
  });

  final List<AssetValuation> valuations;
  final Map<AssetType, PortfolioGroupSummary> groups;
  final int valuedAssetCount;
  final int unvaluedAssetCount;
  final int integrityIssueCount;

  int? get totalKnownValue => valuedAssetCount == 0
      ? null
      : valuations.fold<int>(
          0,
          (total, item) => total + (item.currentValue ?? 0),
        );

  bool get isEmpty => valuations.isEmpty;
  bool get isComplete => !isEmpty && unvaluedAssetCount == 0;
  bool get isPartial => valuedAssetCount > 0 && unvaluedAssetCount > 0;
  bool get isUnavailable => !isEmpty && valuedAssetCount == 0;

  Map<int, AssetValuation> get byAssetId => {
    for (final valuation in valuations) valuation.assetId: valuation,
  };
}
