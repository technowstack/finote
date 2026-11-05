import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/core/theme/app_theme.dart';
import 'package:finote/core/widgets/finote_controls.dart';
import 'package:finote/core/widgets/shared_widgets.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/reports/presentation/reports_page.dart';
import 'package:finote/features/reports/presentation/widgets/report_compact_summary.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transfers/data/transfer_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Income 10.000.000 and food 1.000.000 / shopping 250.000 this month on
/// BCA Utama. With [withTransfer] there is also a 2.000.000 transfer.
Future<AppDatabase> _seed({bool withTransfer = true}) async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final accounts = AccountRepository(database);
  final source = await accounts.create(
    name: 'BCA Utama',
    type: AccountType.bank,
  );
  final destination = await accounts.create(
    name: 'BCA Tabungan',
    type: AccountType.savings,
  );
  final categories = CategoryRepository(database);
  final salary = await categories.create(
    name: 'Gaji',
    type: TransactionType.income,
  );
  final food = await categories.create(
    name: 'Makanan & Minuman',
    type: TransactionType.expense,
  );
  final shopping = await categories.create(
    name: 'Belanja',
    type: TransactionType.expense,
  );
  final now = DateTime.now();
  final date = DateTime(now.year, now.month, now.day);
  final transactions = TransactionRepository(database);
  await transactions.create(
    type: TransactionType.income,
    categoryId: salary.id,
    accountId: source.id,
    amount: 10000000,
    transactionDate: date,
  );
  await transactions.create(
    type: TransactionType.expense,
    categoryId: food.id,
    accountId: source.id,
    amount: 1000000,
    note: 'Makan siang tim',
    transactionDate: date,
  );
  await transactions.create(
    type: TransactionType.expense,
    categoryId: shopping.id,
    accountId: source.id,
    amount: 250000,
    transactionDate: date,
  );
  if (withTransfer) {
    await TransferRepository(database).create(
      fromAccountId: source.id,
      toAccountId: destination.id,
      amount: 2000000,
      transferDate: date,
    );
  }
  return database;
}

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme,
  AppDatabase database, {
  double height = 3000,
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
        home: const ReportsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

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

double _chipTargetHeight(WidgetTester tester, String label) => tester
    .getSize(
      find
          .descendant(
            of: find.widgetWithText(FinoteChip, label),
            matching: find.byType(GestureDetector),
          )
          .first,
    )
    .height;

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    final mode = theme.brightness.name;

    _dbTest('Ringkasan lays out at 320dp with 1.3× text ($mode)', (
      tester,
    ) async {
      final database = await _seed();
      await _pump(tester, theme, database);
      expect(tester.takeException(), isNull);

      // Hero-style Saldo periode: period cashflow, clearly not wealth.
      expect(find.text('Saldo periode'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CompactSummary),
          matching: find.text('Rp8.750.000'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Arus kas periode ini, bukan total kekayaan'),
        findsOneWidget,
      );

      // Category bars: "name · share" and the amount on one row each.
      await tester.scrollUntilVisible(
        find.text('Pengeluaran per kategori'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Makanan & Minuman · 80%'), findsOneWidget);
      expect(find.text('Belanja · 20%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    _dbTest('Ringkasan: zero transfer and Rp0 investment use compact empty '
        'states ($mode)', (tester) async {
      final database = await _seed(withTransfer: false);
      await _pump(tester, theme, database);

      await tester.scrollUntilVisible(
        find.text('Belum ada transfer'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Belum ada transfer'), findsOneWidget);
      expect(find.text('Belum ada arus kas investasi'), findsOneWidget);
      expect(find.byType(AppEmptyState), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    _dbTest('Riwayat tab and controls at 320dp ($mode)', (tester) async {
      final database = await _seed();
      await _pump(tester, theme, database);

      for (final label in ['Semua', 'Hari ini', 'Bulan ini']) {
        expect(
          _chipTargetHeight(tester, label),
          greaterThanOrEqualTo(48),
          reason: label,
        );
      }
      final segment = tester.getSize(
        find.ancestor(of: find.text('Riwayat'), matching: find.byType(InkWell)),
      );
      expect(segment.height, greaterThanOrEqualTo(48));

      await tester.tap(find.text('Riwayat'));
      await tester.pumpAndSettle();
      expect(find.text('Saldo periode'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Ringkasan'));
      await tester.pumpAndSettle();
      expect(find.text('Saldo periode'), findsOneWidget);
    });

    _dbTest('Export dialog fits 320dp with 1.3× text ($mode)', (tester) async {
      final database = await _seed();
      await _pump(tester, theme, database, height: 1400);

      await tester.tap(find.byTooltip('Export laporan'));
      await tester.pumpAndSettle();
      expect(find.text('Export Laporan'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Variants: Teks (Batal), Outline (Bagikan), Primer (Simpan).
      final buttons = [
        find.widgetWithText(TextButton, 'Batal'),
        find.widgetWithText(OutlinedButton, 'Bagikan'),
        find.widgetWithText(FilledButton, 'Simpan'),
      ];
      for (final finder in buttons) {
        expect(finder, findsOneWidget);
        expect(
          tester.getSize(finder).height,
          greaterThanOrEqualTo(48),
          reason: 'every dialog button keeps a 48dp target',
        );
      }

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Export Laporan'), findsNothing);
    });
  }

  _dbTest('hidden balance masks the hero and category amounts', (tester) async {
    SharedPreferences.setMockInitialValues({'finote_hide_balance': true});
    final database = await _seed();
    await _pump(tester, AppTheme.light, database);

    expect(
      find.descendant(
        of: find.byType(CompactSummary),
        matching: find.text('Rp8.750.000'),
      ),
      findsNothing,
    );
    expect(find.text(maskedAmount), findsWidgets);
    expect(find.text('Saldo periode'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Pengeluaran per kategori'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Rp1.000.000'), findsNothing);
    expect(find.text('Makanan & Minuman · 80%'), findsOneWidget);
  });
}
