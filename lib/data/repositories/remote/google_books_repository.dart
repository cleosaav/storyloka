import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/env.dart';
import '../../remote/open_library_api.dart';
import '../book_search_repository.dart';

/// Exception umum untuk error pada Google Books API.
class GoogleBooksException implements Exception {
  final String message;
  final int? statusCode;

  GoogleBooksException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Exception kuota habis (HTTP 429) — Fase R2.
class GoogleBooksQuotaException extends GoogleBooksException {
  GoogleBooksQuotaException(
      [super.message = 'Kuota pencarian habis, coba lagi nanti'])
      : super(statusCode: 429);
}

/// Exception otentikasi / API key ditolak (HTTP 403) — Fase R2.
class GoogleBooksAuthException extends GoogleBooksException {
  GoogleBooksAuthException(
      [super.message = 'Akses ditolak, periksa API key'])
      : super(statusCode: 403);
}

/// Exception timeout atau masalah jaringan — Fase R2.
class GoogleBooksNetworkException extends GoogleBooksException {
  GoogleBooksNetworkException(
      [super.message =
          'Periksa koneksi Anda. Koneksi ke server buku gagal (timeout 15 detik).']);
}

/// Entri cache detail buku di memori dengan masa berlaku (TTL) 10 menit — Fase S3.
class GoogleBooksDetailCacheEntry {
  final BookSearchResult detail;
  final DateTime timestamp;

  GoogleBooksDetailCacheEntry(this.detail, this.timestamp);

  bool get isExpired =>
      DateTime.now().difference(timestamp) >= const Duration(minutes: 10);
}

/// Implementasi nyata BookSearchRepository menggunakan Google Books API — PRD §9.1 & Fase R2/S3.
class GoogleBooksRepository implements BookSearchRepository {
  GoogleBooksRepository({
    http.Client? client,
    OpenLibraryApi? openLibraryApi,
  })  : _client = client ?? http.Client(),
        openLibraryApi =
            openLibraryApi ?? OpenLibraryApi(client: client);

  final http.Client _client;
  final OpenLibraryApi openLibraryApi;
  final Map<String, GoogleBooksDetailCacheEntry> _detailCache = {};

  /// Jumlah entri detail aktif di cache memori.
  int get detailCacheSize => _detailCache.length;

  /// Bersihkan cache detail di memori.
  void clearDetailCache() => _detailCache.clear();

  static const String _baseUrl =
      'https://www.googleapis.com/books/v1/volumes';
  static const Duration _timeout = Duration(seconds: 15);

  /// Daftar subjek untuk shake-to-discover — PRD §7.3.
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
    'self-improvement',
  ];

