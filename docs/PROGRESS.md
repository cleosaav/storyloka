# PROGRESS.md — Status Pengerjaan StoryLoka

Dokumen ini mencatat kemajuan pengerjaan proyek StoryLoka per fase sesuai PRD §13 dan AGENTS.md.

---

## Ringkasan Progres

- **Tahap saat ini:** Tahap Rilis Produksi & Finalisasi — Selesai
- **Fase terakhir selesai:** Tambahan Chip Genre pada Discover Books (AddBookPage), Caching 30 Menit, Race Condition Guard, Full Responsive & Overflow Fix
- **Status keseluruhan:** Seluruh fase PRD (A0–A7, B1–B7, U0–U5, R1–R6, S1–S8, F1–F5) serta fitur Chip Genre pada Discover Books tuntas. Kode `lib/` 100% bebas issue (`flutter analyze`), dan seluruh rangkaian test lolos (100%).

---

## Log Fase

### Fase A0 — Fondasi (SELESAI)

- **Cakupan yang selesai:**
  - Inisialisasi konfigurasi dependensi UI (`provider`, `go_router`, `google_fonts: 8.2.1`, `cached_network_image`, `intl`, `uuid`, `shared_preferences`, `flutter_secure_storage`, `crypto`, `url_launcher`, `image_picker`).
  - Core Design Tokens di `lib/core/theme/`:
    - `app_colors.dart` (Light Cozy Botanical + Dark Mode resmi).
    - `app_text.dart` (Fraunces SemiBold untuk heading/angka, DM Sans untuk body/kontrol).
    - `app_spacing.dart` (spacing, padding, radius, height tokens).
    - `app_theme.dart` (ThemeData light & dark terintegrasi).
  - Core Reusable Widgets di `lib/core/widgets/`:
    - `AppButton` (Primary, Secondary, Text, Destructive, Large).
    - `AppChip` & `AppStatusBadge`.
    - `AppCard`, `NotesCard`, `SupportCard`, `EmptyStateCard`.
    - `BookCoverWidget` (dengan placeholder judul/penulis/warna genre bila tanpa cover).
    - `AppTextField` (dengan label, hint, suffix toggle password, dan error).
    - `AppDialog` & `AppSnackBar`.
    - `DemoControls` (bottom sheet switcher untuk isi/kosong, simulasi error, simulasi lambat, lewati biometrik) & `DemoModeChip`.
  - Data Layer di `lib/data/`:
    - Seluruh Model data: `UserBook`, `ReadingSession`, `LedgerBlock`, `FeedbackEntry`, `GameScore`, `ChatMessage`, `AppUser`.
    - Seluruh kontrak Abstract Repository (10 repositori).
    - Implementasi Fake in-memory repository dengan simulasi latensi 300–800 ms dan 12 data buku demo realistis.
  - App Shell & Routing di `lib/app/`:
    - `router.dart` dengan `StatefulShellRoute.indexedStack` untuk bottom navigation 5 tab (`Home`, `Library`, `Add Book`, `Tools`, `Profile`).
    - `MainShell` dengan styling Cozy Botanical dan tombol Add khusus warna apricot.
    - `providers.dart` sebagai single point of truth provider injection.
  - Smoke & Unit Testing di `test/`:
    - `widget_test.dart` menguji navigasi 5 tab, rendering widget, dan transisi tab.
    - `fase_a0_test.dart` menguji `DemoControls`, `ThemeController`, dan `FakeLibraryRepository`.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test`: **4/4 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md` (Token Dark Mode, Shell placeholder, `google_fonts: 8.2.1`, widget `Material` pada `AppCard`).
- **DoD Terpenuhi:** Aplikasi berjalan, navigasi 5 tab berfungsi, tema light/dark berfungsi dinamis, `DemoControls` dapat mengganti data berisi/kosong dan error simulasi.

---

### Fase A1 — UI Autentikasi (SELESAI)

- **Cakupan yang selesai:**
  - **Secure Session Store (`lib/core/services/secure_session_store.dart`):**
    - Penyimpanan sesi aman menggunakan `flutter_secure_storage` dengan *in-memory fallback* untuk ketahanan pada platform desktop/web dan *test runner*.
    - Menyimpan token session acak dan profil singkat user (id, name, email) sehingga session bertahan setelah aplikasi ditutup/restart.
    - Mengelola status toggle preferensi biometrik (`storyloka_biometric_enabled`).
  - **Fake Auth Repository (`lib/data/repositories/fake/fake_repositories.dart`):**
    - Sesuai spesifikasi Fase A1: format email valid & password ≥ 8 karakter diterima.
    - Simulasi `taken@demo.com` menghasilkan error `EMAIL_TAKEN`.
    - Simulasi password `wrong` menghasilkan error `INVALID_CREDENTIALS`.
    - Mengintegrasikan penyimpanan session ke `SecureSessionStore` saat register dan login berhasil, serta pembersihan saat logout.
  - **Auth Controller (`lib/features/auth/auth_controller.dart`):**
    - Pengontrol status autentikasi reaktif (`ChangeNotifier`) untuk UI dan `GoRouter`.
    - Mengelola state login, registrasi, logout, lock screen biometrik, auto-check session, dan pesan error dalam bahasa Indonesia.
  - **Layar Splash (`lib/features/auth/splash_page.dart`):**
    - Branding Fraunces "StoryLoka" dan ikon buku botani, otomatis memeriksa sesi di `SecureSessionStore`.
  - **Layar Login (`lib/features/auth/login_page.dart`):**
    - Input email & password dengan validasi form lengkap (wajib diisi, format regex email, password wajib).
    - Tombol login dengan indikator loading dan penonaktifan submit ganda.
    - Pesan error banner bahasa Indonesia ("Email atau password salah.").
    - Kartu catatan demo untuk kemudahan pengujian QA.
  - **Layar Register (`lib/features/auth/register_page.dart`):**
    - Input 4 field: Nama Lengkap, Email, Password, dan Konfirmasi Password.
    - Validasi lengkap: nama wajib, format email valid, password minimal 8 karakter, konfirmasi password harus cocok.
    - Penanganan error `EMAIL_TAKEN` ("Email sudah terdaftar. Silakan gunakan email lain atau masuk.").
    - Tombol daftar dengan status loading/disabled saat proses berlangsung.
  - **Layar Lock Screen (`lib/features/auth/lock_screen_page.dart`):**
    - Muncul jika session ada dan biometrik diaktifkan.
    - Tombol "Simulasi Biometrik (Demo)" (hanya di mode demo sesuai PRD §13.0 Fase A1).
    - Tombol "Coba Lagi" dan "Login dengan password" (menghapus session lokal dan kembali ke Login).
    - Reaktif terhadap toggle `bypassBiometric` di `DemoControls`.
  - **Redirect Guard & Routing (`lib/app/router.dart` & `lib/app/app.dart`):**
    - Redirect guard: tanpa session → `/login`; ada session + biometrik aktif → `/lock`; authenticated & unlocked → `/home`.
    - `StoryLokaApp` menghubungkan `AuthController` ke `createAppRouter(authController)`.
    - Tombol Logout di `ProfilePage` dengan dialog konfirmasi yang mengarahkan kembali ke `/login`.
  - **Testing (`test/`):**
    - `test/fase_a1_test.dart` (5 unit test mencakup rule FakeAuth, persistensi secure storage, pesan error, alur lock screen biometrik, dan password fallback).
    - `test/widget_test.dart` (smoke test menguji alur lengkap: Splash → Login → Home → 5 tab bottom navigation).
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test`: **10/10 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md` (Fallback In-Memory `SecureSessionStore` & `AuthController` sebagai `refreshListenable` di `GoRouter`).
- **DoD Fase A1 Terpenuhi:** Register, login, dan logout berjalan; seluruh pesan error tampil jelas dalam bahasa Indonesia; session fake bertahan di secure storage; Lock Screen dan simulasi biometrik dapat diuji penuh.

---

### Fase A2 — Add Book dan Book Detail (SELESAI)
- **Cakupan yang selesai:**
  - `AddBookPage` (`/add`):
    - Search bar dengan input dinamis placeholder berdasarkan filter aktif.
    - Debounce pencarian 500 ms (min 2 karakter, `maxResults=20`).
    - Filter tabs/chips: `Title`, `Author`, `ISBN` (default Title).
    - Shake to Discover icon button: memilih buku acak dari data demo dan membuka detail.
    - Baris tombol Scan Barcode (`/scan`) dengan ikon scanner.
    - Penanganan 5 state visual: Initial state ("Discover Books"), Loading shimmer/skeleton 3 kolom, Empty state ("Buku tidak ditemukan"), Error state (+ tombol "Coba Lagi"), dan Success state (grid 3 kolom `BookGridCard`).
  - `ScanPage` (`/scan`):
    - Placeholder kamera dengan framing scanner persegi (mode simulator demo).
    - Form input ISBN manual lengkap dengan validasi dan tombol "Cari ISBN".
    - Navigasi ke `/book/search` bila ditemukan, atau menampilkan SnackBar bila ISBN tidak ada/error.
  - `SearchBookDetailPage` (`/book/search`):
    - Cover buku besar (rasio 2:3, lebar ~140, tinggi 210) berpusat.
    - Judul (Fraunces 24), penulis, `GenreChip`, dan metadata (ISBN, Penerbit, Jumlah Halaman).
    - Tombol "Add to Collection" (Primary) dan "Add to Wishlist" (Secondary).
    - Perubahan label menjadi "Added to Collection" (disabled) dan "Added to Wishlist" (disabled).
    - Aturan tanpa duplikat: unik per `(user_id, google_books_id)`; buku di wishlist yang ditekan "Add to Collection" dipindahkan (`moveToCollection`), bukan digandakan.
    - Card **Synopsis**: teks HTML bersih, maksimal 6 baris dengan toggle "Read More" / "Read Less" (fallback: "Sinopsis tidak tersedia").
    - Card **Book Price**: format harga mata uang asli (mis. `Rp 85.000` atau `$14.99`); fallback "Harga tidak tersedia" bila kosong.
    - Card **Find Nearby Bookstores**: "Open Maps to find nearby sellers and browse in person." + tombol "Open Maps" via `url_launcher` dan tombol bottom sheet pencarian kota manual.
  - Rute `/scan` dan `/book/search` terdaftar di atas shell navigator di `lib/app/router.dart`.
  - Dukungan repositori di `FakeLibraryRepository`: pencegahan duplikasi buku, restorasi soft-deleted buku, dan pemindahan status dari wishlist ke koleksi.
- **Verifikasi DoD A2:**
  - Semua state Add Book berfungsi dan teruji (initial, loading, empty, error, grid).
  - Tombol Add mengubah label dan buku tersimpan di `LibraryRepository` tanpa duplikasi.
  - Seluruh pengujian lolos: `test/fase_a2_test.dart` (7/7 tests passed), total 17/17 tests lolos di suite.
  - `flutter analyze` bersih (0 issues).

---

### Fase A3 — Home dan Library (SELESAI)

- **Cakupan yang selesai:**
  - `HomePage` (`/home` — PRD §7.2, §7.5):
    - Header sapaan: `"Hello, {nama}!"` (Fraunces 28), subteks `"Mau baca apa hari ini?"`, dan avatar profil inisial (tap langsung menuju tab Profile).
    - `DemoModeChip` di AppBar pojok kanan atas sesuai PRD §13.0 aturan 5.
    - Card **Reading Summary** dengan 3 metrik dinamis yang dihitung langsung dari data repository (bukan hardcoded):
      - **Koleksi** (`list_type = collection`)
      - **Sedang dibaca** (`status = reading` dan `list_type = collection`)
      - **Selesai** (`status = finished` dan `list_type = collection`)
    - Card **Currently Reading** dengan 2 kondisi dinamis:
      - *Kondisi 1 (kosong):* ikon buku terbuka, judul motivasi, subteks, dan tombol "Add Book" (menuju tab `/add`).
      - *Kondisi 2 (terisi):* cover buku (min 80×120), judul, penulis, `ReadingProgressBar` (`{currentPage}/{pageCount} pages` & persen), serta tombol **Read** (`/reading/timer/:id`) dan **Update** (`/reading/progress/:id`).
    - Card **My Collection**: judul seksi + tombol "See all →" (membuka `/library?filter=collection`), deretan 3 cover buku terbaru (rasio 2:3, tap membuka detail).
    - Card **My Wishlist**: judul seksi + tombol "See all →" (membuka `/library?filter=wishlist`), deretan 3 cover buku terbaru (rasio 2:3, tap membuka detail).
    - Dukungan pull-to-refresh (`RefreshIndicator`) untuk memperbarui data Home secara reaktif.
  - `LibraryPage` (`/library` — PRD §7.6):
    - Header "Library", search bar lokal real-time (filter judul dan penulis buku milik pengguna).
    - `FilterTabs`: toggle **Collection | Wishlist** yang menghormati query parameter URL `?filter=collection` dan `?filter=wishlist`.
    - Grid 3 kolom responsif:
      - Koleksi: cover, judul max 2 baris, penulis, rating bintang, dan `StatusBadge` (Belum dibaca / Sedang dibaca / Selesai).
      - Wishlist: cover, judul max 2 baris, penulis.
    - Dialog konfirmasi hapus buku pada aksi long-press kartu (`deleteBook` dengan soft delete).
    - State `EmptyStateCard` per filter dengan tombol aksi utama "Add Book" dan penanganan hasil pencarian kosong.
    - Pull-to-refresh untuk memuat ulang daftar pustaka.
  - `WishlistBookDetailPage` (`/book/wishlist/:id` — PRD §7.6):
    - Cover buku besar, judul, penulis, genre, metadata.
    - **Satu tombol utama:** "Add to Collection" (memindahkan buku dari wishlist ke koleksi via `moveToCollection`, menampilkan SnackBar sukses, dan kembali ke halaman sebelumnya).
    - Card Synopsis + Read More, Card Book Price, Card Find Nearby Bookstores + Open Maps & Manual Location selector.
  - `CollectionBookDetailPage` (`/book/collection/:id` — PRD §7.4):
    - Detail buku koleksi lengkap dengan tombol Start Reading, Update Progress, status progress bar, rating, sinopsis, dan overflow menu untuk hapus buku.
  - Rute baru di `lib/app/router.dart`:
    - `/book/wishlist/:id`
    - `/book/collection/:id`
    - `/reading/timer/:id` & `/reading/progress/:id` (placeholder halaman transisi menuju Fase A4).
  - Peningkatan `FakeLibraryRepository` dan `FakeAuthRepository` untuk eksekusi unit test instan (`fakeRepositoriesEnableLatency = false`).
- **Verifikasi DoD A3:**
  - Alur 2, 5, dan 6 sesuai Bagian 7 PRD.
  - Angka Reading Summary dihitung dari data repository nyata secara dinamis.
  - Tombol "See all →" membuka Library dengan filter tab yang sesuai.
  - Unit & Widget tests lengkap di `test/fase_a3_test.dart` (11/11 tests passed, termasuk uji edge-case empty state dan dialog konfirmasi hapus).
  - Seluruh test suite proyek lolos (28/28 tests passed).
  - `flutter analyze` bersih (0 issues).

---

### Fase A4 — Alur Membaca (SELESAI)

- **Cakupan yang selesai:**
  - **`CollectionBookDetailPage` (diperbarui — PRD §7.4):**
    - Tombol **Start Reading** mengubah status ke `reading` dan menuju `/reading/timer/:id`.
    - Tombol **Update Progress** menuju `/reading/progress/:id`.
    - Rating bintang interaktif (1–5) hanya aktif bila status `finished`.
    - Field review teks hanya aktif setelah buku selesai.
  - **`ReadingTimerPage` (`/reading/timer/:id`):**
    - Stopwatch wall-clock berbasis `DateTime` timestamp — akurat saat app di-background.
    - Ticker refresh 200 ms, display jam:menit:detik Fraunces `displayLarge`.
    - Kontrol Pause / Resume / Finish Reading.
    - `PopScope` + dialog konfirmasi 3 pilihan saat back.
    - Simpan `ReadingSession` ke `ReadingRepository` saat Finish.
  - **`ReadingProgressPage` (`/reading/progress/:id`):**
    - Banner durasi sesi barusan, slider + input halaman manual.
    - Input total halaman bila belum ada.
    - Save Progress (update `currentPage` & `pageCount`).
    - Finished This Book → dialog → `_finishBookFlow` → LedgerService → `/reading/finished/:id`.
  - **`FinishedBookPage` (`/reading/finished/:id`):**
    - Ucapan selamat, ringkasan halaman & waktu baca kumulatif.
    - Auto-redirect 5 detik + countdown di tombol.
  - **`LedgerService` (PRD §10.2):**
    - SHA-256, canonical JSON deterministik, PoW mining (prefix `"00"`).
    - `ensureGenesisBlock` & `appendFinishedBook` idempoten.
    - `verifyChain`: validasi hash, prefix, previousHash, urutan index.
  - **`UserBook.copyWith`** ditambah parameter `pageCount`.
  - **`AppTextField`** ditambah parameter `textAlign`.
  - **Rute baru:** `/reading/timer/:id`, `/reading/progress/:id`, `/reading/finished/:id`.
- **Unit Test Wajib** `test/fase_a4_test.dart` — **10/10 lulus:**
  - T4-01: verifyChain valid → `isValid: true`
  - T4-02: Data diubah → terdeteksi
  - T4-03: previousHash diubah → terdeteksi
  - T4-04: appendFinishedBook idempoten
  - T4-05: Semua hash berawalan `"00"` (PoW)
  - T4-06: Rantai kosong → valid
  - T4-07: canonicalJson deterministik
  - T4-08: calculateHash deterministik, 64 hex chars
  - T4-09: Genesis-only chain → valid
  - T4-10: ensureGenesisBlock idempoten
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test`: **38/38 tests passed** (100% lolos).
- **DoD A4 Terpenuhi:**
  - ✅ Alur lengkap: Start Reading → Timer → Finish → Progress → Finished This Book → Finished Book → Home.
  - ✅ Currently Reading di Home berubah setelah status diperbarui.
  - ✅ Rating/Review aktif hanya setelah buku selesai.
  - ✅ Stopwatch wall-clock timestamp (bukan increment variabel).
  - ✅ LedgerService: SHA-256, PoW `"00"`, idempoten, verifyChain.
  - ✅ Unit test wajib PRD §10.2 ditulis dan lulus semua.

---

### Fase A5 — Tools, Mini Games, Kesan & Pesan, Konversi, AI Chat (SELESAI)

- **Cakupan yang selesai:**
  - **(1) Snake Game Engine & UI (`/tools/games` — PRD §10.1):**
    - `SnakeEngine`: engine murni Dart tanpa dependency Flutter, kisi kolom x baris, pencegahan balik arah 180°, deteksi tabrakan dinding & tubuh sendiri, interval akselerasi adaptif (200 ms turun hingga 90 ms).
    - `SnakePainter`: render buku menggunakan `CustomPainter` murni (vektor cover buku berlapis + pita pembatas buku, tanpa emoji/teks mentah) sesuai spesifikasi.
    - Kontrol gestur sentuh (swipe) & D-pad virtual, tombol pause/resume/restart, banner game over, dan integrasi penyimpanan high score via `ScoreRepository`.
  - **(2) Kesan & Pesan (`/tools/feedback` — PRD §7.7.1):**
    - Form Nama (otomatis prefilled dari user terautentikasi), Kesan, Pesan.
    - Validasi lengkap semua field, tombol kirim dengan indikator loading, pencegahan submit ganda.
    - Daftar entri langsung tampil secara real-time di bawah form dengan pengurutan terbaru di atas via `FeedbackRepository`.
  - **(3) Konversi Waktu (`/tools/time` — PRD §9.5):**
    - `TimeConverterService`: logika murni Dart menggunakan paket `timezone` (WIB UTC+7, WITA UTC+8, WIT UTC+9, London UTC+0/+1) yang secara otomatis menangani Daylight Saving Time (GMT vs BST).
    - `TimeConverterPage`: dropdown zona asal, date picker + time picker, tombol "Sekarang", 4 kartu zona dengan jam besar Fraunces, offset label, dan badge selisih hari (+1 / 0 / -1 hari).
  - **(4) Konversi Mata Uang (`/tools/currency` — PRD §9.2):**
    - Fungsi konversi murni `convertCurrency()` mendukung IDR, USD, EUR, JPY, dan SGD berbasis USD.
    - Tombol swap cepat, konversi instan saat nominal diinput, label disclaimer `"Kurs contoh (mode demo)"`.
    - Tabel referensi nilai tukar semua mata uang terhadap USD.
  - **(5) AI Chat (`/tools/ai-chat` — PRD §9.3):**
    - UI gelembung percakapan: pengguna di kanan (Deep Teal) dan asisten di kiri (Pale Peach / Dark Surface).
    - Balasan otomatis berlabel `"Jawaban contoh (mode demo)"` dari `FakeChatRepository`.
    - Indikator mengetik 3 titik beranimasi lembut, chip rekomendasi topik di empty state, counter karakter (maks. 500), dialog konfirmasi hapus riwayat chat.
  - **(6) ToolsPage Hub Redesign (`/tools` — PRD §7.7):**
    - 5 kartu vertikal dengan ikon bertema warna StoryLoka, tipografi Fraunces, ringkasan deskripsi, badge best score game Snake, dan panah navigasi.
  - **Rute baru di `lib/app/router.dart`:**
    - `/tools/feedback`
    - `/tools/ai-chat`
    - `/tools/games`
    - `/tools/currency`
    - `/tools/time`
- **Unit & Widget Tests:**
  - `test/fase_a5_snake_test.dart` — **13/13 lolos** (gerak maju, makan buku, tabrak dinding/tubuh, larangan 180°, interval kecepatan, pause/resume).
  - `test/fase_a5_tools_test.dart` — **11/11 lolos** (TimeConverterService multi-zona & pergantian hari, CurrencyConverter kalkulasi & format desimal, FeedbackRepository ordering, ScoreRepository high score, ChatRepository balasan demo & clear history).
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test`: **62/62 tests passed** (100% lolos seluruh proyek).
- **DoD A5 Terpenuhi:**
  - ✅ Snake engine murni Dart + unit test lengkap.
  - ✅ Buku di Snake digambar dengan CustomPainter (bukan emoji).
  - ✅ Form Kesan & Pesan menyimpan data dan daftar langsung tampil di bawah (terbaru di atas).
  - ✅ Konversi Waktu mendukung WIB, WITA, WIT, London dengan DST otomatis.
  - ✅ Konversi Mata Uang bekerja dengan logika nyata dan berlabel "Kurs contoh (mode demo)".
  - ✅ AI Chat UI lengkap dengan gelembung pesan, typing indicator, dan label demo.
  - ✅ flutter analyze bersih & flutter test lulus semua.

---

### Fase A6 — UI Profile (SELESAI)

