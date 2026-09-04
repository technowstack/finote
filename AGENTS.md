# AGENTS.md

## Project: Finote

Finote is a modern, offline-first personal finance application built with Flutter.

The application is intended to replace an older discontinued **Catatan Keuangan** application while preserving the ability to import its legacy SQLite database.

---

# 1. Purpose

Primary goals:

- fast personal finance tracking;
- offline-first usage;
- reliable local financial data storage;
- legacy database migration;
- backup and restore;
- Excel, Text, and PDF export;
- Play Store readiness;
- maintainable architecture for future optional features.

The main product requirements are defined in:

```text
PRD.md
```

Development progress is tracked in:

```text
STATUS.md
```

Always read `PRD.md`, `STATUS.md`, and the relevant files under `.agents/skill/` before implementing a task.

---

# 2. Source of Truth

Requirement priority:

```text
1. Latest explicit user instruction
2. PRD.md
3. AGENTS.md
4. Relevant .agents/skill/ instructions
5. Existing project architecture and conventions
6. Reasonable engineering practices
```

`STATUS.md` is a progress tracker, not a requirements document.

If an older requirement conflicts with a newer explicit user decision, follow the newest instruction unless doing so would create a serious security or data-integrity risk.

Do not modify `PRD.md` during normal feature implementation unless explicitly requested.

---

# 3. Development Rule

Do **not** implement the entire PRD at once.

Development must be incremental.

Only implement the phase or task explicitly requested.

If the current task is:

```text
Phase 5A — Export Excel / Text / PDF
```

do not automatically implement:

```text
Phase 5B
Phase 5C
Phase 5D
```

even when those phases are already documented.

Before coding:

1. read `AGENTS.md`;
2. read `PRD.md`;
3. read `STATUS.md`;
4. inspect relevant `.agents/skill/`;
5. inspect the existing implementation;
6. reuse working code where reasonable;
7. implement only the requested scope.

---

# 4. Current Product Direction

Finote is currently extending its mature offline-first personal finance core with **Finote v1.3.0 — Assets / Investments**, while preserving financial correctness, data ownership, backward compatibility, and offline operation.

Current priorities:

1. data integrity;
2. financial correctness;
3. stability;
4. transaction entry speed;
5. usability;
6. offline reliability;
7. export and data portability;
8. backup and restore reliability;
9. performance;
10. Play Store readiness;
11. real user feedback;
12. new features.

Never sacrifice financial correctness or user data for convenience.

Data loss is a **critical bug**.

---

# 5. Core Product Principle

Finote must remain simple.

Before adding complexity, ask:

> Does this make personal finance tracking easier, safer, or more useful?

Finote is primarily a:

```text
Personal Finance Tracker
```

not a:

```text
Business Accounting System
ERP
Banking Application
Broker / Trading Platform
```

---

# 6. Technology Stack

Use Flutter stable.

Primary stack:

```text
Flutter
Dart
Riverpod
GoRouter
Drift
SQLite
Material Design 3
```

Supporting packages may include:

```text
freezed
json_serializable
uuid
intl
path_provider
file_picker
share_plus
```

For Excel and PDF generation, select maintained packages that are compatible with the project's current Flutter/Dart versions.

Do not add dependencies without clear value.

Avoid large dependencies for trivial functionality.

---

# 7. Architecture

Use **Feature-First Architecture**.

Preferred structure:

