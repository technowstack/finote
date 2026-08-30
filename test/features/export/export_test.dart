import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:finote/core/database/app_database.dart';
import 'package:finote/features/categories/data/category_repository.dart';
import 'package:finote/features/export/data/excel_exporter.dart';
import 'package:finote/features/export/data/export_repository.dart';
import 'package:finote/features/export/data/pdf_exporter.dart';
import 'package:finote/features/export/data/text_exporter.dart';
import 'package:finote/features/export/domain/export_document.dart';
import 'package:finote/features/reports/data/report_repository.dart';
import 'package:finote/features/transactions/data/transaction_repository.dart';
import 'package:finote/features/transactions/domain/transaction_type.dart';
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
    expect(buildTextExport(document), contains('Transaksi   : 0'));
    expect((await buildPdfExport(document)).take(5), [37, 80, 68, 70, 45]);
  });

  test(
    'generators produce readable text, PDF, and two-sheet Excel ZIP',
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

      final pdf = await buildPdfExport(document);
      expect(pdf.take(5), [37, 80, 68, 70, 45]);

      final workbook = ZipDecoder()
          .decodeBytes(buildExcelExport(document))
          .files;
      expect(
        workbook.map((file) => file.name),
        containsAll(['xl/worksheets/sheet1.xml', 'xl/worksheets/sheet2.xml']),
      );
      final sheet = utf8.decode(
        workbook
                .singleWhere((file) => file.name == 'xl/worksheets/sheet2.xml')
                .content
            as List<int>,
      );
      expect(sheet, contains('<v>1000000</v>'));
      expect(sheet, contains('Makan Siang'));
    },
  );

  test('builds a synthetic 10,000-row document', () async {
    final rows = [
      for (var i = 0; i < 10000; i++)
        ExportTransaction(
          date: DateTime(2026, 8, (i % 28) + 1),
          type: i.isEven ? TransactionType.income : TransactionType.expense,
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
    );
    expect(buildExcelExport(document), isNotEmpty);
    expect(buildTextExport(document).length, greaterThan(10000));
  });
}
