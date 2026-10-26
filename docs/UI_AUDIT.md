# UI_AUDIT.md — Laporan Audit Tampilan StoryLoka (Fase U0)

Dokumen ini merupakan hasil audit tampilan frontend StoryLoka yang mengacu pada `docs/spec/design-system.md` (Bagian 3–13) dan `docs/spec/wireframe.md`. Seluruh temuan dikelompokkan per halaman dan diklasifikasikan ke dalam 6 kategori evaluasi.

---

## 1. Ringkasan Audit per Kategori

1. **Lebar / Tata Letak:** Terdapat potensi overflow vertikal (`RenderFlex`) pada layar 360×640 px dengan skala teks 1.3 di halaman yang tidak dibungkus `SingleChildScrollView` (Finished Book, Reading Timer, Lock Screen). Selain itu, baris berdampingan dengan dua tombol aksi panjang (Book Detail) dan row input halaman di Reading Progress rentan tertekan pada layar sempit.
2. **Token Desain:** Masih ditemukan penulisan angka mentah untuk `borderRadius` (8, 10, 12, 16, 24 px), `fontSize` (10, 11, 13, 14, 36, 40 px), dimensi kontainer, dan `TextStyle` manual bawaan Flutter tanpa konstanta `AppSpacing` / `AppText`.
3. **Komponen Reusable:** Penggunaan `DropdownButton` / `DropdownButtonHideUnderline` bawaan di Konversi Mata Uang dan Konversi Waktu, `SegmentedButton` bawaan di Add Book dan Profile, serta `AlertDialog` bawaan Material di berbagai alur alih-alih memanfaatkan `AppDialog`, `AppTextField`, `AppChip`, dan `EmptyStateCard`.
4. **Dark Mode:** Beberapa ikon dan warna aksi masih meng-hardcode `AppColors.deepTeal` atau `AppColors.white` tanpa beralih ke `AppColors.primaryDark` / `AppColors.inkDark` saat tema gelap aktif (misalnya ikon piala perayaan, slider progres baca, tombol kirim AI Chat, dan tombol swap kurs).
5. **Teks & Salinan:** Terdapat inkonsistensi pencampuran bahasa Inggris dan Indonesia pada judul halaman, tab, dan tombol aksi. Ditemukan banner demo yang masih tampil secara hardcoded pada alur nyata di AI Chat dan Login Page.
6. **Aksesibilitas:** Ditemukan tombol dengan tinggi/area sentuh di bawah standar minimum 44×44 px (tombol "Read More/Less" 30 px, bintang rating 32×36 px, dan chip pemilih waktu 36 px), serta elemen interaktif tanpa label `Semantics`.

---

## 2. Temuan Audit per Halaman

### 2.1 Home (`lib/features/home/home_page.dart`)
- [x] **Kategori 1 (Lebar/Tata Letak)** — `lib/features/home/home_page.dart:516` & `lib/features/home/home_page.dart:618` *(Selesai di Fase U2)*
  - *Masalah:* Card empty state Koleksi dan Wishlist menggunakan `Row` yang memuat `Expanded(Text)` berdampingan dengan `PrimaryButton('Add Book')`. Pada layar 360 px dengan skala teks 1.3, tombol dapat mendesak teks penjelasan hingga terpotong atau overflow.
  - *Solusi Fase U2:* Menggunakan `EmptyStateCard.horizontal` yang secara adaptif beralih ke layout vertikal saat constraint sempit (<340 px) atau skala teks > 1.15. Semua card di Home menggunakan `CrossAxisAlignment.stretch` selebar penuh area konten.
  - *Tingkat:* Sedang.
- [x] **Kategori 2 (Token)** — `lib/features/home/home_page.dart:207`, `395`, `498`, `550`, `600`, `652` *(Selesai di Fase U2)*
  - *Masalah:* Penggunaan angka mentah `BorderRadius.circular(24)`, `borderRadius: 10`, `borderRadius: 12`, dan `fontSize: 14` pada avatar, cover buku, dan tombol "See all".
  - *Solusi Fase U2:* Digantikan dengan `CircleBorder()`, token `AppSpacing.cardPadding`, dan `TertiaryButton`.
  - *Tingkat:* Rendah.
- [x] **Kategori 3 (Komponen)** — `lib/features/home/home_page.dart:336-379` & `487, 589` *(Selesai di Fase U2)*
  - *Masalah:* Empty state Currently Reading dirakit manual dari `AppCard` + Container bulat + Icon + Text alih-alih memakai `EmptyStateCard`. Tombol "See all" menggunakan `TextButton` bawaan alih-alih `TertiaryButton`.
  - *Solusi Fase U2:* Ditambahkan `EmptyStateCard.horizontal` dengan tata letak horizontal ikon + teks + tombol, dan tombol "See all" menggunakan `TertiaryButton`.
  - *Tingkat:* Sedang.
- [x] **Kategori 4 (Dark Mode)** — `lib/features/home/home_page.dart:349` *(Selesai di Fase U2)*
  - *Masalah:* Ikon buku empty state meng-hardcode warna `AppColors.deepTeal` tanpa penyesuaian `primaryDark` saat tema gelap aktif.
  - *Solusi Fase U2:* Ikon dinamis di `EmptyStateCard` memakai `isDark ? AppColors.primaryDark : AppColors.deepTeal`.
  - *Tingkat:* Sedang.
- **Kategori 5 (Teks)** — `lib/features/home/home_page.dart:181, 190, 328, 479, 495, 520, 581, 597, 622`
  - *Masalah:* Bahasa tercampur antara Inggris dan Indonesia ("Hello, {nama}!" vs "Mau baca apa hari ini?", "Currently Reading" vs "Koleksi / Sedang dibaca / Selesai", "My Collection" & "See all" vs "Belum ada buku di koleksi Anda.").
  - *Saran:* Selaraskan ke bahasa Indonesia editorial yang konsisten ("Sedang Dibaca", "Koleksi Saya", "Wishlist Saya", "Lihat semua").
  - *Tingkat:* Sedang.
- [x] **Kategori 6 (Aksesibilitas)** — `lib/features/home/home_page.dart:545, 647` *(Selesai di Fase U2)*
  - *Masalah:* `InkWell` pembungkus cover buku terbaru tidak memiliki `Semantics(label: book.title)`. Screen reader tidak dapat mengumumkan judul buku yang dipilih.
  - *Solusi Fase U2:* Ditambahkan `Semantics(label: 'Buka detail buku ${book.title}', button: true)`.
  - *Tingkat:* Sedang.

---

### 2.2 Library (`lib/features/library/library_page.dart`)
- [x] **Kategori 1 (Lebar/Tata Letak)** — `lib/features/library/library_page.dart:331-336` *(Selesai di Fase U1)*
  - *Masalah:* Grid 3 kolom memiliki `childAspectRatio: 0.44` (Collection) dan `0.52` (Wishlist). Pada layar 360 px (lebar kolom ~96 px) dengan text scale 1.3, judul 2 baris, penulis, rating, dan `StatusBadge` berisiko mengalami overflow vertikal di dalam cell grid.
  - *Solusi Fase U1:* Rasio aspek sel grid dihitung dinamis berdasarkan skala teks `MediaQuery.textScalerOf(context).scale(1.0)`.
  - *Tingkat:* Tinggi.
- **Kategori 2 (Token)** — `lib/features/library/library_page.dart:385, 396, 407, 419, 433`
  - *Masalah:* `BorderRadius.circular(12)`, `borderRadius: 10`, `fontSize: 12`, `height: 1.25`, `fontSize: 10`, dan ukuran bintang `size: 11` ditulis mentah.
  - *Saran:* Gunakan `AppSpacing` dan token `AppText.caption` resmi (font size minimal 12 px sesuai design-system.md §3).
  - *Tingkat:* Sedang.
- [x] **Kategori 3 (Komponen)** — `lib/features/library/library_page.dart:95-112` & `365-452` *(Selesai di Fase U4b)*
  - *Masalah:* Dialog konfirmasi hapus menggunakan `AlertDialog` bawaan Flutter + `TextButton` mentah alih-alih `AppDialog`. Item grid `_LibraryBookItem` dirakit manual alih-alih menyatu dengan `BookGridCard` di `core/widgets/`.
  - *Solusi Fase U4b:* Mengganti `AlertDialog` dengan `AppDialog.showConfirm` dan mengganti `_LibraryBookItem` dengan `BookGridCard` reusable lengkap dengan `rating`, `statusBadge`, dan `onLongPress`.
  - *Tingkat:* Sedang.
- [x] **Kategori 4 (Dark Mode)** — `lib/features/library/library_page.dart:95-112` *(Selesai di Fase U4b)*
  - *Masalah:* `AlertDialog` bawaan tidak menentukan warna background `AppColors.surfaceDark`.
  - *Solusi Fase U4b:* `AppDialog` secara otomatis menerapkan warna tema (surfaceDark di dark mode dan white di light mode).
  - *Tingkat:* Sedang.
- **Kategori 5 (Teks)** — `lib/features/library/library_page.dart:163, 202, 405`
  - *Masalah:* Judul AppBar "Library", tab "Collection" dan "Wishlist" berbahasa Inggris, sementara empty state berbahasa Indonesia. Judul buku kartu menggunakan DM Sans (`AppText.bodyMedium`) alih-alih Fraunces serif sesuai panduan §3.
  - *Saran:* Selaraskan bahasa dan gunakan Fraunces untuk judul buku di kartu.
  - *Tingkat:* Sedang.
