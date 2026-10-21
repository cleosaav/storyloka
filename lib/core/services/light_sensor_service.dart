import 'dart:async';

import 'package:flutter/material.dart';

/// Sampel nilai sensor lux dengan catatan waktu.
class LuxSample {
  final int lux;
  final DateTime timestamp;

  const LuxSample({required this.lux, required this.timestamp});
}

/// Service sensor cahaya untuk penyesuaian tema otomatis — PRD §10.4.
/// Menerapkan moving average 3 detik dan hysteresis (dark < 10, light > 40)
/// dengan jeda perubahan minimal 5 detik.
class LightSensorService {
  LightSensorService._();
  static final LightSensorService instance = LightSensorService._();

  StreamSubscription<int>? _subscription;
  final List<LuxSample> _samples = [];
  DateTime _lastThemeChangeTime = DateTime(2000);
  ThemeMode? _currentTheme;
  void Function(ThemeMode)? _onThemeChanged;

  bool _isSensorAvailable = true;

  bool get isSensorAvailable => _isSensorAvailable;

  /// Keterangan status untuk ditampilkan di UI Profile (PRD §10.4).
  String get autoModeDescription {
    if (!_isSensorAvailable) {
      return 'Sensor cahaya tidak tersedia, mengikuti tema sistem.';
    }
    return 'Auto: Menyesuaikan tema terang/gelap berdasarkan sensor cahaya sekitar.';
  }

  /// Menghitung rata-rata lux dari sampel dalam jendela durasi tertentu (fungsi murni).
  static double calculateAverageLux(
    List<LuxSample> samples, {
    required DateTime now,
    Duration window = const Duration(seconds: 3),
  }) {
    final recent = samples
        .where((s) => now.difference(s.timestamp) <= window)
        .toList();
    if (recent.isEmpty) return -1;
    final total = recent.fold<int>(0, (sum, s) => sum + s.lux);
    return total / recent.length;
  }

  /// Mengevaluasi tema baru berdasarkan aturan hysteresis PRD §10.4:
  /// - masuk dark jika lux < 10
  /// - kembali light jika lux > 40
  /// - di antara 10 dan 40: pertahankan tema saat ini
  static ThemeMode? evaluateHysteresis({
    required double averageLux,
    required ThemeMode? currentTheme,
  }) {
    if (averageLux < 0) return currentTheme;

    if (averageLux < 10) {
      return ThemeMode.dark;
    } else if (averageLux > 40) {
      return ThemeMode.light;
    }
    // Hysteresis buffer (10 - 40): pertahankan tema
    return currentTheme;
  }

  /// Mulai memantau sensor cahaya saat pengguna memilih mode Auto.
  Future<void> startListening({
    required void Function(ThemeMode) onThemeChanged,
  }) async {
    _onThemeChanged = onThemeChanged;
    // Sesuai PRD §10.4 & DEVIATIONS.md: paket sensor cahaya di pub.dev (light_sensor)
    // bermasalah dengan Gradle 9 (jcenter removal), sehingga otomatis fallback
    // ke tema sistem dan sensor kedua dialihkan ke Gyroscope (Tilt Control Snake).
    _isSensorAvailable = false;
  }

  /// Memproses pembacaan lux dan menerapkan moving average + hysteresis + rate limit.
  void processLuxReading(int lux, {DateTime? customNow}) {
    final now = customNow ?? DateTime.now();
    _samples.add(LuxSample(lux: lux, timestamp: now));

    // Bersihkan sampel yang lebih tua dari 3 detik
    _samples.removeWhere(
      (s) => now.difference(s.timestamp) > const Duration(seconds: 3),
    );

    final avgLux = calculateAverageLux(_samples, now: now);
    final targetTheme = evaluateHysteresis(
      averageLux: avgLux,
      currentTheme: _currentTheme,
    );

    if (targetTheme != null && targetTheme != _currentTheme) {
      // Ubah tema paling cepat setiap 5 detik (PRD §10.4)
      if (now.difference(_lastThemeChangeTime) >= const Duration(seconds: 5)) {
        _lastThemeChangeTime = now;
        _currentTheme = targetTheme;
        _onThemeChanged?.call(targetTheme);
      }
    }
  }

  /// Hentikan pemantauan sensor cahaya saat mode Auto tidak aktif.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _samples.clear();
  }

  @visibleForTesting
  void resetForTesting() {
    stopListening();
    _lastThemeChangeTime = DateTime(2000);
    _currentTheme = null;
    _isSensorAvailable = true;
  }
}
