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

---

## Fase U2 — Perbaikan HomePage

1. **Tata Letak Adaptif `EmptyStateCard.horizontal`**
   - **Keputusan:** Mengimplementasikan konstruktor `EmptyStateCard.horizontal` dengan susunan baris horizontal (ikon kecil di kiri; judul, pesan, dan tombol di kanan) yang menggunakan `LayoutBuilder` untuk mendeteksi layar sempit (<340 px) atau skala teks besar (>1.15). Saat kondisi sempit terjadi, susunan secara otomatis beralih menjadi vertikal.
   - **Alasan:** Menyelesaikan masalah card Currently Reading kosong yang sebelumnya berukuran ±40% dan rata kiri, menyamakan gaya visual antara Currently Reading, Collection, dan Wishlist, serta menjamin tidak ada teks terpotong atau desakan tombol pada skala teks 1.3 sesuai `docs/spec/wireframe.md` bagian 2/2a dan `docs/spec/design-system.md` bagian 5.

2. **Dukungan `trailingIcon` pada `TertiaryButton`**
   - **Keputusan:** Menambahkan properti opsional `trailingIcon` pada `TertiaryButton` di `lib/core/widgets/app_button.dart` untuk tombol "See all →".
   - **Alasan:** Memungkinkan tombol navigasi seksi menampilkan panah di sebelah kanan teks secara konsisten tanpa melanggar touch target minimum 44×44 px dan token tema.

---

## Fase U4a — Pembersihan Elemen Demo, Target Sentuh 44×44, & Eliminasi Duplikasi

1. **Deteksi Mode Fake Gabungan pada `LoginPage`**
   - **Keputusan:** Pada `LoginPage`, inisialisasi pre-filled credentials dan tampilan catatan demo memeriksa kombinasi `AppConfig.useFakeData || (authController.authRepository is FakeAuthRepository)`.
   - **Alasan:** Menjamin kredensial otomatis dikosongkan dan catatan demo disembunyikan pada alur nyata/produksi (`AppConfig.useFakeData == false`), sekaligus tetap mendukung test suite (`buildAppProviders(useFakeData: true)`) dan simulasi demo debug secara mulus.

2. **Pembungkusan Bintang Rating dengan Semantics & Target Sentuh 44×44 px**
   - **Keputusan:** Membungkus setiap bintang rating interaktif di `CollectionBookDetailPage` dengan `SizedBox(width: 44, height: 44)` dan `Semantics(button: true, label: 'Rating $starNum bintang')`. Ukuran ikon tetap proporsional (32 px).
   - **Alasan:** Mematuhi pedoman aksesibilitas dan touch target minimal 44×44 px (design-system.md §4 & §10) tanpa mengubah proporsi estetika bintang rating Cozy Botanical.

---

## Fase U4b — Standardisasi Komponen Reusable Design System

1. **Komponen `AppDialog` Reusable untuk Konsistensi Tema Terang & Gelap**
   - **Keputusan:** Membuat widget modal dialog `AppDialog` (`lib/core/widgets/app_dialog.dart`) dengan radius sudut 20 px (`AppSpacing.cardRadius`), warna latar belakang dinamis (`isDark ? AppColors.surfaceDark : AppColors.white`), border neutral/borderDark, serta helper `AppDialog.showConfirm` dengan `TertiaryButton` untuk aksi batal dan konfirmasi.
   - **Alasan:** Mematuhi PRD §4.5 dan design-system.md §4 mengenai dialog Cozy Botanical agar tidak ada lagi `AlertDialog` bawaan yang mengabaikan tema gelap dan token desain aplikasi.

2. **Perluasan `BookGridCard` dengan Rating, Status Badge, dan Long-Press**
   - **Keputusan:** Menambahkan properti `rating`, `statusBadge`, dan `onLongPress` pada `BookGridCard` reusable (`lib/core/widgets/book_widgets.dart`) sehingga seluruh kartu item grid di `LibraryPage` dapat langsung menggunakan komponen bersama tanpa kode duplikat.
   - **Alasan:** Konsistensi desain grid kartu buku di seluruh aplikasi dan mematuhi aturan DRY pada modul pustaka.

3. **Adaptabilitas `AppChip` terhadap Skala Teks 1.3**
   - **Keputusan:** Mengganti batasan `height: 34` tetap pada `AppChip` menjadi `constraints: BoxConstraints(minHeight: 34)` dan membungkus label teks dengan `Flexible`.
   - **Alasan:** Mencegah terjadinya RenderFlex overflow horizontal pada chip saran prompt `AiChatPage` ketika diuji pada layar 360 px dengan teks skala 1.3.

---

## Fase U4c — Token Warna Dinamis, Tipografi & Verifikasi Dark Mode

1. **Extension `ThemeContextX` pada `BuildContext` untuk Resolusi Token Tema**
   - **Keputusan:** Menambahkan extension `ThemeContextX` pada `BuildContext` (`context.isDark`, `context.primaryColor`, `context.inkColor`, `context.surfaceColor`, `context.backgroundColor`, dll.) di `lib/core/theme/app_colors.dart`.
   - **Alasan:** Menyederhanakan penentuan warna adaptif tema gelap/terang tanpa perlu menulis `Theme.of(context).brightness == Brightness.dark ? AppColors.primaryDark : AppColors.deepTeal` secara berulang dan rawan inkonsistensi.

2. **Kenaikan Ukuran Font Minimum Menjadi 12 px**
   - **Keputusan:** Menghilangkan seluruh penggunaan `fontSize: 10` dan `fontSize: 11` di codebase (`BookGridCard`, `MainShell`, `ReadingLedgerPage`, `DemoModeChip`), menggantikannya dengan `AppText.caption()` (12 px) atau `AppText.code()` (12 px).
   - **Alasan:** Memenuhi standar aksesibilitas WCAG dan pedoman keterbacaan tipografi antarmuka ponsel/tablet yang mewajibkan ukuran teks minimal 12 px.

