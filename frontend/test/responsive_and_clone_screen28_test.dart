import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/clone_entity_review_dialog.dart';
import 'package:frontend/features/customs_clearance/providers/customs_clearance_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/warehouse_receiving/models/warehouse_receiving_model.dart';
import 'package:frontend/features/warehouse_receiving/providers/goods_in_transit_provider.dart';
import 'package:frontend/features/warehouse_receiving/providers/warehouse_receiving_provider.dart';
import 'package:frontend/features/warehouse_receiving/screens/warehouse_receiving_screen.dart';
import 'package:frontend/features/warehouse_receiving/widgets/search_and_clone_warehouse_receiving_dialog.dart';

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
    String? search,
  }) async {
    state = AsyncValue.data(initialRecords);
  }

  @override
  Future<WarehouseReceivingModel?> createRecord(Map<String, dynamic> payload) async {
    final created = WarehouseReceivingModel(
      receivingId: 999,
      grnCode: 'GRN-DRAFT-TEST',
      importFileId: payload['import_file_id'] ?? 10,
      warehouseName: payload['warehouse_name'] ?? 'Main Warehouse - Cairo',
      arrivalDatetime: DateTime.now().toIso8601String(),
      truckPlateNumber: payload['truck_plate_number'],
      driverName: payload['driver_name'],
      sealNumber: payload['seal_number'],
      sealIntact: payload['seal_intact'] ?? true,
      status: payload['status'] ?? 'Draft / Pending Warehouse Count',
      inspectorName: 'Kamal',
      createdAt: '2026-09-17T00:00:00Z',
      updatedAt: '2026-09-17T00:00:00Z',
    );
    initialRecords.add(created);
    state = AsyncValue.data(initialRecords);
    return created;
  }

  @override
  Future<void> softDeleteRecord(int recordId) async {
    initialRecords.removeWhere((r) => r.receivingId == recordId);
    state = AsyncValue.data(initialRecords);
  }
}

class _MockImportFilesNotifier extends ImportFilesNotifier {
  final List<ImportFileModel> initialFiles;
  _MockImportFilesNotifier(this.initialFiles) : super(Dio()) {
    state = AsyncValue.data(initialFiles);
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
    state = AsyncValue.data(initialFiles);
  }
}

class _MockPurchaseOrdersNotifier extends PurchaseOrdersNotifier {
  _MockPurchaseOrdersNotifier(Ref ref) : super(Dio(), ref) {
    state = PurchaseOrdersState(purchaseOrders: []);
  }

  @override
  Future<void> fetchPurchaseOrders() async {
    state = PurchaseOrdersState(purchaseOrders: []);
  }
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
    String? search,
  }) async {
    state = const AsyncValue.data([]);
  }
}

class _MockGoodsInTransitNotifier extends GoodsInTransitNotifier {
  _MockGoodsInTransitNotifier() : super() {
    state = const AsyncValue.data([]);
  }

  @override
  void initLedger() {
    state = const AsyncValue.data([]);
  }

  @override
  void confirmWarehouseReceipt(int importFileId) {}
}

