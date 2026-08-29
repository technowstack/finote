import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/transactions/new'),
        icon: const Icon(Icons.add),
        label: const Text('Tambah transaksi'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Cari judul, catatan, atau kategori',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Hapus pencarian',
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.close),
                  ),
              ],
              onChanged: _scheduleSearch,
            ),
          ),
          _FilterRow(
            children: [
              ChoiceChip(
                label: const Text('Semua'),
                selected: _type == null,
                onSelected: (_) => setState(() => _type = null),
              ),
              ChoiceChip(
                label: const Text('Pemasukan'),
                selected: _type == TransactionType.income,
                onSelected: (_) =>
                    setState(() => _type = TransactionType.income),
              ),
              ChoiceChip(
                label: const Text('Pengeluaran'),
                selected: _type == TransactionType.expense,
                onSelected: (_) =>
                    setState(() => _type = TransactionType.expense),
              ),
            ],
          ),
          _FilterRow(
            children: [
              _dateChip('Hari Ini', _DateFilter.today),
              _dateChip('Minggu Ini', _DateFilter.week),
              _dateChip('Bulan Ini', _DateFilter.month),
              ChoiceChip(
                label: const Text('Rentang'),
                selected: _dateFilter == _DateFilter.custom,
                onSelected: (_) => _selectCustomRange(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: transactions.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _ErrorState(
                onRetry: () =>
                    ref.invalidate(transactionHistoryProvider(filter)),
              ),
              data: (items) => items.isEmpty
                  ? const _EmptyState()
                  : _GroupedTransactionList(items: items),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChip(String label, _DateFilter value) {
    return ChoiceChip(
      label: Text(label),
      selected: _dateFilter == value,
      onSelected: (_) => setState(() => _dateFilter = value),
    );
  }

  void _scheduleSearch(String value) {
    setState(() {});
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _search = value.trim());
    });
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    _searchController.clear();
    setState(() => _search = '');
  }

  Future<void> _selectCustomRange() async {
    final today = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _customRange ?? DateTimeRange(start: today, end: today),
    );
    if (selected != null) {
      setState(() {
        _customRange = selected;
        _dateFilter = _DateFilter.custom;
      });
    }
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(spacing: 8, children: children),
    );
  }
}

class _GroupedTransactionList extends StatelessWidget {
  const _GroupedTransactionList({required this.items});

  final List<TransactionListItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
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
                padding: EdgeInsets.only(top: index == 0 ? 4 : 20, bottom: 8),
                child: Text(
                  formatDate(item.transaction.transactionDate),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            _TransactionTile(item: item),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.item});

  final TransactionListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = item.transaction;
    final isExpense = transaction.type == TransactionType.expense;
    final amountColor = isExpense
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => context.push('/transactions/${transaction.id}/edit'),
        leading: Icon(
          isExpense ? Icons.arrow_upward : Icons.arrow_downward,
          color: amountColor,
        ),
        title: Text(
          transaction.title.isEmpty ? item.category.name : transaction.title,
        ),
        subtitle: transaction.title.isEmpty ? null : Text(item.category.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${isExpense ? '-' : '+'}${formatIdr(transaction.amount)}',
              style: TextStyle(color: amountColor, fontWeight: FontWeight.w700),
            ),
            PopupMenuButton<void>(
              tooltip: 'Tindakan transaksi',
              onSelected: (_) => _delete(context, ref),
              itemBuilder: (context) => const [
                PopupMenuItem(child: Text('Hapus')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
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
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(transactionRepositoryProvider)
          .softDelete(item.transaction.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi gagal dihapus. Coba lagi.')),
        );
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text('Tidak ada transaksi yang cocok.'),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Transaksi belum dapat dimuat.'),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

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
