# Design System (redesign v1.3)

Dokumen ini menggantikan versi sebelumnya, yang menjelaskan palet hijau mint
dan sudah usang. Sumber kebenaran adalah kode tema dan `docs/design/`.

## Sumber kebenaran

| Lapisan | File |
|---|---|
| Token (nilai) | `docs/design/tokens.json` (DTCG; nilai gelap ada di `$extensions["finote.mode"].dark`) |
| Spesifikasi komponen | `docs/design/components.md` |
| Screenshot acuan | `docs/design/screens/` (terang dan gelap) |
| Kode warna | `lib/core/theme/finote_colors.dart` (`FinoteColors`, `ThemeExtension`) |
| Kode radius | `lib/core/theme/app_radius.dart` |
| Kode tipografi | `lib/core/theme/app_typography.dart` |
| Skema Material | `lib/core/theme/app_theme.dart` (dibangun dari `FinoteColors`) |
| Kategori | `lib/core/theme/category_style.dart` |
| Jarak | `lib/core/theme/app_spacing.dart` |

Aturan: warna, radius, dan teks di luar `lib/core/theme/` harus lewat token.
Pengecualian yang disengaja: `Colors.transparent` (latar kosong) dan ukuran
font di dokumen PDF ekspor.

## Warna dan satu merek

Satu warna brand untuk dua mode. Mode gelap adalah versi lebih terang dari
warna yang sama, bukan palet lain.

| Token | Terang | Gelap |
|---|---|---|
| `bg` (kanvas) | `#EEF1F8` | `#0B1020` |
| `surface` (kartu, nav) | `#FFFFFF` | `#151C33` |
| `surfaceAlt` (area di dalam kartu) | `#F3F5FB` | `#1F2847` |
| `primary` (satu warna brand) | `#3B5BDB` | `#8EA2FF` |
| `primaryContainer` | `#E3E9FF` | `#28366F` |
| `onPrimaryContainer` | `#233D9F` | `#D5DDFF` |
| `text` | `#182238` | `#EEF1FA` |
| `textMuted` | `#5B6780` | `#A7B1CC` |
| `income` (hanya nominal) | `#0A7560` | `#6FD3B0` |
| `expense` (hanya nominal) | `#A24941` | `#F0A39C` |
| `error` | `#B42318` | `#FDA29B` |
| `warning` | `#8A5300` | `#F5B26B` |
| `outline` (garis input) | `#7B86A0` | `#7C88AC` |
| `heroFrom` → `heroTo` | `#2A42BD` → `#1B2750` | `#33449E` → `#1B2557` |

Aturan warna:
- Merah dan hijau hanya untuk nominal. Ikon tidak pernah merah atau hijau.
- Transfer memakai `transfer.fg/bg` (netral), karena transfer bukan pemasukan
  maupun pengeluaran.
- Ikon kategori memakai pasangan `fg/bg` dari kategori itu sendiri. Kategori
  buatan pengguna memakai `custom1..6`, dipilih dengan hash nama yang
  deterministik (rumus di `tokens.json`).
- Teks selalu di atas latar yang lolos 4.5:1. Ikon kategori (`fg` di atas
  `bg`) hanya dipakai sebagai ikon, karena rasio 3:1 cukup untuk elemen non-teks.

Pemeriksaan kontras dilakukan lewat `test/core/theme/app_theme_test.dart`.

## Permukaan dan elevasi

- Permukaan dibedakan dengan tone: `bg` → `surface` → `surfaceAlt`.
- Tidak ada border pada kartu. Border hanya pada input (`outline`, fokus
  `focus`) dan tombol Outline.
- Bayangan hanya pada hero (`shadow.hero`) dan FAB (`shadow.fab`). Keduanya
  punya nilai terang dan gelap.

## Radius (4 ukuran)

| Token | Nilai | Dipakai untuk |
|---|---|---|
| `radius.sm` | 8 | bar, chip kecil, badge, kode aset |
| `radius.md` | 14 | ubin ikon, tombol, input, snackbar, tombol ikon |
| `radius.lg` | 20 | kartu |
| `radius.xl` | 28 | hero, dialog, bottom sheet, bottom nav, FAB, search |

Konstanta: `AppRadius.sm/md/lg/xl` dan `smAll`, `mdAll`, `lgAll`, `xlAll`.

## Jarak

