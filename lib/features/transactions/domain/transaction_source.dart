enum TransactionSource { manual, legacyImport, receiptScan, recurring }

extension TransactionSourceValue on TransactionSource {
  String get databaseValue => switch (this) {
    TransactionSource.manual => 'manual',
    TransactionSource.legacyImport => 'legacy_import',
    TransactionSource.receiptScan => 'receipt_scan',
    TransactionSource.recurring => 'recurring',
  };
}
