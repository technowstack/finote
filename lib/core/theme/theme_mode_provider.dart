import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes the user's chosen [ThemeMode].
///
/// Stored as a stable string (`system`, `light`, `dark`) rather than an
/// enum index so the value survives code refactors.
///
/// Invalid or missing values fall back to [ThemeMode.system].
class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  static const _key = 'finote_theme_mode';

  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    return _parse(stored);
  }

  Future<void> setMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _serialize(mode));
    state = AsyncData(mode);
  }

  static ThemeMode _parse(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => ThemeMode.system, // fallback for invalid/missing
  };

  static String _serialize(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

final themeModeProvider = AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
