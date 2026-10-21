# StoryLoka: Struktur Layar & Wireframe

Aplikasi personal book management dan reading companion.
Konsep visual: Cozy Editorial × Soft Botanical × Warm Minimalism.

**Legenda wireframe**

| Simbol | Arti |
|--------|------|
| `[ Tombol ]` | Tombol |
| `( )` | Ikon, chip, atau avatar |
| `+--+` | Card atau kotak |
| `{data}` | Data dinamis (bukan data palsu) |
| `>` | Navigasi ke layar lain |

---

## 0. Peta Navigasi

```
App Launch
│
├── [Belum login] ──► Auth Flow
│                      ├── Login (email)
│                      └── Register (email)
│
└── [Sudah login] ──► Main Shell (Bottom Navigation)
                       ├── 1. Home
                       ├── 2. Library
                       ├── 3. Add Book   (tombol tengah, aksen Soft Apricot)
                       ├── 4. Tools
                       └── 5. Profile
```

> Urutan bottom nav mengikuti dokumen alur. Di design system bagian "Values to Verify", urutan final masih perlu dicek ulang di Figma.

### Alur antar halaman

```
Login/Register ──► Home
Home ──► Add Book ──► Book Detail (Add) ──► Library
Home ──► Library (See all)
Library ──► Book Detail (Collection) ──► Reading Timer ──► Reading Progress ──► Finished Book ──► Home
Library ──► Book Detail (Wishlist) ──► (Add to Collection) ──► Library
Home (Read / Update) ──► Reading Timer / Reading Progress
Tools ──► Kesan & Pesan | AI Chat | Mini Games | Konversi Mata Uang | Konversi Waktu
Profile ──► Edit Profile | Logout ──► Login
```

### Ringkasan daftar layar

| Grup | Layar |
|------|-------|
| Auth | Login, Register |
| Main | Home, Library (Collection / Wishlist), Add Book, Tools, Profile |
| Detail | Book Detail (Add), Book Detail (Collection), Book Detail (Wishlist) |
| Reading | Reading Timer, Reading Progress, Finished Book |
| Add Book | Scan Barcode |
| Tools | Kesan & Pesan, AI Chat, Mini Games, Konversi Mata Uang, Konversi Waktu |
| Profile | Edit Profile |
| Dialog | Konfirmasi Finished Book, Konfirmasi Logout, Permission (kamera, lokasi, biometrik, notifikasi) |

**Total: 22 layar + dialog**

---

## 1. Auth Flow

### 1.1 Login

**Komponen:** logo, input email, input password, tombol Login, link ke Register.
**State:** loading, validation error, network error.

```
+--------------------------------------+
|                                      |
|            [ logo ]                  |
|             StoryLoka                |
|                                      |
|  Email                               |
|  +--------------------------------+  |
|  | nama@email.com                 |  |
|  +--------------------------------+  |
|  Password                            |
|  +--------------------------------+  |
|  | ********                   [o] |  |
|  +--------------------------------+  |
|                                      |
|  [              LOGIN              ] |
|                                      |
|   Belum punya akun? Register         |
+--------------------------------------+
```

### 1.2 Register

**Komponen:** input nama, email, password, tombol Register, link ke Login.
**State:** loading, validation error, email sudah terdaftar.

```
+--------------------------------------+
| <  Register                          |
|                                      |
|  Nama                                |
|  +--------------------------------+  |
|  | Nama lengkap                   |  |
|  +--------------------------------+  |
|  Email                               |
|  +--------------------------------+  |
|  | nama@email.com                 |  |
|  +--------------------------------+  |
|  Password                            |
|  +--------------------------------+  |
|  | ********                   [o] |  |
|  +--------------------------------+  |
|                                      |
|  [           REGISTER              ] |
|                                      |
|   Sudah punya akun? Login            |
+--------------------------------------+
```

---

## 2. Home

**Header:** sapaan "Hello, User!" + "Mau baca apa hari ini?", avatar (tap > Profile).

**Komponen:**
1. **Reading Summary:** jumlah buku, sedang dibaca, selesai dibaca.
2. **Currently Reading** (2 kondisi):
   - Kosong: ilustrasi + "Start Your Reading Journey" + tombol Add Book > Add Book.
   - Terisi: cover, judul, penulis, progress bar, tombol **Read** > Reading Timer, tombol **Update** > Reading Progress.
