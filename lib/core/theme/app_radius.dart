import 'package:flutter/painting.dart';

/// The only four corner radii in the design (`radius.*` tokens).
abstract final class AppRadius {
  /// 8 — small chips, chart bars, badges.
  static const double sm = 8;

  /// 14 — icon tiles, buttons, chips, inputs, snackbar.
  static const double md = 14;

  /// 20 — cards.
  static const double lg = 20;

  /// 28 — hero, dialogs, bottom sheets, bottom nav, FAB, search bar.
  static const double xl = 28;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const xlAll = BorderRadius.all(Radius.circular(xl));
}
