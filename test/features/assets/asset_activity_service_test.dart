import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/assets/data/asset_activity_service.dart';
import 'package:finote/features/assets/data/asset_repository.dart';
import 'package:finote/features/assets/data/asset_transaction_repository.dart';
import 'package:finote/features/assets/domain/asset_quantity.dart';
import 'package:finote/features/assets/domain/asset_type.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late AssetActivityService service;
  late AssetRecord asset;
  late AccountRecord account;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    service = AssetActivityService(database);
    await database.ensureDefaultAccount();
    await CategoryRepository(database).initializeDefaults();
    account = (await AccountRepository(database).watchAll().first).first;
    asset = await AssetRepository(database).create(
      symbol: 'BBCA',
      name: 'Bank Central Asia',
      assetType: AssetType.stock,
      pricingMode: AssetPricingMode.api,
    );
  });

  tearDown(() => database.close());

  AssetQuantity shares(int lots) =>
      AssetQuantity.fromScaled(lots * 100 * AssetQuantity.scale);

  test(
    'buy, sell, and adjustment reconcile holdings and cashflow once',
    () async {
      await AssetTransactionRepository(database).createOpeningPosition(
        assetId: asset.id,
        quantity: shares(12),
        transactionDate: DateTime(2026, 9, 1),
      );

      final buy = await service.createBuy(
        assetId: asset.id,
        quantity: shares(3),
        priceAmount: 9000,
        accountId: account.id,
        date: DateTime(2026, 9, 3),
      );
      expect(buy.sourceTransactionId, isNotNull);
      expect(buy.totalAmount, 2700000);

      final sell = await service.createSell(
        assetId: asset.id,
        quantity: shares(2),
        priceAmount: 9000,
        accountId: account.id,
        date: DateTime(2026, 9, 4),
      );
      expect(sell.totalAmount, 1800000);

      await service.createAdjustment(
        assetId: asset.id,
        quantity: shares(1),
        date: DateTime(2026, 9, 5),
      );

      expect(
        await AssetTransactionRepository(database).currentHolding(asset.id),
        shares(14),
      );
      final transactions = await database.select(database.transactions).get();
      expect(transactions, hasLength(2));
      expect(
        transactions.map((row) => row.amount),
        containsAll([2700000, 1800000]),
      );
      expect(
        transactions.map((row) => row.accountId),
        everyElement(account.id),
      );
      final summary = (await AccountRepository(database).watchSummaries().first)
          .singleWhere((item) => item.account.id == account.id);
      expect(summary.balance, -900000);
    },
  );

  test('buy works from zero and sell above holdings is rejected', () async {
    await service.createBuy(
      assetId: asset.id,
      quantity: shares(2),
      priceAmount: 10000,
      accountId: account.id,
      date: DateTime(2026, 9, 3),
    );

    await expectLater(
      service.createSell(
        assetId: asset.id,
        quantity: shares(3),
        priceAmount: 10000,
        accountId: account.id,
        date: DateTime(2026, 9, 4),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await database.select(database.transactions).get(), hasLength(1));
    expect(
      await AssetTransactionRepository(database).currentHolding(asset.id),
      shares(2),
    );
  });

  test(
    'deleting linked cashflow also soft-deletes the asset activity',
    () async {
      final buy = await service.createBuy(
        assetId: asset.id,
        quantity: shares(2),
        priceAmount: 10000,
        accountId: account.id,
        date: DateTime(2026, 9, 3),
      );
      final transactionId = buy.sourceTransactionId!;

      expect(
        await TransactionRepository(database).softDelete(transactionId),
        isTrue,
      );
      expect(
        await AssetTransactionRepository(database).currentHolding(asset.id),
        AssetQuantity.fromScaled(0),
      );
      expect(
        (await database.select(database.assetTransactions).get())
            .single
            .deletedAt,
        isNotNull,
      );
    },
  );

  test('editing a buy updates the same linked cashflow and rejects invalid adjustment', () async {
    final buy = await service.createBuy(
      assetId: asset.id,
      quantity: shares(2),
      priceAmount: 10000,
      accountId: account.id,
      date: DateTime(2026, 9, 3),
    );
    await service.updateBuy(
      activityId: buy.id,
      quantity: shares(3),
      priceAmount: 11000,
      accountId: account.id,
      date: DateTime(2026, 9, 4),
    );

    final activities = await database.select(database.assetTransactions).get();
    final transactions = await database.select(database.transactions).get();
    expect(activities, hasLength(1));
    expect(transactions, hasLength(1));
    expect(activities.single.sourceTransactionId, transactions.single.id);
    expect(transactions.single.amount, 3300000);
    await expectLater(
      service.createAdjustment(
        assetId: asset.id,
        quantity: AssetQuantity.fromScaled(-4 * 100 * AssetQuantity.scale),
        date: DateTime(2026, 9, 5),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('editing preserves an archived linked account', () async {
    final accounts = AccountRepository(database);
    final archived = await accounts.create(
      name: 'Rekening Investasi',
      type: AccountType.bank,
    );
    final buy = await service.createBuy(
      assetId: asset.id,
      quantity: shares(2),
      priceAmount: 10000,
      accountId: archived.id,
      date: DateTime(2026, 9, 3),
    );
    await accounts.archive(archived.id);

    await service.updateBuy(
      activityId: buy.id,
      quantity: shares(3),
      priceAmount: 11000,
      accountId: archived.id,
      date: DateTime(2026, 9, 4),
    );

    final transaction = await TransactionRepository(database)
        .findActiveById(buy.sourceTransactionId!);
    expect(transaction?.accountId, archived.id);
  });

  test('editing or deleting a buy cannot make holdings negative', () async {
    final buy = await service.createBuy(
      assetId: asset.id,
      quantity: shares(2),
      priceAmount: 10000,
      accountId: account.id,
      date: DateTime(2026, 9, 3),
    );
    await service.createSell(
      assetId: asset.id,
      quantity: shares(2),
      priceAmount: 10000,
      accountId: account.id,
      date: DateTime(2026, 9, 4),
    );

    await expectLater(
      service.updateBuy(
        activityId: buy.id,
        quantity: shares(1),
        priceAmount: 10000,
        accountId: account.id,
        date: DateTime(2026, 9, 3),
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(service.delete(buy.id), throwsA(isA<StateError>()));
    expect(
      await AssetTransactionRepository(database).currentHolding(asset.id),
      AssetQuantity.fromScaled(0),
    );
  });

  test('direct transaction edit rejects linked buy cashflow', () async {
    final buy = await service.createBuy(
      assetId: asset.id,
      quantity: shares(2),
      priceAmount: 10000,
      accountId: account.id,
      date: DateTime(2026, 9, 3),
    );
    final transactionId = buy.sourceTransactionId!;
    final transaction = await TransactionRepository(database)
        .findActiveById(transactionId);

    await expectLater(
      TransactionRepository(database).update(transaction!),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('asset activity'),
        ),
      ),
    );
    expect(await database.select(database.transactions).get(), hasLength(1));
    expect(
      (await database.select(database.assetTransactions).get())
          .single
          .deletedAt,
      isNull,
    );
  });
}
