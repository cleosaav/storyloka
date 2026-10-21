/// Model skor game — PRD §8.1 (tabel game_scores).
class GameScore {
  final String id;
  final String userId;
  final String game;
  final int score;
  final DateTime playedAt;
  final String syncStatus;

  const GameScore({
    required this.id,
    required this.userId,
    required this.game,
    required this.score,
    required this.playedAt,
    this.syncStatus = 'pending',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'game': game,
        'score': score,
        'played_at': playedAt.toUtc().toIso8601String(),
        'sync_status': syncStatus,
      };

  factory GameScore.fromMap(Map<String, dynamic> m) => GameScore(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        game: m['game'] as String,
        score: m['score'] as int,
        playedAt: DateTime.parse(m['played_at'] as String),
        syncStatus: (m['sync_status'] as String?) ?? 'pending',
      );
}
