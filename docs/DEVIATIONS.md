# DEVIATIONS.md — Catatan Penyimpangan & Keputusan StoryLoka

Dokumen ini mencatat penyimpangan, klarifikasi, atau keputusan teknis yang diambil selama implementasi, sesuai dengan aturan PRD §0 butir 6 & 10.

---

## Fase A0 — Fondasi

1. **Token Warna Dark Mode (PRD §4.2)**
   - **Keputusan:** Menambahkan token warna Dark Mode (`bgDark: #101819`, `surfaceDark: #1A2527`, `borderDark: #2C3B3D`, `inkDark: #F2EDE3`, `mutedDark: #8FA0A2`, `primaryDark: #2F7F8C`, `trackDark: #2A3638`) sebagai turunan resmi dari design system sesuai mandat PRD §4.2.
   - **Alasan:** Memenuhi kebutuhan tema gelap tanpa mengorbankan konsistensi palet editorial Cozy Botanical.

2. **Placeholder Fitur Shell untuk Fase A0 (PRD §13)**
   - **Keputusan:** Pada Fase A0, membuat 5 halaman fitur (`HomePage`, `LibraryPage`, `AddBookPage`, `ToolsPage`, `ProfilePage`) dengan konten minimal/placeholder untuk menguji fungsionalitas `StatefulShellRoute`, bottom navigation 5-tab, dynamic theme switching, dan `DemoControls`.
   - **Alasan:** Sesuai batas Fase A0 (jangan melompat ke fase berikutnya), halaman-halaman tersebut akan diimplementasikan penuh pada fase masing-masing (A1-A6).

3. **Penetapan Versi `google_fonts: 8.2.1`**
   - **Keputusan:** Menggunakan versi `8.2.1` untuk paket `google_fonts`.
   - **Alasan:** Kompatibilitas dengan Flutter 3.47 / Dart 3.13; versi <7.0 memiliki isu evaluasi const `FontWeight` pada map keys, sedangkan versi 9.0.0 menarik dependensi transitif yang membayangi (`shadowing`) kelas `TextTheme` inti Flutter.

4. **Penggunaan Widget `Material` pada `AppCard`**
   - **Keputusan:** Mengimplementasikan kontainer dasar `AppCard` menggunakan widget `Material` dengan `shape: RoundedRectangleBorder`, menggantikan `Container(decoration: BoxDecoration)`.
   - **Alasan:** Memastikan kepatuhan terhadap assertion framework Flutter untuk ink splash/ripple dan rendering background komponen turunan seperti `ListTile` dan `SwitchListTile`.

---

## Fase A1 — UI Autentikasi

1. **Fallback In-Memory pada `SecureSessionStore`**
   - **Keputusan:** Menambahkan mekanisme *fallback in-memory* pada `SecureSessionStore` ketika akses platform channel `FlutterSecureStorage` belum tersedia atau saat dieksekusi dalam *unit test*.
   - **Alasan:** Menjamin aplikasi dan test tidak mengalami *hang* atau *crash* pada lingkungan desktop/web maupun saat pengujian otomatis tanpa native mock.

2. **Integrasi `AuthController` sebagai `refreshListenable` di `GoRouter`**
   - **Keputusan:** Menggunakan `AuthController` (turunan `ChangeNotifier`) sebagai parameter `refreshListenable` pada pembuatan `GoRouter`.
   - **Alasan:** Memungkinkan *redirect guard* bereaksi secara reaktif dan otomatis saat terjadi perubahan status autentikasi (login, logout, biometrik lock/unlock).

---

## Fase A2 — Add Book dan Book Detail

1. **Simulasi Kamera pada `ScanPage` (Tahap A)**
   - **Keputusan:** Pada Fase A2 (Tahap A — Frontend), halaman scan menyajikan *camera frame simulator* dengan petunjuk visual dan form input manual ISBN lengkap yang terhubung ke repositori. Paket pemindai perangkat keras (`mobile_scanner`) disimpan untuk Fase B3 sesuai aturan PRD §13.0 & §13.2.
   - **Alasan:** Mematuhi batasan pengerjaan Fase A (tanpa dependensi native scanner) sambil memastikan alur input ISBN manual dan pencarian buku dapat diuji penuh.

2. **Ikon Shake to Discover sebagai Aksi Acak Demo**
   - **Keputusan:** Tombol ikon di samping search bar memicu `BookSearchRepository.randomBook()` yang memilih buku acak dari dataset demo dan langsung membuka layar detail buku.
   - **Alasan:** Sesuai PRD §7.3, tombol ikon shake disediakan sebagai alternatif aksesibilitas dan kemudahan pengujian di lingkungan emulator sebelum sensor akselerometer perangkat diaktifkan pada Fase B3.

