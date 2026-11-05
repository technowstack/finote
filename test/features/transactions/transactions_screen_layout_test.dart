import 'dart:async';

import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/core/preferences/balance_visibility_provider.dart';
import 'package:finote/core/theme/app_colors.dart';
import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/core/theme/category_style.dart';
import 'package:finote/core/utils/date_formatter.dart';
import 'package:finote/core/widgets/finote_controls.dart';
import 'package:finote/core/widgets/shared_widgets.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/transactions/data/financial_activity_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/financial_activity.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transactions/presentation/transactions_page.dart';
import 'package:finote/features/transfers/data/transfer_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Seeds today: a default-account expense with a note, a BCA expense with a
/// note, a transfer. Yesterday: an income and an untitled custom-category
/// expense.
Future<AppDatabase> _seededDatabase() async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final categories = CategoryRepository(database);
  final food = await categories.create(
    name: 'Makanan & Minuman',
    type: TransactionType.expense,
  );
  final salary = await categories.create(
    name: 'Gaji',
    type: TransactionType.income,
  );
  final custom = await categories.create(
    name: 'Kopi',
    type: TransactionType.expense,
  );
  final accounts = AccountRepository(database);
  final bca = await accounts.create(name: 'BCA', type: AccountType.bank);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final transactions = TransactionRepository(database);
  await transactions.create(
    type: TransactionType.expense,
    categoryId: food.id,
    amount: 48000,
    title: 'Makan siang',
    note: 'Nasi padang',
    transactionDate: today,
  );
  await transactions.create(
    type: TransactionType.expense,
    categoryId: food.id,
    accountId: bca.id,
    amount: 150000,
    title: 'Belanja bulanan',
    note: 'Alfamart',
    transactionDate: today,
  );
  await transactions.create(
    type: TransactionType.income,
    categoryId: salary.id,
    amount: 8500000,
    title: 'Gaji November',
    transactionDate: yesterday,
  );
  await transactions.create(
    type: TransactionType.expense,
    categoryId: custom.id,
    amount: 20000,
    transactionDate: yesterday,
  );
  final tunai = (await database.select(database.accounts).get()).firstWhere(
    (account) => account.isDefault,
  );
  await TransferRepository(database).create(
    fromAccountId: bca.id,
    toAccountId: tunai.id,
    amount: 500000,
    transferDate: today,
  );
  return database;
}

