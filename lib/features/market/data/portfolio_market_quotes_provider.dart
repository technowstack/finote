import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/data/asset_transaction_repository.dart';
import '../../assets/domain/asset_type.dart';
import '../domain/market_failure.dart';
import '../domain/market_quote.dart';
import 'asset_price_repository.dart';
import 'market_repository.dart';

class PortfolioMarketQuoteState {
  const PortfolioMarketQuoteState({
    required this.result,
    this.isRefreshing = false,
    this.failure,
  });

  const PortfolioMarketQuoteState.initial()
    : result = const BatchQuoteResult.empty(),
      isRefreshing = false,
      failure = null;

  final BatchQuoteResult result;
  final bool isRefreshing;
  final MarketFailure? failure;

  PortfolioMarketQuoteState copyWith({
    BatchQuoteResult? result,
    bool? isRefreshing,
    MarketFailure? failure,
    bool clearFailure = false,
  }) {
    return PortfolioMarketQuoteState(
      result: result ?? this.result,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

class PortfolioMarketQuotesController
    extends StateNotifier<PortfolioMarketQuoteState> {
  PortfolioMarketQuotesController(this._ref)
    : super(const PortfolioMarketQuoteState.initial());

  final Ref _ref;
  bool _inFlight = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> refresh() async {
    if (_inFlight) return;
    final holdings = _ref.read(assetHoldingsProvider).valueOrNull;
    if (holdings == null) return;

    final requests = <MarketQuoteRequest>[];
    final keys = <AssetMarketKey>{};
    final assetIdsByKey = <AssetMarketKey, int>{};
    for (final holding in holdings) {
      final asset = holding.asset;
      if (!holding.hasActivity ||
          holding.quantity.isNegative ||
          holding.quantity.isZero ||
          asset.pricingMode != AssetPricingMode.api ||
          (asset.assetType != AssetType.stock &&
              asset.assetType != AssetType.crypto) ||
          asset.symbol == null ||
          asset.symbol!.trim().isEmpty) {
        continue;
      }
      final request = MarketQuoteRequest(
        symbol: asset.symbol!,
        assetType: asset.assetType,
      );
      if (keys.add(request.key)) {
        requests.add(request);
        assetIdsByKey[request.key] = asset.id;
      }
    }

    if (requests.isEmpty) {
      state = state.copyWith(
        result: const BatchQuoteResult.empty(),
        isRefreshing: false,
        clearFailure: true,
      );
      return;
    }

    _inFlight = true;
    state = state.copyWith(isRefreshing: true, clearFailure: true);
    try {
      final result = await _ref
          .read(marketRepositoryProvider)
          .getQuotes(requests);
      if (_disposed) return;
      await _ref.read(assetPriceRepositoryProvider).saveQuotes({
        for (final entry in result.quotes.entries)
          if (assetIdsByKey[entry.key] != null)
            assetIdsByKey[entry.key]!: entry.value,
      });
      if (_disposed) return;
      state = PortfolioMarketQuoteState(result: result);
    } on MarketFailure catch (error) {
      if (_disposed) return;
      // Keep the last successful quotes when a refresh fails.
      state = state.copyWith(isRefreshing: false, failure: error);
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(
        isRefreshing: false,
        failure: const MarketInvalidResponse(
          'Harga terbaru belum dapat disimpan.',
        ),
      );
    } finally {
      _inFlight = false;
    }
  }
}

final portfolioMarketQuotesProvider =
    StateNotifierProvider<
      PortfolioMarketQuotesController,
      PortfolioMarketQuoteState
    >((ref) => PortfolioMarketQuotesController(ref));
