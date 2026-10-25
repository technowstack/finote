# Navigasi dan User Flow

## Graph

```mermaid
flowchart TD
  Launch[main.dart] --> App[FinoteApp]
  App --> Gate[AppLock root gate]
  Gate --> Shell[StatefulShellRoute]
  Shell --> Home[/ Dashboard]
  Shell --> Tx[/transactions]
  Shell --> Portfolio[/portfolio]
  Shell --> Reports[/reports]
  Shell --> Settings[/settings]
  Tx --> New[/transactions/new]
  Tx --> Detail[/transactions/:id]
  Detail --> Edit[/transactions/:id/edit]
  Reports --> Analytics[/reports/analytics]
  Reports --> Month[/reports/history/:month]
  Settings --> Accounts[/accounts]
  Settings --> Categories[/categories]
  Settings --> Backup[/backup]
  Settings --> Import[/legacy-import]
  Settings --> Security[/security]
  Accounts --> Transfers[/transfers]
  Home --> Scan[/receipt-scan]
```

## Flow 1 — Launch → Dashboard

- Entry: `main()` → `ProviderScope` → `FinoteApp` → `/`.
- State: theme async provider, database provider, App Lock controller, dashboard streams.
- Data: account/transaction aggregates and net worth; local only on initial render.
- Errors: root App Lock error gate; dashboard summary/recent transaction retry states.
- Friction: initialization errors are generic and can make it unclear which subsystem failed.

## Flow 2/3 — Add income/expense

1. Dashboard/Transactions FAB → `_showAddMenu`.
2. `Tambah transaksi manual` → `/transactions/new`.
3. `TransactionFormPage` initializes default categories, then `_TransactionForm` defaults expense and today (`transaction_form_page.dart:31-59`, `93-120`).
4. User enters integer IDR, selects type/category/account/date, optionally title/note.
5. Save validates and calls transaction repository; transaction insert is inside DB transaction and resolves category/account.
6. Reactive streams update dashboard/history/reports.

**Validation:** amount positive integer; category/type compatibility; account resolution; date-only converter. **Error:** disabled save/loading and generic Indonesian SnackBar/error page. **Friction:** category initialization is a hard gate before a blank form.

## Flow 4 — Edit/delete transaction

- Entry: history row/detail → `/transactions/:id` → edit route.
- Edit loads active transaction with `findActiveById`; save updates source row and preserves source/relations according to repository.
- Delete is soft delete in ordinary CRUD; dependent totals react through Drift streams.
- If category/account join is missing, list/detail paths may fail differently because some use inner joins and others left joins.

## Flow 5 — Transfer

- Entry: Accounts app bar action → `/transfers`.
- Requires at least two active accounts (`transfers_page.dart:28-43`).
- Dialog validates distinct accounts, positive amount, active accounts; repository writes `transfers` only.
- Transfers affect account balances but are not income/expense; history/report includes a separate transfer type.
- Delete is soft delete; edit allows archived accounts used by existing transfer.

## Flow 6 — Account/wallet

- Entry: Settings → `/accounts`.
- FAB opens dialog; repository writes name/type/initial balance.
- Accounts with history cannot be permanently deleted; can be archived. Default account cannot archive.
- Stream `accountSummariesProvider` recomputes income/expense/incoming/outgoing transfer totals.

## Flow 7 — Reports/filter

- Entry: shell Reports → `/reports`.
- Period chips: all/today/week/month/year/custom; report and chart providers receive `ReportFilter`.
- Optional account/category filters are dialog-driven; data is SQL aggregation from active transactions/transfers.
- Current portfolio/net worth are point-in-time values and are shown alongside period flows; this separation is implemented but cognitively dense.

## Flow 8 — Analytics

- Reports → analytics route with period encoded in query URI.
- Invalid dates fall back to current month; charts query trend/category/account providers.
- No market API call is present in inspected analytics path.

## Flow 9 — Asset

- Portfolio → add asset dialog; create/update/archives/reactivate/delete-unused through `AssetRepository`.
- Asset detail handles opening position and activity actions.
- Buy/sell uses `AssetActivityService` to atomically create linked cashflow transaction + asset activity; adjustment only changes holdings.
- Portfolio valuation reads local holdings/prices; explicit `Refresh Harga` sends batch market identifiers only.

## Flow 10 — PIN/biometric

- Settings → Security.
- PIN uses secure storage verifier; 4/6 digits, PBKDF2/SHA-256, failed-attempt lockout.
- Biometric enable/disable requires device auth and availability; root `AppLock` gates child before content.
- Lifecycle paused/hidden relocks protected sessions except external activity/authentication guard.
- Android runtime enrollment/prompt matrix is **NOT VERIFIED/blocked per STATUS**.

## Flow 11 — Backup

- Settings → Backup → `BackupService.createAndSave()`.
- DB snapshot via `VACUUM INTO`, validates, ZIPs `database.sqlite` and `manifest.json`, saves with system picker.
- App Lock external-activity guard prevents file picker from being interpreted as background relock.

## Flow 12 — Restore

- Backup Restore tab → picker → ZIP parse/version/integrity validation → preview → safety backup → confirmation → close live DB → staged atomic replacement/rollback.
- Providers are expected to rebind through shared root database architecture; exact post-restore app lifecycle is partially documented in STATUS and needs runtime validation.

## Missing/not verified

- No distinct account detail route found.
- No cloud sync/user login found.
- iOS runtime flows not verified.
- External market API server behavior and production TLS/certificate posture not verified from client source.
