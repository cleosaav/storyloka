import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Client remote untuk Open Library API — PRD §9.1b.
/// Menyediakan fallback pengambilan sinopsis dan cover resolusi tinggi saat Google Books kosong.
class OpenLibraryApi {
  final http.Client _client;

  OpenLibraryApi({http.Client? client}) : _client = client ?? http.Client();

  static const Map<String, String> _headers = {
    'User-Agent': 'StoryLoka/1.0 (student project)',
    'Accept': 'application/json',
  };

  static const Duration _timeout = Duration(seconds: 15);

  /// Helper untuk membersihkan dan menormalisasi ISBN (menghapus spasi dan tanda hubung).
  static String normalizeIsbn(String rawIsbn) {
    return rawIsbn.replaceAll(RegExp(r'[\s\-]'), '').trim();
  }

  /// Mengurai field `description` dari Open Library:
  /// Bisa berupa String atau objek Map `{ "type": "...", "value": "..." }`.
  /// Mengembalikan String hasil trim atau null jika kosong.
  static String? parseDescription(dynamic description) {
    if (description == null) return null;

    String? text;
    if (description is String) {
      text = description;
    } else if (description is Map) {
      final val = description['value'];
      if (val is String) {
        text = val;
      }
    }

    if (text == null) return null;
    final trimmed = text.trim();
    return trimmed.isNotEmpty ? trimmed : null;
  }

  /// Mengambil sinopsis buku dari Open Library berdasarkan ISBN:
  /// 1. GET https://openlibrary.org/isbn/{isbn}.json (ikuti redirect). Status != 200 -> null.
  /// 2. Jika field `description` pada edition ada & tidak kosong -> pakai itu.
  /// 3. Jika tidak, ambil `works[0].key`, lalu GET https://openlibrary.org{key}.json dan baca `description`.
  /// 4. Tangani String atau objek `{type, value}`. Trim; kosong -> null.
  /// Menangkap semua error (jaringan, parse, timeout) dan mengembalikan null (tidak melempar exception).
  Future<String?> fetchSynopsis(String isbn) async {
    final cleanIsbn = normalizeIsbn(isbn);
    if (cleanIsbn.isEmpty) return null;

    try {
      final editionUri = Uri.parse('https://openlibrary.org/isbn/$cleanIsbn.json');
      final editionRes = await _client.get(editionUri, headers: _headers).timeout(_timeout);

      if (editionRes.statusCode != 200) return null;

      final editionData = jsonDecode(editionRes.body);
      if (editionData is! Map<String, dynamic>) return null;

      // 1. Cek description langsung di edition
      final editionDesc = parseDescription(editionData['description']);
      if (editionDesc != null) return editionDesc;

      // 2. Jika tidak ada, ambil works[0].key
      final works = editionData['works'];
      if (works is List && works.isNotEmpty && works.first is Map) {
        final workKey = works.first['key'];
        if (workKey is String && workKey.trim().isNotEmpty) {
          final cleanWorkKey = workKey.trim().startsWith('/') ? workKey.trim() : '/${workKey.trim()}';
          final workUri = Uri.parse('https://openlibrary.org$cleanWorkKey.json');
          final workRes = await _client.get(workUri, headers: _headers).timeout(_timeout);

          if (workRes.statusCode == 200) {
            final workData = jsonDecode(workRes.body);
            if (workData is Map<String, dynamic>) {
              final workDesc = parseDescription(workData['description']);
              if (workDesc != null) return workDesc;
            }
          }
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Memverifikasi keberadaan cover di Open Library lewat HEAD request:
  /// HEAD https://covers.openlibrary.org/b/isbn/{isbn}-L.jpg?default=false
  /// Mengembalikan URL cover jika status 200, selain itu null.
  Future<String?> fetchCoverUrl(String isbn) async {
    final cleanIsbn = normalizeIsbn(isbn);
    if (cleanIsbn.isEmpty) return null;

    final coverUrl = 'https://covers.openlibrary.org/b/isbn/$cleanIsbn-L.jpg?default=false';

    try {
      final res = await _client.head(Uri.parse(coverUrl), headers: _headers).timeout(_timeout);
      if (res.statusCode == 200) {
        return coverUrl;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