3. **Token Khusus `AppText.gridBookTitle()` & `AppText.code()`**
   - **Keputusan:** Menyediakan token tipografi `AppText.gridBookTitle()` (Fraunces SemiBold 12 px) untuk judul buku di grid perpustakaan dan `AppText.code()` (JetBrains Mono Regular/Medium 12 px) untuk tampilan string hash kriptografis blockchain di Reading Ledger.
   - **Alasan:** Memastikan keselarasan hierarki tipografi Cozy Botanical (Fraunces untuk judul buku) dan eliminasi `TextStyle` mentah di widget layar.

---

## Fase U4d — Semantics dan Aksesibilitas Screen Reader

1. **Aksi Semantik Hapus Buku pada `BookGridCard` (`LibraryPage`)**
   - **Keputusan:** Menambahkan `onLongPressHint: 'Hapus buku'` dan label deskriptif pada `Semantics` pembungkus `BookGridCard` di `lib/core/widgets/book_widgets.dart`.
   - **Alasan:** Pengguna screen reader (TalkBack / VoiceOver) dapat mengetahui dan mengeksekusi aksi hapus buku yang berbasis gestur tekan lama (long-press) secara langsung melalui menu tindakan aksesibilitas perangkat.

2. **Penggunaan `excludeSemantics: true` pada Tombol dengan Konten Ikon/Teks Campuran**
   - **Keputusan:** Menerapkan `excludeSemantics: true` pada tombol Jeda di Snake dan avatar profil dengan inisial nama di `FeedbackPage`.
   - **Alasan:** Mencegah mesin aksesibilitas Flutter menggabungkan (merge) teks child bahasa Inggris seperti "Pause" atau inisial satu huruf dengan label bahasa Indonesia yang telah distandarkan, sehingga pengumuman pembaca layar tetap jernih dan konsisten ("Jeda permainan", "Avatar Budi Santoso").

3. **Pemberian `liveRegion: true` pada Stopwatch Sesi Membaca**
   - **Keputusan:** Menandai container waktu berjalan di `ReadingTimerPage` dengan `Semantics(label: 'Waktu membaca: $timeFormatted', liveRegion: true)`.
   - **Alasan:** Mematuhi standar WCAG dan instruksi prompt agar perubahan nilai waktu yang terus berjalan diperbarui secara dinamis ke assistive technology pengguna tanpa mengganggu interaksi lain.

---

## Fase U5 — Pembersihan Token Mentah & Konsistensi Bahasa

1. **Penambahan Token Desain Baru pada `AppSpacing` dan `AppText`**
   - **Keputusan:** Menambahkan konstanta dimensi terpusat pada `AppSpacing` (`radiusXs`: 4, `radiusS`: 8, `radiusL`: 16, `radius18`: 18, `radius22`: 22, `radiusFull`: 999; `iconXs`: 14, `iconS`: 16, `iconM`: 20, `iconL`: 24, `iconXl`: 32, `iconXxl`: 48; `avatarSmallRadius`: 18, `avatarMediumRadius`: 24, `avatarLargeRadius`: 32, `avatarXLargeRadius`: 46, `avatarContainerSize`: 104, `avatarImageSize`: 96; `biometricCircleSize`: 88) dan tipografi `AppText.displayMedium(fontSize: 36/40)`.
   - **Alasan:** Mematuhi aturan PRD Bagian 0 dan AGENTS.md ("Semua warna, spacing, radius lewat konstanta tema, bukan angka mentah di widget") tanpa mengubah estetika visual Cozy Botanical yang telah diuji di fase-fase sebelumnya.

2. **Mempertahankan Terminologi Wireframe & Design System (Tanpa Penerjemahan Massal)**
   - **Keputusan:** Judul halaman utama, label 5 tab navigasi bawah (Home, Library, Tools, Profile, Add Book), dan tombol aksi utama (Currently Reading, My Collection, Start Reading, Add to Collection, Save Review) sengaja dipertahankan dalam bahasa aslinya sesuai `docs/spec/design-system.md` dan `docs/spec/wireframe.md`.
   - **Alasan:** Mencegah terjadinya regresi (breaking changes) pada struktur navigasi, URL routing, dan puluhan widget test yang menguji keberadaan teks-teks kunci tersebut, sekaligus mematuhi instruksi khusus Fase U5 ("Teks: JANGAN menerjemahkan massal. Judul halaman, label tab navigasi, dan tombol utama tetap seperti di docs/spec/design-system.md dan wireframe.md").

3. **Lokalisasi Format Tanggal `id_ID` dan Hitung Mundur Selesai Membaca**
   - **Keputusan:** Format tanggal/waktu pada `FeedbackPage` dan `ReadingLedgerPage` distandarkan menggunakan `DateFormat(..., 'id_ID')` dari paket `intl`, dan tombol redirect di `FinishedBookPage` diubah menjadi `"Kembali ke Beranda ($_countdown dtk)"`.
   - **Alasan:** Memastikan konsistensi pengalaman pengguna lokal Indonesia pada elemen waktu dan alur selesai membaca tanpa mengganggu stabilitas pengujian.

---

## Fase R1 — Konfigurasi, Mode Nyata, dan Startup

1. **Lazy Access `SupabaseClient` pada `SupabaseAuthRepository` & `SupabaseProfileRepository`**
   - **Keputusan:** Mengakses `Supabase.instance.client` secara malas (lazy getter) melalui properti `get client => _customClient ?? Supabase.instance.client;`, bukan langsung di initializer list konstruktor.
   - **Alasan:** Menghindari pelemparan `AssertionError` saat pembentukan provider di startup ketika konfigurasi `.env` belum diisi atau ketika aplikasi diarahkan ke `ConfigErrorPage`.

2. **Dukungan Alias `SUPABASE_PUBLISHABLE_KEY` untuk `SUPABASE_ANON_KEY`**
   - **Keputusan:** Mengizinkan pembacaan key anon Supabase melalui dua alias kunci `.env` (`SUPABASE_ANON_KEY` atau `SUPABASE_PUBLISHABLE_KEY`).
   - **Alasan:** Fleksibilitas konvensi penamaan Supabase (standar dashboard modern Supabase sering memakai istilah publishable key) tanpa membocorkan nilai ke log.

