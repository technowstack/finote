import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/finote_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../receipt_scanner/domain/receipt_data.dart';
import 'idr_amount_input.dart';
import 'transaction_draft.dart';

class ReceiptReviewSection extends StatelessWidget {
  const ReceiptReviewSection({
    super.key,
    required this.review,
    required this.items,
    required this.saveMode,
    required this.onSaveModeChanged,
    required this.onRemoveItem,
    required this.onAddItem,
    required this.onItemChanged,
    required this.onItemCategoryChanged,
    required this.categories,
    required this.defaultCategoryId,
  });

  final ReceiptReviewData review;
  final List<DraftReceiptItem> items;
  final ReceiptSaveMode saveMode;
  final ValueChanged<ReceiptSaveMode> onSaveModeChanged;
  final ValueChanged<DraftReceiptItem> onRemoveItem;
  final VoidCallback onAddItem;
  final VoidCallback onItemChanged;
  final void Function(DraftReceiptItem item, int? categoryId)
  onItemCategoryChanged;
  final List<CategoryRecord> categories;
  final int? defaultCategoryId;

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
                        inputFormatters: const [IdrInputFormatter()],
                        decoration: const InputDecoration(labelText: 'Nominal'),
                        onChanged: (_) => onItemChanged(),
                      ),
                    ),
                    // Removing an item is destructive: error color, not neutral.
                    IconButton(
                      tooltip: 'Hapus item',
                      onPressed: () => onRemoveItem(item),
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: Theme.of(context).finote.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
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
                : '${review.reconciliationMessage}\nSelisih: ${formatIdr(difference!.abs())}',
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
        if (saveMode == ReceiptSaveMode.itemized &&
            items.any(
              (item) =>
                  item.name.trim().isEmpty ||
                  item.amount <= 0 ||
                  (item.categoryId ?? defaultCategoryId) == null,
            ))
          Text(
            'Periksa nama, nominal, dan kategori setiap item sebelum menyimpan.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
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

class AddReceiptItemSheet extends StatefulWidget {
  const AddReceiptItemSheet({super.key});

  @override
  State<AddReceiptItemSheet> createState() => _AddReceiptItemSheetState();
}

class _AddReceiptItemSheetState extends State<AddReceiptItemSheet> {
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
            inputFormatters: const [IdrInputFormatter()],
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
    final unitPrice = parseIdrAmount(_unitPrice.text);
    if (quantity != null && quantity > 0 && unitPrice > 0) {
      final text = formatIdrAmountInput(quantity * unitPrice);
      _total.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _submit() {
    final name = _name.text.trim();
    final total = parseIdrAmount(_total.text);
    if (name.isEmpty || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan total item wajib diisi.')),
      );
      return;
    }
    final unitPrice = parseIdrAmount(_unitPrice.text);
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
