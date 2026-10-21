/// Model pesan chat — PRD §8.1 (tabel chat_messages, lokal saja).
class ChatMessage {
  final String id;
  final String userId;
  final String role; // 'user' atau 'model'
  final String content;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.userId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  bool get isUser => role == 'user';

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'role': role,
        'content': content,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        role: m['role'] as String,
        content: m['content'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