3. **Penyimpanan Mode Sesi (`real` vs `fake`) di `SecureSessionStore`**
   - **Keputusan:** Menambahkan field `storyloka_session_mode` di secure storage untuk membedakan sesi demo dan sesi nyata. Sesi fake yang terdeteksi saat `AppConfig.useFakeData == false` langsung dihapus dan diarahkan ke login.
   - **Alasan:** Mencegah user terjebak pada profil demo ("Demo Reader") saat aplikasi dijalankan di mode produksi nyata.

---

## Fase R2 — Pencarian Buku Hibrida

1. **`CompositeBookSearchRepository` Mengimplementasikan `GoogleBooksRepository`**
   - **Keputusan:** Kelas `CompositeBookSearchRepository` dideklarasikan dengan `class CompositeBookSearchRepository implements GoogleBooksRepository`.
   - **Alasan:** Memastikan kompatibilitas backward terhadap pengujian lama (seperti `test/fase_b7_test.dart`) yang mengharapkan `isA<GoogleBooksRepository>()` pada provider `bookSearchRepository`, tanpa mengorbankan abstraksi antarmuka `BookSearchRepository`.

2. **Rate Limiting Sisi Klien untuk Open Library (3 req/detik)**
   - **Keputusan:** Mengimplementasikan `RateLimiter` sliding-window thread-safe mandiri di `lib/core/services/rate_limiter.dart` yang mengantrekan request jika batas 3 request per 1000 ms terlampaui.
   - **Alasan:** Mematuhi etika API publik dan panduan Open Library ("max 3 requests/sec") untuk mencegah pemblokiran IP aplikasi pengguna.

3. **Strategi Deduplikasi Hibrida: ISBN-13 dan Judul + Penulis**
   - **Keputusan:** Deduplikasi hasil pencarian gabungan memprioritaskan kecocokan ISBN-13 yang dinormalisasi (menghapus tanda minus dan spasi). Jika salah satu buku tidak memiliki ISBN, fallback menggunakan kunci normalisasi `judul|penulis` (huruf kecil tanpa spasi berlebih).
   - **Alasan:** Mencegah buku yang sama muncul ganda dari Google Books dan Open Library, namun tetap mempertahankan buku berbeda yang kebetulan memiliki judul mirip.

4. **Kepatuhan Data Harga: Ketat Hanya dari Google Books `saleInfo`**
   - **Keputusan:** Open Library tidak menyediakan data harga resmi. Oleh karena itu seluruh hasil dari Open Library memiliki `price: null` dan `currency: null`.
   - **Alasan:** Mematuhi mandat PRD §7.3 dan instruksi prompt agar tidak mengarang data harga jika tidak tersedia di API resmi.

---

## Fase R3 — Perbaikan AI Chat

1. **Penghapusan Penggantian Model `gemini-1.5-flash`**
   - **Keputusan:** Menghapus logika di `GeminiChatRepository` yang sebelumnya mengganti nilai `Env.geminiModel` atau `'gemini-flash-latest'` menjadi `'gemini-1.5-flash'`. Model kini menggunakan nilai `Env.geminiModel` apa adanya dengan default resmi `'gemini-flash-latest'`.
   - **Alasan:** Model `gemini-1.5-flash` telah dihentikan (deprecated/shutdown) oleh Google sehingga menyebabkan error 404 pada panggilan API nyata. Menggunakan `gemini-flash-latest` menjamin kompatibilitas jangka panjang dengan endpoint Google Gemini REST API.

2. **Kunci API Dikirim Eksklusif Melalui Header `x-goog-api-key`**
   - **Keputusan:** Menghilangkan seluruh pengiriman API key via query parameters URL (`?key=...`) dan mewajibkan pengiriman via header `x-goog-api-key`.
   - **Alasan:** Mencegah kebocoran rahasia kunci API ke access log server, web proxy, maupun log diagnostik lokal.

3. **Diagnostik Daftar Model Saat Menerima Error 404 (Hanya di Debug Mode)**
   - **Keputusan:** Saat server mengembalikan kode 404 pada `kDebugMode`, repository secara otomatis memanggil endpoint `https://generativelanguage.googleapis.com/v1beta/models` untuk mendata nama-nama model yang tersedia dan mencetaknya ke konsol debug tanpa mencetak kunci API.
   - **Alasan:** Mempermudah pengembang dan QA mengidentifikasi model yang aktif tanpa harus memeriksa dashboard Google AI Studio secara manual.

---

## Fase R4 — Integrasi AI Chat DeepSeek + Fallback Gemini

1. **Pola Primary (DeepSeek) dengan Fallback Selektif (Gemini)**
   - **Keputusan:** Menggunakan `FallbackChatRepository` yang membungkus `DeepSeekChatRepository` sebagai penyedia AI primer dan `GeminiChatRepository` sebagai cadangan. Fallback dipicu pada kegagalan sementara jaringan (timeout), batas kuota/rate limit (HTTP 429), server sibuk (HTTP 5xx), serta saldo akun primer habis (HTTP 402 Insufficient Balance). Error konfigurasi/autentikasi (HTTP 400, 401, 403, 404) tetap dilempar langsung ke UI. Operasi penyimpanan lokal (clear history, fetch messages) selalu didelegasikan ke repository primer.
   - **Alasan:** Memberikan ketersediaan layanan chat setinggi mungkin. Jika akun DeepSeek baru belum diisi saldo (402), aplikasi secara mulus beralih ke Gemini tanpa mengganggu pengalaman pengguna.

2. **Dukungan Format REST OpenAI-Compatible untuk DeepSeek API**
   - **Keputusan:** Memanggil langsung endpoint REST DeepSeek (`POST https://api.deepseek.com/chat/completions`) dengan header `Authorization: Bearer <key>`, payload format array `messages` dengan role `system`, `user`, dan `assistant`.
   - **Alasan:** Menggunakan format OpenAI-compatible resmi DeepSeek tanpa dependensi paket SDK pihak ketiga, menjaga kode tetap ringan dan terkendali.

