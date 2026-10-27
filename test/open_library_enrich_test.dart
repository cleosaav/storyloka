import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:storyloka/data/remote/open_library_api.dart';
import 'package:storyloka/data/repositories/book_search_repository.dart';
import 'package:storyloka/data/repositories/remote/google_books_repository.dart';

void main() {
  group('OpenLibraryApi Unit Tests', () {
    test('parseDescription menangani bentuk String, Map {type, value}, dan null', () {
      // 1. Bentuk String
      expect(
        OpenLibraryApi.parseDescription('  Sebuah kisah petualangan.  '),
        equals('Sebuah kisah petualangan.'),
      );
      expect(OpenLibraryApi.parseDescription('   '), isNull);

      // 2. Bentuk Map/Objek {type, value}
      expect(
        OpenLibraryApi.parseDescription({
          'type': '/type/text',
          'value': '  Kisah menarik dari objek deskripsi.  ',
        }),
        equals('Kisah menarik dari objek deskripsi.'),
      );
      expect(
        OpenLibraryApi.parseDescription({
          'type': '/type/text',
          'value': '   ',
        }),
        isNull,
      );
      expect(
        OpenLibraryApi.parseDescription({'type': '/type/text'}),
        isNull,
      );

      // 3. Bentuk null atau tipe tidak dikenal
      expect(OpenLibraryApi.parseDescription(null), isNull);
      expect(OpenLibraryApi.parseDescription(12345), isNull);
      expect(OpenLibraryApi.parseDescription([]), isNull);
    });

    test('fetchSynopsis membaca description langsung dari edition jika tersedia', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/isbn/9786020385914.json') {
          return http.Response(
            jsonEncode({
              'title': 'Buku Uji',
              'description': 'Sinopsis langsung dari edition.',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final api = OpenLibraryApi(client: mockClient);
      final synopsis = await api.fetchSynopsis('978-602-03-8591-4');

      expect(synopsis, equals('Sinopsis langsung dari edition.'));
    });

    test('fetchSynopsis membaca description dari works jika edition tidak punya description', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/isbn/9786020385914.json') {
          return http.Response(
            jsonEncode({
              'title': 'Buku Uji',
              'works': [
                {'key': '/works/OL8888W'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/works/OL8888W.json') {
          return http.Response(
            jsonEncode({
              'title': 'Buku Uji Work',
              'description': {
                'type': '/type/text',
                'value': 'Sinopsis diambil dari work object.',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final api = OpenLibraryApi(client: mockClient);
      final synopsis = await api.fetchSynopsis('9786020385914');

      expect(synopsis, equals('Sinopsis diambil dari work object.'));
    });

    test('fetchSynopsis mengembalikan null jika status != 200 atau request gagal tanpa crash', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final api = OpenLibraryApi(client: mockClient);
      final synopsis = await api.fetchSynopsis('9781234567890');

      expect(synopsis, isNull);
    });

    test('fetchCoverUrl mengembalikan URL cover jika HEAD berstatus 200', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD' &&
            request.url.toString() ==
                'https://covers.openlibrary.org/b/isbn/9786020385914-L.jpg?default=false') {
          return http.Response('', 200);
        }
        return http.Response('', 404);
      });

      final api = OpenLibraryApi(client: mockClient);
      final coverUrl = await api.fetchCoverUrl('978-602-03-8591-4');

      expect(
        coverUrl,
        equals('https://covers.openlibrary.org/b/isbn/9786020385914-L.jpg?default=false'),
      );
    });

    test('fetchCoverUrl mengembalikan null jika cover tidak ditemukan (status 404)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 404);
      });

      final api = OpenLibraryApi(client: mockClient);
      final coverUrl = await api.fetchCoverUrl('9780000000000');

      expect(coverUrl, isNull);
    });
  });

  group('BookRepository enrich Tests', () {
    test('enrich tidak memanggil Open Library jika data sinopsis & cover sudah lengkap', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response('', 200);
      });

      final olApi = OpenLibraryApi(client: mockClient);
      final repo = GoogleBooksRepository(
        client: mockClient,
        openLibraryApi: olApi,
      );

      final book = const BookSearchResult(
        googleBooksId: 'gb123',
        title: 'Buku Lengkap',
        isbn: '9786020385914',
        synopsis: 'Sinopsis dari Google Books',
        coverUrl: 'https://books.google.com/cover.jpg',
      );

      final enriched = await repo.enrich(book);

      expect(requestCount, equals(0));
      expect(enriched.synopsis, equals('Sinopsis dari Google Books'));
      expect(enriched.coverUrl, equals('https://books.google.com/cover.jpg'));
    });

    test('enrich tidak menimpa data Google Books yang sudah ada jika Open Library merespons', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/isbn/9786020385914.json') {
          return http.Response(
            jsonEncode({'description': 'Sinopsis dari Open Library'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'HEAD') {
          return http.Response('', 200);
        }
        return http.Response('', 404);
      });

      final olApi = OpenLibraryApi(client: mockClient);
      final repo = GoogleBooksRepository(
        client: mockClient,
        openLibraryApi: olApi,
      );

      // Buku memiliki cover dari Google Books, tetapi sinopsis kosong
      final bookWithCoverOnly = const BookSearchResult(
        googleBooksId: 'gb123',
        title: 'Buku Tanpa Sinopsis',
        isbn: '978-602-03-8591-4',
        synopsis: null,
        coverUrl: 'https://books.google.com/original-cover.jpg',
      );

      final enriched = await repo.enrich(bookWithCoverOnly);

      // Sinopsis diisi oleh Open Library, cover dari Google Books TIDAK DITIMPA
      expect(enriched.synopsis, equals('Sinopsis dari Open Library'));
      expect(enriched.coverUrl, equals('https://books.google.com/original-cover.jpg'));
    });

    test('enrich mengisi cover jika cover kosong dan sinopsis Google Books tidak ditimpa', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') {
          return http.Response('', 200);
        }
        return http.Response('', 404);
      });

      final olApi = OpenLibraryApi(client: mockClient);
      final repo = GoogleBooksRepository(
        client: mockClient,
        openLibraryApi: olApi,
      );

      // Buku memiliki sinopsis dari Google Books, tetapi cover kosong
      final bookWithSynopsisOnly = const BookSearchResult(
        googleBooksId: 'gb456',
        title: 'Buku Tanpa Cover',
        isbn: '9786020385914',
        synopsis: 'Sinopsis asli Google Books',
        coverUrl: null,
      );

      final enriched = await repo.enrich(bookWithSynopsisOnly);

      expect(enriched.synopsis, equals('Sinopsis asli Google Books'));
      expect(
        enriched.coverUrl,
        equals('https://covers.openlibrary.org/b/isbn/9786020385914-L.jpg?default=false'),
      );
    });

    test('enrich langsung mengembalikan buku apa adanya jika ISBN kosong atau null', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response('', 200);
      });

      final olApi = OpenLibraryApi(client: mockClient);
      final repo = GoogleBooksRepository(
        client: mockClient,
        openLibraryApi: olApi,
      );

      final bookWithoutIsbn = const BookSearchResult(
        googleBooksId: 'gb789',
        title: 'Buku Tanpa ISBN',
        isbn: null,
        synopsis: null,
        coverUrl: null,
      );

      final result = await repo.enrich(bookWithoutIsbn);

      expect(requestCount, equals(0));
      expect(result.synopsis, isNull);
      expect(result.coverUrl, isNull);
    });
  });
}
