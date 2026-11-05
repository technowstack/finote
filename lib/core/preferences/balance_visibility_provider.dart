import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the Dashboard hero masks balances. A display preference only;
/// it never touches financial records.
class BalanceVisibilityNotifier extends AsyncNotifier<bool> {
  /// Pass [initial] (read in `main()` before `runApp`) so the very first
  /// frame already knows the preference and never flashes a mask.
  BalanceVisibilityNotifier([this._initial]);

  static const _key = 'finote_hide_balance';

  final bool? _initial;

  @override
  FutureOr<bool> build() {
    final initial = _initial;
    if (initial != null) return initial;
    return readBalanceHidden();
  }

  Future<void> toggle() async {
    final hidden = !(state.value ?? false);
    state = AsyncData(hidden);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, hidden);
  }
}

/// Reads the stored preference; any storage failure means "not hidden".
Future<bool> readBalanceHidden() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(BalanceVisibilityNotifier._key) ?? false;
  } catch (_) {
    return false;
  }
}

/// Masks until the preference is known so a hidden balance never flashes;
/// a storage error falls back to visible rather than locking the user out.
bool watchBalanceHidden(WidgetRef ref) =>
    switch (ref.watch(balanceHiddenProvider)) {
      AsyncData(:final value) => value,
      AsyncError() => false,
      _ => true,
    };

final balanceHiddenProvider =
    AsyncNotifierProvider<BalanceVisibilityNotifier, bool>(
      BalanceVisibilityNotifier.new,
    );
