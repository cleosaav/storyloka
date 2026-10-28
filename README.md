# StoryLoka 📚🌿
> *Aplikasi pelacak kebiasaan membaca buku pribadi berbasis offline-first dengan kurasi katalog cerdas, pendamping membaca AI, geolokasi toko buku fisik, mini game interaktif, dan rantai integritas bacaan.*

---

## 📌 Tentang StoryLoka

**StoryLoka** adalah aplikasi mobile pelacak kebiasaan membaca buku (*personal reading companion & tracker*) yang dirancang dengan estetika visual **Cozy Botanical Editorial**. Dibangun untuk memenuhi tugas akhir mata kuliah **Pemrograman Aplikasi Mobile (PAM)**, StoryLoka memadukan keandalan arsitektur offline-first, sinkronisasi cloud real-time, kecerdasan buatan (AI LLM), serta integrasi sensor perangkat keras (GPS, kamera scanner, akselerometer, giroskop, sensor cahaya ambient, dan biometrik fingerprint/face unlock).

---

## ✨ Fitur Utama

1. **Autentikasi Mandiri & Keamanan Biometrik (PRD §7.1 & §8.2):**
   - Registrasi, login, dan logout via PostgreSQL Custom RPC tanpa Firebase & tanpa Supabase Auth SDK.
   - Password di-hash menggunakan algoritma `blowfish/bcrypt` dengan salt dinamis di sisi server Supabase.
   - Sesi token 32-byte disimpan terenkripsi di `FlutterSecureStorage` dengan validasi offline yang andal.
   - Penguncian instan layar dengan biometrik (*Fingerprint / Face ID*) melalui `local_auth` dan `FlutterFragmentActivity`.
2. **Pencarian Katalog Buku Hibrida & Scan Barcode (PRD §7.3 & §9.1):**
   - Pencarian katalog hibrida via Google Books API v1 dan cadangan cerdas Open Library API.
   - Scanner barcode kamera fisik (EAN-13 ISBN) berbasis `mobile_scanner`.
   - Fitur *Shake to Discover*: kocok perangkat untuk menemukan rekomendasi buku acak via akselerometer.
3. **Koleksi & Wishlist Offline-First (PRD §7.2, §7.6 & §8.3):**
   - Manajemen rak buku pribadi: *Collection* dan *Wishlist*.
   - Pemindahan satu sentuhan dari Wishlist ke Koleksi tanpa mereset progres membaca.
   - Sinkronisasi dua arah otomatis (*last-write-wins conflict resolution*) antara SQLite lokal dan cloud Supabase.
4. **Sesi Membaca, Stopwatch & Reading Ledger (PRD §7.4, §10.2 & §10.5):**
   - Stopwatch wall-clock persisten berbasis timestamp dengan notifikasi Android Chronometer yang efisien daya.
   - Pembaruan progres halaman dinamis, persentase baca, dan dialog rating/ulasan setelah buku selesai dibaca.
   - **Reading Ledger**: Setiap buku yang selesai dicatat ke dalam rantai blok (*blockchain ledger*) lokal dengan hash SHA-256 kanonikal dan Proof of Work (prefix `"00"`). Dilengkapi fitur *Verify Ledger* untuk mendeteksi manipulasi data.
5. **Alat Bantu Membaca (Tools) & AI Chat Companion (PRD §7.7 & §9):**
   - **AI Chat Teman Baca**: Percakapan seputar buku bersama LLM primer DeepSeek Chat (`deepseek-chat`) dengan failover otomatis ke Google Gemini (`gemini-3.5-flash-lite` / `gemini-3.5-flash`).
   - **Peta Toko Buku Terdekat**: Peta interaktif bawaan berbasis `flutter_map`, OpenStreetMap tiles, Overpass API, dan database cadangan toko buku Indonesia terverifikasi.
   - **Konversi Mata Uang & Waktu**: Konversi kurs 5 mata uang (IDR, USD, EUR, JPY, SGD) via live exchange rate API dan konversi zona waktu (WIB, WITA, WIT, London dengan penyesuaian otomatis musim panas DST).
   - **Mini Game Book Snake**: Game retro Snake dengan grid adaptif 15 kolom, kontrol swipe, D-pad, serta kontrol kemiringan fisik (*tilt control* via giroskop). Skor tertinggi tersimpan lokal dan cloud.
   - **Kesan & Pesan Tim**: Halaman baca-saja (*read-only*) yang memuat kesan dan pesan perkuliahan dari 3 anggota tim pengembang.
