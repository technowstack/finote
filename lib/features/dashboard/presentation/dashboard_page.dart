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
      appBar: AppBar(title: const Text('Finote')),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(dashboardSummaryProvider.future),
            ref.refresh(dashboardRecentTransactionsProvider.future),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.screenV,
            AppSpacing.screenH,
            96,
          ),
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
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => context.push('/receipt-scan'),
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan struk'),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: 'Transaksi terbaru',
              trailing: TextButton(
                onPressed: () => context.go('/transactions'),
                child: const Text('Lihat semua'),
              ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NetWorthCard(netWorth: netWorth, onOpenPortfolio: onOpenPortfolio),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Pemasukan bulan ini',
                amount: summary.monthlyIncome,
                color: colors.incomeColor,
                icon: Icons.south_west,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
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

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({required this.netWorth, required this.onOpenPortfolio});

  final AsyncValue<NetWorthSnapshot> netWorth;
  final VoidCallback onOpenPortfolio;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: netWorth.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Kekayaan bersih belum dapat dimuat.'),
          data: (snapshot) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kekayaan Bersih',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatIdr(snapshot.totalKnownValue),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _NetWorthLine(label: 'Kas & Dompet', value: snapshot.cashValue),
              _NetWorthLine(
                label: 'Portofolio',
                value: snapshot.portfolioKnownValue,
                key: const Key('dashboard-portfolio-summary'),
                onTap: onOpenPortfolio,
              ),
              if (snapshot.isPartial)
                Text(
                  snapshot.unvaluedAssetCount > 0
                      ? 'Nilai sementara • ${snapshot.unvaluedAssetCount} aset belum memiliki harga'
                      : 'Nilai sementara • terdapat posisi aset yang tidak valid',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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
    return ListTile(
      dense: true,
      onTap: onTap,
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value == null ? 'Belum tersedia' : formatIdr(value!)),
          if (onTap != null) const Icon(Icons.chevron_right),
        ],
      ),
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
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: AppSpacing.xs),
                Text(label, style: textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatIdr(amount),
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent transactions — flat list wrapped in a single card
// ---------------------------------------------------------------------------

class _RecentTransactionsList extends StatelessWidget {
  const _RecentTransactionsList({required this.items});

  final List<TransactionListItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _RecentTransactionRow(item: items[i]),
            if (i < items.length - 1) const Divider(indent: 16, endIndent: 16),
          ],
        ],
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
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      onTap: () => context.push('/transactions/${transaction.id}/edit'),
      title: Text(
        transaction.title.isEmpty ? item.category.name : transaction.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: transaction.title.isEmpty ? null : Text(item.category.name),
      trailing: CurrencyText(
        amount: transaction.amount,
        type: transaction.type,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: colors.amountColor(isExpense: isExpense)),
      ),
    );
  }
}