- **Kategori 6 (Aksesibilitas)** — `lib/features/library/library_page.dart:382, 419`
  - *Masalah:* `InkWell` item buku tidak memiliki `Semantics` label judul buku dan tidak ada semantic action untuk fungsi long-press hapus. Font penulis berukuran 10 px (< 12 px) sulit dibaca pengguna berpenglihatan rendah.
  - *Saran:* Tambahkan Semantics informatif dan tingkatkan font minimum ke 12 px.
  - *Tingkat:* Sedang.

---

### 2.3 Add Book & Scan Barcode (`lib/features/add_book/add_book_page.dart` & `scan_page.dart`)
- **Kategori 1 (Lebar/Tata Letak)** — `lib/features/add_book/add_book_page.dart:238-275`
  - *Masalah:* Pemilih filter pencarian menggunakan `SegmentedButton` 3 opsi (Title | Author | ISBN) berlebar penuh. Pada layar 360 px dengan teks skala 1.3, label teks berpotensi terpotong.
  - *Saran:* Bungkus label dengan `FittedBox` atau gunakan tab geser yang fleksibel.
  - *Tingkat:* Sedang.
- **Kategori 2 (Token)** — `lib/features/add_book/add_book_page.dart:203, 269, 378, 389` & `scan_page.dart:224, 233, 251`
  - *Masalah:* Input pencarian menggunakan `AppSpacing.cardRadius` (20 px) alih-alih `inputRadius` (12 px). Digunakan warna mentah `Colors.white` dan `Colors.black54` pada overlay scanner kamera.
  - *Saran:* Gunakan `AppSpacing.inputRadius` dan definisikan overlay warna gelap melalui token tema.
  - *Tingkat:* Sedang.
- **Kategori 3 (Komponen)** — `lib/features/add_book/add_book_page.dart:185-210, 240-274, 431-469, 472-504` & `scan_page.dart:167-179`
  - *Masalah:* Kolom pencarian di Add Book dan Scan Page menggunakan `TextField` bawaan alih-alih `AppTextField`. SegmentedButton dan empty state dirakit manual tanpa memakai `FilterTabs` dan `EmptyStateCard`.
  - *Saran:* Ganti dengan `AppTextField`, `FilterTabs`, dan `EmptyStateCard`.
  - *Tingkat:* Sedang.
- [x] **Kategori 4 (Dark Mode)** — `lib/features/add_book/add_book_page.dart:269` & `scan_page.dart:233, 251` *(Selesai di Fase U4c)*
  - *Masalah:* Hardcoded `Colors.white` pada foreground SegmentedButton terpilih dan `Colors.black54` pada overlay scanner kamera.
  - *Solusi Fase U4c:* Menggunakan token warna tema `(isDark ? AppColors.bgDark : AppColors.ink).withValues(alpha: 0.65)` pada scanner overlay dan `isDark ? AppColors.inkDark : AppColors.white` untuk teks overlay kamera.
  - *Tingkat:* Rendah.
- **Kategori 5 (Teks)** — `lib/features/add_book/add_book_page.dart:164, 245, 308, 453, 487`
  - *Masalah:* Percampuran bahasa: "Add a Book", "Title | Author | ISBN", "Scan Barcode", "Discover Books" (Inggris) vs "Buku tidak ditemukan", "Coba gunakan kata kunci atau filter lain", "Coba Lagi" (Indonesia).
  - *Saran:* Terjemahkan istilah ke bahasa Indonesia ("Tambah Buku", "Judul | Penulis | ISBN", "Pindai Barcode", "Temukan Buku").
  - *Tingkat:* Sedang.
- **Kategori 6 (Aksesibilitas)** — `lib/features/add_book/add_book_page.dart:253`
  - *Masalah:* `tapTargetSize: MaterialTapTargetSize.shrinkWrap` pada SegmentedButton memperkecil tinggi target sentuh di bawah 44 px.
  - *Saran:* Hapus shrink wrap atau pastikan tinggi tombol minimal `AppSpacing.touchTarget` (44 px).
  - *Tingkat:* Sedang.

---

### 2.4 Book Detail x3:
#### A. Search Book Detail (`lib/features/book_detail/search_book_detail_page.dart`)
- [x] **Kategori 1 (Lebar/Tata Letak)** — `lib/features/book_detail/search_book_detail_page.dart:289-310` *(Selesai di Fase U1)*
  - *Masalah:* Row membagi dua tombol aksi: `Expanded(PrimaryButton('Added to Collection'))` dan `Expanded(SecondaryButton('Added to Wishlist'))`. Pada layar 360 px dengan teks skala 1.3, teks tombol panjang di lebar ~140 px terancam terpotong karena tinggi tombol fixed 48 px.
  - *Solusi Fase U1:* Menerapkan tata letak kolom vertikal adaptif (`Column`) jika `screenWidth < 340` atau skala teks `> 1.15`. Membatasi `_buildMetaItem` agar tidak overflow.
  - *Tingkat:* Tinggi.
- **Kategori 2 (Token)** — `lib/features/book_detail/search_book_detail_page.dart:354, 370-371, 380, 470`
  - *Masalah:* `fontSize: 13`, ukuran kontainer `44x44`, dan ukuran ikon `size: 22`, `size: 16` ditulis sebagai angka mentah.
  - *Saran:* Gunakan token `AppText.button()` standar dan konstanta spacing/icon.
  - *Tingkat:* Rendah.
- **Kategori 3 (Komponen)** — `lib/features/book_detail/search_book_detail_page.dart:339-358` & `446-450`
  - *Masalah:* Tombol "Read More / Read Less" memakai `TextButton` bawaan alih-alih `TertiaryButton`. Tombol edit lokasi menggunakan `IconButton` alih-alih `AppIconButton`.
  - *Saran:* Ganti dengan `TertiaryButton` dan `AppIconButton`.
  - *Tingkat:* Sedang.
- [x] **Kategori 4 (Dark Mode)** — `lib/features/book_detail/search_book_detail_page.dart:287` *(Selesai di Fase U4c)*
  - *Masalah:* `CircularProgressIndicator()` tanpa penetapan warna eksplisit untuk mode gelap (`primaryDark`).
  - *Solusi Fase U4c:* Menetapkan `color: context.primaryColor` (`isDark ? primaryDark : deepTeal`).
  - *Tingkat:* Rendah.
- [x] **Kategori 5 (Teks & Label Ganda)** — `lib/features/book_detail/search_book_detail_page.dart:279-280` & `401-408` *(Selesai di Fase U4a)*
  - *Masalah:* **Penerbit buku ditampilkan dua kali**: pertama di dalam baris metadata (baris 279) dan kedua di dalam Card Harga Buku ("Penerbit: ...", baris 404). Selain itu terdapat pencampuran bahasa ("Book Detail", "Synopsis", "Book Price", "Find Nearby Bookstores" vs "Penulis tidak diketahui", "hlm", "Harga tidak tersedia").
  - *Solusi Fase U4a:* Menghapus duplikasi label penerbit di Card Book Price sehingga penerbit hanya ditampilkan di baris metadata.
  - *Tingkat:* Sedang.
- [x] **Kategori 6 (Aksesibilitas)** — `lib/features/book_detail/search_book_detail_page.dart:348` *(Selesai di Fase U4a)*
  - *Masalah:* `minimumSize: const Size(50, 30)` pada tombol Read More melanggar aturan target sentuh minimal 44×44 px (design-system.md §4 & §10).
  - *Solusi Fase U4a:* Mengganti tombol Read More / Read Less menjadi `TertiaryButton` dengan area sentuh minimal 44 px.
  - *Tingkat:* Tinggi.

#### B. Collection Book Detail (`lib/features/book_detail/collection_book_detail_page.dart`)
- [x] **Kategori 1 (Lebar/Tata Letak)** — `lib/features/book_detail/collection_book_detail_page.dart:275-309` *(Selesai di Fase U1)*
  - *Masalah:* Row membagi dua tombol aksi: `Expanded(PrimaryButton('Start Reading'))` dan `Expanded(SecondaryButton('Update Progress'))`. Teks "Update Progress" pada layar 360 px dengan skala teks 1.3 sangat sempit di lebar setengah layar. Card tidak selebar penuh karena alignment center.
  - *Solusi Fase U1:* Menerapkan tata letak adaptif (Column jika lebar < 340 atau skala teks > 1.15), mengubah Column utama ke `CrossAxisAlignment.stretch`, dan membungkus judul status baca dengan `Expanded`.
  - *Tingkat:* Tinggi.
- **Kategori 2 (Token)** — `lib/features/book_detail/collection_book_detail_page.dart:158, 231, 380, 416, 421`
  - *Masalah:* `style: TextStyle(color: AppColors.error)` ditulis dengan `TextStyle` mentah bawaan Flutter. Terdapat angka mentah `borderRadius: 16`, `fontSize: 13`, `size: 32`.
  - *Saran:* Gunakan `AppText.button()` / `AppText.body()` dan token radius tema.
  - *Tingkat:* Sedang.
- [x] **Kategori 3 (Komponen)** — `lib/features/book_detail/collection_book_detail_page.dart:88-105, 141-164, 365-384` *(Selesai di Fase U4b)*
  - *Masalah:* Dialog hapus menggunakan `AlertDialog` + `TextButton` bawaan alih-alih `AppDialog`. Menu opsi titik tiga menggunakan `PopupMenuButton` mentah. Tombol Read More memakai `TextButton` bawaan.
  - *Solusi Fase U4b:* Mengganti dialog hapus dengan `AppDialog.showConfirm` dan tombol Read More dengan `TertiaryButton`.
  - *Tingkat:* Sedang.
