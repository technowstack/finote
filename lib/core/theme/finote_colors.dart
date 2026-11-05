import 'package:flutter/material.dart';

import 'category_style.dart';

/// Foreground/background pair for a category icon tile or bar.
@immutable
class CategoryColors {
  const CategoryColors(this.foreground, this.background);

  final Color foreground;
  final Color background;
}

/// Every color token from `docs/design/tokens.json`, per mode.
///
/// This is the single source of color values: [AppTheme] builds its
/// [ColorScheme] from it, and tokens without a Material role (hero, transfer,
/// warning, shadows, categories) are read through [FinoteThemeX.finote].
@immutable
class FinoteColors extends ThemeExtension<FinoteColors> {
  const FinoteColors._({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.text,
    required this.textMuted,
    required this.income,
    required this.expense,
    required this.heroFrom,
    required this.heroTo,
    required this.onHero,
    required this.onHeroMuted,
    required this.onHeroChip,
    required this.transfer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.outline,
    required this.focus,
    required this.disabled,
    required this.onDisabled,
    required this.divider,
    required this.scrim,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.inversePrimary,
    required this.shadowHero,
    required this.shadowFab,
    required this.categories,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color text;
  final Color textMuted;

  /// Only for income amounts, never icons.
  final Color income;

  /// Only for expense amounts, never icons.
  final Color expense;
  final Color heroFrom;
  final Color heroTo;
  final Color onHero;
  final Color onHeroMuted;
  final Color onHeroChip;

  /// Neutral: a transfer is neither income nor expense.
  final CategoryColors transfer;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color outline;
  final Color focus;
  final Color disabled;
  final Color onDisabled;
  final Color divider;
  final Color scrim;
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color inversePrimary;
  final Color shadowHero;
  final Color shadowFab;
  final Map<FinoteCategory, CategoryColors> categories;

  LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [heroFrom, heroTo],
  );

  List<BoxShadow> get heroShadow => [
    BoxShadow(color: shadowHero, offset: const Offset(0, 12), blurRadius: 28),
  ];

  List<BoxShadow> get fabShadow => [
    BoxShadow(color: shadowFab, offset: const Offset(0, 8), blurRadius: 20),
  ];

  /// Icon and colors for a category name; see [FinoteCategory.fromName].
  CategoryStyle categoryStyle(String name) {
    final category = FinoteCategory.fromName(name);
    if (category != null) {
      return CategoryStyle(category.icon, categories[category]!);
    }
    final palette = customCategoryPalette[customCategoryIndex(name)];
    return CategoryStyle(customCategoryIcon, categories[palette]!);
  }

  CategoryStyle get transferStyle => CategoryStyle(transferIcon, transfer);

  static const light = FinoteColors._(
    bg: Color(0xFFEEF1F8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF3F5FB),
    primary: Color(0xFF3B5BDB),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE3E9FF),
    onPrimaryContainer: Color(0xFF233D9F),
    text: Color(0xFF182238),
    textMuted: Color(0xFF5B6780),
    income: Color(0xFF0A7560),
    expense: Color(0xFFA24941),
    heroFrom: Color(0xFF2A42BD),
    heroTo: Color(0xFF1B2750),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xFFE8ECFD),
    onHeroChip: Color(0x24FFFFFF),
    transfer: CategoryColors(Color(0xFF475569), Color(0xFFE3E8F1)),
    error: Color(0xFFB42318),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFDECEA),
    onErrorContainer: Color(0xFF7A1B14),
    warning: Color(0xFF8A5300),
    warningContainer: Color(0xFFFFF1D6),
    onWarningContainer: Color(0xFF5F3A00),
    outline: Color(0xFF7B86A0),
    focus: Color(0xFF3B5BDB),
    disabled: Color(0xFFE4E8F1),
    onDisabled: Color(0xFF8E98AE),
    divider: Color(0xFFE3E8F1),
    scrim: Color(0x8C1B2750),
    inverseSurface: Color(0xFF1B2750),
    onInverseSurface: Color(0xFFEEF1FA),
    inversePrimary: Color(0xFFAEBFFF),
    shadowHero: Color(0x591D2A50),
    shadowFab: Color(0x663B5BDB),
    categories: {
      FinoteCategory.food: CategoryColors(Color(0xFFB45309), Color(0xFFFDEBD3)),
      FinoteCategory.transport: CategoryColors(
        Color(0xFF2563EB),
        Color(0xFFE0EBFF),
      ),
      FinoteCategory.shopping: CategoryColors(
        Color(0xFF9333EA),
        Color(0xFFF1E3FF),
      ),
      FinoteCategory.bills: CategoryColors(
        Color(0xFF0E7490),
        Color(0xFFD8F3F9),
      ),
      FinoteCategory.salary: CategoryColors(
        Color(0xFF0D806A),
        Color(0xFFD9F2E8),
      ),
      FinoteCategory.fun: CategoryColors(Color(0xFFBE185D), Color(0xFFFCE1EE)),
      FinoteCategory.health: CategoryColors(
        Color(0xFFB91C1C),
        Color(0xFFFDE3E3),
      ),
      FinoteCategory.education: CategoryColors(
        Color(0xFF4338CA),
        Color(0xFFE4E6FD),
      ),
      FinoteCategory.donation: CategoryColors(
        Color(0xFF4D7C0F),
        Color(0xFFEAF7CC),
      ),
      FinoteCategory.other: CategoryColors(
        Color(0xFF475569),
        Color(0xFFE3E8F1),
      ),
      FinoteCategory.dividend: CategoryColors(
        Color(0xFF0369A1),
        Color(0xFFDDF0FB),
      ),
      FinoteCategory.bonus: CategoryColors(
        Color(0xFFA16207),
        Color(0xFFFDF0C4),
      ),
      FinoteCategory.business: CategoryColors(
        Color(0xFF78350F),
        Color(0xFFF1E4D3),
      ),
      FinoteCategory.gift: CategoryColors(Color(0xFFA21CAF), Color(0xFFF9E5FC)),
      FinoteCategory.invest: CategoryColors(
        Color(0xFF1D4ED8),
        Color(0xFFDEE8FF),
      ),
      FinoteCategory.assetBuy: CategoryColors(
        Color(0xFF0F766E),
        Color(0xFFD3F4EF),
      ),
      FinoteCategory.assetSell: CategoryColors(
        Color(0xFF047857),
        Color(0xFFD1FAE5),
      ),
    },
  );

  static const dark = FinoteColors._(
    bg: Color(0xFF0B1020),
    surface: Color(0xFF151C33),
    surfaceAlt: Color(0xFF1F2847),
    primary: Color(0xFF8EA2FF),
    onPrimary: Color(0xFF0B1020),
    primaryContainer: Color(0xFF28366F),
    onPrimaryContainer: Color(0xFFD5DDFF),
    text: Color(0xFFEEF1FA),
    textMuted: Color(0xFFA7B1CC),
    income: Color(0xFF6FD3B0),
    expense: Color(0xFFF0A39C),
    heroFrom: Color(0xFF33449E),
    heroTo: Color(0xFF1B2557),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xFFE3E8FA),
    onHeroChip: Color(0x1CFFFFFF),
    transfer: CategoryColors(Color(0xFFB4BEDA), Color(0xFF232C4A)),
    error: Color(0xFFFDA29B),
    onError: Color(0xFF4A0F0B),
    errorContainer: Color(0xFF4A1F1C),
    onErrorContainer: Color(0xFFFFD9D5),
    warning: Color(0xFFF5B26B),
    warningContainer: Color(0xFF3A2A1B),
    onWarningContainer: Color(0xFFFFE1B8),
    outline: Color(0xFF7C88AC),
    focus: Color(0xFF8EA2FF),
    disabled: Color(0xFF262F4D),
    onDisabled: Color(0xFF6E789A),
    divider: Color(0xFF283255),
    scrim: Color(0xB3000000),
    inverseSurface: Color(0xFFEEF1FA),
    onInverseSurface: Color(0xFF0B1020),
    inversePrimary: Color(0xFF3B5BDB),
    shadowHero: Color(0xA6000000),
    shadowFab: Color(0x8C3B5BDB),
    categories: {
      FinoteCategory.food: CategoryColors(Color(0xFFF5B26B), Color(0xFF3A2A1B)),
      FinoteCategory.transport: CategoryColors(
        Color(0xFF8DB4FF),
        Color(0xFF1B2A4D),
      ),
      FinoteCategory.shopping: CategoryColors(
        Color(0xFFD0A3FF),
        Color(0xFF2E1F47),
      ),
      FinoteCategory.bills: CategoryColors(
        Color(0xFF6FD0E6),
        Color(0xFF15323B),
      ),
      FinoteCategory.salary: CategoryColors(
        Color(0xFF6FD3B0),
        Color(0xFF15332D),
      ),
      FinoteCategory.fun: CategoryColors(Color(0xFFF59CC0), Color(0xFF3D1B2C)),
      FinoteCategory.health: CategoryColors(
        Color(0xFFFCA5A5),
        Color(0xFF3F1D1D),
      ),
      FinoteCategory.education: CategoryColors(
        Color(0xFFA5ACFF),
        Color(0xFF22265A),
      ),
      FinoteCategory.donation: CategoryColors(
        Color(0xFFBEE37A),
        Color(0xFF27330F),
      ),
      FinoteCategory.other: CategoryColors(
        Color(0xFFB4BEDA),
        Color(0xFF232C4A),
      ),
      FinoteCategory.dividend: CategoryColors(
        Color(0xFF7DD3FC),
        Color(0xFF112F42),
      ),
      FinoteCategory.bonus: CategoryColors(
        Color(0xFFFACC15),
        Color(0xFF3A3010),
      ),
      FinoteCategory.business: CategoryColors(
        Color(0xFFD6A57A),
        Color(0xFF33231A),
      ),
      FinoteCategory.gift: CategoryColors(Color(0xFFE9A3F0), Color(0xFF38183D)),
      FinoteCategory.invest: CategoryColors(
        Color(0xFF93B4FF),
        Color(0xFF16254F),
      ),
      FinoteCategory.assetBuy: CategoryColors(
        Color(0xFF5EEAD4),
        Color(0xFF103532),
      ),
      FinoteCategory.assetSell: CategoryColors(
        Color(0xFF6EE7B7),
        Color(0xFF0F3328),
      ),
    },
  );

  static FinoteColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  @override
  FinoteColors copyWith() => this;

  // shortcut: snaps at the midpoint instead of blending each token; blend
  // per-field if the 200ms theme-switch animation shows a visible jump.
  @override
  FinoteColors lerp(FinoteColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension FinoteThemeX on ThemeData {
  /// Finote tokens for this theme; falls back by brightness for bare
  /// [ThemeData] instances (e.g. in tests) that lack the extension.
  FinoteColors get finote =>
      extension<FinoteColors>() ?? FinoteColors.of(brightness);
}
