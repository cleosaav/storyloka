/// Model entri kesan & pesan — PRD §7.7 (tabel feedbacks).
class FeedbackEntry {
  final String id;
  final String userId;
  final String name;
  final String impression;
  final String suggestion;
  final DateTime createdAt;
  final String syncStatus;

  const FeedbackEntry({
    required this.id,
    required this.userId,
    required this.name,
    required this.impression,
    required this.suggestion,
    required this.createdAt,
    this.syncStatus = 'pending',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'impression': impression,
        'suggestion': suggestion,
        'created_at': createdAt.toUtc().toIso8601String(),
        'sync_status': syncStatus,
      };

  factory FeedbackEntry.fromMap(Map<String, dynamic> m) => FeedbackEntry(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        name: m['name'] as String,
        impression: m['impression'] as String,
        suggestion: m['suggestion'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        syncStatus: (m['sync_status'] as String?) ?? 'pending',
      );
}
