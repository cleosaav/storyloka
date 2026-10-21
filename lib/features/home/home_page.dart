import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/book_widgets.dart';
import '../../core/widgets/demo_widgets.dart';
import '../../core/widgets/progress_and_badge.dart';
import '../../data/models/user_book.dart';
import '../../data/repositories/library_repository.dart';
import '../auth/auth_controller.dart';

/// Halaman Home — PRD §7.2, §7.5, & §13.0 Fase A3.
/// Menampilkan Header sapaan, Reading Summary (Koleksi, Sedang dibaca, Selesai),
/// Currently Reading (2 kondisi), My Collection (3 cover terbaru), My Wishlist (3 cover terbaru),
/// dan "See all →" yang mengarahkan ke Library dengan filter yang tepat.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  String? _errorMessage;

  List<UserBook> _collectionBooks = [];
  List<UserBook> _wishlistBooks = [];
  UserBook? _currentlyReading;

  int _collectionCount = 0;
  int _readingCount = 0;
  int _finishedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final library = context.read<LibraryRepository>();
      final allBooks = await library.getBooks();
      final currentReading = await library.getCurrentlyReading();

      if (!mounted) return;

      final activeBooks = allBooks.where((b) => !b.isDeleted).toList();

      final collection = activeBooks
          .where((b) => b.listType == ListType.collection)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      final wishlist = activeBooks
          .where((b) => b.listType == ListType.wishlist)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      final colCount = collection.length;
      final readCount = collection.where((b) => b.status == BookStatus.reading).length;
      final finCount = collection.where((b) => b.status == BookStatus.finished).length;

      setState(() {
        _collectionBooks = collection;
        _wishlistBooks = wishlist;
        _currentlyReading = currentReading;
        _collectionCount = colCount;
        _readingCount = readCount;
        _finishedCount = finCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data Home.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authController = context.watch<AuthController>();
    final userName = authController.currentUser?.name.trim().isNotEmpty == true
        ? authController.currentUser!.name.trim()
        : 'Reader';

    final initialLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'R';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'StoryLoka',
          style: AppText.pageHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.l),
            child: Center(child: DemoModeChip()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _buildBody(isDark, userName, initialLetter),
      ),
    );
  }

  Widget _buildBody(bool isDark, String userName, String initialLetter) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.deepTeal),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: isDark ? AppColors.mutedDark : AppColors.error,
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                _errorMessage!,
                style: AppText.cardHeading(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.l),
              PrimaryButton(
                label: 'Coba Lagi',
                onPressed: _loadData,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageMargin,
        vertical: AppSpacing.m,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header sapaan: Hello, {nama}! + Avatar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $userName!',
                      style: AppText.pageHeading(
                        color: isDark ? AppColors.inkDark : AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mau baca apa hari ini?',
                      style: AppText.body(
                        color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              // Avatar profil (tap -> tab Profile)
              Semantics(
                button: true,
                label: 'Buka Profil',
                child: InkWell(
                  onTap: () {
                    context.go('/profile');
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.softApricot,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initialLetter,
                      style: AppText.sectionHeading(
                        color: AppColors.ink,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // 2. Card Reading Summary (3 angka: Koleksi, Sedang dibaca, Selesai)
          _buildReadingSummaryCard(isDark),
          const SizedBox(height: AppSpacing.xxl),

          // 3. Card Currently Reading (2 kondisi: kosong atau ada)
          _buildCurrentlyReadingSection(isDark),
          const SizedBox(height: AppSpacing.xxl),

          // 4. Card My Collection (Header + See all + 3 cover terbaru)
          _buildCollectionSection(isDark),
          const SizedBox(height: AppSpacing.xxl),

          // 5. Card My Wishlist (Header + See all + 3 cover terbaru)
          _buildWishlistSection(isDark),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  /// Card Reading Summary — PRD §7.2 butir 2.
  Widget _buildReadingSummaryCard(bool isDark) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.l,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              count: _collectionCount,
              label: 'Koleksi',
              isDark: isDark,
            ),
          ),
          Container(
            height: 40,
            width: 1,
            color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
          ),
          Expanded(
            child: _buildSummaryItem(
              count: _readingCount,
              label: 'Sedang dibaca',
              isDark: isDark,
            ),
          ),
          Container(
            height: 40,
            width: 1,
            color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
          ),
          Expanded(
            child: _buildSummaryItem(
              count: _finishedCount,
              label: 'Selesai',
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required int count,
    required String label,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: AppText.pageHeading(
            color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppText.caption(
            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Card Currently Reading — PRD §7.2 butir 3 & §7.4.
  Widget _buildCurrentlyReadingSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Currently Reading',
          style: AppText.sectionHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        if (_currentlyReading == null) ...[
          // Kondisi 1: Kosong
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.sageGreen.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_stories_outlined,
                    color: AppColors.deepTeal,
                    size: 28,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                Text(
                  'Start Your Reading Journey',
                  style: AppText.cardHeading(
                    color: isDark ? AppColors.inkDark : AppColors.ink,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Your next favorite book is waiting for you.',
                  style: AppText.caption(
                    color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.l),
                PrimaryButton(
                  label: 'Add Book',
                  icon: Icons.add_rounded,
                  onPressed: () {
                    context.go('/add');
                  },
                ),
              ],
            ),
          ),
        ] else ...[
          // Kondisi 2: Ada buku yang sedang dibaca
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover min 80x120
                    BookCover(
                      coverUrl: _currentlyReading!.coverUrl,
                      width: 80,
                      height: 120,
                      borderRadius: 10,
                    ),
                    const SizedBox(width: AppSpacing.l),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentlyReading!.title,
                            style: AppText.cardHeading(
                              color: isDark ? AppColors.inkDark : AppColors.ink,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_currentlyReading!.authors != null &&
                              _currentlyReading!.authors!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _currentlyReading!.authors!,
                              style: AppText.caption(
                                color: isDark
                                    ? AppColors.mutedDark
                                    : AppColors.mutedGray,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.m),
                          ReadingProgressBar(
                            currentPage: _currentlyReading!.currentPage,
                            totalPages: _currentlyReading!.pageCount ?? 0,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.l),
                // Tombol Read dan Update
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'Read',
                        icon: Icons.play_arrow_rounded,
                        onPressed: () {
                          context.push('/reading/timer/${_currentlyReading!.id}');
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: SecondaryButton(
                        label: 'Update',
                        icon: Icons.edit_note_rounded,
                        onPressed: () {
                          context.push('/reading/progress/${_currentlyReading!.id}');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Card My Collection — PRD §7.2 butir 4 & §7.5.
  Widget _buildCollectionSection(bool isDark) {
    final recentBooks = _collectionBooks.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'My Collection',
                style: AppText.sectionHeading(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () {
                context.go('/library?filter=collection');
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See all',
                    style: AppText.button(
                      color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        if (recentBooks.isEmpty) ...[
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Belum ada buku di koleksi Anda.',
                    style: AppText.body(
                      color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                PrimaryButton(
                  label: 'Add Book',
                  onPressed: () => context.go('/add'),
                ),
              ],
            ),
          ),
        ] else ...[
          // Deretan 3 cover terbaru (cover saja, rasio 2:3)
          Row(
            children: List.generate(3, (index) {
              if (index < recentBooks.length) {
                final book = recentBooks[index];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index < 2 ? AppSpacing.m : 0,
                    ),
                    child: InkWell(
                      onTap: () async {
                        await context.push('/book/collection/${book.id}');
                        if (mounted) _loadData();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: BookCover(
                        coverUrl: book.coverUrl,
                        width: double.infinity,
                        borderRadius: 12,
                      ),
                    ),
                  ),
                );
              } else {
                return const Expanded(child: SizedBox());
              }
            }),
          ),
        ],
      ],
    );
  }

  /// Card My Wishlist — PRD §7.2 butir 5 & §7.5.
  Widget _buildWishlistSection(bool isDark) {
    final recentBooks = _wishlistBooks.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'My Wishlist',
                style: AppText.sectionHeading(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () {
                context.go('/library?filter=wishlist');
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See all',
                    style: AppText.button(
                      color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        if (recentBooks.isEmpty) ...[
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Wishlist Anda masih kosong.',
                    style: AppText.body(
                      color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                PrimaryButton(
                  label: 'Add Book',
                  onPressed: () => context.go('/add'),
                ),
              ],
            ),
          ),
        ] else ...[
          // Deretan 3 cover terbaru (cover saja, rasio 2:3)
          Row(
            children: List.generate(3, (index) {
              if (index < recentBooks.length) {
                final book = recentBooks[index];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index < 2 ? AppSpacing.m : 0,
                    ),
                    child: InkWell(
                      onTap: () async {
                        await context.push('/book/wishlist/${book.id}');
                        if (mounted) _loadData();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: BookCover(
                        coverUrl: book.coverUrl,
                        width: double.infinity,
                        borderRadius: 12,
                      ),
                    ),
                  ),
                );
              } else {
                return const Expanded(child: SizedBox());
              }
            }),
          ),
        ],
      ],
    );
  }
}
