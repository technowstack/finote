# Core Stability Audit

Scope: Phase 5B release-critical core. No private financial data is included.

## Findings

### High: active transactions could reference deleted categories

- **Root cause:** Category soft-delete did not check active transaction references,
  while transaction updates require an active matching category.
- **Fix:** `CategoryRepository.softDelete` now rejects deletion when active
  transactions use the category. The UI shows a safe Indonesian explanation.
- **Test coverage:** Repository regression test covers the rejected deletion and
  confirms the category remains active.
- **Remaining risk:** Users must create/select a replacement category before the
  old category can be deleted.

### Medium: restore lifecycle is not fully coordinated with active providers

- **Root cause:** Restore closes and replaces the database while existing Drift
  streams may still be mounted; provider invalidation is handled by the backup UI.
- **Fix:** Not changed in this audit because the current file replacement flow is
  data-safe and a coordinated database restart requires an app lifecycle design.
- **Test coverage:** Existing tests cover atomic file replacement and failed
  restore rollback.
- **Remaining risk:** Real-device restore while dashboard/reports/history streams
  are mounted needs manual validation before release.

### Medium: version-1 migration coverage is incomplete

- **Root cause:** The migration history contains a broad `from < 2` branch, but
  tests do not include a realistic prior database with existing records.
- **Fix:** Not changed; no evidence of a currently failing fixture was available.
- **Test coverage:** Existing migration tests cover fresh creation and the
  available version-1 fixture.
- **Remaining risk:** Add and run a real historical v1 fixture before release.

### Medium: legacy duplicate identity is shared across source files

- **Root cause:** Every legacy import uses the same `legacySource`, so reused
  legacy IDs from different source databases can be treated as duplicates.
- **Fix:** Not changed because changing identity semantics requires a persisted
  compatibility decision for already-imported data.
- **Test coverage:** Existing tests cover repeat import protection for one source.
- **Remaining risk:** Importing two distinct legacy databases with overlapping IDs
  can skip records from the second source.

### Medium: history materializes all matching transactions

- **Root cause:** `watchHistory` returns the complete matching list and the main
  history screen has no pagination.
- **Fix:** Not changed; performance needs device measurement before choosing
  pagination or another UX change.
- **Test coverage:** Existing history/filter tests cover correctness, not device
  memory or latency.
- **Remaining risk:** Very large datasets may increase memory use and rebuild cost.

### Medium: malformed PIN records can still fail closed without recovery detail

- **Root cause:** PIN record shape validation does not enforce salt/hash lengths
  and failed-attempt bounds.
- **Fix:** Verification failures now reset the checking state and show a generic
  user-safe error instead of surfacing an exception.
- **Test coverage:** Existing PIN tests cover valid, invalid, and lockout flows.
- **Remaining risk:** Corrupt secure-storage records still require a recovery UX.

### Low: all-time report uses fixed date bounds

- **Root cause:** The Reports "Semua" period uses `2000-01-01` through
  `2100-12-31` because `ReportRange` is currently bounded.
- **Fix:** Not changed; current date pickers and schema operate within those bounds.
- **Test coverage:** Existing reports/export tests cover normal ranges and year
  boundaries within the supported UI range.
- **Remaining risk:** Imported records outside those bounds are omitted from the
  all-time report/export.

### Low: backup filename differs from the written guidance

- **Root cause:** Backup emits `finance_backup_...` while guidance says
  `finote_backup_...`.
- **Fix:** Not changed because backup compatibility and naming are outside this
  stabilization fix set.
- **Test coverage:** Existing backup tests validate archive contents and manifest.
- **Remaining risk:** Naming inconsistency only; backup data is unaffected.

## Verified Areas

- Integer amounts remain the storage and calculation type.
- Dashboard, Reports, and Export calculations use active transactions only.
- Reports/export totals reconcile in automated coverage.
- Transaction categories enforce income/expense type matching.
- Legacy databases are opened read-only.
- Restore failure paths preserve the current database in existing tests.
- No broad Android storage permission is present.
- Theme persistence and app-lock flows have existing regression coverage.
- No database schema changes were made in Phase 5B.

## Release Blockers

- Manual Android restore lifecycle validation.
- Real historical migration fixture validation.
- Two-source legacy import collision decision/test.
- 10,000+ transaction performance measurement on target devices.
