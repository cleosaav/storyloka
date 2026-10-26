import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:storyloka/core/services/rate_limiter.dart';
import 'package:storyloka/data/repositories/book_search_repository.dart';
import 'package:storyloka/data/repositories/remote/composite_book_search_repository.dart';
import 'package:storyloka/data/repositories/remote/google_books_repository.dart';
import 'package:storyloka/data/repositories/remote/open_library_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase R2: Pencarian Buku Hibrida Tests', () {
    // ══════════════════════════════════════════════════════════════════════════
    // 1. GoogleBooksRepository Fixture & Mapping
    // ══════════════════════════════════════════════════════════════════════════
    group('1. GoogleBooksRepository', () {
      test('Mapping lengkap: parameter fields, country=ID, cover https, ISBN-13, dan harga dari saleInfo', () async {
        final fixtureJson = {
          'totalItems': 1,
          'items': [
            {
              'id': 'g_book_1',
              'volumeInfo': {
                'title': 'Laskar Pelangi',
                'authors': ['Andrea Hirata'],
                'categories': ['Fiction'],
                'industryIdentifiers': [
                  {'type': 'ISBN_10', 'identifier': '9793062797'},
                  {'type': 'ISBN_13', 'identifier': '9789793062792'},
                ],
                'publisher': 'Bentang Pustaka',
                'pageCount': 529,
                'imageLinks': {
                  'thumbnail': 'http://books.google.com/books/content?id=g_book_1&printsec=frontcover',
                },
                'description': '<p>Kisah tentang <b>sepuluh laskar pelangi</b> di Belitung.</p>',
              },
              'saleInfo': {
                'saleability': 'FOR_SALE',
                'retailPrice': {
                  'amount': 89000.0,
                  'currencyCode': 'IDR',
                },
              },
            }
          ],
        };

        Uri? capturedUri;
        final mockClient = MockClient((request) async {
          capturedUri = request.url;
          return http.Response(jsonEncode(fixtureJson), 200);
        });

        final repo = GoogleBooksRepository(client: mockClient);
        final results = await repo.search('Laskar Pelangi');

        expect(results.length, 1);
        final book = results.first;
        expect(book.googleBooksId, 'g_book_1');
        expect(book.title, 'Laskar Pelangi');
        expect(book.authors, 'Andrea Hirata');
        expect(book.genre, 'Fiction');
        expect(book.isbn, '9789793062792');
        expect(book.publisher, 'Bentang Pustaka');
        expect(book.pageCount, 529);
        expect(book.coverUrl, startsWith('https://'));
        expect(book.synopsis, 'Kisah tentang sepuluh laskar pelangi di Belitung.');
        expect(book.priceAmount, 89000.0);
        expect(book.priceCurrency, 'IDR');

        // Parameter query Google Books
        expect(capturedUri?.queryParameters['country'], 'ID');
        expect(capturedUri?.queryParameters['printType'], 'books');
        expect(capturedUri?.queryParameters['fields'], contains('totalItems,items'));
      });

      test('Buku tanpa cover dan tanpa harga (NOT_FOR_SALE)', () async {
        final fixtureJson = {
          'totalItems': 1,
          'items': [
            {
              'id': 'g_book_2',
              'volumeInfo': {
                'title': 'Buku Tanpa Cover',
                'authors': ['Penulis Anonim'],
              },
              'saleInfo': {
                'saleability': 'NOT_FOR_SALE',
              },
            }
          ],
        };

        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode(fixtureJson), 200);
        });

        final repo = GoogleBooksRepository(client: mockClient);
        final results = await repo.search('Buku Tanpa Cover');

        expect(results.length, 1);
        final book = results.first;
        expect(book.coverUrl, isNull);
        expect(book.priceAmount, isNull);
        expect(book.priceCurrency, isNull);
      });

      test('Petakan error: 429 -> Kuota pencarian habis', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Rate limit exceeded', 429);
        });

        final repo = GoogleBooksRepository(client: mockClient);
        expect(
          () => repo.search('test'),
          throwsA(isA<GoogleBooksQuotaException>().having(
            (e) => e.message,
            'message',
            contains('Kuota pencarian habis, coba lagi nanti'),
          )),
        );
      });

      test('Petakan error: 403 -> Akses ditolak, periksa API key', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Forbidden', 403);
        });

        final repo = GoogleBooksRepository(client: mockClient);
        expect(
          () => repo.search('test'),
          throwsA(isA<GoogleBooksAuthException>().having(
            (e) => e.message,
            'message',
            contains('Akses ditolak, periksa API key'),
          )),
        );
      });

      test('Petakan error: timeout / jaringan -> Periksa koneksi Anda', () async {
        final mockClient = MockClient((request) async {
          throw TimeoutException('Timed out');
        });

        final repo = GoogleBooksRepository(client: mockClient);
        expect(
          () => repo.search('test'),
          throwsA(isA<GoogleBooksNetworkException>().having(
            (e) => e.message,
            'message',
            contains('Periksa koneksi Anda'),
          )),
        );
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // 2. OpenLibraryRepository Fixture & Mapping
    // ══════════════════════════════════════════════════════════════════════════
    group('2. OpenLibraryRepository', () {
      test('Mapping search.json: cover_i, author_name, number_of_pages_median, tanpa harga', () async {
        final fixtureJson = {
          'numFound': 1,
          'docs': [
            {
              'key': '/works/OL45804W',
              'title': 'Fantastic Beasts and Where to Find Them',
              'author_name': ['J.K. Rowling', 'Newt Scamander'],
              'cover_i': 8235110,
              'isbn': ['0439321603', '9780439321600'],
              'number_of_pages_median': 128,
              'subject': ['Dragons', 'Fantasy'],
              'publisher': ['Arthur A. Levine Books'],
            }
          ],
        };

        Map<String, String>? capturedHeaders;
        Uri? capturedUri;

        final mockClient = MockClient((request) async {
          capturedHeaders = request.headers;
          capturedUri = request.url;
          return http.Response(jsonEncode(fixtureJson), 200);
        });

        final repo = OpenLibraryRepository(client: mockClient);
        final results = await repo.search('Fantastic Beasts');

        expect(results.length, 1);
        final book = results.first;
        expect(book.title, 'Fantastic Beasts and Where to Find Them');
        expect(book.authors, 'J.K. Rowling, Newt Scamander');
        expect(book.coverUrl, 'https://covers.openlibrary.org/b/id/8235110-M.jpg');
        expect(book.isbn, '9780439321600');
        expect(book.pageCount, 128);
        expect(book.genre, 'Dragons');
        expect(book.publisher, 'Arthur A. Levine Books');
        // Harga HANYA dari Google saleInfo; jika tidak ada -> null
        expect(book.priceAmount, isNull);
        expect(book.priceCurrency, isNull);

        // Header User-Agent "StoryLoka/1.0"
        expect(capturedHeaders?['User-Agent'], 'StoryLoka/1.0');
        expect(capturedUri?.queryParameters['fields'], contains('key,title,author_name,cover_i,isbn'));
      });

      test('Buku Open Library tanpa cover_i menghasilkan coverUrl null', () async {
        final fixtureJson = {
          'numFound': 1,
          'docs': [
            {
              'key': '/works/OL999W',
              'title': 'Ancient Manuscript',
              'author_name': ['Anonymous'],
            }
          ],
        };

        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode(fixtureJson), 200);
        });

        final repo = OpenLibraryRepository(client: mockClient);
        final results = await repo.search('Ancient Manuscript');

        expect(results.length, 1);
        expect(results.first.coverUrl, isNull);
        expect(results.first.priceAmount, isNull);
      });

      test('Lookup ISBN lewat api/books?bibkeys=ISBN:...&jscmd=data', () async {
        final cleanIsbn = '9780140328721';
        final fixtureJson = {
          'ISBN:$cleanIsbn': {
            'key': '/books/OL7353617M',
            'title': 'Fantastic Mr Fox',
            'authors': [
              {'name': 'Roald Dahl'}
            ],
            'number_of_pages': 96,
            'publishers': [
              {'name': 'Puffin'}
            ],
            'cover': {
              'medium': 'https://covers.openlibrary.org/b/id/6498519-M.jpg',
            },
            'identifiers': {
              'isbn_13': ['9780140328721'],
            },
            'subjects': [
              {'name': 'Children Fiction'}
            ],
          }
        };

        Uri? capturedUri;
        final mockClient = MockClient((request) async {
          capturedUri = request.url;
          return http.Response(jsonEncode(fixtureJson), 200);
        });

        final repo = OpenLibraryRepository(client: mockClient);
        final results = await repo.search('978-014-032-872-1', filter: 'isbn');

        expect(results.length, 1);
        final book = results.first;
        expect(book.title, 'Fantastic Mr Fox');
        expect(book.authors, 'Roald Dahl');
        expect(book.pageCount, 96);
        expect(book.publisher, 'Puffin');
        expect(book.coverUrl, 'https://covers.openlibrary.org/b/id/6498519-M.jpg');
        expect(book.priceAmount, isNull);
        expect(capturedUri?.path, contains('/api/books'));
        expect(capturedUri?.queryParameters['bibkeys'], 'ISBN:$cleanIsbn');
      });

      test('Sinopsis dari /works/{id}.json (string vs objek {value})', () async {
        // 1. Description berupa String
        final stringDescJson = {
          'title': 'Bumi Manusia',
          'description': 'Kisah Minke di masa kolonial.',
        };

        // 2. Description berupa Map {type: ..., value: ...}
        final objectDescJson = {
          'title': 'Anak Semua Bangsa',
          'description': {
            'type': '/type/text',
            'value': 'Perjuangan Minke mencari jati diri bangsa.',
          },
        };

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('OL1W')) {
            return http.Response(jsonEncode(stringDescJson), 200);
          } else {
            return http.Response(jsonEncode(objectDescJson), 200);
          }
        });

        final repo = OpenLibraryRepository(client: mockClient);
        final desc1 = await repo.fetchWorkSynopsis('OL1W');
        final desc2 = await repo.fetchWorkSynopsis('OL2W');

        expect(desc1, 'Kisah Minke di masa kolonial.');
        expect(desc2, 'Perjuangan Minke mencari jati diri bangsa.');
      });

      test('Rate limiter membatasi frekuensi request (maksimal 3 per detik)', () async {
        final rateLimiter = RateLimiter(maxRequestsPerSecond: 3);
        final stopwatch = Stopwatch()..start();

        // Lakukan 4 kali acquire
        await rateLimiter.acquire();
        await rateLimiter.acquire();
        await rateLimiter.acquire();
        await rateLimiter.acquire(); // Harus menunggu minimal ~1 detik dari request pertama

        stopwatch.stop();
        // Request ke-4 seharusnya mengalami delay menunggu jendela 1 detik
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(900));
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // 3. CompositeBookSearchRepository: Fallback saat 429 & Hasil Kosong
    // ══════════════════════════════════════════════════════════════════════════
    group('3. CompositeBookSearchRepository Fallback', () {
      test('Fallback ke Open Library saat Google Books 429 (kuota habis)', () async {
        final googleClient = MockClient((request) async {
          return http.Response('Rate limit', 429);
        });

        final openLibClient = MockClient((request) async {
          final openLibDoc = {
            'numFound': 1,
            'docs': [
              {
                'key': '/works/OL_FALLBACK_1',
                'title': 'Buku Cadangan Open Library',
                'author_name': ['Penulis Alternatif'],
                'cover_i': 99999,
                'isbn': ['9781112223334'],
              }
            ],
          };
          return http.Response(jsonEncode(openLibDoc), 200);
        });

        final composite = CompositeBookSearchRepository(
          googleRepo: GoogleBooksRepository(client: googleClient),
          openLibraryRepo: OpenLibraryRepository(client: openLibClient),
        );

        final results = await composite.search('query apapun');

        expect(results.length, 1);
        expect(results.first.title, 'Buku Cadangan Open Library');
        expect(results.first.authors, 'Penulis Alternatif');
        expect(results.first.coverUrl, contains('99999'));
        expect(results.first.priceAmount, isNull);
      });

      test('Fallback ke Open Library saat Google Books mengembalikan hasil kosong', () async {
        final googleClient = MockClient((request) async {
          return http.Response(jsonEncode({'totalItems': 0, 'items': []}), 200);
        });

        final openLibClient = MockClient((request) async {
          final openLibDoc = {
            'numFound': 1,
            'docs': [
              {
                'key': '/works/OL_RARE_BOOK',
                'title': 'Rare Indonesian Manuscript',
                'author_name': ['Pujangga Lama'],
              }
            ],
          };
          return http.Response(jsonEncode(openLibDoc), 200);
        });

        final composite = CompositeBookSearchRepository(
          googleRepo: GoogleBooksRepository(client: googleClient),
          openLibraryRepo: OpenLibraryRepository(client: openLibClient),
        );

        final results = await composite.search('Rare Manuscript');

        expect(results.length, 1);
        expect(results.first.title, 'Rare Indonesian Manuscript');
        expect(results.first.authors, 'Pujangga Lama');
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // 4. Scan Barcode: Cari ISBN di Google, jika kosong coba Open Library
    // ══════════════════════════════════════════════════════════════════════════
    group('4. Scan Barcode ISBN Fallback', () {
      test('Scan barcode: ditemukan di Google -> kembalikan hasil Google dengan harga', () async {
        final googleClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'g_isbn_1',
                  'volumeInfo': {
                    'title': 'Clean Code',
                    'authors': ['Robert C. Martin'],
                    'industryIdentifiers': [
                      {'type': 'ISBN_13', 'identifier': '9780132350884'}
                    ],
                  },
                  'saleInfo': {
                    'retailPrice': {'amount': 350000.0, 'currencyCode': 'IDR'}
                  }
                }
              ]
            }),
            200,
          );
        });

        var openLibCalled = false;
        final openLibClient = MockClient((request) async {
          openLibCalled = true;
          return http.Response('{}', 200);
        });

        final composite = CompositeBookSearchRepository(
          googleRepo: GoogleBooksRepository(client: googleClient),
          openLibraryRepo: OpenLibraryRepository(client: openLibClient),
        );

        final results = await composite.search('978-013-235-088-4', filter: 'isbn');

        expect(results.length, 1);
        expect(results.first.title, 'Clean Code');
        expect(results.first.priceAmount, 350000.0);
        expect(openLibCalled, isFalse);
      });

      test('Scan barcode: kosong di Google -> coba Open Library', () async {
        final googleClient = MockClient((request) async {
          return http.Response(jsonEncode({'items': []}), 200);
        });

        final openLibClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'ISBN:9780132350884': {
                'title': 'Clean Code (OpenLibrary Edition)',
                'authors': [
                  {'name': 'Robert C. Martin'}
                ],
                'identifiers': {
                  'isbn_13': ['9780132350884']
                }
              }
            }),
            200,
          );
        });

        final composite = CompositeBookSearchRepository(
          googleRepo: GoogleBooksRepository(client: googleClient),
          openLibraryRepo: OpenLibraryRepository(client: openLibClient),
        );

        final results = await composite.search('9780132350884', filter: 'isbn');

        expect(results.length, 1);
        expect(results.first.title, 'Clean Code (OpenLibrary Edition)');
        expect(results.first.priceAmount, isNull);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // 5. Deduplikasi (ISBN-13 dan Judul+Penulis) & Aturan Harga
    // ══════════════════════════════════════════════════════════════════════════
    group('5. Deduplikasi dan Integritas Data Harga', () {
      test('Deduplikasi berdasarkan ISBN-13 mempertahankan harga Google', () {
        const googleBook = BookSearchResult(
          googleBooksId: 'g_1',
          title: 'Pemrograman Dart',
          authors: 'Budi Santoso',
          isbn: '9786020001112',
          priceAmount: 75000.0,
          priceCurrency: 'IDR',
        );

        const openLibBook = BookSearchResult(
          googleBooksId: 'openlib:ol_1',
          title: 'Pemrograman Dart',
          authors: 'Budi Santoso',
          isbn: '978-602-000-111-2', // Format dengan strip
          priceAmount: null,
          priceCurrency: null,
        );

        final combined = CompositeBookSearchRepository.deduplicateBooks([
          googleBook,
          openLibBook,
        ]);

        expect(combined.length, 1);
        expect(combined.first.googleBooksId, 'g_1');
        expect(combined.first.priceAmount, 75000.0);
        expect(combined.first.priceCurrency, 'IDR');
      });

      test('Deduplikasi berdasarkan Judul+Penulis (jika tanpa ISBN)', () {
        const book1 = BookSearchResult(
          googleBooksId: 'g_2',
          title: 'Filosofi Teras',
          authors: 'Henry Manampiring',
          isbn: null,
          priceAmount: 88000.0,
          priceCurrency: 'IDR',
        );

        const book2 = BookSearchResult(
          googleBooksId: 'openlib:ol_2',
          title: 'filosofi teras', // Case-insensitive
          authors: 'Henry Manampiring',
          isbn: null,
          priceAmount: null,
          priceCurrency: null,
        );

        final combined = CompositeBookSearchRepository.deduplicateBooks([
          book1,
          book2,
        ]);

        expect(combined.length, 1);
        expect(combined.first.priceAmount, 88000.0);
      });

      test('Buku yang hanya ada di Open Library tidak mengarang harga (price null)', () {
        const openLibOnly = BookSearchResult(
          googleBooksId: 'openlib:ol_3',
          title: 'Catatan Pinggir',
          authors: 'Goenawan Mohamad',
          isbn: '9789791112223',
          priceAmount: null,
          priceCurrency: null,
        );

        final combined = CompositeBookSearchRepository.deduplicateBooks([openLibOnly]);

        expect(combined.length, 1);
        expect(combined.first.priceAmount, isNull);
        expect(combined.first.priceCurrency, isNull);
      });
    });

    // ══════════════════════════════════════════════════════════════════════════
    // 6. In-Memory Cache 5 Menit
    // ══════════════════════════════════════════════════════════════════════════
    group('6. In-Memory Cache (TTL 5 Menit)', () {
      test('Pencarian berulang dalam 5 menit menggunakan cache memori tanpa HTTP baru', () async {
        int httpCalls = 0;
        final mockClient = MockClient((request) async {
          httpCalls++;
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'g_cache_1',
                  'volumeInfo': {'title': 'Cached Book', 'authors': ['Tester']}
                }
              ]
            }),
            200,
          );
        });

        final composite = CompositeBookSearchRepository(
          googleRepo: GoogleBooksRepository(client: mockClient),
        );

        expect(composite.cacheSize, 0);

        // Request 1: harus memanggil HTTP
        final res1 = await composite.search('cached query');
        expect(res1.length, 1);
        expect(httpCalls, 1);
        expect(composite.cacheSize, 1);

        // Request 2: query yang sama harus mengambil dari cache memori
        final res2 = await composite.search('cached query');
        expect(res2.length, 1);
        expect(httpCalls, 1); // Tidak ada HTTP call tambahan!

        // Setelah cache dibersihkan, request baru akan memanggil HTTP kembali
        composite.clearCache();
        expect(composite.cacheSize, 0);
        final res3 = await composite.search('cached query');
        expect(res3.length, 1);
        expect(httpCalls, 2);
      });
    });
  });
}
