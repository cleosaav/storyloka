import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/book_search_repository.dart';

/// Halaman Scan Barcode ISBN dengan simulator kamera dan input ISBN manual — PRD §7.3.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final TextEditingController _isbnController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _isbnController.dispose();
    super.dispose();
  }

  Future<void> _searchIsbn() async {
    final rawIsbn = _isbnController.text.trim();
    final cleanIsbn = rawIsbn.replaceAll(RegExp(r'[^0-9X]'), '');

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
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackBar.show(
        context,
        message: 'Gagal mencari ISBN. Silakan coba lagi.',
        type: SnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Scan Barcode',
          style: AppText.pageHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Kamera placeholder / scanner frame simulator
            Container(
              height: 260,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.ink,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Sudut-sudut frame scanner
                  Container(
                    width: 200,
                    height: 140,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.softApricot,
                        width: 2.5,
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.s),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 56,
                        color: AppColors.softApricot,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: AppSpacing.m,
                    left: AppSpacing.m,
                    right: AppSpacing.m,
                    child: Text(
                      'Mode Demo / Simulator Kamera\nArahkan ke barcode ISBN (EAN-13)',
                      textAlign: TextAlign.center,
                      style: AppText.caption(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Card Input ISBN Manual
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
                  TextField(
                    controller: _isbnController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Nomor ISBN',
                      hintText: 'Contoh: 9786024526986',
                      prefixIcon: const Icon(Icons.numbers_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      ),
                    ),
                    onSubmitted: (_) => _searchIsbn(),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  PrimaryButton(
                    label: 'Cari ISBN',
                    isLoading: _isLoading,
                    onPressed: _searchIsbn,
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
