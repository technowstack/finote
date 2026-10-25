import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/core/widgets/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('empty-state icon is readable in ${theme.brightness}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: AppEmptyState(
              icon: Icons.edit_note_outlined,
              message: 'Belum ada data',
            ),
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.edit_note_outlined));
      expect(
        icon.color,
        theme.brightness == Brightness.light
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.outline,
      );
    });
  }
}
