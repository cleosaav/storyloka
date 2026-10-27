import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/repositories/feedback_repository.dart';
import '../../../data/static/team_feedback.dart';

/// Halaman Kesan & Pesan Mata Kuliah Pemrograman Aplikasi Mobile (PAM).
///
/// Halaman ini bersifat BACA SAJA (Read-Only) yang menampilkan kesan dan pesan
/// dari 3 anggota kelompok pengembang StoryLoka.
/// Data bersumber statis dari [teamFeedbacks] dan tidak dapat diubah oleh pengguna.
class FeedbackPage extends StatelessWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.inkDark : AppColors.ink;
    final canvasBg = isDark ? AppColors.bgDark : AppColors.warmIvory;

    // Ambil data dari repository jika tersedia, atau langsung fallback ke teamFeedbacks
    FeedbackRepository? repo;
    try {
      repo = context.read<FeedbackRepository>();
    } catch (_) {
      repo = null;
    }

    return Scaffold(
      backgroundColor: canvasBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Kesan & Pesan',
          style: AppText.sectionHeading(color: textColor),
        ),
      ),
      body: repo == null
          ? _FeedbackContent(items: teamFeedbacks)
          : FutureBuilder<List<TeamFeedback>>(
              future: repo.getAll(),
              initialData: teamFeedbacks,
              builder: (context, snapshot) {
                final list = snapshot.data ?? teamFeedbacks;
                return _FeedbackContent(items: list);
              },
            ),
    );
  }
}

class _FeedbackContent extends StatelessWidget {
  final List<TeamFeedback> items;

  const _FeedbackContent({required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.inkDark : AppColors.ink;
    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedGray;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.deepTeal;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: AppSpacing.m,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Pengantar
          Semantics(
            container: true,
            label: 'Pengantar kesan dan pesan tim StoryLoka',
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark
                    : AppColors.sageGreen.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderDark
                      : AppColors.sageGreen.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.format_quote_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kesan dan pesan dari kelompok kami untuk mata kuliah Pemrograman Aplikasi Mobile.',
                          style: AppText.bodyMedium(color: textColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'StoryLoka — Kelompok Pengembang PAM',
                          style: AppText.caption(color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // Tepat 3 Kartu Anggota Tim
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.l),
              child: _TeamMemberCard(
                item: item,
                index: index,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  final TeamFeedback item;
  final int index;

  const _TeamMemberCard({
    required this.item,
    required this.index,
  });

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'SL';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _getAvatarBg(int idx, bool isDark) {
    final colorsLight = [
      AppColors.deepTeal,
      AppColors.softApricot,
      AppColors.sageGreen,
    ];
    final colorsDark = [
      AppColors.primaryDark,
      AppColors.softApricot,
      AppColors.sageGreen,
    ];
    final palette = isDark ? colorsDark : colorsLight;
    return palette[idx % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.inkDark : AppColors.ink;
    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedGray;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.deepTeal;
    final avatarBg = _getAvatarBg(index, isDark);
    final initials = _getInitials(item.name);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Identitas Anggota
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Semantics(
                  label: 'Avatar ${item.name}',
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: avatarBg,
                    child: Text(
                      initials,
                      style: AppText.cardHeading(
                        color: isDark ? AppColors.bgDark : AppColors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: AppText.cardHeading(color: textColor),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.surfaceDark
                                  : AppColors.palePeach,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusS),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.borderDark
                                    : AppColors.softApricot.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'NIM: ${item.nim}',
                              style: AppText.caption(
                                color: isDark
                                    ? AppColors.softApricot
                                    : AppColors.ink,
                              ),
                            ),
                          ),
                          if (item.role != null && item.role!.isNotEmpty)
                            Text(
                              item.role!,
                              style: AppText.caption(color: mutedColor),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
            ),
            const SizedBox(height: AppSpacing.m),

            // Bagian Kesan
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.sentiment_satisfied_alt_rounded,
                  size: 18,
                  color: primaryColor,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Kesan',
                  style: AppText.bodyMedium(
                    color: primaryColor,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.impression,
              style: AppText.body(color: textColor),
              softWrap: true,
            ),
            const SizedBox(height: AppSpacing.m),

            // Bagian Pesan
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: isDark ? AppColors.softApricot : AppColors.softApricot,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Pesan',
                  style: AppText.bodyMedium(
                    color: AppColors.softApricot,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.suggestion,
              style: AppText.body(color: textColor),
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }
}
