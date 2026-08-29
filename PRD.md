# PRODUCT REQUIREMENTS DOCUMENT

# Catatan Keuangan

## Modern Offline-First Personal Finance Tracker

---

# 1. Product Information

**Working Name:** Catatan Keuangan

**Platform awal:** Android

**Future Platform:**

* Android
* iOS jika dibutuhkan

**Framework:** Flutter

**Primary Architecture:** Offline-first

**Local Database:** SQLite + Drift

**State Management:** Riverpod

**Routing:** GoRouter

**UI System:** Material Design 3

**Primary Language UI:** Bahasa Indonesia

**Target Distribution:** Google Play Store

**Cloud:** Optional

**Primary User:** Pengguna individu

---

# 2. Product Background

Aplikasi ini dikembangkan sebagai penerus modern dari aplikasi pencatatan keuangan lama yang sudah tidak aktif dikembangkan.

Aplikasi lama memiliki kelebihan utama:

* sederhana;
* cepat;
* tidak membutuhkan akun;
* dapat digunakan offline;
* pencatatan pemasukan dan pengeluaran mudah;
* memiliki kategori;
* memiliki laporan;
* mendukung backup database.

Kelemahan yang ingin diperbaiki:

* aplikasi tidak lagi dikembangkan;
* tampilan sudah tertinggal;
* kompatibilitas dengan Android masa depan tidak terjamin;
* tidak memiliki sinkronisasi modern;
* backup masih manual;
* tidak memiliki fitur scan struk;
* pengelolaan data belum fleksibel;
* tidak memiliki kemampuan multi-device.

Aplikasi baru mempertahankan kesederhanaan aplikasi lama namun dengan arsitektur modern.

---

# 3. Product Vision

Membangun aplikasi keuangan pribadi yang:

> sederhana untuk digunakan setiap hari, dapat berjalan tanpa internet, menjaga kepemilikan data pengguna, mampu memigrasikan data aplikasi lama, dan secara bertahap berkembang menjadi personal finance tracker modern.

Aplikasi harus terasa seperti:

```text
Buku Catatan Keuangan
+
Kalkulator
+
Laporan
+
Scanner Struk
+
Backup Modern
```

bukan seperti aplikasi accounting kompleks.

---

# 4. Product Principles

Prinsip utama:

1. Offline-first.
2. Cepat digunakan.
3. Tidak wajib login.
4. Data milik pengguna.
5. Data mudah dibackup.
6. Data mudah dipindahkan.
7. Cloud optional.
8. Fitur tidak boleh membuat aplikasi terasa rumit.
9. Data integrity lebih penting daripada jumlah fitur.
10. Pengguna harus tetap bisa menggunakan aplikasi meskipun layanan cloud tidak tersedia.

---

# 5. Primary Goals

Aplikasi harus memungkinkan pengguna:

* mencatat pengeluaran;
* mencatat pemasukan;
* melihat saldo;
* melihat histori transaksi;
* mengelola kategori;
* melihat laporan;
* mencari transaksi;
* backup data;
* restore data;
* import database aplikasi lama;
* scan struk belanja;
* menghasilkan draft transaksi dari struk;
* menggunakan aplikasi tanpa internet.

---

# 6. Secondary Goals

Setelah fitur inti stabil:

* multiple wallet;
* budgeting;
* recurring transaction;
* Google Drive backup;
* advanced reports;
* optional account;
* multi-device sync;
* attachment struk;
* OCR yang semakin pintar.

---

# 7. Non Goals

Versi awal bukan:

* aplikasi accounting perusahaan;
* ERP;
* aplikasi invoice;
* aplikasi perpajakan;
* aplikasi kasir;
* aplikasi pembayaran;
* aplikasi perbankan;
* aplikasi investasi;
* aplikasi cryptocurrency;
* aplikasi pembukuan double-entry.

---

# 8. Target Users

Target utama:

Pengguna Android yang ingin mencatat aktivitas finansial pribadi.

Contoh kebutuhan:

```text
Makan
Bensin
Belanja
Gaji
Bonus
Tagihan
Internet
Transportasi
Hiburan
```

Karakteristik:

