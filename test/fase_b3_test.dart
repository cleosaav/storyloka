import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:storyloka/core/services/sensor_service.dart';
import 'package:storyloka/data/repositories/remote/google_books_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase B3 — GoogleBooksRepository Tests', () {
    test('query kosong mengembalikan list kosong tanpa memanggil HTTP', () async {
      var called = false;
      final mockClient = MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });

      final repo = GoogleBooksRepository(client: mockClient);
      final results = await repo.search('   ');

      expect(results, isEmpty);
      expect(called, isFalse);
    });

    test('mapping field: cover http diubah ke https, HTML sinopsis dibersihkan, dan harga dari saleInfo', () async {
      final sampleJson = {
        'totalItems': 1,
        'items': [
          {
            'id': 'book123',
            'volumeInfo': {
              'title': 'Bumi Manusia',
              'authors': ['Pramoedya Ananta Toer'],
              'categories': ['Historical Fiction'],
              'industryIdentifiers': [
                {'type': 'ISBN_13', 'identifier': '9789799731234'}
              ],
              'publisher': 'Lentera Dipantara',
              'pageCount': 535,
              'imageLinks': {
                'thumbnail': 'http://books.google.com/books/content?id=book123&printsec=frontcover'
              },
              'description': '<p>Kisah cinta antara <b>Minke</b> dan <i>Annelies</i>.<br/>Berlatar kolonial.</p>'
            },
            'saleInfo': {
              'saleability': 'FOR_SALE',
              'isEbook': true,
              'listPrice': {
                'amount': 95000.0,
                'currencyCode': 'IDR',
              }
            }
          }
        ]
      };

      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['q'], contains('intitle:Bumi Manusia'));
        return http.Response(jsonEncode(sampleJson), 200);
      });

      final repo = GoogleBooksRepository(client: mockClient);
      final results = await repo.search('Bumi Manusia', filter: 'title');

      expect(results.length, 1);
      final book = results.first;

      expect(book.googleBooksId, 'book123');
      expect(book.title, 'Bumi Manusia');
      expect(book.authors, 'Pramoedya Ananta Toer');
      expect(book.isbn, '9789799731234');
      // Cover harus https
      expect(book.coverUrl, startsWith('https://'));
      // HTML sinopsis harus dibersihkan
      expect(book.synopsis, contains('Kisah cinta antara Minke dan Annelies.'));
      expect(book.synopsis, isNot(contains('<p>')));
      expect(book.synopsis, isNot(contains('<b>')));
      // Harga dari saleInfo
      expect(book.priceAmount, 95000.0);
      expect(book.priceCurrency, 'IDR');
    });

    test('ISBN search menormalkan tanda hubung dan spasi', () async {
      String? queriedQ;
      final mockClient = MockClient((request) async {
        queriedQ = request.url.queryParameters['q'];
        return http.Response(jsonEncode({'items': []}), 200);
      });

      final repo = GoogleBooksRepository(client: mockClient);
      await repo.search('978-979-973-123-4', filter: 'isbn');

      expect(queriedQ, 'isbn:9789799731234');
    });

    test('author filter menyusun parameter q dengan benar', () async {
      String? queriedQ;
      final mockClient = MockClient((request) async {
        queriedQ = request.url.queryParameters['q'];
        return http.Response(jsonEncode({'items': []}), 200);
      });

      final repo = GoogleBooksRepository(client: mockClient);
      await repo.search('Pramoedya', filter: 'author');

      expect(queriedQ, 'inauthor:Pramoedya');
    });

    test('respons HTTP non-200 melempar Exception', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final repo = GoogleBooksRepository(client: mockClient);
      expect(() => repo.search('test'), throwsA(isA<Exception>()));
    });

    test('respons HTTP 200 tapi items null atau kosong mengembalikan list kosong', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'totalItems': 0}), 200);
      });

      final repo = GoogleBooksRepository(client: mockClient);
      final results = await repo.search('querytidakada12345');

      expect(results, isEmpty);
    });

    test('timeout 15 detik ditangani dengan exception berbahasa Indonesia', () async {
      final mockClient = MockClient((request) async {
        // Simulasi delay lebih dari 15s dengan TimeoutException langsung
        throw TimeoutException('Connection timed out');
      });

      final repo = GoogleBooksRepository(client: mockClient);
      expect(
        () => repo.search('test'),
        throwsA(predicate((e) => e.toString().contains('Koneksi ke server buku gagal (timeout 15 detik)'))),
      );
    });

    test('randomBook mengembalikan buku dari subjek acak', () async {
      final sampleJson = {
        'items': [
          {
            'id': 'rand1',
            'volumeInfo': {
              'title': 'Buku Acak',
              'authors': ['Penulis Acak'],
            }
          }
        ]
      };

      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['q'], contains('subject:'));
        return http.Response(jsonEncode(sampleJson), 200);
      });

      final repo = GoogleBooksRepository(client: mockClient);
      final book = await repo.randomBook();

      expect(book, isNotNull);
      expect(book?.title, 'Buku Acak');
    });
  });

  group('Fase B3 — SensorService Tests', () {
    test('SensorService adalah singleton', () {
      final s1 = SensorService.instance;
      final s2 = SensorService.instance;
      expect(identical(s1, s2), isTrue);
    });

    test('SensorService startListening dan stopListening tidak melempar error', () {
      final service = SensorService.instance;
      expect(() => service.startListening(), returnsNormally);
      expect(() => service.stopListening(), returnsNormally);
    });
  });
}
