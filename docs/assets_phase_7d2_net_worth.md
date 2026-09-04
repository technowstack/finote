# Finote v1.3.0 - Phase 7D.2 Net Worth Integration

Status: **COMPLETE**

## Definition and sources

```text
Kekayaan Bersih = Kas & Dompet + Nilai Portofolio Saat Ini
```

`Kas & Dompet` is the sum of current balances from the existing account
aggregation, including archived accounts according to current account-summary
semantics. Account balances retain their existing initial balance, income,
expense, and transfer formula.

`Nilai Portofolio Saat Ini` is read from the existing local `PortfolioSnapshot`.
Net Worth does not recalculate holdings or quantity times price, and it does
not initiate market refreshes.

## Completeness

- No current holdings: portfolio is zero and Net Worth is complete.
- Some valued and some unvalued holdings: known Net Worth is shown as temporary
  with the unavailable asset count.
- Holdings with no valid prices: cash remains known, but Net Worth is temporary
  and portfolio value is unavailable, never silently treated as zero.
- Portfolio integrity issues also make Net Worth temporary.

Manual prices, valid stale API prices, and last-known API prices contribute to
the current portfolio value. Archived assets follow the active
`PortfolioSnapshot` exclusion policy. Negative account balances are preserved;
negative holdings remain an integrity issue.

## Separation rules

Net Cash Invested, Total Pembelian Aset, and Total Penjualan Aset are historical
cashflow and are never added to Net Worth. Legacy investment transactions affect
Net Worth only through their existing account-balance effect. Opening Position
affects holdings and therefore portfolio value when priced, but never cash.
Buy/Sell affect cash and holdings through their existing linked records; no
amount is applied a second time. Transfers do not change total cash or Net Worth
by themselves. Income and Expense continue to affect Net Worth through account
balances.

## UI and boundaries

Dashboard now shows `Kekayaan Bersih`, `Kas & Dompet`, and `Portofolio` as a
compact current-state summary. The existing account-only `Total aset` display is
retained as `Kas & Dompet` to avoid ambiguity. Reports keeps Net Flow and
Income/Expense aggregation separate; Net Worth is not added to reports totals.

No liabilities, historical timeline, P/L, performance, or persisted Net Worth
value is introduced. Restore recalculates from source records. Opening Home or
Portfolio remains network-free; explicit `Refresh Harga` updates local prices,
which reactively updates Net Worth.

## Validation

Coverage includes composition, partial and unavailable portfolio states, no
portfolio holdings, negative net cash exclusion, and Dashboard integration.
Existing account, transfer, portfolio, market-refresh, investment-cashflow, and
Reports regression tests remain required.
