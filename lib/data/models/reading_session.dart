/// Model sesi membaca — PRD §8.1 (tabel reading_sessions).
class ReadingSession {
  final String id;
  final String userId;
  final String userBookId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final DateTime createdAt;
  final String syncStatus;

  const ReadingSession({
    required this.id,
    required this.userId,
    required this.userBookId,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.createdAt,
    this.syncStatus = 'pending',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'user_book_id': userBookId,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
        'duration_seconds': durationSeconds,
        'created_at': createdAt.toUtc().toIso8601String(),
        'sync_status': syncStatus,
      };

  factory ReadingSession.fromMap(Map<String, dynamic> m) => ReadingSession(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        userBookId: m['user_book_id'] as String,
        startedAt: DateTime.parse(m['started_at'] as String),
        endedAt: DateTime.parse(m['ended_at'] as String),
        durationSeconds: m['duration_seconds'] as int,
        createdAt: DateTime.parse(m['created_at'] as String),
        syncStatus: (m['sync_status'] as String?) ?? 'pending',
      );
}
