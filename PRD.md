# PRODUCT REQUIREMENTS DOCUMENT

# Finote

## Modern Offline-First Personal Finance Tracker

---

# 1. Product Information

**Product Name:** Finote  
**Platform awal:** Android  
**Future platform:** iOS jika dibutuhkan  
**Framework:** Flutter  
**Primary architecture:** Offline-first  
**Local database:** SQLite + Drift  
**State management:** Riverpod  
**Routing:** GoRouter  
**UI system:** Material Design 3  
**Primary language:** Bahasa Indonesia  
**Target distribution:** Google Play Store  
**Cloud:** Optional dan bukan kebutuhan inti  
**Primary user:** Pengguna individu

---

# 2. Product Background

Finote dikembangkan sebagai penerus modern dari aplikasi pencatatan keuangan lama yang sudah tidak aktif dikembangkan.

Kelebihan aplikasi lama yang ingin dipertahankan:

- sederhana;
- cepat;
- dapat digunakan tanpa akun;
- dapat digunakan tanpa internet;
- pencatatan pemasukan dan pengeluaran mudah;
- memiliki kategori;
- memiliki laporan;
- memiliki backup database;
- data dapat dipindahkan.

Finote memperbaiki pengalaman tersebut dengan:

- UI/UX modern;
- kompatibilitas Android yang lebih baik;
- database lokal yang terstruktur;
- backup dan restore yang aman;
- import database aplikasi lama;
- pencarian dan filter transaksi;
- laporan yang lebih matang;
- ekspor laporan ke **Excel, Text, dan PDF**;
- tema Light, Dark, dan System;
- arsitektur yang dapat dikembangkan tanpa mengorbankan core offline-first.

Receipt Scanner lokal yang sudah dikembangkan dapat dipertahankan selama stabil, tetapi bukan alasan untuk menunda rilis.

---

# 3. Current Product Direction

Fokus Finote saat ini adalah:

> **Membuat core personal finance app yang matang, stabil, cepat, nyaman digunakan secara manual, dan layak dirilis ke Play Store.**

Finote saat ini **tidak berfokus pada AI**.

Fitur berikut ditunda:

- AI Receipt Scan;
- AI OCR parsing;
- AI smart categorization;
- AI financial assistant;
- AI gateway/backend;
- integrasi OpenAI/Gemini/Claude atau layanan AI lainnya;
- AI subscription infrastructure.

Fitur AI hanya akan dipertimbangkan kembali setelah:

1. Finote rilis di Google Play Store;
2. memiliki pengguna nyata;
3. kebutuhan AI tervalidasi;
4. tersedia budget server/API;
5. strategi premium/langganan sudah jelas.

---

# 4. Product Vision

Membangun aplikasi keuangan pribadi yang:

> sederhana untuk digunakan setiap hari, cepat untuk mencatat transaksi, dapat berjalan sepenuhnya tanpa internet, menjaga kepemilikan data pengguna, mudah dibackup dan diekspor, serta dapat berkembang secara bertahap tanpa menjadikan cloud atau AI sebagai ketergantungan.

Finote harus terasa seperti:

```text
Buku Catatan Keuangan
+
Kalkulator
+
Laporan
+
Backup / Restore
+
Export
```

bukan seperti sistem accounting bisnis yang kompleks.

---

# 5. Product Principles

1. Offline-first.
2. Manual finance workflow harus selalu menjadi first-class feature.
3. Cepat digunakan.
4. Tidak wajib login.
5. Data milik pengguna.
6. Data mudah dibackup.
7. Data mudah direstore.
8. Data mudah diekspor.
9. Cloud bersifat optional.
10. Data integrity lebih penting daripada jumlah fitur.
11. Fitur baru tidak boleh membuat aplikasi terasa rumit.
12. Core finance harus tetap bekerja meskipun layanan eksternal tidak tersedia.
13. Jangan mengorbankan kestabilan demi fitur eksperimental.
14. Jangan menambahkan AI sebelum ada kebutuhan nyata yang tervalidasi.

---

# 6. Primary Goals

Finote harus memungkinkan pengguna:

- mencatat pengeluaran;
- mencatat pemasukan;
- mengedit transaksi;
- menghapus transaksi dengan aman;
- melihat saldo;
- melihat histori transaksi;
- mengelola kategori;
- mencari transaksi;
- memfilter transaksi;
- melihat laporan;
- backup data;
- restore data;
- import database aplikasi lama;
- **export data/laporan ke Excel (.xlsx);**
- **export data/laporan ke Text (.txt);**
- **export data/laporan ke PDF (.pdf);**
- memilih tema Light, Dark, atau System;
- menggunakan aplikasi sepenuhnya tanpa internet.

Receipt Scanner lokal dapat tersedia apabila kualitasnya cukup aman untuk pengguna.

---

# 7. Secondary Goals

Setelah versi publik stabil dan kebutuhan pengguna tervalidasi:

- multiple wallet/account;
- budgeting;
- recurring transaction;
- Google Drive/cloud backup;
- advanced reports;
- optional account;
- multi-device sync;
- attachment struk;
- receipt archive.

AI tetap masuk kategori **deferred/future validated features**.

---

# 8. Non-Goals Saat Ini

Finote versi awal bukan:

- aplikasi accounting perusahaan;
- ERP;
- aplikasi invoice;
- aplikasi perpajakan;
- aplikasi kasir;
- aplikasi pembayaran;
- aplikasi perbankan;
- aplikasi investasi;
- aplikasi cryptocurrency;
- sistem pembukuan double-entry;
- AI financial assistant;
- AI expense advisor;
- AI-first finance app.

---

# 9. Target Users

Target utama adalah pengguna Android yang ingin mencatat keuangan pribadi dengan cepat.

Contoh transaksi:

- makan;
- bensin;
- belanja;
- gaji;
- bonus;
- tagihan;
- internet;
- transportasi;
- hiburan.

Karakteristik target user:

- menginginkan aplikasi sederhana;
- tidak ingin banyak langkah;
- ingin bekerja offline;
- ingin data aman;
- ingin backup;
- ingin laporan yang mudah dipahami;
- ingin dapat membawa datanya keluar melalui format umum seperti Excel, Text, dan PDF.

---

# 10. Main Navigation

Bottom navigation:

```text
Home
Transactions
Reports
Settings
```

Primary action:

```text
+ Tambah Transaksi
```

Jika Receipt Scanner tetap diaktifkan:

```text
Scan Struk
```

harus menjadi fitur tambahan dan tidak menggantikan transaksi manual.

---

# 11. Core Manual Transaction Flow

```text
Buka aplikasi
↓
Tambah Transaksi
↓
Pilih Pengeluaran / Pemasukan
↓
Masukkan nominal
↓
Pilih kategori
↓
Simpan
```

Target UX:

> transaksi umum harus dapat dicatat hanya dalam beberapa detik.

---

# 12. Technical Stack

Gunakan:

```text
Flutter
Dart
Riverpod
GoRouter
Drift
SQLite
Material 3
```

Supporting packages dipilih hanya bila diperlukan dan maintained.

Contoh:

```text
uuid
intl
freezed
json_serializable
path_provider
file_picker
share_plus
```

Library Excel/PDF dipilih berdasarkan kompatibilitas dan maintenance pada saat implementasi.

---

# 13. Architecture

Gunakan Feature-First Architecture.

