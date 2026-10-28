import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/book_search_repository.dart';

/// Halaman Scan Barcode ISBN nyata via mobile_scanner + fallback manual — PRD §7.3.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final TextEditingController _isbnController = TextEditingController();
  MobileScannerController? _cameraController;
  bool _isLoading = false;
  bool _cameraPermissionDenied = false;
  bool _hasScanned = false; // Prevent multiple scans

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  void _initCamera() {
    _cameraController = MobileScannerController(
      formats: [BarcodeFormat.ean13],
      detectionSpeed: DetectionSpeed.normal,
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _isbnController.dispose();
    super.dispose();
  }

  /// Proses barcode yang terdeteksi oleh kamera — PRD §7.3.
  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_hasScanned || _isLoading) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    // Hanya format EAN-13/ISBN (awalan 978/979) — PRD §7.3
    final cleanCode = rawValue.replaceAll(RegExp(r'[^0-9]'), '');
    if (!cleanCode.startsWith('978') && !cleanCode.startsWith('979')) return;

    setState(() => _hasScanned = true);
    _cameraController?.stop();
    _searchByIsbn(cleanCode);
  }

  Future<void> _searchByIsbn(String isbn) async {
    final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9X]'), '');

    if (cleanIsbn.isEmpty) {
      AppSnackBar.show(
        context,
        message: 'Silakan masukkan kode ISBN terlebih dahulu',
        type: SnackBarType.warning,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = context.read<BookSearchRepository>();
      final results = await repository.search(cleanIsbn, filter: 'isbn');

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (results.isNotEmpty) {
        context.push('/book/search', extra: results.first);
      } else {
        AppSnackBar.show(
          context,
          message: 'ISBN tidak ditemukan',
          type: SnackBarType.info,
        );
        _resetScanner();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackBar.show(
        context,
        message: 'Gagal mencari ISBN. Silakan coba lagi.',
        type: SnackBarType.error,
      );
      _resetScanner();
    }
  }

  void _resetScanner() {
    setState(() => _hasScanned = false);
    _cameraController?.start();
  }

  void _searchManualIsbn() {
    _searchByIsbn(_isbnController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Scan Barcode',
          style: AppText.sectionHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Area kamera / scanner nyata
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              child: SizedBox(
                height: 260,
                child: _cameraPermissionDenied
                    ? _buildPermissionDenied(isDark)
                    : _buildScanner(isDark),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Card Input ISBN Manual — fallback PRD §7.3
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Input ISBN Manual',
                    style: AppText.sectionHeading(
                      color: isDark ? AppColors.inkDark : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Jika kamera tidak tersedia atau barcode rusak, masukkan 10 atau 13 digit nomor ISBN.',
                    style: AppText.body(
                      color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  AppTextField(
                    controller: _isbnController,
                    label: 'Nomor ISBN',
                    hintText: 'Contoh: 9786024526986',
                    prefixIcon: const Icon(Icons.numbers_rounded),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _searchManualIsbn(),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  PrimaryButton(
                    label: 'Cari ISBN',
                    isLoading: _isLoading,
                    onPressed: _searchManualIsbn,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget scanner kamera nyata menggunakan mobile_scanner.
  Widget _buildScanner(bool isDark) {
    return Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(
          controller: _cameraController!,
          onDetect: _onBarcodeDetected,
          errorBuilder: (context, error) {
            // Izin kamera ditolak — PRD §11
            if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _cameraPermissionDenied = true);
                }
              });
            }
            return _buildCameraError(isDark, error);
          },
        ),
        // Frame overlay scanner
        IgnorePointer(
          child: Container(
            width: 220,
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.softApricot,
                width: 2.5,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusS),
            ),
          ),
        ),
        // Loading overlay
        if (_isLoading)
          Container(
            color: (isDark ? AppColors.bgDark : AppColors.ink).withValues(alpha: 0.65),
            child: const Center(
              child: CircularProgressIndicator(
                color: AppColors.softApricot,
              ),
            ),
          ),
        // Instruksi
        Positioned(
          bottom: AppSpacing.m,
          left: AppSpacing.m,
          right: AppSpacing.m,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.bgDark : AppColors.ink).withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(AppSpacing.radiusS),
            ),
            child: Text(
              'Arahkan kamera ke barcode ISBN (EAN-13)',
              textAlign: TextAlign.center,
              style: AppText.caption(
                color: isDark ? AppColors.inkDark : AppColors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Tampilan error kamera.
  Widget _buildCameraError(bool isDark, MobileScannerException error) {
    return Container(
      color: isDark ? AppColors.surfaceDark : AppColors.ink,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              size: AppSpacing.iconXxl,
              color: AppColors.softApricot,
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              'Kamera tidak tersedia',
              style: AppText.sectionHeading(color: AppColors.white),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Gunakan input ISBN manual di bawah.',
              style: AppText.caption(color: AppColors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  /// Tampilan izin kamera ditolak — PRD §11.
  Widget _buildPermissionDenied(bool isDark) {
    return Container(
      color: isDark ? AppColors.surfaceDark : AppColors.ink,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_rounded,
                size: AppSpacing.iconXxl,
                color: AppColors.softApricot,
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                'Izin Kamera Ditolak',
                style: AppText.sectionHeading(color: AppColors.white),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Izinkan akses kamera di pengaturan untuk scan barcode, atau gunakan input ISBN manual di bawah.',
                textAlign: TextAlign.center,
                style: AppText.caption(color: AppColors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
