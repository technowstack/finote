import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/export/data/export_repository.dart';
import 'package:finote/features/export/domain/export_document.dart';
import 'package:finote/features/reports/data/report_repository.dart';
import 'package:finote/features/transactions/data/financial_activity_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/financial_activity.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transfers/data/transfer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'golden dataset reconciles accounts, reports, history, and export',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final accounts = AccountRepository(database);
      final bca = await accounts.create(
        name: 'BCA Utama',
        type: AccountType.bank,
        initialBalance: 5000000,
      );
      final savings = await accounts.create(
        name: 'BCA Tabungan',
        type: AccountType.savings,
        initialBalance: 500000,
      );
      final categories = CategoryRepository(database);
      final salary = await categories.create(
        name: 'Gaji',
        type: TransactionType.income,
      );
      final food = await categories.create(
        name: 'Makan',
        type: TransactionType.expense,
      );
      final admin = await categories.create(
        name: 'Biaya Admin',
        type: TransactionType.expense,
      );
      final transactions = TransactionRepository(database);
      final date = DateTime(2026, 8, 31);
      await transactions.create(
        type: TransactionType.income,
        categoryId: salary.id,
        accountId: bca.id,
        amount: 10000000,
        title: 'Gaji',
        transactionDate: date,
      );
      await transactions.create(
        type: TransactionType.expense,
        categoryId: food.id,
        accountId: bca.id,
        amount: 1000000,
        title: 'Makan',
        transactionDate: date,
      );
      await transactions.create(
        type: TransactionType.expense,
        categoryId: admin.id,
        accountId: savings.id,
        amount: 50000,
        title: 'Biaya Admin',
        transactionDate: date,
      );
      await TransferRepository(database).create(
        fromAccountId: bca.id,
        toAccountId: savings.id,
        amount: 2000000,
        transferDate: date,
      );

      final summaries = await accounts.watchSummaries().first;
      expect(
        summaries.singleWhere((item) => item.account.id == bca.id).balance,
        12000000,
      );
      expect(
        summaries.singleWhere((item) => item.account.id == savings.id).balance,
        2450000,
      );
      expect(
        summaries.fold<int>(0, (total, item) => total + item.balance),
        14450000,
      );

      final range = ReportRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      );
      final report = await ReportRepository(database).watchReport(range).first;
      expect(
        (report.totalIncome, report.totalExpense, report.netBalance),
        (10000000, 1050000, 8950000),
      );
      expect(
        (report.transferSummary.count, report.transferSummary.volume),
        (1, 2000000),
      );
      expect(
        report.topExpenseCategories.map((item) => item.categoryName),
        containsAll(['Makan', 'Biaya Admin']),
      );

      final history = await FinancialActivityRepository(database)
          .watch(const FinancialActivityQuery())
          .first;
      expect(history, hasLength(4));
      expect(
        history.where((item) => item.type == FinancialActivityType.transfer),
        hasLength(1),
      );

      final export = await ExportRepository(
        database,
      ).buildDocument(ExportFilter(startDate: range.start, endDate: range.end));
      expect(
        (export.totalIncome, export.totalExpense, export.balance),
        (report.totalIncome, report.totalExpense, report.netBalance),
      );
      expect(export.totalAssets, 14450000);
      expect(export.transferVolume, 2000000);
      expect(export.transfers, hasLength(1));
    },
  );
}