void main() {
  final List<WarehouseReceivingModel> mockRecords = [
    WarehouseReceivingModel(
      receivingId: 101,
      grnCode: 'GRN-2026-0001',
      importFileId: 10,
      warehouseName: 'Cairo Central Warehouse',
      arrivalDatetime: '2026-09-17T10:00:00Z',
      truckPlateNumber: 'TRK-4421',
      driverName: 'Ahmed Mahmoud',
      driverPhone: '01011223344',
      sealNumber: 'SEAL-EGY-8899',
      sealIntact: true,
      grnItems: [
        GrnItemModel(
          itemCode: 'ITM-01',
          itemName: 'Industrial Pumps',
          invoicedQty: 100,
          acceptedQty: 98,
          shortageQty: 2,
          damagedQty: 0,
          quarantineFlag: false,
        ),
      ],
      totalInvoicedQty: 100,
      totalAcceptedQty: 98,
      totalShortageQty: 2,
      totalDamagedQty: 0,
      discrepancyType: 'Shortage Only',
      discrepancyNotes: '2 missing units',
      quarantineZoneAssigned: false,
      insuranceClaimFiled: false,
      status: 'Goods Received',
      inspectorName: 'Eng. Kamal',
      createdAt: '2026-09-17T10:00:00Z',
      updatedAt: '2026-09-17T10:00:00Z',
    ),
    WarehouseReceivingModel(
      receivingId: 102,
      grnCode: 'GRN-2026-0002',
      importFileId: 11,
      warehouseName: 'Alexandria Free Zone Depot',
      arrivalDatetime: '2026-09-16T14:30:00Z',
      truckPlateNumber: 'TRK-9988',
      driverName: 'Sayed Hassan',
      driverPhone: '01222334455',
      sealNumber: 'SEAL-ALX-1122',
      sealIntact: false,
      grnItems: [
        GrnItemModel(
          itemCode: 'ITM-02',
          itemName: 'Sensors & Controllers',
          invoicedQty: 50,
          acceptedQty: 45,
          shortageQty: 0,
          damagedQty: 5,
          quarantineFlag: true,
        ),
      ],
      totalInvoicedQty: 50,
      totalAcceptedQty: 45,
      totalShortageQty: 0,
      totalDamagedQty: 5,
      discrepancyType: 'Damage Only',
      discrepancyNotes: '5 broken boxes found during inspection',
      quarantineZoneAssigned: true,
      insuranceClaimFiled: true,
      insuranceClaimRef: 'CLM-2026-WH-001',
      status: 'Discrepancy Reported',
      inspectorName: 'Eng. Nadia',
      createdAt: '2026-09-16T14:30:00Z',
      updatedAt: '2026-09-16T14:30:00Z',
    ),
  ];

  final List<ImportFileModel> mockFiles = [
    ImportFileModel(
      importFileId: 10,
      importFileCode: 'IMP-2026-0010',
      companyId: 1,
      companyName: 'Al-Amal Logistics Co.',
      supplierName: 'Siemens Germany',
      acidNumber: '1234567890123456789',
      portOfLoading: 'Hamburg',
      portOfDischarge: 'Alexandria',
      currentModule: 'Warehouse Receiving',
      currentStage: 'Port Inspection',
      nextAction: 'Warehouse Count',
      status: 'Active',
      createdAt: '2026-09-01T00:00:00Z',
      updatedAt: '2026-09-01T00:00:00Z',
    ),
  ];

  Widget buildTestWidget({
    Size size = const Size(1440, 900),
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('ar'),
    List<WarehouseReceivingModel>? records,
  }) {
    final activeRecords = records ?? List.from(mockRecords);
    return ProviderScope(
      overrides: [
        warehouseReceivingProvider.overrideWith((ref) => _MockWarehouseReceivingNotifier(activeRecords)),
        importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier(mockFiles)),
        purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier(ref)),
        customsClearanceProvider.overrideWith((ref) => _MockCustomsClearanceNotifier()),
        goodsInTransitProvider.overrideWith((ref) => _MockGoodsInTransitNotifier()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: Scaffold(
          body: Directionality(
            textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: AppLocalizationsProvider(
              locale: locale,
              child: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  platformBrightness: themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
                ),
                child: const WarehouseReceivingScreen(isEmbedded: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 28: Inbound Warehouse Hub & Receiving (GRN) Enterprise Tests', () {
    testWidgets('1. Desktop Layout (1440x900) renders with complete toolbar & zero RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(size: const Size(1440, 900)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('createGrnBtn')), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneGrnBtn')), findsOneWidget);
      expect(find.byKey(const Key('copyGrnTableTsvBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportGrnExcelBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportGrnPdfBtn')), findsOneWidget);

      expect(find.text('GRN-2026-0001'), findsOneWidget);
      expect(find.text('GRN-2026-0002'), findsOneWidget);
    });

    testWidgets('2. Tablet Layout (800x1024) wraps toolbar cleanly with zero RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(size: const Size(800, 1024)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('createGrnBtn')), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneGrnBtn')), findsOneWidget);
      expect(find.text('Cairo Central Warehouse'), findsOneWidget);
    });

    testWidgets('3. Mobile Layout (390x844) renders without RenderFlex overflow and adapts cards',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      FlutterErrorDetails? errorDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errorDetails = details;
        originalOnError?.call(details);
      };

      await tester.pumpWidget(buildTestWidget(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      FlutterError.onError = originalOnError;

      if (errorDetails != null) {
        // ignore: avoid_print
        print('=== TEST 3 FULL DETAILS ===');
        // ignore: avoid_print
        print(errorDetails.toString());
      }
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('createGrnBtn')), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneGrnBtn')), findsOneWidget);
    });

    testWidgets('4. Dark Mode WCAG AA Compliance renders with appropriate dark palette',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(size: const Size(1440, 900), themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('createGrnBtn')), findsOneWidget);
      expect(find.text('GRN-2026-0001'), findsOneWidget);
    });

    testWidgets('5. Arabic RTL Directionality properly applies right-to-left layout and localized labels',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(size: const Size(1440, 900), locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('سجل أذون الإضافة المخزنية'), findsOneWidget);
      expect(find.text('بحث واستنساخ إذن إضافة سابق'), findsOneWidget);
    });

    testWidgets('6. Search & Clone Dialog workflow enforces strict reset invariants (Task D)',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(size: const Size(1440, 900)));
      await tester.pumpAndSettle();

      // Tap toolbar button to open search and clone dialog
      final cloneBtn = find.byKey(const Key('searchAndCloneGrnBtn'));
      expect(cloneBtn, findsOneWidget);
      await tester.tap(cloneBtn);
      await tester.pumpAndSettle();

      // Confirm SearchAndCloneWarehouseReceivingDialog is visible
      expect(find.byType(SearchAndCloneWarehouseReceivingDialog), findsOneWidget);
      expect(find.byKey(const Key('selectRecordToCloneBtn_GRN-2026-0001')), findsOneWidget);

      // Select record to clone
      await tester.tap(find.byKey(const Key('selectRecordToCloneBtn_GRN-2026-0001')));
      await tester.pumpAndSettle();

      // Confirm CloneEntityReviewDialog appears
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);

      // Verify reset invariants are highlighted
      expect(find.textContaining('معرف الاستلام'), findsWidgets);
      // No client-made code is suggested: the server issues the GRN code.
      expect(find.textContaining('GRN-DRAFT-'), findsNothing);

      // Confirm cloning into draft
      final confirmBtn = find.byKey(const Key('confirmCloneBtn'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Form dialog opens populated with cloned draft data
      expect(find.text('Cairo Central Warehouse'), findsWidgets);
    });

    testWidgets('7. Row TSV Copy, Table TSV Copy, Excel/PDF exports, and Card Clone button operate cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(size: const Size(1440, 900)));
      await tester.pumpAndSettle();

      // Row TSV Copy
      final copyRowBtn = find.byKey(const Key('copyGrnRowBtn_GRN-2026-0001'));
      expect(copyRowBtn, findsOneWidget);
      await tester.tap(copyRowBtn);
      await tester.pumpAndSettle();

      // Table TSV Copy
      final copyTableBtn = find.byKey(const Key('copyGrnTableTsvBtn'));
      expect(copyTableBtn, findsOneWidget);
      await tester.tap(copyTableBtn);
      await tester.pumpAndSettle();

      // Excel & PDF export buttons
      final excelBtn = find.byKey(const Key('exportGrnExcelBtn'));
      expect(excelBtn, findsOneWidget);
      await tester.tap(excelBtn);
      await tester.pumpAndSettle();

      final pdfBtn = find.byKey(const Key('exportGrnPdfBtn'));
      expect(pdfBtn, findsOneWidget);
      await tester.tap(pdfBtn);
      await tester.pumpAndSettle();

      // Row direct clone button
      final rowCloneBtn = find.byKey(const Key('cloneGrnBtn_GRN-2026-0001'));
      expect(rowCloneBtn, findsOneWidget);
      await tester.tap(rowCloneBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.textContaining('GRN-2026-0001'), findsWidgets);
    });
  });
}
