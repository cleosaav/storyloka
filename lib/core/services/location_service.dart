import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/app_button.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/app_text_field.dart';

/// Service LBS pencarian toko buku terdekat — PRD §9.4.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Membuka peta pencarian toko buku terdekat dengan koordinat GPS pengguna.
  /// Minta izin lokasi dengan penjelasan transparan.
  /// Jika ditolak/mati -> fallback ke bottom sheet input lokasi manual.
  Future<void> openNearbyBookstores(BuildContext context) async {
    // 1. Periksa apakah layanan lokasi aktif
    bool serviceEnabled;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      serviceEnabled = false;
    }

    if (!serviceEnabled) {
      if (context.mounted) {
        showManualLocationSheet(
          context,
          reason: 'Layanan lokasi (GPS) sedang dinonaktifkan.',
        );
      }
      return;
    }

    // 2. Periksa status izin lokasi
    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
    } catch (_) {
      permission = LocationPermission.denied;
    }

    if (permission == LocationPermission.denied) {
      // Tampilkan dialog penjelasan edukasi sesuai PRD §9.4
      if (context.mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Izin Lokasi', style: AppText.cardHeading()),
            content: Text(
              'Izin lokasi dipakai untuk mencari toko buku di dekatmu.',
              style: AppText.body(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Izinkan'),
              ),
            ],
          ),
        );

        if (proceed != true) {
          if (context.mounted) {
            showManualLocationSheet(context);
          }
          return;
        }
      }

      try {
        permission = await Geolocator.requestPermission();
      } catch (_) {
        permission = LocationPermission.denied;
      }

      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          showManualLocationSheet(
            context,
            reason: 'Izin lokasi tidak diberikan.',
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        showManualLocationSheet(
          context,
          reason: 'Izin lokasi ditolak permanen.',
          isPermanentlyDenied: true,
        );
      }
      return;
    }

    // 3. Izin diberikan -> ambil posisi GPS saat ini
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final uri = Uri.parse(
        'https://www.google.com/maps/search/toko+buku/@${position.latitude},${position.longitude},15z',
      );

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        AppSnackBar.show(
          context,
          message: 'Tidak dapat membuka aplikasi Google Maps.',
          type: SnackBarType.warning,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showManualLocationSheet(
          context,
          reason: 'Gagal mendeteksi lokasi otomatis.',
        );
      }
    }
  }

  /// Menampilkan modal bottom sheet berisi field lokasi manual (kota/daerah) — PRD §9.4.
  void showManualLocationSheet(
    BuildContext context, {
    String? reason,
    bool isPermanentlyDenied = false,
  }) {
    final locationController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.cardRadius),
        ),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.l,
            right: AppSpacing.l,
            top: AppSpacing.l,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cari Toko Buku Terdekat',
                style: AppText.sectionHeading(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              if (reason != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  reason,
                  style: AppText.caption(
                    color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s),
              Text(
                'Masukkan nama kota atau daerah untuk menemukan toko buku di sekitarmu.',
                style: AppText.body(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              AppTextField(
                controller: locationController,
                autofocus: true,
                hintText: 'Contoh: Jakarta Selatan, Bandung, Yogyakarta',
                prefixIcon: const Icon(Icons.location_city_rounded),
              ),
              const SizedBox(height: AppSpacing.l),
              PrimaryButton(
                label: 'Buka di Maps',
                onPressed: () {
                  final text = locationController.text.trim();
                  Navigator.pop(ctx);
                  openMapsWithQuery(context, text);
                },
              ),
              if (isPermanentlyDenied) ...[
                const SizedBox(height: AppSpacing.s),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Geolocator.openAppSettings();
                  },
                  icon: const Icon(Icons.settings_rounded, size: 16),
                  label: const Text('Buka Pengaturan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.deepTeal,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Membuka Maps berdasarkan query teks lokasi manual — PRD §9.4.
  Future<void> openMapsWithQuery(BuildContext context, String query) async {
    final clean = query.trim();
    final Uri uri = clean.isEmpty
        ? Uri.parse('https://www.google.com/maps/search/toko+buku/')
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=toko+buku+di+${Uri.encodeComponent(clean)}',
          );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        AppSnackBar.show(
          context,
          message: 'Tidak dapat membuka aplikasi Maps',
          type: SnackBarType.warning,
        );
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: 'Gagal membuka Google Maps',
          type: SnackBarType.error,
        );
      }
    }
  }
}
