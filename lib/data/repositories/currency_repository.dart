/// Kontrak konversi mata uang — PRD §13.0.
abstract class CurrencyRepository {
  /// Ambil kurs terbaru (base → rates).
  Future<Map<String, double>> getRates(String baseCurrency);

  /// Tanggal update kurs terakhir.
  Future<DateTime?> getLastUpdated();
}
