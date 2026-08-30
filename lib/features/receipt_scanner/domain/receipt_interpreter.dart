import 'receipt_data.dart';
import 'receipt_ocr.dart';

abstract interface class ReceiptInterpreter {
  Future<ReceiptData> interpret(ReceiptOcrResult ocrResult);
}
