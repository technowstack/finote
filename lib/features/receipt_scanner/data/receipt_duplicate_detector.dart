import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../transactions/domain/transaction_source.dart';
import '../domain/receipt_duplicate.dart';

class ReceiptDuplicateDetector {
  ReceiptDuplicateDetector(this._database);

  final AppDatabase _database;

  Future<ReceiptDuplicate?> findDuplicate(ReceiptIdentity identity) async {
    final fingerprint = await identity.fingerprint();
    final exactMatches =
        await (_database.select(_database.transactions)..where(
              (transaction) =>
                  transaction.source.equals(
                    TransactionSource.receiptScan.databaseValue,
                  ) &
                  transaction.receiptFingerprint.equals(fingerprint) &
                  transaction.deletedAt.isNull(),
            ))
            .get();
    final exact = exactMatches.isEmpty ? null : exactMatches.first;
    if (exact != null) {
      return ReceiptDuplicate(
        transactionId: exact.id,
        level: identity.receiptNumber == null
            ? ReceiptDuplicateLevel.possible
            : ReceiptDuplicateLevel.strong,
      );
    }

    if (identity.total <= 0) return null;
    final date =
        '${identity.date.year.toString().padLeft(4, '0')}-'
        '${identity.date.month.toString().padLeft(2, '0')}-'
        '${identity.date.day.toString().padLeft(2, '0')}';
    final candidates =
        await (_database.select(_database.transactions)..where(
              (transaction) =>
                  transaction.source.equals(
                    TransactionSource.receiptScan.databaseValue,
                  ) &
                  transaction.transactionDate.equals(date) &
                  transaction.amount.equals(identity.total) &
                  transaction.deletedAt.isNull(),
            ))
            .get();
    final merchant = normalizeReceiptPart(identity.merchant);
    for (final candidate in candidates) {
      if (merchant.isNotEmpty &&
          normalizeReceiptPart(candidate.title).contains(merchant)) {
        return ReceiptDuplicate(
          transactionId: candidate.id,
          level: ReceiptDuplicateLevel.possible,
        );
      }
    }
    return null;
  }
}

final receiptDuplicateDetectorProvider = Provider<ReceiptDuplicateDetector>(
  (ref) => ReceiptDuplicateDetector(ref.watch(databaseProvider)),
);
