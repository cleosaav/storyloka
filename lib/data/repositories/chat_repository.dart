import '../models/chat_message.dart';

/// Kontrak AI Chat — PRD §13.0 & Fase S1.
abstract class ChatRepository {
  /// Kirim pesan dan dapatkan balasan.
  /// Mendukung callback [onStatusUpdate] untuk memberi umpan balik UI saat retry/fallback.
  Future<String> sendMessage(
    String message,
    List<ChatMessage> history, {
    void Function(String status)? onStatusUpdate,
  });

  /// Ambil riwayat chat.
  Future<List<ChatMessage>> getHistory();

  /// Simpan pesan ke riwayat lokal.
  Future<void> saveMessage(ChatMessage message);

  /// Hapus semua riwayat chat.
  Future<void> clearHistory();
}
