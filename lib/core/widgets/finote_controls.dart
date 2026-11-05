import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// components.md `Chip`: 34dp visual, 48dp hit area via transparent padding.
class FinoteChip extends StatelessWidget {
  const FinoteChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onSelected != null;
    final background = !enabled
        ? colors.surfaceContainerHighest
        : selected
        ? colors.primary
        : colors.surfaceContainer;
    final foreground = !enabled
        ? colors.onSurfaceVariant
        : selected
        ? colors.onPrimary
        : colors.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: GestureDetector(
        // The 7dp bands above/below the visual still count as the chip.
        behavior: HitTestBehavior.opaque,
        onTap: onSelected,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            widthFactor: 1,
            child: Material(
              color: background,
              borderRadius: AppRadius.mdAll,
              child: InkWell(
                onTap: onSelected,
                borderRadius: AppRadius.mdAll,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 34),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTypography.labelSm.copyWith(color: foreground),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FinoteSegment<T> {
  const FinoteSegment(this.value, this.label);

  final T value;
  final String label;
}

/// components.md `Segmented`: surface track with 4dp padding; each segment
/// is a full 48dp-tall target.
class FinoteSegmented<T> extends StatelessWidget {
  const FinoteSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<FinoteSegment<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(
          children: [
            for (final segment in segments)
              Expanded(child: _segment(context, segment)),
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, FinoteSegment<T> segment) {
    final colors = Theme.of(context).colorScheme;
    final isSelected = segment.value == selected;
    return Semantics(
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: isSelected ? colors.primary : Colors.transparent,
        borderRadius: AppRadius.smAll,
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged!(segment.value),
          borderRadius: AppRadius.smAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    segment.label,
                    style:
                        (isSelected
                                ? AppTypography.labelMd.copyWith(
                                    fontWeight: FontWeight.w600,
                                  )
                                : AppTypography.labelMd)
                            .copyWith(
                              color: isSelected
                                  ? colors.onPrimary
                                  : colors.onSurfaceVariant,
                            ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
