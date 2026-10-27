import 'dart:math' as math;

/// Model data Toko Buku dari OpenStreetMap via Overpass API — PRD §9.4 & Fase S6.
class Bookstore {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String? address;
  final String? phone;
  final String? website;
  final String? openingHours;
  final double? distanceMeters;

  const Bookstore({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.address,
    this.phone,
    this.website,
    this.openingHours,
    this.distanceMeters,
  });

  /// Factory untuk mem-parsing elemen Overpass JSON (node, way, atau relation dengan out center tags)
  factory Bookstore.fromOverpassElement(
    Map<String, dynamic> element, {
    double? userLat,
    double? userLng,
  }) {
    final type = element['type'] as String? ?? 'node';
    final rawId = element['id'];
    final id = '$type/$rawId';

    // Koordinat: node menggunakan lat/lon langsung; way & relation menggunakan center
    double lat = 0.0;
    double lng = 0.0;
    if (element.containsKey('lat') && element.containsKey('lon')) {
      lat = (element['lat'] as num).toDouble();
      lng = (element['lon'] as num).toDouble();
    } else if (element.containsKey('center') && element['center'] is Map) {
      final center = element['center'] as Map<String, dynamic>;
      lat = (center['lat'] as num?)?.toDouble() ?? 0.0;
      lng = (center['lon'] as num?)?.toDouble() ?? 0.0;
    }

    final tags = (element['tags'] as Map<String, dynamic>?) ?? {};

    // Nama: jika kosong atau null, gunakan fallback "Toko buku (tanpa nama)"
    final rawName = (tags['name'] as String?)?.trim();
    final name = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : 'Toko buku (tanpa nama)';

    // Rangkai alamat dari tag addr:*
    String? address;
    final fullAddr = (tags['addr:full'] as String?)?.trim();
    if (fullAddr != null && fullAddr.isNotEmpty) {
      address = fullAddr;
    } else {
      final parts = <String>[];
      final street = (tags['addr:street'] as String?)?.trim();
      final houseNumber = (tags['addr:housenumber'] as String?)?.trim();
      if (street != null && street.isNotEmpty) {
        if (houseNumber != null && houseNumber.isNotEmpty) {
          parts.add('$street No. $houseNumber');
        } else {
          parts.add(street);
        }
      }
      final district = (tags['addr:suburb'] as String?)?.trim() ??
          (tags['addr:district'] as String?)?.trim();
      if (district != null && district.isNotEmpty) parts.add(district);

      final city = (tags['addr:city'] as String?)?.trim();
      if (city != null && city.isNotEmpty) parts.add(city);

      final postcode = (tags['addr:postcode'] as String?)?.trim();
      if (postcode != null && postcode.isNotEmpty) parts.add(postcode);

      if (parts.isNotEmpty) {
        address = parts.join(', ');
      }
    }

    final phone = (tags['phone'] as String?)?.trim() ??
        (tags['contact:phone'] as String?)?.trim();
    final website = (tags['website'] as String?)?.trim() ??
        (tags['contact:website'] as String?)?.trim();
    final openingHours = (tags['opening_hours'] as String?)?.trim();

    double? distance;
    if (userLat != null && userLng != null && lat != 0.0 && lng != 0.0) {
      distance = calculateHaversineDistance(
        lat1: userLat,
        lon1: userLng,
        lat2: lat,
        lon2: lng,
      );
    }

    return Bookstore(
      id: id,
      name: name,
      lat: lat,
      lng: lng,
      address: address,
      phone: phone,
      website: website,
      openingHours: openingHours,
      distanceMeters: distance,
    );
  }

  Bookstore copyWith({
    String? id,
    String? name,
    double? lat,
    double? lng,
    String? address,
    String? phone,
    String? website,
    String? openingHours,
    double? distanceMeters,
  }) {
    return Bookstore(
      id: id ?? this.id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      openingHours: openingHours ?? this.openingHours,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }

  /// Format teks jarak yang mudah dibaca (mis. "450 m" atau "2.4 km")
  String get formattedDistance {
    if (distanceMeters == null) return '-';
    if (distanceMeters! < 1000) {
      return '${distanceMeters!.round()} m';
    }
    final km = distanceMeters! / 1000;
    return '${km.toStringAsFixed(1)} km';
  }
}

/// Menghitung jarak lingkaran besar (Great-circle distance) antara dua titik koordinat GPS
/// dalam meter menggunakan formula Haversine.
double calculateHaversineDistance({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
}) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

double _degToRad(double deg) => deg * (math.pi / 180.0);

/// Model hasil pencarian lokasi / geocoding Nominatim
class PlaceResult {
  final String displayName;
  final double lat;
  final double lng;

  const PlaceResult({
    required this.displayName,
    required this.lat,
    required this.lng,
  });

  factory PlaceResult.fromNominatimJson(Map<String, dynamic> json) {
    return PlaceResult(
      displayName: json['display_name'] as String? ?? 'Lokasi',
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      lng: double.tryParse(json['lon']?.toString() ?? '0') ?? 0.0,
    );
  }
}
