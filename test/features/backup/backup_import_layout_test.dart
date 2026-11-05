import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/core/widgets/finote_controls.dart';
import 'package:finote/core/widgets/finote_list_tile.dart';
import 'package:finote/features/backup/presentation/backup_page.dart';
import 'package:finote/features/legacy_import/presentation/legacy_import_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme,
  AppDatabase database,
  Widget home,
) async {
  tester.view.physicalSize = const Size(320, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
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

void _dbTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    final mode = theme.brightness.name;

    _dbTest('Backup lays out at 320dp with 1.3× text ($mode)', (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _pump(tester, theme, database, const BackupPage());
      expect(tester.takeException(), isNull);

      expect(find.text('Backup dan restore'), findsOneWidget);
      expect(find.text('Simpan salinan data Anda'), findsOneWidget);
      expect(find.text('Buat backup'), findsOneWidget);
      expect(find.byType(FinoteIconBadge), findsWidgets);
      expect(find.byType(FinoteListTile), findsWidgets);
      // Primary action keeps a 48dp target.
      expect(
        tester.getSize(find.widgetWithText(FilledButton, 'Buat backup')).height,
        greaterThanOrEqualTo(48),
      );
    });

    _dbTest('Import lays out at 320dp with 1.3× text ($mode)', (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _pump(tester, theme, database, const LegacyImportPage());
      expect(tester.takeException(), isNull);

      expect(find.text('Import dari aplikasi lama'), findsWidgets);
      expect(find.byType(FinoteIconBadge), findsWidgets);
    });
  }

  _dbTest('Backup tabs use FinoteSegmented and keep both panes mounted', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _pump(tester, AppTheme.light, database, const BackupPage());

    expect(find.byType(FinoteSegmented<int>), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Simpan salinan data Anda'), findsOneWidget);

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan salinan data Anda'), findsNothing);

    // IndexedStack keeps the Backup pane alive, so switching back is cheap
    // and any in-progress state survives the switch.
    await tester.tap(find.text('Backup'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan salinan data Anda'), findsOneWidget);
    expect(find.byType(IndexedStack), findsOneWidget);
  });
}
