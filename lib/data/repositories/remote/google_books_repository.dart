import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../book_search_repository.dart';
import '../../../core/config/env.dart';

/// Implementasi nyata BookSearchRepository menggunakan Google Books API — PRD §9.1.
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
    if (query.trim().isEmpty) return [];

    // Bangun parameter q sesuai PRD §9.1
    String q;
    switch (filter) {
      case 'author':
        q = 'inauthor:$query';
        break;
      case 'isbn':
        // Hapus tanda hubung dan spasi — PRD §9.1
        final cleanIsbn = query.replaceAll(RegExp(r'[\s\-]'), '');
        q = 'isbn:$cleanIsbn';
        break;
      case 'subject':
        q = 'subject:$query';
        break;
      default: // title
        q = 'intitle:$query';
        break;
    }

    final params = <String, String>{
      'q': q,
      'maxResults': maxResults.toString(),
      'printType': 'books',
    };

    if (startIndex != null) {
      params['startIndex'] = startIndex.toString();
    }

    // Key opsional — PRD §3
    final apiKey = Env.googleBooksApiKey;
    if (apiKey.isNotEmpty) {
      params['key'] = apiKey;
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);

    try {
      final response = await _client.get(uri).timeout(_timeout);

      // Status non-200 — PRD §9.1
      if (response.statusCode != 200) {
        throw Exception(
          'Google Books API error: status ${response.statusCode}',
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
      throw Exception('Koneksi ke server buku gagal (timeout 15 detik).');
    } catch (e) {
      if (e is Exception &&
          e.toString().contains('Google Books API error')) {
        rethrow;
      }
      throw Exception('Tidak ada koneksi internet. Periksa jaringan Anda.');
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
      final validResults =
          results.where((b) => b.title.isNotEmpty).toList();
      if (validResults.isEmpty) return null;

      return validResults[random.nextInt(validResults.length)];
    } catch (_) {
      return null;
    }
  }

  /// Mapping field persis sesuai PRD §9.1.
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
    // Hapus semua tag HTML
    final withoutTags = html.replaceAll(RegExp(r'<[^>]*>'), '');
    // Decode HTML entities umum
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