- [x] **Kategori 4 (Dark Mode)** — `lib/features/book_detail/collection_book_detail_page.dart:88-105` *(Selesai di Fase U4b)*
  - *Masalah:* `AlertDialog` tidak menetapkan warna latar kartu tema gelap (`surfaceDark`).
  - *Solusi Fase U4b:* `AppDialog` otomatis menggunakan warna background tema.
  - *Tingkat:* Sedang.
- **Kategori 5 (Teks)** — `lib/features/book_detail/collection_book_detail_page.dart:134, 158, 279, 300, 321, 345, 397`
  - *Masalah:* Campuran bahasa: "Book Detail", "Remove from library", "Start Reading", "Update Progress", "Reading Status", "Synopsis", "Your Rating", "Save Review" vs dialog "Hapus dari Koleksi?", "Batal", "Hapus", dan teks "Selesaikan buku ini untuk memberi review.".
  - *Saran:* Selaraskan ke bahasa Indonesia.
  - *Tingkat:* Sedang.
- [x] **Kategori 6 (Aksesibilitas)** — `lib/features/book_detail/collection_book_detail_page.dart:373` & `408-428` *(Selesai di Fase U4a)*
  - *Masalah:* Tombol Read More berukuran 30 px (< 44 px). Bintang rating menggunakan `InkWell` dengan padding hanya `only(right: 4)` dan ukuran ikon 32 px, sehingga target sentuhnya hanya 36×32 px (< 44×44 px). Selain itu tidak ada `Semantics(label: 'Beri rating $starNum bintang')`.
  - *Solusi Fase U4a:* Mengganti Read More dengan `TertiaryButton` (target sentuh >= 44 px) dan membungkus bintang rating dengan `SizedBox(44, 44)` + `Semantics(label: 'Rating $starNum bintang', button: true)` dengan ukuran ikon tetap proporsional (32 px).
  - *Tingkat:* Tinggi.

#### C. Wishlist Book Detail (`lib/features/book_detail/wishlist_book_detail_page.dart`)
- **Kategori 1 (Lebar/Tata Letak)** — `lib/features/book_detail/wishlist_book_detail_page.dart:273-281`
  - *Masalah:* Tombol utama "Add to Collection" berlebar penuh (`double.infinity`). Tata letak baik dan responsif.
  - *Saran:* Pertahankan.
  - *Tingkat:* Rendah.
- **Kategori 2 (Token)** — `lib/features/book_detail/wishlist_book_detail_page.dart:229, 325, 341-342, 351, 442`
  - *Masalah:* Angka mentah `borderRadius: 16`, `fontSize: 13`, `width: 44, height: 44`, `size: 22`, dan `size: 16`.
  - *Saran:* Ganti dengan konstanta `AppSpacing` dan token `AppText`.
  - *Tingkat:* Rendah.
- **Kategori 3 (Komponen)** — `lib/features/book_detail/wishlist_book_detail_page.dart:310-329` & `418-422`
  - *Masalah:* Tombol Read More memakai `TextButton` bawaan dan tombol peta memakai `IconButton` alih-alih `TertiaryButton` dan `AppIconButton`.
  - *Saran:* Ganti dengan komponen reusable.
  - *Tingkat:* Sedang.
- **Kategori 4 (Dark Mode)** — Konsisten dengan Search Book Detail.
  - *Tingkat:* Rendah.
- **Kategori 5 (Teks)** — `lib/features/book_detail/wishlist_book_detail_page.dart:146, 276, 290, 360, 396`
  - *Masalah:* Campuran bahasa: "Book Detail", "Add to Collection", "Synopsis", "Book Price", "Find Nearby Bookstores" vs "Buku tidak ditemukan di wishlist.", "halaman", "Penerbit:".
  - *Saran:* Selaraskan ke bahasa Indonesia.
  - *Tingkat:* Sedang.
- [x] **Kategori 6 (Aksesibilitas)** — `lib/features/book_detail/wishlist_book_detail_page.dart:318` *(Selesai di Fase U4a)*
  - *Masalah:* `minimumSize: const Size(50, 30)` pada tombol Read More melanggar target sentuh 44×44 px.
  - *Solusi Fase U4a:* Mengganti tombol Read More / Read Less menjadi `TertiaryButton` dengan area sentuh minimal 44 px.
  - *Tingkat:* Tinggi.

---

### 2.5 Reading Flow:
#### A. Reading Timer (`lib/features/reading/reading_timer_page.dart`)
- [x] **Kategori 1 (Lebar/Tata Letak)** — `lib/features/reading/reading_timer_page.dart:373-374` *(Selesai di Fase U1)*
  - *Masalah:* Lingkaran stopwatch memiliki dimensi tetap `Container(width: 250, height: 250)`. Pada layar tinggi terbatas (640 px atau rotasi lanskap), kombinasi dua `Spacer()`, info buku, dan tombol kontrol tanpa `SingleChildScrollView` berpotensi menyebabkan overflow vertikal.
  - *Solusi Fase U1:* Membungkus body dengan `SingleChildScrollView` + `SafeArea`, membuat ukuran lingkaran proporsional `(screenWidth * 0.55).clamp(180.0, 260.0)`, dan membungkus teks display waktu dengan `FittedBox`.
  - *Tingkat:* Tinggi.
- **Kategori 2 (Token)** — `lib/features/reading/reading_timer_page.dart:208, 218, 337, 384, 410`
  - *Masalah:* `style: TextStyle(color: AppColors.error)` mentah, `Colors.white` mentah, `borderRadius: 8`, `width: 6`, dan `fontSize: 40` ditulis mentah.
  - *Saran:* Gunakan `AppText.button()`, `AppColors.white`, dan token tema resmi.
  - *Tingkat:* Sedang.
- [x] **Kategori 3 (Komponen)** — `lib/features/reading/reading_timer_page.dart:200-224` & `262` *(Selesai di Fase U4b)*
  - *Masalah:* Dialog keluar sesi membaca menggunakan `AlertDialog` + `TextButton` + `ElevatedButton` bawaan alih-alih `AppDialog` dan komponen tombol reusable. Tombol back di AppBar menggunakan `IconButton` alih-alih `AppIconButton`.
  - *Solusi Fase U4b:* Mengganti dialog konfirmasi dengan `AppDialog` (TertiaryButton + PrimaryButton) dan tombol back dengan `AppIconButton`.
  - *Tingkat:* Sedang.
- [x] **Kategori 4 (Dark Mode)** — `lib/features/reading/reading_timer_page.dart:217` *(Selesai di Fase U4c)*
  - *Masalah:* Tombol "Simpan & Keluar" di dalam dialog meng-hardcode `backgroundColor: AppColors.deepTeal`, tidak menyesuaikan ke `primaryDark` di dark theme.
  - *Solusi Fase U4c:* Menggunakan komponen `AppDialog` dan token `context.primaryColor`.
  - *Tingkat:* Sedang.
- **Kategori 5 (Teks)** — `lib/features/reading/reading_timer_page.dart:257, 433, 444`
  - *Masalah:* Campuran bahasa: AppBar "Reading Timer", tombol "Pause" / "Resume", "Finish Reading" vs dialog "Keluar dari Sesi Membaca?", "Buang", "Lanjut Membaca", "Simpan & Keluar", dan subtitle "Sedang Membaca..." / "Timer Dijeda".
  - *Saran:* Selaraskan ke bahasa Indonesia ("Pengatur Waktu Baca", "Jeda", "Lanjut", "Selesai Membaca").
  - *Tingkat:* Sedang.
- [x] **Kategori 6 (Aksesibilitas)** — `lib/features/reading/reading_timer_page.dart:372-423` *(Selesai di Fase U4d)*
  - *Masalah:* Tampilan stopwatch tidak memiliki pengumuman Semantics berkala untuk pembaca layar.
  - *Solusi Fase U4d:* Menambahkan `Semantics(label: 'Waktu membaca: $timeFormatted', liveRegion: true)`.
  - *Tingkat:* Sedang.

#### B. Reading Progress (`lib/features/reading/reading_progress_page.dart`)
- [x] **Kategori 1 (Lebar/Tata Letak)** — `lib/features/reading/reading_progress_page.dart:525-553` *(Selesai di Fase U1)*
  - *Masalah:* Row input halaman: `Expanded(Text('Halaman:'))`, `SizedBox(width: 100, child: AppTextField(...))`, dan `Text('dari ...')`. Pada layar 360 px dengan teks skala 1.3, lebar tetap 100 px ditambah label teks rentan menyebabkan overflow horizontal `RenderFlex`.
  - *Solusi Fase U1:* Menyederhanakan baris input menjadi `Expanded(child: AppTextField)` yang didampingi suffix label `/ total hlm` secara fleksibel dan anti-overflow.
  - *Tingkat:* Tinggi.
- **Kategori 2 (Token)** — `lib/features/reading/reading_progress_page.dart:225, 362, 407, 518`
  - *Masalah:* `Colors.white` mentah, `BorderRadius.circular(12)` mentah, `borderRadius: 10` mentah, dan `activeColor: AppColors.deepTeal` di-hardcode pada Slider.
  - *Saran:* Gunakan konstanta `AppSpacing` dan sesuaikan warna aktif Slider dengan tema.
  - *Tingkat:* Sedang.
