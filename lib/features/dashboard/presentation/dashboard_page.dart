import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/main_scaffold.dart';
import '../../../core/finance/net_worth.dart';
import '../../../core/preferences/balance_visibility_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/finote_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/expense_7day_card.dart';
import '../../../core/widgets/finance_tiles.dart';
import '../../../core/widgets/finote_hero.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/widgets/temporary_badge.dart';
import '../../transactions/data/transaction_repository.dart';
import '../data/dashboard_repository.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDateSensitiveData();
  }

  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      _refreshDateSensitiveData();
      _scheduleMidnightRefresh();
    });
  }

  void _refreshDateSensitiveData() {
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(dashboardWeeklyTrendProvider);
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(dashboardSummaryProvider);
    final netWorth = ref.watch(netWorthProvider);
    final weeklyTrend = ref.watch(dashboardWeeklyTrendProvider);
    final recentTransactions = ref.watch(dashboardRecentTransactionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Finote', style: theme.textTheme.headlineLarge),
        actions: [
          IconButton(
            tooltip: 'Scan struk',
            onPressed: () => context.push('/receipt-scan'),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
              fixedSize: const Size(40, 40),
            ),
            icon: const Icon(Icons.document_scanner_outlined),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(dashboardSummaryProvider.future),
            ref.refresh(dashboardWeeklyTrendProvider.future),
            ref.refresh(dashboardRecentTransactionsProvider.future),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.sm,
            AppSpacing.screenH,
            kFabClearance,
          ),
          children: [
            FinoteHero(
              title: 'Kekayaan Bersih',
              action: const BalanceVisibilityButton(),
              child: _NetWorthBody(
                netWorth: netWorth,
                onOpenPortfolio: () => context.go('/portfolio'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            weeklyTrend.when(
              loading: () => const Card(
                child: SizedBox(height: 144, child: AppLoadingState()),
              ),
              error: (_, _) => AppErrorState(
                message: 'Pengeluaran 7 hari belum dapat dimuat.',
                onRetry: () => ref.invalidate(dashboardWeeklyTrendProvider),
              ),
              data: (points) => Expense7DayCard(
                days: [
                  for (final p in points) (day: p.period, expense: p.expense),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            summary.when(
              loading: () =>
                  const SizedBox(height: 120, child: AppLoadingState()),
              error: (_, _) => AppErrorState(
                message: 'Ringkasan belum dapat dimuat.',
                onRetry: () => ref.invalidate(dashboardSummaryProvider),
              ),
              data: (data) => _MonthSection(summary: data),
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                Text(
                  'Transaksi terbaru',
                  style: AppTypography.titleSection.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/transactions'),
                  child: const Text('Lihat semua'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            recentTransactions.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: AppLoadingState(),
              ),
              error: (_, _) => AppErrorState(
                message: 'Transaksi terbaru belum dapat dimuat.',
                onRetry: () =>
                    ref.invalidate(dashboardRecentTransactionsProvider),
              ),
              data: (items) => items.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.edit_note_outlined,
                      message: 'Belum ada transaksi.',
                      subtitle:
                          'Catat pemasukan atau pengeluaran pertama Anda.',
                    )
                  : _RecentTransactionsCard(items: items),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero body: point-in-time Net Worth (never mixed with period cashflow)
// ---------------------------------------------------------------------------

class _NetWorthBody extends ConsumerWidget {
  const _NetWorthBody({required this.netWorth, required this.onOpenPortfolio});

  final AsyncValue<NetWorthSnapshot> netWorth;
  final VoidCallback onOpenPortfolio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = Theme.of(context).finote;
    final hidden = watchBalanceHidden(ref);
    return netWorth.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: LinearProgressIndicator(
          color: f.onHero,
          backgroundColor: f.onHeroChip,
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          'Kekayaan bersih belum dapat dimuat.',
          style: AppTypography.labelMd.copyWith(color: f.onHero),
        ),
      ),
      data: (snapshot) {
        final badge = hidden
            ? 'Saldo disembunyikan'
            : !snapshot.isPartial
            ? null
            : snapshot.unvaluedAssetCount > 0
            ? 'Nilai sementara • ${snapshot.unvaluedAssetCount} aset belum memiliki harga'
            : 'Nilai sementara • terdapat posisi aset yang tidak valid';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FinoteHeroAmount(amount: snapshot.totalKnownValue),
            if (badge != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TemporaryBadge(
                text: badge,
                onHero: true,
                icon: hidden ? null : Icons.schedule,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FinoteHeroTile(
                    label: 'Kas & Dompet',
                    amount: snapshot.cashValue,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FinoteHeroTile(
                    key: const Key('dashboard-portfolio-summary'),
                    label: 'Portofolio',
                    amount: snapshot.portfolioKnownValue,
                    onTap: onOpenPortfolio,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// This month: period cashflow
// ---------------------------------------------------------------------------

class _MonthSection extends StatelessWidget {
  const _MonthSection({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final balance = summary.monthlyIncome - summary.monthlyExpense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Text(
              'Bulan ini',
              style: AppTypography.titleSection.copyWith(
                color: colors.onSurface,
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Saldo ', style: theme.textTheme.bodySmall),
                  TextSpan(
                    text:
                        '${balance < 0 ? '-' : '+'}${formatIdr(balance.abs())}',
                    style: AppTypography.amountSm.copyWith(
                      color: colors.amountColor(isExpense: balance < 0),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Pemasukan bulan ini',
                amount: summary.monthlyIncome,
                color: colors.incomeColor,
                icon: Icons.south_west,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricTile(
                label: 'Pengeluaran bulan ini',
                amount: summary.monthlyExpense,
                color: colors.expenseColor,
                icon: Icons.north_east,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final int amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Direction icon stays neutral: red/green only on the amount.
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Icon(icon, size: 18, color: colors.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            CurrencyText(
              amount: amount,
              alignment: Alignment.centerLeft,
              style: AppTypography.amountMd.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent transactions
// ---------------------------------------------------------------------------

class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({required this.items});

  final List<TransactionListItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            for (final item in items)
              TransactionTile(
                title: item.transaction.title,
                categoryName: item.category.name,
                amount: item.transaction.amount,
                type: item.transaction.type,
                onTap: () =>
                    context.push('/transactions/${item.transaction.id}/edit'),
              ),
          ],
        ),
      ),
    );
  }
}
