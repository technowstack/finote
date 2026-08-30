import 'dart:typed_data';

import 'backup_manifest.dart';

/// Hasil dari validasi file backup sebelum restore dieksekusi.
///
/// Berisi manifest yang sudah divalidasi dan byte-byte arsip ZIP agar
/// proses restore dapat dilanjutkan tanpa membaca ulang file dari disk.
class RestorePreview {
  const RestorePreview({
    required this.manifest,
    required this.archiveBytes,
    required this.transactionCount,
    required this.categoryCount,
    required this.totalIncome,
    required this.totalExpense,
    required this.oldestTransactionAt,
    required this.newestTransactionAt,
  });

  /// Manifest yang telah divalidasi dari file backup.
  final BackupManifest manifest;

  /// Byte-byte lengkap arsip ZIP yang akan dipulihkan.
  final Uint8List archiveBytes;

  final int transactionCount;
  final int categoryCount;
  final int totalIncome;
  final int totalExpense;
  final DateTime? oldestTransactionAt;
  final DateTime? newestTransactionAt;
}