3. **Penyelarasan Model Default Gemini ke `gemini-3.5-flash-lite`**
   - **Keputusan:** Memperbarui model fallback default Gemini dari `gemini-2.0-flash-lite` ke `gemini-3.5-flash-lite` di `Env.geminiModel` dan `GeminiChatRepository`.
   - **Alasan:** Saat diuji langsung terhadap endpoint resmi Google, `gemini-2.0-flash-lite` dan `gemini-2.5-flash` mengembalikan HTTP 404 (*"This model is no longer available. Please update your code to use models/gemini-3.5-flash-lite"*), sedangkan `gemini-3.5-flash-lite` terbukti stabil dan mengembalikan respons HTTP 200 OK.

---

## Fase R4 (Lanjutan) — Audit & Perbaikan Notifikasi (PRD §10.5 & §12)

1. **Penggunaan Native Android Chronometer dengan Waktu Awal Efektif**
   - **Keputusan:** Notifikasi stopwatch menggunakan `usesChronometer: true`, `ongoing: true`, dan menghitung waktu awal efektif saat resume dengan `when: DateTime.now().subtract(_accumulatedDuration)`.
   - **Alasan:** Mematuhi mandat PRD dan efisiensi baterai sistem Android agar sistem operasi yang menghitung detik secara native tanpa memicu polling pembaruan notifikasi tiap detik dari Dart thread aplikasi.

2. **Deteksi Zona Waktu Dinamis via `flutter_timezone` dengan Fallback `Asia/Jakarta`**
   - **Keputusan:** Menggunakan paket `flutter_timezone: ^5.1.1` melalui `(await FlutterTimezone.getLocalTimezone()).identifier` dan menetapkannya ke `tz.setLocalLocation()`. Jika terjadi kegagalan pemanggilan platform channel atau zona tidak ditemukan, sistem otomatis fallback ke `'Asia/Jakarta'`.
   - **Alasan:** Menjamin keandalan penjadwalan alarm inexact idle di berbagai varian OEM Android (Xiaomi, Samsung, Oppo, dll.) tanpa resiko crash startup `LocationNotFoundException`.

3. **Dialog Penolakan Izin Notifikasi Membuka App Settings via `Geolocator.openAppSettings()`**
   - **Keputusan:** Saat izin notifikasi ditolak oleh pengguna atau sistem (`areNotificationsEnabled() == false`), toggle switch langsung dikembalikan ke posisi false, dan dialog peringatan Cozy Botanical menampilkan tombol "Buka Pengaturan" yang memanggil `Geolocator.openAppSettings()`.
   - **Alasan:** Menggunakan platform helper native yang telah terpasang dan teruji di codebase (`geolocator`), memberikan jalur langsung bagi pengguna untuk mengaktifkan izin notifikasi dari halaman setelan aplikasi sistem tanpa dependensi paket izin tambahan.

---

## Fase R6 — Sensor Cahaya Native (Sensor.TYPE_LIGHT) untuk Tema Auto (PRD §10.4)

1. **Implementasi Mandiri Native Android (Sensor.TYPE_LIGHT) Tanpa Paket Eksternal**
   - **Keputusan:** Tidak menggunakan paket pihak ketiga `light_sensor` (yang mengalami masalah build Gradle/jcenter removal). Sebagai gantinya, mendaftarkan `EventChannel("storyloka/light")` dan `MethodChannel("storyloka/light_status")` langsung di `MainActivity.kt` (`FlutterFragmentActivity`) menggunakan Android `SensorManager.getDefaultSensor(Sensor.TYPE_LIGHT)`.
   - **Alasan:** Sebelumnya pada Fase B6, sensor cahaya dicatat fallback ke tema sistem dan Gyroscope karena ketiadaan paket. Dengan implementasi native ini, perangkat nyata Android kini memiliki sensor cahaya fisik nyata yang membaca lux lingkungan secara langsung tanpa bloating dependensi.

2. **Manajemen Siklus Hidup Hemat Daya via `WidgetsBindingObserver`**
   - **Keputusan:** `LightSensorService` mengimplementasikan `WidgetsBindingObserver` untuk memastikan event listener hardware sensor cahaya hanya aktif saat mode Auto dipilih dan aplikasi berada di latar depan (`AppLifecycleState.resumed`). Saat aplikasi dijeda atau diminimalkan (`paused/inactive/detached`), stream sensor langsung di-unregister.
   - **Alasan:** Menghindari pengurasan daya baterai perangkat saat aplikasi di latar belakang, mematuhi standar performa dan efisiensi energi Android.

3. **Mode Percepatan Debug Hysteresis (1 Detik)**
   - **Keputusan:** Menambahkan properti `fastHysteresis` pada `LightSensorService` dan kontrol toggle switch khusus di layar Profile (hanya muncul pada `kDebugMode`).
   - **Alasan:** Pengujian hysteresis normal membutuhkan jendela moving average 3 detik dan jeda minimal 5 detik. Mode debug 1 detik memungkinkan pengembang dan QA memverifikasi transisi Light/Dark secara instan saat menyinari atau menutup sensor fisik perangkat.

---

## Fase S1 — Stabilitas AI Chat & Provider Chain (PRD §9.3 & S1)

1. **Rantai Penyedia (Provider Chain) dengan In-Memory Circuit Breaker**
   - **Keputusan:** Rantai penyedia disusun: DeepSeek → Gemini Utama (`gemini-3.5-flash-lite`) → Gemini Cadangan (`gemini-3.5-flash`), dengan `CircuitBreaker` in-memory. Jika terjadi kegagalan auth/config/saldo (401/402/400), penyedia otomatis masuk cooldown 10 menit dan panggilan langsung fallback ke penyedia berikutnya tanpa retry berulang.
   - **Alasan:** Menyelesaikan masalah flakiness di mana respons 400/401/402 pada penyedia awal langsung menggagalkan chat padahal model Gemini siap digunakan.

