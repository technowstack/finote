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
import '../../receipt_scanner/data/local_receipt_category_suggestion_service.dart';
import '../../receipt_scanner/domain/receipt_data.dart';
import '../../receipt_scanner/domain/receipt_category_suggestion.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction_source.dart';
import '../domain/transaction_type.dart';

class TransactionFormPage extends ConsumerWidget {
  const TransactionFormPage({super.key, this.transactionId, this.draft});

  final int? transactionId;
  final TransactionFormDraft? draft;

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
        if (id == null) return _TransactionForm(draft: draft);

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
  const _TransactionForm({this.transaction, this.draft});

  final TransactionRecord? transaction;
  final TransactionFormDraft? draft;

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
  CategorySuggestion? _categorySuggestion;
  bool _categoryManuallySelected = false;
  bool _saving = false;
  late final List<_DraftReceiptItem> _receiptItems;
  ReceiptSaveMode _saveMode = ReceiptSaveMode.single;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    final draft = widget.draft;
    _type = transaction?.type ?? draft?.type ?? TransactionType.expense;
    _date = transaction?.transactionDate ?? draft?.date ?? DateTime.now();
    _categoryId = transaction?.categoryId;
    _amountController = TextEditingController(
      text: transaction != null
          ? _formatAmountInput(transaction.amount)
          : draft?.amount == null
          ? ''
          : _formatAmountInput(draft!.amount!),
    );
    _titleController = TextEditingController(
      text: transaction?.title ?? draft?.title ?? '',
    );
    _noteController = TextEditingController(text: transaction?.note ?? '');
    _receiptItems = [
      for (final item in draft?.receiptReview?.items ?? const <ReceiptItem>[])
        _DraftReceiptItem(item),
    ];
    if (draft?.receiptReview != null) {
      _loadReceiptSuggestions(draft!.receiptReview!);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    for (final item in _receiptItems) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesByTypeProvider(_type));
    final isEditing = widget.transaction != null;
    final isReceiptDraft =
        widget.draft?.source == TransactionSource.receiptScan;
    final review = widget.draft?.receiptReview;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'Ubah transaksi'
              : isReceiptDraft
              ? 'Tinjau pengeluaran'
              : 'Tambah transaksi',
        ),
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
            child: Text(
              _saving
                  ? 'Menyimpan...'
                  : isReceiptDraft
                  ? 'Simpan pengeluaran'
                  : 'Simpan transaksi',
            ),
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
            if (isReceiptDraft)
              const Text('Pengeluaran dari struk')
            else
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

            if (review != null) ...[
              _ReceiptReviewSection(
                review: review,
                items: _receiptItems,
                saveMode: _saveMode,
                onSaveModeChanged: (mode) => setState(() => _saveMode = mode),
                onRemoveItem: (item) => setState(() {
                  _receiptItems.remove(item);
                  item.dispose();
                }),
                onAddItem: _addReceiptItem,
                onItemChanged: () => setState(() {}),
                onItemCategoryChanged: (item, categoryId) => setState(() {
                  item.categoryId = categoryId;
                  item.categoryManuallySelected = true;
                }),
                categories: categories.value ?? const [],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ----- Category grid -----
            Row(
              children: [
                Text('Kategori', style: textTheme.titleSmall),
                if (_categorySuggestion != null &&
                    !_categoryManuallySelected) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Disarankan',
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            categories.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => AppErrorState(
                message: 'Kategori belum dapat dimuat.',
                onRetry: () => ref.invalidate(categoriesByTypeProvider(_type)),
              ),
              data: (items) => _CategoryGrid(
                categories: items,
                selectedId: _categoryId,
                isExpense: _type == TransactionType.expense,
                onSelected: (id) => setState(() {
                  _categoryId = id;
                  _categoryManuallySelected = true;
                }),
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
            _DateChip(date: _date, onTap: _selectDate),
            if (isReceiptDraft && widget.draft!.date == null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Tanggal tidak terbaca. Menggunakan hari ini, silakan periksa.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),

            // ----- Optional title & note -----
            _OptionalFieldsSection(
              titleController: _titleController,
              noteController: _noteController,
              initiallyExpanded:
                  isReceiptDraft ||
                  isEditing &&
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

  Future<void> _addReceiptItem() async {
    final item = await showModalBottomSheet<ReceiptItem>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AddReceiptItemSheet(),
    );
    if (item != null && mounted) {
      setState(() => _receiptItems.add(_DraftReceiptItem(item)));
    }
  }

  Future<void> _loadReceiptSuggestions(ReceiptReviewData review) async {
    final service = ref.read(receiptCategorySuggestionServiceProvider);
    final items = List<_DraftReceiptItem>.of(_receiptItems);
    final receiptSuggestion = await service.suggestReceiptCategory(
      merchant: review.merchant,
      rawText: review.rawOcrText,
    );
    final itemSuggestions = <CategorySuggestion?>[];
    for (final item in items) {
      itemSuggestions.add(await service.suggestItemCategory(item.item));
    }
    if (!mounted) return;
    setState(() {
      if (!_categoryManuallySelected && receiptSuggestion != null) {
        _categoryId = receiptSuggestion.categoryId;
        _categorySuggestion = receiptSuggestion;
      }
      for (var i = 0; i < items.length; i++) {
        final suggestion = itemSuggestions[i];
        if (!items[i].categoryManuallySelected && suggestion != null) {
          items[i]
            ..categoryId = suggestion.categoryId
            ..categorySuggestion = suggestion;
        }
      }
    });
  }

  Future<void> _save() async {
    final router = GoRouter.of(context);
    final itemEntries = [
      for (final item in _receiptItems)
        if (item.amount > 0 &&
            item.name.trim().isNotEmpty &&
            (item.categoryId ?? _categoryId) != null)
          (
            amount: item.amount,
            title: item.name.trim(),
            transactionDate: _date,
            categoryId: (item.categoryId ?? _categoryId)!,
          ),
    ];
    final isItemized =
        widget.draft?.receiptReview != null &&
        _saveMode == ReceiptSaveMode.itemized;
    if ((!isItemized && !_formKey.currentState!.validate()) ||
        (isItemized && itemEntries.isEmpty) ||
        (!isItemized && _categoryId == null)) {
      // Force rebuild to show category error
      setState(() {});
      return;
    }
    final categoryId = _categoryId;

    setState(() => _saving = true);
    final repository = ref.read(transactionRepositoryProvider);
    final note = _noteController.text.trim();

    try {
      final existing = widget.transaction;
      if (existing == null) {
        if (isItemized) {
          await repository.createManyWithCategories(
            type: _type,
            entries: itemEntries,
            source: TransactionSource.receiptScan,
          );
        } else {
          await repository.create(
            type: _type,
            categoryId: categoryId!,
            amount: _parseAmount(_amountController.text),
            title: _titleController.text,
            note: note.isEmpty ? null : note,
            transactionDate: _date,
            source: widget.draft?.source ?? TransactionSource.manual,
          );
        }
      } else {
        final updated = await repository.update(
          existing.copyWith(
            type: _type,
            categoryId: categoryId!,
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
      final service = ref.read(receiptCategorySuggestionServiceProvider);
      if (_categoryId != null &&
          widget.draft?.receiptReview?.merchant?.isNotEmpty == true) {
        await service.learnReceiptCategory(
          merchant: widget.draft!.receiptReview!.merchant!,
          categoryId: _categoryId!,
        );
      }
      for (final item in _receiptItems) {
        final itemCategory = item.categoryId ?? _categoryId;
        if (itemCategory != null) {
          await service.learnItemCategory(
            itemName: item.name,
            categoryId: itemCategory,
          );
        }
      }
      router.canPop() ? router.pop() : router.go('/transactions');
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

class TransactionFormDraft {
  const TransactionFormDraft({
    required this.type,
    required this.source,
    this.amount,
    this.title = '',
    this.date,
    this.receiptReview,
  });

  final TransactionType type;
  final TransactionSource source;
  final int? amount;
  final String title;
  final DateTime? date;
  final ReceiptReviewData? receiptReview;
}

enum ReceiptSaveMode { single, itemized }

class _DraftReceiptItem {
  _DraftReceiptItem(this.item)
    : nameController = TextEditingController(text: item.name),
      amountController = TextEditingController(
        text: item.lineTotal == null ? '' : _formatAmountInput(item.lineTotal!),
      );

  final ReceiptItem item;
  final TextEditingController nameController;
  final TextEditingController amountController;
  int? categoryId;
  CategorySuggestion? categorySuggestion;
  bool categoryManuallySelected = false;

  String get name => nameController.text;
  int get amount => _parseAmount(amountController.text);

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

class _ReceiptReviewSection extends StatelessWidget {
  const _ReceiptReviewSection({
    required this.review,
    required this.items,
    required this.saveMode,
    required this.onSaveModeChanged,
    required this.onRemoveItem,
    required this.onAddItem,
    required this.onItemChanged,
    required this.onItemCategoryChanged,
    required this.categories,
  });

  final ReceiptReviewData review;
  final List<_DraftReceiptItem> items;
  final ReceiptSaveMode saveMode;
  final ValueChanged<ReceiptSaveMode> onSaveModeChanged;
  final ValueChanged<_DraftReceiptItem> onRemoveItem;
  final VoidCallback onAddItem;
  final VoidCallback onItemChanged;
  final void Function(_DraftReceiptItem item, int? categoryId)
  onItemCategoryChanged;
  final List<CategoryRecord> categories;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final itemTotal = items.fold(0, (sum, item) => sum + item.amount);
    final difference = review.total == null ? null : itemTotal - review.total!;
    final warnings = [
      ...review.warnings,
      if (items.any((item) => item.amount <= 0))
        'Periksa nominal setiap item sebelum memilih mode per item.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detail struk', style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Merchant: ${review.merchant?.isNotEmpty == true ? review.merchant : 'Belum terbaca'}',
        ),
        if (review.receiptNumber != null)
          Text('Nomor struk: ${review.receiptNumber}'),
        const SizedBox(height: AppSpacing.md),
        Text('Item', style: textTheme.titleSmall),
        if (items.isEmpty)
          const Text(
            'Belum ada item yang berhasil dibaca. Kamu dapat menambahkan item secara manual.',
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAddItem,
            icon: const Icon(Icons.add),
            label: const Text('Tambah item'),
          ),
        ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: item.nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama item',
                        ),
                        onChanged: (_) => onItemChanged(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 125,
                      child: TextFormField(
                        controller: item.amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: const [_IdrInputFormatter()],
                        decoration: const InputDecoration(labelText: 'Nominal'),
                        onChanged: (_) => onItemChanged(),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus item',
                      onPressed: () => onRemoveItem(item),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
                DropdownButtonFormField<int?>(
                  initialValue: item.categoryId,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Default struk'),
                    ),
                    for (final category in categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (id) => onItemCategoryChanged(item, id),
                ),
              ],
            ),
          ),
        Text('Jumlah item: ${formatIdr(itemTotal)}'),
        if (review.subtotal != null)
          Text('Subtotal terdeteksi: ${formatIdr(review.subtotal!)}'),
        if (review.total != null) ...[
          Text('Total struk: ${formatIdr(review.total!)}'),
          Text(
            difference == 0
                ? 'Status: Cocok'
                : 'Selisih: ${formatIdr(difference!.abs())}. Periksa pajak, diskon, item yang belum terbaca, atau OCR.',
          ),
        ],
        if (review.tax != null)
          Text('Pajak terdeteksi: ${formatIdr(review.tax!)}'),
        if (review.discount != null)
          Text('Diskon terdeteksi: ${formatIdr(review.discount!)}'),
        if (warnings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              warnings.join('\n'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text('Cara menyimpan', style: textTheme.titleSmall),
        SegmentedButton<ReceiptSaveMode>(
          segments: const [
            ButtonSegment(
              value: ReceiptSaveMode.single,
              label: Text('Satu transaksi'),
            ),
            ButtonSegment(
              value: ReceiptSaveMode.itemized,
              label: Text('Pisahkan per item'),
            ),
          ],
          selected: {saveMode},
          onSelectionChanged: (selection) =>
              onSaveModeChanged(selection.single),
        ),
        const SizedBox(height: AppSpacing.sm),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Teks hasil OCR'),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(review.rawOcrText),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddReceiptItemSheet extends StatefulWidget {
  const _AddReceiptItemSheet();

  @override
  State<_AddReceiptItemSheet> createState() => _AddReceiptItemSheetState();
}

class _AddReceiptItemSheetState extends State<_AddReceiptItemSheet> {
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _unitPrice = TextEditingController();
  final _total = TextEditingController();
  bool _totalOverridden = false;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _total.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + bottom,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('Tambah item', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nama item'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Jumlah / Quantity (opsional)',
            ),
            onChanged: (_) => _calculateTotal(),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _unitPrice,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Harga satuan (opsional)',
            ),
            onChanged: (_) => _calculateTotal(),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _total,
            keyboardType: TextInputType.number,
            inputFormatters: const [_IdrInputFormatter()],
            decoration: const InputDecoration(labelText: 'Total item *'),
            onChanged: (_) => _totalOverridden = true,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _submit, child: const Text('Tambahkan')),
        ],
      ),
    );
  }

  void _calculateTotal() {
    if (_totalOverridden) return;
    final quantity = int.tryParse(_quantity.text.trim());
    final unitPrice = _parseAmount(_unitPrice.text);
    if (quantity != null && quantity > 0 && unitPrice > 0) {
      final text = _formatAmountInput(quantity * unitPrice);
      _total.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _submit() {
    final name = _name.text.trim();
    final total = _parseAmount(_total.text);
    if (name.isEmpty || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan total item wajib diisi.')),
      );
      return;
    }
    final unitPrice = _parseAmount(_unitPrice.text);
    Navigator.pop(
      context,
      ReceiptItem(
        name: name,
        quantity: int.tryParse(_quantity.text.trim()),
        unitPrice: unitPrice > 0 ? unitPrice : null,
        lineTotal: total,
        source: ReceiptItemSource.manual,
      ),
    );
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
            color: value == TransactionType.income ? colors.incomeColor : null,
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
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

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
          decoration: const InputDecoration(labelText: 'Judul'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: noteController,
          textCapitalization: TextCapitalization.sentences,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Catatan'),
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
