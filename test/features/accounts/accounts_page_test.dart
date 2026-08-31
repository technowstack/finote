import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/presentation/accounts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('accounts page creates an account without transaction controls', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: AccountsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tunai'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'DANA');
    await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
    await tester.pumpAndSettle();

    expect(find.text('DANA'), findsOneWidget);
    expect(find.text('Transaksi'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
