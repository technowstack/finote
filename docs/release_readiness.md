# Release Readiness

Candidate: Finote `1.0.0` / `versionCode 1` / proposed `v1.0.0-rc.1`

Status values: `PASS`, `WARNING`, `FAIL`, `NOT TESTED`.

| Area | Status | Evidence / remaining gate |
| --- | --- | --- |
| Core Finance | PASS | 125 automated tests pass, including transaction/category/dashboard flows. Device script remains. |
| Data Integrity | WARNING | Automated restore/import safeguards pass; real-device restore and historical migration fixture remain. |
| Reports | PASS | Deterministic report tests pass. Manual period comparison remains. |
| Export | WARNING | Excel/Text/PDF generators and 10,000-row coverage pass; physical open/share and PDF visual inspection remain. |
| Backup | WARNING | Archive/SQLite integrity tests pass; restart and multiple-device lifecycle remain. |
| Restore | WARNING | Atomic and failed-restore tests pass; mounted-stream real-device validation remains release-critical. |
| Legacy Import | WARNING | Synthetic mapping/repeat/rollback tests pass; historical and copied-file behavior need manual confirmation. |
| Performance | WARNING | 10,000-row automated benchmark passes; device startup/scroll/memory measurement remains. |
| Privacy | WARNING | Drafts exist; public URL, contact details, and final dependency review remain. |
| Android Release | WARNING | APK/AAB build; target SDK and ID verified. Candidate is debug-signed without private upload-key configuration. |
| Known Issues | WARNING | Default launcher/splash assets remain; scanner classification and external manual tests remain. |

## Release Gates

Block v1.0 when any of these occurs:

- BLOCKER bug remains.
- CRITICAL financial, restore, migration, or duplicate-record bug remains.
- Release build fails.
- Reports and exports disagree.
- Restore can lose current data.
- Legacy import duplicates normal repeat imports.
- Upgrade migration loses data.
- Core offline usage fails.
- Final candidate uses the debug signing key.

LOW/MEDIUM cosmetic issues may ship when documented and they do not affect
data, totals, recovery, or core usability.

## Candidate Sanity Audit

- PASS: no debug banner in release mode.
- PASS: synthetic data generators exist only under `test/`.
- PASS: OCR diagnostics are guarded by `kDebugMode`.
- PASS: no developer-only performance navigation or hidden test route found.
- PASS: no AI endpoint or application development endpoint found.
- WARNING: `INTERNET` and `ACCESS_NETWORK_STATE` enter the merged release manifest through the ML Kit transport dependency; recheck before submission.
- WARNING: release signing falls back to debug when `android/key.properties` is absent.

## External Work Remaining

- Run the device matrix, airplane-mode suite, lifecycle suite, and upgrade test.
- Generate/configure the private upload key and verify the signed artifact.
- Finish launcher/splash/store assets and publish the privacy policy.
- Decide whether Receipt Scanner remains experimental or becomes hidden.
- Configure Internal/Closed Testing manually later. Nothing in this repository uploads to Play Console.
