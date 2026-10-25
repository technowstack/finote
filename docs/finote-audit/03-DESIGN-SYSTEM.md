# Audit Design System

## Source of truth

Primary design files: `lib/core/theme/app_theme.dart`, `app_colors.dart`, `app_spacing.dart`, `theme_mode_provider.dart`, `shared_widgets.dart`. Screens still contain many direct `EdgeInsets`, `SizedBox`, `Radius`, and button overrides.

## Palette

### Light `ColorScheme` (`app_theme.dart:10-50`)

| Token | Value |
|---|---|
| primary | `#2A7F67` |
| primaryContainer | `#D0F0E4` |
| secondary | `#4F6358` |
| secondaryContainer | `#D2E8DA` |
| tertiary | `#3D6373` |
| tertiaryContainer | `#C1E8FB` |
| error | `#C0392B` |
| errorContainer | `#FCE4E4` |
| surface | `#F7F5F2` |
| onSurface | `#1C1B1A` |
| onSurfaceVariant | `#5C5C5A` |
| outline | `#8E8E8C` |
| outlineVariant | `#C8C6C3` |

### Dark (`app_theme.dart:54-94`)

| Token | Value |
|---|---|
| primary | `#8DD4B8` |
| primaryContainer | `#1A5E47` |
| secondary | `#B6CCBF` |
| secondaryContainer | `#374B41` |
| tertiary | `#A5CCDF` |
| tertiaryContainer | `#244B5B` |
| error | `#EF8E7E` |
| errorContainer | `#8C1D18` |
| surface | `#161615` |
| onSurface | `#E3E2DF` |
| onSurfaceVariant | `#ADADAB` |
| outline | `#7A7A78` |
| outlineVariant | `#484846` |

Semantic extensions in `app_colors.dart:9-36`: income/positive green, expense/negative red, warning amber, success alias income. These are centralized and preferable to raw screen colors.

## Typography

`AppTheme._textTheme()` explicitly uses `Roboto` (`app_theme.dart:100-188`). Sizes: display 34/28, headline 24/20, title 18/15/13, body 15/14/12, label 14/12/11. Weights range 400–800; display/headline use heavy weights. Line heights are not explicitly set, so Flutter defaults apply. No custom font assets are declared in `pubspec.yaml`.

## Spacing

`AppSpacing` (`app_spacing.dart:5-28`): `xs=4`, `sm=8`, `md=12`, `lg=16`, `xl=24`, `xxl=32`, `screenH=16`, `screenV=8`. Many screens use these, but dialogs and some pages also hardcode 16/20/24/32.

## Shape/elevation/surfaces

- Card radius 12, elevation 0 (`app_theme.dart:195-201`).
- Dialog radius 16; bottom sheet top radius 16 (`240-324`).
- Input outline radius 12, content padding 16 horizontal/14 vertical (`208-214`).
- Chips use `StadiumBorder`; segmented buttons radius 10.
- FAB is circular with elevation 2.
- Snackbar floating, radius 10.
- Surface hierarchy is Material 3 container variants; no custom shadow system beyond theme defaults.

## Components

Reusable shared components: `AppErrorState`, `AppEmptyState`, `AppLoadingState`, `CurrencyText`, `SectionHeader` (`shared_widgets.dart:16-164`). Material components used directly include `Card`, `ListTile`, `ChoiceChip`, `InputChip`, `SegmentedButton`, `SearchBar`, `AlertDialog`, `BottomSheet`, `NavigationBar`, `TabBar`, and `FilledButton`.

## Navigation UI

`MainScaffold` uses a five-destination `NavigationBar`: Beranda, Transaksi, Portofolio, Laporan, Pengaturan (`main_scaffold.dart:32-65`). The shell also provides a context-sensitive FAB for dashboard/transaction branches and a bottom sheet with manual transaction and scan receipt (`71-117`).

## Accessibility/contrast audit

- **TERVERIFIKASI:** Material 3 semantics and standard controls are used; `CurrencyText` uses `FittedBox`; many long values use constraints/fitting.
- **INFERENCE:** color semantics rely on green/red, so amount labels/icons should remain textually signed; this is partly true via `CurrencyText` prefixes.
- **HIGH risk:** contrast has not been programmatically measured against WCAG for all custom pairs, especially dark muted text and semantic colors.
- **MEDIUM risk:** `titleSmall` is 13 px and `labelSmall` 11 px; enlarged text behavior needs device testing.
- **MEDIUM risk:** horizontal chip rows are intentionally scrollable but keyboard focus/overflow behavior is not verified.
- **NOT VERIFIED:** screen reader labels, TalkBack traversal, and 200% text scaling.

## Scattered values/inconsistencies

Examples: Settings/Backup/Security use direct `EdgeInsets.all(16/20/24/32)`; forms define local `InputDecoration`; some list rows use raw `SizedBox(height: 8)`. The system is coherent enough for redesign, but not all spacing and interaction patterns are tokenized.

## Screenshot correspondence

`assets/playstore/1. dashboard.jpg` through `9. Backup & restore.jpg` are available. They are useful visual evidence for intended listing states, but exact runtime state/device/font scale is **NOT VERIFIED**.
