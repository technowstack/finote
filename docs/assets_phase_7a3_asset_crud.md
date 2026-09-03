# Finote v1.3.0 — Phase 7A.3 Asset CRUD & Asset Types

Status: **COMPLETE**

## Scope

This phase manages asset master data only. An asset identifies an instrument or
manual investment object; it is not a transaction, holding, quote, or value.

Deferred to later phases: opening positions, buy/sell/adjustment UI, holdings,
market API, prices, valuation, P/L, portfolio summary, Net Worth, and report or
dashboard integration.

## Architecture

- `AssetRepository` owns validation, persistence, reactivity, archive/restore,
  and deletion safety.
- `AssetsPage` is the Portfolio screen and the shared master-data screen.
- `AssetDetailPage` is a minimal read-only detail route.
- `allAssetsProvider` drives the reactive active and archived lists.
- Existing Drift database and Material 3 components are reused.

## Types and Pricing

| Stored type | Label | Default pricing | Unit metadata |
| --- | --- | --- | --- |
| `stock` | Saham | API | `share` |
| `crypto` | Crypto | API | `coin/token` |
| `mutualFund` | Reksadana | Manual | `unit` |
| `gold` | Emas | Manual | `gram` |
| `other` | Lainnya | Manual | `unit` |

API pricing is configuration only in this phase. No network request is made.

## Validation and Lifecycle

- Name is required and trimmed.
- Stock and crypto symbols are required; other types may omit them.
- Symbols are trimmed and normalized to uppercase for lookup. Display input is
  kept in its trimmed form.
- Uniqueness follows the schema identity `(asset_type, normalized_symbol)`.
- Duplicate symbols return a user-safe message instead of a raw SQLite error.
- Active assets can be archived and archived assets can be reactivated.
- Assets without any asset activity can be hard-deleted.
- Assets with any activity, including soft-deleted activity, cannot be hard
  deleted; activity history is never cascade-deleted.

## UI States

- Active assets are grouped by type and show name, symbol, and pricing mode.
- Archived assets are shown separately with restore support.
- Empty state explains that assets must be added manually; old investment
  transactions do not create assets automatically.
- Asset detail shows name, symbol, type, pricing mode, status, and a clear
  no-position message. It does not show fake holdings or zero portfolio value.
- Forms use scrolling dialogs and work offline without market metadata lookup.

## Portfolio Navigation

The v1.3 bottom navigation order is:

```text
Beranda -> Transaksi -> Portofolio -> Laporan -> Pengaturan
```

Portfolio currently shows tracked active assets and the honest state
`Belum ada posisi`. It does not calculate or display holdings, prices, value,
P/L, or Net Worth. Asset detail navigation preserves the Portfolio context;
asset management does not have a separate Settings shortcut.

## Tests

Coverage includes all five types, pricing defaults, symbol normalization and
duplicates, identity-preserving edit, archive/restore, unused deletion,
history-protected deletion, detail flow, and reactive UI updates.

## Deferred Functionality

Opening Position begins in Phase 7A.4. Activity workflows and holdings remain
deferred to 7A.5/7A.6. Market pricing begins in Phase 7B. No backup format or
financial report behavior was changed by this phase; raw SQLite backup already
captures the asset tables introduced in 7A.2.