- [x] **Kategori 3 (Komponen)** — `lib/features/reading/reading_progress_page.dart:211-231` & `513-521` *(Selesai di Fase U4b)*
  - *Masalah:* Dialog selesai buku memakai `AlertDialog` + `ElevatedButton` bawaan alih-alih `AppDialog`. Material `Slider` dipakai langsung tanpa wrapper tema seragam.
  - *Solusi Fase U4b:* Mengganti dialog selesai buku dengan `AppDialog.showConfirm`.
  - *Tingkat:* Sedang.
- [x] **Kategori 4 (Dark Mode)** — `lib/features/reading/reading_progress_page.dart:371, 518` *(Selesai di Fase U4c)*
  - *Masalah:* Ikon check pada banner sesi dan warna aktif `Slider` meng-hardcode `AppColors.deepTeal` tanpa berganti ke `primaryDark` di dark mode.
  - *Solusi Fase U4c:* Menerapkan token dinamis `context.primaryColor` (`isDark ? AppColors.primaryDark : AppColors.deepTeal`).
  - *Tingkat:* Sedang.
- **Kategori 5 (Teks)** — `lib/features/reading/reading_progress_page.dart:297, 449, 561, 567`
  - *Masalah:* Campuran bahasa: AppBar "Reading Progress", Card "Current Progress", tombol "Save Progress", "Finished This Book" vs banner "Sesi membaca tercatat!", "Halaman:", "Total Halaman Buku (Wajib)", dan dialog "Selesaikan Buku Ini?".
  - *Saran:* Selaraskan ke bahasa Indonesia ("Progres Membaca", "Progres Saat Ini", "Simpan Progres", "Selesaikan Buku Ini").
  - *Tingkat:* Sedang.
- [x] **Kategori 6 (Aksesibilitas)** — `lib/features/reading/reading_progress_page.dart:513-521` *(Selesai di Fase U4d)*
  - *Masalah:* `Slider` tidak memiliki semantic label deskriptif untuk assistive technology.
  - *Solusi Fase U4d:* Menambahkan `semanticFormatterCallback: (val) => 'Halaman ${val.round()} dari $_totalPages'`.
  - *Tingkat:* Sedang.

#### C. Finished Book (`lib/features/reading/finished_book_page.dart`)
- [x] **Kategori 1 (Lebar/Tata Letak)** — `lib/features/reading/finished_book_page.dart:133-278` *(Selesai di Fase U1)*
  - *Masalah:* Halaman dibangun menggunakan `Column` dengan dua `Spacer()` dan tidak dibungkus `SingleChildScrollView`. Pada layar 360×640 px dengan teks skala 1.3, badge piala (110×110) + cover (80×120) + ringkasan + tombol pasti mengalami **vertical overflow `RenderFlex by X pixels`**.
  - *Solusi Fase U1:* Membungkus seluruh body dengan `SafeArea` + `SingleChildScrollView` dan mengganti `Spacer()` dengan `SizedBox`.
  - *Tingkat:* Tinggi.
- **Kategori 2 (Token)** — `lib/features/reading/finished_book_page.dart:140, 147, 153, 184, 216, 242`
  - *Masalah:* Angka mentah `width: 110, height: 110`, `width: 3`, `size: 58`, `borderRadius: 12`, `BorderRadius.circular(16)`, `height: 32`.
  - *Saran:* Ganti dengan konstanta `AppSpacing` dan token desain resmi.
  - *Tingkat:* Sedang.
- **Kategori 3 (Komponen)** — `lib/features/reading/finished_book_page.dart:209-265`
  - *Masalah:* Kontainer ringkasan total halaman dan durasi membaca dirakit manual dengan Container ber-border alih-alih memakai `AppCard`.
  - *Saran:* Gunakan `AppCard`.
  - *Tingkat:* Sedang.
- [x] **Kategori 4 (Dark Mode)** — `lib/features/reading/finished_book_page.dart:154` *(Selesai di Fase U4c)*
  - *Masalah:* Ikon piala perayaan meng-hardcode warna `AppColors.deepTeal` di dark theme.
  - *Solusi Fase U4c:* Menggunakan warna adaptif `isDark ? AppColors.softApricot : AppColors.deepTeal` yang kontras tinggi di atas latar warm ivory/surface dark.
  - *Tingkat:* Rendah.
- **Kategori 5 (Teks)** — `lib/features/reading/finished_book_page.dart:162, 170, 234, 256, 272`
  - *Masalah:* Teks ucapan berbahasa Indonesia ("Selamat!", "Kamu telah menyelesaikan buku ini", "Halaman Selesai", "Waktu Membaca"), namun tombol aksi berbahasa Inggris ("Back to Home (5 s)").
  - *Saran:* Ganti label tombol menjadi "Kembali ke Beranda (5 dtk)".
  - *Tingkat:* Sedang.
- **Kategori 6 (Aksesibilitas)** — `lib/features/reading/finished_book_page.dart:89-94`
  - *Masalah:* Pengalihan otomatis (auto-redirect) 5 detik tanpa jeda manual dapat menyulitkan pengguna disabilitas / motorik lambat untuk membaca ringkasan.
  - *Saran:* Sediakan opsi pause countdown saat pengguna berinteraksi dengan layar.
  - *Tingkat:* Sedang.

---

### 2.6 Tools & 5 Sub-halamannya:
#### A. Tools Index (`lib/features/tools/tools_page.dart`)
- **Kategori 1 (Lebar/Tata Letak)** — `lib/features/tools/tools_page.dart:154-192`
  - *Masalah:* Tata letak kartu menu vertikal responsif dengan `Expanded` kolom teks.
  - *Saran:* Pertahankan.
  - *Tingkat:* Rendah.
- **Kategori 2 (Token)** — `lib/features/tools/tools_page.dart:158-159, 164`
  - *Masalah:* Angka mentah `width: 52, height: 52` dan `size: 26`.
  - *Saran:* Ganti dengan token spacing/icon.
  - *Tingkat:* Rendah.
- [x] **Kategori 3 (Komponen)** — `lib/features/tools/tools_page.dart:140-195` *(Selesai di Fase U4b)*
  - *Masalah:* `_ToolCard` mengombinasikan `Material` + `InkWell` + `Container` berulang kali alih-alih memanfaatkan `AppCard(onTap: ...)`.
  - *Solusi Fase U4b:* Refaktor `_ToolCard` menjadi menggunakan `AppCard(onTap: ...)`.
  - *Tingkat:* Sedang.
- **Kategori 4 (Dark Mode)** — Tata letak warna kartu dan ikon menyesuaikan `isDark` dengan baik.
  - *Tingkat:* Rendah.
- **Kategori 5 (Teks)** — `lib/features/tools/tools_page.dart:94, 55, 64`
  - *Masalah:* Campuran bahasa: AppBar "Tools", kartu "AI Chat", "Mini Games — Book Snake", "Best: X buku" vs "Kesan & Pesan", "Konversi Mata Uang", "Konversi Waktu".
  - *Saran:* Selaraskan ke bahasa Indonesia ("Alat & Fitur", "Permainan Mini — Book Snake", "Terbaik: ...").
  - *Tingkat:* Sedang.
- **Kategori 6 (Aksesibilitas)** — `lib/features/tools/tools_page.dart:143`
  - *Masalah:* `InkWell` pada kartu menu tidak memiliki atribut `Semantics(label: ..., button: true)`.
  - *Saran:* Tambahkan Semantics label untuk screen reader.
  - *Tingkat:* Sedang.

#### B. Kesan & Pesan (`lib/features/tools/feedback_page.dart`)
- [x] **Kategori 1 (Lebar/Tata Letak)** — `lib/features/tools/feedback_page.dart:298-304` *(Selesai di Fase U1)*
  - *Masalah:* Baris detail kartu masukan menggunakan lebar tetap `SizedBox(width: 60, child: Text(label...))`. Pada skala teks 1.3, lebar 60 px rentan memotong label "Kesan" atau "Pesan".
  - *Solusi Fase U1:* Menghapus lebar tetap 60 px dan menyusun label secara inline proporsional.
  - *Tingkat:* Sedang.
- **Kategori 2 (Token)** — `lib/features/tools/feedback_page.dart:243, 299`
  - *Masalah:* `CircleAvatar(radius: 18)` dan `width: 60` ditulis mentah.
  - *Saran:* Gunakan konstanta token.
  - *Tingkat:* Rendah.
- **Kategori 3 (Komponen)** — `lib/features/tools/feedback_page.dart:187-223`
  - *Masalah:* Widget custom `_FormField` membungkus `AppTextField` di dalam `FormField<String>` bawaan alih-alih memanfaatkan fitur bawaan form field.
  - *Saran:* Rapikan integrasi validasi form langsung ke `AppTextField`.
  - *Tingkat:* Rendah.
- [x] **Kategori 4 (Dark Mode)** — `lib/features/tools/feedback_page.dart:247` *(Selesai di Fase U4c)*
  - *Masalah:* Inisial avatar pengguna meng-hardcode `AppColors.deepTeal` di dark mode.
  - *Solusi Fase U4c:* Menggunakan `isDark ? AppColors.inkDark : AppColors.deepTeal`.
  - *Tingkat:* Sedang.
- **Kategori 5 (Teks)** — `lib/features/tools/feedback_page.dart:282`
  - *Masalah:* Format tanggal dirangkai manual dengan string interpolation alih-alih `DateFormat` lokal.
  - *Saran:* Gunakan `DateFormat('d MMM yyyy, HH:mm', 'id_ID')`.
  - *Tingkat:* Rendah.