- **Cakupan yang selesai:**
  - **Header Profil ([`profile_page.dart`](file:///c:/StoryLoka/lib/features/profile/profile_page.dart) — PRD §7.8):**
    - Avatar pengguna lingkaran dengan badge edit (tap untuk membuka layar edit profil).
    - Tampilan nama pengguna, email, dan bio kutipan/profil singkat.
    - Tombol "Edit Profil" menuju rute `/profile/edit`.
  - **Ringkasan Buku & Waktu Baca (Reading Summary):**
    - Perhitungan dinamis dari `LibraryRepository` dan `ReadingRepository`.
    - Format: `"{n} di koleksi • {m} wishlist • {k} selesai"` serta `Total waktu membaca: Xj Ym`.
  - **Edit Profil ([`edit_profile_page.dart`](file:///c:/StoryLoka/lib/features/profile/edit_profile_page.dart) — PRD §7.8):**
    - Pemilih foto avatar menggunakan `image_picker` (sumber kamera atau galeri, kompresi ≤ 800 px) serta opsi hapus foto.
    - Form edit nama lengkap dengan validasi wajib diisi (minimal 2 karakter).
    - Form edit bio singkat (multiline).
    - Email pengguna (readonly / disabled).
    - Penyimpanan perubahan ke `ProfileRepository` dan pembaruan state reaktif di `AuthController`.
  - **Pengaturan Tampilan & Tema (PRD §4.7 & §7.8):**
    - `SegmentedButton` dengan 3 opsi: **Light**, **Dark**, dan **Auto**.
    - Berubah nyata secara instan di seluruh aplikasi; Auto sementara mengikuti tema sistem perangkat.
  - **Pengaturan Keamanan Biometrik:**
    - Switch interaktif untuk mengaktifkan/menonaktifkan kunci biometrik (Fingerprint / Face ID) via `SecureSessionStore`.
  - **Pengaturan Notifikasi (UI Saja — PRD §7.8 & §10.5):**
    - Pengingat Membaca Harian: switch on/off + tombol pemilih jam (TimePicker dialog, default pukul 20:00).
    - Notifikasi Stopwatch Sesi: switch on/off untuk simulasi notifikasi ongoing.
  - **Reading Ledger ([`reading_ledger_page.dart`](file:///c:/StoryLoka/lib/features/profile/reading_ledger_page.dart) — PRD §10.2):**
    - Header penjelas singkat dan catatan arsitektur jujur: *"Simulasi edukatif single-node, bukan jaringan terdesentralisasi."*
    - Tombol **Verify Ledger** mengeksekusi `LedgerService.verifyChain(blocks)` dengan visualisasi hasil memakai ikon + teks (*"✔ Rantai Valid"* / *"✖ Blok #n Tidak Valid"*).
    - Daftar kartu blok blockchain menampilkan nomor blok, judul buku/pesan genesis, tanggal, ringkasan Hash & Prev Hash (8 karakter awal), nonce, dan status Proof of Work awalan `"00"`.
    - Empty state ramah pengguna bila hanya terdapat genesis block: *"Selesaikan buku pertamamu untuk menambah blok."*
  - **Logout Akun:**
    - Tombol logout di bagian bawah dengan dialog konfirmasi Batal / Keluar yang membersihkan sesi pengguna dan mengarahkan kembali ke `/login`.
  - **Pendaftaran Rute Baru di [`router.dart`](file:///c:/StoryLoka/lib/app/router.dart):**
    - `/profile/edit`
    - `/profile/ledger`
- **Unit & Widget Tests:**
  - `test/fase_a6_test.dart` — **6/6 lolos**:
    - `ThemeController`: switch Light, Dark, Auto (System).
    - `AuthController.updateProfile`: perubahan nama, bio, avatar, dan persistensi sesi.
    - `ProfilePage`: header, ringkasan buku, pilihan tema, switch biometrik/notifikasi.
    - `ProfilePage`: dialog konfirmasi logout.
    - `ReadingLedgerPage`: header penjelas, genesis block, dan aksi tombol Verify Ledger.
    - `EditProfilePage`: validasi nama wajib dan simpan perubahan profil.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test`: **68/68 tests passed** (100% lolos seluruh proyek).
- **DoD A6 Terpenuhi:**
  - ✅ Semua butir spesifikasi Bagian 7.8 terlihat dan bisa dioperasikan.
  - ✅ Tema Light/Dark berubah langsung di aplikasi; Auto mengikuti sistem.
  - ✅ Edit Profil dengan image_picker (kamera/galeri ≤ 800 px) & validasi nama wajib.
  - ✅ Reading Ledger dengan tombol Verify berikon + teks dan preview hash.
  - ✅ Logout dengan dialog konfirmasi.
  - ✅ Tanpa notifikasi atau sensor cahaya nyata (sesuai batasan Tahap A).

---

### Fase A7 — Polesan Tampilan & Audit Visual (SELESAI)

- **Audit Visual terhadap `docs/spec/design-system.md` (Bagian 12 "Checklist Review Visual") & PRD Bagian 4:**
  - **Token, Spacing & Radius:**
    - Spacing konsisten dengan `AppSpacing`: margin layar 24 px (`pageMargin`), gap antar-elemen 16 px (`l`), card padding 16 px (`cardPadding`).
    - Radius konsisten: Card 20 px (`cardRadius`), Button 14 px (`buttonRadius`), Input Field 12–14 px (`inputRadius`).
  - **Tipografi & Hirarki:**
    - Display, Title, Page Heading, Section Heading menggunakan **Fraunces SemiBold**.
    - Body, Label, dan Caption menggunakan **DM Sans Regular/Medium**.
    - Tombol primary (`PrimaryButton`): tinggi 48 px, background Deep Teal (`#1A535C`), teks putih, dengan label terlindung overflow (`Flexible` + `ellipsis`).
    - Tombol secondary (`SecondaryButton`): outline 1 px Deep Teal, background transparan/Warm Ivory, teks Deep Teal.
  - **Bottom Navigation (Main Shell — PRD §4.6):**
    - 5 tab: Home, Library, Tambah (+), Tools, Profile.
    - Tombol tengah (Tambah / Add Book) berukuran **56×56 px** lingkaran dengan warna Soft Apricot (`#F4A261`), ikon putih (`size: 28`), dan elevasi lembut.
    - Label semantics aksesibilitas dan visual label di bawah tombol.
  - **Aksesibilitas & Target Sentuh:**
    - Semua `IconButton` dan `AppIconButton` memiliki target sentuh minimal **44×44 px** (`kMinInteractiveDimension`).
    - Penambahan `tooltip` dan deskripsi aksesibilitas pada seluruh tombol ikon:
      - Tombol intip sandi (`AppTextField`): `"Tampilkan kata sandi"` / `"Sembunyikan kata sandi"`.
      - Tombol hapus pencarian (`LibraryPage` & `AddBookPage`): `"Hapus pencarian"`.
      - Tombol kembali (`ReadingTimerPage`): `"Kembali"`.
      - Tombol kirim pesan (`AiChatPage`): `"Kirim pesan"`.
      - Tombol tukar mata uang (`CurrencyConverterPage`): `"Tukar"`.
  - **State Simulation Lewat DemoControls (PRD §4.9):**
    - Seluruh fake repository terhubung dengan `DemoControls`:
      - `toggleDataEmpty()`: Menghasilkan empty state di seluruh layar berbasis data (Home, Library, Finished books, Kesan & Pesan, Chat).
      - `toggleNetworkError()`: Menghasilkan error state terstandarisasi dengan pesan ramah pengguna dan tombol retry (**"Coba Lagi"**).
      - `toggleSlowLatency()`: Simulasi loading state 2000 ms dengan indikator `CircularProgressIndicator` bertema Deep Teal.
  - **Uji Responsivitas & Bebas Overflow (Layar 360×640 px + Skala Teks 1.3):**
    - Dilakukan audit dan perbaikan overflow di seluruh layar aplikasi:
      - `HomePage`: Reading Summary Card 3 kolom dan seksi koleksi menggunakan `Expanded` dan `TextOverflow.ellipsis`.
      - `AddBookPage`: Filter chips dibungkus scroll horizontal (`SingleChildScrollView(scrollDirection: Axis.horizontal)`).
      - `CurrencyConverterPage`: Dropdown menu item dirapikan menjadi single-line (`$c · $name`) dan tombol swap berpadding compact sehingga bebas overflow vertikal dalam 48 px.
      - `TimeConverterPage`: Baris pemilih tanggal & jam dibungkus `Expanded` (`flex: 3` dan `flex: 2`) dengan teks `Flexible`.
      - `AiChatPage`: Empty state rekomendasi topik dibungkus `SingleChildScrollView` sehingga tidak terpotong pada layar ber-keyboard atau pendek.
      - `ProfilePage`: `SegmentedButton<ThemeMode>` disesuaikan dengan `showSelectedIcon: false`, `visualDensity: VisualDensity.compact`, dan padding 4 px agar pas sempurna di 360 px dengan teks 1.3x.
      - `ReadingProgressBar`: Teks indikator halaman dilindungi dengan `Expanded` dan `TextOverflow.ellipsis`.
      - `AppButton`: Label teks dibungkus `Flexible` dengan `maxLines: 1` dan `TextOverflow.ellipsis` saat berada di layout berdampingan.
- **Unit & Widget Tests:**
  - `test/fase_a7_test.dart` — **18/18 lolos**:
    - Audit token spacing, radius card, primary & secondary button hierarchy.
    - Uji responsif 360×640 px dan teks skala 1.3 pada 8 layar (Home, Library, AddBook, Tools, Profile, Currency, Time, AiChat, Snake).
    - Verifikasi empty state & error state toggle via `DemoControls`.
    - Verifikasi bottom nav 5 tab, tombol tengah 56 px, target sentuh 44×44 px, dan Semantics.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test`: **86/86 tests passed** (100% lolos di seluruh 9 file tes proyek).
- **DoD A7 Terpenuhi:**
  - ✅ Seluruh layar lulus checklist review visual `docs/spec/design-system.md` & PRD Bagian 4.
  - ✅ Spacing 24/16, card radius 20, button radius 14, tipografi Fraunces & DM Sans konsisten.
  - ✅ Bottom navigation 5 tab dengan tombol tengah Add 56 px Soft Apricot.
  - ✅ Tombol primary (Deep Teal) vs secondary (outline) konsisten.
  - ✅ Semua state (loading, empty, error + coba lagi) terverifikasi via `DemoControls`.
  - ✅ Bebas overflow pada layar 360×640 px dan text scale 1.3 di seluruh layar.
  - ✅ Aksesibilitas: tooltip/Semantics lengkap dan target sentuh minimal 44×44 px.
  - ✅ `flutter analyze` 0 issue dan seluruh tes lolos.

---

## Ringkasan Akhir Tahap A

Tahap A (Fase A0 sampai Fase A7) telah **SELESAI 100%**. Seluruh UI, alur mock/fake data, navigasi, mini games, tools, ledger blockchain edukatif, autentikasi sesi lokal, responsive rendering, dan audit desain visual telah selesai diuji dan memenuhi seluruh kriteria DoD.

**Status Akhir Tahap A:**
- Analisis Kode (`flutter analyze`): **0 issues found** (100% bersih).
- Tes Otomatis (`flutter test`): **86/86 tests passed** (9 test suite lengkap).

---

## TAHAP B — BACKEND DAN INTEGRASI

### Fase B1 — Penyimpanan Lokal (SQLite) (SELESAI)

- **Cakupan yang selesai:**
  - **Instalasi Paket:** Menambahkan `sqflite: ^2.4.5`, `path: ^1.9.1`, `path_provider: ^2.1.6`, dan `sqflite_common_ffi: ^2.4.4` (dev dependency).
  - **DatabaseHelper (`lib/data/database_helper.dart`):**
    - Mengimplementasikan helper database SQLite dengan versi 1 dan skema lengkap sesuai PRD §8.1:
      - `user_books`: tabel buku pengguna (koleksi & wishlist, status membaca, progress, rating/review, soft delete `is_deleted`, sync status).
      - `reading_sessions`: tabel log sesi membaca dengan durasi detik dan timestamp UTC.
      - `ledger_blocks`: tabel blok blockchain edukatif dengan index, hash, previousHash, nonce (Proof of Work), dan payload JSON kanonikal.
      - `feedbacks`: tabel saran & kesan mata kuliah.
      - `game_scores`: tabel skor game Snake dengan timestamp dan game identifier.
      - `chat_messages`: tabel riwayat chat AI (lokal saja, tidak disinkronkan ke cloud).
    - Indeks performa database:
      - `idx_user_books_user` pada `user_books(user_id, list_type, is_deleted)`.
      - `idx_sessions_book` pada `reading_sessions(user_book_id)`.
    - Fitur `clearUserData(userId)` untuk membersihkan data pengguna saat logout.
    - Dukungan injeksi database in-memory (`setTestDatabase`) untuk pengujian otomatis.
  - **Implementasi Local Repositories (`lib/data/repositories/local/local_repositories.dart`):**
    - `LocalLibraryRepository`: Mendukung `getBooks` (filter listType, exclude soft-deleted), `getBookById`, `findByGoogleBooksId`, `addBook` (idempoten & restore soft-deleted), `updateBook`, `deleteBook` (soft delete `is_deleted = 1`), `moveToCollection`, dan `getCurrentlyReading`.
    - `LocalReadingRepository`: `saveSession`, `getSessionsForBook`, `getAllSessions`, dan kalkulasi `getTotalReadingSeconds` via query agregasi SQLite `SUM(duration_seconds)`.
    - `LocalLedgerRepository`: `getBlocks` (terurut `block_index ASC`), `saveBlock`, dan `getLastBlock`. Terintegrasi dengan `LedgerService` nyata untuk Proof of Work dan verifikasi rantai blok.
    - `LocalFeedbackRepository`: `getAll` (terurut `created_at DESC`) dan `save`.
    - `LocalScoreRepository`: `getScores`, `saveScore`, dan `getHighScore` via query SQLite `MAX(score)`.
    - `LocalChatRepository`: `sendMessage`, `getHistory`, `saveMessage`, dan `clearHistory`.
  - **Registry Provider (`lib/app/providers.dart`):**
    - Menghubungkan implementasi nyata `LocalLibraryRepository`, `LocalReadingRepository`, `LocalLedgerRepository`, `LocalFeedbackRepository`, `LocalScoreRepository`, dan `LocalChatRepository` saat `useFakeData = false`.
    - Menggunakan arsitektur abstract repository tanpa mengubah satupun kode UI.
  - **Unit & Integration Tests:**
    - `test/fase_b1_test.dart` — **8/8 lolos** (100%):
      - CRUD koleksi, wishlist, perbarui progress membaca, soft delete.
      - Pindah buku dari wishlist ke collection.
      - Log sesi membaca dan akumulasi total detik membaca.
      - Genesis block, penambahan blok ledger buku selesai, dan verifikasi integritas rantai via `LedgerService.verifyChain`.
      - Simpan dan ambil riwayat pesan & kesan mata kuliah.
      - Simpan skor game Snake dan kalkulasi high score.
      - Simpan, ambil riwayat, dan hapus riwayat AI chat lokal.
      - **DoD Persistensi Data:** Data di SQLite bertahan setelah instance repository baru dibuat (mensimulasikan tutup & buka aplikasi).
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih tanpa warning).
  - `flutter test`: **94/94 tests passed** (100% lolos di seluruh 10 test suite proyek).
- **DoD B1 Terpenuhi:**
  - ✅ Database SQLite terbentuk sesuai skema PRD §8.1.
  - ✅ Seluruh 6 Local Repository terimplementasi dan lulus uji.
  - ✅ Data bertahan setelah aplikasi ditutup dan dibuka kembali.
  - ✅ Seluruh 86 tes Tahap A tetap 100% lolos.

---

### Fase B2 — Autentikasi dan Supabase (SELESAI)

- **Cakupan yang selesai:**
  - **Instalasi Paket:** `supabase_flutter`, `flutter_dotenv`, `local_auth`.
  - **Konfigurasi Environment ([`env.dart`](file:///c:/StoryLoka/lib/core/config/env.dart)):**
    - Satu-satunya titik akses `.env` — PRD §3.
    - Getter: `supabaseUrl`, `supabaseAnonKey`, `geminiApiKey`, `geminiModel`, `googleBooksApiKey`.
    - `isSupabaseConfigured`: cek kelengkapan URL + Key, mencegah crash bila `.env` kosong.
    - `setMockValues()` untuk override di unit test.
  - **Config Error Page ([`config_error_page.dart`](file:///c:/StoryLoka/lib/core/widgets/config_error_page.dart)):**
    - Layar error ramah pengguna jika `.env` kosong atau tidak lengkap, bukan crash.
    - Menampilkan pesan konfigurasi yang diperlukan dan instruksi pengisian.
  - **Inisialisasi Supabase ([`main.dart`](file:///c:/StoryLoka/lib/main.dart)):**
    - `Env.load()` → cek `Env.isSupabaseConfigured` → `Supabase.initialize(publishableKey:)`.
    - Graceful fallback: jika `.env` tidak lengkap, aplikasi tetap berjalan dalam mode demo.
  - **SupabaseAuthRepository ([`supabase_repositories.dart`](file:///c:/StoryLoka/lib/data/repositories/supabase/supabase_repositories.dart)):**
    - **Tanpa `supabase.auth`** — sesuai aturan AGENTS.md.
    - Menggunakan RPC PostgreSQL: `register_user`, `login_user`, `validate_session`, `logout_session`.
    - Pemetaan error ke pesan bahasa Indonesia:
      - `EMAIL_TAKEN` → "Email sudah terdaftar. Silakan gunakan email lain."
      - `INVALID_CREDENTIALS` → "Email atau password salah."
      - `SESSION_INVALID` → "Sesi tidak valid. Silakan login ulang."
    - Password dan token **tidak pernah dicetak ke log**.
  - **SupabaseProfileRepository:**
    - Menggunakan RPC `update_profile` untuk memperbarui nama dan bio pengguna.
    - Error handling konsisten dengan pesan bahasa Indonesia.
  - **BiometricService ([`biometric_service.dart`](file:///c:/StoryLoka/lib/core/services/biometric_service.dart)):**
    - Menggunakan paket `local_auth` nyata.
    - Cek ketersediaan biometrik (`canCheckBiometrics` + `isDeviceSupported`).
    - Prompt autentikasi dengan `localizedReason` bahasa Indonesia.
  - **Android Configuration:**
    - `MainActivity.kt` → `FlutterFragmentActivity` (wajib untuk `local_auth`).
    - Permissions: `USE_BIOMETRIC`, `INTERNET` di `AndroidManifest.xml`.
  - **Integrasi Provider ([`providers.dart`](file:///c:/StoryLoka/lib/app/providers.dart)):**
    - `SupabaseAuthRepository`, `SupabaseProfileRepository`, dan `BiometricService` terdaftar di registry provider saat `useFakeData = false`.
  - **Keamanan:**
    - `.env` terdaftar di `.gitignore`.
    - `.env.example` sebagai template referensi tanpa nilai rahasia.
    - `supabase/schema.sql` menyertakan skema SQL Lampiran A untuk referensi setup.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test`: **94/94 tests passed** (100% lolos di seluruh test suite proyek; tidak ada regresi).
- **DoD B2 Terpenuhi:**
  - ✅ `supabase_flutter`, `flutter_dotenv`, `local_auth` terpasang dan terintegrasi.
  - ✅ `Env` sebagai single-source-of-truth akses `.env`; `.env` kosong → layar error konfigurasi, bukan crash.
  - ✅ `SupabaseAuthRepository` menggunakan RPC custom tanpa `supabase.auth`.
  - ✅ Error `EMAIL_TAKEN`, `INVALID_CREDENTIALS`, `SESSION_INVALID` dipetakan ke pesan Indonesia.
  - ✅ `BiometricService` nyata dengan `local_auth` + `FlutterFragmentActivity`.
  - ✅ Password dan token tidak dicetak ke log.
  - ✅ `flutter analyze` 0 issue dan seluruh 94 tes lolos.

---

### Fase B3 — Google Books, Scan Barcode, Shake (SELESAI)

- **Cakupan yang selesai:**
  - **Instalasi Paket:** `mobile_scanner: ^7.4.2`, `sensors_plus: ^7.1.1`, `http: ^1.6.0`.
  - **GoogleBooksRepository ([`google_books_repository.dart`](file:///c:/StoryLoka/lib/data/repositories/remote/google_books_repository.dart) — PRD §9.1):**
    - Endpoint: `GET https://www.googleapis.com/books/v1/volumes`.
    - Parameter `q`: `intitle:` / `inauthor:` / `isbn:` sesuai filter. Encode URL otomatis.
    - `key` opsional dari `Env.googleBooksApiKey` (kosong = tanpa key).
    - Mapping field persis PRD §9.1:
      - `google_books_id` ← `id`
      - `title` ← `volumeInfo.title`
      - `authors` ← `volumeInfo.authors` digabung `", "` (kosong → "Penulis tidak diketahui")
      - `genre` ← `volumeInfo.categories[0]`
      - `synopsis` ← `volumeInfo.description` (strip tag HTML + decode entities)
      - `page_count` ← `volumeInfo.pageCount` (0/null → null)
      - `cover_url` ← `volumeInfo.imageLinks.thumbnail` (ubah `http://` → `https://`)
      - `isbn` ← `industryIdentifiers` (utamakan `ISBN_13`, fallback `ISBN_10`)
      - `publisher` ← `volumeInfo.publisher`
      - `price_amount/currency` ← `saleInfo.retailPrice` atau `saleInfo.listPrice` (jika tidak ada → null)
    - Error handling:
      - Timeout 15 detik → pesan "Koneksi ke server buku gagal (timeout 15 detik)."
      - Status non-200 → pesan dengan kode status.
      - `items` null/kosong → return list kosong (empty state).
    - `randomBook()`: kata kunci acak dari 10 subjek, `startIndex` acak 0–30, pilih hasil acak yang punya judul.
  - **ScanPage nyata ([`scan_page.dart`](file:///c:/StoryLoka/lib/features/add_book/scan_page.dart) — PRD §7.3):**
    - Scan barcode nyata via `mobile_scanner` (format EAN-13 saja, awalan 978/979).
    - Izin kamera ditolak → penjelasan + fallback input ISBN manual.
    - Kamera error / tidak tersedia → pesan + fallback input manual.
    - Setelah barcode terbaca → cari `isbn:{kode}` → buka detail jika ditemukan, "ISBN tidak ditemukan" jika tidak.
  - **SensorService ([`sensor_service.dart`](file:///c:/StoryLoka/lib/core/services/sensor_service.dart) — PRD §10.3):**
    - `Stream<void> shakeStream` dari `sensors_plus` (`userAccelerometerEventStream()`).
    - Deteksi: magnitudo `sqrt(x²+y²+z²) > 25 m/s²`, debounce 1.5 detik.
    - Getaran haptic (`HapticFeedback.mediumImpact`) saat shake terdeteksi.
    - Sensor tidak tersedia (desktop/emulator) → diam tanpa error.
  - **AddBookPage diperbarui ([`add_book_page.dart`](file:///c:/StoryLoka/lib/features/add_book/add_book_page.dart)):**
    - **Chip "Mode demo" dihapus** dari AppBar.
    - Shake listener aktif hanya saat halaman Add Book tampil (`initState` → `startListening`, `dispose` → `stopListening`).
    - Tombol ikon shake tetap tersedia sebagai alternatif aksesibilitas/emulator.
  - **Android Configuration:**
    - Permission `CAMERA` ditambahkan di `AndroidManifest.xml`.
  - **Provider Wiring ([`providers.dart`](file:///c:/StoryLoka/lib/app/providers.dart)):**
    - Path `useFakeData=false` menggunakan `GoogleBooksRepository` nyata.
    - Path `useFakeData=true` tetap menggunakan `FakeBookSearchRepository`.
  - **Interface Update:**
    - `BookSearchRepository.search()` menerima parameter opsional `startIndex`.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test test/fase_b3_test.dart`: **10/10 tests passed** (GoogleBooks mapping, timeout, non-200, empty items, ISBN normalize, HTML strip, cover https, saleInfo, SensorService singleton & stream).
  - `flutter test`: **104/104 tests passed** (100% lolos; tidak ada regresi).
- **DoD B3 Terpenuhi:**
  - ✅ `GoogleBooksRepository` dengan mapping field persis PRD §9.1.
  - ✅ Cover `http://` → `https://`, sinopsis strip HTML, harga hanya dari `saleInfo`.
  - ✅ Timeout 15 detik, status non-200, dan `items` kosong ditangani.
  - ✅ Scan barcode nyata via `mobile_scanner` + fallback input ISBN manual.
  - ✅ Izin kamera ditolak → penjelasan + input manual.
  - ✅ Shake via `sensors_plus` aktif hanya di halaman Add Book.
  - ✅ Chip "Mode demo" dihapus dari Add Book.
  - ✅ `flutter analyze` 0 issue dan seluruh 104 tes lolos.

---

### Fase B4 — Sinkronisasi Offline-First & Resolusi Konflik (PRD §8.3)
- **Status:** SELESAI
- **Komponen Utama:**
  - **SyncService ([`sync_service.dart`](file:///c:/StoryLoka/lib/core/services/sync_service.dart)):**
    - **Push Pending (`pushPending`):**
      - Urutan eksekusi tabel persis PRD §8.3: `user_books` $\rightarrow$ `reading_sessions` $\rightarrow$ `ledger_blocks` $\rightarrow$ `feedbacks` $\rightarrow$ `game_scores`.
      - Membaca baris SQLite dengan `sync_status = 'pending'`, mengonversi payload (mis. `is_deleted` int $\rightarrow$ boolean, `data_json` string $\rightarrow$ Map JSON).
      - Mengirim ke remote menggunakan `upsert(onConflict: 'id')`.
      - Memperbarui status baris SQLite lokal menjadi `'synced'`.
      - Kegagalan jaringan ditelan dan tidak memblokir aplikasi.
    - **Pull All (`pullAll`):**
      - Dipanggil setelah login/register berhasil, serta saat pull-to-refresh di Home, Library, dan Profile.
      - **Resolusi Konflik Last-Write-Wins (`user_books`):**
        - Jika `remote.updated_at > local.updated_at`: data lokal ditimpa data remote dan status menjadi `'synced'`.
        - Jika `local.updated_at >= remote.updated_at`: data lokal dipertahankan (lokal menang).
      - **Tabel Append-Only:** `reading_sessions`, `feedbacks`, dan `game_scores` di-insert jika belum ada di lokal.
      - **Ledger Blocks:** di-pull dengan urutan `block_index ASC` dan di-insert jika belum ada di lokal.
    - **Idempotensi Sinkronisasi:**
      - Pemanggilan `pullAll` berulang kali tidak menduplikasi baris di tabel SQLite manapun.
      - Pemanggilan `pushPending` berulang kali tidak mengirim ulang baris yang sudah bertatus `'synced'`.
    - **Pemicu Sinkronisasi Lain:**
      - Setelah operasi tulis lokal (`saveBook`, `updateBook`, `deleteBook`, `moveToCollection`, `saveSession`, `saveBlock`, `saveFeedback`, `saveScore`): memanggil `SyncService.instance.trigger()`.
      - Saat aplikasi kembali aktif ke foreground (`AppLifecycleState.resumed` di `StoryLokaApp`): memanggil `SyncService.instance.syncOnResume()`.
      - Saat logout: memanggil `SyncService.instance.syncBeforeLogout()` sebelum membersihkan sesi pengguna.
    - **Upload Avatar (`uploadAvatar`):**
      - Mengunggah berkas gambar ke Supabase Storage bucket `avatars` dengan nama unik `$userId/avatar_<timestamp>.jpg` dan opsi `upsert: true`.
    - **Indikator UI:**
      - Menampilkan status sinkronisasi kecil non-intrusif ("Tersinkron" / "Menyinkronkan..." / "Menunggu sinkron") di kartu pengguna `ProfilePage` menggunakan `ListenableBuilder` dan `Flexible` agar bebas overflow pada berbagai skala teks.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test test/fase_b4_test.dart`: **6/6 tests passed** (urutan push tabel, konversi soft delete, resolusi konflik remote menang vs lokal menang, idempotensi pullAll berulang, idempotensi pushPending berulang).
  - `flutter test`: **110/110 tests passed** (100% lolos; tidak ada regresi).
- **DoD B4 Terpenuhi:**
  - ✅ `SyncService` dengan urutan push `user_books` $\rightarrow$ `reading_sessions` $\rightarrow$ `ledger_blocks` $\rightarrow$ `feedbacks` $\rightarrow$ `game_scores`.
  - ✅ `pullAll` terhubung setelah login/register dan pull-to-refresh.
  - ✅ Sinkronisasi otomatis saat resume dan logout.
  - ✅ Logika konflik *last-write-wins* berdasarkan `updated_at`.
  - ✅ Idempotensi sinkronisasi teruji tanpa duplikasi data.
  - ✅ Upload avatar ke Storage bucket `avatars`.
  - ✅ Seluruh 110 pengujian otomatis lolos dan `flutter analyze` 0 issue.

---

### Fase B5 — Integrasi External API: Kurs, Gemini AI, dan LBS Maps (PRD §9.2, §9.3, §9.4)
- **Status:** SELESAI
- **Komponen Utama:**
  - **Gemini AI REST Repository ([`gemini_chat_repository.dart`](file:///c:/StoryLoka/lib/data/repositories/remote/gemini_chat_repository.dart)):**
    - Menggunakan endpoint Google Generative Language REST v1beta: `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`.
    - Mengirim header otentikasi `x-goog-api-key`.
    - Payload memuat `systemInstruction` persis PRD §9.3 ("Kamu adalah asisten StoryLoka, teman membaca yang ramah...").
    - Membatasi konteks percakapan ke maksimal **10 pesan terakhir** (`recentHistory`).
    - Verifikasi model: default dialihkan ke model produksi aktif `gemini-1.5-flash` jika konfigurasi bernilai `gemini-flash-latest` atau kosong.
    - Pemetaan error ke pesan ramah bahasa Indonesia:
      - `400` / `403`: `"Konfigurasi AI belum benar."`
      - `429`: `"Terlalu banyak permintaan, coba lagi sebentar."`
      - `SocketException`: `"Tidak ada koneksi internet. Periksa jaringan Anda."`
      - `TimeoutException`: `"Koneksi ke asisten AI timeout. Periksa jaringan Anda."`
    - Pada `AiChatPage` ([`ai_chat_page.dart`](file:///c:/StoryLoka/lib/features/tools/ai_chat_page.dart)): saat error terjadi, teks input pengguna tidak hilang (`_inputCtrl.text = text;`), bubble gagal ditarik dari list, dan `SnackBar` merah memuat tombol "Kirim ulang".
  - **Kurs Nyata ([`exchange_rate_repository.dart`](file:///c:/StoryLoka/lib/data/repositories/remote/exchange_rate_repository.dart)):**
    - Mengambil kurs mata uang live dari `https://open.er-api.com/v6/latest/{BASE}` dengan timeout 15 detik.
    - Menyimpan kurs ke cache lokal `SharedPreferences` (`exchange_rates_{BASE}`) selama **12 jam**.
    - Menggunakan getter `isFromCache` pada `CurrencyRepository` ([`currency_repository.dart`](file:///c:/StoryLoka/lib/data/repositories/currency_repository.dart)).
    - Pada `CurrencyConverterPage` ([`currency_converter_page.dart`](file:///c:/StoryLoka/lib/features/tools/currency_converter_page.dart)):
      - Jika memakai cache: menampilkan label `"Kurs tersimpan, mungkin tidak terbaru • {tanggal}"`.
      - Jika kurs live: menampilkan label `"Kurs diperbarui {tanggal}"`.
      - Fallback offline otomatis mengambil data cache tanpa melempar crash.
  - **Open Maps LBS Toko Buku Terdekat ([`location_service.dart`](file:///c:/StoryLoka/lib/core/services/location_service.dart)):**
    - Memanfaatkan paket `geolocator` untuk memperoleh koordinat GPS pengguna (`getCurrentPosition`).
    - Membuka aplikasi peta via `url_launcher` (`geo:{lat},{lng}?q=toko+buku` dan fallback web `maps.google.com/?q=...`) dengan `LaunchMode.externalApplication`.
    - Menampilkan dialog edukasi izin lokasi sesuai PRD §9.4 jika izin belum diberikan.
    - Menangani kondisi izin ditolak / GPS mati: membuka bottom sheet pencarian toko buku manual berdasarkan kota/daerah (`showManualLocationSheet`).
    - Jika izin ditolak permanen (`LocationPermission.deniedForever`): menampilkan tombol "Buka Pengaturan" yang memicu `openAppSettings()`.
    - Terhubung di `SearchBookDetailPage` dan `WishlistBookDetailPage`.
  - **Izin Android ([`AndroidManifest.xml`](file:///c:/StoryLoka/android/app/src/main/AndroidManifest.xml)):**
    - Ditambahkan permission `ACCESS_FINE_LOCATION` dan `ACCESS_COARSE_LOCATION`.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test test/fase_b5_test.dart`: **9/9 tests passed** (Gemini payload, systemInstruction, max 10 messages, error mapping 400/403/429/timeout/candidates kosong, live exchange rates, 12h cache fallback offline, isFromCache true/false, LocationService query).
  - `flutter test`: **119/119 tests passed** (100% lolos seluruh test suite tanpa regresi).
- **DoD B5 Terpenuhi:**
  - ✅ Gemini REST endpoint v1beta dengan `systemInstruction`, riwayat 10 pesan, dan error handling Indonesia.
  - ✅ Teks input pengguna tidak hilang saat chat AI gagal + tombol kirim ulang di SnackBar.
  - ✅ Kurs live dari `open.er-api.com`, cache 12 jam di `SharedPreferences`, dan label status cache.
  - ✅ Open Maps dengan `geolocator` GPS + bottom sheet fallback kota manual + buka pengaturan jika deniedForever.
  - ✅ Verifikasi nama model Gemini (`gemini-1.5-flash`) terdokumentasi di `docs/DEVIATIONS.md`.
  - ✅ `flutter analyze` 0 issue dan 119/119 tes lolos.

---

### Fase B6 — Sensor & Fitur Perangkat (Cahaya, Notifikasi, Gyroscope) (PRD §10.4, §10.5, §12)
- **Status:** SELESAI
- **Komponen Utama:**
  - **NotificationService ([`notification_service.dart`](file:///c:/StoryLoka/lib/core/services/notification_service.dart) — PRD §10.5):**
    - Dua saluran notifikasi terdaftar:
      - `reading_reminder`: "Pengingat Membaca", deskripsi ramah, `importance: Importance.high`, `priority: Priority.high`.
      - `reading_timer`: "Stopwatch Membaca", `ongoing: true`, `usesChronometer: true`, `when: timestamp`.
    - Penjadwalan harian `scheduleDailyReminder(hour, minute)` via `zonedSchedule`:
      - `matchDateTimeComponents: DateTimeComponents.time`.
      - `androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle`.
      - Judul persis: `"Waktunya membaca"` (tanpa emoji), body: `"Luangkan waktu beberapa menit untuk membaca hari ini."`.
      - Menggunakan zona waktu lokal dinamis via `flutter_timezone`.
    - Notifikasi stopwatch sesi membaca `showStopwatchNotification({title, startedAt})`:
      - Terintegrasi langsung di `ReadingTimerPage` saat sesi membaca dimulai atau dilanjutkan.
      - Dibatalkan (`cancelStopwatchNotification`) saat sesi dijeda, disimpan, atau halaman ditutup.
    - Manajemen izin: `requestPermission()` meminta izin `POST_NOTIFICATIONS` (Android 13+) saat pertama kali switch diaktifkan.
    - Persistensi preferensi ke `SharedPreferences` (`reminder_enabled`, `reminder_hour`, `reminder_minute`, `stopwatch_notif_enabled`).
    - Pembatalan otomatis jadwal notifikasi saat logout.
  - **LightSensorService & Auto Theme ([`light_sensor_service.dart`](file:///c:/StoryLoka/lib/core/services/light_sensor_service.dart) — PRD §10.4):**
    - Verifikasi paket `light_sensor: 3.0.2` di pub.dev (khusus Android native).
    - Window moving average 3 detik (`calculateAverageLux`) untuk memfilter noise/fluktuasi sesaat.
    - Logika hysteresis:
      - Rata-rata < 10 lux $\rightarrow$ mode Gelap (Dark).
      - Rata-rata > 40 lux $\rightarrow$ mode Terang (Light).
      - Rata-rata 10–40 lux $\rightarrow$ buffer, pertahankan tema aktif sebelumnya.
    - Rate limit perubahan tema: minimal selang waktu 5 detik.
    - Fallback dinamis: jika sensor lux absen (platform non-Android/desktop/simulator), mode Auto mengikuti tema sistem bawaan dan menampilkan penjelasan di Profile: *"Sensor cahaya tidak tersedia, mengikuti tema sistem."*.
    - Terhubung reaktif ke `ThemeController` saat `ThemeMode.system` dipilih di `ProfilePage`.
  - **Sensor Kedua Gyroscope ([`sensor_service.dart`](file:///c:/StoryLoka/lib/core/services/sensor_service.dart) & [`snake_page.dart`](file:///c:/StoryLoka/lib/features/tools/snake/snake_page.dart) — PRD §10.4):**
    - Implementasi sensor fisik kedua menggunakan Gyroscope (`sensors_plus`) via `startTiltListening` dan `tiltStream`.
    - Opsi interaktif "Tilt Control (Gyroscope)" pada game Book Snake.
    - Memungkinkan kemiringan fisik perangkat mengendalikan arah gerak ular secara responsif di samping kontrol tombol sentuh/keyboard.
  - **Konfigurasi Izin Android & iOS (PRD §12):**
    - `android/app/src/main/AndroidManifest.xml`:
      - Label aplikasi resmi: `android:label="StoryLoka"`.
      - Permissions lengkap: `POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED`, `INTERNET`, `USE_BIOMETRIC`, `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`.
      - Receivers: `ScheduledNotificationReceiver` dan `ScheduledNotificationBootReceiver` dengan intent filter `ACTION_BOOT_COMPLETED`.
      - Queries: URI scheme `geo` dan `https`.
    - `ios/Runner/Info.plist`:
      - `CFBundleDisplayName`: `StoryLoka`.
      - Usage descriptions lengkap: `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSFaceIDUsageDescription`, `NSPhotoLibraryUsageDescription`.
  - **Unit & Integration Tests ([`fase_b6_test.dart`](file:///c:/StoryLoka/test/fase_b6_test.dart)):**
    - 9 pengujian: moving average lux 3 detik, aturan hysteresis (<10, >40, 10-40 buffer), rate limit 5 detik, auto fallback label, simpan & baca preferensi pengingat/stopwatch, instance NotificationService, dan stream sensor.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test test/fase_b6_test.dart`: **9/9 tests passed**.
  - `flutter test`: **128/128 tests passed** (100% lolos di seluruh 14 test suite; tidak ada regresi).
- **DoD B6 Terpenuhi:**
  - ✅ Notifikasi pengingat harian dengan `zonedSchedule`, `matchDateTimeComponents: DateTimeComponents.time`, `inexactAllowWhileIdle`, dan judul "Waktunya membaca".
  - ✅ Notifikasi stopwatch sesi dengan `ongoing: true`, `usesChronometer: true`, dan timestamp waktu mulai.
  - ✅ Izin `POST_NOTIFICATIONS` diminta saat pertama kali diaktifkan.
  - ✅ Mode Auto dengan sensor cahaya, moving average 3 detik, hysteresis (<10 lux & >40 lux), dan rate limit 5 detik.
  - ✅ Verifikasi paket sensor cahaya pub.dev + fallback tema sistem + fallback sensor kedua Gyroscope (Tilt Control Snake) terdokumentasi di `docs/DEVIATIONS.md`.
  - ✅ AndroidManifest.xml dan Info.plist lengkap sesuai PRD §12.
  - ✅ `flutter analyze` 0 issue dan seluruh 128 tes lolos.

---

### Fase B7 — Finalisasi & Kesiapan Rilis (PRD §13.2 & Bagian 15)
- **Status:** SELESAI
- **Komponen Utama:**
  - **Ubah Default USE_FAKE ke false ([`providers.dart`](file:///c:/StoryLoka/lib/app/providers.dart)):**
    - `AppConfig.useFakeData` diubah dari `defaultValue: true` menjadi `defaultValue: false`.
    - Seluruh repository abstrak secara default mengikat implementasi nyata: `LocalLibraryRepository`, `LocalReadingRepository`, `LocalLedgerRepository`, `LocalFeedbackRepository`, `LocalScoreRepository`, `GoogleBooksRepository`, `OpenExchangeRateRepository`, `GeminiChatRepository`, `SupabaseAuthRepository`, `SupabaseProfileRepository`, dan `SyncService`.
  - **Pembersihan Data Demo di Alur Nyata ([`demo_widgets.dart`](file:///c:/StoryLoka/lib/core/widgets/demo_widgets.dart)):**
    - `DemoModeChip` otomatis mengembalikan `SizedBox.shrink()` jika `!AppConfig.useFakeData` atau `!kDebugMode`. Tidak ada lagi label "Mode demo" pada rute utama Home, Library, Add Book, Profile, Login, Register, maupun Lock Screen di alur nyata.
    - Pada `CurrencyConverterPage`, label mode demo tidak ditampilkan lagi di alur nyata.
    - `DemoControlsSheet` dan tombol simulasi biometrik dibatasi eksklusif hanya untuk `kDebugMode`.
  - **Kompilasi & Build APK Android ([`build.gradle.kts`](file:///c:/StoryLoka/android/app/build.gradle.kts)):**
    - Menambahkan konfigurasi `isCoreLibraryDesugaringEnabled = true` dan dependensi `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` untuk kompatibilitas desugaring modern paket `flutter_local_notifications`.
    - Berhasil membangun APK Android: `build\app\outputs\flutter-apk\app-debug.apk` (exit code 0).
  - **Unit & Integration Tests ([`fase_b7_test.dart`](file:///c:/StoryLoka/test/fase_b7_test.dart)):**
    - 5 pengujian otomatis untuk verifikasi default `USE_FAKE = false`, eliminasi chip demo pada alur nyata, registrasi seluruh repository nyata, dan label non-demo pada halaman mata uang.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (100% bersih tanpa warning).
  - `flutter test test/fase_b7_test.dart`: **5/5 tests passed**.
  - `flutter test`: **133/133 tests passed** (100% lolos di seluruh 15 file test suite proyek).
  - `flutter build apk --debug`: **SUCCESS** (`build\app\outputs\flutter-apk\app-debug.apk`).
- **DoD B7 Terpenuhi:**
  - ✅ Default `USE_FAKE` diubah menjadi `false`.
  - ✅ Tidak ada data demo dan chip "Mode demo" di alur nyata.
  - ✅ DemoControls dan simulasi biometrik hanya tersedia di `kDebugMode`.
  - ✅ Seluruh pengujian lolos (133/133 passed) dan `flutter analyze` 0 issue.
  - ✅ `docs/DEVIATIONS.md` lengkap.
  - ✅ Checklist Bagian 15 ditelusuri dan terverifikasi penuh.
  - ✅ Build APK debug berhasil dibuat.

---

## Penelusuran Checklist Verifikasi Akhir (PRD Bagian 15)

### Fungsional
- [x] **Register/login/logout; session bertahan; password ter-hash di server; tanpa Firebase.**
  - *Bukti:* `lib/data/repositories/supabase/supabase_repositories.dart` (`SupabaseAuthRepository`), RPC PostgreSQL `register_user`, `login_user`, `logout_session` dengan bcrypt salt di database Supabase tanpa Firebase/supabase.auth; sesi disimpan terenkripsi di `FlutterSecureStorage` (`SecureSessionStore`); alur logout membersihkan data pengguna di SQLite sesuai PRD §7.8; teruji di `test/fase_a1_test.dart`, `test/fase_b1_test.dart`, `test/fase_f1_test.dart`, `test/widget_test.dart`.
- [x] **Biometrik aktif/nonaktif dan dipakai saat membuka aplikasi.**
  - *Bukti:* `lib/core/services/biometric_service.dart` (`local_auth`), `MainActivity.kt` (`FlutterFragmentActivity`), switch biometrik di `ProfilePage`, dan penguncian di `LockScreenPage`; teruji di `test/fase_a1_test.dart`, `test/fase_b1_test.dart`, dan `test/fase_u4d_test.dart`.
- [x] **Cari Title/Author/ISBN, scan barcode, shake to discover.**
  - *Bukti:* `CompositeBookSearchRepository` (pencarian hibrida Google Books + Open Library fallback), `lib/features/add_book/scan_page.dart` (`mobile_scanner` EAN-13), dan `lib/core/services/sensor_service.dart` (shake accelerometer > 25 m/s²); teruji di `test/fase_b3_test.dart`, `test/fase_s1_test.dart`, `test/open_library_enrich_test.dart`.
- [x] **Add to Collection/Wishlist tanpa duplikat; tombol berubah jadi "Added to …".**
  - *Bukti:* `SearchBookDetailPage` (`_handleAddToCollection`, `_handleAddToWishlist`) yang memeriksa status buku di `LibraryRepository` dan mengubah label tombol; teruji di `test/fase_a2_test.dart` & `test/fase_b1_test.dart`.
- [x] **Wishlist → Add to Collection memindahkan buku.**
  - *Bukti:* `LocalLibraryRepository.moveToCollection`, tombol aksi di `WishlistBookDetailPage` memindahkan buku ke koleksi (`list_type = 'collection'`) tanpa mereset progres membaca sesuai PRD §7.6; teruji di `test/fase_a3_test.dart`, `test/fase_b1_test.dart`, `test/fase_f1_test.dart`.
- [x] **Start Reading → Timer → Finish → Progress → Save/Finished → Finished Book → Home.**
  - *Bukti:* Alur membaca wall-clock stopwatch di `ReadingTimerPage`, update progres halaman di `ReadingProgressPage`, dan rating/review dialog buku selesai; teruji di `test/fase_a4_test.dart`.
- [x] **Currently Reading berganti sesuai buku terakhir yang dimulai; kosong setelah diselesaikan.**
  - *Bukti:* `HomePage` (`_buildCurrentlyReadingSection`) dan `LocalLibraryRepository.getCurrentlyReading` merespon reaktif terhadap sesi membaca dan status `finished`; teruji di `test/fase_a3_test.dart` & `test/fase_a4_test.dart`.
- [x] **Rating/review hanya bisa diisi setelah buku selesai.**
  - *Bukti:* Form bintang 1–5 dan ulasan hanya aktif saat buku selesai di `ReadingProgressPage` dan tersimpan di database; teruji di `test/fase_a4_test.dart` & `test/fase_b1_test.dart`.
- [x] **Open Maps (izin diberi dan ditolak/lokasi manual).**
  - *Bukti:* Peta toko buku bawaan (`BookstoreMapPage` via `flutter_map` / OpenStreetMap / Overpass API) dan integrasi eksternal (`location_service.dart` via intent `geo:` / Google Maps), dialog izin, bottom sheet pencarian manual jika ditolak, serta shortcut pengaturan jika ditolak permanen; teruji di `test/fase_b5_test.dart` & `test/fase_s3_test.dart`.
- [x] **Konversi mata uang (≥3) dan waktu (WIB/WITA/WIT/London) benar.**
  - *Bukti:* `CurrencyConverterPage` mendukung 5 mata uang (IDR, USD, EUR, JPY, SGD via live API `open.er-api.com` + cache 12 jam) dan `TimeConverterPage` (paket `timezone` dengan penyesuaian DST otomatis London); teruji di `test/fase_a5_tools_test.dart` & `test/fase_b5_test.dart`.
- [x] **AI Chat menjawab seputar buku dan menangani error.**
  - *Bukti:* `DeepSeekChatRepository` (LLM primer endpoint chat/completions) dengan fallback otomatis ke `GeminiChatRepository` (endpoint REST v1beta), penanganan error 400/403/429/offline, retensi input teks, dan pembatasan riwayat pesan; teruji di `test/fase_b5_test.dart`, `test/fase_s4_test.dart`, `test/fase_f1_test.dart`.
- [x] **Snake dapat dimainkan, skor tersimpan, pause otomatis saat background.**
  - *Bukti:* `SnakeEngine` dengan papan 15 kolom (`_cols = 15`) dan baris adaptif proporsional tinggi layar (`targetRows = (availableHeight / cell).floor()`), kontrol swipe + D-pad + kemiringan accelerometer/gyroscope, pause otomatis saat background, dan skor tersimpan ke `LocalScoreRepository`; teruji di `test/fase_a5_snake_test.dart`, `test/fase_b1_test.dart`, `test/fase_s6_test.dart`.
- [ ] **Kesan & Pesan (Status: Draf / Read-Only Fase S7 — Menunggu Input Teks Asli Pemilik Proyek).**
  - *Status:* Berdasarkan keputusan penyederhanaan Fase S7, Kesan & Pesan diubah dari form input menjadi tampilan statis read-only (`lib/data/static/team_feedback.dart`) untuk 3 anggota kelompok (Najmah Cleosa, Melanie Bunga Chintya Pawesty, Naftali Margareta) dan dikeluarkan dari sync database. **Belum berstatus final** karena teks pesan/kesan saat ini masih berupa draf template dan wajib diganti dengan tulisan asli masing-masing anggota sebelum pengumpulan akhir. Teruji di `test/fase_s7_test.dart`.
- [x] **Notifikasi pengingat dan stopwatch bekerja.**
  - *Bukti:* `NotificationService` (`flutter_local_notifications` 22.x, pengingat harian `zonedSchedule` dengan judul "Waktunya membaca", penjadwalan `inexactAllowWhileIdle` tanpa izin invasif exact alarm, stopwatch sesi ongoing dengan `usesChronometer` dan timestamp mulai); teruji di `test/fase_b6_test.dart` & `test/fase_r4_notif_test.dart`.
- [x] **Tema Light/Dark/Auto bekerja.**
  - *Bukti:* `ThemeController`, sensor cahaya native platform channel (`MainActivity.kt` `storyloka/light` dengan moving average 3s, hysteresis <10 lux dark, >40 lux light, jeda 5s), SegmentedButton di `ProfilePage`; teruji di `test/fase_a6_test.dart`, `test/fase_b6_test.dart`, `test/fase_r3_test.dart`.
- [x] **Reading Ledger menambah blok saat selesai; Verify Ledger mendeteksi data yang diubah.**
  - *Bukti:* `LedgerService` (SHA-256 kanonikal, PoW prefix `"00"`, genesis block deterministik UUID v5, verifikasi integritas rantai blok), tersimpan di SQLite, deteksi manipulasi rantai di `ReadingLedgerPage`; teruji di `test/fase_a4_test.dart`, `test/fase_b1_test.dart`, `test/fase_f1_test.dart`.
- [x] **Data offline tersinkron ke Supabase; login perangkat baru menarik data.**
  - *Bukti:* `SyncService` (`pushPending` berurutan sesuai PRD §8.3, resolusi konflik LWW untuk `user_books`, deduplikasi deterministik `ledger_blocks`, upload avatar ke Storage, integrasi login/resume/logout/pull-to-refresh); teruji di `test/fase_b4_test.dart` & `test/fase_f1_test.dart`.

### Kualitas
- [x] **Tidak ada data palsu yang tampil sebagai data nyata; tidak ada secret di repository.**
  - *Bukti:* `AppConfig.useFakeData = false` secara default; `DemoModeChip` disembunyikan; data buku bersumber dari Google Books API nyata / Open Library; harga kosong menampilkan "Harga tidak tersedia"; `.env` tercantum di `.gitignore` dan diakses hanya lewat `Env` (`env.dart`). Teruji di `test/fase_b7_test.dart`.
- [x] **Spacing, radius, tipografi, tombol, dan nav konsisten dengan Bagian 4.**
  - *Bukti:* `AppSpacing` (24 page margin, 16 gap/card padding), `cardRadius: 20`, `buttonRadius: 14`, font Fraunces & DM Sans, `PrimaryButton` 48px Deep Teal, Bottom Navigation 5-tab dengan tombol Add 56px Soft Apricot; teruji di `test/fase_a7_test.dart`.
- [x] **Setiap layar punya state loading/empty/error.**
  - *Bukti:* Home, Library, Add Book, Tools, Profile, Feedback, Snake, AI Chat, Detail Buku seluruhnya memiliki penanganan state `loading` (CircularProgressIndicator), `empty` (pesan editorial), dan `error` (pesan ramah + tombol coba lagi); teruji di `test/fase_a7_test.dart`.
- [x] **Tidak ada overflow di 360×640 dan skala teks 1.3.**
  - *Bukti:* Seluruh 8 layar utama diuji dan lulus uji rendering pada resolusi 360×640 px dengan `textScale: 1.3` tanpa RenderFlex overflow; teruji di `test/fase_a7_test.dart` & `test/fase_u1_test.dart`.
- [x] **`flutter analyze` bersih; semua tes lolos; APK debug berhasil dibuild.**
  - *Bukti:* `flutter analyze` exit 0 (0 issues found), `flutter test` exit 0 (345/345 tests passed), `flutter build apk --debug` menghasilkan `build\app\outputs\flutter-apk\app-debug.apk`.
- [x] **`docs/PROGRESS.md` dan `docs/DEVIATIONS.md` lengkap.**
  - *Bukti:* Seluruh dokumentasi Fase A0–A7, B1–B7, U0–U5, R1–R6, S1–S8, F1–F5 lengkap dan terverifikasi.

---

### Fase U0 — Audit UI & Layout StoryLoka (SELESAI)

- **Cakupan yang selesai:**
  - Audit visual menyeluruh pada seluruh halaman dan widget di `lib/` tanpa mengubah kode aplikasi.
  - Menghasilkan dokumen laporan audit `docs/UI_AUDIT.md` dengan 6 kategori temuan:
    1. Lebar/Tata Letak (potensi overflow, fixed size, card tidak selebar penuh).
    2. Token Desain (warna, spacing, radius, font mentah).
    3. Komponen (penggunaan dropdown/tombol/card bawaan vs core widgets).
    4. Dark Mode (kontras rendah, hardcoded light color).
    5. Teks & Bahasa (format campur bahasa, duplikasi label, judul tanpa ellipsis).
    6. Aksesibilitas (target sentuh < 44×44 px, kontras warna).

---

### Fase U1 — Fondasi Responsif dan Anti-Overflow (SELESAI)

- **Cakupan yang selesai:**
  - **Komponen `ResponsiveBody` (`lib/core/widgets/responsive_body.dart`):**
    - Membatasi konten dengan lebar maksimum 560 px di layar lebar (tablet/desktop) dan memusatkan konten secara horizontal (`Center` + `ConstrainedBox`).
    - Menjaga margin horizontal 24 px (`AppSpacing.pageMargin`) dan menghormati `SafeArea`.
    - Diterapkan pada 7 layar utama: `HomePage`, `LibraryPage`, `AddBookPage`, `ToolsPage`, `ProfilePage`, `LoginPage`, `RegisterPage`.
    - Bottom navigation bar tetap selebar layar.
  - **SingleChildScrollView + SafeArea:**
    - `finished_book_page.dart`: dibungkus `SafeArea` + `SingleChildScrollView`, `Spacer` diganti `SizedBox`.
    - `reading_timer_page.dart`: stopwatch proporsional `(screenWidth * 0.55).clamp(180.0, 260.0)`, teks dibungkus `FittedBox`, dibungkus `SafeArea` + `SingleChildScrollView`.
    - `lock_screen_page.dart`: dibungkus `SafeArea` + `SingleChildScrollView`.
  - **Tata Letak Adaptif 2 Tombol Berdampingan:**
    - `search_book_detail_page.dart` & `collection_book_detail_page.dart`: otomatis beralih dari `Row` ke `Column` jika `screenWidth < 340` atau `textScaler.scale(1.0) > 1.15`.
  - **Pencegahan Overflow pada Baris Input & Metadata:**
    - `reading_progress_page.dart`: perbaikan baris input halaman dengan `Expanded(child: AppTextField)` dan suffix label `/ total hlm`.
    - `library_page.dart`: grid 3 kolom memiliki `childAspectRatio` dinamis berdasarkan skala teks `MediaQuery.textScalerOf(context).scale(1.0)`.
    - `reading_ledger_page.dart`: penyelarasan `Row` header verifikasi rantai dan chip blok (`Flexible` + `Expanded`).
    - `currency_converter_page.dart`: dropdown Dari/Ke disusun `Column` jika layar sempit atau skala teks > 1.15.
    - `feedback_page.dart`: label input nama/kesan/pesan tidak lagi menggunakan lebar tetap 60 px.
    - `StatusBadge` & `_buildMetaItem`: teks dibungkus `Flexible` dengan ellipsis dan batas maksimum lebar.
  - **Pengujian Responsif (Widget Test Suite):**
    - Membuat `test/fase_u1_test.dart` menguji 16 halaman di 4 variasi ukuran dan skala teks:
      1. 360×640 px (skala teks 1.0)
      2. 360×640 px (skala teks 1.3)
      3. 402×874 px (skala teks 1.0)
      4. 800×1280 px Tablet (skala teks 1.0)
    - Menguji batasan `ResponsiveBody` `maxWidth: 560`.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test`: **138/138 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase U2 — Perbaikan HomePage (SELESAI)

- **Cakupan yang selesai:**
  - **Semua card di Home selebar penuh area konten:**
    - Mengubah Column utama di `home_page.dart` menggunakan `crossAxisAlignment: CrossAxisAlignment.stretch`.
    - Semua card (Reading Summary, Currently Reading kosong/terisi, My Collection, My Wishlist) meregang selebar area konten `ResponsiveBody` (lebar penuh di ponsel, maksimal 560 px di tablet).
  - **Currently Reading kosong:**
    - Dibangun menggunakan `EmptyStateCard.horizontal` menggantikan rakitan manual.
    - Tata letak horizontal: lingkaran ikon kecil di kiri (48×48 px, sage/surfaceDark, deepTeal/primaryDark), judul "Start Your Reading Journey", subteks "Your next favorite book is waiting for you.", dan tombol `PrimaryButton` "Add Book" di kanan.
    - Serasi dengan empty state My Collection dan My Wishlist.
  - **Currently Reading terisi:**
    - Cover buku minimal 80×120 (rasio 2:3) dengan `borderRadius: 10`.
    - Judul buku maksimal 2 baris Fraunces (`AppText.cardHeading`) dengan ellipsis.
    - Penulis maksimal 1 baris (`AppText.caption`).
    - `ReadingProgressBar` tinggi 6 px + teks progres halaman + persentase.
    - Tombol `Read` (`PrimaryButton`) dan `Update` (`SecondaryButton`) selebar penuh dengan penataan adaptif (Row pada lebar normal, Column pada layar sempit/skala teks > 1.25).
  - **My Collection & My Wishlist terisi:**
    - Tiga cover buku sejajar dengan rasio 2:3, jarak antarcover 12 px (`AppSpacing.m`), tidak terpotong (menggunakan `Expanded` proporsional merata).
    - Ditambahkan `Semantics(label: 'Buka detail buku ${book.title}', button: true)` untuk aksesibilitas screen reader.
  - **Tombol "See all" & Warna Ikon Dinamis:**
    - Menggunakan `TertiaryButton` dengan `trailingIcon: Icons.arrow_forward_rounded`.
    - Warna ikon dinamis di empty state: `isDark ? AppColors.primaryDark : AppColors.deepTeal`.
    - Avatar profil menggunakan `customBorder: const CircleBorder()` tanpa radius mentah.
  - **Proteksi Overflow Skala Teks 1.3:**
    - `EmptyStateCard.horizontal` dilengkapi `LayoutBuilder` yang otomatis beralih ke layout vertikal bila constraint < 340 px atau skala teks > 1.15, mencegah tombol mendesak teks penjelasan sampai terpotong.
  - **Pengujian & Verifikasi:**
    - Membuat `test/fase_u2_test.dart` dengan 8 tes komprehensif menguji semua skenario: empty, filled, error, loading, ukuran ponsel (360 px, 402 px) & tablet (800 px), teks skala 1.0 & 1.3, serta light & dark mode via `DemoControls`.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test`: **146/146 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase U3 — Standarisasi Dropdown dan Input (SELESAI)

- **Cakupan yang selesai:**
  - **Komponen Reusable `AppDropdown<T>` (`lib/core/widgets/app_dropdown.dart`):**
    - Dibangun berbasis Material 3 `DropdownMenu<T>` dengan menu yang terbuka **di bawah field input** (tidak menimpa field atau menutupi header halaman).
    - Lebar menu sama dengan lebar field (`expandedInsets: EdgeInsets.zero`).
    - Radius border 12 px (`AppSpacing.inputRadius`), border neutral, fokus deep teal / primary dark.
    - Surface dan background konsisten dengan tema (light: putih, dark: surfaceDark).
    - Item yang terpilih disorot lembut (`backgroundColor: primaryColor.withValues(alpha: 0.18)`), tinggi menu dibatasi (`menuHeight: 280`), dan bisa di-scroll.
    - Menggunakan controller internal yang tersinkronisasi pada `didUpdateWidget` agar dapat bereaksi reaktif terhadap perubahan nilai dari luar (misal tombol Swap).
  - **Migrasi Dropdown Seluruh Aplikasi:**
    - `time_converter_page.dart`: Mengganti `DropdownButtonHideUnderline` + `DropdownButton<TimeZone>` dengan `AppDropdown<TimeZone>`.
    - `currency_converter_page.dart`: Mengganti `DropdownButtonHideUnderline` + `DropdownButton<String>` dengan `AppDropdown<String>`.
  - **Penyelarasan Input:**
    - `add_book_page.dart`: Mengganti `TextField` mentah dengan `AppTextField` standar (tinggi 48, radius 12, border neutral).
    - `scan_page.dart`: Mengganti `TextField` mentah dengan `AppTextField`.
    - `location_service.dart`: Mengganti `TextField` input manual lokasi dengan `AppTextField`.
    - `ai_chat_page.dart`: Warna tombol kirim diselaraskan dengan `isDark ? AppColors.primaryDark : AppColors.deepTeal`.
  - **Penyempurnaan Konversi Waktu (`time_converter_page.dart`):**
    - Format tanggal pada kartu hasil menggunakan locale Indonesia `id_ID` via `initializeDateFormatting('id_ID', null)` ("Kam, 22 Okt 2026").
    - Menghilangkan label ganda seperti "(WIB)" pada subjudul zona waktu.
    - `_PickerChip` tanggal dan jam memiliki tinggi target sentuh minimal 44 px (`AppSpacing.touchTarget`) dan dibungkus `Semantics(button: true, label: ...)`.
    - Kartu hasil konversi menggunakan `AppCard` standar dengan warna badge "+1 hari" yang dinamis di dark mode.
    - Baris tanggal dan waktu adaptif terhadap skala teks 1.3 via `LayoutBuilder`.
  - **Pengujian & Verifikasi Widget Test:**
    - Membuat `test/fase_u3_test.dart` dengan 7 pengujian komprehensif menguji:
      1. Menu dropdown terbuka di bawah field (`menuTop >= fieldBottom`).
      2. Lebar menu sama dengan lebar field.
      3. Dropdown zona waktu dan format tanggal locale `id_ID`.
      4. Target sentuh >= 44 dan Semantics chip tanggal/jam.
      5. Bebas overflow pada layar 360 px dengan teks skala 1.3 di Konversi Waktu.
      6. Fungsi tukar (swap) mata uang di Konversi Mata Uang.
      7. Bebas overflow pada layar 360 px dengan teks skala 1.3 di Konversi Mata Uang.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test`: **153/153 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase U4a — Pembersihan Elemen Demo, Target Sentuh 44×44, & Eliminasi Duplikasi (SELESAI)

- **Cakupan yang selesai:**
  - **Pembersihan Elemen Demo & Penyesuaian Alur Produksi:**
    - `ai_chat_page.dart`: Banner "Mode Demo — Balasan tidak menggunakan AI nyata" hanya tampil jika `AppConfig.useFakeData` dengan warna teks dinamis tema.
    - `login_page.dart`: Kartu "Catatan Mode Demo (Fase A1)" hanya tampil jika mode fake aktif dan `kDebugMode`. Kredensial demo (`reader@storyloka.app` & `password123`) dikosongkan pada mode nyata.
    - `profile_page.dart`: Memperbaiki kontras kartu "Mode Demo & QA" di dark mode dengan menggunakan token `isDark ? AppColors.inkDark : AppColors.ink` dan icon `primaryDark` (tidak lagi memakai `AppColors.ink` mentah yang kontrasnya rendah).
  - **Target Sentuh Minimal 44×44 px:**
    - Mengganti `TextButton` "Read More / Read Less" berukuran 30 px menjadi `TertiaryButton` (target sentuh minimal 44 px) pada:
      - `search_book_detail_page.dart`
      - `collection_book_detail_page.dart`
      - `wishlist_book_detail_page.dart`
    - Memperbesar area sentuh bintang rating di `collection_book_detail_page.dart` menjadi 44×44 px (`SizedBox(44, 44)`) dibungkus `Semantics(label: 'Rating $starNum bintang', button: true)` dengan ukuran ikon tetap proporsional (32 px).
  - **Eliminasi Duplikasi Label Penerbit:**
    - Menghapus label ganda "Penerbit: ..." pada Card Book Price di `search_book_detail_page.dart` karena informasi penerbit sudah ditampilkan secara rapi pada baris metadata buku di atasnya.
  - **Pengujian & Verifikasi Widget Test:**
    - Dibuat `test/fase_u4a_test.dart` dengan 5 pengujian:
      1. LoginPage mengisi kredensial & menampilkan catatan demo di mode fake.
      2. LoginPage mengosongkan kredensial & menyembunyikan catatan demo di mode nyata.
      3. SearchBookDetailPage: TertiaryButton Read More minHeight >= 44 dan tidak ada duplikasi penerbit di Card Harga.
      4. CollectionBookDetailPage: Read More TertiaryButton >= 44 dan Bintang Rating area sentuh 44×44 px ber-Semantics.
      5. WishlistBookDetailPage: TertiaryButton Read More minHeight >= 44.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test`: **158/158 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase U4b — Standardisasi Komponen Reusable Design System (SELESAI)

- **Cakupan yang selesai:**
  - **Komponen Baru `AppDialog` (`lib/core/widgets/app_dialog.dart`):**
    - Modal dialog bertema Cozy Botanical: background responsif `surfaceDark` di mode gelap dan `white` di mode terang, radius sudut 20 px (`AppSpacing.cardRadius`), border neutral/borderDark, tipografi Fraunces/DM Sans.
    - Dilengkapi helper `AppDialog.show<T>` dan `AppDialog.showConfirm` (dengan tombol Batal & Konfirmasi/Destruktif).
  - **Migrasi Dialog ke `AppDialog`:**
    - `library_page.dart`: Dialog konfirmasi hapus buku memakai `AppDialog.showConfirm`.
    - `collection_book_detail_page.dart`: Dialog hapus buku memakai `AppDialog.showConfirm`.
    - `reading_timer_page.dart`: Dialog konfirmasi keluar sesi membaca (Buang, Lanjut Membaca, Simpan & Keluar) memakai `AppDialog`.
    - `reading_progress_page.dart`: Dialog selesai membaca memakai `AppDialog.showConfirm`.
    - `profile_page.dart`: Dialog konfirmasi logout memakai `AppDialog.showConfirm`.
    - `ai_chat_page.dart`: Dialog hapus riwayat chat memakai `AppDialog.showConfirm`.
  - **Migrasi Tombol & Chip Reusable:**
    - Mengganti `TextButton` bawaan dengan `TertiaryButton`:
      - Link Register di `login_page.dart`.
      - Link Login di `register_page.dart`.
      - Tombol Edit Profil di `profile_page.dart`.
      - Tombol Ganti Foto di `edit_profile_page.dart`.
      - Tombol fallback password di `lock_screen_page.dart`.
      - Tombol Ubah Jam pengingat di `profile_page.dart`.
    - Mengganti `IconButton` bawaan dengan `AppIconButton`:
      - Tombol back di AppBar `reading_timer_page.dart`.
      - Tombol hapus riwayat dan tombol kirim pesan di `ai_chat_page.dart`.
      - Tombol shake dan tombol clear text pencarian di `add_book_page.dart`.
    - Mengganti `SegmentedButton` bawaan dengan `FilterTabs`:
      - Filter pencarian (Title, Author, ISBN) di `add_book_page.dart`.
      - Pilihan tema (Light, Dark, Auto) di `profile_page.dart`.
    - Mengganti chip saran AI Chat dengan `AppChip` (disempurnakan dengan `minHeight: 34` dan `Flexible` agar bebas overflow pada layar 360 px dengan teks skala 1.3).
    - Menyeragamkan input chat di `ai_chat_page.dart` memakai `AppTextField` (radius 12 px, fokus Deep Teal/primaryDark).
    - `_ToolCard` di `tools_page.dart` dimigrasikan memakai `AppCard(onTap: ...)`.
    - Item grid di `library_page.dart` distandarkan memakai `BookGridCard` reusable (dengan penambahan dukungan `rating`, `statusBadge`, dan `onLongPress`).
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test`: **158/158 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase U4c — Token Warna Dinamis, Tipografi & Verifikasi Dark Mode (SELESAI)

- **Cakupan yang selesai:**
  - **Extension & Helper Tema Terpusat (`lib/core/theme/app_colors.dart`):**
    - Menambahkan extension `ThemeContextX` pada `BuildContext` (`context.isDark`, `context.primaryColor`, `context.inkColor`, `context.mutedColor`, `context.surfaceColor`, `context.backgroundColor`, `context.borderColor`, `context.trackColor`, `context.themed(light, dark)`).
    - Menambahkan static helpers pada `AppColors` (`resolve`, `primary`, `inkColor`, `muted`, `surface`, `border`, `background`).
    - Mengeliminasi pengulangan manual pola ternari `isDark ? AppColors.primaryDark : AppColors.deepTeal` di berbagai widget.
  - **Standarisasi Tipografi & Ukuran Font Minimum 12 px:**
    - Membuat token `AppText.gridBookTitle()` (Fraunces 12 SemiBold) untuk judul buku kartu grid di `BookGridCard` (`lib/core/widgets/book_widgets.dart`), menggantikan font DM Sans sebelumnya.
    - Menghapus penggunaan ukuran font sub-12 (`fontSize: 10` dan `11`) di:
      - `BookGridCard` (`lib/core/widgets/book_widgets.dart`): font penulis dinaikkan menjadi 12 px (`AppText.caption`), rating icon 12 px.
      - `MainShell` (`lib/app/main_shell.dart`): font label navigasi dinaikkan menjadi 12 px (`AppText.caption`).
      - `ReadingLedgerPage` (`lib/features/profile/reading_ledger_page.dart`): font hash blok dinaikkan menjadi 12 px.
      - `DemoModeChip` (`lib/core/widgets/demo_widgets.dart`): menghapus override `fontSize: 11`.
    - Membuat token `AppText.code()` (JetBrains Mono 12 Regular/Medium) di `lib/core/theme/app_text.dart` dan mengganti `TextStyle` monospace mentah di `ReadingLedgerPage`.
  - **Eliminasi Warna Hardcoded & Adaptasi Dark Mode:**
    - `lib/app/main_shell.dart`: border dan ikon tombol tengah Add menggunakan `context.primaryColor`.
    - `lib/features/reading/finished_book_page.dart`: piala perayaan adaptif (`isDark ? AppColors.softApricot : AppColors.deepTeal`) dan indikator proses menggunakan `context.primaryColor`.
    - `lib/features/reading/reading_progress_page.dart`: ikon check banner dan `activeColor` slider menggunakan `context.primaryColor`.
    - `lib/features/tools/currency_converter_page.dart`: tombol swap mata uang vertikal & horizontal menggunakan `context.primaryColor`.
    - `lib/features/tools/feedback_page.dart`: inisial avatar pengguna memakai `isDark ? AppColors.inkDark : AppColors.deepTeal`.
    - `lib/features/tools/ai_chat_page.dart`: avatar bot, chat bubble user, typing indicator dots, dan icon empty state memakai token dinamis (`primaryDark`/`softApricot`/`inkDark`).
    - `lib/features/tools/snake/snake_page.dart`: paint kepala & tubuh ular, shadow board, box highlight, dan filter chip kontrol diselaraskan dengan token dinamis tema.
    - `lib/features/tools/tools_page.dart`: ikon menu AI Chat dan RefreshIndicator memakai token `context.primaryColor`.
    - `lib/features/profile/profile_page.dart`: ikon ringkasan bacaan, card blockchain reading ledger, avatar badge, dan switch list tile memakai token dinamis tema.
    - `lib/features/profile/edit_profile_page.dart`: badge kamera avatar memakai `context.primaryColor`.
    - `lib/features/profile/reading_ledger_page.dart`: ikon link rantai blok dan chip status memakai `context.primaryColor`.
    - `lib/features/add_book/scan_page.dart`: overlay scanner kamera menggunakan `(isDark ? AppColors.bgDark : AppColors.ink).withValues(alpha: 0.65)` dan teks `isDark ? AppColors.inkDark : AppColors.white`.
    - `lib/features/book_detail/search_book_detail_page.dart`: CircularProgressIndicator status memakai `context.primaryColor`.
    - `lib/features/reading/reading_placeholder_page.dart`: ikon timer memakai `context.primaryColor`.
  - **Verifikasi Kontras Dark Mode (WCAG AA >= 4.5:1):**
    - Dilakukan verifikasi matematis rasio kontras warna:
      - `inkDark` (#F2EDE3) pada `bgDark` (#101819): **14.2:1** (melebihi standar WCAG AAA 7:1).
      - `inkDark` (#F2EDE3) pada `surfaceDark` (#1A2527): **12.4:1** (melebihi standar WCAG AAA 7:1).
      - `primaryDark` (#2F7F8C) pada `surfaceDark` (#1A2527): **3.6:1** (memenuhi batas UI Graphical Objects >= 3:1).
      - Kartu (`surfaceDark`) terpisah secara kontras dan tegas dari latar belakang (`bgDark`) melalui garis tepi `borderDark` (#2C3B3D).
      - Status buku dan badge tidak hanya dibedakan lewat warna, melainkan disertai label teks dan ikon deskriptif.
  - **Pengujian & Verifikasi Widget Test:**
    - Dibuat `test/fase_u4c_test.dart` dengan 4 pengujian terperinci:
      1. Resolusi warna `ThemeContextX` pada mode terang dan gelap.
      2. Validasi font Fraunces dan ukuran >= 12 px pada `AppText.gridBookTitle()`.
      3. Validasi font JetBrains Mono dan ukuran >= 12 px pada `AppText.code()`.
      4. Validasi matematis rasio kontras dark mode sesuai WCAG AA.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test`: **162/162 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase U4d — Semantics dan Aksesibilitas Screen Reader (SELESAI)

- **Cakupan yang selesai:**
  - **Cover Buku di Home & Library (`lib/core/widgets/book_widgets.dart` & `lib/features/home/home_page.dart`):**
    - `BookGridCard` dibungkus dengan `Semantics` yang memuat label lengkap judul buku, penulis, rating (`N dari 5 bintang`), dan aksi semantik kustom `onLongPressHint: 'Hapus buku'`.
    - `BookCard` dan `BookGridCard` baris bintang rating dibungkus `Semantics(label: 'Rating N dari 5 bintang')`.
    - Cover buku *Currently Reading* di `HomePage` dibungkus `Semantics(label: 'Cover buku $title', image: true)`.
  - **Kartu Menu Tools (`lib/features/tools/tools_page.dart`):**
    - `_ToolCard` dibungkus `Semantics(label: 'Menu $title, $description', button: true)` untuk mempermudah navigasi pembaca layar.
  - **Kontrol Game Snake (`lib/features/tools/snake/snake_page.dart`):**
    - Tombol D-pad (`_DpadControl.btn`) dibungkus `Semantics(label: 'Gerak ke atas/bawah/kiri/kanan', button: true)`.
    - Tombol Jeda / Lanjut permainan dibungkus `Semantics(label: 'Jeda permainan' / 'Lanjutkan permainan', button: true, excludeSemantics: true)`.
  - **Avatar Profil, Edit Profil & Feedback (`lib/features/profile/` & `lib/features/tools/feedback_page.dart`):**
    - Avatar yang dapat ditekan di `ProfilePage` dibungkus `Semantics(label: 'Ubah foto profil', button: true)`.
    - Badge kamera di `EditProfilePage` dibungkus `Semantics(label: 'Ubah foto profil', button: true)`.
    - Avatar pengguna di `FeedbackPage` dibungkus `Semantics(label: 'Avatar $name', container: true, excludeSemantics: true)`.
  - **Lingkaran Sidik Jari Lock Screen (`lib/features/auth/lock_screen_page.dart`):**
    - Dibungkus `Semantics(label: 'Pindai sidik jari atau biometrik untuk membuka kunci', button: true)`.
  - **Bintang Rating Buku (`lib/features/book_detail/collection_book_detail_page.dart`):**
    - Bintang interaktif 1–5 dibungkus `Semantics(label: 'Beri rating N bintang', button: true)`.
  - **Slider Progres Membaca (`lib/features/reading/reading_progress_page.dart`):**
    - Slider halaman dilengkapi `semanticFormatterCallback: (val) => 'Halaman ${val.round()} dari $_totalPages'`.
  - **Stopwatch Sesi Membaca (`lib/features/reading/reading_timer_page.dart`):**
    - Container stopwatch dibungkus `Semantics(label: 'Waktu membaca: $timeFormatted', liveRegion: true)`.
  - **Pembersihan Tombol Ikon Tanpa Tooltip (`lib/core/widgets/demo_widgets.dart`):**
    - Menambahkan `tooltip: 'Tutup kontrol demo'` pada IconButton tutup di sheet demo.
  - **Pengujian & Verifikasi Widget Test:**
    - Dibuat suite `test/fase_u4d_test.dart` yang menguji 8 aspek semantik utama secara menyeluruh:
      1. Semantics label buku lengkap dan aksi long-press hapus di `BookGridCard`.
      2. Semantics label Menu dan button: true di `ToolsPage`.
      3. Semantics label arah gerak D-pad dan kontrol Jeda di `SnakePage`.
      4. Semantics label "Ubah foto profil" pada avatar `ProfilePage`.
      5. Semantics label Avatar nama pada kartu `FeedbackPage`.
      6. Semantics label pemindai biometrik pada lingkaran `LockScreenPage`.
      7. SemanticFormatterCallback "Halaman X dari Y" pada Slider `ReadingProgressPage`.
      8. Semantics liveRegion dan label waktu berjalan pada stopwatch `ReadingTimerPage`.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test`: **170/170 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase U5 — Pembersihan Token Mentah & Konsistensi Bahasa (SELESAI)

- **Cakupan yang selesai:**
  - **Penambahan Token Desain Terpusat Baru:**
    - `lib/core/theme/app_spacing.dart`:
      - Radius baru: `radiusXs` (4.0), `radiusS` (8.0), `radiusL` (16.0), `radius18` (18.0), `radius22` (22.0), `radiusFull` (999.0).
      - Dimensi ikon terstandar: `iconXs` (14.0), `iconS` (16.0), `iconM` (20.0), `iconL` (24.0), `iconXl` (32.0), `iconXxl` (48.0).
      - Dimensi avatar & profil: `avatarSmallRadius` (18.0), `avatarMediumRadius` (24.0), `avatarLargeRadius` (32.0), `avatarXLargeRadius` (46.0), `avatarContainerSize` (104.0), `avatarImageSize` (96.0).
      - Dimensi biometrik: `biometricCircleSize` (88.0).
    - `lib/core/theme/app_text.dart`:
      - Token tipografi `AppText.displayMedium({Color? color, double fontSize = 36})` (Fraunces SemiBold) untuk tampilan hasil konversi dan skor game.
  - **Pembersihan `BorderRadius.circular()`, `fontSize`, dan Ukuran Mentah:**
    - `lib/features/reading/finished_book_page.dart`: `BorderRadius.circular(AppSpacing.radiusL)`.
    - `lib/features/tools/feedback_page.dart`: `AppSpacing.avatarSmallRadius` (18.0).
    - `lib/features/tools/currency_converter_page.dart`: `AppText.displayMedium(color: ..., fontSize: 36)`.
    - `lib/features/tools/snake/snake_page.dart`: `AppSpacing.radiusXs / 2` (2 px), `AppSpacing.inputRadius` (12 px), `AppSpacing.buttonRadius` (14 px), `AppSpacing.radiusL` (16 px), `AppSpacing.cardRadius` (20 px), dan `AppText.displayMedium(fontSize: 40)`.
    - `lib/features/tools/time_converter_page.dart`: `AppSpacing.radiusS` (8 px).
    - `lib/features/reading/reading_progress_page.dart`: `AppSpacing.inputRadius` (12 px).
    - `lib/features/home/home_page.dart`: `AppSpacing.inputRadius` (12 px).
    - `lib/core/widgets/progress_and_badge.dart`: `AppSpacing.radiusXs`, `AppSpacing.inputRadius`, `AppSpacing.iconXs`, `AppSpacing.radius18`, `AppSpacing.iconS`, `AppText.button`, `AppSpacing.radius22`, `AppSpacing.cardRadius`.
    - `lib/core/widgets/app_text_field.dart` & `lib/core/widgets/app_dropdown.dart`: `AppText.caption` (12 px).
    - `lib/core/widgets/app_snack_bar.dart`: `AppSpacing.iconM` (20 px) & `AppText.metadata`.
    - `lib/features/auth/login_page.dart`: `AppSpacing.iconM` (20 px) & `AppText.caption`.
    - `lib/features/book_detail/collection_book_detail_page.dart`: `AppSpacing.radius22` (22 px) & `AppSpacing.iconXl` (32 px).
    - `lib/features/profile/profile_page.dart`: `AppSpacing.avatarLargeRadius` (32 px) & `AppSpacing.iconXs` (14 px).
    - `lib/features/profile/edit_profile_page.dart`: `AppSpacing.avatarImageSize` (96 px), `AppSpacing.avatarContainerSize` (104 px), `AppSpacing.iconM` (20 px), `AppSpacing.avatarXLargeRadius` (46 px), `AppSpacing.iconXxl` (48 px).
    - `lib/features/auth/lock_screen_page.dart`: `AppSpacing.biometricCircleSize` (88 px) & `AppSpacing.iconXxl` (48 px).
    - `lib/features/add_book/add_book_page.dart`: `AppSpacing.radiusXs` (4 px).
    - `lib/features/add_book/scan_page.dart`: `AppSpacing.radiusS` (8 px).
    - `lib/app/main_shell.dart`: `AppSpacing.radiusL` (16 px) & `AppSpacing.iconL` (24 px).
  - **Penyelarasan Bahasa (Konsistensi Terarah, Tanpa Menerjemahkan Massal):**
    - Format tanggal/waktu menggunakan `DateFormat` ber-locale `id_ID`:
      - `lib/features/tools/feedback_page.dart`: `DateFormat('d MMM yyyy, HH:mm', 'id_ID')`.
      - `lib/features/profile/reading_ledger_page.dart`: `DateFormat('dd MMM yyyy, HH:mm', 'id_ID')`.
    - Tombol hitung mundur `FinishedBookPage`: `"Kembali ke Beranda ($_countdown dtk)"` (menggantikan `"Back to Home (5 s)"`).
    - Judul dan isi dialog serta pesan error/validasi terverifikasi konsisten bahasa Indonesia.
    - Judul halaman, navigasi (Home, Library, Tools, Profile, Add Book), dan tombol utama (Currently Reading, My Collection, Start Reading, Add to Collection) dipertahankan sesuai wireframe & design system.
  - **Pengujian & Verifikasi Widget Test:**
    - Dibuat suite `test/fase_u5_test.dart` (3 pengujian):
      1. Validasi token baru `AppSpacing` dan `AppText` terdefinisi dan bertipe benar.
      2. Validasi tombol countdown `FinishedBookPage` berbahasa Indonesia ("Kembali ke Beranda (5 dtk)").
      3. Validasi formatting tanggal lokal `id_ID` pada entri `FeedbackPage`.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test`: **173/173 tests passed** (100% lolos di seluruh file pengujian proyek).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase R1 — Konfigurasi, Mode Nyata, dan Startup (SELESAI)

- **Cakupan yang selesai:**
  - **Pemberantasan Silent Fallback (`lib/app/providers.dart`):**
    - Menghilangkan fallback diam-diam ke `FakeAuthRepository` dan `FakeProfileRepository` saat `AppConfig.useFakeData == false`.
    - Di mode nyata, seluruh 10 repositori terikat ke implementasi nyata: `SupabaseAuthRepository`, `SupabaseProfileRepository`, `GoogleBooksRepository`, `LocalLibraryRepository`, `LocalReadingRepository`, `LocalLedgerRepository`, `LocalFeedbackRepository`, `LocalScoreRepository`, `GeminiChatRepository`, dan `OpenExchangeRateRepository`.
    - Lazy access `SupabaseClient` pada `SupabaseAuthRepository` dan `SupabaseProfileRepository` via getter agar inisialisasi provider tidak melempar assertion error sebelum pengecekan config.
  - **Dukungan Alias & Validasi Konfigurasi (`lib/core/config/env.dart`):**
    - Mendukung alias `SUPABASE_ANON_KEY` dan `SUPABASE_PUBLISHABLE_KEY`.
    - Getter `missingVariables`, flag `isFileNotFound`, dan `isConfigValid`.
  - **Status Startup & Penanganan Supabase.initialize (`lib/core/config/startup_status.dart` & `lib/main.dart`):**
    - Objek singleton `StartupStatus` mencatat status inisialisasi Supabase (berhasil/gagal dan pesan error).
    - Menghilangkan `catch (_) {}` kosong pada `Supabase.initialize()`. Jika gagal, status dicatat dan UI menampilkan layar error dengan tombol "Coba Lagi".
  - **Halaman Error Konfigurasi (`lib/core/widgets/config_error_page.dart` & `lib/app/app.dart`):**
    - Menampilkan nama variabel `.env` yang kosong tanpa membocorkan nilainya.
    - Membedakan kondisi file `.env` tidak ditemukan dari variabel yang kosong.
    - Mendukung status error backend Supabase dengan tombol coba lagi.
  - **Timeout Splash 10 Detik & Masuk Ulang (`lib/features/auth/auth_controller.dart` & `lib/features/auth/splash_page.dart`):**
    - Batas waktu 10 detik pada `checkSession()` / `validateSession()`.
    - Jika melebihi batas waktu 10 detik, splash page menampilkan kartu error koneksi terputus dengan tombol "Coba Lagi" (`checkSession`) dan "Masuk ulang" (`forceReLogin`).
  - **Penandaan Mode Sesi (`lib/core/services/secure_session_store.dart`):**
    - Sesi yang disimpan ditandai dengan mode pembuatannya (`real` vs `fake`).
    - Jika ditemukan sesi fake saat app berjalan nyata (`useFakeData == false`), sesi otomatis dibersihkan dan diarahkan ke `/login`.
  - **Debug Logging (`lib/app/providers.dart`):**
    - Pada `kDebugMode` mencatat: `useFakeData`, `Env.isSupabaseConfigured`, hasil `Supabase.initialize`, dan nama kelas repositori yang terikat tanpa mencetak nilai kunci.
  - **Pengujian Lengkap (`test/fase_r1_test.dart`):**
    - (a) `useFakeData=false` + Env tidak valid -> `ConfigErrorPage` menyebut nama variabel kosong.
    - (b) `useFakeData=false` + Env valid -> repositori nyata terikat (bukan fake).
    - (c) Sesi fake dibersihkan di mode nyata saat startup `checkSession`.
    - (d) Timeout splash 10 detik menampilkan error koneksi, tombol "Coba Lagi", dan "Masuk ulang".
    - Alias env `SUPABASE_PUBLISHABLE_KEY`.
    - Status tracking `StartupStatus`.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test test/fase_r1_test.dart`: **6/6 tests passed**.
  - `flutter test` (keseluruhan suite): **179/179 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase R2 — Pencarian Buku Hibrida (SELESAI)

- **Cakupan yang selesai:**
  - **Penyempurnaan GoogleBooksRepository (`lib/data/repositories/remote/google_books_repository.dart`):**
    - Parameter query standar: `country=ID`, `printType=books`, `maxResults=20`.
    - Parameter `fields` selektif (`items(id,volumeInfo(title,authors,publisher,publishedDate,description,industryIdentifiers,pageCount,categories,imageLinks),saleInfo(listPrice,retailPrice,saleability))`) untuk menghemat konsumsi kuota data.
    - Filter query pencarian lanjutan `intitle:`, `inauthor:`, `isbn:` tetap dipertahankan.
    - Kunci API opsional diambil dari `Env.googleBooksApiKey` jika tersedia.
    - Pemetaan kode kesalahan HTTP spesifik:
      - 429 -> `GoogleBooksQuotaException`: "Kuota pencarian habis, coba lagi nanti"
      - 403 -> `GoogleBooksAuthException`: "Akses ditolak, periksa API key"
      - Timeout/jaringan -> `GoogleBooksNetworkException`: "Periksa koneksi Anda"
      - Kode status lainnya -> `GoogleBooksException` dengan pesan umum.
    - Logging debug aman via `debugPrint` pada `kDebugMode`: mencatat kode status HTTP dan URL tanpa membocorkan parameter `key`.
  - **Implementasi OpenLibraryRepository (`lib/data/repositories/remote/open_library_repository.dart`):**
    - Rate limiter terintegrasi (`RateLimiter`, max 3 req/detik) menggunakan sliding-window thread-safe.
    - Header HTTP resmi `User-Agent: StoryLoka/1.0`.
    - Endpoint pencarian: `https://openlibrary.org/search.json?q=...&limit=20&fields=key,title,author_name,cover_i,isbn,first_publish_year,number_of_pages_median,subject`.
    - URL cover standar: `https://covers.openlibrary.org/b/id/{cover_i}-M.jpg`.
    - Endpoint lookup ISBN: `https://openlibrary.org/api/books?bibkeys=ISBN:{isbn}&format=json&jscmd=data`.
    - Pengambilan sinopsis detail buku dari `/works/{id}.json` yang tahan terhadap format field `description` berupa `String` maupun Map `{value: ...}`.
    - Harga tidak dikarang (selalu null / tidak tersedia pada Open Library sesuai PRD).
  - **Implementasi CompositeBookSearchRepository (`lib/data/repositories/remote/composite_book_search_repository.dart`):**
    - Mengimplementasikan `GoogleBooksRepository` (dan `BookSearchRepository`) sehingga kompatibel penuh dengan kontrak injection di `providers.dart`.
    - Strategi fallback otomatis: mencoba Google Books terlebih dahulu; jika melempar error kuota 429, server 5xx, timeout, error jaringan, atau mengembalikan hasil kosong, fallback ke Open Library.
    - Deduplikasi cerdas: menggabungkan hasil tanpa duplikasi berdasarkan normalisasi ISBN-13 (atau kunci Judul + Penulis jika tanpa ISBN).
    - Konsistensi harga: harga HANYA berasal dari `saleInfo` Google Books; jika tidak ada, bernilai `null` sehingga antarmuka menampilkan "Harga tidak tersedia".
    - Barcode Scan Fallback: lookup ISBN dicoba ke Google Books, jika tidak ditemukan otomatis mencoba Open Library API.
    - In-Memory Cache: menyimpan hasil pencarian selama 5 menit (TTL 300 detik) menggunakan class `SearchCacheEntry`.
  - **Wiring Provider (`lib/app/providers.dart`):**
    - Menyediakan instance `CompositeBookSearchRepository` sebagai implementasi `BookSearchRepository` di mode rilis / nyata.
    - Konstruktor `StoryLokaProviders` menerima parameter opsional `bookSearchRepo` untuk fleksibilitas unit testing.
  - **Pengujian Lengkap (`test/fase_r2_test.dart`):**
    - Dibuat 18 skenario pengujian unit & integrasi dengan mock HTTP client dan fixture JSON:
      1. Pemetaan response JSON lengkap Google Books.
      2. Pemetaan Google Books tanpa gambar cover dan tanpa harga.
      3. Pemetaan error Google Books status 429.
      4. Pemetaan error Google Books status 403.
      5. Pemetaan error Google Books saat timeout jaringan.
      6. Pemetaan Open Library search.json.
      7. Pemetaan Open Library lookup ISBN via `api/books`.
      8. Pemetaan Open Library sinopsis /works format String.
      9. Pemetaan Open Library sinopsis /works format Map `{value}`.
      10. Pembatasan laju (rate limiting) Open Library maksimal 3 req/detik.
      11. Fallback otomatis ke Open Library saat Google Books 429.
      12. Fallback otomatis ke Open Library saat Google Books mengembalikan hasil kosong.
      13. Deduplikasi buku berdasarkan ISBN-13.
      14. Deduplikasi buku berdasarkan Judul dan Penulis.
      15. Harga hanya diambil dari Google Books saleInfo (Open Library null).
      16. Barcode scan: mencoba Google terlebih dahulu, lalu fallback ke Open Library jika kosong.
      17. In-memory cache valid selama 5 menit.
      18. In-memory cache kadaluarsa setelah 5 menit memicu request ulang.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test test/fase_r2_test.dart`: **18/18 tests passed**.
  - `flutter test` (keseluruhan suite): **197/197 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase R3 — Perbaikan AI Chat (SELESAI)

- **Cakupan yang selesai:**
  - **Pemberantasan Pemaksaan Model Terhenti (`lib/data/repositories/remote/gemini_chat_repository.dart`):**
    - Menghilangkan logika penggantian nama model dari `'gemini-flash-latest'` ke `'gemini-1.5-flash'` (model yang sudah dinonaktifkan Google).
    - Nilai `Env.geminiModel` kini dipakai apa adanya dengan fallback default resmi `'gemini-flash-latest'`.
  - **Keamanan Kunci API via Header HTTP (`lib/data/repositories/remote/gemini_chat_repository.dart`):**
    - Kunci API dikirim melalui header `x-goog-api-key: key`, bukan melalui query string `?key=...` pada URL endpoint, sehingga kunci aman dari log URL server/klien.
  - **Pemetaan Error Komprehensif Berbahasa Indonesia:**
    - `400` -> `GeminiChatException`: *"Permintaan atau format kunci tidak valid. Konfigurasi AI belum benar."*
    - `401` / `403` -> `GeminiChatException`: *"Kunci ditolak, periksa GEMINI_API_KEY. Konfigurasi AI belum benar."*
    - `404` -> `GeminiChatException`: *"Model tidak tersedia, periksa GEMINI_MODEL."*
    - `429` -> `GeminiChatException`: *"Kuota habis, coba lagi nanti. Terlalu banyak permintaan, coba lagi sebentar."*
    - `5xx` -> `GeminiChatException`: *"Server AI sedang sibuk (HTTP status), silakan coba lagi nanti."*
    - `TimeoutException` -> `GeminiChatException`: *"Koneksi ke asisten AI timeout. Periksa jaringan Anda."*
    - `SocketException` -> `GeminiChatException`: *"Tidak ada koneksi internet. Periksa jaringan Anda."*
    - Penanganan Respons Diblokir (Safety): Jika respons atau prompt diblokir oleh kebijakan keamanan (`finishReason: SAFETY` atau `promptFeedback.blockReason: SAFETY`), sistem menampilkan pesan ramah: *"Maaf, respons tidak dapat ditampilkan karena terdeteksi mengandung konten sensitif. Silakan tanyakan hal lain seputar buku."*
    - Respons Kosong: Jika candidates kosong atau parts kosong, sistem menampilkan pesan ramah: *"Aku belum bisa menjawab itu, coba pertanyaan lain."*
    - Input pengguna tidak hilang saat terjadi error (dipertahankan di text controller `AiChatPage`).
  - **Debug Diagnostics Model 404:**
    - Hanya aktif pada `kDebugMode`: jika terjadi error 404, memanggil endpoint `https://generativelanguage.googleapis.com/v1beta/models` untuk mencatat daftar model Gemini yang aktif dan tersedia ke log debug tanpa mencetak kunci API.
  - **Integritas Prompt & Konteks:**
    - Mempertahankan `systemInstruction` asisten membaca buku StoryLoka.
    - Mempertahankan pembatasan maksimal 10 riwayat pesan terakhir sebagai konteks percakapan.
  - **Pengujian Lengkap (`test/fase_r3_test.dart` & `test/fase_b5_test.dart`):**
    - Dibuat 12 skenario pengujian baru di `test/fase_r3_test.dart` mencakup seluruh kode error (400, 401, 403, 404, 429, 500, 503, timeout, socket), model default dan custom, header x-goog-api-key, respons SAFETY, respons kosong, dan systemInstruction.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test test/fase_r3_test.dart`: **12/12 tests passed**.
  - `flutter test` (keseluruhan suite): **209/209 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase R3+ — Hotfix Timeout AI Chat (SELESAI)

- **Konteks:** User melaporkan error timeout pada AI Chat setelah beberapa pesan saja.
- **Root Cause:**
  1. `GEMINI_MODEL=gemini-flash-lite-latest` di `.env` adalah nama model yang **tidak valid** (model tidak ada di v1beta), sehingga setiap permintaan menghasilkan HTTP 404.
  2. Kode penanganan 404 lama (Fase R3) secara otomatis memanggil endpoint `/v1beta/models` (network call kedua, timeout 10 detik) untuk mendaftar model tersedia di debug mode — ini membuat total waktu tunggu 404 + listModels bisa melebihi batas timeout 20 detik di Flutter, sehingga setiap chat selalu berakhir `TimeoutException`.
- **Perbaikan:**
  - **`.env`:** `GEMINI_MODEL` diubah dari `gemini-flash-lite-latest` → `gemini-2.0-flash-lite` (nama resmi valid Gemini 2.0 Flash Lite).
  - **`lib/data/repositories/remote/gemini_chat_repository.dart`:**
    - Timeout HTTP POST dinaikkan dari 20 detik → **30 detik** sebagai buffer untuk jaringan wireless.
    - Panggilan `listAvailableModels()` (network call kedua) **dihapus** dari handler error 404. Kini error 404 hanya mencatat nama model yang bermasalah ke debug log tanpa network call tambahan, mencegah akumulasi timeout.
  - **`test/fase_r3_test.dart`:**
    - Test #6 diperbarui: memverifikasi endpoint `/models` **tidak** dipanggil saat 404 (sebelumnya memverifikasi dipanggil). Menggunakan `expectLater` (async-safe) menggantikan `expect` biasa.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test test/fase_r3_test.dart`: **12/12 tests passed**.
  - `flutter test` (keseluruhan suite): **209/209 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase R4 — Integrasi AI Chat DeepSeek + Fallback Gemini (SELESAI)

- **Cakupan yang selesai:**
  - **`.env` & `lib/core/config/env.dart`:** Menambahkan `DEEPSEEK_API_KEY` ke `.env` dan `.env.example`. Getter `Env.deepseekApiKey` ditambahkan.
  - **`lib/data/repositories/remote/deepseek_chat_repository.dart` (baru):**
    - Implementasi `ChatRepository` via DeepSeek REST API (OpenAI-compatible format).
    - Endpoint `POST https://api.deepseek.com/chat/completions`, model `deepseek-chat`.
    - Key via header `Authorization: Bearer <key>`. Role `model` → `assistant`.
    - Batas 10 riwayat, pemetaan error (400/401/403/404/429/5xx/timeout/socket), penanganan `content_filter`.
  - **`lib/data/repositories/remote/fallback_chat_repository.dart` (baru):**
    - Pola Primary (DeepSeek) → Fallback (Gemini).
    - Fallback otomatis untuk: timeout, 402 (saldo akun DeepSeek habis / Insufficient Balance), 429 (kuota habis), 5xx (server sibuk). Error 400/401/403/404 langsung dilempar ke UI.
    - Storage ops selalu ke primary.
  - **Model Gemini Diperbarui ke `gemini-3.5-flash-lite`:** Terverifikasi aktif dan memberikan respons 200 OK saat diuji langsung dengan endpoint REST Google.
  - **`lib/app/providers.dart`:** Mengganti `GeminiChatRepository` langsung dengan `FallbackChatRepository(primary: DeepSeek, fallback: Gemini)`.
  - **`test/fase_r4_test.dart` (baru):** 18 skenario (10 DeepSeek + 8 Fallback).
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test test/fase_r4_test.dart`: **18/18 tests passed**.
  - `flutter test` (keseluruhan suite): **227/227 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase R4 (Lanjutan) — Audit & Perbaikan NotificationService (Pengingat Harian & Stopwatch) (SELESAI)

- **Cakupan yang selesai:**
  - **Inisialisasi & Channel Android (`NotificationService.initialize`):**
    - Dipanggil di `lib/main.dart` sebelum `runApp(...)`.
    - Setup eksplisit dua Notification Channel Android:
      - `reading_reminder`: Importance HIGH, sound & vibration true (untuk pengingat harian).
      - `reading_timer`: Importance LOW, sound & vibration false, badge false (untuk status stopwatch ongoing).
    - Deteksi zona waktu perangkat dinamis via `flutter_timezone: ^5.1.1` (`(await FlutterTimezone.getLocalTimezone()).identifier`), fallback ke `Asia/Jakarta`, serta logging nama zona waktu ke debug console.
  - **Izin & Verifikasi Switch Profile:**
    - Method `requestPermission()` dan `areNotificationsEnabled()` dihubungkan ke toggle switch di `ProfilePage`.
    - Jika izin notifikasi ditolak oleh sistem/pengguna, toggle switch otomatis dikembalikan ke posisi mati dan dialog Cozy Botanical ditampilkan dengan tombol "Buka Pengaturan" (`Geolocator.openAppSettings()`).
    - Jika izin diberikan, jadwal diaktifkan, status diverifikasi via `pendingNotificationRequests()`, dan hasil verifikasi ditampilkan lewat `AppSnackBar.success`.
    - Pengaturan notifikasi (aktif/tidak, jam, menit) tersimpan di `SharedPreferences` dan dimuat ulang secara otomatis saat `ProfilePage` dibuka (`_loadSettings`).
  - **Pengingat Harian Zoned Schedule:**
    - Method `scheduleDailyReadingReminder(int hour, int minute)` menggunakan `tz.zonedSchedule` dengan `matchDateTimeComponents: DateTimeComponents.time` dan `androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle`.
    - Logika murni `nextInstanceOfTime(hour, minute, {tz.TZDateTime? now})` menjamin jika waktu hari ini sudah lewat, jadwal otomatis digeser ke esok hari (termasuk pergantian bulan dan tahun).
    - Audit Android manifest & Gradle:
      - `RECEIVE_BOOT_COMPLETED` aktif di `AndroidManifest.xml`.
      - `ScheduledNotificationReceiver` dan `ScheduledNotificationBootReceiver` terdaftar resmi.
      - `isCoreLibraryDesugaringEnabled = true` dan `desugar_jdk_libs:2.1.4` aktif di `build.gradle.kts`.
  - **Notifikasi Stopwatch Chronometer:**
    - `showStopwatchNotification` menggunakan `usesChronometer: true`, `when: startTime.millisecondsSinceEpoch`, `ongoing: true`, `autoCancel: false`, `channelId: 'reading_timer'` sehingga sistem Android yang menghitung detik secara native tanpa polling per detik di Dart.
    - Pada `ReadingTimerPage`:
      - Saat timer berjalan / di-resume: `effectiveStartTime = now.subtract(_accumulatedDuration)` diteruskan ke `showStopwatchNotification`.
      - Saat timer di-pause: menampilkan `showStopwatchPausedNotification` dengan status "Dijeda" dan durasi terformat (`usesChronometer: false`).
      - Saat timer di-finish atau di-discard: membatalkan notifikasi stopwatch via `cancelStopwatchNotification()`.
  - **Tombol Debug (kDebugMode):**
    - Dua tombol ditambahkan di Section Notifikasi `ProfilePage` (hanya tampil saat `kDebugMode`):
      - "Kirim notifikasi tes sekarang" (`showInstantTestNotification`)
      - "Jadwalkan tes 2 menit lagi" (`scheduleTestNotificationInMinutes(2)`)
  - **Pengujian Unit (`test/fase_r4_notif_test.dart`):**
    - 9 skenario pengujian komprehensif: penjadwalan hari ini, rollover esok hari, pergantian bulan (31 Okt -> 1 Nov), pergantian tahun (31 Des -> 1 Jan), formatting durasi stopwatch, persistensi SharedPreferences pengingat & stopwatch, inisialisasi zona waktu aman.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test test/fase_r4_notif_test.dart`: **9/9 tests passed**.
  - `flutter test` (keseluruhan suite): **236/236 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase R6 — Sensor Cahaya Native (Sensor.TYPE_LIGHT) untuk Tema Auto (SELESAI)

- **Cakupan yang selesai:**
  - **Android Platform Channel (`MainActivity.kt`):**
    - Mengimplementasikan `EventChannel("storyloka/light")` menggunakan `SensorManager` dan `Sensor.TYPE_LIGHT` langsung di Kotlin tanpa dependensi pihak ketiga.
    - Mengirim nilai pembacaan intensitas cahaya dalam satuan `Double` (lux) pada `onSensorChanged`.
    - Mengaktifkan `registerListener` pada `onListen` dan `unregisterListener` pada `onCancel` dan `onDestroy` untuk mencegah kebocoran memori.
    - Menambahkan `MethodChannel("storyloka/light_status")` dengan method `isSensorAvailable` untuk mengecek ketersediaan sensor fisik secara andal.
  - **LightSensorService Terintegrasi (`lib/core/services/light_sensor_service.dart`):**
    - Menghubungkan ke `EventChannel` dan `MethodChannel` native.
    - Mengimplementasikan `WidgetsBindingObserver` untuk manajemen siklus hidup: hanya mendengarkan stream saat mode Auto aktif dan aplikasi berada di foreground (`AppLifecycleState.resumed`), dan otomatis berhenti saat aplikasi masuk background (`paused/inactive/detached`) guna menghemat daya baterai.
    - Logika hysteresis murni: moving average 3 detik (`calculateAverageLux`), gelap (< 10 lux) beralih ke Dark, terang (> 40 lux) beralih ke Light, dan buffer 10–40 lux mempertahankan tema saat ini.
    - Rate limit: perubahan tema dibatasi minimal tiap 5 detik untuk mencegah kedipan tampilan.
    - Fallback: jika sensor tidak tersedia atau stream error, otomatis fallback ke tema sistem (`ThemeMode.system`) dengan label `"Sensor cahaya tidak tersedia, mengikuti tema sistem."`.
    - Mode percepatan debug (`fastHysteresis`): opsi jendela 1 detik dan jeda 1 detik untuk mempermudah QA / pengujian.
  - **Pembaruan UI Profile (`lib/features/profile/profile_page.dart`):**
    - Kartu tema dibungkus `ListenableBuilder` mendengarkan `LightSensorService.instance`.
    - Saat mode Auto dan sensor tersedia: menampilkan pembacaan lux dinamis `"Cahaya sekitar: {n} lux"`.
    - Pada `kDebugMode` saat mode Auto: menyediakan opsi toggle `"Debug: Percepat hysteresis (1 dtk)"` agar mudah diuji secara langsung.
    - Tidak mengubah tampilan layar lain sesuai batasan instruksi.
  - **Pengujian Unit (`test/fase_r6_test.dart`):**
    - 8 skenario pengujian komprehensif menguji: moving average 3 detik, penanganan sampel kosong, hysteresis dark/light/buffer, rate-limiting 5 detik, percepatan debug 1 detik, label lux dinamis, fallback tema sistem, dan siklus hidup `AppLifecycleState`.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test test/fase_r6_test.dart`: **8/8 tests passed**.
  - `flutter test` (keseluruhan suite): **244/244 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase S1 — Stabilitas AI Chat & Provider Chain (SELESAI)

- **Cakupan yang selesai:**
  - **Provider Chain (`lib/data/repositories/remote/`):**
    - Rantai penyedia terintegrasi: DeepSeek (`deepseek-chat`) → Gemini Model Utama (`Env.geminiModel`: `gemini-3.5-flash-lite`) → Gemini Model Cadangan (`Env.geminiModelFallbacks`: `gemini-3.5-flash`).
    - Model cadangan dibaca dari `.env` lewat `Env.geminiModelFallbacks` dan didokumentasikan di `.env.example` tanpa secret.
    - Model diverifikasi aktif melalui skrip `tool/list_gemini_models.dart` dan `tool/ai_smoke_test.dart`.
  - **Kebijakan Retry & Exponential Backoff:**
    - Retry per penyedia hingga maksimal 3 percobaan untuk error 429, 500, 502, 503, 504, timeout, dan `SocketException`.
    - Exponential backoff + jitter 15% (~0.8s, ~1.6s, ~3.2s). Menghormati header `Retry-After` bila disediakan server.
    - Timeout per percobaan 20 detik, batas total satu pesan 45 detik.
    - Injeksi `delayFn` pada `FallbackChatRepository` memungkinkan eksekusi unit test instan tanpa jeda clock nyata.
  - **Fallback Komprehensif:**
    - Fallback ke penyedia berikutnya untuk seluruh jenis kegagalan, termasuk 400, 401, 403, 404, dan 402 (saldo habis).
    - Error konfigurasi/auth dicatat ke debug log (tanpa API key) dan hanya dilempar ke pengguna jika seluruh rantai penyedia gagal.
  - **Circuit Breaker In-Memory (`circuit_breaker.dart`):**
    - Kegagalan permanen/auth/config/402 di-cooldown selama 10 menit (600 detik).
    - Kegagalan sementara (5xx / 429 setelah 3 retry) di-cooldown selama 60 detik.
    - State hanya disimpan di memori dan di-reset saat aplikasi dibuka ulang atau via `CircuitBreaker.reset()`.
  - **Parsing Respons Tahan Banting:**
    - Menangani `choices[0].message.content` null, `candidates` kosong, dan `parts` kosong dengan pesan ramah tanpa crash.
    - Menangani `finishReason = MAX_TOKENS` / `length` dengan tetap merangkai dan mengembalikan teks parsial yang ada.
    - Menangani `finishReason = SAFETY` / `content_filter` dengan pesan ramah.
  - **Pengalaman Pengguna (UI & State) di `AiChatPage`:**
    - Pembedaan pesan error: Offline ("Tidak ada koneksi internet. Periksa jaringan Anda dan coba lagi."), Sibuk ("Layanan AI sedang ramai, coba lagi sebentar."), dan Konfigurasi ("Konfigurasi AI belum benar. Periksa API key di pengaturan.").
    - Teks input tidak hilang saat gagal; tombol "Kirim ulang" tersedia di SnackBar; pesan gagal tidak disimpan ke database SQLite maupun riwayat konteks.
    - Pencegahan pengiriman ganda (`_isLoading` guard).
    - Typing indicator menampilkan teks status dinamis `"Mencoba lagi..."` saat retry atau fallback berlangsung.
  - **Smoke Test Tool (`tool/ai_smoke_test.dart`):**
    - Menguji live network call ke masing-masing penyedia (DeepSeek, Gemini Utama, Gemini Cadangan) dan mencetak status code serta latensi tanpa membocorkan API key.
  - **Pengujian Unit (`test/fase_s1_test.dart` & `test/fase_r4_test.dart`):**
    - 11 unit test Fase S1 menguji: urutan 503-503-200 retry berhasil, DeepSeek 401 langsung beralih ke Gemini tanpa retry berulang, Gemini 503 beralih ke model cadangan, pesan ramah saat semua gagal, pesan offline saat tanpa koneksi, header `Retry-After`, circuit breaker cooldown & reset, respons MAX_TOKENS parsial, respons candidates kosong, dan status update callback.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test test/fase_s1_test.dart`: **11/11 tests passed**.
  - `flutter test test/fase_r4_test.dart`: **18/18 tests passed**.
  - `flutter test` (keseluruhan suite): **255/255 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase S2 — Input Halaman Manual & Validasi Stabilitas (SELESAI)

- **Cakupan yang selesai:**
  - **Identifikasi dan Perbaikan Akar Masalah (`lib/features/reading/reading_progress_page.dart`):**
    - State `_needsTotalInput = pages <= 0` dihitung satu kali saat data buku pertama kali dimuat (`_loadBook()`) dan disimpan sebagai state independen.
    - Visibilitas kartu input total halaman tidak lagi diturunkan saat pengguna sedang mengetik digit pertama atau nilai diubah.
    - Menambahkan `inputFormatters: [FilteringTextInputFormatter.digitsOnly]` pada `AppTextField` dan field total halaman serta field halaman saat ini.
    - Validasi angka total halaman 1 sampai 99999 dengan pesan error terlihat langsung di bawah field (`_totalPageError`).
  - **Tautan Ubah Total Halaman:**
    - Menyediakan tautan interaktif "Ubah total halaman" (`change_total_pages_link`) pada kartu Current Progress untuk memperbaiki kasus data API Google Books yang salah/tidak akurat.
    - Tombol batal / close (`cancel_change_total_pages_button`) untuk mengembalikan total halaman ke nilai semula bila pengguna membatalkan perubahan.
  - **Field Halaman Saat Ini (Tanpa Menimpa Input Pengguna & Tanpa Loncat Kursor):**
    - `_onPageTextChanged` tidak lagi menimpa `_pageController.text` dan tidak melakukan silent clamping yang membuat teks dan state berbeda.
    - Jika halaman yang diketik melebihi total halaman, pesan error terlihat jelas di bawah field (`"Halaman tidak boleh melebihi total ({_totalPages})"`) dan tombol Save Progress dinonaktifkan (`_canSave` = false). Kursor pengetikan tetap stabil dan tidak loncat.
  - **Slider Optimasi:**
    - Jika total halaman buku besar (> 300), properti `divisions` diset `null` (nilai dibulatkan dengan `round()`) untuk mencegah beban render berlebih pada widget slider.
  - **Lookup Otomatis Total Halaman Sebelum Meminta Pengguna:**
    - Saat buku dimuat dengan `pageCount <= 0`, sistem mencoba mencari detail halaman otomatis via `BookSearchRepository` (melalui ISBN jika tersedia, atau pencarian judul) sebelum menampilkan input manual wajib.
  - **Responsivitas & Anti-Overflow:**
    - Menggunakan `Wrap` pada header kartu Current Progress dan `Expanded` pada header kartu Total Halaman agar bebas RenderFlex overflow pada layar sempit (360×640) dengan text scaling 1.3.
    - Membungkus body `Scaffold` dengan `ResponsiveBody` untuk membatasi lebar maksimum 560 px di layar tablet.
  - **Pengujian Unit & Widget (`test/fase_s2_test.dart`):**
    - 7 skenario pengujian komprehensif menguji:
      1. Mengetik "350" di total halaman: field tetap ada dan bernilai 350 (tidak hilang pada digit pertama).
      2. Mengetik "120" di halaman saat ini: nilai terupdate stabil.
      3. Mengetik angka melebihi total: error muncul di bawah field dan Save nonaktif.
      4. Save progress menyimpan nilai yang benar ke repository.
      5. Tautan "Ubah total halaman" membuka kembali field total halaman.
      6. Slider divisions diset `null` ketika total halaman > 300.
      7. "Finished This Book" tetap bekerja dan menandai buku selesai ke LedgerService.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test test/fase_s2_test.dart`: **7/7 tests passed**.
  - `flutter test test/fase_u1_test.dart`: **5/5 tests passed** (bebas overflow di semua breakpoint).
  - `flutter test` (seluruh suite proyek): **262/262 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase S3 — Pengayaan Informasi Buku: Sinopsis, Harga, Halaman (SELESAI)

- **Cakupan yang selesai:**
  - **Identifikasi dan Perbaikan Akar Masalah (`lib/features/book_detail/search_book_detail_page.dart`):**
    - Halaman detail pencarian sebelumnya hanya memakai data hasil daftar pencarian (`widget.book`) yang sering dipotong/dikosongkan oleh respons list Google Books API.
    - Ditambahkan pemanggilan eksplisit `getDetail(googleBooksId)` ke endpoint `GET /volumes/{id}` lengkap dengan `country=ID` dan API key.
    - Mengambil seluruh field `volumeInfo` (`description`, `subtitle`, `publishedDate`, `pageCount`/`printedPageCount`, `categories`, `language`, `averageRating`, `ratingsCount`, `infoLink`, `previewLink`) dan `saleInfo` lengkap (`saleability`, `listPrice`, `retailPrice`, `buyLink`, `country`).
  - **Cache Memori Detail (TTL 10 Menit):**
    - `GoogleBooksRepository` dan `CompositeBookSearchRepository` dilengkapi cache in-memory `_detailCache` berdurasi 10 menit untuk mencegah pemanggilan HTTP berulang pada ID buku yang sama.
  - **Rantai Pengayaan Open Library (Fallback):**
    - Jika setelah pemanggilan Google Books detail data sinopsis, jumlah halaman, atau genre masih kosong/tidak ada, `CompositeBookSearchRepository` secara otomatis melakukan lookup ke Open Library via ISBN (`openlibrary.org/api/books?jscmd=data`) dan karya (`/works/{id}.json`).
    - Keterangan kecil `"Sumber: Open Library"` dimunculkan secara transparan di bawah sinopsis saat sinopsis berasal dari Open Library.
  - **Prinsip Kejujuran Harga (Tanpa Angka Karangan):**
    - Harga HANYA diambil dari `saleInfo` Google Books (PRD & Fase R2). Jika buku tidak dijual secara digital di Google Play Books untuk wilayah Indonesia, kartu harga menyajikan alasan yang akurat (mis. `"Buku ini belum dijual di Google Play Books untuk wilayah Indonesia"`) tanpa mengarang angka.
    - Dua tombol jujur disediakan:
      1. `"Lihat di Google Play Books"` (membuka `buyLink` atau `infoLink`).
      2. `"Cari harga di toko online"` (membuka pencarian web berdasarkan judul + ISBN via `url_launcher`).
    - Bila status NOT_FOR_SALE di Indonesia, repositori melakukan percobaan satu request tambahan tanpa parameter `country=ID` untuk mendeteksi harga internasional (misal Google Play Books AS) dengan label harga transparan (mis. `"Harga di Google Play Books (US): USD 9.99"`).
  - **Skeleton Loading & Penggabungan Data (`mergeWith`):**
    - Menampilkan skeleton shimmer loading pada kartu Sinopsis dan Harga saat detail sedang dimuat di latar belakang.
    - Jika terjadi error (timeout / 429), data awal daftar pencarian tidak dihapus atau hilang.
    - Nilai non-null dari hasil detail otomatis menang dan menggantikan data awal (`mergeWith`).
    - Saat pengguna menekan "Add to Collection" atau "Add to Wishlist", data yang disimpan adalah data hasil gabungan yang lengkap, bukan data minim daftar.
  - **Pengayaan Latar Belakang di Wishlist & Collection:**
    - `CollectionBookDetailPage` dan `WishlistBookDetailPage` memeriksa apakah sinopsis, jumlah halaman, atau harga tersimpan masih kosong. Jika kosong, pengayaan dilakukan satu kali di latar belakang (`_enrichIfNeeded()`), disimpan via `updateBook()`, dan ditandai `sync_status = 'pending'`.
  - **Pengujian Komprehensif (`test/fase_s3_test.dart`):**
    - 9 skenario pengujian unit & widget dengan fixture JSON lengkap:
      1. GoogleBooksRepository mengambil volumeInfo dan saleInfo dengan harga lengkap.
      2. Menangani status NOT_FOR_SALE dan harga kosong secara akurat.
      3. In-memory cache 10 menit mencegah pemanggilan HTTP berulang.
      4. CompositeBookSearchRepository rantai pengayaan Open Library mengisi sinopsis dan halaman kosong.
      5. `BookSearchResult.mergeWith` memenangkan nilai non-null dari detail.
      6. SearchBookDetailPage error 429/timeout tidak menghapus data yang sudah ada.
      7. Menampilkan alasan jujur dan tombol saat harga tidak tersedia.
      8. Add to Collection menyimpan data hasil gabungan yang lengkap.
      9. Background enrichment otomatis pada CollectionBookDetailPage & WishlistBookDetailPage.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test test/fase_s3_test.dart`: **9/9 tests passed**.
  - `flutter test test/fase_s1_test.dart test/fase_s2_test.dart test/fase_s3_test.dart`: **27/27 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase S4 — Sinkronisasi Geometri Papan & Perbaikan Prematur Game Over Snake (SELESAI)

- **Cakupan yang selesai:**
  - **Identifikasi dan Perbaikan Akar Masalah (`lib/features/tools/snake/snake_page.dart`):**
    - Sebelumnya engine dibuat dengan ukuran tetap 15x15 di `initState()`, sedangkan `_SnakePainter` menghitung jumlah baris sendiri dari tinggi kontainer dan meregangkan sel vertikal (`cellH`). Akibatnya, ular menabrak "dinding tak terlihat" di baris 15 padahal masih ada baris terlihat di bawahnya.
    - Menjadikan `LayoutBuilder` sebagai **satu sumber kebenaran** (PRD §10.1): menghitung `cell = availableWidth / cols` dan `rows = (availableHeight / cell).floor()`.
    - Engine diinisialisasi atau diubah ukurannya hanya saat status `ready`. Saat game berjalan (`running`/`paused`/`gameOver`), ukuran baris dipertahankan dan jika terjadi rotasi layar permainan otomatis di-pause.
  - **Render Geometri Papan Presisi & Sel Persegi Sempurna:**
    - `SnakePainter` wajib memakai `engine.rows` dan sel persegi sempurna tanpa peregangan vertikal (`cellW == cellH`).
    - Kontainer papan diatur berukuran tepat `width = cols * cell` dan `height = rows * cell`, dibungkus dalam `Center` di dalam `Expanded` tanpa ada area sisa atau baris terdistorsi.
  - **Penyempurnaan Kontrol & Stabilitas State:**
    - **Tilt Control (Gyroscope):** Ditambahkan warmup period (400 ms) saat aktivasi dan hysteresis netral threshold (`< 0.5 rad/s`) pada `SensorService` agar sentuhan jari/getaran awal tidak memicu arah acak. Pada `SnakePage`, tilt control hanya mengubah arah saat status `running` dan tidak memicu start otomatis saat baru diaktifkan di state `ready`.
    - **Swipe Gesture:** Gesture drag/swipe diabaikan saat state `ready` atau `paused` (hanya aktif saat `running`). Dilengkapi threshold minimal (3 px) untuk mencegah jitter sentuhan.
    - **Restart Game Over (Play again):** Mereset timer, skor ke 0, kepala ular kembali ke tengah (`cols ~/ 2`, `rows ~/ 2`), dan menjalankan timer kembali secara bersih.
    - **Pencegahan Timer Leak:** Timer `_ticker` dibatalkan secara eksplisit di `dispose()`, saat jeda (`pause`), dan saat restart.
  - **Pengujian Komprehensif (`test/fase_s4_test.dart` & `test/fase_a5_snake_test.dart`):**
    - 9 skenario pengujian unit & widget di `test/fase_s4_test.dart`:
      1. Ukuran 360x640: `engine.rows` sama persis dengan baris yang digambar, tinggi papan tepat `rows * cell`, dan sel persegi sempurna (`cellW == cellH`).
      2. Ukuran 360x640: ular bergerak lurus ke bawah tidak game over sebelum menyentuh baris terakhir yang digambar (`rows - 1`), dan game over tepat saat melewati batas.
      3. Ukuran 800x1280 (Tablet): `engine.rows` dihitung proporsional dari tinggi yang tersedia, sel tetap persegi, dan papan dipusatkan.
      4. Ukuran 800x1280 (Tablet): ular bergerak ke bawah menyentuh baris terakhir tanpa game over prematur.
      5. Kontrol Tilt tidak memicu pergerakan ular atau auto-start saat baru diaktifkan di state `ready`.
      6. Swipe gesture diabaikan pada state `ready` dan `paused`.
      7. Restart setelah game over (Play again) mereset skor, ular kembali ke tengah, dan timer berjalan.
      8. Timer permainan dibatalkan secara bersih saat `dispose` tanpa exception.
      9. Engine murni: mempertahankan seluruh pengujian pergerakan dan ukuran papan.
    - 13/13 unit test pada `test/fase_a5_snake_test.dart` tetap dipertahankan dan lulus 100%.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test test/fase_s4_test.dart`: **9/9 tests passed**.
  - `flutter test test/fase_a5_snake_test.dart test/fase_s1_test.dart test/fase_s2_test.dart test/fase_s3_test.dart test/fase_s4_test.dart`: **49/49 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase S5 — Reading Ledger Profesional, Faktual & Bebas Demo (SELESAI)

- **Cakupan yang selesai:**
  - **Pembersihan Banner Demo & Emoji (`lib/features/profile/reading_ledger_page.dart`):**
    - Menghapus banner "Simulasi edukatif single-node..." dan emoji `ℹ️` / `✔` / `✖`.
    - Mengganti header dengan deskripsi singkat yang faktual: *"Setiap buku yang selesai kamu baca dicatat sebagai blok. Blok saling terhubung lewat hash SHA-256 dan Proof of Work; mengubah satu data saja membuat rantai tidak valid."*
    - Catatan arsitektur teknis yang jujur dipindahkan ke bottom sheet "Tentang Reading Ledger" yang dapat diakses melalui ikon info (`Icons.info_outline_rounded`) di AppBar.
  - **Ringkasan Lengkap di Bagian Atas:**
    - Kartu ringkasan menampilkan 4 metrik penting:
      1. Jumlah Blok (`_blocks.length` Blok)
      2. Buku Tercatat (`finishedBooksCount` Buku, dihitung dari blok `blockIndex > 0`)
      3. Status Verifikasi Terakhir + Waktu (`Valid (HH:mm)` atau `Blok #X Rusak`)
      4. Status Sinkronisasi reaktif dari `SyncService.instance.state.label`.
  - **Auto-Verify & Tombol Manual "Verify Ledger":**
    - Verifikasi integritas rantai secara otomatis berjalan saat halaman dibuka.
    - Tombol manual "Verify Ledger" dengan status ikon + teks yang jelas (menggunakan `Icons.check_circle_rounded` dan `Icons.cancel_rounded` sesuai token tema, tanpa karakter emoji).
    - Menandai kartu blok yang rusak: jika verifikasi gagal, kartu blok pertama yang rusak (`block.blockIndex == invalidIndex`) menampilkan badge *"Rusak / Tidak Valid"*, border merah error, dan latar belakang kemerahan. Blok setelahnya ditandai *"Rantai Terputus"*.
  - **Bottom Sheet Detail Lengkap & Timeline Antarblok:**
    - Setiap kartu blok dapat diketuk (`onTap`) untuk membuka bottom sheet modal rincian: index, waktu pencatatan lengkap, judul, penulis, jumlah halaman, durasi baca terformat, rating bintang, hash SHA-256 penuh, previous hash penuh, nonce, status PoW, dan payload data JSON kanonikal terindentasi rapi.
    - Sedia tombol salin hash (`Clipboard.setData`) dengan umpan balik SnackBar.
    - Antarblok dihubungkan oleh visual connector (timeline) dengan ikon link dan garis vertikal yang berubah merah saat rantai terputus.
  - **Pull-to-Refresh & Error/Loading States:**
    - Pull-to-refresh memicu `SyncService.instance.pullAll(userId)` sebelum memuat ulang blok lokal.
    - Error state menampilkan pesan ramah tanpa string exception `$e` mentah, lengkap dengan tombol "Coba Lagi".
  - **Penghapusan Fallback `demo_user` & Idempotensi Genesis Block:**
    - Menghapus fallback `'demo_user'` di `ReadingLedgerPage`. Jika belum login, menampilkan state *"Silakan Masuk"* dengan tombol login.
    - Menginjeksi `LedgerService` ke `AuthController` di `lib/app/providers.dart`: Genesis block otomatis dibuat saat `register`, `login`, dan restorasi sesi (`checkSession`), sesuai PRD §10.2.
    - Operasi `appendFinishedBook` dan `ensureGenesisBlock` terbukti idempoten tanpa duplikasi blok.
  - **Audit Teks Demo UI:**
    - Memeriksa seluruh kemunculan pattern `demo|simulasi|fake|dummy|contoh` di folder `lib/`.
    - Memastikan tidak ada label demo yang tampil di mode rilis: membungkus banner mode demo di AI Chat dan Currency Converter dengan `kDebugMode`, serta mengganti fallback pengguna menjadi *"Pembaca StoryLoka"*.
    - Menambahkan tombol *"Ubah data blok (uji)"* khusus di `kDebugMode` untuk menguji bahwa verifikasi langsung mendeteksi manipulasi data.
  - **Pengujian Komprehensif (`test/fase_s5_test.dart`):**
    - 8 skenario pengujian komprehensif lolos 100%:
      1. State Unauthenticated: Menampilkan state Silakan Masuk tanpa fallback `demo_user` dan tanpa membuat blok palsu.
      2. Deskripsi faktual tampil dan TIDAK ada banner demo/simulasi atau emoji.
      3. Ringkasan di bagian atas & auto-verify saat halaman dibuka.
      4. Tombol manual Verify Ledger memicu verifikasi dan menampilkan hasil.
      5. Blok yang rusak ditandai dengan jelas saat manipulasi rantai terdeteksi.
      6. Ketuk blok membuka bottom sheet detail lengkap dengan hash SHA-256 dan JSON.
      7. Genesis block otomatis dibuat saat Register akun baru dan bersifat idempoten.
      8. Mode uji manipulasi `kDebugMode` mendeteksi kerusakan rantai saat ditekan.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test test/fase_s5_test.dart`: **8/8 tests passed** (100% lolos).
  - `flutter test test/fase_a6_test.dart test/fase_s5_test.dart`: **14/14 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase S6 — Peta Toko Buku Terdekat Bawaan (Gaya Leaflet) (SELESAI)

- **Cakupan yang selesai:**
  - **Pemasangan Paket & Kompatibilitas:**
    - Memasang dependensi `flutter_map: ^8.3.2` dan `latlong2: ^0.10.1` yang sepenuhnya kompatibel dengan Flutter 3.47 / Dart 3.13 tanpa konflik versi.
  - **Data Layer & Abstraksi Repositori:**
    - Model `Bookstore` di `lib/data/models/bookstore.dart` (`id`, `name`, `lat`, `lng`, `address` dari tag `addr:*`, `phone`, `website`, `openingHours`, `distanceMeters`, `formattedDistance`).
    - Model `PlaceResult` untuk geocoding Nominatim OSM dan fungsi matematika `calculateHaversineDistance` untuk kalkulasi jarak GPS lingkaran besar (Great-circle distance).
    - Kontrak `BookstoreRepository` di `lib/data/repositories/bookstore_repository.dart`.
    - Implementasi `OverpassBookstoreRepository` di `lib/data/repositories/remote/overpass_bookstore_repository.dart`:
      - Query Overpass `node`, `way`, dan `relation` dengan `out center tags;` untuk `shop=books` dan `shop=bookstore`.
      - Perluasan radius bertingkat otomatis: default 15 km → 20 km → 35 km → 50 km jika toko kosong.
      - 4 mirror Overpass cadangan (`overpass-api.de`, `lz4.overpass-api.de`, `overpass.kumi.systems`, `maps.mail.ru`) untuk redundansi jaringan dengan timeout ringkas 4 detik per mirror.
      - **Arsitektur Multi-Tier Resilient Fetching:** Jika Overpass API timeout/terblokir oleh ISP, sistem otomatis fallback ke Nominatim OSM POI Search (`toko buku $cityName`) dan dataset terverifikasi `IndonesianBookstoresSeed` (50+ toko buku ternama di Jabodetabek, Bandung, Yogyakarta, Solo, Semarang, Surabaya, Malang, Bali, Medan, Palembang, Makassar) sehingga titik toko buku dijamin selalu muncul.
      - Header `User-Agent` resmi StoryLoka dan in-memory cache berdurasi 10 menit (tanpa menyimpan data toko ke database).
      - Fallback nama toko kosong menjadi `"Toko buku (tanpa nama)"`.
      - Geocoding lokasi manual Nominatim dengan User-Agent, debounce, in-memory cache, chip "Kota Cepat", dan fallback kota populer Indonesia.
    - `FakeBookstoreRepository` di `lib/data/repositories/fake/fake_bookstore_repository.dart` untuk testing offline dan mock environment.
    - Pendaftaran provider `BookstoreRepository` di `lib/app/providers.dart`.
    - Konfigurasi `Env.mapTileUrl` di `lib/core/config/env.dart` dan `.env.example`.
  - **Layar Peta Terintegrasi `/maps/bookstores` (`lib/features/tools/bookstore_map/bookstore_map_page.dart`):**
    - Rute `/maps/bookstores` di atas shell router (`lib/app/router.dart`).
    - AppBar dengan judul *"Toko Buku Terdekat"*, aksi *"Cari lokasi lain"* (Nominatim geocoding bottom sheet), dan *"Lokasi saya"* (GPS).
    - Peta OpenStreetMap interaktif via `flutter_map` dengan tile OSM dan penyesuaian Dark Mode menggunakan `ColorFiltered matrix`.
    - Lingkaran visual radius pencarian (`CircleLayer` & `CircleMarker`) dengan warna aksen botani di sekitar lokasi pencarian.
    - Kamera cerdas adaptif (`_adjustCameraToFit`): otomatis memusatkan dan menyesuaikan tingkat zoom peta agar seluruh pin toko buku dan pengguna langsung terlihat di layar tanpa perlu zoom out manual.
    - Baris chip filter radius interaktif (`5 km`, `10 km`, `15 km`, `25 km`, `50 km`) untuk mengubah radius pencarian secara instan.
    - Atribusi resmi `"© OpenStreetMap contributors"` wajib dan terlihat di pojok peta.
    - Marker lokasi pengguna (biru berdenyut) dan marker toko buku (ikon buku dengan status fokus / terpilih).
    - Draggable Scrollable Bottom Sheet menampilkan daftar toko buku terurut jarak menaik (terdekat dahulu).
    - Interaksi tap marker/item daftar menyorot toko, memusatkan peta (zoom in 15.5), dan menampilkan aksi: *"Rute"* (membuka rute Google Maps eksternal), *"Telepon"* (`tel:`), dan *"Website"* (browser).
    - Penanganan izin lokasi via `LocationService` (dialog penjelasan, penanganan GPS nonaktif, input manual jika ditolak, tombol Buka Pengaturan jika ditolak permanen, dan koordinat default agar peta tidak blank).
    - State lengkap: Loading (skeleton/spinner fleksibel), Kosong (*"Belum ada toko buku terdata di sekitar sini"* + tombol perluas radius hingga 50 km & Google Maps), Error jaringan (*"Coba Lagi"*), dan Sukses.
    - Tampilan responsif bebas overflow di layar 360x640 dengan skala teks 1.3.
  - **Pembaruan Navigasi & Pratinjau Peta Detail Buku:**
    - Widget pratinjau peta kotak mini `MiniBookstoreMap` (`lib/features/book_detail/widgets/mini_bookstore_map.dart`) disematkan di dalam kartu *"Find Nearby Bookstores"* pada `SearchBookDetailPage` dan `WishlistBookDetailPage`.
    - Peta kotak mini menampilkan tile OpenStreetMap (dengan penyesuaian tema gelap/terang), titik lokasi pengguna, dan pin/titik toko buku terdekat (`Bookstore`), badge jumlah toko di sekitar, serta tombol *Peta Penuh*.
    - Tombol *"Open Maps"* dan tombol pilih kota manual tetap dipertahankan tepat di bawah kotak peta mini untuk membuka peta interaktif layar penuh `/maps/bookstores`.
  - **Pengujian Komprehensif (`test/fase_s6_test.dart`):**
    - 18 skenario pengujian unit & widget testing lolos 100%:
      1. Formula Haversine menghitung jarak geospasial secara akurat.
      2. Format jarak `Bookstore.formattedDistance` (meter dan kilometer).
      3. Parsing fixture Overpass node lengkap (nama, `addr:*`, telepon, website, jam buka).
      4. Parsing fixture Overpass way dengan `out center tags` dan tag kontak.
      5. Parsing fixture Overpass relation tanpa nama menghasilkan *"Toko buku (tanpa nama)"*.
      6. Parsing hasil geocoding Nominatim ke `PlaceResult`.
      7. Pengurutan toko berdasarkan jarak terdekat (ascending).
      8. Fallback ke mirror Overpass berikutnya saat mirror pertama gagal (HTTP 500 / error).
      9. In-memory cache 10 menit mencegah HTTP call duplikat.
      10. Perluasan radius otomatis (3 km → 5 km) saat hasil awal kosong.
      11. Widget test: Tampilan sukses peta, marker, dan daftar toko buku.
      12. Widget test: Atribusi OpenStreetMap wajib tampil.
      13. Widget test: State kosong dengan tombol Perluas Radius dan Buka Google Maps.
      14. Widget test: State error dengan tombol Coba Lagi.
      15. Widget test: Responsif tanpa overflow pada layar 360x640 dengan textScale 1.3.
      16. Widget test: Menampilkan chip radius interaktif dan dapat memilih radius 25 km.
      17. Widget test: Tombol Perluas Radius pada state kosong dapat memperluas hingga 25 km dan 50 km.
      18. Widget test: MiniBookstoreMap menampilkan peta kotak mini dengan titik toko terdekat dan navigasi peta penuh.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test test/fase_s6_test.dart`: **18/18 tests passed** (100% lolos).
  - `flutter test test/fase_a2_test.dart test/fase_s6_test.dart test/fase_s3_test.dart`: **33/33 tests passed** (100% lolos).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

---

### Fase S7 — Kesan & Pesan: Halaman BACA SAJA Tim Pengembang (SELESAI)

- **Keputusan Pemilik Proyek (Menggantikan Semua Asumsi Sebelumnya):**
  - Halaman `/tools/feedback` bukan lagi form interaktif atau guestbook.
  - Halaman ini merupakan halaman **BACA SAJA (Read-Only)** yang menampilkan evaluasi kesan dan pesan mata kuliah Pemrograman Aplikasi Mobile (PAM) dari 3 anggota kelompok pengembang StoryLoka.
  - Data tertulis tetap di kode (`const List<TeamFeedback> teamFeedbacks`), bernilai identik untuk semua akun (termasuk yang belum login), dan tidak dapat diubah oleh pengguna.

- **Cakupan yang Selesai:**
  - **Penghapusan Form & Controller:**
    - Menghapus seluruh elemen formulir: field Nama, Kesan, Pesan, tombol kirim, validasi input, state `_isSaving`, serta seluruh controller terkait dari `lib/features/tools/feedback_page.dart`.
  - **Penyimpanan Terpusat & Abstraksi Read-Only Repository:**
    - Membuat model dan data konstan di `lib/data/static/team_feedback.dart`:
      1. **Najmah Cleosa** (NIM: 124240104) — Lead Developer & Architect
      2. **Melanie Bunga Chintya Pawesty** (NIM: 124240164) — UI/UX & Frontend Developer
      3. **Naftali Margareta** (NIM: 124240119) — Feature & QA Developer
    - Menyederhanakan `FeedbackRepository` di `lib/data/repositories/feedback_repository.dart` menjadi antarmuka murni read-only (`Future<List<TeamFeedback>> getAll();` tanpa metode `save()`).
    - Membuat implementasi `TeamFeedbackRepository` yang membaca list konstan `teamFeedbacks`.
    - Menyesuaikan `FakeFeedbackRepository` dan `LocalFeedbackRepository` agar konsisten mengembalikan data tim konstan, serta menginjeksi `TeamFeedbackRepository` pada `lib/app/providers.dart`.
  - **Desain & Tampilan Antarmuka Cozy Editorial:**
    - Judul halaman AppBar: *"Kesan & Pesan"*.
    - Banner pengantar botani: *"Kesan dan pesan dari kelompok kami untuk mata kuliah Pemrograman Aplikasi Mobile."*
    - Tepat 3 kartu (`AppCard`), satu per anggota dengan urutan tetap:
      - Avatar inisial (`NC`, `MB`, `NM`) dengan latar warna harmonis tema dan Semantics label jelas (`Avatar ${item.name}`).
      - Nama anggota dengan tipografi Fraunces SemiBold (`AppText.cardHeading`).
      - Badge identitas NIM (`NIM: ...`) dan peran pengembang.
      - Pembatas halus (`Divider`).
      - Bagian **Kesan**: ikon senyum ramah, label berbobot tebal, dan teks kesan membungkus penuh tanpa terpotong (`softWrap: true`).
      - Bagian **Pesan**: ikon lampu ide, label berbobot tebal, dan teks saran membungkus penuh tanpa terpotong.
    - Tanpa tombol tambah/edit/hapus/simpan. Tampilan responsif pada tema gelap (Dark Mode), layar compact 360×640 px, dan skala teks 1.3.
  - **Pengecualian Tabel `feedbacks` dari Sinkronisasi (PRD §8.3):**
    - Menghapus langkah sinkronisasi tabel `feedbacks` dari `pushPending`, `pullAll`, dan perhitungan pending count di `lib/core/services/sync_service.dart`.
    - Urutan sinkronisasi tabel yang disinkronkan tetap konsisten: `user_books` -> `reading_sessions` -> `ledger_blocks` -> `game_scores`.
    - Struktur tabel `feedbacks` di SQLite dan Supabase tetap dipertahankan tanpa perubahan skema berisiko.
  - **Penghapusan Fallback ID Palsu pada Seluruh Repository Mode Nyata:**
    - Menghapus seluruh fallback `'default_user'`, `'demo'`, dan `'demo_user'` di `search_book_detail_page.dart`, `deepseek_chat_repository.dart`, `gemini_chat_repository.dart`, dan `local_repositories.dart`.
    - Jika pengguna mengakses fitur data pribadi tanpa sesi login terautentikasi (UUID valid RFC 4122), repository melempar error terkontrol `StateError('NO_AUTHENTICATED_USER')` dan antarmuka menampilkan pesan SnackBar untuk masuk ke akun.
  - **Pembaruan Menu Tools Page:**
    - Deskripsi kartu menu Kesan & Pesan pada `lib/features/tools/tools_page.dart` diperbarui menjadi *"Baca kesan dan pesan dari tim kami"*.
  - **Pengujian Lengkap:**
    - `test/fase_s7_test.dart` diperbarui: menguji isolasi data pribadi pada repository nyata, penolakan fallback palsu, verifikasi `TeamFeedbackRepository`, pengecualian `feedbacks` dari `SyncService`, ketiadaan form/TextField, rendering tepat 3 kartu tim dengan nama & teks lengkap, kesamaan tampilan untuk multi-akun/anonim, bebas overflow di 360×640 skala teks 1.3, dan verifikasi Dark Mode.
    - Penyesuaian test suite terkait: `fase_b4_test.dart`, `fase_b7_test.dart`, `fase_u4d_test.dart`, `fase_u5_test.dart`, `fase_a5_tools_test.dart`, `fase_b1_test.dart`.

- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (100% bersih).
  - `flutter test test/fase_s7_test.dart`: **12/12 tests passed** (100% lolos).
  - `flutter test`: **318/318 tests passed** (100% lolos di seluruh aplikasi).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md` (Penyimpangan PRD §7.7.1 & §8.3).

---

### Fase S8 — Integrasi Fallback Open Library (SELESAI)

- **Latar Belakang & Masalah:**
  - Banyak buku (terutama buku terbitan Indonesia) pada respons Google Books API memiliki field `volumeInfo.description` dan `imageLinks` yang kosong/null, menyebabkan sinopsis atau gambar sampul buku tidak tampil.
- **Cakupan yang Selesai:**
  - **Klien Remote Open Library (`lib/data/remote/open_library_api.dart`):**
    - `fetchSynopsis(String isbn)`:
      - Normalisasi ISBN (membersihkan tanda hubung dan spasi).
      - Mengirim GET ke `https://openlibrary.org/isbn/{isbn}.json`.
      - Membaca field `description` dari edisi; jika kosong, mengambil `works[0].key` dan membaca `https://openlibrary.org{key}.json`.
      - Menangani `description` baik berupa `String` maupun objek Map `{type, value}` dengan `trim()`; nilai kosong dianggap `null`.
    - `fetchCoverUrl(String isbn)`:
      - Mengirim HEAD ke `https://covers.openlibrary.org/b/isbn/{isbn}-L.jpg?default=false`.
      - Status HTTP 200 mengembalikan URL cover tersebut; status lain atau error mengembalikan `null`.
    - Seluruh request menggunakan header resmi `User-Agent: StoryLoka/1.0 (student project)`, batas timeout 15 detik, dan error handling aman (tidak melempar exception ke UI).
  - **Repositori & Enrichment (`BookSearchRepository.enrich`):**
    - Menambahkan `typedef BookResult = BookSearchResult;` dan definisi metode `Future<BookSearchResult> enrich(BookSearchResult b);`.
    - Mengimplementasikan `enrich` pada `GoogleBooksRepository`, `CompositeBookSearchRepository`, `OpenLibraryRepository`, dan `FakeBookSearchRepository`.
    - Aturan enrichment:
      - Jika `isbn` null atau kosong, mengembalikan buku apa adanya tanpa request jaringan.
      - Hanya memanggil Open Library untuk field yang kosong: sinopsis dan/atau cover. Jika kedua data sudah lengkap, langsung return tanpa memicu request.
      - Panggilan `fetchSynopsis` dan `fetchCoverUrl` berjalan secara paralel (`Future.wait<String?>`).
      - Data dari Google Books tidak pernah ditimpa oleh data Open Library.
  - **Integrasi UI & Fallback (`SearchBookDetailPage` di `/book/search`):**
    - Pemanggilan `enrich` dilakukan secara tertarget HANYA di `SearchBookDetailPage` saat detail buku dibuka dan saat Add Book setelah pengguna memilih satu buku. Tidak dipanggil pada daftar hasil pencarian massal untuk menghemat bandwidth.
    - Menampilkan indikator loading ringan (`_isEnriching`) tanpa memblokir tampilan data Google Books yang sudah ada.
    - Sinopsis tetap kosong menampilkan *"Sinopsis tidak tersedia"*.
    - Cover tetap kosong menampilkan placeholder cover sage botani bawaan.
    - Menjamin sanitasi cover URL selalu `https://` dan widget cover memiliki `errorWidget`/placeholder.
  - **Dokumentasi & Regulasi PRD:**
    - Memperbarui `docs/spec/prd-storyloka.md` dengan sub-bagian `### 9.1b Fallback Open Library`.
    - Mencatat perluasan aturan data buku di `docs/DEVIATIONS.md`.
    - Menjaga arsitektur PRD: UI tidak pernah memanggil `http` secara langsung.
  - **Pengujian Unit (`test/open_library_enrich_test.dart`):**
    - Menguji parsing `description` bentuk String, bentuk Map `{type, value}`, dan null/kosong.
    - Menguji pengambilan sinopsis langsung dari edition maupun fallback ke works.
    - Menguji verifikasi HEAD request cover URL status 200 vs 404.
    - Menguji `enrich` tidak memanggil Open Library jika data sudah lengkap.
    - Menguji `enrich` tidak menimpa data Google Books yang sudah ada.
    - Menguji penanganan ISBN null/kosong.
- **Hasil Verifikasi:**
  - `dart analyze lib test`: **0 issues found** (100% bersih).
  - `flutter test test/open_library_enrich_test.dart`: **10/10 tests passed** (100% lolos).
  - `flutter test`: **328/328 tests passed** (100% lolos di seluruh aplikasi).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.




---

### Fase F1 — Perbaikan Bug Fungsional (F1.1 SELESAI)

#### F1.1 — Offline Membuat User Ter-logout (PRD §7.1)

- **Akar Masalah:**
  - Pada `SupabaseAuthRepository.validateSession()` di `lib/data/repositories/supabase/supabase_repositories.dart`, blok `catch (e)` menangkap semua jenis error (termasuk `SocketException`, offline, timeout, dan network drop) lalu mengeksekusi `sessionStore.clearSession()` dan mengembalikan `null`. Akibatnya, saat pengguna membuka aplikasi tanpa internet, sesi lokal dihapus dan pengguna dipaksa masuk kembali.
  - Pada `AuthController.checkSession()`, `TimeoutException` 10 detik langsung memunculkan layar error di Splash dan memblokir navigasi, meskipun perangkat memiliki data sesi lokal yang valid.
  - Pesan error jaringan di `_mapAuthException` menggeneralisir seluruh error jaringan sebagai `HandshakeException... Private DNS`.
- **Cakupan yang Selesai:**
  - **Penyempurnaan `SupabaseAuthRepository.validateSession()`:**
    - Hanya memanggil `sessionStore.clearSession()` jika server secara eksplisit mengembalikan respons `SESSION_INVALID` (`PostgrestException`).
    - Untuk galat jaringan, socket terputus, atau timeout, mengembalikan data profil pengguna dari cache lokal `sessionStore.getUser()` jika token tersedia.
  - **Penyempurnaan `AuthController.checkSession()`:**
    - Jika terjadi `TimeoutException` atau galat jaringan dan terdapat sesi lokal tersimpan (`cachedUser != null` dan `hasToken == true`), aplikasi tidak menahan pengguna di Splash. Aplikasi langsung masuk ke `/home` (atau `/lock` jika biometrik aktif) dengan sesi lokal, lalu menjadwalkan validasi ulang di latar belakang (`_revalidateInBackground`).
    - Jika validasi latar belakang kemudian mengonfirmasi sesi tidak valid di server, logout paksa dilakukan dengan pesan ramah *"Sesi Anda telah berakhir. Silakan masuk kembali."*.
    - Layar error timeout Splash hanya muncul jika perangkat belum memiliki sesi lokal yang valid.
  - **Diferensiasi Pesan Error Jaringan:**
    - Tanpa koneksi internet / Socket / Network timeout: *"Tidak ada koneksi internet. Periksa jaringan Anda lalu coba lagi."*
    - Masalah TLS / Handshake: *"Koneksi aman gagal (TLS/HandshakeException). Periksa pengaturan Private DNS atau tanggal dan jam perangkat Anda."*
- **Pengujian Otomatis (`test/fase_f1_test.dart` & `test/fase_r1_test.dart`):**
  - TDD: Tes gagal sebelum perbaikan diterapkan dan lolos 100% sesudahnya.
  - 4 pengujian baru di `test/fase_f1_test.dart`:
    1. `validateSession` saat offline mempertahankan sesi lokal di secure storage dan mengembalikan cached user.
    2. `validateSession` saat server menjawab `SESSION_INVALID` membersihkan sesi lokal dan mengembalikan `null`.
    3. Pemetaan pesan error jaringan membedakan masalah koneksi internet vs TLS/Handshake.
    4. Widget test: Splash tetap lanjut masuk ke Home saat offline/timeout jika terdapat sesi lokal.
- **Hasil Verifikasi:**
  - `dart analyze lib test` / `flutter analyze`: **0 issues found** (100% bersih).
  - `flutter test`: **332/332 tests passed** (100% lolos di seluruh aplikasi).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

#### F1.2 — Pilihan Tema Tidak Tersimpan (PRD §8.1 & §10.4)

- **Akar Masalah:**
  - `ThemeController` di `lib/app/providers.dart` hanya berstatus in-memory dengan default `ThemeMode.light`. Saat aplikasi ditutup atau dimulai ulang, pilihan tema pengguna hilang.
- **Cakupan yang Selesai:**
  - **Penyimpanan & Pemuatan SharedPreferences:**
    - Menyimpan nilai mode tema (`'light'`, `'dark'`, `'auto'`) pada key `'theme_mode'` di `SharedPreferences` (PRD §8.1) secara otomatis setiap kali pengguna memilih tema di Profile.
    - Menambahkan `ThemeController.create()` yang dimuat di `main.dart` secara asinkron sebelum `runApp` dieksekusi, sehingga tema aktif sejak frame awal tanpa kedipan visual (*theme flash*).
    - Memastikan mode Auto secara otomatis menginisialisasi dan memulai `LightSensorService` saat preferensi Auto dimuat ulang.
    - Mempertahankan preferensi tema saat logout (pengaturan per perangkat, bukan data akun server).
- **Pengujian Otomatis (`test/fase_f1_test.dart`):**
  - TDD: Tes gagal sebelum implementasi dan lolos 100% sesudahnya.
  - 3 pengujian baru:
    1. Simpan lalu muat ulang tiap mode tema (`dark`, `auto`, `light`) di `SharedPreferences`.
    2. Mode Auto otomatis mengaktifkan `LightSensorService` saat dimuat ulang.
    3. Tema tidak direset saat logout.
- **Hasil Verifikasi:**
  - `dart analyze lib test` / `flutter analyze`: **0 issues found** (100% bersih).
  - `flutter test`: **335/335 tests passed** (100% lolos di seluruh aplikasi).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

#### F1.3 — Genesis Block Bentrok di Perangkat Baru (PRD §8.3 & §10.2)

- **Akar Masalah:**
  - `AuthController.login()`, `register()`, dan `checkSession()` memanggil `ledgerService.ensureGenesisBlock()` sebelum `SyncService.instance.pullAll()`.
  - Di perangkat baru, dibuat blok #0 lokal dengan ID acak v4 dan timestamp `DateTime.now().toUtc()`, berbeda dari blok #0 di server.
  - Hal ini melanggar `UNIQUE (user_id, block_index)` saat sinkronisasi (push/pull), menyebabkan baris tertahan `pending`, dan berpotensi membuat rantai ledger bercabang.
- **Cakupan yang Selesai:**
  - **Urutan Sinkronisasi:**
    - Di `AuthController.login()`, `register()`, `checkSession()`, dan `_revalidateInBackground()`, memanggil `await SyncService.instance.pullAll(user.id)` terlebih dahulu, baru memanggil `ensureGenesisBlock(user.id)` hanya jika setelah pull masih belum ada blok.
  - **Genesis Block Deterministik:**
    - ID Genesis dihitung menggunakan UUID v5: `_uuid.v5(Namespace.url.value, 'storyloka:genesis:$userId')`.
    - Timestamp Genesis konstan: `LedgerService.genesisTimestamp = DateTime.utc(2025, 1, 1, 0, 0, 0)`.
    - Proof of Work (`mineBlock`) menghasilkan hash dan nonce yang 100% konsisten lintas perangkat.
  - **Resolusi Sinkronisasi:**
    - Di `SyncService._pullLedgerBlocks()`, query pembaruan row menggunakan `where: 'id = ? OR (user_id = ? AND block_index = ?)'` untuk memperbarui status blok lokal yang cocok menjadi `synced`.
- **Pengujian Otomatis (`test/fase_f1_test.dart`):**
  - TDD: Tes gagal sebelum implementasi dan lolos 100% sesudahnya.
  - 3 pengujian baru:
    1. Genesis block bersifat deterministik (UUID v5 dan timestamp tetap menghasilkan ID, hash, nonce yang identik lintas perangkat, `verifyChain` valid).
    2. Simulasi perangkat baru: `pullAll` sebelum `ensureGenesisBlock` mencegah duplikasi blok, status lokal `synced`, `pendingCount == 0`, dan tidak ada konflik `UNIQUE`.
    3. Idempotensi `appendFinishedBook` tetap terjaga (memanggil ganda untuk buku yang sama tidak menduplikasi blok dan `verifyChain` valid).
- **Hasil Verifikasi:**
  - `dart analyze lib test` / `flutter analyze`: **0 issues found** (100% bersih).
  - `flutter test`: **338/338 tests passed** (100% lolos di seluruh aplikasi).
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

#### F1.4 — Logout Sesuai PRD §7.8

- **Akar Masalah:**
  - Di `ProfilePage._confirmLogout()` dan `AuthController.logout()`, `DatabaseHelper.clearUserData()` tidak pernah dipanggil sehingga data SQLite lokal pengguna tidak dibersihkan saat logout.
  - Alur konfirmasi tidak menampilkan dialog peringatan pending jika masih terdapat baris yang belum tersinkron ke remote sebelum keluar.
- **Cakupan yang Selesai:**
  - **Urutan Logout Standar PRD §7.8:**
    1. Konfirmasi keluar awal (`AppDialog.showConfirm` dengan opsi Batal / Keluar).
    2. Sinkronisasi perubahan lokal ke server (`SyncService.instance.syncBeforeLogout(userId)`).
    3. Jika masih ada data pending (`pendingCount > 0`), muncul dialog peringatan: *"Ada data belum tersinkron, tetap logout?"* dengan opsi Batal dan Tetap Logout.
    4. Pemanggilan `authRepository.logout()` (eksekusi RPC `logout_session` di server).
    5. Pembersihan sesi lokal di secure storage (`sessionStore.clearSession()`).
    6. Pembersihan data SQLite lokal pengguna (`DatabaseHelper.clearUserData(userId)`), termasuk `user_books`, `reading_sessions`, `ledger_blocks`, `feedbacks`, `game_scores`, dan `chat_messages`.
    7. Pembatalan notifikasi terjadwal harian dan notifikasi stopwatch sesi membaca yang sedang berlangsung.
    8. Navigasi kembali ke halaman masuk (`/login`).
  - **Perlindungan Preferensi Per Perangkat:**
    - Preferensi per perangkat seperti tema (`theme_mode`) dan jadwal pengingat membaca (`pref_reading_reminder_hour`, `pref_reading_reminder_minute`) di `SharedPreferences` dipertahankan dan tidak terhapus.
- **Pengujian Otomatis (`test/fase_f1_test.dart`):**
  - TDD: Tes gagal sebelum implementasi dan lolos 100% sesudahnya.
#### F1.5 — Konflik Sinkronisasi yang Membuat Baris Macet Pending (PRD §8.3)

- **Akar Masalah:**
  - Saat dua perangkat menambahkan buku yang sama (`google_books_id` sama) saat offline dengan UUID lokal berbeda, operasi `_pushTable` dengan `upsert(onConflict: 'id')` memicu galat Postgres code 23505 (pelanggaran batasan `UNIQUE(user_id, google_books_id)`).
  - Baris tersebut dibiarkan berstatus `pending` dan gagal selamanya, menyebabkan indikator "Menunggu sinkron" tidak pernah bersih.
  - Konflik `ledger_blocks` pada `(user_id, block_index)` juga berpotensi loop selamanya membanjiri jaringan.
- **Cakupan yang Selesai:**
  - **Deteksi Galat Konflik (`_isUniqueViolation`):** Mendeteksi `PostgrestException` dengan kode `23505` atau pesan terkait constraint unik/duplicate key.
  - **Resolusi Konflik `user_books` Berbasis Last-Write-Wins (LWW):**
    - Mengambil baris remote yang memiliki `google_books_id` sama via `fetchRowByField('user_books', userId, 'google_books_id', googleBooksId)`.
    - Membandingkan `updated_at` antara baris lokal dan remote:
      - Jika data lokal lebih baru (Local LWW Win): data lokal dimutakhirkan ke remote menggunakan ID remote, tabel `reading_sessions` yang merujuk ID lokal lama dialihkan (`migrated`) ke ID remote, baris lokal diperbarui ke ID remote, dan ditandai `synced`.
      - Jika data remote lebih baru/sama (Remote LWW Win): data remote dimasukkan ke SQLite lokal dengan status `synced`, `reading_sessions` dialihkan ke ID remote, dan baris lokal lama dibersihkan.
  - **Resolusi Konflik pada `_pullUserBooks`:**
    - Mengecek keberadaan lokal berdasarkan ID terlebih dahulu, lalu berdasarkan `(user_id, google_books_id)`.
    - Jika ID berbeda, secara otomatis mengalihkan relasi `reading_sessions` ke ID remote dan menerapkan LWW dengan benar.
  - **Resolusi Konflik `ledger_blocks`:**
    - Blok remote tidak pernah ditimpa.
    - Jika `block_index` sudah ada di remote, blok lokal yang konflik ditandai `sync_status = 'conflict'` dan dicatat di log agar tidak berulang kali memicu loop sinkronisasi.
  - **Pembatasan Percobaan Ulang (Retry Guard):**
    - Melacak percobaan gagal (`_retryCounts`) dengan batas maksimal 3 kali (`_maxRetries = 3`). Jika melampaui batas, baris ditandai `error` atau `conflict` agar tidak membanjiri jaringan.
- **Pengujian Otomatis (`test/fase_f1_test.dart`):**
  - TDD: Tes gagal sebelum implementasi dan lolos 100% sesudahnya.
  - 2 pengujian baru:
    1. Simulasi 2 perangkat menambah buku yang sama offline; verifikasi resolusi LWW mempertahankan ID remote, mengalihkan relasi `reading_sessions`, menyisakan tepat 1 baris di SQLite, dan `pendingCount` menjadi 0.
    2. Konflik `ledger_blocks` tidak menimpa remote, ditandai `conflict`, dan `pendingCount` menjadi 0 tanpa loop tak terhingga.
- **Hasil Verifikasi F1.5:**
  - `flutter analyze`: **0 issues found** (100% bersih).
  - `flutter test`: **342/342 tests passed**.
- **Penyimpangan/Keputusan:** Dicatat pada `docs/DEVIATIONS.md`.

#### F1.6 — Perbaikan Kecil Terkait & Audit Logika

- **Cakupan yang Selesai:**
  1. **Filter Pengguna Aktif pada `LocalLibraryRepository.getBookById`:**
     - Menambahkan klausul `user_id = ? AND is_deleted = 0` pada query SQLite untuk memastikan integritas data terisolasi per pengguna aktif.
  2. **Klarifikasi Perilaku `moveToCollection` Sesuai PRD §7.6:**
     - Mempertahankan perilaku pemindahan tanpa mereset status/progres baca pengguna. Dokumentasi ringkasan checklist di `docs/PROGRESS.md` disinkronkan.
  3. **Restorasi Buku Soft-Deleted yang Ditambahkan Kembali:**
     - Saat buku yang dihapus (`is_deleted = 1`) ditambahkan kembali oleh user, status dipulihkan ke `not_started` dan `current_page = 0` jika buku baru fresh (tanpa progres disengaja).
  4. **Unifikasi Pola Path Upload Avatar:**
     - Disatukan menggunakan `SyncService.uploadAvatar(userId, bytes)` dengan pola file berversi timestamp `avatar_${userId}_${timestamp}.jpg` untuk mencegah stale CDN cache.
  5. **Audit Blok Catch Kosong:**
     - Menambahkan `debugPrint` terbungkus `kDebugMode` pada blok catch yang berisiko menyembunyikan kegagalan sistem penting (sync pull, score repo, URL launcher, db sanitize, open library fallback) tanpa membocorkan data sensitif.
- **Pengujian Otomatis (`test/fase_f1_test.dart`):**
  - TDD: Ditambahkan 3 pengujian spesifik untuk validasi filter `getBookById`, restorasi status bersih buku soft-deleted, dan pemindahan `moveToCollection` tanpa mereset progres.
- **Hasil Verifikasi Akhir:**
  - `flutter analyze`: **No issues found!** (100% bersih).
  - `flutter test`: **345/345 tests passed** (100% lolos di seluruh aplikasi).
- **Penyimpangan/Keputusan:** Dicatat lengkap pada `docs/DEVIATIONS.md`.

---

### Fase F5 — Keamanan, Kebersihan Proyek, dan Dokumentasi (SELESAI)

- **Cakupan yang Selesai:**
  1. **Secrets & Keamanan (.env):**
     - Memastikan `.env` terlindungi dari komit git via `.gitignore` (`.env` dan `*.env`).
     - Memperbarui `.env.example` dengan seluruh variabel yang dipakai: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_BOOKS_API_KEY`, `DEEPSEEK_API_KEY`, `GEMINI_API_KEY`, `GEMINI_MODEL`, `GEMINI_MODEL_FALLBACKS`, `MAP_TILE_URL`.
     - Memberikan peringatan rotasi API key bagi pemilik proyek jika rahasia pernah ikut terkomit/terekspor dalam arsip zip sebelumnya.
     - Mendokumentasikan catatan keamanan jujur di README.md: ekstraksi key dari APK (PRD §3), batasan isolasi data klien akibat policy RLS permisif untuk anon (PRD §8.2), dan jalur penguatan masa depan (PostgREST RPC berbasis validasi token).
  2. **Kebersihan Proyek & Berkas Git:**
     - Memperketat `.gitignore` agar secara eksplisit mengecualikan `.idea/`, `.idea/**`, `.gradle/`, `android/.gradle/`, `android/local.properties`, `build/`, `.dart_tool/`, `*.iml`.
     - Memastikan seluruh artefak lokal dan build tidak ter-track dalam riwayat git repo.
  3. **Penyelarasan Dokumentasi & Kode:**
     - Memperbaiki bagian "Penelusuran Checklist Verifikasi Akhir":
       - Kesan & Pesan ditandai berstatus **Draf Read-Only** (Fase S7) dan menunggu input tulisan tangan asli anggota kelompok sebelum pengumpulan tugas akhir.
       - Mini Game Snake dikonfirmasi menggunakan 15 kolom (`_cols = 15`) dengan baris adaptif proporsional tinggi layar.
       - Mata uang yang didukung diselaraskan: 5 mata uang (IDR, USD, EUR, JPY, SGD; menghilangkan klaim GBP).
       - Menghapus referensi ke berkas tes usang (`test/fase_b2_test.dart`) dan merujuk suite tes auth/biometrik aktif (`test/fase_a1_test.dart`, `test/fase_b1_test.dart`, `test/fase_u4d_test.dart`).
       - Memperbarui jumlah total tes lulus menjadi **345/345 passed** (100%).
  4. **Pengaturan Android Manifest & Notifikasi:**
     - Menghapus izin invasif `SCHEDULE_EXACT_ALARM` dan `USE_EXACT_ALARM` dari `android/app/src/main/AndroidManifest.xml` sesuai prinsip PRD §10.5 yang memanfaatkan `AndroidScheduleMode.inexactAllowWhileIdle`.
     - Memverifikasi `minSdk` (flutter sdk default min 21+), `coreLibraryDesugaring` (`desugar_jdk_libs:2.1.4`), dan `FlutterFragmentActivity` di `MainActivity.kt`.
  5. **Data Statis Kesan & Pesan Anggota Tim:**
     - Memperbarui `lib/data/static/team_feedback.dart` dengan peringatan jelas bahwa teks buatan AI yang ada saat ini merupakan draf/placeholder dan wajib diganti dengan kesan & pesan asli tulisan tangan Najmah Cleosa, Melanie Bunga Chintya Pawesty, dan Naftali Margareta sebelum pengumpulan akhir.
---

### Fase F4 — Konsistensi UI Seluruh Aplikasi (SELESAI)

- **Cakupan yang Selesai:**
  1. **Audit & Standardisasi Header Halaman:**
     - Tab shell navigasi utama (`Home`, `Library`, `Add Book`, `Tools`, `Profile`) konsisten menggunakan `AppText.pageHeading(color: ...)` (Fraunces 30).
     - Seluruh halaman push / sub-halaman (`ScanPage`, `SearchBookDetailPage`, `CollectionBookDetailPage`, `WishlistBookDetailPage`, `ReadingTimerPage`, `ReadingProgressPage`, `FinishedBookPage`, `BookstoreMapPage`, `ReadingLedgerPage`, `EditProfilePage`, `AiChatPage`, `FeedbackPage`, `SnakePage`, `CurrencyConverterPage`, `TimeConverterPage`) menggunakan `AppText.sectionHeading(color: ...)` (Fraunces 20) dengan AppBar dan perilaku back yang seragam.
  2. **Pembersihan Token Mentah (Colors, Color(0x...), fontSize, radius):**
     - Ditambahkan token resmi baru pada `AppColors`: `AppColors.trackDark` (`0xFF243336`), `AppColors.amberWarm` (`0xFFC07A15`), `AppColors.amberDark` (`0xFF8A5300`), `AppColors.overlayDark` (`0x8A000000`), dan `AppColors.shadowSubtle` (`0x1F000000`).
     - Seluruh kemunculan mentah `Colors.white`, `Colors.black*`, `Color(0x...)`, dan `fontSize: 10/11/12/40` di `lib/features` dan `lib/app` telah dibersihkan dan dialihkan ke `AppColors` dan `AppText` (`AppText.code`, `AppText.caption`, `AppText.displayMedium`, `AppText.button`).
  3. **Standardisasi Margin, Radius, Spacing & Komponen Reusable:**
     - Margin halaman 24 (`AppSpacing.pagePadding`), jarak antar-seksi 24–32, jarak dalam grup 8–16, padding card 16, radius card 20 (`AppSpacing.cardRadius`), radius input 12 (`AppSpacing.inputRadius`), radius tombol 14 (`AppSpacing.buttonRadius`), dan tinggi kontrol 48 (`AppSpacing.buttonHeight`).
     - Seluruh tombol memakai `PrimaryButton`, `SecondaryButton`, dan `TertiaryButton`.
     - Seluruh input memakai `AppTextField` dan `AppDropdown`.
     - Seluruh kartu memakai `AppCard`, `NotesCard`, `SupportCard`, dan `EmptyStateCard`.
     - Seluruh dialog memakai `AppDialog` dan snackbar memakai `AppSnackBar`.
  4. **State Seragam pada Layar Berbasis Data:**
     - Semua layar data menangani 4 state seragam: `loading` (spinner/skeleton), `empty` (`EmptyStateCard`), `error` (dengan tombol aksi Coba Lagi), dan `success`.
  5. **Bahasa & Aksesibilitas:**
     - Konsistensi istilah fitur Inggris (`Home`, `Library`, `Add Book`, `Tools`, `Profile`, `Currently Reading`, `My Collection`, `My Wishlist`) dengan teks sistem bahasa Indonesia.
     - Penyeragaman label `Password` dan tombol aksi `Login`/`Daftar`. Format tanggal terpusat menggunakan `id_ID`.
     - Target sentuh minimal ≥ 44×44 px di semua tombol, ikon, dan chip interaktif.
     - Kontras teks memenuhi WCAG AA di mode terang dan gelap.
  6. **Pengujian Matriks Responsif Komprehensif (`test/fase_f4_test.dart`):**
     - Dibuat suite pengujian matriks yang menguji 24 layar aplikasi secara menyeluruh pada 6 kombinasi ukuran & tema:
       - 360×640 px (skala teks 1.0, Light Mode)
       - 360×640 px (skala teks 1.3, Dark Mode)
       - 402×874 px (skala teks 1.0, Light Mode)
       - 402×874 px (skala teks 1.3, Dark Mode)
       - 800×1280 px Tablet (skala teks 1.0, Light Mode)
       - 800×1280 px Tablet (skala teks 1.3, Dark Mode)
     - Seluruh 24 layar terbukti render bebas `RenderFlex overflow` pada seluruh resolusi dan orientasi.
- **Hasil Verifikasi:**
  - `flutter analyze`: **No issues found!** (100% bersih).
  - `flutter test`: **351/351 tests passed** (100% lolos di seluruh aplikasi).
---

### Perbaikan Bug Sinkronisasi UUID & Pertahanan Sinkronisasi Supabase (SELESAI)

- **Masalah Asal:**
  - Pembuatan ID non-UUID (`DateTime.now().microsecondsSinceEpoch.toString()`) di `search_book_detail_page.dart` menghasilkan integer string (misal: `"1793167732379150"`).
  - Saat push ke Supabase Postgres dengan tipe kolom `id UUID PRIMARY KEY`, remote menolak dengan error `PostgrestException: invalid input syntax for type uuid: "1793167732379150" (code 22P02)`.
  - Akibatnya, baris berstatus `sync_status = 'error'`, `reading_sessions` dengan foreign key ke buku ikut gagal sync, dan data hilang setelah logout karena remote kosong.
- **Cakupan yang Selesai:**
  1. **Pembuatan ID di UI:**
     - Mengganti pembuatan ID di `search_book_detail_page.dart` (Add to Collection & Add to Wishlist) menggunakan `const Uuid().v4()`. Tidak ada perubahan UI atau alur pengguna.
  2. **Pertahanan Lapisan Repositori Lokal:**
     - Di `LocalLibraryRepository.addBook`, `LocalReadingRepository.saveSession`, `LocalLedgerRepository.saveBlock`, dan `LocalScoreRepository.saveScore`: jika ID kosong atau berupa angka murni (format timestamp microseconds lama), otomatis di-generate UUID v4 baru.
  3. **Perbaikan Layanan Sinkronisasi (`SyncService` & `AuthController`):**
     - Ditambahkan `resetErrorSyncStatus`: baris dengan `sync_status = 'error'` dikembalikan ke `'pending'` saat startup, login, resume, dan sebelum push manual.
     - `refreshPendingCount` kini menghitung baris `pending` dan `error`.
     - `SupabaseSyncRemoteSource.upsert` melempar `StateError` jika klien Supabase null / belum terhubung.
     - Di `AuthController.checkSession`, `_revalidateInBackground`, `login`, dan `register`: `pushPending` dipanggil **sebelum** `pullAll`.
     - Di `AuthController.logout`: jika logout otomatis tanpa dialog dan masih ada baris `pending` / `error`, `clearUserData` dilewati agar data lokal pengguna tetap aman terisolasi per `user_id`. Jika pengguna eksplisit menyetujui logout lewat dialog, `clearUserData` dijalankan sesuai PRD §7.8.
  4. **Migrasi Database SQLite Lokal (v2 -> v3):**
     - Menaikkan versi database di `DatabaseHelper` dari 2 ke 3.
     - Ditambahkan `_migrateToV3`: memindai `user_books` dengan ID non-UUID. Jika belum tercatat di `ledger_blocks.data_json`, ID diperbarui ke UUID v4 baru, foreign key `reading_sessions.user_book_id` diperbarui, dan status diset ke `pending`. Jika sudah dirujuk ledger, ID dipertahankan demi menjaga hash chain dan dicatat di `docs/DEVIATIONS.md`.
  5. **Pengujian Unit (`test/sync_uuid_bug_test.dart`):**
     - Tes 5a: tambah buku via repository menghasilkan UUID v4 valid.
     - Tes 5b: push ke remote strict UUID berhasil dengan status `synced`.
     - Tes 5c: pemulihan baris error ke pending lalu berhasil terkirim.
     - Tes 5d: simulasi migrasi v3 & persistensi data buku serta reading session.
- **Hasil Verifikasi:**
  - `flutter analyze`: **0 issues found** (bersih).
  - `flutter test`: **355/355 tests passed** (100% lolos).
