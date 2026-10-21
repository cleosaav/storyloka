# StoryLoka — Design System & UI Guidelines

> Dokumen acuan visual untuk implementasi frontend StoryLoka menggunakan Flutter + Dart.  
> **Sumber kebenaran visual:** dokumen ini dan token pada PRD. Jika wireframe berbeda warna atau gaya dengan token di sini, ikuti token di sini. Jangan mengubah alur dan struktur navigasi yang sudah ditetapkan PRD.

## 1. Arah Visual

**Konsep:** Cozy Editorial × Soft Botanical × Warm Minimalism.

StoryLoka harus terasa seperti jurnal membaca pribadi: hangat, tenang, rapi, sedikit editorial, dan nyaman dipakai dalam waktu lama. Gunakan komposisi yang lapang dan hierarki tipografi yang jelas.

### Prinsip desain
- **Editorial:** judul halaman dan judul buku menggunakan serif Fraunces; isi dan kontrol menggunakan DM Sans.
- **Warm:** latar ivory, permukaan terang, aksen apricot secukupnya.
- **Botanical:** sage dan teal untuk aksen lembut, ilustrasi daun/buku sederhana.
- **Minimal:** utamakan ruang kosong, alignment rapi, dan sedikit dekorasi.
- **Readable:** semua aksi harus jelas; jangan mengandalkan warna saja untuk status.
- **Consistent:** komponen yang memiliki fungsi sama harus terlihat dan berperilaku sama di semua halaman.

### Hindari
- Neon, gradient mencolok, glow, shadow berat, glassmorphism, dan dashboard generik.
- Terlalu banyak warna aksen dalam satu layar.
- Serif untuk paragraf panjang, form, metadata, atau tombol.
- Cover buku yang diregangkan atau dipotong dengan rasio yang salah.
- Emoji sebagai ikon UI; gunakan satu keluarga ikon outline yang konsisten.
- Dekorasi di belakang teks atau tombol penting.

## 2. Token Warna

Semua warna harus didefinisikan sebagai konstanta tema, bukan ditulis sebagai nilai mentah di widget.

### Light theme

| Token | HEX | Penggunaan |
|---|---|---|
| `warmIvory` | `#FAF6EF` | Latar utama aplikasi |
| `deepTeal` | `#164E59` | Tombol primer, ikon utama, navigasi aktif |
| `oceanTeal` | `#245C67` | Aksen teal sekunder |
| `softApricot` | `#F5B65D` | Highlight kecil, indikator, tombol Add di navigasi |
| `palePeach` | `#FBE9D7` | Notes/supporting card |
| `sageGreen` | `#A8BDA8` | Ilustrasi, badge, elemen pendukung |
| `ink` | `#26383A` | Teks utama |
| `mutedGray` | `#859395` | Teks sekunder dan ikon nonaktif |
| `white` | `#FFFFFF` | Surface kartu/input yang memerlukan kontras |
| `borderNeutral` | `#E4E2DA` | Border dan divider |
| `trackNeutral` | `#E3E7DF` | Track progress |
| `error` | `#B54747` | Error dan aksi destruktif |
| `success` | `#3F7658` | Status berhasil |

### Dark theme

| Token | HEX | Penggunaan |
|---|---|---|
| `bgDark` | `#101819` | Latar utama |
| `surfaceDark` | `#1A2527` | Surface kartu dan navigasi |
| `borderDark` | `#2C3B3D` | Border/divider |
| `inkDark` | `#F2EDE3` | Teks utama |
| `mutedDark` | `#8FA0A2` | Teks sekunder |
| `primaryDark` | `#2F7F8C` | Tombol primer, teks putih |
| `trackDark` | `#2A3638` | Track progress |

`softApricot`, `sageGreen`, `error`, dan `success` tetap digunakan pada dark theme. Dark theme merupakan turunan dari token PRD; catat sebagai deviasi terdokumentasi bila implementasi proyek memerlukan dokumentasi deviasi.

### Aturan penggunaan warna
- Background utama light: `warmIvory`; gunakan `white` untuk kartu atau input bila membutuhkan pemisahan.
- Aksi primer: `deepTeal` dengan teks putih. Pada dark theme gunakan `primaryDark`.
- Aksi sekunder: outline `deepTeal`, teks `deepTeal`; sesuaikan dengan token dark theme.
- Apricot adalah aksen, bukan warna utama tombol aksi. Pengecualian: tombol **Add** di bottom navigation.
- `palePeach` hanya untuk catatan/supporting card, bukan sebagai latar semua komponen.
- Status harus selalu memiliki label teks selain warna.
- Jangan menambahkan warna baru tanpa alasan yang jelas.

