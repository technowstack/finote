import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/finance/net_worth.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/finote_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../reports/domain/report_chart_data.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction_type.dart';
import '../data/balance_visibility_provider.dart';
import '../data/dashboard_repository.dart';

const _maskedAmount = 'Rp ••••••';

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
            96,
          ),
          children: [
            _NetWorthHero(
              netWorth: netWorth,
              onOpenPortfolio: () => context.go('/portfolio'),
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
              data: (points) => _WeeklyExpenseCard(points: points),
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
// Hero: point-in-time Net Worth (never mixed with period cashflow)
// ---------------------------------------------------------------------------

class _NetWorthHero extends ConsumerWidget {
  const _NetWorthHero({required this.netWorth, required this.onOpenPortfolio});

  final AsyncValue<NetWorthSnapshot> netWorth;
  final VoidCallback onOpenPortfolio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = Theme.of(context).finote;
    // Mask until the preference is known so a hidden balance never flashes.
    final hidden = switch (ref.watch(balanceHiddenProvider)) {
      AsyncData(:final value) => value,
      AsyncError() => false,
      _ => true,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: f.heroGradient,
        borderRadius: AppRadius.xlAll,
        boxShadow: f.heroShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Kekayaan Bersih',
                    style: AppTypography.labelMd.copyWith(color: f.onHeroMuted),
                  ),
                ),
                IconButton(
                  tooltip: hidden ? 'Tampilkan saldo' : 'Sembunyikan saldo',
                  onPressed: () =>
                      ref.read(balanceHiddenProvider.notifier).toggle(),
                  style: IconButton.styleFrom(
                    backgroundColor: f.onHeroChip,
                    foregroundColor: f.onHero,
                    fixedSize: const Size(40, 40),
                  ),
                  icon: Icon(
                    hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ],
            ),
            netWorth.when(
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
              data: (snapshot) => _HeroBody(
                snapshot: snapshot,
                hidden: hidden,
                onOpenPortfolio: onOpenPortfolio,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBody extends StatelessWidget {
  const _HeroBody({
    required this.snapshot,
    required this.hidden,
    required this.onOpenPortfolio,
  });

  final NetWorthSnapshot snapshot;
  final bool hidden;
  final VoidCallback onOpenPortfolio;

  @override
  Widget build(BuildContext context) {
    final f = Theme.of(context).finote;
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
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            hidden ? _maskedAmount : formatIdr(snapshot.totalKnownValue),
            style: AppTypography.amountHero.copyWith(color: f.onHero),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _HeroBadge(text: badge, icon: hidden ? null : Icons.schedule),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _HeroTile(
                label: 'Kas & Dompet',
                value: snapshot.cashValue,
                hidden: hidden,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _HeroTile(
                key: const Key('dashboard-portfolio-summary'),
                label: 'Portofolio',
                value: snapshot.portfolioKnownValue,
                hidden: hidden,
                onTap: onOpenPortfolio,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final f = Theme.of(context).finote;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: f.onHeroChip,
        borderRadius: AppRadius.smAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: f.onHero),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                text,
                style: AppTypography.captionSemibold.copyWith(color: f.onHero),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroTile extends StatelessWidget {
  const _HeroTile({
    super.key,
    required this.label,
    required this.value,
    required this.hidden,
    this.onTap,
  });

  final String label;
  final int? value;
  final bool hidden;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final f = Theme.of(context).finote;
    final text = value == null
        ? 'Belum tersedia'
        : hidden
        ? _maskedAmount
        : formatIdr(value!);
    return Material(
      color: f.onHeroChip,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.captionRegular.copyWith(
                          color: f.onHeroMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          text,
                          style: AppTypography.amountItem.copyWith(
                            color: f.onHero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) Icon(Icons.chevron_right, color: f.onHero),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7-day expense
// ---------------------------------------------------------------------------

const _weekdayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

class _WeeklyExpenseCard extends StatelessWidget {
  const _WeeklyExpenseCard({required this.points});

  final List<FinancialTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = points.fold<int>(0, (sum, p) => sum + p.expense);
    final peak = points.fold<int>(0, (m, p) => p.expense > m ? p.expense : m);
    final semantics = [
      for (final p in points)
        '${_weekdayLabels[p.period.weekday - 1]} ${formatIdr(p.expense)}',
    ].join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pengeluaran 7 hari', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatIdr(total),
                style: AppTypography.amountLg.copyWith(color: colors.onSurface),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              label: 'Pengeluaran harian: $semantics',
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < points.length; i++)
                      Expanded(
                        child: _DayBar(
                          label: _weekdayLabels[points[i].period.weekday - 1],
                          ratio: peak == 0 ? 0 : points[i].expense / peak,
                          isToday: i == points.length - 1,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (total == 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Belum ada pengeluaran 7 hari terakhir.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.label,
    required this.ratio,
    required this.isToday,
  });

  final String label;
  final double ratio;
  final bool isToday;

  static const _barArea = 56.0;
  static const _minBar = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: _barArea,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 24,
              height: _minBar + (_barArea - _minBar) * ratio,
              decoration: BoxDecoration(
                color: isToday ? colors.primary : colors.primaryContainer,
                borderRadius: AppRadius.smAll,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style:
                (isToday
                        ? AppTypography.captionSemibold
                        : AppTypography.captionRegular)
                    .copyWith(
                      color: isToday
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
          ),
        ),
      ],
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
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatIdr(amount),
                style: AppTypography.amountMd.copyWith(color: color),
              ),
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
            for (final item in items) _RecentTransactionRow(item: item),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactionRow extends StatelessWidget {
  const _RecentTransactionRow({required this.item});

  final TransactionListItem item;

  @override
  Widget build(BuildContext context) {
    final transaction = item.transaction;
    final isExpense = transaction.type == TransactionType.expense;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = theme.finote.categoryStyle(item.category.name);
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;

    return InkWell(
      onTap: () => context.push('/transactions/${transaction.id}/edit'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: style.background,
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(style.icon, color: style.foreground),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title.isEmpty
                        ? item.category.name
                        : transaction.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLg.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  if (transaction.title.isNotEmpty)
                    Text(item.category.name, style: theme.textTheme.bodySmall),
                  if (largeText)
                    Text(
                      '${isExpense ? '-' : '+'}${formatIdr(transaction.amount)}',
                      style: AppTypography.amountItem.copyWith(
                        color: colors.amountColor(isExpense: isExpense),
                      ),
                    ),
                ],
              ),
            ),
            if (!largeText) ...[
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: CurrencyText(
                  amount: transaction.amount,
                  type: transaction.type,
                  style: AppTypography.amountItem,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
