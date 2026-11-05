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

## Kategori: urutan berdasarkan pemakaian

- **Tampilan:** daftar kategori diurutkan dari yang paling sering dipakai
  (lihat `docs/design/screens/12-kategori-terang.png`).
- **Kenapa belum:** butuh hitungan pemakaian per kategori, sama dengan item
  "jumlah transaksi per kategori" di atas. Urutan sekarang abjad.
- **Syarat saat dikerjakan:** urutan hanya memakai transaksi aktif
  (`deleted_at IS NULL`), dan tie-break tetap abjad agar urutan stabil.

## Akun: Masuk/Keluar bulan ini per akun

- **Tampilan:** panel per akun menampilkan "Masuk/Keluar bulan ini"
  (lihat `docs/design/screens/11-akun-dan-dompet-terang.png`).
- **Keputusan sekarang:** panel memakai "Total masuk" dan "Total keluar"
  sepanjang waktu, supaya tidak terkesan membatasi periode.
- **Kenapa belum:** butuh filter periode di ringkasan akun
  (`accountSummariesProvider`), yang menyentuh perhitungan saldo.
- **Syarat saat dikerjakan:** Masuk/Keluar per periode harus konsisten dengan
  Laporan dan Beranda untuk periode yang sama. Saldo tetap dihitung dari
  seluruh transaksi aktif, tidak dari periode.
