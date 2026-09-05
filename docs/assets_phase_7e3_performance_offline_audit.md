# Finote v1.3.0 - Phase 7E.3 Portfolio Performance & Offline Audit

Status: **BLOCKED - automated audit passes; required Android runtime matrix unavailable**

## Executive Result

Portfolio's production path is local-first. Opening Portfolio, Home, Reports,
rebuilding widgets, and local Drift emissions do not invoke Market API. The only
production caller of the batch quote repository remains the explicit `Refresh
Harga` action.

Automated tests pass with 100 local assets, 5,000 unrelated Transactions, 5,000
activities on one Asset Detail, and a 30-asset market refresh. No schema or
index change was justified. The phase cannot receive PASS because no connected
Android device or emulator AVD exists for the required airplane-mode, profile,
scroll, lifecycle, rotation, and cold-process runtime matrix.

## Final Report

1. **Portfolio initial data flow:** `assetHoldingsProvider` runs one local SQL
   aggregate, `activeAssetPricesProvider` loads one local price map, and
   `portfolioValuationProvider` derives one shared `PortfolioSnapshot`.
2. **First-render behavior:** Portfolio waits only for local Drift holdings; it
   never waits for Market API, Reports, Home, Net Worth, or Transactions.
3. **Portfolio-open requests:** 0 in production-path search and widget tests.
4. **Home requests:** 0; Home reads `netWorthProvider`, not the market controller.
5. **Reports requests:** 0; Reports reads local report and Net Worth providers.
6. **Tab-switch requests:** no tab/navigation code invokes market refresh;
   Android repeated-tab runtime verification remains unavailable.
7. **Background/resume:** Dashboard invalidates only date-sensitive local data;
   no market call exists. Android lifecycle verification remains unavailable.
8. **Holdings query:** one SQL `LEFT JOIN` and `GROUP BY assets.id` over active
   `asset_transactions`, never cashflow Transactions.
9. **Price lookup:** one active local price query produces a map keyed by
   `asset_id`; Portfolio performs no per-row price query.
10. **N+1 DB:** none on Portfolio root. Asset Detail alone owns its per-asset
    activity/price streams, and those families now auto-dispose after navigation.
11. **N+1 network:** none. Thirty eligible holdings produced one POST request.
12. **PortfolioSnapshot:** one shared O(n) derivation calculates asset values,
    group subtotals, known total, missing-price count, and integrity count.
13. **Provider builds:** a 30-quote transaction caused at most one settled price,
    PortfolioSnapshot, and Net Worth emission in the automated measurement.
14. **Provider loops:** measured emissions settled and remained unchanged without
    further data/user input.
15. **AppDatabase instances:** production has one root, non-auto-disposed
    `databaseProvider`; restore closes, replaces, then invalidates that root once.
16. **Main isolate:** no synchronous network/database wait was added. Full tests
    and a 100-asset widget build complete; Android ANR/profile verification is
    unavailable.
17. **10 assets:** local holdings + prices + snapshot completed in about 23 ms on
    the test host in the full debug test run.
18. **25 assets:** about 3 ms.
19. **50 assets:** about 3 ms.
20. **100 assets:** about 6 ms; the full 100-card widget test completed in about
    681 ms including Flutter test-harness startup. These are informational debug
    numbers, not production thresholds.
21. **Large transaction DB:** 50-asset holdings remained correct beside 5,000
    Transactions; the holdings plan did not access the Transactions table.
22. **Scrolling:** one coherent `ListView` is used without nested ListViews.
    Device frame/drop profiling remains unavailable.
23. **Asset Detail:** activity history is scoped to one asset and uses its asset
    index. Loading 5,000 rows took about 142 ms on the test host. The current UI
    still materializes its activity widgets in one children list; pagination or
    lazy slivers should be added only if device profiling or real usage proves
    this atypical history size problematic.
24. **Batch refresh:** one explicit action creates one deduplicated Stock/Crypto
    batch; local values stay visible while it runs.
25. **Request deduplication:** normalized symbol + asset type is the stable key;
    the database also prevents duplicate type/normalized-symbol records.
26. **Refresh success:** valid quotes persist in one database transaction and
    update local watchers reactively.
27. **Partial failure:** valid siblings update; missing/failed siblings retain
    their previous local prices.
28. **Total failure:** cached values remain and the controller leaves refreshing
    state safely.
