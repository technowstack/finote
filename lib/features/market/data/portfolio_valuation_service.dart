import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/data/asset_transaction_repository.dart';
import '../../assets/domain/asset_type.dart';
import '../domain/portfolio_valuation.dart';
import 'asset_price_repository.dart';

class PortfolioValuationService {
  PortfolioSnapshot buildSnapshot(
    List<AssetHolding> holdings,
    Map<int, LocalAssetPrice> prices,
  ) {
    final valuations = <AssetValuation>[];
    final groups = <AssetType, _GroupAccumulator>{};
    var integrityIssueCount = 0;
    var holdingAssetCount = 0;

    for (final holding in holdings) {
      if (!holding.hasActivity) continue;
      final valuation = valueFor(holding, prices[holding.asset.id]);
      valuations.add(valuation);
      if (holding.quantity.isNegative) {
        integrityIssueCount++;
        continue;
      }
      if (holding.quantity.isZero) continue;
      holdingAssetCount++;
      final group = groups.putIfAbsent(
        holding.asset.assetType,
        () => _GroupAccumulator(),
      );
      if (valuation.isValued) {
        group.knownValue += valuation.currentValue!;
        group.valuedAssetCount++;
      } else {
        group.unvaluedAssetCount++;
      }
    }

    return PortfolioSnapshot(
      valuations: valuations,
      groups: {
        for (final entry in groups.entries)
          entry.key: PortfolioGroupSummary(
            knownValue: entry.value.knownValue,
            valuedAssetCount: entry.value.valuedAssetCount,
            unvaluedAssetCount: entry.value.unvaluedAssetCount,
          ),
      },
      holdingAssetCount: holdingAssetCount,
      valuedAssetCount: groups.values.fold<int>(
        0,
        (total, group) => total + group.valuedAssetCount,
      ),
      unvaluedAssetCount: groups.values.fold<int>(
        0,
        (total, group) => total + group.unvaluedAssetCount,
      ),
      integrityIssueCount: integrityIssueCount,
    );
  }

  AssetValuation valueFor(AssetHolding holding, LocalAssetPrice? price) {
    final source = holding.asset.pricingMode == AssetPricingMode.api
        ? ValuationPriceSource.api
        : ValuationPriceSource.manual;
    final usablePrice =
        price != null &&
            price.currency == holding.asset.currency &&
            !holding.quantity.isNegative
        ? price.price
        : null;
    return AssetValuation(
      assetId: holding.asset.id,
      quantity: holding.quantity,
      unitPrice: usablePrice,
      currentValue: usablePrice == null
          ? null
          : _multiply(holding.quantity.scaled, usablePrice),
      pricingSource: source,
      priceUpdatedAt: price?.updatedAt,
      isBackendStale: source == ValuationPriceSource.api
          ? price?.isBackendStale ?? false
          : false,
      hasPrice: usablePrice != null,
    );
  }

  int _multiply(int scaledQuantity, int unitPrice) {
    final product = BigInt.from(scaledQuantity) * BigInt.from(unitPrice);
    final scale = BigInt.from(100000000);
    final quotient = product ~/ scale;
    final remainder = product.remainder(scale);
    final rounded = remainder * BigInt.from(2) >= scale
        ? quotient + BigInt.one
        : quotient;
    if (rounded > BigInt.from(9223372036854775807)) {
      throw RangeError('Asset value is out of range');
    }
    return rounded.toInt();
  }
}

class _GroupAccumulator {
  int knownValue = 0;
  int valuedAssetCount = 0;
  int unvaluedAssetCount = 0;
}

final portfolioValuationServiceProvider = Provider<PortfolioValuationService>(
  (ref) => PortfolioValuationService(),
);

final portfolioValuationProvider = Provider<AsyncValue<PortfolioSnapshot>>((
  ref,
) {
  final holdings = ref.watch(assetHoldingsProvider);
  final prices = ref.watch(activeAssetPricesProvider);
  if (holdings.hasError) {
    return AsyncError(holdings.error!, holdings.stackTrace!);
  }
  if (prices.hasError) {
    return AsyncError(prices.error!, prices.stackTrace!);
  }
  if (!holdings.hasValue || !prices.hasValue) return const AsyncLoading();
  return AsyncData(
    ref
        .read(portfolioValuationServiceProvider)
        .buildSnapshot(holdings.requireValue, prices.requireValue),
  );
});

final assetValuationProvider = Provider.autoDispose
    .family<AsyncValue<AssetValuation?>, int>((ref, assetId) {
      final holding = ref.watch(holdingProvider(assetId));
      final price = ref.watch(currentAssetPriceProvider(assetId));
      if (holding.hasError) {
        return AsyncError(holding.error!, holding.stackTrace!);
      }
      if (price.hasError) return AsyncError(price.error!, price.stackTrace!);
      if (!holding.hasValue || !price.hasValue) return const AsyncLoading();
      final item = holding.requireValue;
      if (item == null || !item.hasActivity) return const AsyncData(null);
      return AsyncData(
        ref
            .read(portfolioValuationServiceProvider)
            .valueFor(item, price.requireValue),
      );
    });
