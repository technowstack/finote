import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/transfers/data/transfer_repository.dart';
import 'package:finote/features/transfers/presentation/transfers_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression tests for the transfer dialog validator and submit path.
/// An earlier report of a validator exception came from a debugger breakpoint,
/// not from the app; these tests lock the validation behaviour down.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() => initializeDateFormatting('id_ID'));

  Future<AppDatabase> open(
    WidgetTester tester, {
    bool withTransfer = false,
  }) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final bca = await AccountRepository(database)
        .create(name: 'BCA', type: AccountType.bank);
    final tunai = (await database.select(database.accounts).get()).singleWhere(
      (a) => a.isDefault,
    );
    if (withTransfer) {
      await TransferRepository(database).create(
        fromAccountId: tunai.id,
        toAccountId: bca.id,
        amount: 1000000,
        transferDate: DateTime(2026, 8, 31),
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: TransfersPage()),
      ),
    );
    await tester.pumpAndSettle();
    return database;
  }

  Future<void> pick(WidgetTester t, int dropdown, String label) async {
    await t.tap(find.byType(DropdownButtonFormField<int>).at(dropdown));
    await t.pumpAndSettle();
    await t.tap(find.textContaining(label).last);
    await t.pumpAndSettle();
  }

  testWidgets(
    'submitting an empty transfer form shows the source-account error',
    (tester) async {
      await open(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Pilih akun asal.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('choosing the same source and destination account is rejected', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await pick(tester, 0, 'BCA ·');
    await pick(tester, 1, 'BCA ·');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nominal'),
      '1000',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Akun asal dan tujuan tidak boleh sama.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a dotted amount such as 1.000.000 is saved as 1000000', (
    tester,
  ) async {
    final db = await open(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await pick(tester, 0, 'Tunai ·');
    await pick(tester, 1, 'BCA ·');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nominal'),
      '1.000.000',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect((await db.select(db.transfers).get()).single.amount, 1000000);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('saving an unchanged existing transfer keeps its amount', (
    tester,
  ) async {
    final db = await open(tester, withTransfer: true);
    await tester.tap(find.byTooltip('Tindakan transfer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect((await db.select(db.transfers).get()).single.amount, 1000000);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
