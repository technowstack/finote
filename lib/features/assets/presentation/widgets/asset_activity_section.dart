import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/asset_activity_service.dart';
import '../../data/asset_transaction_repository.dart';
import '../../domain/asset_quantity.dart';
import '../../domain/asset_transaction_action.dart';
import '../../domain/asset_type.dart';
import '../../../accounts/data/account_repository.dart';
import '../../../transactions/data/transaction_repository.dart';
import 'asset_formatters.dart';

Future<void> showActivityMenu(
  BuildContext context,
  WidgetRef ref,
  AssetRecord asset,
) async {
  final action = await showModalBottomSheet<AssetTransactionAction>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add_shopping_cart),
            title: const Text('Beli'),
            onTap: () => Navigator.pop(context, AssetTransactionAction.buy),
          ),
          ListTile(
            leading: const Icon(Icons.sell_outlined),
            title: const Text('Jual'),
            onTap: () => Navigator.pop(context, AssetTransactionAction.sell),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Penyesuaian'),
            onTap: () =>
                Navigator.pop(context, AssetTransactionAction.adjustment),
          ),
        ],
      ),
    ),
  );
  if (action != null && context.mounted) {
    await showActivityForm(context, ref, asset, null, action: action);
  }
}

Future<void> showActivityForm(
  BuildContext context,
  WidgetRef ref,
  AssetRecord asset,
  AssetTransactionRecord? activity, {
  AssetTransactionAction? action,
}) async {
  final selectedAction = action ?? activity?.action;
  if (selectedAction == null) return;
  final sourceTransactionId = activity?.sourceTransactionId;
  final initialAccountId = sourceTransactionId == null
      ? null
      : (await ref
                .read(transactionRepositoryProvider)
                .findActiveById(sourceTransactionId))
            ?.accountId;
  if (!context.mounted) return;
  final data = await showDialog<_ActivityFormData>(
    context: context,
    builder: (_) => _ActivityFormDialog(
      asset: asset,
      action: selectedAction,
      activity: activity,
      initialAccountId: initialAccountId,
    ),
  );
  if (data == null || !context.mounted) return;
  try {
    final service = ref.read(assetActivityServiceProvider);
    final id = activity?.id;
    if (id == null) {
      switch (selectedAction) {
        case AssetTransactionAction.buy:
          await service.createBuy(
            assetId: asset.id,
            quantity: data.quantity,
            priceAmount: data.priceAmount!,
            accountId: data.accountId!,
            date: data.date,
            note: data.note,
          );
        case AssetTransactionAction.sell:
          await service.createSell(
            assetId: asset.id,
            quantity: data.quantity,
            priceAmount: data.priceAmount!,
            accountId: data.accountId!,
            date: data.date,
            note: data.note,
          );
        case AssetTransactionAction.adjustment:
          await service.createAdjustment(
            assetId: asset.id,
            quantity: data.quantity,
            date: data.date,
            note: data.note,
          );
        case AssetTransactionAction.openingPosition:
          return;
      }
    } else {
      switch (selectedAction) {
        case AssetTransactionAction.buy:
          await service.updateBuy(
            activityId: id,
            quantity: data.quantity,
            priceAmount: data.priceAmount!,
            accountId: data.accountId!,
            date: data.date,
            note: data.note,
          );
        case AssetTransactionAction.sell:
          await service.updateSell(
            activityId: id,
            quantity: data.quantity,
            priceAmount: data.priceAmount!,
            accountId: data.accountId!,
            date: data.date,
            note: data.note,
          );
        case AssetTransactionAction.adjustment:
          await service.updateAdjustment(
            activityId: id,
            quantity: data.quantity,
            date: data.date,
            note: data.note,
          );
        case AssetTransactionAction.openingPosition:
          return;
      }
    }
  } catch (error) {
    if (context.mounted) {
      final message =
          error is StateError &&
              error.message == 'Sell quantity exceeds holdings'
          ? 'Jumlah yang dijual melebihi aset yang dimiliki.'
          : error is StateError &&
                error.message == 'Activity would make holdings negative'
          ? 'Perubahan akan membuat posisi aset menjadi negatif.'
          : 'Aktivitas gagal disimpan. Coba lagi.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

Future<void> deleteActivity(
  BuildContext context,
  WidgetRef ref,
  AssetTransactionRecord activity,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Hapus aktivitas?'),
      content: Text(
        activity.sourceTransactionId == null
            ? 'Aktivitas ini akan dihapus dari riwayat aset.'
            : 'Transaksi kas yang terhubung juga akan dihapus.',
      ),
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
    await ref.read(assetActivityServiceProvider).delete(activity.id);
  } catch (error) {
    if (context.mounted) {
      final message =
          error is StateError &&
              error.message == 'Delete would make holdings negative'
          ? 'Aktivitas tidak dapat dihapus karena posisi aset akan menjadi negatif.'
          : 'Aktivitas gagal dihapus.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class AssetActivityTile extends StatelessWidget {
  const AssetActivityTile({
    super.key,
    required this.asset,
    required this.activity,
    required this.onEdit,
    required this.onDelete,
  });

  final AssetRecord asset;
  final AssetTransactionRecord activity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final quantity = AssetQuantity.fromScaled(activity.quantityScaled);
    final label = switch (activity.action) {
      AssetTransactionAction.buy => 'Beli',
      AssetTransactionAction.sell => 'Jual',
      AssetTransactionAction.adjustment => 'Penyesuaian',
      AssetTransactionAction.openingPosition => 'Posisi Awal',
    };
    final prefix = activity.action == AssetTransactionAction.sell
        ? '-'
        : activity.action == AssetTransactionAction.adjustment &&
              quantity.isNegative
        ? ''
        : '+';
    final historicalPrice = activity.priceAmount == null
        ? null
        : '${formatIdr(activity.priceAmount!)} / ${assetPriceUnit(asset)}';
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(
          [
            formatPositionDate(context, activity.transactionDate),
            '$prefix${formatAssetQuantity(asset, quantity)}'
                '${historicalPrice == null ? '' : ' @ $historicalPrice'}',
            if (activity.totalAmount != null) formatIdr(activity.totalAmount!),
          ].join('\n'),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Tindakan aktivitas',
          onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Ubah')),
            PopupMenuItem(value: 'delete', child: Text('Hapus')),
          ],
        ),
      ),
    );
  }
}

