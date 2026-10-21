# AGENTS.md — StoryLoka

## Sumber kebenaran
- docs/spec/prd-storyloka.md = sumber utama (alur, aturan, fase). Jangan ubah alur.
- docs/spec/design-system.md = sumber visual. Jika wireframe berbeda, ikuti design system.
- docs/spec/wireframe.md = struktur layar dan urutan elemen saja.

## Aturan kerja
- Kerjakan hanya fase yang diminta di prompt. Jangan lompat ke fase berikutnya.
- Baca hanya bagian PRD yang relevan: Bagian 0, 4, 5, 8, dan bagian fase yang dikerjakan.
- Tanpa Firebase dan tanpa supabase.auth. Tanpa secret di kode; semua key dari .env.
- Widget tidak boleh memanggil http/sqflite/supabase langsung; lewat abstract repository.
- Semua warna, spacing, radius lewat konstanta tema, bukan angka mentah di widget.
- Setiap layar berbasis data punya state loading, empty, error (+retry), success.
- Setelah tiap fase: jalankan `flutter analyze` dan tes terkait, perbaiki sampai bersih,
  lalu perbarui docs/PROGRESS.md. Catat penyimpangan di docs/DEVIATIONS.md.
- Jika ambigu, ambil keputusan paling sederhana yang konsisten dengan PRD dan catat.
- Balas dengan bahasa Indonesia, ringkas.