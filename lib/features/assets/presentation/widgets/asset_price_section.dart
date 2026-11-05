import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/asset_repository.dart';
import '../../domain/asset_type.dart';
import '../../../market/data/asset_price_repository.dart';
import 'asset_formatters.dart';

class ManualPriceCard extends StatelessWidget {
  const ManualPriceCard({
    super.key,
    required this.asset,
    required this.price,
    required this.onSetPrice,
    required this.onClearPrice,
    this.onUseAutomatic,
  });

  final AssetRecord asset;
  final LocalAssetPrice? price;
  final VoidCallback onSetPrice;
  final VoidCallback? onClearPrice;
  final VoidCallback? onUseAutomatic;

  @override
  Widget build(BuildContext context) {
    final hasPrice = price != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              manualPriceLabel(asset),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hasPrice
                  ? '${formatIdr(price!.price)} / ${assetPriceUnit(asset)}'
                  : 'Belum diatur',
            ),
            if (hasPrice) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Diperbarui ${formatPositionDate(context, price!.updatedAt)}',
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onSetPrice,
                    child: Text(hasPrice ? 'Ubah Harga' : 'Atur Harga'),
                  ),
                ),
                if (onClearPrice != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    tooltip: 'Hapus Harga',
                    onPressed: onClearPrice,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
            if (onUseAutomatic != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onUseAutomatic,
                  child: const Text('Gunakan Harga Otomatis'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> useAutomaticPrice(
  BuildContext context,
  WidgetRef ref,
  AssetRecord asset,
) async {
  try {
    final updated = await ref
        .read(assetRepositoryProvider)
        .update(
          id: asset.id,
          symbol: asset.symbol,
          name: asset.name,
          assetType: asset.assetType,
          pricingMode: AssetPricingMode.api,
          currency: asset.currency,
          unitLabel: asset.unitLabel,
        );
    if (!updated) throw StateError('Asset is no longer available');
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harga otomatis gagal diaktifkan. Coba lagi.'),
        ),
      );
    }
  }
}

class ApiPriceFallbackCard extends StatelessWidget {
  const ApiPriceFallbackCard({
    super.key,
    required this.asset,
    required this.price,
    required this.onSetManual,
  });

  final AssetRecord asset;
  final LocalAssetPrice? price;
  final VoidCallback onSetManual;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Harga pasar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            price == null
                ? 'Harga belum tersedia'
                : '${price!.isBackendStale ? 'Harga terakhir ' : ''}${formatIdr(price!.price)} / ${assetPriceUnit(asset)}',
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: onSetManual,
            child: const Text('Atur Harga Manual'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showManualPriceForm(
  BuildContext context,
  WidgetRef ref,
  AssetRecord asset,
  LocalAssetPrice? currentPrice,
) async {
  final price = await showDialog<int>(
    context: context,
    builder: (_) =>
        _ManualPriceDialog(asset: asset, currentPrice: currentPrice),
  );
  if (price == null || !context.mounted) return;
  try {
    await ref
        .read(assetPriceRepositoryProvider)
        .setManualPrice(
          assetId: asset.id,
          price: price,
          currency: asset.currency,
        );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harga gagal disimpan. Coba lagi.')),
      );
    }
  }
}

Future<void> showManualFallbackForm(
  BuildContext context,
  WidgetRef ref,
  AssetRecord asset,
) async {
  final price = await showDialog<int>(
    context: context,
    builder: (_) => _ManualPriceDialog(asset: asset, currentPrice: null),
  );
  if (price == null || !context.mounted) return;
  try {
    final updated = await ref
        .read(assetRepositoryProvider)
        .update(
          id: asset.id,
          symbol: asset.symbol,
          name: asset.name,
          assetType: asset.assetType,
          pricingMode: AssetPricingMode.manual,
          currency: asset.currency,
          unitLabel: asset.unitLabel,
        );
    if (!updated) throw StateError('Asset is no longer available');
    await ref
        .read(assetPriceRepositoryProvider)
        .setManualPrice(
          assetId: asset.id,
          price: price,
          currency: asset.currency,
        );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harga manual gagal disimpan. Coba lagi.'),
        ),
      );
    }
  }
}

Future<void> clearAssetManualPrice(
  BuildContext context,
  WidgetRef ref,
  AssetRecord asset,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Hapus harga saat ini?'),
      content: const Text(
        'Jumlah aset tetap tersimpan. Hanya harga saat ini yang akan dihapus.',
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
    await ref.read(assetPriceRepositoryProvider).clearManualPrice(asset.id);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harga gagal dihapus. Coba lagi.')),
      );
    }
  }
}

class _ManualPriceDialog extends StatefulWidget {
  const _ManualPriceDialog({required this.asset, required this.currentPrice});

  final AssetRecord asset;
  final LocalAssetPrice? currentPrice;

  @override
  State<_ManualPriceDialog> createState() => _ManualPriceDialogState();
}

class _ManualPriceDialogState extends State<_ManualPriceDialog> {
  late final TextEditingController _price;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(
      text: widget.currentPrice == null
          ? ''
          : formatIdr(widget.currentPrice!.price).replaceFirst('Rp', ''),
    );
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Harga Manual'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: TextFormField(
          controller: _price,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: manualPriceLabel(widget.asset),
            helperText: widget.asset.assetType == AssetType.mutualFund
                ? 'Masukkan NAB/unit terbaru.'
                : null,
            prefixText: 'Rp ',
          ),
          validator: (value) {
            final amount = parseMoneyDigits(value ?? '');
            if (amount <= 0) return 'Masukkan harga lebih dari 0.';
            return null;
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, parseMoneyDigits(_price.text));
          }
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}
