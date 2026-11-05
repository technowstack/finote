import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/asset_transaction_repository.dart';
import '../../domain/asset_quantity.dart';
import '../../domain/asset_type.dart';
import 'asset_formatters.dart';

Future<void> showOpeningPositionForm(
  BuildContext context,
  WidgetRef ref,
  AssetRecord asset,
  AssetTransactionRecord? opening,
) async {
  final data = await showDialog<_OpeningPositionData>(
    context: context,
    builder: (_) => _OpeningPositionDialog(asset: asset, opening: opening),
  );
  if (data == null || !context.mounted) return;
  try {
    final repository = ref.read(assetTransactionRepositoryProvider);
    if (opening == null) {
      await repository.createOpeningPosition(
        assetId: asset.id,
        quantity: data.quantity,
        transactionDate: data.date,
        totalAmount: data.totalAmount,
        note: data.note,
      );
    } else {
      final updated = await repository.updateOpeningPosition(
        id: opening.id,
        quantity: data.quantity,
        transactionDate: data.date,
        totalAmount: data.totalAmount,
        note: data.note,
      );
      if (!updated) throw StateError('Opening position is no longer available');
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError &&
                    error.message == 'Opening position already exists'
                ? 'Posisi awal sudah tersedia. Edit posisi yang ada.'
                : 'Posisi awal gagal disimpan. Coba lagi.',
          ),
        ),
      );
    }
  }
}

Future<void> removeAssetOpeningPosition(
  BuildContext context,
  WidgetRef ref,
  int id,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Hapus Posisi Awal?'),
      content: const Text('Aset akan kembali ke status Belum ada posisi.'),
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
        .read(assetTransactionRepositoryProvider)
        .removeOpeningPosition(id);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Posisi awal tidak dapat dihapus.')),
      );
    }
  }
}

class _OpeningPositionData {
  const _OpeningPositionData({
    required this.quantity,
    required this.date,
    required this.totalAmount,
    required this.note,
  });

  final AssetQuantity quantity;
  final DateTime date;
  final int? totalAmount;
  final String? note;
}

class _OpeningPositionDialog extends StatefulWidget {
  const _OpeningPositionDialog({required this.asset, this.opening});

  final AssetRecord asset;
  final AssetTransactionRecord? opening;

  @override
  State<_OpeningPositionDialog> createState() => _OpeningPositionDialogState();
}

class _OpeningPositionDialogState extends State<_OpeningPositionDialog> {
  late final TextEditingController _quantity;
  late final TextEditingController _cost;
  late final TextEditingController _note;
  late DateTime _date;
  late bool _hasCost;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final opening = widget.opening;
    final quantity = opening == null
        ? ''
        : inputQuantityText(
            widget.asset,
            AssetQuantity.fromScaled(opening.quantityScaled),
          );
    _quantity = TextEditingController(text: quantity);
    _cost = TextEditingController(
      text: opening?.totalAmount == null
          ? ''
          : opening!.totalAmount!.toString(),
    );
    _note = TextEditingController(text: opening?.note ?? '');
    _date = opening?.transactionDate ?? DateTime.now();
    _hasCost = opening?.totalAmount != null;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _cost.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStock = widget.asset.assetType == AssetType.stock;
    return AlertDialog(
      title: const Text('Posisi Awal'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.asset.symbol == null
                      ? widget.asset.name
                      : '${widget.asset.symbol}\n${widget.asset.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _quantity,
                autofocus: true,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: !isStock,
                ),
                decoration: InputDecoration(
                  labelText: isStock
                      ? 'Jumlah Lot'
                      : 'Jumlah ${quantityUnitLabel(widget.asset)}',
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  try {
                    final quantity = parseOpeningQuantity(
                      widget.asset,
                      value ?? '',
                    );
                    return quantity.isNegative || quantity.isZero
                        ? 'Jumlah harus lebih dari 0'
                        : null;
                  } catch (_) {
                    return isStock
                        ? 'Masukkan jumlah lot bulat yang valid'
                        : 'Masukkan jumlah dengan maksimal 8 angka desimal';
                  }
                },
              ),
              if (isStock)
                if (stockSharesPreview(_quantity.text) case final shares?)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Jumlah Lembar: ${formatPlainInteger(shares)}'),
                  ),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tanggal Posisi'),
                subtitle: Text(formatPositionDate(context, _date)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (selected != null && mounted) {
                    setState(() => _date = selected);
                  }
                },
              ),
              if (widget.opening == null)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tanggal ini menandai awal pencatatan aset di Finote, bukan tanggal pembelian asli.',
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Saya tahu modal awal'),
                subtitle: Text(
                  _hasCost ? 'Modal akan disimpan' : 'Tidak diketahui',
                ),
                value: _hasCost,
                onChanged: (value) => setState(() => _hasCost = value),
              ),
              if (_hasCost) ...[
                TextFormField(
                  controller: _cost,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Modal Awal',
                    prefixText: 'Rp ',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) =>
                      _hasCost && parseMoneyDigits(value ?? '') <= 0
                      ? 'Modal harus lebih dari 0'
                      : null,
                ),

                if (parseMoneyDigits(_cost.text) > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        formatIdr(parseMoneyDigits(_cost.text)),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _save, child: const Text('Simpan Posisi')),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _OpeningPositionData(
        quantity: parseOpeningQuantity(widget.asset, _quantity.text),
        date: _date,
        totalAmount: _hasCost ? parseMoneyDigits(_cost.text) : null,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }
}
