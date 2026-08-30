import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction_type.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _searchController = TextEditingController();
  TransactionType? _type;
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
    final filter = TransactionHistoryQuery(
      type: _type,
      startDate: range.start,
      endDate: range.end,
      search: _search,
    );
    final transactions = ref.watch(transactionHistoryProvider(filter));
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
                    hintText: 'Cari judul, catatan, atau kategori',
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
                  selected: _type == TransactionType.income,
                  onSelected: () =>
                      setState(() => _type = TransactionType.income),
                ),
                _filterChip(
                  'Pengeluaran',
                  selected: _type == TransactionType.expense,
                  onSelected: () =>
                      setState(() => _type = TransactionType.expense),
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
          transactions.whenOrNull(
                data: (items) {
                  if (items.isEmpty) return null;
                  var income = 0;
                  var expense = 0;
                  for (final item in items) {
                    if (item.transaction.type == TransactionType.income) {
                      income += item.transaction.amount;
                    } else {
                      expense += item.transaction.amount;
                    }
                  }
                  return _PeriodSummaryStrip(income: income, expense: expense);
                },
              ) ??
              const SizedBox.shrink(),

          // ----- Transaction list -----
          Expanded(
            child: transactions.when(
              loading: () => const AppLoadingState(),
              error: (error, stackTrace) => AppErrorState(
                message: 'Transaksi belum dapat dimuat.',
                onRetry: () =>
                    ref.invalidate(transactionHistoryProvider(filter)),
              ),
              data: (items) => items.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: 'Tidak ada transaksi yang cocok.',
                    )
                  : _GroupedTransactionList(items: items),
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

class _GroupedTransactionList extends StatelessWidget {
  const _GroupedTransactionList({required this.items});

  final List<TransactionListItem> items;

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
            index == 0 ||
            !_isSameDate(
              item.transaction.transactionDate,
              items[index - 1].transaction.transactionDate,
            );
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
                  formatDate(item.transaction.transactionDate),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            _TransactionRow(item: item),
          ],
        );
      },
    );
  }
}

class _TransactionRow extends ConsumerWidget {
  const _TransactionRow({required this.item});

  final TransactionListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = item.transaction;
    final isExpense = transaction.type == TransactionType.expense;
    final colors = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(transaction.id),
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
          onTap: () => context.push('/transactions/${transaction.id}/edit'),
          leading: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.amountColor(isExpense: isExpense),
            ),
          ),
          title: Text(
            transaction.title.isEmpty ? item.category.name : transaction.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: transaction.title.isEmpty ? null : Text(item.category.name),
          trailing: CurrencyText(
            amount: transaction.amount,
            type: transaction.type,
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: const Text('Transaksi tidak akan muncul lagi.'),
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
      final deleted = await ref
          .read(transactionRepositoryProvider)
          .softDelete(item.transaction.id);
      if (!deleted) throw StateError('Transaction is no longer active');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi gagal dihapus. Coba lagi.')),
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
  final today = DateTime(now.year, now.month, now.day);
  return switch (filter) {
    _DateFilter.today => (start: today, end: today),
    _DateFilter.week => (
      start: today.subtract(Duration(days: today.weekday - 1)),
      end: today.add(Duration(days: 7 - today.weekday)),
    ),
    _DateFilter.month => (
      start: DateTime(today.year, today.month),
      end: DateTime(today.year, today.month + 1, 0),
    ),
    _DateFilter.custom => (
      start: customRange?.start ?? today,
      end: customRange?.end ?? today,
    ),
  };
}

bool _isSameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

enum _DateFilter { today, week, month, custom }
