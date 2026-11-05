import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/asset_quantity.dart';
import '../../domain/asset_type.dart';

bool isMarketAsset(AssetRecord asset) =>
    asset.assetType == AssetType.stock || asset.assetType == AssetType.crypto;

String assetPriceUnit(AssetRecord asset) => switch (asset.assetType) {
  AssetType.gold => 'gram',
  AssetType.mutualFund => 'unit',
  AssetType.other => asset.unitLabel ?? 'unit',
  AssetType.stock => 'saham',
  AssetType.crypto => 'coin/token',
};

String manualPriceLabel(AssetRecord asset) => switch (asset.assetType) {
  AssetType.gold => 'Harga per Gram',
  AssetType.mutualFund => 'Nilai per Unit',
  AssetType.other => 'Harga per ${assetPriceUnit(asset)}',
  _ => 'Harga per Unit',
};

String activityPriceLabel(AssetRecord asset) => switch (asset.assetType) {
  AssetType.gold => 'Harga per Gram (IDR)',
  AssetType.stock => 'Harga per Saham (IDR)',
  _ => 'Harga per Unit (IDR)',
};

String formatAssetQuantity(
  AssetRecord asset,
  AssetQuantity quantity, {
  bool hasActivity = true,
}) {
  if (quantity.isZero && !hasActivity) return 'Belum ada posisi';
  if (asset.assetType == AssetType.stock) {
    return formatStockQuantity(quantity);
  }
  final unit = switch (asset.assetType) {
    AssetType.crypto => 'coin/token',
    AssetType.mutualFund => 'unit',
    AssetType.gold => 'gram',
    AssetType.other => asset.unitLabel ?? 'unit',
    AssetType.stock => 'saham',
  };
  return '$quantity $unit';
}

String formatStockQuantity(AssetQuantity quantity) {
  if (quantity.scaled % AssetQuantity.scale != 0) {
    return '$quantity lembar';
  }
  final shares = quantity.scaled ~/ AssetQuantity.scale;
  final sign = shares < 0 ? '-' : '';
  final absoluteShares = shares.abs();
  final lots = absoluteShares ~/ 100;
  final remainder = absoluteShares % 100;
  if (remainder == 0) return '$sign$lots lot';
  if (lots == 0) return '$sign$remainder lembar';
  return '$sign$lots lot + $remainder lembar';
}

String formatStockShares(AssetQuantity quantity) {
  if (quantity.scaled % AssetQuantity.scale != 0) {
    return '$quantity lembar';
  }
  return '${formatIdr(quantity.scaled ~/ AssetQuantity.scale).replaceFirst('Rp', '')} lembar';
}

String quantityUnitLabel(AssetRecord asset) => switch (asset.assetType) {
  AssetType.crypto => 'Coin/Token',
  AssetType.mutualFund => 'Unit',
  AssetType.gold => 'Gram',
  AssetType.other => asset.unitLabel ?? 'Unit',
  AssetType.stock => 'Lot',
};

String inputQuantityText(AssetRecord asset, AssetQuantity quantity) {
  if (asset.assetType != AssetType.stock) return quantity.toString();
  return (quantity.scaled ~/ AssetQuantity.scale ~/ 100).toString();
}

AssetQuantity parseOpeningQuantity(AssetRecord asset, String value) {
  if (asset.assetType != AssetType.stock) {
    return AssetQuantity.parse(value.replaceAll(',', '.'));
  }
  if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
    throw const FormatException('Stock lot must be a whole number');
  }
  final scaled =
      BigInt.parse(value.trim()) * BigInt.from(AssetQuantity.scale * 100);
  if (scaled > BigInt.from(9223372036854775807)) {
    throw const FormatException('Quantity is out of range');
  }
  return AssetQuantity.fromScaled(scaled.toInt());
}

int parseMoneyDigits(String value) =>
    int.tryParse(value.replaceAll(RegExp(r'\D'), '')) ?? 0;

int? stockSharesPreview(String value) {
  final input = value.trim();
  if (!RegExp(r'^\d+$').hasMatch(input)) return null;
  final shares = BigInt.parse(input) * BigInt.from(100);
  if (shares > BigInt.from(9223372036854775807 ~/ AssetQuantity.scale)) {
    return null;
  }
  return shares.toInt();
}

int? _stockTotalPreview(String quantity, String price) {
  final shares = stockSharesPreview(quantity);
  final amount = parseMoneyDigits(price);
  if (shares == null || amount <= 0) return null;
  final total = BigInt.from(shares) * BigInt.from(amount);
  if (total > BigInt.from(9223372036854775807)) return null;
  return total.toInt();
}

int? activityTotalPreview(AssetRecord asset, String quantity, String price) {
  if (asset.assetType == AssetType.stock) {
    return _stockTotalPreview(quantity, price);
  }
  final parsedQuantity = _parseDecimalQuantityPreview(quantity);
  final parsedPrice = parseMoneyDigits(price);
  if (parsedQuantity == null || parsedPrice <= 0) return null;
  final total =
      BigInt.from(parsedQuantity) *
      BigInt.from(parsedPrice) ~/
      BigInt.from(AssetQuantity.scale);
  if (total > BigInt.from(9223372036854775807)) return null;
  return total.toInt();
}

int? _parseDecimalQuantityPreview(String value) {
  try {
    final quantity = AssetQuantity.parse(value.trim().replaceAll(',', '.'));
    return quantity.isNegative || quantity.isZero ? null : quantity.scaled;
  } catch (_) {
    return null;
  }
}

String formatPlainInteger(int value) => formatIdr(value).replaceFirst('Rp', '');

String formatPositionDate(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatMediumDate(date);

String inputActivityQuantity(AssetRecord asset, AssetQuantity quantity) {
  final magnitude = quantity.isNegative
      ? AssetQuantity.fromScaled(-quantity.scaled)
      : quantity;
  return inputQuantityText(asset, magnitude);
}

AssetQuantity parseActivityQuantity(
  AssetRecord asset,
  String value,
  bool increase, {
  bool exactStockShares = false,
}) {
  final parsed = exactStockShares
      ? _parseExactStockShares(value)
      : parseOpeningQuantity(asset, value);
  if (parsed.isNegative) {
    throw const FormatException('Quantity must be positive');
  }
  if (parsed.isZero) return parsed;
  return increase ? parsed : AssetQuantity.fromScaled(-parsed.scaled);
}

AssetQuantity _parseExactStockShares(String value) {
  final input = value.trim();
  if (!RegExp(r'^\d+$').hasMatch(input)) {
    throw const FormatException('Stock shares must be a whole number');
  }
  return AssetQuantity.fromScaled(int.parse(input) * AssetQuantity.scale);
}

String formatStockSharesInput(AssetQuantity quantity) =>
    (quantity.scaled.abs() ~/ AssetQuantity.scale).toString();

String assetErrorMessage(Object error, {required bool editing}) {
  if (error is StateError && error.message == 'Asset symbol already exists') {
    return 'Aset dengan simbol tersebut sudah tersedia.';
  }
  return editing
      ? 'Aset gagal diperbarui. Coba lagi.'
      : 'Aset gagal disimpan. Coba lagi.';
}
