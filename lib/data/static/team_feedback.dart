/// Model data kesan & pesan anggota tim pengembang StoryLoka — PRD §7.7 & Fase S7.
class TeamFeedback {
  final String name;
  final String nim;
  final String impression;
  final String suggestion;
  final String? role;

  const TeamFeedback({
    required this.name,
    required this.nim,
    required this.impression,
    required this.suggestion,
    this.role,
  });
}

const List<TeamFeedback> teamFeedbacks = [
  TeamFeedback(
    name: 'Najmah Cleosa',
    nim: '124240104',
    impression:
        'Awalnya mengira aplikasi mobile itu cuma soal membuat tampilan. Ternyata satu aplikasi seperti StoryLoka melibatkan banyak hal sekaligus: database lokal dan online, autentikasi, sensor, notifikasi, sampai AI. Prosesnya melelahkan, tapi puas sekali waktu semua fitur akhirnya jalan di HP sendiri.',
    suggestion:
        'Semoga mata kuliah ini terus memberi ruang untuk proyek utuh dari nol seperti ini, karena belajar dari bug di perangkat nyata jauh lebih membekas daripada hanya membaca teori. Terima kasih kepada dosen dan asisten yang sabar menjawab pertanyaan kami.',
  ),
  TeamFeedback(
    name: 'Melanie Bunga Chintya Pawesty',
    nim: '124240164',
    impression:
        'Paling berkesan itu saat debugging. Sering ada hal yang jalan di emulator tapi error di HP asli. Dari situ kami belajar menguji dengan teliti, membaca log, dan tidak panik. Kerja kelompok juga jadi lebih rapi karena kami membagi tugas dan saling review.',
    suggestion:
        'Mungkin materi tentang manajemen state, sinkronisasi offline-first, dan pengujian bisa diberi porsi lebih banyak, karena itu yang paling terasa di proyek nyata. Secara keseluruhan mata kuliahnya seru dan sangat bermanfaat.',
  ),
  TeamFeedback(
    name: 'Naftali Margareta',
    nim: '124240119',
    impression:
        'Mengerjakan fitur-fitur yang tidak biasa, seperti game Snake, ledger berbasis hash, dan scan barcode, membuat belajar terasa seperti bermain. Dari mata kuliah ini saya jadi lebih percaya diri membuat aplikasi yang bukan sekadar tugas.',
    suggestion:
        'Terima kasih atas tugas akhir yang menantang tapi masuk akal. Saran saya, sediakan lebih banyak sesi konsultasi di pertengahan semester supaya kendala teknis bisa cepat teratasi. Untuk adik tingkat: mulai lebih awal dan sering commit!',
  ),
];
