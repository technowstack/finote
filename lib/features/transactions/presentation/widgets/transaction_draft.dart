import 'package:flutter/material.dart';

import '../../../receipt_scanner/domain/receipt_data.dart';
import '../../../receipt_scanner/domain/receipt_category_suggestion.dart';
import '../../domain/transaction_source.dart';
import '../../domain/transaction_type.dart';
import 'idr_amount_input.dart';

class TransactionFormDraft {
  const TransactionFormDraft({
    required this.type,
    required this.source,
    this.amount,
    this.title = '',
    this.date,
    this.receiptReview,
  });

  final TransactionType type;
  final TransactionSource source;
  final int? amount;
  final String title;
  final DateTime? date;
  final ReceiptReviewData? receiptReview;
}

enum ReceiptSaveMode { single, itemized }

class DraftReceiptItem {
  DraftReceiptItem(this.item)
    : nameController = TextEditingController(text: item.name),
      amountController = TextEditingController(
        text: item.lineTotal == null
            ? ''
            : formatIdrAmountInput(item.lineTotal!),
      );

  final ReceiptItem item;
  final TextEditingController nameController;
  final TextEditingController amountController;
  int? categoryId;
  CategorySuggestion? categorySuggestion;
  bool categoryManuallySelected = false;

  String get name => nameController.text;
  int get amount => parseIdrAmount(amountController.text);

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}
