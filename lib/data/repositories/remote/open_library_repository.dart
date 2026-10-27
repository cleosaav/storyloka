import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/services/rate_limiter.dart';
import '../../remote/open_library_api.dart';
import '../book_search_repository.dart';

/// Implementasi BookSearchRepository menggunakan Open Library API — Fase R2.
class OpenLibraryRepository implements BookSearchRepository {
  final http.Client _client;
  final RateLimiter _rateLimiter;
  final OpenLibraryApi openLibraryApi;

  static const String _searchBaseUrl = 'https://openlibrary.org/search.json';
  static const String _isbnBaseUrl = 'https://openlibrary.org/api/books';
  static const String _worksBaseUrl = 'https://openlibrary.org';
  static const Duration _timeout = Duration(seconds: 15);
  static const Map<String, String> _headers = {
    'User-Agent': 'StoryLoka/1.0',
    'Accept': 'application/json',
  };

  static const List<String> _discoverSubjects = [
    'fiction',
    'fantasy',
    'romance',
    'history',
    'science',
    'mystery',
    'philosophy',
    'business',
    'biography',
  ];

  OpenLibraryRepository({
    http.Client? client,
    RateLimiter? rateLimiter,
    OpenLibraryApi? openLibraryApi,
  })  : _client = client ?? http.Client(),
        _rateLimiter = rateLimiter ?? RateLimiter(maxRequestsPerSecond: 3),
        openLibraryApi = openLibraryApi ?? OpenLibraryApi(client: client);

