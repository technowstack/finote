import 'package:drift/drift.dart';

import '../../features/transactions/domain/transaction_source.dart';
import '../../features/transactions/domain/transaction_type.dart';

class TransactionTypeConverter extends TypeConverter<TransactionType, String> {
  const TransactionTypeConverter();

  @override
  TransactionType fromSql(String fromDb) => switch (fromDb) {
    'income' => TransactionType.income,
    'expense' => TransactionType.expense,
    _ => throw FormatException('Unknown transaction type: $fromDb'),
  };

  @override
  String toSql(TransactionType value) => value.name;
}

class TransactionSourceConverter
    extends TypeConverter<TransactionSource, String> {
  const TransactionSourceConverter();

  @override
  TransactionSource fromSql(String fromDb) => switch (fromDb) {
    'manual' => TransactionSource.manual,
    'legacy_import' => TransactionSource.legacyImport,
    'receipt_scan' => TransactionSource.receiptScan,
    'recurring' => TransactionSource.recurring,
    _ => throw FormatException('Unknown transaction source: $fromDb'),
  };

  @override
  String toSql(TransactionSource value) => value.databaseValue;
}

class DateOnlyConverter extends TypeConverter<DateTime, String> {
  const DateOnlyConverter();

  static final _pattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  @override
  DateTime fromSql(String fromDb) {
    if (!_pattern.hasMatch(fromDb)) {
      throw const FormatException('Invalid date');
    }
    final parts = fromDb.split('-').map(int.parse).toList();
    final date = DateTime(parts[0], parts[1], parts[2]);
    if (toSql(date) != fromDb) throw const FormatException('Invalid date');
    return date;
  }

  @override
  String toSql(DateTime value) {
    String pad(int part) => part.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-${pad(value.month)}-${pad(value.day)}';
  }
}
