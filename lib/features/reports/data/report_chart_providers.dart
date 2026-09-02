import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/data/account_repository.dart';
import '../domain/report_chart_data.dart';
import 'report_repository.dart';

final financialTrendProvider = StreamProvider.autoDispose
    .family<List<FinancialTrendPoint>, ReportRange>(
      (ref, range) =>
          ref.watch(reportRepositoryProvider).watchFinancialTrend(range),
    );

final expenseCategoryChartProvider = StreamProvider.autoDispose
    .family<List<CategoryChartPoint>, ReportRange>(
      (ref, range) =>
          ref.watch(reportRepositoryProvider).watchExpenseCategories(range),
    );

final accountBalanceChartProvider =
    StreamProvider.autoDispose<List<AccountBalanceChartPoint>>((ref) {
      return ref
          .watch(accountRepositoryProvider)
          .watchSummaries()
          .map(
            (summaries) => [
              for (final summary in summaries)
                AccountBalanceChartPoint(
                  accountId: summary.account.id,
                  accountName: summary.account.name,
                  accountType: summary.account.type,
                  balance: summary.balance,
                  isActive: summary.account.isActive,
                ),
            ],
          );
    });
