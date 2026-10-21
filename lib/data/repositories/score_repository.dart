import '../models/game_score.dart';

/// Kontrak skor game — PRD §13.0.
abstract class ScoreRepository {
  /// Ambil semua skor untuk game tertentu.
  Future<List<GameScore>> getScores(String game);

  /// Simpan skor baru.
  Future<void> saveScore(GameScore score);

  /// Skor tertinggi untuk game tertentu.
  Future<int> getHighScore(String game);
}
