import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Service pengelola notifikasi lokal StoryLoka — PRD §10.5 & Bagian 12.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  @visibleForTesting
  set plugin(FlutterLocalNotificationsPlugin p) => _plugin = p;

  bool _isInitialized = false;
  bool _pluginAvailable = false;
  String _currentTimezone = 'UTC';

  String get currentTimezone => _currentTimezone;

  static const int _reminderNotificationId = 1001;
  static const int _stopwatchNotificationId = 1002;
  static const int _testInstantNotificationId = 9999;
  static const int _testScheduledNotificationId = 9998;

  static const String _channelReminderId = 'reading_reminder_v2';
  static const String _channelReminderName = 'Pengingat Membaca';
  static const String _channelReminderDesc = 'Notifikasi jadwal membaca harian';

  static const String _channelTimerId = 'reading_timer';
  static const String _channelTimerName = 'Stopwatch Membaca';
  static const String _channelTimerDesc = 'Notifikasi sesi membaca berlangsung';

  static const String _keyReminderEnabled = 'pref_reading_reminder_enabled';
  static const String _keyReminderHour = 'pref_reading_reminder_hour';
  static const String _keyReminderMinute = 'pref_reading_reminder_minute';
  static const String _keyStopwatchNotif = 'pref_stopwatch_notif_enabled';

  /// Inisialisasi plugin notifikasi dan pembuatan channels Android secara eksplisit.
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _isInitialized = true;
      _pluginAvailable = false;
      return;
    }

    try {
      tz_data.initializeTimeZones();
      String detectedTz = 'Asia/Jakarta';
      try {
        if (!kIsWeb) {
          final tzInfo = await FlutterTimezone.getLocalTimezone();
          detectedTz = tzInfo.identifier;
        }
      } catch (e) {
        debugPrint('[NotificationService] Gagal mendeteksi zona waktu sistem ($e), menggunakan fallback $detectedTz');
      }

      try {
        tz.setLocalLocation(tz.getLocation(detectedTz));
        _currentTimezone = detectedTz;
        debugPrint('[NotificationService] Local timezone diatur ke: $_currentTimezone');
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
        _currentTimezone = 'Asia/Jakarta';
        debugPrint('[NotificationService] Fallback timezone diatur ke: $_currentTimezone');
      }
    } catch (e) {
      debugPrint('[NotificationService] Inisialisasi timezone gagal: $e');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          // Ketika notifikasi diklik, aplikasi diarahkan ke Home
        },
      );

      // Buat Android notification channels secara eksplisit
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // Channel Pengingat (Importance.max agar muncul heads-up pop-up banner & suara)
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelReminderId,
            _channelReminderName,
            description: _channelReminderDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
          ),
        );

        // Channel Stopwatch Timer (Importance.low agar ongoing tanpa suara/getar)
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelTimerId,
            _channelTimerName,
            description: _channelTimerDesc,
            importance: Importance.low,
            enableVibration: false,
            playSound: false,
            showBadge: false,
          ),
        );
      }
      _isInitialized = true;
      _pluginAvailable = true;
    } catch (e) {
      _isInitialized = true;
      _pluginAvailable = false;
      debugPrint('NotificationService init error (mock or unsupported): $e');
    }
  }

  /// Cek apakah izin notifikasi aktif di perangkat.
  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await androidPlugin?.areNotificationsEnabled() ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Minta izin notifikasi (Android 13+ & iOS).
  Future<bool> requestPermission() async {
    await initialize();

    try {
      if (kIsWeb) return false;

      if (Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final granted =
              await androidPlugin.requestNotificationsPermission() ?? false;
          return granted;
        }
      } else if (Platform.isIOS || Platform.isMacOS) {
        final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        if (iosPlugin != null) {
          final granted = await iosPlugin.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              ) ??
              false;
          return granted;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Mengambil daftar notifikasi yang sedang aktif terjadwal.
  Future<List<PendingNotificationRequest>> getPendingNotificationRequests() async {
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (_) {
      return [];
    }
  }

  /// Hitung waktu penjadwalan berikutnya untuk jam [hour] dan [minute].
  /// Jika waktu hari ini sudah lewat dari [now], jadwalkan untuk hari esok.
  static tz.TZDateTime nextInstanceOfTime(int hour, int minute, {tz.TZDateTime? now}) {
    final current = now ?? tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      current.location,
      current.year,
      current.month,
      current.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(current) || scheduledDate.isAtSameMomentAs(current)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Format durasi stopwatch menjadi HH:mm:ss.
  static String formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// Jadwalkan pengingat harian dengan [hour] dan [minute] — PRD §10.5.
  Future<void> scheduleDailyReadingReminder({
    required int hour,
    required int minute,
  }) async {
    await initialize();

    try {
      final scheduledDate = nextInstanceOfTime(hour, minute);

      const androidDetails = AndroidNotificationDetails(
        _channelReminderId,
        _channelReminderName,
        channelDescription: _channelReminderDesc,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.reminder,
        ticker: 'StoryLoka',
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails();

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await androidPlugin?.canScheduleExactNotifications() ?? false;
      final scheduleMode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _plugin.zonedSchedule(
        id: _reminderNotificationId,
        title: 'Waktunya membaca',
        body: 'Luangkan beberapa menit untuk buku favoritmu.',
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('[NotificationService] Pengingat harian berhasil dijadwalkan pada: $scheduledDate (ID: $_reminderNotificationId)');
    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
    }
  }

  /// Batalkan pengingat harian.
  Future<void> cancelDailyReadingReminder() async {
    await initialize();
    if (!_pluginAvailable) return;
    try {
      await _plugin.cancel(id: _reminderNotificationId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Gagal membatalkan pengingat harian: $e');
      }
    }
  }

  /// Tampilkan notifikasi stopwatch sesi membaca yang sedang berlangsung — PRD §10.5.
  Future<void> showStopwatchNotification({
    required String bookTitle,
    required DateTime startTime,
  }) async {
    await initialize();

    final isEnabled = await isStopwatchNotifEnabled();
    if (!isEnabled) return;

    try {
      final androidDetails = AndroidNotificationDetails(
        _channelTimerId,
        _channelTimerName,
        channelDescription: _channelTimerDesc,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        usesChronometer: true,
        when: startTime.millisecondsSinceEpoch,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails();

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.show(
        id: _stopwatchNotificationId,
        title: 'Sedang membaca',
        body: bookTitle,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('Error showing stopwatch notification: $e');
    }
  }

  /// Tampilkan notifikasi status stopwatch dijeda saat sesi di-pause — PRD §10.5.
  Future<void> showStopwatchPausedNotification({
    required String bookTitle,
    required Duration elapsed,
  }) async {
    await initialize();

    final isEnabled = await isStopwatchNotifEnabled();
    if (!isEnabled) return;

    try {
      final formattedDuration = formatDuration(elapsed);
      final androidDetails = const AndroidNotificationDetails(
        _channelTimerId,
        _channelTimerName,
        channelDescription: _channelTimerDesc,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        usesChronometer: false,
        showWhen: false,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails();

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.show(
        id: _stopwatchNotificationId,
        title: 'Sesi membaca dijeda',
        body: '$bookTitle ($formattedDuration)',
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('Error showing paused stopwatch notification: $e');
    }
  }

  /// Batalkan notifikasi stopwatch sesi membaca.
  Future<void> cancelStopwatchNotification() async {
    await initialize();
    if (!_pluginAvailable) return;
    try {
      await _plugin.cancel(id: _stopwatchNotificationId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Gagal membatalkan notifikasi stopwatch: $e');
      }
    }
  }

  /// Kirim notifikasi tes langsung sekarang — PRD §10.5 & QA Debug.
  Future<void> showInstantTestNotification() async {
    await initialize();
    try {
      const androidDetails = AndroidNotificationDetails(
        _channelReminderId,
        _channelReminderName,
        channelDescription: _channelReminderDesc,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.reminder,
        ticker: 'StoryLoka',
        icon: '@mipmap/ic_launcher',
      );
      const darwinDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );
      await _plugin.show(
        id: _testInstantNotificationId,
        title: 'Tes Notifikasi StoryLoka',
        body: 'Notifikasi langsung berhasil diterima di perangkat Anda!',
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('Error showing instant test notification: $e');
    }
  }

  /// Jadwalkan notifikasi tes dalam [minutes] menit ke depan — PRD §10.5 & QA Debug.
  Future<tz.TZDateTime> scheduleTestNotificationInMinutes(int minutes) async {
    await initialize();
    final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));

    try {
      const androidDetails = AndroidNotificationDetails(
        _channelReminderId,
        _channelReminderName,
        channelDescription: _channelReminderDesc,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.reminder,
        ticker: 'StoryLoka',
        icon: '@mipmap/ic_launcher',
      );
      const darwinDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await androidPlugin?.canScheduleExactNotifications() ?? false;
      final scheduleMode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _plugin.zonedSchedule(
        id: _testScheduledNotificationId,
        title: 'Tes Jadwal StoryLoka',
        body: 'Notifikasi terjadwal $minutes menit lalu berhasil muncul!',
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: scheduleMode,
      );
    } catch (e) {
      debugPrint('Error scheduling test notification: $e');
    }
    return scheduledDate;
  }

  // ─── Preferensi Notifikasi via SharedPreferences ────────────────────────────

  Future<bool> isReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyReminderEnabled) ?? false;
  }

  Future<TimeOfDay> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_keyReminderHour) ?? 20;
    final minute = prefs.getInt(_keyReminderMinute) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> saveReminderSettings({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReminderEnabled, enabled);
    await prefs.setInt(_keyReminderHour, hour);
    await prefs.setInt(_keyReminderMinute, minute);

    if (enabled) {
      await scheduleDailyReadingReminder(hour: hour, minute: minute);
    } else {
      await cancelDailyReadingReminder();
    }
  }

  Future<bool> isStopwatchNotifEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyStopwatchNotif) ?? false;
  }

  Future<void> setStopwatchNotifEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyStopwatchNotif, enabled);
    if (!enabled) {
      await cancelStopwatchNotification();
    }
  }
}
