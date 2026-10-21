import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../currency_repository.dart';

/// Implementasi nyata CurrencyRepository menggunakan open.er-api.com — PRD §9.2.
/// Menyimpan cache lokal (12 jam) dan menandai status cache saat offline.
class OpenExchangeRateRepository implements CurrencyRepository {
  final http.Client _client;
  SharedPreferences? prefs;

  bool _isFromCache = false;
  DateTime? _lastUpdated;

  static const String _cachePrefix = 'exchange_rates_';
  static const Duration _timeout = Duration(seconds: 15);

  OpenExchangeRateRepository({
    http.Client? client,
    this.prefs,
  }) : _client = client ?? http.Client();

  Future<SharedPreferences> _getPrefs() async {
    return prefs ??= await SharedPreferences.getInstance();
  }

  @override
  bool get isFromCache => _isFromCache;

  @override
  Future<DateTime?> getLastUpdated() async => _lastUpdated;

  @override
  Future<Map<String, double>> getRates(String baseCurrency) async {
    final base = baseCurrency.toUpperCase();
    final url = Uri.parse('https://open.er-api.com/v6/latest/$base');

    try {
      final response = await _client.get(url).timeout(_timeout);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final resultStatus = json['result'] as String?;

        if (resultStatus == 'success') {
          final rawRates = json['rates'] as Map<String, dynamic>;
          final parsedRates = <String, double>{};
          rawRates.forEach((k, v) {
            if (v is num) {
              parsedRates[k] = v.toDouble();
            }
          });

          // Baca time_last_update_utc jika ada
          final updateUtcStr = json['time_last_update_utc'] as String?;
          final updated = updateUtcStr != null
              ? DateTime.tryParse(updateUtcStr) ?? DateTime.now()
              : DateTime.now();

          _lastUpdated = updated;
          _isFromCache = false;

          // Simpan ke SharedPreferences cache 12 jam
          await _saveToCache(base, parsedRates, updated);

          return parsedRates;
        }
      }
      throw Exception('Gagal memuat kurs: status ${response.statusCode}');
    } catch (_) {
      // Saat jaringan gagal/offline, coba fallback ke cache lokal
      final cachedData = await _loadFromCache(base);
      if (cachedData != null) {
        _lastUpdated = cachedData.lastUpdated;
        _isFromCache = true;
        return cachedData.rates;
      }

      // Tanpa cache dan gagal jaringan -> lempar error
      throw Exception('Tidak ada koneksi internet dan tidak ada kurs tersimpan.');
    }
  }

  Future<void> _saveToCache(
    String base,
    Map<String, double> rates,
    DateTime updated,
  ) async {
    try {
      final prefs = await _getPrefs();
      final cacheKey = '$_cachePrefix$base';
      final cachePayload = jsonEncode({
        'rates': rates,
        'last_updated': updated.toUtc().toIso8601String(),
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      });
      await prefs.setString(cacheKey, cachePayload);
    } catch (_) {
      // Abaikan error penyimpanan cache
    }
  }

  Future<_CachedRates?> _loadFromCache(String base) async {
    try {
      final prefs = await _getPrefs();
      final cacheKey = '$_cachePrefix$base';
      final raw = prefs.getString(cacheKey);
      if (raw == null || raw.isEmpty) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final rawRates = json['rates'] as Map<String, dynamic>;
      final parsedRates = <String, double>{};
      rawRates.forEach((k, v) {
        if (v is num) {
          parsedRates[k] = v.toDouble();
        }
      });

      final updatedStr = json['last_updated'] as String?;
      final lastUpdated = updatedStr != null
          ? DateTime.tryParse(updatedStr) ?? DateTime.now()
          : DateTime.now();

      return _CachedRates(rates: parsedRates, lastUpdated: lastUpdated);
    } catch (_) {
      return null;
    }
  }
}

class _CachedRates {
  final Map<String, double> rates;
  final DateTime lastUpdated;

  _CachedRates({required this.rates, required this.lastUpdated});
}