class _ActivityFormData {
  const _ActivityFormData({
    required this.quantity,
    required this.priceAmount,
    required this.accountId,
    required this.date,
    required this.note,
  });

  final AssetQuantity quantity;
  final int? priceAmount;
  final int? accountId;
  final DateTime date;
  final String? note;
}

class _ActivityFormDialog extends ConsumerStatefulWidget {
  const _ActivityFormDialog({
    required this.asset,
    required this.action,
    this.activity,
    this.initialAccountId,
  });

  final AssetRecord asset;
  final AssetTransactionAction action;
  final AssetTransactionRecord? activity;
  final int? initialAccountId;

  @override
  ConsumerState<_ActivityFormDialog> createState() =>
      _ActivityFormDialogState();
}

class _ActivityFormDialogState extends ConsumerState<_ActivityFormDialog> {
  late final TextEditingController _quantity;
  late final TextEditingController _price;
  late final TextEditingController _note;
  late DateTime _date;
  late bool _increase;
  late bool _exactStockShares;
  int? _accountId;
  final _formKey = GlobalKey<FormState>();

  bool get isAdjustment => widget.action == AssetTransactionAction.adjustment;
  bool get isStock => widget.asset.assetType == AssetType.stock;

  @override
  void initState() {
    super.initState();
    final activity = widget.activity;
    final activityQuantity = activity == null
        ? null
        : AssetQuantity.fromScaled(activity.quantityScaled);
    _exactStockShares =
        isStock &&
        widget.action == AssetTransactionAction.adjustment &&
        activityQuantity != null &&
        activityQuantity.scaled % (AssetQuantity.scale * 100) != 0;
    final quantity = activity == null
        ? ''
        : _exactStockShares
        ? formatStockSharesInput(activityQuantity!)
        : inputActivityQuantity(widget.asset, activityQuantity!);
    _quantity = TextEditingController(text: quantity);
    _price = TextEditingController(
      text: activity?.priceAmount?.toString() ?? '',
    );
    _note = TextEditingController(text: activity?.note ?? '');
    _date = activity?.transactionDate ?? DateTime.now();
    _increase = activity?.quantityScaled.isNegative != true;
    _accountId = widget.initialAccountId;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final holding = ref.watch(holdingProvider(widget.asset.id)).valueOrNull;
    final previewShares = _exactStockShares
        ? int.tryParse(_quantity.text.trim())
        : stockSharesPreview(_quantity.text);
    final title = switch (widget.action) {
      AssetTransactionAction.buy =>
        'Beli ${widget.asset.symbol ?? widget.asset.name}',
      AssetTransactionAction.sell =>
        'Jual ${widget.asset.symbol ?? widget.asset.name}',
      AssetTransactionAction.adjustment =>
        'Penyesuaian ${widget.asset.symbol ?? widget.asset.name}',
      AssetTransactionAction.openingPosition => 'Posisi Awal',
    };
    return AlertDialog(
      title: Text(title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _quantity,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: !isStock,
                ),
                decoration: InputDecoration(
                  labelText: _exactStockShares
                      ? 'Jumlah Lembar'
                      : isStock
                      ? 'Jumlah Lot'
                      : 'Jumlah ${quantityUnitLabel(widget.asset)}',
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  try {
                    final quantity = parseActivityQuantity(
                      widget.asset,
                      value ?? '',
                      _increase,
                      exactStockShares: _exactStockShares,
                    );
                    return quantity.isZero || quantity.isNegative
                        ? 'Jumlah harus lebih dari 0'
                        : null;
                  } catch (_) {
                    return _exactStockShares
                        ? 'Masukkan jumlah lembar bulat yang valid'
                        : isStock
                        ? 'Masukkan jumlah lot bulat yang valid'
                        : 'Jumlah maksimal 8 angka desimal';
                  }
                },
              ),
              if (isStock) ...[
                if (widget.action == AssetTransactionAction.sell &&
                    holding?.hasActivity == true)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tersedia ${formatStockQuantity(holding!.quantity)}',
                    ),
                  ),
                if (previewShares != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Jumlah Lembar: ${formatPlainInteger(previewShares)}',
                    ),
                  ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (isAdjustment)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_increase ? 'Tambah jumlah' : 'Kurangi jumlah'),
                  value: _increase,
                  onChanged: (value) => setState(() => _increase = value),
                ),
              if (!isAdjustment) ...[
                TextFormField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: activityPriceLabel(widget.asset),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) => parseMoneyDigits(value ?? '') <= 0
                      ? 'Harga harus lebih dari 0'
                      : null,
                ),
                if (activityTotalPreview(
                      widget.asset,
                      _quantity.text,
                      _price.text,
                    )
                    case final total?)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Total: ${formatIdr(total)}'),
                  ),
                const SizedBox(height: AppSpacing.md),
                accounts.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(),
                  ),
                  error: (_, _) => const Text('Akun belum dapat dimuat.'),
                  data: (items) {
                    final options = items
                        .where((item) => item.isActive || item.id == _accountId)
                        .toList();
                    _accountId ??= options.firstOrNull?.id;
                    return DropdownButtonFormField<int>(
                      initialValue: options.any((item) => item.id == _accountId)
                          ? _accountId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Akun'),
                      items: [
                        for (final account in options)
                          DropdownMenuItem(
                            value: account.id,
                            child: Text(
                              '${account.name}${account.isActive ? '' : ' (Tidak aktif)'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => _accountId = value),
                      validator: (value) =>
                          value == null ? 'Akun wajib dipilih' : null,
                    );
                  },
                ),
              ] else
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Penyesuaian mengubah jumlah aset tanpa membuat transaksi pemasukan atau pengeluaran.',
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tanggal'),
                subtitle: Text(formatPositionDate(context, _date)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null && mounted) {
                    setState(() => _date = date);
                  }
                },
              ),
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
        FilledButton(
          onPressed: accounts.isLoading && !isAdjustment ? null : _save,
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ActivityFormData(
        quantity: parseActivityQuantity(
          widget.asset,
          _quantity.text,
          _increase,
          exactStockShares: _exactStockShares,
        ),
        priceAmount: isAdjustment ? null : parseMoneyDigits(_price.text),
        accountId: isAdjustment ? null : _accountId,
        date: _date,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }
}
