import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/core/finance/net_worth.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/assets/data/asset_activity_service.dart';
import 'package:finote/features/assets/data/asset_repository.dart';
import 'package:finote/features/assets/data/asset_transaction_repository.dart';
import 'package:finote/features/assets/domain/asset_quantity.dart';
import 'package:finote/features/assets/domain/asset_type.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/market/data/asset_price_repository.dart';
import 'package:finote/features/market/data/portfolio_valuation_service.dart';
import 'package:finote/features/market/domain/portfolio_valuation.dart';
import 'package:finote/features/transfers/data/transfer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('composes account balances and known portfolio value', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final account = await AccountRepository(
      database,
    ).create(name: 'Tunai', type: AccountType.cash, initialBalance: 25000000);
    final accounts = await AccountRepository(database).watchSummaries().first;
    final portfolio = PortfolioSnapshot(
      valuations: [_valuation(1, 30000000), _valuation(2, 25400000)],
      groups: const {},
      holdingAssetCount: 2,
      valuedAssetCount: 2,
      unvaluedAssetCount: 0,
      integrityIssueCount: 0,
    );
    final snapshot = const NetWorthService().buildSnapshot(accounts, portfolio);

    expect(account.initialBalance, 25000000);
    expect(snapshot.cashValue, 25000000);
    expect(snapshot.portfolioKnownValue, 55400000);
    expect(snapshot.totalKnownValue, 80400000);
    expect(snapshot.isComplete, isTrue);
  });

  test('marks net worth partial when portfolio has missing prices', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await AccountRepository(
      database,
    ).create(name: 'Tunai', type: AccountType.cash, initialBalance: 25000000);
    final accounts = await AccountRepository(database).watchSummaries().first;
    final portfolio = PortfolioSnapshot(
      valuations: [_valuation(1, 40000000)],
      groups: const {},
      holdingAssetCount: 2,
      valuedAssetCount: 1,
      unvaluedAssetCount: 1,
      integrityIssueCount: 0,
    );
    final snapshot = const NetWorthService().buildSnapshot(accounts, portfolio);

    expect(snapshot.totalKnownValue, 65000000);
    expect(snapshot.isPartial, isTrue);
    expect(snapshot.unvaluedAssetCount, 1);
  });

  test(
    'cash-only Net Worth is complete while unvalued holdings are partial',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await AccountRepository(
        database,
      ).create(name: 'Tunai', type: AccountType.cash, initialBalance: 25000000);
      final accounts = await AccountRepository(database).watchSummaries().first;
      final service = const NetWorthService();

      final cashOnly = service.buildSnapshot(
        accounts,
        const PortfolioSnapshot(
          valuations: [],
          groups: {},
          holdingAssetCount: 0,
          valuedAssetCount: 0,
          unvaluedAssetCount: 0,
          integrityIssueCount: 0,
        ),
      );
      expect(cashOnly.totalKnownValue, 25000000);
      expect(cashOnly.isComplete, isTrue);

      final unvalued = service.buildSnapshot(
        accounts,
        const PortfolioSnapshot(
          valuations: [],
          groups: {},
          holdingAssetCount: 1,
          valuedAssetCount: 0,
          unvaluedAssetCount: 1,
          integrityIssueCount: 0,
        ),
      );
      expect(unvalued.totalKnownValue, 25000000);
      expect(unvalued.portfolioKnownValue, isNull);
      expect(unvalued.isPartial, isTrue);
    },
  );

  test(
    'buy and transfer affect Net Worth only through derived components',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final accounts = AccountRepository(database);
      final source = await accounts.create(
        name: 'BCA',
        type: AccountType.bank,
        initialBalance: 10000000,
      );
      final destination = await accounts.create(
        name: 'Tabungan',
        type: AccountType.savings,
      );
      await CategoryRepository(database).initializeDefaults();
      final asset = await AssetRepository(database).create(
        name: 'Bitcoin',
        symbol: 'BTC',
        assetType: AssetType.crypto,
        pricingMode: AssetPricingMode.manual,
      );
      await AssetActivityService(database).createBuy(
        assetId: asset.id,
        quantity: AssetQuantity.parse('1'),
        priceAmount: 2000000,
        accountId: source.id,
        date: DateTime(2026, 9, 4),
      );
      await AssetPriceRepository(database)
          .setManualPrice(assetId: asset.id, price: 2000000);

      final holdings = await AssetTransactionRepository(database)
          .watchHoldings()
          .first;
      final prices = await AssetPriceRepository(database).watchActive().first;
      PortfolioSnapshot portfolio = PortfolioValuationService().buildSnapshot(
        holdings,
        prices,
      );
      var snapshot = const NetWorthService().buildSnapshot(
        await accounts.watchSummaries().first,
        portfolio,
      );
      expect(snapshot.totalKnownValue, 10000000);

      await TransferRepository(database).create(
        fromAccountId: source.id,
        toAccountId: destination.id,
        amount: 2000000,
        transferDate: DateTime(2026, 9, 4),
      );
      portfolio = PortfolioValuationService().buildSnapshot(holdings, prices);
      snapshot = const NetWorthService().buildSnapshot(
        await accounts.watchSummaries().first,
        portfolio,
      );
      expect(snapshot.cashValue, 8000000);
      expect(snapshot.totalKnownValue, 10000000);
    },
  );
}

AssetValuation _valuation(int assetId, int value) => AssetValuation(
  assetId: assetId,
  quantity: AssetQuantity.fromScaled(100000000),
  unitPrice: value,
  currentValue: value,
  pricingSource: ValuationPriceSource.manual,
  priceUpdatedAt: null,
  isBackendStale: false,
  hasPrice: true,
);
