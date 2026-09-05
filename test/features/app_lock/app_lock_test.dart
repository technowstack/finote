import 'package:finote/features/app_lock/data/pin_repository.dart';
import 'package:finote/features/app_lock/data/biometric_lock.dart';
import 'package:finote/features/app_lock/presentation/app_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PIN hides content at startup and after app pause', (
    tester,
  ) async {
    final repository = PinRepository(_MemoryPinStore(), iterations: 2);
    await repository.setPin('1234');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinRepositoryProvider.overrideWithValue(repository),
          appLockPreferenceStoreProvider.overrideWithValue(
            _MemoryAppLockStore(),
          ),
          biometricAuthenticatorProvider.overrideWithValue(
            _FakeBiometricAuthenticator(),
          ),
        ],
        child: const MaterialApp(
          home: AppLock(child: Scaffold(body: Text('Data pribadi'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Data pribadi'), findsNothing);
    expect(find.text('Buka Finote'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    expect(find.text('Data pribadi'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.text('Data pribadi'), findsNothing);
    expect(find.text('Buka Finote'), findsOneWidget);
  });

  testWidgets('biometric App Lock gates content until authentication', (
    tester,
  ) async {
    final preferences = _MemoryAppLockStore()..enabled = true;
    final biometrics = _FakeBiometricAuthenticator();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinRepositoryProvider.overrideWithValue(
            PinRepository(_MemoryPinStore(), iterations: 2),
          ),
          appLockPreferenceStoreProvider.overrideWithValue(preferences),
          biometricAuthenticatorProvider.overrideWithValue(biometrics),
        ],
        child: const MaterialApp(
          home: AppLock(child: Scaffold(body: Text('Data pribadi'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Data pribadi'), findsNothing);
    expect(find.text('Buka dengan Biometrik'), findsOneWidget);
    await tester.tap(find.text('Buka dengan Biometrik'));
    await tester.pumpAndSettle();
    expect(find.text('Data pribadi'), findsOneWidget);
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
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate() async => true;
}

class _MemoryPinStore implements PinStore {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