- **Kategori 6 (Aksesibilitas)** — `lib/features/tools/feedback_page.dart:242-250`
  - *Masalah:* Inisial avatar kartu tidak memiliki semantic label.
  - *Saran:* Tambahkan `Semantics(label: 'Avatar ${entry.name}')`.
  - *Tingkat:* Rendah.

#### C. AI Chat (`lib/features/tools/ai_chat_page.dart`)
- **Kategori 1 (Lebar/Tata Letak)** — `lib/features/tools/ai_chat_page.dart:547-609`
  - *Masalah:* Baris input teks menggunakan `Expanded(Container(...))` dan `IconButton` kirim di dalam `Row`. Responsif dan aman overflow.
  - *Saran:* Pertahankan.
  - *Tingkat:* Rendah.
- **Kategori 2 (Token)** — `lib/features/tools/ai_chat_page.dart:198, 501, 551, 589, 598-601`
  - *Masalah:* `vertical: 6`, `BorderRadius.circular(20)`, `maxHeight: 120`, `strokeWidth: 2`, dan warna `Colors.white` ditulis mentah.
  - *Saran:* Gunakan konstanta `AppSpacing` dan token desain.
  - *Tingkat:* Rendah.
- [x] **Kategori 3 (Komponen)** — `lib/features/tools/ai_chat_page.dart:146-163, 243, 559-577` *(Selesai di Fase U4b)*
  - *Masalah:* Dialog hapus riwayat memakai `AlertDialog` + `ElevatedButton` bawaan alih-alih `AppDialog`. Chip saran dibuat manual alih-alih memakai `AppChip`. Input chat menggunakan `TextField` mentah di dalam Container alih-alih `AppTextField`.
  - *Solusi Fase U4b:* Mengganti dialog dengan `AppDialog.showConfirm`, chip saran memakai `AppChip`, input chat memakai `AppTextField`, dan tombol aksi memakai `AppIconButton`.
  - *Tingkat:* Sedang.
- [x] **Kategori 4 (Dark Mode)** — `lib/features/tools/ai_chat_page.dart:197, 589` *(Selesai di Fase U4c)*
  - *Masalah:* Banner demo dan tombol kirim pesan meng-hardcode `AppColors.deepTeal` tanpa berganti ke `primaryDark` di dark theme.
  - *Solusi Fase U4c:* Menggunakan `isDark ? AppColors.primaryDark : AppColors.deepTeal` untuk tombol aksi, typing dots, bubble user, dan avatar.
  - *Tingkat:* Sedang.
- [x] **Kategori 5 (Teks & Mode Demo Nyata)** — `lib/features/tools/ai_chat_page.dart:199` *(Selesai di Fase U4a)*
  - *Masalah:* **CRITICAL**: Banner "Mode Demo — Balasan tidak menggunakan AI nyata" **selalu ditampilkan secara hardcoded**, bahkan ketika integrasi Gemini nyata aktif (`AppConfig.useFakeData == false`)! Ini melanggar aturan PRD Bagian 15 mengenai penghapusan elemen demo di alur produksi.
  - *Solusi Fase U4a:* Banner demo dibungkus kondisi `if (AppConfig.useFakeData)` dan teks disesuaikan dengan warna dinamis tema.
  - *Tingkat:* Tinggi.
- **Kategori 6 (Aksesibilitas)** — Aksesibilitas baik, tombol kirim dan hapus memiliki tooltip dan ukuran sentuh minimal 48 px.
  - *Tingkat:* Rendah.

#### D. Mini Game Snake (`lib/features/tools/snake/snake_page.dart`)
- **Kategori 1 (Lebar/Tata Letak)** — `lib/features/tools/snake/snake_page.dart:273-326`
  - *Masalah:* Baris skor atas: Kartu skor Books - Tombol Pause - Kartu skor Best. Pada layar 360 px, tombol pause di tengah dan dua kartu skor berhimpitan.
  - *Saran:* Berikan margin fleksibel antar-elemen skor.
  - *Tingkat:* Sedang.
- **Kategori 2 (Token)** — `lib/features/tools/snake/snake_page.dart:163, 176, 195, 206, 293, 378, 417, 459, 608, 663`
  - *Masalah:* Banyak radius dan font mentah: `Radius.circular(24)`, `BorderRadius.circular(2/12/14/16/20)`, dan `fontSize: 40`.
  - *Saran:* Standarkan ke token `AppSpacing.cardRadius` / `buttonRadius` dan `AppText.displayLarge()`.
  - *Tingkat:* Sedang.
- **Kategori 3 (Komponen)** — `lib/features/tools/snake/snake_page.dart:284-318` & `438-460`
  - *Masalah:* Tombol Pause/Resume dibuat manual dengan `GestureDetector` + Container alih-alih `AppButton`. Opsi tilt control menggunakan `FilterChip` bawaan alih-alih `AppChip`.
  - *Saran:* Gunakan `AppButton` dan `AppChip`.
  - *Tingkat:* Sedang.
- [x] **Kategori 4 (Dark Mode)** — `snake_page.dart:392, 422` *(Selesai di Fase U4c)*
  - *Masalah:* `color: AppColors.white` di-hardcode pada teks overlay game.
  - *Solusi Fase U4c:* Menyesuaikan warna teks, paint ular, highlight score box, dan shadow board ke palet tema adaptif.
  - *Tingkat:* Rendah.
- **Kategori 5 (Teks)** — `lib/features/tools/snake/snake_page.dart:181, 198, 209, 215, 225, 258, 310, 390, 420`
  - *Masalah:* Campuran bahasa: "Book Snake", "Game Over!", "Books", "Best", "Play again", "Back to Tools", "Pause", "Resume", "Tap to start", "Paused", "Tilt Control (Gyroscope)" vs "Kumpulkan buku sebanyak mungkin!".
  - *Saran:* Selaraskan ke bahasa Indonesia ("Permainan Berakhir", "Buku", "Terbaik", "Main lagi", "Kembali ke Menu", "Jeda", "Lanjut", "Sentuh untuk mulai").
  - *Tingkat:* Sedang.
- **Kategori 6 (Aksesibilitas)** — `lib/features/tools/snake/snake_page.dart:284` & `600-640`
  - *Masalah:* Tombol Pause/Resume dan 4 tombol panah D-pad virtual tidak memiliki `Semantics` label arah gerak ular.
  - *Saran:* Tambahkan `Semantics(label: 'Gerak ke atas/bawah/kiri/kanan', button: true)` pada setiap tombol D-pad.
  - *Tingkat:* Sedang.

#### E. Konversi Mata Uang (`lib/features/tools/currency_converter_page.dart`)
- [x] **Kategori 1 (Lebar/Tata Letak)** — `lib/features/tools/currency_converter_page.dart:207-240` *(Selesai di Fase U1)*
  - *Masalah:* Row memuat dropdown "Dari", tombol Swap, dan dropdown "Ke". Pada layar 360 px, masing-masing dropdown hanya mendapat lebar ~135 px, menyebabkan nama mata uang "USD · Dolar Amerika" terpotong.
  - *Solusi Fase U1:* Menyediakan opsi susunan vertikal adaptif (`Column`) saat `isNarrow` (`screenWidth < 340` atau skala teks `> 1.15`).
  - *Tingkat:* Tinggi.
- **Kategori 2 (Token)** — `lib/features/tools/currency_converter_page.dart:227, 263, 363`
  - *Masalah:* `size: 22`, `fontSize: 36` pada display angka hasil, dan padding mentah `vertical: 4`.
  - *Saran:* Gunakan `AppText.displayLarge()` dan konstanta spacing resmi.
  - *Tingkat:* Sedang.
- [x] **Kategori 3 (Komponen)** — `lib/features/tools/currency_converter_page.dart:371-392` *(Selesai di Fase U3)*
  - *Masalah:* **Menggunakan `DropdownButtonHideUnderline` dan `DropdownButton<String>` bawaan Flutter** di dalam Container ber-border alih-alih komponen pemilih/dropdown form terpusat design system (pelanggaran langsung Kategori 3).
  - *Solusi Fase U3:* Digantikan dengan komponen reusable `AppDropdown<String>` (Material 3) yang membuka menu di bawah field dengan lebar menu sama dengan lebar field.
  - *Tingkat:* Tinggi.
- [x] **Kategori 4 (Dark Mode)** — `lib/features/tools/currency_converter_page.dart:222` *(Selesai di Fase U3)*
  - *Masalah:* Tombol swap mata uang meng-hardcode `backgroundColor: AppColors.deepTeal` tanpa berganti ke `primaryDark` di dark theme.
  - *Solusi Fase U3:* Menggunakan warna dinamis `isDark ? AppColors.primaryDark : AppColors.deepTeal`.
  - *Tingkat:* Sedang.
- **Kategori 5 (Teks)** — Bahasa Indonesia sudah diterapkan dengan konsisten.
  - *Tingkat:* Rendah.
- **Kategori 6 (Aksesibilitas)** — Target sentuh dan tooltip tombol swap sudah memadai.
  - *Tingkat:* Rendah.