  @override
  Future<List<BookSearchResult>> search(
    String query, {
    String filter = 'title',
    int maxResults = 20,
    int? startIndex,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // Bangun parameter q sesuai PRD §9.1 & Fase R2
    String q;
    switch (filter) {
      case 'author':
        q = 'inauthor:$cleanQuery';
        break;
      case 'isbn':
        // Hapus tanda hubung dan spasi — PRD §9.1
        final cleanIsbn = cleanQuery.replaceAll(RegExp(r'[\s\-]'), '');
        q = 'isbn:$cleanIsbn';
        break;
      case 'subject':
        q = 'subject:$cleanQuery';
        break;
      default: // title
        q = 'intitle:$cleanQuery';
        break;
    }

    final params = <String, String>{
      'q': q,
      'maxResults': maxResults.toString(),
      'printType': 'books',
      'country': 'ID',
      'fields':
          'totalItems,items(id,volumeInfo(title,authors,categories,description,pageCount,imageLinks/thumbnail,industryIdentifiers,publisher),saleInfo(saleability,listPrice,retailPrice))',
    };

    if (startIndex != null) {
      params['startIndex'] = startIndex.toString();
    }

    // Key opsional — PRD §3 (tanpa mencetak nilai kunci ke log!)
    final apiKey = Env.googleBooksApiKey;
    if (apiKey.isNotEmpty) {
      params['key'] = apiKey;
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);

    try {
      final response = await _client.get(uri).timeout(_timeout);

      // Catat kode status di log debug tanpa kunci — Fase R2
      if (kDebugMode) {
        final safeParams = Map<String, String>.from(params)..remove('key');
        final safeUri = uri.replace(queryParameters: safeParams);
        debugPrint('[GoogleBooks] HTTP ${response.statusCode}: $safeUri');
      }

      // Pemetaan error spesifik — Fase R2
      if (response.statusCode == 429) {
        throw GoogleBooksQuotaException('Kuota pencarian habis, coba lagi nanti');
      }
      if (response.statusCode == 403) {
        throw GoogleBooksAuthException('Akses ditolak, periksa API key');
      }
      if (response.statusCode != 200) {
        throw GoogleBooksException(
          'Terjadi kesalahan saat mencari buku. Silakan coba lagi. (HTTP ${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // items null / kosong — PRD §9.1
      final items = json['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return [];

      return items
          .map((item) => _mapToBookSearchResult(item as Map<String, dynamic>))
          .where((book) => book != null)
          .cast<BookSearchResult>()
          .toList();
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('[GoogleBooks] Timeout 15s');
      }
      throw GoogleBooksNetworkException(
          'Koneksi ke server buku gagal (timeout 15 detik). Periksa koneksi Anda.');
    } catch (e) {
      if (e is GoogleBooksException) {
        rethrow;
      }
      if (kDebugMode) {
        debugPrint('[GoogleBooks] Network/Socket error: $e');
      }
      throw GoogleBooksNetworkException('Periksa koneksi Anda');
    }
  }

  @override
  Future<BookSearchResult?> randomBook() async {
    // PRD §7.3: kata kunci acak dari daftar subjek, startIndex acak 0–30
    final random = Random();
    final subject = _discoverSubjects[random.nextInt(_discoverSubjects.length)];
    final startIndex = random.nextInt(31);

    try {
      final results = await search(
        subject,
        filter: 'subject',
        maxResults: 10,
        startIndex: startIndex,
      );

      if (results.isEmpty) return null;

      // Pilih satu hasil acak yang punya judul — PRD §7.3
      final validResults = results.where((b) => b.title.isNotEmpty).toList();
      if (validResults.isEmpty) return null;

      return validResults[random.nextInt(validResults.length)];
    } catch (_) {
      return null;
    }
  }

  @override
  Future<BookSearchResult?> getDetail(String googleBooksId) async {
    final cleanId = googleBooksId.trim();
    if (cleanId.isEmpty) return null;

    final cached = _detailCache[cleanId];
    if (cached != null && !cached.isExpired) {
      if (kDebugMode) {
        debugPrint('[GoogleBooks] Detail cache HIT untuk id "$cleanId"');
      }
      return cached.detail;
    }

    final params = <String, String>{
      'country': 'ID',
    };
    final apiKey = Env.googleBooksApiKey;
    if (apiKey.isNotEmpty) {
      params['key'] = apiKey;
    }

    final uri =
        Uri.parse('$_baseUrl/$cleanId').replace(queryParameters: params);

    try {
      final response = await _client.get(uri).timeout(_timeout);

      if (kDebugMode) {
        debugPrint('[GoogleBooks Detail] HTTP ${response.statusCode}: $cleanId');
      }

      if (response.statusCode == 429) {
        throw GoogleBooksQuotaException(
            'Kuota pencarian habis, coba lagi nanti');
      }
      if (response.statusCode == 403) {
        throw GoogleBooksAuthException('Akses ditolak, periksa API key');
      }
      if (response.statusCode == 404) {
        return null;
      }
      if (response.statusCode != 200) {
        throw GoogleBooksException(
          'Terjadi kesalahan saat memuat detail buku (HTTP ${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final parsed = _mapToBookSearchResult(json, isDetail: true);
      if (parsed == null) return null;
      var detail = parsed;

      // Percobaan kedua jika harga kosong di Indonesia: cek tanpa country=ID untuk harga internasional
      if (detail.priceAmount == null && detail.saleability != 'NOT_FOR_SALE') {
        try {
          final globalParams = <String, String>{};
          if (apiKey.isNotEmpty) {
            globalParams['key'] = apiKey;
          }
          final globalUri = Uri.parse('$_baseUrl/$cleanId').replace(
            queryParameters: globalParams.isNotEmpty ? globalParams : null,
          );
          final globalResp =
              await _client.get(globalUri).timeout(const Duration(seconds: 5));
          if (globalResp.statusCode == 200) {
            final globalJson =
                jsonDecode(globalResp.body) as Map<String, dynamic>;
            final globalSaleInfo =
                globalJson['saleInfo'] as Map<String, dynamic>?;
            if (globalSaleInfo != null) {
              final retail =
                  globalSaleInfo['retailPrice'] as Map<String, dynamic>?;
              final list = globalSaleInfo['listPrice'] as Map<String, dynamic>?;
              final pSource = retail ?? list;
              if (pSource != null) {
                final amt = (pSource['amount'] as num?)?.toDouble();
                final curr = pSource['currencyCode'] as String?;
                final cCountry =
                    globalSaleInfo['country'] as String? ?? 'AS';
                if (amt != null && curr != null) {
                  detail = detail.copyWith(
                    priceAmount: amt,
                    priceCurrency: curr,
                    priceCountry: cCountry,
                    priceNote:
                        'Harga di Google Play Books ($cCountry): $curr $amt',
                    buyLink: globalSaleInfo['buyLink'] as String? ??
                        detail.buyLink,
                  );
                }
              }
            }
          }
        } catch (_) {
          // Abaikan kegagalan panggilan internasional
        }
      }

      _detailCache[cleanId] =
          GoogleBooksDetailCacheEntry(detail, DateTime.now());
      return detail;
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('[GoogleBooks Detail] Timeout 15s');
      }
      throw GoogleBooksNetworkException(
        'Koneksi ke server buku gagal (timeout 15 detik). Periksa koneksi Anda.',
      );
    } catch (e) {
      if (e is GoogleBooksException) rethrow;
      throw GoogleBooksNetworkException('Periksa koneksi Anda');
    }
  }

  /// Mapping field sesuai PRD §9.1, Fase R2 & S3.
  BookSearchResult? _mapToBookSearchResult(
    Map<String, dynamic> item, {
    bool isDetail = false,
  }) {
    final volumeInfo = item['volumeInfo'] as Map<String, dynamic>?;
    if (volumeInfo == null) return null;

    final title = volumeInfo['title'] as String?;
    if (title == null || title.isEmpty) return null;

    final id = item['id'] as String?;
    if (id == null) return null;

    // authors: digabung ", " — PRD §9.1
    final authorsList = volumeInfo['authors'] as List<dynamic>?;
    final authors = (authorsList != null && authorsList.isNotEmpty)
        ? authorsList.join(', ')
        : 'Penulis tidak diketahui';

    // genre: categories[0] — PRD §9.1
    final categories = volumeInfo['categories'] as List<dynamic>?;
    final genre = (categories != null && categories.isNotEmpty)
        ? categories[0] as String?
        : null;

    // synopsis: strip tag HTML — PRD §9.1
    final rawDescription = volumeInfo['description'] as String?;
    final synopsis = rawDescription != null ? _stripHtml(rawDescription) : null;

    // page_count / printedPageCount: 0/null → null — PRD §9.1 & S3
    int? pageCount = volumeInfo['pageCount'] as int?;
    if (pageCount == null || pageCount <= 0) {
      final printedPages = volumeInfo['printedPageCount'] as int?;
      if (printedPages != null && printedPages > 0) {
        pageCount = printedPages;
      } else {
        pageCount = null;
      }
    }

    // cover_url: ubah http:// → https:// — PRD §9.1
    final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
    String? coverUrl = imageLinks?['thumbnail'] as String? ??
        imageLinks?['small'] as String? ??
        imageLinks?['medium'] as String?;
    if (coverUrl != null) {
      coverUrl = coverUrl.replaceFirst('http://', 'https://');
    }

    // isbn: utamakan ISBN_13 — PRD §9.1
    final identifiers =
        volumeInfo['industryIdentifiers'] as List<dynamic>?;
    String? isbn;
    if (identifiers != null && identifiers.isNotEmpty) {
      // Cari ISBN_13 dulu
      for (final id in identifiers) {
        final map = id as Map<String, dynamic>;
        if (map['type'] == 'ISBN_13') {
          isbn = map['identifier'] as String?;
          break;
        }
      }
      // Fallback ke ISBN_10
      isbn ??= (identifiers.first as Map<String, dynamic>)['identifier']
          as String?;
    }

    // publisher — PRD §9.1
    final publisher = volumeInfo['publisher'] as String?;

    // price: saleInfo.retailPrice atau saleInfo.listPrice — PRD §9.1
    final saleInfo = item['saleInfo'] as Map<String, dynamic>?;
    double? priceAmount;
    String? priceCurrency;
    String? saleability;
    String? buyLink;
    String? priceCountry;

    if (saleInfo != null) {
      saleability = saleInfo['saleability'] as String?;
      buyLink = saleInfo['buyLink'] as String?;
      priceCountry = saleInfo['country'] as String? ?? 'ID';

      final retailPrice = saleInfo['retailPrice'] as Map<String, dynamic>?;
      final listPrice = saleInfo['listPrice'] as Map<String, dynamic>?;
      final priceSource = retailPrice ?? listPrice;
      if (priceSource != null) {
        priceAmount = (priceSource['amount'] as num?)?.toDouble();
        priceCurrency = priceSource['currencyCode'] as String?;
      }
    }

    // Field detail tambahan — Fase S3
    final subtitle = volumeInfo['subtitle'] as String?;
    final publishedDate = volumeInfo['publishedDate'] as String?;
    final language = volumeInfo['language'] as String?;
    final averageRating = (volumeInfo['averageRating'] as num?)?.toDouble();
    final ratingsCount = volumeInfo['ratingsCount'] as int?;
    final infoLink = volumeInfo['infoLink'] as String?;
    final previewLink = volumeInfo['previewLink'] as String?;

    return BookSearchResult(
      googleBooksId: id,
      title: title,
      authors: authors,
      genre: genre,
      isbn: isbn,
      publisher: publisher,
      pageCount: pageCount,
      coverUrl: coverUrl,
      synopsis: synopsis,
      priceAmount: priceAmount,
      priceCurrency: priceCurrency,
      subtitle: subtitle,
      publishedDate: publishedDate,
      language: language,
      averageRating: averageRating,
      ratingsCount: ratingsCount,
      infoLink: infoLink,
      previewLink: previewLink,
      buyLink: buyLink,
      saleability: saleability,
      priceCountry: priceCountry,
      synopsisSource: synopsis != null ? 'Google Books' : null,
    );
  }

  /// Menghapus tag HTML dari teks sinopsis — PRD §9.1.
  String _stripHtml(String html) {
    final withoutTags = html.replaceAll(RegExp(r'<[^>]*>'), '');
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
