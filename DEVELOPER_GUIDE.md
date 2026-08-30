# Finote Developer Guide

Panduan ini menjelaskan cara bekerja di repository Finote tanpa mengubah scope
produk secara tidak sengaja.

## Prinsip Proyek

- Finote adalah aplikasi personal finance offline-first.
- SQLite/Drift adalah source of truth data keuangan.
- Nilai uang disimpan sebagai `int` dalam satuan Rupiah, bukan `double`.
- Data loss, total finansial yang salah, dan restore yang merusak data adalah
  release-critical.
- Manual transaction flow tetap menjadi fitur utama.
- Jangan menambahkan AI, cloud, wallet, budget, atau recurring transaction pada
  roadmap release tanpa instruksi eksplisit.
- Gunakan Bahasa Inggris untuk nama kode dan Bahasa Indonesia untuk UI.

Sumber keputusan, berurutan:

1. Instruksi user terbaru.
2. `PRD.md`.
3. `agents.md`.
4. Skill yang relevan di `.agents/skill/`.
5. Arsitektur dan pola yang sudah ada.

`STATUS.md` melacak kemajuan, bukan menggantikan requirement di `PRD.md`.

## Setup

```bash
flutter pub get
flutter run
```

Konfigurasi Android saat ini:

- Application ID: `com.finote.app`.
- `minSdk`: nilai Flutter toolchain, saat ini 24.
- `compileSdk`: 37.
- `targetSdk`: 36.
- Java/Kotlin target: 17.

## Struktur Kode

```text
lib/
├── app/                 # App root, router, scaffold
├── core/
│   ├── database/        # Drift tables, database, converters
│   ├── errors/          # User-safe error mapping
│   ├── services/        # Shared services, logger
│   ├── theme/           # Colors, spacing, theme preference
│   └── utils/           # Currency and date helpers
└── features/
    ├── dashboard/
    ├── transactions/
    ├── categories/
    ├── reports/
    ├── export/
    ├── settings/
    ├── backup/
    ├── legacy_import/
    └── receipt_scanner/
```

Feature code dapat menggunakan `data/`, `domain/`, dan `presentation/` jika
memang membantu. Jangan membuat layer atau abstraction untuk satu pemakaian.

## Data dan Database

SQLite melalui Drift menyimpan transaksi, kategori, dan settings. Transaksi
menggunakan integer amount, UUID, `source`, metadata legacy, dan soft delete.

Aturan penting:

- Balance dihitung sebagai income aktif dikurangi expense aktif.
- Transaksi soft-deleted tidak boleh muncul di histori aktif, dashboard,
  laporan, pencarian, atau export.
- Operasi multi-record harus atomik.
- Perubahan schema wajib menaikkan schema version dan menyediakan migration.
- Uji migration pada database lama yang berisi data, bukan hanya fresh install.
- Legacy database dibuka read-only.
- Import harus repeat-safe menggunakan `legacy_source` dan `legacy_id`.
- Restore harus memvalidasi file dan membuat safety backup sebelum replacement.

Jangan mengedit file generated Drift secara manual. Jika generated code berubah,
gunakan:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Menambah Fitur

1. Baca `PRD.md`, `STATUS.md`, dan skill yang relevan.
2. Cari repository, provider, utility, dan test yang sudah ada.
3. Ubah file sesedikit mungkin.
4. Pertahankan offline behavior dan data integrity.
5. Tambahkan regression test untuk logic non-trivial.
6. Jalankan format, analyzer, dan seluruh test.
7. Update `STATUS.md` hanya untuk progress yang benar-benar tervalidasi.

Jangan mencampur feature baru, dependency upgrade, refactor besar, dan release
work dalam satu perubahan tanpa alasan yang jelas.

## Testing

Perintah standar:

```bash
dart format .
flutter analyze
flutter test
```

Test saat ini mencakup core finance, kategori, dashboard, reports, export,
backup/restore, legacy import, theme, PIN, receipt scanner, dan benchmark
10.000 transaksi.

