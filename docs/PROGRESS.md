# PROGRESS.md — Status Pengerjaan StoryLoka

Dokumen ini mencatat kemajuan pengerjaan proyek StoryLoka per fase sesuai PRD §13 dan AGENTS.md.

---

## Ringkasan Progres

- **Tahap saat ini:** Tahap B (Backend dan Integrasi)
- **Fase terakhir selesai:** Fase B3 — Google Books, Scan Barcode, Shake
- **Fase selanjutnya:** Fase B4 — Integrasi Lanjutan

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
  - *Bukti:* `lib/data/repositories/supabase/supabase_repositories.dart` (`SupabaseAuthRepository`), RPC PostgreSQL `register_user`, `login_user`, `logout_session` dengan bcrypt salt di database Supabase tanpa Firebase/supabase.auth; sesi disimpan terenkripsi di `FlutterSecureStorage` (`SecureSessionStore`); teruji di `test/fase_a1_test.dart`, `test/fase_b2_test.dart`, `test/widget_test.dart`.
- [x] **Biometrik aktif/nonaktif dan dipakai saat membuka aplikasi.**
  - *Bukti:* `lib/core/services/biometric_service.dart` (`local_auth`), `MainActivity.kt` (`FlutterFragmentActivity`), switch biometrik di `ProfilePage`, dan penguncian di `LockScreenPage`; teruji di `test/fase_a1_test.dart` & `test/fase_b2_test.dart`.
- [x] **Cari Title/Author/ISBN, scan barcode, shake to discover.**
  - *Bukti:* `lib/data/repositories/remote/google_books_repository.dart` (`intitle:`, `inauthor:`, `isbn:`), `lib/features/add_book/scan_page.dart` (`mobile_scanner` EAN-13), dan `lib/core/services/sensor_service.dart` (shake accelerometer > 25 m/s²); teruji di `test/fase_b3_test.dart`.
- [x] **Add to Collection/Wishlist tanpa duplikat; tombol berubah jadi "Added to …".**
  - *Bukti:* `SearchBookDetailPage` (`_handleAddToCollection`, `_handleAddToWishlist`) yang memeriksa status buku di `LibraryRepository` dan mengubah label tombol; teruji di `test/fase_a2_test.dart` & `test/fase_b1_test.dart`.
- [x] **Wishlist → Add to Collection memindahkan buku.**
  - *Bukti:* `LocalLibraryRepository.moveToCollection`, tombol aksi di `WishlistBookDetailPage` memindahkan buku ke koleksi dengan mereset status baca; teruji di `test/fase_a3_test.dart` & `test/fase_b1_test.dart`.
- [x] **Start Reading → Timer → Finish → Progress → Save/Finished → Finished Book → Home.**
  - *Bukti:* Alur membaca wall-clock stopwatch di `ReadingTimerPage`, update progres halaman di `ReadingProgressPage`, dan rating/review dialog buku selesai; teruji di `test/fase_a4_test.dart`.
- [x] **Currently Reading berganti sesuai buku terakhir yang dimulai; kosong setelah diselesaikan.**
  - *Bukti:* `HomePage` (`_buildCurrentlyReadingSection`) dan `LocalLibraryRepository.getCurrentlyReading` merespon reaktif terhadap sesi membaca dan status `finished`; teruji di `test/fase_a3_test.dart` & `test/fase_a4_test.dart`.
- [x] **Rating/review hanya bisa diisi setelah buku selesai.**
  - *Bukti:* Form bintang 1–5 dan ulasan hanya aktif saat buku selesai di `ReadingProgressPage` dan tersimpan di database; teruji di `test/fase_a4_test.dart` & `test/fase_b1_test.dart`.
- [x] **Open Maps (izin diberi dan ditolak/lokasi manual).**
  - *Bukti:* `lib/core/services/location_service.dart` (`geolocator` GPS, intent URI `geo:` dan web maps fallback), dialog izin, bottom sheet pencarian manual jika ditolak, serta shortcut pengaturan jika ditolak permanen; teruji di `test/fase_b5_test.dart`.
- [x] **Konversi mata uang (≥3) dan waktu (WIB/WITA/WIT/London) benar.**
  - *Bukti:* `CurrencyConverterPage` (USD, IDR, EUR, GBP, JPY via live API `open.er-api.com` + cache 12 jam) dan `TimeConverterPage` (paket `timezone` dengan penyesuaian DST otomatis London); teruji di `test/fase_a5_tools_test.dart` & `test/fase_b5_test.dart`.