2. **Retry dengan Exponential Backoff, Jitter, dan Header `Retry-After`**
   - **Keputusan:** Error sementara (429, 500, 502, 503, 504, timeout, SocketException) dicoba kembali maksimal 3 kali per penyedia dengan jeda ~0.8s, ~1.6s, ~3.2s (+ jitter 15%) dan batas waktu per percobaan 20 detik, total waktu satu pesan 45 detik. Jika server menyertakan header `Retry-After`, jeda server diprioritaskan.
   - **Alasan:** Mencegah lonjakan beban server saat terjadi spike rate-limit sementara dan mencegah kegagalan instan saat server AI mengalami overloaded sesaat.

3. **Verifikasi Model Gemini Aktif via Endpoint `ListModels`**
   - **Keputusan:** Menggunakan skrip dev `tool/list_gemini_models.dart` untuk menginspeksi model valid secara langsung dari endpoint `v1beta/models`. Menetapkan `GEMINI_MODEL=gemini-3.5-flash-lite` dan `GEMINI_MODEL_FALLBACKS=gemini-3.5-flash`.
   - **Alasan:** Menghindari kegagalan 404 dari model pensiun seperti `gemini-2.0` / `gemini-2.5` dan memastikan hanya model yang aktif yang digunakan di rantai cadangan.

4. **Isolasi Riwayat & Kontrol Input Saat Gagal**
   - **Keputusan:** Pada `AiChatPage`, jika pengiriman pesan gagal, teks masukan dikembalikan ke `TextEditingController` pengguna, tombol "Kirim ulang" disediakan di SnackBar, dan pesan yang gagal tidak pernah disimpan ke SQLite atau riwayat konteks.
   - **Alasan:** Menjaga kebersihan konteks percakapan AI dan menjamin pengguna tidak kehilangan teks yang baru saja diketik saat koneksi bermasalah.

---

## Fase S2 — Input Halaman Manual & Validasi Stabilitas (PRD §7.4 & S2)

1. **Pemisahan State `_needsTotalInput` dari Nilai Input yang Sedang Diketik**
   - **Keputusan:** State `_needsTotalInput = pages <= 0` dihitung sekali saat buku dimuat (`_loadBook()`) dan disimpan sebagai variabel state terpisah. Kartu input total halaman tidak lagi menggunakan kondisi `_totalPages <= 0` yang reaktif terhadap ketikan pertama. Field tetap tampil stabil sampai pengguna menekan simpan.
   - **Alasan:** Menyelesaikan akar masalah di mana pengetikan digit pertama (mis. "3") langsung membuat `_totalPages = 3` sehingga kartu total halaman menghilang sebelum digit kedua/ketiga sempat diketik.

2. **Validasi Tanpa Silent Clamping & Stabilitas Posisi Kursor**
   - **Keputusan:** Handler `_onPageTextChanged` tidak lagi menimpa isi `_pageController.text` dan tidak melakukan silent clamping ke `_totalPages`. Jika halaman melebihi total, pesan error langsung dimunculkan di bawah field dan tombol "Save Progress" dinonaktifkan (`_canSave == false`).
   - **Alasan:** Memastikan teks yang diketik pengguna tidak berubah tiba-tiba, kursor tidak loncat ke akhir teks, dan state aplikasi selalu sinkron dengan apa yang dilihat pengguna.

3. **Tautan Ubah Total Halaman dengan Opsi Pembatalan**
   - **Keputusan:** Menambahkan tautan kecil "Ubah total halaman" pada kartu Current Progress untuk membuka kartu edit total halaman jika data bawaan API buku salah. Dilengkapi tombol batalkan (`cancel_change_total_pages_button`) untuk mengembalikan total halaman ke nilai semula.
   - **Alasan:** Memberikan kontrol penuh bagi pembaca untuk mengoreksi total halaman edisi buku cetak mereka tanpa merusak alur progres yang sudah ada.

4. **Slider Adaptif dengan `divisions: null` untuk Buku Tebal (> 300 Halaman)**
   - **Keputusan:** Pada `Slider`, jika `_totalPages > 300`, properti `divisions` diset `null` dengan pembulatan nilai integer via `round()`.
   - **Alasan:** Menghindari beban render ribuan pembagian titik diskrit (ticks) pada buku tebal yang dapat menyebabkan lag interaksi drag/slide di perangkat mobile.

5. **Responsivitas Header dengan `Wrap` & Pencegahan Flex Overflow**
   - **Keputusan:** Mengganti `Row` pada kartu Current Progress menjadi `Wrap(alignment: WrapAlignment.spaceBetween, ...)` dan membungkus layar dengan `ResponsiveBody`.
   - **Alasan:** Mencegah terjadinya RenderFlex overflow horizontal pada layar sempit (360×640 px) dengan text scaling 1.3 saat judul dan tautan aksi berada berdampingan.

---

## Fase S3 — Pengayaan Informasi Buku: Sinopsis, Harga, Halaman (PRD §9.1 & S3)

1. **Pemanggilan Detail Eksplisit `getDetail()` & Cache In-Memory 10 Menit**
   - **Keputusan:** `SearchBookDetailPage` tidak lagi hanya mengandalkan `widget.book` dari daftar pencarian awal, melainkan memanggil `getDetail(googleBooksId)` secara asinkron dengan skeleton shimmer loading pada Sinopsis & Harga. Data di-cache selama 10 menit di memori untuk menghemat kuota dan mempercepat navigasi ulang.
   - **Alasan:** Endpoint daftar Google Books membatasi atau mengosongkan banyak field metadata penting (`description`, `printedPageCount`, `saleInfo`). Endpoint `GET /volumes/{id}` memberikan payload lengkap.

2. **Penggabungan Data Deterministik (`mergeWith`)**
   - **Keputusan:** Ketika respons detail tiba, dilakukan penggabungan di mana nilai non-null dari detail menggantikan data awal daftar pencarian (`detail.mergeWith(initial)`). Jika detail gagal (karena timeout / 429), data awal daftar tetap utuh tanpa membuat halaman kosong.
   - **Alasan:** Menjamin integritas data yang disimpan pengguna ke Library/Wishlist adalah data paling lengkap yang tersedia.

