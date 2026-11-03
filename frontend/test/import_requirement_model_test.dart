import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/import_requirements/models/import_requirement_model.dart';

void main() {
  group('ImportRequirementModel 5-Pillar Unit Tests (BP-011)', () {
    test('fromJson and toJson should parse and serialize all 5 pillars accurately', () {
      final json = {
        'assessment_id': 101,
        'assessment_code': 'BP011-2026-0001',
        'import_file_id': 5,
        'import_file_code': 'IMP-2026-0005',
        'hs_code': '8415820010',
        'commodity_description': 'آلات وأجهزة تكييف أخر متضمنة وحدة تبريد',
        'country_of_origin': 'China',
        'currency': 'USD',
        'shipment_value': 45000.0,
        'shipment_value_usd': 45000.0,
        'acid_number': '7595528271015010011',
        'consultation_id': 12,
        'consultation_code': 'CS-2026-0012',
        'confirmation_status': 'Confirmed & Cleared',
        'is_post_acid_confirmed': true,
        // Pillar 1
        'supplier_id': 3,
        'supplier_name': 'Gree Electric Appliances Inc.',
        'decree_43_applicable': true,
        'white_list_required': true,
        'white_list_verified': true,
        'factory_registration_no': 'GOEIC-REG-987654',
        // Pillar 2
        'coo_required': true,
        'coo_type': 'EUR.1 (الشراكة الأوروبية / إفتا / تركيا)',
        'coo_status': 'تم الاستلام والتحقق',
        'coo_notes': 'اتفاقية الشراكة إعفاء كامل',
        // Pillar 3
        'inspection_required': true,
        'inspection_body': 'SGS',
        'inspection_status': 'تم الفحص واجتياز المطابقة',
        'inspection_report_no': 'SGS-CN-2026-8899',
        'inspection_notes': 'مطابق للمواصفة القياسية المصرية ES 3795',
        // Pillar 4
        'import_permit_required': true,
        'permit_issuing_authority': 'جهاز شئون البيئة (EEAA)',
        'permit_number': 'EEAA-PERMIT-4421',
        'permit_status': 'تمت الموافقة والاعتماد',
        'permit_notes': 'موافقة بيئية لغاز R410A صديق للبيئة',
        // Pillar 5
        'msds_required': true,
        'msds_status': 'Obtained',
        'msds_notes': 'MSDS for Refrigerant',
        'halal_cert_required': false,
        'halal_cert_status': 'Not Required',
        'halal_cert_notes': null,
        'coa_required': true,
        'coa_status': 'Obtained',
        'coa_notes': 'Lab test COA attached',
        // Summary
        'overall_status': 'معتمد ومصرح للشحن',
        'risk_level': 'منخفض (Low)',
        'assessed_by': 'Kamal',
        'assessment_notes': 'تم استيفاء كافة الاشتراطات التنظيمية والقانونية بالكامل',
        'is_active': true,
        'created_at': '2026-08-15T10:00:00.000Z',
        'updated_at': '2026-08-15T10:30:00.000Z',
      };

      final model = ImportRequirementModel.fromJson(json);

      // Verify Pillar 1
      expect(model.decree43Applicable, true);
      expect(model.whiteListVerified, true);
      expect(model.factoryRegistrationNo, 'GOEIC-REG-987654');
      expect(model.supplierName, 'Gree Electric Appliances Inc.');
      expect(model.acidNumber, '7595528271015010011');
      expect(model.consultationCode, 'CS-2026-0012');
      expect(model.isPostAcidConfirmed, true);

      // Verify Pillar 2
      expect(model.cooRequired, true);
      expect(model.cooType, contains('EUR.1'));
      expect(model.cooStatus, 'تم الاستلام والتحقق');

      // Verify Pillar 3
      expect(model.inspectionRequired, true);
      expect(model.inspectionBody, 'SGS');
      expect(model.inspectionReportNo, 'SGS-CN-2026-8899');

      // Verify Pillar 4
      expect(model.importPermitRequired, true);
      expect(model.permitIssuingAuthority, contains('EEAA'));
      expect(model.permitNumber, 'EEAA-PERMIT-4421');

      // Verify Pillar 5
      expect(model.msdsRequired, true);
      expect(model.coaRequired, true);

      // Verify Summary
      expect(model.overallStatus, 'معتمد ومصرح للشحن');
      expect(model.riskLevel, 'منخفض (Low)');
      expect(model.currency, 'USD');
      expect(model.shipmentValue, 45000.0);

      final serialized = model.toJson();
      expect(serialized['assessment_code'], 'BP011-2026-0001');
      expect(serialized['currency'], 'USD');
      expect(serialized['shipment_value'], 45000.0);
      expect(serialized['acid_number'], '7595528271015010011');
      expect(serialized['factory_registration_no'], 'GOEIC-REG-987654');
      expect(serialized['inspection_report_no'], 'SGS-CN-2026-8899');
      expect(serialized['permit_number'], 'EEAA-PERMIT-4421');
    });

    test('ImportRequirementPrefillModel.fromJson parses prefill data accurately', () {
      final json = {
        'import_file_id': 2,
        'import_file_code': 'IMP-2026-0002',
        'supplier_id': 8,
        'supplier_name': 'Suzhou Yuheng Textile Co., Ltd.',
        'country_of_origin': 'China',
        'foreign_exporter_id': 'CN99887766',
        'currency': 'USD',
        'shipment_value': 32000.0,
        'po_number': 'PO-8899',
        'acid_number': '7595528271015010011',
        'consultation_id': 4,
        'consultation_code': 'CS-2026-0004',
        'broker_name': 'El-Ahram Brokerage',
        'consultation_status': 'Clearance Ready',
        'readiness_percentage': 100.0,
        'decree_43_applicable': true,
        'white_list_required': true,
        'white_list_verified': true,
        'factory_registration_no': 'CN99887766',
        'coo_required': true,
        'coo_type': 'EUR.1',
        'coo_status': 'Obtained',
        'inspection_required': true,
        'inspection_body': 'SGS',
        'inspection_status': 'Completed',
        'import_permit_required': true,
        'permit_issuing_authority': 'EEAA',
        'permit_status': 'Approved',
        'msds_required': false,
        'halal_cert_required': false,
        'coa_required': false,
      };

      final prefill = ImportRequirementPrefillModel.fromJson(json);
      expect(prefill.importFileCode, 'IMP-2026-0002');
      expect(prefill.acidNumber, '7595528271015010011');
      expect(prefill.consultationCode, 'CS-2026-0004');
      expect(prefill.decree43Applicable, true);
      expect(prefill.whiteListVerified, true);
      expect(prefill.cooRequired, true);
      expect(prefill.inspectionBody, 'SGS');
      expect(prefill.readinessPercentage, 100.0);
    });

    test('ImportRequirementHSCodeItemModel handles Decree 43 compliance states and pillar checks', () {
      // Unverified without justification -> Not fulfilled
      final unverifiedItem = ImportRequirementHSCodeItemModel(
        hsCode: '8415820010',
        decree43Applicable: true,
        whiteListVerified: false,
        cooRequired: true,
        cooStatus: 'Pending',
      );
      expect(unverifiedItem.isPillarFulfilled(0), false);
      expect(unverifiedItem.fulfilledPillarsCount, 3); // 2, 3, 4 are not required so fulfilled
      expect(unverifiedItem.isFullyCompliant, false);

      // With justification reason -> Fulfilled
      final justifiedItem = unverifiedItem.copyWith(
        decree43Action: 'justified',
        decree43Justification: 'استيراد مستلزمات إنتاج لاستخدام المصنع الخاص طبقا للقرار الوزاري',
      );
      expect(justifiedItem.isPillarFulfilled(0), true);

      // Verified registration -> Fulfilled
      final verifiedItem = unverifiedItem.copyWith(
        whiteListVerified: true,
        factoryRegistrationNo: 'GOEIC-2026-99',
      );
      expect(verifiedItem.isPillarFulfilled(0), true);

      // Complete all 5 pillars
      final fullyCompliantItem = verifiedItem.copyWith(
        cooStatus: 'Obtained',
        inspectionRequired: true,
        inspectionStatus: 'Completed',
        permitRequired: true,
        permitStatus: 'Approved',
        msdsRequired: true,
        msdsStatus: 'Obtained',
      );
      expect(fullyCompliantItem.fulfilledPillarsCount, 5);
      expect(fullyCompliantItem.isFullyCompliant, true);

      // Test JSON round-trip
      final json = fullyCompliantItem.toJson();
      expect(json['hs_code'], '8415820010');
      expect(json['decree_43_applicable'], true);
      expect(json['white_list_verified'], true);
      expect(json['factory_registration_no'], 'GOEIC-2026-99');

      final fromJson = ImportRequirementHSCodeItemModel.fromJson(json);
      expect(fromJson.hsCode, '8415820010');
      expect(fromJson.whiteListVerified, true);
      expect(fromJson.isFullyCompliant, true);
    });

    test('Advanced Operational Pillars serialization and compliance helpers', () {
      final advancedItem = ImportRequirementHSCodeItemModel(
        hsCode: '0406.90',
        commodityDescription: 'Cheddar Cheese',
        cargoxVerified: true,
        readyForAcid: true,
        commodityGroupMatched: true,
        importCardGroupCode: 'GRP-FOOD-04',
        isShelflifeApplicable: true,
        shelfLifeTotalDays: 365,
        shelfLifeRemainingPercent: 65.0,
        artworkArabicApproved: true,
        samplingRequired: true,
        labType: 'Central Food Safety Lab',
        detentionAllowed: true,
        estimatedLabFees: 4500.0,
        coldChainRequired: true,
        targetTemperature: '+4C',
        dataLoggerVerified: true,
      );

      expect(advancedItem.isReadyForAcidApplication, true);
      expect(advancedItem.isShelflifeCompliant, true);
      expect(advancedItem.isSamplingCompliant, true);
      expect(advancedItem.isLogisticsCompliant, true);

      // Industrial item where shelf-life is not applicable
      final industrialItem = ImportRequirementHSCodeItemModel(
        hsCode: '8418.10',
        commodityDescription: 'Compressor',
        cargoxVerified: true,
        commodityGroupMatched: true,
        isShelflifeApplicable: false,
      );
      expect(industrialItem.isShelflifeCompliant, true); // N/A is automatically compliant

      // When shelf-life is below 50% threshold
      final expiredItem = advancedItem.copyWith(shelfLifeRemainingPercent: 40.0);
      expect(expiredItem.isShelflifeCompliant, false);

      // JSON round trip
      final json = advancedItem.toJson();
      expect(json['cargox_verified'], true);
      expect(json['is_shelflife_applicable'], true);
      expect(json['shelf_life_remaining_percent'], 65.0);
      expect(json['detention_allowed'], true);

      final parsed = ImportRequirementHSCodeItemModel.fromJson(json);
      expect(parsed.cargoxVerified, true);
      expect(parsed.shelfLifeRemainingPercent, 65.0);
      expect(parsed.detentionAllowed, true);
      expect(parsed.estimatedLabFees, 4500.0);
    });
  });
}