## 3. Tipografi

Gunakan Google Fonts:
- **Fraunces SemiBold:** heading halaman, judul buku, section heading, angka besar.
- **DM Sans:** body, metadata, form, tombol, caption, label, dan navigasi.

| Gaya | Font | Ukuran |
|---|---|---:|
| Page heading | Fraunces SemiBold | 30 |
| Judul buku detail | Fraunces SemiBold | 24 |
| Section heading | Fraunces SemiBold | 20 |
| Card heading | Fraunces SemiBold | 18 |
| Body | DM Sans Regular | 16 |
| Tombol | DM Sans Medium | 14–16 |
| Metadata | DM Sans Regular | 14 |
| Caption | DM Sans Medium | 12 |
| Stopwatch/angka utama | Fraunces SemiBold | 48–80 |

### Aturan tipografi
- Gunakan sentence case; uppercase hanya untuk label kecil yang memang sesuai, misalnya `CURRENTLY READING`.
- Line height heading sekitar 1.2–1.3; body 1.4–1.6.
- Judul buku pada kartu maksimal dua baris, lalu gunakan ellipsis bila perlu.
- Jangan memakai serif untuk paragraf panjang, form, metadata, atau teks bantuan.
- Jangan mengecilkan teks penting hanya agar muat; biarkan layout scroll jika diperlukan.

## 4. Spacing, Ukuran, dan Bentuk

Gunakan konstanta spacing yang konsisten.

| Token | Nilai |
|---|---:|
| XS | 4 |
| S | 8 |
| M | 12 |
| L | 16 |
| XL | 24 |
| XXL | 32 |

### Aturan layout
- Margin horizontal halaman: **24 px**.
- Padding standar kartu: **16 px**.
- Radius kartu: **20 px**.
- Radius input: **12–14 px**.
- Radius tombol: **14–16 px**.
- Tinggi input dan tombol utama: **48 px**.
- Target sentuh minimum: **44 × 44 px**.
- Jarak antar-seksi utama: **24–32 px**.
- Jarak di dalam satu grup: **8–16 px**.
- Hormati SafeArea dan bottom inset perangkat.
- Hindari tinggi tetap untuk area konten yang bisa bertambah; gunakan scroll.
- Uji tampilan pada layar 360 × 640 dan skala teks 1.3.

## 5. Komponen UI Reusable

Buat komponen reusable di `lib/core/widgets/`. Semua komponen membaca warna dan tipografi dari theme.

### Buttons
- **`PrimaryButton`**: Deep Teal, teks putih, tinggi 48 px. Untuk aksi utama seperti `Add to Collection`, `Start Reading`, `Read`, `Login`, `Save`, dan `Open Maps`.
- **`SecondaryButton`**: outline 1 px Deep Teal dengan teks Deep Teal. Untuk aksi pendamping seperti `Add to Wishlist`, `Update`, dan `Update Progress`.
- **`TertiaryButton`**: aksi ringan tanpa tampilan primer yang dominan.
- **`AppIconButton`**: target sentuh minimal 44 × 44 px, dengan tooltip/semantic label bila diperlukan.

Semua tombol harus punya state normal, pressed, disabled, dan loading bila melakukan operasi asynchronous. Cegah submit ganda saat loading.

### Cards
- **`AppCard`**: surface putih/ivory, radius 20 px, padding 16 px, border neutral atau shadow sangat lembut.
- **`NotesCard`**: background pale peach.
- **`SupportCard`**: menggunakan sage yang lembut.
- **`EmptyStateCard`**: ilustrasi kecil, pesan singkat, satu aksi utama yang jelas.

### Buku
- **`BookCover`**: rasio **2:3**, tidak diregangkan. Jika cover tidak tersedia, gunakan placeholder sage dengan ikon buku.
- **`BookCard`**: cover, judul (Fraunces, maksimal dua baris), penulis (DM Sans), rating bila tersedia, dan status badge bila relevan.
- Jangan membuat rating, cover, harga, atau metadata palsu terlihat seperti data nyata. Saat memakai data demo, tampilkan label **Mode demo** sesuai PRD.

