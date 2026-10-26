import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/book_widgets.dart';
import '../../core/widgets/progress_and_badge.dart';
import '../../core/widgets/responsive_body.dart';
import '../../data/models/user_book.dart';
import '../../data/repositories/library_repository.dart';

/// Halaman Library — PRD §7.6 & §13.0 Fase A3.
/// Mendukung search lokal (judul/penulis), toggle Collection | Wishlist (menghormati query ?filter=),
/// StatusBadge, empty state per filter, serta hapus dengan konfirmasi via long-press.
class LibraryPage extends StatefulWidget {
  final String? filter;

  const LibraryPage({super.key, this.filter});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late int _selectedTab; // 0: Collection, 1: Wishlist
  final TextEditingController _searchController = TextEditingController();

  List<UserBook> _allBooks = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedTab = (widget.filter?.toLowerCase() == 'wishlist') ? 1 : 0;
    _loadBooks();
  }

  @override
  void didUpdateWidget(covariant LibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filter != oldWidget.filter) {
      final newIndex = (widget.filter?.toLowerCase() == 'wishlist') ? 1 : 0;
      if (newIndex != _selectedTab) {
        setState(() {
          _selectedTab = newIndex;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final library = context.read<LibraryRepository>();
      final books = await library.getBooks();
      if (!mounted) return;

      setState(() {
        _allBooks = books;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat buku di Library.';
      });
    }
  }

  Future<void> _deleteBook(UserBook book) async {
    final isCollection = book.listType == ListType.collection;
    final listLabel = isCollection ? 'Koleksi' : 'Wishlist';

    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: 'Hapus dari $listLabel?',
      message: 'Apakah Anda yakin ingin menghapus "${book.title}" dari $listLabel Anda?',
      confirmLabel: 'Hapus',
      cancelLabel: 'Batal',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      try {
        final library = context.read<LibraryRepository>();
        await library.deleteBook(book.id);
        if (!mounted) return;

        AppSnackBar.show(
          context,
          message: 'Buku berhasil dihapus dari $listLabel',
          type: SnackBarType.info,
        );

        // Refresh data
        _loadBooks();
      } catch (e) {
        if (!mounted) return;
        AppSnackBar.show(
          context,
          message: 'Gagal menghapus buku: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  List<UserBook> get _currentList {
    final targetType = _selectedTab == 0 ? ListType.collection : ListType.wishlist;
    var list = _allBooks.where((b) => b.listType == targetType && !b.isDeleted).toList();

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((b) {
        final titleMatch = b.title.toLowerCase().contains(q);
        final authorMatch = b.authors?.toLowerCase().contains(q) ?? false;
        return titleMatch || authorMatch;
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Library',
          style: AppText.pageHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
      ),
      body: ResponsiveBody(
        child: RefreshIndicator(
          onRefresh: _loadBooks,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Bar & Filter Tabs
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.s,
                ),
                child: Column(
                children: [
                  AppTextField(
                    controller: _searchController,
                    hintText: 'Cari judul atau penulis di library...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            tooltip: 'Hapus teks pencarian',
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),
                  FilterTabs(
                    tabs: const ['Collection', 'Wishlist'],
                    selectedIndex: _selectedTab,
                    onTabSelected: (index) {
                      setState(() {
                        _selectedTab = index;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s),

            // Konten Grid / State
            Expanded(
              child: _buildContent(isDark),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.deepTeal),
      );
    }

    if (_errorMessage != null) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                      onPressed: _loadBooks,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final books = _currentList;

    // Empty state
    if (books.isEmpty) {
      final isCollection = _selectedTab == 0;
      final isSearching = _searchQuery.trim().isNotEmpty;

      if (isSearching) {
        return LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 56,
                        color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                      ),
                      const SizedBox(height: AppSpacing.m),
                      Text(
                        'Buku tidak ditemukan',
                        style: AppText.sectionHeading(
                          color: isDark ? AppColors.inkDark : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      Text(
                        'Tidak ada buku yang cocok dengan "$_searchQuery".',
                        style: AppText.body(
                          color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Empty collection / wishlist
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: EmptyStateCard(
                  icon: isCollection
                      ? Icons.collections_bookmark_outlined
                      : Icons.bookmark_border_rounded,
                  title: isCollection ? 'Koleksi Masih Kosong' : 'Wishlist Masih Kosong',
                  message: isCollection
                      ? 'Tambahkan buku yang sedang atau pernah Anda baca ke dalam koleksi Anda.'
                      : 'Simpan buku yang ingin Anda baca di kemudian hari ke daftar wishlist.',
                  actionLabel: 'Add Book',
                  onAction: () {
                    context.go('/add');
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }

    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final baseRatio = _selectedTab == 0 ? 0.44 : 0.52;
    final childAspectRatio = textScale > 1.0
        ? baseRatio / (1.0 + (textScale - 1.0) * 0.85)
        : baseRatio;

    // Grid 3 kolom
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.m,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: AppSpacing.m,
        mainAxisSpacing: AppSpacing.l,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final isCollection = _selectedTab == 0;

        return BookGridCard(
          title: book.title,
          authors: book.authors,
          coverUrl: book.coverUrl,
          rating: book.rating,
          statusBadge: isCollection ? StatusBadge(status: book.status) : null,
          onTap: () async {
            if (isCollection) {
              await context.push('/book/collection/${book.id}');
            } else {
              await context.push('/book/wishlist/${book.id}');
            }
            // Muat ulang data sekembalinya dari halaman detail
            if (mounted) {
              _loadBooks();
            }
          },
          onLongPress: () {
            _deleteBook(book);
          },
        );
      },
    );
  }
}
