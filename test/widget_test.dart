import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finote/app/app.dart';
import 'package:finote/core/theme/theme_mode_provider.dart';

void main() {
  testWidgets('app starts with system theme and configured router', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);

    await tester.pumpWidget(const ProviderScope(child: FinoteApp()));
    await tester.pumpAndSettle();

    expect(find.text('Catatan Keuangan'), findsOneWidget);
    expect(find.text('Fondasi aplikasi siap.'), findsOneWidget);
  });
}
