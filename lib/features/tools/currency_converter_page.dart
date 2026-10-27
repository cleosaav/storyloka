import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/repositories/currency_repository.dart';
import '../../app/providers.dart';

// ─── Logika konversi murni (fungsi agar bisa dites) ──────────────────────────

/// Mengkonversi [amount] dari [fromCurrency] ke [toCurrency]
/// menggunakan [rates] berbasis USD.
///
/// [rates] harus memiliki key mata uang dengan nilai terhadap USD.
/// Contoh: {'USD': 1.0, 'IDR': 15500.0, 'EUR': 0.92}
double convertCurrency({
  required double amount,
  required String fromCurrency,
  required String toCurrency,
  required Map<String, double> rates,
}) {
  if (fromCurrency == toCurrency) return amount;
  final fromRate = rates[fromCurrency];
  final toRate = rates[toCurrency];
  if (fromRate == null || toRate == null || fromRate == 0) return 0;
  // Konversi ke USD dulu, lalu ke target
  final inUsd = amount / fromRate;
  return inUsd * toRate;
}

/// Format angka hasil konversi sesuai mata uang.
String formatCurrencyResult(double amount, String currency) {
  final fmt = NumberFormat.currency(
    locale: currency == 'IDR' ? 'id_ID' : 'en_US',
    symbol: _currencySymbol(currency),
    decimalDigits: currency == 'IDR' || currency == 'JPY' ? 0 : 2,
  );
  return fmt.format(amount);
}

String _currencySymbol(String code) {
  return switch (code) {
    'IDR' => 'Rp',
    'USD' => '\$',
    'EUR' => '€',
    'JPY' => '¥',
    'SGD' => 'S\$',
    _ => code,
  };
}

// ─── Daftar mata uang ─────────────────────────────────────────────────────────

const _currencies = ['IDR', 'USD', 'EUR', 'JPY', 'SGD'];

const _currencyNames = {
  'IDR': 'Rupiah Indonesia',
  'USD': 'Dolar Amerika',
  'EUR': 'Euro',
  'JPY': 'Yen Jepang',
  'SGD': 'Dolar Singapura',
};

/// Halaman Konversi Mata Uang — PRD §9.2.
///
/// UI: field nominal, dropdown dari/ke, tombol tukar (swap),
/// hasil besar (Fraunces), keterangan kurs.
/// Kurs: dari FakeCurrencyRepository (berlabel "Kurs contoh" pada Fase A).
class CurrencyConverterPage extends StatefulWidget {
  const CurrencyConverterPage({super.key});

  @override
  State<CurrencyConverterPage> createState() => _CurrencyConverterPageState();
}

class _CurrencyConverterPageState extends State<CurrencyConverterPage> {
  final _amountCtrl = TextEditingController(text: '1');
  String _fromCurrency = 'USD';
  String _toCurrency = 'IDR';

  Map<String, double>? _rates;
  DateTime? _lastUpdated;
  bool _isLoading = true;
  String? _errorMessage;

  double get _amount => double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;

  double get _result {
    if (_rates == null) return 0;
    return convertCurrency(
      amount: _amount,
      fromCurrency: _fromCurrency,
      toCurrency: _toCurrency,
      rates: _rates!,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  bool _isFromCache = false;

  Future<void> _loadRates() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final repo = context.read<CurrencyRepository>();
      final rates = await repo.getRates('USD');
      final updated = await repo.getLastUpdated();
      final fromCache = repo.isFromCache;
      if (mounted) {
        setState(() {
          _rates = rates;
          _lastUpdated = updated;
          _isFromCache = fromCache;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _errorMessage = e.toString().replaceFirst('Exception: ', ''); });
      }
    }
  }

  void _swap() {
    setState(() {
      final tmp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = tmp;
    });
  }

