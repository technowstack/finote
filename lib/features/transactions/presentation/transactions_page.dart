import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/financial_date_range.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../transfers/data/transfer_repository.dart';
import '../data/financial_activity_repository.dart';
import '../data/transaction_repository.dart';
import '../domain/financial_activity.dart';
import '../domain/transaction_type.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _searchController = TextEditingController();
  FinancialActivityType? _type;
  _DateFilter _dateFilter = _DateFilter.month;
  DateTimeRange? _customRange;
  String _search = '';
  Timer? _searchTimer;
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final range = _dateRange(_dateFilter, _customRange, DateTime.now());
    final filter = FinancialActivityQuery(
      type: _type,
      startDate: range.start,
      endDate: range.end,
      search: _search,
    );
    final activities = ref.watch(financialActivityProvider(filter));
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _searchOpen ? null : const Text('Transaksi'),
        flexibleSpace: _searchOpen
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Cari transaksi, transfer, atau akun',
                    autoFocus: true,
                    leading: const Icon(Icons.search, size: 20),
                    trailing: [
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: _closeSearch,
                        tooltip: 'Tutup pencarian',
                      ),
                    ],
                    onChanged: _scheduleSearch,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _applySearch,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                  ),
                ),
              )
            : null,
        actions: [
          if (!_searchOpen)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Cari transaksi',
              onPressed: () => setState(() => _searchOpen = true),
            ),
        ],
      ),
      body: Column(
        children: [
          // ----- Single filter row -----
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xs,
              AppSpacing.screenH,
              AppSpacing.xs,
            ),
            child: Row(
              spacing: AppSpacing.sm,
              children: [
                // Type filters
                _filterChip(
                  'Semua',
                  selected: _type == null,
                  onSelected: () => setState(() => _type = null),
                ),
                _filterChip(
                  'Pemasukan',
                  selected: _type == FinancialActivityType.income,
                  onSelected: () =>
                      setState(() => _type = FinancialActivityType.income),
                ),
                _filterChip(
                  'Pengeluaran',
                  selected: _type == FinancialActivityType.expense,
                  onSelected: () =>
                      setState(() => _type = FinancialActivityType.expense),
                ),
                _filterChip(
                  'Transfer',
                  selected: _type == FinancialActivityType.transfer,
                  onSelected: () =>
                      setState(() => _type = FinancialActivityType.transfer),
                ),
                // Divider dot
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.outlineVariant,
                  ),
                ),
                // Date filters
                _filterChip(
                  'Hari ini',
                  selected: _dateFilter == _DateFilter.today,
                  onSelected: () =>
                      setState(() => _dateFilter = _DateFilter.today),
                ),
                _filterChip(
                  'Minggu ini',
                  selected: _dateFilter == _DateFilter.week,
                  onSelected: () =>
                      setState(() => _dateFilter = _DateFilter.week),
                ),
                _filterChip(
                  'Bulan ini',
                  selected: _dateFilter == _DateFilter.month,
                  onSelected: () =>
                      setState(() => _dateFilter = _DateFilter.month),
                ),
                ChoiceChip(
                  label: const Text('Rentang'),
                  selected: _dateFilter == _DateFilter.custom,
                  onSelected: (_) => _selectCustomRange(),
                ),
              ],
            ),
          ),

          // ----- Custom range label -----
          if (_dateFilter == _DateFilter.custom && _customRange != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                '${formatDate(_customRange!.start)} - ${formatDate(_customRange!.end)}',
                style: textTheme.bodySmall,
              ),
            ),

          // ----- Period summary strip -----
          activities.whenOrNull(
                data: (items) {
                  if (items.isEmpty) return null;
                  var income = 0;
                  var expense = 0;
                  var hasTransactions = false;
                  for (final item in items) {
                    if (item.type == FinancialActivityType.income) {
                      hasTransactions = true;
                      income += item.amount;
                    } else if (item.type == FinancialActivityType.expense) {
                      hasTransactions = true;
                      expense += item.amount;
                    }
                  }
                  if (!hasTransactions) return null;
                  return _PeriodSummaryStrip(income: income, expense: expense);
                },
              ) ??
              const SizedBox.shrink(),

          // ----- Transaction list -----
          Expanded(
            child: activities.when(
              loading: () => const AppLoadingState(),
              error: (error, stackTrace) => AppErrorState(
                message: 'Aktivitas belum dapat dimuat.',
                onRetry: () =>
                    ref.invalidate(financialActivityProvider(filter)),
              ),
              data: (items) => items.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: 'Tidak ada aktivitas yang sesuai.',
                    )
                  : _GroupedActivityList(items: items),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    String label, {
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        FocusManager.instance.primaryFocus?.unfocus();
        onSelected();
      },
    );
  }

  void _scheduleSearch(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _search = value.trim());
    });
  }

  void _closeSearch() {
    _searchTimer?.cancel();
    _searchController.clear();
    setState(() {
      _search = '';
      _searchOpen = false;
    });
  }

  void _applySearch(String value) {
    _searchTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _search = value.trim());
  }

  Future<void> _selectCustomRange() async {
    final today = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _customRange ?? DateTimeRange(start: today, end: today),
    );
    if (!mounted) return;
    if (selected != null) {
      setState(() {
        _customRange = selected;
        _dateFilter = _DateFilter.custom;
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Period summary strip
// ---------------------------------------------------------------------------

class _PeriodSummaryStrip extends StatelessWidget {
  const _PeriodSummaryStrip({required this.income, required this.expense});

  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenH,
        vertical: AppSpacing.sm,
      ),
      color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(Icons.south_west, size: 14, color: colors.incomeColor),
          const SizedBox(width: AppSpacing.xs),
          Text(
            formatIdr(income),
            style: textTheme.labelMedium?.copyWith(color: colors.incomeColor),
          ),
          const SizedBox(width: AppSpacing.lg),
          Icon(Icons.north_east, size: 14, color: colors.expenseColor),
          const SizedBox(width: AppSpacing.xs),
          Text(
            formatIdr(expense),
            style: textTheme.labelMedium?.copyWith(color: colors.expenseColor),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grouped transaction list — flat rows, no individual cards
// ---------------------------------------------------------------------------

class _GroupedActivityList extends StatelessWidget {
  const _GroupedActivityList({required this.items});

  final List<FinancialActivity> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.xs,
        AppSpacing.screenH,
        96,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final showDate =
            index == 0 || !_isSameDate(item.date, items[index - 1].date);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDate)
              Padding(
                padding: EdgeInsets.only(
                  top: index == 0 ? AppSpacing.xs : AppSpacing.lg,
                  bottom: AppSpacing.sm,
                ),
                child: Text(
                  formatDate(item.date),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            _ActivityRow(item: item),
          ],
        );
      },
    );
  }
}

