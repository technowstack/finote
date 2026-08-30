import 'package:finote/core/theme/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to ThemeMode.system when no value is stored', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final mode = await container.read(themeModeProvider.future);
    expect(mode, ThemeMode.system);
  });

  test('persists light theme and restores it', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.light);
    final stored = await container.read(themeModeProvider.future);
    expect(stored, ThemeMode.light);

    // Simulate restart: new container reads from same SharedPreferences
    final container2 = ProviderContainer();
    addTearDown(container2.dispose);

    final restored = await container2.read(themeModeProvider.future);
    expect(restored, ThemeMode.light);
  });

  test('persists dark theme and restores it', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);

    final container2 = ProviderContainer();
    addTearDown(container2.dispose);

    final restored = await container2.read(themeModeProvider.future);
    expect(restored, ThemeMode.dark);
  });

  test('persists system theme and restores it', () async {
    // First set to dark, then switch back to system
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    await container.read(themeModeProvider.notifier).setMode(ThemeMode.system);

    final container2 = ProviderContainer();
    addTearDown(container2.dispose);

    final restored = await container2.read(themeModeProvider.future);
    expect(restored, ThemeMode.system);
  });

  test('falls back to system for invalid stored value', () async {
    SharedPreferences.setMockInitialValues({
      'finote_theme_mode': 'invalid_garbage',
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final mode = await container.read(themeModeProvider.future);
    expect(mode, ThemeMode.system);
  });

  test('falls back to system for empty stored value', () async {
    SharedPreferences.setMockInitialValues({'finote_theme_mode': ''});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final mode = await container.read(themeModeProvider.future);
    expect(mode, ThemeMode.system);
  });
}
