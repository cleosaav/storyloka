# PRD — StoryLoka (Final, siap implementasi)

**Platform:** Flutter (Dart 3) — target utama Android, iOS sekunder
**Backend/DB online:** Supabase (Postgres + REST/RPC + Storage) — **tanpa Firebase, tanpa Supabase Auth**
**DB lokal:** SQLite (`sqflite`)
**LLM:** Gemini API (REST)
**Mini game:** Snake (apel diganti buku)
**Bahasa UI aplikasi:** Indonesia untuk teks sistem, istilah fitur tetap Inggris sesuai desain (Home, Library, Add Book, Tools, Profile, Currently Reading, My Collection, My Wishlist, dll.)

---

## 0. Petunjuk untuk AI Coding Agent (BACA DULU)

Dokumen ini adalah sumber kebenaran tunggal. Kerjakan **berurutan per fase** (Bagian 13). Pengerjaan dibagi dua tahap: **Tahap A (frontend dengan data demo)** lebih dulu, baru **Tahap B (backend dan integrasi)**. Setelah tiap fase: jalankan `flutter analyze`, jalankan test yang relevan, perbaiki, lalu lanjut.

**Aturan keras:**
1. **Jangan mengubah alur** (Bagian 7). Alur sudah final; boleh melengkapi detail, tidak boleh menambah/menghapus layar utama atau mengubah urutan navigasi.
2. **Jangan memakai Firebase** (Auth, Firestore, apa pun). Supabase hanya dipakai sebagai database/RPC/Storage; **jangan memakai `supabase.auth`**.
3. **Jangan mengarang data.** Tidak ada buku/harga/lokasi/skor palsu yang tampil sebagai data nyata. *Satu-satunya pengecualian:* data demo selama Tahap A, yang wajib diberi label "Mode demo" dan dihapus dari alur nyata di Tahap B (aturan di 13.0). Data buku hanya dari Google Books API; harga hanya dari field API, jika kosong tampilkan "Harga tidak tersedia".
4. **Jangan hardcode secret.** Semua key dari `.env` (di-`.gitignore`), sediakan `.env.example`.
5. **Local-first (mulai Tahap B):** UI selalu membaca/menulis ke SQLite; sinkronisasi ke Supabase di belakang layar. Di Tahap A, UI hanya berbicara ke abstract repository (13.0) sehingga peralihan ke SQLite/Supabase tidak mengubah tampilan.
6. Ikuti design tokens di Bagian 4. Jangan menambah warna baru tanpa alasan. Semua warna/spacing/radius lewat konstanta tema, bukan angka mentah di widget. **Prioritas sumber visual: `design-system.md` (token di Bagian 4) > wireframe/mockup.** Wireframe/mockup hanya dipakai untuk struktur layar, urutan elemen, dan isi konten; jika warna, ukuran, atau gaya komponen di wireframe berbeda dari design system, **ikuti design system**.
7. Setiap layar berbasis data wajib punya state: **loading, empty, error (+retry), success**.
8. Paket di Bagian 2: gunakan versi terbaru yang kompatibel (`flutter pub add`). Jika sebuah paket bermasalah/tidak kompatibel, pakai alternatif setara dan catat di `docs/DEVIATIONS.md`.
9. Setelah selesai tiap fase, ringkas hasil di `docs/PROGRESS.md` (apa selesai, apa yang belum, penyimpangan).
10. Jika ada hal yang ambigu, **ambil keputusan paling sederhana yang konsisten dengan dokumen ini** dan catat di `docs/DEVIATIONS.md`. Jangan berhenti untuk bertanya kecuali ada konflik langsung antar bagian.

**Yang disiapkan pemilik proyek (di luar tugas agent, hanya dibutuhkan saat masuk Tahap B):** buat project Supabase, jalankan SQL di Lampiran A, isi `.env` (Supabase URL + anon key + Gemini API key).

---

## 1. Ringkasan Produk

**StoryLoka** adalah aplikasi *personal book management* dan *reading companion*.

**Tujuan aplikasi**
1. Menemukan dan mencari buku yang ingin dibaca.
2. Menyimpan koleksi buku.
3. Menyimpan wishlist buku.
4. Melakukan tracking pada buku yang dibaca.

**Bukan cakupan:** fitur sosial, pembelian buku di dalam aplikasi, e-reader (tombol "Read" hanya membuka Reading Timer).

---

## 2. Tech Stack dan Paket

| Kebutuhan | Paket |
|---|---|
| State management | `provider` (ChangeNotifier) |
| Routing | `go_router` (`StatefulShellRoute` untuk bottom nav) |
| Backend online | `supabase_flutter` (hanya `.from()`, `.rpc()`, `.storage`) |
| DB lokal | `sqflite`, `path`, `path_provider` |
| Session aman | `flutter_secure_storage` |
| Pengaturan sederhana | `shared_preferences` |
| Env | `flutter_dotenv` |
| HTTP | `http` |
| Biometrik | `local_auth` |
| Scan barcode | `mobile_scanner` |
| Sensor | `sensors_plus` (accelerometer, gyroscope), `light_sensor` (sensor cahaya, Android) — *verifikasi di pub.dev; jika bermasalah lihat 10.4* |
| Lokasi | `geolocator` |
| Buka Maps/URL | `url_launcher` |
| Notifikasi | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| Foto profil | `image_picker` |
| UI | `google_fonts` (Fraunces, DM Sans), `cached_network_image` |
| Util | `intl`, `uuid`, `crypto` |

---

## 3. Konfigurasi dan Secrets

`.env.example` (salin menjadi `.env`, daftarkan `.env` di `pubspec.yaml` bagian `assets`, dan di `.gitignore`):

```
SUPABASE_URL=
SUPABASE_ANON_KEY=
GEMINI_API_KEY=
GEMINI_MODEL=gemini-flash-latest
GOOGLE_BOOKS_API_KEY=
```

- `GOOGLE_BOOKS_API_KEY` opsional (kosong = tanpa key).
- Buat `lib/core/config/env.dart` sebagai satu-satunya titik akses ke `.env`.
- Jika `SUPABASE_URL`/`SUPABASE_ANON_KEY` kosong, tampilkan layar error konfigurasi yang jelas (bukan crash).
- Catatan jujur untuk dokumentasi: API key Gemini yang tertanam di aplikasi mobile bisa diekstrak; ini diterima untuk proyek kuliah.

---

## 4. Design System (ringkas, wajib diikuti)

Konsep: **Cozy Editorial × Soft Botanical × Warm Minimalism**. Hindari neon, gradient mencolok, shadow berat, dan tampilan dashboard generik.

### 4.1 Token Warna (Light)

| Token | HEX | Pemakaian |
|---|---|---|
| `warmIvory` | `#FAF6EF` | Background utama |
| `deepTeal` | `#164E59` | Primary button, nav aktif, ikon utama |
| `oceanTeal` | `#245C67` | Aksen teal sekunder |
| `softApricot` | `#F5B65D` | Highlight, indikator, progress, tombol Add tengah |
| `palePeach` | `#FBE9D7` | Notes/supporting card |
| `sageGreen` | `#A8BDA8` | Ilustrasi, badge, pendukung |
| `ink` | `#26383A` | Teks utama |
| `mutedGray` | `#859395` | Teks sekunder, ikon nonaktif |
| `white` | `#FFFFFF` | Card/input yang perlu kontras |
| `borderNeutral` | `#E4E2DA` | Border/divider |
| `trackNeutral` | `#E3E7DF` | Track progress bar |
| `error` | `#B54747` | Error/destruktif |
| `success` | `#3F7658` | Sukses |

### 4.2 Token Warna (Dark) — **turunan baru, catat sebagai penyimpangan terdokumentasi**

| Token | HEX |
|---|---|
| `bgDark` | `#101819` |
| `surfaceDark` | `#1A2527` |
| `borderDark` | `#2C3B3D` |
| `inkDark` | `#F2EDE3` |
| `mutedDark` | `#8FA0A2` |
| `primaryDark` (tombol primer, teks putih) | `#2F7F8C` |
| `trackDark` | `#2A3638` |

`softApricot`, `sageGreen`, `error`, `success` dipakai sama di dark mode.

### 4.3 Tipografi
- **Fraunces SemiBold:** page heading (30), judul buku detail (24), section heading (20), card heading (18), stopwatch/angka besar (48–80).
- **DM Sans:** body 16 (Regular), tombol 14–16 (Medium), metadata 14, caption 12 (Medium).
- Sentence case; uppercase hanya label kecil (mis. CURRENTLY READING). Line height heading 1.2–1.3, body 1.4–1.6. Judul buku di card maksimal 2 baris. Jangan pakai serif untuk paragraf panjang/form/metadata.

### 4.4 Spacing, Radius, Ukuran
- Spacing: XS 4, S 8, M 12, L 16, XL 24, XXL 32.
- Margin horizontal halaman **24**; padding card **16**; radius card **20**; radius input **12–14**; radius tombol **14–16**; tinggi input dan tombol **48**; target sentuh ≥ **44×44**.
- Jarak antarseksi utama 24–32; dalam grup 8–16.
- Respect safe area; tanpa tinggi fixed untuk konten yang bisa tumbuh.

