import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:storyloka/core/theme/app_theme.dart';
import 'package:storyloka/data/models/user_book.dart';
import 'package:storyloka/data/repositories/book_search_repository.dart';
import 'helpers/fake/fake_repositories.dart';
import 'package:storyloka/data/repositories/library_repository.dart';
import 'package:storyloka/data/repositories/remote/composite_book_search_repository.dart';
import 'package:storyloka/data/repositories/remote/google_books_repository.dart';
import 'package:storyloka/data/repositories/remote/open_library_repository.dart';
import 'package:storyloka/features/book_detail/collection_book_detail_page.dart';
import 'package:storyloka/features/book_detail/search_book_detail_page.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    fakeRepositoriesEnableLatency = false;
    await initializeDateFormatting('id_ID', null);
  });

  group('Fase S3: Pengayaan Informasi Buku (Sinopsis, Harga, Halaman)', () {
    // Fixture 1: Google Books Detail dengan Harga
    const fixtureWithPrice = '''
{
  "id": "gb_price_1",
  "volumeInfo": {
    "title": "Bumi Manusia",
    "subtitle": "Sebuah Roman Sejarah",
    "authors": ["Pramoedya Ananta Toer"],
    "publisher": "Lentera Dipantara",
    "publishedDate": "1980",
    "description": "<p>Kisah cinta antara Minke dan Annelies di era kolonial Hindia Belanda.</p>",
    "pageCount": 535,
    "printedPageCount": 540,
    "categories": ["Fiction", "Historical"],
    "language": "id",
    "averageRating": 4.8,
    "ratingsCount": 1200,
    "imageLinks": {
      "thumbnail": "http://books.google.com/books/content?id=gb_price_1&printsec=frontcover&img=1"
    },
    "industryIdentifiers": [
      {"type": "ISBN_13", "identifier": "9789799731234"},
      {"type": "ISBN_10", "identifier": "9799731234"}
    ],
    "infoLink": "https://books.google.co.id/books?id=gb_price_1"
  },
  "saleInfo": {
    "country": "ID",
    "saleability": "FOR_SALE",
    "listPrice": {"amount": 95000.0, "currencyCode": "IDR"},
    "retailPrice": {"amount": 85000.0, "currencyCode": "IDR"},
    "buyLink": "https://play.google.com/store/books/details?id=gb_price_1"
  }
}
''';

    // Fixture 2: Google Books Detail Tanpa Harga (NOT_FOR_SALE)
    const fixtureNotForSale = '''
{
  "id": "gb_not_for_sale",
  "volumeInfo": {
    "title": "Laskar Pelangi",
    "authors": ["Andrea Hirata"],
    "publisher": "Bentang Pustaka",
    "description": "Perjuangan sepuluh anak di Belitung bersekolah di tengah keterbatasan.",
    "pageCount": 529,
    "categories": ["Fiction"],
    "imageLinks": {
      "thumbnail": "https://books.google.com/books/content?id=gb_not_for_sale"
    },
    "industryIdentifiers": [
      {"type": "ISBN_13", "identifier": "9789793062792"}
    ]
  },
  "saleInfo": {
    "country": "ID",
    "saleability": "NOT_FOR_SALE"
  }
}
''';

    // Fixture 3: Google Books Detail Tanpa Description (perlu fallback Open Library)
    const fixtureNoDescription = '''
{
  "id": "gb_no_desc",
  "volumeInfo": {
    "title": "Catatan Seorang Demonstran",
    "authors": ["Soe Hok Gie"],
    "publisher": "LP3ES",
    "description": "",
    "pageCount": 0,
    "printedPageCount": 0,
    "industryIdentifiers": [
      {"type": "ISBN_13", "identifier": "9789798015502"}
    ]
  },
  "saleInfo": {
    "country": "ID",
    "saleability": "NOT_FOR_SALE"
  }
}
''';

    // Fixture 4: Open Library API Books response (jscmd=data)
    const fixtureOpenLibraryIsbn = '''
{
  "ISBN:9789798015502": {
    "title": "Catatan Seorang Demonstran",
    "number_of_pages": 385,
    "subjects": [{"name": "Biography"}],
    "notes": "Buku harian aktivis Soe Hok Gie yang mencatat pergolakan mahasiswa era 1960-an."
  }
}
''';

    test('1. GoogleBooksRepository.getDetail mengambil volumeInfo dan saleInfo dengan harga lengkap',
        () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        expect(request.url.path, contains('/volumes/gb_price_1'));
        expect(request.url.queryParameters['country'], equals('ID'));
        return http.Response(fixtureWithPrice, 200);
      });

      final repo = GoogleBooksRepository(client: mockClient);
      final detail = await repo.getDetail('gb_price_1');

      expect(detail, isNotNull);
      expect(detail!.title, equals('Bumi Manusia'));
      expect(detail.subtitle, equals('Sebuah Roman Sejarah'));
      expect(detail.authors, equals('Pramoedya Ananta Toer'));
      expect(detail.publisher, equals('Lentera Dipantara'));
      expect(detail.pageCount, equals(535));
      expect(detail.isbn, equals('9789799731234'));
      expect(detail.coverUrl, startsWith('https://'));
      expect(detail.synopsis,
          contains('Kisah cinta antara Minke dan Annelies'));
      expect(detail.priceAmount, equals(85000.0));
      expect(detail.priceCurrency, equals('IDR'));
      expect(detail.saleability, equals('FOR_SALE'));
      expect(detail.buyLink, contains('play.google.com'));
      expect(detail.synopsisSource, equals('Google Books'));
      expect(requestCount, equals(1));
    });

    test('2. GoogleBooksRepository.getDetail menangani status NOT_FOR_SALE dan harga kosong secara akurat',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(fixtureNotForSale, 200);
      });

      final repo = GoogleBooksRepository(client: mockClient);
      final detail = await repo.getDetail('gb_not_for_sale');

      expect(detail, isNotNull);
      expect(detail!.title, equals('Laskar Pelangi'));
      expect(detail.saleability, equals('NOT_FOR_SALE'));
      expect(detail.priceAmount, isNull);
      expect(detail.priceCurrency, isNull);
    });

    test('3. Cache in-memory 10 menit mencegah pemanggilan HTTP berulang', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(fixtureWithPrice, 200);
      });

      final repo = GoogleBooksRepository(client: mockClient);

      // Panggilan pertama -> request HTTP
      final d1 = await repo.getDetail('gb_price_1');
      expect(d1, isNotNull);
      expect(requestCount, equals(1));
      expect(repo.detailCacheSize, equals(1));

      // Panggilan kedua -> ambil dari cache, tanpa request HTTP
      final d2 = await repo.getDetail('gb_price_1');
      expect(d2, isNotNull);
      expect(requestCount, equals(1));

      // Bersihkan cache -> memicu request baru
      repo.clearDetailCache();
      expect(repo.detailCacheSize, equals(0));
      await repo.getDetail('gb_price_1');
      expect(requestCount, equals(2));
    });

    test('4. CompositeBookSearchRepository: Rantai pengayaan Open Library mengisi sinopsis dan halaman yang kosong',
        () async {
      final mockClient = MockClient((request) async {
        final path = request.url.toString();
        if (path.contains('googleapis.com/books/v1/volumes/gb_no_desc')) {
          return http.Response(fixtureNoDescription, 200);
        }
        if (path.contains('openlibrary.org/api/books') &&
            path.contains('9789798015502')) {
          return http.Response(fixtureOpenLibraryIsbn, 200);
        }
        return http.Response('{}', 404);
      });

      final googleRepo = GoogleBooksRepository(client: mockClient);
      final openLibraryRepo = OpenLibraryRepository(client: mockClient);
      final compositeRepo = CompositeBookSearchRepository(
        googleRepo: googleRepo,
        openLibraryRepo: openLibraryRepo,
      );

      final detail = await compositeRepo.getDetail('gb_no_desc');
      expect(detail, isNotNull);
      expect(detail!.title, equals('Catatan Seorang Demonstran'));
      // Halaman diisi oleh Open Library (385)
      expect(detail.pageCount, equals(385));
      // Sinopsis diisi oleh Open Library
      expect(detail.synopsis, contains('Buku harian aktivis Soe Hok Gie'));
      expect(detail.synopsisSource, equals('Open Library'));
    });

    test('5. BookSearchResult.mergeWith: Nilai non-null dari detail menggantikan data minimal awal', () {
      const initialBook = BookSearchResult(
        googleBooksId: 'gb_merge_test',
        title: 'Judul Dasar',
        authors: 'Penulis A',
        synopsis: null,
        pageCount: null,
        priceAmount: null,
      );

      const detailBook = BookSearchResult(
        googleBooksId: 'gb_merge_test',
        title: 'Judul Dasar Lengkap',
        authors: 'Penulis A, Penulis B',
        synopsis: 'Sinopsis lengkap hasil detail',
        pageCount: 420,
        priceAmount: 75000.0,
        priceCurrency: 'IDR',
        saleability: 'FOR_SALE',
      );

      final merged = initialBook.mergeWith(detailBook);
      expect(merged.title, equals('Judul Dasar Lengkap'));
      expect(merged.authors, equals('Penulis A, Penulis B'));
      expect(merged.synopsis, equals('Sinopsis lengkap hasil detail'));
      expect(merged.pageCount, equals(420));
      expect(merged.priceAmount, equals(75000.0));
      expect(merged.priceCurrency, equals('IDR'));
    });

    testWidgets('6. SearchBookDetailPage: Error 429/timeout detail tidak menghapus data yang sudah ada',
        (tester) async {
      final fakeSearchRepo = FakeBookSearchRepository();
      // Simulasikan buku awal
      const sampleBook = BookSearchResult(
        googleBooksId: 'sample_err_book',
        title: 'Buku Tetap Ada Walau Error',
        authors: 'Penulis Setia',
        synopsis: 'Sinopsis awal yang tidak boleh hilang.',
        pageCount: 250,
      );

      final fakeLibrary = FakeLibraryRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<BookSearchRepository>.value(value: fakeSearchRepo),
            Provider<LibraryRepository>.value(value: fakeLibrary),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: SearchBookDetailPage(book: sampleBook),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Pastikan judul, penulis, dan sinopsis awal tetap terlihat
      expect(find.text('Buku Tetap Ada Walau Error'), findsOneWidget);
      expect(find.text('Penulis Setia'), findsOneWidget);
      expect(find.text('Sinopsis awal yang tidak boleh hilang.'), findsOneWidget);
    });

    testWidgets('7. SearchBookDetailPage: Menampilkan alasan jujur dan tombol saat harga tidak tersedia',
        (tester) async {
      final fakeSearchRepo = FakeBookSearchRepository();
      fakeSearchRepo.setMockDetail(
        'book_not_for_sale',
        const BookSearchResult(
          googleBooksId: 'book_not_for_sale',
          title: 'Buku Cetak Tanpa E-Book',
          authors: 'Penulis Klasik',
          synopsis: 'Buku cetak fisik lama.',
          pageCount: 300,
          saleability: 'NOT_FOR_SALE',
          priceAmount: null,
        ),
      );

      final fakeLibrary = FakeLibraryRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<BookSearchRepository>.value(value: fakeSearchRepo),
            Provider<LibraryRepository>.value(value: fakeLibrary),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: SearchBookDetailPage(
              book: BookSearchResult(
                googleBooksId: 'book_not_for_sale',
                title: 'Buku Cetak Tanpa E-Book',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Alasan akurat terlihat
      expect(
        find.text('Buku ini tidak dijual secara digital di Google Play Books.'),
        findsOneWidget,
      );

      // Dua tombol jujur terlihat
      expect(find.byKey(const Key('btn_view_google_play')), findsOneWidget);
      expect(find.byKey(const Key('btn_search_online_stores')), findsOneWidget);
    });

    testWidgets('8. SearchBookDetailPage: Add to Collection menyimpan data hasil gabungan yang lengkap',
        (tester) async {
      final fakeSearchRepo = FakeBookSearchRepository();
      fakeSearchRepo.setMockDetail(
        'enrich_save_book',
        const BookSearchResult(
          googleBooksId: 'enrich_save_book',
          title: 'Judul Buku Gabungan',
          authors: 'Penulis Lengkap',
          genre: 'Literature',
          isbn: '9781112223334',
          pageCount: 450,
          synopsis: 'Sinopsis lengkap hasil getDetail.',
          priceAmount: 88000.0,
          priceCurrency: 'IDR',
        ),
      );

      final fakeLibrary = FakeLibraryRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<BookSearchRepository>.value(value: fakeSearchRepo),
            Provider<LibraryRepository>.value(value: fakeLibrary),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: SearchBookDetailPage(
              book: BookSearchResult(
                googleBooksId: 'enrich_save_book',
                title: 'Judul Buku Gabungan',
                // Data awal kosong
                pageCount: null,
                synopsis: null,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Klik tombol Add to Collection
      final addBtn = find.text('Add to Collection');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Periksa buku di repository
      final savedBook = await fakeLibrary.findByGoogleBooksId('enrich_save_book');
      expect(savedBook, isNotNull);
      // Yang disimpan adalah nilai hasil gabungan (450 hlm dan sinopsis lengkap)
      expect(savedBook!.pageCount, equals(450));
      expect(savedBook.synopsis, equals('Sinopsis lengkap hasil getDetail.'));
      expect(savedBook.priceAmount, equals(88000.0));
      expect(savedBook.genre, equals('Literature'));
    });

    testWidgets('9. CollectionBookDetailPage & WishlistBookDetailPage melakukan enrichment otomatis saat data kosong',
        (tester) async {
      final fakeSearchRepo = FakeBookSearchRepository();
      fakeSearchRepo.setMockDetail(
        'book_bg_enrich',
        const BookSearchResult(
          googleBooksId: 'book_bg_enrich',
          title: 'Buku Koleksi Minim Data',
          authors: 'Penulis X',
          pageCount: 365,
          synopsis: 'Sinopsis hasil background enrichment.',
        ),
      );

      final fakeLibrary = FakeLibraryRepository();
      final now = DateTime.now();
      final initialUserBook = UserBook(
        id: 'user_book_enrich_1',
        userId: 'demo_user',
        googleBooksId: 'book_bg_enrich',
        title: 'Buku Koleksi Minim Data',
        pageCount: null, // Kosong
        synopsis: null, // Kosong
        listType: ListType.collection,
        status: BookStatus.reading,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'synced',
      );
      await fakeLibrary.addBook(initialUserBook);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<BookSearchRepository>.value(value: fakeSearchRepo),
            Provider<LibraryRepository>.value(value: fakeLibrary),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: CollectionBookDetailPage(id: 'user_book_enrich_1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Data di layar terupdate dengan hasil enrichment
      expect(find.text('Sinopsis hasil background enrichment.'), findsOneWidget);

      // Data di database terupdate dan ditandai syncStatus = pending
      final updated = await fakeLibrary.getBookById('user_book_enrich_1');
      expect(updated, isNotNull);
      expect(updated!.pageCount, equals(365));
      expect(updated.synopsis, equals('Sinopsis hasil background enrichment.'));
      expect(updated.syncStatus, equals('pending'));
    });
  });
}