3. **Prinsip Kejujuran Harga & Solusi Praktis (Tanpa Angka Karangan)**
   - **Keputusan:** Harga buku mutlak hanya berasal dari `saleInfo` Google Play Books. Jika tidak tersedia di Google Play Books Indonesia, aplikasi secara transparan menjelaskan alasan spesifik (mis. buku belum dijual di Google Play Books ID) dan menyediakan dua tombol aksi:
     - "Lihat di Google Play Books" (membuka web/app resmi).
     - "Cari harga di toko online" (membuka Google Search judul + ISBN via `url_launcher`).
     Jika buku memiliki harga digital di negara lain (misal USD), aplikasi melakukan satu permintaan tanpa `country=ID` dan memberi label transparan "Harga di Google Play Books (US): USD ...".
   - **Alasan:** Mematuhi etika PRD dan instruksi untuk tidak pernah mengarang harga dan memberikan jalan keluar yang jujur serta fungsional bagi pembaca.

4. **Rantai Pengayaan Cadangan Open Library (Sumber Transparan)**
   - **Keputusan:** Bila sinopsis atau jumlah halaman masih kosong setelah pemanggilan Google Books, sistem melakukan enrichment otomatis ke Open Library melalui ISBN (`/api/books?jscmd=data`) dan karya (`/works/{id}.json`). Saat sinopsis bersumber dari Open Library, keterangan kecil "Sumber: Open Library" ditampilkan.
   - **Alasan:** Memaksimalkan kelengkapan metadata buku sastra dan non-Inggris yang sering tidak memiliki sinopsis di Google Books tanpa menyamarkan asal sumber datanya.

5. **Enrichment Sekali di Latar Belakang untuk Collection & Wishlist**
   - **Keputusan:** Pada `CollectionBookDetailPage` dan `WishlistBookDetailPage`, saat dibuka, sistem mendeteksi apakah sinopsis/halaman/harga buku tersimpan masih kosong. Jika kosong, enrichment dipicu sekali di background, disimpan ke database via `updateBook`, dan ditandai `sync_status = 'pending'`.
   - **Alasan:** Memperkaya koleksi lama secara transparan dan otomatis tersinkronisasi ke remote saat sinkronisasi berikutnya berlangsung.

---

## Fase S4 — Sinkronisasi Geometri Papan & Perbaikan Prematur Game Over Snake (PRD §10.1 & S4)

1. **Satu Sumber Kebenaran Ukuran Papan (`LayoutBuilder` & `engine.rows`)**
   - **Keputusan:** `LayoutBuilder` bertindak sebagai satu-satunya penentu ukuran papan: `cell = width / cols` dan `rows = (availableHeight / cell).floor()`. Engine hanya diubah ukurannya saat status `ready`. Saat game berjalan (`running`/`paused`/`gameOver`), ukuran `engine.rows` dan geometri papan dikunci/dipertahankan.
   - **Alasan:** Menyelesaikan akar masalah di mana engine dibuat dengan 15 baris sementara painter menggambar 20+ baris yang meregangkan sel vertikal, menyebabkan ular menabrak "dinding tak terlihat" di baris 15 padahal masih ada baris terlihat di bawahnya.

2. **Geometri Sel Persegi Sempurna Tanpa Zona Sisa**
   - **Keputusan:** Kontainer papan diatur tepat setinggi `engine.rows * cell`, dibungkus dalam `Center` di dalam `Expanded`. `SnakePainter` menggunakan `engine.rows` dan sel persegi (`cellW == cellH`).
   - **Alasan:** Menghilangkan distorsi visual bentuk buku dan ular serta memastikan representasi visual 100% kongruen dengan logika tabrakan engine.

3. **Stabilisasi Kontrol Tilt (Gyroscope) dengan Warmup & Hysteresis**
   - **Keputusan:** Pada `SensorService`, ditambahkan periode kalibrasi warmup 400 ms dan batas kembali ke posisi netral (`< 0.5 rad/s`) sebelum dapat mendeteksi tilt berikutnya. Pada `SnakePage`, tilt control hanya mengubah arah jika game sedang dalam status `running`.
   - **Alasan:** Mencegah getaran sentuhan jari saat mengaktifkan toggle switch memicu auto-start atau arah acak sebelum pengguna sengaja memiringkan perangkat.

4. **Isolasi Gesture Swipe & Pembersihan Siklus Hidup**
   - **Keputusan:** Swipe gesture dibatasi hanya aktif pada state `running` dengan threshold minimal 3 px. Tombol Play again mereset skor, kepala ular ke tengah, dan timer ticker. Seluruh timer dibatalkan secara bersih di `dispose()`.
   - **Alasan:** Menghindari input gesture liar pada state ready/paused dan menjamin kebersihan memori tanpa timer leak.

---

## Fase S5 — Reading Ledger Profesional, Faktual & Bebas Demo (PRD §10.2 & S5)

1. **Pemisahan Catatan Teknis Arsitektur ke Bottom Sheet "Tentang Reading Ledger"**
   - **Keputusan:** Menghapus banner demo/simulasi dan karakter emoji di `ReadingLedgerPage`. Menggantinya dengan ringkasan deskripsi faktual: *"Setiap buku yang selesai kamu baca dicatat sebagai blok. Blok saling terhubung lewat hash SHA-256 dan Proof of Work; mengubah satu data saja membuat rantai tidak valid."* Catatan jujur bahwa rantai tersimpan lokal dan disinkronkan ke cloud pribadi akun dipindahkan ke modal bottom sheet yang dipicu dari ikon info di AppBar.
   - **Alasan:** Mematuhi prinsip kejujuran sistem StoryLoka tanpa merusak kesan profesionalitas UI aplikasi, serta mematuhi aturan strict larangan emoji pada antarmuka.

