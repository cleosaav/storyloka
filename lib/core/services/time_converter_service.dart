import 'package:timezone/timezone.dart' as tz;

/// Zona waktu yang didukung — PRD §9.5.
enum TimeZone {
  wib('WIB', 'Asia/Jakarta', 'UTC+7'),
  wita('WITA', 'Asia/Makassar', 'UTC+8'),
  wit('WIT', 'Asia/Jayapura', 'UTC+9'),
  london('London', 'Europe/London', 'UTC+0/+1');

  final String label;
  final String tzId;
  final String baseOffset;

  const TimeZone(this.label, this.tzId, this.baseOffset);
}

/// Hasil konversi untuk satu zona waktu.
class TimeConversionResult {
  final TimeZone zone;
  final DateTime localTime;
  final String offsetLabel;   // mis. "UTC+7" atau "UTC+1 (BST)"
  final int dayDiff;          // selisih hari dari zona asal (+1, 0, -1)

  const TimeConversionResult({
    required this.zone,
    required this.localTime,
    required this.offsetLabel,
    required this.dayDiff,
  });
}

/// Logika konversi waktu murni — PRD §9.5.
///
/// Menggunakan paket `timezone` agar DST (Daylight Saving Time) London
/// ditangani secara otomatis (GMT vs BST).
class TimeConverterService {
  /// Konversi [inputTime] dari [fromZone] ke semua 4 zona yang didukung.
  ///
  /// Kembalikan list 4 [TimeConversionResult].
  static List<TimeConversionResult> convertAll(
    DateTime inputTime,
    TimeZone fromZone,
  ) {
    // Konversi input ke UTC dulu
    final fromLocation = tz.getLocation(fromZone.tzId);
    final tzFrom = tz.TZDateTime(
      fromLocation,
      inputTime.year,
      inputTime.month,
      inputTime.day,
      inputTime.hour,
      inputTime.minute,
    );
    final utc = tzFrom.toUtc();
    final originDay = tzFrom.day;

    return TimeZone.values.map((zone) {
      final location = tz.getLocation(zone.tzId);
      final converted = tz.TZDateTime.from(utc, location);
      final offsetHours = converted.timeZoneOffset.inHours;
      final offsetMins = converted.timeZoneOffset.inMinutes % 60;
      final sign = offsetHours >= 0 ? '+' : '';
      final offsetStr = offsetMins != 0
          ? 'UTC$sign$offsetHours:${offsetMins.abs().toString().padLeft(2, '0')}'
          : 'UTC$sign$offsetHours';
      final abbr = converted.timeZoneName;
      final offsetLabel = abbr.isNotEmpty && abbr != offsetStr ? '$offsetStr ($abbr)' : offsetStr;
      final dayDiff = converted.day - originDay;

      return TimeConversionResult(
        zone: zone,
        localTime: converted,
        offsetLabel: offsetLabel,
        dayDiff: dayDiff.clamp(-1, 1),
      );
    }).toList();
  }
}
