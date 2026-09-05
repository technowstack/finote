import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/core/finance/net_worth.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/assets/data/asset_activity_service.dart';
import 'package:finote/features/assets/data/asset_repository.dart';
import 'package:finote/features/assets/data/asset_transaction_repository.dart';
import 'package:finote/features/assets/domain/asset_quantity.dart';
import 'package:finote/features/assets/domain/asset_transaction_action.dart';
import 'package:finote/features/assets/domain/asset_type.dart';
import 'package:finote/features/backup/data/backup_service.dart';
import 'package:finote/features/backup/domain/backup_manifest.dart';
import 'package:finote/features/backup/domain/restore_error.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/dashboard/data/dashboard_repository.dart';
import 'package:finote/features/market/data/asset_price_repository.dart';
import 'package:finote/features/market/data/market_api_client.dart';
import 'package:finote/features/market/data/market_repository.dart';
import 'package:finote/features/market/data/portfolio_market_quotes_provider.dart';
import 'package:finote/features/market/data/portfolio_valuation_service.dart';
import 'package:finote/features/reports/data/report_repository.dart';
import 'package:finote/features/transactions/data/financial_activity_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'v1.3 backup restores exact Portfolio source data and derivations',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'finote_portfolio_backup_',
      );
      addTearDown(() => temp.delete(recursive: true));
      final path = '${temp.path}/finote.sqlite';
      var database = AppDatabase(NativeDatabase(File(path)));
      await CategoryRepository(database).initializeDefaults();
      final account = (await AccountRepository(
        database,
      ).watchAll().first).singleWhere((item) => item.isDefault);
      final assets = AssetRepository(database);
      final activities = AssetTransactionRepository(database);
      final activityService = AssetActivityService(database);
      final prices = AssetPriceRepository(database);
      final stock = await assets.create(
        symbol: 'BBCA',
        name: 'Bank Central Asia',
        assetType: AssetType.stock,
        pricingMode: AssetPricingMode.manual,
      );
      final crypto = await assets.create(
        symbol: 'BTC',
        name: 'Bitcoin',
        assetType: AssetType.crypto,
        pricingMode: AssetPricingMode.api,
      );
      final gold = await assets.create(
        name: 'Emas',
        assetType: AssetType.gold,
        pricingMode: AssetPricingMode.manual,
        unitLabel: 'gram',
      );
      final mutualFund = await assets.create(
        name: 'Reksa Dana',
        assetType: AssetType.mutualFund,
        pricingMode: AssetPricingMode.manual,
        unitLabel: 'unit',
      );
      final archived = await assets.create(
        name: 'Aset Arsip',
        assetType: AssetType.other,
        pricingMode: AssetPricingMode.manual,
      );
      final stockOpening = await activities.createOpeningPosition(
        assetId: stock.id,
        quantity: AssetQuantity.parse('1200'),
        transactionDate: DateTime(2026, 9, 1),
      );
      final buy = await activityService.createBuy(
        assetId: stock.id,
        quantity: AssetQuantity.parse('300'),
        priceAmount: 9000,
        accountId: account.id,
        date: DateTime(2026, 9, 2),
      );
      final sell = await activityService.createSell(
        assetId: stock.id,
        quantity: AssetQuantity.parse('100'),
        priceAmount: 9000,
        accountId: account.id,
        date: DateTime(2026, 9, 3),
      );
      await activities.createOpeningPosition(
        assetId: crypto.id,
        quantity: AssetQuantity.parse('0.012125'),
        transactionDate: DateTime(2026, 9, 1),
      );
      await activityService.createAdjustment(
        assetId: crypto.id,
        quantity: AssetQuantity.parse('0.000001'),
        date: DateTime(2026, 9, 2),
      );
      await activities.createOpeningPosition(
        assetId: gold.id,
        quantity: AssetQuantity.parse('5.25'),
        transactionDate: DateTime(2026, 9, 1),
      );
      await activities.createOpeningPosition(
        assetId: mutualFund.id,
        quantity: AssetQuantity.parse('123.4567'),
        transactionDate: DateTime(2026, 9, 1),
      );
      await activities.createOpeningPosition(
        assetId: archived.id,
        quantity: AssetQuantity.parse('2'),
        transactionDate: DateTime(2026, 9, 1),
      );
      await assets.archive(archived.id);
      final deleted = await activities.create(
        assetId: gold.id,
        action: AssetTransactionAction.adjustment,
        quantity: AssetQuantity.parse('0.25'),
        transactionDate: DateTime(2026, 9, 2),
      );
      await activities.softDelete(deleted.id);
      await prices.setManualPrice(assetId: stock.id, price: 9000);
      await prices.setManualPrice(assetId: gold.id, price: 1500000);
      await prices.setManualPrice(assetId: mutualFund.id, price: 2000);

      final beforeAssets = await database.select(database.assets).get();
      final beforeActivities = await database
          .select(database.assetTransactions)
          .get();
      final beforeTransactions = await database
          .select(database.transactions)
          .get();
      final beforePrices = await database.select(database.assetPrices).get();
      final service = BackupService(database, databasePath: path);
      final backup = await service.buildBackup(
        appVersion: '1.3.0',
        temporaryDirectory: temp,
      );
      final preview = await service.parseRestoreFile(
        backup.bytes,
        temporaryDirectory: temp,
      );
      expect((preview.assetCount, preview.assetActivityCount), (5, 8));

      await assets.create(
        name: 'Tidak boleh tersisa',
        assetType: AssetType.other,
        pricingMode: AssetPricingMode.manual,
      );
      await service.restoreFromArchive(backup.bytes, temporaryDirectory: temp);
      database = AppDatabase(NativeDatabase(File(path)));
      addTearDown(database.close);

      expect(await database.select(database.assets).get(), beforeAssets);
      expect(
        await database.select(database.assetTransactions).get(),
        beforeActivities,
      );
      expect(
        await database.select(database.transactions).get(),
        beforeTransactions,
      );
      expect(await database.select(database.assetPrices).get(), beforePrices);
      expect(stockOpening.totalAmount, isNull);
      expect(buy.sourceTransactionId, isNotNull);
      expect(sell.sourceTransactionId, isNotNull);
      expect(
        beforeTransactions.map((row) => row.id),
        containsAll([buy.sourceTransactionId, sell.sourceTransactionId]),
      );
      expect(beforeTransactions, hasLength(2));

      final holdings = await AssetTransactionRepository(database)
          .watchAllHoldings()
          .first;
      AssetQuantity holding(int id) =>
          holdings.singleWhere((item) => item.asset.id == id).quantity;
      expect(holding(stock.id), AssetQuantity.parse('1400'));
      expect(holding(crypto.id), AssetQuantity.parse('0.012126'));
      expect(holding(gold.id), AssetQuantity.parse('5.25'));
      expect(holding(mutualFund.id), AssetQuantity.parse('123.4567'));
      expect(holding(archived.id), AssetQuantity.parse('2'));
      expect(
        holdings
            .singleWhere((item) => item.asset.id == archived.id)
            .asset
            .isActive,
        isFalse,
      );

      final activeHoldings = holdings
          .where((item) => item.asset.isActive)
          .toList();
      final restoredPrices = await AssetPriceRepository(database)
          .getForAssets(activeHoldings.map((item) => item.asset.id));
      final portfolio = PortfolioValuationService().buildSnapshot(
        activeHoldings,
        restoredPrices,
      );
      expect(portfolio.totalKnownValue, 20721913);
      expect(portfolio.unvaluedAssetCount, 1);
      final accountSummaries = await AccountRepository(database)
          .watchSummaries()
          .first;
      final netWorth = const NetWorthService().buildSnapshot(
        accountSummaries,
        portfolio,
      );
      expect(netWorth.cashValue, -1800000);
      expect(netWorth.totalKnownValue, 18921913);
      expect(netWorth.isPartial, isTrue);
      final cashflow = await ReportRepository(database)
          .watchInvestmentCashflow(
            ReportRange(start: DateTime(2026), end: DateTime(2026, 12, 31)),
          )
          .first;
      expect(
        (
          cashflow.totalPurchases,
          cashflow.totalSales,
          cashflow.transactionCount,
        ),
        (2700000, 900000, 2),
      );
    },
  );

  test('version 9 Portfolio migrates with an empty price cache', () async {
    final temp = await Directory.systemTemp.createTemp('finote_v9_portfolio_');
    addTearDown(() => temp.delete(recursive: true));
    final sourceFile = File('${temp.path}/source.sqlite');
    final source = AppDatabase(NativeDatabase(sourceFile));
    final asset = await AssetRepository(source).create(
      symbol: 'BTC',
      name: 'Bitcoin',
      assetType: AssetType.crypto,
      pricingMode: AssetPricingMode.api,
    );
    final opening = await AssetTransactionRepository(source)
        .createOpeningPosition(
          assetId: asset.id,
          quantity: AssetQuantity.parse('0.012125'),
          transactionDate: DateTime(2026, 9, 1),
        );
    await source.close();
    final raw = sqlite3.open(sourceFile.path);
    raw.execute('DROP TABLE asset_prices');
    raw.userVersion = 9;
    raw.close();
    final archive = _buildArchive(
      await sourceFile.readAsBytes(),
      databaseVersion: 9,
    );

    final targetPath = '${temp.path}/target.sqlite';
    var target = AppDatabase(NativeDatabase(File(targetPath)));
    final service = BackupService(target, databasePath: targetPath);
    final preview = await service.parseRestoreFile(
      archive,
      temporaryDirectory: temp,
    );
    expect((preview.assetCount, preview.assetActivityCount), (1, 1));
    await service.restoreFromArchive(archive, temporaryDirectory: temp);
    target = AppDatabase(NativeDatabase(File(targetPath)));
    addTearDown(target.close);

    expect((await target.select(target.assets).getSingle()).uuid, asset.uuid);
    expect(
      (await target.select(target.assetTransactions).getSingle()).uuid,
      opening.uuid,
    );
    expect(await target.select(target.assetPrices).get(), isEmpty);
    expect(
      await AssetTransactionRepository(target).currentHolding(asset.id),
      AssetQuantity.parse('0.012125'),
    );
  });

  test('restore rejects a version 10 snapshot without asset prices', () async {
    final temp = await Directory.systemTemp.createTemp('finote_bad_prices_');
    addTearDown(() => temp.delete(recursive: true));
    final sourceFile = File('${temp.path}/source.sqlite');
    final source = AppDatabase(NativeDatabase(sourceFile));
    await source.customSelect('SELECT 1').getSingle();
    await source.close();
    final raw = sqlite3.open(sourceFile.path);
    raw.execute('DROP TABLE asset_prices');
    raw.close();
    final archive = _buildArchive(
      await sourceFile.readAsBytes(),
      databaseVersion: 10,
    );
    final current = AppDatabase(NativeDatabase.memory());
    addTearDown(current.close);

    await expectLater(
      BackupService(current)
          .parseRestoreFile(archive, temporaryDirectory: temp),
      throwsA(isA<RestoreError>()),
    );
  });

  test(
    'restore rejects missing identity index and unknown enum values',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'finote_compatibility_validation_',
      );
      addTearDown(() => temp.delete(recursive: true));
      final sourcePath = '${temp.path}/source.sqlite';
      final source = AppDatabase(NativeDatabase(File(sourcePath)));
      final category = await CategoryRepository(source)
          .create(name: 'Belanja', type: TransactionType.expense);
      await TransactionRepository(source).create(
        type: TransactionType.expense,
        categoryId: category.id,
        amount: 1000,
        transactionDate: DateTime(2026, 9, 4),
      );
      final backup = await BackupService(
        source,
        databasePath: sourcePath,
      ).buildBackup(appVersion: '1.3.0', temporaryDirectory: temp);
      await source.close();
      final snapshot = Uint8List.fromList(
        ZipDecoder()
                .decodeBytes(backup.bytes)
                .findFile('database.sqlite')!
                .content
            as List<int>,
      );
      final current = AppDatabase(NativeDatabase.memory());
      addTearDown(current.close);

      for (final mutation in [
        'DROP INDEX transactions_legacy_source_id',
        "PRAGMA ignore_check_constraints = ON; UPDATE transactions SET source = 'unknown_source'",
      ]) {
        final file = File('${temp.path}/${mutation.hashCode}.sqlite');
        await file.writeAsBytes(snapshot, flush: true);
        final raw = sqlite3.open(file.path);
        raw.execute(mutation);
        raw.close();

        await expectLater(
          BackupService(current).parseRestoreFile(
            _buildArchive(
              await file.readAsBytes(),
              databaseVersion: current.schemaVersion,
            ),
            temporaryDirectory: temp,
          ),
          throwsA(isA<RestoreError>()),
        );
      }
    },
  );

  test('restored providers stay local and react to transaction CRUD', () async {
    final temp = await Directory.systemTemp.createTemp(
      'finote_restore_reactive_',
    );
    addTearDown(() => temp.delete(recursive: true));
    final sourcePath = '${temp.path}/source.sqlite';
    final source = AppDatabase(NativeDatabase(File(sourcePath)));
    await CategoryRepository(source).initializeDefaults();
    final asset = await AssetRepository(source).create(
      name: 'Emas',
      assetType: AssetType.gold,
      pricingMode: AssetPricingMode.manual,
    );
    await AssetTransactionRepository(source).createOpeningPosition(
      assetId: asset.id,
      quantity: AssetQuantity.parse('5.25'),
      transactionDate: DateTime.now(),
    );
    await AssetPriceRepository(source)
        .setManualPrice(assetId: asset.id, price: 1500000);
    final backup = await BackupService(
      source,
      databasePath: sourcePath,
    ).buildBackup(appVersion: '1.3.0', temporaryDirectory: temp);
    await source.close();

    var marketRequests = 0;
    final targetPath = '${temp.path}/target.sqlite';
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) {
          final database = AppDatabase(NativeDatabase(File(targetPath)));
          ref.onDispose(database.close);
          return database;
        }),
        marketRepositoryProvider.overrideWithValue(
          MarketRepository(
            MarketApiClient(
              baseUrl: 'https://market.example/',
              post: (_, _) async {
                marketRequests++;
                throw StateError('Restore must not request market prices');
              },
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(databaseProvider).customSelect('SELECT 1').getSingle();
    container.invalidate(portfolioMarketQuotesProvider);
    await BackupService(
      container.read(databaseProvider),
      databasePath: targetPath,
    ).restoreFromArchive(backup.bytes, temporaryDirectory: temp);
    container.invalidate(databaseProvider);
    container.invalidate(portfolioMarketQuotesProvider);

    final holdings = await container.read(assetHoldingsProvider.future);
    final localPrices = await container.read(activeAssetPricesProvider.future);
    await container.read(accountSummariesProvider.future);
    expect(holdings.single.quantity, AssetQuantity.parse('5.25'));
    expect(localPrices.values.single.price, 1500000);
    expect(
      container.read(portfolioValuationProvider).requireValue.totalKnownValue,
      7875000,
    );
    expect(
      container.read(netWorthProvider).requireValue.totalKnownValue,
      7875000,
    );
    expect(marketRequests, 0);

    const filter = FinancialActivityQuery();
    final historyCreated = Completer<void>();
    final historyEdited = Completer<void>();
    final dashboardCreated = Completer<void>();
    final historySubscription = container.listen(
      financialActivityProvider(filter),
      (_, next) {
        final rows = next.valueOrNull;
        if (rows?.any((row) => row.title == 'Sesudah restore') == true &&
            !historyCreated.isCompleted) {
          historyCreated.complete();
        }
        if (rows?.any((row) => row.title == 'Sesudah edit') == true &&
            !historyEdited.isCompleted) {
          historyEdited.complete();
        }
      },
      fireImmediately: true,
    );
    final dashboardSubscription = container.listen(dashboardSummaryProvider, (
      _,
      next,
    ) {
      if (next.valueOrNull?.monthlyExpense == 1000 &&
          !dashboardCreated.isCompleted) {
        dashboardCreated.complete();
      }
    }, fireImmediately: true);
    addTearDown(historySubscription.close);
    addTearDown(dashboardSubscription.close);
    await container.read(financialActivityProvider(filter).future);
    await container.read(dashboardSummaryProvider.future);
    final database = container.read(databaseProvider);
    final category = (await database.select(database.categories).get())
        .firstWhere((row) => row.type == TransactionType.expense);
    final account = (await database.select(database.accounts).get())
        .singleWhere((row) => row.isDefault);
    final transaction = await container
        .read(transactionRepositoryProvider)
        .create(
          type: TransactionType.expense,
          accountId: account.id,
          categoryId: category.id,
          amount: 1000,
          title: 'Sesudah restore',
          transactionDate: DateTime.now(),
        );
    await Future.wait([
      historyCreated.future.timeout(const Duration(seconds: 5)),
      dashboardCreated.future.timeout(const Duration(seconds: 5)),
    ]);
    await container
        .read(transactionRepositoryProvider)
        .update(transaction.copyWith(title: 'Sesudah edit'));
    await historyEdited.future.timeout(const Duration(seconds: 5));
    for (var i = 0; i < 3; i++) {
      container.invalidate(dashboardSummaryProvider);
      await container.read(dashboardSummaryProvider.future);
    }
    expect(marketRequests, 0);
  });
}

Uint8List _buildArchive(Uint8List database, {required int databaseVersion}) {
  final manifest = BackupManifest.create(
    databaseVersion: databaseVersion,
    createdAt: DateTime.utc(2026, 9, 4),
    appVersion: databaseVersion == 9 ? '1.2.0' : '1.3.0',
  );
  final archive = Archive()
    ..addFile(ArchiveFile('database.sqlite', database.length, database))
    ..addFile(
      ArchiveFile.string('manifest.json', jsonEncode(manifest.toJson())),
    );
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
