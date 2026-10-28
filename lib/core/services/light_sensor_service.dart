import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sampel nilai sensor lux dengan catatan waktu.
class LuxSample {
  final int lux;
  final DateTime timestamp;

  const LuxSample({required this.lux, required this.timestamp});
}

/// Service sensor cahaya untuk penyesuaian tema otomatis — PRD §10.4.
/// Menggunakan EventChannel native "storyloka/light" (Sensor.TYPE_LIGHT)
/// tanpa dependensi paket pihak ketiga, menerapkan moving average 3 detik
/// dan hysteresis (dark < 10, light > 40) dengan jeda minimal perubahan 5 detik.
class LightSensorService extends ChangeNotifier with WidgetsBindingObserver {
  LightSensorService._() {
    _initLifecycleObserver();
  }
  static final LightSensorService instance = LightSensorService._();

  static const EventChannel _eventChannel = EventChannel('storyloka/light');
  static const MethodChannel _methodChannel = MethodChannel('storyloka/light_status');

  StreamSubscription? _subscription;
  final List<LuxSample> _samples = [];
  DateTime _lastThemeChangeTime = DateTime(2000);
  ThemeMode? _currentTheme;
  void Function(ThemeMode)? _onThemeChanged;

  bool _isSensorAvailable = true;
  double? _currentLux;
  bool _isAutoActive = false;
  bool _fastHysteresis = false;
  bool _isObserverRegistered = false;

  bool get isSensorAvailable => _isSensorAvailable;
  double? get currentLux => _currentLux;
  bool get isAutoActive => _isAutoActive;

  /// Mode percepatan hysteresis untuk keperluan pengujian QA / debug.
  bool get fastHysteresis => _fastHysteresis;
  set fastHysteresis(bool value) {
    if (_fastHysteresis != value) {
      _fastHysteresis = value;
      notifyListeners();
    }
  }

  void _initLifecycleObserver() {
    if (!_isObserverRegistered) {
      try {
        WidgetsBinding.instance.addObserver(this);
        _isObserverRegistered = true;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[LightSensorService] Gagal mendaftarkan observer: $e');
        }
      }
    }
  }

  /// Keterangan status untuk ditampilkan di UI Profile (PRD §10.4).
  String get autoModeDescription {
    if (!_isSensorAvailable) {
      return 'Sensor cahaya tidak tersedia, mengikuti tema sistem.';
    }
    if (_currentLux != null) {
      return 'Cahaya sekitar: ${_currentLux!.toStringAsFixed(0)} lux';
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

  /// Cek ketersediaan sensor cahaya fisik via MethodChannel.
  Future<bool> checkSensorAvailability() async {
    if (kIsWeb) {
      _isSensorAvailable = false;
      notifyListeners();
      return false;
    }

    try {
      final available =
          await _methodChannel.invokeMethod<bool>('isSensorAvailable');
      _isSensorAvailable = available ?? false;
    } catch (_) {
      // Jika platform channel belum siap / mock runner
      _isSensorAvailable = false;
    }
    notifyListeners();
    return _isSensorAvailable;
  }

  /// Mulai memantau sensor cahaya saat pengguna memilih mode Auto (dan app di foreground).
  Future<void> startListening({
    required void Function(ThemeMode) onThemeChanged,
  }) async {
    _onThemeChanged = onThemeChanged;
    _isAutoActive = true;
    _initLifecycleObserver();

    final available = await checkSensorAvailability();
    if (!available) {
      // Fallback ke tema sistem jika sensor tidak ada (PRD §10.4)
      _onThemeChanged?.call(ThemeMode.system);
      notifyListeners();
      return;
    }

    _startNativeStream();
  }

  void _startNativeStream() {
    if (kIsWeb || !_isAutoActive) return;

    _subscription?.cancel();
    try {
      _subscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is num) {
            processLuxReading(event.toDouble());
          }
        },
        onError: (dynamic error) {
          debugPrint('[LightSensorService] Stream sensor cahaya gagal: $error');
          _isSensorAvailable = false;
          _onThemeChanged?.call(ThemeMode.system);
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('[LightSensorService] Gagal menghubungkan EventChannel: $e');
      _isSensorAvailable = false;
      _onThemeChanged?.call(ThemeMode.system);
      notifyListeners();
    }
  }

  void _stopNativeStream() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Hentikan pemantauan sensor cahaya saat mode Auto tidak aktif.
  void stopListening() {
    _isAutoActive = false;
    _stopNativeStream();
    _samples.clear();
    _currentLux = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isAutoActive) return;

    // Mulai mendengarkan hanya saat app di foreground, berhenti saat di background
    if (state == AppLifecycleState.resumed) {
      _startNativeStream();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _stopNativeStream();
    }
  }

  /// Memproses pembacaan lux dan menerapkan moving average + hysteresis + rate limit.
  void processLuxReading(num luxValue, {DateTime? customNow}) {
    final now = customNow ?? DateTime.now();
    final luxInt = luxValue.round();
    _samples.add(LuxSample(lux: luxInt, timestamp: now));

    final window = _fastHysteresis
        ? const Duration(seconds: 1)
        : const Duration(seconds: 3);
    final minChangeInterval = _fastHysteresis
        ? const Duration(seconds: 1)
        : const Duration(seconds: 5);

    // Bersihkan sampel yang lebih tua dari durasi jendela moving average
    _samples.removeWhere((s) => now.difference(s.timestamp) > window);

    final avgLux = calculateAverageLux(_samples, now: now, window: window);
    _currentLux = avgLux >= 0 ? avgLux : luxValue.toDouble();

    final targetTheme = evaluateHysteresis(
      averageLux: avgLux,
      currentTheme: _currentTheme,
    );

    if (targetTheme != null && targetTheme != _currentTheme) {
      // Ubah tema paling cepat setiap 5 detik (atau 1 detik di debug)
      if (now.difference(_lastThemeChangeTime) >= minChangeInterval) {
        _lastThemeChangeTime = now;
        _currentTheme = targetTheme;
        _onThemeChanged?.call(targetTheme);
      }
    }

    notifyListeners();
  }

  @visibleForTesting
  void setSensorAvailableForTesting(bool available) {
    _isSensorAvailable = available;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    stopListening();
    _lastThemeChangeTime = DateTime(2000);
    _currentTheme = null;
    _isSensorAvailable = true;
    _currentLux = null;
    _fastHysteresis = false;
  }

  @override
  void dispose() {
    if (_isObserverRegistered) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[LightSensorService] Gagal menghapus observer: $e');
        }
      }
      _isObserverRegistered = false;
    }
    _subscription?.cancel();
    super.dispose();
  }
}
