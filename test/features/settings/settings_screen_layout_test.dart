import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/core/theme/finote_colors.dart';
import 'package:finote/core/widgets/finote_list_tile.dart';
import 'package:finote/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  tester.view.physicalSize = const Size(320, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const SettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    final mode = theme.brightness.name;

    testWidgets('lays out at 320dp with 1.3× text ($mode)', (tester) async {
      await _pump(tester, theme);
      expect(tester.takeException(), isNull);

      for (final label in ['DATA', 'TAMPILAN', 'KEAMANAN', 'TENTANG']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final title in [
        'Akun & Dompet',
        'Kategori',
        'Backup & Restore',
        'Import data lama',
        'Reset data',
        'Tema',
        'PIN & Biometrik',
        'Tentang Finote',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      // Every row keeps the 56dp minimum (and so a 48dp hit area).
      for (final tile in find.byType(FinoteListTile).evaluate()) {
        expect(
          (tile.renderObject! as RenderBox).size.height,
          greaterThanOrEqualTo(56),
        );
      }
      expect(find.text('Ikuti sistem'), findsOneWidget);
    });

    testWidgets('Reset data uses the destructive variant ($mode)', (
      tester,
    ) async {
      await _pump(tester, theme);
      final f = theme.finote;

      final title = tester.widget<Text>(find.text('Reset data'));
      expect(title.style?.color, f.error);
      final resetTile = find.ancestor(
        of: find.text('Reset data'),
        matching: find.byType(FinoteListTile),
      );
      final iconBox = tester.widget<DecoratedBox>(
        find
            .descendant(of: resetTile, matching: find.byType(DecoratedBox))
            .first,
      );
      expect((iconBox.decoration as BoxDecoration).color, f.errorContainer);
      expect(find.textContaining('Backup dulu'), findsOneWidget);

      // Two confirmations; the final action is red. Cancel keeps the data.
      await tester.tap(find.text('Reset data'));
      await tester.pumpAndSettle();
      expect(find.text('Reset semua data?'), findsOneWidget);
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi terakhir'), findsOneWidget);
      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Reset data'),
      );
      expect(
        confirm.style?.backgroundColor?.resolve({}),
        theme.colorScheme.error,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi terakhir'), findsNothing);
      expect(find.text('Data berhasil direset.'), findsNothing);
    });
  }

  testWidgets('theme dialog selects a mode and the tile shows it', (
    tester,
  ) async {
    await _pump(tester, AppTheme.light);
    await tester.tap(find.text('Tema'));
    await tester.pumpAndSettle();
    // Theme options are brand-toned rows now, not RadioListTile.
    expect(find.byType(RadioListTile<ThemeMode>), findsNothing);
    for (final label in ['Ikuti sistem', 'Terang', 'Gelap']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();
    expect(find.text('Gelap'), findsOneWidget);
    expect(find.text('Ikuti sistem'), findsNothing);
  });

  testWidgets(
    'theme dialog fits 320dp with 1.3× text and shows the selection',
    (tester) async {
      await _pump(tester, AppTheme.dark);
      await tester.tap(find.text('Tema'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsNWidgets(2));
      for (final mode in ['Ikuti sistem', 'Terang', 'Gelap']) {
        final row = find.ancestor(
          of: find.text(mode),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(row.first).height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
    },
  );
}