* ingin aplikasi sederhana;
* tidak ingin banyak menu;
* ingin bisa offline;
* ingin data aman;
* ingin backup;
* ingin laporan mudah dipahami;
* terkadang malas mengetik struk satu per satu.

---

# 9. Main Navigation

Bottom navigation:

```text
Home
Transactions
Reports
Settings
```

Floating button:

```text
+
```

Default action:

```text
Tambah Transaksi
```

Tambahkan shortcut:

```text
Scan Struk
```

setelah Receipt Scanner tersedia.

---

# 10. Main User Flow

## Manual transaction

```text
Buka aplikasi
↓
+
↓
Pilih Pengeluaran / Pemasukan
↓
Masukkan nominal
↓
Pilih kategori
↓
Simpan
```

---

## Receipt transaction

```text
Buka aplikasi
↓
Scan Struk
↓
Foto / pilih gambar
↓
OCR
↓
Parsing
↓
Draft transaksi
↓
User review
↓
Simpan
```

---

# 11. Technical Stack

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

Recommended supporting packages:

```text
uuid
intl
freezed
json_serializable
path_provider
file_picker
image_picker
```

Untuk OCR dipilih ketika fitur Receipt Scanner dikerjakan.

Prioritas:

```text
on-device OCR
```

jika kualitas mencukupi.

---

# 12. Project Architecture

Gunakan:

```text
Feature First Architecture
```

Struktur:

```text
lib/

app/
  app.dart
  router.dart

core/
  database/
  errors/
  extensions/
  services/
  theme/
  utils/

features/

  dashboard/
  transactions/
  categories/
  reports/
  settings/
  backup/
  legacy_import/
  receipt_scanner/
  accounts/
  budgets/
  recurring/
  sync/
```

Setiap feature dapat memiliki:

```text
data/
domain/
presentation/
```

Tidak perlu membuat Clean Architecture terlalu kompleks.

---

# 13. Development Roadmap

Urutan utama:

```text
PHASE 0
Foundation

PHASE 1
Core Finance

PHASE 2
Backup / Restore / Legacy Import

PHASE 3
Personal-Use Ready

PHASE 4
Receipt Scanner & Auto Transaction

PHASE 5
Play Store Ready

PHASE 6
Wallet

PHASE 7
Budget

PHASE 8
Recurring Transactions

PHASE 9
Cloud Backup

PHASE 10
Advanced Reports

PHASE 11
Cloud Sync
```

---

# PHASE 0 — FOUNDATION

## Goal

Membangun pondasi project.

Tidak ada business feature besar.

---

# 14. Flutter Setup

Setup:

```text
Flutter stable
Material 3
Riverpod
GoRouter
Drift
SQLite
```

---

# 15. Project Structure

Buat struktur feature-first.

---

# 16. Theme

Support:

```text
Light
Dark
System
```

---

# 17. Localization Foundation

Initial:

```text
Bahasa Indonesia
```

Arsitektur tidak boleh menghalangi penambahan bahasa lain.

---

# 18. Utility

Siapkan:

* IDR formatter;
* date formatter;
* UUID generator;
* logging wrapper;
* error mapper.

---

# PHASE 1 — CORE FINANCE

## Goal

Menghasilkan aplikasi pencatatan keuangan yang benar-benar bisa digunakan.

Ini prioritas tertinggi.

---

# 19. Database Tables

Minimum:

```text
transactions
categories
settings
```

---

# 20. Transaction Schema

```text
transactions

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

---

# 21. Transaction Source

Tambahkan:

```text
source
```

Possible values:

```text
manual
legacy_import
receipt_scan
recurring
```

Ini akan berguna di kemudian hari.

---

# 22. Amount

Uang harus disimpan sebagai:

```text
INTEGER
```

Contoh:

```text
Rp25.000
```

disimpan:

```text
25000
```

Jangan menggunakan:

```text
double
float
```

---

# 23. UUID

Setiap transaction dan category memiliki UUID.

---

# 24. Soft Delete

Gunakan:

```text
deleted_at
```

---

# 25. Categories

Category schema:

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

---

# 26. Default Categories

Expense:

```text
Makanan & Minuman
Transportasi
Belanja
Tagihan
Hiburan
Kesehatan
Pendidikan
Rumah
Keluarga
Lainnya
```

Income:

```text
Gaji
Bonus
Bisnis
Hadiah
Investasi
Lainnya
```

---

# 27. Add Transaction

Form:

```text
Pengeluaran | Pemasukan

