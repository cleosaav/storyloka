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

