import '../models/reading_session.dart';

/// Kontrak sesi membaca — PRD §13.0.
abstract class ReadingRepository {
  /// Simpan sesi membaca.
  Future<void> saveSession(ReadingSession session);

  /// Ambil semua sesi untuk satu buku.
  Future<List<ReadingSession>> getSessionsForBook(String userBookId);

  /// Ambil semua sesi milik pengguna.
  Future<List<ReadingSession>> getAllSessions();

  /// Total durasi membaca (detik) untuk semua buku.
  Future<int> getTotalReadingSeconds();
}
