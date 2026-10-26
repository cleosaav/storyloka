import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../../../core/services/time_converter_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dropdown.dart';

/// Halaman Konversi Waktu — PRD §9.5.
///
/// Zona: WIB, WITA, WIT, London (otomatis ikut DST).
/// Menginisialisasi timezone database sekali di halaman ini
/// (jika belum diinisialisasi dari main).
class TimeConverterPage extends StatefulWidget {
  const TimeConverterPage({super.key});

  @override
  State<TimeConverterPage> createState() => _TimeConverterPageState();
}

class _TimeConverterPageState extends State<TimeConverterPage> {
  TimeZone _fromZone = TimeZone.wib;
  DateTime _inputTime = DateTime.now();
  List<TimeConversionResult> _results = [];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initAndConvert();
  }

  Future<void> _initAndConvert() async {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      await initializeDateFormatting('id_ID', null);
      _initialized = true;
    }
    _convert();
  }

  void _convert() {
    setState(() {
      _results = TimeConverterService.convertAll(_inputTime, _fromZone);
    });
  }

  Future<void> _pickDate() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.deepTeal;

    final picked = await showDatePicker(
      context: context,
      initialDate: _inputTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2099),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: primaryColor,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _inputTime = DateTime(
          picked.year, picked.month, picked.day,
          _inputTime.hour, _inputTime.minute,
        );
      });
      _convert();
    }
  }

  Future<void> _pickTime() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.deepTeal;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _inputTime.hour, minute: _inputTime.minute),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: primaryColor,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _inputTime = DateTime(
          _inputTime.year, _inputTime.month, _inputTime.day,
          picked.hour, picked.minute,
        );
      });
      _convert();
    }
  }

  void _resetNow() {
    setState(() => _inputTime = DateTime.now());
    _convert();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DateFormat dateFmt;
    try {
      dateFmt = DateFormat('EEE, d MMM yyyy', 'id_ID');
    } catch (_) {
      dateFmt = DateFormat('EEE, d MMM yyyy');
    }
    final timeFmt = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text('Konversi Waktu',
          style: AppText.sectionHeading(color: isDark ? AppColors.inkDark : AppColors.ink)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageMargin,
          vertical: AppSpacing.m,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Zona Asal',
                    style: AppText.bodyMedium(
                      color: isDark ? AppColors.inkDark : AppColors.ink,
                    ).copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.s),
                  _ZoneDropdown(
                    value: _fromZone,
                    isDark: isDark,
                    onChanged: (zone) {
                      if (zone != null) {
                        setState(() => _fromZone = zone);
                        _convert();
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Text('Tanggal & Jam',
                    style: AppText.bodyMedium(
                      color: isDark ? AppColors.inkDark : AppColors.ink,
                    ).copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.s),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                      final isNarrow = constraints.maxWidth < 340 || textScale > 1.15;

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PickerChip(
                              icon: Icons.calendar_today_rounded,
                              label: dateFmt.format(_inputTime),
                              semanticsLabel: 'Pilih tanggal: ${dateFmt.format(_inputTime)}',
                              isDark: isDark,
                              onTap: _pickDate,
                            ),
                            const SizedBox(height: AppSpacing.s),
                            _PickerChip(
                              icon: Icons.access_time_rounded,
                              label: timeFmt.format(_inputTime),
                              semanticsLabel: 'Pilih waktu: ${timeFmt.format(_inputTime)}',
                              isDark: isDark,
                              onTap: _pickTime,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _PickerChip(
                              icon: Icons.calendar_today_rounded,
                              label: dateFmt.format(_inputTime),
                              semanticsLabel: 'Pilih tanggal: ${dateFmt.format(_inputTime)}',
                              isDark: isDark,
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            flex: 2,
                            child: _PickerChip(
                              icon: Icons.access_time_rounded,
                              label: timeFmt.format(_inputTime),
                              semanticsLabel: 'Pilih waktu: ${timeFmt.format(_inputTime)}',
                              isDark: isDark,
                              onTap: _pickTime,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),
                  SecondaryButton(
                    label: 'Sekarang',
                    icon: Icons.my_location_rounded,
                    onPressed: _resetNow,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.l),

            // Hasil konversi
            Text('Hasil Konversi',
              style: AppText.sectionHeading(
                color: isDark ? AppColors.inkDark : AppColors.ink,
              )),
            const SizedBox(height: AppSpacing.m),

            ..._results.map((r) => _ResultCard(
              result: r,
              isDark: isDark,
              isSource: r.zone == _fromZone,
            )),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets pendukung ────────────────────────────────────────────────────────

class _ZoneDropdown extends StatelessWidget {
  final TimeZone value;
  final bool isDark;
  final ValueChanged<TimeZone?> onChanged;

  const _ZoneDropdown({
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = TimeZone.values.map((z) {
      return AppDropdownItem<TimeZone>(
        value: z,
        label: '${z.label} (${z.tzId})',
      );
    }).toList();

    return AppDropdown<TimeZone>(
      value: value,
      items: items,
      onChanged: onChanged,
    );
  }
}

class _PickerChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semanticsLabel;
  final bool isDark;
  final VoidCallback onTap;

  const _PickerChip({
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.deepTeal;
    final bgColor = isDark ? AppColors.surfaceDark : AppColors.warmIvory;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderNeutral;

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSpacing.touchTarget,
        ),
        child: Material(
          color: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            side: BorderSide(color: borderColor),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: primaryColor),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyMedium(
                        color: isDark ? AppColors.inkDark : AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final TimeConversionResult result;
  final bool isDark;
  final bool isSource;

  const _ResultCard({
    required this.result,
    required this.isDark,
    required this.isSource,
  });

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');
    DateFormat dateFmt;
    try {
      dateFmt = DateFormat('EEE, d MMM yyyy', 'id_ID');
    } catch (_) {
      dateFmt = DateFormat('EEE, d MMM yyyy');
    }

    // Bersihkan label ganda seperti "(WIB)" jika zone.label sudah sama dengan singkatan offset
    final cleanOffset = result.offsetLabel.replaceAll(' (${result.zone.label})', '');
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.deepTeal;
    final cardColor = isSource
        ? primaryColor.withValues(alpha: isDark ? 0.15 : 0.08)
        : (isDark ? AppColors.surfaceDark : AppColors.white);
    final borderSide = isSource
        ? BorderSide(color: primaryColor.withValues(alpha: isDark ? 0.4 : 0.3), width: 1.5)
        : (isDark
            ? const BorderSide(color: AppColors.borderDark)
            : const BorderSide(color: AppColors.borderNeutral));

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: AppCard(
        color: cardColor,
        border: borderSide,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          children: [
            // Zone label
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.zone.label,
                    style: AppText.cardHeading(
                      color: isSource
                          ? primaryColor
                          : (isDark ? AppColors.inkDark : AppColors.ink),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cleanOffset,
                    style: AppText.caption(
                      color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeFmt.format(result.localTime),
                    style: AppText.sectionHeading(
                      color: isSource
                          ? primaryColor
                          : (isDark ? AppColors.inkDark : AppColors.ink),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          dateFmt.format(result.localTime),
                          style: AppText.caption(
                            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (result.dayDiff != 0) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.sageGreen.withValues(alpha: 0.25)
                                : AppColors.sageGreen.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusS),
                          ),
                          child: Text(
                            result.dayDiff > 0 ? '+${result.dayDiff} hari' : '${result.dayDiff} hari',
                            style: AppText.caption(
                              color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

