import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/env.dart';
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

/// Implementasi nyata BookSearchRepository menggunakan Google Books API — PRD §9.1 & Fase R2.
class GoogleBooksRepository implements BookSearchRepository {
  GoogleBooksRepository({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

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

  /// Mapping field persis sesuai PRD §9.1 & Fase R2.
  BookSearchResult? _mapToBookSearchResult(Map<String, dynamic> item) {
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

    // page_count: 0/null → null — PRD §9.1
    final rawPageCount = volumeInfo['pageCount'] as int?;
    final pageCount =
        (rawPageCount != null && rawPageCount > 0) ? rawPageCount : null;

    // cover_url: ubah http:// → https:// — PRD §9.1
    final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
    String? coverUrl = imageLinks?['thumbnail'] as String?;
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
    if (saleInfo != null) {
      final retailPrice = saleInfo['retailPrice'] as Map<String, dynamic>?;
      final listPrice = saleInfo['listPrice'] as Map<String, dynamic>?;
      final priceSource = retailPrice ?? listPrice;
      if (priceSource != null) {
        priceAmount = (priceSource['amount'] as num?)?.toDouble();
        priceCurrency = priceSource['currencyCode'] as String?;
      }
    }

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
}
