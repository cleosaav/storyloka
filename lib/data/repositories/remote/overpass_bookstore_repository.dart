import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../datasources/indonesian_bookstores_seed.dart';
import '../../models/bookstore.dart';
import '../bookstore_repository.dart';

/// Entry cache in-memory untuk toko buku dan geocoding — PRD §9.4 & Fase S6.
class _BookstoreCacheEntry {
  final List<Bookstore> data;
  final DateTime cachedAt;

  _BookstoreCacheEntry(this.data) : cachedAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(cachedAt) > const Duration(minutes: 10);
}

class _PlaceCacheEntry {
  final List<PlaceResult> data;
  final DateTime cachedAt;

  _PlaceCacheEntry(this.data) : cachedAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(cachedAt) > const Duration(minutes: 10);
}

/// Implementasi tangguh BookstoreRepository menggunakan Overpass API, Nominatim OSM,
/// dan Curated Seed Data Toko Buku Indonesia — PRD §9.4 & Fase S6.
class OverpassBookstoreRepository implements BookstoreRepository {
  final http.Client _client;

  /// Daftar endpoint Overpass mirror untuk redundansi jaringan
  final List<String> mirrors;

  static const List<String> defaultMirrors = [
    'https://overpass-api.de/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];

  static const String userAgent =
      'StoryLoka/1.0 (com.storyloka.storyloka; contact@storyloka.app)';

  // Cache in-memory berdurasi 10 menit
  final Map<String, _BookstoreCacheEntry> _bookstoreCache = {};
  final Map<String, _PlaceCacheEntry> _placeCache = {};

  // Rate limiting Nominatim: maksimal 1 permintaan per detik
  DateTime? _lastNominatimRequestTime;

  OverpassBookstoreRepository({
    http.Client? client,
    List<String>? mirrors,
  })  : _client = client ?? http.Client(),
        mirrors = mirrors ?? defaultMirrors;

  @override
  Future<List<Bookstore>> getNearbyBookstores({
    required double lat,
    required double lng,
    double initialRadiusKm = 15.0,
  }) async {
    // 1. Periksa in-memory cache
    final overallCacheKey =
        '${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}_${initialRadiusKm.toStringAsFixed(1)}';
    final cached = _bookstoreCache[overallCacheKey];
    if (cached != null && !cached.isExpired && cached.data.isNotEmpty) {
      return cached.data;
    }

    // Daftar radius bertingkat jika hasil kosong: awal -> 5 km -> 10 km -> 20 km -> 35 km -> 50 km
    final radiiKm = <double>[initialRadiusKm];
    if (initialRadiusKm < 5.0) radiiKm.add(5.0);
    if (initialRadiusKm < 10.0) radiiKm.add(10.0);
    if (initialRadiusKm < 20.0) radiiKm.add(20.0);
    if (initialRadiusKm < 35.0) radiiKm.add(35.0);
    if (initialRadiusKm < 50.0) radiiKm.add(50.0);

    // 2. Coba ambil dari Overpass API terlebih dahulu
    for (final radiusKm in radiiKm) {
      final cacheKey =
          '${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}_${radiusKm.toStringAsFixed(1)}';

      final innerCached = _bookstoreCache[cacheKey];
      if (innerCached != null && !innerCached.isExpired && innerCached.data.isNotEmpty) {
        return innerCached.data;
      }

      final stores = await _fetchFromOverpass(
        lat: lat,
        lng: lng,
        radiusMeters: (radiusKm * 1000).round(),
      );

      if (stores.isNotEmpty) {
        _bookstoreCache[cacheKey] = _BookstoreCacheEntry(stores);
        _bookstoreCache[overallCacheKey] = _BookstoreCacheEntry(stores);
        return stores;
      }
    }

    // 3. Jika Overpass API gagal / timeout / tidak menemukan toko:
    // Gunakan strategi fallback tangguh (Nominatim OSM Search + Curated Indonesian Seed)
    final fallbackStores = await _fetchFallbackStores(
      lat: lat,
      lng: lng,
      radiusKm: initialRadiusKm,
    );

    if (fallbackStores.isNotEmpty) {
      _bookstoreCache[overallCacheKey] = _BookstoreCacheEntry(fallbackStores);
      return fallbackStores;
    }

    return [];
  }

  /// Memanggil Overpass API dengan mencoba mirror satu per satu jika terjadi kegagalan
  Future<List<Bookstore>> _fetchFromOverpass({
    required double lat,
    required double lng,
    required int radiusMeters,
  }) async {
    final query = '''
[out:json][timeout:15];
(
  node["shop"="books"](around:$radiusMeters,$lat,$lng);
  way["shop"="books"](around:$radiusMeters,$lat,$lng);
  relation["shop"="books"](around:$radiusMeters,$lat,$lng);
  node["shop"="bookstore"](around:$radiusMeters,$lat,$lng);
  way["shop"="bookstore"](around:$radiusMeters,$lat,$lng);
);
out center tags;
''';

    Exception? lastException;

    for (final mirror in mirrors) {
      try {
        final uri = Uri.parse(mirror);
        final response = await _client.post(
          uri,
          headers: {
            'User-Agent': userAgent,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {'data': query},
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final elements = (decoded['elements'] as List<dynamic>?) ?? [];

          final stores = elements.map((e) {
            final map = e as Map<String, dynamic>;
            return Bookstore.fromOverpassElement(
              map,
              userLat: lat,
              userLng: lng,
            );
          }).where((b) => b.lat != 0.0 && b.lng != 0.0).toList();

          // Urutkan toko dari yang paling dekat
          stores.sort((a, b) {
            final distA = a.distanceMeters ?? double.infinity;
            final distB = b.distanceMeters ?? double.infinity;
            return distA.compareTo(distB);
          });

          return stores;
        } else {
          lastException = Exception(
            'Overpass mirror $mirror returned HTTP ${response.statusCode}',
          );
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
      }
    }

    if (lastException != null) {
      debugPrint('[OverpassBookstoreRepository] Overpass mirrors unavailable: $lastException');
    }

    return [];
  }

  /// Fallback tangguh menggunakan Nominatim OSM POI Search dan Curated Seed Data Indonesia
  Future<List<Bookstore>> _fetchFallbackStores({
    required double lat,
    required double lng,
    required double radiusKm,
  }) async {
    final Map<String, Bookstore> storeMap = {};

    // 1. Coba cari toko buku secara live dari Nominatim OpenStreetMap
    try {
      final osmStores = await _fetchBookstoresFromNominatim(lat: lat, lng: lng);
      for (final s in osmStores) {
        storeMap[s.id] = s;
      }
    } catch (e) {
      debugPrint('[OverpassBookstoreRepository] Nominatim POI search note: $e');
    }

    // 2. Ambil dari dataset terverifikasi IndonesianBookstoresSeed
    for (final seed in IndonesianBookstoresSeed.allStores) {
      final dist = calculateHaversineDistance(
        lat1: lat,
        lon1: lng,
        lat2: seed.lat,
        lon2: seed.lng,
      );

      // Cek apakah toko berada dalam radius atau batas wilayah yang relevan
      final maxDistanceAllowed = (radiusKm * 1000).clamp(15000.0, 60000.0);
      if (dist <= maxDistanceAllowed) {
        final normName = seed.name.toLowerCase();
        final isDuplicate = storeMap.values.any((existing) {
          final existingNorm = existing.name.toLowerCase();
          return existingNorm.contains(normName) || normName.contains(existingNorm);
        });

        if (!isDuplicate) {
          storeMap[seed.id] = seed.copyWith(distanceMeters: dist);
        }
      }
    }

    // 3. Jika koordinat berada di luar jangkauan kota seed (misal kota lain),
    // ambil 5 toko buku terdekat di Indonesia agar peta selalu menampilkan data
    if (storeMap.isEmpty) {
      final sortedSeeds = IndonesianBookstoresSeed.allStores.map((s) {
        final dist = calculateHaversineDistance(
          lat1: lat,
          lon1: lng,
          lat2: s.lat,
          lon2: s.lng,
        );
        return s.copyWith(distanceMeters: dist);
      }).toList()
        ..sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));

      for (final s in sortedSeeds.take(5)) {
        storeMap[s.id] = s;
      }
    }

    final result = storeMap.values.toList();
    result.sort((a, b) {
      final distA = a.distanceMeters ?? double.infinity;
      final distB = b.distanceMeters ?? double.infinity;
      return distA.compareTo(distB);
    });

    return result;
  }

  /// Reverse geocode koordinat untuk menemukan kota, lalu cari toko buku di kota tersebut via Nominatim
  Future<List<Bookstore>> _fetchBookstoresFromNominatim({
    required double lat,
    required double lng,
  }) async {
    // Rate limit Nominatim
    await _throttleNominatim();

    final revUri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json',
    );
    final revRes = await _client.get(
      revUri,
      headers: {'User-Agent': userAgent},
    ).timeout(const Duration(seconds: 4));

    if (revRes.statusCode != 200) return [];

    final revData = jsonDecode(revRes.body) as Map<String, dynamic>;
    final addr = revData['address'] as Map<String, dynamic>? ?? {};
    final rawCity = addr['city'] ??
        addr['city_district'] ??
        addr['county'] ??
        addr['town'] ??
        addr['state'];

    if (rawCity == null) return [];

    final cleanCity = rawCity
        .toString()
        .replaceAll(
          RegExp(r'(Kota|Kabupaten|Daerah Khusus Ibukota)\s*', caseSensitive: false),
          '',
        )
        .trim();

    if (cleanCity.isEmpty) return [];

    // Rate limit Nominatim sebelum query kedua
    await _throttleNominatim();

    final searchUri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=toko+buku+${Uri.encodeComponent(cleanCity)}&format=json&limit=12&addressdetails=1',
    );

