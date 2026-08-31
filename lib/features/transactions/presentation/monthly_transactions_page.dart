import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
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

class _MonthlyTransactionList extends StatelessWidget {
  const _MonthlyTransactionList({required this.items});

  final List<TransactionListItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.xxl,
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
            _MonthlyTransactionRow(item: item),
          ],
        );
      },
    );
  }
}

class _MonthlyTransactionRow extends StatelessWidget {
  const _MonthlyTransactionRow({required this.item});

  final TransactionListItem item;

  @override
  Widget build(BuildContext context) {
    final transaction = item.transaction;
    final colors = Theme.of(context).colorScheme;
    final isExpense = transaction.type == TransactionType.expense;
    final note = transaction.note?.trim();

    return Card(
      child: ListTile(
        onTap: () => context.push('/transactions/${transaction.id}'),
        leading: Icon(
          isExpense ? Icons.arrow_upward : Icons.arrow_downward,
          color: colors.amountColor(isExpense: isExpense),
        ),
        title: Text(item.category.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isExpense ? 'Pengeluaran' : 'Pemasukan'),
            if (transaction.title.isNotEmpty) Text(transaction.title),
            Text(item.account.name),
            if (note != null && note.isNotEmpty)
              Text(note, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        isThreeLine:
            transaction.title.isNotEmpty || (note != null && note.isNotEmpty),
        trailing: CurrencyText(
          amount: transaction.amount,
          type: transaction.type,
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
