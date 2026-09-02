import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/backup/data/backup_service.dart';
import 'package:finote/features/dashboard/data/dashboard_repository.dart';
import 'package:finote/features/export/data/excel_exporter.dart';
import 'package:finote/features/export/data/export_repository.dart';
import 'package:finote/features/export/data/pdf_exporter.dart';
import 'package:finote/features/export/data/text_exporter.dart';
import 'package:finote/features/export/domain/export_document.dart';
import 'package:finote/features/reports/data/report_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/data/financial_activity_repository.dart';
import 'package:finote/features/transactions/domain/transaction_source.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> seedSyntheticDatabase(AppDatabase database, int count) async {
  final accountRepository = AccountRepository(database);
  final defaultAccount = await database.select(database.accounts).getSingle();
  final accounts = [
    defaultAccount,
    await accountRepository.create(
      name: 'BCA Perf',
      type: AccountType.bank,
      initialBalance: 1000000,
    ),
    await accountRepository.create(
      name: 'Cash Perf',
      type: AccountType.cash,
      initialBalance: 500000,
    ),
  ];
  final categoryIds = <int>[];
  for (final entry in [
    ('Makanan', TransactionType.expense),
    ('Transportasi', TransactionType.expense),
    ('Gaji', TransactionType.income),
    ('Bonus', TransactionType.income),
  ]) {
    categoryIds.add(
      await database
          .into(database.categories)
          .insertReturning(
            CategoriesCompanion.insert(name: entry.$1, type: entry.$2),
          )
          .then((category) => category.id),
    );
  }

  await database.batch((batch) {
    batch.insertAll(
      database.transactions,
      List.generate(count, (index) {
        final income = index % 4 >= 2;
        return TransactionsCompanion.insert(
          type: income ? TransactionType.income : TransactionType.expense,
          accountId: Value(accounts[index % accounts.length].id),
          categoryId: categoryIds[index % categoryIds.length],
          amount: 10000 + index,
          title: Value('Transaksi sintetis $index'),
          note: Value('Catatan sintetis $index'),
          transactionDate: DateTime(2022, 1, 1 + index % 1460),
          source: TransactionSource.manual,
          deletedAt: Value(index % 20 == 0 ? DateTime.utc(2026) : null),
        );
      }),
    );
    batch.insertAll(
      database.transfers,
      List.generate(
        count ~/ 2,
        (index) => TransfersCompanion.insert(
          fromAccountId: accounts[index % accounts.length].id,
          toAccountId: accounts[(index + 1) % accounts.length].id,
          amount: 5000 + index,
          transferDate: DateTime(2026, 8, 1 + index % 28),
          note: Value('Transfer sintetis $index'),
        ),
      ),
    );
  });
}

