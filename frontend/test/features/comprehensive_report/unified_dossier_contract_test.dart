import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/providers/navigation_provider.dart';
import 'package:frontend/features/comprehensive_report/models/comprehensive_dossier_model.dart';
import 'package:frontend/features/comprehensive_report/services/comprehensive_dossier_service.dart';

void main() {
  group('Unified Dossier Contract & State Synchronization (Session 1)', () {
    test('ComprehensiveShipmentDossierModel parses full JSON payload accurately without data loss', () {
      final json = {
        'import_file_id': 105,
        'import_file_code': 'IMP-2026-0005',
        'custom_file_number': 'CFN-8899',
        'status': 'Closed',
        'current_stage': 'Archive & Close',
        'current_module': 'P10',
        'progress_percent': 100.0,
        'next_action': 'File Archived',
        'company_id': 1,
        'company_name': 'SCAS For Construction And Finishing',
        'supplier_id': 2,
        'supplier_name': 'Suzhou Yuheng Textile Co.,Ltd',
        'shipment_mode': 'Sea FCL',
        'incoterm_code': 'EXW',
        'shipment_category': 'Standard Commercial',
        'priority': 'High',
        'commodity': 'PET Acoustic Panels',
        'port_of_loading': 'Shanghai Port',
        'port_of_discharge': 'El Dekheila Port',
        'total_packages': 144,
        'gross_weight_kg': 10510.0,
        'net_weight_kg': 10080.0,
        'total_cbm': 66.388,
        'target_free_days': 21,
        'acid_number': '5281534391023010013',
        'smart_recommendation': 'اقتراح شحن بحري حاوية كاملة (Sea FCL)',
        'smart_reference_card': {
          'product_summary': {
            'hs_code': '5602290000',
            'product_category': 'PET Acoustic Panels (YH-652)',
            'total_cbm': 66.388,
            'total_gross_weight_kg': 10510.0,
            'total_net_weight_kg': 10080.0,
            'packages_count': 144,
          },
          'route_summary': {
            'origin_port': 'Shanghai Port',
            'destination_port': 'El Dekheila Port',
            'shipping_line': 'Wan Hai Lines Ltd.',
          },
        },
      };

      final dossier = ComprehensiveShipmentDossierModel.fromJson(json);

      expect(dossier.importFileId, 105);
      expect(dossier.importFileCode, 'IMP-2026-0005');
      expect(dossier.companyName, 'SCAS For Construction And Finishing');
      expect(dossier.supplierName, 'Suzhou Yuheng Textile Co.,Ltd');
      expect(dossier.grossWeightKg, 10510.0);
      expect(dossier.netWeightKg, 10080.0);
      expect(dossier.totalCbm, 66.388);
      expect(dossier.totalPackages, 144);
      expect(dossier.portOfDischarge, 'El Dekheila Port');
      expect(dossier.acidNumber, '5281534391023010013');
      expect(dossier.smartRecommendation, contains('Sea FCL'));

      final refCard = dossier.smartReferenceCard;
      expect(refCard, isNotNull);
      final prod = refCard!['product_summary'] as Map<String, dynamic>;
      expect(prod['hs_code'], '5602290000');
    });

    test('openComprehensiveReportForFile synchronizes selected file ID and navigation tab 47', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(navigationIndexProvider), 0);
      expect(container.read(selectedComprehensiveReportFileIdProvider), isNull);

      // Trigger bidirectional jump to report
      openComprehensiveReportForFile(container as dynamic, 105);

      expect(container.read(selectedComprehensiveReportFileIdProvider), 105);
      expect(container.read(navigationIndexProvider), 47);
    });

    test('openOperationalDetailsForFile synchronizes operational file ID and navigation tab 1', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(navigationIndexProvider), 0);
      expect(container.read(selectedOperationalFileIdProvider), isNull);

      // Trigger bidirectional jump to operational hub
      openOperationalDetailsForFile(container as dynamic, 105);

      expect(container.read(selectedOperationalFileIdProvider), 105);
      expect(container.read(navigationIndexProvider), 1);
    });

    test('invalidateDossier invalidates cached provider cleanly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Should run without throw
      expect(() => invalidateDossier(container as dynamic, 105), returnsNormally);
    });
  });
}
