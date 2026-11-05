import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/finance/net_worth.dart';
import '../../../accounts/domain/account_summary.dart';
import '../../data/report_repository.dart';
import '../../domain/report_chart_data.dart';
import '../analytics_chart_page.dart';
import '../income_expense_chart.dart';
import '../report_chart_section.dart';
import 'account_balances_section.dart';
import 'category_breakdown.dart';
import 'report_compact_summary.dart';
import 'investment_cashflow_section.dart';
import 'current_position_section.dart';
import 'transfer_summary_section.dart';

class ReportSummaryTab extends StatelessWidget {
  const ReportSummaryTab({
    super.key,
    required this.data,
    required this.investmentCashflow,
    required this.netWorth,
    required this.accounts,
    required this.trend,
    required this.range,
    required this.onRetryTrend,
  });

  final ReportData data;
  final AsyncValue<InvestmentCashflowSummary> investmentCashflow;
  final AsyncValue<NetWorthSnapshot> netWorth;
  final AsyncValue<List<AccountSummary>> accounts;
  final AsyncValue<List<FinancialTrendPoint>> trend;
  final ReportRange range;
  final VoidCallback onRetryTrend;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.xxl,
      ),
      children: [
        if (data.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.summarize_outlined),
              title: Text('Belum ada transaksi pada periode ini.'),
            ),
          )
        else
          CompactSummary(data: data),
        const SizedBox(height: AppSpacing.lg),
        AccountBalancesSection(accounts: accounts),
        InvestmentCashflowSection(summary: investmentCashflow),
        CurrentPositionSection(netWorth: netWorth),
        const SizedBox(height: AppSpacing.xl),
        ReportChartSection<List<FinancialTrendPoint>>(
          title: 'Pemasukan vs Pengeluaran',
          subtitle: 'Perbandingan berdasarkan periode laporan',
          data: trend,
          isEmpty: (points) => !hasIncomeExpenseData(points),
          onRetry: onRetryTrend,
          height: 260,
          emptyMessage: 'Belum ada transaksi pada periode ini.',
          builder: (context, points) => IncomeExpenseChart(
            points: points,
            granularity: chartGranularityFor(range),
            range: range,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const Key('open-analytics'),
            onPressed: () =>
                context.push(AnalyticsChartPage.locationFor(range)),
            icon: const Icon(Icons.arrow_forward),
            iconAlignment: IconAlignment.end,
            label: const Text('Lihat Analisis Grafik'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (data.topExpenseCategories.isNotEmpty) ...[
          CategoryBreakdown(
            title: 'Pengeluaran per kategori',
            items: data.topExpenseCategories,
            total: data.totalExpense,
            isExpense: true,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (data.topIncomeCategories.isNotEmpty) ...[
          CategoryBreakdown(
            title: 'Pemasukan per kategori',
            items: data.topIncomeCategories,
            total: data.totalIncome,
            isExpense: false,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        const SizedBox(height: AppSpacing.lg),
        TransferSummarySection(summary: data.transferSummary),
      ],
    );
  }
}
