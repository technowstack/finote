# Closed Testing Plan

## Scope

Test Finote `1.0.0` with dummy or non-sensitive data. Do not upload the APK or
AAB from this repository automatically. Do not collect raw databases,
receipts, screenshots containing balances, or logs containing financial data.

## Test Groups

| Group | Scenarios | Pass condition |
| --- | --- | --- |
| A. Installation | Fresh install, launch, uninstall | Installs, launches, and removes app data according to Android behavior. |
| B. First-run | Seed defaults, initialize theme, save first transaction | No crash, duplicate seed, broken empty state, or internet requirement. |
| C. Transactions | Expense/income add, edit, type/category/date/note changes, delete, rapid save, cancel | One intended record, correct fields, correct totals, no accidental save. |
| D. Categories | Create income/expense, rename, delete, use existing category, referenced deleted category | Safe validation; no crash, silent remap, or invalid transaction. |
| E. Dashboard | Balance, current-period income/expense, today count, recent rows | Matches the known dataset and Reports. |
| F. Search & Filters | Keyword, type, today/week/month/custom, type+keyword, type+range, category if available | Every combination returns the expected active records. |
| G. Reports | Today/week/month/custom, totals, balance, breakdown, monthly history | Deterministic values match source transactions. |
| H. Exports | Excel/Text/PDF generate, save, open, share, filters, soft-delete exclusion, large data | Files open and equal Reports for count, range, and totals. |
| I. Backup | Create data, backup, restart, inspect archive, create several backups | Data survives; each archive is valid and distinct. |
| J. Restore | Backup A, add B, restore A, verify safety backup and derived views | State returns to A without data loss. |
| K. Legacy Import | Valid synthetic DB, preview, import, totals, repeat import | Mapping is correct and repeat import creates no duplicates. |
| L. Theme | System/light/dark, restart, switch device theme in System | Selection persists and follows the expected device theme. |
| M. Security | Enable/change/disable PIN if supported, correct/incorrect PIN, reopen/resume | Protected content stays hidden; valid PIN unlocks; invalid PIN fails safely. |
| N. Performance | 100, 1,000, and 10,000+ transactions; startup, scroll, search, report, export, backup | Usable without crash, corruption, or unacceptable interaction failure. |
| O. Upgrade | Install old build, create data, install candidate over it, reopen | Migration preserves transactions, categories, settings, theme, reports, exports, and backup. |
| P. Reliability | Background/foreground, lock/unlock, rotation, process recreation, interruption during work | App resumes safely; retry does not duplicate or corrupt data. |
| Q. Receipt Scanner | Camera/gallery, partial OCR, manual correction, duplicate, category suggestion, single/itemized save | Only run if exposed; use `docs/receipt_scanner_manual_test.md`. |

## First-Run Script

1. Install the candidate on a clean device or emulator.
2. Launch without network access.
3. Confirm default income and expense categories appear once.
4. Confirm the selected System theme initializes without a blank/broken screen.
5. Create one expense and confirm the dashboard and history update.
6. Restart and confirm the record remains exactly once.

## Transaction Script

Use known values: income `1,000,000`, expense `25,000`, and a second expense
`50,000`. After each operation compare history, dashboard, Reports, and the
expected balance. Cover add/edit/type/category/date/title/note/delete, rapid
save, and cancelling an unsaved form.

## Report and Export Script

Use a deterministic dataset spanning today, this week, this month, a custom
range, both transaction types, two categories, and one soft-deleted record.
For each period and type filter, compare Reports with Excel, Text, and PDF:
transaction count, income, expense, balance, dates, and category values.

Inspect Excel sheets, headers, numeric cells, and dates. Open Text as UTF-8.
Open PDF, inspect multiple pages, clipping, totals, table readability, and
Indonesian text. Also test empty and 10,000-row exports.

## Restore and Import Script

Use a disposable dataset. Validate the backup archive and SQLite integrity.
Restore after adding extra records, then inspect dashboard, Reports, and
exports. Try corrupt ZIP, malformed manifest, missing database, unsupported
version, and random file; current data must remain untouched. Import a
synthetic legacy database twice and compare counts after each run.

## Offline Script

Enable airplane mode before launch. Run first-run, CRUD, categories, dashboard,
Reports, search, filters, exports, backup, restore, and legacy import. The
receipt scanner may require device capability and is tested separately.

## Test Data Rules

- Use dummy or redacted values.
- Never request raw financial data for a bug report.
- Never commit real receipt images, OCR text, databases, backups, or logs.
- Ask testers to record counts and expected-vs-actual totals instead of sharing private files.

## Feedback Flow

Testers submit `docs/bug_report_template.md` for defects and
`docs/tester_feedback_template.md` for usability feedback. Log feature ideas
in `docs/post_v1_ideas.md`; do not add feature work during testing unless it
fixes a release blocker.

## Future Play Flow

`AAB -> Play Console -> Internal Testing -> Closed Testing -> feedback -> fixes`
then repeat the candidate gates. This document does not perform any Play
Console action.
