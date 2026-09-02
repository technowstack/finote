# Finote Development Status

## Completed

- [x] Phase 0 — Foundation
- [x] Phase 1 — Core Finance
- [x] Phase 2 — Backup / Restore / Legacy Import
- [x] Phase 3 — Personal Use Ready
- [x] Phase 3.5H — Theme Mode & Color System
- [x] Phase 4A — Receipt Scanner Foundation
- [x] Phase 4B — On-device OCR
- [x] Phase 4C — Receipt Parser
- [x] Phase 4D — Auto Transaction Draft
- [x] Phase 4D.1 — Receipt Review & Itemized Transaction Fix
- [x] Phase 4D.2 — Receipt Review Completion & AI-Ready OCR Pipeline
- [x] Phase 4E — Receipt Category Suggestion
- [x] Phase 4F — Receipt Safety & Duplicate Detection
- [x] Phase 4G — Receipt Scanner Polish & Automated Coverage
- [x] Phase 5A — Export Excel / Text / PDF
- [x] Phase 5B — Core Finance Audit & Stabilization
- [x] Phase 5C — Transaction UX & Workflow Hardening
- [x] Phase 5D — Reports & Financial Accuracy
- [x] Phase 5E — Backup / Restore / Legacy Migration Hardening
- [x] Phase 5F — Performance & Reliability
- [x] Phase 5G — Play Store Preparation
- [x] Phase 5H — Closed Testing Preparation / Release Candidate Validation (local)
- [x] Phase 5I — LOCAL PRODUCTION FINAL / PLAY STORE READY v1.0.0
- [x] Phase 6A — Accounts & Transfers v1.1.0
- [x] Safe Account Deletion Polish

## Current

Finote v1.1.0 has completed **Phase 6A — Accounts & Transfers** including final testing/polish and Safe Account Deletion polish.

Current focus:

- [x] Phase 6B.1 — Report Chart Foundation
- [x] Phase 6B.2 — Income vs Expense Preview Chart
- [x] Phase 6B.3 — Analytics Chart Screen
- [x] Phase 6B.4 — Category Expense Chart
- [x] Phase 6B.5 — Financial Trend Chart
- [x] Phase 6B.6 — Account Balance Visualization
- [x] Keep Reports concise: summary + one primary chart preview
- [x] Move complete chart exploration to the dedicated Analytics screen
- [x] Preserve Income / Expense / Net correctness
- [x] Keep Transfer excluded from Income / Expense charts
- [x] Keep Accounts & Transfers regression-safe
- [ ] Continue real usage and fix real bugs discovered during development

## Current Product State

```text
Finote v1.1.0
ACCOUNTS & TRANSFERS COMPLETE
PHASE 6B REPORT VISUALIZATION & ANALYTICS — IN PROGRESS
PHASE 6B.6 ACCOUNT BALANCE VISUALIZATION COMPLETE
```

Finote v1.0.0 remains the first local production-final baseline. v1.1.0 extends it with Accounts & Transfers. External Play Store upload/testing/publication remains a separate activity from local feature readiness.

## External Release When Ready

The following may remain pending until the actual Google Play release window:

- [ ] Final production signing / upload-key configuration as needed
- [ ] Final versionCode confirmation
- [ ] Public Privacy Policy URL
- [ ] Final screenshots / feature graphic
- [ ] Play Console Data Safety submission
- [ ] Content rating / target audience / ads declarations
- [ ] Upload final `.aab`
- [ ] Configure actual Play Console closed testing if required
- [ ] Production submission / rollout

These external tasks do not reopen the v1.0 feature scope.

## Next Development

- [x] v1.1.0 — Phase 6A Accounts & Transfers
- [x] Safe Account Deletion polish
- [ ] v1.2.0 — Phase 6B Reports Visualization & Analytics
- [x] 6B.1 Report Chart Foundation
- [x] 6B.2 Income vs Expense Preview Chart
- [x] 6B.3 Analytics Chart Screen
- [x] 6B.4 Category Expense Chart
- [x] 6B.5 Financial Trend Chart
- [x] 6B.6 Account Balance Visualization
- [ ] 6B.7 Chart Filters & Interaction

---

## Product Direction

Finote is an **offline-first personal finance application**.

The current product priority is to make the manual finance experience:

- stable;
- fast;
- accurate;
- comfortable for daily use;
- safe for long-term financial data;
- fully usable offline;
- ready for Google Play Store distribution.

The core product must not depend on AI, cloud services, or user accounts.

### Current release priorities

1. Data integrity
2. Transaction CRUD
3. Categories
4. Transaction entry UX
5. Dashboard
6. Search / Filter
7. Reports
8. Export Excel
9. Export Text
10. Export PDF
11. Backup
12. Restore
13. Legacy Import
14. Theme / Basic Security
15. Performance
16. Play Store Release
17. Real User Feedback

---

## Export — Core Release Feature

Export is now a **core Finote feature** and is required before the first public release.

Required formats:

- [ ] Excel (`.xlsx`)
- [ ] Text (`.txt`)
- [ ] PDF (`.pdf`)

Required capabilities:

- [ ] Export all transactions
- [ ] Export today
- [ ] Export this week
- [ ] Export this month
- [ ] Export custom date range
- [ ] Filter income / expense where applicable
- [ ] Export totals consistent with Reports
- [ ] Exclude soft-deleted transactions
- [ ] Work fully offline
- [ ] Save using Android system file/document APIs
- [ ] Share exported files where supported
- [ ] Handle empty datasets safely
- [ ] Handle large datasets without crashing

Export is separate from Backup:

- **Backup** = application recovery / restoration
- **Export** = reporting / portability / sharing

---

## Receipt Scanner Status

Receipt Scanner has already been developed locally through Phase 4G.

Current capabilities include:

- camera/gallery input;
- on-device OCR;
- local receipt parser;
- merchant/date/total extraction;
- multiple receipt items;
- manual add/edit/delete item;
- receipt review;
- single transaction mode;
- itemized transaction mode;
- local category suggestion;
- local category learning;
- duplicate receipt detection;
- reconciliation warnings;
- save safety;
- temporary image cleanup.

### Release rule

Receipt Scanner is **not a release-critical core feature** for Finote v1.0.

It may remain available only if manual device testing shows that it is sufficiently reliable and safe.

If reliability is not good enough:

- keep the code;
- do not expand it;
- hide it behind a feature flag or experimental setting;
- do not delay the core Finote release because of scanner accuracy.

---

## AI Feature Freeze

AI development is currently frozen.

Do NOT implement or expand:

- AI Receipt Interpretation
- AI Receipt Scan
- AI OCR Parsing
- AI Categorization
- AI Financial Assistant
- AI Financial Recommendations
- OpenAI integration
- Gemini integration
- Claude integration
- AI Gateway / Backend
- AI Subscription Infrastructure

AI features may only be reconsidered after:

- [ ] Finote is released publicly on Google Play
- [ ] Finote has real active users
- [ ] AI-related user demand is validated
- [ ] Server/API budget is available
- [ ] Privacy design is ready
- [ ] Premium/subscription strategy is defined

Existing AI-ready abstractions may remain only if they do not create unnecessary maintenance complexity.

---

## Deferred Features

### Completed v1.1.0 — Phase 6A Accounts & Transfers

- [x] 6A.1 Account / Wallet Management
- [x] 6A.2 Assign Transactions to Account
- [x] 6A.3 Account Balance Calculation
- [x] 6A.4 Account-to-Account Transfer
- [x] 6A.5 Transaction History Integration
- [x] 6A.6 Reports Integration
- [x] 6A.7 Export Integration
- [x] 6A.8 Backup / Restore Migration
- [x] 6A.9 Legacy Database Compatibility
- [x] 6A.10 Testing & Polish

Core rule:

> Transfer antar account milik user bukan Income dan bukan Expense. Transfer hanya memindahkan saldo/aset antar account.

Migration rule used for Phase 6A:

```text
Create accounts
↓
Create Default Account / Cash
↓
Add nullable account relation to existing transactions
↓
Backfill existing records
↓
Validate
↓
Only tighten constraints when safe
```

Legacy transactions without account information are assigned to the Default Account during import/migration. The legacy database remains read-only.

Safe Account Deletion polish is complete: only unused non-default accounts may be hard-deleted; used/default accounts remain protected and may be archived/deactivated as appropriate.


### Planned v1.2.0 — Phase 6B Reports Visualization & Analytics

