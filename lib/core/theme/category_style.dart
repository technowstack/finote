import 'package:flutter/material.dart';

import 'finote_colors.dart';

/// The 17 default categories with a designed icon and color.
///
/// Names follow `finote.categoryMap` in `docs/design/tokens.json`. "Lainnya"
/// exists for both income and expense and shares [other].
enum FinoteCategory {
  food('Makanan & Minuman', Icons.restaurant_rounded),
  transport('Transportasi', Icons.directions_car_outlined),
  shopping('Belanja', Icons.shopping_bag_outlined),
  bills('Tagihan', Icons.receipt_long_outlined),
  fun('Hiburan', Icons.play_arrow_outlined),
  health('Kesehatan', Icons.local_hospital_outlined),
  education('Pendidikan', Icons.school_outlined),
  donation('Donasi', Icons.volunteer_activism_outlined),
  other('Lainnya', Icons.more_horiz_rounded),
  salary('Gaji', Icons.account_balance_wallet_outlined),
  dividend('Deviden', Icons.percent_rounded),
  bonus('Bonus', Icons.star_outline_rounded),
  business('Bisnis', Icons.business_center_outlined),
  gift('Hadiah', Icons.card_giftcard_outlined),
  invest('Investasi', Icons.trending_up_rounded),
  assetBuy('Pembelian Aset', Icons.download_rounded),
  assetSell('Penjualan Aset', Icons.upload_rounded);

  const FinoteCategory(this.categoryName, this.icon);

  final String categoryName;
  final IconData icon;

  static final _byName = {for (final c in values) c.categoryName: c};

  /// Exact-name match; any other name is a user-created category.
  static FinoteCategory? fromName(String name) => _byName[name];
}

/// Icon tile/bar style resolved for one category.
@immutable
class CategoryStyle {
  const CategoryStyle(this.icon, this.colors);

  final IconData icon;
  final CategoryColors colors;

  Color get foreground => colors.foreground;
  Color get background => colors.background;
}

const customCategoryIcon = Icons.sell_outlined;
const transferIcon = Icons.swap_horiz_rounded;

/// `color.category.custom1..6` alias these categories, in order.
const customCategoryPalette = [
  FinoteCategory.food,
  FinoteCategory.transport,
  FinoteCategory.shopping,
  FinoteCategory.bills,
  FinoteCategory.fun,
  FinoteCategory.education,
];

/// Zero-based palette index for a user-created category (`customN` = index + 1).
///
/// Mirrors the tokens.json rule so the same name always gets the same color
/// on every device: `fold(0, (h, c) => (h * 31 + c) & 0x7fffffff) % 6`.
int customCategoryIndex(String name) =>
    name.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff) %
    customCategoryPalette.length;