class _ActivityRow extends ConsumerWidget {
  const _ActivityRow({required this.item});

  final FinancialActivity item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTransfer = item.type == FinancialActivityType.transfer;
    final transactionType = switch (item.type) {
      FinancialActivityType.income => TransactionType.income,
      FinancialActivityType.expense => TransactionType.expense,
      FinancialActivityType.transfer => null,
    };
    final colors = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(item.identity),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: colors.onErrorContainer),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _performDelete(context, ref),
      child: Card(
        child: ListTile(
          onTap: () => isTransfer
              ? context.push('/transfers?edit=${item.entityId}')
              : context.push('/transactions/${item.entityId}/edit'),
          leading: CircleAvatar(
            backgroundColor: isTransfer
                ? colors.tertiaryContainer
                : colors
                      .amountColor(
                        isExpense: item.type == FinancialActivityType.expense,
                      )
                      .withValues(alpha: 0.15),
            child: Icon(
              switch (item.type) {
                FinancialActivityType.income => Icons.south_west,
                FinancialActivityType.expense => Icons.north_east,
                FinancialActivityType.transfer => Icons.swap_horiz,
              },
              color: isTransfer
                  ? colors.onTertiaryContainer
                  : colors.amountColor(
                      isExpense: item.type == FinancialActivityType.expense,
                    ),
            ),
          ),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isTransfer && item.categoryName != null)
                Text(item.categoryName!),
              Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
          isThreeLine: !isTransfer && item.categoryName != null,
          trailing: CurrencyText(
            amount: item.amount,
            type: transactionType,
            style: isTransfer
                ? Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: colors.tertiary)
                : null,
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus aktivitas?'),
        content: const Text('Aktivitas tidak akan muncul lagi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(BuildContext context, WidgetRef ref) async {
    try {
      final deleted = item.type == FinancialActivityType.transfer
          ? await ref.read(transferRepositoryProvider).softDelete(item.entityId)
          : await ref
                .read(transactionRepositoryProvider)
                .softDelete(item.entityId);
      if (!deleted) throw StateError('Activity is no longer active');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktivitas gagal dihapus. Coba lagi.')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

({DateTime start, DateTime end}) _dateRange(
  _DateFilter filter,
  DateTimeRange? customRange,
  DateTime now,
) {
  final range = resolveFinancialDateRange(
    switch (filter) {
      _DateFilter.today => FinancialPeriod.today,
      _DateFilter.week => FinancialPeriod.week,
      _DateFilter.month => FinancialPeriod.month,
      _DateFilter.custom => FinancialPeriod.custom,
    },
    now: now,
    customStart: customRange?.start,
    customEnd: customRange?.end,
  );
  return (start: range.start, end: range.end);
}

bool _isSameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

enum _DateFilter { today, week, month, custom }
