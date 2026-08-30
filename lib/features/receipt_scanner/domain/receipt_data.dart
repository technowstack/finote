import 'receipt_ocr.dart';

enum ReceiptItemSource { ocr, manual, ai }

class ReceiptItem {
  const ReceiptItem({
    required this.name,
    this.quantity,
    this.unitPrice,
    this.lineTotal,
    this.rawLine,
    this.source = ReceiptItemSource.ocr,
  });

  final String name;
  final int? quantity;
  final int? unitPrice;
  final int? lineTotal;
  final String? rawLine;
  final ReceiptItemSource source;
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

  ReceiptReviewData toReviewData() => ReceiptReviewData(
    merchant: merchant,
    transactionDate: transactionDate,
    subtotal: subtotal,
    tax: tax,
    discount: discount,
    total: total,
    receiptNumber: receiptNumber,
    items: items,
    rawOcrText: rawText ?? '',
  );
}

class ReceiptReviewData {
  const ReceiptReviewData({
    this.merchant,
    this.transactionDate,
    this.subtotal,
    this.tax,
    this.discount,
    this.total,
    this.receiptNumber,
    this.items = const [],
    this.rawOcrText = '',
  });

  final String? merchant;
  final DateTime? transactionDate;
  final int? subtotal;
  final int? tax;
  final int? discount;
  final int? total;
  final String? receiptNumber;
  final List<ReceiptItem> items;
  final String rawOcrText;

  int get itemTotal =>
      items.fold(0, (sum, item) => sum + (item.lineTotal ?? 0));

  int? get difference => total == null ? null : itemTotal - total!;

  bool get reconciles => total != null && itemTotal == total;

  List<String> get warnings => [
    if (total == null)
      'Total struk belum terbaca. Masukkan nominal sebelum menyimpan.',
    if (items.any((item) => item.lineTotal == null || item.lineTotal! <= 0))
      'Beberapa item belum memiliki nominal yang valid.',
    if (total != null && items.isNotEmpty && !reconciles) 'Jumlah item berbeda dari total struk. Periksa pajak, diskon, item yang belum terbaca, atau OCR.',
  ];

  ReceiptReviewData copyWith({
    String? merchant,
    DateTime? transactionDate,
    int? subtotal,
    int? tax,
    int? discount,
    int? total,
    String? receiptNumber,
    List<ReceiptItem>? items,
  }) => ReceiptReviewData(
    merchant: merchant ?? this.merchant,
    transactionDate: transactionDate ?? this.transactionDate,
    subtotal: subtotal ?? this.subtotal,
    tax: tax ?? this.tax,
    discount: discount ?? this.discount,
    total: total ?? this.total,
    receiptNumber: receiptNumber ?? this.receiptNumber,
    items: items ?? this.items,
    rawOcrText: rawOcrText,
  );
}

abstract interface class ReceiptParser {
  ReceiptData parse(ReceiptOcrResult result);
}
