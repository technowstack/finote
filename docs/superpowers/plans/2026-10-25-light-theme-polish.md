# Light Theme Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Finote Light theme's mint canvas, cards, and Material controls visually distinct and consistent, while preserving financial behavior and Dark theme.

**Architecture:** Adjust only existing Material 3 Light ColorScheme/component values and their theme regression tests. Preserve current teal family and dark theme. Semantic amount colors remain the readable text colors; brighter income/expense accents stay icon-only.

**Tech Stack:** Flutter, Dart, Material 3, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-25-light-theme-polish-design.md`

## Global Constraints

- Modify only UI/theme and related tests.
- Preserve Dark theme values, providers, navigation, finance calculations, persistence, and app behavior.
- Keep current teal family anchored at `#0D766A`; distinguish page surface from white cards visibly.
- Normal text contrast remains at least 4.5:1; large text at least 3:1.
- No dependencies.

## Review Focus

- Surface and card contrast: verify Light theme canvas and card token distinction in assertions.
- Text readability: verify `onSurface`, `onSurfaceVariant`, semantic amount colors against actual surfaces.
- Control states: inspect inherited FilledButton, TextButton, OutlinedButton, disabled/focused styling; override only where inconsistent.
- Narrow/large text regression: retain Dashboard tests at 320/390/430dp and 2x text scaling.
- Dark theme regression: test existing Dark scheme unchanged.

---

### Task 1: Pin Light theme visual tokens and contrast

**Files:**
- Modify: `test/core/theme/app_theme_test.dart`
- Modify: `lib/core/theme/app_theme.dart`

- [ ] Add/adjust Light theme assertions requiring a visible mint canvas distinct from white card surface, preserving `primary #0D766A`, readable semantic text, and required Light navigation/action colors.
- [ ] Run `flutter test --no-pub test/core/theme/app_theme_test.dart`; confirm failure on current surface separation.
- [ ] Update only `_lightScheme` values to a restrained mint canvas/card hierarchy; keep dark scheme byte-for-byte unchanged.
- [ ] Verify test passes; calculate any explicit foreground/background ratios using the test helper.
- [ ] Run `dart format lib/core/theme/app_theme.dart test/core/theme/app_theme_test.dart`.

### Task 2: Verify Light Material control consistency and app layout

**Files:**
- Modify: `lib/core/theme/app_theme.dart` only if concrete control inconsistency is found.
- Test: `test/features/dashboard/dashboard_page_test.dart`, `test/widget_test.dart`

- [ ] Review current Light `FilledButton`, `OutlinedButton`, `TextButton`, disabled, focused, and pressed colors derived from the ColorScheme.
- [ ] Add a focused assertion only for a concrete inconsistent themed color; do not add broad override scaffolding.
- [ ] Run `flutter test --no-pub test/core/theme/app_theme_test.dart test/core/theme/theme_mode_provider_test.dart test/features/dashboard/dashboard_page_test.dart test/widget_test.dart`; expected all targeted tests pass.
- [ ] Run `dart analyze` on changed Dart files; expected no issues.
- [ ] Run `flutter test --no-pub`; report existing suite failures by name without unrelated fixes.
- [ ] Review `git diff --check` and diff scope; verify no financial logic/provider/navigation/Dark theme changes.

## Self-review

Plan covers all agreed audit items within the user's UI-only scope. Dark theme is explicitly protected. Runtime Android screenshot and visual click-through remain a manual follow-up if device availability permits; do not claim them without running.