  @override
  Future<List<BookSearchResult>> search(
    String query, {
    String filter = 'title',
    int maxResults = 20,
    int? startIndex,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // Jika pencarian berbasis ISBN, prioritaskan endpoint api/books (jscmd=data)
    if (filter == 'isbn') {
      final cleanIsbn = cleanQuery.replaceAll(RegExp(r'[\s\-]'), '');
      final isbnBook = await lookupIsbn(cleanIsbn);
      if (isbnBook != null) {
        return [isbnBook];
      }
      // Fallback ke search.json dengan parameter isbn
      return _searchWithSearchJson(cleanIsbn, isIsbnSearch: true, maxResults: maxResults);
    }

    return _searchWithSearchJson(cleanQuery, maxResults: maxResults, startIndex: startIndex);
  }

  /// Pencarian menggunakan endpoint search.json
  Future<List<BookSearchResult>> _searchWithSearchJson(
    String query, {
    bool isIsbnSearch = false,
    int maxResults = 20,
    int? startIndex,
  }) async {
    final params = <String, String>{
      if (isIsbnSearch) 'isbn': query else 'q': query,
      'limit': maxResults.toString(),
      'fields':
          'key,title,author_name,cover_i,isbn,first_publish_year,number_of_pages_median,subject',
    };

    if (startIndex != null && startIndex > 0) {
      params['offset'] = startIndex.toString();
    }

    final uri = Uri.parse(_searchBaseUrl).replace(queryParameters: params);

    try {
      await _rateLimiter.acquire();
      final response = await _client.get(uri, headers: _headers).timeout(_timeout);

      if (kDebugMode) {
        debugPrint('[OpenLibrary] HTTP ${response.statusCode}: $uri');
      }

      if (response.statusCode != 200) {
        return [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final docs = json['docs'] as List<dynamic>?;
      if (docs == null || docs.isEmpty) return [];

      return docs
          .map((item) => _mapDocToBookSearchResult(item as Map<String, dynamic>))
          .where((b) => b != null)
          .cast<BookSearchResult>()
          .toList();
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('[OpenLibrary] Timeout 15s');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OpenLibrary] Search error: $e');
      }
      return [];
    }
  }

  /// Lookup ISBN lewat endpoint https://openlibrary.org/api/books?bibkeys=ISBN:{isbn}&format=json&jscmd=data
  Future<BookSearchResult?> lookupIsbn(String rawIsbn) async {
    final cleanIsbn = rawIsbn.replaceAll(RegExp(r'[\s\-]'), '');
    if (cleanIsbn.isEmpty) return null;

    final bibKey = 'ISBN:$cleanIsbn';
    final uri = Uri.parse(_isbnBaseUrl).replace(
      queryParameters: {
        'bibkeys': bibKey,
        'format': 'json',
        'jscmd': 'data',
      },
    );

    try {
      await _rateLimiter.acquire();
      final response = await _client.get(uri, headers: _headers).timeout(_timeout);

      if (kDebugMode) {
        debugPrint('[OpenLibrary ISBN] HTTP ${response.statusCode}: $uri');
      }

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json[bibKey] as Map<String, dynamic>?;
      if (data == null) return null;

      return _mapIsbnDataToBookSearchResult(cleanIsbn, data);
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('[OpenLibrary ISBN] Timeout 15s');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OpenLibrary ISBN] Lookup error: $e');
      }
      return null;
    }
  }

  /// Mengambil sinopsis karya dari /works/{id}.json — Fase R2.
  /// Field description bisa berupa String atau Objek { "value": "..." }.
  Future<String?> fetchWorkSynopsis(String workKeyOrId) async {
    String path = workKeyOrId.trim();
    if (!path.startsWith('/')) {
      path = '/works/$path';
    }
    if (!path.endsWith('.json')) {
      path = '$path.json';
    }

    final uri = Uri.parse('$_worksBaseUrl$path');

    try {
      await _rateLimiter.acquire();
      final response = await _client.get(uri, headers: _headers).timeout(_timeout);

      if (kDebugMode) {
        debugPrint('[OpenLibrary Work] HTTP ${response.statusCode}: $uri');
      }

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return parseDescription(json['description']);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OpenLibrary Work] Error: $e');
      }
      return null;
    }
  }

  /// Parser fleksibel untuk field description Open Library (String / Map {value}).
  static String? parseDescription(dynamic description) {
    if (description == null) return null;
    if (description is String) {
      return _cleanSynopsis(description);
    }
    if (description is Map) {
      final value = description['value'];
      if (value is String) {
        return _cleanSynopsis(value);
      }
    }
    return null;
  }

  @override
  Future<BookSearchResult?> getDetail(String googleBooksId) async {
    final cleanId = googleBooksId.trim();
    if (cleanId.isEmpty) return null;

    final cleanIsbn = cleanId.replaceAll(RegExp(r'[\s\-]'), '');
    final isbnBook = await lookupIsbn(cleanIsbn);
    if (isbnBook != null) {
      return isbnBook.copyWith(synopsisSource: 'Open Library');
    }

    if (cleanId.contains('OL') || cleanId.startsWith('/')) {
      final synopsis = await fetchWorkSynopsis(cleanId);
      if (synopsis != null) {
        return BookSearchResult(
          googleBooksId: cleanId,
          title: cleanId,
          synopsis: synopsis,
          synopsisSource: 'Open Library',
        );
      }
    }
    return null;
  }

  @override
  Future<BookSearchResult?> randomBook() async {
    final random = Random();
    final subject = _discoverSubjects[random.nextInt(_discoverSubjects.length)];
    final startIndex = random.nextInt(20);

    try {
      final results = await search(
        subject,
        filter: 'subject',
        maxResults: 10,
        startIndex: startIndex,
      );

      if (results.isEmpty) return null;

      final valid = results.where((b) => b.title.isNotEmpty).toList();
      if (valid.isEmpty) return null;

      return valid[random.nextInt(valid.length)];
    } catch (_) {
      return null;
    }
  }

  /// Pemetaan objek dari search.json docs ke BookSearchResult.
  BookSearchResult? _mapDocToBookSearchResult(Map<String, dynamic> doc) {
    final title = doc['title'] as String?;
    if (title == null || title.isEmpty) return null;

    final key = doc['key'] as String? ?? '';
    final id = key.isNotEmpty ? key.replaceFirst('/works/', '') : 'ol_${title.hashCode}';

    // Authors
    final authorsList = doc['author_name'] as List<dynamic>?;
    final authors = (authorsList != null && authorsList.isNotEmpty)
        ? authorsList.map((a) => a.toString()).join(', ')
        : 'Penulis tidak diketahui';

    // Cover: https://covers.openlibrary.org/b/id/{cover_i}-M.jpg — Fase R2
    final coverI = doc['cover_i'];
    String? coverUrl;
    if (coverI != null && (coverI is int && coverI > 0)) {
      coverUrl = 'https://covers.openlibrary.org/b/id/$coverI-M.jpg';
    }

    // ISBN (utamakan 13 digit)
    final isbnList = doc['isbn'] as List<dynamic>?;
    String? isbn;
    if (isbnList != null && isbnList.isNotEmpty) {
      for (final raw in isbnList) {
        final clean = raw.toString().replaceAll(RegExp(r'[\s\-]'), '');
        if (clean.length == 13) {
          isbn = clean;
          break;
        }
      }
      isbn ??= isbnList.first.toString().replaceAll(RegExp(r'[\s\-]'), '');
    }

    // Pages
    final pageCount = doc['number_of_pages_median'] as int?;

    // Genre / Subject
    final subjects = doc['subject'] as List<dynamic>?;
    final genre = (subjects != null && subjects.isNotEmpty)
        ? subjects.first.toString()
        : null;

    // Publisher
    final publishers = doc['publisher'] as List<dynamic>?;
    final publisher = (publishers != null && publishers.isNotEmpty)
        ? publishers.first.toString()
        : null;

    return BookSearchResult(
      googleBooksId: 'openlib:$id',
      title: title,
      authors: authors,
      genre: genre,
      isbn: isbn,
      publisher: publisher,
      pageCount: pageCount,
      coverUrl: coverUrl,
      synopsis: null, // Open Library search.json tidak menyertakan sinopsis lengkap
      priceAmount: null, // Harga HANYA dari Google saleInfo — Fase R2
      priceCurrency: null,
    );
  }

  /// Pemetaan objek dari api/books (jscmd=data) ke BookSearchResult.
  BookSearchResult _mapIsbnDataToBookSearchResult(
    String cleanIsbn,
    Map<String, dynamic> data,
  ) {
    final title = data['title'] as String? ?? 'Tanpa Judul';
    final key = data['key'] as String? ?? 'openlib:$cleanIsbn';

    // Authors
    final authorsList = data['authors'] as List<dynamic>?;
    final authors = (authorsList != null && authorsList.isNotEmpty)
        ? authorsList
            .map((a) => (a as Map)['name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .join(', ')
        : 'Penulis tidak diketahui';

    // Cover
    final coverMap = data['cover'] as Map<String, dynamic>?;
    final coverUrl = (coverMap?['medium'] ?? coverMap?['large'] ?? coverMap?['small']) as String?;

    // Pages
    final pageCount = data['number_of_pages'] as int?;

    // Publisher
    final publishers = data['publishers'] as List<dynamic>?;
    final publisher = (publishers != null && publishers.isNotEmpty)
        ? (publishers.first as Map)['name']?.toString()
        : null;

    // Subjects
    final subjects = data['subjects'] as List<dynamic>?;
    final genre = (subjects != null && subjects.isNotEmpty)
        ? (subjects.first as Map)['name']?.toString()
        : null;

    // Identifiers
    final identifiers = data['identifiers'] as Map<String, dynamic>?;
    final isbn13List = identifiers?['isbn_13'] as List<dynamic>?;
    final isbn = (isbn13List != null && isbn13List.isNotEmpty)
        ? isbn13List.first.toString().replaceAll(RegExp(r'[\s\-]'), '')
        : cleanIsbn;

    // Works & Notes/Description (Sinopsis)
    final works = data['works'] as List<dynamic>?;
    final workKey = (works != null && works.isNotEmpty)
        ? (works.first as Map)['key']?.toString()
        : null;

    final synopsis = parseDescription(data['notes']) ?? parseDescription(data['description']);

    return BookSearchResult(
      googleBooksId: workKey ??
          (key.startsWith('/books/') ? 'openlib:${key.replaceFirst('/books/', '')}' : key),
      title: title,
      authors: authors,
      genre: genre,
      isbn: isbn,
      publisher: publisher,
      pageCount: pageCount,
      coverUrl: coverUrl,
      synopsis: synopsis,
      synopsisSource: synopsis != null ? 'Open Library' : null,
      priceAmount: null, // Harga HANYA dari Google saleInfo — Fase R2
      priceCurrency: null,
    );
  }

  static String _cleanSynopsis(String raw) {
    final withoutTags = raw.replaceAll(RegExp(r'<[^>]*>'), '');
    return withoutTags
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Future<BookSearchResult> enrich(BookSearchResult b) async {
    final rawIsbn = b.isbn;
    if (rawIsbn == null || rawIsbn.trim().isEmpty) {
      return b;
    }
    final cleanIsbn = OpenLibraryApi.normalizeIsbn(rawIsbn);
    if (cleanIsbn.isEmpty) {
      return b;
    }

    final needsSynopsis = b.synopsis == null || b.synopsis!.trim().isEmpty;
    final needsCover = b.coverUrl == null || b.coverUrl!.trim().isEmpty;

    if (!needsSynopsis && !needsCover) {
      return b;
    }

    final Future<String?> synopsisFuture = needsSynopsis
        ? openLibraryApi.fetchSynopsis(cleanIsbn)
        : Future.value(null);
    final Future<String?> coverFuture = needsCover
        ? openLibraryApi.fetchCoverUrl(cleanIsbn)
        : Future.value(null);

    final results = await Future.wait<String?>([synopsisFuture, coverFuture]);
    final olSynopsis = results[0];
    final olCover = results[1];

    final hasNewSynopsis =
        needsSynopsis && olSynopsis != null && olSynopsis.isNotEmpty;
    final hasNewCover =
        needsCover && olCover != null && olCover.isNotEmpty;

    return b.copyWith(
      synopsis: hasNewSynopsis ? olSynopsis : b.synopsis,
      coverUrl: hasNewCover ? olCover : b.coverUrl,
      synopsisSource: hasNewSynopsis ? 'Open Library' : b.synopsisSource,
    );
  }
}