```text
lib/
├── app/
│   ├── app.dart
│   └── router.dart
├── core/
│   ├── database/
│   ├── errors/
│   ├── extensions/
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

A feature may contain:

```text
data/
domain/
presentation/
```

Do not force unnecessary layers.

Prefer architecture that is:

- readable;
- maintainable;
- testable;
- consistent;
- simple.

---

# 8. Offline-First Requirement

Core functionality must work without internet.

Core features must never require:

```text
Supabase
Firebase
Google Drive
Dropbox
Internet connection
User account
AI service
```

Core offline functionality includes:

```text
transactions
categories
dashboard
reports
search
filters
export
settings
backup
restore
legacy import
```

Cloud functionality is optional and belongs to future phases.

---

# 9. Local Database

Use:

```text
Drift + SQLite
```

SQLite is the local source of truth.

Do not use SharedPreferences as financial-record storage.

SharedPreferences or equivalent may only be used for simple non-critical preferences when appropriate.

---

# 10. Money Rules

Financial values must never use floating-point storage.

Incorrect:

```dart
double amount;
```

Correct conceptually:

```dart
int amount;
```

Example:

```text
Rp25.000
```

stored as:

```text
25000
```

Never store formatted currency strings as the source value.

Format money only in the presentation/export layer as appropriate.

---

# 11. Transaction Schema Rules

Core transaction entity should support at least:

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

Transaction types:

```text
income
expense
```

Do not expose legacy numeric values such as `0` and `1` in application business logic.

---

# 12. UUID

Entities intended to survive migrations or future synchronization should use UUIDs.

```text
id   = local SQLite primary key
uuid = globally unique identifier
```

Generate UUID when the record is created.

---

# 13. Soft Delete

Important financial records should use:

```text
deleted_at
```

`deleted_at = null` means active.

Do not physically delete transactions during normal delete operations unless explicitly required by a later product decision.

Soft-deleted transactions must not appear in:

- dashboard totals;
- reports;
- search results;
- exports;
- active transaction history.

---

# 14. Balance Calculation

Never store the application's primary balance as an independently edited value.

Formula:

```text
balance = total income - total expense
```

Derived totals must come from active transactions.

---

# 15. Reports

Reports must derive data from transaction records.

Examples:

```text
daily total
weekly total
monthly total
category total
custom-period total
```

Avoid summary tables unless measurements later prove they are necessary.

For the same filter and period:

```text
Dashboard
Reports
Transaction History
Exports
```

must reconcile.

A mismatch in financial totals is a release-critical bug.

---

# 16. Date Handling

Transaction dates are financial calendar dates.

A transaction entered as:

```text
30 Aug 2026
```

must not unexpectedly shift to another day because of timezone conversion.

Metadata timestamps may use UTC where appropriate, but transaction-date semantics must remain stable.

---

# 17. Currency Formatting

Initial currency:

```text
IDR
```

Examples:

```text
Rp10.000
Rp1.250.000
```

Store numeric values and format only for display/export.

---

# 18. State Management

Use:

```text
Riverpod
```

Prefer reactive updates using Drift streams/providers where appropriate.

Avoid manually refreshing whole screens when reactive state can update them safely.

---

# 19. Routing

Use:

```text
GoRouter
```

Keep routing centralized.

Do not mix navigation logic deeply into repositories or domain services.

---

# 20. UI and UX

Use Material Design 3.

The UI should feel:

- modern;
- simple;
- clean;
- comfortable;
- fast.

Primary manual transaction flow:

```text
Open app
↓
Tap Add Transaction
↓
Enter amount
↓
Select category
↓
Save
```

Defaults:

```text
type = expense
date = today
```

Optional fields must not make common transaction entry unnecessarily slow.

Support:

```text
ThemeMode.system
ThemeMode.light
ThemeMode.dark
```

Theme preference must persist.

---

# 21. Error Handling

Never show raw technical errors to users.

Bad:

```text
SQLiteException: constraint failed
```

Good:

```text
Gagal menyimpan transaksi.
Silakan coba lagi.
```

Technical information may be logged in development, but sensitive financial information must not be included.

---

# 22. Logging

Do not log:

```text
transaction title
transaction note
amount
balance
receipt OCR text
receipt image
backup contents
PIN
access token
API key
```

Use privacy-safe structural logs where necessary.

---

# 23. Data Integrity

Operations involving multiple dependent database changes should be atomic.

Use database transactions where appropriate.

Examples:

- legacy import;
- multi-record receipt saves;
- migrations;
- operations that must succeed or fail together.

When uncertain, fail safely rather than performing destructive recovery.

---

# 24. Legacy Database Import

The application supports importing the legacy Catatan Keuangan SQLite database.

Known legacy tables include:

```text
Transaction
TransactionDay
TransactionType
TransactionSubType
AppSetting
```

Legacy databases must be treated as:

```text
READ ONLY
```

Never modify the selected legacy database.

Legacy type mapping:

```text
0 = expense
1 = income
```

Convert these values immediately into Finote's internal domain representation.

`TransactionDay` must not be used as the source of truth.

Reports must be recalculated from imported transactions.

---

# 25. Legacy Import Safety

Flow:

```text
Validate
↓
Preview
↓
Confirm
↓
Import
↓
Verify
```

Preview should include, where available:

```text
transaction count
category count
date range
income total
expense total
```

Use:

```text
legacy_source
legacy_id
```

to make import repeat-safe.

Run import inside a SQLite transaction.

If an unrecoverable error occurs:

```text
ROLLBACK
```

Do not leave a partially imported dataset.

---

# 26. Backup

Backup is for **recovery**, not reporting.

Preferred structure:

```text
finote_backup_YYYY-MM-DD_HH-mm.zip
├── database.sqlite
└── manifest.json
```

Backup format must include version metadata.

---

# 27. Restore

Before destructive restore:

1. validate backup;
2. validate compatibility;
3. create safety backup of current data;
4. show preview;
5. ask for confirmation;
6. restore;
7. verify.

Never replace the current database destructively without a recovery path.

---

# 28. Export Is a Core Release Feature

Export is required before Finote v1.0.

Required formats:

```text
Excel (.xlsx)
Text (.txt)
PDF (.pdf)
```

Export is separate from backup:

```text
Backup = recovery / restoration
Export = reporting / portability / sharing
```

Do not use backup archives as report exports.

---

# 29. Export Scope

Export should support:

```text
All transactions
Today
This week
This month
Custom date range
```

When supported by the current Reports filters:

```text
Income only
Expense only
Category
```

If export is launched from a filtered Reports screen, reuse the active filter where reasonable.

---

# 30. Export Architecture

Prefer a shared pipeline:

```text
ReportFilter
↓
Export Query / Repository
↓
ExportDocumentModel
↓
Exporter
   ├── ExcelExporter
   ├── TextExporter
   └── PdfExporter
