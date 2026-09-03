import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/assets/presentation/assets_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('creates, edits, opens, archives, and restores an asset', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.ensureDefaultAccount();
    await CategoryRepository(database).initializeDefaults();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const AssetsPage()),
        GoRoute(
          path: '/portfolio/assets/:id',
          builder: (_, state) =>
              AssetDetailPage(assetId: int.parse(state.pathParameters['id']!)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Belum ada aset investasi'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Tambah Aset'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'bbca');
    await tester.enterText(
      find.byType(TextFormField).last,
      'Bank Central Asia',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
    await tester.pumpAndSettle();

    expect(find.text('BBCA'), findsOneWidget);
    expect(find.textContaining('Bank Central Asia'), findsOneWidget);
    expect(find.text('Belum ada aset'), findsNothing);

    await tester.tap(find.text('BBCA'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Aset'), findsOneWidget);
    expect(find.text('Belum ada posisi'), findsAtLeastNWidgets(1));
    await tester.tap(find.widgetWithText(FilledButton, 'Tambah Posisi Awal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '12');
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan Posisi'));
    await tester.pumpAndSettle();
    expect(find.text('12 lot'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Edit Posisi Awal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '15');
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan Posisi'));
    await tester.pumpAndSettle();
    expect(find.text('15 lot'), findsAtLeastNWidgets(1));
    expect(find.text('27 lot'), findsNothing);

    await tester.tap(find.byTooltip('Hapus Posisi Awal'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada posisi'), findsAtLeastNWidgets(1));
    await tester.tap(find.widgetWithText(FilledButton, 'Tambah Posisi Awal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '12');
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan Posisi'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.text('BBCA'),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(of: card, matching: find.byTooltip('Tindakan aset')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).last,
      'Bank Central Asia Tbk',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bank Central Asia Tbk'), findsOneWidget);

    final editedCard = find.ancestor(
      of: find.text('BBCA'),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(
        of: editedCard,
        matching: find.byTooltip('Tindakan aset'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arsipkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Arsipkan'));
    await tester.pumpAndSettle();
    expect(find.text('Aset Diarsipkan'), findsOneWidget);

    await tester.tap(find.byTooltip('Tindakan aset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aktifkan kembali'));
    await tester.pumpAndSettle();
    expect(find.text('Saham'), findsOneWidget);
    await tester.tap(find.text('BBCA'));
    await tester.pumpAndSettle();
    expect(find.text('12 lot'), findsAtLeastNWidgets(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
