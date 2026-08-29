# AGENTS.md

# Project: Catatan Keuangan

## 1. Purpose

This repository contains a modern, offline-first personal finance application built with Flutter.

The application is designed to replace an older discontinued "Catatan Keuangan" application while preserving the ability to import the legacy SQLite database.

Primary goals:

* fast personal finance tracking;
* offline-first usage;
* reliable local data storage;
* legacy database migration;
* backup and restore;
* Play Store readiness;
* maintainable architecture for future cloud synchronization.

The main product requirements are defined in:

```text
PRD.md
```

Always read `PRD.md` before implementing a new feature.

---

# 2. Development Rule

Do NOT implement the entire PRD at once.

Development must be completed incrementally by phase and task.

Only implement the phase/task explicitly requested by the user.

If the current task is:

```text
PHASE 1C
```

do not automatically implement:

```text
PHASE 1D
PHASE 2
PHASE 3
```

even if those features are described in `PRD.md`.

---

# 3. Priority

Development priority:

```text
1. Stability
2. Data integrity
3. Simplicity
4. User experience
5. Performance
6. New features
```

Never sacrifice data integrity just to simplify implementation.

This application stores financial records.

Data loss is considered a critical bug.

---

# 4. Core Product Principle

The application must remain simple.

Before adding complexity, ask:

> Does this make recording personal finances easier?

Avoid turning the application into a complex accounting system.

The application is primarily a:

```text
Personal Finance Tracker
```

not:

```text
Accounting ERP
Business Accounting System
Banking Application
```

---

# 5. Technology Stack

Use Flutter stable.

Primary stack:

```text
Flutter
Dart
Riverpod
GoRouter
Drift
SQLite
Material 3
```

Supporting packages may include:

```text
freezed
json_serializable
uuid
intl
path_provider
```

Prefer stable and actively maintained packages.

Do not add dependencies unless they provide clear value.

Avoid large dependencies for trivial functionality.

---

# 6. Architecture

Use:

```text
Feature-First Architecture
```

Preferred project structure:

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
  import/
```

Feature modules may contain:

```text
data/
domain/
presentation/
```

Avoid excessive architecture abstraction.

Prefer:

```text
maintainable
readable
testable
simple
```

over unnecessary architectural complexity.

---

# 7. Offline-First Requirement

The application must work without an internet connection.

Core features must NEVER require:

```text
Supabase
Firebase
Google Drive
Dropbox
Internet connection
User account
```

Core local functionality includes:

```text
transactions
categories
dashboard
reports
settings
backup
restore
```

Cloud functionality will be optional and implemented in future phases.

---

# 8. Local Database

Use:

```text
Drift + SQLite
```

SQLite is the source of truth for local application data.

Do not use shared preferences as transaction storage.

Shared preferences may only be used for simple non-critical preferences where appropriate.

---

# 9. Database Design Rules

Financial values must NEVER use floating point types.

Incorrect:

```text
double amount
float amount
```

Correct:

```text
int amount
```

Example:

```text
Rp25.000
```

stored as:

```text
25000
```

---

# 10. UUID

Entities intended for future synchronization must have UUIDs.

Example:

```text
id
uuid
```

`id` may be the local SQLite primary key.

`uuid` is the globally unique identifier.

Generate UUID when a record is created.

---

# 11. Soft Delete

Important entities should support soft delete.

Use:

```text
deleted_at
```

Do not immediately physically delete transaction records.

Example:

```text
deleted_at = null
```

means active.

A timestamp means deleted.

This is required because future cloud synchronization needs to know which records were deleted.

---

# 12. Transaction Schema

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
legacy_source
legacy_id
created_at
updated_at
deleted_at
```

Do not add wallet/account dependencies during the initial transaction phase unless the PRD phase explicitly requires them.

---

# 13. Transaction Types

Use clear domain values:

```text
income
expense
```

Do not expose legacy numeric values such as:

```text
0
1
```

inside application business logic.

Legacy values should only exist inside the legacy import adapter.

---

# 14. Balance Calculation

Never store the primary application balance manually.

