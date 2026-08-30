# Performance Audit

## Scope

Phase 5F covers startup, database queries, transaction history, Dashboard,
Reports, search/filtering, export, backup, restore, legacy import, Riverpod
providers, and resource cleanup. No real financial data was used.

## Synthetic Baseline

The repeatable benchmark is `test/performance/performance_benchmark_test.dart`.
It creates 10,000 transactions across four categories, income and expense
types, multiple years, titles, notes, and 5% soft-deleted rows. It measures
database reads, exports, and backup without timing assertions, so CI hardware
does not make the suite flaky.

Observed on the local test environment:

| Scenario | Result |
| --- | ---: |
| Transaction history, 9,500 active rows | 403 ms |
| Search | 8 ms |
| Dashboard aggregation | 10 ms |
| Report aggregation | 11 ms |
| Export document preparation | 330 ms |
| Text export | 121 ms |
| Excel export | 219 ms |
| PDF export | 6,015 ms |
| Backup | 150 ms |

These are practical baselines, not device guarantees. Startup, scrolling,
memory high-water marks, and Android lifecycle behavior require real-device
profiling.

## Findings and Fixes

### PDF table construction

- **Finding:** One 9,500-row `TableHelper.fromTextArray` caused the initial
  10,000-row PDF benchmark to exceed 120 seconds.
- **Fix:** Split PDF transaction data into 250-row tables. Each table repeats
  the header and remains compatible with `MultiPage` pagination.
- **Result:** 10,000-row PDF generation completed in about 6 seconds in the
  benchmark environment.

### Legacy import insertion

- **Finding:** Import awaited one database insert per transaction inside one
  transaction.
- **Fix:** Category mapping remains cached, while transaction rows are inserted
  with one Drift batch operation. Progress reports completion after the actual
  batch completes; no fake intermediate percentage is shown.
- **Result:** Existing mapping, duplicate protection, and rollback tests pass.

### Transaction history

- **Finding:** History materializes all matching rows, but filtering, joining,
  sorting, and search are database-side. The UI uses `ListView.builder`.
- **Decision:** Do not add pagination yet. The 9,500-row query completed in
  about 403 ms and pagination would add state and correctness complexity without
  a measured device problem.
- **Limit:** Memory and scroll jank still need Android measurement.

### Dashboard and Reports

- **Finding:** Both already use SQL aggregation and Drift reactive streams.
- **Decision:** No duplicate cache or broad provider refactor was added.
- **Result:** Dashboard and report queries completed in 10 ms and 11 ms in the
  benchmark while preserving financial totals.

### Search and filters

- **Finding:** Search and type/date filters are applied in SQL, with a 300 ms
  UI debounce. Category search uses the existing joined query.
- **Decision:** No new index was added. `%term%` search cannot benefit from a
  normal leading-prefix index, and current measured response is fast.

### Startup and resources

- Startup only initializes Flutter bindings, Indonesian date formatting, and
  the app. Database/category work remains provider-driven.
- Controllers, timers, tab controllers, observers, and receipt draft items
  have explicit disposal paths in the inspected screens.
- No persistent financial cache or isolate was added.

## Database and Index Decision

Existing indexes cover transaction date, category, type, deleted state,
receipt fingerprint, and legacy source/id. No index or schema version change
was justified by the measured workload. No generated Drift code changed.

## Reliability Review

- Export, backup, restore, and import retain existing loading/error boundaries.
- Export and backup work is asynchronous; duplicate UI actions are disabled by
  existing busy states.
- Legacy import remains transactional and read-only against the source file.
- Restore remains staged and verified according to `docs/data_safety_audit.md`.
- Financial accuracy tests remain unchanged and pass with the performance
  changes.

## Remaining Limitations

- No real Android device or profile-build timing was available.
- Startup duration and memory high-water marks are not instrumented.
- Long-list scrolling and rapid filter/search interaction need manual device
  validation.
- PDF generation is the heaviest export path; 10,000 rows completed in the
  local benchmark but should still be observed on low-memory Android devices.
- Backgrounding during exports/backups and process interruption during file
  operations need device testing.

## Release Blockers

No new automated release blocker was found. Real-device performance and
lifecycle validation remain release checks before Play Store preparation.
