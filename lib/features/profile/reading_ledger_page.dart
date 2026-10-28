import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/ledger_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/ledger_block.dart';
import '../../data/repositories/ledger_repository.dart';
import '../auth/auth_controller.dart';

/// Halaman Reading Ledger (Buku Selesai Terenkripsi) — PRD §10.2 & Fase S5.
class ReadingLedgerPage extends StatefulWidget {
  const ReadingLedgerPage({super.key});

  @override
  State<ReadingLedgerPage> createState() => _ReadingLedgerPageState();
}

class _ReadingLedgerPageState extends State<ReadingLedgerPage> {
  List<LedgerBlock> _blocks = [];
  bool _isLoading = true;
  String? _errorMessage;

  ChainVerificationResult? _verificationResult;
  DateTime? _lastVerificationTime;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  Future<void> _loadBlocks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authController = context.read<AuthController>();
      final user = authController.currentUser;

      // Jika belum login, hentikan loading dan jangan buat blok demo palsu — Fase S5
      if (user == null) {
        if (mounted) {
          setState(() {
            _blocks = [];
            _isLoading = false;
            _errorMessage = null;
          });
        }
        return;
      }

      final ledgerService = context.read<LedgerService>();
      final ledgerRepo = context.read<LedgerRepository>();

      // Pastikan genesis block ada untuk user ini jika belum pernah dibuat
      await ledgerService.ensureGenesisBlock(user.id);

      final blocks = await ledgerRepo.getBlocks();
      
      // Auto-verify saat halaman dibuka — Fase S5
      final verifyResult = LedgerService.verifyChain(blocks);

