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

Finote is currently focused on becoming a mature, reliable, fast, offline-first personal finance app suitable for public release.

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
Investment Platform
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

# 55. Current Release Roadmap

Completed/existing foundation:

```text
Phase 0   Foundation
Phase 1   Core Finance
Phase 2   Backup / Restore / Legacy Import
Phase 3   Personal Use Ready
Phase 3.5 UI/UX + Theme Polish
Phase 4A-G Local Receipt Scanner Development
```

Current release-focused roadmap:

```text
Phase 5A  Export Excel / Text / PDF
Phase 5B  Core Finance Audit & Stabilization
Phase 5C  Transaction UX & Workflow Hardening
Phase 5D  Reports & Financial Accuracy
Phase 5E  Backup / Restore / Legacy Migration Hardening
Phase 5F  Performance & Reliability
Phase 5G  Play Store Preparation
Phase 5H  Closed Testing
Phase 5I  LOCAL PRODUCTION FINAL / PLAY STORE READY v1.0
```

During Phase 5A–5I, do not add major unrelated features.

---

# 56. Release-Focused Feature Freeze

Do not implement unless explicitly requested:

```text
AI features
Wallet / Accounts
Budgeting
Recurring Transactions
Cloud Backup
Cloud Sync
Optional User Accounts
Advanced Analytics
Major Receipt Scanner Expansion
```

Current sequence:

```text
Export
↓
Stabilize
↓
Validate Financial Accuracy
↓
Harden Backup / Restore / Migration
↓
Validate Performance
↓
Prepare Play Store Release
↓
Closed Testing
↓
v1.0 Production Release
```

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

---

# 64. Current Finote Product Goal

The current goal is not to maximize feature count.

The goal is:

> Make Finote a mature, trustworthy, fast, offline-first personal finance application with strong data portability and a safe path to Google Play release.

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
