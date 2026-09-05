import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/assets/data/asset_activity_service.dart';
import 'package:finote/features/assets/data/asset_repository.dart';
import 'package:finote/features/assets/data/asset_transaction_repository.dart';
import 'package:finote/features/assets/domain/asset_quantity.dart';
import 'package:finote/features/assets/domain/asset_transaction_action.dart';
import 'package:finote/features/assets/domain/asset_type.dart';
import 'package:finote/features/backup/data/backup_service.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/dashboard/data/dashboard_repository.dart';
import 'package:finote/features/market/data/asset_price_repository.dart';
import 'package:finote/features/market/data/market_api_client.dart';
import 'package:finote/features/market/data/market_repository.dart';
import 'package:finote/features/market/data/portfolio_market_quotes_provider.dart';
import 'package:finote/features/reports/data/report_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'v1.0 schema 3 upgrades without reconstruction and stays reactive',
    () async {
      final temp = await Directory.systemTemp.createTemp('finote_v1_upgrade_');
      addTearDown(() => temp.delete(recursive: true));
      final path = '${temp.path}/finote.sqlite';
      _createVersion3Database(path);

      var database = AppDatabase(NativeDatabase(File(path)));
      await database.customSelect('SELECT 1').getSingle();
      expect(await _userVersion(database), 11);
      await _expectIntegrity(database);

      final original = await database.select(database.transactions).get();
      expect(original, hasLength(4));
      expect(original.map((row) => row.id), [100, 101, 102, 103]);
      expect(original.map((row) => row.uuid), [
        'tx-purchase-v1',
        'tx-sale-v1',
        'tx-normal-v1',
        'tx-deleted-v1',
      ]);
      expect(original.map((row) => row.amount), [
        10000000,
        4000000,
        25000,
        700000,
      ]);
      expect(original[0].transactionDate, DateTime(2021, 7, 1));
      expect(original[3].deletedAt, isNotNull);
      expect(original[1].legacySource, 'catatan_keuangan_old:fixture');
      expect(original[1].legacyId, 77);

      final defaultAccount = await database
          .select(database.accounts)
          .getSingle();
      expect(defaultAccount.isDefault, isTrue);
      expect(defaultAccount.isActive, isTrue);
      expect(
        original.every((row) => row.accountId == defaultAccount.id),
        isTrue,
      );
      expect(await database.select(database.transfers).get(), isEmpty);
      expect(await database.select(database.assets).get(), isEmpty);
      expect(await database.select(database.assetTransactions).get(), isEmpty);
      expect(await database.select(database.assetPrices).get(), isEmpty);
      expect(
        (await database.select(database.settings).get())
            .singleWhere((row) => row.key == 'theme_mode')
            .value,
        'dark',
      );

      final reports = ReportRepository(database);
      final range = ReportRange(
        start: DateTime(2021),
        end: DateTime(2026, 12, 31),
      );
      final report = await reports.watchReport(range).first;
      expect(
        (report.totalIncome, report.totalExpense, report.netBalance),
        (4000000, 10025000, -6025000),
      );
      final investment = await reports.watchInvestmentCashflow(range).first;
      expect(
        (investment.totalPurchases, investment.totalSales),
        (10000000, 4000000),
      );

      final categories = CategoryRepository(database);
      await categories.initializeDefaults();
      await categories.initializeDefaults();
      final categoryRows = await database.select(database.categories).get();
      expect(
        categoryRows.where(
          (row) =>
              row.name == 'Pembelian Aset' &&
              row.type == TransactionType.expense,
        ),
        hasLength(1),
      );
      expect(
        categoryRows.where(
          (row) =>
              row.name == 'Penjualan Aset' &&
              row.type == TransactionType.income,
        ),
        hasLength(1),
      );
      expect(
        categoryRows.singleWhere((row) => row.id == 10).uuid,
        'cat-purchase-v1',
      );

      final transactions = TransactionRepository(database);
      final history = StreamIterator(transactions.watchAll());
      final dashboard = StreamIterator(
        DashboardRepository(database).watchSummary(DateTime(2026, 9, 4)),
      );
      expect(
        await history.moveNext().timeout(const Duration(seconds: 5)),
        isTrue,
      );
      expect(
        await dashboard.moveNext().timeout(const Duration(seconds: 5)),
        isTrue,
      );
      final baselineExpense = dashboard.current.monthlyExpense;
      final expenseCategory = categoryRows.firstWhere(
        (row) => row.name == 'Belanja' && row.type == TransactionType.expense,
      );
      final incomeCategory = categoryRows.firstWhere(
        (row) => row.name == 'Gaji' && row.type == TransactionType.income,
      );
      final expense = await transactions.create(
        type: TransactionType.expense,
        categoryId: expenseCategory.id,
        amount: 1000,
        title: 'Migrated expense',
        transactionDate: DateTime(2026, 9, 4),
      );
      expect(
        await history.moveNext().timeout(const Duration(seconds: 5)),
        isTrue,
      );
      expect(
        history.current.any((row) => row.transaction.id == expense.id),
        isTrue,
      );
      expect(
        await dashboard.moveNext().timeout(const Duration(seconds: 5)),
        isTrue,
      );
      expect(dashboard.current.monthlyExpense, baselineExpense + 1000);

      final income = await transactions.create(
        type: TransactionType.income,
        categoryId: incomeCategory.id,
        amount: 2000,
        title: 'Migrated income',
        transactionDate: DateTime(2026, 9, 4),
      );
      expect(
        await history.moveNext().timeout(const Duration(seconds: 5)),
        isTrue,
      );
      expect(
        history.current.any((row) => row.transaction.id == income.id),
        isTrue,
      );
      expect(
        await dashboard.moveNext().timeout(const Duration(seconds: 5)),
        isTrue,
      );
      expect(dashboard.current.monthlyIncome, 2000);

      await transactions.update(
        expense.copyWith(title: 'Migrated expense edited'),
      );
      expect(
        await history.moveNext().timeout(const Duration(seconds: 5)),
        isTrue,
      );
      expect(
        history.current.any(
          (row) => row.transaction.title == 'Migrated expense edited',
        ),
        isTrue,
      );
      await transactions.softDelete(expense.id);
      expect(
        await history.moveNext().timeout(const Duration(seconds: 5)),
        isTrue,
      );
      expect(
        history.current.any((row) => row.transaction.id == expense.id),
        isFalse,
      );
      expect(
        await dashboard.moveNext().timeout(const Duration(seconds: 5)),
        isTrue,
      );
      expect(dashboard.current.monthlyExpense, baselineExpense);
      await history.cancel();
      await dashboard.cancel();

      final assets = AssetRepository(database);
      final activities = AssetTransactionRepository(database);
      final stock = await assets.create(
        symbol: 'BBCA',
        name: 'Bank Central Asia',
        assetType: AssetType.stock,
        pricingMode: AssetPricingMode.api,
      );
      final opening = await activities.createOpeningPosition(
        assetId: stock.id,
        quantity: AssetQuantity.parse('1200'),
        transactionDate: DateTime(2026, 9, 4),
      );
      expect(opening.totalAmount, isNull);
      expect(opening.sourceTransactionId, isNull);
      final assetActivity = AssetActivityService(database);
      final buy = await assetActivity.createBuy(
        assetId: stock.id,
        quantity: AssetQuantity.parse('100'),
        priceAmount: 9000,
        accountId: defaultAccount.id,
        date: DateTime(2026, 9, 4),
      );
      final sell = await assetActivity.createSell(
        assetId: stock.id,
        quantity: AssetQuantity.parse('50'),
        priceAmount: 9200,
        accountId: defaultAccount.id,
        date: DateTime(2026, 9, 4),
      );
      expect(buy.sourceTransactionId, isNotNull);
      expect(sell.sourceTransactionId, isNotNull);
      expect(
        await activities.currentHolding(stock.id),
        AssetQuantity.parse('1250'),
      );

      final gold = await assets.create(
        name: 'Emas',
        assetType: AssetType.gold,
        pricingMode: AssetPricingMode.manual,
      );
      await activities.createOpeningPosition(
        assetId: gold.id,
        quantity: AssetQuantity.parse('5.25'),
        transactionDate: DateTime(2026, 9, 4),
      );
      await AssetPriceRepository(database)
          .setManualPrice(assetId: gold.id, price: 1500000);

      var marketRequests = 0;
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          marketRepositoryProvider.overrideWithValue(
            MarketRepository(
              MarketApiClient(
                baseUrl: 'https://market.example/',
                post: (_, _) async {
                  marketRequests++;
                  return const MarketHttpResponse(200, '''
                  {"quotes":[{"symbol":"BBCA","asset_type":"stock","price":9300,"currency":"IDR"}]}
                ''');
                },
              ),
            ),
          ),
        ],
      );
      expect(identical(container.read(databaseProvider), database), isTrue);
      await container.read(assetHoldingsProvider.future);
      await container.read(dashboardSummaryProvider.future);
      expect(marketRequests, 0);
      await container.read(portfolioMarketQuotesProvider.notifier).refresh();
      expect(marketRequests, 1);
      container.dispose();

      final backup = await BackupService(
        database,
        databasePath: path,
      ).buildBackup(appVersion: '1.3.0', temporaryDirectory: temp);
      await database.close();
      final targetPath = '${temp.path}/restored.sqlite';
      var target = AppDatabase(NativeDatabase(File(targetPath)));
      await target.customSelect('SELECT 1').getSingle();
      await BackupService(
        target,
        databasePath: targetPath,
      ).restoreFromArchive(backup.bytes, temporaryDirectory: temp);
      target = AppDatabase(NativeDatabase(File(targetPath)));
      expect(await target.select(target.assets).get(), hasLength(2));
      expect(await target.select(target.assetTransactions).get(), hasLength(4));
      expect(await target.select(target.assetPrices).get(), hasLength(2));
      await _expectIntegrity(target);
      await target.close();

      database = AppDatabase(NativeDatabase(File(path)));
      expect(await _userVersion(database), 11);
      expect(await database.select(database.accounts).get(), hasLength(1));
      expect(await database.select(database.transactions).get(), hasLength(8));
      expect(
        (await database.select(database.categories).get()).where(
          (row) =>
              row.name == 'Pembelian Aset' &&
              row.type == TransactionType.expense,
        ),
        hasLength(1),
      );
      await _expectIntegrity(database);
      await database.close();
    },
  );

  for (final release in [('v1.1.0', 2), ('v1.2.0', 5000)]) {
    test(
      '${release.$1} schema 8 preserves accounts, transfers, and rows',
      () async {
        final temp = await Directory.systemTemp.createTemp(
          'finote_v8_upgrade_',
        );
        addTearDown(() => temp.delete(recursive: true));
        final path = '${temp.path}/finote.sqlite';
        _createVersion8Database(path, transactionCount: release.$2);

        var database = AppDatabase(NativeDatabase(File(path)));
        await database.customSelect('SELECT 1').getSingle();
        expect(await _userVersion(database), 11);
        await _expectIntegrity(database);
        expect(
          await database.select(database.transactions).get(),
          hasLength(release.$2),
        );
        expect(await database.select(database.accounts).get(), hasLength(2));
        expect(await database.select(database.transfers).get(), hasLength(2));
        expect(await database.select(database.assets).get(), isEmpty);
        expect(
          await database.select(database.assetTransactions).get(),
          isEmpty,
        );
        expect(await database.select(database.assetPrices).get(), isEmpty);
        final accounts = await database.select(database.accounts).get();
        expect(
          accounts.singleWhere((row) => row.id == 20).uuid,
          'account-default-v8',
        );
        expect(
          accounts.singleWhere((row) => row.id == 21).uuid,
          'account-bank-v8',
        );
        final transfers = await database.select(database.transfers).get();
        expect(transfers.map((row) => row.uuid), [
          'transfer-active-v8',
          'transfer-deleted-v8',
        ]);
        expect(transfers.last.deletedAt, isNotNull);
        expect(
          (await database.select(database.settings).getSingle()).value,
          'system',
        );
        expect(
          (await AccountRepository(database).watchSummaries().first).fold<int>(
            0,
            (sum, row) => sum + row.balance,
          ),
          1500000 + release.$2 * 10,
        );

        await database.ensureDefaultAccount();
        await database.ensureDefaultAccount();
        expect(
          (await database.select(database.accounts).get()).where(
            (row) => row.isDefault,
          ),
          hasLength(1),
        );
        final beforeCounts = (
          await database
              .select(database.accounts)
              .get()
              .then((rows) => rows.length),
          await database
              .select(database.transactions)
              .get()
              .then((rows) => rows.length),
          await database
              .select(database.transfers)
              .get()
              .then((rows) => rows.length),
        );
        await database.close();
        database = AppDatabase(NativeDatabase(File(path)));
        expect(await _userVersion(database), 11);
        expect((
          await database
              .select(database.accounts)
              .get()
              .then((rows) => rows.length),
          await database
              .select(database.transactions)
              .get()
              .then((rows) => rows.length),
          await database
              .select(database.transfers)
              .get()
              .then((rows) => rows.length),
        ), beforeCounts);
        await _expectIntegrity(database);
        await database.close();
      },
    );
  }

  test(
    'schema 10 repair adds the historical receipt index idempotently',
    () async {
      final temp = await Directory.systemTemp.createTemp('finote_v10_repair_');
      addTearDown(() => temp.delete(recursive: true));
      final path = '${temp.path}/finote.sqlite';
      var database = AppDatabase(NativeDatabase(File(path)));
      await database.customSelect('SELECT 1').getSingle();
      await database.close();
      final raw = sqlite3.open(path);
      raw.execute('DROP INDEX transactions_receipt_fingerprint');
      raw.userVersion = 10;
      raw.close();

      database = AppDatabase(NativeDatabase(File(path)));
      expect(await _userVersion(database), 11);
      expect(
        await _schemaNames(database),
        contains('transactions_receipt_fingerprint'),
      );
      await database.close();
      database = AppDatabase(NativeDatabase(File(path)));
      expect(
        await _schemaNames(database),
        contains('transactions_receipt_fingerprint'),
      );
      await database.close();
    },
  );

  test('asset enum persistence uses stable database literals', () {
    expect(AssetType.values.map((value) => value.databaseValue), [
      'stock',
      'crypto',
      'mutualFund',
      'gold',
      'other',
    ]);
    expect(AssetPricingMode.values.map((value) => value.databaseValue), [
      'api',
      'manual',
    ]);
    expect(AssetTransactionAction.values.map((value) => value.databaseValue), [
      'openingPosition',
      'buy',
      'sell',
      'adjustment',
    ]);
  });
}