### 4.5 Komponen (buat reusable di `core/widgets/`)
- `PrimaryButton` (Deep Teal, teks putih, 48; aksi utama seperti Add to Collection, Start Reading, Read, Login, Save, Open Maps), `SecondaryButton` (outline 1px Deep Teal, teks Deep Teal; aksi pendamping seperti Add to Wishlist, Update, Update Progress), `TertiaryButton`, `AppIconButton` (≥44).
- `AppCard` (default putih/ivory, radius 20, padding 16, shadow sangat lembut atau border neutral), `NotesCard` (Pale Peach), `SupportCard` (Sage lembut), `EmptyStateCard` (ilustrasi kecil + pesan singkat + satu aksi utama).
- `BookCover` (rasio **2:3**, tidak boleh diregangkan; placeholder sage + ikon buku jika cover tidak ada).
- `BookCard` (cover, judul max 2 baris Fraunces, penulis DM Sans, bintang rating jika ada, badge status).
- `ReadingProgressBar` (tinggi 6, ujung rounded, fill Deep Teal, track `trackNeutral`; Soft Apricot boleh sebagai aksen kecil), selalu dengan teks "x / y pages" dan persen.
- `AppChip` (pill, tinggi 32–36, selected = Deep Teal + teks putih), `FilterTabs` (Collection | Wishlist / Title | Author | ISBN).
- `AppTextField` (48, radius 12–14, border neutral, fokus Deep Teal, pesan error terlihat).
- `StatusBadge` (teks + warna; **jangan mengandalkan warna saja**): "Belum dibaca", "Sedang dibaca", "Selesai".
- Ikon: satu keluarga outline (Material Symbols Rounded/Outlined, stroke seragam). Filled untuk state aktif. **Jangan campur emoji dengan ikon UI.**
- Ilustrasi: dibuat dengan `CustomPainter`/SVG sederhana (buku, daun) dalam warna Sage + Deep Teal, apricot hanya aksen kecil; hanya di empty state, Reading Timer, supporting card. Tidak boleh di belakang teks/tombol penting.

### 4.6 Bottom Navigation
5 item: **Home, Library, Add (tombol tengah), Tools, Profile**.
- Surface putih (dark: `surfaceDark`), aktif Deep Teal, nonaktif Muted Gray, indikator aktif kecil apricot.
- **Add** = tombol pill/lingkaran apricot 56px dengan ikon `+` (teal gelap), sedikit menonjol di tengah.
- Sisakan bottom safe area. Semua item punya `Semantics` label.

### 4.7 Tema
`ThemeMode` mendukung `light`, `dark`, `auto` (Bagian 10.4). Semua widget membaca warna dari `Theme`/`AppColors` yang sadar tema.

### 4.8 Ketidakkonsistenan di sumber desain — keputusan final
| Temuan | Keputusan |
|---|---|
| Wireframe Home memakai label "Buku dibaca" tiga kali | Ganti menjadi **Koleksi**, **Sedang dibaca**, **Selesai** |
| Wireframe Book Detail punya dua tombol berlabel "Add to Collection" | Tombol kedua = **Add to Wishlist** |
| Wireframe memakai tombol apricot untuk aksi utama | **Ikuti design system**: primary = Deep Teal (Add to Collection, Start Reading, Read, dst.); secondary = outline teal; apricot hanya aksen (indikator, aksen progress) dan tombol Add tengah di bottom nav |
| Teks alur Library nomor 2 dan 3 sama-sama "filter Collection" | Nomor 2 = Collection (judul, penulis, **status**); nomor 3 = **Wishlist** (judul, penulis) |
| Tools: teks "3 card horizontal" vs wireframe 5 card vertikal | Ikuti wireframe terbaru: **5 card vertikal** (Kesan & Pesan, AI Chat, Mini Games, Konversi Mata Uang, Konversi Waktu) |
| Harga "10000" di wireframe | Hanya placeholder; harga nyata dari API |
| Dropdown konversi harga di Book Detail | Alur menyebut boleh dilepas bila sulit. **Keputusan: konversi hanya di menu Tools** (Bagian 7.7). Dropdown di Book Detail = *stretch goal* di akhir |

---

## 5. Arsitektur dan Struktur Folder

Pola: **feature-first + repository**. UI → Provider → Repository → (LocalDao + RemoteApi).

```
storyloka/
├─ .env.example
├─ docs/ (PROGRESS.md, DEVIATIONS.md)
├─ supabase/schema.sql          # salinan Lampiran A
├─ lib/
│  ├─ main.dart                  # init dotenv, supabase, timezone, notifikasi, DB, runApp
│  ├─ app/
│  │  ├─ app.dart                # MaterialApp.router, tema
│  │  ├─ router.dart             # go_router
│  │  └─ main_shell.dart         # scaffold + bottom nav
│  ├─ core/
│  │  ├─ config/env.dart
│  │  ├─ theme/ (app_colors.dart, app_text.dart, app_spacing.dart, app_theme.dart)
│  │  ├─ widgets/ (komponen Bagian 4.5)
│  │  ├─ utils/ (validators.dart, date_utils.dart, html_strip.dart)
│  │  └─ services/
│  │     ├─ database_helper.dart       # sqflite
│  │     ├─ supabase_client.dart
│  │     ├─ secure_session_store.dart
│  │     ├─ sync_service.dart
│  │     ├─ notification_service.dart
│  │     ├─ sensor_service.dart        # shake + light
│  │     ├─ biometric_service.dart
│  │     └─ location_service.dart
│  ├─ data/
│  │  ├─ models/ (app_user, book, user_book, reading_session, ledger_block, feedback_entry, game_score, chat_message)
│  │  ├─ local/ (dao per tabel)
│  │  ├─ remote/ (supabase_api.dart, google_books_api.dart, currency_api.dart, gemini_api.dart)
│  │  └─ repositories/ (auth_, book_, reading_, ledger_, feedback_, score_, chat_, currency_repository)
│  └─ features/
│     ├─ auth/ (splash, login, register, lock_screen)
│     ├─ home/
│     ├─ library/
│     ├─ add_book/ (add_book_page, scan_page)
│     ├─ book_detail/ (search_detail, collection_detail, wishlist_detail)
│     ├─ reading/ (timer, progress, finished)
│     ├─ tools/ (tools_page, feedback, ai_chat, snake/, currency, time_converter)
│     ├─ profile/ (profile_page, edit_profile, ledger_page)
│     └─ ledger/ (ledger_service.dart)  # logika blockchain murni
└─ test/
```

---

## 6. Navigasi dan Routes

```
/splash
/login            /register            /lock
Shell (StatefulShellRoute, 5 cabang):
  /home            (cabang 0)
  /library?filter=collection|wishlist   (cabang 1)
  /add             (cabang 2)
  /tools           (cabang 3)
  /profile         (cabang 4)
Di atas shell (push):
  /scan
  /book/search                 extra: hasil API (BookResult)
  /book/collection/:id         id = user_books.id
  /book/wishlist/:id
  /reading/timer/:id
  /reading/progress/:id
  /reading/finished/:id
  /tools/feedback   /tools/ai-chat   /tools/games   /tools/currency   /tools/time
  /profile/edit     /profile/ledger
```

**Redirect guard:** tanpa session → `/login`; ada session + biometrik aktif + belum lolos kunci → `/lock`; selainnya normal.

---

## 7. Spesifikasi Alur per Layar

### 7.1 ALUR 1 — Autentikasi dan Struktur Utama

**Splash:** logo/nama StoryLoka (Fraunces) + ilustrasi daun kecil; cek session di secure storage.
- Tidak ada session → `/login`.
- Ada session → (jika biometrik aktif → `/lock`, selainnya → `/home`). Validasi token ke server di latar belakang bila online; jika server menyatakan tidak valid → logout paksa dengan pesan "Sesi berakhir, silakan login lagi". Jika offline → percaya session lokal.

**Register:** field nama, email, password, konfirmasi password. Validasi: nama wajib; email format valid; password ≥ 8 karakter; konfirmasi sama. Panggil RPC `register_user`. Error `EMAIL_TAKEN` → "Email sudah terdaftar". Sukses → simpan session, buat **genesis block** ledger lokal, masuk `/home`. Cegah submit ganda (tombol loading/disabled).

**Login:** email + password, tombol "Login", link ke Register. Panggil RPC `login_user`. Error `INVALID_CREDENTIALS` → "Email atau password salah". Sukses → simpan session, tarik data pengguna dari server (`SyncService.pullAll`), masuk `/home`. Input tidak hilang saat error.

**Enkripsi:** password di-hash **di server (bcrypt via pgcrypto)** di dalam RPC; password tidak pernah disimpan teks asli dan tidak pernah dicatat di log. Komunikasi HTTPS (default Supabase).

**Session:** token acak 32-byte (hex) dibuat server, berlaku 30 hari, disimpan di `flutter_secure_storage` bersama JSON profil singkat. Logout menghapus token di server (RPC `logout_session`) dan lokal.

**Lock screen (biometrik):** ditampilkan jika session ada dan biometrik aktif di perangkat. Otomatis memunculkan prompt `local_auth`. Tombol "Coba lagi" dan "Login dengan password" (menghapus session lokal → `/login`). Biometrik tidak tersedia → toggle di Profile dinonaktifkan dengan keterangan.

**Main shell:** bottom nav 5 tab: Home, Library, Add, Tools, Profile. State tiap tab dipertahankan.