29. **429/rate limit:** normalized provider failures are displayed as partial or
    total refresh failure; Flutter performs no aggressive or hidden retry.
30. **Manual exclusion:** manual mode, Gold, Mutual Fund, Other, zero holding, no
    position, negative holding, and archived assets are excluded from requests.
31. **Manual override:** persistence now revalidates active mode, symbol, type,
    currency, and positive price, so an old in-flight API response cannot replace
    a newly entered manual price.
32. **Offline first launch:** local widget/provider tests pass with a Market API
    client that is never called; airplane-mode device verification is unavailable.
33. **Offline restart:** persisted old API and manual prices survive closing and
    reopening SQLite without any refresh call.
34. **Old prices:** age does not invalidate local usability or trigger fetch.
35. **Missing prices:** holdings remain represented and valuation remains null;
    UI uses `Harga belum tersedia`/`Harga belum diatur`, never Rp0.
36. **API cache persistence:** an API quote from 2020 round-trips through a full
    database reopen with price and stale state intact.
37. **Transaction create:** existing active-stream regression remains green.
38. **Transaction edit:** existing History/Dashboard reactivity remains green.
39. **Backup/restore:** Phase 7E.1 restore reactivity/offline/no-auto-fetch tests
    remain green in the full suite.
40. **Migration:** Phase 7E.2 release-schema and post-migration behavior tests
    remain green in the full suite.
41. **Query plans/indexes:** holdings and detail activity plans use
    `asset_transactions_asset_id`. Prices use the unique `asset_prices_asset_id`
    path. No measured evidence justified another index or schema version.
42. **Financial reconciliation:** exact stock 1,300 x 9,200 = 11,960,000, crypto
    precision, gold 5.25 x 1,500,000 = 7,875,000, partial totals, Net Worth,
    Reports cashflow, and account balances remain covered and green.
43. **Tests added:** large Portfolio matrix, 5,000-Transaction independence,
    5,000-detail-activity query, 100-asset widget paint, 30-asset batch/emission,
    family disposal, old API restart, invalid/stale quote protection, exact
    privacy payload, and persistence-failure recovery.
44. **Files changed:** Portfolio/detail providers and UI, local price persistence,
    market parser/controller, focused market tests, performance audit tests, and
    this documentation.
45. **Flutter analyze:** PASS, no issues.
46. **Flutter test:** PASS, 303 tests.
47. **Debug build:** PASS, `build/app/outputs/flutter-apk/app-debug.apk`.
48. **Emulator/device/profile:** BLOCKED; `adb devices -l` reports no device and
    `emulator -list-avds` reports no AVD.
49. **Known limits:** device frame timing, navigation-listener stress, airplane
    mode, background/foreground, rotation/theme rebuild, and full process kill
    remain unmeasured. Asset Detail does not paginate very large histories.
50. **BLOCKER/CRITICAL:** no automated blocker was found. Missing required
    Android runtime/profile evidence is the phase blocker.
51. **STATUS:** 7E.3 remains unchecked. Phase 7E.4 has not started.

## Stabilization Changes

- Portfolio builds its valuation lookup map once rather than once per row.
- Refresh preparation maps asset IDs in the same O(n) candidate pass.
- Unexpected local persistence failures always release refresh state.
- API quote writes revalidate current asset semantics and ignore zero, malformed,
  wrong-currency, renamed, archived, or manual-mode targets.
- Detail asset metadata is reactive; detail-scoped family providers auto-dispose.
- Detail no longer exposes a false empty position while its local providers load.
- Refresh is disabled until local holdings are ready, and retry invalidates the
  actual holdings provider.

## PRD Confirmation

`PRD.md` sections 53.13-53.18 remain authoritative: Portfolio renders from
local Drift data, old prices remain usable, Net Worth consumes the same local
PortfolioSnapshot, and market refresh is explicitly user initiated. No PRD
change was required.

## Validation

```text
dart format .             PASS
flutter analyze           PASS
flutter test              PASS (303 tests)
flutter build apk --debug PASS
git diff --check          PASS
Android runtime/profile   BLOCKED (no device or AVD)
```

Exact conclusion:

> **PHASE 7E.3 - PORTFOLIO PERFORMANCE & OFFLINE AUDIT: BLOCKED**

Recommended next phase after this runtime gate passes or is explicitly waived:
**Phase 7E.4 - UI/UX Polish**. Phase 7E.4 has not started.
