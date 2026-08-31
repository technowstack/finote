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
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: TransfersPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tunai → BCA'), findsOneWidget);
    expect(find.text('Rp2.000.000'), findsOneWidget);
    expect(await database.select(database.transfers).get(), hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('long transfer labels fit a small screen', (tester) async {
    tester.view.physicalSize = const Size(640, 1200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final accounts = AccountRepository(database);
    final source = await accounts.create(
      name: 'BCA Utama Untuk Kebutuhan Harian Keluarga',
      type: AccountType.bank,
    );
    final destination = await accounts.create(
      name: 'BCA Tabungan Dana Darurat Jangka Panjang',
      type: AccountType.savings,
    );
    await TransferRepository(database).create(
      fromAccountId: source.id,
      toAccountId: destination.id,
      amount: 9000000000000,
      transferDate: DateTime(2026, 8, 31),
      note: 'Catatan transfer yang panjang untuk menguji layar kecil',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: TransfersPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rp9.000.000.000.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
