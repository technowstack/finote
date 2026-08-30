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

## Current

- [ ] Complete Phase 4G manual real-device validation using `docs/receipt_scanner_manual_test.md`.
- [ ] Record remaining OCR/parser limitations without expanding scope into AI.
- [ ] Decide whether Receipt Scanner is:
  - stable enough for v1.0,
  - experimental but usable, or
  - hidden behind a feature flag for the first public release.
- [ ] Complete Phase 5A manual export validation on Android: save, share, open, date/type filters, and all themes.
- [ ] Resolve or explicitly accept the remaining risks documented in `docs/core_stability_audit.md` before release.
- [ ] Complete real-device backup/restore validation, including app restart and 10,000+ transactions.
- [ ] Complete real-device performance/profile validation for long lists, exports, and lifecycle interruptions.

## Next

- [ ] Phase 5H — Closed Testing
- [ ] Phase 5I — Production Release v1.0

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

### Post-v1 Candidate Features

- [ ] Wallet / Accounts
- [ ] Budget
- [ ] Recurring Transactions
- [ ] Google Drive / Cloud Backup
- [ ] Advanced Reports
- [ ] Optional User Account
- [ ] Multi-device Sync

These features should be prioritized based on real user feedback after release.

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
- [ ] Excel export
- [ ] Text export
- [ ] PDF export
- [ ] Core finance stabilization audit
- [ ] Financial accuracy audit
- [x] Backup / restore / legacy hardening
- [x] Performance validation
- [ ] Play Store preparation
- [ ] Closed testing
- [ ] Production release

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

Before starting new release-focused development:

1. Finish the Phase 4G manual device matrix.
2. Record receipt scanner limitations.
3. Freeze further scanner feature expansion.
4. Start **Phase 5A — Export Excel / Text / PDF**.
5. Continue directly into stabilization and Play Store preparation after export is complete.

Do not start AI work.
