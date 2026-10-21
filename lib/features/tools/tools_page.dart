import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../data/repositories/score_repository.dart';

/// Halaman Tools — 5 card vertikal sesuai PRD §7.7.
///
/// Urutan: Kesan & Pesan, AI Chat, Mini Games (Snake), Konversi Mata Uang, Konversi Waktu.
class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  int _snakeHighScore = 0;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
  }

  Future<void> _loadHighScore() async {
    try {
      final repo = context.read<ScoreRepository>();
      final hs = await repo.getHighScore('snake');
      if (mounted) setState(() => _snakeHighScore = hs);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tools = [
      _ToolCard(
        id: 'feedback',
        icon: Icons.favorite_outline_rounded,
        iconColor: AppColors.softApricot,
        title: 'Kesan & Pesan',
        description: 'Bagikan kesan dan pesanmu tentang mata kuliah Pemrograman Aplikasi Mobile.',
        route: '/tools/feedback',
        isDark: isDark,
      ),
      _ToolCard(
        id: 'ai_chat',
        icon: Icons.auto_awesome_rounded,
        iconColor: AppColors.deepTeal,
        title: 'AI Chat',
        description: 'Tanya rekomendasi buku, tips membaca, dan tema literatur bersama asisten AI.',
        route: '/tools/ai-chat',
        isDark: isDark,
      ),
      _ToolCard(
        id: 'snake',
        icon: Icons.sports_esports_rounded,
        iconColor: AppColors.sageGreen,
        title: 'Mini Games — Book Snake',
        description: _snakeHighScore > 0
            ? 'Best: ${_snakeHighScore ~/ 10} buku 🏆 Kumpulkan buku sebanyak mungkin!'
            : 'Kumpulkan buku sebanyak mungkin!',
        route: '/tools/games',
        isDark: isDark,
      ),
      _ToolCard(
        id: 'currency',
        icon: Icons.currency_exchange_rounded,
        iconColor: AppColors.oceanTeal,
        title: 'Konversi Mata Uang',
        description: 'Konversi IDR, USD, EUR, JPY, SGD secara instan.',
        route: '/tools/currency',
        isDark: isDark,
      ),
      _ToolCard(
        id: 'time',
        icon: Icons.schedule_rounded,
        iconColor: AppColors.mutedGray,
        title: 'Konversi Waktu',
        description: 'Konversi waktu antara WIB, WITA, WIT, dan London (GMT/BST).',
        route: '/tools/time',
        isDark: isDark,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tools',
          style: AppText.pageHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.deepTeal,
        onRefresh: _loadHighScore,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
            vertical: AppSpacing.m,
          ),
          itemCount: tools.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.m),
          itemBuilder: (ctx, i) => tools[i],
        ),
      ),
    );
  }
}

// ─── Tool Card ────────────────────────────────────────────────────────────────

class _ToolCard extends StatelessWidget {
  final String id;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String route;
  final bool isDark;

  const _ToolCard({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.route,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppColors.surfaceDark : AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        onTap: () => context.push(route),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.l),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
            ),
          ),
          child: Row(
            children: [
              // Ikon bulat
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: AppSpacing.l),
              // Judul + deskripsi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                      style: AppText.cardHeading(
                        color: isDark ? AppColors.inkDark : AppColors.ink,
                      )),
                    const SizedBox(height: 4),
                    Text(description,
                      style: AppText.caption(
                        color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