### 7.2 ALUR 2 — Home

Urutan dari atas:
1. **Header sapaan:** "Hello, {nama}!" (Fraunces 30), subteks "Mau baca apa hari ini?", avatar profil (tap → tab Profile). Avatar tanpa foto = lingkaran apricot dengan inisial.
2. **Card Reading Summary:** 3 angka besar (Fraunces) dengan label di bawah: **Koleksi** (jumlah `list_type=collection`), **Sedang dibaca** (`status=reading`), **Selesai** (`status=finished`).
3. **Card Currently Reading** (judul seksi "Currently Reading"):
   - **Kondisi 1 (kosong):** ilustrasi buku terbuka + teks "Start Your Reading Journey" / "Your next favorite book is waiting for you." + tombol **Add Book** → pindah ke tab Add (`/add`).
   - **Kondisi 2 (ada):** cover (min 80×120), judul, penulis, progress bar + "{current_page}/{page_count} pages" + persen, tombol **Read** (→ `/reading/timer/:id`) dan **Update** (→ `/reading/progress/:id`).
   - **Sumber data:** buku `status = reading` dengan `last_read_at` terbaru. Berganti otomatis tiap pengguna menekan **Start Reading** pada buku lain.
4. **Card My Collection:** judul + tombol "See all →" (→ `/library?filter=collection`). Kosong: pesan + tombol Add Book. Terisi: deretan **3 cover** terbaru (cover saja, rasio 2:3).
5. **Card My Wishlist:** sama; "See all →" → `/library?filter=wishlist`.

Pull-to-refresh memicu `SyncService.syncNow()`.

### 7.3 ALUR 3 — Add Book dan Book Detail (dari pencarian)

**Add Book (`/add`):**
- Header "Add a Book" dengan tombol back.
- **Search bar** dengan placeholder dinamis ("Search books by title/author/ISBN") + ikon **shake to discover** di sampingnya.
- **Filter tabs:** Title | Author | ISBN (default Title).
- Baris **Scan Barcode** ("Find a book by scanning its ISBN") → `/scan`.
- **State awal:** ilustrasi tumpukan buku + "Discover Books" + "Search by title, author, or ISBN to find your next read."
- **Hasil:** grid 3 kolom `BookCard` (cover, judul, penulis). Pencarian dengan debounce 500 ms, minimal 2 karakter, `maxResults=20`. State: loading (skeleton), kosong ("Buku tidak ditemukan, coba kata kunci lain"), error jaringan (+ tombol Coba lagi).
- Tap card → `/book/search` (membawa data hasil API).

**Scan Barcode (`/scan`):** `mobile_scanner`, hanya format EAN-13/ISBN (awalan 978/979). Kamera izin ditolak → penjelasan + input ISBN manual. Setelah terbaca → cari `isbn:{kode}` → buka detail jika ada hasil, jika tidak → "ISBN tidak ditemukan".

**Shake to Discover:** aktif hanya saat halaman Add Book tampil (stream dihentikan saat keluar). Deteksi: magnitudo accelerometer `sqrt(x²+y²+z²) > 25 m/s²`, debounce 1,5 detik, getaran haptic singkat. Aksi: ambil buku acak dari Google Books dengan kata kunci acak dari daftar subjek (`fiction, fantasy, romance, history, science, mystery, philosophy, business, biography, self-improvement`) dan `startIndex` acak 0–30; pilih satu hasil acak yang punya judul → buka `/book/search`. Tombol ikon shake juga bisa ditekan sebagai alternatif (untuk aksesibilitas/emulator).

**Book Detail — dari pencarian (`/book/search`):**
- Header back + "Book Detail". Cover besar (rasio 2:3, lebar ~140), judul (Fraunces 24), penulis, chip genre, detail lain (ISBN, penerbit, jumlah halaman jika ada).
- Dua tombol (rata tepat di bawah cover): **Add to Collection** (primary) dan **Add to Wishlist** (secondary).
  - Tekan Add to Collection → buku tersimpan `list_type=collection`, `status=not_started`; tombol menjadi **Added to Collection** (disabled); tampil snackbar sukses. Buku otomatis muncul di Library filter Collection.
  - Tekan Add to Wishlist → `list_type=wishlist`; tombol menjadi **Added to Wishlist** (disabled).
  - Jika buku sudah ada di wishlist lalu ditekan Add to Collection → **dipindahkan** ke collection (wishlist button kembali nonaktif/hilang).
  - Jika sudah ada di collection → tombol Add to Wishlist dinonaktifkan.
  - **Tidak boleh duplikat**: unik per `(user_id, google_books_id)`; baris yang pernah dihapus (`is_deleted=1`) dihidupkan kembali.
- Card **Synopsis:** teks (HTML dibersihkan), maksimal 6 baris + tombol tersier **Read More** (expand/collapse). Kosong → "Sinopsis tidak tersedia".
- Card **Book Price:** label "Book Price", subteks penerbit/edisi bila ada, nilai dengan format mata uang aslinya (mis. `Rp 85.000`). Tidak tersedia → "Harga tidak tersedia".
- Card **Find Nearby Bookstores** ("Open Maps to find nearby sellers and browse in person.") + tombol **Open Maps** (lihat 9.4).

### 7.4 ALUR 4 — Membaca (Currently Reading)

**Book Detail — Collection (`/book/collection/:id`):**
- Cover, judul, penulis, genre, detail.
- 2 tombol: **Start Reading** (primary) dan **Update Progress** (secondary).
- Card **Reading Status:** progress bar + "{current_page}/{page_count} pages" + persen + badge status.
- Card **Synopsis** (Read More).
- Card **Your Rating:** bintang 1–5 + kolom review. **Aktif/bisa diisi hanya setelah status = finished**; sebelum itu tampil nonaktif dengan teks "Selesaikan buku ini untuk memberi review". Tombol Save → update `rating` dan `review`.
- Overflow menu: **Remove from library** (dengan dialog konfirmasi; soft delete).

**Start Reading:** set `status=reading`, `started_at` (jika kosong), `last_read_at=now` → buka **Reading Timer**. Buku langsung menjadi Currently Reading di Home.

**Reading Timer (`/reading/timer/:id`):**
- Menampilkan cover kecil + judul + penulis.
- **Stopwatch besar** (Fraunces 48–80, format `HH:MM:SS`) dalam ring Sage dengan ilustrasi daun/buku kecil.
- Kontrol: **Play/Pause** (primary Deep Teal, besar) dan **Finish Reading**. Stopwatch dihitung dari timestamp (bukan sekadar `Timer` increment) agar akurat saat aplikasi di background.
- Saat berjalan dan notifikasi stopwatch aktif di Profile → tampilkan notifikasi ongoing dengan chronometer (10.5).
- **Finish Reading:** hentikan stopwatch, simpan baris `reading_sessions` (durasi > 0 detik), batalkan notifikasi stopwatch, lalu navigasi ke **Reading Progress** (menampilkan durasi sesi barusan).
- Tombol back saat timer berjalan → dialog konfirmasi ("Sesi akan disimpan/dibuang?" — pilihan: Simpan & keluar, Buang, Lanjut membaca).

**Reading Progress (`/reading/progress/:id`):**
- Menampilkan buku, progress bar, input **halaman saat ini** (slider + field angka), "Page X of Y". Jika `page_count` tidak diketahui → tampilkan field **Total pages** yang wajib diisi dulu.
- Validasi: halaman ≥ 0 dan ≤ total halaman.
- Tombol **Save Progress:** simpan `current_page`, set `status=reading` jika > 0 dan belum finished, `last_read_at=now`, progress bar di semua tempat ikut ter-update; snackbar sukses; kembali ke halaman asal.
- Tombol **Finished This Book:** dialog konfirmasi ("Yakin sudah selesai membaca buku ini?" Batal / Ya, selesai). Jika ya → set `status=finished`, `current_page=page_count`, `finished_at=now`, tambahkan **blok ledger** (10.2), navigasi ke **Finished Book**.

**Finished Book (`/reading/finished/:id`):**
- Ucapan selamat (Fraunces) + ilustrasi sederhana (konfeti/daun, tanpa animasi berat), nama buku, ringkasan singkat (total halaman, total durasi baca buku ini dari `reading_sessions`).
- Status buku diperbarui; tombol **Back to Home** dan otomatis kembali ke Home setelah 5 detik jika tidak ditekan (batalkan timer saat halaman ditinggalkan).

**Aturan Currently Reading (Home):**
- Buku belum selesai dan masih berprogress → card Currently Reading menampilkan cover, judul, penulis, progress bar, tombol **Read** (→ Reading Timer) dan **Update** (→ Reading Progress).
- Reading Timer dan Reading Progress juga bisa diakses dari Home (card Currently Reading), bukan hanya dari Book Detail.
- Jika buku yang sedang dibaca diselesaikan dan tidak ada buku `reading` lain → Home kembali ke kondisi kosong.

### 7.5 ALUR 5 — My Collection dan My Wishlist (di Home)
Sudah tercakup di 7.2 butir 4–5. Aturan: "See all" membuka Library dengan filter yang sesuai; card hanya menampilkan **cover** buku yang ditambahkan pengguna (maks 3 terbaru); kosong → empty state + Add Book.

