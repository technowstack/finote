import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// components.md `Snackbar` Tipe=Info: themed inverse surface, no shadow.
void showAppSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
}

/// components.md `Snackbar` Tipe=Error. [message] must be user-friendly
/// Indonesian text, never a raw exception.
void showAppErrorSnackBar(
  BuildContext context,
  String message, {
  String actionLabel = 'Coba lagi',
  VoidCallback? onAction,
}) {
  final colors = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: colors.errorContainer,
        content: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 20, color: colors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyMd.copyWith(
                  color: colors.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
        action: onAction == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: colors.onErrorContainer,
                onPressed: onAction,
              ),
      ),
    );
}
