# Spesifikasi Komponen Finote

Dihasilkan dari `finote-redesign.figcraft` (halaman **Komponen** dan **Komponen (lanjutan)**). Nilai warna/radius/spacing = token di `tokens.json`. Satuan px desain = dp.

## Aturan umum

- Spacing hanya 4/8/12/16/24/32; radius hanya 8/14/20/28.
- Permukaan dibedakan tone (`color/bg` → `surface` → `surfaceAlt`); border hanya pada input & tombol Outline.
- Bayangan hanya hero (`shadow.hero`) dan FAB (`shadow.fab`), keduanya punya nilai terang & gelap.
- Teks Roboto ≥12px, lineHeight eksplisit; angka uang `fontFeatureSettings: "tnum"`.
- Merah/hijau hanya pada nominal; transfer memakai `color/transfer/*` (netral).
- **Hit area 48×48 ≠ ukuran visual.** Visual boleh lebih kecil (chip 34, tombol ikon & menu ⋮ 40, tautan teks setinggi teksnya); lint hanya menolak visual < 24 (WCAG 2.5.8).

## Hit area 48×48 di Flutter

Desain menggambar ukuran **visual**. Hit area 48 dibuat di kode, bukan dengan memperbesar visual:

- `ThemeData(materialTapTargetSize: MaterialTapTargetSize.padded)` (default di Android) memberi padding transparan sampai 48 pada `IconButton`, `Chip`/`ChoiceChip`, `TextButton`, `Checkbox`, `Radio`.
- `IconButton`: biarkan `constraints` default (48) dengan `style: IconButton.styleFrom(fixedSize: Size(40, 40))` untuk visual 40.
- Tautan teks seperti "Lihat semua": `TextButton` (min 48 lewat `minimumSize`/`tapTargetSize`) atau bungkus `InkWell` + `ConstrainedBox(BoxConstraints(minHeight: 48))` dengan padding transparan.
- Widget kustom: `GestureDetector`/`InkWell` di dalam `SizedBox(48, 48)` atau `Padding` transparan; `behavior: HitTestBehavior.opaque`.
- Jaga jarak antar target agar hit area 48 tidak saling tumpang.

### `Bottom Nav`

Varian Tab = 5 tujuan; tiap item 72×52 (≥48).

| Varian | Ukuran & gaya |
|---|---|
| `Tab=Beranda` | 390×84; horizontal, gap 0, padding [12, 8, 16, 8]; radius 28; fill `color/surface` |
| `Tab=Transaksi` | 390×84; horizontal, gap 0, padding [12, 8, 16, 8]; radius 28; fill `color/surface` |
| `Tab=Portofolio` | 390×84; horizontal, gap 0, padding [12, 8, 16, 8]; radius 28; fill `color/surface` |
| `Tab=Laporan` | 390×84; horizontal, gap 0, padding [12, 8, 16, 8]; radius 28; fill `color/surface` |
| `Tab=Pengaturan` | 390×84; horizontal, gap 0, padding [12, 8, 16, 8]; radius 28; fill `color/surface` |

- Teks: `Label` 12px SemiBold/16.0 `color/onPrimaryContainer`; `Label` 12px Medium/16.0 `color/textMuted`; `Label` 12px Medium/16.0 `color/textMuted`; `Label` 12px Medium/16.0 `color/textMuted`; `Label` 12px Medium/16.0 `color/textMuted`

### `FAB`

- 56×56; horizontal, gap 0, padding 0; radius 28 (`radius/xl`); fill `color/primary`; shadow `color/shadow/fab`

### `Item/Aset`

- 326×70; horizontal, gap 12, padding [12, 0, 12, 0]
- Teks: `Nama` 15px Medium/22.0 `color/text`; `Kode` 12px Medium/16.0 `color/textMuted`; `Info` 13px Regular/18.0 tnum `color/textMuted`; `Nilai` 17px Bold/24.0 tnum `color/text`; `Perubahan` 13px Medium/18.0 tnum `color/income`
- Properti: `info` (text), `kode` (text), `nama` (text), `nilai` (text), `perubahan` (text)

### `Item/Pemasukan`

- 326×60; horizontal, gap 12, padding [8, 0, 8, 0]
- Teks: `Judul` 15px Medium/22.0 `color/text`; `Subjudul` 13px Regular/18.0 `color/textMuted`; `Nominal` 15px Medium/22.0 tnum `color/income`; `Waktu` 12px Regular/16.0 tnum `color/textMuted`
- Properti: `ikon` (instanceSwap), `judul` (text), `kategori` (text), `nominal` (text), `waktu` (text)

