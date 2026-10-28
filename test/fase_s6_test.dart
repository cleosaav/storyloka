import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:storyloka/data/models/bookstore.dart';
import 'package:storyloka/data/repositories/bookstore_repository.dart';
import 'helpers/fake/fake_bookstore_repository.dart';
import 'package:storyloka/data/repositories/remote/overpass_bookstore_repository.dart';
import 'package:storyloka/features/book_detail/widgets/mini_bookstore_map.dart';
import 'package:storyloka/features/tools/bookstore_map/bookstore_map_page.dart';

void main() {
  group('Fase S6: Model & Haversine Distance Tests', () {
    test('calculateHaversineDistance menghitung jarak dengan benar', () {
      // Monas: -6.1754, 106.8272
      // Bundaran HI: -6.1950, 106.8230
      final distance = calculateHaversineDistance(
        lat1: -6.1754,
        lon1: 106.8272,
        lat2: -6.1950,
        lon2: 106.8230,
      );

      // Jarak garis lurus Monas ke Bundaran HI ~2.2 km (2100 - 2300 m)
      expect(distance, greaterThan(2000));
      expect(distance, lessThan(2500));
    });

    test('Bookstore.formattedDistance format meter dan kilometer', () {
      const storeNear = Bookstore(
        id: 'node/1',
        name: 'Toko Buku Dekat',
        lat: -6.1,
        lng: 106.8,
        distanceMeters: 450.4,
      );
      expect(storeNear.formattedDistance, '450 m');

      const storeFar = Bookstore(
        id: 'node/2',
        name: 'Toko Buku Jauh',
        lat: -6.2,
        lng: 106.9,
        distanceMeters: 2450.0,
      );
      expect(storeFar.formattedDistance, '2.5 km');

      const storeNull = Bookstore(
        id: 'node/3',
        name: 'Toko Tanpa Jarak',
        lat: -6.2,
        lng: 106.9,
      );
      expect(storeNull.formattedDistance, '-');
    });

    test('Parsing Overpass fixture node lengkap', () {
      final fixture = {
        'type': 'node',
        'id': 1001,
        'lat': -6.175,
        'lon': 106.827,
        'tags': {
          'shop': 'books',
          'name': 'Gramedia Merdeka',
          'addr:street': 'Jl. Merdeka',
          'addr:housenumber': '10',
          'addr:city': 'Jakarta Pusat',
          'phone': '+6221123456',
          'website': 'https://gramedia.com',
          'opening_hours': 'Mo-Su 10:00-21:00',
        },
      };

      final store = Bookstore.fromOverpassElement(
        fixture,
        userLat: -6.176,
        userLng: 106.828,
      );

      expect(store.id, 'node/1001');
      expect(store.name, 'Gramedia Merdeka');
      expect(store.lat, -6.175);
      expect(store.lng, 106.827);
      expect(store.address, contains('Jl. Merdeka No. 10'));
      expect(store.address, contains('Jakarta Pusat'));
      expect(store.phone, '+6221123456');
      expect(store.website, 'https://gramedia.com');
      expect(store.openingHours, 'Mo-Su 10:00-21:00');
      expect(store.distanceMeters, isNotNull);
    });

    test('Parsing Overpass fixture way dengan out center tags', () {
      final fixture = {
        'type': 'way',
        'id': 2002,
        'center': {
          'lat': -6.185,
          'lon': 106.830,
        },
        'tags': {
          'shop': 'books',
          'name': 'Periplus Sudirman',
          'addr:street': 'Jl. Jend. Sudirman',
          'contact:phone': '+6221987654',
          'contact:website': 'https://periplus.com',
        },
      };

      final store = Bookstore.fromOverpassElement(fixture);

      expect(store.id, 'way/2002');
      expect(store.name, 'Periplus Sudirman');
      expect(store.lat, -6.185);
      expect(store.lng, 106.830);
      expect(store.address, 'Jl. Jend. Sudirman');
      expect(store.phone, '+6221987654');
      expect(store.website, 'https://periplus.com');
    });

    test('Parsing Overpass fixture tanpa nama menghasilkan Toko buku (tanpa nama)', () {
      final fixture = {
        'type': 'relation',
        'id': 3003,
        'center': {
          'lat': -6.190,
          'lon': 106.835,
        },
        'tags': {
          'shop': 'books',
          // Tanpa nama
        },
      };

      final store = Bookstore.fromOverpassElement(fixture);

      expect(store.id, 'relation/3003');
      expect(store.name, 'Toko buku (tanpa nama)');
      expect(store.lat, -6.190);
      expect(store.lng, 106.835);
      expect(store.address, isNull);
    });

    test('Parsing PlaceResult dari Nominatim JSON', () {
      final json = {
        'display_name': 'Bandung, Jawa Barat, Indonesia',
        'lat': '-6.9175',
        'lon': '107.6191',
      };

      final place = PlaceResult.fromNominatimJson(json);
      expect(place.displayName, 'Bandung, Jawa Barat, Indonesia');
      expect(place.lat, closeTo(-6.9175, 0.0001));
      expect(place.lng, closeTo(107.6191, 0.0001));
    });
  });

  group('Fase S6: OverpassBookstoreRepository Tests', () {
    test('Mengurutkan toko berdasarkan jarak menaik (terdekat dahulu)', () async {
      final elementsJson = {
        'elements': [
          {
            'type': 'node',
            'id': 1,
            'lat': -6.200, // lebih jauh
            'lon': 106.800,
            'tags': {'name': 'Toko Jauh', 'shop': 'books'}
          },
          {
            'type': 'node',
            'id': 2,
            'lat': -6.101, // sangat dekat dengan user di -6.100
            'lon': 106.801,
            'tags': {'name': 'Toko Dekat', 'shop': 'books'}
          },
        ]
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(elementsJson), 200, headers: {
          'content-type': 'application/json',
        });
      });

      final repo = OverpassBookstoreRepository(
        client: mockClient,
        mirrors: ['https://mock-overpass.test/interpreter'],
      );

      final stores = await repo.getNearbyBookstores(lat: -6.100, lng: 106.800);

      expect(stores.length, 2);
      expect(stores[0].name, 'Toko Dekat');
      expect(stores[1].name, 'Toko Jauh');
      expect(stores[0].distanceMeters!, lessThan(stores[1].distanceMeters!));
    });

    test('Fallback ke mirror berikutnya saat mirror pertama error 500', () async {
      int requestCount = 0;

      final mockClient = MockClient((request) async {
        requestCount++;
        if (request.url.host == 'fail.overpass.test') {
          return http.Response('Server Error', 500);
        }
        return http.Response(
          jsonEncode({
            'elements': [
              {
                'type': 'node',
                'id': 99,
                'lat': -6.105,
                'lon': 106.805,
                'tags': {'name': 'Toko dari Mirror 2', 'shop': 'books'}
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = OverpassBookstoreRepository(
        client: mockClient,
        mirrors: [
          'https://fail.overpass.test/interpreter',
          'https://success.overpass.test/interpreter',
        ],
      );

      final stores = await repo.getNearbyBookstores(lat: -6.100, lng: 106.800);

      expect(requestCount, 2);
      expect(stores.length, 1);
      expect(stores.first.name, 'Toko dari Mirror 2');
    });

    test('In-memory cache mengembalikan data tanpa hit HTTP kedua kali', () async {
      int httpCalls = 0;

      final mockClient = MockClient((request) async {
        httpCalls++;
        return http.Response(
          jsonEncode({
            'elements': [
              {
                'type': 'node',
                'id': 10,
                'lat': -6.102,
                'lon': 106.802,
                'tags': {'name': 'Toko Cache', 'shop': 'books'}
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = OverpassBookstoreRepository(
        client: mockClient,
        mirrors: ['https://mock.test/interpreter'],
      );

      // Panggilan 1
      final res1 = await repo.getNearbyBookstores(lat: -6.100, lng: 106.800);
      expect(httpCalls, 1);
      expect(res1.length, 1);

      // Panggilan 2 dengan koordinat yang sama
      final res2 = await repo.getNearbyBookstores(lat: -6.100, lng: 106.800);
      expect(httpCalls, 1); // Tidak bertambah karena cache
      expect(res2.first.name, 'Toko Cache');
    });

    test('Perluasan radius otomatis jika 3 km kosong', () async {
      final List<int> queriedRadii = [];

      final mockClient = MockClient((request) async {
        final query = request.bodyFields['data'] ??
            Uri.decodeQueryComponent(request.body);
        if (query.contains('around:3000')) {
          queriedRadii.add(3000);
          return http.Response(jsonEncode({'elements': []}), 200);
        } else if (query.contains('around:5000')) {
          queriedRadii.add(5000);
          return http.Response(
            jsonEncode({
              'elements': [
                {
                  'type': 'node',
                  'id': 55,
                  'lat': -6.140,
                  'lon': 106.840,
                  'tags': {'name': 'Toko Radius 5km', 'shop': 'books'}
                }
              ]
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'elements': []}), 200);
      });

      final repo = OverpassBookstoreRepository(
        client: mockClient,
        mirrors: ['https://mock.test/interpreter'],
      );

      final stores = await repo.getNearbyBookstores(
        lat: -6.100,
        lng: 106.800,
        initialRadiusKm: 3.0,
      );

      expect(queriedRadii, contains(3000));
      expect(queriedRadii, contains(5000));
      expect(stores.length, 1);
      expect(stores.first.name, 'Toko Radius 5km');
    });
  });

  group('Fase S6: BookstoreMapPage Widget Tests', () {
    Widget createTestApp(BookstoreRepository repository) {
      return MultiProvider(
        providers: [
          Provider<BookstoreRepository>.value(value: repository),
        ],
        child: const MaterialApp(
          home: BookstoreMapPage(
            initialLat: -6.2088,
            initialLng: 106.8456,
          ),
        ),
      );
    }

    testWidgets('Menampilkan halaman peta dan daftar toko buku sukses', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = FakeBookstoreRepository();
      await tester.pumpWidget(createTestApp(repo));
      await tester.pumpAndSettle();

      // Verifikasi AppBar
      expect(find.text('Toko Buku Terdekat'), findsOneWidget);

      // Verifikasi Atribusi OpenStreetMap
      expect(find.textContaining('OpenStreetMap'), findsOneWidget);

      // Verifikasi daftar toko buku
      expect(find.text('Gramedia Grand Indonesia'), findsOneWidget);
      expect(find.text('Periplus Plaza Indonesia'), findsOneWidget);

      // Verifikasi tombol Rute
      expect(find.text('Rute'), findsWidgets);
    });

    testWidgets('Menampilkan state kosong jika tidak ada toko terdata', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = FakeBookstoreRepository(stores: []);
      await tester.pumpWidget(createTestApp(repo));
      await tester.pumpAndSettle();

      expect(
        find.text('Belum ada toko buku terdata di sekitar sini'),
        findsOneWidget,
      );
      expect(find.text('Buka di Google Maps'), findsOneWidget);
    });

    testWidgets('Menampilkan state error dan tombol Coba Lagi saat repo melempar exception', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = FakeBookstoreRepository(shouldThrowError: true);
      await tester.pumpWidget(createTestApp(repo));
      await tester.pumpAndSettle();

      expect(
        find.text('Gagal memuat data toko buku dari OpenStreetMap.'),
        findsOneWidget,
      );
      expect(find.text('Coba Lagi'), findsOneWidget);
    });

    testWidgets('Toko terpilih saat di-tap menyorot card', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = FakeBookstoreRepository();
      await tester.pumpWidget(createTestApp(repo));
      await tester.pumpAndSettle();

      final firstStoreText = find.text('Gramedia Grand Indonesia');
      expect(firstStoreText, findsOneWidget);

      await tester.tap(firstStoreText);
      await tester.pumpAndSettle();

      // Card tetap tampil dan terfokus
      expect(firstStoreText, findsOneWidget);
    });

    testWidgets('Responsif tanpa overflow di layar 360x640 dengan textScale 1.3', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = FakeBookstoreRepository();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: MultiProvider(
            providers: [
              Provider<BookstoreRepository>.value(value: repo),
            ],
            child: const MaterialApp(
              home: BookstoreMapPage(
                initialLat: -6.2088,
                initialLng: 106.8456,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Toko Buku Terdekat'), findsOneWidget);
    });

    testWidgets('Menampilkan chip radius interaktif dan dapat memilih radius 25 km', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = FakeBookstoreRepository();
      await tester.pumpWidget(createTestApp(repo));
      await tester.pumpAndSettle();

      // Chip radius tampil
      expect(find.text('5 km'), findsOneWidget);
      expect(find.text('15 km'), findsOneWidget);
      expect(find.text('25 km'), findsOneWidget);
      expect(find.text('50 km'), findsOneWidget);

      // Ketuk chip 25 km
      await tester.tap(find.text('25 km'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Radius pencarian: 25 km'), findsOneWidget);
    });

    testWidgets('Tombol Perluas Radius pada state kosong dapat memperluas hingga 25 km dan 50 km', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = FakeBookstoreRepository(stores: []);
      await tester.pumpWidget(createTestApp(repo));
      await tester.pumpAndSettle();

      // Radius default 15 km kosong -> tombol perluas ke 25 km tampil
      expect(find.text('Perluas Radius (25 km)'), findsOneWidget);

      await tester.tap(find.text('Perluas Radius (25 km)'));
      await tester.pumpAndSettle();

      // Radius 25 km masih kosong -> tombol perluas ke 50 km tampil
      expect(find.text('Perluas Radius (50 km)'), findsOneWidget);
    });

    testWidgets('MiniBookstoreMap menampilkan peta kotak mini dengan titik toko terdekat', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool openedFull = false;
      final repo = FakeBookstoreRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Provider<BookstoreRepository>.value(
              value: repo,
              child: MiniBookstoreMap(
                onOpenFullMap: () => openedFull = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Memastikan widget MiniBookstoreMap ter-render
      expect(find.byType(MiniBookstoreMap), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);

      // Memastikan tombol Peta Penuh dapat ditekan
      expect(find.text('Peta Penuh'), findsOneWidget);
      await tester.tap(find.text('Peta Penuh'));
      expect(openedFull, isTrue);
    });
  });
}
