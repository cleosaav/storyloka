import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storyloka/core/services/light_sensor_service.dart';
import 'package:storyloka/core/services/notification_service.dart';
import 'package:storyloka/core/services/sensor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase B6: LightSensorService Hysteresis & Moving Average (PRD §10.4)', () {
    test('calculateAverageLux menghitung rata-rata pembacaan dalam jendela 3 detik', () {
      final now = DateTime(2026, 10, 22, 12, 0, 10);
      final samples = [
        // Sampel dalam 3 detik terakhir (12:00:07 - 12:00:10)
        LuxSample(lux: 5, timestamp: now.subtract(const Duration(seconds: 1))),
        LuxSample(lux: 7, timestamp: now.subtract(const Duration(seconds: 2))),
        LuxSample(lux: 6, timestamp: now),
        // Sampel usang (> 3 detik)
        LuxSample(lux: 100, timestamp: now.subtract(const Duration(seconds: 5))),
      ];

      final avg = LightSensorService.calculateAverageLux(samples, now: now);
      // Rata-rata dari (5 + 7 + 6) / 3 = 6.0
      expect(avg, equals(6.0));
    });

    test('calculateAverageLux mengembalikan -1 jika sampel kosong atau seluruhnya usang', () {
      final now = DateTime.now();
      final avg = LightSensorService.calculateAverageLux([], now: now);
      expect(avg, equals(-1.0));
    });

    test('evaluateHysteresis aturan: dark < 10, light > 40, buffer 10..40 pertahankan tema', () {
      // 1. Lux < 10 -> Masuk Dark
      expect(
        LightSensorService.evaluateHysteresis(
          averageLux: 8.0,
          currentTheme: ThemeMode.light,
        ),
        equals(ThemeMode.dark),
      );

      // 2. Lux > 40 -> Kembali Light
      expect(
        LightSensorService.evaluateHysteresis(
          averageLux: 45.0,
          currentTheme: ThemeMode.dark,
        ),
        equals(ThemeMode.light),
      );

      // 3. Buffer Hysteresis (10 <= lux <= 40): Pertahankan Dark jika sebelumnya Dark
      expect(
        LightSensorService.evaluateHysteresis(
          averageLux: 25.0,
          currentTheme: ThemeMode.dark,
        ),
        equals(ThemeMode.dark),
      );

      // 4. Buffer Hysteresis (10 <= lux <= 40): Pertahankan Light jika sebelumnya Light
      expect(
        LightSensorService.evaluateHysteresis(
          averageLux: 25.0,
          currentTheme: ThemeMode.light,
        ),
        equals(ThemeMode.light),
      );
    });

    test('processLuxReading mematuhi rate limit jeda minimal 5 detik antar perubahan tema', () {
      final service = LightSensorService.instance;
      service.resetForTesting();

      final changes = <ThemeMode>[];
      service.startListening(onThemeChanged: (mode) => changes.add(mode));

      final t0 = DateTime(2026, 10, 22, 10, 0, 0);

      // Pembacaan gelap (lux 5) -> memicu Dark
      service.processLuxReading(5, customNow: t0);
      expect(changes, equals([ThemeMode.dark]));

      // Pembacaan terang (lux 50) hanya 2 detik kemudian (belum 5 detik) -> tidak boleh berubah (rate limit)
      final t1 = t0.add(const Duration(seconds: 2));
      service.processLuxReading(50, customNow: t1);
      expect(changes.length, equals(1)); // Tetap hanya 1 kali perubahan

      // Pembacaan terang (lux 50) setelah 6 detik -> berhasil berubah ke Light
      final t2 = t0.add(const Duration(seconds: 6));
      service.processLuxReading(50, customNow: t2);
      expect(changes, equals([ThemeMode.dark, ThemeMode.light]));

      service.stopListening();
    });

    test('autoModeDescription menyajikan teks edukatif saat sensor tidak tersedia', () {
      final service = LightSensorService.instance;
      expect(service.autoModeDescription, isNotEmpty);
    });
  });

  group('Fase B6: NotificationService Preferensi & Siklus Hidup (PRD §10.5)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Inisialisasi NotificationService aman tanpa melempar crash', () async {
      final service = NotificationService.instance;
      await expectLater(service.initialize(), completes);
    });

    test('Menyimpan dan memuat preferensi pengingat membaca harian', () async {
      final service = NotificationService.instance;

      // Default: false
      expect(await service.isReminderEnabled(), isFalse);

      // Set aktif pukul 21:30
      await service.saveReminderSettings(enabled: true, hour: 21, minute: 30);
      expect(await service.isReminderEnabled(), isTrue);
      final time = await service.getReminderTime();
      expect(time.hour, equals(21));
      expect(time.minute, equals(30));

      // Matikan pengingat
      await service.saveReminderSettings(enabled: false, hour: 21, minute: 30);
      expect(await service.isReminderEnabled(), isFalse);
    });

    test('Menyimpan dan memuat preferensi notifikasi stopwatch sesi', () async {
      final service = NotificationService.instance;

      expect(await service.isStopwatchNotifEnabled(), isFalse);
      await service.setStopwatchNotifEnabled(true);
      expect(await service.isStopwatchNotifEnabled(), isTrue);
      await service.setStopwatchNotifEnabled(false);
      expect(await service.isStopwatchNotifEnabled(), isFalse);
    });
  });

  group('Fase B6: SensorService Gyroscope Tilt & Accelerometer (PRD §10.3 & §10.4)', () {
    test('SensorService menyediakan stream shake dan tilt', () {
      final service = SensorService.instance;
      expect(service.shakeStream, isNotNull);
      expect(service.tiltStream, isNotNull);
    });
  });
}
