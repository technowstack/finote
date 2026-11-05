import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/core/widgets/finance_tiles.dart';
import 'package:finote/core/widgets/finote_controls.dart';
import 'package:finote/core/widgets/shared_widgets.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transactions/presentation/transaction_detail_page.dart';
import 'package:finote/features/transactions/presentation/transaction_form_page.dart';
import 'package:finote/features/transactions/presentation/widgets/transaction_form_fields.dart';
import 'package:finote/features/transfers/data/transfer_repository.dart';
import 'package:finote/features/transfers/presentation/transfers_page.dart';
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

    _dbTest('Form tambah transaksi lays out at 320dp with 1.3× text ($mode)', (
      tester,
    ) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await CategoryRepository(database)
          .create(name: 'Makanan & Minuman', type: TransactionType.expense);
      await CategoryRepository(database).create(
        name: 'Kategori buatan dengan nama panjang',
        type: TransactionType.expense,
      );
      await _pump(tester, theme, database, const TransactionFormPage());
      expect(tester.takeException(), isNull);

      expect(find.text('Pengeluaran'), findsWidgets);
      expect(find.byType(FinoteSegmented<TransactionType>), findsOneWidget);
      expect(find.byType(TransactionTypeToggle), findsOneWidget);
      expect(find.byType(TransactionCategoryGrid), findsOneWidget);
      expect(find.text('Makanan & Minuman'), findsOneWidget);
      expect(find.text('Simpan pengeluaran'), findsOneWidget);
    });

    _dbTest('Detail transaksi lays out at 320dp with 1.3× text ($mode)', (
      tester,
    ) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final category = await CategoryRepository(database)
          .create(name: 'Makanan', type: TransactionType.expense);
      final created = await TransactionRepository(database).create(
        type: TransactionType.expense,
        categoryId: category.id,
        amount: 1250000,
        title: 'Makan siang tim proyek',
        transactionDate: DateTime(2026, 8, 30),
      );
      await _pump(
        tester,
        theme,
        database,
        TransactionDetailPage(transactionId: created.id),
      );
      expect(tester.takeException(), isNull);

      expect(find.text('Detail transaksi'), findsOneWidget);
      expect(find.text('-Rp1.250.000'), findsOneWidget);
      expect(find.text('Makanan'), findsWidgets);
      expect(find.byType(CurrencyText), findsWidgets);
      // The delete action sits behind the destructive confirmation.
      await tester.tap(find.byTooltip('Hapus transaksi').first);
      await tester.pumpAndSettle();
      expect(find.text('Transaksi tidak akan muncul lagi.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
    });

    _dbTest('Transfer antar akun lays out at 320dp with 1.3× text ($mode)', (
      tester,
    ) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final bca = await AccountRepository(database)
          .create(name: 'BCA Utama Tabungan', type: AccountType.bank);
      final tunai = (await database.select(database.accounts).get())
          .singleWhere((account) => account.isDefault);
      await TransferRepository(database).create(
        fromAccountId: tunai.id,
        toAccountId: bca.id,
        amount: 2000000,
        note: 'Isi dompet untuk minggu ini yang panjang',
        transferDate: DateTime(2026, 8, 31),
      );
      await _pump(tester, theme, database, const TransfersPage());
      expect(tester.takeException(), isNull);

      expect(find.text('Tunai → BCA Utama Tabungan'), findsOneWidget);
      expect(find.byType(TransferTile), findsOneWidget);
      expect(find.text('Rp2.000.000'), findsOneWidget);
      expect(find.byTooltip('Tindakan transfer'), findsOneWidget);
    });
  }

  _dbTest('Detail amount is masked while balances are hidden', (tester) async {
    SharedPreferences.setMockInitialValues({'finote_hide_balance': true});
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final category = await CategoryRepository(database)
        .create(name: 'Makanan', type: TransactionType.expense);
    final created = await TransactionRepository(database).create(
      type: TransactionType.expense,
      categoryId: category.id,
      amount: 1250000,
      transactionDate: DateTime(2026, 8, 30),
    );
    await _pump(
      tester,
      AppTheme.light,
      database,
      TransactionDetailPage(transactionId: created.id),
    );
    expect(find.text('-Rp1.250.000'), findsNothing);
    expect(find.text(maskedAmount), findsWidgets);
  });
}
