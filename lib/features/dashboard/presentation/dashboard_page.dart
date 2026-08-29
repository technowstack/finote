import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/currency_formatter.dart';
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
      appBar: AppBar(
        title: const Text('Catatan Keuangan'),
        actions: [
          IconButton(
            tooltip: 'Laporan',
            onPressed: () => context.push('/reports'),
            icon: const Icon(Icons.assessment_outlined),
          ),
          IconButton(
            tooltip: 'Semua transaksi',
            onPressed: () => context.push('/transactions'),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          PopupMenuButton<_DashboardMenu>(
            tooltip: 'Menu lainnya',
            onSelected: (item) => switch (item) {
              _DashboardMenu.categories => context.push('/categories'),
              _DashboardMenu.backup => context.push('/backup'),
              _DashboardMenu.legacyImport => context.push('/legacy-import'),
              _DashboardMenu.security => context.push('/security'),
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _DashboardMenu.categories,
                child: ListTile(
                  leading: Icon(Icons.category_outlined),
                  title: Text('Kategori'),
                ),
              ),
              PopupMenuItem(
                value: _DashboardMenu.backup,
                child: ListTile(
                  leading: Icon(Icons.backup_outlined),
                  title: Text('Backup dan restore'),
                ),
              ),
              PopupMenuItem(
                value: _DashboardMenu.legacyImport,
                child: ListTile(
                  leading: Icon(Icons.move_to_inbox_outlined),
                  title: Text('Import aplikasi lama'),
                ),
              ),
              PopupMenuItem(
                value: _DashboardMenu.security,
                child: ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Keamanan'),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/transactions/new'),
        icon: const Icon(Icons.add),
        label: const Text('Tambah transaksi'),
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            summary.when(
              loading: () => const _SummaryLoading(),
              error: (error, stackTrace) => _ErrorCard(
                message: 'Ringkasan belum dapat dimuat.',
                onRetry: () => ref.invalidate(dashboardSummaryProvider),
              ),
              data: (data) => _Summary(summary: data),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Transaksi terbaru',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/transactions'),
                  child: const Text('Lihat semua'),
                ),
              ],
            ),
            recentTransactions.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => _ErrorCard(
                message: 'Transaksi terbaru belum dapat dimuat.',
                onRetry: () =>
                    ref.invalidate(dashboardRecentTransactionsProvider),
              ),
              data: (items) => items.isEmpty
                  ? const _EmptyTransactions()
                  : Column(
                      children: [
                        for (final item in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _RecentTransactionTile(item: item),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _DashboardMenu { categories, backup, legacyImport, security }

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saldo',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatIdr(summary.balance),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Dihitung dari seluruh transaksi',
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MonthlyCard(
                label: 'Pemasukan bulan ini',
                amount: summary.monthlyIncome,
                icon: Icons.south_west,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MonthlyCard(
                label: 'Pengeluaran bulan ini',
                amount: summary.monthlyExpense,
                icon: Icons.north_east,
                color: colors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.today_outlined),
            title: const Text('Transaksi hari ini'),
            trailing: Text(
              '${summary.todayTransactionCount} transaksi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthlyCard extends StatelessWidget {
  const _MonthlyCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final int amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 16),
            Text(label, maxLines: 2),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatIdr(amount),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactionTile extends StatelessWidget {
  const _RecentTransactionTile({required this.item});

  final TransactionListItem item;

  @override
  Widget build(BuildContext context) {
    final transaction = item.transaction;
    final isExpense = transaction.type == TransactionType.expense;
    final color = isExpense
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => context.push('/transactions/${transaction.id}/edit'),
        title: Text(
          transaction.title.isEmpty ? item.category.name : transaction.title,
        ),
        subtitle: transaction.title.isEmpty ? null : Text(item.category.name),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${isExpense ? '-' : '+'}${formatIdr(transaction.amount)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.edit_note_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text('Belum ada transaksi.'),
            const SizedBox(height: 4),
            const Text('Catat pemasukan atau pengeluaran pertama Anda.'),
          ],
        ),
      ),
    );
  }
}

class _SummaryLoading extends StatelessWidget {
  const _SummaryLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 280,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(message),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