- [x] **AI Chat menjawab seputar buku dan menangani error.**
  - *Bukti:* `GeminiChatRepository` (endpoint REST Generative Language v1beta, systemInstruction teman baca, batas 10 pesan riwayat, penanganan error 400/403/429/offline, dan retensi input teks); teruji di `test/fase_b5_test.dart`.
- [x] **Snake dapat dimainkan, skor tersimpan, pause otomatis saat background.**
  - *Bukti:* `SnakeEngine` (grid 20×20, buku sebagai makanan vektor), `SnakePage` (auto-pause on lifecycle background), skor tersimpan ke `LocalScoreRepository`; teruji di `test/fase_a5_tools_test.dart` & `test/fase_b1_test.dart`.
- [x] **Kesan & Pesan tersimpan dan langsung tampil.**
  - *Bukti:* `FeedbackPage` dengan form nama, kesan, dan pesan tersimpan ke SQLite via `LocalFeedbackRepository` dan reaktif ditampilkan; teruji di `test/fase_a5_tools_test.dart` & `test/fase_b1_test.dart`.
- [x] **Notifikasi pengingat dan stopwatch bekerja.**
  - *Bukti:* `NotificationService` (`flutter_local_notifications` 22.x, pengingat harian `zonedSchedule` dengan judul "Waktunya membaca", stopwatch sesi ongoing dengan `usesChronometer` dan timestamp mulai); teruji di `test/fase_b6_test.dart`.
- [x] **Tema Light/Dark/Auto bekerja.**
  - *Bukti:* `ThemeController`, `LightSensorService` (moving average 3s, hysteresis <10 lux dark, >40 lux light, jeda 5s), SegmentedButton di `ProfilePage`; teruji di `test/fase_a6_test.dart` & `test/fase_b6_test.dart`.
- [x] **Reading Ledger menambah blok saat selesai; Verify Ledger mendeteksi data yang diubah.**
  - *Bukti:* `LedgerService` (SHA-256 kanonikal, PoW prefix `"00"`, genesis block, verifikasi integritas rantai blok), tersimpan di SQLite, dan tombol Verify di `ReadingLedgerPage`; teruji di `test/fase_a4_test.dart` & `test/fase_b1_test.dart`.
- [x] **Data offline tersinkron ke Supabase; login perangkat baru menarik data.**
  - *Bukti:* `SyncService` (`pushPending` berurutan sesuai PRD §8.3, `pullAll` last-write-wins berdasarkan `updated_at`, upload avatar ke Storage, integrasi login/resume/logout/pull-to-refresh); teruji di `test/fase_b4_test.dart`.

### Kualitas
- [x] **Tidak ada data palsu yang tampil sebagai data nyata; tidak ada secret di repository.**
  - *Bukti:* `AppConfig.useFakeData = false` secara default; `DemoModeChip` disembunyikan; data buku bersumber dari Google Books API nyata; harga kosong menampilkan "Harga tidak tersedia"; `.env` tercantum di `.gitignore` dan diakses hanya lewat `Env` (`env.dart`). Teruji di `test/fase_b7_test.dart`.
- [x] **Spacing, radius, tipografi, tombol, dan nav konsisten dengan Bagian 4.**
  - *Bukti:* `AppSpacing` (24 page margin, 16 gap/card padding), `cardRadius: 20`, `buttonRadius: 14`, font Fraunces & DM Sans, `PrimaryButton` 48px Deep Teal, Bottom Navigation 5-tab dengan tombol Add 56px Soft Apricot; teruji di `test/fase_a7_test.dart`.
- [x] **Setiap layar punya state loading/empty/error.**
  - *Bukti:* Home, Library, Add Book, Tools, Profile, Feedback, Snake, AI Chat, Detail Buku seluruhnya memiliki penanganan state `loading` (CircularProgressIndicator), `empty` (pesan editorial), dan `error` (pesan ramah + tombol coba lagi); teruji di `test/fase_a7_test.dart`.
- [x] **Tidak ada overflow di 360×640 dan skala teks 1.3.**
  - *Bukti:* Seluruh 8 layar utama diuji dan lulus uji rendering pada resolusi 360×640 px dengan `textScale: 1.3` tanpa RenderFlex overflow; teruji di `test/fase_a7_test.dart`.
- [x] **`flutter analyze` bersih; semua tes lolos; APK debug berhasil dibuild.**
  - *Bukti:* `flutter analyze` exit 0 (0 issues found), `flutter test` exit 0 (133/133 tests passed), `flutter build apk --debug` menghasilkan `build\app\outputs\flutter-apk\app-debug.apk`.
- [x] **`docs/PROGRESS.md` dan `docs/DEVIATIONS.md` lengkap.**
  - *Bukti:* Seluruh dokumentasi Fase A0–A7 dan B1–B7 lengkap dan terverifikasi.
