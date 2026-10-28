import 'package:storyloka/data/models/bookstore.dart';
import 'package:storyloka/data/repositories/bookstore_repository.dart';

/// Implementasi Fake BookstoreRepository untuk unit & widget testing — PRD §9.4 & Fase S6.
class FakeBookstoreRepository implements BookstoreRepository {
  bool simulateEmpty = false;
  bool simulateError = false;
  bool expandRadiusOnly = false;

  final List<Bookstore>? customStores;

  FakeBookstoreRepository({
    List<Bookstore>? stores,
    List<Bookstore>? customStores,
    this.simulateEmpty = false,
    bool? shouldThrowError,
    bool simulateError = false,
    this.expandRadiusOnly = false,
  })  : customStores = stores ?? customStores,
        simulateError = shouldThrowError ?? simulateError;

  static List<Bookstore> defaultDummyStores({required double lat, required double lng}) {
    // Generate beberapa toko buku di sekitar koordinat lat/lng
    return [
      Bookstore(
        id: 'node/101',
        name: 'Gramedia Grand Indonesia',
        lat: lat + 0.005,
        lng: lng + 0.004,
        address: 'Grand Indonesia Mall, Jl. M.H. Thamrin No. 1, Jakarta Pusat',
        phone: '+62 21 8581763',
        website: 'https://www.gramedia.com',
        openingHours: 'Senin-Minggu 10:00 - 22:00',
        distanceMeters: calculateHaversineDistance(
          lat1: lat,
          lon1: lng,
          lat2: lat + 0.005,
          lon2: lng + 0.004,
        ),
      ),
      Bookstore(
        id: 'way/202',
        name: 'Periplus Plaza Indonesia',
        lat: lat + 0.012,
        lng: lng - 0.008,
        address: 'Plaza Indonesia Level 4, Jakarta Pusat',
        phone: '+62 21 3107567',
        website: 'https://www.periplus.com',
        openingHours: '10:00 - 22:00',
        distanceMeters: calculateHaversineDistance(
          lat1: lat,
          lon1: lng,
          lat2: lat + 0.012,
          lon2: lng - 0.008,
        ),
      ),
      Bookstore(
        id: 'node/303',
        name: 'Toko buku (tanpa nama)',
        lat: lat - 0.018,
        lng: lng + 0.015,
        address: 'Jl. Palmerah Barat',
        openingHours: '08:00 - 17:00',
        distanceMeters: calculateHaversineDistance(
          lat1: lat,
          lon1: lng,
          lat2: lat - 0.018,
          lon2: lng + 0.015,
        ),
      ),
    ];
  }

  @override
  Future<List<Bookstore>> getNearbyBookstores({
    required double lat,
    required double lng,
    double initialRadiusKm = 15.0,
  }) async {
    if (simulateError) {
      throw Exception('Gagal terhubung ke server Overpass.');
    }
    if (simulateEmpty) {
      return [];
    }

    if (expandRadiusOnly) {
      // Jika radius 3 km, kembalikan kosong. Jika >= 5 km, kembalikan hasil
      if (initialRadiusKm < 5.0) {
        return [];
      }
    }

    final list = customStores != null
        ? customStores!.map((store) {
            return store.copyWith(
              distanceMeters: calculateHaversineDistance(
                lat1: lat,
                lon1: lng,
                lat2: store.lat,
                lon2: store.lng,
              ),
            );
          }).toList()
        : defaultDummyStores(lat: lat, lng: lng);

    list.sort((a, b) {
      final distA = a.distanceMeters ?? double.infinity;
      final distB = b.distanceMeters ?? double.infinity;
      return distA.compareTo(distB);
    });

    return list;
  }

  @override
  Future<List<PlaceResult>> searchPlaces(String query) async {
    if (simulateError) {
      throw Exception('Gagal mencari lokasi.');
    }
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];

    return [
      PlaceResult(
        displayName: '$query, Daerah Khusus Ibukota Jakarta, Indonesia',
        lat: -6.2088,
        lng: 106.8456,
      ),
      PlaceResult(
        displayName: '$query, Kota Bandung, Jawa Barat, Indonesia',
        lat: -6.9175,
        lng: 107.6191,
      ),
    ];
  }
}