### 7.6 ALUR 6 — Library (`/library`)
- Header "Library", **search bar** (filter lokal berdasarkan judul/penulis dari data pengguna), toggle **Collection | Wishlist** (menghormati query `filter`).
- **Collection:** grid 3 kolom `BookCard` → cover, judul, penulis, rating bintang (jika ada), dan **StatusBadge** (Belum dibaca/Sedang dibaca/Selesai). Tap → `/book/collection/:id`.
- **Wishlist:** grid 3 kolom → cover, judul, penulis. Tap → **Book Detail — Wishlist**.
- Long-press card → opsi hapus (konfirmasi).
- Empty state per filter dengan tombol Add Book.

**Book Detail — Wishlist (`/book/wishlist/:id`):** cover, judul, penulis, genre, detail; **satu** tombol utama **Add to Collection** (memindahkan ke collection lalu snackbar + kembali); card Synopsis; card Book Price; card Find Nearby Bookstores.

### 7.7 ALUR 7 — Tools (`/tools`)
Daftar vertikal 5 card (judul Fraunces, deskripsi singkat DM Sans, ikon outline, chevron):

1. **Kesan & Pesan** (`/tools/feedback`) — memenuhi ketentuan "saran dan kesan mata kuliah Pemrograman Aplikasi Mobile".
   - Form: **Nama** (prefill nama pengguna), **Kesan**, **Pesan**. Semua wajib (validasi).
   - Simpan → tulis ke SQLite + sinkron ke Supabase; hasil langsung tampil sebagai daftar di bawah form (terbaru di atas; nama, kesan, pesan, tanggal). Cegah submit ganda; form dikosongkan setelah sukses.
2. **AI Chat** (`/tools/ai-chat`) — lihat 9.3.
3. **Mini Games** (`/tools/games`) — **Snake** (10.1). Layar ini langsung berisi kartu game Snake dengan skor tertinggi pengguna, tombol Play.
4. **Konversi Mata Uang** (`/tools/currency`) — lihat 9.2.
5. **Konversi Waktu** (`/tools/time`) — lihat 9.5.

> Konversi mata uang dan waktu **berdiri sendiri di menu Tools** (tidak digabung ke Book Detail), sesuai catatan alur.

### 7.8 ALUR 8 — Profile (`/profile`)
- **Header:** foto profil (lingkaran, tap untuk ganti), nama, email, bio singkat, tombol **Edit Profil**.
- **Ringkasan buku:** "{n} di koleksi • {m} wishlist • {k} selesai" + total waktu membaca (dari `reading_sessions`, format `Xj Ym`).
- **Edit Profil (`/profile/edit`):** ubah nama, bio, foto (kamera/galeri via `image_picker`, kompres ≤ 800 px, simpan lokal di folder aplikasi dan upload ke Supabase Storage bucket `avatars` bila online → `avatar_url`). Simpan memanggil RPC `update_profile` (antre bila offline). Validasi nama wajib.
- **Login biometrik:** switch. Mengaktifkan → minta autentikasi biometrik dulu; sukses → simpan flag lokal (`shared_preferences`, per perangkat, bukan di server). Tidak tersedia/tidak terdaftar → switch nonaktif + teks penjelasan.
- **Notifikasi:**
  - **Pengingat membaca:** switch + pemilih jam (default 20:00). Jadwal harian lewat notifikasi lokal. Meminta izin notifikasi saat pertama kali diaktifkan dengan penjelasan tujuan.
  - **Notifikasi stopwatch:** switch (menampilkan notifikasi ongoing saat sesi membaca berjalan; 10.5).
- **Tampilan:** pilihan **Light / Dark / Auto** (segmented). Auto memakai sensor cahaya (10.4).
- **Reading Ledger** (`/profile/ledger`) — 10.2.
- **Logout:** dialog konfirmasi → coba `syncNow()` dulu; jika masih ada data pending, beri peringatan ("Ada data belum tersinkron, tetap logout?") → hapus token server, session, dan data lokal pengguna → `/login`.

---

## 8. Data

### 8.1 SQLite (lokal) — `database_helper.dart`, versi 1
Semua `id` adalah **UUID v4 dibuat di klien** (agar bisa dibuat offline). Waktu disimpan sebagai ISO-8601 UTC string. Kolom `sync_status` ∈ (`pending`, `synced`).

```sql
CREATE TABLE user_books (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  google_books_id TEXT NOT NULL,
  title TEXT NOT NULL,
  authors TEXT,
  genre TEXT,
  isbn TEXT,
  publisher TEXT,
  page_count INTEGER,
  cover_url TEXT,
  synopsis TEXT,
  price_amount REAL,
  price_currency TEXT,
  list_type TEXT NOT NULL CHECK (list_type IN ('collection','wishlist')),
  status TEXT NOT NULL DEFAULT 'not_started' CHECK (status IN ('not_started','reading','finished')),
  current_page INTEGER NOT NULL DEFAULT 0,
  rating INTEGER,
  review TEXT,
  started_at TEXT,
  finished_at TEXT,
  last_read_at TEXT,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'pending',
  UNIQUE (user_id, google_books_id)
);

CREATE TABLE reading_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  user_book_id TEXT NOT NULL,
  started_at TEXT NOT NULL,
  ended_at TEXT NOT NULL,
  duration_seconds INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'pending'
);

CREATE TABLE ledger_blocks (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  block_index INTEGER NOT NULL,
  timestamp TEXT NOT NULL,
  data_json TEXT NOT NULL,
  previous_hash TEXT NOT NULL,
  nonce INTEGER NOT NULL,
  hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'pending',
  UNIQUE (user_id, block_index)
);

CREATE TABLE feedbacks (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  impression TEXT NOT NULL,
  suggestion TEXT NOT NULL,
  created_at TEXT NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'pending'
);

CREATE TABLE game_scores (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  game TEXT NOT NULL,
  score INTEGER NOT NULL,
  played_at TEXT NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'pending'
);

-- Hanya lokal (tidak disinkronkan)
CREATE TABLE chat_messages (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('user','model')),
  content TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX idx_user_books_user ON user_books(user_id, list_type, is_deleted);
CREATE INDEX idx_sessions_book ON reading_sessions(user_book_id);
```

**Pengaturan per perangkat** (`shared_preferences`, bukan DB): `biometric_enabled`, `theme_mode`, `reminder_enabled`, `reminder_time`, `stopwatch_notification_enabled`.
**Session + profil singkat:** `flutter_secure_storage` (`session_token`, `user_json`).

### 8.2 Supabase
Skema lengkap + RPC + RLS + Storage ada di **Lampiran A** (salin ke `supabase/schema.sql`). Ringkas:
- `app_users`, `app_sessions` — **tidak bisa diakses langsung** dari klien (RLS aktif tanpa policy); hanya lewat RPC `SECURITY DEFINER`: `register_user`, `login_user`, `validate_session`, `logout_session`, `update_profile`.
- `user_books`, `reading_sessions`, `ledger_blocks`, `feedbacks`, `game_scores` — diakses klien lewat `.from(...)` dengan filter `user_id`.
- Storage bucket publik `avatars`.

> **Batasan keamanan yang diakui (dicatat di `docs/DEVIATIONS.md`):** karena autentikasi custom (tanpa Supabase Auth), database tidak dapat membedakan pengguna lewat JWT, sehingga policy tabel data bersifat permisif untuk peran `anon` dan isolasi data antarpengguna bergantung pada filter `user_id` di klien. Ini diterima untuk proyek kuliah. Jalur penguatan: semua akses data lewat RPC yang memvalidasi `token`.

### 8.3 Strategi Sinkronisasi (`sync_service.dart`)
- **Tulis:** repository menulis ke SQLite dengan `sync_status='pending'` dan `updated_at=now`, lalu memanggil `SyncService.trigger()` (tidak memblokir UI, error ditelan dan dicoba lagi nanti).
- **Push** (`pushPending`): urutan tabel `user_books` → `reading_sessions` → `ledger_blocks` → `feedbacks` → `game_scores`. Kirim baris `pending` dengan `upsert(onConflict: 'id')`; sukses → tandai `synced`. Kegagalan jaringan tidak dianggap error fatal.
- **Pull** (`pullAll(userId)`): dipanggil setelah login/register dan pull-to-refresh (Home/Library). Ambil semua baris milik `user_id` dari server; sisipkan ke SQLite bila belum ada, atau timpa bila `remote.updated_at > local.updated_at` (hanya `user_books`; tabel append-only cukup insert-jika-belum-ada). `ledger_blocks` diurutkan `block_index`.
- **Trigger lain:** saat aplikasi resume ke foreground, setelah operasi tulis, dan saat logout.
- **Hapus:** `user_books` memakai soft delete (`is_deleted=1`, ikut disinkronkan); semua query UI memfilter `is_deleted=0`.
- **Konflik:** *last-write-wins* berdasarkan `updated_at`.
- **Indikator:** teks kecil "Tersinkron / Menunggu sinkron" di Profile (opsional, tidak mengganggu).

---

## 9. Integrasi Eksternal

