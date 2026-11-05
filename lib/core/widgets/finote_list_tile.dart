import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/finote_colors.dart';

/// components.md `List Tile`: settings-style row with the icon in a toned
/// 44×44 container, min height 56. [destructive] switches to the error
/// tokens (Reset data, delete actions).
class FinoteListTile extends StatelessWidget {
  const FinoteListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.tone,
    this.destructive = false,
    this.trailing,
    this.showChevron = true,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Short current value shown before the chevron (e.g. "Ikuti sistem").
  final String? value;

  /// Icon container colors; defaults to the primary container.
  final CategoryColors? tone;
  final bool destructive;

  /// Replaces the chevron (e.g. a progress indicator while busy).
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final f = Theme.of(context).finote;
    final background = destructive
        ? f.errorContainer
        : tone?.background ?? colors.primaryContainer;
    final foreground = destructive
        ? f.error
        : tone?.foreground ?? colors.onPrimaryContainer;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: AppRadius.mdAll,
                ),
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(icon, color: foreground),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.labelLg.copyWith(
                        color: destructive ? f.error : colors.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTypography.bodySm.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    value!,
                    textAlign: TextAlign.end,
                    style: AppTypography.bodyMd.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ] else if (showChevron && onTap != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled group of [FinoteListTile]s on one surface: an overline label
/// (e.g. "DATA") above a card. Surfaces are separated by tone, not dividers.
class FinoteListSection extends StatelessWidget {
  const FinoteListSection({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Text(
              title!.toUpperCase(),
              style: AppTypography.captionOverline.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}
