import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/shipment_inquiry/models/shipment_inquiry_filter_model.dart';
import 'package:frontend/features/shipment_inquiry/services/shipment_inquiry_export_service.dart';

void main() {
  group('ShipmentInquiryFilterModel', () {
    test('initial model has no active filters', () {
      const model = ShipmentInquiryFilterModel.empty;
      expect(model.hasActiveFilters, isFalse);
      expect(model.supplierId, isNull);
      expect(model.companyId, isNull);
      expect(model.hsCodeOrProduct, isEmpty);
    });

    test('copyWith updates filters correctly and activates hasActiveFilters', () {
      var model = const ShipmentInquiryFilterModel();
      model = model.copyWith(
        supplierId: 10,
        companyId: 20,
        hsCodeOrProduct: '6802',
        incotermCode: 'EXW',
        portOfLoading: 'Venice',
        portOfDischarge: 'Alexandria',
        shipmentMode: 'Sea FCL',
        carrier: 'MSC',
      );

      expect(model.hasActiveFilters, isTrue);
      expect(model.supplierId, equals(10));
      expect(model.companyId, equals(20));
      expect(model.hsCodeOrProduct, equals('6802'));
      expect(model.incotermCode, equals('EXW'));
      expect(model.portOfLoading, equals('Venice'));
      expect(model.portOfDischarge, equals('Alexandria'));
      expect(model.shipmentMode, equals('Sea FCL'));
      expect(model.carrier, equals('MSC'));
    });

    test('supports statuses list in copyWith and hasActiveFilters', () {
      var model = const ShipmentInquiryFilterModel();
      expect(model.hasActiveFilters, isFalse);

      model = model.copyWith(statuses: ['In Progress', 'Completed']);
      expect(model.hasActiveFilters, isTrue);
      expect(model.statuses, contains('In Progress'));
      expect(model.statuses.length, equals(2));
    });

    test('clear flags in copyWith reset fields to null', () {
      var model = const ShipmentInquiryFilterModel(
        supplierId: 5,
        companyId: 8,
        incotermCode: 'FOB',
      );

      model = model.copyWith(
        clearSupplier: true,
        clearCompany: true,
        clearIncoterm: true,
      );

      expect(model.supplierId, isNull);
      expect(model.companyId, isNull);
      expect(model.incotermCode, isNull);
      expect(model.hasActiveFilters, isFalse);
    });
  });

  group('ShipmentInquiryReportRow', () {
    test('fromImportFile correctly maps fields', () {
      final file = ImportFileModel(
        importFileId: 101,
        importFileCode: 'IMP-2026-0101',
        customFileNumber: 'CF-8890',
        companyName: 'SCAS Co.',
        supplierName: 'Vendor A (Italy)',
        hsCode: '680299',
        productCategory: 'Wall Cladding',
        shipmentMode: 'Sea - 1x40HC',
        incotermCode: 'EXW',
        portOfLoading: 'Venice',
        portOfDischarge: 'Alexandria',
        estimatedCost: 2450.0,
        estimatedCostCurrency: 'EUR',
        fileOpeningDate: '2026-05-10',
        notes: 'توريد كلادينج واجهات - مشروع A',
        invoicesData: [],
        packingListsData: [],
        projectIds: [],
        priority: 'High',
        shipmentCategory: 'New Purchase',
        isCustomsReleased: false,
        currentModule: 'Draft',
        currentStage: 'Draft',
        progressPercent: 10.0,
        nextAction: 'None',
        skippedStages: [],
        status: 'In Progress',
        owner: 'Kamal',
        isActive: true,
        createdAt: '2026-05-10',
        updatedAt: '2026-05-10',
      );

      final row = ShipmentInquiryReportRow.fromImportFile(file);

      expect(row.shipmentName, equals('توريد كلادينج واجهات - مشروع A'));
      expect(row.importFileCode, equals('IMP-2026-0101'));
      expect(row.supplierName, equals('Vendor A (Italy)'));
      expect(row.companyName, equals('SCAS Co.'));
      expect(row.itemAndHs, equals('Wall Cladding (680299)'));
      expect(row.route, equals('Venice → Alexandria'));
      expect(row.shippingMode, equals('Sea - 1x40HC'));
      expect(row.incoterm, equals('EXW'));
      expect(row.freightCost, closeTo(2450.0, 0.001));
      expect(row.currency, equals('EUR'));
      expect(row.finalCost, closeTo(2450.0, 0.001));
      expect(row.finalCostCurrency, equals('EGP'));
      expect(row.status, equals('In Progress'));
      expect(row.fileDate, equals('2026-05-10'));
    });
  });
}
