import '../models/user_book.dart';

/// Kontrak library (koleksi + wishlist) — PRD §13.0.
abstract class LibraryRepository {
  /// Ambil semua buku milik pengguna (belum dihapus).
  Future<List<UserBook>> getBooks({ListType? listType});

  /// Ambil satu buku berdasarkan ID.
  Future<UserBook?> getBookById(String id);

  /// Cek apakah buku sudah ada berdasarkan googleBooksId.
  Future<UserBook?> findByGoogleBooksId(String googleBooksId);

  /// Tambahkan buku ke koleksi/wishlist.
  Future<UserBook> addBook(UserBook book);

  /// Perbarui data buku.
  Future<UserBook> updateBook(UserBook book);

  /// Soft delete buku.
  Future<void> deleteBook(String id);

  /// Pindahkan buku dari wishlist ke collection.
  Future<UserBook> moveToCollection(String id);

  /// Buku yang sedang dibaca (Currently Reading — last_read_at terbaru).
  Future<UserBook?> getCurrentlyReading();
}
