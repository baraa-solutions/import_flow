import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/customs_consultation/models/customs_consultation_model.dart';
import 'package:frontend/features/customs_consultation/utils/customs_estimate_payload_builder.dart';
import 'package:frontend/features/customs_tariff/models/customs_tariff_model.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';

void main() {
  group('CustomsEstimatePayloadBuilder Tests', () {
    final sampleTariff = CustomsTariffModel(
      tariffId: 101,
      hsCode: '8471.30.00',
      hsDescription: 'Laptops and portable computers',
      customsDutyRate: 5.0,
      vatRate: 14.0,
      scheduleTaxRate: 0.0,
      developmentFeeRate: 5.0,
      importFeeRate: 0.0,
      customsServiceFeeRate: 1.0,
      requiresCoo: true,
      requiresInspection: false,
      requiresAcid: true,
      effectiveFrom: DateTime(2025, 1, 1),
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    final lineWithTariff = POLineItemModel(
      itemId: 1,
      poId: 10,
      descriptionAr: 'أجهزة حاسب آلي محمول',
      hsCode: '8471.30.00',
      tariffId: 101,
      quantity: 5,
      unitPrice: 1000.0,
      totalPrice: 5000.0,
      countryOfOrigin: 'CN - China',
      grossWeightKg: 10.0,
      unitOfMeasure: 'PCS',
    );

    final lineWithoutTariff = POLineItemModel(
      itemId: 2,
      poId: 10,
      descriptionAr: 'بند غير مصنف جمركياً',
      hsCode: null,
      tariffId: null,
      quantity: 2,
      unitPrice: 200.0,
      totalPrice: 400.0,
      unitOfMeasure: 'PCS',
    );

    test('Test 1: Payload built from lines with and without tariffs only includes tariffed lines', () {
      final payload = CustomsEstimatePayloadBuilder.buildPayload(
        lines: [lineWithTariff, lineWithoutTariff],
        tariffs: [sampleTariff],
        currency: 'USD',
        exchangeRate: 48.5,
      );

      expect(payload, isNotNull);
      expect(payload!['currency'], 'USD');
      expect(payload['exchange_rate'], 48.5);

      final reqLines = payload['lines'] as List<dynamic>;
      expect(reqLines.length, 1);
      expect(reqLines.first['line_no'], 1);
      expect(reqLines.first['hs_code'], '8471.30.00');
      expect(reqLines.first['value_fc'], 5000.0);
      expect(reqLines.first['qty'], 5.0);
      expect(reqLines.first['origin_country'], 'CN');
    });

    test('Test 2: Engine response with VAT 0% maps strictly to vatRate: 0.0 without fallback to 14.0%', () {
      final engineResponse = {
        'currency': 'USD',
        'exchange_rate': '50.00',
        'lines': [
          {
            'line_no': 1,
            'hs_code': '8471.30.00',
            'value_fc': '5000.00',
            'cif_value_egp': '250000.00',
            'customs_duty_rate': '0.00',
            'duty_egp': '0.00',
            'vat_rate': '0.00',
            'vat_egp': '0.00',
            'vat_base_egp': '250000.00',
            'schedule_tax_rate': '0.00',
            'schedule_tax_egp': '0.00',
            'development_fee_rate': '0.00',
            'development_fee_egp': '0.00',
            'customs_service_fee_rate': '0.00',
            'customs_service_fee_egp': '0.00',
            'import_fee_egp': '0.00',
            'requires_coo': true,
            'requires_inspection': false,
            'requires_acid': true,
            'is_exemption_applied': true,
            'conditions_note': 'Exempt under trade agreement',
          }
        ],
      };

      final calcRows = CustomsEstimatePayloadBuilder.mapEngineResponseToCalcRows(
        engineResponse: engineResponse,
        allLines: [lineWithTariff],
        tariffs: [sampleTariff],
        exchangeRate: 50.0,
      );

      expect(calcRows.length, 1);
      final row = calcRows.first;
      expect(row.isTariffMissing, isFalse);
      expect(row.vatRate, 0.0);
      expect(row.vatAmountEgp, 0.0);
      expect(row.dutyRate, 0.0);
      expect(row.hasExemption, isTrue);
      expect(row.status, 'CALCULATED');
    });

    test('Test 3: Uncalculated/missing tariff lines map to isTariffMissing: true and status TARIFF_MISSING', () {
      final engineResponse = {
        'currency': 'USD',
        'exchange_rate': '50.00',
        'lines': [
          {
            'line_no': 1,
            'hs_code': '8471.30.00',
            'value_fc': '5000.00',
            'cif_value_egp': '250000.00',
            'customs_duty_rate': '5.00',
            'duty_egp': '12500.00',
            'vat_rate': '14.00',
            'vat_egp': '36750.00',
          }
        ],
      };

      final calcRows = CustomsEstimatePayloadBuilder.mapEngineResponseToCalcRows(
        engineResponse: engineResponse,
        allLines: [lineWithTariff, lineWithoutTariff],
        tariffs: [sampleTariff],
        exchangeRate: 50.0,
      );

      expect(calcRows.length, 2);

      // Line 1: Tariffed & calculated
      final row1 = calcRows[0];
      expect(row1.isTariffMissing, isFalse);
      expect(row1.status, 'CALCULATED');
      expect(row1.dutyRate, 5.0);

      // Line 2: Missing tariff
      final row2 = calcRows[1];
      expect(row2.isTariffMissing, isTrue);
      expect(row2.status, 'TARIFF_MISSING');
      expect(row2.dutyRate, 0.0);
      expect(row2.dutyAmountEgp, 0.0);
      expect(row2.vatRate, 0.0);
      expect(row2.vatAmountEgp, 0.0);
      expect(row2.totalTaxesAndDutiesEgp, 0.0);
    });

    test('Test 4: CustomsRecalculationResponseModel.fromJson without exchange_rate yields null', () {
      final json = <String, dynamic>{
        'success': true,
        'message': 'Calculated successfully',
        'lines': [],
      };

      final response = CustomsRecalculationResponseModel.fromJson(json);
      expect(response.exchangeRate, isNull);
    });

    test('Test 5: Grep-guard asserting zero instances of ?? 50.0, 14.0, or 8479.89.90 in screen', () {
      final candidates = [
        File('lib/features/customs_consultation/screens/customs_consultation_screen.dart'),
        File('frontend/lib/features/customs_consultation/screens/customs_consultation_screen.dart'),
      ];
      final file = candidates.firstWhere(
        (f) => f.existsSync(),
        orElse: () => candidates.first,
      );
      expect(file.existsSync(), isTrue, reason: 'Customs consultation screen file must exist');

      final content = file.readAsStringSync();

      // Check for hardcoded 50.0 fallback
      expect(content.contains('?? 50.0'), isFalse,
          reason: 'Customs consultation screen must not contain `?? 50.0` exchange rate fallback');
      expect(content.contains("?? '50.0'"), isFalse,
          reason: 'Customs consultation screen must not contain `?? 50.0` text fallback');

      // Check for hardcoded Case A HS code
      expect(content.contains('8479.89.90'), isFalse,
          reason: 'Customs consultation screen must not contain fabricated Case A HS code 8479.89.90');

      // Check for hardcoded 14.0 VAT fallback
      expect(content.contains('?? 14.0'), isFalse,
          reason: 'Customs consultation screen must not contain `?? 14.0` VAT fallback');

      // Check for hardcoded agreement country sets
      expect(content.contains('euCountries'), isFalse,
          reason: 'Customs consultation screen must not contain hardcoded euCountries list');
      expect(content.contains('gaftaCountries'), isFalse,
          reason: 'Customs consultation screen must not contain hardcoded gaftaCountries list');
      expect(content.contains('mercosurCountries'), isFalse,
          reason: 'Customs consultation screen must not contain hardcoded mercosurCountries list');
    });

    test('Test 6: 1-based indexing handles skipped zero-value tariffed line at index 0 correctly', () {
      final zeroValLine = POLineItemModel(
        itemId: 10,
        poId: 10,
        descriptionAr: 'بند مجاني ترويجي',
        hsCode: '8471.30.00',
        tariffId: 101,
        quantity: 1,
        unitPrice: 0.0,
        totalPrice: 0.0,
        countryOfOrigin: 'CN',
        grossWeightKg: 1.0,
        unitOfMeasure: 'PCS',
      );

      final positiveValLine = POLineItemModel(
        itemId: 11,
        poId: 10,
        descriptionAr: 'أجهزة حاسب آلي محمول',
        hsCode: '8471.30.00',
        tariffId: 101,
        quantity: 2,
        unitPrice: 1000.0,
        totalPrice: 2000.0,
        countryOfOrigin: 'CN',
        grossWeightKg: 4.0,
        unitOfMeasure: 'PCS',
      );

      // Build payload with zeroValLine first (index 0) and positiveValLine second (index 1)
      final payload = CustomsEstimatePayloadBuilder.buildPayload(
        lines: [zeroValLine, positiveValLine],
        tariffs: [sampleTariff],
        currency: 'USD',
        exchangeRate: 50.0,
      );

      expect(payload, isNotNull);
      final reqLines = payload!['lines'] as List<dynamic>;
      // Only the positive value line should be included in engine request
      expect(reqLines.length, 1);
      // Its line_no must be 2 (1-based index corresponding to position in allLines)
      expect(reqLines.first['line_no'], 2);
      expect(reqLines.first['value_fc'], 2000.0);

      // Engine returns line breakdown matching line_no: 2
      final engineResponse = {
        'currency': 'USD',
        'exchange_rate': '50.00',
        'grand_total_payable_egp': '19000.00',
        'lines': [
          {
            'line_no': 2,
            'hs_code': '8471.30.00',
            'value_fc': '2000.00',
            'cif_value_egp': '100000.00',
            'customs_duty_rate': '5.00',
            'duty_egp': '5000.00',
            'vat_rate': '14.00',
            'vat_egp': '14000.00',
            'vat_base_egp': '105000.00',
            'schedule_tax_rate': '0.00',
            'schedule_tax_egp': '0.00',
            'development_fee_rate': '0.00',
            'development_fee_egp': '0.00',
            'customs_service_fee_rate': '0.00',
            'customs_service_fee_egp': '0.00',
            'import_fee_egp': '0.00',
          }
        ],
      };

      final calcRows = CustomsEstimatePayloadBuilder.mapEngineResponseToCalcRows(
        engineResponse: engineResponse,
        allLines: [zeroValLine, positiveValLine],
        tariffs: [sampleTariff],
        exchangeRate: 50.0,
      );

      expect(calcRows.length, 2);

      // Line 0: zero-value line was not sent to engine -> UNESTIMATED
      final row0 = calcRows[0];
      expect(row0.status, 'UNESTIMATED');
      expect(row0.isTariffMissing, isFalse);
      expect(row0.isCalculated, isFalse);
      expect(row0.dutyAmountEgp, 0.0);
      expect(row0.vatAmountEgp, 0.0);
      expect(row0.totalTaxesAndDutiesEgp, 0.0);

      // Line 1: mapped from line_no: 2 -> CALCULATED
      final row1 = calcRows[1];
      expect(row1.status, 'CALCULATED');
      expect(row1.isTariffMissing, isFalse);
      expect(row1.isCalculated, isTrue);
      expect(row1.dutyRate, 5.0);
      expect(row1.dutyAmountEgp, 5000.0);
      expect(row1.vatRate, 14.0);
      expect(row1.vatAmountEgp, 14000.0);
      expect(row1.totalTaxesAndDutiesEgp, 19000.0);
    });

    test('Test 7: parseToDouble tolerantly handles string decimals, numbers, and nulls; and engine grand total with additional fees', () {
      expect(CustomsEstimatePayloadBuilder.parseToDouble('50.00'), 50.0);
      expect(CustomsEstimatePayloadBuilder.parseToDouble('0.00'), 0.0);
      expect(CustomsEstimatePayloadBuilder.parseToDouble('12500.50'), 12500.5);
      expect(CustomsEstimatePayloadBuilder.parseToDouble(50.0), 50.0);
      expect(CustomsEstimatePayloadBuilder.parseToDouble(0), 0.0);
      expect(CustomsEstimatePayloadBuilder.parseToDouble(null), isNull);
      expect(CustomsEstimatePayloadBuilder.parseToDouble('not-a-number'), isNull);

      // Test response with additional fees where grand_total_payable_egp includes extra Nafeza/basic fees
      final engineResponseWithFees = {
        'currency': 'USD',
        'exchange_rate': '50.00',
        'total_duty_egp': '10000.00',
        'total_vat_egp': '15000.00',
        'additional_fees_egp': '1250.00',
        'grand_total_payable_egp': '26250.00',
        'lines': [],
      };

      final grandTotal = CustomsEstimatePayloadBuilder.parseToDouble(engineResponseWithFees['grand_total_payable_egp']);
      expect(grandTotal, 26250.0);

      // Verify grand total when zero
      final zeroEngineResponse = {
        'grand_total_payable_egp': '0.00',
      };
      expect(CustomsEstimatePayloadBuilder.parseToDouble(zeroEngineResponse['grand_total_payable_egp']), 0.0);
    });
  });
}
