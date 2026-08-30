import 'receipt_image.dart';

class ReceiptTextBlock {
  const ReceiptTextBlock({required this.text, this.confidence});

  final String text;
  final double? confidence;
}

class ReceiptOcrResult {
  const ReceiptOcrResult({
    required this.rawText,
    this.blocks = const [],
    this.confidence,
  });

  final String rawText;
  final List<ReceiptTextBlock> blocks;
  final double? confidence;
}

abstract interface class ReceiptOcrService {
  Future<ReceiptOcrResult> recognize(ReceiptImage image);
}
