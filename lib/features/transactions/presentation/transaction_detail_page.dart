import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../categories/data/category_repository.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction_type.dart';

class TransactionDetailPage extends ConsumerWidget {
  const TransactionDetailPage({super.key, required this.transactionId});

  final int transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = ref.watch(transactionByIdProvider(transactionId));
    return transaction.when(
      loading: () => const _LoadingPage(),
      error: (error, stackTrace) => AppErrorScaffold(
        title: 'Detail transaksi',
        message: 'Transaksi belum dapat dimuat.',
        onRetry: () => ref.invalidate(transactionByIdProvider(transactionId)),
      ),
      data: (record) {
        if (record == null) {
          return AppErrorScaffold(
            title: 'Detail transaksi',
            message: 'Transaksi tidak ditemukan.',
            onRetry: () =>
                ref.invalidate(transactionByIdProvider(transactionId)),
          );
        }

        final categories = ref.watch(categoriesProvider);
        return categories.when(
          loading: () => const _LoadingPage(),
          error: (error, stackTrace) => AppErrorScaffold(
            title: 'Detail transaksi',
            message: 'Kategori belum dapat dimuat.',
            onRetry: () => ref.invalidate(categoriesProvider),
          ),
          data: (items) {
            final category = items.where(
              (item) => item.id == record.categoryId,
            );
            return _TransactionDetailScaffold(
              transaction: record,
              categoryName: category.isEmpty
                  ? 'Kategori tidak tersedia'
                  : category.first.name,
              onEdit: () => context.push('/transactions/$transactionId/edit'),
              onDelete: () => _delete(context, ref, record.id),
            );
          },
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, int id) async {
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
    if (confirmed != true) return;

    try {
      final deleted = await ref
          .read(transactionRepositoryProvider)
          .softDelete(id);
      if (!deleted) throw StateError('Transaction is no longer active');
      if (context.mounted) context.pop();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi gagal dihapus. Coba lagi.')),
        );
      }
    }
  }
}

class _TransactionDetailScaffold extends StatelessWidget {
  const _TransactionDetailScaffold({
    required this.transaction,
    required this.categoryName,
    required this.onEdit,
    required this.onDelete,
  });

  final TransactionRecord transaction;
  final String categoryName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isExpense = transaction.type == TransactionType.expense;
    final typeLabel = isExpense ? 'Pengeluaran' : 'Pemasukan';
    final note = transaction.note?.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail transaksi'),
        actions: [
          IconButton(
            onPressed: onEdit,
            tooltip: 'Ubah transaksi',
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Hapus transaksi',
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.lg,
          AppSpacing.screenH,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            typeLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.amountColor(isExpense: isExpense),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${isExpense ? '-' : '+'}${formatIdr(transaction.amount)}',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: colors.amountColor(isExpense: isExpense),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  _DetailRow(label: 'Kategori', value: categoryName),
                  const Divider(height: AppSpacing.xl),
                  _DetailRow(
                    label: 'Tanggal',
                    value: formatDate(transaction.transactionDate),
                  ),
                  if (transaction.title.isNotEmpty) ...[
                    const Divider(height: AppSpacing.xl),
                    _DetailRow(label: 'Judul', value: transaction.title),
                  ],
                  const Divider(height: AppSpacing.xl),
                  _DetailRow(
                    label: 'Catatan',
                    value: note == null || note.isEmpty
                        ? 'Tidak ada catatan'
                        : note,
                    multiline: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            value,
            maxLines: multiline ? null : 2,
            overflow: multiline ? null : TextOverflow.ellipsis,
            style: textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) => const Scaffold(body: AppLoadingState());
}

class AppErrorScaffold extends StatelessWidget {
  const AppErrorScaffold({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: AppErrorState(message: message, onRetry: onRetry),
  );
}
