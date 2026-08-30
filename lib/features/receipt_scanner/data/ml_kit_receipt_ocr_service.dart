import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/receipt_image.dart';
import '../domain/receipt_ocr.dart';

class MlKitReceiptOcrService implements ReceiptOcrService {
  MlKitReceiptOcrService() : _recognizer = TextRecognizer();

  final TextRecognizer _recognizer;

  @override
  Future<ReceiptOcrResult> recognize(ReceiptImage image) async {
    final result = await _recognizer.processImage(
      InputImage.fromFilePath(image.path),
    );
    return ReceiptOcrResult(
      rawText: result.text,
      blocks: result.blocks
          .map(
            (block) => ReceiptTextBlock(
              text: block.text,
              boundingBox: _box(block.boundingBox),
              lines: block.lines
                  .map(
                    (line) => ReceiptTextLine(
                      text: line.text,
                      boundingBox: _box(line.boundingBox),
                      confidence: line.confidence,
                      elements: line.elements
                          .map(
                            (element) => ReceiptTextElement(
                              text: element.text,
                              boundingBox: _box(element.boundingBox),
                              confidence: element.confidence,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  ReceiptBoundingBox _box(Rect rect) => ReceiptBoundingBox(
    left: rect.left,
    top: rect.top,
    right: rect.right,
    bottom: rect.bottom,
  );

  Future<void> close() => _recognizer.close();
}

final receiptOcrServiceProvider = Provider<ReceiptOcrService>((ref) {
  final service = MlKitReceiptOcrService();
  ref.onDispose(service.close);
  return service;
});
