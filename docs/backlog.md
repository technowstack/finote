# Backlog

Fitur yang sengaja tidak dikerjakan saat redesign. Bukan komitmen rilis.
Tidak menggantikan dokumen lain; belum ditautkan dari README atau STATUS.

## Kategori: jumlah transaksi per kategori

- **Tampilan:** baris kategori menampilkan "Digunakan di N transaksi" (lihat
  `docs/design/screens/12-kategori-terang.png`).
- **Kenapa belum:** butuh query agregasi baru (hitung transaksi aktif per
  `category_id`). Redesign dibatasi pada tampilan, tanpa query baru.
- **Syarat saat dikerjakan:** hitung hanya transaksi yang tidak dihapus
  (`deleted_at IS NULL`), dan tambahkan index bila terukur lambat (AGENTS §48).
  Jumlahnya harus sama dengan yang dipakai Laporan untuk kategori yang sama.
