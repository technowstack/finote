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
  final transactionTables = <pw.Widget>[];
  for (var start = 0; start < document.transactions.length; start += 250) {
    final rows = document.transactions
        .skip(start)
        .take(250)
        .map(_tableRow)
        .toList();
    transactionTables.add(
      pw.TableHelper.fromTextArray(
        headers: const [
          'Tanggal',
          'Tipe',
          'Akun',
          'Kategori',
          'Keterangan',
          'Nominal',
        ],
        data: rows,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 7),
        cellAlignments: {5: pw.Alignment.centerRight},
        headerCount: 1,
      ),
    );
  }
  final accountTables = <pw.Widget>[];
  for (var start = 0; start < document.accounts.length; start += 250) {
    accountTables.add(
      pw.TableHelper.fromTextArray(
        headers: const [
          'Akun',
          'Jenis',
          'Saldo Awal',
          'Saldo Saat Ini',
          'Status',
        ],
        data: document.accounts.skip(start).take(250).map(_accountRow).toList(),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 8),
        cellAlignments: {
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
        },
        headerCount: 1,
      ),
    );
  }
  final transferTables = <pw.Widget>[];
  for (var start = 0; start < document.transfers.length; start += 250) {
    transferTables.add(
      pw.TableHelper.fromTextArray(
        headers: const ['Tanggal', 'Dari', 'Ke', 'Catatan', 'Nominal'],
        data: document.transfers
            .skip(start)
            .take(250)
            .map(_transferRow)
            .toList(),
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
        pw.Text('Saldo periode: ${formatIdr(document.balance)}'),
        pw.Text('Jumlah transaksi: ${document.transactions.length}'),
        pw.SizedBox(height: 16),
        pw.Text(
          'Saldo Akun Saat Ini',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('Posisi saat ini, tidak dibatasi periode laporan.'),
        pw.SizedBox(height: 6),
        if (accountTables.isEmpty)
          pw.Text('Tidak ada akun.')
        else
          ...accountTables,
        pw.SizedBox(height: 6),
        pw.Text('Kas & dompet saat ini: ${formatIdr(document.totalAssets)}'),
        pw.SizedBox(height: 16),
        pw.Text(
          'Transfer Antar Akun',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          '${document.transfers.length} transfer, volume ${formatIdr(document.transferVolume)}. Tidak memengaruhi pemasukan atau pengeluaran.',
        ),
        pw.SizedBox(height: 6),
        if (transferTables.isEmpty)
          pw.Text('Tidak ada transfer.')
        else
          ...transferTables,
        pw.SizedBox(height: 16),
        pw.Text(
          'Transaksi',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (transactionTables.isEmpty)
          pw.Text('Tidak ada transaksi.')
        else
          ...transactionTables,
      ],
    ),
  );
  return pdf.save();
}

List<String> _tableRow(ExportTransaction row) => [
  DateFormat('dd/MM/yyyy').format(row.date),
  row.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran',
  row.account,
  row.category,
  [row.title, row.note].where((value) => value?.isNotEmpty == true).join('\n'),
  formatIdr(row.amount),
];

List<String> _accountRow(ExportAccount row) => [
  row.name,
  row.type,
  formatIdr(row.initialBalance),
  formatIdr(row.balance),
  row.isActive ? 'Aktif' : 'Diarsipkan',
];

List<String> _transferRow(ExportTransfer row) => [
  DateFormat('dd/MM/yyyy').format(row.date),
  row.fromAccount,
  row.toAccount,
  row.note ?? '',
  formatIdr(row.amount),
];

String _period(ExportDocument document) {
  final start = document.filter.startDate;
  final end = document.filter.endDate;
  if (start == null && end == null) return 'Semua transaksi';
  return '${start == null ? '-' : formatDate(start)} - ${end == null ? '-' : formatDate(end)}';
}