void _createVersion3Database(String path) {
  final db = sqlite3.open(path);
  _createCoreTables(db, includeReceipt: true, includeAccount: false);
  db.execute(
    "INSERT INTO categories VALUES (10, 'cat-purchase-v1', 'Pembelian Aset', 'expense', NULL, 1, 1, NULL)",
  );
  db.execute(
    "INSERT INTO categories VALUES (11, 'cat-sale-v1', 'Penjualan Aset', 'income', NULL, 1, 1, NULL)",
  );
  db.execute(
    "INSERT INTO categories VALUES (12, 'cat-normal-v1', 'Kebutuhan Lama', 'expense', NULL, 1, 1, NULL)",
  );
  db.execute("INSERT INTO settings VALUES ('theme_mode', 'dark', 1)");
  db.execute(
    "INSERT INTO transactions VALUES (100, 'tx-purchase-v1', 'expense', 10, 10000000, 'Pembelian lama', NULL, '2021-07-01', 'manual', NULL, NULL, NULL, 1, 1, NULL)",
  );
  db.execute(
    "INSERT INTO transactions VALUES (101, 'tx-sale-v1', 'income', 11, 4000000, 'Penjualan lama', NULL, '2022-08-31', 'legacy_import', NULL, 'catatan_keuangan_old:fixture', 77, 1, 1, NULL)",
  );
  db.execute(
    "INSERT INTO transactions VALUES (102, 'tx-normal-v1', 'expense', 12, 25000, 'Normal', NULL, '2026-08-30', 'receipt_scan', 'receipt-v1', NULL, NULL, 1, 1, NULL)",
  );
  db.execute(
    "INSERT INTO transactions VALUES (103, 'tx-deleted-v1', 'expense', 12, 700000, 'Deleted', NULL, '2026-08-30', 'recurring', NULL, NULL, NULL, 1, 1, 2)",
  );
  db.userVersion = 3;
  db.close();
}