```

Exact naming may follow existing conventions.

Rules:

- all formats must use the same resolved financial dataset;
- do not duplicate report calculations in each exporter;
- export must ignore soft-deleted transactions;
- export must not mutate database records;
- export must work offline.

---

# 31. Excel Export Rules

Preferred file name:

```text
finote_report_YYYY-MM-DD.xlsx
```

Minimum workbook:

```text
Ringkasan
Transaksi
```

`Ringkasan`:

```text
Periode
Total pemasukan
Total pengeluaran
Saldo
Jumlah transaksi
Generated at
```

`Transaksi`:

```text
No
Tanggal
Tipe
Kategori
Judul
Catatan
Nominal
```

Rules:

- monetary cells should be numeric when supported;
- transaction dates must be valid spreadsheet dates where practical;
- output must open correctly in common spreadsheet applications;
- do not export soft-deleted records.

---

# 32. Text Export Rules

Preferred file name:

```text
finote_report_YYYY-MM-DD.txt
```

Use UTF-8.

Output must be human-readable.

Minimum content:

```text
Periode
Total pemasukan
Total pengeluaran
Saldo
Transaction details
```

Do not make Text export a raw database dump.

---

# 33. PDF Export Rules

Preferred file name:

```text
finote_report_YYYY-MM-DD.pdf
```

Minimum content:

```text
Finote
Laporan Keuangan
Periode
Total pemasukan
Total pengeluaran
Saldo
Jumlah transaksi
Detail transaksi
```

Requirements:

- support multi-page output;
- avoid clipped values;
- use readable layout;
- work offline;
- remain print-friendly.

---

# 34. Export Storage Rules

Use modern Android system file/document APIs.

Users should be able to:

- save exported files;
- choose destination where supported;
- open files;
- share files where appropriate.

Follow least privilege.

Do not add:

```text
MANAGE_EXTERNAL_STORAGE
```

solely for export.

---

# 35. Export Accuracy

For the same period/filter, these must match:

```text
Reports
Excel
Text
PDF
```

Example:

```text
Income  = Rp8.500.000
Expense = Rp4.350.000
Balance = Rp4.150.000
```

The same values must appear across all supported export formats.

Any inconsistency is a release-critical bug.

---

# 36. Export Testing

Meaningful tests should cover:

- date range;
- income-only filter;
- expense-only filter;
- category filter where supported;
- soft-delete exclusion;
- empty dataset;
- large dataset;
- Excel generation;
- Text generation;
- PDF generation;
- Reports/export consistency.

Do not add brittle pixel-perfect tests unless there is a clear need.

---

# 37. Export Definition of Done

Phase 5A is complete only when:

- Excel export works;
- Text export works;
- PDF export works;
- period filters work;
- export totals match Reports;
- soft-deleted records are excluded;
- empty data is handled safely;
- large datasets do not crash the app;
- export works offline;
- output can be saved/shared using appropriate Android APIs;
- broad storage permission is not introduced;
- relevant tests pass;
- `flutter analyze` passes.

---

# 38. Receipt Scanner Status

Receipt Scanner has already been developed locally through Phase 4G.

Current rules:

- scanner remains local-only;
- OCR creates a draft, never a final automatic transaction;
- explicit user confirmation is mandatory;
- parsed financial values remain editable;
- manual corrections are authoritative;
- do not upload receipt images or OCR text;
- do not log receipt contents;
- do not expand scanner scope during the release-focused roadmap.

Receipt Scanner is **not release-critical for v1.0**.

If real-device testing shows that it is not sufficiently reliable:

- keep the working implementation;
- stop expanding it;
- hide it behind a feature flag or experimental setting if necessary;
- do not delay Finote v1.0 because of OCR accuracy.

---

# 39. AI Feature Freeze

AI-related functionality is currently out of scope.

Do **not** implement or expand:

```text
AI Receipt Scan
AI OCR Interpretation
AI Receipt Parsing
AI Categorization
AI Financial Assistant
AI Financial Recommendations
LLM Integration
OpenAI Integration
Gemini Integration
Claude Integration
AI Gateway / Backend
AI Subscription Infrastructure
```

AI may only be reconsidered after Finote:

- is released publicly on Google Play;
- has real active users;
- has validated user demand;
- has sufficient server/API budget;
- has an appropriate privacy design;
- has a defined monetization or premium strategy.

Existing AI-ready abstractions may remain only if they do not create unnecessary maintenance complexity.

Do not expand them without explicit user instruction.

---

# 40. Cloud

Do not implement cloud synchronization during the release-focused roadmap unless explicitly requested.

Core Finote must remain fully usable without an account.

Cloud backup and multi-device sync are separate concepts and must not be conflated.

---

# 41. Security

Never store secrets in source code or ordinary SQLite tables.

Never commit:

```text
.env
keystore
key.properties
service account keys
API secrets
OAuth credentials
private backup files
real receipt images containing private data
```

Use secure platform storage where appropriate.

---

# 42. Android Permissions

Follow least privilege.

Prefer Android Storage Access Framework/system picker for user-selected files.

Avoid broad storage permissions.

Request camera permission only when the user actually chooses camera functionality.

---

# 43. Play Store Compatibility

All features must be compatible with Play Store distribution.

Before release, verify current requirements for:

```text
targetSdk
permissions
privacy policy
Data Safety
background behavior
production signing
```

Do not assume old Play Store requirements are still valid.

---

# 44. Testing

Important tests include:

```text
currency formatting
balance calculation
income calculation
expense calculation
category CRUD
transaction CRUD
soft delete
search
filters
report calculations
Excel export
Text export
PDF export
export/report consistency
database migrations
legacy mapping
duplicate import prevention
backup validation
restore validation
theme persistence
```

Only keep receipt-specific tests required by the scanner implementation that remains active.

---

# 45. Code Quality

Before considering a significant task complete:

```bash
dart format .
flutter analyze
flutter test
```

If generated code is involved:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Then rerun analyze/tests when appropriate.

Do not claim a command passed unless it was actually executed.

Do not suppress analyzer rules just to hide legitimate problems.

---

# 46. Generated Code

Do not manually modify generated files produced by packages such as:

```text
freezed
json_serializable
drift
```

Regenerate instead.

---

# 47. Database Migration

Never make an incompatible schema change without:

```text
schema version increment
+
migration
```

Database updates must preserve existing user data.

When changing schema, test:

```text
fresh install
previous version → new version
database containing existing transactions
```

Never assume only fresh installations exist.

---

# 48. Performance

Design for at least:

```text
10,000+ transactions
```

Do not load the entire transaction database into memory when a filtered/aggregated query can do the work efficiently.

Index frequently queried columns when justified.

Potential examples:

```text
transaction_date
category_id
type
deleted_at
legacy_source + legacy_id
```

Do not add indexes blindly.

Measure first where practical.

---

# 49. Repository Pattern

Repositories may be used to isolate features from persistence implementation.

Examples:

```text
TransactionRepository
CategoryRepository
```

Keep repositories focused.

Do not create unnecessary pass-through layers.

---

# 50. Naming

Use English for:

```text
class names
methods
variables
source files
database tables
domain models
```

Use Bahasa Indonesia for initial user-facing text.

Example:

Code:

```text
TransactionRepository
```

UI:

```text
Tambah Transaksi
```

---

# 51. Comments

Do not add comments that merely repeat the code.

Comments are useful for:

- non-obvious financial rules;
- migration decisions;
- legacy compatibility;
- complex calculations;
- platform-specific workarounds.

---

# 52. Git Changes

Keep implementation changes focused.

Avoid mixing unrelated:

```text
feature work
massive refactoring
dependency upgrades
formatting of unrelated files
```

unless genuinely required.

Recommended Conventional Commits:

```text
feat:
fix:
refactor:
test:
docs:
chore:
```

Examples:

```text
feat: add Excel report export
feat: add PDF and text exports
fix: keep report and export totals consistent
test: add export regression coverage
```

---

# 53. Do Not Rewrite Working Code Without Reason

Before replacing an existing implementation:

1. inspect it;
2. understand why it exists;
3. reuse it when reasonable;
4. refactor only when necessary.

Do not recreate repositories, services, providers, utilities, or widgets that already solve the problem adequately.

---

# 54. Preserve User Data

Any operation involving:

```text
database migration
restore
legacy import
delete
backup
```

must prioritize data preservation.

When uncertain:

```text
fail safely
```

rather than performing destructive recovery automatically.

---

# 55. Release Roadmap Status

Finote v1.0.0 has completed the local release-focused roadmap and is now in maintenance / real-usage mode.

Completed/existing foundation:

```text
Phase 0   Foundation
Phase 1   Core Finance
Phase 2   Backup / Restore / Legacy Import
Phase 3   Personal Use Ready
Phase 3.5 UI/UX + Theme Polish
Phase 4A-G Local Receipt Scanner Development
```

Completed local release-focused roadmap:

```text
Phase 5A  Export Excel / Text / PDF                         COMPLETE
Phase 5B  Core Finance Audit & Stabilization               COMPLETE
Phase 5C  Transaction UX & Workflow Hardening              COMPLETE
Phase 5D  Reports & Financial Accuracy                     COMPLETE
Phase 5E  Backup / Restore / Legacy Migration Hardening    COMPLETE
Phase 5F  Performance & Reliability                        COMPLETE
Phase 5G  Play Store Preparation                           COMPLETE
Phase 5H  Closed Testing Preparation / RC Validation       COMPLETE LOCALLY
Phase 5I  LOCAL PRODUCTION FINAL / PLAY STORE READY v1.0   COMPLETE
```

Post-v1 development is active by explicit user instruction. Finote v1.1.0 Accounts & Transfers and v1.2.0 Reports Visualization & Analytics are complete; the current approved track is Finote v1.3.0 Assets / Investments.

---

# 56. Versioned Development / Scope Control

Finote v1.0.0 remains the local production-final baseline, but later version development may proceed only when explicitly requested. The currently approved feature track is **v1.3.0 Assets / Investments**.

Do not implement outside the explicitly requested version/phase. AI, Cloud Sync, automated trading, realtime trading, and unrelated post-v1 features remain deferred unless separately requested.

Current sequence:

```text
Finote v1.0.0 Local Production Final
↓
Daily Real Usage / Maintenance
↓
Bug / Data-Integrity / Compatibility Fixes Only
↓
Optional External Play Store Release When Ready
↓
Post-v1 Development Only When Explicitly Requested
```

---

# 56A. Completed v1.1.0 — Accounts & Transfers

Accounts/Wallet and account-to-account transfers are a completed **post-v1** feature under:

```text
v1.1.0
Phase 6A — Accounts & Transfers
```

Completed sub-phases:

```text
6A.1 Account / Wallet Management
6A.2 Assign Transactions to Account
6A.3 Account Balance Calculation
6A.4 Account-to-Account Transfer
6A.5 Transaction History Integration
6A.6 Reports Integration
6A.7 Export Integration
6A.8 Backup / Restore Migration
6A.9 Legacy Database Compatibility
6A.10 Testing & Polish
```

Historical note: before Phase 6A was explicitly started, these changes were deferred. They are now implemented in v1.1.0. Do not recreate or duplicate them:

- create an `accounts` table;
- create a `transfers` table;
- add `account_id` to the current transaction schema;
- alter Reports to include transfer logic;
- change Legacy Import to require accounts;
- change backup format solely for future accounts;
- change exports solely for future accounts.

Phase 6A is complete. Existing Accounts & Transfers code is now baseline architecture and must be reused rather than reimplemented.

## 56A.1 Transfer Financial Semantics

Implemented domain separation:

```text
Transactions
├── Income
└── Expense

