/// Hasil deteksi read-only dari database legacy Catatan Keuangan.
///
/// Seluruh data bersifat informatif — tidak ada perubahan yang dilakukan
/// pada database sumber.
class LegacyDetectionResult {
  const LegacyDetectionResult({
    required this.tablesFound,
    required this.tablesRecognised,
    required this.tablesMissing,
    required this.transactionCount,
    required this.categoryCount,
    this.oldestTransactionAt,
    this.newestTransactionAt,
  });

  /// Semua tabel yang ditemukan di database legacy.
  final Set<String> tablesFound;

  /// Subset dari [tablesFound] yang dikenal oleh aplikasi ini
  /// (irisan dengan [LegacySchema.knownTables]).
  final Set<String> tablesRecognised;

  /// Tabel wajib yang tidak ditemukan di database
  /// ([LegacySchema.requiredTables] − [tablesFound]).
  ///
  /// Jika kosong, database dianggap kompatibel.
  final Set<String> tablesMissing;

  /// Jumlah baris di tabel `Transaction`.
  final int transactionCount;

  /// Jumlah nilai `subType` yang unik di tabel `Transaction` —
  /// merepresentasikan jumlah kategori yang digunakan.
  final int categoryCount;

  /// Tanggal transaksi paling lama (kolom `date` dalam Unix ms).
  ///
  /// `null` jika database tidak memiliki transaksi.
  final DateTime? oldestTransactionAt;

  /// Tanggal transaksi paling baru (kolom `date` dalam Unix ms).
  ///
  /// `null` jika database tidak memiliki transaksi.
  final DateTime? newestTransactionAt;

  /// `true` jika semua tabel wajib ditemukan dan database dapat di-import.
  bool get isCompatible => tablesMissing.isEmpty;
}
