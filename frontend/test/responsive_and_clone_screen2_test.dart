import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/clone_entity_review_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart' show ImportFileModel;
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/projects/models/project_model.dart';
import 'package:frontend/features/projects/providers/projects_provider.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/purchase_orders/screens/purchase_orders_screen.dart';
import 'package:frontend/features/purchase_orders/widgets/po_form_dialog.dart';

class _MockHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode([]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _createTestDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:28080/api/v1'));
  dio.httpClientAdapter = _MockHttpAdapter();
  return dio;
}

class MockPurchaseOrdersNotifier extends PurchaseOrdersNotifier {
  MockPurchaseOrdersNotifier(Ref ref, List<PurchaseOrderModel> orders) : super(Dio(), ref) {
    state = PurchaseOrdersState(
      purchaseOrders: orders,
      isLoading: false,
    );
  }

  @override
  Future<void> fetchPurchaseOrders() async {}

  @override
  Future<PurchaseOrderModel?> clonePurchaseOrder(int poId, Map<String, dynamic> payload) async {
    return null;
  }
}

class MockProjectsNotifier extends ProjectsNotifier {
  MockProjectsNotifier(List<ProjectModel> projects) : super(Dio()) {
    state = AsyncValue.data(projects);
  }

  @override
  Future<void> fetchProjects({bool includeInactive = true, String? status, String? search}) async {}
}

class MockImportFilesNotifier extends ImportFilesNotifier {
  MockImportFilesNotifier(List<ImportFileModel> files) : super(Dio()) {
    state = AsyncValue.data(files);
  }

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<PurchaseOrderModel> sampleOrders = [
    PurchaseOrderModel(
      poId: 1,
      poNumber: 'PO-2026-0001',
      poReference: 'Industrial Valves Lot A',
      companyId: 10,
      companyName: 'Sorour Logistics Cairo',
      supplierId: 20,
      supplierName: 'Hamburg Industrial Tools Co.',
      projectId: 1,
      projectName: 'Main Pipeline Project',
      incotermId: 1,
      currencyId: 1,
      status: 'Approved',
      totalAmountFob: 54000.0,
      totalCbm: 12.5,
      totalGrossWeightKg: 3400.0,
      currencyCode: 'USD',
      countryOfOrigin: 'DE - ألمانيا (Germany)',
      orderDate: DateTime(2026, 9, 1),
      items: [
        POLineItemModel(
          itemId: 101,
          descriptionAr: 'صمام صناعي عالي الضغط',
          quantity: 50,
          unitPrice: 1080.0,
        ),
      ],
      packingListItems: [
        PackingListItemModel(
          packingItemId: 201,
          hsCode: '8481.80',
          itemCode: 'VALVE-HD-50',
          qtyPkg: 10,
          qtyPcs: 50,
          packageType: 'Carton',
          lengthCm: 60,
          widthCm: 40,
          heightCm: 50,
          netWeightUnitKg: 65,
          grossWeightUnitKg: 68,
        ),
      ],
    ),
    PurchaseOrderModel(
      poId: 2,
      poNumber: 'PO-2026-0002',
      poReference: 'Electrical Switchboards',
      companyId: 11,
      companyName: 'Nile Delta Trading',
      supplierId: 21,
      supplierName: 'Shanghai Electric Ltd',
      projectId: 2,
      projectName: 'Smart Grid 2026',
      incotermId: 1,
      currencyId: 1,
      status: 'Draft',
      totalAmountFob: 28000.0,
      totalCbm: 8.2,
      totalGrossWeightKg: 1950.0,
      currencyCode: 'USD',
      countryOfOrigin: 'CN - الصين (China)',
      orderDate: DateTime(2026, 9, 5),
      items: [],
      packingListItems: [],
    ),
  ];

  final List<ProjectModel> sampleProjects = [
    ProjectModel(
      projectId: 1,
      projectCode: 'PRJ-001',
      projectName: 'Main Pipeline Project',
      projectOwner: 'Eng. Ahmed',
      companyId: 10,
      supplierId: 20,
      incotermId: 1,
    ),
    ProjectModel(
      projectId: 2,
      projectCode: 'PRJ-002',
      projectName: 'Smart Grid 2026',
      projectOwner: 'Eng. Mohamed',
      companyId: 11,
      supplierId: 21,
      incotermId: 1,
    ),
  ];