### 9.1 Google Books API
- Endpoint: `GET https://www.googleapis.com/books/v1/volumes`
- Parameter: `q`, `maxResults=20`, `printType=books`, `startIndex` (untuk shake), `key` (jika ada di `.env`).
- `q`: Title → `intitle:{teks}`; Author → `inauthor:{teks}`; ISBN → `isbn:{kode}` (hapus tanda hubung/spasi). Encode URL.
- Mapping ke model `BookResult`:
  - `google_books_id` ← `id`
  - `title` ← `volumeInfo.title`
  - `authors` ← `volumeInfo.authors` digabung `", "` (kosong → "Penulis tidak diketahui")
  - `genre` ← `volumeInfo.categories[0]`
  - `synopsis` ← `volumeInfo.description` (strip tag HTML)
  - `page_count` ← `volumeInfo.pageCount` (0/null → null)
  - `cover_url` ← `volumeInfo.imageLinks.thumbnail` (ubah `http://` → `https://`)
  - `isbn` ← `industryIdentifiers` (utamakan `ISBN_13`)
  - `publisher` ← `volumeInfo.publisher`
  - `price_amount/currency` ← `saleInfo.retailPrice` atau `saleInfo.listPrice` (`amount`, `currencyCode`); jika tidak ada → null
- Tangani: timeout 15 detik, status non-200, `items` null (hasil kosong).

### 9.2 Konversi Mata Uang
- **Mata uang:** minimal 3; sediakan **IDR, USD, EUR, JPY, SGD** (5).
- Sumber kurs: `GET https://open.er-api.com/v6/latest/{BASE}` (tanpa key). Ambil `rates` dan `time_last_update_utc`.
- UI: field nominal, dropdown "dari" dan "ke", tombol tukar (swap), hasil besar (Fraunces), keterangan "Kurs diperbarui {tanggal}".
- Cache kurs terakhir (SQLite/`shared_preferences`, berlaku 12 jam untuk refresh otomatis). Offline/gagal → pakai cache dengan label "Kurs tersimpan, mungkin tidak terbaru"; tanpa cache → pesan error + Coba lagi. Jangan menampilkan kurs karangan.
- Validasi: nominal angka ≥ 0; format ribuan via `intl`.
- Logika konversi dibuat sebagai fungsi murni agar bisa dites.

### 9.3 AI Chat (Gemini)
- Endpoint: `POST https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent`
- Header: `x-goog-api-key: {GEMINI_API_KEY}`, `Content-Type: application/json`.
- Body:
```json
{
  "systemInstruction": { "parts": [ { "text": "<SYSTEM_PROMPT>" } ] },
  "contents": [
    { "role": "user",  "parts": [ { "text": "..." } ] },
    { "role": "model", "parts": [ { "text": "..." } ] }
  ],
  "generationConfig": { "temperature": 0.7, "maxOutputTokens": 800 }
}
```
- Jawaban: `candidates[0].content.parts[0].text`. Jika `candidates` kosong/diblokir → pesan ramah "Aku belum bisa menjawab itu, coba pertanyaan lain."
- Kirim maksimal **10 pesan terakhir** sebagai konteks.
- `SYSTEM_PROMPT`: *"Kamu adalah asisten StoryLoka, teman membaca yang ramah. Bantu pengguna dengan rekomendasi buku, ringkasan, penjelasan tema/penulis, dan tips membaca. Jawab dengan bahasa yang dipakai pengguna, ringkas dan jelas. Jika pertanyaan di luar topik buku/membaca, tolak dengan sopan dan arahkan kembali. Jangan mengarang judul, penulis, atau fakta; jika tidak yakin, katakan tidak yakin."*
- UI: gelembung chat (pengguna kanan Deep Teal teks putih; asisten kiri Pale Peach/putih), indikator mengetik, input maks 500 karakter, tombol kirim dinonaktifkan saat kosong/loading, chip saran prompt di state kosong ("Rekomendasi novel fantasi", "Tips membaca lebih konsisten", "Jelaskan konsep buku Atomic Habits" — ini saran *prompt*, bukan data buku), tombol hapus riwayat (dengan konfirmasi). Riwayat disimpan di `chat_messages` (lokal saja).
- Error: 400/403 (key salah/kosong) → "Konfigurasi AI belum benar"; 429 → "Terlalu banyak permintaan, coba lagi sebentar"; jaringan → pesan + **Kirim ulang** (teks input tidak hilang).

### 9.4 LBS — Toko Buku Terdekat
- Tombol **Open Maps**: minta izin lokasi (dengan penjelasan "Dipakai untuk mencari toko buku di dekatmu"). Izin diberikan → `Geolocator.getCurrentPosition` → buka `https://www.google.com/maps/search/toko+buku/@{lat},{lng},15z` via `url_launcher` (mode external application).
- **Izin ditolak / lokasi mati:** tampilkan bottom sheet berisi field **lokasi manual** (kota/daerah) → buka `https://www.google.com/maps/search/?api=1&query=toko+buku+di+{lokasi}`; plus tombol "Buka pengaturan" bila ditolak permanen.
- Tidak menyimpan data toko; tidak mengarang hasil.

### 9.5 Konversi Waktu
- Zona (paket `timezone`): **WIB** `Asia/Jakarta`, **WITA** `Asia/Makassar`, **WIT** `Asia/Jayapura`, **London** `Europe/London` (otomatis ikut DST: GMT/BST).
- UI: pilih zona asal (dropdown), pilih tanggal dan jam (picker, default = sekarang), hasil 4 baris kartu (WIB, WITA, WIT, London) dengan jam + tanggal + selisih ("+1 hari" bila berganti hari) dan label offset (mis. `UTC+7`, `UTC+1 (BST)`). Tombol **Sekarang** untuk reset ke waktu saat ini.
- Inisialisasi database timezone (`initializeTimeZones()`) di `main`.
- Logika konversi sebagai fungsi murni agar bisa dites.

---

## 10. Fitur Khusus

### 10.1 Snake — "Book Snake" (`/tools/games`)

**Konsep:** Snake klasik; "apel" diganti **buku** yang dikumpulkan.

**Engine murni Dart** (`snake_engine.dart`, tanpa dependensi Flutter, wajib dites):
- Papan `cols × rows` (cols = 15; rows dihitung dari tinggi papan tersedia agar sel persegi).
- State: `snake` (daftar sel, kepala di indeks 0), `direction`, `pendingDirection`, `book` (posisi buku), `score`, `status` ∈ (`ready`, `running`, `paused`, `gameOver`).
- `tick()`: gerakkan 1 sel; jika menabrak dinding **atau** tubuh sendiri → `gameOver`; jika kepala di posisi buku → ular memanjang 1, `score += 10`, spawn buku baru di sel **kosong** acak (menerima `Random` injeksi untuk tes).
- Tidak boleh berbalik arah 180° langsung; input arah di-buffer ke `pendingDirection` dan dipakai di tick berikutnya.
- Kecepatan: awal 200 ms/tick, turun 8 ms setiap 3 buku, minimum 90 ms.
- Posisi awal: ular panjang 3 di tengah, arah kanan.

**UI:**
- Layar: header (back, "Book Snake"), baris skor "Books {score}" dan "Best {highScore}", papan dalam `AppCard` (radius 20), kontrol di bawah.
- Gambar papan dengan `CustomPainter`: latar Warm Ivory (dark: surfaceDark), grid sangat halus; kepala ular `deepTeal`, tubuh `oceanTeal` (sudut membulat); **buku** digambar sebagai buku kecil (persegi panjang `softApricot` dengan "punggung" `deepTeal`) — bukan emoji.
- **Kontrol:** geser (swipe) di papan + **D-pad** 4 tombol (≥ 48×48) di bawah papan. Tombol **Pause/Resume**.
- Overlay "Tap to start" pada state `ready`. Game over → bottom sheet: skor, best, tombol **Play again** (primary) dan **Back to Tools**.
- Game otomatis `paused` saat aplikasi ke background (`WidgetsBindingObserver`) atau halaman tertutup (timer dibatalkan di `dispose`).
- Game over: simpan `game_scores` (game=`snake`) jika skor > 0; high score = skor terbesar milik pengguna.
- Haptic ringan saat makan buku dan saat game over (opsional).

**Tes unit wajib:** gerak maju, pertumbuhan saat makan buku, tabrak dinding, tabrak tubuh, larangan balik arah, buku tidak pernah muncul di atas tubuh ular.

### 10.2 Reading Ledger (Blockchain Sederhana)

Tujuan: memenuhi ketentuan "fitur blockchain sederhana" tanpa mengubah alur. Setiap buku yang **selesai dibaca** dicatat sebagai blok pada rantai milik pengguna.

**Logika murni** di `ledger_service.dart`:
- Struktur blok: `index`, `timestamp` (ISO UTC), `data` (map), `previousHash`, `nonce`, `hash`.
- Hash: `SHA-256` (paket `crypto`) atas string `"$index|$timestamp|${jsonEncode(data)}|$previousHash|$nonce"` dalam heksadesimal. `jsonEncode` data harus **deterministik** (kunci diurutkan).
- **Proof of work sederhana:** cari `nonce` mulai 0 sehingga `hash` diawali `"00"` (difficulty 2 karakter hex).
- **Genesis block:** `index=0`, `previousHash="0"`, `data={"message":"StoryLoka genesis","user_id":...}`; dibuat sekali saat register (atau saat pertama dibuka bila belum ada).
- `data` blok buku selesai: `{ "user_book_id", "google_books_id", "title", "authors", "page_count", "total_reading_seconds", "rating", "finished_at" }`.
- `appendFinishedBook(userBook)`: ambil blok terakhir → hitung blok baru → simpan (`sync_status='pending'`). Idempoten: jangan menambah blok kedua untuk `user_book_id` yang sama.
- `verifyChain(blocks)`: untuk tiap blok cek (a) hash tersimpan = hash dihitung ulang, (b) hash memenuhi prefix `"00"`, (c) `previousHash` = hash blok sebelumnya, (d) `index` berurutan. Hasil: valid, atau indeks blok pertama yang rusak.

