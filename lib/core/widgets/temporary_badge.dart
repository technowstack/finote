import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/finote_colors.dart';

/// components.md `Badge/Sementara`: must sit next to any partial value
/// (Portfolio, Net Worth). [onHero] picks the translucent hero variant.
class TemporaryBadge extends StatelessWidget {
  const TemporaryBadge({
    super.key,
    required this.text,
    this.onHero = false,
    this.icon = Icons.schedule,
  });

  final String text;
  final bool onHero;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final f = Theme.of(context).finote;
    final background = onHero ? f.onHeroChip : f.warningContainer;
    final foreground = onHero ? f.onHero : f.onWarningContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.smAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                text,
                style: AppTypography.captionSemibold.copyWith(
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