---

## Fase A3 — Home dan Library

1. **Rute Collection Detail dan Placeholder Reading untuk Keutuhan Navigasi**
   - **Keputusan:** Mendaftarkan rute `/book/collection/:id` serta placeholder ramah pengguna untuk `/reading/timer/:id` dan `/reading/progress/:id` di `lib/app/router.dart` sejak Fase A3.
   - **Alasan:** Memastikan tombol "Read" dan "Update" pada card Currently Reading di Home serta kartu buku di Library Collection dapat ditekan tanpa memicu *route not found* / *page crash*, sebelum implementasi penuh stopwatch dan progress di Fase A4.

2. **Flag `fakeRepositoriesEnableLatency` untuk Kestabilan Testing**
   - **Keputusan:** Menyediakan kontrol `fakeRepositoriesEnableLatency` pada `FakeLibraryRepository` dan `FakeBookSearchRepository` yang dapat dinonaktifkan khusus saat eksekusi *widget test*.
   - **Alasan:** Animasi `CircularProgressIndicator` yang aktif selama simulasi latensi dapat mencegah `tester.pumpAndSettle()` menyelesaikan frame pada pengujian otomatis. Mematikan latensi di lingkungan test memastikan pengujian berjalan stabil, cepat (dalam hitungan detik), dan deterministik sesuai PRD §13.0 aturan 4.

---

## Fase A4 — Alur Membaca & Ledger

1. **Stopwatch Wall-Clock Berbasis Timestamp**
   - **Keputusan:** Reading timer diimplementasikan dengan menyimpan `DateTime` awal (`_startedAt`) dan menjumlahkan durasi elapsed daripada increment timer variabel per detik.
   - **Alasan:** Menjamin keakuratan durasi membaca saat aplikasi di-minimize/backgrounded dan mematuhi instruksi eksplisit PRD §7.4.

2. **LedgerService In-Memory dengan Mining Prefix "00"**
   - **Keputusan:** Penyimpanan blok rantai buku selesai menggunakan in-memory storage yang otomatis menginisialisasi Genesis Block dan memvalidasi keutuhan hash (PoW `"00"` dan `previousHash`).
   - **Alasan:** Memenuhi spesifikasi PRD §10.2 untuk integritas data riwayat bacaan buku selesai secara deterministik sebelum persistensi SQLite di Fase B.

---

## Fase A5 — Tools, Snake Game, Konversi, AI Chat

1. **Paket `timezone` untuk Konversi Zona Waktu Otomatis (PRD §9.5)**
   - **Keputusan:** Menggunakan paket `timezone` (dengan `tz_data.initializeTimeZones()`) daripada kalkulasi offset statis.
   - **Alasan:** Memastikan waktu London secara otomatis menyesuaikan Daylight Saving Time (GMT UTC+0 saat musim dingin vs BST UTC+1 saat musim panas) tanpa hardcode manual yang rentan kesalahan musiman.

2. **Render Buku Snake Menggunakan `CustomPainter` Vektor Geometris (PRD §10.1)**
   - **Keputusan:** Objek buku pada grid Snake digambar menggunakan `CustomPainter` yang menggambar cover buku bergradien, lipatan punggung buku, halaman kertas krem, dan bookmark ribbon merah, tanpa karakter emoji/teks string.
   - **Alasan:** Mematuhi mandat PRD §10.1 dan instruksi prompt agar representasi buku tajam, konsisten di semua platform, dan bebas dari fragmentasi rendering font emoji bawaan OS.

3. **Kurs Demo Berlabel Eksplisit "Kurs contoh (mode demo)" (PRD §9.2)**
   - **Keputusan:** Menggunakan nilai kurs statis 5 mata uang berbasis USD pada `FakeCurrencyRepository` dengan label keterangan resmi "Kurs contoh (mode demo)".
   - **Alasan:** Sesuai batasan Tahap A (Frontend) sebelum integrasi live API kurs online pada Tahap B.

---

## Fase A6 — UI Profile & Reading Ledger

1. **Segmented Button Tema dengan Auto Fallback Sistem (PRD §4.7 & §7.8)**
   - **Keputusan:** Kontrol tema diimplementasikan menggunakan `SegmentedButton<ThemeMode>` (Light, Dark, Auto). Opsi Light dan Dark mengubah tema aplikasi secara langsung, sedangkan opsi Auto diarahkan ke `ThemeMode.system`.
   - **Alasan:** Memenuhi instruksi PRD §7.8 ("Auto sementara mengikuti sistem") sebelum integrasi pembacaan sensor cahaya perangkat pada Tahap B (PRD §10.4).