**UI (`/profile/ledger`):** header penjelas singkat ("Catatan buku yang selesai kamu baca, saling terhubung lewat hash."), tombol **Verify Ledger** (hasil: ✔ "Rantai valid" / "Blok #n tidak valid" memakai ikon + teks, bukan warna saja), daftar blok (nomor, judul buku, tanggal, 8 karakter awal hash dan previous hash). Empty state: hanya genesis block + pesan "Selesaikan buku pertamamu untuk menambah blok."

**Catatan jujur (tulis di dokumentasi kode):** ini simulasi edukatif single-node, bukan jaringan terdesentralisasi.

**Tes unit wajib:** rantai valid, rantai invalid setelah data blok diubah, rantai invalid setelah `previousHash` diubah, idempotensi `appendFinishedBook`, hash berawalan `"00"`.

### 10.3 Accelerometer (Sensor 1)
`sensor_service.dart` menyediakan `Stream<void> shakeStream` dari `sensors_plus` (lihat parameter 7.3). Langganan hanya saat halaman Add Book aktif.

### 10.4 Sensor Cahaya (Sensor 2) dan Tema Auto
- Mode Auto hanya aktif jika pengguna memilih **Auto** di Profile.
- Ambil lux dari `light_sensor` (Android). Aturan dengan **hysteresis** agar tidak berkedip: masuk dark jika lux < 10, kembali light jika lux > 40; ambil rata-rata pembacaan 3 detik terakhir; ubah tema paling cepat setiap 5 detik.
- Sensor tidak tersedia/paket gagal → mode Auto mengikuti `ThemeMode.system` dan tampilkan keterangan kecil "Sensor cahaya tidak tersedia, mengikuti tema sistem".
- **Fallback sensor kedua jika `light_sensor` tidak bisa dipakai sama sekali:** gunakan **Gyroscope** (`sensors_plus`) sebagai opsi "Tilt control" pada Snake (miringkan ponsel untuk mengubah arah, switch di layar Snake), dan catat di `docs/DEVIATIONS.md`. Dengan ini ketentuan "minimal 2 sensor" tetap terpenuhi.

### 10.5 Notifikasi (`notification_service.dart`)
- Channel Android: `reading_reminder` (pengingat), `reading_timer` (stopwatch).
- **Pengingat harian:** `zonedSchedule` dengan `matchDateTimeComponents: DateTimeComponents.time`, mode `inexactAllowWhileIdle` (tanpa izin exact alarm). Zona lokal dari `flutter_timezone`. Isi: judul "Waktunya membaca 📖" **tanpa emoji** → "Waktunya membaca", isi "Luangkan beberapa menit untuk buku favoritmu." Tap → buka aplikasi (Home). Dijadwal ulang saat pengguna mengubah jam/saklar; dibatalkan saat dimatikan atau logout.
- **Notifikasi stopwatch:** notifikasi `ongoing` dengan `usesChronometer: true` dan `when: <epoch ms waktu mulai>`, judul "Sedang membaca", isi judul buku; diperbarui/dihentikan sesuai Play/Pause/Finish (saat pause, batalkan lalu tampilkan ulang dengan waktu yang disesuaikan, atau cukup sembunyikan). Hanya tampil jika saklar aktif.
- Android 13+: minta izin `POST_NOTIFICATIONS` saat pertama kali pengguna mengaktifkan salah satu notifikasi, setelah penjelasan tujuan. Izin ditolak → saklar kembali mati + info cara mengaktifkan.

---

## 11. State dan Penanganan Error

| Situasi | Perilaku |
|---|---|
| Offline saat cari buku | Pesan "Tidak ada koneksi" + Coba lagi |
| Hasil pencarian kosong | Empty state + saran ubah kata kunci/filter |
| Izin kamera ditolak (scan) | Penjelasan + input ISBN manual |
| Izin lokasi ditolak | Pencarian lokasi manual (9.4) |
| Biometrik tidak tersedia | Switch nonaktif + keterangan |
| Gemini gagal | Pesan sesuai 9.3, input tidak hilang |
| Kurs gagal | Cache + label; tanpa cache → error + retry |
| Sync gagal | Diam-diam diulang; data tetap aman lokal |
| Sesi server tidak valid | Logout paksa + pesan |
| Aksi destruktif (hapus buku, logout, hapus riwayat chat) | Dialog konfirmasi |
| Submit form | Tombol loading/disabled; cegah ganda |
| Foto profil gagal upload | Tetap tersimpan lokal; coba lagi saat online |

Aturan: jangan tampilkan sukses sebelum operasi benar-benar berhasil; pertahankan input saat error masih bisa dipulihkan; teks panjang harus membungkus; tidak ada overflow pada layar kecil (uji 360×640 dan skala teks 1.3).

---

## 12. Konfigurasi Platform

**Android**
- `minSdkVersion 23` (atau sesuai kebutuhan paket tertinggi).
- Izin di `AndroidManifest.xml`: `INTERNET`, `CAMERA`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, `USE_BIOMETRIC`, `POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED` (ikuti README `flutter_local_notifications` untuk receiver/boot).
- `MainActivity` harus `FlutterFragmentActivity` (wajib untuk `local_auth`).
- `<queries>` untuk intent `https` dan `geo` (agar `url_launcher` bisa membuka Maps).
- `flutter_local_notifications`: aktifkan core library desugaring sesuai README paketnya.
- Nama aplikasi: **StoryLoka**; ikon aplikasi sederhana (buku + daun) dalam palet.

**iOS (sekunder):** `Info.plist` — `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSFaceIDUsageDescription`, `NSPhotoLibraryUsageDescription`.

---

## 13. Urutan Pengerjaan (Dua Tahap: Frontend dulu, Backend kemudian)

### 13.0 Strategi dan aturan penghubung

- **Tahap A — Frontend:** seluruh layar dan alur dikerjakan memakai **Fake repository** (in-memory). Tampilan bisa dilihat dan diuji sejak awal tanpa Supabase, API key, atau internet.
- **Tahap B — Backend dan integrasi:** implementasi repository diganti ke versi nyata (SQLite + Supabase + API + fitur perangkat) **tanpa mengubah UI**.

**Aturan agar peralihan mulus (wajib sejak Fase A0):**
1. UI hanya bergantung pada **abstract repository** (`AuthRepository`, `ProfileRepository`, `BookSearchRepository`, `LibraryRepository`, `ReadingRepository`, `LedgerRepository`, `FeedbackRepository`, `ScoreRepository`, `ChatRepository`, `CurrencyRepository`). Tidak boleh ada widget yang memanggil `http`, `sqflite`, atau `supabase` secara langsung.
2. Model data memakai bentuk yang sama dengan Bagian 8 (`UserBook`, `ReadingSession`, `LedgerBlock`, dst.), sehingga Tahap B hanya menulis implementasi baru.
3. Pemilihan implementasi ada di **satu tempat**: `lib/app/providers.dart`, ditentukan flag `AppConfig.useFakeData` (`--dart-define=USE_FAKE=true`; default `true` selama Tahap A, diubah menjadi `false` di Fase B7).
4. Fake repository wajib mensimulasikan **latensi** (300–800 ms) dan bisa mensimulasikan **error**, agar state loading/empty/error bisa dilihat.
5. **Data demo** (pengecualian terbatas untuk aturan "tanpa data palsu"): sekitar 12 buku dengan judul dan penulis nyata dan umum, tanpa cover (pakai placeholder `BookCover`), harga dibiarkan kosong kecuali beberapa contoh. Setiap layar yang menampilkan data demo memunculkan chip kecil **"Mode demo"** (Home dan Add Book). Data demo tidak boleh terbawa ke Tahap B.
6. **DemoControls** (hanya `kDebugMode`, bottom sheet dari Profile): ganti data berisi/kosong, simulasi error jaringan, simulasi lambat, lewati biometrik. Dipakai untuk memeriksa semua state tampilan.
7. Logika murni yang tidak butuh backend (Snake, stopwatch, konversi waktu, ledger, perhitungan konversi mata uang) **dikerjakan nyata sejak Tahap A**, bukan palsu.

Setiap fase selesai jika **Definition of Done (DoD)** terpenuhi, `flutter analyze` bersih, tes relevan lolos, dan `docs/PROGRESS.md` diperbarui.

---

## TAHAP A — FRONTEND (data demo)

### Fase A0 — Fondasi
- Buat proyek Flutter `storyloka`; pasang paket yang dibutuhkan UI (`provider`, `go_router`, `google_fonts`, `cached_network_image`, `intl`, `uuid`, `shared_preferences`, `flutter_secure_storage`, `crypto`, `url_launcher`, `image_picker`). Paket backend/perangkat dipasang di Tahap B.
- `core/theme` (token light + dark, Fraunces/DM Sans), `core/widgets` (Bagian 4.5).
- Model data (Bagian 8), **abstract repository** + **Fake implementation** + data demo + `DemoControls` + chip "Mode demo".
- `router.dart` + `MainShell` (bottom nav 5 tab).
- **DoD:** aplikasi berjalan; bottom nav 5 tab berpindah; tema light/dark berfungsi; DemoControls bisa mengganti data berisi/kosong.

