import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../core/utils/date_formatter.dart';
import '../../transactions/domain/transaction_type.dart';
import '../domain/export_document.dart';

Uint8List buildExcelExport(ExportDocument document) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('[Content_Types].xml', _contentTypes))
    ..addFile(ArchiveFile.string('_rels/.rels', _rels))
    ..addFile(ArchiveFile.string('xl/workbook.xml', _workbook))
    ..addFile(ArchiveFile.string('xl/_rels/workbook.xml.rels', _workbookRels))
    ..addFile(ArchiveFile.string('xl/styles.xml', _styles))
    ..addFile(
      ArchiveFile.string('xl/worksheets/sheet1.xml', _summarySheet(document)),
    )
    ..addFile(
      ArchiveFile.string(
        'xl/worksheets/sheet2.xml',
        _transactionSheet(document),
      ),
    )
    ..addFile(
      ArchiveFile.string('xl/worksheets/sheet3.xml', _accountSheet(document)),
    )
    ..addFile(
      ArchiveFile.string('xl/worksheets/sheet4.xml', _transferSheet(document)),
    );
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

String _summarySheet(ExportDocument document) => _sheet([
  _row([_text('Periode'), _text(_period(document))]),
  _row([_text('Total pemasukan'), _number(document.totalIncome)]),
  _row([_text('Total pengeluaran'), _number(document.totalExpense)]),
  _row([_text('Saldo'), _number(document.balance)]),
  _row([_text('Jumlah transaksi'), _number(document.transactions.length)]),
  _row([_text('Total aset saat ini'), _number(document.totalAssets)]),
  _row([_text('Jumlah akun'), _number(document.accounts.length)]),
  _row([_text('Jumlah transfer'), _number(document.transfers.length)]),
  _row([_text('Total volume transfer'), _number(document.transferVolume)]),
  _row([
    _text('Generated at'),
    _text(document.generatedAt.toLocal().toIso8601String()),
  ]),
]);

String _transactionSheet(ExportDocument document) => _sheet([
  _row(
    [
      'No',
      'Tanggal',
      'Tipe',
      'Akun',
      'Kategori',
      'Judul',
      'Catatan',
      'Nominal',
    ].map(_text).toList(),
  ),
  for (var i = 0; i < document.transactions.length; i++)
    _row([
      _number(i + 1),
      _date(document.transactions[i].date),
      _text(
        document.transactions[i].type == TransactionType.income
            ? 'Pemasukan'
            : 'Pengeluaran',
      ),
      _text(document.transactions[i].account),
      _text(document.transactions[i].category),
      _text(document.transactions[i].title),
      _text(document.transactions[i].note ?? ''),
      _number(document.transactions[i].amount),
    ]),
]);

String _accountSheet(ExportDocument document) => _sheet([
  _row(
    [
      'No',
      'Nama Akun',
      'Jenis',
      'Saldo Awal',
      'Total Pemasukan',
      'Total Pengeluaran',
      'Transfer Masuk',
      'Transfer Keluar',
      'Saldo Saat Ini',
      'Status',
    ].map(_text).toList(),
  ),
  for (var i = 0; i < document.accounts.length; i++)
    _row([
      _number(i + 1),
      _text(document.accounts[i].name),
      _text(document.accounts[i].type),
      _number(document.accounts[i].initialBalance),
      _number(document.accounts[i].totalIncome),
      _number(document.accounts[i].totalExpense),
      _number(document.accounts[i].incomingTransfers),
      _number(document.accounts[i].outgoingTransfers),
      _number(document.accounts[i].balance),
      _text(document.accounts[i].isActive ? 'Aktif' : 'Diarsipkan'),
    ]),
]);

String _transferSheet(ExportDocument document) => _sheet([
  _row(
    ['No', 'Tanggal', 'Dari', 'Ke', 'Catatan', 'Nominal'].map(_text).toList(),
  ),
  for (var i = 0; i < document.transfers.length; i++)
    _row([
      _number(i + 1),
      _date(document.transfers[i].date),
      _text(document.transfers[i].fromAccount),
      _text(document.transfers[i].toAccount),
      _text(document.transfers[i].note ?? ''),
      _number(document.transfers[i].amount),
    ]),
]);

String _sheet(List<String> rows) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>${rows.join()}</sheetData></worksheet>';
String _row(List<String> cells) => '<row>${cells.join()}</row>';
String _text(String value) =>
    '<c t="inlineStr"><is><t>${_xml(value)}</t></is></c>';
String _number(num value) => '<c t="n"><v>$value</v></c>';
String _date(DateTime value) {
  final serial = value.difference(DateTime(1899, 12, 30)).inDays;
  return '<c s="1" t="n"><v>$serial</v></c>';
}

String _period(ExportDocument document) {
  final start = document.filter.startDate;
  final end = document.filter.endDate;
  if (start == null && end == null) return 'Semua transaksi';
  return '${start == null ? '-' : formatDate(start)} - ${end == null ? '-' : formatDate(end)}';
}

String _xml(String value) => const HtmlEscape().convert(value);

const _contentTypes =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet3.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet4.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>';
const _rels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>';
const _workbook =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Ringkasan" sheetId="1" r:id="rId1"/><sheet name="Transaksi" sheetId="2" r:id="rId2"/><sheet name="Akun" sheetId="3" r:id="rId3"/><sheet name="Transfer" sheetId="4" r:id="rId4"/></sheets></workbook>';
const _workbookRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet3.xml"/><Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet4.xml"/><Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>';
const _styles =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf numFmtId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0"/><xf numFmtId="14"/></cellXfs></styleSheet>';