```text
lib/
├── app/
├── core/
│   ├── database/
│   ├── errors/
│   ├── services/
│   ├── theme/
│   └── utils/
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

Future features tidak perlu dibuat sebelum dibutuhkan.

---

# 14. Core Database Rules

Minimum tables:

```text
transactions
categories
settings
```

Transaction entity minimal:

```text
id
uuid
type
category_id
amount
title
note
transaction_date
source
legacy_source
legacy_id
created_at
updated_at
deleted_at
```

Financial values:

```text
INTEGER
```

Contoh:

```text
Rp25.000 → 25000
```

Jangan gunakan float/double untuk nominal IDR.

---

# 15. Transaction Source

Possible values:

```text
manual
legacy_import
receipt_scan
recurring
```

Nilai future boleh dipertahankan untuk kompatibilitas arsitektur.

---

# 16. Categories

Category minimal:

```text
id
uuid
name
type
icon
created_at
updated_at
deleted_at
```

Type:

```text
income
expense
```

Default Expense:

- Makanan & Minuman
- Transportasi
- Belanja
- Tagihan
- Hiburan
- Kesehatan
- Pendidikan
- Rumah
- Keluarga
- Lainnya

Default Income:

- Gaji
- Bonus
- Bisnis
- Hadiah
- Investasi
- Lainnya

---

# 17. Transaction CRUD

User harus dapat:

- menambah transaksi;
- mengedit transaksi;
- melakukan soft delete;
- membuka detail transaksi.

Default:

```text
type = expense
date = today
```

Prioritas form:

1. nominal;
2. kategori;
3. simpan;
4. judul;
5. tanggal;
6. catatan.

---

# 18. Transaction History

Support:

- grouping berdasarkan tanggal;
- income/expense indicator;
- edit;
- delete;
- search;
- filter.

Search:

```text
title
note
category
```

Filter:

```text
Semua
Pemasukan
Pengeluaran
Hari Ini
Minggu Ini
Bulan Ini
Custom
```

---

# 19. Dashboard

Dashboard minimum menampilkan:

- saldo;
- pemasukan bulan berjalan;
- pengeluaran bulan berjalan;
- transaksi hari ini;
- transaksi terbaru.

Balance:

```text
Total Income - Total Expense
```

Saldo tidak disimpan sebagai state finansial terpisah.

---

# 20. Reports

Minimum:

- total pemasukan;
- total pengeluaran;
- saldo periode;
- top expense categories;
- top income categories;
- monthly history.

Periods:

- hari;
- minggu;
- bulan;
- custom.

Dashboard, reports, dan transaction history harus menghasilkan angka konsisten untuk periode yang sama.

---

# 21. EXPORT — CORE FEATURE

Export merupakan **fitur utama Finote**, bukan fitur tambahan opsional.

Export harus tersedia sebelum first public release.

Entry point utama:

```text
Reports
→ Export
```

Dapat juga tersedia dari:

```text
Settings
→ Data
→ Export Data
```

## 21.1 Supported Formats

Wajib:

```text
Excel (.xlsx)
Text (.txt)
PDF (.pdf)
```

Future optional:

```text
CSV
JSON
```

## 21.2 Export Scope

User dapat memilih:

```text
Semua transaksi
Hari ini
Minggu ini
Bulan ini
Custom date range
```

Jika filter laporan sedang aktif, opsi export dapat menggunakan filter tersebut.

## 21.3 Export Filters

Support bila relevan:

- semua transaksi;
- hanya pemasukan;
- hanya pengeluaran;
- kategori;
- rentang tanggal.

## 21.4 Export Preview

Sebelum membuat file, tampilkan ringkasan:

```text
Periode
Jumlah transaksi
Total pemasukan
Total pengeluaran
Saldo periode
Format
```

Contoh:

```text
Export Laporan

Periode:
1–31 Agustus 2026

128 transaksi

Pemasukan      Rp8.500.000
Pengeluaran    Rp4.350.000
Saldo          Rp4.150.000

Format:
Excel

[Export]
```

## 21.5 Excel Export

File:

```text
finote_report_YYYY-MM-DD.xlsx
```

Minimum worksheet:

### Ringkasan

```text
Periode
Total pemasukan
Total pengeluaran
Saldo
Jumlah transaksi
Generated at
```

### Transaksi

Columns:

```text
No
Tanggal
Tipe
Kategori
Judul
Catatan
Nominal
```

Requirements:

- nominal disimpan sebagai numeric cell;
- header jelas;
- date cell benar;
- file dapat dibuka di Microsoft Excel/LibreOffice/Google Sheets;
- tidak menggunakan formatted currency string sebagai sumber angka.

Optional:

### Kategori

Summary per kategori.

## 21.6 Text Export

File:

```text
finote_report_YYYY-MM-DD.txt
```

Harus human-readable.

Contoh:

```text
FINOTE - LAPORAN KEUANGAN

Periode:
1 - 31 Agustus 2026

RINGKASAN