`4, 8, 12, 16, 24, 32` (`AppSpacing.xs` sampai `xxl`). Padding layar horizontal 16.

## Tipografi

Roboto. Tinggi baris eksplisit untuk setiap gaya. Ukuran teks minimal 12.

- Gaya angka uang memakai `FontFeature.tabularFigures()`, supaya digit
  sejajar di daftar dan total.
- Skala: `amount.hero` 34, `amount.xl` 28, `amount.lg` 22, `amount.md` 17,
  `amount.item` 15, dan seterusnya, sesuai `tokens.json`.
- Judul layar memakai `headlineLarge` (24, tebal). Judul bagian `titleSection`
  (17, semibold). Label kecil `captionOverline` (12, kapital) untuk grup
  pengaturan.

Gaya diakses lewat `AppTypography` (`amountHero`, `titleCard`, `bodySm`, dan
seterusnya). `AppTypography.textTheme(c)` memetakan gaya ke slot `TextTheme`
bawaan Material.

## Tombol dan area sentuh

Varian tombol (components.md `Tombol`):
- **Primer:** `FilledButton`, warna `primary`. Satu per layar.
- **Outline:** `OutlinedButton`, border `outline`.
- **Teks:** `TextButton`, untuk aksi sekunder dan batal.
- **Destruktif:** `FilledButton` dengan warna `error` (hapus, reset, pulihkan).

Area sentuh minimal 48 untuk semua kontrol. Visual boleh lebih kecil (chip 34,
ikon 40) karena `ThemeData.materialTapTargetSize` diatur ke `padded`, dan
widget kustom memakai `ConstrainedBox(minHeight: 48)`.

Setiap `IconButton` dan `PopupMenuButton` punya `tooltip`. Tooltip inilah label
untuk TalkBack. Pemeriksaan ini dijalankan di audit redesign.

## Komponen bersama

Semua di `lib/core/widgets/`. Jangan membuat versi baru.

| Widget | Berkas | Fungsi |
|---|---|---|
| `FinoteHero`, `FinoteHeroAmount`, `FinoteHeroTile`, `BalanceVisibilityButton` | `finote_hero.dart` | Kartu gradasi (Kekayaan Bersih, Saldo periode, Total portofolio) |
| `TemporaryBadge` | `temporary_badge.dart` | Penanda nilai sementara/parsial |
| `Expense7DayCard` | `expense_7day_card.dart` | Mini chart 7 hari |
| `CategoryIconTile`, `TransactionTile`, `TransferTile`, `AssetTile`, `DateHeader`, `CategoryBar` | `finance_tiles.dart` | Item daftar dan bar kategori |
| `FinoteChip`, `FinoteSegmented`, `FinoteIconBadge` | `finote_controls.dart` | Filter, pemilih tab, ikon status |
| `FinoteListTile`, `FinoteListSection` | `finote_list_tile.dart` | Baris pengaturan |
| `CurrencyText` | `shared_widgets.dart` | Nominal IDR, tabular, bisa disamarkan |
| `AppEmptyState`, `AppErrorState`, `AppLoadingState` | `shared_widgets.dart` | Status layar |
| `showAppSnackBar`, `showAppErrorSnackBar` | `app_snackbars.dart` | Snackbar info dan error |

## Saldo tersembunyi

Tombol mata di hero menyembunyikan semua nominal dengan "Rp ••••••". Pilihan
disimpan di SharedPreferences (`finote_hide_balance`) dan dibaca di `main()`
sebelum `runApp`, sehingga frame pertama sudah benar. Nilai yang tersamar
tetap ada di data; hanya tampilannya yang diganti.

## Tema dan mode

- `ThemeMode.system`, `light`, dan `dark` didukung. Pilihannya disimpan.
- Dialog Tema memakai baris bertone brand dengan indikator terpilih.
- Setiap komponen memiliki gaya terang dan gelap. Test layout dijalankan untuk
  keduanya.

## Verifikasi

- Layout diuji di lebar 320 dengan teks 1.3×, terang dan gelap, untuk layar
  utama dan komponen.
- Konsistensi token dijaga oleh `test/core/theme/tokens_parity_test.dart`.
  Test ini gagal jika `tokens.json` dan kode tema berbeda.
- Yang belum diverifikasi di perangkat: TalkBack secara langsung, tampilan
  dengan font sistem paling besar, dan layar Scan struk dengan kamera sungguhan.
