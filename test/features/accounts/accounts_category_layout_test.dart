import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/core/utils/currency_formatter.dart';
import 'package:finote/core/widgets/finance_tiles.dart';
import 'package:finote/core/widgets/finote_hero.dart';
import 'package:finote/core/widgets/shared_widgets.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/accounts/presentation/accounts_page.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/categories/presentation/category_page.dart';
import 'package:finote/features/dashboard/presentation/dashboard_page.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
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

    _dbTest('Kategori lays out at 320dp with 1.3× text ($mode)', (
      tester,
    ) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final categories = CategoryRepository(database);
      await categories.create(
        name: 'Kategori dengan nama yang sangat panjang sekali',
        type: TransactionType.expense,
      );
      await categories.create(name: 'Belanja', type: TransactionType.expense);
      await _pump(tester, theme, database, const CategoryPage());
      expect(tester.takeException(), isNull);

      expect(find.text('Kategori'), findsOneWidget);
      expect(find.text('Belanja'), findsOneWidget);
      expect(find.byType(CategoryIconTile), findsWidgets);
      // Each row's menu keeps a usable touch target.
      for (final menu in find.byTooltip('Tindakan kategori').evaluate()) {
        expect(
          (menu.renderObject! as RenderBox).size.shortestSide,
          greaterThanOrEqualTo(40),
        );
      }
    });

    _dbTest('Akun & Dompet lays out at 320dp with 1.3× text ($mode)', (
      tester,
    ) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await AccountRepository(database).create(
        name: 'BCA Utama Tabungan Keluarga',
        type: AccountType.bank,
        initialBalance: 12000000,
      );
      await _pump(tester, theme, database, const AccountsPage());
      expect(tester.takeException(), isNull);

      expect(find.text('Akun & Dompet'), findsOneWidget);
      expect(find.text('Total saldo semua akun'), findsOneWidget);
      expect(find.text('BCA Utama Tabungan Keluarga'), findsOneWidget);
      // Two rows: the seeded account and the default Tunai account.
      expect(find.textContaining('Saldo Saat Ini'), findsNWidgets(2));
    });
  }

  _dbTest('Akun total equals the Beranda "Kas & Dompet" figure', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final accounts = AccountRepository(database);
    await accounts.create(
      name: 'BCA Utama',
      type: AccountType.bank,
      initialBalance: 5000000,
    );
    final archived = await accounts.create(
      name: 'Arsip Lama',
      type: AccountType.cash,
      initialBalance: 1000000,
    );
    await accounts.archive(archived.id);
    final expected = formatIdr(6000000);

    // Beranda's cash tile.
    await _pump(tester, AppTheme.light, database, const DashboardPage());
    final tile = find.ancestor(
      of: find.text('Kas & Dompet'),
      matching: find.byType(FinoteHeroTile),
    );
    expect(
      find.descendant(of: tile, matching: find.text(expected)),
      findsOneWidget,
    );

    // Akun & Dompet total card.
    await _pump(tester, AppTheme.light, database, const AccountsPage());
    final total = find.ancestor(
      of: find.text('Total saldo semua akun'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: total, matching: find.text(expected)),
      findsOneWidget,
    );
    // The default Tunai account is active too, so two active accounts.
    expect(find.text('2 akun aktif · 1 diarsipkan'), findsOneWidget);
  });

  _dbTest('Akun total is masked while balances are hidden', (tester) async {
    SharedPreferences.setMockInitialValues({'finote_hide_balance': true});
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await AccountRepository(database).create(
      name: 'BCA Utama',
      type: AccountType.bank,
      initialBalance: 5000000,
    );
    await _pump(tester, AppTheme.light, database, const AccountsPage());
    expect(find.text('Rp5.000.000'), findsNothing);
    expect(find.text(maskedAmount), findsWidgets);
  });
}
