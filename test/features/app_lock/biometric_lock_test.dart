import 'dart:async';

import 'package:finote/features/app_lock/data/biometric_lock.dart';
import 'package:finote/features/app_lock/data/pin_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _MemoryAppLockStore preferences;
  late _FakeBiometricAuthenticator biometrics;
  late AppLockController controller;

  setUp(() async {
    preferences = _MemoryAppLockStore();
    biometrics = _FakeBiometricAuthenticator();
    controller = AppLockController(
      preferences,
      biometrics,
      () async => const PinStatus(enabled: false, length: 6),
    );
    await controller.load();
  });

  tearDown(() => controller.dispose());

  test('cold start is unlocked when biometric App Lock is disabled', () {
    expect(controller.state.initialized, isTrue);
    expect(controller.state.locked, isFalse);
  });

  test('successful authentication enables biometric App Lock', () async {
    expect(await controller.setBiometricEnabled(true), isTrue);
    expect(preferences.enabled, isTrue);
    expect(controller.state.biometricEnabled, isTrue);
  });

  test('failed authentication does not enable biometric App Lock', () async {
    biometrics.authenticationResult = false;

    expect(await controller.setBiometricEnabled(true), isFalse);
    expect(preferences.enabled, isFalse);
    expect(controller.state.biometricEnabled, isFalse);
  });

  test('cancellation keeps enabled App Lock locked', () async {
    biometrics.authenticationResult = true;
    expect(await controller.setBiometricEnabled(true), isTrue);
    controller.handleLifecycle(AppLifecycleState.paused);
    biometrics.authenticationResult = false;

    expect(await controller.authenticate(), isFalse);
    expect(controller.state.locked, isTrue);
  });

  test('disabling App Lock requires successful authentication', () async {
    expect(await controller.setBiometricEnabled(true), isTrue);
    biometrics.authenticationResult = false;
    expect(await controller.setBiometricEnabled(false), isFalse);
    expect(preferences.enabled, isTrue);

    biometrics.authenticationResult = true;
    expect(await controller.setBiometricEnabled(false), isTrue);
    expect(preferences.enabled, isFalse);
  });

  test('unsupported biometrics cannot enable App Lock', () async {
    biometrics.available = false;
    expect(await controller.setBiometricEnabled(true), isFalse);
    expect(preferences.enabled, isFalse);
    expect(biometrics.authenticationCalls, 0);
  });

  test('duplicate authentication requests are coalesced', () async {
    final result = Completer<bool>();
    biometrics.pending = result.future;
    final first = controller.setBiometricEnabled(true);
    final second = controller.setBiometricEnabled(true);

    expect(await second, isFalse);
    expect(biometrics.authenticationCalls, 1);
    result.complete(true);
    expect(await first, isTrue);
  });
}

class _MemoryAppLockStore implements AppLockPreferenceStore {
  bool enabled = false;

  @override
  Future<bool> readEnabled() async => enabled;

  @override
  Future<void> writeEnabled(bool value) async => enabled = value;
}

class _FakeBiometricAuthenticator implements BiometricAuthenticator {
  bool available = true;
  bool authenticationResult = true;
  Future<bool>? pending;
  int authenticationCalls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate() {
    authenticationCalls++;
    return pending ?? Future.value(authenticationResult);
  }
}
