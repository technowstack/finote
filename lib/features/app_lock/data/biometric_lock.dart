import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_repository.dart';

abstract interface class AppLockPreferenceStore {
  Future<bool> readEnabled();
  Future<void> writeEnabled(bool enabled);
}

class SharedPreferencesAppLockStore implements AppLockPreferenceStore {
  static const _key = 'finote_app_lock_biometric_enabled';

  @override
  Future<bool> readEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_key) ?? false;
  }

  @override
  Future<void> writeEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key, enabled);
  }
}

abstract interface class BiometricAuthenticator {
  Future<bool> isAvailable();
  Future<bool> authenticate();
}

class LocalBiometricAuthenticator implements BiometricAuthenticator {
  LocalBiometricAuthenticator([LocalAuthentication? authentication])
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _authentication.isDeviceSupported()) return false;
      if (!await _authentication.canCheckBiometrics) return false;
      return (await _authentication.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    try {
      return await _authentication.authenticate(
        localizedReason: 'Gunakan biometrik untuk membuka Finote',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

class AppLockState {
  const AppLockState({
    this.initialized = false,
    this.pinEnabled = false,
    this.pinLength = 6,
    this.biometricEnabled = false,
    this.sessionUnlocked = false,
    this.authenticating = false,
    this.error,
  });

  final bool initialized;
  final bool pinEnabled;
  final int pinLength;
  final bool biometricEnabled;
  final bool sessionUnlocked;
  final bool authenticating;
  final String? error;

  bool get protectionEnabled => pinEnabled || biometricEnabled;
  bool get locked => protectionEnabled && !sessionUnlocked;

  AppLockState copyWith({
    bool? initialized,
    bool? pinEnabled,
    int? pinLength,
    bool? biometricEnabled,
    bool? sessionUnlocked,
    bool? authenticating,
    String? error,
    bool clearError = false,
  }) {
    return AppLockState(
      initialized: initialized ?? this.initialized,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      pinLength: pinLength ?? this.pinLength,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      sessionUnlocked: sessionUnlocked ?? this.sessionUnlocked,
      authenticating: authenticating ?? this.authenticating,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AppLockController extends StateNotifier<AppLockState> {
  AppLockController(this._preferences, this._biometrics, this._pinStatus)
    : super(const AppLockState()) {
    load();
  }

  final AppLockPreferenceStore _preferences;
  final BiometricAuthenticator _biometrics;
  final Future<PinStatus> Function() _pinStatus;

  Future<void> load() async {
    try {
      final enabled = await _preferences.readEnabled();
      final pinStatus = await _pinStatus();
      if (_disposed) return;
      state = AppLockState(
        initialized: true,
        pinEnabled: pinStatus.enabled,
        pinLength: pinStatus.length,
        biometricEnabled: enabled,
        sessionUnlocked: !enabled && !pinStatus.enabled,
      );
    } catch (_) {
      if (!_disposed) {
        state = const AppLockState(
          initialized: true,
          error: 'Keamanan aplikasi belum dapat dimuat.',
        );
      }
    }
  }

  Future<bool> setBiometricEnabled(bool enabled) async {
    if (state.authenticating) return false;
    if (enabled && !await _biometrics.isAvailable()) {
      state = state.copyWith(
        error: 'Biometrik tidak tersedia atau belum diatur di perangkat.',
      );
      return false;
    }
    if (!await _authenticate()) return false;
    try {
      await _preferences.writeEnabled(enabled);
      if (!_disposed) {
        state = state.copyWith(
          biometricEnabled: enabled,
          sessionUnlocked: true,
          clearError: true,
        );
      }
      return true;
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(
          error: 'Pengaturan Kunci Aplikasi gagal disimpan.',
        );
      }
      return false;
    }
  }

  Future<bool> authenticate() => _authenticate();

  void markPinUnlocked() {
    if (!_disposed) {
      state = state.copyWith(sessionUnlocked: true, clearError: true);
    }
  }

  void beginExternalActivity() {
    _externalActivityActive = true;
  }

  void endExternalActivity() {
    _externalActivityActive = false;
  }

  void handleLifecycle(AppLifecycleState lifecycleState) {
    if (_disposed) return;

    if (_externalActivityActive) {
      return;
    }

    if (state.authenticating) {
      return;
    }

    if (!state.protectionEnabled) {
      return;
    }

    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.hidden) {
      state = state.copyWith(sessionUnlocked: false, clearError: true);
    }
  }

  bool _disposed = false;
  bool _externalActivityActive = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<bool> _authenticate() async {
    if (state.authenticating || _disposed) return false;
    state = state.copyWith(authenticating: true, clearError: true);
    final success = await _biometrics.authenticate();
    if (_disposed) return success;
    state = state.copyWith(
      authenticating: false,
      sessionUnlocked: success ? true : state.sessionUnlocked,
      error: success ? null : 'Autentikasi biometrik dibatalkan atau gagal.',
      clearError: success,
    );
    return success;
  }
}

final appLockPreferenceStoreProvider = Provider<AppLockPreferenceStore>(
  (ref) => SharedPreferencesAppLockStore(),
);

final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>(
  (ref) => LocalBiometricAuthenticator(),
);

final appLockControllerProvider =
    StateNotifierProvider<AppLockController, AppLockState>(
      (ref) => AppLockController(
        ref.watch(appLockPreferenceStoreProvider),
        ref.watch(biometricAuthenticatorProvider),
        () => ref.watch(pinRepositoryProvider).status(),
      ),
    );
