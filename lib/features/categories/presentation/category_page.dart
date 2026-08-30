import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../transactions/domain/transaction_type.dart';
import '../data/category_repository.dart';

class CategoryPage extends ConsumerStatefulWidget {
  const CategoryPage({super.key});

  @override
  ConsumerState<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends ConsumerState<CategoryPage> {
  TransactionType _selectedType = TransactionType.expense;

  @override
  Widget build(BuildContext context) {
    final initialization = ref.watch(categoryInitializationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kategori')),
      floatingActionButton: FloatingActionButton(
        onPressed: initialization.hasValue ? _createCategory : null,
        tooltip: 'Tambah kategori',
        child: const Icon(Icons.add),
      ),
      body: initialization.when(
        loading: () => const AppLoadingState(),
        error: (error, stackTrace) => AppErrorState(
          message: 'Kategori belum dapat dimuat.',
          onRetry: () => ref.invalidate(categoryInitializationProvider),
        ),
        data: (_) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.sm,
                AppSpacing.screenH,
                AppSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.expense,
                      icon: Icon(Icons.arrow_upward),
                      label: Text('Pengeluaran'),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      icon: Icon(Icons.arrow_downward),
                      label: Text('Pemasukan'),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (selection) {
                    setState(() => _selectedType = selection.single);
                  },
                ),
              ),
            ),
            Expanded(child: _CategoryList(type: _selectedType)),
          ],
        ),
      ),
    );
  }

  Future<void> _createCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _CategoryNameDialog(
        title: 'Tambah kategori',
        actionLabel: 'Tambah',
      ),
    );
    if (name == null || !mounted) return;

    try {
      await ref
          .read(categoryRepositoryProvider)
          .create(name: name, type: _selectedType);
    } catch (_) {
      if (mounted) _showError('Kategori gagal ditambahkan. Coba lagi.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.type});

  final TransactionType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesByTypeProvider(type));

    return categories.when(
      loading: () => const AppLoadingState(),
      error: (error, stackTrace) => AppErrorState(
        message: 'Kategori belum dapat dimuat.',
        onRetry: () => ref.invalidate(categoriesByTypeProvider(type)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const AppEmptyState(
            icon: Icons.category_outlined,
            message: 'Belum ada kategori.',
          );
        }

        // Wrap all items in a single card with dividers
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            0,
            AppSpacing.screenH,
            96,
          ),
          children: [
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _CategoryTile(category: items[i]),
                    if (i < items.length - 1)
                      const Divider(indent: 56, endIndent: 16),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category});

  final CategoryRecord category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final isExpense = category.type == TransactionType.expense;

    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: isExpense
            ? colors.errorContainer
            : colors.primaryContainer,
        foregroundColor: isExpense
            ? colors.onErrorContainer
            : colors.onPrimaryContainer,
        child: Icon(
          isExpense ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
        ),
      ),
      title: Text(category.name),
      trailing: PopupMenuButton<_CategoryAction>(
        tooltip: 'Tindakan kategori',
        onSelected: (action) => switch (action) {
          _CategoryAction.edit => _rename(context, ref),
          _CategoryAction.delete => _delete(context, ref),
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: _CategoryAction.edit, child: Text('Ubah')),
          PopupMenuItem(value: _CategoryAction.delete, child: Text('Hapus')),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _CategoryNameDialog(
        title: 'Ubah kategori',
        actionLabel: 'Simpan',
        initialName: category.name,
      ),
    );
    if (name == null || !context.mounted) return;

    try {
      final renamed = await ref
          .read(categoryRepositoryProvider)
          .rename(category.id, name);
      if (!renamed) throw StateError('Category is no longer active');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kategori gagal diubah. Coba lagi.')),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus kategori?'),
        content: Text('Kategori "${category.name}" tidak akan muncul lagi.'),
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
      final deleted = await ref
          .read(categoryRepositoryProvider)
          .softDelete(category.id);
      if (!deleted) throw StateError('Category is no longer active');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kategori gagal dihapus. Coba lagi.')),
        );
      }
    }
  }
}

class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog({
    required this.title,
    required this.actionLabel,
    this.initialName = '',
  });

  final String title;
  final String actionLabel;
  final String initialName;

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  late final TextEditingController _controller;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Nama kategori',
          errorText: _showError ? 'Nama kategori wajib diisi.' : null,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(context, name);
  }
}

enum _CategoryAction { edit, delete }
