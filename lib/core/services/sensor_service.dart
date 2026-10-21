import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/services.dart';

/// Service sensor accelerometer — PRD §10.3.
/// Menyediakan [shakeStream] yang memancarkan event saat perangkat diguncang.
/// Langganan hanya saat halaman Add Book aktif (sesuai PRD §10.3).
class SensorService {
  SensorService._();
  static final SensorService instance = SensorService._();

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  final StreamController<void> _shakeController =
      StreamController<void>.broadcast();
  DateTime _lastShakeTime = DateTime(2000);

  /// Threshold magnitudo: sqrt(x²+y²+z²) > 25 m/s² — PRD §7.3.
  static const double _shakeThreshold = 25.0;

  /// Debounce 1.5 detik antar shake — PRD §7.3.
  static const Duration _shakeCooldown = Duration(milliseconds: 1500);

  /// Stream yang memancarkan event shake.
  Stream<void> get shakeStream => _shakeController.stream;

  /// Mulai mendengarkan sensor accelerometer.
  void startListening() {
    if (_subscription != null) return; // Sudah aktif
    try {
      _subscription = userAccelerometerEventStream().listen((event) {
        final magnitude =
            sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        final now = DateTime.now();
        if (magnitude > _shakeThreshold &&
            now.difference(_lastShakeTime) > _shakeCooldown) {
          _lastShakeTime = now;
          // Getaran haptic singkat — PRD §7.3
          HapticFeedback.mediumImpact();
          _shakeController.add(null);
        }
      });
    } catch (_) {
      // Sensor tidak tersedia (desktop/emulator) — diam saja
    }
  }

  /// Hentikan pendengaran sensor (saat keluar halaman Add Book).
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Bersihkan resource.
  void dispose() {
    stopListening();
    _shakeController.close();
  }
}
