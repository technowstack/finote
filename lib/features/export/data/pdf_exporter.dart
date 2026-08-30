import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../transactions/domain/transaction_type.dart';
import '../domain/export_document.dart';

Future<List<int>> buildPdfExport(ExportDocument document) async {
  final pdf = pw.Document();
  final period = _period(document);
  final tables = <pw.Widget>[];
  for (var start = 0; start < document.transactions.length; start += 250) {
    final rows = document.transactions
        .skip(start)
        .take(250)
        .map(_tableRow)
        .toList();
    tables.add(
      pw.TableHelper.fromTextArray(
        headers: const ['Tanggal', 'Tipe', 'Kategori', 'Keterangan', 'Nominal'],
        data: rows,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 8),
        cellAlignments: {4: pw.Alignment.centerRight},
        headerCount: 1,
      ),
    );
  }
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      maxPages: 1000,
      header: (context) => pw.Text('Finote - Laporan Keuangan'),
      build: (context) => [
        pw.Text('Periode: $period'),
        pw.SizedBox(height: 8),
        pw.Text('Pemasukan: ${formatIdr(document.totalIncome)}'),
        pw.Text('Pengeluaran: ${formatIdr(document.totalExpense)}'),
        pw.Text('Saldo: ${formatIdr(document.balance)}'),
        pw.Text('Jumlah transaksi: ${document.transactions.length}'),
        pw.SizedBox(height: 16),
        ...tables,
      ],
    ),
  );
  return pdf.save();
}

List<String> _tableRow(ExportTransaction row) => [
  DateFormat('dd/MM/yyyy').format(row.date),
  row.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran',
  row.category,
  row.title,
  formatIdr(row.amount),
];

String _period(ExportDocument document) {
  final start = document.filter.startDate;
  final end = document.filter.endDate;
  if (start == null && end == null) return 'Semua transaksi';
  return '${start == null ? '-' : formatDate(start)} - ${end == null ? '-' : formatDate(end)}';
}