  String _formatLastUpdated() {
    if (_lastUpdated == null) return '';
    DateFormat fmt;
    try {
      fmt = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
    } catch (_) {
      fmt = DateFormat('d MMM yyyy, HH:mm');
    }
    final formattedDate = fmt.format(_lastUpdated!);
    if (kDebugMode && AppConfig.useFakeData) {
      return 'Kurs contoh (mode demo) • $formattedDate';
    }
    if (_isFromCache) {
      return 'Kurs tersimpan, mungkin tidak terbaru • $formattedDate';
    }
    return 'Kurs diperbarui $formattedDate';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isNarrow = screenWidth < 340 || textScale > 1.15;

    return Scaffold(
      appBar: AppBar(
        title: Text('Konversi Mata Uang',
          style: AppText.sectionHeading(color: isDark ? AppColors.inkDark : AppColors.ink)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.deepTeal))
          : _errorMessage != null
              ? _ErrorState(message: _errorMessage!, onRetry: _loadRates)
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageMargin,
                    vertical: AppSpacing.m,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Input card
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nominal',
                              style: AppText.bodyMedium(
                                color: isDark ? AppColors.inkDark : AppColors.ink,
                              ).copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: AppSpacing.s),
                            AppTextField(
                              controller: _amountCtrl,
                              hintText: '0',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: AppSpacing.l),

                            // From / Swap / To
                            if (isNarrow)
                              Column(
                                children: [
                                  _CurrencyDropdown(
                                    label: 'Dari',
                                    value: _fromCurrency,
                                    isDark: isDark,
                                    onChanged: (v) => setState(() => _fromCurrency = v!),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Center(
                                    child: IconButton(
                                      onPressed: _swap,
                                      style: IconButton.styleFrom(
                                        backgroundColor: context.primaryColor,
                                        foregroundColor: AppColors.white,
                                        shape: const CircleBorder(),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                      icon: const Icon(Icons.swap_vert_rounded, size: 22),
                                      tooltip: 'Tukar',
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  _CurrencyDropdown(
                                    label: 'Ke',
                                    value: _toCurrency,
                                    isDark: isDark,
                                    onChanged: (v) => setState(() => _toCurrency = v!),
                                  ),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: _CurrencyDropdown(
                                      label: 'Dari',
                                      value: _fromCurrency,
                                      isDark: isDark,
                                      onChanged: (v) => setState(() => _fromCurrency = v!),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                                    child: IconButton(
                                      onPressed: _swap,
                                      style: IconButton.styleFrom(
                                        backgroundColor: context.primaryColor,
                                        foregroundColor: AppColors.white,
                                        shape: const CircleBorder(),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                      icon: const Icon(Icons.swap_horiz_rounded, size: 22),
                                      tooltip: 'Tukar',
                                    ),
                                  ),
                                  Expanded(
                                    child: _CurrencyDropdown(
                                      label: 'Ke',
                                      value: _toCurrency,
                                      isDark: isDark,
                                      onChanged: (v) => setState(() => _toCurrency = v!),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.l),

                      // Hasil
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          children: [
                            Text(
                              '${NumberFormat('#,##0.##').format(_amount)} $_fromCurrency =',
                              style: AppText.body(
                                color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.s),
                            Text(
                              formatCurrencyResult(_result, _toCurrency),
                              style: AppText.displayMedium(
                                color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.s),
                            Text(
                              _toCurrency,
                              style: AppText.bodyMedium(
                                color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.m),
                            Text(
                              _formatLastUpdated(),
                              style: AppText.caption(
                                color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.l),

                      // Tabel kurs semua mata uang
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kurs Semua Mata Uang (vs $_fromCurrency)',
                              style: AppText.bodyMedium(
                                color: isDark ? AppColors.inkDark : AppColors.ink,
                              ).copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: AppSpacing.m),
                            ..._currencies.where((c) => c != _fromCurrency).map((c) {
                              final rate = convertCurrency(
                                amount: 1,
                                fromCurrency: _fromCurrency,
                                toCurrency: c,
                                rates: _rates!,
                              );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                                child: Row(
                                  children: [
                                    Text('1 $_fromCurrency =',
                                      style: AppText.caption(
                                        color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                                      )),
                                    const SizedBox(width: AppSpacing.s),
                                    Expanded(
                                      child: Text(
                                        '${formatCurrencyResult(rate, c)} $c',
                                        textAlign: TextAlign.end,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.bodyMedium(
                                          color: isDark ? AppColors.inkDark : AppColors.ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final ValueChanged<String?> onChanged;

  const _CurrencyDropdown({
    required this.label,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = _currencies.map((c) {
      return AppDropdownItem<String>(
        value: c,
        label: '$c · ${_currencyNames[c] ?? c}',
      );
    }).toList();

    return AppDropdown<String>(
      label: label,
      value: value,
      items: items,
      onChanged: onChanged,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.currency_exchange_rounded, size: 56,
              color: isDark ? AppColors.mutedDark : AppColors.error),
            const SizedBox(height: AppSpacing.m),
            Text(message,
              style: AppText.body(color: isDark ? AppColors.inkDark : AppColors.ink),
              textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.l),
            PrimaryButton(label: 'Coba lagi', icon: Icons.refresh_rounded, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
