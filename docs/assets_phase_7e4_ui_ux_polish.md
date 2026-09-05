# Finote v1.3.0 - Phase 7E.4 UI/UX Polish

Status: **BLOCKED - implementation and automated validation pass; secure-device visual matrix unavailable**

## Result

Phase 7E.4 polished the existing Portfolio flows without adding investment
features. Portfolio remains the canonical asset-management entry and retains
the explicit-only market refresh boundary.

Implemented changes:

- archived-only portfolios retain the `Tambah aset` action;
- archiving explains its Portfolio and Net Worth impact, and archived assets
  cannot create new activities until reactivated;
- Asset Detail distinguishes `Belum ada posisi` from an existing zero holding;
- the opening-position card shows current and opening quantities separately;
- editing Buy/Sell preserves its linked account, including an unchanged
  archived account, rather than silently selecting another active account;
- edits, deletes, and opening-position changes cannot leave negative holdings;
- Sell rows display a negative quantity and Adjustment deletion no longer
  claims that a linked cashflow exists;
- activity amounts moved out of the constrained trailing area and account
  options truncate safely on narrow/scaled layouts;
- duplicate refresh and missing-price messages were removed;
- user-facing `Simbol` and `sumber pasar` copy is consistently Indonesian;
- account-only values in Reports and exports are labelled `Kas & Dompet`, not
  the ambiguous `Total aset` used before Portfolio existed;
- asynchronous date pickers verify widget lifecycle before updating state.

## Financial And Offline Safety

- No schema or migration changed.
- No dependency was added.
- Holdings remain derived from local asset activities.
- Buy/Sell retain one linked cashflow transaction; edit does not create a new
  cashflow row.
- Missing prices remain unknown and are never displayed as zero.
- Portfolio, Home, Reports, detail navigation, and provider builds still make
  no automatic market request. Only explicit `Refresh Harga` may request data.

## Tests

Added regression coverage for:

- archived-only Portfolio add access;
- archived linked-account preservation through the edit form and service;
- rejecting Buy edit/delete operations that would make holdings negative;
- rejecting an opening-position edit that would make holdings negative;
- closed zero position versus no position;
- narrow 320 logical-pixel activity editing at text scale 1.3;
- updated Reports/export terminology.

Validation:

```text
dart format .             PASS
flutter analyze           PASS
flutter test              PASS (308 tests)
flutter build apk --debug PASS
git diff --check          PASS
```

## Android Runtime

The debug APK was installed with `adb install -r` on a connected Pixel 6a and
the app process launched without an AndroidRuntime or Flutter crash. The device
remained behind secure keyguard/AOD, so visual checks for Portfolio navigation,
Light/Dark appearance, large system font, scrolling, activity forms, and
airplane-mode interaction could not be completed without user unlock.

Exact conclusion:

> **PHASE 7E.4 - UI/UX POLISH: BLOCKED**

Automated implementation is complete. Phase 7E.4 remains unchecked until the
secure-device visual matrix is completed or explicitly waived. Phase 7E.5 has
not started.