3. **My Collection** + See all > Library (filter Collection).
4. **My Wishlist** + See all > Library (filter Wishlist).

> Currently Reading mengikuti buku terakhir yang di-*Start Reading*, jadi bisa berganti-ganti.

```
+--------------------------------------+
| Hello, User!                    (  ) |
| Mau baca apa hari ini?               |
|                                      |
| +----------------------------------+ |
| |   00        00        00         | |
| | Koleksi   Dibaca   Selesai       | |
| +----------------------------------+ |
|                                      |
| CURRENTLY READING                    |
| +----------------------------------+ |
| | +------+ Judul Buku              | |
| | |      | Nama penulis            | |
| | |cover | [=====>   ] 62%         | |
| | |      | [Read]  [Update]        | |
| | +------+                         | |
| +----------------------------------+ |
|                                      |
| My Collection              See all > |
| +----------------------------------+ |
| | +----+  +----+  +----+           | |
| | |    |  |    |  |    |           | |
| | +----+  +----+  +----+           | |
| +----------------------------------+ |
|                                      |
| My Wishlist                See all > |
| +----------------------------------+ |
| | +----+  +----+  +----+           | |
| | |    |  |    |  |    |           | |
| | +----+  +----+  +----+           | |
| +----------------------------------+ |
|--------------------------------------|
|  Home  Lib   (+)  Tools  Profil      |
+--------------------------------------+
```

### 2a. Home, kondisi kosong

```
| CURRENTLY READING                    |
| +----------------------------------+ |
| |              Start Your Reading  | |
| |              Journey             | |
| |              [ + Add Book ]      | |
| +----------------------------------+ |
|                                      |
| My Collection              See all > |
| +----------------------------------+ |
| |  Belum ada buku di koleksimu     | |
| |  [ + Add Book ]                  | |
| +----------------------------------+ |
```

My Wishlist kosong polanya sama. Semua tombol Add Book menuju **Add Book**.

---

## 3. Library

**Komponen umum:** back button, judul, search bar, filter tab Collection | Wishlist, grid card buku 3 kolom, empty state.

### 3.1 Filter Collection

Card: cover, badge status, judul, penulis. Tap card > **Book Detail (Collection)**.

```
+--------------------------------------+
| <  Library                           |
|                                      |
|  +--------------------------------+  |
|  | (o) Search books by title      |  |
|  +--------------------------------+  |
|                                      |
|  [ Collection ]      Wishlist        |
|                                      |
|  +------+  +------+  +------+        |
|  |status|  |status|  |status|        |
|  | cover|  | cover|  | cover|        |
|  +------+  +------+  +------+        |
|  Judul     Judul     Judul           |
|  Penulis   Penulis   Penulis         |
|                                      |
|  +------+  +------+  +------+        |
|  |status|  |status|  |status|        |
|  | cover|  | cover|  | cover|        |
|  +------+  +------+  +------+        |
|  Judul     Judul     Judul           |
|  Penulis   Penulis   Penulis         |
|--------------------------------------|
|  Home  Lib   (+)  Tools  Profil      |
+--------------------------------------+
```

### 3.2 Filter Wishlist

Sama dengan Collection, tetapi card **tanpa badge status**. Tap card > **Book Detail (Wishlist)**.

```
|  Collection      [ Wishlist ]        |
|                                      |
|  +------+  +------+  +------+        |
|  | cover|  | cover|  | cover|        |
|  +------+  +------+  +------+        |
|  Judul     Judul     Judul           |
|  Penulis   Penulis   Penulis         |
```

### 3.3 Empty state

```
|        ,-----------.                 |
|        |  (buku)   |                 |
|        '-----------'                 |
|       Belum ada buku di sini         |
|     [ Add Your Book ]                |
```

---

## 4. Add Book

**Komponen:** search bar, ikon **Shake to Discover** (accelerometer, hp digoyang > buku acak), filter chip Title | Author | ISBN, tombol Scan Barcode, area hasil.
**State:** initial, loading (skeleton), hasil, tidak ada hasil, error jaringan.

