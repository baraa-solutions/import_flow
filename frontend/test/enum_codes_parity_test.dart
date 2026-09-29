import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/domain_enum_labels.dart';

/// Parity with the backend enum catalog (modules/common/enum_codes.py), exported
/// as docs/enum_codes.json: {TYPE: {codes: {CODE: label_en}, legacy: {label: CODE}}}.
/// Flutter must use the same codes and map every legacy label to the same code.
const _typeMap = <String, String>{
  'RELEASE_TYPE': DomainEnumType.releaseType,
  'PAYMENT_METHOD': DomainEnumType.paymentMethod,
  'DUTY_BANK': DomainEnumType.dutyBank,
  'CLEARANCE_EXPENSE_CATEGORY': DomainEnumType.clearanceExpenseCategory,
  'TRUCK_TYPE': DomainEnumType.truckType,
  'REGULATORY_BODY': DomainEnumType.regulatoryBody,
  'CLEARANCE_QUOTE_SERVICE_CATEGORY': DomainEnumType.clearanceServiceCategory,
  'BROKER_EXPENSE_CATEGORY': DomainEnumType.brokerExpenseCategory,
  'PRICING_UNIT': DomainEnumType.brokerUnit,
  'EMPTY_CONTAINER_DEPOT': DomainEnumType.depot,
  'SKIP_REASON_CATEGORY': DomainEnumType.skipReasonCategory,
  'HOLD_REASON': DomainEnumType.holdReason,
  'INSPECTION_YARD': DomainEnumType.inspectionYard,
  'STAGE': DomainEnumType.stage,
  'CUSTOMS_CHANNEL': DomainEnumType.customsChannel,
  'INSPECTION_RESULT': DomainEnumType.inspectionResult,
  'REQUIREMENT_STATUS': DomainEnumType.requirementStatus,
  'WAREHOUSE_INSPECTION_VERDICT': DomainEnumType.warehouseInspectionVerdict,
  'DB_HEALTH_VERDICT': DomainEnumType.dbHealthVerdict,
  'ALERT_SEVERITY': DomainEnumType.alertSeverity,
  'LANDED_COST_VARIANCE_STATUS': DomainEnumType.landedCostVarianceStatus,
  'CUSTOMS_CATEGORY': DomainEnumType.customsCategory,
  'VALUE_PLACEHOLDER': DomainEnumType.valuePlaceholder,
  'MEASURE_UNIT': DomainEnumType.measureUnit,
};

/// Backend-only types that the Flutter UI does not pick from a list.
const _backendOnly = {'PHASE_FOLLOW_UP_TASK'};

void main() {
  final file = File('../docs/enum_codes.json');

  test('docs/enum_codes.json exists (run from frontend/)', () {
    expect(file.existsSync(), isTrue, reason: file.absolute.path);
  });

  test('every backend enum type is mapped in Flutter', () {
    final catalog = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    for (final type in catalog.keys) {
      expect(_typeMap.containsKey(type) || _backendOnly.contains(type), isTrue, reason: type);
    }
  });

  test('codes are identical per type', () {
    final catalog = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    _typeMap.forEach((backendType, flutterType) {
      final entry = catalog[backendType] as Map<String, dynamic>?;
      expect(entry, isNotNull, reason: backendType);
      final backendCodes = (entry!['codes'] as Map<String, dynamic>).keys.toSet();
      expect(DomainEnums.codesOf(flutterType).toSet(), backendCodes, reason: backendType);
    });
  });

  test('every backend legacy label maps to the same code in Flutter', () {
    final catalog = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final mismatches = <String>[];
    _typeMap.forEach((backendType, flutterType) {
      final legacy = (catalog[backendType] as Map<String, dynamic>)['legacy'] as Map<String, dynamic>? ?? {};
      legacy.forEach((label, code) {
        final got = DomainEnums.legacyToCode(flutterType, label);
        if (got != code) mismatches.add('$backendType: "$label" -> backend $code, flutter $got');
      });
    });
    expect(mismatches, isEmpty, reason: mismatches.join('\n'));
  });
}