void main() {
  test('10,000 synthetic transactions complete core data paths', () async {
    final tempDir = await Directory.systemTemp.createTemp('finote_perf_');
    final databasePath = '${tempDir.path}/finote.sqlite';
    var database = AppDatabase(NativeDatabase(File(databasePath)));
    addTearDown(() async {
      await database.close();
      await tempDir.delete(recursive: true);
    });

    final seed = Stopwatch()..start();
    await seedSyntheticDatabase(database, 10000);
    seed.stop();

    final repository = TransactionRepository(database);
    final activities = FinancialActivityRepository(database);
    final accountRepository = AccountRepository(database);
    final dashboard = DashboardRepository(database);
    final reports = ReportRepository(database);
    final exports = ExportRepository(database);
    final measure = <String, Duration>{};

    var stopwatch = Stopwatch()..start();
    final history = await repository.watchAll().first;
    stopwatch.stop();
    measure['history'] = stopwatch.elapsed;

    stopwatch = Stopwatch()..start();
    final unifiedHistory = await activities
        .watch(const FinancialActivityQuery())
        .first;
    stopwatch.stop();
    measure['unified-history'] = stopwatch.elapsed;

    stopwatch = Stopwatch()..start();
    final search = await repository
        .watchHistory(
          const TransactionHistoryQuery(search: 'Transaksi sintetis 99'),
        )
        .first;
    stopwatch.stop();
    measure['search'] = stopwatch.elapsed;

    stopwatch = Stopwatch()..start();
    final dashboardSummary = await dashboard
        .watchSummary(DateTime(2026, 8, 30))
        .first;
    stopwatch.stop();
    measure['dashboard'] = stopwatch.elapsed;

    stopwatch = Stopwatch()..start();
    final report = await reports
        .watchReport(
          ReportRange(start: DateTime(2022), end: DateTime(2026, 12, 31)),
        )
        .first;
    stopwatch.stop();
    measure['report'] = stopwatch.elapsed;

    stopwatch = Stopwatch()..start();
    final chartRange = ReportRange(
      start: DateTime(2022),
      end: DateTime(2026, 12, 31),
    );
    final trend = await reports.watchFinancialTrend(chartRange).first;
    final expenseCategories = await reports
        .watchExpenseCategories(chartRange)
        .first;
    stopwatch.stop();
    measure['report-charts'] = stopwatch.elapsed;

    final filteredAccount = await (database.select(
      database.accounts,
    )..where((row) => row.name.equals('BCA Perf'))).getSingle();
    final filteredCategory = await (database.select(
      database.categories,
    )..where((row) => row.name.equals('Makanan'))).getSingle();
    stopwatch = Stopwatch()..start();
    final filteredReport = await reports
        .watchReport(
          chartRange,
          accountId: filteredAccount.id,
          categoryId: filteredCategory.id,
        )
        .first;
    final filteredTrend = await reports
        .watchFinancialTrend(
          chartRange,
          accountId: filteredAccount.id,
          categoryId: filteredCategory.id,
        )
        .first;
    final filteredCategories = await reports
        .watchExpenseCategories(
          chartRange,
          accountId: filteredAccount.id,
          categoryId: filteredCategory.id,
        )
        .first;
    stopwatch.stop();
    measure['filtered-report-charts'] = stopwatch.elapsed;

    stopwatch = Stopwatch()..start();
    final accountSummaries = await accountRepository.watchSummaries().first;
    stopwatch.stop();
    measure['account-balances'] = stopwatch.elapsed;

    stopwatch = Stopwatch()..start();
    final document = await exports.buildDocument(const ExportFilter());
    stopwatch.stop();
    measure['export-data'] = stopwatch.elapsed;

    stopwatch = Stopwatch()..start();
    final text = buildTextExport(document);
    stopwatch.stop();
    measure['text'] = stopwatch.elapsed;

    stopwatch = Stopwatch()..start();
    final excel = buildExcelExport(document);
    stopwatch.stop();
    measure['excel'] = stopwatch.elapsed;

    stopwatch = Stopwatch()..start();
    final pdf = await buildPdfExport(document);
    stopwatch.stop();
    measure['pdf-10000'] = stopwatch.elapsed;

    stopwatch = Stopwatch()..start();
    final backup = await BackupService(
      database,
      databasePath: databasePath,
    ).buildBackup(appVersion: '1.0.0', temporaryDirectory: tempDir);
    stopwatch.stop();
    measure['backup'] = stopwatch.elapsed;

    stopwatch = Stopwatch()..start();
    await BackupService(
      database,
      databasePath: databasePath,
    ).restoreFromArchive(backup.bytes, temporaryDirectory: tempDir);
    database = AppDatabase(NativeDatabase(File(databasePath)));
    final restoredReport = await ReportRepository(database)
        .watchReport(
          ReportRange(start: DateTime(2022), end: DateTime(2026, 12, 31)),
        )
        .first;
    final restoredAccounts = await AccountRepository(database)
        .watchSummaries()
        .first;
    final restoredHistory = await FinancialActivityRepository(database)
        .watch(const FinancialActivityQuery())
        .first;
    final restoredExport = await ExportRepository(database)
        .buildDocument(const ExportFilter());
    stopwatch.stop();
    measure['restore-and-verify'] = stopwatch.elapsed;

    expect(history, hasLength(9500));
    expect(unifiedHistory, hasLength(14500));
    expect(search, isNotEmpty);
    expect(dashboardSummary.totalAssets, isNot(0));
    expect(report.transactionCount, 9500);
    expect(report.transferSummary.count, 5000);
    expect(report.transferSummary.volume, greaterThan(0));
    expect(trend, hasLength(60));
    expect(expenseCategories, hasLength(2));
    expect(
      filteredTrend.fold<int>(0, (sum, point) => sum + point.income),
      filteredReport.totalIncome,
    );
    expect(
      filteredTrend.fold<int>(0, (sum, point) => sum + point.expense),
      filteredReport.totalExpense,
    );
    expect(
      filteredCategories.fold<int>(0, (sum, point) => sum + point.amount),
      filteredReport.totalExpense,
    );
    expect(accountSummaries, hasLength(3));
    expect(accountSummaries.every((summary) => summary.balance != 0), isTrue);
    expect(document.transactions, hasLength(9500));
    expect(document.accounts, hasLength(3));
    expect(document.transfers, hasLength(5000));
    expect(document.transferVolume, greaterThan(0));
    expect(text, isNotEmpty);
    expect(excel, isNotEmpty);
    expect(pdf, isNotEmpty);
    expect(backup.bytes, isNotEmpty);
    expect(restoredReport.transactionCount, 9500);
    expect(restoredReport.transferSummary.count, 5000);
    expect(restoredAccounts, hasLength(3));
    expect(restoredHistory, hasLength(14500));
    expect(restoredExport.transactions, hasLength(9500));
    expect(restoredExport.transfers, hasLength(5000));

    // Deliberately informational: hardware-dependent timings must not gate CI.
    // ignore: avoid_print
    print(
      'PERF 10000 rows: ${measure.entries.map((e) => '${e.key}=${e.value.inMilliseconds}ms').join(', ')}',
    );
  });
}