```
+--------------------------------------+
| <  Add a Book                        |
|                                      |
|  +-----------------------------+ (~) |
|  | (o) Search books by title   |     |
|  +-----------------------------+     |
|                                      |
|  [ Title ]   Author    ISBN          |
|                                      |
|  +--------------------------------+  |
|  | (|||)  Scan Barcode          > |  |
|  |        Find a book by ISBN     |  |
|  +--------------------------------+  |
|                                      |
|            ,-----------.             |
|            | (buku)    |             |
|            '-----------'             |
|          Discover Books              |
|    Cari lewat judul, penulis,        |
|    atau ISBN untuk menemukan         |
|    bacaan berikutnya.                |
|--------------------------------------|
|  Home  Lib   (+)  Tools  Profil      |
+--------------------------------------+
```

`(~)` = ikon Shake to Discover.

### 4a. Setelah ada hasil pencarian

Card hanya menampilkan cover, judul, penulis. Tap card > **Book Detail (Add)**.

```
|  [ Title ]   Author    ISBN          |
|  +--------------------------------+  |
|  | (|||)  Scan Barcode          > |  |
|  +--------------------------------+  |
|                                      |
|  +------+  +------+  +------+        |
|  |      |  |      |  |      |        |
|  | cover|  | cover|  | cover|        |
|  +------+  +------+  +------+        |
|  Judul     Judul     Judul           |
|  Penulis   Penulis   Penulis         |
|                                      |
|  (grid berlanjut ke bawah)           |
```

### 4b. Scan Barcode

Jika izin kamera ditolak: tampilkan penjelasan dan input ISBN manual. Hasil scan > **Book Detail (Add)**.

```
+--------------------------------------+
| <  Scan Barcode                      |
|                                      |
|  +--------------------------------+  |
|  |                                |  |
|  |      +------------------+      |  |
|  |      |  ----barcode---  |      |  |
|  |      +------------------+      |  |
|  |                                |  |
|  +--------------------------------+  |
|                                      |
|    Arahkan kamera ke barcode ISBN    |
|                                      |
|  [      Masukkan ISBN manual       ] |
+--------------------------------------+
```

---

## 5. Book Detail (3 varian)

### 5.1 Book Detail (Add), dari Add Book

**Komponen:** cover (rasio 2:3), judul, penulis, genre, tombol **Add to Collection** (primary) dan **Add to Wishlist** (secondary), card Synopsis, card Book Price, card Find Nearby Bookstores.

**Perilaku:**
- Setelah ditekan, tombol berubah menjadi "Added to collection" / "Added to wishlist".
- Buku langsung muncul di Library sesuai filter.
- Cegah duplikasi data.
- Harga memakai data yang benar-benar tersedia.

```
+--------------------------------------+
| <  Book Detail                       |
|                                      |
|             +--------+               |
|             | cover  |               |
|             |  2:3   |               |
|             +--------+               |
|            Judul Buku                |
|             Penulis                  |
|        (Genre) (Genre) (Genre)       |
|                                      |
|  [        Add to Collection        ] |
|  [        Add to Wishlist          ] |
|                                      |
| +----------------------------------+ |
| | Synopsis                         | |
| | Lorem ipsum dolor sit amet...    | |
| | Read More v                      | |
| +----------------------------------+ |
| +----------------------------------+ |
| | (tag) Book Price                 | |
| |         {harga}        [IDR v]   | |
| +----------------------------------+ |
| +----------------------------------+ |
| | (pin) Find Nearby Bookstores     | |
| | [        > Open Maps          ]  | |
| +----------------------------------+ |
+--------------------------------------+
```

Dropdown `[IDR v]` boleh dihapus jika konversi dipindah ke Tools > Konversi Mata Uang.

### 5.2 Book Detail (Collection), dari Library > Collection

**Komponen:** cover, judul, penulis, genre, tombol **Start Reading** > Reading Timer, tombol **Update Progress** > Reading Progress, card Reading Status, card Synopsis, card Your Rating & Review (hanya bisa diisi setelah buku selesai dibaca).

```
+--------------------------------------+
| <  Book Detail                       |
|                                      |
|             +--------+               |
|             | cover  |               |
|             +--------+               |
|            Judul Buku                |
|             Penulis                  |
|        (Genre) (Genre) (Genre)       |
|                                      |
|  [        Start Reading            ] |
|  [        Update Progress          ] |
|                                      |
| +----------------------------------+ |
| | Reading Status                   | |
| | [=====>      ]  62%              | |
| | 186 / 300 pages                  | |
| +----------------------------------+ |
| +----------------------------------+ |
| | Synopsis                         | |
| | Lorem ipsum dolor sit amet...    | |
| | Read More v                      | |
| +----------------------------------+ |
| +----------------------------------+ |
| | Your Rating & Review             | |
| | (*)(*)(*)(*)(*)                  | |
| | Bisa diisi setelah buku selesai  | |
| +----------------------------------+ |
+--------------------------------------+
```

