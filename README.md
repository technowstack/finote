# Finote

Finote adalah aplikasi pencatatan keuangan pribadi yang sederhana, cepat, dan
dapat digunakan tanpa internet.

Finote membantu pengguna mencatat pemasukan dan pengeluaran, memahami kondisi
keuangan, menjaga data tetap tersimpan di perangkat, serta membawa data keluar
melalui laporan dan backup.

## Fitur Utama

- Mencatat pemasukan dan pengeluaran, termasuk input cepat dengan nominal
  bilangan bulat dalam Rupiah.
- Mengelola kategori transaksi, dengan tab Pengeluaran dan Pemasukan.
- Mengelola akun dan dompet (Tunai, Bank, E-Wallet, Tabungan), serta transfer
  antar akun. Transfer tidak dihitung sebagai pemasukan atau pengeluaran.
- Melihat saldo, total kekayaan bersih, histori, dan ringkasan keuangan.
- Mencari dan memfilter transaksi.
- Laporan dengan grafik: pengeluaran per kategori, pemasukan dan pengeluaran,
  saldo per akun, dan riwayat bulanan.
- Export laporan ke Excel, Text, dan PDF.
- Backup dan restore data.
- Import data dari aplikasi Catatan Keuangan lama.
- Portofolio aset (saham, kripto, reksa dana, emas, dan lainnya) dengan posisi
  awal, pembelian, penjualan, dan penyesuaian. Harga pasar hanya diambil saat
  pengguna menekan Refresh Harga.
- Sembunyikan saldo dengan satu ketukan.
- Pilihan tema Sistem, Terang, dan Gelap.
- Kunci aplikasi dengan PIN atau biometrik perangkat. Saat kunci aktif, layar
  aplikasi disembunyikan dari pratinjau Recent Apps.
- Reset data untuk memulai dari kondisi awal.
- Receipt Scanner lokal sebagai fitur eksperimental.

## Desain

Tampilan mengikuti redesign v1.3 dengan satu warna brand untuk mode terang dan
gelap. Sumber desainnya ada di `docs/design/` (token, spesifikasi komponen, dan
screenshot). Ringkasan sistem desain ada di
`docs/finote-audit/03-DESIGN-SYSTEM.md`.

## Prinsip Finote

- Data keuangan adalah milik pengguna.
- Fitur utama tetap dapat digunakan secara offline.
- Data disimpan secara lokal di perangkat.
- Backup dan export membantu pengguna menjaga serta membawa datanya.
- Pengalaman pencatatan manual tetap menjadi fokus utama.

Finote tidak membutuhkan akun atau layanan cloud untuk fitur inti. AI, budget,
recurring transaction, dan cloud sync belum termasuk dalam versi saat ini.
Pengambilan harga pasar hanya terjadi saat pengguna memintanya.

## Status Proyek

- v1.0.0 (fitur inti, export, backup, import, dan keamanan dasar) sudah selesai
  secara lokal.
- v1.1.0 (akun dan transfer) dan v1.2.0 (visualisasi laporan) sudah selesai.
- v1.3.0 (aset dan investasi) sedang dikerjakan. Fase yang sudah selesai dan
  yang masih berjalan dicatat di `STATUS.md`.
- Pengujian di perangkat nyata, verifikasi upgrade data, signing production,
  dan aset publik masih dalam proses.

Receipt Scanner belum ditetapkan sebagai fitur stable. Fitur ini akan
dipertahankan hanya jika hasil pengujian menunjukkan pengalaman yang aman dan
cukup dapat diandalkan.

## Pengembangan

Perintah dasar:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

Test mencakup perhitungan keuangan, migrasi database, export, backup, layout
pada lebar 320dp dengan teks 1.3×, dan tema terang serta gelap.

## Dokumentasi

- [Product Requirements](PRD.md)
- [Development Status](STATUS.md)
- [Developer Guide](DEVELOPER_GUIDE.md)
- [Design System](docs/finote-audit/03-DESIGN-SYSTEM.md)
- [Backlog](docs/backlog.md)
- [Release Feature Matrix](docs/release_feature_matrix.md)
- [Closed Testing Plan](docs/closed_testing_plan.md)
- [Release Readiness](docs/release_readiness.md)
- [Privacy Policy Draft](docs/privacy_policy.md)

Finote belum dipublikasikan ke Google Play Store.