Future<void> _pumpPage(
  WidgetTester tester,
  ThemeData theme,
  AppDatabase database, {
  double height = 1800,
}) async {
  tester.view.physicalSize = Size(320, height);
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
        home: const TransactionsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The chip row scrolls horizontally (the last chip is clipped at 320dp
/// with 1.3× text), so scroll the chip into view before tapping it.
Future<void> _tapChip(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(FinoteChip, label);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Finder _textMatching(RegExp pattern) => find.byWidgetPredicate(
  (widget) => widget is Text && pattern.hasMatch(widget.data ?? ''),
);

/// testWidgets that unmounts at the end so Drift's stream-cleanup timer is
/// flushed (the convention used by the other database-backed widget tests).
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

    _dbTest('lays out at 320dp with 1.3× text ($mode)', (tester) async {
      final database = await _seededDatabase();
      await _pumpPage(tester, theme, database);
      expect(tester.takeException(), isNull);

      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      // Summary: income 8.500.000 - expense 218.000; the transfer is neither.
      expect(find.text('Arus kas · Semua waktu'), findsOneWidget);
      expect(find.text('+Rp8.282.000'), findsOneWidget);
      expect(find.text('Rp8.500.000'), findsOneWidget);
      expect(find.text('Rp218.000'), findsOneWidget);

      // Date groups with income/expense-only daily totals.
      expect(find.text(formatActivityDateLabel(now, now)), findsOneWidget);
      expect(
        find.text(formatActivityDateLabel(yesterday, now)),
        findsOneWidget,
      );
      expect(find.text('-Rp198.000'), findsOneWidget);
      expect(find.text('+Rp8.480.000'), findsOneWidget);
    });

    _dbTest('rows: subtitle rules, category icons, neutral transfer '
        '($mode)', (tester) async {
      final database = await _seededDatabase();
      await _pumpPage(tester, theme, database);

      // note · time (the default account's name is omitted).
      expect(
        _textMatching(RegExp(r'^Nasi padang · \d{2}\.\d{2}$')),
        findsOneWidget,
      );
      // note · time · account when the account is not the default one.
      expect(
        _textMatching(RegExp(r'^Alfamart · \d{2}\.\d{2} · BCA$')),
        findsOneWidget,
      );
      // 'Tunai' (default account) appears only in the transfer's own route.
      expect(find.textContaining('· Tunai'), findsNothing);
      // Entered today for a past date: no misleading time. Untitled rows
      // fall back to the category name.
      expect(find.text('Kopi'), findsOneWidget);
      expect(find.text('Gaji November'), findsOneWidget);

      final colors = theme.colorScheme;
      expect(find.byIcon(Icons.restaurant_rounded), findsNWidgets(2));
      expect(find.byIcon(customCategoryIcon), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
      // Red/green only on amounts; the transfer amount is neutral.
      expect(
        tester.widget<Text>(find.text('-Rp48.000')).style?.color,
        colors.expenseColor,
      );
      expect(
        tester.widget<Text>(find.text('+Rp8.500.000')).style?.color,
        colors.incomeColor,
      );
      expect(
        tester.widget<Text>(find.text('Rp500.000')).style?.color,
        colors.onSurface,
      );
    });
  }

  _dbTest('hidden balance masks every amount but keeps labels', (tester) async {
    SharedPreferences.setMockInitialValues({'finote_hide_balance': true});
    final database = await _seededDatabase();
    await _pumpPage(tester, AppTheme.light, database);

    for (final amount in [
      '-Rp48.000',
      '+Rp8.500.000',
      'Rp500.000',
      '-Rp198.000',
      '+Rp8.282.000',
      'Rp218.000',
    ]) {
      expect(find.text(amount), findsNothing, reason: amount);
    }
    expect(find.text(maskedAmount), findsWidgets);
    expect(find.text('Makan siang'), findsOneWidget);
    expect(find.text('Arus kas · Semua waktu'), findsOneWidget);
  });

  _dbTest('type chips filter and keep 48dp hit areas', (tester) async {
    final database = await _seededDatabase();
    await _pumpPage(tester, AppTheme.light, database);

    for (final label in ['Semua', 'Pemasukan', 'Pengeluaran', 'Transfer']) {
      final target = tester.getRect(
        find
            .descendant(
              of: find.widgetWithText(FinoteChip, label),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(target.height, greaterThanOrEqualTo(48), reason: label);
    }
    for (final tooltip in ['Cari transaksi', 'Filter transaksi']) {
      final button = find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      );
      expect(
        tester.getSize(button).shortestSide,
        greaterThanOrEqualTo(48),
        reason: tooltip,
      );
    }

    await _tapChip(tester, 'Pemasukan');
    expect(find.text('Gaji November'), findsOneWidget);
    expect(find.text('Makan siang'), findsNothing);
    expect(find.textContaining('Transfer ke'), findsNothing);

    await _tapChip(tester, 'Transfer');
    expect(find.textContaining('Transfer ke'), findsOneWidget);
    expect(find.text('Gaji November'), findsNothing);
    // Transfers alone have no income/expense, so no cashflow summary.
    expect(find.textContaining('Arus kas'), findsNothing);

    await _tapChip(tester, 'Semua');
    expect(find.text('Makan siang'), findsOneWidget);
  });

  _dbTest('filter chips stay pinned while the list scrolls', (tester) async {
    final database = await _seededDatabase();
    await _pumpPage(tester, AppTheme.dark, database, height: 640);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final chip = tester.getRect(find.widgetWithText(FinoteChip, 'Semua'));
    expect(chip.top, lessThan(120));
    expect(tester.takeException(), isNull);
  });

  _dbTest('search stays usable at 320dp and keeps the filter button', (
    tester,
  ) async {
    final database = await _seededDatabase();
    await _pumpPage(tester, AppTheme.light, database);

    await tester.tap(find.byTooltip('Cari transaksi'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Filter transaksi'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Alfamart');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Belanja bulanan'), findsOneWidget);
    expect(find.text('Makan siang'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Tutup pencarian'));
    await tester.pumpAndSettle();
    expect(find.text('Makan siang'), findsOneWidget);
  });

  _dbTest('swipe-to-delete soft-deletes and updates the summary', (
    tester,
  ) async {
    final database = await _seededDatabase();
    await _pumpPage(tester, AppTheme.light, database);

    await tester.drag(find.text('Makan siang'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Hapus aktivitas?'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    final rows = await database.select(database.transactions).get();
    expect(
      rows.firstWhere((row) => row.title == 'Makan siang').deletedAt,
      isNotNull,
    );
    expect(find.text('Makan siang'), findsNothing);
    // 218.000 - 48.000
    expect(find.text('Rp170.000'), findsOneWidget);
  });

  _dbTest('empty and filtered-empty states', (tester) async {
    final empty = AppDatabase(NativeDatabase.memory());
    addTearDown(empty.close);
    await _pumpPage(tester, AppTheme.light, empty);
    expect(find.text('Belum ada transaksi.'), findsOneWidget);
    expect(find.textContaining('Arus kas'), findsNothing);

    await _tapChip(tester, 'Transfer');
    expect(
      find.text('Tidak ada transaksi yang cocok dengan filter.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reset Filter'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada transaksi.'), findsOneWidget);

    await tester.tap(find.byTooltip('Cari transaksi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'tidak ada');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      find.text('Tidak ada transaksi yang cocok dengan filter.'),
      findsOneWidget,
    );
  });

  _dbTest('loading shows a spinner; error offers retry', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final never = StreamController<List<FinancialActivity>>();
    addTearDown(never.close);

    Widget app(ThemeData theme, Stream<List<FinancialActivity>> stream) =>
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            databaseProvider.overrideWithValue(database),
            financialActivityProvider.overrideWith((ref, filter) => stream),
          ],
          child: MaterialApp(theme: theme, home: const TransactionsPage()),
        );

    await tester.pumpWidget(app(AppTheme.dark, never.stream));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(
      app(AppTheme.light, Stream<List<FinancialActivity>>.error('boom')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aktivitas belum dapat dimuat.'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  group('balance preference preloaded in main()', () {
    /// Pumps exactly one frame (the first one).
    Future<void> pumpFirstFrame(
      WidgetTester tester, {
      List<Override> overrides = const [],
    }) => tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          home: Scaffold(body: CurrencyText(amount: 15000000, maskable: true)),
        ),
      ),
    );

    testWidgets('known "visible" renders the amount on the first frame', (
      tester,
    ) async {
      await pumpFirstFrame(
        tester,
        overrides: [
          balanceHiddenProvider.overrideWith(
            () => BalanceVisibilityNotifier(false),
          ),
        ],
      );
      expect(find.text('Rp15.000.000'), findsOneWidget);
      expect(find.text(maskedAmount), findsNothing);
    });

    testWidgets('known "hidden" masks on the first frame', (tester) async {
      await pumpFirstFrame(
        tester,
        overrides: [
          balanceHiddenProvider.overrideWith(
            () => BalanceVisibilityNotifier(true),
          ),
        ],
      );
      expect(find.text(maskedAmount), findsOneWidget);
      expect(find.text('Rp15.000.000'), findsNothing);
    });

    testWidgets('without preloading, only the first frame is masked', (
      tester,
    ) async {
      await pumpFirstFrame(tester);
      expect(find.text(maskedAmount), findsOneWidget);
      // ...and resolves once the stored preference has been read.
      await tester.pumpAndSettle();
      expect(find.text('Rp15.000.000'), findsOneWidget);
    });

    test('readBalanceHidden reads the stored value', () async {
      SharedPreferences.setMockInitialValues({'finote_hide_balance': true});
      expect(await readBalanceHidden(), isTrue);
      SharedPreferences.setMockInitialValues({});
      expect(await readBalanceHidden(), isFalse);
    });
  });
}