2. **Pengaturan Notifikasi Berbasis UI State (PRD §7.8 & §10.5)**
   - **Keputusan:** Switch Pengingat Membaca (dengan pemilih jam `TimePicker`) dan switch Notifikasi Stopwatch diimplementasikan sebagai komponen UI interaktif tanpa memasang paket background notification native.
   - **Alasan:** Sesuai batasan Fase A (Frontend) di mana servis notifikasi lokal nyata (`flutter_local_notifications`) dijadwalkan untuk Tahap B.

3. **Kompresi dan Sumber Gambar Edit Profil (PRD §7.8)**
   - **Keputusan:** `ImagePicker` dikonfigurasi dengan batas resolusi `maxWidth: 800, maxHeight: 800` dan `imageQuality: 85`, serta menyediakan pilihan sumber Kamera dan Galeri.
   - **Alasan:** Mematuhi spesifikasi kompresi foto profil ≤ 800 px pada PRD §7.8 untuk efisiensi penyimpanan lokal dan unggahan storage mendatang.
---

## Fase B2 — Integrasi Backend Supabase & Keamanan

1. **Autentikasi Mandiri via Database RPC (PRD §8.2, Lampiran A)**
   - **Keputusan:** Menggunakan fungsi RPC PostgreSQL (`register_user`, `login_user`, `validate_session`, `logout_session`, `update_profile`) melalui client Supabase publik tanpa modul `supabase.auth` dan tanpa Firebase.
   - **Alasan:** Sesuai batasan eksplisit PRD §0 dan instruksi prompt agar mekanisme autentikasi dan session token sepenuhnya dikendalikan via database RPC custom.

2. **Akses Terpusat dan Aman Konfigurasi (.env) via `Env`**
   - **Keputusan:** Seluruh akses kunci lingkungan diarahkan hanya melalui `lib/core/config/env.dart`. Jika konfigurasi Supabase tidak lengkap, aplikasi menyajikan layar error konfigurasi alih-alih crash.
   - **Alasan:** Menjamin kepatuhan prinsip keamanan zero-hardcode-secrets dan stabilitas aplikasi.

3. **Biometrik Nyata dengan `FlutterFragmentActivity`**
   - **Keputusan:** Mengganti `FlutterActivity` dengan `FlutterFragmentActivity` di `MainActivity.kt` Android serta memanfaatkan `local_auth` dan `flutter_secure_storage`.
   - **Alasan:** Prasyarat resmi Android biometric prompt agar dialog autentikasi biometrik dapat dipanggil tanpa exception `IllegalStateException`.

---

## Fase B3 — Google Books API & Sensor Akselerometer

1. **Normalisasi ISBN dan Sanitasi HTML Sinopsis (PRD §9.1)**
   - **Keputusan:** Seluruh pencarian berfilter ISBN otomatis membersihkan tanda hubung (`-`) dan spasi sebelum dikirimkan ke Google Books API (`isbn:<digits>`). Sinopsis dari Google Books disanitasi menggunakan regex penghapus tag HTML dan decode entitas dasar (`&quot;`, `&#39;`, `&amp;`, `&lt;`, `&gt;`).
   - **Alasan:** Format query Google Books API mensyaratkan ISBN bersih dari tanda baca agar hasil pencarian presisi, dan tampilan sinopsis di aplikasi harus bersih dari markup HTML mentah.

2. **Dukungan Filter Subjek pada `BookSearchRepository.search()` dan `randomBook()` (PRD §7.3, §9.1)**
   - **Keputusan:** Menambahkan penanganan `filter: 'subject'` (`subject:<query>`) pada `GoogleBooksRepository` yang digunakan oleh `randomBook()` untuk fitur Shake to Discover.
   - **Alasan:** Mematuhi deskripsi PRD §7.3 bahwa guncangan memicu query acak ke Google Books API dari daftar subjek (fiction, fantasy, romance, history, dll.) dengan `startIndex` acak (0–30).

3. **Aksesibilitas Tombol Shake di Add Book Page**
   - **Keputusan:** Di samping guncangan fisik akselerometer melalui `SensorService`, tombol icon shake tetap dipertahankan pada header search bar Add Book Page.
   - **Alasan:** Memastikan fitur penemuan buku acak tetap dapat digunakan oleh pengguna dengan keterbatasan mobilitas (aksesibilitas) serta mempermudah pengujian di emulator/desktop yang tidak memiliki sensor fisik akselerometer.

