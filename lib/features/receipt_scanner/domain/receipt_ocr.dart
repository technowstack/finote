import 'receipt_image.dart';

class ReceiptBoundingBox {
  const ReceiptBoundingBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

class ReceiptTextElement {
  const ReceiptTextElement({
    required this.text,
    required this.boundingBox,
    this.confidence,
  });

  final String text;
  final ReceiptBoundingBox boundingBox;
  final double? confidence;
}

class ReceiptTextLine {
  const ReceiptTextLine({
    required this.text,
    required this.boundingBox,
    this.elements = const [],
    this.confidence,
  });

  final String text;
  final ReceiptBoundingBox boundingBox;
  final List<ReceiptTextElement> elements;
  final double? confidence;
}

class ReceiptTextBlock {
  const ReceiptTextBlock({
    required this.text,
    required this.boundingBox,
    this.lines = const [],
  });

  final String text;
  final ReceiptBoundingBox boundingBox;
  final List<ReceiptTextLine> lines;
}

class ReceiptOcrResult {
  const ReceiptOcrResult({required this.rawText, this.blocks = const []});

  final String rawText;
  final List<ReceiptTextBlock> blocks;
}

abstract interface class ReceiptOcrService {
  Future<ReceiptOcrResult> recognize(ReceiptImage image);
}
