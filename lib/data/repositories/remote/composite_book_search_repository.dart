import 'dart:async';

import 'package:flutter/foundation.dart';

import '../book_search_repository.dart';
import 'google_books_repository.dart';
import 'open_library_repository.dart';

/// Entri cache pencarian di memori dengan masa berlaku (TTL).
class SearchCacheEntry {
  final List<BookSearchResult> results;
  final DateTime timestamp;

  SearchCacheEntry(this.results, this.timestamp);

  bool get isExpired =>
      DateTime.now().difference(timestamp) >= const Duration(minutes: 5);
}

/// Implementasi hibrida BookSearchRepository — Fase R2.
/// Mencoba Google Books API terlebih dahulu; jika gagal (429/5xx/timeout) atau hasil kosong,
/// melakukan fallback ke Open Library.
/// Menggabungkan hasil tanpa duplikat (kunci ISBN-13 atau judul+penulis).
/// Harga HANYA dari Google saleInfo; jika tidak ada bernilai null (tampil "Harga tidak tersedia").
class CompositeBookSearchRepository implements GoogleBooksRepository {
  final GoogleBooksRepository googleRepo;
  final OpenLibraryRepository openLibraryRepo;
  final Duration cacheDuration;
  final Map<String, SearchCacheEntry> _cache = {};

  CompositeBookSearchRepository({
    GoogleBooksRepository? googleRepo,
    OpenLibraryRepository? openLibraryRepo,
    this.cacheDuration = const Duration(minutes: 5),
  })  : googleRepo = googleRepo ?? GoogleBooksRepository(),
        openLibraryRepo = openLibraryRepo ?? OpenLibraryRepository();

  final Map<String, GoogleBooksDetailCacheEntry> _detailCache = {};

  /// Jumlah entri aktif di cache memori.
  int get cacheSize => _cache.length;

  @override
  int get detailCacheSize => _detailCache.length;

  /// Bersihkan seluruh cache pencarian di memori.
  void clearCache() {
    _cache.clear();
    clearDetailCache();
  }

  @override
  void clearDetailCache() {
    _detailCache.clear();
    googleRepo.clearDetailCache();
  }

  /// Ambil entri cache untuk pengujian.
  SearchCacheEntry? getCacheEntry(String key) => _cache[key];