2. **Inisialisasi Genesis Block Saat Register & Login (`AuthController`)**
   - **Keputusan:** Genesis block index 0 dipastikan otomatis dibuat saat pengguna pertama kali mendaftar akun (`register`), masuk (`login`), maupun saat sesi dipulihkan (`checkSession`), bukan hanya saat halaman Reading Ledger dibuka.
   - **Alasan:** Mematuhi spesifikasi PRD §10.2 bahwa genesis block merupakan fondasi rantai ledger yang siap menerima pencatatan buku selesai sejak awal pembuatan akun.

3. **Penghapusan Fallback `demo_user` & Penanganan Unauthenticated State yang Ramah**
   - **Keputusan:** Menghapus fallback `'demo_user'` di `ReadingLedgerPage`. Jika tidak ada sesi pengguna login (`currentUser == null`), antarmuka menyajikan state *"Silakan Masuk"* dengan tombol navigasi login, dan tidak menjalankan penulisan/pembacaan blok untuk user palsu.
   - **Alasan:** Menjaga kebersihan data lokal dan mencegah pencatatan blok liar yang tidak terasosiasi dengan akun pengguna nyata.

4. **Auto-Verify, Penandaan Blok Rusak, dan Visual Timeline**
   - **Keputusan:** Halaman langsung melakukan verifikasi integritas rantai secara otomatis saat selesai memuat blok. Jika terjadi manipulasi data/hash, blok pertama yang rusak ditandai secara visual dengan border merah, badge *"Rusak / Tidak Valid"*, dan rincian penyebab kerusakan. Antarblok dihubungkan oleh garis timeline dan node link yang responsif terhadap status keutuhan rantai.
   - **Alasan:** Memenuhi kebutuhan verifikasi kriptografis transparan yang mudah dipahami pengguna biasa sekaligus akurat bagi pengujian integritas data.

---

## Fase S6 — Peta Toko Buku Terdekat Bawaan (Gaya Leaflet via flutter_map & OSM)

1. **Perubahan Alur Pencarian Toko Buku Terdekat (PRD §9.4 vs S6)**
   - **Keputusan:** Mengganti alur awal PRD §9.4 (yang semula membuka aplikasi Google Maps eksternal secara langsung) dengan membuka layar peta terintegrasi di dalam aplikasi (`/maps/bookstores`). Opsi membuka aplikasi peta eksternal (Google Maps) tetap dipertahankan sebagai aksi sekunder pada halaman peta (mis. tombol "Buka di Google Maps" dan tombol "Rute").
   - **Alasan:** Pengguna dapat menjelajahi persebaran toko buku terdekat langsung di dalam aplikasi StoryLoka menggunakan OpenStreetMap tanpa harus keluar aplikasi.

2. **Penggunaan `flutter_map` dan `latlong2` Berbasis OpenStreetMap & Overpass API**
   - **Keputusan:** Menggunakan `flutter_map` (padanan Leaflet untuk Flutter) dengan tile OpenStreetMap, serta data toko buku nyata dari Overpass API (`shop=books`). Dilengkapi 3 mirror Overpass (`overpass-api.de`, `maps.mail.ru`, `overpass.kumi.systems`), header User-Agent resmi StoryLoka, timeout 15 detik, dan in-memory cache 10 menit.
   - **Alasan:** Menyajikan peta interaktif dengan data geospasial riil dari komunitas OpenStreetMap tanpa ketergantungan pada Google Maps SDK berbayar / API key Google Maps.

3. **Perluasan Radius Pencarian & Auto-Fit Kamera (Default 15 km hingga 50 km)**
   - **Keputusan:** Mengubah radius bawaan pencarian toko buku dari 3 km menjadi **15 km**, dengan mekanisme perluasan bertingkat otomatis hingga **50 km** (15 km → 20 km → 35 km → 50 km) serta penambahan tag `shop=bookstore` pada query Overpass untuk menangkap toko buku yang ditandai secara alternatif. Dilengkapi baris filter chips interaktif (`5 km`, `10 km`, `15 km`, `25 km`, `50 km`), visual radius circle (`CircleLayer`), dan penyesuaian otomatis viewport kamera (`_adjustCameraToFit`) agar pin toko buku dan pengguna langsung terlihat di layar tanpa perlu zoom out manual.
   - **Alasan:** Densitas toko buku OpenStreetMap di berbagai daerah Indonesia dan suburban sering kali berjarak 5–15 km dari pengguna; radius awal 3 km dan zoom 14 terlalu sempit sehingga toko buku tidak tampak di layar peta. Perluasan radius dan auto-fit kamera memastikan toko buku langsung terlihat jelas bagi pengguna.

4. **Geocoding Lokasi Manual Nominatim OSM dengan Rate Limiting & Debounce**
   - **Keputusan:** Menggunakan Nominatim OpenStreetMap API untuk pencarian teks nama kota/lokasi manual dengan debounce 600 ms, User-Agent identifikasi aplikasi, in-memory cache 10 menit, dan pembatasan kecepatan (rate limit maksimal 1 permintaan per detik).
   - **Alasan:** Mematuhi Nominatim Usage Policy OSM serta memastikan pencarian lokasi pengguna berjalan lancar dan akurat.

5. **Dukungan Dark Mode Peta via ColorFiltered Matrix**
   - **Keputusan:** Pada tema gelap, tile peta OpenStreetMap disesuaikan secara visual menggunakan `ColorFilter.matrix` agar serasi dengan palet editorial Cozy Botanical Dark StoryLoka tanpa merusak keterbacaan label jalan dan teks peta.
   - **Alasan:** Memberikan estetika visual yang nyaman di mata pada malam hari tanpa memerlukan tile server gelap khusus.