Balance must be calculated from transactions.

Formula:

```text
balance = total income - total expense
```

This avoids inconsistent duplicated financial state.

---

# 15. Reports

Reports must derive data directly from transaction records.

Do not create unnecessary summary tables during the MVP.

Examples:

```text
daily total
weekly total
monthly total
category total
```

should be calculated using queries.

Optimization may be introduced later only if measurements show that it is necessary.

---

# 16. Date Handling

Be careful with financial transaction dates.

Timestamp metadata may use UTC.

However, a local transaction date must not unexpectedly shift days because of timezone conversion.

Example:

```text
27 Aug 2026
```

must remain:

```text
27 Aug 2026
```

when the timezone changes.

---

# 17. Currency Formatting

Initial currency:

```text
IDR
```

Display examples:

```text
Rp10.000
Rp1.250.000
```

Never store formatted currency strings in the database.

Store numeric values and format them only in presentation code.

---

# 18. State Management

Use:

```text
Riverpod
```

State should react automatically to database changes when practical.

Avoid manually refreshing entire screens after each CRUD operation if Drift streams/providers can update the UI reactively.

---

# 19. Routing

Use:

```text
GoRouter
```

Keep route definitions centralized.

Avoid navigation logic scattered throughout business logic.

---

# 20. UI

Use:

```text
Material Design 3
```

The design should feel:

```text
modern
simple
clean
comfortable
fast
```

Do not copy the exact visual appearance of the legacy application.

The legacy application is only a UX/functionality reference.

---

# 21. Main Navigation

Initial navigation should remain simple.

Recommended:

```text
Home
Transactions
Reports
Settings
```

Use a Floating Action Button for:

```text
Add Transaction
```

where appropriate.

---

# 22. Transaction UX

Creating a transaction is the most important interaction in the application.

Prioritize speed.

Ideal flow:

```text
Open app
↓
Tap +
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

Optional fields should not prevent saving.

---

# 23. Error Handling

Never show technical errors directly to the user.

Incorrect:

```text
SQLiteException: constraint failed
```

Correct:

```text
Gagal menyimpan transaksi.
Silakan coba lagi.
```

Technical information may be written to developer logs.

Never log sensitive financial information unnecessarily.

---

# 24. Data Integrity

Operations involving multiple dependent database changes must use transactions.

Example:

```text
create financial record
create sync queue record
update related metadata
```

must succeed or fail atomically when applicable.

---

# 25. Legacy Database Import

The application must eventually support importing the legacy Catatan Keuangan SQLite database.

Legacy database examples may contain tables:

```text
Transaction
TransactionDay
TransactionType
TransactionSubType
AppSetting
```

Do not modify legacy databases.

Legacy database files must be treated as:

```text
READ ONLY
```

---

# 26. Legacy Mapping

Legacy transaction type:

```text
0 = expense
1 = income
```

Convert immediately into the application's internal enum/domain representation.

Example:

```text
0
↓
TransactionType.expense
```

---

# 27. Legacy Categories

Legacy categories may be stored through:

```text
Transaction.subType
```

with category definitions from:

```text
TransactionSubType
```

Importer must map legacy categories into the new category table.

---

# 28. Legacy TransactionDay

Do NOT depend on:

```text
TransactionDay
```

as the source of truth.

Reports should be recalculated using imported transactions.

Legacy summary/cache tables may contain inconsistencies.

---

# 29. Legacy Dates

Legacy timestamps may use Unix timestamp milliseconds.

Example:

```text
1625500800000
```

Importer must correctly detect/convert legacy dates.

Do not assume seconds when the schema clearly stores milliseconds.

---

# 30. Legacy Import Safety

Import process must include:

```text
Validate
Preview
Confirm
Import
Verify
```

Do not immediately import after a file is selected.

User should first see information such as:

```text
transaction count
category count
date range
income total
expense total
```

---

# 31. Duplicate Protection

Legacy imports must be repeat-safe.

Recommended metadata:

```text
legacy_source
legacy_id
```

Example:

```text
legacy_source = catatan_keuangan_old
legacy_id = 12345
```

Prevent importing the same legacy record twice.

---

# 32. Import Transaction Safety

Run legacy import inside a database transaction.

If an unrecoverable import error occurs:

```text
rollback
```

Do not leave the application's database partially migrated.

---

# 33. Legacy Test Files

Real user backup databases must NEVER be committed into a public repository.

Recommended:

```text
dev_assets/legacy/
```

and `.gitignore`:

```gitignore
dev_assets/legacy/*.db
dev_assets/legacy/*.sqlite
dev_assets/legacy/*.sqlite3
```

Test databases containing fabricated/dummy data may be committed when safe.

---

# 34. Backup

Local backup is more important than cloud sync.

Backup implementation should eventually support:

```text
database.sqlite
manifest.json
```

inside a versioned backup format.

Never create a backup format without version metadata.

---

# 35. Restore

Before destructive restore:

1. validate backup;
2. validate version compatibility;
3. create safety backup of current data;
4. ask for confirmation;
5. restore;
6. verify.

Avoid destructive database replacement without recovery options.

---

# 36. Cloud

Do not implement cloud synchronization during MVP unless explicitly requested.

Future architecture may use:

```text
SQLite
↕
Sync Engine
↕
Supabase/PostgreSQL
```

SQLite remains the offline local database.

---

# 37. Google Drive / Dropbox

Cloud file providers should initially be considered for:

```text
backup
restore
```

not realtime database synchronization.

Do not confuse cloud backup with multi-device sync.

---

# 38. Authentication

Core application must not require authentication.

Future cloud features may introduce optional accounts.

Users must still be able to use the application locally without creating an account.

---

# 39. Security

Never store:

```text
passwords
PIN
tokens
OAuth secrets
API keys
```

as plaintext in source code or ordinary SQLite tables.

Use secure platform storage where appropriate.

---

# 40. Secrets

Never commit:

```text
.env
keystore
key.properties
service account keys
API secrets
OAuth credentials
```

Ensure relevant files are included in `.gitignore`.

---

# 41. Logging

Do not log sensitive transaction contents.

Avoid logging:

```text
transaction title
notes
amount
account balance
backup contents
access tokens
```

unless strictly required for local debugging and explicitly protected.

---

# 42. Android Permissions

Follow least privilege.

Do not request broad storage permissions unnecessarily.

Prefer Android Storage Access Framework for user-selected files.

Avoid:

```text
MANAGE_EXTERNAL_STORAGE
```

unless there is an unavoidable and justified requirement.

---

# 43. Play Store Compatibility

All features must be designed with Play Store distribution in mind.

Avoid libraries or APIs likely to violate Play Store policies.

Before release, verify current requirements for:

```text
targetSdk
privacy
permissions
data safety
background services
```

Do not assume old Play Store requirements are still valid.

---

# 44. Testing

Every critical feature should be testable.

Minimum important tests:

```text
currency formatting
balance calculation
income calculation
expense calculation
category operations
transaction CRUD
database migrations
legacy mapping
duplicate import prevention
backup validation
restore validation
```

---

# 45. Code Quality

Before considering a task complete, run:

```bash
flutter analyze
```

and:

```bash
flutter test
```

Fix errors introduced by the implementation.

Do not suppress analyzer rules merely to hide legitimate errors.

---

# 46. Formatting

Run:

```bash
dart format .
```

before completing significant code changes.

---

# 47. Generated Code

If using packages such as:

```text
freezed
json_serializable
drift
```

regenerate code when required.

Example:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Do not manually modify generated source files.

---

# 48. Database Migration

Never modify an already released database schema without increasing the schema version and providing a migration.

Database updates must preserve existing user data.

A Play Store application may be upgraded over years.

Database migration is therefore a first-class requirement.

---

# 49. Migration Testing

When changing database schema, test:

```text
fresh install
previous version → new version
database with existing transactions
```

Never assume only fresh installations exist.

---

# 50. Performance

Do not prematurely optimize.

However, database queries should be designed to support at least:

```text
10,000+ transactions
```

without obvious UI slowdown.

Index commonly queried columns such as:

```text
transaction_date
category_id
type
deleted_at
```

when appropriate.

---

# 51. Repository Pattern

Repositories may be used to isolate application features from database implementation.

Example:

```text
TransactionRepository
CategoryRepository
```

Keep repositories focused.

Do not create unnecessary layers that simply forward every method without adding abstraction value.

---

# 52. Naming

Use English for:

```text
source code
class names
methods
variables
database tables
```

Use Indonesian for user-facing text in the initial application.

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

# 53. Comments

Do not add comments that merely repeat the code.

Add comments only for:

```text
non-obvious business rules
migration decisions
legacy compatibility
complex calculations
platform-specific workarounds
```

---

# 54. Git Changes

Keep each implementation focused.

Avoid mixing:

```text
feature implementation
massive refactoring
dependency upgrades
formatting unrelated files
```

in the same change unless required.

---

# 55. Commit Convention

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
chore: initialize Flutter project foundation
feat: add local transaction database
feat: implement category management
feat: implement transaction CRUD
feat: add financial dashboard
feat: add monthly reports
feat: add legacy database importer
fix: prevent duplicate legacy transactions
```

---

# 56. Task Completion Response

After completing a requested implementation, report:

1. what was implemented;
2. important files created/changed;
3. database/schema changes;
4. tests added;
5. commands executed;
6. whether `flutter analyze` passed;
7. whether `flutter test` passed;
8. any remaining limitation;
9. recommended next task from `PRD.md`.

Do not claim commands passed unless they were actually executed.

---

# 57. Do Not Rewrite Existing Working Code Without Reason

Before replacing existing architecture or implementation:

1. inspect existing code;
2. understand why it exists;
3. reuse it if reasonable;
4. refactor only when necessary.

Avoid recreating services, repositories, providers, utilities, or widgets that already solve the problem.

---

# 58. Preserve User Data

Any operation touching:

```text
database migrations
restore
legacy import
delete
backup
```

must prioritize preserving user data.

When uncertain:

```text
fail safely
```

rather than performing destructive recovery automatically.

---

# 59. Phase Boundaries

Follow the development roadmap in `PRD.md`.

Recommended order:

```text
PHASE 0
Foundation

PHASE 1
Core MVP

PHASE 2
Backup / Restore / Legacy Import

PHASE 3
Play Store readiness

PHASE 4+
Optional advanced features
```

Do not skip directly into cloud synchronization while core transaction functionality remains unstable.

---

# 60. Current Development Philosophy

For every coding task:

```text
Read PRD
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
Report
```

Do not:

```text
Read PRD
↓
Implement everything
```

---

# 61. Definition of Done

A task is complete only when:

* requested functionality works;
* existing functionality remains intact;
* architecture is consistent with this document;
* financial data integrity is maintained;
* code is formatted;
* analyzer errors introduced by the task are resolved;
* relevant tests pass;
* no unrelated future phase was implemented.

---

# 62. Source of Truth

Requirement priority:

```text
1. Explicit current user instruction
2. PRD.md
3. AGENTS.md
4. Existing project architecture
5. Reasonable engineering conventions
```

If an explicit user instruction conflicts with an older PRD requirement, follow the latest user instruction unless it creates a significant security or data-integrity risk.

When requirements are ambiguous, prefer the smallest implementation consistent with the current phase.

---

# 63. Golden Rule

The most important rule of this project:

> Never risk a user's financial history for convenience.

Build incrementally, preserve compatibility, keep the application simple, and treat local financial data as critical user data.

# Receipt Scanner Rules

Receipt scanning is a future feature and must not be implemented before the core roadmap unless explicitly requested.

When implemented:

- OCR output must create a draft, never an automatic final transaction.
- User confirmation is mandatory.
- Financial amounts detected through OCR must be editable.
- Prefer on-device OCR when practical.
- Separate OCR engine from receipt parsing.
- Do not permanently store receipt images by default.
- Do not upload receipt images without explicit user consent.
- Do not log receipt contents or detected financial values.
- Design OCR providers behind an abstraction so they can be replaced later.