### Fase A1 — UI Autentikasi
- Splash, Register, Login (validasi form lengkap), Lock screen (tombol "Simulasi biometrik" muncul hanya di mode demo), redirect guard.
- Fake auth: format email valid dan password ≥ 8 karakter diterima; email `taken@demo.com` mensimulasikan error `EMAIL_TAKEN`; password salah disimulasikan dengan `wrong` di DemoControls. Session fake disimpan di secure storage agar alur tutup-buka bisa dites.
- **DoD:** register/login/logout berjalan, semua pesan error tampil, session fake bertahan setelah restart, Lock screen bisa dilihat.

### Fase A2 — Add Book dan Book Detail
- Add Book: search bar, filter Title/Author/ISBN, debounce, grid 3 kolom, state awal/loading/kosong/error, tombol Scan Barcode (halaman scan berisi tampilan kamera placeholder + input ISBN manual), ikon shake (tombol memilih buku acak dari data demo).
- Book Detail (pencarian): cover, judul, penulis, genre, tombol Add to Collection/Wishlist dengan state "Added to …", Synopsis + Read More, Book Price ("Harga tidak tersedia" bila kosong), Find Nearby Bookstores (Open Maps via `url_launcher` + bottom sheet lokasi manual).
- **DoD:** semua state Add Book terlihat; tombol Add mengubah label dan buku muncul di Library; tanpa duplikat.

### Fase A3 — Home dan Library
- Home (header, Reading Summary, Currently Reading dua kondisi, My Collection, My Wishlist, See all), Library (search, toggle, status badge, empty state, hapus dengan konfirmasi), Book Detail Wishlist, pindah wishlist → collection.
- **DoD:** alur 2, 5, 6 sesuai Bagian 7; angka ringkasan benar; See all membuka filter yang tepat.

### Fase A4 — Alur Membaca
- Book Detail Collection, Start Reading, Reading Timer (stopwatch berbasis timestamp, nyata), Reading Progress, Finished Book, Rating/Review, penyimpanan sesi membaca (in-memory).
- `LedgerService` nyata (hash, proof of work, verifikasi) dengan penyimpanan in-memory + tes unit (Bagian 10.2).
- **DoD:** Start Reading → timer → Finish → Progress → Finished This Book → Finished Book → Home berjalan penuh; Currently Reading ikut berubah; blok ledger bertambah saat selesai.

### Fase A5 — Tools
Urutan: **(1) Snake** (engine + tes + UI + skor), (2) Kesan & Pesan (in-memory, tampil langsung), (3) Konversi Waktu (nyata + tes), (4) Konversi Mata Uang (UI + logika nyata + tes; kurs **demo** berlabel "Kurs contoh"), (5) AI Chat (UI lengkap: gelembung, indikator mengetik, chip saran, hapus riwayat; balasan fake berlabel "Jawaban contoh (mode demo)").
- **DoD:** 5 card Tools berfungsi di sisi tampilan; tes engine Snake, konversi mata uang, konversi waktu lolos.

### Fase A6 — UI Profile
- Header (foto via `image_picker`, nama, email, bio), ringkasan buku, Edit Profil, switch Biometrik/Notifikasi (pengingat + stopwatch)/Tema (Light/Dark/Auto) **sebagai UI** (efek nyata hanya untuk Light/Dark; Auto sementara mengikuti sistem), Reading Ledger (daftar blok + Verify, nyata), Logout dengan konfirmasi.
- **DoD:** semua butir 7.8 terlihat dan bisa dioperasikan; tema Light/Dark berubah langsung.

### Fase A7 — Polesan Tampilan
- Pass konsistensi desain (spacing, radius, tipografi, tombol, nav), semua state di semua layar (pakai DemoControls), aksesibilitas (label ikon, target 44, kontras), uji layar 360×640 dan skala teks 1.3.
- **DoD:** semua layar rapi dan konsisten; tidak ada overflow; tes unit Tahap A lolos. **Titik berhenti untuk review tampilan** sebelum masuk Tahap B.

---

## TAHAP B — BACKEND DAN INTEGRASI

*(Mulai dari sini pemilik proyek perlu menyiapkan Supabase dan `.env` — lihat Bagian 0.)*

### Fase B1 — Penyimpanan Lokal (SQLite)
- Pasang `sqflite`, `path`, `path_provider`; implementasikan `database_helper` (skema 8.1) dan implementasi **Local** untuk `LibraryRepository`, `ReadingRepository`, `LedgerRepository`, `FeedbackRepository`, `ScoreRepository`, `ChatRepository`; pengaturan lewat `shared_preferences`.
- **DoD:** data bertahan setelah aplikasi ditutup dan dibuka lagi, tanpa internet; semua tes Tahap A tetap lolos.

### Fase B2 — Autentikasi dan Supabase
- Jalankan Lampiran A; `supabase_flutter`, `env.dart`; `AuthRepository` dan `ProfileRepository` nyata (RPC `register_user`, `login_user`, `validate_session`, `logout_session`, `update_profile`); session di secure storage; biometrik nyata (`local_auth`, konfigurasi `FlutterFragmentActivity`).
- **DoD:** register → masuk Home; session bertahan; logout kembali ke Login; password tidak terbaca di tabel; biometrik berfungsi di perangkat.

### Fase B3 — Google Books, Scan, Shake
- `BookSearchRepository` nyata (9.1); scan barcode nyata (`mobile_scanner`); shake nyata (`sensors_plus`, 7.3/10.3); harga dari API.
- **DoD:** pencarian Title/Author/ISBN memberi hasil nyata; scan ISBN dan shake berfungsi; chip "Mode demo" hilang di Add Book.

### Fase B4 — Sinkronisasi Online
- Lengkapi `SyncService` (8.3), push/pull semua tabel, sinkron saat login/resume/logout, pull-to-refresh, upload avatar ke Storage.
- **DoD:** data offline tersinkron saat online; login di instalasi baru menarik buku, ledger, kesan-pesan, dan skor; tidak ada duplikasi saat sync berulang.

### Fase B5 — Layanan Eksternal Lain
- AI Chat nyata (Gemini, 9.3), kurs mata uang nyata + cache (9.2), LBS nyata (`geolocator`, 9.4).
- **DoD:** AI Chat menjawab dan menangani error; kurs nyata dengan fallback cache; Open Maps memakai lokasi, atau lokasi manual jika izin ditolak.

### Fase B6 — Fitur Perangkat
- Notifikasi (pengingat harian + stopwatch ongoing, 10.5), sensor cahaya + tema Auto (10.4, termasuk fallback), konfigurasi izin/manifest/Info.plist (Bagian 12).
- **DoD:** notifikasi muncul sesuai jadwal; Auto bereaksi terhadap sensor (atau fallback terdokumentasi); izin diminta saat dibutuhkan.

### Fase B7 — Finalisasi
- Ubah default `USE_FAKE=false`; pastikan tidak ada data demo di build rilis (DemoControls hanya `kDebugMode`); jalankan seluruh tes; lengkapi `docs/DEVIATIONS.md`; build APK debug.
- **DoD:** checklist Bagian 15 lolos.
- *(Stretch, jika semua selesai)* dropdown konversi mata uang di card Book Price memakai `CurrencyRepository` yang sama.

---

## 14. Pemetaan Ketentuan Tugas Akhir

| Ketentuan | Realisasi |
|---|---|
| Konsep projek akhir | Dokumen ini + design system |
| Login enkripsi (non-Firebase) + session | 7.1: bcrypt di server, token session di secure storage |
| Login biometrik | 7.1 (Lock screen), 7.8 (switch) |
| DB lokal dan online | SQLite (8.1) + Supabase (8.2, Lampiran A), sync 8.3 |
| Web service/API + LBS terkait tema | Google Books (9.1), Gemini (9.3), Maps toko buku terdekat (9.4) |
| Bottom navigation: profil (ada gambar), saran & kesan, logout | Bottom nav 5 tab; foto + logout di Profile (7.8); Kesan & Pesan di Tools (7.7) |
| Konversi mata uang (≥3) dan waktu (WIB, WIT, WITA, London) | 9.2, 9.5 (menu Tools) |
| Minimal 2 sensor | Accelerometer (10.3) + sensor cahaya (10.4), fallback gyroscope |
| Fitur AI/LLM sesuai tema | AI Chat Gemini (9.3) |
| Mini game sederhana | Book Snake (10.1) |
| Fasilitas pencarian dan pemilihan | Add Book, Library, Scan, Shake (7.3, 7.6) |
| Notifikasi berbasis mobile | 10.5 |
| Blockchain sederhana | Reading Ledger (10.2) |

(Presentasi mingguan dan laporan dikerjakan terpisah di luar dokumen ini.)

---

## 15. Checklist Verifikasi Akhir