### `Item/Pengeluaran`

- 326×60; horizontal, gap 12, padding [8, 0, 8, 0]
- Teks: `Judul` 15px Medium/22.0 `color/text`; `Subjudul` 13px Regular/18.0 `color/textMuted`; `Nominal` 15px Medium/22.0 tnum `color/expense`; `Waktu` 12px Regular/16.0 tnum `color/textMuted`
- Properti: `ikon` (instanceSwap), `judul` (text), `kategori` (text), `nominal` (text), `waktu` (text)

### `Kategori/Belanja`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/shopping/bg`

### `Kategori/Bisnis`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/business/bg`

### `Kategori/Bonus`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/bonus/bg`

### `Kategori/Deviden`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/dividend/bg`

### `Kategori/Donasi`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/donation/bg`

### `Kategori/Gaji`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/salary/bg`

### `Kategori/Hadiah`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/gift/bg`

### `Kategori/Hiburan`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/fun/bg`

### `Kategori/Investasi`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/invest/bg`

### `Kategori/Kesehatan`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/health/bg`

### `Kategori/Kustom`

Fallback kategori buatan pengguna: ikon tag, warna palet `cat/customN` (indeks dari hash nama, lihat tokens.json).

| Varian | Ukuran & gaya |
|---|---|
| `Warna=1` | 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/custom1/bg` |
| `Warna=2` | 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/custom2/bg` |
| `Warna=3` | 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/custom3/bg` |
| `Warna=4` | 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/custom4/bg` |
| `Warna=5` | 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/custom5/bg` |
| `Warna=6` | 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/custom6/bg` |


### `Kategori/Lainnya`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/other/bg`

### `Kategori/Makanan & Minuman`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/food/bg`

### `Kategori/Pembelian Aset`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/assetBuy/bg`

### `Kategori/Pendidikan`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/education/bg`

### `Kategori/Penjualan Aset`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/assetSell/bg`

### `Kategori/Tagihan`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/bills/bg`

### `Kategori/Transfer`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `color/transfer/bg`

### `Kategori/Transportasi`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `cat/transport/bg`

### `Metrik/Pemasukan`

- 173×60; horizontal, gap 12, padding [8, 12, 8, 12]; radius 20 (`radius/lg`); fill `color/surface`
- Teks: `Label` 13px Regular/18.0 `color/textMuted`; `Nominal` 16px Bold/22.0 tnum `color/income`
- Properti: `nominal` (text)

### `Metrik/Pengeluaran`

- 173×60; horizontal, gap 12, padding [8, 12, 8, 12]; radius 20 (`radius/lg`); fill `color/surface`
- Teks: `Label` 13px Regular/18.0 `color/textMuted`; `Nominal` 16px Bold/22.0 tnum `color/expense`
- Properti: `nominal` (text)

### `Badge/Sementara`

Wajib menempel pada angka yang nilainya parsial (Portofolio, Kekayaan Bersih).

| Varian | Ukuran & gaya |
|---|---|
| `Latar=Permukaan` | 256×24; horizontal, gap 4, padding [4, 8, 4, 8]; radius 8 (`radius/sm`); fill `color/warningContainer` |
| `Latar=Hero` | 256×24; horizontal, gap 4, padding [4, 8, 4, 8]; radius 8 (`radius/sm`); fill `color/onHeroChip` |

- Teks: `Teks` 12px SemiBold/16.0 `color/onWarningContainer`
- Properti: `teks` (text)

### `Bar Kategori`

Track `cat/<k>/bg`, isi `cat/<k>/fg`; lebar isi = persen × lebar track.

| Varian | Ukuran & gaya |
|---|---|
| `Kategori=Makanan & Minuman` | 326×36; vertical, gap 8, padding 0 |
| `Kategori=Belanja` | 326×36; vertical, gap 8, padding 0 |
| `Kategori=Transportasi` | 326×36; vertical, gap 8, padding 0 |
| `Kategori=Tagihan` | 326×36; vertical, gap 8, padding 0 |
| `Kategori=Hiburan` | 326×36; vertical, gap 8, padding 0 |
| `Kategori=Kustom` | 326×36; vertical, gap 8, padding 0 |

- Teks: `Nama` 14px Regular/20.0 `color/text`; `Nominal` 14px SemiBold/20.0 tnum `color/expense`
- Properti: `nama` (text), `nominal` (text)

