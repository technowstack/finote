import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/finance_tiles.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction_type.dart';

class MonthlyTransactionsPage extends ConsumerWidget {
  const MonthlyTransactionsPage({super.key, required this.month});

  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsedMonth = _parseMonth(month);
    if (parsedMonth == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Riwayat transaksi')),
        body: AppEmptyState(
          icon: Icons.calendar_month_outlined,
          message: 'Bulan tidak valid.',
        ),
      );
    }

    final range = _monthRange(parsedMonth);
    final filter = TransactionHistoryQuery(
      startDate: range.start,
      endDate: range.end,
    );
    final transactions = ref.watch(transactionHistoryProvider(filter));

    return Scaffold(
      appBar: AppBar(title: Text(_formatMonth(parsedMonth))),
      body: transactions.when(
        loading: () => const AppLoadingState(),
        error: (error, stackTrace) => AppErrorState(
          message: 'Transaksi belum dapat dimuat.',
          onRetry: () => ref.invalidate(transactionHistoryProvider(filter)),
        ),
        data: (items) => items.isEmpty
            ? const AppEmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'Tidak ada transaksi pada bulan ini.',
              )
            : _MonthlyTransactionList(items: items),
      ),
    );
  }
}

/// Flattened (header + rows) so rows still build lazily; each date reads as
/// one rounded surface. The daily total counts income minus expense.
class _MonthlyTransactionList extends StatelessWidget {
  const _MonthlyTransactionList({required this.items});

  final List<TransactionListItem> items;

  @override
  Widget build(BuildContext context) {
    final entries = _entriesOf(items);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.xxl,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final item = entry.item;
        if (item == null) {
          return Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : AppSpacing.md),
            child: DateHeader(
              label: formatDate(entry.date!),
              total: entry.total,
              maskable: true,
            ),
          );
        }
        return _MonthlyTransactionRow(
          item: item,
          first: entry.first,
          last: entry.last,
        );
      },
    );
  }
}

class _Entry {
  const _Entry.header(this.date, this.total)
    : item = null,
      first = false,
      last = false;
  const _Entry.row(
    TransactionListItem this.item, {
    this.first = false,
    this.last = false,
  }) : date = null,
       total = null;

  final DateTime? date;
  final int? total;
  final TransactionListItem? item;
  final bool first;
  final bool last;
}

List<_Entry> _entriesOf(List<TransactionListItem> items) {
  final entries = <_Entry>[];
  var start = 0;
  while (start < items.length) {
    final date = items[start].transaction.transactionDate;
    var end = start;
    var total = 0;
    while (end < items.length &&
        _isSameDate(items[end].transaction.transactionDate, date)) {
      final transaction = items[end].transaction;
      total += transaction.type == TransactionType.income
          ? transaction.amount
          : -transaction.amount;
      end++;
    }
    entries.add(_Entry.header(date, total));
    for (var i = start; i < end; i++) {
      entries.add(_Entry.row(items[i], first: i == start, last: i == end - 1));
    }
    start = end;
  }
  return entries;
}

class _MonthlyTransactionRow extends StatelessWidget {
  const _MonthlyTransactionRow({
    required this.item,
    required this.first,
    required this.last,
  });

  final TransactionListItem item;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final transaction = item.transaction;
    final note = transaction.note?.trim();
    final titled = transaction.title.isNotEmpty;
    const radius = Radius.circular(AppRadius.lg);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: first ? radius : Radius.zero,
          bottom: last ? radius : Radius.zero,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: first ? AppSpacing.xs : 0,
          bottom: last ? AppSpacing.xs : 0,
        ),
        child: TransactionTile(
          title: transaction.title,
          categoryName: item.category.name,
          amount: transaction.amount,
          type: transaction.type,
          // The account is always shown here: this history spans accounts.
          subtitle: item.account.name,
          details: [if (note != null && note.isNotEmpty) note],
          caption: titled ? item.category.name : null,
          maskable: true,
          onTap: () => context.push('/transactions/${transaction.id}'),
        ),
      ),
    );
  }
}

DateTime? _parseMonth(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  if (month < 1 || month > 12) return null;
  return DateTime(year, month);
}

({DateTime start, DateTime end}) _monthRange(DateTime month) => (
  start: DateTime(month.year, month.month),
  end: DateTime(month.year, month.month + 1, 0),
);

String _formatMonth(DateTime month) =>
    DateFormat('MMMM y', 'id_ID').format(month);

bool _isSameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
