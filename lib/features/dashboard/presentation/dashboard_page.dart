import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/finance/net_worth.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction_type.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(dashboardSummaryProvider);
    final netWorth = ref.watch(netWorthProvider);
    final recentTransactions = ref.watch(dashboardRecentTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Finote', style: Theme.of(context).textTheme.headlineLarge),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(dashboardSummaryProvider.future),
            ref.refresh(dashboardRecentTransactionsProvider.future),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, AppSpacing.md, 20, 96),
          children: [
            summary.when(
              loading: () =>
                  const SizedBox(height: 160, child: AppLoadingState()),
              error: (error, stackTrace) => AppErrorState(
                message: 'Ringkasan belum dapat dimuat.',
                onRetry: () => ref.invalidate(dashboardSummaryProvider),
              ),
              data: (data) => _Summary(
                summary: data,
                netWorth: netWorth,
                onOpenPortfolio: () => context.go('/portfolio'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => context.push('/receipt-scan'),
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan struk'),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                Text(
                  'Transaksi terbaru',
                  style: Theme.of(context).textTheme.titleLarge,
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
              error: (error, stackTrace) => AppErrorState(
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
                  : _RecentTransactionsList(items: items),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary header
// ---------------------------------------------------------------------------

class _Summary extends StatelessWidget {
  const _Summary({
    required this.summary,
    required this.netWorth,
    required this.onOpenPortfolio,
  });

  final DashboardSummary summary;
  final AsyncValue<NetWorthSnapshot> netWorth;
  final VoidCallback onOpenPortfolio;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final monthlyBalance = summary.monthlyIncome - summary.monthlyExpense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NetWorthCard(netWorth: netWorth, onOpenPortfolio: onOpenPortfolio),
        const SizedBox(height: AppSpacing.md),
        _MonthlyBalanceCard(amount: monthlyBalance),

        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Pemasukan bulan ini',
                amount: summary.monthlyIncome,
                color: colors.incomeColor,
                iconColor: colors.incomeAccentColor,
                icon: Icons.south_west,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _MetricTile(
                label: 'Pengeluaran bulan ini',
                amount: summary.monthlyExpense,
                color: colors.expenseColor,
                iconColor: colors.expenseAccentColor,
                icon: Icons.north_east,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({required this.netWorth, required this.onOpenPortfolio});

  final AsyncValue<NetWorthSnapshot> netWorth;
  final VoidCallback onOpenPortfolio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? null : theme.colorScheme.dashboardHeroColor,
        borderRadius: BorderRadius.circular(24),
        gradient: dark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF302544),
                  Color(0xFF60445A),
                  Color(0xFF75536F),
                ],
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: netWorth.when(
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kekayaan Bersih',
                style: TextStyle(color: dark ? null : Colors.white),
              ),
              const SizedBox(height: 24),
              const LinearProgressIndicator(),
            ],
          ),
          error: (_, _) => Text(
            'Kekayaan bersih belum dapat dimuat.',
            style: TextStyle(color: dark ? null : Colors.white),
          ),
          data: (snapshot) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kekayaan Bersih',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: dark ? const Color(0xFFF6F3FA) : Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                formatIdr(snapshot.totalKnownValue),
                softWrap: true,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 32,
                  color: dark ? const Color(0xFFF6F3FA) : Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Divider(color: theme.colorScheme.dashboardHeroDivider),
              _NetWorthLine(label: 'Kas & Dompet', value: snapshot.cashValue),
              _NetWorthLine(
                label: 'Portofolio',
                value: snapshot.portfolioKnownValue,
                key: const Key('dashboard-portfolio-summary'),
                onTap: onOpenPortfolio,
              ),
              if (snapshot.isPartial) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  snapshot.unvaluedAssetCount > 0
                      ? 'Nilai sementara • ${snapshot.unvaluedAssetCount} aset belum memiliki harga'
                      : 'Nilai sementara • terdapat posisi aset yang tidak valid',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: dark ? const Color(0xFFF6F3FA) : Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NetWorthLine extends StatelessWidget {
  const _NetWorthLine({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final int? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.dashboardHeroLabel,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value == null ? 'Belum tersedia' : formatIdr(value!),
                    softWrap: true,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: dark ? const Color(0xFFF6F3FA) : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: dark ? const Color(0xFFF6F3FA) : Colors.white,
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.iconColor,
    required this.icon,
  });

  final String label;
  final int amount;
  final Color color;
  final Color iconColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              formatIdr(amount),
              softWrap: true,
              style: textTheme.titleLarge?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyBalanceCard extends StatelessWidget {
  const _MonthlyBalanceCard({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isPositive = amount >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo Bulan Ini', style: theme.textTheme.titleMedium),

            const SizedBox(height: AppSpacing.md),

            Text(
              formatIdr(amount),
              softWrap: true,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: isPositive ? colors.incomeColor : colors.expenseColor,
              ),
            ),

            const SizedBox(height: AppSpacing.xs),

            Text(
              isPositive
                  ? 'Arus kas bulan ini positif'
                  : 'Pengeluaran melebihi pemasukan',
              style: theme.textTheme.bodyMedium,
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

class _RecentTransactionsList extends StatelessWidget {
  const _RecentTransactionsList({required this.items});

  final List<TransactionListItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _RecentTransactionRow(item: items[i]),
          if (i < items.length - 1) const Divider(height: 1),
        ],
      ],
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
    final colors = Theme.of(context).colorScheme;

    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/transactions/${transaction.id}/edit'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isExpense ? Icons.north_east : Icons.south_west,
                color: colors.amountColor(isExpense: isExpense),
              ),
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
                    style: theme.textTheme.titleMedium,
                  ),
                  if (transaction.title.isNotEmpty)
                    Text(item.category.name, style: theme.textTheme.bodySmall),
                  if (MediaQuery.textScalerOf(context).scale(14) > 21)
                    Text(
                      '${isExpense ? '-' : '+'}${formatIdr(transaction.amount)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.amountColor(isExpense: isExpense),
                      ),
                    ),
                ],
              ),
            ),
            if (MediaQuery.textScalerOf(context).scale(14) <= 21)
              Flexible(
                child: CurrencyText(
                  amount: transaction.amount,
                  type: transaction.type,
                  style: theme.textTheme.titleMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
