import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/warehouse_receiving/models/warehouse_receiving_model.dart';
import 'package:frontend/features/warehouse_receiving/services/warehouse_received_report_export_service.dart';

Widget _buildTestWidget({Locale locale = const Locale('en')}) {
  return MaterialApp(
    home: AppLocalizationsProvider(
      locale: locale,
      child: const Scaffold(body: SizedBox()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Screen 64: Warehouse Received Shipments Export Service Tests', () {
    final sampleItems = [
      const WarehouseReceivedReportItem(
        importFileCode: 'IMP-101',
        poNumber: 'PO-MAIN-101',
        truckPlateNumber: 'TRK-987',
        itemCode: 'SKU-001',
        itemName: 'Industrial Ball Bearings',
        invoicedQty: 500,
        shortageQty: 10,
        damagedQty: 5,
        receivedQty: 485,
        varianceQty: -15,
        warehouseName: 'Main Warehouse - Cairo',
        arrivalDate: '2026-09-08',
        status: 'Approved & Received',
        grnCode: 'GRN-2026-001',
      ),
      const WarehouseReceivedReportItem(
        importFileCode: 'IMP-102',
        poNumber: 'PO-MAIN-102',
        truckPlateNumber: 'TRK-456',
        itemCode: 'SKU-002',
        itemName: 'Electronic Flow Sensor',
        invoicedQty: 200,
        shortageQty: 0,
        damagedQty: 0,
        receivedQty: 200,
        varianceQty: 0,
        warehouseName: 'Alexandria Hub',
        arrivalDate: '2026-09-09',
        status: 'Approved & Received',
        grnCode: 'GRN-2026-002',
      ),
    ];

    testWidgets('exportReportToTsv produces valid TSV with UTF-8 BOM and correct headers', (tester) async {
      await tester.pumpWidget(_buildTestWidget(locale: const Locale('en')));
      final contextEn = tester.element(find.byType(SizedBox));
      final tsvEn = WarehouseReceivedReportExportService.exportReportToTsv(contextEn, sampleItems);

      expect(tsvEn.startsWith('\uFEFF'), isTrue, reason: 'TSV must begin with UTF-8 BOM');
      expect(tsvEn, contains('IMP-101'));
      expect(tsvEn, contains('PO-MAIN-101'));
      expect(tsvEn, contains('SKU-001 - Industrial Ball Bearings'));
      expect(tsvEn, contains('500'));
      expect(tsvEn, contains('485'));
      expect(tsvEn, contains('-15'));
      expect(tsvEn, contains('Main Warehouse - Cairo'));
      expect(tsvEn, contains('IMP-102'));
      expect(tsvEn, contains('+0'));

      final lines = tsvEn.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(lines.length, 3); // 1 header + 2 data rows

      // Verify Arabic locale
      await tester.pumpWidget(_buildTestWidget(locale: const Locale('ar')));
      final contextAr = tester.element(find.byType(SizedBox));
      final tsvAr = WarehouseReceivedReportExportService.exportReportToTsv(contextAr, sampleItems);
      expect(tsvAr.startsWith('\uFEFF'), isTrue);
      expect(tsvAr, contains('ملف الشحنة'));
      expect(tsvAr, contains('أمر الشراء'));
      expect(tsvAr, contains('الصنف وبيانه'));
    });

    testWidgets('exportReportToCsv produces valid CSV with UTF-8 BOM and proper escaping', (tester) async {
      await tester.pumpWidget(_buildTestWidget(locale: const Locale('en')));
      final context = tester.element(find.byType(SizedBox));
      final csv = WarehouseReceivedReportExportService.exportReportToCsv(context, sampleItems);

      expect(csv.startsWith('\uFEFF'), isTrue, reason: 'CSV must begin with UTF-8 BOM');
      expect(csv, contains('IMP-101'));
      expect(csv, contains('PO-MAIN-101'));
      expect(csv, contains('SKU-001 - Industrial Ball Bearings'));
      expect(csv, contains('Main Warehouse - Cairo'));

      final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(lines.length, 3);
    });

    testWidgets('buildReportDossier includes complete summary, KPIs, and footer', (tester) async {
      await tester.pumpWidget(_buildTestWidget(locale: const Locale('en')));
      final context = tester.element(find.byType(SizedBox));
      final dossier = WarehouseReceivedReportExportService.buildReportDossier(
        context: context,
        items: sampleItems,
      );

      expect(dossier, contains('Warehouse Operational KPI Summary'));
      expect(dossier, contains('Total Invoiced Qty: 700'));
      expect(dossier, contains('Actual Received at Warehouse: 685'));
      expect(dossier, contains('Total Damaged Qty: 5'));
      expect(dossier, contains('Total Shortage Qty: 10'));
      expect(dossier, contains('Net Quantity Variance: -15'));
      expect(dossier, contains('[1] Import File: IMP-101'));
      expect(dossier, contains('[2] Import File: IMP-102'));
      expect(dossier, contains('End of Report - Sorour Logistics Import & Warehouse Management'));
    });

    testWidgets('empty list handling in TSV, CSV, and Dossier', (tester) async {
      await tester.pumpWidget(_buildTestWidget(locale: const Locale('en')));
      final context = tester.element(find.byType(SizedBox));

      final tsv = WarehouseReceivedReportExportService.exportReportToTsv(context, []);
      expect(tsv.startsWith('\uFEFF'), isTrue);

      final csv = WarehouseReceivedReportExportService.exportReportToCsv(context, []);
      expect(csv.startsWith('\uFEFF'), isTrue);

      final dossier = WarehouseReceivedReportExportService.buildReportDossier(
        context: context,
        items: [],
      );
      expect(dossier, contains('No received shipments matching search criteria.'));
    });

    test('fromReceivingRecords maps correctly from WarehouseReceivingModel', () {
      final records = [
        WarehouseReceivingModel(
          receivingId: 1,
          grnCode: 'GRN-2026-001',
          importFileId: 50,
          warehouseName: 'Port Said Warehouse',
          arrivalDatetime: '2026-09-08 14:30:00',
          truckPlateNumber: 'TRK-1234',
          grnItems: [
            GrnItemModel(
              itemCode: 'ITM-99',
              itemName: 'Centrifugal Pump',
              invoicedQty: 100,
              acceptedQty: 95,
              shortageQty: 5,
              damagedQty: 0,
              poNumber: 'PO-MAIN-50',
            ),
          ],
          createdAt: '2026-09-08',
          updatedAt: '2026-09-08',
        ),
      ];

      final items = WarehouseReceivedReportItem.fromReceivingRecords(
        records,
        fileCodeById: {50: 'IMP-50'},
      );
      expect(items.length, 1);
      expect(items.first.importFileCode, 'IMP-50');
      expect(items.first.poNumber, 'PO-MAIN-50');
      expect(items.first.itemCode, 'ITM-99');
      expect(items.first.itemName, 'Centrifugal Pump');
      expect(items.first.invoicedQty, 100);
      expect(items.first.receivedQty, 95);
      expect(items.first.shortageQty, 5);
      expect(items.first.damagedQty, 0);
      expect(items.first.varianceQty, -5);
      expect(items.first.warehouseName, 'Port Said Warehouse');
      expect(items.first.arrivalDate, '2026-09-08');
      expect(items.first.grnCode, 'GRN-2026-001');
    });
  });
}