void _createVersion8Database(String path, {required int transactionCount}) {
  final db = sqlite3.open(path);
  _createAccounts(db);
  _createCoreTables(db, includeReceipt: true, includeAccount: true);
  _createTransfers(db);
  db.execute(
    "INSERT INTO accounts VALUES (20, 'account-default-v8', 'Tunai Utama', 'cash', 1000000, 1, 1, 1, 1)",
  );
  db.execute(
    "INSERT INTO accounts VALUES (21, 'account-bank-v8', 'BCA Lama', 'bank', 500000, 0, 0, 1, 1)",
  );
  db.execute(
    "INSERT INTO categories VALUES (30, 'category-v8', 'Belanja Lama', 'income', NULL, 1, 1, NULL)",
  );
  db.execute("INSERT INTO settings VALUES ('theme_mode', 'system', 1)");
  db.execute('BEGIN');
  final insert = db.prepare(
    'INSERT INTO transactions VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
  );
  try {
    for (var i = 0; i < transactionCount; i++) {
      insert.execute([
        1000 + i,
        'transaction-v8-$i',
        'income',
        i.isEven ? 20 : 21,
        30,
        10,
        'Historical $i',
        null,
        '2026-08-${(i % 28 + 1).toString().padLeft(2, '0')}',
        'manual',
        null,
        null,
        null,
        1,
        1,
        null,
      ]);
    }
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  } finally {
    insert.close();
  }
  db.execute(
    "INSERT INTO transfers VALUES (40, 'transfer-active-v8', 20, 21, 100000, '2026-08-15', NULL, 1, 1, NULL)",
  );
  db.execute(
    "INSERT INTO transfers VALUES (41, 'transfer-deleted-v8', 21, 20, 20000, '2026-08-16', NULL, 1, 1, 2)",
  );
  db.userVersion = 8;
  db.close();
}

