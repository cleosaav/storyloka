import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/ledger_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/ledger_block.dart';
import '../../data/repositories/ledger_repository.dart';
import '../auth/auth_controller.dart';

/// Halaman Reading Ledger (Blockchain Sederhana) — PRD §10.2.
///
/// CATATAN JUJUR ARSITEKTUR:
/// Ini merupakan simulasi edukatif single-node untuk mencatat buku yang selesai
/// dibaca ke dalam rantai blok terhubung lewat cryptographic hash (SHA-256) dan
/// Proof of Work berawalan "00", bukan jaringan peer-to-peer terdesentralisasi nyata.
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
      final ledgerService = context.read<LedgerService>();
      final ledgerRepo = context.read<LedgerRepository>();
      final authController = context.read<AuthController>();
      final userId = authController.currentUser?.id ?? 'demo_user';

      // Pastikan genesis block ada
      await ledgerService.ensureGenesisBlock(userId);

      final blocks = await ledgerRepo.getBlocks();
      if (mounted) {
        setState(() {
          _blocks = blocks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat rantai ledger: $e';
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
      _isVerifying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reading Ledger',
          style: AppText.pageHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: context.primaryColor,
        onRefresh: _loadBlocks,
        child: _buildBody(isDark),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: context.primaryColor),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.m),
              Text(_errorMessage!, textAlign: TextAlign.center, style: AppText.body()),
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

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageMargin,
        vertical: AppSpacing.m,
      ),
      children: [
        // 1. Header Penjelas Singkat
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
                size: 28,
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buku Selesai Terenkripsi',
                      style: AppText.cardHeading(
                        color: isDark ? AppColors.inkDark : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Catatan buku yang selesai kamu baca, saling terhubung lewat cryptographic hash SHA-256 dan Proof of Work.',
                      style: AppText.body(
                        color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      'ℹ️ Simulasi edukatif single-node, bukan jaringan terdesentralisasi.',
                      style: AppText.caption(
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

        // 2. Tombol & Status Verifikasi Ledger
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Verifikasi Keutuhan Rantai',
                      style: AppText.cardHeading(
                        color: isDark ? AppColors.inkDark : AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Text(
                    '${_blocks.length} Blok',
                    style: AppText.metadata(
                      color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                    ),
                  ),
                ],
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

        // 3. Section Title
        Text(
          'Daftar Blok Rantai',
          style: AppText.sectionHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.m),

        // 4. Empty state jika hanya ada genesis block
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
                    'Selesaikan buku pertamamu untuk menambah blok riwayat baca ke dalam rantai.',
                    style: AppText.body(
                      color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 5. Daftar Kartu Blok Blockchain
        for (int i = 0; i < _blocks.length; i++) ...[
          _buildBlockCard(_blocks[i], isDark),
          if (i < _blocks.length - 1)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Container(width: 2, height: 10, color: AppColors.sageGreen),
                    const Icon(Icons.link_rounded, size: 20, color: AppColors.deepTeal),
                    Container(width: 2, height: 10, color: AppColors.sageGreen),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
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
            size: 26,
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isValid ? '✔ Rantai Valid' : '✖ Blok #${result.invalidIndex} Tidak Valid',
                  style: AppText.cardHeading(color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  isValid
                      ? 'Seluruh ${_blocks.length} blok terverifikasi utuh, hash cocok, dan tidak dimodifikasi.'
                      : result.reason ?? 'Terjadi kesalahan pada rantai hash.',
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

  Widget _buildBlockCard(LedgerBlock block, bool isDark) {
    final isGenesis = block.blockIndex == 0;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row Header: Chip Indeks + Tanggal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
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

          // Hash Details Grid
          _buildHashRow('Hash', '$shortHash... (${block.hash})', isDark, isHighlight: true),
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
            fontSize: 12,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            color: textColor ?? (isDark ? AppColors.inkDark : AppColors.ink),
          ),
        ),
      ],
    );
  }
}
