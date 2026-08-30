import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
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
    final recentTransactions = ref.watch(dashboardRecentTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Catatan Keuangan')),
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
              data: (data) => _Summary(summary: data),
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
  const _Summary({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Balance
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saldo',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.onPrimaryContainer.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatIdr(summary.balance),
                  style: textTheme.displayMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Monthly income & expense — single compact row
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Pemasukan',
                amount: summary.monthlyIncome,
                color: colors.incomeColor,
                icon: Icons.south_west,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _MetricTile(
                label: 'Pengeluaran',
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
