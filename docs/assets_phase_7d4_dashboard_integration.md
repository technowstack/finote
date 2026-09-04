# Finote v1.3.0 - Phase 7D.4 Dashboard Integration

Status: **COMPLETE**

## Dashboard composition

Home uses the shared `NetWorthSnapshot` for current financial position:

```text
Kekayaan Bersih = Kas & Dompet + Portofolio
```

The primary summary card shows Net Worth with Cash and Portfolio breakdowns.
The previous account-only `Total aset` headline was removed to avoid presenting
two competing asset totals. Monthly Income and Expense remain period-based
secondary metrics.

Portfolio values come from the existing local `PortfolioSnapshot` through
`netWorthProvider`. Home does not recalculate holdings, account balances, or
portfolio value and does not request market prices.

## Navigation and states

The Portfolio breakdown is tappable and uses the existing `/portfolio` route.
Complete, partial, and unavailable portfolio values retain the existing
`NetWorthSnapshot` semantics. Unavailable portfolio value is shown as
`Belum tersedia`; partial totals remain explicitly marked as temporary.

No hide-balance preference exists in the current application, so this phase
does not add a new privacy setting or masking policy.

## Scope exclusions

This phase does not add charts, P/L, ROI, liabilities, historical Net Worth,
watchlists, automatic refresh, or new navigation routes.

## Validation

Dashboard widget coverage verifies the current Net Worth summary and the
Portfolio summary navigation. `flutter analyze`, `flutter test`, and
`flutter build apk --debug` pass.