### Progress dan status
- **`ReadingProgressBar`**: tinggi 6 px, ujung rounded, fill Deep Teal, track `trackNeutral` (atau `trackDark` di dark theme). Apricot hanya sebagai aksen kecil.
- Progress selalu disertai teks `x / y pages` dan persentase.
- **`StatusBadge`**: tampilkan teks dan warna untuk `Belum dibaca`, `Sedang dibaca`, dan `Selesai`. Warna tidak boleh menjadi satu-satunya pembeda.
- **`AppChip`**: bentuk pill, tinggi 32–36 px; selected = Deep Teal dengan teks putih.
- **`FilterTabs`**: gunakan untuk pilihan seperti `Collection | Wishlist` dan `Title | Author | ISBN`.

### Form
- **`AppTextField`**: tinggi 48 px, radius 12–14 px, border neutral, border fokus Deep Teal.
- Label dan error message harus terlihat; jangan hanya mengandalkan placeholder.
- Pertahankan input pengguna ketika request gagal.
- Pesan validasi harus spesifik, singkat, dan menggunakan bahasa Indonesia.

### Ikon dan ilustrasi
- Gunakan satu keluarga ikon outline, misalnya Material Symbols Rounded/Outlined, dengan ketebalan visual konsisten.
- Ikon state aktif boleh filled; ikon nonaktif outline.
- Jangan mencampur emoji dengan ikon UI.
- Ilustrasi dibuat sederhana (CustomPainter/SVG): buku dan daun dengan sage + deep teal, apricot hanya aksen kecil.
- Gunakan ilustrasi hanya pada empty state, Reading Timer, atau supporting card. Jangan meletakkannya di belakang teks/tombol penting.

## 6. Bottom Navigation

Navigasi utama terdiri dari **lima item**, dengan urutan tetap:

1. Home
2. Library
3. Add
4. Tools
5. Profile

### Tampilan
- Surface putih pada light theme; `surfaceDark` pada dark theme.
- Item aktif: Deep Teal; item nonaktif: Muted Gray.
- Indikator aktif kecil berwarna Soft Apricot.
- Tombol **Add** berada di tengah, berukuran sekitar 56 px, berbentuk lingkaran/pill berwarna Soft Apricot dengan ikon plus Deep Teal, sedikit menonjol dari bar.
- Sisakan bottom safe area.
- Semua item memiliki `Semantics` label yang jelas.
- Gunakan `StatefulShellRoute` agar state setiap tab tetap terjaga saat berpindah tab.

Jangan mengubah urutan atau menambah tab utama baru.

## 7. Prinsip Perancangan Layar

Bagian ini mengatur hierarki visual. Alur dan fungsi setiap layar tetap mengikuti PRD.

### Splash
- Logo/nama StoryLoka menggunakan Fraunces.
- Ilustrasi daun kecil sebagai aksen.
- Tampilan tenang dan ringan, tanpa animasi berat.

### Login dan Register
- Form diletakkan dalam satu kolom dengan jarak konsisten.
- Heading editorial, teks bantuan ringkas, input jelas, dan satu tombol primer.
- Tautan pindah Login/Register terlihat sebagai aksi sekunder.
- Error validasi tampil dekat field terkait.
- Jangan membuat desain autentikasi seperti landing page pemasaran yang penuh dekorasi.

### Home
Urutan visual dari atas ke bawah:
1. Header sapaan `Hello, {nama}!`, subteks `Mau baca apa hari ini?`, dan avatar.
2. **Reading Summary** dengan tiga metrik: `Koleksi`, `Sedang dibaca`, `Selesai`.
3. **Currently Reading**: cover, judul, penulis, progress, aksi `Read` dan `Update`; jika kosong, tampilkan empty state dan tombol `Add Book`.
4. **My Collection**: judul seksi, `See all`, lalu maksimal tiga cover terbaru.
5. **My Wishlist**: struktur serupa My Collection.

Jaga summary tetap ringkas dan mudah dipindai. Jangan mengulang label metrik yang sama. Data demo pada Home harus memiliki chip **Mode demo**.

### Add Book
- Heading `Add a Book`.
- Search bar dengan pilihan `Title | Author | ISBN`.
- Aksi `Scan Barcode` mudah ditemukan tetapi tidak lebih dominan dari search.
- Tombol/ikon `Shake to Discover` tersedia sebagai alternatif.
- State awal memakai ilustrasi tumpukan buku dan pesan `Discover Books`.
- Hasil pencarian menggunakan grid tiga kolom `BookCard`.
- Sediakan tampilan loading/skeleton, hasil kosong, error jaringan dengan `Coba lagi`, dan hasil berhasil.
- Data demo harus ditandai **Mode demo**.