#### F. Konversi Waktu (`lib/features/tools/time_converter_page.dart`)
- [x] **Kategori 1 (Lebar/Tata Letak)** — `lib/features/tools/time_converter_page.dart:154-176` *(Selesai di Fase U3)*
  - *Masalah:* Row pemilih tanggal (`flex: 3`) dan waktu (`flex: 2`). Pada layar 360 px dengan teks skala 1.3, tanggal "Rab, 22 Okt 2026" di flex 3 dapat terpotong atau mepet ke ikon kalender.
  - *Solusi Fase U3:* Menggunakan `LayoutBuilder` yang otomatis beralih ke layout `Column` saat constraint < 340 px atau skala teks > 1.15.
  - *Tingkat:* Sedang.
- [x] **Kategori 2 (Token)** — `lib/features/tools/time_converter_page.dart:59, 83, 274, 282, 336, 385` *(Selesai di Fase U3)*
  - *Masalah:* `primary: AppColors.deepTeal` di date picker builder, `BorderRadius.circular(10)`, `size: 16`, `width: 64`, dan `BorderRadius.circular(8)` ditulis mentah.
  - *Solusi Fase U3:* Menstandarkan token ke `AppSpacing.cardPadding`, `AppSpacing.cardRadius`, `AppSpacing.inputRadius`, dan warna dinamis tema.
  - *Tingkat:* Sedang.
- [x] **Kategori 3 (Komponen)** — `lib/features/tools/time_converter_page.dart:231-246, 265-298, 319-402` *(Selesai di Fase U3)*
  - *Masalah:* **Menggunakan `DropdownButtonHideUnderline` dan `DropdownButton<TimeZone>` bawaan Flutter** alih-alih komponen pemilih seragam (pelanggaran langsung Kategori 3). Pemilih tanggal dibuat dengan `_PickerChip` manual dan kartu hasil dibuat dengan Container alih-alih `AppChip` dan `AppCard`.
  - *Solusi Fase U3:* Digantikan dengan `AppDropdown<TimeZone>`, kartu hasil memakai `AppCard`, dan `_PickerChip` berstandar `AppSpacing.touchTarget` (44 px).
  - *Tingkat:* Tinggi.
- [x] **Kategori 4 (Dark Mode)** — `lib/features/tools/time_converter_page.dart:59, 83, 282, 390` *(Selesai di Fase U3)*
  - *Masalah:* Date & time picker dialog serta badge "+1 hari" meng-hardcode `AppColors.deepTeal` tanpa penyesuaian `primaryDark` di dark mode.
  - *Solusi Fase U3:* Terapkan warna dinamis `isDark ? AppColors.primaryDark : AppColors.deepTeal`.
  - *Tingkat:* Sedang.
- **Kategori 5 (Teks)** — Bahasa Indonesia konsisten, timezone label mengikuti nama wilayah resmi.
  - *Tingkat:* Rendah.
- [x] **Kategori 6 (Aksesibilitas)** — `lib/features/tools/time_converter_page.dart:265-298` *(Selesai di Fase U3)*
  - *Masalah:* `_PickerChip` menggunakan `GestureDetector` dengan padding vertical 8 px, sehingga tinggi area sentuh totalnya hanya ~36 px, berada **di bawah batas minimum 44×44 px** (design-system.md §4).
  - *Solusi Fase U3:* Menggunakan `ConstrainedBox(constraints: BoxConstraints(minHeight: 44))` dan dibungkus `Semantics(button: true, label: ...)`.
  - *Tingkat:* Tinggi.

---

### 2.7 Profile & Reading Ledger:
#### A. Profile (`lib/features/profile/profile_page.dart`)
- **Kategori 1 (Lebar/Tata Letak)** — `lib/features/profile/profile_page.dart:331-393` & `539-588`
  - *Masalah:* Row bawah card profil yang memuat status sinkronisasi (`Flexible`) dan tombol `TextButton.icon('Edit Profil')` dapat berhimpitan pada layar 360 px. `SegmentedButton` tema (Light, Dark, Auto) berisiko memotong teks label pada skala teks 1.3.
  - *Saran:* Berikan susunan kolom pada header profile di layar sempit dan bungkus label segmented button dengan `FittedBox`.
  - *Tingkat:* Sedang.
- **Kategori 2 (Token)** — `lib/features/profile/profile_page.dart:276, 281, 383, 389, 748, 891, 913`
  - *Masalah:* Angka mentah `width: 1.5`, `size: 12/16/20`, `fontSize: 13`, `width: 64, height: 64`, dan `radius: 32` pada widget avatar.
  - *Saran:* Gunakan konstanta `AppSpacing` dan token `AppText`.
  - *Tingkat:* Rendah.
- [x] **Kategori 3 (Komponen)** — `lib/features/profile/profile_page.dart:161-209, 378-391, 539-588, 756-764` *(Selesai di Fase U4b)*
  - *Masalah:* Dialog logout menggunakan `AlertDialog` + `ElevatedButton` bawaan alih-alih `AppDialog`. Edit Profil memakai `TextButton.icon` bawaan. Pilihan tema memakai `SegmentedButton` bawaan. Tombol ubah jam memakai `OutlinedButton` bawaan.
  - *Solusi Fase U4b:* Mengganti dialog logout dengan `AppDialog.showConfirm`, tombol Edit Profil dan Ubah Jam dengan `TertiaryButton`, dan pilihan tema dengan `FilterTabs`.
  - *Tingkat:* Sedang.
- [x] **Kategori 4 (Dark Mode)** — `lib/features/profile/profile_page.dart:409, 481, 747, 844, 854` *(Selesai di Fase U4a)*
  - *Masalah:* Ikon Ringkasan Bacaan, Reading Ledger, dan Jadwal Pengingat meng-hardcode `AppColors.deepTeal` / `oceanTeal` di dark theme. Teks catatan demo meng-hardcode `AppColors.ink`.
  - *Solusi Fase U4a:* Menyesuaikan kartu "Mode Demo & QA" memakai warna dinamis `isDark ? AppColors.inkDark : AppColors.ink` dan icon `primaryDark` di dark theme.
  - *Tingkat:* Sedang.
- **Kategori 5 (Teks)** — `lib/features/profile/profile_page.dart:233, 491, 544, 549, 554, 871`
  - *Masalah:* Campuran bahasa: AppBar "Profile", Card "Reading Ledger", segmen "Light / Dark / Auto", tombol "Keluar dari Akun (Logout)" vs "Ringkasan Bacaan", "Kunci Biometrik", "Pengingat Membaca Harian".
  - *Saran:* Selaraskan ke bahasa Indonesia ("Profil", "Terang / Gelap / Otomatis", "Keluar dari Akun").
  - *Tingkat:* Sedang.
- [x] **Kategori 6 (Aksesibilitas)** — `lib/features/profile/profile_page.dart:259` & `564` *(Selesai di Fase U4d)*
  - *Masalah:* Avatar yang dapat ditekan untuk membuka edit profil menggunakan `GestureDetector` tanpa `Semantics(label: 'Ubah foto profil', button: true)`. `tapTargetSize: MaterialTapTargetSize.shrinkWrap` pada SegmentedButton tema memperkecil area sentuh di bawah 44 px.
  - *Solusi Fase U4d:* Menambahkan `Semantics(label: 'Ubah foto profil', button: true)` pada avatar dan membungkus avatar FeedbackPage.
  - *Tingkat:* Sedang.

#### B. Reading Ledger (`lib/features/profile/reading_ledger_page.dart`)
- [x] **Kategori 1 (Lebar/Tata Letak)** — `lib/features/profile/reading_ledger_page.dart:433-445` *(Selesai di Fase U1)*
  - *Masalah:* Row membagi dua kolom: `Expanded(_buildHashRow('Nonce'))` dan `Expanded(_buildHashRow('PoW Status'))`. Kolom PoW Status memuat teks 'Awalan "00" (Valid)' yang sangat panjang untuk lebar ~130 px pada layar 360 px, rentan terpotong.
  - *Solusi Fase U1:* Meringkas status PoW menjadi `'Valid (${LedgerService.targetPrefix})'`, membungkus header verifikasi dan chip blok dengan `Flexible`/`Expanded` anti-overflow.
  - *Tingkat:* Sedang.
- **Kategori 2 (Token)** — `lib/features/profile/reading_ledger_page.dart:277, 299, 307, 360, 471-477`
  - *Masalah:* **Menggunakan `TextStyle(fontFamily: 'monospace', fontSize: 11, ...)` mentah bawaan Flutter** alih-alih token tipografi desain sistem (`AppText`). Garis rantai dan border width ditulis mentah.
  - *Saran:* Buat token helper `AppText.code()` atau `AppText.monospace()` dan gunakan `AppSpacing`.
  - *Tingkat:* Sedang.
- **Kategori 3 (Komponen)** — `lib/features/profile/reading_ledger_page.dart:238-266` & `294-332`
  - *Masalah:* Empty state rantai blok dan kartu hasil verifikasi dirakit manual dengan Container ber-border alih-alih `EmptyStateCard` dan `AppCard`.
  - *Saran:* Gunakan `EmptyStateCard` dan `AppCard`.
  - *Tingkat:* Sedang.
- [x] **Kategori 4 (Dark Mode)** — `lib/features/profile/reading_ledger_page.dart:153, 278, 373, 379` *(Selesai di Fase U4c)*
  - *Masalah:* Ikon rantai dan teks chip blok meng-hardcode `AppColors.deepTeal` tanpa berganti ke `primaryDark` di dark theme.
  - *Solusi Fase U4c:* Menggunakan `context.primaryColor` (`isDark ? AppColors.primaryDark : AppColors.deepTeal`) dan `AppText.code()` monospace.
  - *Tingkat:* Sedang.
