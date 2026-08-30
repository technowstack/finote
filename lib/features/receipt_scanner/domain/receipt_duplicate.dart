import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'receipt_data.dart';

enum ReceiptDuplicateLevel { strong, possible }

class ReceiptDuplicate {
  const ReceiptDuplicate({required this.transactionId, required this.level});

  final int transactionId;
  final ReceiptDuplicateLevel level;
}

class ReceiptIdentity {
  const ReceiptIdentity({
    required this.merchant,
    required this.date,
    required this.total,
    required this.receiptNumber,
    required this.items,
  });

  final String merchant;
  final DateTime date;
  final int total;
  final String? receiptNumber;
  final List<ReceiptItem> items;

  String get signature {
    final itemSignature = [
      for (final item in items)
        '${normalizeReceiptPart(item.name)}:${item.lineTotal ?? 0}',
    ]..sort();
    return [
      normalizeReceiptPart(merchant),
      '${date.year}-${date.month}-${date.day}',
      total,
      normalizeReceiptPart(receiptNumber ?? ''),
      itemSignature.join('|'),
    ].join('|');
  }

  Future<String> fingerprint() async {
    final digest = await Sha256().hash(utf8.encode(signature));
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

String normalizeReceiptPart(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');