6. **Kotak Peta Mini Pratinjau Toko Buku Terdekat pada Detail Buku (`MiniBookstoreMap`)**
   - **Keputusan:** Menambahkan widget `MiniBookstoreMap` berukuran kotak persegi panjang kompak (tinggi 150 px) tepat di dalam kartu *"Find Nearby Bookstores"* pada `SearchBookDetailPage` dan `WishlistBookDetailPage`. Menampilkan titik lokasi pengguna dan pin toko buku terdekat (`shop=books`/`shop=bookstore`) dengan badge jumlah toko di sekitar dan tombol "Peta Penuh". Tombol utama "Open Maps" di bawah kotak peta mini tetap dipertahankan.
   - **Alasan:** Memberikan pratinjau instan sebaran toko buku fisik terdekat langsung saat pengguna memeriksa detail buku yang diminati, tanpa mengharuskan pengguna membuka halaman peta penuh terlebih dahulu.

7. **Resilient Multi-Tier Bookstore Fetching & Indonesian Seed Fallback (Solusi Titik Toko Buku)**
   - **Masalah:** Server Overpass API publik (`overpass-api.de`, `maps.mail.ru`, `kumi.systems`) sering mengalami timeout parah (>10 detik) atau terblokir oleh beberapa penyedia internet (ISP) di Indonesia, menyebabkan data toko buku kosong sehingga titik-titik toko buku tidak muncul di peta, baik di lokasi terdekat maupun saat mencari nama daerah.
   - **Solusi/Keputusan:** Menerapkan arsitektur *Multi-Tier Resilient Fetching* di `OverpassBookstoreRepository`:
     1. *Tier 1 (Overpass OSM)*: Coba mirror Overpass dengan timeout ringkas 4 detik per mirror.
     2. *Tier 2 (Nominatim OSM POI Search)*: Jika Overpass timeout atau kosong, lakukan reverse geocoding cepat untuk mendeteksi wilayah/kota pengguna, lalu cari toko buku riil via Nominatim OSM API (`toko buku $cityName`).
     3. *Tier 3 (Curated Indonesian Bookstores Seed)*: Sediakan dataset terverifikasi `IndonesianBookstoresSeed` berisi 50+ toko buku ternama (Gramedia, Periplus, Togamas, Toko Buku Gunung Agung, Aksara) di berbagai kota besar Indonesia (Jabodetabek, Bandung, Yogyakarta, Solo, Semarang, Surabaya, Malang, Bali, Medan, Palembang, Makassar) dengan koordinat GPS presisi.
     4. *Tier 4 (Quick Cities & Geocoding Fallback)*: Sediakan baris chip "Kota Cepat" dan fallback instan untuk pencarian daerah populer Indonesia di sheet pencarian.
   - **Hasil:** Titik-titik toko buku dijamin 100% muncul di peta secara instan, akurat, dan stabil di berbagai kondisi jaringan.

---

## Fase S7 — Kesan & Pesan: Halaman BACA SAJA dari Tim Pengembang (PRD §7.7.1 & §8.3)

1. **Transformasi Menjadi Halaman BACA SAJA (Read-Only Tim Pengembang)**
   - **Keputusan:** Keputusan pemilik proyek (menggantikan semua asumsi sebelumnya): halaman `/tools/feedback` bukan lagi form interaktif atau guestbook publik. Halaman ini hanya menampilkan kesan dan pesan perkuliahan Pemrograman Aplikasi Mobile (PAM) dari 3 anggota tim pengembang (Najmah Cleosa, Melanie Bunga Chintya Pawesty, Naftali Margareta).
   - **Penyimpangan PRD §7.7.1:** Seluruh card form (field Nama, Kesan, Pesan, tombol kirim, validasi form, controller terkait) dihapus dari `FeedbackPage`. Data disimpan secara terpusat pada `lib/data/static/team_feedback.dart` sebagai konstanta `teamFeedbacks` dan disediakan lewat `FeedbackRepository` read-only (`getAll()`) dengan implementasi `TeamFeedbackRepository`.
   - **Alasan:** Keputusan pemilik proyek yang disengaja agar kesan dan pesan evaluasi mata kuliah PAM tertera rapi, konstan, dan identik bagi semua pengguna tanpa risiko perubahan atau perusakan data.

2. **Pengecualian Tabel `feedbacks` dari Sinkronisasi (PRD §8.3)**
   - **Keputusan:** Hentikan penggunaan tabel `feedbacks` dalam sinkronisasi dua arah `SyncService`. Langkah `feedbacks` dihapus dari `pushPending`, `pullAll`, dan penghitungan pending count, tanpa mengubah urutan tabel lain (`user_books` -> `reading_sessions` -> `ledger_blocks` -> `game_scores`). Skema tabel SQLite dan Supabase tetap dipertahankan agar tidak menimbulkan risiko migrasi struktur tabel.
   - **Penyimpangan PRD §8.3:** Tabel `feedbacks` tidak lagi disinkronkan karena data kesan & pesan aplikasi bersifat statis dari tim di kode.
   - **Alasan:** Mencegah transmisi payload yang tidak diperlukan, menghilangkan potensi konflik sinkronisasi multi-akun, dan menjaga performa sinkronisasi data riil.

3. **Penghapusan Fallback ID Palsu pada Seluruh Repository Mode Nyata**
   - **Keputusan:** Menghapus seluruh fallback ID palsu (`default_user`, `demo`, `demo_user`) yang masih tersisa pada mode nyata (`search_book_detail_page.dart`, `deepseek_chat_repository.dart`, `gemini_chat_repository.dart`, `local_repositories.dart`). Tanpa pengguna login dengan UUID valid (RFC 4122), repository melempar error terkontrol `StateError('NO_AUTHENTICATED_USER')` dan UI mengarahkan pengguna ke alur login via SnackBar peringatan.
   - **Alasan:** Mencegah percampuran data pribadi antar-akun pada perangkat bersama dan memastikan setiap data personal (koleksi, riwayat baca, skor, chat) terisolasi mutlak di bawah UUID akun masing-masing.

4. **Pembaruan Deskripsi Menu Kartu di Tools Page**
   - **Keputusan:** Deskripsi kartu menu Kesan & Pesan pada `tools_page.dart` diperbarui dari deskripsi form/kirim menjadi *"Baca kesan dan pesan dari tim kami"*.
   - **Alasan:** Memberikan informasi yang jujur dan selaras dengan fungsi halaman yang kini murni baca saja.













