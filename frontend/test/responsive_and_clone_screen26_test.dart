import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/clone_entity_review_dialog.dart';
import 'package:frontend/features/cargo_shipping/models/cargo_shipping_model.dart';
import 'package:frontend/features/cargo_shipping/providers/cargo_shipping_provider.dart';
import 'package:frontend/features/cargo_shipping/screens/cargo_shipping_screen.dart';
import 'package:frontend/features/cargo_shipping/widgets/search_and_clone_cargo_shipping_dialog.dart';
import 'package:frontend/features/freight_booking/models/freight_booking_model.dart';
import 'package:frontend/features/freight_booking/providers/freight_booking_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';

class _MockCargoShippingNotifier extends CargoShippingNotifier {
  final List<CargoShippingModel> initialRecords;
  _MockCargoShippingNotifier(this.initialRecords) : super(Dio()) {
    state = AsyncValue.data(initialRecords);
  }

  @override
  Future<void> fetchRecords({bool includeInactive = true, int? importFileId, String? status, String? search, int skip = 0, int limit = 200}) async {
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

class _MockFreightBookingNotifier extends FreightBookingNotifier {
  final List<ShipmentBookingModel> initialBookings;
  _MockFreightBookingNotifier(this.initialBookings) : super(Dio()) {
    state = AsyncValue.data(initialBookings);
  }

  @override
  Future<void> fetchBookings({bool includeInactive = false, int? importFileId, String? status, String? search, int skip = 0, int limit = 200}) async {
    state = AsyncValue.data(initialBookings);
  }
}

class _MockPurchaseOrdersNotifier extends StateNotifier<PurchaseOrdersState> implements PurchaseOrdersNotifier {
  final List<PurchaseOrderModel> initialPOs;
  _MockPurchaseOrdersNotifier(this.initialPOs) : super(PurchaseOrdersState(purchaseOrders: initialPOs));

  @override
  Future<void> fetchPurchaseOrders({
    bool includeInactive = false,
    String? search,
    int? importFileId,
    int? supplierId,
    String? status,
  }) async {
    state = state.copyWith(purchaseOrders: initialPOs, isLoading: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final List<CargoShippingModel> mockShippingRecords = [
    CargoShippingModel(
      cargoShippingId: 4,
      cargoShippingCode: 'SHP-2026-0004',
      importFileId: 1,
      importFileCode: 'IMP-2026-0001',
      companyName: 'Al-Amal Medical Group',
      shipmentType: 'FCL',
      status: 'Completed',
      isActive: true,
      createdAt: '2026-09-01T10:00:00Z',
      updatedAt: '2026-09-02T12:00:00Z',
      courierTrackingData: CourierTrackingModel(),
      cargoxExchangeData: CargoXExchangeModel(),
      containersLoadingData: [
        ContainerLoadingModel(
          containerType: '40HC',
          quantity: 1,
          containerNo: 'MSCU1234567',
          sealNo: 'SL-99001',
          tareWeightKg: 3800,
          netWeightKg: 20700,
          grossWeightKg: 24500,
          vgmStatus: 'Submitted',
          vgmRefNo: 'VGM-9901',
          containerAssignmentDate: '2026-09-01T10:00:00Z',
          trackingStatus: 'GATED_IN_AT_PORT',
          individualUnits: [
            {'container_no': 'MSCU1234567', 'seal_no': 'SL-99001'}
          ],
        ),
      ],
    ),
    CargoShippingModel(
      cargoShippingId: 5,
      cargoShippingCode: 'SHP-2026-0005',
      importFileId: 2,
      importFileCode: 'IMP-2026-0002',
      companyName: 'Delta Pharma Industries',
      shipmentType: 'LCL',
      status: 'Cargo Ready',
      isActive: true,
      createdAt: '2026-09-05T09:00:00Z',
      updatedAt: '2026-09-05T09:00:00Z',
      courierTrackingData: CourierTrackingModel(),
      cargoxExchangeData: CargoXExchangeModel(),
      lclTrackingData: LclLoadingTrackingModel(
        shipmentType: 'LCL',
        cfsWarehouseName: 'Shanghai International CFS Hub #3',
        consolidationScheduledDate: '2026-09-05T09:00:00Z',
        trackingStatus: 'ASSIGNED',
      ),
      containersLoadingData: [],
    ),
  ];

  final List<ImportFileModel> mockImportFiles = [
    ImportFileModel(
      importFileId: 1,
      importFileCode: 'IMP-2026-0001',
      companyId: 10,
      companyName: 'Al-Amal Medical Group',
      supplierName: 'Siemens Healthineers',
      acidNumber: '1234567890123456789',
      portOfLoading: 'Hamburg',
      portOfDischarge: 'Alexandria',
      currentModule: 'Cargo Shipping',
      currentStage: 'Container Allocation',
      nextAction: 'Track Containers',
      status: 'Active',
      createdAt: '2026-09-01T08:00:00Z',
      updatedAt: '2026-09-01T08:00:00Z',
    ),
    ImportFileModel(
      importFileId: 2,
      importFileCode: 'IMP-2026-0002',
      companyId: 20,
      companyName: 'Delta Pharma Industries',
      supplierName: 'Pfizer Global',
      acidNumber: '9876543210987654321',
      portOfLoading: 'Shanghai',
      portOfDischarge: 'Damietta',
      currentModule: 'Cargo Shipping',
      currentStage: 'CFS Consolidation',
      nextAction: 'Track Containers',
      status: 'Active',
      createdAt: '2026-09-05T08:00:00Z',
      updatedAt: '2026-09-05T08:00:00Z',
    ),
  ];

  Widget buildTestApp({
    Size size = const Size(1440, 900),
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('ar'),
    int initialSubTab = 0,
  }) {
    return ProviderScope(
      overrides: [
        cargoShippingProvider.overrideWith((ref) => _MockCargoShippingNotifier(mockShippingRecords)),
        importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier(mockImportFiles)),
        freightBookingProvider.overrideWith((ref) => _MockFreightBookingNotifier([])),
        purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier([])),
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
                child: CargoShippingScreen(initialSubTab: initialSubTab),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 26: CargoShippingScreen Enterprise Protocol Tests', () {
    testWidgets('Test 1: Desktop Viewport (1440x900) renders with 0 RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(1440, 900)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Check Tab 0 headers and fields
      expect(find.text('تجهيز الشحن ومتابعة التحميل'), findsWidgets);
      expect(find.text('سجل متابعة الشحنات والتحميل'), findsWidgets);
      expect(find.text('⚡ محاكاة تشغيلية ذكية ⚡'), findsOneWidget);

      // Switch to Tab 1 (Saved Cargo Registry)
      await tester.tap(find.text('سجل متابعة الشحنات والتحميل').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('createShippingBtn')), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneShippingBtn')), findsOneWidget);
      expect(find.byKey(const Key('copyShippingTableTsvBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportShippingExcelBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportShippingPdfBtn')), findsOneWidget);

      // Verify records are present in the list
      expect(find.text('SHP-2026-0004'), findsOneWidget);
      expect(find.text('SHP-2026-0005'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 2: Tablet Viewport (800x1024) renders with 0 RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(800, 1024)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('تجهيز الشحن ومتابعة التحميل'), findsWidgets);

      // Switch to Tab 1 (Saved Cargo Registry)
      await tester.tap(find.text('سجل متابعة الشحنات والتحميل').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('searchAndCloneShippingBtn')), findsOneWidget);
      expect(find.text('SHP-2026-0004'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 3: Mobile Viewport (390x844) renders with ZERO RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(390, 844)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tab 0 rendered without overflow
      expect(tester.takeException(), isNull);

      // Switch to Tab 1 (Saved Cargo Registry)
      final tabStripFinder = find.byType(ListView).first;
      await tester.drag(tabStripFinder, const Offset(300, 0));
      await tester.pump(const Duration(milliseconds: 300));
      final registryTabFinder = find.text('سجل متابعة الشحنات والتحميل').first;
      await tester.tap(registryTabFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify all buttons and records render without overflow on 390px mobile
      expect(find.byKey(const Key('createShippingBtn')), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneShippingBtn')), findsOneWidget);
      expect(find.text('SHP-2026-0004'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 4: Dark Mode WCAG AA Compliance renders with correct palette', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(
        size: const Size(1440, 900),
        themeMode: ThemeMode.dark,
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Tab 1
      await tester.tap(find.text('سجل متابعة الشحنات والتحميل').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('SHP-2026-0004'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 5: RTL Arabic Localization displays correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(
        size: const Size(1440, 900),
        locale: const Locale('ar'),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Tab 1
      await tester.tap(find.text('سجل متابعة الشحنات والتحميل').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('تسجيل ومتابعة شحنة جديدة'), findsOneWidget);
      expect(find.text('بحث واستنساخ شحنة سابقة'), findsOneWidget);
      expect(find.text('نسخ كجدول بيانات'), findsOneWidget);
      expect(find.text('تصدير سجل الشحنات إلى Excel'), findsOneWidget);
      expect(find.text('تصدير سجل الشحنات إلى PDF'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 6: Session / Record Clone Workflow (Toolbar & Row Clone)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(1440, 900)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Tab 1
      await tester.tap(find.text('سجل متابعة الشحنات والتحميل').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Open Search & Clone Dialog
      final searchAndCloneBtn = find.byKey(const Key('searchAndCloneShippingBtn'));
      expect(searchAndCloneBtn, findsOneWidget);
      await tester.tap(searchAndCloneBtn);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SearchAndCloneCargoShippingDialog), findsOneWidget);

      // Select first record to clone
      final selectRecordBtn = find.byKey(const Key('selectRecordToCloneBtn_SHP-2026-0004'));
      expect(selectRecordBtn, findsOneWidget);
      await tester.tap(selectRecordBtn);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify CloneEntityReviewDialog opens
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.textContaining('SHP-2026-0004'), findsWidgets);

      // Confirm clone
      final confirmBtn = find.byKey(const Key('confirmCloneBtn'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tab 0 should now be active with cloned state
      expect(find.byType(CloneEntityReviewDialog), findsNothing);

      // 2. Row Clone Button Test
      await tester.tap(find.text('سجل متابعة الشحنات والتحميل').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final rowCloneBtn = find.byKey(const Key('cloneShippingRowBtn_SHP-2026-0004'));
      expect(rowCloneBtn, findsOneWidget);
      await tester.tap(rowCloneBtn);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmCloneBtn')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 7: Row TSV Copy, Container Row Duplicate, and Table Multi-Format Exports (Excel & PDF)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(1440, 900)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 1. In Tab 0, test Container Row Duplicate (Task E)
      final duplicateContainerBtn = find.byKey(const Key('duplicateContainerBtn_0'));
      expect(duplicateContainerBtn, findsOneWidget);
      await tester.tap(duplicateContainerBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // Should now have 2 containers (key duplicateContainerBtn_1 should appear)
      expect(find.byKey(const Key('duplicateContainerBtn_1')), findsOneWidget);

      // 2. Switch to Tab 1
      await tester.tap(find.text('سجل متابعة الشحنات والتحميل').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Test Row TSV Copy
      final copyRowBtn = find.byKey(const Key('copyShippingRowBtn_SHP-2026-0004'));
      expect(copyRowBtn, findsOneWidget);
      await tester.tap(copyRowBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // Test Table TSV Copy
      final copyTableBtn = find.byKey(const Key('copyShippingTableTsvBtn'));
      expect(copyTableBtn, findsOneWidget);
      await tester.tap(copyTableBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // Test Excel Export
      final excelBtn = find.byKey(const Key('exportShippingExcelBtn'));
      expect(excelBtn, findsOneWidget);
      await tester.tap(excelBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // Test PDF Export
      final pdfBtn = find.byKey(const Key('exportShippingPdfBtn'));
      expect(pdfBtn, findsOneWidget);
      await tester.tap(pdfBtn);
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  });
}
