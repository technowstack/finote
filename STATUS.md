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
- [x] Phase 6A.1 — Account / Wallet Management
- [x] Phase 6A.2 — Assign Transactions to Account
- [x] Phase 6A.3 — Account Balance Calculation
- [x] Phase 6A.4 — Account-to-Account Transfer
- [x] Phase 6A.5 — Transaction History Integration
- [x] Phase 6A.6 — Reports Integration
- [x] Phase 6A.7 — Export Integration
- [x] Phase 6A.8 — Backup / Restore Migration
- [x] Phase 6A.9 — Legacy Database Compatibility
- [x] Phase 6A.10 — Testing & Polish
- [x] Phase 6A — Accounts & Transfers COMPLETE

## Current

Finote v1.0.0 has completed **Phase 5I — LOCAL PRODUCTION FINAL / PLAY STORE READY**.
Finote v1.1.0 completed **Phase 6A — Accounts & Transfers** through Phase 6A.10 Testing & Polish.

Current focus:

- [x] Complete Phase 6A.2 account assignment
- [x] Complete Phase 6A.3 account balance calculation
- [x] Complete Phase 6A.4 account-to-account transfer
- [x] Complete Phase 6A.5 transaction history integration
- [x] Complete Phase 6A.6 reports integration
- [x] Complete Phase 6A.7 export integration
- [x] Complete Phase 6A.8 backup/restore migration
- [x] Make account management reachable from Settings
- [x] Complete Phase 6A.9 legacy database compatibility
- [x] Complete Phase 6A.10 testing and polish
- [x] Add safe permanent deletion for unused non-default accounts
- [x] Preserve financial accuracy and data integrity
- [x] Keep release configuration healthy
- [ ] Perform external Play Store activities only when the user is ready

## Current Product State

```text
Finote v1.0.0 foundation remains local production final.
Finote v1.1.0 Accounts & Transfers is feature complete / stabilization-ready.
```

Local production final means the v1.0.0 codebase is considered finalized locally. It does **not** mean the app has already been uploaded, externally closed-tested through Play Console, or published to production.

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

## Next After v1.0

- [ ] Continue real daily usage / bug-fix period
- [x] v1.1.0 — Phase 6A.1 Account / Wallet Management
- [x] v1.1.0 — Phase 6A.2 Assign Transactions to Account
- [x] Phase 6A.3 — Account Balance Calculation
- [x] Phase 6A.4 — Account-to-Account Transfer
- [x] Phase 6A.5 — Transaction History Integration
- [x] Phase 6A.6 — Reports Integration
- [x] Phase 6A.7 — Export Integration
- [x] Phase 6A.8 — Backup / Restore Migration
- [x] Phase 6A.9 — Legacy Database Compatibility
- [x] Phase 6A.10 — Testing & Polish
- [x] Phase 6A — Accounts & Transfers COMPLETE

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

### Planned v1.1.0 — Phase 6A Accounts & Transfers

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

Migration rule when Phase 6A starts:

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

Legacy transaction without account information must be assigned to the Default Account during future import/migration. The legacy database remains read-only.

**Do not implement any Phase 6A schema or feature during v1.0 finalization.**

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

Finote v1.0.0 is now in **maintenance / real-usage mode**.

Current rules:

1. Use Finote in realistic daily scenarios.
2. Fix only real bugs, data-integrity issues, security/privacy issues, compatibility issues, and measured reliability/performance problems.
3. Keep financial reconciliation intact: Dashboard = Reports = Export for equivalent data/filter semantics.
4. Keep backup/restore/migration/legacy-import safety intact.
5. Keep AI frozen.
6. Do not automatically add Wallet/Accounts, Budget, Recurring, Cloud, or other post-v1 features.
7. Keep Phase 6A parked until the user explicitly starts it.
8. External Play Store tasks may be completed later without changing the v1.0 core scope.

When the user eventually starts Phase 6A, first inspect the actual Drift schema and migration history before changing any database structure.