### `Chip`

Visual 34 tinggi; hit area 48 lewat padding transparan. Dipilih: `color/primary`; tidak: `color/surfaceAlt`.

| Varian | Ukuran & gaya |
|---|---|
| `Dipilih=Ya` | 65×34; horizontal, gap 0, padding 0 |
| `Dipilih=Tidak` | 73×34; horizontal, gap 0, padding 0 |

- Teks: `Label` 13px Medium/18.0 `color/onPrimary`
- Properti: `label` (text)

### `Header Tanggal`

Total harian bertanda +/− dengan warna nominal.

| Varian | Ukuran & gaya |
|---|---|
| `Total=Negatif` | 358×22; horizontal, gap 0, padding [4, 4, 0, 4] |
| `Total=Positif` | 358×22; horizontal, gap 0, padding [4, 4, 0, 4] |

- Teks: `Tanggal` 13px SemiBold/18.0 `color/textMuted`; `Total harian` 13px SemiBold/18.0 tnum `color/expense`
- Properti: `tanggal` (text), `total` (text)

### `Hero/Kekayaan Bersih`

Saldo=Tersembunyi mengganti semua nominal dengan "••••"; ikon mata tertutup.

| Varian | Ukuran & gaya |
|---|---|
| `Saldo=Tampil` | 358×238; vertical, gap 12, padding 16; radius 28 (`radius/xl`); fill `gradient color/heroFrom→color/heroTo`; shadow `color/shadow/hero` |
| `Saldo=Tersembunyi` | 358×238; vertical, gap 12, padding 16; radius 28 (`radius/xl`); fill `gradient color/heroFrom→color/heroTo`; shadow `color/shadow/hero` |

- Teks: `Label` 14px Medium/20.0 `color/onHeroMuted`; `Saldo` 34px Bold/40.0 tnum `color/onHero`; `Teks` 12px Medium/16.0 tnum `color/onHero`; `Label` 12px Regular/16.0 `color/onHeroMuted`; `Nilai` 15px Medium/22.0 tnum `color/onHero`; `Label` 12px Regular/16.0 `color/onHeroMuted`
- Properti: `kas` (text), `perubahan` (text), `portofolio` (text), `saldo` (text)

### `Ikon Pilih/Akun`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `color/primaryContainer`

### `Ikon Pilih/Tanggal`

- 44×44; horizontal, gap 0, padding 0; radius 14 (`radius/md`); fill `color/primaryContainer`

### `Input/Nominal`

Format IDR bilangan bulat; prefix "Rp" terpisah dari angka (tnum). State sama dengan Input/Teks.

| Varian | Ukuran & gaya |
|---|---|
| `State=Default` | 358×114; vertical, gap 4, padding 0 |
| `State=Fokus` | 358×114; vertical, gap 4, padding 0 |
| `State=Error` | 358×114; vertical, gap 4, padding 0 |
| `State=Disabled` | 358×114; vertical, gap 4, padding 0 |

- Teks: `Label` 13px Medium/18.0 `color/textMuted`; `Prefix` 20px SemiBold/28.0 `color/textMuted`; `Nilai` 28px Bold/36.0 tnum `color/text`; `Bantuan` 12px Regular/16.0 `color/textMuted`
- Properti: `bantuan` (text), `label` (text), `nilai` (text)

### `Input/Pilih`

