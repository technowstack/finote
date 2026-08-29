import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/categories/presentation/category_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('category page lists defaults and creates an expense category', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: CategoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Makanan & Minuman'), findsOneWidget);
    expect(find.text('Gaji'), findsNothing);

    await tester.tap(find.text('Tambah kategori'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Olahraga');
    await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
    await tester.pumpAndSettle();

    expect(find.text('Olahraga'), findsOneWidget);

    await tester.tap(find.text('Pemasukan'));
    await tester.pumpAndSettle();
    expect(find.text('Gaji'), findsOneWidget);
    expect(find.text('Olahraga'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
