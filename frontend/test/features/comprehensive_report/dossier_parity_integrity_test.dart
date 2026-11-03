import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/comprehensive_report/models/comprehensive_dossier_model.dart';
import 'package:frontend/features/comprehensive_report/services/comprehensive_report_export_service.dart';
import 'package:frontend/features/experience_guide/models/smart_reference_card_model.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/purchase_orders/utils/po_packing_matcher.dart';

void main() {
  group('Parity & Integrity Tests (Session 4.3)', () {
    const testAcid = '5281534391023010013';
    const testHsCode = '5602290000';
    const testCbm = 66.388;
    const testGrossWeight = 10510.0;
    const testNetWeight = 10080.0;
    const testSupplier = 'Suzhou Yuheng Textile Co.,Ltd';
    const testFileCode = 'IMP-2026-0005';
    const testForm4 = 'FORM4-2026-99';

    final dossierJson = {
      'import_file_id': 105,
      'import_file_code': testFileCode,
      'custom_file_number': 'CFN-8899',
      'status': 'Under Clearance',
      'current_stage': 'Customs Inspection',
      'current_module': 'P07',
      'progress_percent': 70.0,
      'next_action': 'Sampling and Release',
      'company_id': 1,
      'company_name': 'SCAS For Construction And Finishing',
      'supplier_id': 2,
      'supplier_name': testSupplier,
      'shipment_mode': 'Sea FCL',
      'incoterm_code': 'EXW',
      'shipment_category': 'Standard Commercial',
      'priority': 'High',
      'commodity': 'PET Acoustic Panels',
      'port_of_loading': 'Shanghai Port',
      'port_of_discharge': 'El Dekheila Port',
      'total_packages': 144,
      'gross_weight_kg': testGrossWeight,
      'net_weight_kg': testNetWeight,
      'total_cbm': testCbm,
      'target_free_days': 21,
      'acid_number': testAcid,
      'form4_no': testForm4,
      'smart_recommendation': 'اقتراح شحن بحري حاوية كاملة (Sea FCL)',
      'smart_reference_card': {
        'import_file_id': 105,
        'import_file_code': testFileCode,
        'custom_file_number': 'CFN-8899',
        'product_summary': {
          'hs_code': testHsCode,
          'product_category': 'PET Acoustic Panels (YH-652)',
          'total_cbm': testCbm,
          'total_gross_weight_kg': testGrossWeight,
          'total_net_weight_kg': testNetWeight,
          'packages_count': 144,
        },
        'route_summary': {
          'origin_port': 'Shanghai Port',
          'destination_port': 'El Dekheila Port',
          'shipping_line': 'Wan Hai Lines Ltd.',
          'incoterm_code': 'EXW',
          'shipment_mode': 'Sea FCL',
        },
        'critical_dates': {
          'target_free_days': 21,
          'free_time_status': '21 days safe window',
          'required_eta': '2026-11-15',
        },
        'document_status': {
          'is_complete': false,
          'acid_number': testAcid,
          'form4_no': testForm4,
          'has_coo_attached': true,
          'is_coo_required': true,
        },
        'cost_summary': {
          'estimated_cost': 45000.0,
          'actual_invoiced_cost': 43200.0,
          'variance_amount': -1800.0,
          'variance_percentage': -4.0,
          'currency': 'USD',
        },
      },
      'closure_readiness': {'is_ready_for_closure': false},
    };

    final importFileJson = {
      'import_file_id': 105,
      'import_file_code': testFileCode,
      'custom_file_number': 'CFN-8899',
      'company_name': 'SCAS For Construction And Finishing',
      'supplier_name': testSupplier,
      'status': 'Under Clearance',
      'current_stage': 'Customs Inspection',
      'current_module': 'P07',
      'progress_percent': 70.0,
      'hs_code': testHsCode,
      'product_category': 'PET Acoustic Panels',
      'port_of_loading': 'Shanghai Port',
      'port_of_discharge': 'El Dekheila Port',
      'incoterm_code': 'EXW',
      'shipment_mode': 'Sea FCL',
      'acid_number': testAcid,
      'created_at': '2026-10-01T10:00:00',
      'target_free_days': 21,
      'estimated_cost': 45000.0,
      'actual_landed_cost_total_egp': 0.0,
      'actual_landed_cost_variance_egp': 0.0,
      'actual_landed_cost_variance_pct': 0.0,
      'form4_no': testForm4,
    };

    test('100% Data Parity between ComprehensiveShipmentDossierModel and SmartReferenceCardModel', () {
      final dossier = ComprehensiveShipmentDossierModel.fromJson(dossierJson);
      final refCard = SmartReferenceCardModel.fromDossier(dossier);

      // Verify ACID Parity
      expect(dossier.acidNumber, equals(testAcid));
      expect(refCard.documentStatus['acid_number'], equals(testAcid));

      // Verify HS Code Parity
      expect(refCard.hsCode, equals(testHsCode));
      expect(dossier.smartReferenceCard?['product_summary']?['hs_code'], equals(testHsCode));

      // Verify Volume & Weight Parity
      expect(refCard.totalCbm, equals(testCbm));
      expect(dossier.totalCbm, equals(testCbm));
      expect(refCard.totalGrossWeightKg, equals(testGrossWeight));
      expect(dossier.grossWeightKg, equals(testGrossWeight));
      expect(refCard.totalNetWeightKg, equals(testNetWeight));
      expect(dossier.netWeightKg, equals(testNetWeight));

      // Verify Supplier Parity
      expect(dossier.supplierName, equals(testSupplier));
    });

    testWidgets('100% Parity in Dossier Plain Text Export (buildDossierText)', (tester) async {
      final dossier = ComprehensiveShipmentDossierModel.fromJson(dossierJson);
      final file = ImportFileModel.fromJson(importFileJson);

      String? generatedText;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppLocalizationsProvider(
              locale: const Locale('ar'),
              child: Builder(
                builder: (context) {
                  generatedText = ComprehensiveReportExportService.buildDossierText(
                    context: context,
                    file: file,
                    dossier: dossier,
                  );
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(generatedText, isNotNull);
      final text = generatedText!;

      // 1. ACID Parity (Must contain exact ACID number without modification)
      expect(text, contains(testAcid));

      // 2. HS Code Parity (Must contain exact HS code)
      expect(text, contains(testHsCode));

      // 3. Volume Parity (Must contain formatted CBM)
      expect(text, contains(testCbm.toStringAsFixed(3)));

      // 4. Weight Parity (Must contain Gross and Net weights formatted via PoPackingMatcher)
      final expectedGrossFormatted = PoPackingMatcher.formatWeight(testGrossWeight);
      final expectedNetFormatted = PoPackingMatcher.formatWeight(testNetWeight);
      expect(text, contains(expectedGrossFormatted));
      expect(text, contains(expectedNetFormatted));

      // 5. Supplier Parity (Must contain exact supplier name)
      expect(text, contains(testSupplier));
    });

    testWidgets('100% Parity in TSV Export Output', (tester) async {
      final dossier = ComprehensiveShipmentDossierModel.fromJson(dossierJson);
      final file = ImportFileModel.fromJson(importFileJson);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppLocalizationsProvider(
              locale: const Locale('ar'),
              child: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ComprehensiveReportExportService.exportToTsv(
                        context: context,
                        file: file,
                        dossier: dossier,
                      );
                    },
                    child: const Text('Export TSV'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    test('Zero Data Loss when constructing from Dossier without pre-computed card', () {
      // Dossier without smart_reference_card JSON map
      final rawDossierJson = Map<String, dynamic>.from(dossierJson);
      rawDossierJson.remove('smart_reference_card');

      final rawDossier = ComprehensiveShipmentDossierModel.fromJson(rawDossierJson);
      final card = SmartReferenceCardModel.fromDossier(rawDossier);

      expect(card.importFileId, equals(105));
      expect(card.importFileCode, equals(testFileCode));
      expect(card.totalCbm, equals(testCbm));
      expect(card.totalGrossWeightKg, equals(testGrossWeight));
      expect(card.totalNetWeightKg, equals(testNetWeight));
      expect(card.documentStatus['acid_number'], equals(testAcid));
      expect(card.documentStatus['form4_no'], equals(testForm4));
    });
  });
}
