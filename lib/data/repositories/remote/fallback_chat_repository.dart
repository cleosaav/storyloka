import 'package:flutter/foundation.dart';

import '../../models/chat_message.dart';
import '../chat_repository.dart';
import 'deepseek_chat_repository.dart';
import 'gemini_chat_repository.dart';

/// Repository AI Chat dengan strategi Primary → Fallback — Fase R4.
///
/// Strategi:
/// 1. Coba kirim pesan ke [primary] (DeepSeek).
/// 2. Jika primary gagal karena masalah jaringan, timeout, atau error server (5xx/429),
///    otomatis fallback ke [fallback] (Gemini) dan catat di debug log.
/// 3. Error autentikasi (401/403) dan konfigurasi (400/404) dari primary TIDAK
///    difallback — langsung dilempar ke UI agar pengguna tahu kuncinya bermasalah.
/// 4. Operasi storage (getHistory, saveMessage, clearHistory) selalu delegasi ke
///    [primary] karena keduanya berbagi DatabaseHelper yang sama.
class FallbackChatRepository implements ChatRepository {
  final ChatRepository primary;
  final ChatRepository fallback;

  const FallbackChatRepository({
    required this.primary,
    required this.fallback,
  });

  /// Apakah exception ini layak untuk di-fallback ke provider lain?
  /// Fallback hanya untuk kegagalan jaringan/server, bukan konfigurasi/auth error.
  bool _isFallbackWorthy(Object e) {
    if (e is DeepSeekChatException) {
      final code = e.statusCode;
      // Fallback: timeout (null), server error (5xx), rate limit (429), saldo habis (402)
      // Tidak fallback: auth error (401/403), config error (400/404)
      if (code == null) return true; // TimeoutException / SocketException
      if (code == 402 || code == 429 || (code >= 500 && code < 600)) return true;
      return false;
    }
    if (e is GeminiChatException) {
      final code = e.statusCode;
      if (code == null) return true;
      if (code == 429 || (code >= 500 && code < 600)) return true;
      return false;
    }
    // Exception tidak dikenali (jaringan, dll) — layak fallback
    return true;
  }

  @override
  Future<String> sendMessage(String message, List<ChatMessage> history) async {
    try {
      final result = await primary.sendMessage(message, history);
      return result;
    } catch (primaryError) {
      if (_isFallbackWorthy(primaryError)) {
        if (kDebugMode) {
          debugPrint(
            '[FallbackChat] Primary (${primary.runtimeType}) gagal: $primaryError. '
            'Beralih ke fallback (${fallback.runtimeType})...',
          );
        }
        // Fallback ke Gemini — biarkan error dari fallback naik ke UI jika juga gagal
        return await fallback.sendMessage(message, history);
      }
      // Error konfigurasi/auth — lempar langsung ke UI
      rethrow;
    }
  }

  @override
  Future<List<ChatMessage>> getHistory() => primary.getHistory();

  @override
  Future<void> saveMessage(ChatMessage message) => primary.saveMessage(message);

  @override
  Future<void> clearHistory() => primary.clearHistory();
}
