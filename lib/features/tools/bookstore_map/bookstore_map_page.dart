import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/datasources/indonesian_bookstores_seed.dart';
import '../../../data/models/bookstore.dart';
import '../../../data/repositories/bookstore_repository.dart';

/// Halaman Peta Toko Buku Terdekat — PRD §9.4 & Fase S6.
/// Menggunakan OpenStreetMap via flutter_map & Overpass API.
class BookstoreMapPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const BookstoreMapPage({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<BookstoreMapPage> createState() => _BookstoreMapPageState();
}

class _BookstoreMapPageState extends State<BookstoreMapPage> {
  late final MapController _mapController;

  // Koordinat default Jakarta jika GPS belum aktif/diberikan izin
  static const double defaultLat = -6.2088;
  static const double defaultLng = 106.8456;

  LatLng _currentCenter = const LatLng(defaultLat, defaultLng);
  LatLng? _userLocation;

  List<Bookstore> _bookstores = [];
  Bookstore? _selectedStore;

  bool _isLoading = true;
  String? _errorMessage;
  double _currentRadiusKm = 15.0;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    if (widget.initialLat != null && widget.initialLng != null) {
      _currentCenter = LatLng(widget.initialLat!, widget.initialLng!);
      _userLocation = _currentCenter;
      _fetchBookstores(
        _currentCenter.latitude,
        _currentCenter.longitude,
        radiusKm: _currentRadiusKm,
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initUserLocation();
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _initUserLocation() async {
    setState(() => _isLoading = true);

    final position = await LocationService.instance.getUserLocation(context);
    if (!mounted) return;

    if (position != null) {
      final loc = LatLng(position.latitude, position.longitude);
      setState(() {
        _userLocation = loc;
        _currentCenter = loc;
      });
      _mapController.move(loc, _zoomForRadius(_currentRadiusKm));
      await _fetchBookstores(
        loc.latitude,
        loc.longitude,
        radiusKm: _currentRadiusKm,
      );
    } else {
      // Jika izin lokasi tidak diberikan, gunakan koordinat default
      await _fetchBookstores(
        _currentCenter.latitude,
        _currentCenter.longitude,
        radiusKm: _currentRadiusKm,
      );
    }
  }

  Future<void> _fetchBookstores(
    double lat,
    double lng, {
    double radiusKm = 15.0,
    bool autoFit = true,
  }) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentRadiusKm = radiusKm;
      _selectedStore = null;
    });

    try {
      final repo = context.read<BookstoreRepository>();
      final stores = await repo.getNearbyBookstores(
        lat: lat,
        lng: lng,
        initialRadiusKm: radiusKm,
      );

      if (!mounted) return;

      // Jika repository memperluas radius secara bertingkat dan toko ditemukan
      double effectiveRadius = radiusKm;
      if (stores.isNotEmpty) {
        final maxDist = (stores.last.distanceMeters ?? 0) / 1000.0;
        if (maxDist > effectiveRadius) {
          effectiveRadius = maxDist.ceilToDouble();
        }
      }

      setState(() {
        _bookstores = stores;
        _currentRadiusKm = effectiveRadius;
        _isLoading = false;
      });

      if (autoFit) {
        _adjustCameraToFit(stores, LatLng(lat, lng), effectiveRadius);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat data toko buku dari OpenStreetMap.';
        _isLoading = false;
      });
    }
  }

  void _adjustCameraToFit(List<Bookstore> stores, LatLng center, double radiusKm) {
    if (!mounted) return;
    if (stores.isEmpty) {
      _mapController.move(center, _zoomForRadius(radiusKm));
      return;
    }

    double minLat = center.latitude;
    double maxLat = center.latitude;
    double minLng = center.longitude;
    double maxLng = center.longitude;

    for (final s in stores) {
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

    double targetZoom;
    if (maxSpan > 0.6) {
      targetZoom = 8.5;
    } else if (maxSpan > 0.35) {
      targetZoom = 9.5;
    } else if (maxSpan > 0.18) {
      targetZoom = 10.5;
    } else if (maxSpan > 0.08) {
      targetZoom = 11.5;
    } else if (maxSpan > 0.04) {
      targetZoom = 12.5;
    } else {
      targetZoom = 13.5;
    }

    _mapController.move(LatLng(centerLat, centerLng), targetZoom);
  }

  double _zoomForRadius(double radiusKm) {
    if (radiusKm >= 45) return 8.5;
    if (radiusKm >= 30) return 9.5;
    if (radiusKm >= 20) return 10.5;
    if (radiusKm >= 12) return 11.5;
    if (radiusKm >= 6) return 12.5;
    return 13.5;
  }

  void _onStoreSelected(Bookstore store) {
    setState(() => _selectedStore = store);
    _mapController.move(LatLng(store.lat, store.lng), 15.5);

    // Buka sheet ke ukuran proporsional
    try {
      if (_sheetController.isAttached) {
        _sheetController.animateTo(
          0.4,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (_) {}
  }

  Future<void> _openDirections(Bookstore store) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${store.lat},${store.lng}',
    );
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        AppSnackBar.show(
          context,
          message: 'Tidak dapat membuka aplikasi peta untuk rute.',
          type: SnackBarType.warning,
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Gagal membuka rute peta.',
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        AppSnackBar.show(
          context,
          message: 'Tidak dapat melakukan panggilan ke $phone',
          type: SnackBarType.warning,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BookstoreMap] Gagal panggil $phone: $e');
    }
  }

  Future<void> _openWebsite(String url) async {
    var cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }
    final uri = Uri.parse(cleanUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        AppSnackBar.show(
          context,
          message: 'Tidak dapat membuka website $url',
          type: SnackBarType.warning,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BookstoreMap] Gagal buka website $url: $e');
    }
  }

  void _openGoogleMapsFallback() {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/toko+buku/@${_currentCenter.latitude},${_currentCenter.longitude},14z',
    );
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showSearchLocationDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.cardRadius)),
      ),
      builder: (ctx) => _SearchLocationSheet(
        onLocationSelected: (place) {
          Navigator.pop(ctx);
          final newLoc = LatLng(place.lat, place.lng);
          setState(() {
            _currentCenter = newLoc;
          });
          _mapController.move(newLoc, _zoomForRadius(_currentRadiusKm));
          _fetchBookstores(place.lat, place.lng, radiusKm: _currentRadiusKm);

          AppSnackBar.show(
            context,
            message: 'Mencari toko buku di sekitar ${place.displayName.split(',').first}',
            type: SnackBarType.info,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Toko Buku Terdekat',
          style: AppText.sectionHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Cari lokasi lain',
            onPressed: _showSearchLocationDialog,
          ),
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            tooltip: 'Lokasi saya',
            onPressed: _initUserLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Peta OpenStreetMap (Leaflet style via flutter_map)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 11.5,
              minZoom: 4.0,
              maxZoom: 18.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) {
                  _currentCenter = pos.center;
                }
              },
            ),
            children: [
              // Tile layer OSM dengan opsi Dark Mode ColorFilter
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

              // Circle Layer untuk Lingkaran Radius Pencarian
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _userLocation ?? _currentCenter,
                    radius: _currentRadiusKm * 1000,
                    useRadiusInMeter: true,
                    color: (isDark ? AppColors.primaryDark : AppColors.deepTeal)
                        .withValues(alpha: 0.06),
                    borderColor: (isDark ? AppColors.primaryDark : AppColors.deepTeal)
                        .withValues(alpha: 0.25),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),

              // Marker Layer untuk Lokasi Pengguna & Toko Buku
              MarkerLayer(
                markers: [
                  // Marker Lokasi Pengguna
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.primaryColor.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: context.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.ink.withValues(alpha: 0.25),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Markers Toko Buku
                  for (final store in _bookstores)
                    Marker(
                      point: LatLng(store.lat, store.lng),
                      width: _selectedStore?.id == store.id ? 46 : 38,
                      height: _selectedStore?.id == store.id ? 46 : 38,
                      child: GestureDetector(
                        onTap: () => _onStoreSelected(store),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _selectedStore?.id == store.id
                                ? AppColors.softApricot
                                : AppColors.deepTeal,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.white,
                              width: _selectedStore?.id == store.id ? 3.0 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.ink.withValues(alpha: 0.35),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            size: _selectedStore?.id == store.id ? 24 : 18,
                            color: _selectedStore?.id == store.id
                                ? AppColors.ink
                                : AppColors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Atribusi wajib OpenStreetMap
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(
                      Uri.parse('https://openstreetmap.org/copyright'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Loading Indicator Overlay di atas Peta
          if (_isLoading)
            Positioned(
              top: AppSpacing.m,
              left: AppSpacing.pageMargin,
              right: AppSpacing.pageMargin,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.primaryColor,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Flexible(
                        child: Text(
                          'Mencari toko buku di OpenStreetMap...',
                          style: AppText.caption(
                            color: isDark ? AppColors.inkDark : AppColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 3. Draggable Bottom Sheet untuk Daftar Toko Buku
          _buildDraggableSheet(isDark),
        ],
      ),
    );
  }

  Widget _buildDraggableSheet(bool isDark) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.35,
      minChildSize: 0.15,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.15, 0.35, 0.85],
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.cardRadius),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.s,
              AppSpacing.pageMargin,
              AppSpacing.xl,
            ),
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Baris Info Toko Buku
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoading
                              ? 'Mencari...'
                              : '${_bookstores.length} Toko Buku Ditemukan',
                          style: AppText.sectionHeading(
                            color: isDark ? AppColors.inkDark : AppColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Radius pencarian: ${_currentRadiusKm.toStringAsFixed(0)} km (Overpass OSM)',
                          style: AppText.caption(
                            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Ulang'),
                    onPressed: () => _fetchBookstores(
                      _currentCenter.latitude,
                      _currentCenter.longitude,
                      radiusKm: _currentRadiusKm,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),

              // Baris Radius Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      'Radius: ',
                      style: AppText.caption(
                        color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    for (final r in [5.0, 10.0, 15.0, 25.0, 50.0]) ...[
                      AppChip(
                        label: '${r.toInt()} km',
                        isSelected: (_currentRadiusKm - r).abs() < 1.0,
                        onTap: () {
                          _fetchBookstores(
                            _currentCenter.latitude,
                            _currentCenter.longitude,
                            radiusKm: r,
                          );
                        },
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                  ],
                ),
              ),
              const Divider(height: 16),

              // Content State: Error, Empty, atau List Toko
              if (_errorMessage != null)
                _buildErrorState(isDark)
              else if (!_isLoading && _bookstores.isEmpty)
                _buildEmptyState(isDark)
              else
                ..._bookstores.map((store) => _buildStoreCard(store, isDark)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStoreCard(Bookstore store, bool isDark) {
    final isSelected = _selectedStore?.id == store.id;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark
                ? AppColors.primaryDark.withValues(alpha: 0.15)
                : AppColors.palePeach.withValues(alpha: 0.4))
            : (isDark ? AppColors.surfaceDark : AppColors.warmIvory),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isSelected
              ? (isDark ? AppColors.primaryDark : AppColors.deepTeal)
              : (isDark ? AppColors.borderDark : AppColors.borderNeutral),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: InkWell(
          onTap: () => _onStoreSelected(store),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris Nama & Jarak
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        store.name,
                        style: AppText.cardHeading(
                          color: isDark ? AppColors.inkDark : AppColors.ink,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.primaryDark.withValues(alpha: 0.2)
                            : AppColors.softApricot.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        store.formattedDistance,
                        style: AppText.caption(
                          color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                // Alamat jika ada
                if (store.address != null && store.address!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          store.address!,
                          style: AppText.caption(
                            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Jam Buka jika ada
                if (store.openingHours != null && store.openingHours!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          store.openingHours!,
                          style: AppText.caption(
                            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: AppSpacing.m),

                // Baris Tombol Aksi: Rute, Telepon, Website
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'Rute',
                        icon: Icons.directions_rounded,
                        onPressed: () => _openDirections(store),
                      ),
                    ),
                    if (store.phone != null && store.phone!.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.s),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.phone_rounded, size: 18),
                        tooltip: 'Hubungi Toko',
                        onPressed: () => _callPhone(store.phone!),
                      ),
                    ],
                    if (store.website != null && store.website!.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.s),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.language_rounded, size: 18),
                        tooltip: 'Buka Website',
                        onPressed: () => _openWebsite(store.website!),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.warmIvory,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 44,
            color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            'Belum ada toko buku terdata di sekitar sini',
            textAlign: TextAlign.center,
            style: AppText.cardHeading(
              color: isDark ? AppColors.inkDark : AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Overpass API tidak menemukan toko dengan tag shop=books dalam radius ${_currentRadiusKm.toStringAsFixed(0)} km.',
            textAlign: TextAlign.center,
            style: AppText.caption(
              color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              if (_currentRadiusKm < 50.0) ...[
                Expanded(
                  child: PrimaryButton(
                    label: 'Perluas Radius (${_nextExpandedRadius(_currentRadiusKm).toInt()} km)',
                    icon: Icons.zoom_out_map_rounded,
                    onPressed: () => _fetchBookstores(
                      _currentCenter.latitude,
                      _currentCenter.longitude,
                      radiusKm: _nextExpandedRadius(_currentRadiusKm),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
              ],
              Expanded(
                child: SecondaryButton(
                  label: 'Buka di Google Maps',
                  icon: Icons.map_outlined,
                  onPressed: _openGoogleMapsFallback,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _nextExpandedRadius(double current) {
    if (current < 10.0) return 10.0;
    if (current < 15.0) return 15.0;
    if (current < 25.0) return 25.0;
    if (current < 50.0) return 50.0;
    return 75.0;
  }

  Widget _buildErrorState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.warmIvory,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.error),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.error),
          const SizedBox(height: AppSpacing.s),
          Text(
            _errorMessage ?? 'Terjadi kesalahan.',
            textAlign: TextAlign.center,
            style: AppText.body(
              color: isDark ? AppColors.inkDark : AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Coba Lagi',
                  icon: Icons.refresh_rounded,
                  onPressed: () => _fetchBookstores(
                    _currentCenter.latitude,
                    _currentCenter.longitude,
                    radiusKm: _currentRadiusKm,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: SecondaryButton(
                  label: 'Google Maps',
                  icon: Icons.map_outlined,
                  onPressed: _openGoogleMapsFallback,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sheet pencarian lokasi manual dengan Nominatim OSM — PRD §9.4 & Fase S6.
class _SearchLocationSheet extends StatefulWidget {
  final ValueChanged<PlaceResult> onLocationSelected;

  const _SearchLocationSheet({required this.onLocationSelected});

  @override
  State<_SearchLocationSheet> createState() => _SearchLocationSheetState();
}

class _SearchLocationSheetState extends State<_SearchLocationSheet> {
  final TextEditingController _queryController = TextEditingController();
  Timer? _debounce;
  List<PlaceResult> _places = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _queryController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    final text = query.trim();
    if (text.length < 2) {
      setState(() => _places = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final repo = context.read<BookstoreRepository>();
      final results = await repo.searchPlaces(text);
      if (mounted) {
        setState(() {
          _places = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.pageMargin,
        right: AppSpacing.pageMargin,
        top: AppSpacing.m,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            'Cari Lokasi / Kota',
            style: AppText.sectionHeading(
              color: isDark ? AppColors.inkDark : AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pencarian geocoding Nominatim OpenStreetMap',
            style: AppText.caption(
              color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          AppTextField(
            controller: _queryController,
            autofocus: true,
            hintText: 'Contoh: Bandung, Malioboro, Jakarta Selatan',
            prefixIcon: const Icon(Icons.location_city_rounded),
            onChanged: _onQueryChanged,
          ),
          const SizedBox(height: AppSpacing.s),
          // Baris Rekomendasi Kota Populer
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Kota Cepat: ',
                  style: AppText.caption(
                    color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                  ),
                ),
                for (final city in IndonesianBookstoresSeed.popularCities) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        city.displayName.split(',').first.trim(),
                        style: AppText.caption(
                          color: isDark ? AppColors.inkDark : AppColors.ink,
                        ),
                      ),
                      onPressed: () => widget.onLocationSelected(city),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_isSearching) ...[
            const SizedBox(height: AppSpacing.m),
            const Center(child: CircularProgressIndicator()),
          ],
          if (!_isSearching && _places.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            ..._places.map((place) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(
                    place.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      color: isDark ? AppColors.inkDark : AppColors.ink,
                    ),
                  ),
                  onTap: () => widget.onLocationSelected(place),
                )),
          ],
        ],
      ),
    );
  }
}
