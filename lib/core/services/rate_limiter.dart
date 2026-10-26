import 'dart:async';

/// Rate limiter sliding window sederhana untuk membatasi frekuensi request,
/// mis. maksimal 3 permintaan per detik untuk Open Library API (Fase R2).
class RateLimiter {
  final int maxRequestsPerSecond;
  final List<DateTime> _history = [];

  RateLimiter({this.maxRequestsPerSecond = 3});

  /// Tunggu sampai slot request tersedia (maksimal [maxRequestsPerSecond] request / detik).
  Future<void> acquire() async {
    while (true) {
      final now = DateTime.now();
      // Buang riwayat request yang lebih lama dari 1 detik
      _history.removeWhere((t) => now.difference(t).inMilliseconds >= 1000);

      if (_history.length < maxRequestsPerSecond) {
        _history.add(now);
        return;
      }

      // Hitung sisa waktu tunggu sampai slot tertua kedaluwarsa
      final oldest = _history.first;
      final waitMs = 1000 - now.difference(oldest).inMilliseconds + 5;
      if (waitMs > 0) {
        await Future.delayed(Duration(milliseconds: waitMs));
      }
    }
  }

  /// Reset riwayat rate limiter (untuk testing).
  void reset() {
    _history.clear();
  }
}
