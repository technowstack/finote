/// Consistent spacing scale used across all screens.
///
/// Prefer these constants over ad-hoc pixel values so spacing
/// changes propagate everywhere at once.
abstract final class AppSpacing {
  /// 4dp — tight spacing between related inline elements.
  static const double xs = 4;

  /// 8dp — default gap between list items, chip spacing.
  static const double sm = 8;

  /// 12dp — medium gap within card content.
  static const double md = 12;

  /// 16dp — standard screen-edge padding, section gaps.
  static const double lg = 16;

  /// 24dp — large section separation.
  static const double xl = 24;

  /// 32dp — major section breaks, top-level padding.
  static const double xxl = 32;

  /// Horizontal padding for screen-level content.
  static const double screenH = 16;

  /// Vertical padding at the top of scrollable content.
  static const double screenV = 8;
}
