import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/customs_clearance/providers/customs_clearance_provider.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/warehouse_receiving/models/goods_in_transit_model.dart';
import 'package:frontend/features/warehouse_receiving/models/warehouse_receiving_model.dart';
import 'package:frontend/features/warehouse_receiving/providers/goods_in_transit_provider.dart';
import 'package:frontend/features/warehouse_receiving/providers/warehouse_receiving_provider.dart';
import 'package:frontend/features/warehouse_receiving/screens/goods_in_transit_screen.dart';
import 'package:frontend/features/warehouse_receiving/screens/warehouse_received_report_screen.dart';
import 'package:frontend/features/warehouse_receiving/screens/warehouse_receiving_screen.dart';
import 'package:frontend/features/warehouse_receiving/screens/inbound_warehouse_hub_screen.dart';

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

class _MockImportFilesNotifier extends ImportFilesNotifier {
  _MockImportFilesNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {
    state = const AsyncValue.data([]);
  }
}

class _MockPurchaseOrdersNotifier extends StateNotifier<PurchaseOrdersState> implements PurchaseOrdersNotifier {
  _MockPurchaseOrdersNotifier() : super(PurchaseOrdersState(purchaseOrders: []));

  @override
  Future<void> fetchPurchaseOrders() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCustomsClearanceNotifier extends CustomsClearanceNotifier {
  _MockCustomsClearanceNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchRecords({
    bool includeInactive = false,
    int? importFileId,
    String? status,
    String? search, int skip = 0, int limit = 200}) async {
    state = const AsyncValue.data([]);
  }
}

class _MockGoodsInTransitNotifier extends GoodsInTransitNotifier {
  final List<GitLineItemModel> mockItems;
  _MockGoodsInTransitNotifier(this.mockItems) {
    state = AsyncValue.data(mockItems);
  }

  @override
  void initLedger() {
    state = AsyncValue.data(mockItems);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockGitItem = GitLineItemModel(
    importFileId: 1,
    importFileCode: 'IMP-2026-001',
    poId: 101,
    poNumber: 'PO-2026-IT-001',
    itemCode: 'ITM-SR-101',
    itemName: 'Enterprise Servers',
    invoicedQty: 250.0,
    packagesCount: 125,
    packageType: 'CT - Carton',
    containersCount: 2,
    containerType: '40ft High Cube',
    certifiedDate: '2026-08-20',
    isDeliveredToWarehouse: false,
  );

  final mockGrnRecord = WarehouseReceivingModel(
    receivingId: 1,
    grnCode: 'GRN-2026-001',
    importFileId: 1,
    warehouseName: 'Main Warehouse - Cairo',
    arrivalDatetime: '2026-08-23T10:00:00Z',
    truckPlateNumber: 'TRK-9988',
    driverName: 'Mohamed Ahmed',
    sealNumber: 'SEAL-7761',
    sealIntact: true,
    totalInvoicedQty: 250,
    totalAcceptedQty: 247,
    totalShortageQty: 0,
    totalDamagedQty: 2,
    discrepancyType: 'None',
    status: 'Goods Received',
    inspectorName: 'Eng. Hany',
    createdAt: '2026-08-23T10:00:00Z',
    updatedAt: '2026-08-23T10:00:00Z',
    grnItems: [
      GrnItemModel(
        itemCode: 'ITM-SR-101',
        itemName: 'خوادم رقمية صناعية (Enterprise Servers)',
        invoicedQty: 250,
        acceptedQty: 247,
        shortageQty: 0,
        damagedQty: 2,
      ),
    ],
  );

  group('Goods In Transit (GIT) Ledger & Model Tests', () {
    test('GitLineItemModel should parse and serialize correctly', () {
      final model = mockGitItem;
      final json = model.toJson();
      expect(json['import_file_code'], 'IMP-2026-001');
      expect(json['po_number'], 'PO-2026-IT-001');
      expect(json['invoiced_qty'], 250.0);

      final fromJson = GitLineItemModel.fromJson(json);
      expect(fromJson.itemName, 'Enterprise Servers');
      expect(fromJson.packagesCount, 125);
      expect(fromJson.isDeliveredToWarehouse, false);
    });

    testWidgets('GoodsInTransitScreen renders properly with KPI metrics and data table', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            goodsInTransitProvider.overrideWith((ref) => _MockGoodsInTransitNotifier([mockGitItem])),
          ],
          child: const AppLocalizationsProvider(
            locale: Locale('ar'),
            child: MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: GoodsInTransitScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('رصيد ومطابقة البضاعة في الطريق'), findsOneWidget);
      expect(find.textContaining('تقرير رصيد البضاعة في الطريق'), findsOneWidget);
      expect(find.textContaining('الشحنات في الطريق'), findsOneWidget);
      expect(find.textContaining('أوامر الشراء'), findsWidgets);
      expect(find.text('PO-2026-IT-001'), findsWidgets);
    });
  });

  group('Warehouse Received Shipments Report Tests', () {
    testWidgets('WarehouseReceivedReportScreen renders audit table and metrics', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            warehouseReceivingProvider.overrideWith((ref) => _MockWarehouseReceivingNotifier([mockGrnRecord])),
          ],
          child: const AppLocalizationsProvider(
            locale: Locale('ar'),
            child: MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: WarehouseReceivedReportScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('تقرير الشحنات المستلمة بالمخزن تفصيلي'), findsWidgets);
      expect(find.textContaining('المستلم الفعلي بالمخزن'), findsOneWidget);
      expect(find.textContaining('IMP-1'), findsWidgets);
      expect(find.textContaining('Enterprise Servers'), findsOneWidget);
    });
  });

  group('Warehouse Receiving GRN Screen Tests', () {
    testWidgets('WarehouseReceivingScreen renders GRN registry and toolbar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            warehouseReceivingProvider.overrideWith((ref) => _MockWarehouseReceivingNotifier([mockGrnRecord])),
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier()),
            customsClearanceProvider.overrideWith((ref) => _MockCustomsClearanceNotifier()),
            purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier()),
          ],
          child: const AppLocalizationsProvider(
            locale: Locale('ar'),
            child: MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: WarehouseReceivingScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('استلام البضائع بالمخازن وفحص الجودة'), findsOneWidget);
      expect(find.textContaining('تسجيل وصول شاحنة'), findsOneWidget);
      expect(find.text('GRN-2026-001'), findsOneWidget);
    });
  });

  group('InboundWarehouseHubScreen Tests', () {
    testWidgets('InboundWarehouseHubScreen renders with VerticalStageScaffold and subtabs', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            warehouseReceivingProvider.overrideWith((ref) => _MockWarehouseReceivingNotifier([mockGrnRecord])),
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier()),
            customsClearanceProvider.overrideWith((ref) => _MockCustomsClearanceNotifier()),
            purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier()),
          ],
          child: const AppLocalizationsProvider(
            locale: Locale('ar'),
            child: MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: InboundWarehouseHubScreen(initialSubTab: 0),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('مركز الاستلام والمخازن والبضاعة بالطريق'), findsWidgets);
      expect(find.textContaining('رصيد ومطابقة البضاعة في الطريق'), findsWidgets);
      expect(find.textContaining('استلام المخازن وأذون الإضافة'), findsWidgets);
      expect(find.textContaining('تقرير ومطابقة الشحنات المستلمة'), findsWidgets);
    });
  });
}