Transfers
└── Account → Account
```

A transfer between user-owned accounts is **not income and not expense**.

Example:

```text
Income: Salary Rp10.000.000 → BCA Utama
Transfer: Rp2.000.000 BCA Utama → BCA Tabungan

BCA Utama    Rp8.000.000
BCA Tabungan Rp2.000.000
Total assets Rp10.000.000
```

Reports must not increase expense or income because of the transfer.

## 56A.2 Current Account Balance Rule

Account balance is derived conceptually as:

```text
initial_balance
+ income
- expense
+ incoming_transfer
- outgoing_transfer
```

Do not implement account balance as a manually mutated source-of-truth field that can drift when transactions/transfers are edited or deleted.

## 56A.3 Completed Migration Safety Baseline

The completed Phase 6A migration established the backward-compatible baseline below. Future migrations must inspect the actual Drift schema and migration history first and must not assume conceptual names match current code.

Required backward-compatible strategy:

```text
Create accounts
↓
Create Default Account / Cash
↓
Add nullable account relation to transactions
↓
Backfill existing transactions
↓
Validate
↓
Only tighten constraints if safe
```

Never introduce the first account migration as an unconditional `account_id NOT NULL` change against existing user databases.

The migration must preserve existing financial data and supported upgrade paths.

## 56A.4 Legacy Import Compatibility

Legacy databases may have no account information.

Current Phase 6A behavior:

```text
Legacy transaction
↓
Existing legacy mapping
↓
Default Account
```

Rules:

- legacy database remains READ ONLY;
- users do not manually modify legacy DBs;
- repeated import remains duplicate-safe;
- existing Finote data remains intact;
- transfer records are not synthesized for historical legacy transactions.

## 56A.5 Current Backup / Restore / Export Rules

Accounts & Transfers are implemented; therefore:

- backup/restore must include accounts, transfers, transaction-account relations, and new schema metadata;
- exports may include Account information;
- Reports must continue to exclude transfers from income/expense totals;
- Transaction History may display transfers as a separate entry type.

Required regression testing must cover migrations, Reports, exports, backup/restore, and legacy import.

---

# 57. Release-Critical Core

Treat these as release-critical for Finote v1.0:

```text
Manual income creation
Manual expense creation
Transaction editing
Transaction deletion
Category management
Transaction history
Search
Filters
Dashboard
Reports
Excel Export
Text Export
PDF Export
Backup
Restore
Legacy Import
Light / Dark / System Theme
Basic Security
Offline Usage
Database Migrations
Financial Accuracy
```

Receipt Scanner:

```text
Optional for v1.0 depending on stability
```

AI:

```text
Not included in v1.0
```

---

# 58. STATUS.md Rules

Before implementation:

1. read `STATUS.md`;
2. confirm what is completed;
3. confirm current phase;
4. inspect existing code;
5. do not rebuild completed features.

After implementation:

- update only the relevant status;
- do not rewrite unrelated historical progress;
- do not mark future phases complete;
- keep blockers visible;
- mark a phase complete only after required validation succeeds.

---

# 59. .agents/skill Rules

Before implementation, inspect:

```text
.agents/skill/
```

Read only skills relevant to the task.

Examples for export:

```text
Flutter
Dart
PDF
Excel
file handling
Android storage
testing
```

Examples for database work:

```text
Flutter
Drift
SQLite
migrations
testing
```

Do not expand task scope merely because additional skills exist.

---

# 60. Task Completion Response

After completing a requested implementation, report:

1. what was implemented;
2. important files created/changed;
3. database/schema changes;
4. dependencies added/removed;
5. tests added;
6. commands executed;
7. `flutter analyze` result;
8. `flutter test` result;
9. known limitations;
10. next task from the current roadmap.

Do not claim success for commands that were not executed.

Do not start the next phase automatically.

---

# 60A. Post-v1.0 Maintenance Rules

Current product state:

```text
Finote v1.2.0
REPORTS VISUALIZATION & ANALYTICS COMPLETE

