import '../models/customs_consultation_model.dart';
import '../../purchase_orders/models/purchase_order_model.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';

/// Helper for constructing multi-item customs estimate requests and mapping responses.
/// Enforces the requirement that duty/VAT/fees are strictly calculated by the backend
/// customs engine and never invented client-side.
class CustomsEstimatePayloadBuilder {
  /// Safely parses a dynamic numeric value (whether num, String Decimal, or null) to double.
  static double? parseToDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) {
      final trimmed = val.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    return null;
  }

  /// Extracts a clean 2-letter ISO origin code from string (e.g. 'DE - Germany' -> 'DE').
  static String? extractOriginCode(String? rawOrigin) {
    if (rawOrigin == null) return null;
    final trimmed = rawOrigin.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains(' - ')) {
      final code = trimmed.split(' - ').first.trim().toUpperCase();
      return code.length == 2 ? code : null;
    }
    if (trimmed.length == 2) {
      return trimmed.toUpperCase();
    }
    return null;
  }

  /// Builds the request payload for POST /api/v1/customs-tariff/estimate-multi.
  /// Only lines that match an active tariff in [tariffs] are included in the request.
  /// If no lines match a tariff, returns null.
  static Map<String, dynamic>? buildPayload({
    required List<POLineItemModel> lines,
    required List<CustomsTariffModel> tariffs,
    required String currency,
    double? exchangeRate,
    double freightForeign = 0.0,
    String? freightCurrency,
    double? freightExchangeRate,
    double freightEgp = 0.0,
    double insuranceEgp = 0.0,
    String insuranceOption = '0.5%',
    DateTime? estimateDate,
    double scaleFactor = 1.0,
    String? defaultOriginCountry,
  }) {
    if (lines.isEmpty) return null;

    final tariffById = <int, CustomsTariffModel>{
      for (final t in tariffs) t.tariffId: t,
    };
    final tariffByNormalizedHs = <String, CustomsTariffModel>{
      for (final t in tariffs) t.hsCode.replaceAll('.', '').trim(): t,
    };

    final requestLines = <Map<String, dynamic>>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final hs = line.hsCode?.trim() ?? '';
      CustomsTariffModel? matchedTariff;
      if (line.tariffId != null) {
        matchedTariff = tariffById[line.tariffId];
      }
      if (matchedTariff == null && hs.isNotEmpty && hs != 'UNASSIGNED') {
        matchedTariff = tariffByNormalizedHs[hs.replaceAll('.', '').trim()];
      }

      // Only lines with valid matched tariff are included in the estimate-multi request
      if (matchedTariff == null) continue;

      final double lineVal = line.totalPrice * scaleFactor;
      if (lineVal <= 0) continue;

      final rawOrigin = (line.countryOfOrigin != null && line.countryOfOrigin!.trim().isNotEmpty)
          ? line.countryOfOrigin
          : defaultOriginCountry;
      final originCode = extractOriginCode(rawOrigin);

      requestLines.add({
        'line_no': i + 1,
        'hs_code': matchedTariff.hsCode,
        'value_fc': lineVal,
        'weight_kg': line.grossWeightKg > 0 ? line.grossWeightKg : 0.0,
        'qty': line.quantity > 0 ? line.quantity : 1.0,
        if (originCode != null) 'origin_country': originCode,
      });
    }

    if (requestLines.isEmpty) return null;

    final isActualInsurance = insuranceOption != '0.5%' && insuranceOption != '1.0%';
    final hasFreightDoc = freightForeign > 0 || freightEgp > 0;

    return {
      'currency': currency,
      if (exchangeRate != null && exchangeRate > 0) 'exchange_rate': exchangeRate,
      'insurance_egp': insuranceEgp > 0 ? insuranceEgp : 0.0,
      'freight_egp': freightEgp > 0 ? freightEgp : 0.0,
      'freight_currency': freightCurrency ?? currency,
      'freight_foreign_amount': freightForeign,
      if (freightExchangeRate != null && freightExchangeRate > 0)
        'freight_exchange_rate': freightExchangeRate,
      'has_insurance_document': isActualInsurance,
      'has_freight_document': hasFreightDoc,
      if (insuranceOption == '0.5%') 'deemed_insurance_rate': 0.005,
      if (insuranceOption == '1.0%') 'deemed_insurance_rate': 0.01,
      if (estimateDate != null)
        'estimate_date':
            '${estimateDate.year.toString().padLeft(4, '0')}-${estimateDate.month.toString().padLeft(2, '0')}-${estimateDate.day.toString().padLeft(2, '0')}',
      'lines': requestLines,
    };
  }

  /// Maps backend engine response and original lines to [CustomsItemCalcRow] list.
  /// Lines missing a tariff receive status TARIFF_MISSING and are flagged [isTariffMissing: true].
  /// VAT 0% from engine is explicitly preserved as 0.0 (never defaulted to 14.0%).
  static List<CustomsItemCalcRow> mapEngineResponseToCalcRows({
    required Map<String, dynamic> engineResponse,
    required List<POLineItemModel> allLines,
    required List<CustomsTariffModel> tariffs,
    String? defaultOriginCountry,
    double scaleFactor = 1.0,
    double? exchangeRate,
  }) {
    final tariffById = <int, CustomsTariffModel>{
      for (final t in tariffs) t.tariffId: t,
    };
    final tariffByNormalizedHs = <String, CustomsTariffModel>{
      for (final t in tariffs) t.hsCode.replaceAll('.', '').trim(): t,
    };

    final rawEngineLines = engineResponse['lines'] as List<dynamic>? ?? [];
    final engineLinesMap = <int, Map<String, dynamic>>{};
    for (int i = 0; i < rawEngineLines.length; i++) {
      final lineData = rawEngineLines[i] as Map<String, dynamic>;
      final lNo = (lineData['line_no'] is num
              ? (lineData['line_no'] as num).toInt()
              : int.tryParse(lineData['line_no']?.toString() ?? '')) ??
          (i + 1);
      engineLinesMap[lNo] = lineData;
    }

    final double? effectiveFx = parseToDouble(engineResponse['exchange_rate']) ?? exchangeRate;

    final results = <CustomsItemCalcRow>[];

    for (int i = 0; i < allLines.length; i++) {
      final line = allLines[i];
      final hs = line.hsCode?.trim() ?? '';
      CustomsTariffModel? matchedTariff;
      if (line.tariffId != null) {
        matchedTariff = tariffById[line.tariffId];
      }
      if (matchedTariff == null && hs.isNotEmpty && hs != 'UNASSIGNED') {
        matchedTariff = tariffByNormalizedHs[hs.replaceAll('.', '').trim()];
      }

      final rawOrigin = (line.countryOfOrigin != null && line.countryOfOrigin!.trim().isNotEmpty)
          ? line.countryOfOrigin!
          : (defaultOriginCountry ?? '');

      if (matchedTariff != null) {
        final b = engineLinesMap[i + 1];

        if (b != null) {
          final double lineForeign =
              parseToDouble(b['value_fc']) ?? (line.totalPrice * scaleFactor);
          final double fobEgp = (effectiveFx != null && effectiveFx > 0)
              ? (lineForeign * effectiveFx)
              : 0.0;
          final double cifEgp = parseToDouble(b['cif_value_egp']) ?? fobEgp;
          final double dutyRate =
              parseToDouble(b['customs_duty_rate']) ?? (matchedTariff.customsDutyRate);
          final double dutyAmountEgp = parseToDouble(b['duty_egp']) ?? 0.0;
          final double vatRate =
              parseToDouble(b['vat_rate']) ?? (matchedTariff.vatRate);
          final double vatBaseEgp =
              parseToDouble(b['vat_base_egp']) ?? (cifEgp + dutyAmountEgp);
          final double vatAmountEgp = parseToDouble(b['vat_egp']) ?? 0.0;
          final double schedRate =
              parseToDouble(b['schedule_tax_rate']) ?? (matchedTariff.scheduleTaxRate);
          final double schedAmountEgp = parseToDouble(b['schedule_tax_egp']) ?? 0.0;
          final double devRate =
              parseToDouble(b['development_fee_rate']) ?? (matchedTariff.developmentFeeRate);
          final double devAmountEgp = parseToDouble(b['development_fee_egp']) ?? 0.0;
          final double svcRate =
              parseToDouble(b['customs_service_fee_rate']) ?? (matchedTariff.customsServiceFeeRate);
          final double svcAmountEgp = parseToDouble(b['customs_service_fee_egp']) ?? 0.0;
          final double impAmountEgp = parseToDouble(b['import_fee_egp']) ?? 0.0;
          final double totalLineTaxes =
              dutyAmountEgp + vatAmountEgp + schedAmountEgp + devAmountEgp + svcAmountEgp + impAmountEgp;

          final desc = line.descriptionAr.isNotEmpty
              ? line.descriptionAr
              : ((b['hs_description'] as String?)?.isNotEmpty == true
                  ? b['hs_description'] as String
                  : matchedTariff.hsDescription);

          results.add(CustomsItemCalcRow(
            hsCode: b['hs_code'] as String? ?? matchedTariff.hsCode,
            description: desc,
            qty: parseToDouble(b['qty']) ?? line.quantity,
            unit: line.unitOfMeasure,
            foreignPrice: lineForeign,
            fobEgp: fobEgp,
            freightEgp: parseToDouble(b['allocated_insurance_freight_egp']) ?? 0.0,
            insuranceEgp: 0.0,
            cifEgp: cifEgp,
            dutyRate: dutyRate,
            baseDutyRate: matchedTariff.customsDutyRate,
            dutyAmountEgp: dutyAmountEgp,
            vatRate: vatRate,
            vatBaseEgp: vatBaseEgp,
            vatAmountEgp: vatAmountEgp,
            scheduleTaxRate: schedRate,
            scheduleTaxAmountEgp: schedAmountEgp,
            developmentFeeRate: devRate,
            developmentFeeAmountEgp: devAmountEgp,
            customsServiceFeeRate: svcRate,
            customsServiceFeeAmountEgp: svcAmountEgp,
            totalTaxesAndDutiesEgp: totalLineTaxes,
            requiresCoo: (b['requires_coo'] as bool?) ?? matchedTariff.requiresCoo,
            requiresInspection: (b['requires_inspection'] as bool?) ?? matchedTariff.requiresInspection,
            requiresAcid: (b['requires_acid'] as bool?) ?? matchedTariff.requiresAcid,
            regulatoryAuthority: b['regulatory_authority'] as String? ?? matchedTariff.regulatoryAuthority,
            priorApprovalNote: b['conditions_note'] as String? ?? matchedTariff.priorApprovalNote,
            countryOfOrigin: b['origin_country'] as String? ?? (rawOrigin.isNotEmpty ? rawOrigin : null),
            appliedAgreementName: b['preferential_agreement_applied'] as String?,
            hasExemption: (b['is_exemption_applied'] as bool?) ?? false,
            exemptionConditionsNote: b['conditions_note'] as String?,
            requiredDocument: b['exemption_applied_details'] as String?,
            isTariffMissing: false,
            status: 'CALCULATED',
          ));
        } else {
          // Line has matched tariff but was not in engineResponse (e.g. value <= 0 or not yet estimated)
          final desc = line.descriptionAr.isNotEmpty
              ? line.descriptionAr
              : matchedTariff.hsDescription;
          results.add(CustomsItemCalcRow(
            hsCode: matchedTariff.hsCode,
            description: desc,
            qty: line.quantity,
            unit: line.unitOfMeasure,
            foreignPrice: line.totalPrice * scaleFactor,
            fobEgp: 0.0,
            freightEgp: 0.0,
            insuranceEgp: 0.0,
            cifEgp: 0.0,
            dutyRate: 0.0,
            baseDutyRate: matchedTariff.customsDutyRate,
            dutyAmountEgp: 0.0,
            vatRate: 0.0,
            vatBaseEgp: 0.0,
            vatAmountEgp: 0.0,
            scheduleTaxRate: 0.0,
            scheduleTaxAmountEgp: 0.0,
            developmentFeeRate: 0.0,
            developmentFeeAmountEgp: 0.0,
            customsServiceFeeRate: 0.0,
            customsServiceFeeAmountEgp: 0.0,
            totalTaxesAndDutiesEgp: 0.0,
            requiresCoo: matchedTariff.requiresCoo,
            requiresInspection: matchedTariff.requiresInspection,
            requiresAcid: matchedTariff.requiresAcid,
            regulatoryAuthority: matchedTariff.regulatoryAuthority,
            priorApprovalNote: matchedTariff.priorApprovalNote,
            countryOfOrigin: rawOrigin.isNotEmpty ? rawOrigin : null,
            isTariffMissing: false,
            status: 'UNESTIMATED',
          ));
        }
      } else {
        // Line without tariff -> TARIFF_MISSING
        final desc = line.descriptionAr.isNotEmpty
            ? line.descriptionAr
            : (line.descriptionEn?.isNotEmpty == true ? line.descriptionEn! : '—');
        results.add(CustomsItemCalcRow(
          hsCode: hs.isNotEmpty ? hs : 'UNASSIGNED',
          description: desc,
          qty: line.quantity,
          unit: line.unitOfMeasure,
          foreignPrice: line.totalPrice * scaleFactor,
          fobEgp: 0.0,
          freightEgp: 0.0,
          insuranceEgp: 0.0,
          cifEgp: 0.0,
          dutyRate: 0.0,
          baseDutyRate: 0.0,
          dutyAmountEgp: 0.0,
          vatRate: 0.0,
          vatBaseEgp: 0.0,
          vatAmountEgp: 0.0,
          scheduleTaxRate: 0.0,
          scheduleTaxAmountEgp: 0.0,
          developmentFeeRate: 0.0,
          developmentFeeAmountEgp: 0.0,
          customsServiceFeeRate: 0.0,
          customsServiceFeeAmountEgp: 0.0,
          totalTaxesAndDutiesEgp: 0.0,
          requiresCoo: false,
          requiresInspection: false,
          requiresAcid: false,
          countryOfOrigin: rawOrigin.isNotEmpty ? rawOrigin : null,
          isTariffMissing: true,
          status: 'TARIFF_MISSING',
        ));
      }
    }

    return results;
  }
}
