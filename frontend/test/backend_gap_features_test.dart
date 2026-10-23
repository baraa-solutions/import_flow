import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/container_loader/models/container_loader_model.dart';
import 'package:frontend/features/custody_release/models/custody_release_model.dart';
import 'package:frontend/features/expense_catalog/models/expense_catalog_model.dart';
import 'package:frontend/features/formal_letters/models/formal_letter_model.dart';
import 'package:frontend/features/smart_document_upload/models/smart_document_upload_model.dart';
import 'package:frontend/features/system_parameters/models/system_parameter_model.dart';

void main() {
  group('Backend Gap Features Models Test', () {
    test('SystemParameterModel JSON parsing', () {
      final json = {
        'param_key': 'AIR_VOLUMETRIC_KG_PER_CBM',
        'param_value': '167',
        'description': 'Air volumetric ratio',
        'is_active': true,
        'updated_at': '2026-10-21T10:00:00',
        'updated_by': 'admin',
      };
      final model = SystemParameterModel.fromJson(json);
      expect(model.paramKey, 'AIR_VOLUMETRIC_KG_PER_CBM');
      expect(model.paramValue, '167');
      expect(model.isActive, true);
      expect(model.updatedBy, 'admin');
    });

    test('ExpenseCatalogModel and BrokerMappingModel JSON parsing', () {
      final catJson = {
        'code': 'CLR-LCL-INV',
        'canonical_name_ar': 'أتعاب تخليص',
        'canonical_name_en': 'Clearance fee',
        'category': 'Clearance Fees',
        'unit_type': 'fixed',
        'allow_composite': false,
        'recognition_patterns': ['أتعاب', 'تخليص'],
        'is_active': true,
      };
      final cat = ExpenseCatalogModel.fromJson(catJson);
      expect(cat.code, 'CLR-LCL-INV');
      expect(cat.canonicalNameAr, 'أتعاب تخليص');
      expect(cat.recognitionPatterns.length, 2);

      final mapJson = {
        'broker_name': 'Express Broker',
        'raw_item_name': 'مصاريف نقل',
        'catalog_code': 'TRN-INL-01',
        'canonical_name_ar': 'نقل بري',
        'category': 'Inland Transport',
        'unit_type': 'fixed',
        'confidence_score': 0.95,
      };
      final map = BrokerMappingModel.fromJson(mapJson);
      expect(map.brokerName, 'Express Broker');
      expect(map.catalogCode, 'TRN-INL-01');
      expect(map.confidenceScore, 0.95);
    });

    test('FormalLetter models JSON parsing', () {
      final tplJson = {
        'template_type': 'demurrage_extension',
        'title_ar': 'طلب مد مهلة غرامات الأرضيات',
        'title_en': 'Demurrage Extension Request',
        'description_ar': 'خطاب موجه للتوكيل الملاحي لطلب مد مهلة الحاويات',
      };
      final tpl = FormalLetterTemplateInfo.fromJson(tplJson);
      expect(tpl.templateType, 'demurrage_extension');
      expect(tpl.titleAr, 'طلب مد مهلة غرامات الأرضيات');

      final resJson = {
        'letter_id': 101,
        'letter_code': 'LTR-2026-001',
        'template_type': 'demurrage_extension',
        'letter_title_ar': 'طلب مد مهلة',
        'letter_body': 'السادة توكيل ميرسك...',
        'import_file_id': 12,
        'import_file_code': 'IMP-0012',
        'generated_at': '2026-10-21 12:00:00',
      };
      final res = FormalLetterResponseModel.fromJson(resJson);
      expect(res.letterCode, 'LTR-2026-001');
      expect(res.importFileId, 12);
    });

    test('CustodyReleaseDossierModel JSON parsing', () {
      final json = {
        'custody_id': 5,
        'custody_code': 'CUS-2026-000005',
        'import_file_id': 14,
        'custody_undertaking_number': 'UND-8899',
        'warehouse_address': 'Cairo Warehouse 2',
        'lead_seals_count': 2,
        'lead_seal_numbers': ['SEAL-01', 'SEAL-02'],
        'status': 'RELEASED_UNDER_CUSTODY',
        'lock_active': true,
      };
      final dossier = CustodyReleaseDossierModel.fromJson(json);
      expect(dossier.custodyId, 5);
      expect(dossier.custodyCode, 'CUS-2026-000005');
      expect(dossier.lockActive, true);
      expect(dossier.leadSealNumbers.length, 2);
    });

    test('UploadSessionModel JSON parsing', () {
      final json = {
        'id': 7,
        'session_ref': 'SDU-2026-007',
        'module_name': 'purchase-order',
        'filename': 'invoice_october.pdf',
        'extraction_status': 'SUCCESS',
        'confidence_score': 0.98,
        'extracted_fields': {'po_number': 'PO-991', 'total': 15000},
        'missing_fields': [],
      };
      final s = UploadSessionModel.fromJson(json);
      expect(s.id, 7);
      expect(s.sessionRef, 'SDU-2026-007');
      expect(s.confidenceScore, 0.98);
      expect(s.extractedFields['po_number'], 'PO-991');
    });

    test('ContainerLoader models JSON parsing', () {
      final json = {
        'recommended_container': '40HC',
        'recommended_container_name': "40' High Cube",
        'recommended_count': 1,
        'status': 'FIT',
        'total_cbm': 35.5,
        'total_weight_kg': 12000.0,
        'is_stackable': true,
        'floor_utilization_pct': 75.0,
        'volume_utilization_pct': 48.0,
        'weight_utilization_pct': 42.5,
        'reasons_ar': ['الحمولة والحجم ضمن الحدود المسموح بها'],
        'all_options': [
          {
            'container_code': '40HC',
            'container_name': "40' High Cube",
            'status': 'FIT',
            'required_count': 1,
            'total_cbm': 35.5,
            'total_weight_kg': 12000.0,
            'floor_area_required_m2': 20.0,
            'container_floor_area_m2': 28.0,
            'volume_utilization_pct': 48.0,
            'weight_utilization_pct': 42.5,
            'floor_utilization_pct': 75.0,
            'reasons_ar': ['مطابق'],
          }
        ],
      };
      final eval = ContainerLoaderEvaluationResultModel.fromJson(json);
      expect(eval.recommendedContainer, '40HC');
      expect(eval.allOptions.length, 1);
      expect(eval.allOptions.first.status, 'FIT');
    });
  });
}