    final sRes = await _client.get(
      searchUri,
      headers: {'User-Agent': userAgent},
    ).timeout(const Duration(seconds: 5));

    if (sRes.statusCode != 200) return [];

    final list = jsonDecode(sRes.body) as List<dynamic>;
    final stores = <Bookstore>[];

    for (final item in list) {
      final map = item as Map<String, dynamic>;
      final sLat = double.tryParse(map['lat']?.toString() ?? '0') ?? 0.0;
      final sLng = double.tryParse(map['lon']?.toString() ?? '0') ?? 0.0;
      if (sLat == 0.0 || sLng == 0.0) continue;

      final dist = calculateHaversineDistance(
        lat1: lat,
        lon1: lng,
        lat2: sLat,
        lon2: sLng,
      );

      final displayName = map['display_name'] as String? ?? 'Toko Buku';
      final storeName = displayName.split(',').first.trim();

      stores.add(
        Bookstore(
          id: 'osm/${map['osm_id'] ?? map['place_id']}',
          name: storeName.isNotEmpty ? storeName : displayName,
          lat: sLat,
          lng: sLng,
          address: displayName,
          distanceMeters: dist,
        ),
      );
    }

    return stores;
  }

  Future<void> _throttleNominatim() async {
    if (_lastNominatimRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastNominatimRequestTime!);
      if (elapsed < const Duration(milliseconds: 1000)) {
        await Future.delayed(const Duration(milliseconds: 1000) - elapsed);
      }
    }
    _lastNominatimRequestTime = DateTime.now();
  }

  @override
  Future<List<PlaceResult>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final cacheKey = trimmed.toLowerCase();
    final cached = _placeCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    await _throttleNominatim();

    final results = <PlaceResult>[];

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(trimmed)}&format=json&limit=6&addressdetails=1',
      );

      final response = await _client.get(
        uri,
        headers: {'User-Agent': userAgent},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        final fetched = list
            .map((item) => PlaceResult.fromNominatimJson(item as Map<String, dynamic>))
            .where((p) => p.lat != 0.0 && p.lng != 0.0)
            .toList();
        results.addAll(fetched);
      }
    } catch (e) {
      debugPrint('[OverpassBookstoreRepository] Nominatim searchPlaces error: $e');
    }

    // Jika Nominatim gagal atau hasilnya sedikit, cocokkan dengan daftar kota populer
    final matchingSeeds = IndonesianBookstoresSeed.popularCities.where((city) {
      return city.displayName.toLowerCase().contains(trimmed.toLowerCase());
    }).toList();

    for (final seed in matchingSeeds) {
      final alreadyExists = results.any(
        (r) => (r.lat - seed.lat).abs() < 0.05 && (r.lng - seed.lng).abs() < 0.05,
      );
      if (!alreadyExists) {
        results.add(seed);
      }
    }

    if (results.isNotEmpty) {
      _placeCache[cacheKey] = _PlaceCacheEntry(results);
    }

    return results;
  }
}
