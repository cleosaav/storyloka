import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../features/tools/snake/snake_engine.dart';

/// Service sensor accelerometer (PRD §10.3) dan gyroscope tilt (PRD §10.4).
/// - Menyediakan [shakeStream] untuk Shake to Discover di Add Book.
/// - Menyediakan [tiltStream] untuk Tilt Control di game Book Snake.
class SensorService {
  SensorService._();
  static final SensorService instance = SensorService._();

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  final StreamController<void> _shakeController =
      StreamController<void>.broadcast();
  DateTime _lastShakeTime = DateTime(2000);

  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  final StreamController<SnakeDirection> _tiltController =
      StreamController<SnakeDirection>.broadcast();
  DateTime _lastTiltTime = DateTime(2000);

  /// Threshold magnitudo shake: sqrt(x²+y²+z²) > 25 m/s² — PRD §7.3.
  static const double _shakeThreshold = 25.0;

  /// Debounce 1.5 detik antar shake — PRD §7.3.
  static const Duration _shakeCooldown = Duration(milliseconds: 1500);

  /// Threshold kecepatan rotasi gyroscope (rad/s) untuk tilt control — PRD §10.4.
  static const double _tiltThreshold = 1.2;
  static const Duration _tiltCooldown = Duration(milliseconds: 300);

  /// Stream yang memancarkan event shake.
  Stream<void> get shakeStream => _shakeController.stream;

  /// Stream yang memancarkan arah tilt dari gyroscope.
  Stream<SnakeDirection> get tiltStream => _tiltController.stream;

  /// Mulai mendengarkan sensor accelerometer untuk shake.
  void startListening() {
    if (_subscription != null) return;
    try {
      _subscription = userAccelerometerEventStream().listen(
        (event) {
          final magnitude =
              sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          final now = DateTime.now();
          if (magnitude > _shakeThreshold &&
              now.difference(_lastShakeTime) > _shakeCooldown) {
            _lastShakeTime = now;
            HapticFeedback.mediumImpact();
            _shakeController.add(null);
          }
        },
        onError: (_) {},
      );
    } catch (_) {
      // Sensor tidak tersedia (desktop/emulator) — diam saja
    }
  }

  /// Hentikan pendengaran sensor accelerometer.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Mulai mendengarkan sensor gyroscope untuk tilt control Snake — PRD §10.4.
  void startTiltListening({void Function(SnakeDirection)? onDirection}) {
    if (_gyroSubscription != null) return;
    try {
      _gyroSubscription = gyroscopeEventStream().listen((event) {
        final now = DateTime.now();
        if (now.difference(_lastTiltTime) < _tiltCooldown) return;

        SnakeDirection? detected;
        // Sumbu X: rotasi maju/mundur (atas / bawah)
        if (event.x < -_tiltThreshold) {
          detected = SnakeDirection.up;
        } else if (event.x > _tiltThreshold) {
          detected = SnakeDirection.down;
        }
        // Sumbu Y & Z: rotasi miring kiri/kanan
        else if (event.y < -_tiltThreshold || event.z > _tiltThreshold) {
          detected = SnakeDirection.left;
        } else if (event.y > _tiltThreshold || event.z < -_tiltThreshold) {
          detected = SnakeDirection.right;
        }

        if (detected != null) {
          _lastTiltTime = now;
          HapticFeedback.selectionClick();
          _tiltController.add(detected);
          onDirection?.call(detected);
        }
      }, onError: (_) {});
    } catch (_) {
      // Gyroscope tidak tersedia — diam saja
    }
  }

  /// Hentikan pendengaran sensor gyroscope.
  void stopTiltListening() {
    _gyroSubscription?.cancel();
    _gyroSubscription = null;
  }

  /// Bersihkan semua resource sensor.
  void dispose() {
    stopListening();
    stopTiltListening();
    _shakeController.close();
    _tiltController.close();
  }
}
