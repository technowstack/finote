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
- [x] Phase 6B — Reports Visualization & Analytics v1.2.0
- [x] v1.3 Portfolio primary navigation and asset UI cleanup
- [x] v1.3 Opening Portfolio Snapshot / Opening Position
- [x] v1.3 Asset Activity / Buy-Sell-Adjustment
- [x] v1.3 Holdings Calculation

## Current

Finote v1.3.0 Phase 7A Asset Domain Foundation is complete through holdings calculation. Market Data remains unimplemented.

Current focus:

- [x] Phase 7A.1 — Investment Architecture & Existing Code Audit
- [x] Inspect actual Drift schema and migration history
- [x] Inspect transaction / account / transfer / report architecture
- [x] Inspect existing `Pembelian Aset` / `Penjualan Aset` semantics
- [x] Define deterministic asset-quantity storage strategy
- [x] Define Opening Portfolio Snapshot architecture
- [x] Define asset activity ↔ cashflow relation without duplicate cashflow
- [x] Define Market API client / batch quote / offline-price-cache architecture
- [x] Define Backup/Restore and backward compatibility impact
- [x] Produce implementation plan before Phase 7A.2

## Current Product State

```text
Finote v1.2.0
REPORTS VISUALIZATION & ANALYTICS COMPLETE
FINOTE v1.3.0 ASSETS / INVESTMENTS — PHASE 7A COMPLETE
```

Finote v1.0.0 remains the first local production-final baseline. v1.1.0 added Accounts & Transfers. v1.2.0 added Reports Visualization & Analytics. v1.3.0 now extends Finote with local-first Assets / Investments without turning Finote into a trading platform. External Play Store upload/testing/publication remains a separate activity from local feature readiness.

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
- [x] v1.2.0 — Phase 6B Reports Visualization & Analytics
- [ ] v1.3.0 — Phase 7 Assets / Investments

### Phase 7A — Asset Domain Foundation

- [x] 7A.1 Investment Architecture & Existing Code Audit
- [x] 7A.2 Asset Database Schema & Migration
- [x] 7A.3 Asset CRUD & Asset Types
- [x] 7A.4 Opening Portfolio Snapshot
- [x] 7A.5 Asset Activity / Buy-Sell-Adjustment
- [x] 7A.6 Holdings Calculation

### Phase 7B — Market Data

- [ ] 7B.1 Market API Client Foundation
- [ ] 7B.2 Batch Quote Integration
- [ ] 7B.3 Local Last-Known Price Cache
- [ ] 7B.4 Manual Asset Pricing
- [ ] 7B.5 Current Market Value

### Phase 7C — Portfolio

- [ ] 7C.1 Portfolio Screen Foundation
- [ ] 7C.2 Stock Holdings UI
- [ ] 7C.3 Crypto Holdings UI
- [ ] 7C.4 Mutual Fund / Gold / Manual Assets
- [ ] 7C.5 Portfolio Summary & Refresh UX

### Phase 7D — Finance Integration

- [ ] 7D.1 Historical Investment Cashflow
- [ ] 7D.2 Net Worth Integration
- [ ] 7D.3 Reports Integration
- [ ] 7D.4 Dashboard Integration

### Phase 7E — Reliability & Release

- [ ] 7E.1 Backup / Restore Integration
- [ ] 7E.2 Backward Compatibility & Migration Tests
- [ ] 7E.3 Portfolio Performance & Offline Audit
- [ ] 7E.4 UI/UX Polish
- [ ] 7E.5 v1.3.0 Final Audit & Release Preparation

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


### Completed v1.2.0 — Phase 6B Reports Visualization & Analytics

- [x] 6B.1 Report Chart Foundation
- [x] 6B.2 Income vs Expense Preview Chart
- [x] 6B.3 Analytics Chart Screen
- [x] 6B.4 Category Expense Chart
- [x] 6B.5 Financial Trend Chart
- [x] 6B.6 Account Balance Visualization
- [x] 6B.7 Chart Filters & Interaction
- [x] 6B.8 Chart Testing & Polish

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

Current next task:

> **Phase 7A.1 — Investment Architecture & Existing Code Audit**

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

Finote v1.3.0 Phase 7A Asset Domain Foundation is complete through holdings
calculation. Market Data remains unimplemented.

Current rules:

1. Keep Phase 7A.1 audit decisions authoritative for the next implementation.
2. Keep holdings derived from active asset activities; do not add mutable totals.
3. Keep historical `Pembelian Aset` / `Penjualan Aset` as investment cashflow only.
4. Do not reconstruct holdings, cost basis, or historical P/L from old cashflow.
5. Use Opening Portfolio Snapshot / Opening Asset Position for existing holdings.
6. Preserve deterministic money handling and define a safe fractional-quantity strategy before schema implementation.
7. Keep portfolio source records local in Drift/SQLite.
8. Use Finote Market API only for normalized market prices; prefer batch quotes and local last-known-price fallback.
9. Net Worth = Cash / Wallet Assets + Current Portfolio Value.
10. Keep AI, realtime trading, WebSocket, automated trading, and unrelated feature expansion out of v1.3.0.

Next active implementation:

> **Phase 7B.1 — Market API Client Foundation**


---

## Finote v1.3.0 — Assets / Investments

### Core product rules

- Historical `Pembelian Aset` / `Penjualan Aset` remain historical investment cashflow.
- Do not reconstruct current holdings from historical investment cashflow.
- Existing users start portfolio tracking through an Opening Portfolio Snapshot / Opening Asset Position.
- Current Holdings = Opening Position + Buy - Sell + Adjustment.
- Current Portfolio Value is derived from current holdings × current/last-known/manual price.
- Net Worth = Cash / Wallet Assets + Current Portfolio Value.
- Net Cash Invested is historical cashflow only and must not be treated as portfolio value, cost basis, or P/L.
- Unknown cost basis remains unknown; do not substitute zero.
- Money remains deterministic integer source-of-truth; fractional asset quantity requires a deterministic non-binary-floating-point representation.
- Portfolio data remains in Flutter + Drift/SQLite.
- Market API stores no portfolio/holding data and is used only for normalized market quotes.
- Portfolio must render local holdings + last-known price before attempting network refresh.
- Portfolio uses `POST /api/v1/market/quotes` for batch quotes whenever possible.
- Market API failure must not block portfolio/history/reports/offline usage.
- AI, realtime trading, WebSocket, candlestick charts, automated trading, and complex portfolio analytics are out of scope for v1.3.0.

### Current active task

> **7B.1 — Market API Client Foundation** (not started)

7A.1 through 7A.6 are complete. Do not start 7B.1 automatically.