### 5.3 Book Detail (Wishlist), dari Library > Wishlist

**Komponen:** cover, judul, penulis, genre, satu tombol **Add to Collection**, card Synopsis, card Book Price, card Find Nearby Bookstores.

```
+--------------------------------------+
| <  Book Detail                       |
|             +--------+               |
|             | cover  |               |
|             +--------+               |
|            Judul Buku                |
|             Penulis                  |
|        (Genre) (Genre) (Genre)       |
|                                      |
|  [        Add to Collection        ] |
|                                      |
| +----------------------------------+ |
| | Synopsis ...                     | |
| +----------------------------------+ |
| +----------------------------------+ |
| | (tag) Book Price                 | |
| |         {harga}        [IDR v]   | |
| +----------------------------------+ |
| +----------------------------------+ |
| | (pin) Find Nearby Bookstores     | |
| | [        > Open Maps          ]  | |
| +----------------------------------+ |
+--------------------------------------+
```

---

## 6. Reading Flow

### 6.1 Reading Timer

**Komponen:** info buku, stopwatch besar (Fraunces, 48-80 px) sebagai fokus utama, kontrol Reset / Start-Pause-Resume / Add Time, tombol Finish Reading, akses Session Notes dan History.
**Perilaku:** saat Start Reading, buku otomatis menjadi Currently Reading di Home. Finish Reading > Reading Progress.

```
+--------------------------------------+
| <  Reading Timer                     |
|                                      |
|        +------+                      |
|        | cover|  Judul Buku          |
|        +------+  Penulis             |
|                                      |
|             .-----------.            |
|            /             \           |
|           |    00:25:10   |          |
|            \             /           |
|             '-----------'            |
|                                      |
|  (Reset)   [ Pause ]   (+Add Time)   |
|                                      |
|  [         Finish Reading          ] |
|                                      |
|  Session Notes   |   History         |
+--------------------------------------+
```

Tombol tengah berubah: Start > Pause > Resume.

### 6.2 Reading Progress

**Komponen:** info buku, input halaman terakhir dibaca, progress bar, tombol **Save Progress**, tombol **Finished This Book**.
**Perilaku:**
- Save Progress: simpan otomatis, update progress bar, tampilkan feedback sukses.
- Finished This Book: dialog konfirmasi, jika yakin > Finished Book.

```
+--------------------------------------+
| <  Reading Progress                  |
|                                      |
|        +------+                      |
|        | cover|  Judul Buku          |
|        +------+  Penulis             |
|                                      |
|  Halaman terakhir dibaca             |
|  +----------------+                  |
|  | 186            |  dari 300 hal    |
|  +----------------+                  |
|                                      |
|  [=========>          ]  62%         |
|                                      |
|  [         Save Progress           ] |
|  [      Finished This Book         ] |
+--------------------------------------+
```

### 6.2a Dialog konfirmasi

```
+--------------------------------------+
|                                      |
|    +----------------------------+    |
|    | Selesaikan buku ini?       |    |
|    | Status buku akan diubah    |    |
|    | menjadi selesai.           |    |
|    |                            |    |
|    |   [ Batal ]   [ Yakin ]    |    |
|    +----------------------------+    |
|                                      |
+--------------------------------------+
```

### 6.3 Finished Book

Ucapan selamat, status buku diupdate, otomatis kembali ke Home.

```
+--------------------------------------+
|                                      |
|        *   .   *    .   *            |
|            ,-----------.             |
|            |  (buku)   |             |
|            '-----------'             |
|         Yippee, selamat!             |
|    Kamu sudah menyelesaikan          |
|        {Judul Buku}                  |
|                                      |
|  [        Kembali ke Home          ] |
|        (otomatis ke Home)            |
+--------------------------------------+
```

> Reading Timer dan Reading Progress juga bisa diakses dari tombol **Read** dan **Update** pada card Currently Reading di Home.

---

## 7. Tools

