import 'package:flutter/material.dart';

import 'finote_colors.dart';

TextStyle _style(
  double size,
  double lineHeight,
  FontWeight weight, {
  double letterSpacing = 0,
  bool tabular = false,
}) => TextStyle(
  fontFamily: 'Roboto',
  fontSize: size,
  height: lineHeight / size,
  fontWeight: weight,
  letterSpacing: letterSpacing,
  fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
);

/// `typography.*` tokens. Colorless; apply color at the use site.
///
/// Amount styles use tabular figures so digits align in lists and totals.
abstract final class AppTypography {
  static final amountHero = _style(
    34,
    40,
    FontWeight.w700,
    letterSpacing: -0.5,
    tabular: true,
  );
  static final amountXl = _style(28, 36, FontWeight.w700, tabular: true);
  static final amountLg = _style(22, 28, FontWeight.w700, tabular: true);
  static final amountMd = _style(17, 24, FontWeight.w700, tabular: true);
  static final amountItem = _style(15, 22, FontWeight.w500, tabular: true);
  static final amountSm = _style(14, 20, FontWeight.w600, tabular: true);
  static final amountXs = _style(13, 18, FontWeight.w600, tabular: true);
  static final amountCaption = _style(12, 16, FontWeight.w500, tabular: true);

  static final titleScreen = _style(24, 32, FontWeight.w700);
  static final titleScreenSub = _style(22, 28, FontWeight.w700);
  static final titleDialog = _style(20, 28, FontWeight.w700);
  static final titleSheet = _style(18, 24, FontWeight.w600);
  static final titleSection = _style(17, 24, FontWeight.w600);
  static final titleCard = _style(15, 22, FontWeight.w600);

  static final bodyLg = _style(15, 22, FontWeight.w400);
  static final bodyInput = _style(16, 22, FontWeight.w400);
  static final bodyMd = _style(14, 20, FontWeight.w400);
  static final bodySm = _style(13, 18, FontWeight.w400);

  static final labelLg = _style(15, 22, FontWeight.w500);
  static final labelMd = _style(14, 20, FontWeight.w500);
  static final labelSm = _style(13, 18, FontWeight.w500);
  static final labelButton = _style(15, 22, FontWeight.w600);

  static final captionRegular = _style(12, 16, FontWeight.w400);
  static final captionMedium = _style(12, 16, FontWeight.w500);
  static final captionSemibold = _style(12, 16, FontWeight.w600);
  static final captionOverline = _style(
    12,
    16,
    FontWeight.w600,
    letterSpacing: 0.8,
  );

  /// Maps the tokens onto Material slots so existing `textTheme.*` call sites
  /// pick up the redesign. Display slots carry amounts, hence tabular figures.
  static TextTheme textTheme(FinoteColors c) => TextTheme(
    displayLarge: amountHero.copyWith(color: c.text),
    displayMedium: amountXl.copyWith(color: c.text),
    displaySmall: amountLg.copyWith(color: c.text),
    headlineLarge: titleScreen.copyWith(color: c.text),
    headlineMedium: titleScreenSub.copyWith(color: c.text),
    headlineSmall: titleDialog.copyWith(color: c.text),
    titleLarge: titleSheet.copyWith(color: c.text),
    titleMedium: titleCard.copyWith(color: c.text),
    titleSmall: labelSm.copyWith(color: c.textMuted),
    bodyLarge: bodyLg.copyWith(color: c.text),
    bodyMedium: bodyMd.copyWith(color: c.text),
    bodySmall: bodySm.copyWith(color: c.textMuted),
    labelLarge: labelButton.copyWith(color: c.text),
    labelMedium: captionMedium.copyWith(color: c.textMuted),
    labelSmall: captionRegular.copyWith(color: c.textMuted),
  );
}
