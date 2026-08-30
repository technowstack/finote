# Release Feature Matrix

Candidate: Finote `1.0.0` / `versionCode 1`

| Feature | Status | Evidence or release rule |
| --- | --- | --- |
| Transaction CRUD | READY | Automated CRUD and widget coverage; manual device pass remains required. |
| Categories | READY | Repository and widget coverage, including safe deletion behavior. |
| Dashboard | READY | Repository/widget coverage and report reconciliation tests. |
| Search | READY | History query and widget coverage. |
| Filters | READY | Date/type filter coverage; device combinations remain pending. |
| Reports | READY | Deterministic report totals and period tests. |
| Excel Export | READY | ZIP/workbook structure, numeric values, filters, and large document tests. |
| Text Export | READY | UTF-8 generator and totals tests; device open/share test remains pending. |
| PDF Export | READY | PDF generation and large-document tests; visual inspection remains pending. |
| Backup | READY | Archive, manifest, SQLite integrity, and large-data automated coverage. |
| Restore | READY | Validation, atomic replacement, rollback, and safety-path tests; real-device lifecycle remains a gate. |
| Legacy Import | READY | Synthetic SQLite fixtures, mapping, repeat-import, and rollback tests. |
| Theme System | READY | System/light/dark persistence coverage; device theme-switch test remains pending. |
| PIN | READY | Correct, incorrect, lockout, startup, and resume coverage. |
| Receipt Scanner | EXPERIMENTAL | Local OCR/parser flow exists; classify as stable only after manual scanner matrix passes. Hide it if HIGH or CRITICAL issues remain. |
| AI | DEFERRED | Explicitly frozen by PRD and release direction. |
| Wallet | DEFERRED | Post-v1 feature. |
| Budget | DEFERRED | Post-v1 feature. |
| Recurring | DEFERRED | Post-v1 feature. |
| Cloud | NOT INCLUDED | Core release remains local and offline-first. |

READY means the feature belongs in the candidate and has automated evidence.
It does not waive device testing. EXPERIMENTAL features cannot block the core
release unless the feature is advertised as stable and enabled for v1.0.
