import '../models/feedback_entry.dart';

/// Kontrak kesan & pesan — PRD §13.0.
abstract class FeedbackRepository {
  /// Ambil semua kesan & pesan milik pengguna.
  Future<List<FeedbackEntry>> getAll();

  /// Simpan kesan & pesan baru.
  Future<void> save(FeedbackEntry entry);
}
