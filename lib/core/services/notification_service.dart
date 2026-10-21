import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  static const int _reminderNotificationId = 1001;
  static const int _stopwatchNotificationId = 1002;

  static const String _channelReminderId = 'reading_reminder';
  static const String _channelReminderName = 'Pengingat Membaca';
  static const String _channelReminderDesc = 'Notifikasi jadwal membaca harian';

  static const String _channelTimerId = 'reading_timer';
  static const String _channelTimerName = 'Stopwatch Membaca';
  static const String _channelTimerDesc = 'Notifikasi sesi membaca berlangsung';

  static const String _keyReminderEnabled = 'pref_reading_reminder_enabled';
  static const String _keyReminderHour = 'pref_reading_reminder_hour';
  static const String _keyReminderMinute = 'pref_reading_reminder_minute';
  static const String _keyStopwatchNotif = 'pref_stopwatch_notif_enabled';

  /// Inisialisasi plugin notifikasi dan pembuatan channels Android.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz_data.initializeTimeZones();
    } catch (_) {}

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
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

      // Buat Android notification channels
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelReminderId,
            _channelReminderName,
            description: _channelReminderDesc,
            importance: Importance.defaultImportance,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelTimerId,
            _channelTimerName,
            description: _channelTimerDesc,
            importance: Importance.low,
            enableVibration: false,
            playSound: false,
          ),
        );
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error (mock or unsupported): $e');
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

  /// Jadwalkan pengingat harian dengan [hour] dan [minute] — PRD §10.5.
  Future<void> scheduleDailyReadingReminder({
    required int hour,
    required int minute,
  }) async {
    await initialize();

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        _channelReminderId,
        _channelReminderName,
        channelDescription: _channelReminderDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      const darwinDetails = DarwinNotificationDetails();

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.zonedSchedule(
        id: _reminderNotificationId,
        title: 'Waktunya membaca',
        body: 'Luangkan beberapa menit untuk buku favoritmu.',
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
    }
  }

  /// Batalkan pengingat harian.
  Future<void> cancelDailyReadingReminder() async {
    await initialize();
    try {
      await _plugin.cancel(id: _reminderNotificationId);
    } catch (_) {}
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

  /// Batalkan notifikasi stopwatch sesi membaca.
  Future<void> cancelStopwatchNotification() async {
    await initialize();
    try {
      await _plugin.cancel(id: _stopwatchNotificationId);
    } catch (_) {}
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