Finote v1.3.0
ASSETS / INVESTMENTS — PHASE 7A.1 PLANNING / AUDIT
```

For tasks explicitly scoped to the v1.0 maintenance baseline, default to one of:

- `fix:` bug correction;
- `perf:` measured performance/reliability correction;
- `test:` regression coverage;
- `docs:` release/maintenance documentation;
- `chore:` release configuration or tooling;
- narrow `refactor:` only when required by a concrete bug/reliability problem.

Do not infer permission to add a new product feature from the fact that v1.0.0 is complete.

External Play Store actions are separate from local code readiness. Do not upload, publish, create tester groups, or submit releases unless explicitly requested.

---

# 61. Definition of Done

A task is complete only when:

- the requested functionality works;
- existing functionality remains intact;
- architecture remains consistent;
- financial data integrity is preserved;
- code is formatted;
- analyzer issues introduced by the task are resolved;
- relevant tests pass;
- unrelated future phases were not implemented;
- `STATUS.md` is updated appropriately.

---

# 62. Current Development Philosophy

For every coding task:

```text
Read PRD.md
↓
Read STATUS.md
↓
Read relevant .agents/skill/
↓
Inspect existing code
↓
Implement smallest requested scope
↓
Write/update tests
↓
Format
↓
Analyze
↓
Test
↓
Inspect git diff
↓
Update STATUS.md
↓
Report
```

Do not:

```text
Read PRD
↓
Implement everything
```

---

# 63. Golden Rules

## Rule 1

Never risk a user's financial history for convenience.

## Rule 2

Manual finance workflows must remain first-class.

## Rule 3

Core functionality must work offline.

## Rule 4

Derived totals must come from source transactions.

## Rule 5

Backup is for recovery; export is for portability/reporting.

## Rule 6

Excel, Text, and PDF exports must remain financially consistent.

## Rule 7

Cloud remains optional.

## Rule 8

AI remains deferred until real demand is validated.

## Rule 9

Do not make Finote complicated simply because more features are technically possible.

## Rule 10

Account-to-account transfers must never be classified as income or expense.

---

# 64. Current Finote Product Goal

Current product state:

> **Finote v1.2.0 is the current completed feature baseline; Finote v1.3.0 Assets / Investments is the active explicitly approved development track.**

The current goal is to add Assets / Investments incrementally without weakening the existing finance core. Data integrity, deterministic calculations, offline usability, and backward compatibility remain more important than feature count.

Current product focus:

```text
Manual Finance Core
+
Reports
+
Excel / Text / PDF Export
+
Backup / Restore
+
Legacy Import
+
Reliable Offline Operation
+
Play Store Readiness
```

AI, cloud, and advanced finance features come later only when there is validated demand.


---

# 65. Finote v1.3.0 — Assets / Investments Rules

Finote v1.3.0 is an explicitly approved development track.

Current active phase:

```text
Phase 7A.1 — Investment Architecture & Existing Code Audit
```

Do not automatically implement Phase 7A.2 or later phases until 7A.1 is reviewed/accepted.

## 65.1 Investment Domain Separation

Keep these concepts separate:

```text
Cashflow
Investment Cashflow
Asset Activity
Current Holdings
Current Portfolio Value
Net Worth
```

Historical investment cashflow must never become the holdings source of truth.

## 65.2 Existing Investment Cashflow

Existing categories/transactions have already been normalized manually into:

```text
Pembelian Aset
Penjualan Aset
```

Do not build a legacy category reconstruction/migration assistant.

Use these records only for:

```text
Total Pembelian Aset
Total Penjualan Aset
Net Cash Invested
```

Never infer from Net Cash Invested:

- current portfolio value;
- holdings quantity;
- cost basis;
- historical P/L.

Historical investment cashflow has one source of truth: active Transactions.
Aggregate only correctly typed `Pembelian Aset` expense and `Penjualan Aset`
income rows. Do not sum `AssetTransaction.totalAmount`; linked Buy/Sell already
have one corresponding cashflow transaction. Opening Position and Adjustment
must not create or contribute investment cashflow.

## 65.3 Opening Portfolio Snapshot

Existing users may not know historical lots/units/average buy. Do not force reconstruction.

Use an Opening Portfolio Snapshot / Opening Asset Position that represents the holdings owned when the Assets feature begins.

New users may start from zero or from an Opening Position.

## 65.4 Holdings Formula

Canonical concept:

```text
Current Holdings
= Opening Position
+ Buy
- Sell
+ Adjustment
```

Asset activities required for v1.3.0:

```text
openingPosition
buy
sell
adjustment
```

Do not implement dividend/interest/staking/split unless explicitly requested later.

## 65.5 Quantity Precision

Money rules remain unchanged:

```text
IDR / financial amount = integer source of truth
```

Asset quantity may be fractional. Do not persist/calculate canonical quantity using binary `double` without an explicit deterministic precision design.

Phase 7A.1 must inspect and recommend a safe strategy such as:

- scaled integer;
- decimal value object;
- string-backed decimal;
- another deterministic representation compatible with Drift.

Do not choose scale/precision blindly.

## 65.6 Cost Basis Unknown Is Valid State

Existing opening holdings may have quantity but no known cost basis.

```text
quantity known
cost basis unknown
```

Unknown must not be converted to zero.

Historical P/L must remain unavailable until sufficient cost-basis data exists.

## 65.7 Asset / Cashflow Link

An asset activity may use nullable `source_transaction_id` (exact name follows actual schema) to reference one normal Finote cashflow transaction.

Rules:

- Buy may create/link one Expense / Pembelian Aset cashflow transaction.
- Sell may create/link one Income / Penjualan Aset cashflow transaction.
- Never create duplicate cashflow for one economic event.
- Historical Pembelian/Penjualan records do not require automatic asset-activity backfill.
- Adjustment changes holdings without automatically becoming Income/Expense.

Operations that create both cashflow + asset activity should be atomic where practical.

## 65.8 Asset Types and Pricing

Initial asset types:

```text
stock
crypto
mutualFund
gold
other
```

Pricing modes:

```text
api
manual
```

Do not expand into Bond/SBN/ETF/Property unless explicitly requested.

## 65.9 Market API Boundary

Flutter talks only to **Finote Market API**, not Yahoo/yfinance/CoinGecko/Binance directly.

Preferred portfolio quote endpoint:

```http
POST /api/v1/market/quotes
```

Avoid one request per asset when batch quote is available.

Flutter consumes normalized quote fields and must not depend on provider-specific response formats or symbols such as Yahoo `.JK` suffixes.

## 65.10 Market API Privacy

Market quote requests may send only minimal market identifiers such as:

```text
symbol
asset type
currency
```

Never send to Market API:

- quantity owned;
- account balances;
- account names;
- transaction history;
- transaction notes;
- portfolio value;
- net worth.

## 65.11 Offline-First Portfolio

Required UX/data flow:

```text
Load assets + activities from Drift
↓
derive holdings locally
↓
load local last-known/manual prices
↓
render Portfolio immediately
↓
wait for explicit user Refresh Harga action
↓
refresh batch market quotes
↓
update UI and local last-known price
```

Network failure must not prevent viewing holdings or using Finote core finance.
Opening Portfolio, rebuilding the widget, switching tabs, and expired local
price age must never trigger a Market API request automatically.

Market prices are auxiliary external data; holdings are local source records.

## 65.12 No Realtime Trading Scope

Do not add for v1.3.0:

```text
WebSocket
per-second polling
candlestick chart
trading/order execution
automated trading
large historical price database
server-side portfolio storage
complex portfolio analytics
AI investment advice
```

Finote remains a personal finance tracker with portfolio awareness, not a brokerage/trading terminal.

## 65.13 Current Value and Net Worth

Portfolio Value:

```text
SUM(current holding × current/manual/last-known price)
```

Net Worth:

```text
Cash / Wallet Assets
+ Current Portfolio Value
```

Do not include Net Cash Invested as an extra component of Net Worth.

Net Worth must consume the existing derived account summaries and local
PortfolioSnapshot. Never recalculate either component in the Net Worth UI or
trigger a Market API request from a Net Worth provider. Missing Portfolio prices
make Net Worth partial, not zero-valued or complete.

Market price movement must not modify Income/Expense.

Reports must never period-filter Current Portfolio Value or Current Net Worth,
and must never trigger Market API requests. Reports cashflow must aggregate
linked Buy/Sell through Transactions only; never double-count
AssetTransaction.totalAmount.

## 65.14 Backup / Restore

Persistent v1.3 investment source records must be included in Backup/Restore:

- assets;
- opening-position activities;
- buy/sell/adjustment activities;
- manual pricing configuration;
- any other persistent holdings source records.

Last-known API quote cache is rebuildable and does not have to be backup-critical.

Restore must work offline and preserve referential integrity.

## 65.15 Migration and Legacy Safety

Prefer additive Drift migrations.

Before any schema work:

- inspect actual schema version;
- inspect migration history;
- preserve v1.2 data;
- test fresh install and v1.2 -> v1.3 upgrade;
- do not modify/rewrite existing historical transactions unnecessarily;
- do not auto-create holdings from legacy investment categories.

Legacy source databases remain READ ONLY.

## 65.16 Phase 7 Roadmap

```text
7A Asset Domain Foundation
7A.1 Investment Architecture & Existing Code Audit
7A.2 Asset Database Schema & Migration
7A.3 Asset CRUD & Asset Types
7A.4 Opening Portfolio Snapshot
7A.5 Asset Activity / Buy-Sell-Adjustment
7A.6 Holdings Calculation

