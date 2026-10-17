import '../../currencies/models/currency_model.dart';

/// Pure helper for resolving exchange rates for purchase orders.
/// Enforces the requirement that commercial rates are picked strictly by order date
/// and never defaulted (e.g. date before all rates returns null, never first rate).
class PoFxRateHelper {
  /// Picks the latest active commercial exchange rate on or before [orderDate].
  ///
  /// - If [orderDate] is before all available rates, returns null.
  /// - If [orderDate] matches a rate's effective date exactly, returns that rate.
  /// - If [orderDate] is between rates, returns the previous (most recent prior) rate.
  static double? pickCommercialRate(List<ExchangeRateModel>? rates, DateTime orderDate) {
    if (rates == null || rates.isEmpty) return null;

    final orderDateStr =
        '${orderDate.year.toString().padLeft(4, '0')}-${orderDate.month.toString().padLeft(2, '0')}-${orderDate.day.toString().padLeft(2, '0')}';

    final sortedRates = List<ExchangeRateModel>.from(rates)
      ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));

    for (final r in sortedRates) {
      if (r.effectiveDate.compareTo(orderDateStr) <= 0) {
        return r.commercialRate;
      }
    }

    return null;
  }
}

/// Standalone top-level alias for convenience and direct test imports.
double? pickCommercialRate(List<ExchangeRateModel>? rates, DateTime orderDate) =>
    PoFxRateHelper.pickCommercialRate(rates, orderDate);