Pemilih kategori/akun/tanggal. Properti `ikon` = instance swap ke Kategori/* atau Ikon Pilih/*.

| Varian | Ukuran & gaya |
|---|---|
| `State=Default` | 358×102; vertical, gap 4, padding 0 |
| `State=Error` | 358×102; vertical, gap 4, padding 0 |
| `State=Disabled` | 358×102; vertical, gap 4, padding 0 |

- Teks: `Label` 13px Medium/18.0 `color/textMuted`; `Nilai` 15px Medium/22.0 `color/text`; `Bantuan` 12px Regular/16.0 `color/textMuted`
- Properti: `bantuan` (text), `ikon` (instanceSwap), `label` (text), `nilai` (text)

### `Input/Teks`

Satu-satunya tempat border: Default 1px `color/outline`, Fokus 2px `color/focus` + kursor, Error 2px `color/error` + pesan, Disabled tanpa border di `color/disabled`.

| Varian | Ukuran & gaya |
|---|---|
| `State=Default` | 358×98; vertical, gap 4, padding 0 |
| `State=Fokus` | 358×98; vertical, gap 4, padding 0 |
| `State=Error` | 358×98; vertical, gap 4, padding 0 |
| `State=Disabled` | 358×98; vertical, gap 4, padding 0 |

- Teks: `Label` 13px Medium/18.0 `color/textMuted`; `Nilai` 16px Regular/22.0 `color/text`; `Bantuan` 12px Regular/16.0 `color/textMuted`
- Properti: `bantuan` (text), `label` (text), `nilai` (text)

### `Item/Transfer`

- 326×60; horizontal, gap 12, padding [8, 0, 8, 0]
- Teks: `Judul` 15px Medium/22.0 `color/text`; `Subjudul` 13px Regular/18.0 `color/textMuted`; `Nominal` 15px Medium/22.0 tnum `color/text`; `Waktu` 12px Regular/16.0 `color/textMuted`
- Properti: `judul` (text), `label` (text), `nominal` (text), `rute` (text)

### `Kartu/Pengeluaran 7 Hari`

Bar hari ini `color/primary`, lainnya `color/primaryContainer`; Data=Kosong menampilkan catatan.

| Varian | Ukuran & gaya |
|---|---|
| `Data=Ada` | 358×166; vertical, gap 12, padding 16; radius 20 (`radius/lg`); fill `color/surface` |
| `Data=Kosong` | 358×144; vertical, gap 12, padding 16; radius 20 (`radius/lg`); fill `color/surface` |

- Teks: `Label` 13px Regular/18.0 `color/textMuted`; `Nilai` 22px Bold/28.0 tnum `color/text`; `Hari` 12px Regular/16.0 `color/textMuted`; `Hari` 12px Regular/16.0 `color/textMuted`; `Hari` 12px Regular/16.0 `color/textMuted`; `Hari` 12px Regular/16.0 `color/textMuted`
- Properti: `total` (text)

### `List Tile`

Baris pengaturan, min tinggi 56. Destruktif memakai `color/error*` (Reset data).

| Varian | Ukuran & gaya |
|---|---|
| `Tipe=Biasa` | 358×56; horizontal, gap 12, padding [8, 16, 8, 16]; min tinggi 56 |
| `Tipe=Destruktif` | 358×56; horizontal, gap 12, padding [8, 16, 8, 16]; min tinggi 56 |

- Teks: `Judul` 15px Medium/22.0 `color/text`; `Subjudul` 13px Regular/18.0 `color/textMuted`
- Properti: `judul` (text), `subjudul` (text)

### `Search Bar`

Aktif: border fokus + tombol tutup 48.

| Varian | Ukuran & gaya |
|---|---|
| `State=Default` | 358×48; horizontal, gap 12, padding [0, 16, 0, 16]; radius 28 (`radius/xl`); fill `color/surface` |
| `State=Aktif` | 358×48; horizontal, gap 12, padding [0, 0, 0, 16]; radius 28 (`radius/xl`); fill `color/surface`; border 1px `color/focus` |

- Teks: `Teks` 15px Regular/22.0 `color/textMuted`
- Properti: `teks` (text)

### `Segmented`

Tipe transaksi pada form. Tiap segmen 48 tinggi.

| Varian | Ukuran & gaya |
|---|---|
| `Pilihan=Pengeluaran` | 358×56; horizontal, gap 4, padding 4; radius 14 (`radius/md`); fill `color/surface` |
| `Pilihan=Pemasukan` | 358×56; horizontal, gap 4, padding 4; radius 14 (`radius/md`); fill `color/surface` |
| `Pilihan=Transfer` | 358×56; horizontal, gap 4, padding 4; radius 14 (`radius/md`); fill `color/surface` |

- Teks: `Label` 14px SemiBold/20.0 `color/onPrimary`; `Label` 14px Medium/20.0 `color/textMuted`; `Label` 14px Medium/20.0 `color/textMuted`

### `Snackbar`

Tanpa bayangan (bayangan hanya hero & FAB). Aksi 48 tinggi.

| Varian | Ukuran & gaya |
|---|---|
| `Tipe=Info` | 358×48; horizontal, gap 8, padding [0, 4, 0, 16]; radius 14 (`radius/md`); fill `color/inverseSurface`; min tinggi 48 |
| `Tipe=Error` | 358×48; horizontal, gap 8, padding [0, 4, 0, 16]; radius 14 (`radius/md`); fill `color/errorContainer`; min tinggi 48 |

- Teks: `Pesan` 14px Regular/20.0 `color/onInverseSurface`; `Label` 14px SemiBold/20.0 `color/inversePrimary`
- Properti: `aksi` (text), `pesan` (text)

### `Status`

Loading / Error (+Coba lagi) / Kosong (+aksi utama).

| Varian | Ukuran & gaya |
|---|---|
| `Jenis=Loading` | 358×144; vertical, gap 12, padding [32, 24, 32, 24]; radius 20 (`radius/lg`); fill `color/surface` |
| `Jenis=Error` | 358×248; vertical, gap 12, padding [32, 24, 32, 24]; radius 20 (`radius/lg`); fill `color/surface` |
| `Jenis=Kosong` | 358×268; vertical, gap 12, padding [32, 24, 32, 24]; radius 20 (`radius/lg`); fill `color/surface` |

- Teks: `Judul` 14px Medium/20.0 `color/textMuted`

### `Tombol`

Tinggi visual 48 (tombol berisi). Pressed = state layer Material 12% di atas warna Default (tidak digambar terpisah). Disabled tidak wajib memenuhi kontras (WCAG 1.4.3).

| Varian | Ukuran & gaya |
|---|---|
| `Tipe=Primer, State=Default` | 99×48; horizontal, gap 0, padding [0, 24, 0, 24]; radius 14 (`radius/md`); fill `color/primary` |
| `Tipe=Primer, State=Disabled` | 99×48; horizontal, gap 0, padding [0, 24, 0, 24]; radius 14 (`radius/md`); fill `color/disabled` |
| `Tipe=Outline, State=Default` | 101×48; horizontal, gap 0, padding [0, 24, 0, 24]; radius 14 (`radius/md`); border 1px `color/outline` |
| `Tipe=Outline, State=Disabled` | 101×48; horizontal, gap 0, padding [0, 24, 0, 24]; radius 14 (`radius/md`); border 1px `color/divider` |
| `Tipe=Teks, State=Default` | 115×48; horizontal, gap 0, padding [0, 16, 0, 16]; radius 14 (`radius/md`) |
| `Tipe=Teks, State=Disabled` | 115×48; horizontal, gap 0, padding [0, 16, 0, 16]; radius 14 (`radius/md`) |
| `Tipe=Destruktif, State=Default` | 92×48; horizontal, gap 0, padding [0, 24, 0, 24]; radius 14 (`radius/md`); fill `color/error` |
| `Tipe=Destruktif, State=Disabled` | 92×48; horizontal, gap 0, padding [0, 24, 0, 24]; radius 14 (`radius/md`); fill `color/disabled` |

- Teks: `Label` 15px SemiBold/22.0 `color/onPrimary`
- Properti: `label` (text)

### `Tombol Ikon`

Visual 40×40; hit area 48×48 (IconButton default Material 3). Gaya Polos dipakai untuk menu ⋮ dan tutup.

| Varian | Ukuran & gaya |
|---|---|
| `Ikon=Kembali, Gaya=Surface` | 40×40; horizontal, gap 0, padding 0; radius 28 (`radius/xl`); fill `color/surface` |
| `Ikon=Cari, Gaya=Surface` | 40×40; horizontal, gap 0, padding 0; radius 28 (`radius/xl`); fill `color/surface` |
| `Ikon=Export, Gaya=Surface` | 40×40; horizontal, gap 0, padding 0; radius 28 (`radius/xl`); fill `color/surface` |
| `Ikon=Scan, Gaya=Surface` | 40×40; horizontal, gap 0, padding 0; radius 28 (`radius/xl`); fill `color/surface` |
| `Ikon=Filter, Gaya=Tonal` | 40×40; horizontal, gap 0, padding 0; radius 28 (`radius/xl`); fill `color/primaryContainer` |
| `Ikon=Transfer, Gaya=Tonal` | 40×40; horizontal, gap 0, padding 0; radius 28 (`radius/xl`); fill `color/primaryContainer` |
| `Ikon=Menu, Gaya=Polos` | 40×40; horizontal, gap 0, padding 0; radius 28 (`radius/xl`) |
| `Ikon=Tutup, Gaya=Polos` | 40×40; horizontal, gap 0, padding 0; radius 28 (`radius/xl`) |
| `Ikon=Mata, Gaya=Hero` | 40×40; horizontal, gap 0, padding 0; radius 28 (`radius/xl`); fill `color/onHeroChip` |
| `Ikon=Mata tertutup, Gaya=Hero` | 40×40; horizontal, gap 0, padding 0; radius 28 (`radius/xl`); fill `color/onHeroChip` |

