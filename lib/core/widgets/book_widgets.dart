import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_card.dart';

/// BookCover — rasio 2:3, tidak boleh diregangkan.
/// Placeholder sage + icon buku jika cover tidak ada atau gagal dimuat (PRD §4.5, design-system.md §5).
class BookCover extends StatelessWidget {
  final String? coverUrl;
  final double width;
  final double? height;
  final double borderRadius;

  const BookCover({
    super.key,
    required this.coverUrl,
    this.width = 80,
    this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final hasFiniteWidth = width.isFinite;
    final calculatedHeight = height ?? (hasFiniteWidth ? (width * 3 / 2) : null);

    Widget imageContent = AspectRatio(
      aspectRatio: 2 / 3,
      child: coverUrl != null && coverUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: coverUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildPlaceholder(),
              errorWidget: (context, url, error) => _buildPlaceholder(),
            )
          : _buildPlaceholder(),
    );

    if (hasFiniteWidth || calculatedHeight != null) {
      imageContent = SizedBox(
        width: hasFiniteWidth ? width : null,
        height: calculatedHeight,
        child: imageContent,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: imageContent,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.sageGreen.withValues(alpha: 0.35),
      child: const Center(
        child: Icon(
          Icons.menu_book_outlined,
          color: AppColors.deepTeal,
          size: 28,
        ),
      ),
    );
  }
}

/// BookCard — cover, judul (max 2 baris Fraunces), penulis (DM Sans),
/// rating bintang jika ada, dan status badge jika relevan.
class BookCard extends StatelessWidget {
  final String title;
  final String? authors;
  final String? coverUrl;
  final int? rating;
  final Widget? statusBadge;
  final VoidCallback? onTap;
  final double coverWidth;

  const BookCard({
    super.key,
    required this.title,
    this.authors,
    this.coverUrl,
    this.rating,
    this.statusBadge,
    this.onTap,
    this.coverWidth = 72,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookCover(
            coverUrl: coverUrl,
            width: coverWidth,
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.cardHeading(
                    color: isDark ? AppColors.inkDark : AppColors.ink,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (authors != null && authors!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    authors!,
                    style: AppText.metadata(
                      color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (rating != null && rating! > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Semantics(
                    label: 'Rating $rating dari 5 bintang',
                    child: Row(
                      children: List.generate(
                        5,
                        (index) => Icon(
                          index < rating! ? Icons.star : Icons.star_border,
                          size: 16,
                          color: AppColors.softApricot,
                        ),
                      ),
                    ),
                  ),
                ],
                if (statusBadge != null) ...[
                  const SizedBox(height: AppSpacing.s),
                  statusBadge!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// BookGridCard — Kartu buku vertikal untuk tampilan grid 3-kolom (PRD §7.3 & §7.6).
class BookGridCard extends StatelessWidget {
  final String title;
  final String? authors;
  final String? coverUrl;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final int? rating;
  final Widget? statusBadge;

  const BookGridCard({
    super.key,
    required this.title,
    this.authors,
    this.coverUrl,
    this.onTap,
    this.onLongPress,
    this.rating,
    this.statusBadge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final semanticsLabel = 'Buku $title${authors != null && authors!.isNotEmpty ? ' oleh $authors' : ''}${rating != null && rating! > 0 ? ', rating $rating dari 5 bintang' : ''}';

    return Semantics(
      label: semanticsLabel,
      button: true,
      onLongPress: onLongPress,
      onLongPressHint: onLongPress != null ? 'Hapus buku' : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Buku rasio 2:3
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: BookCover(
                  coverUrl: coverUrl,
                  width: double.infinity,
                  borderRadius: 10,
                ),
              ),
            ),
            // Judul buku max 2 baris (Fraunces — design-system.md §3)
            Text(
              title,
              style: AppText.gridBookTitle(
                color: isDark ? AppColors.inkDark : AppColors.ink,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (authors != null && authors!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                authors!,
                style: AppText.caption(
                  color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (rating != null && rating! > 0) ...[
              const SizedBox(height: 2),
              Semantics(
                label: 'Rating $rating dari 5 bintang',
                child: Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < rating! ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 12,
                      color: AppColors.softApricot,
                    ),
                  ),
                ),
              ),
            ],
            if (statusBadge != null) ...[
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: statusBadge!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// GenreChip — pill kecil warna sage/apricot untuk genre buku (PRD §7.3).
class GenreChip extends StatelessWidget {
  final String genre;

  const GenreChip({super.key, required this.genre});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.softApricot : AppColors.sageGreen)
            .withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        genre,
        style: AppText.caption(
          color: isDark ? AppColors.softApricot : AppColors.deepTeal,
        ).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

