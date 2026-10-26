import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyloka/core/services/light_sensor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase R6: Sensor Cahaya Hysteresis & Native Fallback Tests (PRD §10.4)', () {
    late LightSensorService service;

    setUp(() {
      service = LightSensorService.instance;
      service.resetForTesting();
    });

    tearDown(() {
      service.resetForTesting();
    });

    test('1. Moving average 3 detik menghitung rata-rata lux dan mengabaikan sampel usang', () {
      final now = DateTime(2026, 10, 27, 12, 0, 10);
      final samples = [
        // 3 sampel dalam jendela 3 detik (12:00:07 - 12:00:10)
        LuxSample(lux: 5, timestamp: now.subtract(const Duration(seconds: 2))),
        LuxSample(lux: 7, timestamp: now.subtract(const Duration(seconds: 1))),
        LuxSample(lux: 6, timestamp: now),
        // 1 sampel usang (> 3 detik)
        LuxSample(lux: 100, timestamp: now.subtract(const Duration(seconds: 4))),
      ];

      final avg = LightSensorService.calculateAverageLux(samples, now: now);
      // Rata-rata: (5 + 7 + 6) / 3 = 6.0 lux
      expect(avg, equals(6.0));
    });

    test('2. calculateAverageLux mengembalikan -1 jika sampel kosong', () {
      final now = DateTime.now();
      final avg = LightSensorService.calculateAverageLux([], now: now);
      expect(avg, equals(-1.0));
    });

    test('3. evaluateHysteresis: dark < 10, light > 40, buffer 10..40 menjaga kestabilan', () {
      // a. Nilai lux di bawah 10 lux beralih ke Dark
      expect(
        LightSensorService.evaluateHysteresis(
          averageLux: 6.0,
          currentTheme: ThemeMode.light,
        ),
        equals(ThemeMode.dark),
      );

      // b. Nilai lux di atas 40 lux beralih ke Light
      expect(
        LightSensorService.evaluateHysteresis(
          averageLux: 55.0,
          currentTheme: ThemeMode.dark,
        ),
        equals(ThemeMode.light),
      );

      // c. Buffer hysteresis (mis. 25 lux) saat tema sedang Dark -> tetap Dark
      expect(
        LightSensorService.evaluateHysteresis(
          averageLux: 25.0,
          currentTheme: ThemeMode.dark,
        ),
        equals(ThemeMode.dark),
      );

      // d. Buffer hysteresis (mis. 25 lux) saat tema sedang Light -> tetap Light
      expect(
        LightSensorService.evaluateHysteresis(
          averageLux: 25.0,
          currentTheme: ThemeMode.light,
        ),
        equals(ThemeMode.light),
      );
    });

    test('4. processLuxReading dengan data sintetis mematuhi jeda perubahan minimal 5 detik', () {
      final changes = <ThemeMode>[];
      service.startListening(onThemeChanged: (mode) => changes.add(mode));

      final t0 = DateTime(2026, 10, 27, 10, 0, 0);

      // Pembacaan gelap (5 lux) -> trigger ThemeMode.dark
      service.processLuxReading(5, customNow: t0);
      expect(changes, equals([ThemeMode.dark]));

      // Pembacaan terang (60 lux) setelah 2 detik -> tertahan oleh rate limit (harus >= 5 detik)
      final t1 = t0.add(const Duration(seconds: 2));
      service.processLuxReading(60, customNow: t1);
      expect(changes.length, equals(1)); // Belum berubah

      // Pembacaan terang (60 lux) setelah 6 detik -> berhasil berubah ke Light
      final t2 = t0.add(const Duration(seconds: 6));
      service.processLuxReading(60, customNow: t2);
      expect(changes, equals([ThemeMode.dark, ThemeMode.light]));

      service.stopListening();
    });

    test('5. Mode percepatan debug (fastHysteresis = true) mempercepat perubahan tema menjadi 1 detik', () {
      service.fastHysteresis = true;
      expect(service.fastHysteresis, isTrue);

      final changes = <ThemeMode>[];
      service.startListening(onThemeChanged: (mode) => changes.add(mode));

      final t0 = DateTime(2026, 10, 27, 10, 0, 0);

      // 1. Lux gelap (3 lux) -> memicu dark
      service.processLuxReading(3, customNow: t0);
      expect(changes, equals([ThemeMode.dark]));

      // 2. Lux terang (80 lux) setelah 1.5 detik -> karena mode cepat (1 dtk), langsung berubah ke light
      final t1 = t0.add(const Duration(milliseconds: 1500));
      service.processLuxReading(80, customNow: t1);
      expect(changes, equals([ThemeMode.dark, ThemeMode.light]));

      service.stopListening();
    });

    test('6. Teks autoModeDescription menyajikan nilai lux real-time jika sensor tersedia', () {
      service.setSensorAvailableForTesting(true);

      // Saat belum ada data lux
      expect(
        service.autoModeDescription,
        contains('berdasarkan sensor cahaya sekitar'),
      );

      // Berikan data lux 35
      service.processLuxReading(35);
      expect(service.currentLux, isNotNull);
      expect(service.autoModeDescription, equals('Cahaya sekitar: 35 lux'));
    });

    test('7. Fallback saat sensor tidak tersedia: keterangan fallback ke tema sistem', () {
      service.setSensorAvailableForTesting(false);
      expect(service.isSensorAvailable, isFalse);
      expect(
        service.autoModeDescription,
        equals('Sensor cahaya tidak tersedia, mengikuti tema sistem.'),
      );
    });

    test('8. Lifecycle AppLifecycleState handling aman dan mengendalikan stream', () {
      service.startListening(onThemeChanged: (_) {});
      expect(service.isAutoActive, isTrue);

      // Pindah ke background (paused)
      service.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Kembali ke foreground (resumed)
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);

      service.stopListening();
      expect(service.isAutoActive, isFalse);
    });
  });
}
