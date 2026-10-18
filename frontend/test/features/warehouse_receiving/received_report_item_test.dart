import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/warehouse_receiving/models/warehouse_receiving_model.dart';
import 'package:frontend/features/warehouse_receiving/services/warehouse_received_report_export_service.dart';

void main() {
  group('FE08-T01: WarehouseReceivedReportItem unit tests', () {
    test('builds report items without inventing file code, PO, container, samples, or status', () {
      final records = [
        WarehouseReceivingModel(
          receivingId: 101,
          grnCode: 'GRN-2026-001',
          importFileId: 12,
          warehouseName: 'Main Warehouse - Cairo',
          arrivalDatetime: '2026-10-15 08:30:00',
          truckPlateNumber: 'TRK-9876-CAI',
          status: 'UNDER_QUARANTINE_INSPECTION',
          grnItems: [
            GrnItemModel(
              itemCode: 'SKU-01',
              itemName: 'Steel Valves',
              invoicedQty: 200,
              acceptedQty: 180,
              shortageQty: 20,
              damagedQty: 0,
              poNumber: 'PO-77',
            ),
          ],
          createdAt: '2026-10-15',
          updatedAt: '2026-10-15',
        ),
        WarehouseReceivingModel(
          receivingId: 102,
          grnCode: 'GRN-2026-002',
          importFileId: 15,
          warehouseName: 'Alexandria Hub',
          arrivalDatetime: '2026-10-16 11:00:00',
          truckPlateNumber: 'TRK-5432-ALX',
          status: 'DISCREPANCY_REPORTED',
          grnItems: [
            GrnItemModel(
              itemCode: 'SKU-02',
              itemName: 'Copper Pipes',
              invoicedQty: 50,
              acceptedQty: 45,
              shortageQty: 0,
              damagedQty: 5,
              poNumber: null, // No PO provided
            ),
          ],
          createdAt: '2026-10-16',
          updatedAt: '2026-10-16',
        ),
      ];

      final fileCodeById = {
        12: 'FILE-CAI-2026-012',
        15: 'FILE-ALX-2026-015',
      };

      final items = WarehouseReceivedReportItem.fromReceivingRecords(
        records,
        fileCodeById: fileCodeById,
      );

      expect(items.length, 2);

      // Record 1 assertions
      final item1 = items[0];
      expect(item1.receivingId, 101);
      expect(item1.importFileCode, 'FILE-CAI-2026-012');
      expect(item1.poNumber, 'PO-77');
      expect(item1.truckPlateNumber, 'TRK-9876-CAI');
      expect(item1.containerInfo, 'TRK-9876-CAI');
      expect(item1.status, 'UNDER_QUARANTINE_INSPECTION');
      expect(item1.importFileCode, isNot(contains('IMP-12')));
      expect(item1.poNumber, isNot(contains('PO-MAIN')));
      expect(item1.truckPlateNumber, isNot(contains('40ft HQ')));

      // Record 2 assertions (no PO on line)
      final item2 = items[1];
      expect(item2.receivingId, 102);
      expect(item2.importFileCode, 'FILE-ALX-2026-015');
      expect(item2.poNumber, '');
      expect(item2.truckPlateNumber, 'TRK-5432-ALX');
      expect(item2.status, 'DISCREPANCY_REPORTED');
      expect(item2.importFileCode, isNot(contains('IMP-15')));
      expect(item2.poNumber, isNot(contains('PO-MAIN')));
      expect(item2.truckPlateNumber, isNot(contains('40ft HQ')));
    });

    test('handles missing file code in map gracefully without inventing IMP-<id>', () {
      final records = [
        WarehouseReceivingModel(
          receivingId: 103,
          grnCode: 'GRN-2026-003',
          importFileId: 999,
          warehouseName: 'Port Said Hub',
          arrivalDatetime: '2026-10-17 14:00:00',
          truckPlateNumber: null,
          status: 'GOODS_RECEIVED',
          grnItems: [
            GrnItemModel(
              itemCode: 'SKU-03',
              itemName: 'Ball Bearings',
              invoicedQty: 10,
              acceptedQty: 10,
            ),
          ],
          createdAt: '2026-10-17',
          updatedAt: '2026-10-17',
        ),
      ];

      final items = WarehouseReceivedReportItem.fromReceivingRecords(
        records,
        fileCodeById: {}, // empty map
      );

      expect(items.length, 1);
      expect(items.first.importFileCode, '');
      expect(items.first.importFileCode, isNot(contains('IMP-999')));
      expect(items.first.poNumber, '');
      expect(items.first.truckPlateNumber, '');
      expect(items.first.status, 'GOODS_RECEIVED');
    });
  });
}