- **Kategori 5 (Teks)** — `lib/features/profile/reading_ledger_page.dart:92, 213, 431, 435, 438`
  - *Masalah:* Campuran bahasa: AppBar "Reading Ledger", tombol "Verify Ledger", label "Hash", "Prev Hash", "Nonce", "PoW Status" vs "Buku Selesai Terenkripsi", "Verifikasi Keutuhan Rantai", "Daftar Blok Rantai".
  - *Saran:* Selaraskan ke bahasa Indonesia ("Buku Besar Bacaan", "Verifikasi Ledger", "Hash Sebelumnya").
  - *Tingkat:* Sedang.
- [x] **Kategori 6 (Aksesibilitas)** — `lib/features/profile/reading_ledger_page.dart:473` *(Selesai di Fase U4c)*
  - *Masalah:* Ukuran font monospace hash 11 px berada di bawah batas minimum keterbacaan (12 px).
  - *Solusi Fase U4c:* Ditingkatkan menjadi 12 px dengan token terpusat `AppText.code()`.
  - *Tingkat:* Sedang.

---

### 2.8 Edit Profile (`lib/features/profile/edit_profile_page.dart`)
- **Kategori 1 (Lebar/Tata Letak)** — Tata letak SingleChildScrollView vertikal dengan field lebar penuh. Responsif dan tidak ada risiko overflow pada 360 px.
  - *Tingkat:* Rendah.
- **Kategori 2 (Token)** — `lib/features/profile/edit_profile_page.dart:243, 252, 287, 288, 293, 312, 325, 381, 387`
  - *Masalah:* Dimensi avatar `width: 96, height: 96`, kontainer `104x104`, border width `3`, ukuran ikon `size: 18`, `size: 16`, serta `radius: 46` ditulis mentah.
  - *Saran:* Gunakan konstanta `AppSpacing` dan token tema.
  - *Tingkat:* Rendah.
- [x] **Kategori 3 (Komponen)** — `lib/features/profile/edit_profile_page.dart:301-317` & `323-330` *(Selesai di Fase U4b)*
  - *Masalah:* Tombol badge kamera dirakit manual dengan `Material` + `InkWell` alih-alih `AppIconButton`. Tombol "Ganti Foto" memakai `TextButton.icon` bawaan alih-alih `TertiaryButton`.
  - *Solusi Fase U4b:* Mengganti tombol Ganti Foto dengan `TertiaryButton`.
  - *Tingkat:* Sedang.
- [x] **Kategori 4 (Dark Mode)** — `lib/features/profile/edit_profile_page.dart:302` *(Selesai di Fase U4c)*
  - *Masalah:* Badge kamera meng-hardcode `color: AppColors.deepTeal` di dark theme.
  - *Solusi Fase U4c:* Menggunakan `context.primaryColor` (`isDark ? AppColors.primaryDark : AppColors.deepTeal`).
  - *Tingkat:* Sedang.
- **Kategori 5 (Teks)** — Bahasa Indonesia diterapkan secara konsisten.
  - *Tingkat:* Rendah.
- [x] **Kategori 6 (Aksesibilitas)** — `lib/features/profile/edit_profile_page.dart:306` *(Selesai di Fase U4d)*
  - *Masalah:* `InkWell` badge kamera tidak memiliki semantic label "Ubah foto profil".
  - *Solusi Fase U4d:* Menambahkan `Semantics(label: 'Ubah foto profil', button: true)`.
  - *Tingkat:* Sedang.

---

### 2.9 Auth Flow:
#### A. Login (`lib/features/auth/login_page.dart`)
- **Kategori 1 (Lebar/Tata Letak)** — Tata letak SingleChildScrollView vertikal aman pada layar 360 px.
  - *Tingkat:* Rendah.
- **Kategori 2 (Token)** — `lib/features/auth/login_page.dart:252, 253, 266`
  - *Masalah:* `fontSize: 13` dan `color: AppColors.ink` ditulis mentah pada NotesCard catatan demo.
  - *Saran:* Gunakan token `AppText.caption()` resmi.
  - *Tingkat:* Rendah.
- [x] **Kategori 3 (Komponen)** — `lib/features/auth/login_page.dart:218-231` *(Selesai di Fase U4b)*
  - *Masalah:* Link navigasi ke Register memakai `TextButton` bawaan alih-alih `TertiaryButton`.
  - *Solusi Fase U4b:* Mengganti tombol link ke Register dengan `TertiaryButton`.
  - *Tingkat:* Rendah.
- **Kategori 4 (Dark Mode)** — Kontras kartu NotesCard dan field aman.
  - *Tingkat:* Rendah.
- [x] **Kategori 5 (Teks & Mode Demo Nyata)** — `lib/features/auth/login_page.dart:22-23` & `237-270` *(Selesai di Fase U4a)*
  - *Masalah:* **Kredensial demo terisi otomatis** (`reader@storyloka.app` dan `password123`). Selain itu, **Kartu "Catatan Mode Demo (Fase A1)" masih ditampilkan secara statis** di alur nyata tanpa dibatasi `kDebugMode`. Pada tombol aksi tertulis "Login" (Inggris) vs link "Belum punya akun? Daftar" (Indonesia).
  - *Solusi Fase U4a:* Kredensial dikosongkan kecuali pada mode fake, dan kartu catatan demo hanya ditampilkan jika `isFake && kDebugMode` dengan warna teks dinamis.
  - *Tingkat:* Tinggi.
- **Kategori 6 (Aksesibilitas)** — Target sentuh field dan tombol 48 px memenuhi standar minimum.
  - *Tingkat:* Rendah.

#### B. Register (`lib/features/auth/register_page.dart`)
- **Kategori 1 (Lebar/Tata Letak)** — Tata letak SingleChildScrollView vertikal aman pada layar 360 px.
  - *Tingkat:* Rendah.
- **Kategori 2 (Token)** — Token spacing dan typography digunakan dengan baik.
  - *Tingkat:* Rendah.
- [x] **Kategori 3 (Komponen)** — `lib/features/auth/register_page.dart:292-305` *(Selesai di Fase U4b)*
  - *Masalah:* Link navigasi ke Login memakai `TextButton` bawaan alih-alih `TertiaryButton`.
  - *Solusi Fase U4b:* Mengganti tombol link ke Login dengan `TertiaryButton`.
  - *Tingkat:* Rendah.
- **Kategori 4 (Dark Mode)** — Penanganan mode gelap baik.
  - *Tingkat:* Rendah.
- **Kategori 5 (Teks)** — Bahasa Indonesia diterapkan secara konsisten.
  - *Tingkat:* Rendah.
- **Kategori 6 (Aksesibilitas)** — Target sentuh memenuhi standar.
  - *Tingkat:* Rendah.

#### C. Lock Screen (`lib/features/auth/lock_screen_page.dart`)
- [x] **Kategori 1 (Lebar/Tata Letak)** — `lib/features/auth/lock_screen_page.dart:96-195` *(Selesai di Fase U1)*
  - *Masalah:* Layout menggunakan `Column` dengan dua `Spacer()` tanpa `SingleChildScrollView`. Pada layar 360×640 px dengan skala teks 1.3, bila tombol debug aktif, layar berpotensi overflow vertikal.
  - *Solusi Fase U1:* Membungkus body dengan `SafeArea` + `SingleChildScrollView` dan mengganti `Spacer()` dengan `SizedBox`.
  - *Tingkat:* Sedang.
- **Kategori 2 (Token)** — `lib/features/auth/lock_screen_page.dart:105-106, 114, 120`
  - *Masalah:* Angka mentah `width: 88, height: 88`, `width: 2`, dan `size: 48` pada ikon sidik jari.
  - *Saran:* Gunakan konstanta `AppSpacing` dan token desain.
  - *Tingkat:* Rendah.
- [x] **Kategori 3 (Komponen)** — `lib/features/auth/lock_screen_page.dart:182-192` *(Selesai di Fase U4b)*
  - *Masalah:* Tombol fallback memakai `TextButton` bawaan alih-alih `TertiaryButton`.
  - *Solusi Fase U4b:* Mengganti tombol fallback password dengan `TertiaryButton`.
  - *Tingkat:* Rendah.
- **Kategori 4 (Dark Mode)** — Penanganan warna dinamis `primaryColor` baik.
  - *Tingkat:* Rendah.
- **Kategori 5 (Teks)** — `lib/features/auth/lock_screen_page.dart:185`
  - *Masalah:* Teks "Login dengan password" mencampur kata Inggris dan Indonesia.
  - *Saran:* Ganti menjadi "Masuk dengan kata sandi".
  - *Tingkat:* Rendah.
- [x] **Kategori 6 (Aksesibilitas)** — `lib/features/auth/lock_screen_page.dart:102-125` *(Selesai di Fase U4d)*
  - *Masalah:* Lingkaran ikon sidik jari yang dapat ditekan untuk memicu biometrik menggunakan `GestureDetector` tanpa `Semantics(label: 'Sentuh untuk verifikasi biometrik', button: true)`.
  - *Solusi Fase U4d:* Menambahkan `Semantics(label: 'Pindai sidik jari atau biometrik untuk membuka kunci', button: true)`.
  - *Tingkat:* Sedang.

#### D. Splash Screen (`lib/features/auth/splash_page.dart`)
- **Kategori 1 (Lebar/Tata Letak)** — Tata letak terpusat aman.
  - *Tingkat:* Rendah.