### Book Detail
- Header dengan tombol kembali dan judul halaman `Book Detail`.
- Cover dan informasi utama buku mendapat hierarki paling kuat.
- Tombol `Add to Collection` adalah primer; `Add to Wishlist` adalah sekunder.
- Synopsis dapat dipersingkat dengan `Read More`.
- Bila harga tidak tersedia, tampilkan teks **Harga tidak tersedia**; jangan membuat harga perkiraan.
- Aksi `Find Nearby Bookstores` membuka alur lokasi/Maps sesuai PRD.

### Library
- Search berada di bagian atas.
- Filter `Collection | Wishlist` mudah terlihat.
- Item Collection menampilkan judul, penulis, dan status; Wishlist menampilkan judul dan penulis.
- Gunakan `StatusBadge` yang konsisten.
- Empty state menyertakan satu aksi yang relevan.
- Penghapusan memerlukan konfirmasi; jangan membuat tombol destruktif terlihat seperti aksi primer.

### Reading flow
- Reading Timer memprioritaskan angka stopwatch yang besar dan kontrol yang mudah dijangkau.
- Progress membaca harus jelas dan selalu menyertakan jumlah halaman serta persentase.
- Tombol `Finish`/aksi penyelesaian perlu dibedakan dari aksi biasa.
- Layar buku selesai terasa seperti penutup yang memuaskan tetapi tetap sederhana; rating/review hanya ditampilkan sesuai aturan PRD.

### Tools
Gunakan **lima card vertikal** dengan urutan:
1. Kesan & Pesan
2. AI Chat
3. Mini Games
4. Konversi Mata Uang
5. Konversi Waktu

Setiap card berisi ikon konsisten, judul, deskripsi satu baris bila muat, dan affordance untuk dibuka. Hindari mengubahnya menjadi dashboard dengan banyak statistik.

### Profile
- Header profil dengan foto/avatar, nama, email, dan bio.
- Kelompokkan pengaturan dalam bagian yang jelas: edit profil, biometrik, notifikasi, tema, Reading Ledger, dan logout.
- Toggle harus memiliki label dan deskripsi singkat.
- `Logout` ditempatkan terpisah dari pengaturan biasa dan memakai konfirmasi.
- `DemoControls` hanya muncul pada debug/mode demo sesuai PRD.

### Reading Ledger / Blockchain
- Tampilkan daftar blok sebagai catatan aktivitas membaca yang terstruktur.
- Hierarki data: nomor/index blok, waktu, ringkasan data, hash/status verifikasi.
- Aksi `Verify` harus jelas dan hasil verifikasi disampaikan dengan teks, bukan warna saja.
- Visual ledger tetap mengikuti palet StoryLoka; hindari visual blockchain generik berupa neon, jaringan node dekoratif, atau efek futuristik berlebihan.

## 8. State Wajib untuk Layar Berbasis Data

Setiap layar berbasis data harus punya empat state:

- **Loading:** skeleton atau indikator yang tenang; pertahankan struktur layout agar tidak terjadi lompatan besar.
- **Empty:** ilustrasi kecil bila membantu, pesan spesifik, dan satu aksi utama.
- **Error:** jelaskan masalah dengan bahasa sederhana dan sediakan `Coba lagi` jika relevan.
- **Success:** tampilkan konten sebenarnya dengan hierarki yang jelas.

Ketentuan tambahan:
- Loading/error tidak boleh menghilangkan navigasi utama tanpa alasan.
- Jangan menampilkan stack trace atau pesan teknis mentah kepada pengguna.
- Jangan membuat harga, lokasi, rating, atau hasil pencarian palsu terlihat sebagai data nyata.
- Data demo selama Tahap A wajib diberi label **Mode demo**; balasan AI demo diberi label **Jawaban contoh (mode demo)** dan kurs demo diberi label **Kurs contoh**.
- Ketika berpindah ke backend, hilangkan data demo dan labelnya dari alur nyata sesuai PRD.

## 9. Motion dan Interaksi

