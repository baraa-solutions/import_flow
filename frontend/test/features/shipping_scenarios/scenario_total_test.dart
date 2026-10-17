import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/shipping_scenarios/models/shipping_scenario_model.dart';
import 'package:frontend/features/shipping_scenarios/utils/shipping_scenario_calculator.dart';

void main() {
  group('FE01-T04: ShippingScenarioCalculator - Strict Currency Conversion Tests', () {
    final usdBase = CurrencyModel(
      currencyId: 1,
      currencyCode: 'USD',
      currencyName: 'US Dollar',
      currencySymbol: r'$',
      isBaseCurrency: true,
      latestCommercialRate: 1.0,
    );

    final egpCurrency = CurrencyModel(
      currencyId: 2,
      currencyCode: 'EGP',
      currencyName: 'Egyptian Pound',
      currencySymbol: 'E£',
      isBaseCurrency: false,
      latestCommercialRate: 0.02, // 1 EGP = 0.02 USD
    );

    final eurCurrency = CurrencyModel(
      currencyId: 3,
      currencyCode: 'EUR',
      currencyName: 'Euro',
      currencySymbol: '€',
      isBaseCurrency: false,
      latestCommercialRate: 1.10, // 1 EUR = 1.10 USD
    );

    ShippingScenarioItemModel createItem({
      String provider = 'Cosco Shipping',
      String? quotationCurrency = 'USD',
      bool container40ftApplicable = false,
      double container40ftPrice = 0.0,
      int container40ftQty = 1,
      String container40ftCurrency = 'USD',
      bool inlandTransportFeeApplicable = false,
      double inlandTransportFeePrice = 0.0,
      String inlandTransportFeeCurrency = 'EGP',
      bool telexReleaseApplicable = false,
      double telexReleasePrice = 0.0,
      String telexReleaseCurrency = 'USD',
    }) {
      return ShippingScenarioItemModel(
        providerName: provider,
        vesselName: 'Ever Given',
        sailingDate: '2026-10-15',
        estimatedArrivalDate: '2026-11-05',
        quotationCurrency: quotationCurrency,
        container40ftApplicable: container40ftApplicable,
        container40ftPrice: container40ftPrice,
        container40ftQty: container40ftQty,
        container40ftCurrency: container40ftCurrency,
        inlandTransportFeeApplicable: inlandTransportFeeApplicable,
        inlandTransportFeePrice: inlandTransportFeePrice,
        inlandTransportFeeCurrency: inlandTransportFeeCurrency,
        telexReleaseApplicable: telexReleaseApplicable,
        telexReleasePrice: telexReleasePrice,
        telexReleaseCurrency: telexReleaseCurrency,
      );
    }

    test('returns null and flags missing currency when rate is absent (NEVER 1.0 fallback)', () {
      final item = createItem(
        provider: 'Cosco Shipping',
        quotationCurrency: 'USD',
        container40ftApplicable: true,
        container40ftPrice: 5000.0,
        container40ftQty: 1,
        container40ftCurrency: 'CNY', // CNY is missing from currencies
      );

      final result = ShippingScenarioCalculator.calculateTotalQuoteValue(
        item: item,
        currencies: [usdBase, egpCurrency],
      );

      expect(result.total, isNull);
      expect(result.hasMissingRates, isTrue);
      expect(result.missingCurrencies, contains('CNY'));
      // Verification: ensure it did not silently convert 5000 CNY as 5000 USD
      expect(result.total != 5000.0, isTrue);
    });

    test('calculates correct total when all rates are present', () {
      final item = createItem(
        provider: 'Maersk Line',
        quotationCurrency: 'USD',
        container40ftApplicable: true,
        container40ftPrice: 3000.0,
        container40ftQty: 1,
        container40ftCurrency: 'USD', // Same currency = 3000 USD
        inlandTransportFeeApplicable: true,
        inlandTransportFeePrice: 50000.0, // 50000 EGP * 0.02 = 1000 USD
        inlandTransportFeeCurrency: 'EGP',
      );

      final result = ShippingScenarioCalculator.calculateTotalQuoteValue(
        item: item,
        currencies: [usdBase, egpCurrency, eurCurrency],
      );

      expect(result.hasMissingRates, isFalse);
      expect(result.missingCurrencies, isEmpty);
      expect(result.total, closeTo(4000.0, 0.001));
    });

    test('handles cross-currency calculation when target is not base currency', () {
      // Base currency: EGP
      final egpBase = CurrencyModel(
        currencyId: 1,
        currencyCode: 'EGP',
        currencyName: 'Egyptian Pound',
        currencySymbol: 'E£',
        isBaseCurrency: true,
        latestCommercialRate: 1.0,
      );
      final usdNonBase = CurrencyModel(
        currencyId: 2,
        currencyCode: 'USD',
        currencyName: 'US Dollar',
        currencySymbol: r'$',
        isBaseCurrency: false,
        latestCommercialRate: 50.0, // 1 USD = 50 EGP
      );
      final eurNonBase = CurrencyModel(
        currencyId: 3,
        currencyCode: 'EUR',
        currencyName: 'Euro',
        currencySymbol: '€',
        isBaseCurrency: false,
        latestCommercialRate: 55.0, // 1 EUR = 55 EGP
      );

      // Charge in USD: 1100 USD. Target currency: EUR.
      // Expected EUR = 1100 * (50.0 / 55.0) = 1000.0 EUR
      final item = createItem(
        provider: 'Hapag-Lloyd',
        quotationCurrency: 'EUR',
        container40ftApplicable: true,
        container40ftPrice: 1100.0,
        container40ftQty: 1,
        container40ftCurrency: 'USD',
      );

      final result = ShippingScenarioCalculator.calculateTotalQuoteValue(
        item: item,
        currencies: [egpBase, usdNonBase, eurNonBase],
      );

      expect(result.hasMissingRates, isFalse);
      expect(result.total, closeTo(1000.0, 0.001));
    });

    test('returns null when target currency itself has no exchange rate', () {
      final item = createItem(
        provider: 'CMA CGM',
        quotationCurrency: 'AED', // AED missing
        container40ftApplicable: true,
        container40ftPrice: 2000.0,
        container40ftQty: 1,
        container40ftCurrency: 'USD',
      );

      final result = ShippingScenarioCalculator.calculateTotalQuoteValue(
        item: item,
        currencies: [usdBase],
      );

      expect(result.total, isNull);
      expect(result.missingCurrencies, contains('AED'));
    });

    test('returns null when quotationCurrency is null', () {
      final item = createItem(
        provider: 'Evergreen',
        quotationCurrency: null,
        container40ftApplicable: true,
        container40ftPrice: 2000.0,
        container40ftQty: 1,
        container40ftCurrency: 'USD',
      );

      final result = ShippingScenarioCalculator.calculateTotalQuoteValue(
        item: item,
        currencies: [usdBase],
      );

      expect(result.total, isNull);
      expect(result.hasMissingRates, isTrue);
    });

    test('same currency charges do not require cross exchange rates', () {
      final item = createItem(
        provider: 'ONE',
        quotationCurrency: 'USD',
        container40ftApplicable: true,
        container40ftPrice: 2500.0,
        container40ftQty: 1,
        container40ftCurrency: 'USD',
        telexReleaseApplicable: true,
        telexReleasePrice: 50.0,
        telexReleaseCurrency: 'USD',
      );

      final result = ShippingScenarioCalculator.calculateTotalQuoteValue(
        item: item,
        currencies: [usdBase],
      );

      expect(result.hasMissingRates, isFalse);
      expect(result.total, 2550.0);
    });
  });
}
