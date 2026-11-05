import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/transactions/domain/transaction_type.dart';
import '../preferences/balance_visibility_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';

/// Shown instead of an amount while the user hides balances.
const maskedAmount = 'Rp ••••••';

// -----------------------------------------------------------------------------
// Status: error / empty / loading (components.md `Status`)
// -----------------------------------------------------------------------------

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Icon(icon, size: 24, color: foreground),
      ),
    );
  }
}

/// A centered error message with a retry action. Never pass raw exceptions.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.description,
  });

  final String message;
  final VoidCallback onRetry;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusIcon(
              icon: Icons.warning_amber_rounded,
              background: colors.errorContainer,
              foreground: colors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.titleCard.copyWith(color: colors.onSurface),
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}

/// A centered icon + message for screens with no data, with an optional
/// primary action.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String message;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Inline variant for an empty section inside a card (icon on the left,
  /// text on the right) instead of a full-screen centered state.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (compact) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: AppRadius.mdAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusIcon(
                icon: icon,
                background: colors.primaryContainer,
                foreground: colors.onPrimaryContainer,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: AppTypography.titleCard.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusIcon(
              icon: icon,
              background: colors.primaryContainer,
              foreground: colors.onPrimaryContainer,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.titleCard.copyWith(color: colors.onSurface),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A centered progress indicator with an optional caption. Kept free of
/// padding/card chrome so it still fits the fixed-height slots screens use.
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(message!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Currency text
// -----------------------------------------------------------------------------

/// A formatted IDR amount in tabular figures.
///
/// With [type], it is signed (+/−) and colored as income/expense. With
/// [maskable], it shows [maskedAmount] while the user hides balances. Long
/// amounts shrink to fit instead of overflowing.
class CurrencyText extends StatelessWidget {
  const CurrencyText({
    super.key,
    required this.amount,
    this.type,
    this.style,
    this.maskable = false,
    this.alignment = Alignment.centerRight,
  });

  final int amount;
  final TransactionType? type;
  final TextStyle? style;
  final bool maskable;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    if (!maskable) return _build(context, hidden: false);
    return Consumer(
      builder: (context, ref, _) =>
          _build(context, hidden: watchBalanceHidden(ref)),
    );
  }

  Widget _build(BuildContext context, {required bool hidden}) {
    final colors = Theme.of(context).colorScheme;
    final effectiveStyle = (style ?? AppTypography.amountItem).copyWith(
      color: type == null
          ? null
          : colors.amountColor(isExpense: type == TransactionType.expense),
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final prefix = switch (type) {
      TransactionType.expense => '-',
      TransactionType.income => '+',
      null => '',
    };
    final text = Text(
      hidden ? maskedAmount : '$prefix${formatIdr(amount)}',
      style: effectiveStyle,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: hidden
          ? Semantics(
              label: 'Nominal disembunyikan',
              excludeSemantics: true,
              child: text,
            )
          : text,
    );
  }
}

// -----------------------------------------------------------------------------
// Section header
// -----------------------------------------------------------------------------

/// A row with a title on the left and an optional trailing widget (usually a
/// `TextButton`).
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.titleSection.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