void _createCoreTables(
  Database db, {
  required bool includeReceipt,
  required bool includeAccount,
}) {
  db.execute('PRAGMA foreign_keys = ON');
  db.execute('''
    CREATE TABLE categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
      icon TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER
    )
  ''');
  db.execute('''
    CREATE TABLE settings (
      key TEXT NOT NULL PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  db.execute('''
    CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
      ${includeAccount ? 'account_id INTEGER REFERENCES accounts(id) ON DELETE RESTRICT,' : ''}
      category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
      amount INTEGER NOT NULL CHECK (amount > 0),
      title TEXT NOT NULL DEFAULT '',
      note TEXT,
      transaction_date TEXT NOT NULL,
      source TEXT NOT NULL CHECK (source IN ('manual', 'legacy_import', 'receipt_scan', 'recurring')),
      ${includeReceipt ? 'receipt_fingerprint TEXT,' : ''}
      legacy_source TEXT,
      legacy_id INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER,
      CHECK ((legacy_source IS NULL AND legacy_id IS NULL) OR (legacy_source IS NOT NULL AND legacy_id IS NOT NULL))
    )
  ''');
  for (final statement in [
    'CREATE INDEX categories_type ON categories (type)',
    'CREATE INDEX categories_deleted_at ON categories (deleted_at)',
    'CREATE INDEX transactions_date ON transactions (transaction_date)',
    'CREATE INDEX transactions_category_id ON transactions (category_id)',
    'CREATE INDEX transactions_type ON transactions (type)',
    'CREATE INDEX transactions_deleted_at ON transactions (deleted_at)',
    if (includeAccount)
      'CREATE INDEX transactions_account_id ON transactions (account_id)',
    if (includeReceipt) 'CREATE INDEX transactions_receipt_fingerprint ON transactions (receipt_fingerprint)',
    'CREATE UNIQUE INDEX transactions_legacy_source_id ON transactions (legacy_source, legacy_id)',
  ]) {
    db.execute(statement);
  }
}

void _createAccounts(Database db) {
  db.execute('''
    CREATE TABLE accounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      type TEXT NOT NULL CHECK (type IN ('cash', 'bank', 'e_wallet', 'savings')),
      initial_balance INTEGER NOT NULL DEFAULT 0 CHECK (initial_balance >= 0),
      is_active INTEGER NOT NULL DEFAULT 1,
      is_default INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  db.execute('CREATE INDEX accounts_active ON accounts (is_active)');
}

