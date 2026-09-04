import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/reports/data/report_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'aggregates active investment transactions with report filters',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final account = await AccountRepository(database)
          .create(name: 'Investasi', type: AccountType.bank);
      final otherAccount = await AccountRepository(database)
          .create(name: 'Lainnya', type: AccountType.cash);
      final categories = CategoryRepository(database);
      final purchase = await categories.create(
        name: 'Pembelian Aset',
        type: TransactionType.expense,
      );
      final sale = await categories.create(
        name: 'Penjualan Aset',
        type: TransactionType.income,
      );
      final invalidPurchase = await categories.create(
        name: 'Pembelian Aset',
        type: TransactionType.income,
      );
      final transactions = TransactionRepository(database);
      final date = DateTime(2026, 9, 3);
      final oldDate = DateTime(2025, 9, 3);
      final oldPurchase = await transactions.create(
        type: TransactionType.expense,
        categoryId: purchase.id,
        accountId: account.id,
        amount: 10000000,
        transactionDate: oldDate,
      );
      await transactions.create(
        type: TransactionType.income,
        categoryId: sale.id,
        accountId: account.id,
        amount: 15000000,
        transactionDate: date,
      );
      await transactions.create(
        type: TransactionType.expense,
        categoryId: purchase.id,
        accountId: otherAccount.id,
        amount: 2700000,
        transactionDate: date,
      );
      await transactions.create(
        type: TransactionType.income,
        categoryId: invalidPurchase.id,
        accountId: account.id,
        amount: 999999,
        transactionDate: date,
      );

      final repository = ReportRepository(database);
      final all = ReportRange(
        start: DateTime(2000),
        end: DateTime(2100, 12, 31),
      );
      var summary = await repository.watchInvestmentCashflow(all).first;
      expect(summary.totalPurchases, 12700000);
      expect(summary.totalSales, 15000000);
      expect(summary.netCashInvested, -2300000);
      expect(summary.transactionCount, 3);

      final year = ReportRange(
        start: DateTime(2026),
        end: DateTime(2026, 12, 31),
      );
      summary = await repository
          .watchInvestmentCashflow(year, accountId: account.id)
          .first;
      expect(summary.totalPurchases, 0);
      expect(summary.totalSales, 15000000);
      expect(summary.transactionCount, 1);

      await transactions.softDelete(oldPurchase.id);
      summary = await repository.watchInvestmentCashflow(all).first;
      expect(summary.totalPurchases, 2700000);
      expect(summary.totalSales, 15000000);
      expect(summary.transactionCount, 2);
    },
  );
}