**Fungsional**
- [ ] Register/login/logout; session bertahan; password ter-hash di server; tanpa Firebase.
- [ ] Biometrik aktif/nonaktif dan dipakai saat membuka aplikasi.
- [ ] Cari Title/Author/ISBN, scan barcode, shake to discover.
- [ ] Add to Collection/Wishlist tanpa duplikat; tombol berubah jadi "Added to …".
- [ ] Wishlist → Add to Collection memindahkan buku.
- [ ] Start Reading → Timer → Finish → Progress → Save/Finished → Finished Book → Home.
- [ ] Currently Reading berganti sesuai buku terakhir yang dimulai; kosong setelah diselesaikan.
- [ ] Rating/review hanya bisa diisi setelah buku selesai.
- [ ] Open Maps (izin diberi dan ditolak/lokasi manual).
- [ ] Konversi mata uang (≥3) dan waktu (WIB/WITA/WIT/London) benar.
- [ ] AI Chat menjawab seputar buku dan menangani error.
- [ ] Snake dapat dimainkan, skor tersimpan, pause otomatis saat background.
- [ ] Kesan & Pesan tersimpan dan langsung tampil.
- [ ] Notifikasi pengingat dan stopwatch bekerja.
- [ ] Tema Light/Dark/Auto bekerja.
- [ ] Reading Ledger menambah blok saat selesai; Verify Ledger mendeteksi data yang diubah.
- [ ] Data offline tersinkron ke Supabase; login perangkat baru menarik data.

**Kualitas**
- [ ] Tidak ada data palsu yang tampil sebagai data nyata; tidak ada secret di repository.
- [ ] Spacing, radius, tipografi, tombol, dan nav konsisten dengan Bagian 4.
- [ ] Setiap layar punya state loading/empty/error.
- [ ] Tidak ada overflow di 360×640 dan skala teks 1.3.
- [ ] `flutter analyze` bersih; semua tes lolos; APK debug berhasil dibuild.
- [ ] `docs/PROGRESS.md` dan `docs/DEVIATIONS.md` lengkap.

---

## Lampiran A — Supabase SQL (`supabase/schema.sql`)

Jalankan seluruhnya di Supabase **SQL Editor**.

```sql
-- ============ EXTENSIONS ============
create extension if not exists pgcrypto with schema extensions;

-- ============ TABEL AKUN (tidak diakses langsung oleh klien) ============
create table if not exists public.app_users (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  password_hash text not null,
  avatar_url text,
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists app_users_email_uidx on public.app_users (lower(email));

create table if not exists public.app_sessions (
  token text primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);
create index if not exists app_sessions_user_idx on public.app_sessions (user_id);

alter table public.app_users enable row level security;
alter table public.app_sessions enable row level security;
-- Sengaja TANPA policy: hanya fungsi SECURITY DEFINER di bawah yang bisa mengakses.

-- ============ TABEL DATA ============
create table if not exists public.user_books (
  id uuid primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  google_books_id text not null,
  title text not null,
  authors text,
  genre text,
  isbn text,
  publisher text,
  page_count integer,
  cover_url text,
  synopsis text,
  price_amount numeric,
  price_currency text,
  list_type text not null check (list_type in ('collection','wishlist')),
  status text not null default 'not_started' check (status in ('not_started','reading','finished')),
  current_page integer not null default 0,
  rating integer check (rating between 1 and 5),
  review text,
  started_at timestamptz,
  finished_at timestamptz,
  last_read_at timestamptz,
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, google_books_id)
);
create index if not exists user_books_user_idx on public.user_books (user_id);

create table if not exists public.reading_sessions (
  id uuid primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  user_book_id uuid not null references public.user_books(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  duration_seconds integer not null,
  created_at timestamptz not null default now()
);
create index if not exists reading_sessions_user_idx on public.reading_sessions (user_id);

create table if not exists public.ledger_blocks (
  id uuid primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  block_index integer not null,
  timestamp timestamptz not null,
  data_json jsonb not null,
  previous_hash text not null,
  nonce integer not null,
  hash text not null,
  created_at timestamptz not null default now(),
  unique (user_id, block_index)
);

create table if not exists public.feedbacks (
  id uuid primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  name text not null,
  impression text not null,
  suggestion text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.game_scores (
  id uuid primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  game text not null,
  score integer not null,
  played_at timestamptz not null default now()
);

-- ============ RLS TABEL DATA (permisif untuk anon — lihat catatan keamanan 8.2) ============
alter table public.user_books enable row level security;
alter table public.reading_sessions enable row level security;
alter table public.ledger_blocks enable row level security;
alter table public.feedbacks enable row level security;
alter table public.game_scores enable row level security;

do $$
declare t text;
begin
  foreach t in array array['user_books','reading_sessions','ledger_blocks','feedbacks','game_scores']
  loop
    execute format('drop policy if exists "%1$s anon all" on public.%1$s', t);
    execute format('create policy "%1$s anon all" on public.%1$s for all to anon using (true) with check (true)', t);
  end loop;
end $$;

-- ============ RPC AUTH ============
create or replace function public.register_user(p_name text, p_email text, p_password text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user public.app_users;
  v_token text;
begin
  if p_name is null or length(trim(p_name)) = 0 then raise exception 'NAME_REQUIRED'; end if;
  if p_email is null or p_email !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'EMAIL_INVALID'; end if;
  if p_password is null or length(p_password) < 8 then raise exception 'PASSWORD_TOO_SHORT'; end if;
  if exists (select 1 from public.app_users where lower(email) = lower(trim(p_email))) then
    raise exception 'EMAIL_TAKEN';
  end if;

  insert into public.app_users (name, email, password_hash)
  values (trim(p_name), lower(trim(p_email)), crypt(p_password, gen_salt('bf', 10)))
  returning * into v_user;

  v_token := encode(gen_random_bytes(32), 'hex');
  insert into public.app_sessions (token, user_id, expires_at)
  values (v_token, v_user.id, now() + interval '30 days');

  return json_build_object(
    'token', v_token,
    'user', json_build_object('id', v_user.id, 'name', v_user.name, 'email', v_user.email,
                              'avatar_url', v_user.avatar_url, 'bio', v_user.bio)
  );
end $$;

create or replace function public.login_user(p_email text, p_password text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user public.app_users;
  v_token text;
begin
  select * into v_user from public.app_users where lower(email) = lower(trim(p_email));
  if not found or v_user.password_hash <> crypt(p_password, v_user.password_hash) then
    raise exception 'INVALID_CREDENTIALS';
  end if;

  v_token := encode(gen_random_bytes(32), 'hex');
  insert into public.app_sessions (token, user_id, expires_at)
  values (v_token, v_user.id, now() + interval '30 days');

  return json_build_object(
    'token', v_token,
    'user', json_build_object('id', v_user.id, 'name', v_user.name, 'email', v_user.email,
                              'avatar_url', v_user.avatar_url, 'bio', v_user.bio)
  );
end $$;

create or replace function public.validate_session(p_token text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare v_user public.app_users;
begin
  select u.* into v_user
  from public.app_sessions s join public.app_users u on u.id = s.user_id
  where s.token = p_token and s.expires_at > now();
  if not found then raise exception 'SESSION_INVALID'; end if;
  return json_build_object('id', v_user.id, 'name', v_user.name, 'email', v_user.email,
                           'avatar_url', v_user.avatar_url, 'bio', v_user.bio);
end $$;

create or replace function public.logout_session(p_token text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  delete from public.app_sessions where token = p_token;
end $$;

create or replace function public.update_profile(p_token text, p_name text, p_bio text, p_avatar_url text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid;
  v_user public.app_users;
begin
  select user_id into v_uid from public.app_sessions where token = p_token and expires_at > now();
  if v_uid is null then raise exception 'SESSION_INVALID'; end if;
  if p_name is null or length(trim(p_name)) = 0 then raise exception 'NAME_REQUIRED'; end if;

  update public.app_users
  set name = trim(p_name), bio = p_bio, avatar_url = coalesce(p_avatar_url, avatar_url), updated_at = now()
  where id = v_uid
  returning * into v_user;

  return json_build_object('id', v_user.id, 'name', v_user.name, 'email', v_user.email,
                           'avatar_url', v_user.avatar_url, 'bio', v_user.bio);
end $$;

grant execute on function public.register_user(text, text, text) to anon;
grant execute on function public.login_user(text, text) to anon;
grant execute on function public.validate_session(text) to anon;
grant execute on function public.logout_session(text) to anon;
grant execute on function public.update_profile(text, text, text, text) to anon;

-- ============ STORAGE AVATAR ============
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "avatars anon read" on storage.objects;
drop policy if exists "avatars anon insert" on storage.objects;
drop policy if exists "avatars anon update" on storage.objects;
create policy "avatars anon read"   on storage.objects for select to anon using (bucket_id = 'avatars');
create policy "avatars anon insert" on storage.objects for insert to anon with check (bucket_id = 'avatars');
create policy "avatars anon update" on storage.objects for update to anon using (bucket_id = 'avatars');
```

**Catatan klien untuk RPC:** `supabase.rpc('login_user', params: {'p_email': ..., 'p_password': ...})`. Error dari `raise exception` muncul di `PostgrestException.message` (mis. `EMAIL_TAKEN`, `INVALID_CREDENTIALS`, `SESSION_INVALID`); petakan ke pesan UI bahasa Indonesia. Nama file avatar: `{user_id}/avatar.jpg` dengan `upsert: true`.