- [x] 6B.1 Report Chart Foundation
- [x] 6B.2 Income vs Expense Preview Chart
- [x] 6B.3 Analytics Chart Screen
- [x] 6B.4 Category Expense Chart
- [x] 6B.5 Financial Trend Chart
- [x] 6B.6 Account Balance Visualization
- [ ] 6B.7 Chart Filters & Interaction
- [ ] 6B.8 Chart Testing & Polish

Core chart rules:

- Charts use the same Report/aggregation source of truth.
- Transfer is not Income and not Expense.
- Initial Balance is not Income.
- Income / Expense / Net values in charts must reconcile with Reports for equivalent filters.
- Account balance visualization must reuse the shared derived account balance formula.
- Charts must support Light / Dark / System theme.
- Charts must handle empty/zero data safely.
- Large datasets should use aggregated queries rather than calculating raw transaction lists inside widgets.

Target visualization architecture:

```text
Reports
├── Financial Summary
├── Income vs Expense Preview
├── [Lihat Analisis Grafik]
├── Category Summary
├── Account Summary
└── Transfer Summary

Analisis Grafik
├── Income vs Expense
├── Financial Trend
├── Expense by Category
└── Account Balance Visualization
```

UX principle:

```text
Reports = quick financial summary
Analytics Chart Screen = deeper visual analysis
```

Recommended next phase:

> **Phase 6B.7 — Chart Filters & Interaction**

### Other Post-v1 Candidate Features

- [ ] Budget
- [ ] Recurring Transactions
- [ ] Google Drive / Cloud Backup
- [ ] Advanced Reports
- [ ] Optional User Account
- [ ] Multi-device Sync

These features should be prioritized based on real usage/feedback and explicit product decisions.

### Deferred AI Features

- [ ] AI Receipt Interpretation
- [ ] AI Categorization
- [ ] AI Financial Assistant
- [ ] AI Gateway
- [ ] Premium AI Features

---

## Release-Critical Core

The following are release-critical for Finote v1.0:

- [x] Manual income creation
- [x] Manual expense creation
- [x] Transaction editing
- [x] Transaction deletion
- [x] Category management
- [x] Transaction history
- [x] Search
- [x] Filters
- [x] Dashboard
- [x] Reports
- [x] Backup
- [x] Restore
- [x] Legacy database import
- [x] Light / Dark / System theme
- [x] Basic security
- [x] Excel export
- [x] Text export
- [x] PDF export
- [x] Core finance stabilization audit
- [x] Financial accuracy audit
- [x] Backup / restore / legacy hardening
- [x] Performance validation
- [x] Play Store preparation
- [x] Closed testing preparation / local RC validation
- [x] Local production finalization v1.0.0
- [ ] Actual Play Console closed testing (external, when ready)
- [ ] Production release (external, when ready)

---

## v1.0 Target

Finote v1.0 should include:

- Transaction CRUD
- Categories
- Dashboard
- Transaction History
- Search
- Filter
- Reports
- Excel Export
- Text Export
- PDF Export
- Backup
- Restore
- Legacy Import
- Theme System
- Basic Security
- Offline Usage

Receipt Scanner:

> Optional for v1.0 depending on stability.

AI:

> Not included in v1.0.

---

## Immediate Action

Finote v1.1.0 has completed **Accounts & Transfers** and Phase 6B — Reports Visualization & Analytics is now in progress.

Current rules:

1. Phase 6B.1 Report Chart Foundation through 6B.6 Account Balance Visualization are complete.
2. Continue with Phase 6B.7 — Chart Filters & Interaction only when explicitly requested.
3. Keep Reports concise: Financial Summary + one primary Income vs Expense preview + entry point to Analytics.
4. Place the complete chart experience on the dedicated Analytics Chart Screen.
5. Reuse existing Reports aggregation as financial source of truth.
6. Keep Income / Expense / Net semantics unchanged.
7. Never include Transfer in Income or Expense charts.
8. Keep Account Balance derived from initial balance + transactions + transfers.
9. Preserve Reports = Charts = Export consistency for equivalent financial metrics/filters.
10. Keep AI, Cloud, Budget, and Recurring features deferred unless explicitly requested.

Recommended next phase, not started:

> **Phase 6B.7 — Chart Filters & Interaction**