| No | Menu | Tujuan |
|----|------|--------|
| 1 | Kesan & Pesan | Form kesan dan pesan mata kuliah PAM |
| 2 | AI Chat | Chat dengan AI seputar buku |
| 3 | Mini Games | Game bertema buku |
| 4 | Konversi Mata Uang | Pengganti dropdown currency di card harga |
| 5 | Konversi Waktu | Konverter zona waktu |

```
+--------------------------------------+
| <  Tools                             |
|                                      |
|  +--------------------------------+  |
|  |        Kesan & Pesan           |  |
|  +--------------------------------+  |
|  +--------------------------------+  |
|  |           AI Chat              |  |
|  +--------------------------------+  |
|  +--------------------------------+  |
|  |         Mini Games             |  |
|  +--------------------------------+  |
|  +--------------------------------+  |
|  |      Konversi Mata Uang        |  |
|  +--------------------------------+  |
|  +--------------------------------+  |
|  |        Konversi Waktu          |  |
|  +--------------------------------+  |
|--------------------------------------|
|  Home  Lib   (+)  Tools  Profil      |
+--------------------------------------+
```

### 7.1 Kesan & Pesan

Form nama, kesan, pesan. Hasil langsung tersimpan dan ditampilkan di bawah form.
**State:** validation error, loading, sukses, empty.

```
+--------------------------------------+
| <  Kesan & Pesan                     |
|                                      |
|  Nama                                |
|  +--------------------------------+  |
|  | Nama kamu                      |  |
|  +--------------------------------+  |
|  Kesan                               |
|  +--------------------------------+  |
|  |                                |  |
|  +--------------------------------+  |
|  Pesan                               |
|  +--------------------------------+  |
|  |                                |  |
|  +--------------------------------+  |
|  [            Kirim                ] |
|                                      |
|  Tersimpan                           |
|  +--------------------------------+  |
|  | {nama}                         |  |
|  | Kesan: {...}                   |  |
|  | Pesan: {...}                   |  |
|  +--------------------------------+  |
+--------------------------------------+
```

### 7.2 AI Chat

**State:** loading (AI mengetik), error jaringan, empty (saran pertanyaan).

```
+--------------------------------------+
| <  AI Chat                           |
|                                      |
|  +----------------------+            |
|  | Halo! Mau cari buku  |            |
|  | apa hari ini?        |            |
|  +----------------------+            |
|                                      |
|            +-------------------+     |
|            | Rekomendasi novel |     |
|            | romance dong      |     |
|            +-------------------+     |
|                                      |
|  +----------------------+            |
|  | ... (mengetik)       |            |
|  +----------------------+            |
|                                      |
|  +---------------------------+ [>]   |
|  | Tulis pesan...            |       |
|  +---------------------------+       |
+--------------------------------------+
```

### 7.3 Mini Games

- **Konsep 1:** Snake, apel diganti buku.
- **Konsep 2 (cadangan):** Roulette Book, satu roda + tombol Putar + hasil buku acak.

```
+--------------------------------------+
| <  Mini Games          Skor: 0       |
|                                      |
|  +--------------------------------+  |
|  |                                |  |
|  |      [][][][]>                 |  |
|  |                       (buku)   |  |
|  |                                |  |
|  |                                |  |
|  +--------------------------------+  |
|                                      |
|             [ ^ ]                    |
|        [ < ]     [ > ]               |
|             [ v ]                    |
|                                      |
|  [           Restart               ] |
+--------------------------------------+
```

### 7.4 Konversi Mata Uang

**State:** loading, error jaringan / offline. Kurs harus dari sumber asli, jangan dikarang.

```
+--------------------------------------+
| <  Konversi Mata Uang                |
|                                      |
|  Dari                                |
|  +--------------------------------+  |
|  | 10000                  [IDR v] |  |
|  +--------------------------------+  |
|            (  tukar  )               |
|  Ke                                  |
|  +--------------------------------+  |
|  | {hasil}                [USD v] |  |
|  +--------------------------------+  |
|                                      |
|  [           Konversi              ] |
|   Kurs per {tanggal}                 |
+--------------------------------------+
```

### 7.5 Konversi Waktu

```
+--------------------------------------+
| <  Konversi Waktu                    |
|                                      |
|  Waktu asal                          |
|  +--------------------------------+  |
|  | 14:30                  [WIB v] |  |
|  +--------------------------------+  |
|            (  tukar  )               |
|  Waktu tujuan                        |
|  +--------------------------------+  |
|  | {hasil}                [WIT v] |  |
|  +--------------------------------+  |
|                                      |
|  [           Konversi              ] |
+--------------------------------------+
```

