import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/core/theme/finote_colors.dart';
import 'package:finote/core/widgets/finote_controls.dart';
import 'package:finote/features/app_lock/data/biometric_lock.dart';
import 'package:finote/features/app_lock/data/pin_repository.dart';
import 'package:finote/features/app_lock/presentation/app_lock.dart';
import 'package:finote/features/app_lock/presentation/security_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Store implements AppLockPreferenceStore {
  bool enabled = false;

  @override
  Future<bool> readEnabled() async => enabled;

  @override
  Future<void> writeEnabled(bool value) async => enabled = value;
}

class _Biometrics implements BiometricAuthenticator {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate() async => true;
}

class _Pin implements PinStore {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme,
  Widget home, {
  required _Store store,
  PinRepository? repository,
}) async {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pinRepositoryProvider.overrideWithValue(
          repository ?? PinRepository(_Pin(), iterations: 2),
        ),
        appLockPreferenceStoreProvider.overrideWithValue(store),
        biometricAuthenticatorProvider.overrideWithValue(_Biometrics()),
      ],
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    final mode = theme.brightness.name;

    testWidgets('Keamanan lays out at 320dp with 1.3× text ($mode)', (
      tester,
    ) async {
      final repository = PinRepository(_Pin(), iterations: 2);
      await repository.setPin('1234');
      await _pump(
        tester,
        theme,
        const SecurityPage(),
        store: _Store(),
        repository: repository,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Ubah PIN aplikasi'), findsOneWidget);
      expect(find.text('Kunci Aplikasi'), findsOneWidget);
      expect(find.byType(FinoteSegmented<int>), findsOneWidget);
      expect(
        tester
            .getSize(find.widgetWithText(TextButton, 'Nonaktifkan PIN'))
            .height,
        greaterThanOrEqualTo(48),
      );
      // Disabling the PIN is destructive: error color, not the brand color.
      final disable = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Nonaktifkan PIN'),
      );
      expect(disable.style?.foregroundColor?.resolve({}), theme.finote.error);
    });

    testWidgets('PIN lock page lays out at 320dp with 1.3× text ($mode)', (
      tester,
    ) async {
      final repository = PinRepository(_Pin(), iterations: 2);
      await repository.setPin('1234');
      await _pump(
        tester,
        theme,
        const AppLock(child: Scaffold(body: Text('Data pribadi'))),
        store: _Store(),
        repository: repository,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Buka Finote'), findsOneWidget);
      expect(find.text('Data pribadi'), findsNothing);
    });

    testWidgets(
      'biometric lock page lays out at 320dp with 1.3× text ($mode)',
      (tester) async {
        await _pump(
          tester,
          theme,
          const AppLock(child: Scaffold(body: Text('Data pribadi'))),
          store: _Store()..enabled = true,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Kunci Aplikasi'), findsOneWidget);
        expect(find.text('Data pribadi'), findsNothing);
      },
    );
  }
}
