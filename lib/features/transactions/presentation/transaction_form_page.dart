import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../categories/data/category_repository.dart';
import '../../accounts/data/account_repository.dart';
import '../../receipt_scanner/data/local_receipt_category_suggestion_service.dart';
import '../../receipt_scanner/data/receipt_duplicate_detector.dart';
import '../../receipt_scanner/domain/receipt_duplicate.dart';
import '../../receipt_scanner/domain/receipt_data.dart';
import '../../receipt_scanner/domain/receipt_category_suggestion.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction_source.dart';
import '../domain/transaction_type.dart';
export 'widgets/transaction_draft.dart';
import 'widgets/idr_amount_input.dart';
import 'widgets/transaction_draft.dart';
import 'widgets/transaction_form_fields.dart';
import 'widgets/receipt_review_section.dart';

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
  int? _accountId;
  CategorySuggestion? _categorySuggestion;
  bool _categoryManuallySelected = false;
  bool _showCategoryError = false;
  bool _saving = false;
  late final List<DraftReceiptItem> _receiptItems;
  ReceiptSaveMode _saveMode = ReceiptSaveMode.single;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    final draft = widget.draft;
    _type = transaction?.type ?? draft?.type ?? TransactionType.expense;
    _date = transaction?.transactionDate ?? draft?.date ?? DateTime.now();
    _categoryId = transaction?.categoryId;
    _accountId = transaction?.accountId;
    _amountController = TextEditingController(
      text: transaction != null
          ? formatIdrAmountInput(transaction.amount)
          : draft?.amount == null
          ? ''
          : formatIdrAmountInput(draft!.amount!),
    );
    _titleController = TextEditingController(
      text: transaction?.title ?? draft?.title ?? '',
    );
    _noteController = TextEditingController(text: transaction?.note ?? '');
    _receiptItems = [
      for (final item in draft?.receiptReview?.items ?? const <ReceiptItem>[])
        DraftReceiptItem(item),
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
    final accounts = ref.watch(accountsProvider);
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
                  : isEditing
                  ? 'Simpan perubahan'
                  : _type == TransactionType.income
                  ? 'Simpan pemasukan'
                  : 'Simpan pengeluaran',
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
              TransactionTypeToggle(
                value: _type,
                onChanged: (type) {
                  setState(() {
                    _type = type;
                    _categoryId = null;
                    _showCategoryError = false;
                  });
                },
              ),
            const SizedBox(height: AppSpacing.lg),

            // ----- Amount (hero) -----
            Text(
              _type == TransactionType.income
                  ? 'Nominal pemasukan'
                  : 'Nominal pengeluaran',
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _amountController,
              autofocus: !isEditing,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: const [IdrInputFormatter()],
              style: textTheme.displayMedium?.copyWith(
                color: colors.amountColor(
                  isExpense: _type == TransactionType.expense,
                ),
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                helperText: 'Bilangan bulat, tanpa desimal',
                hintStyle: textTheme.displayMedium?.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                prefixText: 'Rp',
                prefixStyle: textTheme.headlineMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                // Border and fill come from the theme's input states
                // (default, focus, error), as in components.md Input/Nominal.
              ),
              validator: (value) => parseIdrAmount(value ?? '') > 0
                  ? null
                  : 'Masukkan nominal yang valid.',
              onFieldSubmitted: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
            ),
            const Divider(),
            const SizedBox(height: AppSpacing.md),

            if (review != null) ...[
              ReceiptReviewSection(
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
                defaultCategoryId: _categoryId,
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
              data: (items) => TransactionCategoryGrid(
                categories: items,
                selectedId: _categoryId,
                isExpense: _type == TransactionType.expense,
                onSelected: (id) => setState(() {
                  _categoryId = id;
                  _categoryManuallySelected = true;
                  _showCategoryError = false;
                }),
              ),
            ),
            if (isEditing &&
                _categoryId != null &&
                categories.valueOrNull?.every(
                      (category) => category.id != _categoryId,
                    ) ==
                    true)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Kategori lama tidak tersedia. Pilih kategori pengganti.',
                  style: textTheme.bodySmall?.copyWith(color: colors.error),
                ),
              ),
            if (_showCategoryError && _categoryId == null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Pilih kategori transaksi.',
                  style: textTheme.bodySmall?.copyWith(color: colors.error),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),

            // ----- Account picker -----
            Text('Akun', style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            accounts.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => AppErrorState(
                message: 'Akun belum dapat dimuat.',
                onRetry: () => ref.invalidate(accountsProvider),
              ),
              data: (items) {
                final selectedId = _selectedAccountId(items);
                final selected = items.where((a) => a.id == selectedId);
                final isDefaultSelected =
                    selected.isNotEmpty && selected.first.isDefault;
                final options = [
                  for (final account in items)
                    if (account.isActive || account.id == selectedId) account,
                ];
                return DropdownButtonFormField<int>(
                  initialValue: selectedId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'Pilih akun',
                    helperText: isDefaultSelected ? 'Akun default' : null,
                    prefixIcon: const Icon(
                      Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  items: [
                    for (final account in options)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          '${account.name}'
                          '${account.isActive ? '' : ' (Tidak aktif)'}',
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _accountId = value),
                  validator: (_) => selectedId == null ? 'Pilih akun.' : null,
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // ----- Date chip -----
            TransactionDateChip(date: _date, onTap: _selectDate),
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
            OptionalFieldsSection(
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
      builder: (context) => const AddReceiptItemSheet(),
    );
    if (item != null && mounted) {
      setState(() => _receiptItems.add(DraftReceiptItem(item)));
    }
  }

  Future<void> _loadReceiptSuggestions(ReceiptReviewData review) async {
    final service = ref.read(receiptCategorySuggestionServiceProvider);
    final items = List<DraftReceiptItem>.of(_receiptItems);
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
    if (_saving) return;
    var leftForm = false;
    final router = GoRouter.of(context);
    final isItemized =
        widget.draft?.receiptReview != null &&
        _saveMode == ReceiptSaveMode.itemized;
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
    final hasInvalidItem = _receiptItems.any(
      (item) =>
          item.name.trim().isEmpty ||
          item.amount <= 0 ||
          (item.categoryId ?? _categoryId) == null,
    );
    final availableCategoryIds = ref
        .read(categoriesByTypeProvider(_type))
        .valueOrNull
        ?.map((category) => category.id)
        .toSet();
    if ((!isItemized && !_formKey.currentState!.validate()) ||
        (isItemized && hasInvalidItem) ||
        (isItemized && itemEntries.isEmpty) ||
        (!isItemized &&
            (_categoryId == null ||
                availableCategoryIds?.contains(_categoryId) != true))) {
      setState(() => _showCategoryError = _categoryId == null);
      return;
    }
    final categoryId = _categoryId;
    final accountId = _selectedAccountId(
      ref.read(accountsProvider).valueOrNull ?? const [],
    );
    if (accountId == null) {
      setState(() => _showCategoryError = _categoryId == null);
      return;
    }

    setState(() => _saving = true);
    try {
      final review = widget.draft?.receiptReview;
      final identity = review == null
          ? null
          : ReceiptIdentity(
              merchant: review.merchant ?? _titleController.text,
              date: _date,
              total: isItemized
                  ? review.total ?? 0
                  : parseIdrAmount(_amountController.text),
              receiptNumber: review.receiptNumber,
              items: [
                for (final item in _receiptItems)
                  ReceiptItem(name: item.name, lineTotal: item.amount),
              ],
            );
      final fingerprint = identity == null
          ? null
          : await identity.fingerprint();
      if (identity != null && fingerprint != null && identity.total > 0) {
        final duplicate = await ref
            .read(receiptDuplicateDetectorProvider)
            .findDuplicate(identity);
        if (!mounted) return;
        if (duplicate != null) {
          final action = await _confirmDuplicate(duplicate, identity);
          if (!mounted) return;
          if (action == _DuplicateAction.view) {
            leftForm = true;
            router.go('/transactions');
            return;
          }
          if (action != _DuplicateAction.save) {
            return;
          }
        }
      }

      final repository = ref.read(transactionRepositoryProvider);
      final note = _noteController.text.trim();

      final existing = widget.transaction;
      if (existing == null) {
        if (isItemized) {
          await repository.createManyWithCategories(
            type: _type,
            entries: itemEntries,
            accountId: accountId,
            source: TransactionSource.receiptScan,
            receiptFingerprint: fingerprint,
          );
        } else {
          await repository.create(
            type: _type,
            accountId: accountId,
            categoryId: categoryId!,
            amount: parseIdrAmount(_amountController.text),
            title: _titleController.text,
            note: note.isEmpty ? null : note,
            transactionDate: _date,
            source: widget.draft?.source ?? TransactionSource.manual,
            receiptFingerprint: fingerprint,
          );
        }
      } else {
        final updated = await repository.update(
          existing.copyWith(
            type: _type,
            categoryId: categoryId!,
            accountId: Value(accountId),
            amount: parseIdrAmount(_amountController.text),
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
      leftForm = true;
      router.canPop() ? router.pop() : router.go('/transactions');
    } catch (error) {
      if (mounted) {
        final message =
            error is StateError &&
                error.message ==
                    'Edit linked investment transaction from asset activity'
            ? 'Transaksi pembelian/penjualan aset harus diubah dari detail aset.'
            : widget.transaction == null
            ? 'Gagal menyimpan transaksi. Silakan coba lagi.'
            : 'Gagal memperbarui transaksi. Silakan coba lagi.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted && !leftForm) {
        setState(() => _saving = false);
      }
    }
  }

  Future<_DuplicateAction?> _confirmDuplicate(
    ReceiptDuplicate duplicate,
    ReceiptIdentity identity,
  ) {
    final title = duplicate.level == ReceiptDuplicateLevel.strong
        ? 'Struk ini kemungkinan sudah pernah disimpan.'
        : 'Transaksi serupa sudah ada.';
    return showDialog<_DuplicateAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          '${identity.merchant}\n${formatDate(identity.date)}\n${formatIdr(identity.total)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _DuplicateAction.view),
            child: const Text('Lihat transaksi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _DuplicateAction.cancel),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _DuplicateAction.save),
            child: const Text('Tetap simpan'),
          ),
        ],
      ),
    );
  }

  int? _selectedAccountId(List<AccountRecord> accounts) {
    if (_accountId != null &&
        accounts.any((account) => account.id == _accountId)) {
      return _accountId;
    }
    return accounts
            .where((account) => account.isActive && account.isDefault)
            .firstOrNull
            ?.id ??
        accounts.where((account) => account.isActive).firstOrNull?.id;
  }
}

enum _DuplicateAction { view, cancel, save }

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
