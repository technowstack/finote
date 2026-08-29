import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction_type.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/transactions/new'),
        icon: const Icon(Icons.add),
        label: const Text('Tambah transaksi'),
      ),
      body: transactions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _ErrorState(onRetry: () => ref.invalidate(transactionsProvider)),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _TransactionTile(item: items[index]),
          );
        },
      ),
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
        leading: Icon(
          isExpense ? Icons.arrow_upward : Icons.arrow_downward,
          color: amountColor,
        ),
        title: Text(
          transaction.title.isEmpty ? item.category.name : transaction.title,
        ),
        subtitle: Text(
          '${item.category.name} · ${formatDate(transaction.transactionDate)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${isExpense ? '-' : '+'}${formatIdr(transaction.amount)}',
              style: TextStyle(color: amountColor, fontWeight: FontWeight.w700),
            ),
            PopupMenuButton<_TransactionAction>(
              tooltip: 'Tindakan transaksi',
              onSelected: (action) => switch (action) {
                _TransactionAction.edit => context.push(
                  '/transactions/${transaction.id}/edit',
                ),
                _TransactionAction.delete => _delete(context, ref),
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _TransactionAction.edit,
                  child: Text('Ubah'),
                ),
                PopupMenuItem(
                  value: _TransactionAction.delete,
                  child: Text('Hapus'),
                ),
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
          const Text('Belum ada transaksi.'),
          const SizedBox(height: 4),
          const Text('Tekan + untuk mencatat transaksi pertama.'),
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

enum _TransactionAction { edit, delete }
