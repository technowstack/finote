import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/receipt_data.dart';
import '../domain/receipt_interpreter.dart';
import '../domain/receipt_ocr.dart';
import 'indonesian_receipt_parser.dart';

class RuleBasedReceiptInterpreter implements ReceiptInterpreter {
  RuleBasedReceiptInterpreter({ReceiptParser? parser})
    : _parser = parser ?? IndonesianReceiptParser();

  final ReceiptParser _parser;

  @override
  Future<ReceiptData> interpret(ReceiptOcrResult ocrResult) async =>
      _parser.parse(ocrResult);
}

final receiptInterpreterProvider = Provider<ReceiptInterpreter>(
  (ref) => RuleBasedReceiptInterpreter(),
);