  Widget createTestWidget({
    required Size size,
    Locale locale = const Locale('ar'),
    ThemeMode themeMode = ThemeMode.dark,
    Widget? child,
  }) {
    final textDir = locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;
    final testDio = _createTestDio();

    return ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(testDio),
        localeProvider.overrideWith((ref) {
          final n = LocaleNotifier();
          n.setLocale(locale);
          return n;
        }),
        purchaseOrdersProvider.overrideWith((ref) => MockPurchaseOrdersNotifier(ref, sampleOrders)),
        projectsProvider.overrideWith((ref) => MockProjectsNotifier(sampleProjects)),
        importFilesProvider.overrideWith((ref) => MockImportFilesNotifier([])),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        locale: locale,
        home: AppLocalizationsProvider(
          locale: locale,
          child: Directionality(
            textDirection: textDir,
            child: MediaQuery(
              data: MediaQueryData(size: size),
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: child ?? const PurchaseOrdersScreen(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 2 (PurchaseOrdersScreen) — Tasks A to F Automated Tests', () {
    testWidgets('1. Desktop viewport (1400x900): renders full table, metrics, and clone button with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Verify header title and search & clone button
      expect(find.text('Industrial Valves Lot A'), findsOneWidget);
      expect(find.byIcon(Icons.control_point_duplicate_rounded), findsWidgets);

      // Verify summary metrics exist
      expect(find.byIcon(Icons.receipt_long), findsWidgets);
      expect(find.byIcon(Icons.attach_money), findsWidgets);

      // Verify DataTable rendered on desktop with persistent scrollbars
      // Unified EnterpriseDataTable
      expect(find.byType(DataTable), findsWidgets);
      expect(find.byType(Scrollbar), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Tablet viewport (800x1024): renders responsive wrapped metrics & table with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(800, 1024)));
      await tester.pumpAndSettle();

      expect(find.text('Industrial Valves Lot A'), findsOneWidget);
      // Unified EnterpriseDataTable
      expect(find.byType(DataTable), findsWidgets);
      expect(find.byType(Scrollbar), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Mobile viewport (390x844): renders stacked cards list and compact header with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      // On mobile (< 768px), DataTable should be replaced by stacked cards
      expect(find.byType(DataTable), findsNothing);
      expect(find.text('Industrial Valves Lot A'), findsOneWidget);
      expect(find.text('Electrical Switchboards'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('4. RTL Arabic support: proper alignment and localized labels', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        size: const Size(1200, 800),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      final directionality = Directionality.of(tester.element(find.byType(PurchaseOrdersScreen)));
      expect(directionality, TextDirection.rtl);
      expect(find.text('بحث واستنساخ أمر شراء'), findsOneWidget);
    });

    testWidgets('5. Screen-level clone: clicking Search & Clone button opens dialog and filters live', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(1200, 800)));
      await tester.pumpAndSettle();

      // Click Search & Clone button in header
      final cloneBtn = find.text('بحث واستنساخ أمر شراء');
      expect(cloneBtn, findsOneWidget);
      await tester.tap(cloneBtn);
      await tester.pumpAndSettle();

      
// Verify search & clone dialog is opened
      expect(find.text('اختر أمر الشراء المراد استنساخه مع تصفير الشحنات والتخصيصات'), findsOneWidget);

      // Verify both POs are listed in dialog
      expect(find.descendant(of: find.byType(Dialog), matching: find.text('Industrial Valves Lot A')), findsOneWidget);
      expect(find.descendant(of: find.byType(Dialog), matching: find.text('Electrical Switchboards')), findsOneWidget);

      // Test live filter in search dialog
      final searchField = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(searchField, 'Valves');
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(Dialog), matching: find.text('Industrial Valves Lot A')), findsOneWidget);
      expect(find.descendant(of: find.byType(Dialog), matching: find.text('Electrical Switchboards')), findsNothing);

      // Tap Clone button on the matched PO in dialog
      final dialogCloneBtn = find.descendant(
        of: find.byType(Dialog),
        matching: find.text('استنساخ'),
      );
      expect(dialogCloneBtn, findsOneWidget);
      await tester.tap(dialogCloneBtn);
      await tester.pumpAndSettle();

      // Verify CloneEntityReviewDialog appears with reset badges
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.text('PO-2026-0001-COPY'), findsOneWidget);
      expect(find.text('الحالة: تعود تلقائياً إلى مسودة'), findsOneWidget);
      expect(find.text('فك الارتباط بملف الاستيراد السابق'), findsOneWidget);
      expect(find.text('تصفير تخصيصات الشحن الجزئي'), findsOneWidget);
    });

    testWidgets('6. Table row-level clone: clicking clone on row pill opens review dialog', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(400, 900)));
      await tester.pumpAndSettle();

      // On mobile card, RowActionsPill has the clone button
      final rowCloneBtn = find.byIcon(Icons.copy_rounded);
      expect(rowCloneBtn, findsWidgets);

      await tester.ensureVisible(rowCloneBtn.first);
      await tester.tap(rowCloneBtn.first);
      await tester.pumpAndSettle();

      // Verify CloneEntityReviewDialog opened directly for row
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.text('PO-2026-0001-COPY'), findsOneWidget);
    });

    testWidgets('7. POFormDialog item row-level clone: duplicates line item and packing item', (tester) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          size: const Size(1400, 1600),
          child: Scaffold(
            body: POFormDialog(po: sampleOrders.first),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify clone button for line items exists
      final cloneLineItemBtn = find.byWidgetPredicate(
        (w) => w is IconButton && (w.tooltip?.contains('استنساخ') == true || w.tooltip?.contains('Clone') == true),
      );
      expect(cloneLineItemBtn, findsWidgets);

      // Ensure visible and tap to duplicate line item
      await tester.ensureVisible(cloneLineItemBtn.first);
      await tester.tap(cloneLineItemBtn.first, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify duplicated line item was added with clone suffix
      final clonedFields = tester.widgetList<TextFormField>(
        find.byWidgetPredicate((w) => w is TextFormField && w.initialValue != null && (w.initialValue!.contains('(نسخة)') || w.initialValue!.contains('(Copy)'))),
      );
      expect(clonedFields, isNotEmpty);
    });
  });
}
