import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storyloka/core/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fase R4: Logika Penjadwalan Notifikasi (nextInstanceOfTime) — PRD §10.5', () {
    final location = tz.getLocation('Asia/Jakarta');

    test('1. Jika jam target belum lewat hari ini, dijadwalkan pada hari ini', () {
      // Sekarang: 27 Oktober 2026, 09:15
      final now = tz.TZDateTime(location, 2026, 10, 27, 9, 15);
      // Target pengingat: 20:00
      final scheduled = NotificationService.nextInstanceOfTime(20, 0, now: now);

      expect(scheduled.year, equals(2026));
      expect(scheduled.month, equals(10));
      expect(scheduled.day, equals(27)); // Hari yang sama
      expect(scheduled.hour, equals(20));
      expect(scheduled.minute, equals(0));
      expect(scheduled.isAfter(now), isTrue);
    });

    test('2. Jika jam target sudah lewat hari ini, dijadwalkan untuk hari esok', () {
      // Sekarang: 27 Oktober 2026, 21:30
      final now = tz.TZDateTime(location, 2026, 10, 27, 21, 30);
      // Target pengingat: 20:00 (sudah lewat 1.5 jam yang lalu)
      final scheduled = NotificationService.nextInstanceOfTime(20, 0, now: now);

      expect(scheduled.year, equals(2026));
      expect(scheduled.month, equals(10));
      expect(scheduled.day, equals(28)); // Hari esok
      expect(scheduled.hour, equals(20));
      expect(scheduled.minute, equals(0));
      expect(scheduled.isAfter(now), isTrue);
    });

    test('3. Jika jam target sama persis dengan waktu sekarang, dijadwalkan untuk hari esok', () {
      // Sekarang: 27 Oktober 2026, 20:00:00
      final now = tz.TZDateTime(location, 2026, 10, 27, 20, 0);
      final scheduled = NotificationService.nextInstanceOfTime(20, 0, now: now);

      expect(scheduled.year, equals(2026));
      expect(scheduled.month, equals(10));
      expect(scheduled.day, equals(28));
      expect(scheduled.hour, equals(20));
      expect(scheduled.minute, equals(0));
    });

    test('4. Rollover pada akhir bulan: 31 Oktober pukul 22:00 -> 1 November', () {
      final now = tz.TZDateTime(location, 2026, 10, 31, 22, 0);
      final scheduled = NotificationService.nextInstanceOfTime(20, 0, now: now);

      expect(scheduled.year, equals(2026));
      expect(scheduled.month, equals(11)); // November
      expect(scheduled.day, equals(1)); // Tanggal 1
      expect(scheduled.hour, equals(20));
      expect(scheduled.minute, equals(0));
    });

    test('5. Rollover pada akhir tahun: 31 Desember pukul 23:00 -> 1 Januari tahun berikutnya', () {
      final now = tz.TZDateTime(location, 2026, 12, 31, 23, 0);
      final scheduled = NotificationService.nextInstanceOfTime(20, 0, now: now);

      expect(scheduled.year, equals(2027)); // Tahun baru
      expect(scheduled.month, equals(1)); // Januari
      expect(scheduled.day, equals(1)); // Tanggal 1
      expect(scheduled.hour, equals(20));
      expect(scheduled.minute, equals(0));
    });
  });

  group('Fase R4: Helper & Preferensi NotificationService', () {
    test('6. formatDuration menghasilkan format HH:mm:ss yang benar', () {
      expect(NotificationService.formatDuration(Duration.zero), equals('00:00:00'));
      expect(
        NotificationService.formatDuration(const Duration(minutes: 5, seconds: 42)),
        equals('00:05:42'),
      );
      expect(
        NotificationService.formatDuration(const Duration(hours: 2, minutes: 15, seconds: 9)),
        equals('02:15:09'),
      );
    });

    test('7. Penyimpanan dan pemuatan preferensi pengingat membaca', () async {
      final service = NotificationService.instance;

      expect(await service.isReminderEnabled(), isFalse);
      final defaultTime = await service.getReminderTime();
      expect(defaultTime.hour, equals(20));
      expect(defaultTime.minute, equals(0));

      await service.saveReminderSettings(enabled: true, hour: 19, minute: 45);
      expect(await service.isReminderEnabled(), isTrue);
      final savedTime = await service.getReminderTime();
      expect(savedTime.hour, equals(19));
      expect(savedTime.minute, equals(45));

      await service.saveReminderSettings(enabled: false, hour: 19, minute: 45);
      expect(await service.isReminderEnabled(), isFalse);
    });

    test('8. Penyimpanan dan pemuatan preferensi stopwatch membaca', () async {
      final service = NotificationService.instance;

      expect(await service.isStopwatchNotifEnabled(), isFalse);
      await service.setStopwatchNotifEnabled(true);
      expect(await service.isStopwatchNotifEnabled(), isTrue);
      await service.setStopwatchNotifEnabled(false);
      expect(await service.isStopwatchNotifEnabled(), isFalse);
    });

    test('9. Inisialisasi NotificationService aman dan menetapkan zona waktu', () async {
      final service = NotificationService.instance;
      await expectLater(service.initialize(), completes);
      expect(service.currentTimezone, isNotEmpty);
    });
  });
}
