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
    expect(find.text('Kekayaan Bersih'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Belum ada transaksi.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Belum ada transaksi.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('dashboard portfolio summary opens the portfolio tab', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

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

    await tester.tap(find.byKey(const Key('dashboard-portfolio-summary')));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada aset investasi'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'transaction filters and add menu remain independently tappable',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

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

      await tester.tap(find.text('Transaksi'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Tambah transaksi'), findsOneWidget);
      expect(find.text('Filter'), findsOneWidget);

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      expect(find.text('Filter transaksi'), findsOneWidget);
      expect(find.byTooltip('Tambah transaksi'), findsNothing);
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Tambah transaksi'), findsOneWidget);

      await tester.tap(find.byTooltip('Tambah transaksi'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Tambah transaksi'), findsNothing);
      expect(find.text('Tambah transaksi'), findsOneWidget);
      expect(find.text('Tambah transaksi manual'), findsOneWidget);
      expect(find.text('Scan struk'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Tambah transaksi'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('five bottom tabs map to the intended root screens', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

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

    expect(find.text('Beranda'), findsOneWidget);
    await tester.tap(find.text('Transaksi'));
    await tester.pumpAndSettle();
    expect(find.text('Transaksi'), findsAtLeastNWidgets(1));
    expect(find.byTooltip('Tambah transaksi'), findsOneWidget);

    await tester.tap(find.text('Portofolio'));
    await tester.pumpAndSettle();
    expect(find.text('Portofolio'), findsAtLeastNWidgets(1));
    expect(find.byTooltip('Tambah transaksi'), findsNothing);
    expect(find.text('Belum ada aset investasi'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Tambah Aset'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah aset'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();
    expect(find.text('Laporan'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan'), findsAtLeastNWidgets(1));
    expect(find.text('Kelola Aset'), findsNothing);

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