      if (mounted) {
        setState(() {
          _blocks = blocks;
          _verificationResult = verifyResult;
          _lastVerificationTime = DateTime.now();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Gagal memuat rantai ledger. Silakan periksa koneksi atau coba beberapa saat lagi.';
          _isLoading = false;
        });
      }
    }
  }

  void _verifyLedger() {
    setState(() => _isVerifying = true);

    final result = LedgerService.verifyChain(_blocks);

    setState(() {
      _verificationResult = result;
      _lastVerificationTime = DateTime.now();
      _isVerifying = false;
    });

    if (result.isValid) {
      AppSnackBar.show(
        context,
        message: 'Verifikasi berhasil: Seluruh rantai blok utuh dan valid.',
        type: SnackBarType.success,
      );
    } else {
      AppSnackBar.show(
        context,
        message: 'Verifikasi gagal: Blok #${result.invalidIndex} tidak valid!',
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _handleRefresh() async {
    final authController = context.read<AuthController>();
    final user = authController.currentUser;
    if (user != null) {
      try {
        await SyncService.instance.pullAll(user.id);
      } catch (e) {
        if (kDebugMode) debugPrint('[ReadingLedgerPage] pullAll gagal: $e');
      }
    }
    await _loadBlocks();
  }

  void _showAboutLedgerSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.cardRadius)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.m,
              AppSpacing.pageMargin,
              AppSpacing.l,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: context.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Text(
                      'Tentang Reading Ledger',
                      style: AppText.sectionHeading(
                        color: isDark ? AppColors.inkDark : AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                Text(
                  'Reading Ledger adalah sistem pencatatan riwayat bacaan kriptografis berbasis rantai blok lokal. Setiap kali kamu menyelesaikan sebuah buku, buku tersebut dicatat menjadi blok yang terhubung secara permanen dengan blok sebelumnya.',
                  style: AppText.body(
                    color: isDark ? AppColors.inkDark : AppColors.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  'Setiap blok diverifikasi menggunakan Proof of Work dengan target awalan hash \'00\' dan tautan SHA-256. Mengubah satu baris atau satu karakter saja pada riwayat bacaan akan membatalkan validitas seluruh blok setelahnya.',
                  style: AppText.body(
                    color: isDark ? AppColors.inkDark : AppColors.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.bgDark : AppColors.warmIvory,
                    borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Text(
                          'Catatan Arsitektur: Rantai ini merupakan ledger pribadi milik tiap pengguna yang tersimpan secara lokal dan disinkronkan ke cloud pribadi akunmu, bukan jaringan publik peer-to-peer terdesentralisasi.',
                          style: AppText.caption(
                            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: 'Mengerti',
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBlockDetailSheet(BuildContext context, LedgerBlock block) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGenesis = block.blockIndex == 0;

    DateFormat fullDateFormat;
    try {
      fullDateFormat = DateFormat('EEEE, dd MMMM yyyy, HH:mm:ss', 'id_ID');
    } catch (_) {
      fullDateFormat = DateFormat('dd MMM yyyy, HH:mm:ss');
    }
    final formattedDate = fullDateFormat.format(block.timestamp.toLocal());

    final title = isGenesis
        ? (block.dataJson['message'] as String? ?? 'StoryLoka genesis')
        : (block.dataJson['title'] as String? ?? 'Buku Selesai');
    final authors = block.dataJson['authors'] as String?;
    final pageCount = block.dataJson['page_count'] as int?;
    final readingSecs = block.dataJson['total_reading_seconds'] as int?;
    final rating = block.dataJson['rating'] as int?;

    String readingDurationText = '-';
    if (readingSecs != null && readingSecs > 0) {
      final mins = (readingSecs / 60).round();
      if (mins >= 60) {
        final hours = mins ~/ 60;
        final remMins = mins % 60;
        readingDurationText = remMins > 0 ? '$hours jam $remMins menit' : '$hours jam';
      } else {
        readingDurationText = '$mins menit';
      }
    }

    final rawJsonPretty = const JsonEncoder.withIndent('  ').convert(block.dataJson);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.cardRadius)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return SafeArea(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageMargin,
                  AppSpacing.m,
                  AppSpacing.pageMargin,
                  AppSpacing.l,
                ),
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),

                  // Header Index & Tipe
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isGenesis
                              ? AppColors.softApricot.withValues(alpha: isDark ? 0.25 : 0.4)
                              : context.primaryColor.withValues(alpha: isDark ? 0.2 : 0.15),
                          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                        ),
                        child: Text(
                          isGenesis ? 'Blok #0 (Genesis)' : 'Blok #${block.blockIndex}',
                          style: AppText.caption(
                            color: isGenesis
                                ? (isDark ? AppColors.softApricot : AppColors.deepTeal)
                                : context.primaryColor,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        'Nonce: ${block.nonce}',
                        style: AppText.code(
                          color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),

                  // Judul
                  Text(
                    title,
                    style: AppText.cardHeading(
                      color: isDark ? AppColors.inkDark : AppColors.ink,
                    ),
                  ),
                  if (authors != null && authors.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      authors,
                      style: AppText.body(
                        color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.m),

                  // Info Grid: Waktu, Halaman, Durasi, Rating
                  _buildDetailTile('Waktu Pencatatan', formattedDate, isDark),
                  if (!isGenesis) ...[
                    const SizedBox(height: AppSpacing.s),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailTile(
                            'Total Halaman',
                            pageCount != null && pageCount > 0 ? '$pageCount hal' : '-',
                            isDark,
                          ),
                        ),
                        Expanded(
                          child: _buildDetailTile(
                            'Total Waktu Baca',
                            readingDurationText,
                            isDark,
                          ),
                        ),
                      ],
                    ),
                    if (rating != null && rating > 0) ...[
                      const SizedBox(height: AppSpacing.s),
                      _buildDetailTile(
                        'Rating Pembaca',
                        '$rating dari 5 Bintang',
                        isDark,
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.m),
                  const Divider(),
                  const SizedBox(height: AppSpacing.m),

                  // Kriptografi & Hash Penuh
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hash Blok (SHA-256)',
                        style: AppText.sectionHeading(
                          color: isDark ? AppColors.inkDark : AppColors.ink,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        tooltip: 'Salin Hash',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: block.hash));
                          AppSnackBar.show(
                            context,
                            message: 'Hash blok #${block.blockIndex} disalin',
                            type: SnackBarType.info,
                          );
                        },
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.bgDark : AppColors.warmIvory,
                      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
                      ),
                    ),
                    child: SelectableText(
                      block.hash,
                      style: AppText.code(
                        color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),

                  // Previous Hash Penuh
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Previous Hash',
                        style: AppText.sectionHeading(
                          color: isDark ? AppColors.inkDark : AppColors.ink,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        tooltip: 'Salin Previous Hash',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: block.previousHash));
                          AppSnackBar.show(
                            context,
                            message: 'Previous hash disalin',
                            type: SnackBarType.info,
                          );
                        },
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.bgDark : AppColors.warmIvory,
                      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
                      ),
                    ),
                    child: SelectableText(
                      block.previousHash,
                      style: AppText.code(
                        color: isDark ? AppColors.inkDark : AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),

                  // Raw JSON Data
                  Text(
                    'Data Payload (Kanonikal JSON)',
                    style: AppText.sectionHeading(
                      color: isDark ? AppColors.inkDark : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.bgDark : AppColors.warmIvory,
                      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
                      ),
                    ),
                    child: SelectableText(
                      rawJsonPretty,
                      style: AppText.code(
                        color: isDark ? AppColors.inkDark : AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),

                  PrimaryButton(
                    label: 'Tutup',
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildDetailTile(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.caption(
            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppText.body(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reading Ledger',
          style: AppText.sectionHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Tentang Ledger',
            onPressed: () => _showAboutLedgerSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: context.primaryColor,
        onRefresh: _handleRefresh,
        child: _buildBody(isDark),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    // 1. Cek Autentikasi — PRD §10.2 & Fase S5: Tanpa fallback 'demo_user'
    final authController = context.watch<AuthController>();
    final user = authController.currentUser;

    if (user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 56,
                color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                'Silakan Masuk',
                style: AppText.pageHeading(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                'Masuk ke akunmu untuk melihat riwayat rantai blok dan verifikasi Reading Ledger pribadimu.',
                textAlign: TextAlign.center,
                style: AppText.body(
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              PrimaryButton(
                label: 'Masuk Sekarang',
                icon: Icons.login_rounded,
                onPressed: () => context.push('/login'),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Loading State
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: context.primaryColor),
      );
    }

    // 3. Error State (Pesan ramah tanpa $e mentah)
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.m),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppText.body(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              PrimaryButton(
                label: 'Coba Lagi',
                icon: Icons.refresh_rounded,
                onPressed: _loadBlocks,
              ),
            ],
          ),
        ),
      );
    }

    final isOnlyGenesis = _blocks.length <= 1;
    final finishedBooksCount = _blocks.where((b) => b.blockIndex > 0).length;

    // Sinkronisasi status dari SyncService
    String syncLabel = SyncService.instance.state.label;
    try {
      final syncService = context.watch<SyncService?>();
      if (syncService != null) {
        syncLabel = syncService.state.label;
      }
    } catch (_) {
      try {
        final syncService = context.watch<SyncService>();
        syncLabel = syncService.state.label;
      } catch (_) {}
    }

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageMargin,
        vertical: AppSpacing.m,
      ),
      children: [
        // 1. Deskripsi Faktual (Menggantikan banner simulasi/demo)
        AppCard(
          color: isDark
              ? AppColors.primaryDark.withValues(alpha: 0.15)
              : AppColors.softApricot.withValues(alpha: 0.3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.link_rounded,
                color: context.primaryColor,
                size: 26,
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rantai Catatan Bacaan',
                      style: AppText.cardHeading(
                        color: isDark ? AppColors.inkDark : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Setiap buku yang selesai kamu baca dicatat sebagai blok. Blok saling terhubung lewat hash SHA-256 dan Proof of Work; mengubah satu data saja membuat rantai tidak valid.',
                      style: AppText.body(
                        color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.m),

        // 2. Ringkasan di Bagian Atas: Blok, Buku, Verifikasi Terakhir, Status Sinkronisasi
        _buildSummaryCard(
          totalBlocks: _blocks.length,
          finishedBooks: finishedBooksCount,
          verificationResult: _verificationResult,
          lastVerificationTime: _lastVerificationTime,
          syncLabel: syncLabel,
          isDark: isDark,
        ),
        const SizedBox(height: AppSpacing.m),

        // 3. Tombol Verifikasi Manual & Hasil Verifikasi
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Verifikasi Integritas Ledger',
                      style: AppText.cardHeading(
                        color: isDark ? AppColors.inkDark : AppColors.ink,
                      ),
                    ),
                  ),
                  if (_verificationResult != null)
                    Icon(
                      _verificationResult!.isValid
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: _verificationResult!.isValid
                          ? AppColors.sageGreen
                          : AppColors.error,
                      size: 22,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                'Periksa keutuhan seluruh rantai blok, validitas Proof of Work, serta tautan hash dari blok genesis hingga blok terbaru.',
                style: AppText.caption(
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              PrimaryButton(
                label: 'Verify Ledger',
                icon: Icons.verified_user_rounded,
                isLoading: _isVerifying,
                onPressed: _verifyLedger,
              ),
              if (_verificationResult != null) ...[
                const SizedBox(height: AppSpacing.m),
                _buildVerificationResultCard(_verificationResult!, isDark),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.l),

        // 4. Section Heading
        Text(
          'Daftar Blok Rantai',
          style: AppText.sectionHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.m),

        // 6. Empty State jika hanya ada blok Genesis
        if (isOnlyGenesis)
          Container(
            padding: const EdgeInsets.all(AppSpacing.l),
            margin: const EdgeInsets.only(bottom: AppSpacing.m),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.warmIvory,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_stories_outlined,
                  color: AppColors.sageGreen,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Text(
                    'Selesaikan membaca buku untuk menambahkan blok riwayat bacaan baru ke dalam rantai ledger pribadimu.',
                    style: AppText.body(
                      color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 7. Timeline Daftar Kartu Blok Blockchain
        for (int i = 0; i < _blocks.length; i++) ...[
          _buildBlockCard(
            block: _blocks[i],
            isDark: isDark,
            verificationResult: _verificationResult,
          ),
          if (i < _blocks.length - 1)
            _buildTimelineConnector(
              isBroken: _verificationResult != null &&
                  !_verificationResult!.isValid &&
                  _blocks[i].blockIndex >= (_verificationResult!.invalidIndex ?? 0),
            ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildSummaryCard({
    required int totalBlocks,
    required int finishedBooks,
    required ChainVerificationResult? verificationResult,
    required DateTime? lastVerificationTime,
    required String syncLabel,
    required bool isDark,
  }) {
    String verifyStatusText;
    Color verifyColor;
    IconData verifyIcon;

    if (verificationResult == null) {
      verifyStatusText = 'Belum diverifikasi';
      verifyColor = isDark ? AppColors.mutedDark : AppColors.mutedGray;
      verifyIcon = Icons.help_outline_rounded;
    } else if (verificationResult.isValid) {
      final timeStr = lastVerificationTime != null
          ? DateFormat('HH:mm').format(lastVerificationTime.toLocal())
          : '';
      verifyStatusText = timeStr.isNotEmpty ? 'Valid ($timeStr)' : 'Rantai Valid';
      verifyColor = AppColors.sageGreen;
      verifyIcon = Icons.check_circle_rounded;
    } else {
      verifyStatusText = 'Blok #${verificationResult.invalidIndex} Rusak';
      verifyColor = AppColors.error;
      verifyIcon = Icons.cancel_rounded;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan Ledger',
            style: AppText.sectionHeading(
              color: isDark ? AppColors.inkDark : AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.layers_rounded,
                  label: 'Jumlah Blok',
                  value: '$totalBlocks Blok',
                  color: context.primaryColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.book_rounded,
                  label: 'Buku Tercatat',
                  value: '$finishedBooks Buku',
                  color: AppColors.deepTeal,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: verifyIcon,
                  label: 'Status Verifikasi',
                  value: verifyStatusText,
                  color: verifyColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.cloud_done_rounded,
                  label: 'Sinkronisasi',
                  value: syncLabel,
                  color: AppColors.sageGreen,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDark : AppColors.warmIvory,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(
                    color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(
              color: isDark ? AppColors.inkDark : AppColors.ink,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineConnector({required bool isBroken}) {
    final color = isBroken ? AppColors.error : AppColors.sageGreen;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          children: [
            Container(width: 2, height: 8, color: color),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
              child: Icon(
                isBroken ? Icons.link_off_rounded : Icons.link_rounded,
                size: 14,
                color: color,
              ),
            ),
            Container(width: 2, height: 8, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationResultCard(ChainVerificationResult result, bool isDark) {
    final isValid = result.isValid;
    final color = isValid ? AppColors.sageGreen : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isValid ? 'Rantai Utuh & Valid' : 'Blok #${result.invalidIndex} Tidak Valid',
                  style: AppText.cardHeading(color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  isValid
                      ? 'Seluruh ${_blocks.length} blok terverifikasi utuh, hash cocok, dan tidak dimodifikasi.'
                      : (result.reason ?? 'Terjadi ketidaksesuaian data atau hash pada rantai.'),
                  style: AppText.caption(
                    color: isDark ? AppColors.inkDark : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockCard({
    required LedgerBlock block,
    required bool isDark,
    required ChainVerificationResult? verificationResult,
  }) {
    final isGenesis = block.blockIndex == 0;

    // Evaluasi status kerusakan blok
    final isFirstBroken = verificationResult != null &&
        !verificationResult.isValid &&
        block.blockIndex == verificationResult.invalidIndex;
    final isImpactedBroken = verificationResult != null &&
        !verificationResult.isValid &&
        block.blockIndex > (verificationResult.invalidIndex ?? -1);

    final cardBorder = isFirstBroken
        ? const BorderSide(color: AppColors.error, width: 1.5)
        : (isImpactedBroken
            ? const BorderSide(color: AppColors.softApricot, width: 1.5)
            : null);

    final cardBgColor = isFirstBroken
        ? AppColors.error.withValues(alpha: 0.08)
        : (isImpactedBroken ? AppColors.softApricot.withValues(alpha: 0.05) : null);

    DateFormat dateFormat;
    try {
      dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    } catch (_) {
      dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    }
    final formattedDate = dateFormat.format(block.timestamp.toLocal());

    final title = isGenesis
        ? (block.dataJson['message'] as String? ?? 'StoryLoka genesis')
        : (block.dataJson['title'] as String? ?? 'Buku Selesai');
    final authors = block.dataJson['authors'] as String?;
    final rating = block.dataJson['rating'] as int?;

    final shortHash = block.hash.length >= 8 ? block.hash.substring(0, 8) : block.hash;
    final shortPrev = block.previousHash.length >= 8
        ? block.previousHash.substring(0, 8)
        : block.previousHash;

    return AppCard(
      onTap: () => _showBlockDetailSheet(context, block),
      border: cardBorder,
      color: cardBgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row Header: Chip Indeks + Status Validitas + Tanggal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isGenesis
                            ? AppColors.softApricot.withValues(alpha: isDark ? 0.25 : 0.4)
                            : context.primaryColor.withValues(alpha: isDark ? 0.2 : 0.15),
                        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isGenesis ? Icons.star_rounded : Icons.menu_book_rounded,
                            size: 14,
                            color: isGenesis
                                ? (isDark ? AppColors.softApricot : AppColors.deepTeal)
                                : context.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              isGenesis ? 'Blok #0 (Genesis)' : 'Blok #${block.blockIndex}',
                              style: AppText.caption(
                                color: isGenesis
                                    ? (isDark ? AppColors.softApricot : AppColors.deepTeal)
                                    : context.primaryColor,
                              ).copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    if (isFirstBroken)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.error, width: 1),
                        ),
                        child: Text(
                          'Rusak / Tidak Valid',
                          style: AppText.caption(color: AppColors.error).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (isImpactedBroken)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.softApricot.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.softApricot, width: 1),
                        ),
                        child: Text(
                          'Rantai Terputus',
                          style: AppText.caption(color: AppColors.softApricot).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (verificationResult != null && verificationResult.isValid)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: AppColors.sageGreen,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                formattedDate,
                style: AppText.caption(
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),

          // Judul Buku / Pesan Genesis
          Text(
            title,
            style: AppText.cardHeading(
              color: isDark ? AppColors.inkDark : AppColors.ink,
            ),
          ),
          if (authors != null && authors.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              authors,
              style: AppText.metadata(
                color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
              ),
            ),
          ],
          if (rating != null && rating > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: List.generate(
                5,
                (idx) => Icon(
                  idx < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 16,
                  color: AppColors.softApricot,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.m),

          // Hash Details Grid Singkat
          _buildHashRow(
            'Hash',
            '$shortHash... (${block.hash})',
            isDark,
            isHighlight: true,
            textColor: isFirstBroken ? AppColors.error : null,
          ),
          const SizedBox(height: 4),
          _buildHashRow('Prev Hash', '$shortPrev... (${block.previousHash})', isDark),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _buildHashRow('Nonce', '${block.nonce}', isDark)),
              Expanded(
                child: _buildHashRow(
                  'PoW Status',
                  'Valid (${LedgerService.targetPrefix})',
                  isDark,
                  textColor: AppColors.sageGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Ketuk untuk rincian lengkap',
                style: AppText.caption(
                  color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 10,
                color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHashRow(
    String label,
    String value,
    bool isDark, {
    bool isHighlight = false,
    Color? textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.caption(
            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.code(
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            color: textColor ?? (isDark ? AppColors.inkDark : AppColors.ink),
          ),
        ),
      ],
    );
  }
}