Test manual menggunakan dummy, synthetic, atau data yang sudah di-redact.
Jangan memasukkan nominal pribadi, saldo, catatan, foto struk, database,
backup, PIN, atau OCR text ke issue report.

Dokumen testing:

- `docs/closed_testing_plan.md`
- `docs/device_test_matrix.md`
- `docs/bug_report_template.md`
- `docs/tester_feedback_template.md`
- `docs/test_runs/rc1.md`

## Release Build

```bash
flutter build apk --release
flutter build appbundle --release
```

APK dipakai untuk direct device testing. AAB adalah artifact yang kelak dapat
diunggah secara manual ke Play Console. Perintah build tidak melakukan upload.

Release signing membaca `android/key.properties` jika file tersebut tersedia:

```text
storeFile=upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

File keystore pada contoh berada relatif terhadap folder `android/`. Tanpa
file tersebut, konfigurasi saat ini memakai debug key agar build lokal tetap
berjalan. Artifact itu tidak boleh dipakai untuk distribusi.

Sebelum kandidat release:

- gunakan checkout yang bersih dan commit/tag yang diketahui;
- pastikan `versionCode` meningkat saat mengirim build baru;
- verifikasi application ID, target SDK, label, permissions, dan signing;
- inspeksi APK/AAB dan merged release manifest;
- jalankan upgrade test dari build sebelumnya;
- jalankan device, offline, lifecycle, backup/restore, dan export tests.

Candidate yang direncanakan saat ini adalah `v1.0.0-rc.1`. Detail run ada di
`docs/test_runs/rc1.md`.

## Android Permissions dan Privacy

Manifest utama meminta `CAMERA` untuk Receipt Scanner. File dan export memakai
system document picker, bukan broad storage permission.

Merged release manifest juga mendapat `INTERNET` dan
`ACCESS_NETWORK_STATE` dari dependency transport Google ML Kit. Finote tidak
memiliki application-owned network endpoint; audit ini harus diulang jika
dependency berubah.

Privacy dan Data Safety draft berada di:

- `docs/privacy_policy.md`
- `docs/play_store_data_safety.md`

Keduanya harus diperbarui jika data flow, dependency, permission, atau account
behavior berubah.

## Receipt Scanner

Receipt Scanner bersifat lokal dan opsional. OCR menghasilkan draft yang wajib
ditinjau dan dikoreksi user sebelum disimpan. Jangan memperluas OCR, AI, atau
cloud behavior selama release-focused roadmap.

Jika manual test menemukan masalah HIGH atau CRITICAL, sembunyikan scanner atau
labeli sebagai experimental. Jangan menunda core release untuk akurasi scanner.

## Bug dan Release Gates

Gunakan severity berikut:

- `BLOCKER`: app tidak bisa launch, data loss, atau release build gagal.
- `CRITICAL`: total salah, restore merusak data, atau duplikasi normal.
- `HIGH`: export rusak atau workflow utama tidak bisa dipakai.
- `MEDIUM`: masalah non-kritis pada workflow atau UX.
- `LOW`: masalah visual kecil.

Block release jika ada BLOCKER/CRITICAL, mismatch Reports dan export, restore
tidak aman, upgrade kehilangan data, core offline gagal, atau artifact masih
debug-signed.

Catat issue menggunakan `docs/bug_report_template.md`. Masukkan ide non-kritis
ke `docs/post_v1_ideas.md`, bukan langsung ke implementation.

## Dokumentasi Utama

- Product direction: `PRD.md`.
- Progress: `STATUS.md`.
- Play Store preparation: `docs/play_store_release_checklist.md`.
- Feature scope: `docs/release_feature_matrix.md`.
- Readiness: `docs/release_readiness.md`.
- Manual receipt tests: `docs/receipt_scanner_manual_test.md`.

Jangan publish ke Google Play, membuat tester account, membuat tag, atau
memulai production release dari workflow lokal tanpa instruksi eksplisit.
