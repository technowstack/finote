import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/currency_formatter.dart';
import '../../features/transactions/domain/transaction_type.dart';

// -----------------------------------------------------------------------------
// Error state
// -----------------------------------------------------------------------------

/// A centered error message with a retry button.
///
/// Replaces the per-screen `_ErrorState` / `_ErrorCard` widgets that were
/// duplicated across dashboard, transactions, reports, and categories.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Empty state
// -----------------------------------------------------------------------------

/// A centered icon + message for screens with no data.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
  });

  final IconData icon;
  final String message;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 44,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Loading state
// -----------------------------------------------------------------------------

/// A centered circular progress indicator.
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

// -----------------------------------------------------------------------------
// Currency text
// -----------------------------------------------------------------------------

/// Displays a formatted IDR amount with optional sign and semantic coloring.
///
/// When [type] is provided, the text is colored using the income/expense
/// semantic colors from [AppColors] and prefixed with `+` or `-`.
///
/// Wraps itself in a [FittedBox] so long amounts shrink gracefully.
class CurrencyText extends StatelessWidget {
  const CurrencyText({
    super.key,
    required this.amount,
    this.type,
    this.style,
  });

  final int amount;
  final TransactionType? type;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isExpense = type == TransactionType.expense;

    final effectiveStyle = (style ?? Theme.of(context).textTheme.titleMedium)
        ?.copyWith(
          fontWeight: FontWeight.w700,
          color: type != null ? colors.amountColor(isExpense: isExpense) : null,
        );

    final prefix = switch (type) {
      TransactionType.expense => '-',
      TransactionType.income => '+',
      null => '',
    };

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text('$prefix${formatIdr(amount)}', style: effectiveStyle),
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
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}
