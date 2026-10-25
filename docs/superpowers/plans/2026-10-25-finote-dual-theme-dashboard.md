# Finote Dual-Theme Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver Midnight Aurora and Fresh Mint Minimal presentation for Finote's existing Dashboard and Material 3 theme without changing application behavior.

**Architecture:** Map the approved palette into existing `AppTheme` color schemes and semantic `AppColors`; keep all public theme/widget interfaces. Redesign only existing Dashboard presentation widgets; style the unchanged five-destination `NavigationBar` through `ThemeData`, retaining shell routes/FAB behavior.

**Tech Stack:** Flutter, Dart, Material 3, Riverpod widget tests, Drift in-memory fixtures.

**Spec:** User's “FINOTE 2.0 — DUAL-THEME DESIGN SYSTEM & DASHBOARD REDESIGN” brief and approved short design in this conversation; repository constraints in `AGENTS.md` and `docs/finote-audit/`.

## Global Constraints

- No changes to providers, repositories, services, routes, database, financial calculations, security, backup/import/export, dependencies, or market requests.
- Keep five navigation destinations and shell FAB interactions; do not add duplicated manual-entry CTA or fake financial data.
- Preserve existing `AppTheme.light/dark`, `AppColors` and `CurrencyText` public APIs, Roboto and IDR formatter, theme-mode persistence.
- Support 320–430dp, large text, SafeArea/insets, loading/error/empty/partial data states; no unnecessary blur or animations.
- Do not alter uncommitted `docs/finote-audit/` reports or claim Android visual validation without runtime evidence.

## Review Focus

- At 320dp with enlarged text, cash/portfolio and monthly amount rows must wrap without RenderFlex overflow (Task 2 widget test).
- When portfolio price is missing, a visible partial-value explanation must remain alongside known net worth (Task 2 widget test).
- When recent history is empty, existing empty state and `Lihat semua` remain reachable (Task 2 widget test).
- For a real income/expense fixture, recent rows still show signs and route to the existing edit path (Task 2 widget test / existing `test/widget_test.dart`).
- In both themes, primary/surface/on-color and semantic monetary text must meet contrast expectations (Task 1 theme test).

---

### Task 1: Theme palette and shared visual contracts

**Files:**
- Modify: `lib/core/theme/app_theme.dart`, `lib/core/theme/app_colors.dart`, `lib/core/theme/app_spacing.dart` (only additive spacing tokens, if required)
- Test: `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Consumes: Flutter `ThemeData`, `ColorScheme`, existing `AppColors` extension.
- Produces: `AppTheme.light`, `AppTheme.dark` and unchanged semantic getters for all screens.

- [ ] **Step 1: Write failing theme test** asserting specified light/dark `surface`, `surfaceContainerLow`, `primary`, `onPrimary`, `onSurface`, navigation surface/indicator, semantic income/expense/warning colors, Roboto, and WCAG AA contrast of normal-size text on its target surfaces.
- [ ] **Step 2: Run** `flutter test test/core/theme/app_theme_test.dart`; expect color assertions to fail on current palette.
- [ ] **Step 3: Update** existing schemes and component themes: light background `#E8F1EC`, white cards, teal `#00A985`; dark background `#0D0B16`, plum cards, lime `#EAFF86`; retain high-contrast on-colors and theme-aware semantic getters. Navigation styling via `navigationBarTheme`, without editing shell navigation logic.
- [ ] **Step 4: Run** `flutter test test/core/theme/app_theme_test.dart test/core/theme/theme_mode_provider_test.dart`; expect PASS.

### Task 2: Dashboard layout and states

**Files:**
- Modify: `lib/features/dashboard/presentation/dashboard_page.dart`
- Test: `test/features/dashboard/dashboard_page_test.dart`

**Interfaces:**
- Consumes: unchanged `dashboardSummaryProvider`, `netWorthProvider`, `dashboardRecentTransactionsProvider`, `AppColors`, `AppSpacing`, `CurrencyText`, existing `GoRouter` paths.
- Produces: unchanged `DashboardPage` interface and route callbacks; themed hero/summary/history presentation.

- [ ] **Step 1: Write failing widget tests** for 320/390/430dp in both themes with 1x/2x text: hero title and known net worth, cash/portfolio, partial and missing values; monthly labels and amounts; empty/loading/error transactions; existing scan/list/portfolio actions; no Flutter layout exceptions.
- [ ] **Step 2: Run** `flutter test test/features/dashboard/dashboard_page_test.dart`; expect at least one layout/style assertion to fail before implementation.
- [ ] **Step 3: Rework** Dashboard presentation only: compact header, 24dp hero with dark ambient gradient or light white surface; 20dp horizontal page padding; readable wrapping financial values; distinct monthly cashflow group; scan action preserved; compact flat history with separators and semantic signed amounts. Do not alter provider reads/refresh/lifecycle/callbacks.
- [ ] **Step 4: Run** `flutter test test/features/dashboard/dashboard_page_test.dart test/widget_test.dart`; expect PASS.

### Task 3: Final scope and release-quality verification

**Files:** no additional source changes unless an introduced visual defect is confirmed.

- [ ] **Step 1: Format changed Dart files only** using `dart format` with explicit file paths; verify no unrelated formatting edits.
- [ ] **Step 2: Run** `flutter analyze`, targeted dashboard/theme tests, then full `flutter test`; record all failures accurately, including pre-existing failures.
- [ ] **Step 3: Review** `git diff --check` and `git diff` plus untracked file list; ensure no prohibited changes, financial logic change, or accidental modification to prior user work.
- [ ] **Step 4: If available, capture both themes at 390dp and inspect 320dp/large-font and all Dashboard interactions; otherwise state that screenshot/device visual validation was not performed.
