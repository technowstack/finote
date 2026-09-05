import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/accounts/data/account_repository.dart';
import 'package:finote/features/accounts/domain/account_type.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/export/data/excel_exporter.dart';
import 'package:finote/features/export/data/export_repository.dart';
import 'package:finote/features/export/data/pdf_exporter.dart';
import 'package:finote/features/export/data/text_exporter.dart';
import 'package:finote/features/export/domain/export_document.dart';
import 'package:finote/features/reports/data/report_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
import 'package:finote/features/transfers/data/transfer_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late AppDatabase database;
  late CategoryRepository categories;
  late TransactionRepository transactions;
  late ExportRepository exports;
  late ReportRepository reports;
  late CategoryRecord incomeCategory;
  late CategoryRecord expenseCategory;

  setUpAll(() => initializeDateFormatting('id_ID'));

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    categories = CategoryRepository(database);
    transactions = TransactionRepository(database);
    exports = ExportRepository(database);
    reports = ReportRepository(database);
    incomeCategory = await categories.create(
      name: 'Gaji',
      type: TransactionType.income,
    );
    expenseCategory = await categories.create(
      name: 'Makanan',
      type: TransactionType.expense,
    );
  });

  tearDown(() => database.close());

  Future<void> seed() async {
    await transactions.create(
      type: TransactionType.income,
      categoryId: incomeCategory.id,
      amount: 1000000,
      title: 'Gaji Agustus',
      transactionDate: DateTime(2026, 8, 1),
    );
    await transactions.create(
      type: TransactionType.expense,
      categoryId: expenseCategory.id,
      amount: 25000,
      title: 'Makan Siang',
      note: 'Kantor',
      transactionDate: DateTime(2026, 8, 2),
    );
    final deleted = await transactions.create(
      type: TransactionType.expense,
      categoryId: expenseCategory.id,
      amount: 999999,
      title: 'Jangan Ekspor',
      transactionDate: DateTime(2026, 8, 3),
    );
    await transactions.softDelete(deleted.id);
  }

  test(
    'uses range, type filter, soft-delete exclusion, and shared totals',
    () async {
      await seed();
      final document = await exports.buildDocument(
        ExportFilter(
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
        ),
      );
      expect(document.transactions, hasLength(2));
      expect(document.totalIncome, 1000000);
      expect(document.totalExpense, 25000);
      expect(document.balance, 975000);
      expect(document.transactions.map((row) => row.account), {'Tunai'});
      final report = await reports
          .watchReport(
            ReportRange(
              start: DateTime(2026, 8, 1),
              end: DateTime(2026, 8, 31),
            ),
          )
          .first;
      expect(
        (document.totalIncome, document.totalExpense, document.balance),
        (report.totalIncome, report.totalExpense, report.netBalance),
      );

      final incomeOnly = await exports.buildDocument(
        ExportFilter(
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
          type: TransactionType.income,
        ),
      );
      expect(incomeOnly.transactions, hasLength(1));
      expect(incomeOnly.totalIncome, 1000000);
      expect(incomeOnly.totalExpense, 0);
      expect(incomeOnly.transfers, isEmpty);
    },
  );

  test('empty export has zero totals and valid output', () async {
    final document = await exports.buildDocument(
      ExportFilter(
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      ),
    );
    expect(document.transactions, isEmpty);
    expect(document.balance, 0);
    expect(document.transfers, isEmpty);
    expect(buildTextExport(document), contains('Transaksi   : 0'));
    expect((await buildPdfExport(document)).take(5), [37, 80, 68, 70, 45]);
  });

  test(
    'generators produce readable text, PDF, and four-sheet Excel ZIP',
    () async {
      await seed();
      final document = await exports.buildDocument(
        ExportFilter(
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 31),
        ),
      );
      final text = buildTextExport(document);
      expect(text, contains('Makan Siang'));
      expect(text, contains('Rp1.000.000'));
      expect(text, contains('SALDO AKUN SAAT INI'));
      expect(text, contains('Tidak ada transfer.'));

      final pdf = await buildPdfExport(document);
      expect(pdf.take(5), [37, 80, 68, 70, 45]);

      final workbook = ZipDecoder()
          .decodeBytes(buildExcelExport(document))
          .files;
      expect(
        workbook.map((file) => file.name),
        containsAll([
          'xl/worksheets/sheet1.xml',
          'xl/worksheets/sheet2.xml',
          'xl/worksheets/sheet3.xml',
          'xl/worksheets/sheet4.xml',
        ]),
      );
      final sheet = utf8.decode(
        workbook
                .singleWhere((file) => file.name == 'xl/worksheets/sheet2.xml')
                .content
            as List<int>,
      );
      expect(sheet, contains('<v>1000000</v>'));
      expect(sheet, contains('Makan Siang'));
      expect(sheet, contains('Akun'));
      expect(sheet, contains('Tunai'));
    },
  );

  test(
    'exports account summaries and transfers without changing net',
    () async {
      final accounts = AccountRepository(database);
      final source = await accounts.create(
        name: 'BCA Utama',
        type: AccountType.bank,
        initialBalance: 5000000,
      );
      final destination = await accounts.create(
        name: 'BCA Tabungan',
        type: AccountType.savings,
      );
      await transactions.create(
        type: TransactionType.income,
        categoryId: incomeCategory.id,
        accountId: source.id,
        amount: 10000000,
        title: 'Gaji Agustus',
        transactionDate: DateTime(2026, 8, 31),
      );
      await transactions.create(
        type: TransactionType.expense,
        categoryId: expenseCategory.id,
        accountId: source.id,
        amount: 1000000,
        title: 'Makan',
        transactionDate: DateTime(2026, 8, 31),
      );
      final transfers = TransferRepository(database);
      await transfers.create(
        fromAccountId: source.id,
        toAccountId: destination.id,
        amount: 2000000,
        transferDate: DateTime(2026, 8, 31),
        note: 'Tabungan bulanan',
      );
      final deleted = await transfers.create(
        fromAccountId: source.id,
        toAccountId: destination.id,
        amount: 9000000,
        transferDate: DateTime(2026, 8, 31),
      );
      await transfers.softDelete(deleted.id);
      final filter = ExportFilter(
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
      );

      final document = await exports.buildDocument(filter);
      expect(document.totalIncome, 10000000);
      expect(document.totalExpense, 1000000);
      expect(document.balance, 9000000);
      expect(document.transactions.map((row) => row.account), {'BCA Utama'});
      expect(document.transfers, hasLength(1));
      expect(document.transferVolume, 2000000);
      expect(document.transfers.single.fromAccount, 'BCA Utama');
      expect(document.transfers.single.toAccount, 'BCA Tabungan');
      expect(document.accounts, hasLength(3));
      expect(
        document.accounts.singleWhere((row) => row.name == 'BCA Utama').balance,
        12000000,
      );
      expect(
        document.accounts
            .singleWhere((row) => row.name == 'BCA Tabungan')
            .balance,
        2000000,
      );
      expect(document.totalAssets, 14000000);

      final categoryOnly = await exports.buildDocument(
        ExportFilter(
          startDate: filter.startDate,
          endDate: filter.endDate,
          categoryId: incomeCategory.id,
        ),
      );
      expect(categoryOnly.transactions, hasLength(1));
      expect(categoryOnly.transfers, isEmpty);
      final september = await exports.buildDocument(
        ExportFilter(
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 30),
        ),
      );
      expect(september.transactions, isEmpty);
      expect(september.transfers, isEmpty);
      expect(september.totalAssets, 14000000);

      final report = await reports
          .watchReport(
            ReportRange(start: filter.startDate!, end: filter.endDate!),
          )
          .first;
      expect(
        (document.totalIncome, document.totalExpense, document.balance),
        (report.totalIncome, report.totalExpense, report.netBalance),
      );
      expect(document.transfers.length, report.transferSummary.count);
      expect(document.transferVolume, report.transferSummary.volume);

      final text = buildTextExport(document);
      expect(text, contains('Kas & dompet saat ini: Rp14.000.000'));
      expect(text, contains('BCA Utama -> BCA Tabungan'));
      expect(text, contains('Transfer Antar Akun'.toUpperCase()));
      expect(text, contains('Pemasukan | BCA Utama | Gaji'));
      final pdf = await buildPdfExport(document);
      expect(pdf.take(5), [37, 80, 68, 70, 45]);

      final workbook = ZipDecoder()
          .decodeBytes(buildExcelExport(document))
          .files;
      final summarySheet = _sheet(workbook, 1);
      final transactionSheet = _sheet(workbook, 2);
      final accountSheet = _sheet(workbook, 3);
      final transferSheet = _sheet(workbook, 4);
      expect(summarySheet, contains('Kas &amp; dompet saat ini'));
      expect(summarySheet, contains('<v>14000000</v>'));
      expect(transactionSheet, contains('BCA Utama'));
      expect(accountSheet, contains('<v>12000000</v>'));
      expect(transferSheet, contains('<v>2000000</v>'));
      expect(RegExp('<row>').allMatches(transferSheet), hasLength(2));

      await accounts.archive(source.id);
      final archivedDocument = await exports.buildDocument(filter);
      expect(archivedDocument.transactions.first.account, 'BCA Utama');
      expect(archivedDocument.transfers.single.fromAccount, 'BCA Utama');
      expect(
        archivedDocument.accounts
            .singleWhere((row) => row.name == 'BCA Utama')
            .isActive,
        isFalse,
      );
    },
  );

  test('missing account relations use a safe export fallback', () async {
    final accounts = AccountRepository(database);
    final missing = await accounts.create(
      name: 'Akan Dihapus',
      type: AccountType.bank,
    );
    final destination = await accounts.create(
      name: 'Tujuan',
      type: AccountType.cash,
    );
    await transactions.create(
      type: TransactionType.income,
      categoryId: incomeCategory.id,
      accountId: missing.id,
      amount: 1000,
      transactionDate: DateTime(2026, 8, 1),
    );
    await TransferRepository(database).create(
      fromAccountId: missing.id,
      toAccountId: destination.id,
      amount: 500,
      transferDate: DateTime(2026, 8, 1),
    );
    await database.customStatement('PRAGMA foreign_keys = OFF');
    await (database.delete(
      database.accounts,
    )..where((row) => row.id.equals(missing.id))).go();

    final document = await exports.buildDocument(
      ExportFilter(
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
      ),
    );
    expect(document.transactions.single.account, 'Akun tidak tersedia');
    expect(document.transfers.single.fromAccount, 'Akun tidak tersedia');
    expect(document.transfers.single.toAccount, 'Tujuan');
  });

  test('builds a synthetic 10,000-row document', () async {
    final rows = [
      for (var i = 0; i < 10000; i++)
        ExportTransaction(
          date: DateTime(2026, 8, (i % 28) + 1),
          type: i.isEven ? TransactionType.income : TransactionType.expense,
          account: 'Akun Sintetis',
          category: 'Sintetis',
          title: 'Transaksi $i',
          note: null,
          amount: 1000 + i,
        ),
    ];
    final document = ExportDocument(
      filter: const ExportFilter(),
      generatedAt: DateTime(2026, 8, 30),
      transactions: rows,
      accounts: const [],
      transfers: const [],
    );
    expect(buildExcelExport(document), isNotEmpty);
    expect(buildTextExport(document).length, greaterThan(10000));
  });
}

String _sheet(List<ArchiveFile> workbook, int index) => utf8.decode(
  workbook
          .singleWhere((file) => file.name == 'xl/worksheets/sheet$index.xml')
          .content
      as List<int>,
);
