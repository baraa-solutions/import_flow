import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/warehouse_receiving/models/warehouse_receiving_model.dart';
import 'package:frontend/features/warehouse_receiving/services/warehouse_received_report_export_service.dart';

void main() {
  group('FE08-T01: Received report items do not invent data', () {
    test('fromReceivingRecords resolves importFileCode, poNumber and removes invented defaults', () {
      final List<WarehouseReceivingModel> records = [
        WarehouseReceivingModel(
          receivingId: 10,
          grnCode: 'GRN-2026-0010',
          importFileId: 55,
          warehouseName: 'Main Warehouse - Cairo',
          arrivalDatetime: '2026-09-20T10:00:00Z',
          truckPlateNumber: 'ط د ر 7541',
          status: 'Inspection Passed / Clean Receipt',
          createdAt: '2026-09-20T10:00:00Z',
          updatedAt: '2026-09-20T10:00:00Z',
          grnItems: [
            GrnItemModel(
              itemCode: 'ITM-01',
              itemName: 'Widget A',
              invoicedQty: 100,
              acceptedQty: 100,
              shortageQty: 0,
              damagedQty: 0,
              poNumber: 'PO-77',
            ),
          ],
        ),
        WarehouseReceivingModel(
          receivingId: 11,
          grnCode: 'GRN-2026-0011',
          importFileId: 56,
          warehouseName: 'Main Warehouse - Cairo',
          arrivalDatetime: '2026-09-21T11:00:00Z',
          truckPlateNumber: 'د س 128',
          status: 'Under Bond Quarantine',
          createdAt: '2026-09-21T11:00:00Z',
          updatedAt: '2026-09-21T11:00:00Z',
          grnItems: [
            GrnItemModel(
              itemCode: 'ITM-02',
              itemName: 'Widget B',
              invoicedQty: 50,
              acceptedQty: 40,
              shortageQty: 10,
              damagedQty: 0,
            ),
          ],
        ),
      ];

      final fileCodeById = {
        55: 'IMP-2026-0055',
        56: 'IMP-2026-0056',
      };

      final items = WarehouseReceivedReportItem.fromReceivingRecords(
        records,
        fileCodeById: fileCodeById,
      );

      expect(items.length, 2);

      // Record 1 with PO
      final item1 = items[0];
      expect(item1.importFileCode, 'IMP-2026-0055');
      expect(item1.poNumber, 'PO-77');
      expect(item1.truckPlateNumber, 'ط د ر 7541');
      expect(item1.status, 'Inspection Passed / Clean Receipt');
      expect(item1.receivingId, 10);
      expect(item1.poNumber.contains('PO-MAIN'), isFalse);

      // Record 2 without PO
      final item2 = items[1];
      expect(item2.importFileCode, 'IMP-2026-0056');
      expect(item2.poNumber, '');
      expect(item2.truckPlateNumber, 'د س 128');
      expect(item2.status, 'Under Bond Quarantine');
      expect(item2.receivingId, 11);
      expect(item2.importFileCode.contains('IMP-56'), isFalse);
    });
  });
}
