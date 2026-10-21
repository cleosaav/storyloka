import '../models/chat_message.dart';

/// Kontrak AI Chat — PRD §13.0.
abstract class ChatRepository {
  /// Kirim pesan dan dapatkan balasan.
  Future<String> sendMessage(String message, List<ChatMessage> history);

  /// Ambil riwayat chat.
  Future<List<ChatMessage>> getHistory();

  /// Simpan pesan ke riwayat lokal.
  Future<void> saveMessage(ChatMessage message);

  /// Hapus semua riwayat chat.
  Future<void> clearHistory();
}
