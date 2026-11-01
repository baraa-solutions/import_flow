import 'package:flutter/material.dart';

/// Predefined benchmark sample shipment data matching actual Nafeza declaration (2026-612-1-94731).
class DutyCalcSampleData {
  static const String currency = 'USD';
  static const String insuranceAmount = '14902.793';
  static const String freightForeignAmount = '234.72';
  static const String freightEgpAmount = '11922.234';
  static const String additionalFeesAmount = '1329.50';

  static List<Map<String, dynamic>> buildSampleLines() {
    return [
      {
        'hs': TextEditingController(text: '8536.41.00'),
        'value': TextEditingController(text: '607.6'),
        'inspection': TextEditingController(text: '0.00'),
        'origin': 'CN',
        'exemption': null,
        'is_exemption_conditions_met': false,
      },
      {
        'hs': TextEditingController(text: '8537.10.90'),
        'value': TextEditingController(text: '4371.2'),
        'inspection': TextEditingController(text: '8514.81'),
        'origin': 'TR',
        'exemption': null,
        'is_exemption_conditions_met': false,
      },
      {
        'hs': TextEditingController(text: '8537.10.90'),
        'value': TextEditingController(text: '6757.6'),
        'inspection': TextEditingController(text: '69772.09'),
        'origin': 'DE',
        'exemption': null,
        'is_exemption_conditions_met': false,
      },
    ];
  }
}

/// Factory for creating and initializing invoice line data structures.
class DutyCalcLineFactory {
  static Map<String, dynamic> createDefaultLine([String? initialHsCode]) {
    return {
      'hs': TextEditingController(text: initialHsCode ?? ''),
      'value': TextEditingController(),
      'inspection': TextEditingController(),
      'origin': 'CN',
      'exemption': null,
      'is_exemption_conditions_met': false,
    };
  }

  static List<Map<String, dynamic>> createLinesFromExtracted(
    List<Map<String, dynamic>> initialExtractedLines,
  ) {
    return initialExtractedLines.map((line) {
      final hs = line['hs_code']?.toString() ?? line['hs']?.toString() ?? '';
      final val = line['total_price']?.toString() ??
          line['amount']?.toString() ??
          line['value']?.toString() ??
          line['total_amount']?.toString() ??
          '';
      final origin = line['country_of_origin']?.toString() ??
          line['origin_country']?.toString() ??
          line['origin']?.toString();
      return {
        'hs': TextEditingController(text: hs),
        'value': TextEditingController(text: val),
        'inspection': TextEditingController(),
        'origin': origin,
        'exemption': null,
        'is_exemption_conditions_met': false,
      };
    }).toList();
  }

  static Map<String, dynamic> createFromSimulation(
    Map<String, dynamic> lineMap,
    double Function(dynamic, [double]) numToDouble,
  ) {
    return {
      'hs': TextEditingController(text: lineMap['hs_code']?.toString() ?? ''),
      'value': TextEditingController(
          text: numToDouble(lineMap['item_total_fob_foreign']).toStringAsFixed(2)),
      'inspection': TextEditingController(
          text: lineMap['inspection_fee_egp'] != null &&
                  numToDouble(lineMap['inspection_fee_egp']) > 0
              ? numToDouble(lineMap['inspection_fee_egp']).toStringAsFixed(2)
              : ''),
      'origin': lineMap['origin_country']?.toString() ?? 'CN',
      'exemption': lineMap['preferential_agreement_applied']?.toString(),
      'is_exemption_conditions_met': lineMap['is_exemption_applied'] == true ||
          (lineMap['preferential_agreement_applied'] != null &&
              lineMap['preferential_agreement_applied'].toString().isNotEmpty),
    };
  }
}