---

## Fase B4 — Sinkronisasi Offline-First & Resolusi Konflik

1. **Abstraksi `SyncRemoteSource` untuk Pengujian Idempotensi dan Konflik**
   - **Keputusan:** Memperkenalkan antarmuka `SyncRemoteSource` dengan implementasi default `SupabaseSyncRemoteSource` yang membungkus query PostgREST dan bucket Storage Supabase.
   - **Alasan:** Mematuhi aturan PRD §0 dan instruksi pengujian agar logika deterministik sinkronisasi (urutan push tabel, resolusi *last-write-wins*, dan deteksi idempotensi tanpa duplikasi baris) dapat diuji 100% pada unit test tanpa bergantung pada ketersediaan koneksi internet langsung.

2. **Penggunaan `ListenableBuilder` untuk Indikator Status Sinkronisasi di Profile**
   - **Keputusan:** Indikator status sinkronisasi pada `ProfilePage` menggunakan `ListenableBuilder(listenable: SyncService.instance)` yang dibungkus `Flexible`.
   - **Alasan:** Menghindari ketergantungan `Provider<SyncService>` yang kaku pada pengujian widget terisolasi (seperti pada test responsif A6 dan A7) serta mencegah potensi text overflow pada layar kecil (360x640) dengan skala teks 1.3.

3. **Sinkronisasi Otomatis Terhubung ke Seluruh Lifecycle Aplikasi (PRD §8.3)**
   - **Keputusan:** Pemicu sinkronisasi diintegrasikan secara terpadu pada:
     - Operasi tulis repositori lokal (`SyncService.instance.trigger()`).
     - Alur autentikasi login & register (`pullAll`).
     - Alur logout (`syncBeforeLogout`).
     - Lifecycle transisi aplikasi ke foreground via `WidgetsBindingObserver` (`syncOnResume`).
     - Pull-to-refresh pada Home, Library, dan Profile.
   - **Alasan:** Menjamin integritas data dua arah antara SQLite lokal dan cloud Supabase secara mulus tanpa intervensi manual pengguna.

---

## Fase B5 — Integrasi External API: Kurs, Gemini AI, dan LBS Maps

1. **Pemilihan Model Gemini Produksi `gemini-1.5-flash` (PRD §9.3)**
   - **Keputusan:** Menggunakan `gemini-1.5-flash` sebagai model default fallback jika `Env.geminiModel` kosong atau bernilai `gemini-flash-latest`.
   - **Alasan:** PRD §9.3 mencantumkan default `gemini-flash-latest`, namun spesifikasi resmi Google Generative Language API v1beta telah menstandarkan model cepat efisien ke `gemini-1.5-flash` (atau `gemini-2.0-flash`). Alias `-latest` rentan mengalami deprecation atau endpoint path mismatch pada v1beta REST.

2. **Dukungan Dual-Mode URL Maps LBS (PRD §9.4)**
   - **Keputusan:** Pada `LocationService`, koordinat GPS diformat sebagai `geo:lat,lng?q=toko+buku` untuk platform yang mendukung URI scheme maps bawaan, dengan fallback aman ke URL web universal `https://www.google.com/maps/search/?api=1&query=...` via `LaunchMode.externalApplication`.
   - **Alasan:** Menjamin intent Maps terbuka di aplikasi native Google Maps / Apple Maps pada perangkat nyata, sekaligus dapat membuka browser web pada emulator atau perangkat tanpa Maps terpasang tanpa menimbulkan crash.

3. **Retensi Input Pengguna pada Kegagalan Chat AI (PRD §9.3)**
   - **Keputusan:** Saat `GeminiChatRepository.sendMessage()` melempar exception (misal 429 atau kehilangan koneksi internet), teks masukan pengguna yang sempat diketik tidak hilang (`_inputCtrl.text = text;`), pesan error disajikan lewat `SnackBar` merah dengan aksi "Kirim ulang", dan bubble pesan yang gagal dikirim ditarik dari daftar percakapan aktif.
   - **Alasan:** Mematuhi mandat spesifik PRD §9.3 dan instruksi prompt untuk mencegah frustrasi pengguna akibat kehilangan input teks panjang saat terjadi gangguan jaringan atau pembatasan kuota AI.

---

## Fase B6 — Sensor & Fitur Perangkat (Cahaya, Notifikasi, Gyroscope)