- Gunakan animasi pendek dan halus hanya bila membantu memahami perubahan state.
- Hindari parallax, animasi dekoratif berulang, glow, dan transisi yang memperlambat penggunaan.
- Tombol harus memberikan feedback visual saat ditekan.
- Operasi asynchronous menampilkan loading dan mencegah submit ganda.
- Perubahan status buku harus tercermin konsisten di Home, Library, dan detail buku.
- Pertahankan state tab ketika pengguna berpindah melalui bottom navigation.
- Shake to Discover harus tetap memiliki tombol alternatif agar bisa digunakan pada emulator dan oleh pengguna yang tidak dapat menggoyangkan perangkat.

## 10. Aksesibilitas dan Responsivitas

- Target sentuh minimal 44 × 44 px.
- Semua ikon interaktif memiliki semantic label.
- Status memiliki teks selain warna.
- Pastikan kontras teks dan kontrol cukup jelas pada light dan dark theme.
- Hormati text scaling; uji pada skala 1.3.
- Uji minimal ukuran layar 360 × 640; jangan ada overflow horizontal.
- Jangan mengunci tinggi elemen yang berisi teks dinamis.
- Cover buku memakai rasio 2:3 pada semua ukuran.
- Periksa keyboard dan form agar field/tombol tidak tertutup saat mengetik.

## 11. Implementasi Flutter yang Disarankan

Gunakan struktur berikut sesuai arsitektur PRD:

```text
lib/
  app/
    app.dart
    router.dart
    main_shell.dart
    providers.dart
  core/
    theme/
      app_colors.dart
      app_text.dart
      app_spacing.dart
      app_theme.dart
    widgets/
      primary_button.dart
      secondary_button.dart
      app_card.dart
      book_cover.dart
      book_card.dart
      reading_progress_bar.dart
      app_chip.dart
      app_text_field.dart
      status_badge.dart
      empty_state_card.dart
```

### Aturan implementasi
- Token warna, typography, spacing, dan radius didefinisikan terpusat.
- Widget tidak menulis warna/spacing mentah jika token yang sesuai sudah tersedia.
- Gunakan `ThemeData`/`ColorScheme` dan `ThemeMode` untuk light/dark.
- Gunakan Fraunces dan DM Sans secara konsisten melalui `google_fonts`.
- UI hanya berkomunikasi dengan provider/repository abstrak; jangan panggil API, SQLite, atau Supabase langsung dari widget.
- Selama Tahap A, gunakan fake repository dan data demo berlabel.
- Jangan menggunakan Firebase atau `supabase.auth`.
- Pertahankan struktur layar, urutan navigasi, dan istilah fitur sesuai PRD.

## 12. Checklist Review Visual

Sebelum menyatakan UI selesai, periksa:

- [ ] Nuansa Cozy Editorial × Soft Botanical × Warm Minimalism terasa konsisten.
- [ ] Warna sesuai token light/dark; tidak ada warna baru tanpa alasan.
- [ ] Fraunces hanya untuk heading/judul/angka utama; DM Sans untuk body dan kontrol.
- [ ] Margin halaman 24 px, padding kartu 16 px, radius kartu 20 px.
- [ ] Semua tombol memiliki hierarchy primer/sekunder yang benar.
- [ ] Cover buku tidak terdistorsi dan memakai rasio 2:3.
- [ ] Bottom navigation memiliki lima item dengan Add di tengah.
- [ ] Home menampilkan urutan komponen sesuai PRD.
- [ ] Tools terdiri dari lima card vertikal dengan urutan yang benar.
- [ ] Loading, empty, error, dan success tersedia pada layar berbasis data.
- [ ] Data demo diberi label `Mode demo`.
- [ ] Ikon konsisten dan tidak dicampur emoji.
- [ ] Tidak ada overflow pada 360 × 640 atau skala teks 1.3.
- [ ] Semua target sentuh minimal 44 × 44 px.
- [ ] Light theme dan dark theme sama-sama terbaca.
- [ ] Tidak ada perubahan pada alur atau urutan navigasi yang sudah ditetapkan PRD.

---

## Instruksi untuk AI Coding Agent

Baca `prd-storyloka.md` dan `design-system.md` sebelum menulis kode. Implementasikan **satu fase pada satu waktu** sesuai urutan di PRD. Untuk fase frontend, jangan membangun backend lebih dulu. Ikuti token, komponen, hierarchy layar, state, dan navigasi pada dokumen ini. Jika ada perbedaan antara wireframe dan token visual, **token di dokumen ini yang menang**. Setelah setiap fase, jalankan `flutter analyze`, tes yang relevan, dan perbarui `docs/PROGRESS.md` serta `docs/DEVIATIONS.md`.
