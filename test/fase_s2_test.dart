import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:storyloka/core/services/ledger_service.dart';
import 'package:storyloka/data/models/ledger_block.dart';
import 'package:storyloka/data/models/user_book.dart';
import 'package:storyloka/data/repositories/book_search_repository.dart';
import 'helpers/fake/fake_repositories.dart';
import 'package:storyloka/data/repositories/ledger_repository.dart';
import 'package:storyloka/data/repositories/library_repository.dart';
import 'package:storyloka/data/repositories/reading_repository.dart';
import 'package:storyloka/features/reading/reading_progress_page.dart';

class _MockLedgerRepository implements LedgerRepository {
  final List<LedgerBlock> _blocks = [];

  @override
  Future<List<LedgerBlock>> getBlocks() async => List.unmodifiable(_blocks);

  @override
  Future<void> saveBlock(LedgerBlock block) async => _blocks.add(block);

  @override
  Future<LedgerBlock?> getLastBlock() async =>
      _blocks.isEmpty ? null : _blocks.last;
}

Widget _wrapWithProviders({
  required Widget child,
  required LibraryRepository libraryRepo,
  BookSearchRepository? searchRepo,
  ReadingRepository? readingRepo,
  LedgerService? ledgerService,
}) {
  final lService = ledgerService ?? LedgerService(_MockLedgerRepository());

  return MultiProvider(
    providers: [
      Provider<LibraryRepository>.value(value: libraryRepo),
      Provider<BookSearchRepository>.value(
        value: searchRepo ?? FakeBookSearchRepository(),
      ),
      Provider<ReadingRepository>.value(
        value: readingRepo ?? FakeReadingRepository(),
      ),
      Provider<LedgerService>.value(value: lService),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    fakeRepositoriesEnableLatency = false;
  });

  group('Fase S2: Input Halaman Manual & Validasi Stabilitas', () {
    testWidgets(
      '1. Ketik "350" di total halaman: field tetap tampil (tidak hilang saat digit pertama diketik) dan bernilai 350',
      (tester) async {
        final libRepo = FakeLibraryRepository();
        final bookWithoutPages = UserBook(
          id: 'book-no-pages',
          userId: 'user-1',
          googleBooksId: 'gb-no-pages',
          title: 'Buku Tanpa Halaman',
          listType: ListType.collection,
          status: BookStatus.reading,
          pageCount: null, // Tanpa total halaman
          currentPage: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await libRepo.addBook(bookWithoutPages);

        await tester.pumpWidget(
          _wrapWithProviders(
            libraryRepo: libRepo,
            child: const ReadingProgressPage(id: 'book-no-pages'),
          ),
        );
        await tester.pumpAndSettle();

        // Verifikasi card total halaman wajib muncul
        expect(find.text('Total Halaman Buku (Wajib)'), findsOneWidget);

        final totalPageFieldFinder = find.descendant(
          of: find.byKey(const Key('total_page_input')),
          matching: find.byType(TextField),
        );
        expect(totalPageFieldFinder, findsOneWidget);

        // Ketik digit pertama "3"
        await tester.enterText(totalPageFieldFinder, '3');
        await tester.pump();

        // Field HARUS TETAP ADA dan tidak hilang!
        expect(find.text('Total Halaman Buku (Wajib)'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);

        // Ketik digit kedua "5" -> "35"
        await tester.enterText(totalPageFieldFinder, '35');
        await tester.pump();
        expect(find.text('Total Halaman Buku (Wajib)'), findsOneWidget);
        expect(find.text('35'), findsOneWidget);

        // Ketik digit ketiga "0" -> "350"
        await tester.enterText(totalPageFieldFinder, '350');
        await tester.pumpAndSettle();
        expect(find.text('Total Halaman Buku (Wajib)'), findsOneWidget);
        expect(find.text('350'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Ketik "120" di halaman saat ini: nilai terupdate dan kursor stabil',
      (tester) async {
        final libRepo = FakeLibraryRepository();
        final book = UserBook(
          id: 'book-valid',
          userId: 'user-1',
          googleBooksId: 'gb-valid',
          title: 'Buku Filosofi',
          listType: ListType.collection,
          status: BookStatus.reading,
          pageCount: 350,
          currentPage: 10,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await libRepo.addBook(book);

        await tester.pumpWidget(
          _wrapWithProviders(
            libraryRepo: libRepo,
            child: const ReadingProgressPage(id: 'book-valid'),
          ),
        );
        await tester.pumpAndSettle();

        // Cari input halaman saat ini via key
        final currentPageField = find.descendant(
          of: find.byKey(const Key('current_page_input')),
          matching: find.byType(TextField),
        );
        expect(currentPageField, findsOneWidget);

        // Ketik 120
        await tester.enterText(currentPageField, '120');
        await tester.pumpAndSettle();

        expect(find.text('120'), findsOneWidget);
        expect(find.text('Halaman tidak boleh melebihi total (350)'), findsNothing);

        // Tombol Save Progress harus aktif
        final saveBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save Progress'),
        );
        expect(saveBtn.onPressed, isNotNull);
      },
    );

    testWidgets(
      '3. Ketik angka melebihi total memunculkan error dan Save nonaktif',
      (tester) async {
        final libRepo = FakeLibraryRepository();
        final book = UserBook(
          id: 'book-350',
          userId: 'user-1',
          googleBooksId: 'gb-350',
          title: 'Buku 350 Halaman',
          listType: ListType.collection,
          status: BookStatus.reading,
          pageCount: 350,
          currentPage: 50,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await libRepo.addBook(book);

        await tester.pumpWidget(
          _wrapWithProviders(
            libraryRepo: libRepo,
            child: const ReadingProgressPage(id: 'book-350'),
          ),
        );
        await tester.pumpAndSettle();

        final currentPageField = find.descendant(
          of: find.byKey(const Key('current_page_input')),
          matching: find.byType(TextField),
        );
        // Ketik 400 (melebihi 350)
        await tester.enterText(currentPageField, '400');
        await tester.pumpAndSettle();

        // Pesan error harus muncul di bawah field
        expect(find.text('Halaman tidak boleh melebihi total (350)'), findsOneWidget);

        // Tombol Save Progress harus nonaktif (onPressed: null)
        final saveBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save Progress'),
        );
        expect(saveBtn.onPressed, isNull);
      },
    );

    testWidgets(
      '4. Save menyimpan nilai yang benar ke repository',
      (tester) async {
        final libRepo = FakeLibraryRepository();
        final book = UserBook(
          id: 'book-save',
          userId: 'user-1',
          googleBooksId: 'gb-save',
          title: 'Buku Siap Simpan',
          listType: ListType.collection,
          status: BookStatus.reading,
          pageCount: null,
          currentPage: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await libRepo.addBook(book);

        await tester.pumpWidget(
          _wrapWithProviders(
            libraryRepo: libRepo,
            child: const ReadingProgressPage(id: 'book-save'),
          ),
        );
        await tester.pumpAndSettle();

        // Isi total halaman 250
        final totalPageField = find.descendant(
          of: find.byKey(const Key('total_page_input')),
          matching: find.byType(TextField),
        );
        await tester.enterText(totalPageField, '250');
        await tester.pumpAndSettle();

        // Isi halaman saat ini 75
        final currentPageField = find.descendant(
          of: find.byKey(const Key('current_page_input')),
          matching: find.byType(TextField),
        );
        await tester.enterText(currentPageField, '75');
        await tester.pumpAndSettle();

        // Klik Save Progress
        final saveBtn = find.widgetWithText(ElevatedButton, 'Save Progress');
        expect(saveBtn, findsOneWidget);
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Cek data di repository
        final updatedBook = await libRepo.getBookById('book-save');
        expect(updatedBook, isNotNull);
        expect(updatedBook!.pageCount, 250);
        expect(updatedBook.currentPage, 75);
      },
    );

    testWidgets(
      '5. Tautan "Ubah total halaman" membuka kembali field total halaman',
      (tester) async {
        final libRepo = FakeLibraryRepository();
        final book = UserBook(
          id: 'book-edit-total',
          userId: 'user-1',
          googleBooksId: 'gb-edit',
          title: 'Buku Salah Halaman',
          listType: ListType.collection,
          status: BookStatus.reading,
          pageCount: 150,
          currentPage: 20,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await libRepo.addBook(book);

        await tester.pumpWidget(
          _wrapWithProviders(
            libraryRepo: libRepo,
            child: const ReadingProgressPage(id: 'book-edit-total'),
          ),
        );
        await tester.pumpAndSettle();

        // Di awal, kartu "Total Halaman Buku" tidak muncul karena pageCount sudah ada (150)
        expect(find.text('Ubah Total Halaman Buku'), findsNothing);

        // Tautan kecil "Ubah total halaman" harus ada
        final editLink = find.byKey(const Key('change_total_pages_link'));
        expect(editLink, findsOneWidget);

        // Tap tautan
        await tester.tap(editLink);
        await tester.pumpAndSettle();

        // Kartu "Ubah Total Halaman Buku" sekarang harus tampil
        expect(find.text('Ubah Total Halaman Buku'), findsOneWidget);

        // Ubah total halaman menjadi 300
        final totalPageField = find.descendant(
          of: find.byKey(const Key('total_page_input')),
          matching: find.byType(TextField),
        );
        await tester.enterText(totalPageField, '300');
        await tester.pumpAndSettle();

        // Simpan
        final saveBtn = find.widgetWithText(ElevatedButton, 'Save Progress');
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        final updated = await libRepo.getBookById('book-edit-total');
        expect(updated?.pageCount, 300);
      },
    );

    testWidgets(
      '6. Slider divisions null saat total halaman > 300',
      (tester) async {
        final libRepo = FakeLibraryRepository();
        final bigBook = UserBook(
          id: 'book-big',
          userId: 'user-1',
          googleBooksId: 'gb-big',
          title: 'Buku Tebal 800 Hlm',
          listType: ListType.collection,
          status: BookStatus.reading,
          pageCount: 800,
          currentPage: 50,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await libRepo.addBook(bigBook);

        await tester.pumpWidget(
          _wrapWithProviders(
            libraryRepo: libRepo,
            child: const ReadingProgressPage(id: 'book-big'),
          ),
        );
        await tester.pumpAndSettle();

        final sliderFinder = find.byType(Slider);
        expect(sliderFinder, findsOneWidget);
        final slider = tester.widget<Slider>(sliderFinder);
        expect(slider.divisions, isNull, reason: 'Total halaman > 300 tidak boleh memakai divisions agar tidak berat');
      },
    );

    testWidgets(
      '7. "Finished This Book" tetap bekerja dan menandai buku selesai',
      (tester) async {
        final libRepo = FakeLibraryRepository();
        final book = UserBook(
          id: 'book-finish-test',
          userId: 'user-1',
          googleBooksId: 'gb-finish',
          title: 'Buku Menjelang Tamat',
          listType: ListType.collection,
          status: BookStatus.reading,
          pageCount: 200,
          currentPage: 180,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await libRepo.addBook(book);

        await tester.pumpWidget(
          _wrapWithProviders(
            libraryRepo: libRepo,
            child: const ReadingProgressPage(id: 'book-finish-test'),
          ),
        );
        await tester.pumpAndSettle();

        final finishBtn = find.widgetWithText(OutlinedButton, 'Finished This Book');
        expect(finishBtn, findsOneWidget);
        await tester.ensureVisible(finishBtn);
        await tester.tap(finishBtn);
        await tester.pumpAndSettle();

        // Konfirmasi dialog muncul
        expect(find.text('Selesaikan Buku Ini?'), findsOneWidget);
        final confirmBtn = find.text('Ya, Selesai');
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        final updated = await libRepo.getBookById('book-finish-test');
        expect(updated?.status, BookStatus.finished);
        expect(updated?.currentPage, 200);
      },
    );
  });
}
