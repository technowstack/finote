import 'package:intl/intl.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../transactions/domain/transaction_type.dart';
import '../domain/export_document.dart';

String buildTextExport(ExportDocument document) {
  final start = document.filter.startDate;
  final end = document.filter.endDate;
  final period = start == null && end == null
      ? 'Semua transaksi'
      : '${start == null ? '-' : formatDate(start)} - ${end == null ? '-' : formatDate(end)}';
  final buffer = StringBuffer()
    ..writeln('FINOTE')
    ..writeln('LAPORAN KEUANGAN')
    ..writeln()
    ..writeln('Periode:')
    ..writeln(period)
    ..writeln()
    ..writeln('RINGKASAN')
    ..writeln('Pemasukan   : ${formatIdr(document.totalIncome)}')
    ..writeln('Pengeluaran : ${formatIdr(document.totalExpense)}')
    ..writeln('Saldo       : ${formatIdr(document.balance)}')
    ..writeln('Transaksi   : ${document.transactions.length}')
    ..writeln()
    ..writeln('TRANSAKSI');
  for (final row in document.transactions) {
    buffer
      ..writeln()
      ..writeln(DateFormat('dd/MM/yyyy').format(row.date))
      ..writeln(
        '${row.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran'} | ${row.category}',
      )
      ..writeln(row.title.isEmpty ? '-' : row.title)
      ..writeln(formatIdr(row.amount));
    if (row.note?.isNotEmpty == true) buffer.writeln(row.note);
  }
  return buffer.toString();
}
