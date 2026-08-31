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

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('shows a persisted transfer on the transfer page', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final destination = await AccountRepository(database)
        .create(name: 'BCA', type: AccountType.bank);
    final source = (await database.select(database.accounts).get()).singleWhere(
      (account) => account.isDefault,
    );
    await TransferRepository(database).create(
      fromAccountId: source.id,
      toAccountId: destination.id,
      amount: 2000000,
      transferDate: DateTime(2026, 8, 31),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: TransfersPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tunai → BCA'), findsOneWidget);
    expect(find.text('Rp2.000.000'), findsOneWidget);
    expect(await database.select(database.transfers).get(), hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
