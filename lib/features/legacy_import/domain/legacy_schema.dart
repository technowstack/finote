/// Konstanta schema database legacy "Catatan Keuangan" lama.
///
/// Tabel-tabel ini bersifat read-only — tidak boleh dimodifikasi.
abstract final class LegacySchema {
  /// Semua tabel yang diketahui ada di database legacy.
  static const Set<String> knownTables = {
    'Transaction',
    'TransactionDay',
    'TransactionType',
    'TransactionSubType',
    'AppSetting',
  };

  /// Tabel minimum yang harus ada agar database dianggap kompatibel.
  ///
  /// - `Transaction` — sumber data utama transaksi.
  /// - `TransactionSubType` — definisi kategori legacy.
  ///
  /// `TransactionDay`, `TransactionType`, dan `AppSetting` bersifat
  /// opsional; ketidakhadiran mereka tidak membuat database incompatible.
  static const Set<String> requiredTables = {
    'Transaction',
    'TransactionSubType',
  };

  // ---------------------------------------------------------------------------
  // Kolom Transaction yang akan dibaca detector
  // ---------------------------------------------------------------------------

  /// Nama kolom ID di tabel Transaction.
  static const String colId = 'id';

  /// Nama kolom tipe (0 = expense, 1 = income) di tabel Transaction.
  static const String colType = 'type';

  /// Nama kolom jumlah di tabel Transaction.
  static const String colAmount = 'amount';

  /// Nama kolom sub-tipe (kategori) di tabel Transaction.
  static const String colSubType = 'subType';

  /// Nama kolom tanggal di tabel Transaction.
  /// Legacy menyimpan timestamp dalam milidetik (Unix ms).
  static const String colDate = 'date';

  // ---------------------------------------------------------------------------
  // Nama sumber legacy (digunakan untuk duplicate-protection di masa depan)
  // ---------------------------------------------------------------------------

  /// Nilai yang akan digunakan sebagai `legacy_source` saat import.
  static const String legacySource = 'catatan_keuangan_old';
}
