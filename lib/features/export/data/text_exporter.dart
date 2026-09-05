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
    ..writeln('Saldo periode: ${formatIdr(document.balance)}')
    ..writeln('Transaksi   : ${document.transactions.length}')
    ..writeln('Kas & dompet saat ini: ${formatIdr(document.totalAssets)}')
    ..writeln('Transfer    : ${document.transfers.length}')
    ..writeln('Volume transfer: ${formatIdr(document.transferVolume)}')
    ..writeln()
    ..writeln('SALDO AKUN SAAT INI');
  if (document.accounts.isEmpty) {
    buffer.writeln('Tidak ada akun.');
  }
  for (final account in document.accounts) {
    buffer
      ..writeln()
      ..writeln(
        '${account.name} | ${account.type} | ${account.isActive ? 'Aktif' : 'Diarsipkan'}',
      )
      ..writeln('Saldo awal       : ${formatIdr(account.initialBalance)}')
      ..writeln('Pemasukan        : ${formatIdr(account.totalIncome)}')
      ..writeln('Pengeluaran      : ${formatIdr(account.totalExpense)}')
      ..writeln('Transfer masuk   : ${formatIdr(account.incomingTransfers)}')
      ..writeln('Transfer keluar  : ${formatIdr(account.outgoingTransfers)}')
      ..writeln('Saldo saat ini   : ${formatIdr(account.balance)}');
  }
  buffer
    ..writeln()
    ..writeln('TRANSFER ANTAR AKUN');
  if (document.transfers.isEmpty) {
    buffer.writeln('Tidak ada transfer.');
  }
  for (final transfer in document.transfers) {
    buffer
      ..writeln()
      ..writeln(DateFormat('dd/MM/yyyy').format(transfer.date))
      ..writeln('${transfer.fromAccount} -> ${transfer.toAccount}')
      ..writeln(transfer.note?.isNotEmpty == true ? transfer.note : '-')
      ..writeln(formatIdr(transfer.amount));
  }
  buffer
    ..writeln()
    ..writeln('TRANSAKSI');
  if (document.transactions.isEmpty) {
    buffer.writeln('Tidak ada transaksi.');
  }
  for (final row in document.transactions) {
    buffer
      ..writeln()
      ..writeln(DateFormat('dd/MM/yyyy').format(row.date))
      ..writeln(
        '${row.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran'} | ${row.account} | ${row.category}',
      )
      ..writeln(row.title.isEmpty ? '-' : row.title)
      ..writeln(formatIdr(row.amount));
    if (row.note?.isNotEmpty == true) buffer.writeln(row.note);
  }
  return buffer.toString();
}
