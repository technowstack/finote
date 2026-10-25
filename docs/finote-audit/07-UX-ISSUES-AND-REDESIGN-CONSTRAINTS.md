# UX Issues dan Constraint Redesign

Temuan berikut bukan proposal implementasi. Mereka adalah constraint dan risiko yang perlu dipertahankan saat redesign.

## CRITICAL

1. **Sumber angka finansial harus tetap tunggal** — `transactions`, `transfers`, `asset_transactions`, dan local prices memiliki makna berbeda. Jangan mengganti dengan state UI atau summary tersimpan. Bukti: `transactions.dart`, `transfer_repository.dart`, `asset_transaction_repository.dart`, `net_worth.dart`.
2. **Gate keamanan tidak boleh bocor** — `AppLock` sengaja mengembalikan layar hitam/loading atau unlock page sebelum `child` diberikan (`app_lock.dart:40-69`). Redesign shell tidak boleh menaruh konten finansial di luar gate.
3. **Restore/reset wajib mempertahankan recovery path** — jangan mengubah urutan safety backup, validation, confirmation, close/rebind DB, rollback (`backup_service.dart:229-311`; `settings_page.dart:126-185`).

## HIGH

4. **Tambah transaksi terlalu bergantung pada seed category** (`transaction_form_page.dart:31-59`). Jika initialization gagal, pengguna tidak melihat form. Redesign sebaiknya memisahkan availability form dari seed background, tetapi perubahan harus menjaga category/type validation.
5. **Period flow dan point-in-time wealth bercampur di Reports** (`reports_page.dart:51-148`). Label dan hierarchy perlu sangat eksplisit agar pengguna tidak menjumlahkan cashflow period dengan current portfolio value.
6. **Portfolio partial value mudah disalahbaca sebagai total final** (`portfolio_valuation_service.dart:40-60`; dashboard card `dashboard_page.dart:229-234`). Status “sementara/partial” harus tetap dekat dengan angka utama.
7. **History detail join sensitivity** — `TransactionRepository.watchHistory()` memakai inner joins kategori/account (`transaction_repository.dart:20-39`), sedangkan unified history memakai left joins. Redesign list tidak boleh menyembunyikan error atau mengubah integritas relasi secara diam-diam.
8. **Legacy import category identity** — exact name/type matching dan soft-delete dapat menghasilkan kategori aktif baru ketika kategori lama telah dihapus (`legacy_importer.dart:48-97`). UX import harus menjelaskan hasil kategori dibuat/digunakan; jangan mengandalkan pengguna menghapus default sebelum import.
9. **App Lock runtime belum lengkap** — status release masih BLOCKED (`STATUS.md:617-660`). UI redesign keamanan tidak boleh dianggap selesai hanya dari widget test.

## MEDIUM

10. **Horizontal chip rows** pada transactions/reports/analytics menghemat ruang tetapi menyembunyikan opsi di layar sempit (`transactions_page.dart:113-156`; `reports_page.dart:80-103`; `analytics_chart_page.dart:98-120`). Sediakan affordance scroll/focus yang jelas.
11. **Dialog-heavy CRUD** untuk accounts/assets/transfers/categories memberi konsistensi cepat tetapi kurang cocok untuk form panjang dan keyboard. Jangan mengubah menjadi bottom sheet/full-screen tanpa menilai back handling dan App Lock external activity.
12. **Generic errors** seperti “belum dapat dimuat” membantu user tetapi sulit diagnosis (`shared_widgets.dart:16-41`). Redesign dapat memperbaiki copy/action, namun exception sensitif tidak boleh ditampilkan.
13. **Small text/large text** — 11–13 px labels dan dense chart/list layouts membutuhkan TalkBack/font-scale test. Belum ada bukti runtime 200% text scale.
14. **Color semantics** — income/expense memakai hijau/merah. Prefix `+/-` pada `CurrencyText` membantu, tetapi semua redesign state harus mempertahankan label nonwarna.
15. **Settings destructive action** berada di grup Data bersama navigasi rutin (`settings_page.dart:26-54`). Dua konfirmasi sudah ada; visual separation dan copy backup perlu dipertahankan/ditingkatkan.

## LOW

16. **Spacing inconsistency** — sebagian memakai `AppSpacing`, sebagian raw 8/16/20/24/32. Ini meningkatkan biaya perubahan visual.
17. **Screenshot evidence gap** — Play Store images tidak cukup untuk memastikan responsive states, loading, error, accessibility, atau dark/light parity.
18. **About link** memakai external URL dan throws jika gagal (`settings_page.dart:74-88`); failure UX tidak terlihat user-friendly.

## Redesign constraints checklist

- Keep `CurrencyText`/integer amount behavior or replace with equivalent semantics.
- Keep `ThemeMode.system/light/dark` persistence.
- Keep five main destinations unless navigation evidence justifies change.
- Preserve explicit `Refresh Harga`; no network side effects in build/navigation.
- Preserve transfer as a distinct activity.
- Preserve archived/soft-deleted historical readability.
- Keep manual transaction path no slower than: open → amount → category → save.
- Test narrow width, large text, dark theme, empty/error/loading, keyboard, lifecycle, and external picker.
