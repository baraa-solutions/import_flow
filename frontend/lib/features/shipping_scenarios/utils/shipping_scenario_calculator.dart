import '../../currencies/models/currency_model.dart';
import '../models/shipping_scenario_model.dart';

class QuoteCalculationResult {
  final double? total;
  final Set<String> missingCurrencies;

  const QuoteCalculationResult({
    required this.total,
    required this.missingCurrencies,
  });

  bool get hasMissingRates => missingCurrencies.isNotEmpty || total == null;
}

class ShippingScenarioCalculator {
  /// Pure static function to calculate the total quote value.
  ///
  /// Converted according to commercial exchange rates:
  /// - If sourceCurrency == targetCurrency: no rate conversion needed.
  /// - Otherwise: converted = amount * (sourceRate / targetRate).
  ///
  /// If any required rate is missing (null or <= 0), it returns null for total
  /// and includes the missing currency code in [missingCurrencies].
  /// It NEVER falls back to 1.0.
  static QuoteCalculationResult calculateTotalQuoteValue({
    required ShippingScenarioItemModel item,
    required List<CurrencyModel> currencies,
  }) {
    final targetCurrency = item.quotationCurrency;
    if (targetCurrency == null || targetCurrency.trim().isEmpty) {
      return const QuoteCalculationResult(
        total: null,
        missingCurrencies: {'—'},
      );
    }

    final missingCurrencies = <String>{};

    final mainCurr = currencies.where((c) => c.currencyCode == targetCurrency).firstOrNull;
    double? targetRate;
    if (mainCurr != null) {
      targetRate = mainCurr.isBaseCurrency ? 1.0 : mainCurr.latestCommercialRate;
      if (targetRate != null && targetRate <= 0) targetRate = null;
    }

    double? convert(double amount, String? sourceCurrency) {
      if (amount == 0.0) return 0.0;
      if (sourceCurrency == null || sourceCurrency.trim().isEmpty) {
        missingCurrencies.add('—');
        return null;
      }
      if (sourceCurrency == targetCurrency) {
        return amount;
      }

      // Cross-currency conversion requires targetRate
      if (targetRate == null) {
        missingCurrencies.add(targetCurrency);
      }

      final srcCurr = currencies.where((c) => c.currencyCode == sourceCurrency).firstOrNull;
      double? sourceRate;
      if (srcCurr != null) {
        sourceRate = srcCurr.isBaseCurrency ? 1.0 : srcCurr.latestCommercialRate;
        if (sourceRate != null && sourceRate <= 0) sourceRate = null;
      }
      if (sourceRate == null) {
        missingCurrencies.add(sourceCurrency);
      }

      if (targetRate == null || sourceRate == null) {
        return null;
      }
      return amount * (sourceRate / targetRate);
    }

    double total = 0.0;
    bool anyConversionFailed = false;

    void addCharge(bool applicable, double amount, String? currency) {
      if (!applicable) return;
      final converted = convert(amount, currency);
      if (converted == null) {
        anyConversionFailed = true;
      } else {
        total += converted;
      }
    }

    addCharge(item.container40ftApplicable, item.container40ftPrice * item.container40ftQty, item.container40ftCurrency);
    addCharge(item.container20ftApplicable, item.container20ftPrice * item.container20ftQty, item.container20ftCurrency);
    addCharge(item.lclCbmApplicable, item.lclCbmPrice * item.lclCbmQty, item.lclCbmCurrency);
    addCharge(item.expressCourierApplicable, item.expressCourierPrice, item.expressCourierCurrency);
    addCharge(item.eurAtrApplicable, item.eurAtrPrice, item.eurAtrCurrency);
    addCharge(item.solasVgmApplicable, item.solasVgmPrice, item.solasVgmCurrency);
    if (item.vgmNotificationApplicable) {
      final totalQty = (item.container40ftApplicable ? item.container40ftQty : 0) +
                       (item.container20ftApplicable ? item.container20ftQty : 0);
      addCharge(true, item.vgmNotificationPrice * totalQty, item.vgmNotificationCurrency);
    }
    addCharge(item.telexReleaseApplicable, item.telexReleasePrice, item.telexReleaseCurrency);
    addCharge(item.insuranceApplicable, item.insurancePrice, item.insuranceCurrency);
    addCharge(item.bookingCancellationApplicable, item.bookingCancellationPrice, item.bookingCancellationCurrency);
    addCharge(item.ics2FilingFeeApplicable, item.ics2FilingFeePrice, item.ics2FilingFeeCurrency);
    addCharge(item.othersFeeApplicable, item.othersFeePrice, item.othersFeeCurrency);
    addCharge(item.documentFeesApplicable, item.documentFeesPrice, item.documentFeesCurrency);
    addCharge(item.waiverLetterFeeApplicable, item.waiverLetterFeePrice, item.waiverLetterFeeCurrency);
    addCharge(item.dthcApplicable, item.dthcPrice, item.dthcCurrency);
    addCharge(item.storagePerWeekApplicable, item.storagePerWeekPrice, item.storagePerWeekCurrency);
    addCharge(item.extraDayStorageApplicable, item.extraDayStoragePrice, item.extraDayStorageCurrency);
    addCharge(item.clearanceFeeApplicable, item.clearanceFeePrice, item.clearanceFeeCurrency);
    addCharge(item.inspectionFeeApplicable, item.inspectionFeePrice, item.inspectionFeeCurrency);
    addCharge(item.inlandTransportFeeApplicable, item.inlandTransportFeePrice, item.inlandTransportFeeCurrency);
    addCharge(item.portExpensesApplicable, item.portExpensesPrice, item.portExpensesCurrency);

    if (anyConversionFailed || missingCurrencies.isNotEmpty) {
      return QuoteCalculationResult(
        total: null,
        missingCurrencies: missingCurrencies,
      );
    }

    return QuoteCalculationResult(
      total: total,
      missingCurrencies: const {},
    );
  }
}
