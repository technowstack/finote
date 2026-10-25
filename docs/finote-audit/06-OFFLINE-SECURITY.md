# Audit Offline, Privacy, dan Data Safety

## Offline model

Core tables and repositories are local Drift/SQLite. Dashboard, transactions, accounts, transfers, reports, exports, backup, restore, legacy import, and settings do not require network in inspected code. Market pricing is an auxiliary external path; holdings and last-known/manual prices are local.

`PortfolioMarketQuotesController.refresh()` is explicit, deduplicates positive Stock/Crypto API holdings, sends only symbol/type/currency, and stores returned quotes locally (`portfolio_market_quotes_provider.dart:55-123`). No automatic refresh is called from portfolio build in the inspected screen.

## Storage

- SQLite file path resolves to app documents `finote.sqlite` (`app_database.dart:198-205`).
- SharedPreferences stores theme mode and biometric-enabled flag.
- `flutter_secure_storage` stores the PIN verifier.
- Backup is a ZIP with a SQLite snapshot and manifest; it is not database encryption.
- `allowBackup=false` is set in Android manifest; exact OS-level backup behavior beyond this flag is not tested here.

## PIN

`PinRepository` validates 4/6 digits, generates a cryptographically secure random salt, derives a 256-bit PBKDF2-HMAC-SHA256 verifier with 210,000 iterations, stores JSON in secure storage, compares in constant time, and locks for 30 seconds after five failures (`pin_repository.dart:30-104`, `145-203`). Plain PIN is not stored.

## Biometrics/App Lock

`LocalBiometricAuthenticator` delegates to `local_auth`; biometric-only mode, no templates or secrets are stored (`biometric_lock.dart:34-65`). Preference is a boolean in SharedPreferences (`8-25`). `AppLock` is root-level and withholds child content while uninitialized/locked (`app_lock.dart:36-69`). Lifecycle relock occurs on paused/hidden unless external picker/auth activity is marked active (`189-207`).

**STATUS evidence:** controller/widget automated tests exist, but Android biometric runtime validation is blocked/not complete (`STATUS.md:617-640`). Do not claim full device security validation.

## Backup/restore safety

Backup uses `VACUUM INTO`, validates snapshot, and writes version manifest. Restore validates ZIP size, manifest/database version, SQLite integrity, foreign keys/tables/indexes; creates a safety backup; closes live DB; stages replacement and retains rollback on failure (`backup_service.dart:34-100`, `116-179`, `229-311`).

**Critical constraint:** backup contains financial records; sharing/saving is user-directed through system picker. No biometric template/PIN verifier serialization was found in backup source. **NOT VERIFIED:** secure erasure of temporary/rollback files after all failure modes.

## Legacy import

Legacy DB is opened read-only by `sqlite3.OpenMode.readOnly` (`legacy_importer.dart:160-162`). Import occurs inside a database transaction; legacy source hash/id gives duplicate safety; type 0→expense and 1→income (`191-228`). Category matching uses active categories and exact `(name,type)` map (`48-97`), so soft-deleted matching categories can be recreated as active rows.

## Logging/privacy

`AppLogger` wraps `dart:developer` (`core/services/app_logger.dart:3-29`). UI generally logs structural failure boundaries or catches errors into user-safe Indonesian messages. The inspected source does not intentionally log amount/title/note/PIN; ongoing review should preserve this rule. **NOT VERIFIED:** release log collection/retention outside the app process.

## External permissions/services

Manifest permissions: camera, internet, biometric. Scanner uses camera/file picker and ML Kit locally. Market API uses HTTPS default URL from `app_config.dart`, but certificate pinning, backend authentication, and server privacy guarantees are **NOT VERIFIED**.

## Recovery risks

- Restore and reset are destructive boundaries and need Android end-to-end validation.
- App Lock must not lock immediately because file picker/share/biometric activities change lifecycle; code has explicit external activity flags in backup/export paths.
- No cloud sync means device loss requires user-managed backup.