Nominal

Kategori

Judul

Tanggal

Catatan
```

Default:

```text
type = expense
date = today
```

Note optional.

---

# 28. Transaction UX

Prioritaskan:

```text
Cepat
Sedikit input
Minim tap
```

Ideal:

```text
+
↓
Nominal
↓
Kategori
↓
Simpan
```

---

# 29. Edit Transaction

Semua field dapat diedit.

---

# 30. Delete Transaction

Gunakan soft delete.

Confirmation:

```text
Hapus transaksi?
```

---

# 31. Transaction List

Group berdasarkan tanggal.

Contoh:

```text
29 Agustus 2026

Bensin
Transportasi
-Rp50.000

Gaji
Gaji
+Rp8.500.000
```

---

# 32. Filters

Support:

```text
Semua
Pemasukan
Pengeluaran
```

Period:

```text
Hari Ini
Minggu Ini
Bulan Ini
Custom
```

---

# 33. Search

Cari menggunakan:

```text
title
note
category
```

---

# 34. Dashboard

Tampilkan:

```text
Saldo

Pemasukan

Pengeluaran
```

Default:

```text
bulan berjalan
```

---

# 35. Balance

Formula:

```text
Total Income - Total Expense
```

Saldo tidak disimpan secara terpisah.

---

# 36. Recent Transactions

Tampilkan 5–10 transaksi terbaru.

---

# 37. Reports

Minimum:

```text
Total pemasukan
Total pengeluaran
Saldo periode
Top expense category
Top income category
Monthly history
```

---

# 38. Period Reports

Support:

```text
Hari
Minggu
Bulan
Custom
```

---

# 39. Settings

Minimum:

```text
Kategori
Mata Uang
Tema
Data
Keamanan
Tentang
```

---

# PHASE 2 — BACKUP / RESTORE / LEGACY IMPORT

## Goal

Menjamin data pengguna dapat dipindahkan dan dipulihkan.

---

# 40. Local Backup

User dapat membuat:

```text
finance_backup_YYYY-MM-DD.zip
```

---

# 41. Backup Structure

Isi:

```text
database.sqlite
manifest.json
```

---

# 42. Backup Manifest

Contoh:

```json
{
  "application": "Catatan Keuangan",
  "backupVersion": 1,
  "databaseVersion": 1,
  "createdAt": "...",
  "appVersion": "..."
}
```

---

# 43. Restore

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
Restore
↓
Verify
```

---

# 44. Safety Backup

Sebelum restore:

```text
pre_restore_backup
```

wajib dibuat.

---

# 45. Legacy Import

Support database aplikasi lama.

Legacy tables diketahui antara lain:

```text
Transaction
TransactionDay
TransactionType
TransactionSubType
AppSetting
```

---

# 46. Legacy Transaction Mapping

```text
Transaction.title
→ transactions.title
```

```text
Transaction.amount
→ transactions.amount
```

```text
Transaction.date
→ transaction_date
```

---

# 47. Legacy Type

```text
0 = expense
1 = income
```

Convert ke internal enum.

---

# 48. Legacy Categories

Gunakan:

```text
Transaction.subType
```

dan:

```text
TransactionSubType
```

---

# 49. TransactionDay

Jangan jadikan:

```text
TransactionDay
```

sebagai source of truth.

Report harus dihitung ulang dari transactions.

---

# 50. Legacy Import Preview

Tampilkan sebelum import:

```text
Jumlah transaksi

Jumlah kategori

Rentang tanggal

Total pemasukan

Total pengeluaran
```

---

# 51. Duplicate Protection

Gunakan:

```text
legacy_source
legacy_id
```

Combination harus dapat mencegah duplicate import.

---

# 52. Legacy Import Transaction

Import harus menggunakan SQLite database transaction.

Jika gagal:

```text
rollback
```

---

# PHASE 3 — PERSONAL-USE READY

## Goal

Pada fase ini aplikasi harus sudah nyaman digunakan sehari-hari secara pribadi.

Ini adalah milestone penting.

Target:

> Jika cloud, budget dan wallet belum ada sekalipun, aplikasi sudah layak menggantikan aplikasi lama.

---

# 53. Personal-Use Acceptance Criteria

Wajib sudah tersedia:

```text
Transaction CRUD
Categories
Dashboard
Reports
Search
Filter
Backup
Restore
Legacy Import
Theme
Basic Security
```

---

# 54. PIN

Support:

```text
4 digit
atau
6 digit
```

PIN tidak boleh disimpan plaintext.

---

# 55. Biometric

Optional pada tahap ini.

Support jika mudah:

```text
Fingerprint
Face authentication
```

---

# 56. UX Polish

Perbaiki:

* keyboard flow;
* input nominal;
* empty state;
* loading state;
* error state;
* confirmation;
* snackbar;
* responsive layout.

---

# 57. Performance Target

Aplikasi harus nyaman dengan:

```text
10.000+ transaksi
```

---

# 58. Internal Personal Test

Gunakan aplikasi secara nyata minimal beberapa hari.

Catat:

```text
makan
bensin
belanja
gaji
tagihan
```

Perbaiki UX sebelum masuk scanner.

---

# PHASE 4 — RECEIPT SCANNER & AUTO TRANSACTION

## Goal

Memungkinkan pengguna membuat transaksi pengeluaran dengan memfoto struk.

Fase ini dilakukan setelah aplikasi dasar sudah nyaman digunakan secara pribadi.

Bukan fitur paling akhir.

---

# 59. Scanner Entry Point

Tambahkan:

```text
Scan Struk
```

pada:

* dashboard;
* add transaction menu;
* transaction page.

---

# 60. Receipt Flow

```text
Scan Struk
↓
Camera / Gallery
↓
Image preprocessing
↓
OCR
↓
Receipt parsing
↓
Transaction draft
↓
User review
↓
Save
```

---

# 61. Mandatory Safety Rule

JANGAN langsung menyimpan hasil OCR.

Selalu:

```text
OCR
↓
Draft
↓
User Confirmation
↓
Save
```

---

# 62. Supported Input

Support:

```text
Camera
Gallery
```

---

# 63. Camera Screen

Berikan guidance:

```text
Pastikan seluruh struk terlihat

Gunakan pencahayaan yang cukup

Hindari gambar blur

Letakkan struk di permukaan datar
```

---

# 64. Image Preprocessing

Future support:

```text
Auto crop
Perspective correction
Rotate
Contrast enhancement
Noise reduction
```

Minimum implementation tidak harus semuanya sekaligus.

---

# 65. OCR Service

Gunakan abstraction.

Contoh:

```dart
abstract class ReceiptOcrService {
  Future<ReceiptOcrResult> recognize(...);
}
```

Tujuan:

OCR provider mudah diganti.

---

# 66. OCR Preference

Prioritas:

```text
On-device OCR
```

karena:

* offline;
* privacy;
* tidak ada API cost;
* lebih cepat;
* lebih cocok dengan product principle.

---

# 67. Future OCR Providers

Architecture harus memungkinkan:

```text
Google ML Kit
Cloud Vision
AI Vision API
Other OCR engines
```

tanpa mengubah transaction module.

---

# 68. OCR Result

OCR layer menghasilkan:

```text
raw text
text blocks
confidence
bounding data jika tersedia
```

---

# 69. Receipt Parser

Pisahkan OCR dengan parser.

OCR:

```text
gambar → text
```

Parser:

```text
text → receipt data
```

---

# 70. Receipt Data Model

Contoh:

```text
merchant

transaction_date

subtotal

tax

discount

total

payment_method

receipt_number

items

raw_text
```

---

# 71. Minimum Detection

Versi pertama scanner minimal mencoba mendeteksi:

```text
Merchant
Tanggal
Total
```

Jika memungkinkan:

```text
Subtotal
Pajak
Diskon
```

---

# 72. Receipt Items

Optional pada scanner versi pertama.

Jika berhasil:

```text
Air Mineral Rp8.000
Roti Rp15.500
Sabun Rp22.000
```

Tetapi transaksi utama tetap menggunakan:

```text
total receipt
```

---

# 73. Auto Transaction Draft

Contoh:

```text
Type:
Expense

Amount:
87500

Title:
Indomaret

Date:
29 Aug 2026

Category:
Belanja

Source:
receipt_scan
```

---

# 74. Category Suggestion

Aplikasi mencoba memberikan kategori otomatis.

Urutan:

```text
Merchant mapping
↓
Keyword matching
↓
Previous user history
↓
Fallback category
```

---

# 75. Merchant Mapping

Contoh:

```text
PERTAMINA
→ Transportasi
```

```text
INDOMARET
→ Belanja
```

```text
KFC
→ Makanan & Minuman
```

---

# 76. Local Merchant Learning

Jika user mengubah:

```text
Merchant: Indomaret

Suggested:
Belanja

User:
Makanan & Minuman
```

Aplikasi dapat menyimpan preferensi lokal:

```text
Indomaret
→ Makanan & Minuman
```

untuk scan selanjutnya.

---

# 77. Merchant Mapping Schema

Future:

```text
merchant_mappings

id
merchant_pattern
category_id
usage_count
created_at
updated_at
```

---

# 78. Confidence

Jika OCR mendukung confidence, gunakan.

Contoh:

```text
Merchant 98%

Date 91%

Total 99%
```

Field confidence rendah diberi indicator.

---

# 79. User Review Screen

Screen wajib memperlihatkan:

```text
Foto struk

Merchant

Total

Tanggal

Kategori

Catatan

Detected items jika tersedia
```

Semua editable.

---

# 80. Total Safety

Nominal merupakan field paling kritis.

Jika confidence rendah:

```text
Periksa nominal transaksi
```

harus terlihat jelas.

---

# 81. Duplicate Receipt Detection

Gunakan kombinasi:

```text
merchant
date
amount
receipt_number
```

jika tersedia.

Jika kemungkinan duplicate:

```text
Transaksi serupa sudah tersedia.
```

User dapat:

```text
Batal

Tetap Simpan
```

---

# 82. Receipt Image Storage

Default:

```text
Tidak disimpan permanen
```

Setelah transaksi disimpan, temporary image dibersihkan.

---

# 83. Save Receipt Optional

User dapat mengaktifkan:

```text
Simpan foto struk
```

---

# 84. Attachments Schema

Jika image disimpan:

```text
attachments

id
uuid
transaction_id

type

local_path

mime_type

created_at
updated_at
deleted_at
```

Type:

```text
receipt
```

---

# 85. Receipt Privacy

Receipt dapat mengandung:

```text
nama
alamat
nomor transaksi
nomor kartu parsial
detail pembelian
```

Karena itu:

* jangan upload otomatis;
* jangan analytics raw text;
* jangan log OCR result;
* jangan simpan image tanpa persetujuan;
* cloud OCR harus membutuhkan informed consent.

---

# 86. Offline Scanner

Target utama:

```text
scanner dapat bekerja offline
```

jika OCR provider memungkinkan.

---

# 87. Scanner Failure

Jika gagal membaca:

```text
Struk belum berhasil dibaca.
```

Berikan:

```text
Coba Lagi

Isi Manual
```

---

# 88. Scanner Acceptance Criteria

Scanner dianggap versi pertama selesai ketika:

* camera dapat mengambil struk;
* gallery dapat memilih gambar;
* OCR berjalan;
* merchant dicoba dideteksi;
* tanggal dicoba dideteksi;
* total dicoba dideteksi;
* draft transaction dibuat;
* category suggestion tersedia;
* semua field editable;
* user confirmation wajib;
* transaction tersimpan sebagai `receipt_scan`;
* kegagalan tidak menyebabkan crash.

---

# 89. Scanner V2

Setelah versi pertama:

```text
item extraction
smart category
multi category
receipt archive
search receipt
warranty tracking
AI parsing
```

---

# PHASE 5 — PLAY STORE READY

## Goal

Menyiapkan aplikasi untuk distribusi publik.

---

# 90. Android App Identity

Siapkan:

```text
App Name
Application ID
Adaptive icon
Splash screen
Version
```

---

# 91. Production Package

Gunakan:

```text
.aab
```

---

# 92. App Signing

Gunakan:

```text
Google Play App Signing
```

---

# 93. Permissions

Gunakan minimum permission.

Receipt camera meminta:

```text
camera
```