6. **Tema Adaptif & Notifikasi Lokal (PRD §4.2, §10.4 & §10.5):**
   - Tema *Cozy Botanical* Terang (*Warm Ivory*) dan Gelap (*Deep Slate & Botanical Green*).
   - Mode *Auto Theme* yang bereaksi terhadap intensitas cahaya lingkungan (lux) via sensor cahaya fisik Android native (`Sensor.TYPE_LIGHT`).
   - Pengingat membaca harian terjadwal berbasis `flutter_local_notifications` tanpa izin invasif alarm.

---

## 🛠️ Tech Stack & Arsitektur

- **Framework:** Flutter (Channel stable, ^3.47 / Dart ^3.13)
- **Arsitektur:** Clean Architecture dengan Pola Repository Abstrak (Widget → Abstract Repository → Local SQLite / Remote Client).
- **State Management:** `Provider` (`ChangeNotifier`, scoped context injection).
- **Routing:** `go_router` (Stateful nested shell navigation 5 tab, deep linking, auth redirect guard).
- **Penyimpanan Lokal:** `sqflite` (SQLite database lokal), `shared_preferences` (preferensi perangkat), `flutter_secure_storage` (token sesi aman).
- **Backend & Cloud:** Supabase PostgreSQL, PostgREST Custom RPC, Supabase Storage (Avatar).
- **Peta Geospasial:** `flutter_map`, `latlong2`, OpenStreetMap, Overpass API, Nominatim Geocoding.
- **Hardware & Sensor Platform:** `local_auth`, `sensors_plus` (akselerometer & giroskop), `mobile_scanner`, `geolocator`, Android Native Platform Channel (`Sensor.TYPE_LIGHT`).

---

## 📁 Struktur Folder Proyek

```text
StoryLoka/
├── android/                  # Konfigurasi native Android (Kotlin, Gradle, Manifest)
│   └── app/src/main/kotlin/com/storyloka/storyloka/MainActivity.kt # FragmentActivity & Sensor Cahaya Native
├── docs/                     # Dokumentasi spesifikasi, progres, dan deviasi
│   ├── spec/                 # PRD, Design System, Wireframe
│   ├── PROGRESS.md           # Log progres pengerjaan per fase (A0-F5)
│   └── DEVIATIONS.md         # Catatan deviasi teknis & keputusan arsitektur
├── lib/
│   ├── app/                  # Inisialisasi aplikasi, routing (GoRouter), & providers
│   ├── core/                 # Fondasi bersama
│   │   ├── config/           # Pembacaan environment (Env)
│   │   ├── services/         # Biometrik, Lokasi, Notifikasi, Sensor, Ledger, Sync
│   │   ├── theme/            # Token desain (AppColors, AppText, AppSpacing, AppTheme)
│   │   └── widgets/          # Komponen reusable (AppButton, AppCard, AppTextField, dll)
│   ├── data/                 # Lapisan data
│   │   ├── models/           # Data model (UserBook, Session, LedgerBlock, dll)
│   │   ├── repositories/     # Kontrak abstract, implementasi local, remote, dan fake
│   │   └── static/           # Data statis (team_feedback.dart)
│   └── features/             # Fitur antarmuka pengguna
│       ├── add_book/         # Cari buku, scan barcode, shake to discover
│       ├── auth/             # Splash, Login, Register, Lock Screen
│       ├── book_detail/      # Rincian buku, sinopsis, mini map toko buku
│       ├── home/             # Beranda, ringkasan membaca, currently reading
│       ├── library/          # Rak koleksi dan wishlist
│       ├── profile/          # Profil pengguna, ledger blockchain, pengaturan tema
│       ├── reading/          # Stopwatch timer baca, update progres, dialog rating
│       └── tools/            # AI Chat, Bookstore Map, Kurs, Waktu, Snake Game, Kesan & Pesan
├── supabase/
│   └── schema.sql            # Skrip DDL PostgreSQL, RPC function, dan RLS Supabase
├── test/                     # 38 berkas unit & widget test suite (345 tes lulus)
├── .env.example              # Template variabel lingkungan
└── pubspec.yaml              # Dependensi dan metadata proyek
```

