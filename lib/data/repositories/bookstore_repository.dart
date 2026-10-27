import '../models/bookstore.dart';

/// Kontrak repositori pencarian toko buku terdekat & geocoding lokasi — PRD §9.4 & Fase S6.
abstract class BookstoreRepository {
  /// Mengambil daftar toko buku terdekat di sekitar koordinat [lat] dan [lng].
  ///
  /// Menggunakan radius awal [initialRadiusKm] (default 15.0 km).
  /// Jika tidak ada toko buku yang ditemukan, pencarian otomatis memperluas radius bertahap hingga 50 km.
  /// Toko yang dikembalikan wajib terurut dari jarak terdekat (Haversine).
  Future<List<Bookstore>> getNearbyBookstores({
    required double lat,
    required double lng,
    double initialRadiusKm = 15.0,
  });

  /// Mencari lokasi atau nama kota/daerah secara manual lewat Nominatim OSM.
  Future<List<PlaceResult>> searchPlaces(String query);
}
