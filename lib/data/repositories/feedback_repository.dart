import '../static/team_feedback.dart';

/// Kontrak kesan & pesan — PRD §7.7 & Fase S7 (BACA SAJA / Read-Only).
///
/// Disederhanakan menjadi read-only: hanya menyediakan getAll() untuk
/// membaca kesan dan pesan tetap dari anggota tim pengembang.
abstract class FeedbackRepository {
  /// Ambil semua kesan & pesan dari tim.
  Future<List<TeamFeedback>> getAll();
}

/// Implementasi FeedbackRepository membaca list konstan teamFeedbacks.
class TeamFeedbackRepository implements FeedbackRepository {
  const TeamFeedbackRepository();

  @override
  Future<List<TeamFeedback>> getAll() async {
    return teamFeedbacks;
  }
}
