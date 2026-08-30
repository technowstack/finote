import 'receipt_ocr.dart';

class ReceiptItem {
  const ReceiptItem({required this.name, this.quantity, this.total});

  final String name;
  final int? quantity;
  final int? total;
}

class ReceiptData {
  const ReceiptData({
    this.merchant,
    this.transactionDate,
    this.subtotal,
    this.tax,
    this.discount,
    this.total,
    this.receiptNumber,
    this.items = const [],
    this.rawText,
  });

  final String? merchant;
  final DateTime? transactionDate;
  final int? subtotal;
  final int? tax;
  final int? discount;
  final int? total;
  final String? receiptNumber;
  final List<ReceiptItem> items;
  final String? rawText;
}

abstract interface class ReceiptParser {
  ReceiptData parse(ReceiptOcrResult result);
}
