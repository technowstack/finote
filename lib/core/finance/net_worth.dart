import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/accounts/data/account_repository.dart';
import '../../features/accounts/domain/account_summary.dart';
import '../../features/market/data/portfolio_valuation_service.dart';
import '../../features/market/domain/portfolio_valuation.dart';

enum NetWorthCompleteness { complete, partial }

class NetWorthSnapshot {
  const NetWorthSnapshot({
    required this.cashValue,
    required this.portfolioKnownValue,
    required this.totalKnownValue,
    required this.completeness,
    required this.unvaluedAssetCount,
    required this.integrityIssueCount,
  });

  final int cashValue;
  final int? portfolioKnownValue;
  final int totalKnownValue;
  final NetWorthCompleteness completeness;
  final int unvaluedAssetCount;
  final int integrityIssueCount;

  bool get isComplete => completeness == NetWorthCompleteness.complete;
  bool get isPartial => !isComplete;
}

class NetWorthService {
  const NetWorthService();

  NetWorthSnapshot buildSnapshot(
    List<AccountSummary> accounts,
    PortfolioSnapshot portfolio,
  ) {
    final cash = accounts.fold<int>(0, (total, item) => total + item.balance);
    final portfolioValue = portfolio.isEmpty ? 0 : portfolio.totalKnownValue;
    final partial =
        portfolio.integrityIssueCount > 0 || portfolio.unvaluedAssetCount > 0;
    return NetWorthSnapshot(
      cashValue: cash,
      portfolioKnownValue: portfolioValue,
      totalKnownValue: cash + (portfolioValue ?? 0),
      completeness: partial
          ? NetWorthCompleteness.partial
          : NetWorthCompleteness.complete,
      unvaluedAssetCount: portfolio.unvaluedAssetCount,
      integrityIssueCount: portfolio.integrityIssueCount,
    );
  }
}

final netWorthServiceProvider = Provider<NetWorthService>(
  (ref) => const NetWorthService(),
);

final netWorthProvider = Provider<AsyncValue<NetWorthSnapshot>>((ref) {
  final accounts = ref.watch(accountSummariesProvider);
  final portfolio = ref.watch(portfolioValuationProvider);
  if (accounts.hasError) {
    return AsyncError(accounts.error!, accounts.stackTrace!);
  }
  if (portfolio.hasError) {
    return AsyncError(portfolio.error!, portfolio.stackTrace!);
  }
  if (!accounts.hasValue || !portfolio.hasValue) return const AsyncLoading();
  return AsyncData(
    ref
        .read(netWorthServiceProvider)
        .buildSnapshot(accounts.requireValue, portfolio.requireValue),
  );
});