---

## 🚀 Panduan Setup & Instalasi

### 1. Prasyarat Lingkungan
- **Flutter SDK:** versi `3.27.x` atau lebih baru (Dart SDK `^3.13.2`).
- **Android SDK:** Platform API 34/35, `minSdkVersion 21`, JDK 17.
- **Git**

### 2. Kloning Repositori & Instalasi Dependensi
```bash
git clone https://github.com/cleosaav/storyloka.git
cd storyloka
flutter pub get
```

### 3. Konfigurasi Backend Database (Supabase)
1. Buat proyek baru di [Supabase Dashboard](https://supabase.com).
2. Buka menu **SQL Editor**, salin seluruh isi berkas [`supabase/schema.sql`](file:///c:/StoryLoka/supabase/schema.sql), lalu jalankan skrip (*Run*). Skrip ini akan membuat tabel, relasi, constraint `UNIQUE`, fungsi RPC dengan hash bcrypt, dan storage bucket `avatars`.

### 4. Konfigurasi Lingkungan (`.env`)
Salin template berkas `.env.example` menjadi `.env` di direktori akar:
```bash
cp .env.example .env
```
Isi nilai-nilai variabel di dalam berkas `.env`:
```env
# URL & Kunci Anon dari Supabase Dashboard -> Project Settings -> API
SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...

# Kunci API Google Books (Opsional namun disarankan)
GOOGLE_BOOKS_API_KEY=AIzaSy...

# Kunci API LLM Chatbot (DeepSeek sebagai primer dari platform.deepseek.com)
DEEPSEEK_API_KEY=sk-...

# Kunci API Fallback Google Gemini (dari aistudio.google.com)
GEMINI_API_KEY=AIzaSy...
GEMINI_MODEL=gemini-3.5-flash-lite
GEMINI_MODEL_FALLBACKS=gemini-3.5-flash

# URL Tile OpenStreetMap
MAP_TILE_URL=https://tile.openstreetmap.org/{z}/{x}/{y}.png
```

> ⚠️ **Catatan Keamanan Penting (.env):**
> - Berkas `.env` **TIDAK BOLEH** dikemas ke repositori publik atau di-zip saat pengumpulan. Pastikan selalu terdaftar di `.gitignore`.

---

## 🧪 Menjalankan & Menguji Aplikasi

### Menjalankan di Mode Debug
```bash
flutter run
```

### Menjalankan Analisis Statis Kode
Pastikan kode bebas dari peringatan dan galat linting:
```bash
flutter analyze
```

### Menjalankan Seluruh Pengujian Otomatis
Jalankan seluruh suite pengujian unit dan widget test (345 tes):
```bash
flutter test
```

### Membangun Berkas APK Rilis/Debug
Untuk membuat berkas APK instalasi Android:
```bash
# Build APK Debug
flutter build apk --debug

# Build APK Rilis
flutter build apk --release
```
Berkas APK akan berada di: `build/app/outputs/flutter-apk/app-release.apk` (atau `app-debug.apk`).

---

## 📱 Daftar Sensor & Fitur Perangkat Keras yang Digunakan

| Sensor / Fitur Perangkat | Implementasi Teknis | Kegunaan dalam StoryLoka |
| :--- | :--- | :--- |
| **Kamera Fisik** | `mobile_scanner` (Camera2/AVFoundation) | Memindai kode batang (barcode) ISBN-13 pada buku cetak. |
| **Akselerometer** | `sensors_plus` (`accelerometerEventStream`) | Mendeteksi goyangan (*Shake to Discover*) untuk menemukan buku acak. |
| **Giroskop** | `sensors_plus` (`gyroscopeEventStream`) | Kontrol kemiringan fisik (*Tilt Control*) pada Mini Game Book Snake. |
| **Sensor Cahaya Ambient**| Native Android `Sensor.TYPE_LIGHT` via Platform Channel | Mengatur transisi tema otomatis (*Auto Theme: Light/Dark*) berdasarkan lux lingkungan. |
| **GPS / Geolokasi** | `geolocator` | Menentukan posisi pengguna untuk memetakan toko buku fisik terdekat. |
| **Biometrik** | `local_auth` & `FlutterFragmentActivity` | Otentikasi sidik jari (*fingerprint*) atau Face Unlock untuk membuka Lock Screen. |
| **Notifikasi Lokal** | `flutter_local_notifications` | Pengingat jadwal membaca harian dan indikator berjalannya sesi stopwatch. |
| **Getaran (Haptic)** | `HapticFeedback` | Umpan balik sentuhan saat scan barcode, benturan game over Snake, dan verifikasi ledger. |

---

## 🛡️ Catatan Keamanan, Batasan yang Diketahui, & Jalur Penguatan

Sesuai dengan komitmen kejujuran teknis (PRD §3 & §8.2), arsitektur StoryLoka memiliki batasan dan catatan keamanan penting sebagai berikut:

1. **Ekstraksi Kunci API dari Berkas APK (PRD §3):**
   - Segala bentuk kunci API publik atau anonim yang dikompilasi ke dalam aplikasi mobile (seperti `SUPABASE_ANON_KEY`, `GOOGLE_BOOKS_API_KEY`, atau API key pihak ketiga) pada prinsipnya **dapat diekstrak** melalui proses rekayasa balik (*reverse engineering / dekompilasi APK*).
   - **Tindakan Pemilik Proyek:** Kunci API Gemini, DeepSeek, Google Books, dan Supabase yang pernah ikut terunggah atau terekspor dalam riwayat arsip repositori/zip pengujian sebelumnya **wajib di-rotate (dibuat ulang dan dicabut yang lama)** sebelum aplikasi diserahkan atau dipublikasikan ke publik.
2. **Isolasi Data pada Row-Level Security (RLS) Permisif (PRD §8.2):**
   - Karena StoryLoka menggunakan sistem autentikasi mandiri berbasis tabel `app_users` dan token acak via RPC PostgreSQL (tanpa modul `supabase.auth` bawaan yang mengikat JWT `auth.uid()`), policy RLS tabel data (`user_books`, `reading_sessions`, `ledger_blocks`, `game_scores`) di Supabase dibuat permisif untuk role `anon`.
   - Konsekuensinya, isolasi data pada kueri PostgREST bawaan saat ini sangat bergantung pada filter `user_id` yang dikirimkan oleh klien aplikasi.
3. **Jalur Penguatan Masa Depan (Hardening Path):**
   - Untuk memperkuat keamanan backend di masa mendatang, akses data PostgREST dapat sepenuhnya dialihkan melalui **PostgreSQL RPC berstatus `SECURITY DEFINER`** yang memverifikasi validitas token sesi pengguna pada tabel `app_sessions` di setiap pemanggilan baca dan tulis, atau dengan memanfaatkan *Custom JWT Claims* Supabase.

---

## 👥 Tim Pengembang (Mata Kuliah PAM)

- **Najmah Cleosa** (NIM: 124240104) — *Lead Developer & Architect*
- **Melanie Bunga Chintya Pawesty** (NIM: 124240164) — *UI/UX & Frontend Developer*
- **Naftali Margareta** (NIM: 124240119) — *Feature & QA Developer*

> 📝 **Catatan Kesan & Pesan:**
> Struktur data kesan dan pesan statis berada pada [`lib/data/static/team_feedback.dart`](file:///c:/StoryLoka/lib/data/static/team_feedback.dart). Pemilik proyek/anggota kelompok wajib mengganti teks draf template tersebut dengan tulisan tangan asli masing-masing anggota sebelum pengumpulan tugas akhir resmi.
