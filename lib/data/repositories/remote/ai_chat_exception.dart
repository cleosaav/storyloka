import 'dart:io';

/// Exception terpadu untuk kesalahan pada provider AI Chat — Fase S1.
class AiChatException implements Exception {
  final String message;
  final int? statusCode;
  final Duration? retryAfter;
  final bool isTimeout;
  final bool isSocket;
  final String providerName;

  AiChatException(
    this.message, {
    this.statusCode,
    this.retryAfter,
    this.isTimeout = false,
    this.isSocket = false,
    this.providerName = '',
  });

  /// Error konfigurasi, autentikasi, atau saldo habis (layak skip 10 menit).
  bool get isAuthConfigOrBalance =>
      statusCode == 400 ||
      statusCode == 401 ||
      statusCode == 403 ||
      statusCode == 404 ||
      statusCode == 402;

  /// Error sementara yang layak di-retry (maksimal 3 kali dengan backoff).
  bool get isTransient =>
      isTimeout ||
      isSocket ||
      statusCode == 429 ||
      statusCode == 500 ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 504;

  @override
  String toString() => message;
}

/// Helper parsing header Retry-After (bisa berupa detik integer atau HTTP-Date).
Duration? parseRetryAfter(String? headerVal) {
  if (headerVal == null || headerVal.trim().isEmpty) return null;
  final trimmed = headerVal.trim();
  final seconds = int.tryParse(trimmed);
  if (seconds != null && seconds > 0) {
    return Duration(seconds: seconds);
  }
  try {
    final httpDate = HttpDate.parse(trimmed);
    final diff = httpDate.difference(DateTime.now());
    if (diff > Duration.zero) return diff;
  } catch (_) {}
  return null;
}