1. **Verifikasi Paket Sensor Cahaya & Fallback Sensor Kedua Gyroscope (PRD §10.4)**
   - **Keputusan:** Paket `light_sensor: 3.0.2` hanya mendukung Android native dan tidak tersedia pada desktop/iOS. Pada platform non-Android atau perangkat fisik tanpa sensor cahaya ambient, `LightSensorService` mendeteksi ketersediaan sensor secara graceful dan fallback ke tema sistem (`ThemeMode.system`) disertai label kecil di UI Profile: *"Sensor cahaya tidak tersedia, mengikuti tema sistem."*. Sebagai fallback sensor kedua sesuai klausul PRD §10.4 ("minimal 2 sensor fisik perangkat"), ditambahkan kontrol kemiringan perangkat berbasis Gyroscope (`sensors_plus`) berupa opsi "Tilt Control" pada game Book Snake di samping kontrol sentuh/keyboard.
   - **Alasan:** Memenuhi mandat PRD §10.4 perihal verifikasi pub.dev dan fallback sensor kedua yang nyata serta interaktif, menjaga stabilitas multi-platform, dan memastikan aplikasi tidak mengalami unhandled exception saat sensor lux absen.

2. **Penyelarasan Named Arguments API `flutter_local_notifications: 22.3.2` (PRD §10.5)**
   - **Keputusan:** Metode `initialize(settings: ...)`, `zonedSchedule(id: ..., title: ..., body: ..., scheduledDate: ..., notificationDetails: ...)`, `show(id: ..., title: ..., body: ..., notificationDetails: ...)`, dan `cancel(id: ...)` ditulis menggunakan konvensi named arguments modern dari rilis versi 22.x.
   - **Alasan:** Mematuhi spesifikasi rilis breaking API terbaru `flutter_local_notifications` tanpa mengubah parameter fungsional PRD §10.5 (`reading_reminder`, `reading_timer`, `ongoing: true`, `usesChronometer: true`, `when`, `inexactAllowWhileIdle`, `matchDateTimeComponents: DateTimeComponents.time`).

---

## Fase B7 — Finalisasi & Kesiapan Rilis

1. **Pengalihan Default `USE_FAKE` ke `false` dan Eliminasi Data Demo (PRD §13.0 & §13.2)**
   - **Keputusan:** Mengubah nilai bawaan `AppConfig.useFakeData` dari `true` ke `false`. Komponen `DemoModeChip` secara otomatis menyembunyikan chip "Mode demo" di seluruh layar pada mode rilis/nyata (`!AppConfig.useFakeData`), dan `DemoControlsSheet` serta tombol simulasi biometrik diproteksi penuh hanya muncul pada `kDebugMode`.
   - **Alasan:** Menjamin alur aplikasi berjalan 100% menggunakan repository nyata (SQLite, Google Books, Supabase, OpenExchangeRates, Gemini, sensors_plus) tanpa ada data demo yang tampil di aplikasi rilis, sesuai ketentuan keras PRD §0 butir 3 & §13.0 aturan 5.

2. **Pengaktifan Core Library Desugaring Android (`desugar_jdk_libs`)**
   - **Keputusan:** Menambahkan `isCoreLibraryDesugaringEnabled = true` dan dependensi `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` pada `android/app/build.gradle.kts`.
   - **Alasan:** Memenuhi prasyarat build AAR metadata Android pada paket `flutter_local_notifications` versi modern saat mengompilasi APK Android dengan Java/Kotlin 17.

3. **Verifikasi Pub.dev dan Pelepasan Paket `light_sensor` (PRD §10.4)**
   - **Keputusan:** Paket `light_sensor: 3.0.2` pada pub.dev memiliki konfigurasi usang yang masih mereferensikan repositori `jcenter()` yang telah dihapus total pada Gradle 9, sehingga menyebabkan kegagalan evaluasi build Gradle Android. Sesuai instruksi PRD §10.4 dan prompt ("Verifikasi dulu paket sensor cahaya di pub.dev; jika bermasalah, pakai fallback gyroscope..."), paket tersebut dilepas dari dependensi proyek, dan digantikan secara elegan dengan fallback tema sistem pada `LightSensorService` serta sensor fisik kedua menggunakan Gyroscope (`sensors_plus`) untuk fitur Tilt Control di game Snake.
   - **Alasan:** Menjamin keberhasilan build APK rilis/debug Android sekaligus tetap memenuhi ketentuan minimal 2 sensor fisik perangkat nyata secara interaktif dan stabil.
