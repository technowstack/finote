import 'package:finote/features/app_lock/data/biometric_lock.dart';
import 'package:finote/features/app_lock/data/pin_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// An unlocked [AppLockController] with in-memory dependencies, for services
/// such as `BackupService` that only need it to bracket external activities.
///
/// Must be called inside a test or `setUp`; it is disposed on tear-down.
AppLockController fakeAppLockController() {
  final controller = AppLockController(
    _MemoryAppLockStore(),
    _NoBiometrics(),
    () async => const PinStatus(enabled: false, length: 6),
  );
  addTearDown(controller.dispose);
  return controller;
}

class _MemoryAppLockStore implements AppLockPreferenceStore {
  bool _enabled = false;

  @override
  Future<bool> readEnabled() async => _enabled;

  @override
  Future<void> writeEnabled(bool enabled) async => _enabled = enabled;
}

class _NoBiometrics implements BiometricAuthenticator {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate() async => false;
}
