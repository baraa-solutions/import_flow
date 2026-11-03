import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/providers/navigation_provider.dart';
import 'package:frontend/core/widgets/unified_dossier_export_menu.dart';
import 'package:frontend/features/comprehensive_report/models/comprehensive_dossier_model.dart';
import 'package:frontend/features/comprehensive_report/screens/import_file_comprehensive_report_screen.dart';
import 'package:frontend/features/comprehensive_report/services/comprehensive_dossier_service.dart';
import 'package:frontend/features/experience_guide/widgets/smart_shipment_reference_card.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/import_files/screens/import_files_screen.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';

void main() {
  final List<ImportFileModel> sampleFiles = [
    ImportFileModel(
      importFileId: 105,
      importFileCode: 'IMP-2026-0005',
      companyId: 1,
      companyName: 'SCAS For Construction And Finishing',
      supplierId: 2,
      supplierName: 'Suzhou Yuheng Textile Co.,Ltd',
      shipmentMode: 'Sea FCL',
      incotermCode: 'EXW',
      currentStage: 'P07: Customs Clearance',
      currentModule: 'P07',
      nextAction: 'تدقيق أوزان ومعاينة جمركية',
      progressPercent: 70.0,
      status: 'Under Clearance',
      createdAt: '2026-10-01T10:00:00Z',
      updatedAt: '2026-10-28T10:00:00Z',
      estimatedCost: 45000.0,
      estimatedCostCurrency: 'USD',
      hsCode: '5602290000',
      productCategory: 'PET Acoustic Panels',
      portOfLoading: 'Shanghai Port',
      portOfDischarge: 'El Dekheila Port',
      acidNumber: '5281534391023010013',
      form4No: 'FORM4-2026-99',
    ),
  ];

  final sampleDossier = ComprehensiveShipmentDossierModel(
    importFileId: 105,
    importFileCode: 'IMP-2026-0005',
    customFileNumber: 'CFN-8899',
    status: 'Under Clearance',
    currentStage: 'Customs Inspection',
    currentModule: 'P07',
    progressPercent: 70.0,
    nextAction: 'Sampling and Release',
    createdAt: '2026-10-01T10:00:00Z',
    updatedAt: '2026-10-28T10:00:00Z',
    companyName: 'SCAS For Construction And Finishing',
    supplierName: 'Suzhou Yuheng Textile Co.,Ltd',
    shipmentMode: 'Sea FCL',
    incotermCode: 'EXW',
    shipmentCategory: 'Standard Commercial',
    priority: 'High',
    totalPackages: 144,
    grossWeightKg: 10510.0,
    netWeightKg: 10080.0,
    totalCbm: 66.388,
    targetFreeDays: 21,
    purchaseOrders: const [],
    posCount: 0,
    invoicesCount: 0,
    fobByCurrency: const {},
    itemsCount: 0,
    itemsDetail: const [],
    customsDutyAmount: 0.0,
    vatAmount: 0.0,
    scheduleTaxAmount: 0.0,
    totalCustomsPaid: 0.0,
    warehouseAcceptedQty: 0,
    warehouseShortageQty: 0,
    warehouseDamagedQty: 0,
    financialSettlementInvoicesCount: 0,
    financialSettlementTotalEgp: 0.0,
    actualLandedCostTotalEgp: 0.0,
    actualLandedCostVarianceEgp: 0.0,
    actualLandedCostVariancePct: 0.0,
    sections: const [],
    closureReadiness: const {'is_ready_for_closure': false},
    containers: const [],
    timelineEvents: const [],
    etaRevisionsLog: const [],
    similarPastShipments: const [],
    recurringPatterns: const [],
    packingLists: const [],
    acidNumber: '5281534391023010013',
    form4No: 'FORM4-2026-99',
    smartReferenceCard: {
      'import_file_id': 105,
      'import_file_code': 'IMP-2026-0005',
      'product_summary': {
        'hs_code': '5602290000',
        'product_category': 'PET Acoustic Panels',
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
      'critical_dates': {
        'target_free_days': 21,
      },
      'document_status': {
        'is_complete': false,
        'acid_number': '5281534391023010013',
        'form4_no': 'FORM4-2026-99',
      },
    },
  );

  group('UI Overflow & Bidirectional Navigation Tests (Session 4.4)', () {
    testWidgets('Screen 1 (ImportFilesScreen) renders with 0 RenderFlex overflows on Desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      final testDio = Dio()..httpClientAdapter = _FakeHttpClientAdapter();
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(testDio),
          importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier(sampleFiles)),
          paginatedImportFilesProvider.overrideWith(
            (ref) => _MockPaginatedNotifier(
              PaginatedImportFilesState(
                items: sampleFiles,
                total: 1,
                page: 1,
                pageSize: 50,
                totalPages: 1,
                isLoading: false,
              ),
            ),
          ),
          purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: SizedBox(
                width: 1280,
                height: 800,
                child: ImportFilesScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure no overflows occurred during full screen layout
      expect(tester.takeException(), isNull);
      expect(find.byType(ImportFilesScreen), findsOneWidget);
    });

    testWidgets('Operations Screen to Comprehensive Report Button triggers navigation tab 47', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      final testDio = Dio()..httpClientAdapter = _FakeHttpClientAdapter();
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(testDio),
          importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier(sampleFiles)),
          paginatedImportFilesProvider.overrideWith(
            (ref) => _MockPaginatedNotifier(
              PaginatedImportFilesState(
                items: sampleFiles,
                total: 1,
                page: 1,
                pageSize: 50,
                totalPages: 1,
                isLoading: false,
              ),
            ),
          ),
          purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: SizedBox(
                width: 1280,
                height: 800,
                child: ImportFilesScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the report button for file 105
      final reportBtnFinder = find.byKey(const Key('openComprehensiveReportBtn_105'));
      expect(reportBtnFinder, findsOneWidget);

      // Scroll into view if needed and tap
      await tester.ensureVisible(reportBtnFinder);
      await tester.pumpAndSettle();

      final btnWidget = tester.widget<IconButton>(reportBtnFinder);
      if (btnWidget.onPressed != null) {
        btnWidget.onPressed!();
      } else {
        await tester.tap(reportBtnFinder);
      }
      await tester.pumpAndSettle();

      // Verify navigation updated to Tab 47 and targeted file 105
      expect(container.read(navigationIndexProvider), equals(47));
      expect(container.read(selectedComprehensiveReportFileIdProvider), equals(105));
    });

    testWidgets('Comprehensive Report back button navigates back to Operations (Tab 1)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      final testDio = Dio()..httpClientAdapter = _FakeHttpClientAdapter();
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(testDio),
          importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier(sampleFiles)),
          selectedComprehensiveReportFileIdProvider.overrideWith((ref) => 105),
          navigationIndexProvider.overrideWith((ref) => 47),
          comprehensiveDossierProvider(105).overrideWith((ref) => sampleDossier),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: SizedBox(
                width: 1280,
                height: 800,
                child: ImportFileComprehensiveReportScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Back to Operations button exists in AppBar
      final backBtn = find.byKey(const Key('backToOperationsBtn'));
      expect(backBtn, findsOneWidget);

      // Tap Back button
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // Verify navigation jumped back to Tab 1 (Operations) and targeted file 105
      expect(container.read(navigationIndexProvider), equals(1));
      expect(container.read(selectedOperationalFileIdProvider), equals(105));
    });

    testWidgets('UnifiedDossierExportMenu renders without overflow and buttons respond', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 600));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AppLocalizationsProvider(
                locale: const Locale('ar'),
                child: Column(
                  children: [
                    // Row Mode
                    UnifiedDossierExportMenu.row(
                      file: sampleFiles.first,
                      dossier: sampleDossier,
                    ),
                    const SizedBox(height: 20),
                    // Dropdown Mode
                    UnifiedDossierExportMenu(
                      file: sampleFiles.first,
                      dossier: sampleDossier,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('unifiedCopyDossierBtn')), findsOneWidget);
      expect(find.byKey(const Key('unifiedExportExcelBtn')), findsOneWidget);
      expect(find.byKey(const Key('unifiedExportPdfBtn')), findsOneWidget);
      expect(find.byKey(const Key('unifiedExportTsvBtn')), findsOneWidget);
      expect(find.byKey(const Key('unifiedExportModalBtn')), findsOneWidget);
      expect(find.byKey(const Key('unifiedExportMenuDropdown')), findsOneWidget);

      // Tap Copy Dossier button
      await tester.tap(find.byKey(const Key('unifiedCopyDossierBtn')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('SmartShipmentReferenceCard renders with 0 overflow using unified contract', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 600));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AppLocalizationsProvider(
                locale: const Locale('ar'),
                child: SingleChildScrollView(
                  child: SmartShipmentReferenceCard(
                    importFileId: 105,
                    file: sampleFiles.first,
                    dossier: sampleDossier,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('5602290000'), findsWidgets);
      expect(find.textContaining('5281534391023010013'), findsWidgets);
    });
  });
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('[]', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

class _MockImportFilesNotifier extends StateNotifier<AsyncValue<List<ImportFileModel>>>
    implements ImportFilesNotifier {
  _MockImportFilesNotifier(List<ImportFileModel> initial) : super(AsyncValue.data(initial));

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPurchaseOrdersNotifier extends StateNotifier<PurchaseOrdersState>
    implements PurchaseOrdersNotifier {
  _MockPurchaseOrdersNotifier() : super(PurchaseOrdersState());

  @override
  Future<void> fetchPurchaseOrders([int? fileId]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPaginatedNotifier extends StateNotifier<PaginatedImportFilesState>
    implements PaginatedImportFilesNotifier {
  _MockPaginatedNotifier(super.state);

  @override
  Future<void> fetchPage(int page, {String? search, String? status, int? companyId, int? supplierId, int? brokerId, String? currentStage, String? priority, String? owner}) async {}

  void setPage(int page) {}

  void setPageSize(int pageSize) {}

  @override
  void nextPage() {}

  @override
  void prevPage() {}
}