Pemasukan   : Rp8.500.000
Pengeluaran : Rp4.350.000
Saldo       : Rp4.150.000

TRANSAKSI

01/08/2026
Pengeluaran | Makanan & Minuman
Makan Siang
Rp25.000

02/08/2026
Pengeluaran | Transportasi
Bensin
Rp50.000
```

Gunakan UTF-8.

## 21.7 PDF Export

File:

```text
finote_report_YYYY-MM-DD.pdf
```

PDF minimum berisi:

```text
Finote
Laporan Keuangan

Periode

Ringkasan:
- Total pemasukan
- Total pengeluaran
- Saldo
- Jumlah transaksi

Detail transaksi
```

Detail table minimum:

```text
Tanggal
Tipe
Kategori
Keterangan
Nominal
```

Requirements:

- layout tidak terpotong;
- mendukung multi-page;
- nominal rata kanan bila memungkinkan;
- header dapat diulang pada halaman berikutnya jika library mendukung;
- nyaman dicetak/dibaca;
- Bahasa Indonesia tampil benar;
- tidak bergantung internet.

## 21.8 Export Destination

Gunakan Android system file/document APIs.

User harus dapat:

- memilih lokasi penyimpanan;
- membuka file;
- membagikan file jika share action tersedia.

Jangan meminta broad storage permission.

Hindari:

```text
MANAGE_EXTERNAL_STORAGE
```

## 21.9 Export Safety

Export tidak boleh:

- mengubah transaksi;
- mengubah database;
- menghapus data;
- membutuhkan internet.

Jika export gagal:

```text
Gagal membuat laporan.
Silakan coba lagi.
```

Jangan tampilkan stack trace.

## 21.10 Export Architecture

Preferred flow:

```text
ReportFilter
↓
ExportDataRepository / Query
↓
ExportDocumentModel
↓
Exporter
   ├── ExcelExporter
   ├── TextExporter
   └── PdfExporter
