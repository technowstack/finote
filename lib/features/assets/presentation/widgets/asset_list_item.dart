import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/finance_tiles.dart';
import '../../domain/asset_quantity.dart';
import '../../domain/asset_type.dart';
import '../../../market/data/asset_price_repository.dart';
import '../../../market/domain/portfolio_valuation.dart';
import 'asset_formatters.dart';

/// One asset row (components.md `Item/Aset`): name + code on the left, the
/// current value on the right, and quantity/price as small info. Profit/loss
/// is deliberately absent: cost basis is unknown for many holdings, and an
/// unknown value is never shown as zero.
class AssetListItem extends StatelessWidget {
  const AssetListItem({
    super.key,
    required this.asset,
    required this.quantity,
    required this.hasActivity,
    this.price,
    this.valuation,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  final AssetRecord asset;
  final AssetQuantity quantity;
  final bool hasActivity;
  final LocalAssetPrice? price;
  final AssetValuation? valuation;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final symbol = asset.symbol?.trim();
    return AssetTile(
      name: asset.name,
      code: symbol == null || symbol.isEmpty ? null : symbol,
      info: _info(),
      value: valuation?.currentValue,
      // Only claim "unavailable" when a valuation exists and could not be
      // computed; without one (e.g. archived) show no value at all.
      emptyLabel: valuation != null && !valuation!.isValued
          ? 'Nilai belum tersedia'
          : null,
      maskable: true,
      onTap: onTap,
      trailing: PopupMenuButton<_AssetAction>(
        tooltip: 'Tindakan aset',
        onSelected: (action) => switch (action) {
          _AssetAction.edit => onEdit(),
          _AssetAction.archive => onArchive(),
          _AssetAction.delete => onDelete(),
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: _AssetAction.edit, child: Text('Ubah')),
          PopupMenuItem(
            value: _AssetAction.archive,
            child: Text(asset.isActive ? 'Arsipkan' : 'Aktifkan kembali'),
          ),
          const PopupMenuItem(value: _AssetAction.delete, child: Text('Hapus')),
        ],
      ),
    );
  }

  String _info() {
    final price = this.price;
    final priceText = price != null
        ? '${price.isBackendStale
              ? 'Harga terakhir'
              : asset.pricingMode == AssetPricingMode.manual
              ? manualPriceLabel(asset)
              : 'Harga'} ${formatIdr(price.price)} / ${assetPriceUnit(asset)}'
        : asset.pricingMode == AssetPricingMode.manual
        ? 'Harga belum diatur'
        : 'Harga belum tersedia';
    return [
      formatAssetQuantity(asset, quantity, hasActivity: hasActivity),
      priceText,
      if (asset.pricingMode == AssetPricingMode.api) 'Otomatis',
    ].join(' · ');
  }
}

enum _AssetAction { edit, archive, delete }