void _createTransfers(Database db) {
  db.execute('''
    CREATE TABLE transfers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      from_account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
      to_account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
      amount INTEGER NOT NULL CHECK (amount > 0),
      transfer_date TEXT NOT NULL,
      note TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER,
      CHECK (from_account_id <> to_account_id)
    )
  ''');
  for (final statement in [
    'CREATE INDEX transfers_from_account_id ON transfers (from_account_id)',
    'CREATE INDEX transfers_to_account_id ON transfers (to_account_id)',
    'CREATE INDEX transfers_date ON transfers (transfer_date)',
    'CREATE INDEX transfers_deleted_at ON transfers (deleted_at)',
  ]) {
    db.execute(statement);
  }
}

Future<int> _userVersion(AppDatabase database) async =>
    (await database.customSelect('PRAGMA user_version').getSingle()).read<int>(
      'user_version',
    );

Future<Set<String>> _schemaNames(AppDatabase database) async =>
    (await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type IN ('table', 'index')",
            )
            .get())
        .map((row) => row.read<String>('name'))
        .toSet();

Future<void> _expectIntegrity(AppDatabase database) async {
  final integrity = await database
      .customSelect('PRAGMA integrity_check')
      .getSingle();
  expect(integrity.read<String>('integrity_check'), 'ok');
  expect(
    await database.customSelect('PRAGMA foreign_key_check').get(),
    isEmpty,
  );
  expect(
    await _schemaNames(database),
    containsAll([
      'assets',
      'asset_transactions',
      'asset_prices',
      'assets_active',
      'assets_type_normalized_symbol',
      'asset_transactions_asset_id',
      'asset_transactions_date',
      'asset_transactions_deleted_at',
      'asset_transactions_source_transaction_id',
      'asset_prices_asset_id',
      'asset_prices_fetched_at',
      'transactions_receipt_fingerprint',
      'transactions_legacy_source_id',
    ]),
  );
}
