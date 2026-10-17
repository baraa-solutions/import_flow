import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/warehouse_receiving/models/warehouse_receiving_model.dart';
import 'package:frontend/features/warehouse_receiving/providers/warehouse_receiving_provider.dart';
import 'package:frontend/features/warehouse_receiving/screens/warehouse_receiving_screen.dart';

void main() {
  group('TR-03: Warehouse Goods Receiving Note Models Tests', () {
    test('GrnItemModel and WarehouseReceivingModel parse from and serialize to JSON correctly', () {
      final json = {
        'receiving_id': 12,
        'grn_code': 'GRN-2026-0012',
        'import_file_id': 88,
        'warehouse_name': 'Main Warehouse - Cairo (6th of October)',
        'arrival_datetime': '2026-09-18T10:30:00Z',
        'truck_plate_number': 'ط د ر 7541',
        'driver_name': 'Mohamed Ahmed',
        'driver_phone': '01012345678',
        'seal_number': 'SEAL-998822',
        'seal_intact': true,
        'grn_items': [
          {
            'item_code': 'SRV-101',
            'item_name': 'Industrial Servers',
            'invoiced_qty': 50,
            'accepted_qty': 48,
            'shortage_qty': 1,
            'damaged_qty': 1,
            'quarantine_flag': false,
          },
          {
            'item_code': 'SWT-202',
            'item_name': 'Network Switches',
            'invoiced_qty': 100,
            'accepted_qty': 100,
            'shortage_qty': 0,
            'damaged_qty': 0,
            'quarantine_flag': false,
          },
        ],
        'total_invoiced_qty': 150,
        'total_accepted_qty': 148,
        'total_shortage_qty': 1,
        'total_damaged_qty': 1,
        'discrepancy_type': 'Shortage & Damaged',
        'discrepancy_notes': '1 item short and 1 item damaged during transit',
        'quarantine_zone_assigned': false,
        'insurance_claim_filed': true,
        'insurance_claim_ref': 'CLM-2026-0001',
        'status': 'Discrepancy Reported',
        'inspector_name': 'Eng. Kamal',
        'notes': 'Seal verified intact upon arrival',
        'is_active': true,
        'created_at': '2026-09-18T10:45:00Z',
        'updated_at': '2026-09-18T10:45:00Z',
      };

      final model = WarehouseReceivingModel.fromJson(json);

      expect(model.receivingId, 12);
      expect(model.grnCode, 'GRN-2026-0012');
      expect(model.importFileId, 88);
      expect(model.warehouseName, 'Main Warehouse - Cairo (6th of October)');
      expect(model.truckPlateNumber, 'ط د ر 7541');
      expect(model.driverName, 'Mohamed Ahmed');
      expect(model.sealIntact, isTrue);
      expect(model.grnItems.length, 2);
      expect(model.totalInvoicedQty, 150);
      expect(model.totalAcceptedQty, 148);
      expect(model.totalShortageQty, 1);
      expect(model.totalDamagedQty, 1);
      expect(model.discrepancyType, 'Shortage & Damaged');
      expect(model.insuranceClaimFiled, isTrue);
      expect(model.insuranceClaimRef, 'CLM-2026-0001');

      final serialized = model.toJson();
      expect(serialized['grn_code'], 'GRN-2026-0012');
      expect(serialized['total_accepted_qty'], 148);
      expect(serialized['grn_items'], isNotEmpty);
    });

    test('Shortage and Damaged quantities balance invoiced quantity check', () {
      final item = GrnItemModel(
        itemCode: 'ITEM-1',
        itemName: 'Electronic Component',
        invoicedQty: 200,
        acceptedQty: 190,
        shortageQty: 7,
        damagedQty: 3,
      );

      expect(item.acceptedQty + item.shortageQty + item.damagedQty, equals(item.invoicedQty));
    });
  });

  group('TR-03: Warehouse Receiving Screen Widget Tests', () {
    testWidgets('Renders WarehouseReceivingScreen with action buttons', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            warehouseReceivingProvider.overrideWith(
              (ref) => _MockWarehouseReceivingNotifier([
                WarehouseReceivingModel(
                  receivingId: 1,
                  grnCode: 'GRN-2026-0001',
                  importFileId: 10,
                  warehouseName: 'Main Warehouse - Cairo',
                  arrivalDatetime: '2026-09-18T11:00:00Z',
                  totalInvoicedQty: 50,
                  totalAcceptedQty: 50,
                  totalShortageQty: 0,
                  totalDamagedQty: 0,
                  status: 'Goods Received',
                  inspectorName: 'Hassan',
                  createdAt: '2026-09-18T11:00:00Z',
                  updatedAt: '2026-09-18T11:00:00Z',
                ),
              ]),
            ),
          ],
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: const MaterialApp(
              locale: Locale('ar'),
              home: Scaffold(
                body: const WarehouseReceivingScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check create GRN button is rendered
      expect(find.byKey(const Key('createGrnBtn')), findsOneWidget);
      // Check search and clone button
      expect(find.byKey(const Key('searchAndCloneGrnBtn')), findsOneWidget);
      // Check record table shows the GRN code
      expect(find.text('GRN-2026-0001'), findsOneWidget);
    });
  });
}

class _MockWarehouseReceivingNotifier extends WarehouseReceivingNotifier {
  final List<WarehouseReceivingModel> initialRecords;
  _MockWarehouseReceivingNotifier(this.initialRecords) : super(Dio()) {
    state = AsyncValue.data(initialRecords);
  }

  @override
  Future<void> fetchRecords({
    bool includeInactive = false,
    int? importFileId,
    String? status,
    String? search, int skip = 0, int limit = 200}) async {
    state = AsyncValue.data(initialRecords);
  }
}