7B Market Data
7B.1 Market API Client Foundation
7B.2 Batch Quote Integration
7B.3 Local Last-Known Price Cache
7B.4 Manual Asset Pricing
7B.5 Current Market Value

7C Portfolio
7C.1 Portfolio Screen Foundation
7C.2 Stock Holdings UI
7C.3 Crypto Holdings UI
7C.4 Mutual Fund / Gold / Manual Assets
7C.5 Portfolio Summary & Refresh UX

7D Finance Integration
7D.1 Historical Investment Cashflow
7D.2 Net Worth Integration
7D.3 Reports Integration
7D.4 Dashboard Integration

7E Reliability & Release
7E.1 Backup / Restore Integration
7E.2 Backward Compatibility & Migration Tests
7E.3 Portfolio Performance & Offline Audit
7E.4 UI/UX Polish
7E.5 v1.3.0 Final Audit & Release Preparation
```

Implement only the explicitly requested sub-phase.

## 65.17 Phase 7A.1 Gate

7A.1 is **audit/planning only**.

Before coding, inspect:

1. Drift/SQLite schema and migration history;
2. transaction model and transaction categories;
3. Accounts & Transfers architecture;
4. `Pembelian Aset` / `Penjualan Aset` existing implementation;
5. Reports/Dashboard calculations;
6. Backup/Restore format;
7. Legacy Import;
8. Riverpod providers;
9. GoRouter/navigation;
10. networking client conventions;
11. Finote Market API integration contract.

7A.1 must produce an implementation plan and identify blockers. Do not create asset tables, UI, or Market API integration until the user explicitly proceeds to 7A.2.