  @override
  Future<BookSearchResult?> getDetail(String googleBooksId) async {
    final cleanId = googleBooksId.trim();
    if (cleanId.isEmpty) return null;

    final cached = _detailCache[cleanId];
    if (cached != null && !cached.isExpired) {
      if (kDebugMode) {
        debugPrint('[CompositeBookSearch] Detail cache HIT untuk id "$cleanId"');
      }
      return cached.detail;
    }

    BookSearchResult? detail;
    bool googleFailed = false;

    try {
      detail = await googleRepo.getDetail(cleanId);
    } catch (e) {
      googleFailed = true;
      if (kDebugMode) {
        debugPrint('[CompositeBookSearch] Google getDetail gagal ($e)');
      }
    }

    // Jika googleRepo berhasil dan mengembalikan detail:
    if (detail != null) {
      // Rantai pengayaan Open Library bila masih kosong — Fase S3
      final needsSynopsis =
          detail.synopsis == null || detail.synopsis!.trim().isEmpty;
      final needsPageCount =
          detail.pageCount == null || detail.pageCount! <= 0;
      final needsGenre = detail.genre == null || detail.genre!.trim().isEmpty;

      if ((needsSynopsis || needsPageCount || needsGenre) &&
          detail.isbn != null &&
          detail.isbn!.trim().isNotEmpty) {
        try {
          final olBook = await openLibraryRepo.lookupIsbn(detail.isbn!);
          if (olBook != null) {
            String? enrichedSynopsis = detail.synopsis;
            String? enrichedSource = detail.synopsisSource;

            if (needsSynopsis) {
              if (olBook.synopsis != null &&
                  olBook.synopsis!.trim().isNotEmpty) {
                enrichedSynopsis = olBook.synopsis;
                enrichedSource = 'Open Library';
              } else if (olBook.googleBooksId.contains('OL') ||
                  olBook.googleBooksId.startsWith('/works/')) {
                // Coba ambil dari works jika ada id karya
                final workSynopsis = await openLibraryRepo
                    .fetchWorkSynopsis(olBook.googleBooksId);
                if (workSynopsis != null && workSynopsis.trim().isNotEmpty) {
                  enrichedSynopsis = workSynopsis;
                  enrichedSource = 'Open Library';
                }
              }
            }

            detail = detail.copyWith(
              pageCount: needsPageCount ? olBook.pageCount : detail.pageCount,
              genre: needsGenre ? olBook.genre : detail.genre,
              synopsis: enrichedSynopsis,
              synopsisSource: enrichedSource,
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[CompositeBookSearch] Open Library enrichment gagal: $e');
          }
        }
      }
    } else if (googleFailed) {
      // Jika Google gagal (mis. kuota habis/timeout), coba cek apakah cleanId bisa dicari via Open Library
      try {
        final cleanIsbn = cleanId.replaceAll(RegExp(r'[\s\-]'), '');
        final olBook = await openLibraryRepo.lookupIsbn(cleanIsbn);
        if (olBook != null) {
          detail = olBook.copyWith(synopsisSource: 'Open Library');
        }
      } catch (_) {}
    }

    if (detail != null) {
      _detailCache[cleanId] =
          GoogleBooksDetailCacheEntry(detail, DateTime.now());
    }

    return detail;
  }

  @override
  Future<List<BookSearchResult>> search(
    String query, {
    String filter = 'title',
    int maxResults = 20,
    int? startIndex,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // 5. Cache hasil pencarian terakhir di memori selama 5 menit — Fase R2
    final cacheKey =
        '$filter:${cleanQuery.toLowerCase()}:$maxResults:${startIndex ?? 0}';
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      if (kDebugMode) {
        debugPrint(
            '[CompositeBookSearch] Cache HIT untuk "$cleanQuery" (${cached.results.length} buku)');
      }
      return cached.results;
    }

    List<BookSearchResult> results = [];

    if (filter == 'isbn') {
      // 4. Scan barcode: cari ISBN di Google, jika kosong coba Open Library — Fase R2
      try {
        final googleBooks = await googleRepo.search(
          cleanQuery,
          filter: 'isbn',
          maxResults: maxResults,
          startIndex: startIndex,
        );

        if (googleBooks.isNotEmpty) {
          results = googleBooks;
        } else {
          if (kDebugMode) {
            debugPrint(
                '[CompositeBookSearch] ISBN tidak ada di Google Books, mencoba Open Library...');
          }
          results = await openLibraryRepo.search(
            cleanQuery,
            filter: 'isbn',
            maxResults: maxResults,
            startIndex: startIndex,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              '[CompositeBookSearch] Google Books error pada ISBN ($e), fallback ke Open Library...');
        }
        results = await openLibraryRepo.search(
          cleanQuery,
          filter: 'isbn',
          maxResults: maxResults,
          startIndex: startIndex,
        );
      }
    } else {
      // 3. Pencarian umum: coba Google dulu; jika gagal (429/5xx/timeout) atau hasil kosong, fallback ke Open Library
      List<BookSearchResult> googleBooks = [];
      bool googleFailed = false;

      try {
        googleBooks = await googleRepo.search(
          cleanQuery,
          filter: filter,
          maxResults: maxResults,
          startIndex: startIndex,
        );
      } catch (e) {
        googleFailed = true;
        if (kDebugMode) {
          debugPrint(
              '[CompositeBookSearch] Google Books search gagal ($e), fallback ke Open Library...');
        }
      }

      if (googleFailed || googleBooks.isEmpty) {
        try {
          results = await openLibraryRepo.search(
            cleanQuery,
            filter: filter,
            maxResults: maxResults,
            startIndex: startIndex,
          );
        } catch (e) {
          if (googleFailed) {
            // Jika kedua sumber gagal, teruskan pesan ramah pengguna
            rethrow;
          }
          results = [];
        }
      } else {
        results = googleBooks;
      }
    }

    // Deduplikasi hasil
    final deduplicated = deduplicateBooks(results);

    // Simpan di cache memori (berlaku 5 menit)
    _cache[cacheKey] = SearchCacheEntry(deduplicated, DateTime.now());

    return deduplicated;
  }

  @override
  Future<BookSearchResult?> randomBook() async {
    try {
      final book = await googleRepo.randomBook();
      if (book != null) return book;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CompositeBookSearch] Google randomBook error: $e');
      }
    }

    // Fallback ke Open Library
    return await openLibraryRepo.randomBook();
  }

  /// Menggabungkan dua daftar hasil pencarian tanpa duplikat (kunci ISBN-13 atau judul+penulis) — Fase R2.
  /// [primary] (Google Books) diutamakan karena memiliki informasi harga (saleInfo).
  /// [secondary] (Open Library) ditambahkan jika belum ada di [primary].
  List<BookSearchResult> combineAndDeduplicate(
    List<BookSearchResult> primary,
    List<BookSearchResult> secondary,
  ) {
    return deduplicateBooks([...primary, ...secondary]);
  }

  /// Fungsi murni deduplikasi daftar buku berdasarkan ISBN-13 atau judul+penulis.
  static List<BookSearchResult> deduplicateBooks(List<BookSearchResult> books) {
    final result = <BookSearchResult>[];
    final seenIsbns = <String>{};
    final seenTitleAuthors = <String>{};

    for (final book in books) {
      // 1. Kunci ISBN (utamakan ISBN-13)
      final rawIsbn = book.isbn?.replaceAll(RegExp(r'[\s\-]'), '');
      final hasIsbn = rawIsbn != null && rawIsbn.isNotEmpty;

      if (hasIsbn && seenIsbns.contains(rawIsbn)) {
        continue;
      }

      // 2. Kunci judul + penulis (dibersihkan dari spasi berlebih & case-insensitive)
      final normTitle = _normalizeString(book.title);
      final normAuthor = _normalizeString(book.authors ?? '');
      final titleAuthorKey = '$normTitle|$normAuthor';

      if (normTitle.isNotEmpty && seenTitleAuthors.contains(titleAuthorKey)) {
        continue;
      }

      if (hasIsbn) {
        seenIsbns.add(rawIsbn);
      }
      if (normTitle.isNotEmpty) {
        seenTitleAuthors.add(titleAuthorKey);
      }

      result.add(book);
    }

    return result;
  }

  static String _normalizeString(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }
}