hanya ketika diperlukan.

File selection menggunakan system picker.

---

# 94. Privacy Policy

Privacy Policy harus menjelaskan:

* local financial data;
* receipt scanning;
* camera usage;
* backup;
* optional cloud;
* analytics jika ada;
* crash reporting jika ada.

---

# 95. Play Store Data Safety

Data Safety harus sesuai implementasi sebenarnya.

Tidak boleh mengatakan:

```text
Data tidak dikirim
```

jika nanti cloud OCR memang digunakan.

---

# 96. Crash Reporting

Optional:

```text
Firebase Crashlytics
```

Jangan kirim:

```text
transaction amount
title
receipt text
receipt image
balance
```

ke crash logs.

---

# 97. Analytics

Jika digunakan, batasi:

```text
screen_open
feature_used
scan_started
scan_completed
```

Jangan kirim financial values.

---

# 98. Testing

Sebelum production:

```text
Unit Test
Database Test
Widget Test
Importer Test
Scanner Test
Migration Test
```

---

# 99. Play Store Testing Flow

```text
Internal Testing
↓
Closed Testing
↓
Production
```

---

# PHASE 6 — WALLET / ACCOUNT

---

# 100. Accounts

User dapat membuat:

```text
Cash
BCA
Mandiri
BRI
GoPay
DANA
OVO
```

---

# 101. Account Schema

```text
accounts

id
uuid
name
type
initial_balance
icon
created_at
updated_at
deleted_at
```

---

# 102. Transaction Account

Tambahkan:

```text
account_id
```

ke transaction.

---

# 103. Transfer

Type:

```text
transfer
```

Contoh:

```text
BCA
→
GoPay
```

Transfer tidak dihitung sebagai expense.

---

# PHASE 7 — BUDGET

---

# 104. Budget

Contoh:

```text
Makanan

Rp1.500.000 / bulan
```

---

# 105. Budget Progress

Contoh:

```text
Rp1.200.000 / Rp1.500.000

80%
```

---

# 106. Budget Alert

Optional.

Contoh:

```text
Pengeluaran makanan sudah mencapai 80%.
```

---

# PHASE 8 — RECURRING TRANSACTIONS

---

# 107. Recurring Income

Contoh:

```text
Gaji

Rp8.500.000

Tanggal 1
```

---

# 108. Recurring Expense

Contoh:

```text
Internet

Rp350.000

Tanggal 10
```

---

# 109. Default Behavior

Default:

```text
Reminder only
```

Jangan otomatis membuat transaksi tanpa user setting.

---

# PHASE 9 — CLOUD BACKUP

---

# 110. Google Drive Backup

Flow:

```text
SQLite
↓
Backup
↓
Encrypt
↓
Google Drive
```

---

# 111. Cloud Backup vs Sync

Cloud backup:

```text
backup file
```

Cloud sync:

```text
record synchronization
```

Jangan mencampurkan kedua konsep.

---

# 112. Backup Encryption

Target:

```text
AES-256
```

---

# 113. Automatic Backup

Options:

```text
Off
Daily
Weekly
Monthly
```

---

# PHASE 10 — ADVANCED REPORTS

---

# 114. Cash Flow Chart

Income vs Expense.

---

# 115. Expense Trend

Monthly trend.

---

# 116. Category Chart

Breakdown berdasarkan kategori.

---

# 117. Comparison

Contoh:

```text
Agustus vs Juli
```

---

# 118. Merchant Analytics

Setelah receipt scanner cukup banyak digunakan:

```text
Pengeluaran Indomaret

Pengeluaran Pertamina

Pengeluaran restoran
```

---

# PHASE 11 — CLOUD SYNC & MULTI DEVICE

---

# 119. Optional User Account

Core app tetap bisa digunakan tanpa login.

Optional:

```text
Email

Google
```

---

# 120. Cloud Architecture

Future:

```text
Flutter
↓
SQLite / Drift
↕
Sync Engine
↕
Supabase
↓
PostgreSQL
```

---

# 121. Sync Metadata

Records memiliki:

```text
uuid
created_at
updated_at
deleted_at
sync_status
```

---

# 122. Sync Status

```text
pending
synced
failed
```

---

# 123. Conflict

Initial strategy:

```text
Last Modified Wins
```

Dapat diperbaiki setelah kebutuhan nyata ditemukan.

---

# 124. Multi Device

Support future:

```text
Phone
Tablet
Second Phone
```

---

# 125. Database Migration

Setiap perubahan schema setelah aplikasi digunakan harus:

```text
increase schema version
+
provide migration
```

Jangan menghancurkan data lama.

---

# 126. Database Indexes

Minimal:

```text
transaction_date

category_id

type

deleted_at

legacy_source + legacy_id
```

---

# 127. Error Handling

Jangan tampilkan technical error.

Contoh buruk:

```text
SQLiteException
```

Contoh benar:

```text
Gagal menyimpan transaksi.
Silakan coba lagi.
```

---

# 128. Logging

Jangan log:

```text
nominal
saldo
receipt raw text
receipt image
transaction note
access token
```

---

# 129. Security

Jangan commit:

```text
.env
keystore
key.properties
API secrets
OAuth secrets
```

---

# 130. Automated Testing

Minimum:

```text
currency formatter
balance
income
expense
transaction CRUD
category CRUD
soft delete
database migration
backup
restore
legacy mapping
duplicate import
receipt parser
receipt amount detection
receipt date detection
receipt duplicate detection
```

---

# 131. Receipt Parser Tests

Siapkan sample dummy receipt texts.

Contoh:

```text
INDOMARET

29/08/2026

AIR MINERAL 8.000

ROTI 15.500

TOTAL 23.500
```

Expected:

```text
merchant = Indomaret

date = 29 Aug 2026

total = 23500
```

---

# 132. Real Receipt Privacy Testing

Jangan commit struk asli yang mengandung data pribadi ke public repository.

Gunakan:

```text
dummy receipt
synthetic receipt
redacted receipt
```

untuk automated tests.

---

# 133. Performance

Target penggunaan:

```text
10.000+
transactions
```

Scanner tidak boleh membekukan UI.

OCR dilakukan asynchronously.

---

# 134. Version Roadmap

## v0.1.0

Foundation.

---

## v0.2.0

Category + transaction database.

---

## v0.3.0

Transaction CRUD.

---

## v0.4.0

Dashboard + history.

---

## v0.5.0

Reports + search/filter.

Pada titik ini aplikasi sudah dapat digunakan dasar.

---

## v0.6.0

Backup + restore.

---

## v0.7.0

Legacy database import.

---

## v0.8.0

Security + UX polish.

Pada titik ini:

> aplikasi sudah layak digunakan pribadi.

---

## v0.9.0

Receipt Scanner V1.

Support:

```text
camera
gallery
OCR
merchant
date
total
category suggestion
transaction draft
```

---

## v0.10.0

Receipt scanner polish + testing.

---

## v0.11.0

Play Store preparation.

---

## v1.0.0

First Play Store release.

Fitur:

```text
Transaction CRUD

Categories

Dashboard

Reports

Search

Filter

Backup

Restore

Legacy Import

PIN

Theme

Receipt Scanner

Auto Transaction Draft
```

---

## v1.1.0

Wallet.

---

## v1.2.0

Budget.

---

## v1.3.0

Recurring.

---

## v1.4.0

Google Drive backup.

---

## v1.5.0

Advanced reports.

---

## v2.0.0

Cloud sync / multi device.

---

# 135. Personal-Use Milestone

Milestone pertama yang benar-benar penting adalah:

```text
v0.8.0
```

Di sini aplikasi sudah bisa menggantikan aplikasi lama untuk penggunaan sehari-hari.

---

# 136. Intelligent-Input Milestone

Milestone berikutnya:

```text
v0.9.0
```

Di sini user tidak hanya dapat mengetik transaksi manual, tetapi sudah bisa:

```text
Foto struk
↓
Auto baca
↓
Review
↓
Save
```

Ini menjadi salah satu fitur unggulan aplikasi.

---

# 137. First Public Release

Target:

```text
v1.0.0
```

Receipt Scanner sudah termasuk.

Artinya versi pertama yang masuk Play Store bukan hanya clone sederhana, tetapi sudah memiliki differentiator nyata.

---

# 138. MVP Acceptance Criteria

Core MVP selesai ketika:

* transaksi dapat dibuat;
* transaksi dapat diedit;
* transaksi dapat dihapus;
* kategori dapat dikelola;
* dashboard benar;
* laporan benar;
* search bekerja;
* filter bekerja;
* data tetap tersimpan;
* aplikasi bisa offline.

---

# 139. Personal-Use Acceptance Criteria

Layak digunakan pribadi ketika:

* semua MVP selesai;
* backup bekerja;
* restore bekerja;
* legacy import bekerja;
* duplicate import aman;
* PIN tersedia;
* UX nyaman;
* tidak ada data-loss bug.

---

# 140. Receipt Scanner Acceptance Criteria

Receipt Scanner V1 selesai ketika:

* kamera bekerja;
* gallery bekerja;
* OCR berjalan;
* merchant terdeteksi jika memungkinkan;
* tanggal terdeteksi jika memungkinkan;
* total terdeteksi;
* transaction draft terbentuk;
* category suggestion tersedia;
* user dapat mengedit;
* user wajib mengonfirmasi;
* transaksi tersimpan;
* source tercatat sebagai receipt_scan;
* scanner tetap aman ketika OCR gagal.

---

# 141. Play Store Acceptance Criteria

Ready production ketika:

* personal-use milestone stabil;
* receipt scanner stabil;
* migration diuji;
* backup/restore diuji;
* crash blocker tidak ada;
* permission minimal;
* privacy policy tersedia;
* Data Safety akurat;
* production signing siap;
* `.aab` dapat dibangun;
* closed testing dilakukan.

---

# 142. Feature Priority

Urutan implementasi:

```text
1. Database
2. Categories
3. Transaction CRUD
4. Transaction History
5. Dashboard
6. Reports
7. Search / Filter
8. Backup
9. Restore
10. Legacy Import
11. Security
12. UX Polish
13. Receipt Scanner
14. Receipt Parser
15. Auto Transaction Draft
16. Play Store Preparation
17. Wallet
18. Budget
19. Recurring
20. Cloud Backup
21. Cloud Sync
```

---

# 143. Do Not Implement Too Early

Jangan prioritaskan:

```text
Supabase

Cloud sync

Multi-device

Advanced budget

Complex analytics
```

sebelum:

```text
manual transaction

backup

legacy migration

receipt scanner
```

stabil.

---

# 144. Core Product Differentiators

Aplikasi nantinya memiliki empat keunggulan utama:

## Simple

Cepat mencatat transaksi.

## Offline First

Tidak tergantung internet.

## Data Portability

Backup, restore, import legacy.

## Smart Input

Scan struk menjadi draft transaksi otomatis.

---

# 145. Long-Term Architecture

```text
                         Optional Cloud
                              │
             ┌────────────────┴────────────────┐
             │                                 │
      Google Drive                        Supabase
         Backup                              Sync
             ▲                                 ▲
             │                                 │
             │                                 │
      ┌──────┴─────────────────────────────────┴─────┐
      │                                            │
      │               SQLite / Drift               │
      │                                            │
      └──────────────▲──────────────────▲───────────┘
                     │                  │
                     │                  │
               Manual Input       Receipt Scanner
                                        │
                                        ▼
                                      OCR
                                        │
                                        ▼
                                Receipt Parser
                                        │
                                        ▼
                               Transaction Draft
                                        │
                                        ▼
                                  User Confirm
```

---

# 146. Golden Rules

## Rule 1

Never risk financial data.

## Rule 2

Receipt OCR must never silently create a final transaction.

## Rule 3

Always let user review detected amount.

## Rule 4

Core functionality must remain available offline.

## Rule 5

Cloud must stay optional.

## Rule 6

Do not make the application complicated simply because more features become available.

---

# 147. Final Product Direction

Aplikasi bukan hanya pengganti aplikasi Catatan Keuangan lama.

Target produknya adalah:

> **Modern Offline-First Personal Finance Tracker with Smart Receipt Scanning**

Dengan pengalaman utama:

```text
Catat manual dalam beberapa detik

atau

Foto struk
↓
Aplikasi membaca
↓
Periksa
↓
Simpan
```

Pengguna tetap memiliki kendali penuh terhadap data dan aplikasi tetap dapat digunakan tanpa layanan cloud.