```

Business/query logic jangan diduplikasi di setiap exporter.

Semua format harus menggunakan dataset/filter yang sama.

## 21.11 Export Accuracy

Jika laporan menunjukkan:

```text
Pemasukan: Rp8.500.000
Pengeluaran: Rp4.350.000
```

Excel, Text, dan PDF harus menghasilkan total yang sama.

Export harus mengabaikan soft-deleted transactions.

## 21.12 Export Acceptance Criteria

Export dianggap release-ready jika:

- Excel berhasil dibuat;
- Text berhasil dibuat;
- PDF berhasil dibuat;
- user dapat memilih periode;
- user dapat menggunakan custom range;
- total export sama dengan reports;
- soft deleted records tidak muncul;
- file kosong ditangani dengan baik;
- ribuan transaksi dapat diekspor tanpa crash;
- export tetap bekerja offline;
- user dapat menyimpan/membagikan hasil;
- tidak membutuhkan storage permission berlebihan.

---

# 22. Backup

Backup berbeda dengan Export.

**Backup** digunakan untuk pemulihan aplikasi.

**Export** digunakan untuk membaca, membagikan, mencetak, atau mengolah laporan.

Backup:

```text
finote_backup_YYYY-MM-DD_HH-mm.zip
```

Isi:

```text
database.sqlite
manifest.json
```

---

# 23. Restore

Flow:

```text
Pilih Backup
↓
Validate
↓
Preview
↓
Create Safety Backup
↓
Confirm
↓
Restore
↓
Verify
```

Sebelum destructive restore, safety backup wajib dibuat.

---

# 24. Legacy Import

Finote mendukung import database aplikasi Catatan Keuangan lama.

Known legacy tables:

```text
Transaction
TransactionDay
TransactionType
TransactionSubType
AppSetting
```

Mapping utama:

```text
Transaction.title → transactions.title
Transaction.amount → transactions.amount
Transaction.date → transactions.transaction_date
```

Legacy type:

```text
0 → expense
1 → income
```

`TransactionDay` tidak menjadi source of truth.

Import harus:

- read-only terhadap database legacy;
- preview sebelum import;
- menggunakan transaction;
- rollback ketika gagal;
- mencegah duplicate import;
- preserve existing Finote data.

---

# 25. Theme

Support:

```text
Ikuti Sistem
Terang
Gelap
```

Default:

```text
System
```

Theme preference harus persist.

---

# 26. Basic Security

Optional PIN:

```text
4 digit
6 digit
```

PIN tidak boleh disimpan plaintext.

Biometric optional selama tidak mengganggu core release.

---

# 27. Receipt Scanner Current Status

Receipt Scanner lokal yang sudah dibuat dapat tetap dipertahankan.

Current local pipeline:

```text
Camera / Gallery
↓
On-device OCR
↓
Local parser
↓
Receipt review
↓
User correction
↓
Explicit save
```

Rules:

- tidak boleh autosave;
- semua hasil dapat diedit;
- manual correction selalu authoritative;
- scanner harus tetap lokal;
- tidak boleh mengirim data ke AI/cloud;
- jika tidak cukup stabil untuk release, boleh disembunyikan melalui feature flag tanpa menghapus code yang sudah bekerja.

Receipt Scanner **bukan release blocker** untuk v1.0.

---

# 28. AI FEATURE FREEZE

Saat ini jangan implementasikan atau mengembangkan:

```text
AI receipt interpretation
AI receipt parsing
AI categorization
AI finance assistant
AI recommendations
OpenAI integration
Gemini integration
Claude integration
AI gateway/backend
AI subscription backend
```

Existing AI-ready abstraction boleh tetap ada hanya jika tidak menambah maintenance burden.

---

# 29. Performance Targets

Finote harus nyaman digunakan dengan:

```text
10,000+ transactions
```

Target:

- startup cepat;
- query transaksi efisien;
- report tidak memuat semua transaksi ke memory jika bisa diaggregate di database;
- export ribuan transaksi tidak membuat UI freeze;
- operasi berat menggunakan asynchronous processing bila sesuai.

---

# 30. Data Integrity Rules

1. Jangan gunakan float untuk uang.
2. Soft delete untuk transaction.
3. Database migrations harus preserve data.
4. Backup/restore harus fail safely.
5. Legacy import harus transactional.
6. Itemized receipt save harus atomic bila digunakan.
7. Export tidak boleh memodifikasi database.
8. Manual transaction tetap source utama penggunaan harian.

---

# 31. Error Handling

Jangan tampilkan error teknis seperti:

```text
SQLiteException
PlatformException
StackTrace
```

Gunakan pesan Bahasa Indonesia yang mudah dipahami.

---

# 32. Logging

Jangan log:

- nominal transaksi;
- saldo;
- note;
- raw receipt OCR;
- receipt image;
- PIN;
- token;
- private backup content.

---

# 33. Security

Jangan commit:

```text
.env
keystore
key.properties
API secrets
OAuth secrets
private backup
real receipt images
```

---

# 34. Testing Minimum

Core tests:

```text
currency formatter
balance
income
expense
transaction CRUD
category CRUD
soft delete
search/filter
report calculations
database migration
backup
restore
legacy import
duplicate import
theme persistence
```

Export tests:

```text
export query consistency
date range
income/expense filtering
Excel generation
Text generation
PDF generation
empty dataset
large dataset
soft deleted exclusion
report/export total consistency
```

Receipt tests dipertahankan hanya jika scanner tetap aktif.

---

# 35. Revised Development Roadmap

## Completed / Existing Foundation

```text
Phase 0   Foundation
Phase 1   Core Finance
Phase 2   Backup / Restore / Legacy Import
Phase 3   Personal-Use Ready
Phase 3.5 UI/UX + Theme Polish
Phase 4A-G Local Receipt Scanner Development
```

## Current Release-Focused Roadmap

```text
Phase 5A  Export Excel / Text / PDF
Phase 5B  Core Finance Audit & Stabilization
Phase 5C  Transaction UX & Workflow Hardening
Phase 5D  Reports & Financial Accuracy
Phase 5E  Backup / Restore / Legacy Migration Hardening
Phase 5F  Performance & Reliability
Phase 5G  Play Store Preparation
Phase 5H  Closed Testing
Phase 5I  Local Production Finalization v1.0.0
```

No AI development during these phases.

---

# 36. PHASE 5A — EXPORT EXCEL / TEXT / PDF

## Goal

Menjadikan export sebagai salah satu fitur utama Finote sebelum release.

Deliverables:

- Export screen/action;
- filter period;
- Excel exporter;
- Text exporter;
- PDF exporter;
- save/share;
- automated tests;
- large-data validation;
- report/export consistency.

Definition of Done:

- ketiga format berfungsi offline;
- angka konsisten dengan Reports;
- analyzer/tests pass;
- tidak ada broad storage permission.

---

# 37. PHASE 5B — CORE FINANCE AUDIT & STABILIZATION

Audit:

- CRUD;
- categories;
- dashboard;
- search;
- filters;
- reports;
- theme;
- PIN;
- startup;
- database;
- error handling.

Tidak menambah major feature.

---

# 38. PHASE 5C — TRANSACTION UX & WORKFLOW HARDENING

Pastikan common flow:

```text
Add
→ Amount
→ Category
→ Save
```

cepat dan stabil.

Audit:

- keyboard;
- autofocus;
- IDR formatting;
- category picker;
- edit mode;
- save state;
- double-submit;
- small Android screens.

---

# 39. PHASE 5D — REPORTS & FINANCIAL ACCURACY

Pastikan:

```text
Dashboard
=
Transactions
=
Reports
=
Exports
```

untuk filter/periode yang sama.

Audit:

- day;
- week;
- month;
- custom;
- income;
- expense;
- category breakdown;
- soft delete.

---

# 40. PHASE 5E — BACKUP / RESTORE / LEGACY HARDENING

Audit failure paths:

- corrupt backup;
- incompatible version;
- failed restore;
- safety backup;
- invalid legacy DB;
- duplicate import;
- partial failure;
- rollback.

Data loss adalah blocker release.

---

# 41. PHASE 5F — PERFORMANCE & RELIABILITY

Target:

```text
10,000+ transactions
```

Test:

- scrolling;
- search;
- filter;
- report;
- export;
- backup;
- startup.

Optimasi berdasarkan measurement, bukan asumsi.

---

# 42. PHASE 5G — PLAY STORE PREPARATION

Siapkan:

- final product name;
- application ID;
- version;
- adaptive icon;
- splash;
- Android App Bundle;
- signing;
- privacy policy;
- Data Safety;
- permission audit;
- release configuration.

Build:

```text
.aab
```

Gunakan Google Play App Signing.

---

# 43. PHASE 5H — CLOSED TESTING

Flow:

```text
Internal Testing
↓
Closed Testing
↓
Collect Feedback
↓
Fix Blockers
```

Tidak menambah fitur baru selama closed testing kecuali benar-benar diperlukan.

---

# 44. PHASE 5I — LOCAL PRODUCTION FINAL / PLAY STORE READY v1.0

Final local production milestone before public release.

The goal of this phase is to ensure Finote is fully stable, production-ready, and prepared for future Play Store publication without requiring immediate release.

Required core features:

```text
Transaction CRUD
Categories
Dashboard
Transaction History
Search
Filter
Reports
Excel Export
Text Export
PDF Export
Backup
Restore
Legacy Import
Theme System
Basic Security
Offline Usage
```

Receipt Scanner:

```text
Optional for v1.0 depending on stability
```

AI:

```text
NOT INCLUDED
```

Release readiness requirements:

```text
Final feature audit completed
No critical bugs
Database migration verified
Backup and restore verified
Legacy import verified
Export features verified
Offline usage verified
Flutter analyze passed
Automated tests passed
Release APK successfully built
Release AAB successfully built
Production signing configured
Version set to 1.0.0+1
Documentation finalized
Release commit created
Git tag v1.0.0 created
```

Final status:

```text
Finote v1.0.0
Local Production Final
Play Store Ready
Not Yet Publicly Released
```

This phase does NOT include:

```text
Google Play Console submission
Public production rollout
Play Store review process
Post-release user monitoring
Subscription system
Cloud backend
AI features
```

After Phase 5I is completed, Finote can remain as a finalized local production build and be published to the Google Play Store later without changing the v1.0 core scope unless a critical issue is discovered.

---

# 45. v1.0 Acceptance Criteria

Finote siap `v1.0.0` jika:

- transaksi manual stabil;
- financial totals akurat;
- category management stabil;
- dashboard konsisten;
- search/filter benar;
- reports benar;
- **Excel export benar;**
- **Text export benar;**
- **PDF export benar;**
- export sama dengan report;
- backup bekerja;
- restore bekerja;
- legacy import bekerja;
- duplicate import aman;
- migrations aman;
- theme Light/Dark/System bekerja;
- tidak ada critical data-loss bug;
- tidak ada blocker crash;
- permission minimal;
- privacy policy tersedia;
- Data Safety akurat;
- `.aab` berhasil dibuat;
- closed testing selesai.

---

# 46. Feature Priority

Prioritas produk saat ini:

```text
1. Data Integrity
2. Transaction CRUD
3. Categories
4. Transaction Entry UX
5. Dashboard
6. Search / Filter
7. Reports
8. Export Excel
9. Export Text
10. Export PDF
11. Backup
12. Restore
13. Legacy Import
14. Theme / Basic Security
15. Performance
16. Play Store Release
17. Real User Feedback
```

Receipt Scanner berada di luar release-critical core.

AI tidak termasuk prioritas saat ini.

---

# 47. Post-v1 Roadmap

Setelah aplikasi memiliki pengguna nyata, evaluasi berdasarkan feedback.

Possible features:

```text
Wallet / Accounts
Budget
Recurring Transactions
Cloud Backup
Advanced Reports
Cloud Sync
```

Jangan otomatis membangun semuanya.

Setiap feature harus divalidasi.

---

# 48. AI Reconsideration Gate

AI hanya boleh dibuka kembali jika:

```text
Play Store release ✓
Real users ✓
Validated AI demand ✓
API/server budget ✓
Privacy design ✓
Premium/subscription strategy ✓
```

Baru pertimbangkan:

```text
AI Receipt Interpretation
AI Categorization
AI Financial Assistant
```

---

# 49. Core Product Differentiators

## Simple

Cepat mencatat transaksi manual.

## Offline First

Core finance tidak bergantung internet.

## Data Ownership

Backup, restore, legacy migration.

## Data Portability

Excel, Text, dan PDF export menjadi fitur utama.

## Reliable

Kebenaran data lebih penting daripada banyak fitur.

---

# 50. Long-Term Architecture

```text
                    OPTIONAL FUTURE SERVICES
                           │
                  ┌────────┴────────┐
                  │                 │
            Cloud Backup      Cloud Sync
                  ▲                 ▲
                  │                 │
                  └────────┬────────┘
                           │
                    SQLite / Drift
                           ▲
          ┌────────────────┼────────────────┐
          │                │                │
     Manual Input        Reports          Export
          │                │         ┌──────┼──────┐
          │                │         │      │      │
          │                │       Excel   Text    PDF
          │                │
          └──────────── Core Finance ───────┘
```

Receipt Scanner tetap modul optional dan local-only jika dipertahankan.

---

# 51. Golden Rules

## Rule 1

Never risk financial data.

## Rule 2

Manual transaction workflow must always work offline.

## Rule 3

Derived totals must come from source transactions.

## Rule 4

Backup is for recovery; export is for portability/reporting. Do not mix them.

## Rule 5

Excel, Text, dan PDF harus menghasilkan data yang konsisten.

## Rule 6

Cloud remains optional.

## Rule 7

AI remains deferred until validated.

## Rule 8

Do not make Finote complicated simply because more features are technically possible.

---

# 52. Final Product Direction

Target Finote sekarang adalah:

> **Modern Offline-First Personal Finance Tracker focused on reliable manual finance management and strong data portability.**

Pengalaman utama:

```text
Catat transaksi
↓
Lihat kondisi keuangan
↓
Cari / filter
↓
Lihat laporan
↓
Export Excel / Text / PDF
↓
Backup data dengan aman
```

Finote harus terlebih dahulu menjadi aplikasi keuangan manual yang matang dan dapat dipercaya.

AI, cloud sync, dan fitur kompleks hanya dikembangkan setelah kebutuhan nyata pengguna membuktikannya.