---

## 8. Profile

**Komponen:** foto profil, nama, ringkasan buku, Edit Profile, toggle login biometrik, notifikasi (pengingat, opsional notifikasi stopwatch), tampilan Light / Dark / Auto (sensor cahaya), Logout.
**Perilaku:** izin biometrik dan notifikasi diminta hanya saat toggle diaktifkan. Logout memakai dialog konfirmasi, lalu menuju Login.

```
+--------------------------------------+
| Profile                              |
|                                      |
|              (  foto  )              |
|             Nama User                |
|        {n} buku | {n} selesai        |
|        [ Edit Profile ]              |
|                                      |
| +----------------------------------+ |
| | Login biometrik          [ o--]  | |
| +----------------------------------+ |
| | Notifikasi pengingat     [ --o]  | |
| | Notifikasi stopwatch     [ o--]  | |
| +----------------------------------+ |
| | Tampilan                         | |
| | (Light) (Dark) (Auto sensor)     | |
| +----------------------------------+ |
|                                      |
|  [            Logout               ] |
|--------------------------------------|
|  Home  Lib   (+)  Tools  Profil      |
+--------------------------------------+
```

### 8.1 Edit Profile

```
+--------------------------------------+
| <  Edit Profile                      |
|                                      |
|              (  foto  )              |
|            Ganti foto                |
|                                      |
|  Nama                                |
|  +--------------------------------+  |
|  | Nama User                      |  |
|  +--------------------------------+  |
|  Email                               |
|  +--------------------------------+  |
|  | nama@email.com        (locked) |  |
|  +--------------------------------+  |
|                                      |
|  [             Simpan              ] |
+--------------------------------------+
```

---

## 9. Komponen Global

### Bottom Navigation

```
+--------------------------------------+
|  (Home)  (Lib)  [ + ]  (Tools)  (Me) |
|   Home   Library  Add   Tools  Profil|
+--------------------------------------+
```

- Active: Deep Teal `#164E59` (+ indikator kecil Soft Apricot `#F5B65D`)
- Inactive: Muted Gray `#859395`
- Tombol tengah (+): Soft Apricot, menonjol
- Sisakan ruang untuk bottom safe area

### Book Card

```
+----------+
| [status] |
|  cover   |   rasio 2:3
|   2:3    |
+----------+
Judul Buku      (Fraunces SemiBold, maks 2 baris)
Penulis         (DM Sans)
```

### Progress Bar

```
[=========>            ]  62%     186 / 300 pages
```

Tinggi 6 px, ujung rounded, fill Deep Teal, track `#E3E7DF`.

---

## 10. Catatan Perilaku Lintas Layar

- **Sensor/hardware:** accelerometer (shake), kamera (scan barcode), lokasi/Maps (nearby bookstore), biometrik, sensor cahaya (auto theme).
- **State wajib tiap layar berbasis data:** initial, loading, success, empty, validation error, network error, disabled.
- **Izin:** minta hanya saat dibutuhkan dan jelaskan tujuannya. Jika izin lokasi ditolak, sediakan pencarian lokasi manual.
- **Cegah duplikasi:** buku yang sudah ada di Collection tidak bisa ditambahkan lagi, tombol langsung berstatus "Added".
- **Data:** jangan pakai mock data seolah nyata. Harga buku, kurs, dan lokasi toko harus dari sumber asli.
- **Aksi destruktif** (Logout, Finished This Book) wajib dikonfirmasi.
- **Dropdown currency di Book Price:** jika sulit, pindahkan ke Tools > Konversi Mata Uang.

---

## 11. Catatan Perbaikan Dokumen Alur

1. Alur 6 poin 2 dan 3 sama-sama menulis "filter Collection". Poin 3 kemungkinan maksudnya filter **Wishlist**.
2. Alur 4 poin 6 menulis "start read" dan "upgrade progress", sedangkan di tempat lain "Read" dan "Update". Di dokumen ini diseragamkan menjadi **Read** dan **Update**.
3. Alur 4 di Add Book menyebut "berdasarkan judul, buku, author". Kemungkinan maksudnya **judul, author, ISBN** (sesuai filter chip).
