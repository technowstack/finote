# Phase 6B.6 Account Balance Visualization

## Placement

`Analisis Grafik` now ends with:

```text
Aset
  Saldo per Akun
```

The horizontal bars follow the Income versus Expense, Expense by Category, and
Financial Trend sections. Reports keeps its existing numerical account summary
and does not render this full chart.

## Current Balance Semantics

The chart shows current account balances. The selected report period does not
change them. Its subtitle states `Saldo saat ini, tidak dibatasi periode
laporan` so an August report cannot imply an August-only account balance.

`accountBalanceChartProvider` maps the existing
`AccountRepository.watchSummaries()` stream into `AccountBalanceChartPoint`.
The shared `AccountSummary.balance` getter remains the only balance formula:

```text
balance = initial balance
        + active income
        - active expense
        + active incoming transfer
        - active outgoing transfer
```

The provider has no `ReportRange`. Account Management, Reports, export, and
Analytics therefore use the same current balance source. Amounts remain
integers until the renderer calculates bar widths.

## Accounts And Total Assets

The chart displays every active account, including the Default Account and
zero-balance accounts. It sorts them by balance descending, then account name
case-insensitively, then account ID.

Archived accounts do not receive bars. Finote's existing Total Assets semantics
include all accounts, including archived accounts, so the summary above the
bars preserves that definition. When an archived account exists, the summary
states how many archived accounts contribute to Total Assets.

An unused account with an Initial Balance may be permanently deleted under the
existing safe-deletion policy. Its bar disappears and Total Assets drops by its
balance. Default and used accounts retain their existing deletion protection.

## Positive, Negative, And Zero Balances

The renderer derives one shared scale from the smallest and largest active
integer balances. A zero baseline divides the track:

- positive balances extend right;
- negative balances extend left with the existing expense color;
- zero balances keep their account row and exact `Rp0` label.

The renderer does not clamp negative values. Every row shows account name,
account type, and compact amount. Long press shows the exact account name,
type, and signed IDR amount.

## Transfer And Initial Balance Behavior

A transfer changes its source and destination bars but not Total Assets across
all accounts. Editing the destination moves the incoming balance to the new
account. Soft deletion reverses both transfer effects.

Initial Balance contributes to account balance and Total Assets. Editing it
updates the chart without changing Income, Expense, Net, category, or trend
data.

Transaction creation, amount/type edits, account reassignment, and soft deletion
flow through the shared summary stream. Reassignment updates both account bars
while global report totals remain unchanged.

## Responsive And Accessible UI

The account section uses the existing Material 3 chart card, spacing,
typography, loading, retry, error, and empty states. It uses theme-derived
primary and negative colors in Light, Dark, and System modes.

The page keeps one vertical scroll flow. Each active account adds enough card
height for its name, type, amount, and bar, so 20 accounts remain readable
without nested scrolling. Account names truncate with ellipsis. The exact Total
Assets amount scales down when horizontal space is tight.

Bar length never carries the value alone. Visible labels, exact tooltips, and a
semantic summary expose account names, account types, balances, Total Assets,
and archived-account inclusion.

## Performance

`AccountRepository.watchSummaries()` performs one grouped account query with
joined transaction totals and grouped incoming/outgoing transfer totals. It
does not issue transaction or transfer queries per account. Analytics watches
the existing period-independent chart provider and performs no database work
inside `AccountBalanceChart`.

Backup and restore need no chart-specific handling. Restored accounts,
transactions, and transfers regenerate balances through the same repository.

## Tests

Automated coverage verifies:

- the BCA Rp12,000,000 and Tabungan Rp2,450,000 fixture;
- Total Assets Rp14,450,000 versus Reports Net Rp8,950,000;
- shared Account Management/provider balances and account type mapping;
- period independence;
- positive, negative, zero, large, and empty values;
- numeric sorting with deterministic name and ID ties;
- transfer creation, destination edit, deletion, and Total Assets invariance;
- Initial Balance and account metadata edits;
- transaction account reassignment and soft deletion;
- account archive, reactivate, creation, and safe permanent deletion;
- exact tooltip content and accessibility semantics;
- long names, 20 accounts, dark mode, 320 px layout, landscape, and 1.3 text
  scaling;
- Reports-page, export, backup/restore, and 10,000-row regressions through the
  full suite.

## Known Limitations

The chart shows current balances only. Finote has no historical balance or
net-worth series. It displays all active accounts instead of a Top N aggregate
because combining positive and negative balances into `Lainnya` would obscure
account position. Phase 6B.7 added shared filters without changing this overall
current-balance view.
