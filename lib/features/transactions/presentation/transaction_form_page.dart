import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../categories/data/category_repository.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction_source.dart';
import '../domain/transaction_type.dart';

class TransactionFormPage extends ConsumerWidget {
  const TransactionFormPage({super.key, this.transactionId});

  final int? transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialization = ref.watch(categoryInitializationProvider);

    return initialization.when(
      loading: () => const _LoadingPage(),
      error: (error, stackTrace) => _LoadErrorPage(
        onRetry: () => ref.invalidate(categoryInitializationProvider),
      ),
      data: (_) {
        final id = transactionId;
        if (id == null) return const _TransactionForm();

        return ref
            .watch(transactionByIdProvider(id))
            .when(
              loading: () => const _LoadingPage(),
              error: (error, stackTrace) => _LoadErrorPage(
                onRetry: () => ref.invalidate(transactionByIdProvider(id)),
              ),
              data: (transaction) => transaction == null
                  ? _LoadErrorPage(
                      onRetry: () =>
                          ref.invalidate(transactionByIdProvider(id)),
                    )
                  : _TransactionForm(transaction: transaction),
            );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Form
// ---------------------------------------------------------------------------

class _TransactionForm extends ConsumerStatefulWidget {
  const _TransactionForm({this.transaction});

  final TransactionRecord? transaction;

  @override
  ConsumerState<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<_TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late TransactionType _type;
  late DateTime _date;
  int? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _type = transaction?.type ?? TransactionType.expense;
    _date = transaction?.transactionDate ?? DateTime.now();
    _categoryId = transaction?.categoryId;
    _amountController = TextEditingController(
      text: transaction == null ? '' : _formatAmountInput(transaction.amount),
    );
    _titleController = TextEditingController(text: transaction?.title ?? '');
    _noteController = TextEditingController(text: transaction?.note ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesByTypeProvider(_type));
    final isEditing = widget.transaction != null;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Ubah transaksi' : 'Tambah transaksi'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: FilledButton(
            onPressed: _saving || !categories.hasValue ? null : _save,
            child: Text(_saving ? 'Menyimpan...' : 'Simpan transaksi'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.screenV,
            AppSpacing.screenH,
            AppSpacing.xl,
          ),
          children: [
            // ----- Type toggle (compact) -----
            _TypeToggle(
              value: _type,
              onChanged: (type) {
                setState(() {
                  _type = type;
                  _categoryId = null;
                });
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // ----- Amount (hero) -----
            TextFormField(
              controller: _amountController,
              autofocus: !isEditing,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: const [_IdrInputFormatter()],
              style: textTheme.displayMedium?.copyWith(
                color: colors.amountColor(
                  isExpense: _type == TransactionType.expense,
                ),
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: textTheme.displayMedium?.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                prefixText: 'Rp',
                prefixStyle: textTheme.headlineMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                border: InputBorder.none,
                filled: false,
              ),
              validator: (value) => _parseAmount(value ?? '') > 0
                  ? null
                  : 'Nominal harus lebih dari Rp0.',
              onFieldSubmitted: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
            ),
            const Divider(),
            const SizedBox(height: AppSpacing.md),

            // ----- Category grid -----
            Text('Kategori', style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            categories.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => AppErrorState(
                message: 'Kategori belum dapat dimuat.',
                onRetry: () =>
                    ref.invalidate(categoriesByTypeProvider(_type)),
              ),
              data: (items) => _CategoryGrid(
                categories: items,
                selectedId: _categoryId,
                isExpense: _type == TransactionType.expense,
                onSelected: (id) => setState(() => _categoryId = id),
              ),
            ),
            if (_formKey.currentState?.validate() == false &&
                _categoryId == null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Pilih kategori transaksi.',
                  style: textTheme.bodySmall?.copyWith(color: colors.error),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),

            // ----- Date chip -----
            _DateChip(
              date: _date,
              onTap: _selectDate,
            ),
            const SizedBox(height: AppSpacing.md),

            // ----- Optional title & note -----
            _OptionalFieldsSection(
              titleController: _titleController,
              noteController: _noteController,
              initiallyExpanded: isEditing &&
                  (_titleController.text.isNotEmpty ||
                      _noteController.text.isNotEmpty),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _categoryId == null) {
      // Force rebuild to show category error
      setState(() {});
      return;
    }
    final categoryId = _categoryId!;

    setState(() => _saving = true);
    final repository = ref.read(transactionRepositoryProvider);
    final note = _noteController.text.trim();

    try {
      final existing = widget.transaction;
      if (existing == null) {
        await repository.create(
          type: _type,
          categoryId: categoryId,
          amount: _parseAmount(_amountController.text),
          title: _titleController.text,
          note: note.isEmpty ? null : note,
          transactionDate: _date,
          source: TransactionSource.manual,
        );
      } else {
        final updated = await repository.update(
          existing.copyWith(
            type: _type,
            categoryId: categoryId,
            amount: _parseAmount(_amountController.text),
            title: _titleController.text.trim(),
            note: Value(note.isEmpty ? null : note),
            transactionDate: _date,
          ),
        );
        if (!updated) throw StateError('Transaction is no longer active');
        ref.invalidate(transactionByIdProvider(existing.id));
      }

      if (!mounted) return;
      context.canPop() ? context.pop() : context.go('/transactions');
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi gagal disimpan. Coba lagi.')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Type toggle — compact pill
// ---------------------------------------------------------------------------

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.value, required this.onChanged});

  final TransactionType value;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SegmentedButton<TransactionType>(
      segments: [
        ButtonSegment(
          value: TransactionType.expense,
          icon: Icon(
            Icons.arrow_upward,
            size: 18,
            color: value == TransactionType.expense
                ? colors.expenseColor
                : null,
          ),
          label: const Text('Pengeluaran'),
        ),
        ButtonSegment(
          value: TransactionType.income,
          icon: Icon(
            Icons.arrow_downward,
            size: 18,
            color: value == TransactionType.income
                ? colors.incomeColor
                : null,
          ),
          label: const Text('Pemasukan'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.single),
      style: SegmentedButton.styleFrom(
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category chip grid
// ---------------------------------------------------------------------------

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selectedId,
    required this.isExpense,
    required this.onSelected,
  });

  final List<CategoryRecord> categories;
  final int? selectedId;
  final bool isExpense;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text('Belum ada kategori.'),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final category in categories)
          ChoiceChip(
            label: Text(category.name),
            selected: category.id == selectedId,
            onSelected: (_) => onSelected(category.id),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Date chip
// ---------------------------------------------------------------------------

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        avatar: const Icon(Icons.calendar_today_outlined, size: 16),
        label: Text(isToday ? 'Hari ini' : formatDate(date)),
        onPressed: onTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Optional fields
// ---------------------------------------------------------------------------

class _OptionalFieldsSection extends StatelessWidget {
  const _OptionalFieldsSection({
    required this.titleController,
    required this.noteController,
    required this.initiallyExpanded,
  });

  final TextEditingController titleController;
  final TextEditingController noteController;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: initiallyExpanded,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(
        'Judul dan catatan',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: const Text('Opsional'),
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
      children: [
        TextFormField(
          controller: titleController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Judul',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: noteController,
          textCapitalization: TextCapitalization.sentences,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Catatan',
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Input formatter & helpers
// ---------------------------------------------------------------------------

class _IdrInputFormatter extends TextInputFormatter {
  const _IdrInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final amount = int.tryParse(digits);
    if (amount == null) return oldValue;
    final text = _formatAmountInput(amount);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

int _parseAmount(String value) =>
    int.tryParse(value.replaceAll(RegExp(r'\D'), '')) ?? 0;

String _formatAmountInput(int amount) =>
    formatIdr(amount).replaceFirst('Rp', '');

// ---------------------------------------------------------------------------
// Loading / error scaffolds
// ---------------------------------------------------------------------------

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: AppLoadingState());
  }
}

class _LoadErrorPage extends StatelessWidget {
  const _LoadErrorPage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi')),
      body: AppErrorState(
        message: 'Transaksi belum dapat dimuat.',
        onRetry: onRetry,
      ),
    );
  }
}