- **Kategori 2 (Token)** — `lib/features/auth/splash_page.dart:47-48, 58, 63, 96`
  - *Masalah:* Angka mentah `width: 96, height: 96`, `width: 1.5`, `size: 48`, dan `strokeWidth: 2.5`.
  - *Saran:* Gunakan konstanta token.
  - *Tingkat:* Rendah.
- **Kategori 3, 4, 5, 6** — Tidak ada masalah signifikan.

---

### 2.10 App Shell & Navigation (`lib/app/main_shell.dart`)
- **Kategori 1 (Lebar/Tata Letak)** — `lib/app/main_shell.dart:54-103`
  - *Masalah:* 5 item navigasi dengan tombol tengah 56 px. Pada layar 360 px, masing-masing item mendapat lebar ~60 px dengan target sentuh aman (44 px).
  - *Saran:* Pertahankan.
  - *Tingkat:* Rendah.
- **Kategori 2 (Token)** — `lib/app/main_shell.dart:40, 126, 150`
  - *Masalah:* `width: 1.0`, `BorderRadius.circular(16)`, dan font size label navigasi `fontSize: 11` (< 12 px) ditulis mentah.
  - *Saran:* Gunakan token `AppSpacing` dan `AppText.caption()`.
  - *Tingkat:* Sedang.
- **Kategori 3 (Komponen)** — Dibuat custom sesuai Cozy Botanical design-system.md §6.
  - *Tingkat:* Rendah.
- [x] **Kategori 4 (Dark Mode)** — `lib/app/main_shell.dart:196` *(Selesai di Fase U4c)*
  - *Masalah:* Border tombol tengah Add saat aktif meng-hardcode `AppColors.deepTeal` tanpa berganti ke `primaryDark` di dark theme.
  - *Solusi Fase U4c:* Menggunakan `context.primaryColor` (`isDark ? AppColors.primaryDark : AppColors.deepTeal`).
  - *Tingkat:* Sedang.
- **Kategori 5 (Teks)** — `lib/app/main_shell.dart:61, 71, 85, 95, 177`
  - *Masalah:* Label tab navigasi berbahasa Inggris: 'Home', 'Library', 'Tools', 'Profile', 'Add Book'.
  - *Saran:* Selaraskan ke bahasa Indonesia ("Beranda", "Koleksi", "Tambah", "Alat", "Profil") jika seluruh aplikasi dilokalisasi ke bahasa Indonesia.
  - *Tingkat:* Sedang.
- **Kategori 6 (Aksesibilitas)** — Sangat baik; setiap tab dan tombol tengah sudah dibungkus `Semantics` lengkap dengan status selected.
  - *Tingkat:* Rendah.

---

## 3. Urutan Perbaikan yang Diusulkan

Urutan tahapan perbaikan yang disarankan untuk dilaksanakan pada fase perbaikan tampilan (Fase U1 dan seterusnya) adalah sebagai berikut:

### Tahap 1: Perbaikan Kritis & Fungsionalitas Tampilan (Prioritas Tinggi)
1. [x] **Bersihkan Elemen Demo di Alur Nyata:** *(Selesai di Fase U4a)*
   - Sembunyikan banner hardcoded "Mode Demo" di `ai_chat_page.dart:199` jika `!AppConfig.useFakeData`.
   - Sembunyikan "Catatan Mode Demo" di `login_page.dart:237` jika `!kDebugMode`, dan bersihkan pre-filled demo email/password di mode produksi.
2. [x] **Ganti Dropdown Bawaan:** *(Selesai di Fase U3)*
   - Ganti `DropdownButton` bawaan di `currency_converter_page.dart` dan `time_converter_page.dart` dengan komponen pemilih/dropdown seragam design system (Kategori 3).
3. [x] **Cegah Overflow Layar Sempit & Skala Teks 1.3:** *(Selesai di Fase U1 & U3)*
   - Tambahkan `SingleChildScrollView` pada `finished_book_page.dart`, `reading_timer_page.dart`, dan `lock_screen_page.dart`.
   - Perbaiki susunan dua tombol aksi berdampingan di `search_book_detail_page.dart` dan `collection_book_detail_page.dart` agar adaptif (vertikal bila sempit).
   - Perbaiki row input halaman di `reading_progress_page.dart` agar tidak overflow.
4. [x] **Perbaiki Target Sentuh < 44×44 px:** *(Selesai di Fase U3 & U4a)*
   - Tingkatkan area sentuh tombol Read More/Less (30 px $\rightarrow$ 44 px).
   - Tingkatkan area sentuh bintang rating di `collection_book_detail_page.dart` (32×36 px $\rightarrow$ 44×44 px).
   - Tingkatkan tinggi chip pemilih tanggal/jam di `time_converter_page.dart` (36 px $\rightarrow$ 44 px).

### Tahap 2: Standardisasi Komponen, Dark Mode, & Aksesibilitas (Prioritas Sedang)
1. [x] **Migrasi Dialog dan Button Material ke Core Widgets:** *(Selesai di Fase U4b)*
   - Ganti seluruh `AlertDialog` dan `ElevatedButton`/`TextButton` bawaan di Library, Collection Detail, Reading Timer, Reading Progress, Profile, dan AI Chat dengan `AppDialog` / reusable buttons di `core/widgets/`.
   - Ganti `SegmentedButton` bawaan di Add Book dan Profile dengan `FilterTabs` atau `AppChip`.
2. [x] **Perbaiki Inkonsistensi Dark Mode:** *(Selesai di Fase U4c)*
   - Ubah seluruh hardcoded `AppColors.deepTeal` pada ikon/tombol aksi aktif ke `isDark ? AppColors.primaryDark : AppColors.deepTeal` (piala perayaan, slider, tombol kirim AI chat, swap mata uang, border tombol Add).
3. [x] **Standarkan Tipografi & Hierarki Teks:** *(Selesai di Fase U4a & U4c)*
   - Gunakan serif Fraunces untuk judul buku di kartu grid (`library_page.dart` / `BookGridCard`).
   - Ganti raw `TextStyle(fontFamily: 'monospace')` di Reading Ledger dengan token tipografi terpusat `AppText.code()`.
   - Hapus duplikasi label nama penerbit di `search_book_detail_page.dart`.
   - Standarkan ukuran font minimum 12 px (menghapus font 10 & 11 px).
4. [x] **Lengkapi Semantics untuk Screen Reader:** *(Selesai di Fase U4d)*
   - Berikan semantic label pada cover buku di Home & Library (termasuk aksi semantik hapus buku), kartu menu Tools, D-pad kontrol dan tombol Jeda di Snake, avatar/tombol ganti foto profil di Profile/Edit Profile/Feedback, rating bintang, lingkaran sidik jari Lock Screen, stopwatch liveRegion, dan slider progress.

### Tahap 3: Pembersihan Token & Konsistensi Bahasa (Prioritas Rendah)
1. [x] **Pembersihan Token Mentah:** *(Selesai di Fase U5)*
   - Menambahkan konstanta resmi di `AppSpacing`: `radiusXs` (4), `radiusS` (8), `radiusL` (16), `radius18` (18), `radius22` (22), `radiusFull` (999); dimensi ikon `iconXs` (14), `iconS` (16), `iconM` (20), `iconL` (24), `iconXl` (32), `iconXxl` (48); dimensi avatar `avatarSmallRadius` (18), `avatarMediumRadius` (24), `avatarLargeRadius` (32), `avatarXLargeRadius` (46), `avatarContainerSize` (104), `avatarImageSize` (96); serta `biometricCircleSize` (88).
   - Menambahkan token tipografi `AppText.displayMedium({Color? color, double fontSize = 36})`.
   - Mengganti seluruh `BorderRadius.circular(angka)`, `fontSize` mentah, dan dimensi hardcoded di seluruh layar (`FinishedBookPage`, `FeedbackPage`, `ReadingLedgerPage`, `CurrencyConverterPage`, `SnakePage`, `TimeConverterPage`, `ReadingProgressPage`, `HomePage`, `AppTextField`, `AppDropdown`, `AppSnackBar`, `ProgressAndBadge`, `LoginPage`, `CollectionBookDetailPage`, `ProfilePage`, `EditProfilePage`, `LockScreenPage`, `AddBookPage`, `ScanPage`, `MainShell`).
2. [x] **Penyelarasan Bahasa (Lokalisasi Konsisten):** *(Selesai di Fase U5)*
   - **Diselaraskan ke Bahasa Indonesia:**
     - Format tanggal dan waktu di kartu hasil `TimeConverterPage` dan kartu masukan `FeedbackPage` menggunakan `DateFormat('d MMM yyyy, HH:mm', 'id_ID')`, serta `ReadingLedgerPage` menggunakan `DateFormat('dd MMM yyyy, HH:mm', 'id_ID')`.
     - Label tombol hitung mundur di `FinishedBookPage` diubah dari `"Back to Home (5 s)"` menjadi `"Kembali ke Beranda ($_countdown dtk)"`.
     - Seluruh judul dialog, isi dialog konfirmasi, dan pesan validasi/error konsisten berbahasa Indonesia.
   - **Sengaja Dipertahankan (Tidak Diterjemahkan Massal):**
     - Sesuai instruksi Fase U5 dan aturan PRD / `docs/spec/design-system.md` & `wireframe.md`, judul halaman, label tab navigasi bawah (Home, Library, Tools, Profile, Add Book), dan tombol aksi utama (Currently Reading, My Collection, Start Reading, Add to Collection, Save Review, dsb.) **sengaja dipertahankan** sesuai spesifikasi desain sistem agar konsisten dengan arsitektur UI dan ekspektasi widget test.
