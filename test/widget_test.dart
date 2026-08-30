import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finote/app/app.dart';
import 'package:finote/core/theme/theme_mode_provider.dart';
import 'package:finote/features/app_lock/data/pin_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app starts with system theme and configured router', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    // Verify default theme mode is system
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final mode = await container.read(themeModeProvider.future);
    expect(mode, ThemeMode.system);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          pinStoreProvider.overrideWithValue(_EmptyPinStore()),
        ],
        child: const FinoteApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finote'), findsOneWidget);
    expect(find.text('Saldo'), findsOneWidget);
    expect(find.text('Belum ada transaksi.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

class _EmptyPinStore implements PinStore {
  @override
  Future<void> delete() async {}

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String value) async {}
}
