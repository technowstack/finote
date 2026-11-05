import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the Dashboard hero masks balances. A display preference only;
/// it never touches financial records.
class BalanceVisibilityNotifier extends AsyncNotifier<bool> {
  static const _key = 'finote_hide_balance';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    final hidden = !(state.value ?? false);
    state = AsyncData(hidden);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, hidden);
  }
}

final balanceHiddenProvider =
    AsyncNotifierProvider<BalanceVisibilityNotifier, bool>(
      BalanceVisibilityNotifier.new,
    );
