import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/bookstore.dart';
import '../../../data/repositories/bookstore_repository.dart';
import '../../../data/repositories/fake/fake_bookstore_repository.dart';

/// Widget pratinjau peta kecil toko buku terdekat untuk halaman detail buku.
/// Menampilkan OpenStreetMap dengan titik lokasi pengguna dan toko buku terdekat.
class MiniBookstoreMap extends StatefulWidget {
  final double height;
  final VoidCallback? onOpenFullMap;

  const MiniBookstoreMap({
    super.key,
    this.height = 150.0,
    this.onOpenFullMap,
  });

  @override
  State<MiniBookstoreMap> createState() => _MiniBookstoreMapState();
}

class _MiniBookstoreMapState extends State<MiniBookstoreMap> {
  late final MapController _mapController;

  static const double defaultLat = -6.2088;
  static const double defaultLng = 106.8456;

  LatLng _center = const LatLng(defaultLat, defaultLng);
  LatLng? _userLocation;

  List<Bookstore> _stores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadNearbyBookstores();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadNearbyBookstores() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    LatLng userPos = const LatLng(defaultLat, defaultLng);

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          userPos = LatLng(pos.latitude, pos.longitude);
          _userLocation = userPos;
        }
      }
    } catch (_) {}

    if (!mounted) return;

    _center = userPos;

    BookstoreRepository repo;
    try {
      repo = context.read<BookstoreRepository>();
    } catch (_) {
      // Fallback aman untuk widget testing atau jika provider belum terinjeksi
      repo = FakeBookstoreRepository();
    }

    try {
      final stores = await repo.getNearbyBookstores(
        lat: userPos.latitude,
        lng: userPos.longitude,
        initialRadiusKm: 15.0,
      );

      if (!mounted) return;
      setState(() {
        _stores = stores;
        _isLoading = false;
      });

      _adjustZoom(userPos, stores);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _adjustZoom(LatLng center, List<Bookstore> stores) {
    if (!mounted) return;

    if (stores.isEmpty) {
      try {
        _mapController.move(center, 12.0);
      } catch (_) {}
      return;
    }

    double minLat = center.latitude;
    double maxLat = center.latitude;
    double minLng = center.longitude;
    double maxLng = center.longitude;

    // Ambil beberapa toko terdekat untuk penyesuaian framing
    final sample = stores.take(5);
    for (final s in sample) {
      if (s.lat < minLat) minLat = s.lat;
      if (s.lat > maxLat) maxLat = s.lat;
      if (s.lng < minLng) minLng = s.lng;
      if (s.lng > maxLng) maxLng = s.lng;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final spanLat = (maxLat - minLat).abs();
    final spanLng = (maxLng - minLng).abs();
    final maxSpan = spanLat > spanLng ? spanLat : spanLng;

    double zoom;
    if (maxSpan > 0.35) {
      zoom = 9.5;
    } else if (maxSpan > 0.18) {
      zoom = 10.5;
    } else if (maxSpan > 0.08) {
      zoom = 11.5;
    } else if (maxSpan > 0.04) {
      zoom = 12.5;
    } else {
      zoom = 13.0;
    }

    try {
      _mapController.move(LatLng(centerLat, centerLng), zoom);
    } catch (_) {}
  }

  void _handleOpenFullMap() {
    if (widget.onOpenFullMap != null) {
      widget.onOpenFullMap!();
    } else {
      context.push('/maps/bookstores');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius - 4),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius - 4),
        child: Stack(
          children: [
            // Peta OpenStreetMap
            GestureDetector(
              onTap: _handleOpenFullMap,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: 12.0,
                  minZoom: 4.0,
                  maxZoom: 18.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  // Tile Layer OSM
                  if (isDark)
                    ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        -0.75, 0, 0, 0, 255,
                        0, -0.75, 0, 0, 255,
                        0, 0, -0.75, 0, 255,
                        0, 0, 0, 1, 0,
                      ]),
                      child: TileLayer(
                        urlTemplate: Env.mapTileUrl,
                        userAgentPackageName: 'com.storyloka.storyloka',
                      ),
                    )
                  else
                    TileLayer(
                      urlTemplate: Env.mapTileUrl,
                      userAgentPackageName: 'com.storyloka.storyloka',
                    ),

                  // Lingkaran radius visual
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _userLocation ?? _center,
                        radius: 8000,
                        useRadiusInMeter: true,
                        color: (isDark ? AppColors.primaryDark : AppColors.deepTeal)
                            .withValues(alpha: 0.05),
                        borderColor: (isDark ? AppColors.primaryDark : AppColors.deepTeal)
                            .withValues(alpha: 0.2),
                        borderStrokeWidth: 1.0,
                      ),
                    ],
                  ),

                  // Marker Layer (Lokasi Pengguna & Titik Toko Buku)
                  MarkerLayer(
                    markers: [
                      // Titik Lokasi Pengguna
                      Marker(
                        point: _userLocation ?? _center,
                        width: 26,
                        height: 26,
                        child: Container(
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.primaryDark : AppColors.deepTeal)
                                .withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.ink.withValues(alpha: 0.25),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Titik Toko Buku Terdekat
                      for (final store in _stores)
                        Marker(
                          point: LatLng(store.lat, store.lng),
                          width: 26,
                          height: 26,
                          child: GestureDetector(
                            onTap: _handleOpenFullMap,
                            child: Tooltip(
                              message: store.name,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.softApricot,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.white, width: 1.8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.ink.withValues(alpha: 0.35),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  size: 13,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Atribusi OpenStreetMap ringkas
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        '© OSM',
                        onTap: _handleOpenFullMap,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Badge status / jumlah toko di pojok kiri bawah
            Positioned(
              bottom: 8,
              left: 8,
              child: GestureDetector(
                onTap: _handleOpenFullMap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.surfaceDark : AppColors.white)
                        .withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
                      width: 0.8,
                    ),
                    boxShadow: const [
                      BoxShadow(color: AppColors.shadowSubtle, blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoading) ...[
                        Icon(
                          Icons.radar_rounded,
                          size: AppSpacing.iconXs,
                          color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Mencari toko...',
                          style: AppText.caption(
                            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                          ),
                        ),
                      ] else if (_stores.isNotEmpty) ...[
                        const Icon(
                          Icons.store_mall_directory_rounded,
                          size: AppSpacing.iconXs,
                          color: AppColors.deepTeal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_stores.length} toko di sekitar',
                          style: AppText.caption(
                            color: isDark ? AppColors.inkDark : AppColors.ink,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.location_searching_rounded,
                          size: AppSpacing.iconXs,
                          color: AppColors.mutedGray,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ketuk untuk cari lebih luas',
                          style: AppText.caption(
                            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Tombol Perbesar / Fullscreen di pojok kanan atas
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _handleOpenFullMap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.surfaceDark : AppColors.white)
                        .withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
                      width: 0.8,
                    ),
                    boxShadow: const [
                      BoxShadow(color: AppColors.shadowSubtle, blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_full_rounded,
                        size: AppSpacing.iconXs,
                        color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Peta Penuh',
                        style: AppText.caption(
                          color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
