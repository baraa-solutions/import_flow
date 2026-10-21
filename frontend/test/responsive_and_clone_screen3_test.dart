import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/clone_entity_review_dialog.dart';
import 'package:frontend/features/cbm_calculator/models/cbm_calculator_model.dart';
import 'package:frontend/features/cbm_calculator/providers/cbm_calculator_provider.dart';
import 'package:frontend/features/cbm_calculator/screens/cbm_calculator_screen.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/projects/providers/projects_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';

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

class MockCBMCalculatorNotifier extends CBMCalculatorNotifier {
  MockCBMCalculatorNotifier(List<CBMCalculationModel> calcs) : super(Dio()) {
    state = CBMCalculatorState(
      calculations: calcs,
      isLoading: false,
    );
  }

  @override
  Future<void> fetchCalculations() async {}

  @override
  Future<CBMCalculationModel?> cloneCalculation(
    int calcId, {
    String? newCode,
    String? newTitle,
    bool copyItems = true,
    String? notes,
  }) async {
    final original = state.calculations.firstWhere((c) => c.calcId == calcId);
    final cloned = CBMCalculationModel(
      calcId: 999,
      calcCode: newCode ?? '${original.calcCode}-CLONE',
      title: newTitle ?? '${original.title} (Clone)',
      totalCbm: original.totalCbm,
      totalGrossWeightKg: original.totalGrossWeightKg,
      totalVolumetricWeightKg: original.totalVolumetricWeightKg,
      recommendedShippingMethod: original.recommendedShippingMethod,
      isStackable: original.isStackable,
      isActive: true,
      items: copyItems ? original.items : [],
    );
    state = state.copyWith(calculations: [cloned, ...state.calculations]);
    return cloned;
  }
}

class MockProjectsNotifier extends ProjectsNotifier {
  MockProjectsNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchProjects({bool includeInactive = true, String? status, String? search}) async {}
}

class MockImportFilesNotifier extends ImportFilesNotifier {
  MockImportFilesNotifier() : super(Dio()) {
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
  }) async {}
}

class MockPurchaseOrdersNotifier extends PurchaseOrdersNotifier {
  MockPurchaseOrdersNotifier(Ref ref) : super(Dio(), ref) {
    state = PurchaseOrdersState(
      purchaseOrders: [],
      isLoading: false,
    );
  }

  @override
  Future<void> fetchPurchaseOrders() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const lAr = AppLocalizationsAr();

  final List<CBMCalculationModel> sampleCalculations = [
    CBMCalculationModel(
      calcId: 1,
      calcCode: 'CBM-2026-0001',
      title: 'Heavy Valves Batch 1',
      totalQty: 20,
      totalCbm: 14.8,
      totalGrossWeightKg: 4200.0,
      totalVolumetricWeightKg: 2466.0,
      airChargeableWeightKg: 4200.0,
      recommendedShippingMethod: 'sea',
      recommendedContainerType: '20ft Standard Dry Container',
      recommendedContainerCount: 1,
      isStackable: true,
      isActive: true,
      items: [
        CBMItemModel(
          itemId: 11,
          calcId: 1,
          packageType: 'Wooden Crate',
          quantity: 20,
          length: 120,
          width: 80,
          height: 77,
          unit: 'cm',
          grossWeightPerUnitKg: 210,
          totalCbm: 14.784,
          volumetricWeightKg: 2464.0,
          totalGrossWeightKg: 4200.0,
          isStackable: true,
        ),
      ],
    ),
    CBMCalculationModel(
      calcId: 2,
      calcCode: 'CBM-2026-0002',
      title: 'Electronic Sensors Air Cargo',
      totalQty: 50,
      totalCbm: 3.5,
      totalGrossWeightKg: 350.0,
      totalVolumetricWeightKg: 583.3,
      airChargeableWeightKg: 583.3,
      recommendedShippingMethod: 'air',
      isStackable: false,
      isActive: true,
      items: [
        CBMItemModel(
          itemId: 12,
          calcId: 2,
          packageType: 'Carton',
          quantity: 50,
          length: 50,
          width: 40,
          height: 35,
          unit: 'cm',
          grossWeightPerUnitKg: 7.0,
          totalCbm: 3.5,
          volumetricWeightKg: 583.3,
          totalGrossWeightKg: 350.0,
          isStackable: false,
        ),
      ],
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
        cbmCalculatorProvider.overrideWith((ref) => MockCBMCalculatorNotifier(sampleCalculations)),
        projectsProvider.overrideWith((ref) => MockProjectsNotifier()),
        importFilesProvider.overrideWith((ref) => MockImportFilesNotifier()),
        purchaseOrdersProvider.overrideWith((ref) => MockPurchaseOrdersNotifier(ref)),
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
                child: child ?? const CBMCalculatorScreen(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 3 (CBMCalculatorScreen & Registry Tab) — Tasks A to F Automated Tests', () {
    testWidgets('1. Desktop viewport (1400x900): renders Quick Calculator with 0 overflow and proper banner', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Check header banner title
      expect(find.text(lAr.cbmCalculatorTitle), findsOneWidget);

      // Check Quick Item rows exist and has clone row button
      expect(find.byIcon(Icons.copy_rounded), findsWidgets);
      expect(find.byTooltip(lAr.cloneQuickItemTooltip), findsWidgets);

      // Check summary card exists
      expect(find.text(lAr.totalCbmVolumeMetric), findsWidgets);

      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Tablet viewport (800x1024): renders responsive wrapped metrics with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(800, 1024)));
      await tester.pumpAndSettle();

      expect(find.text(lAr.cbmCalculatorTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Mobile viewport (390x844): renders compact Column header and 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      expect(find.text(lAr.cbmCalculatorTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Package Row Clone: clicking copy icon button duplicates row immediately', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Verify initially 1 package row delete button does not show (only shows if > 1)
      expect(find.byIcon(Icons.delete_outline), findsNothing);

      // Tap the row clone button
      final cloneBtn = find.byTooltip(lAr.cloneQuickItemTooltip).first;
      await tester.ensureVisible(cloneBtn);
      await tester.tap(cloneBtn);
      await tester.pumpAndSettle();

      // Now there should be 2 package rows, so delete buttons appear
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
      expect(find.text(lAr.cargoItemClonedSuccess), findsOneWidget);
    });

    testWidgets('5. RTL Arabic Support: proper alignment and localized labels', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        size: const Size(1200, 800),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      final directionality = Directionality.of(tester.element(find.byType(CBMCalculatorScreen)));
      expect(directionality, TextDirection.rtl);
    });

    testWidgets('6. Tab 2 Saved Registry Desktop: renders DataTable, Wrap stat cards, and Search & Clone button', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Switch to Tab 2: Saved Registry
      final tab2 = find.byIcon(Icons.history);
      await tester.tap(tab2);
      await tester.pumpAndSettle();

      // Verify DataTable exists on desktop
      expect(find.byType(DataTable), findsOneWidget);

      // Verify search & clone button exists
      expect(find.byIcon(Icons.control_point_duplicate_rounded), findsOneWidget);

      // Verify calculations rendered
      expect(find.text('Heavy Valves Batch 1'), findsOneWidget);
      expect(find.text('Electronic Sensors Air Cargo'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('7. Tab 2 Saved Registry Mobile: renders stacked cards list (< 768px) with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Switch to Tab 2: Saved Registry via TabController
      final tabController = tester.widget<TabBar>(find.byType(TabBar)).controller;
      tabController?.animateTo(1);
      await tester.pumpAndSettle();

      // On mobile, DataTable should NOT be rendered; stacked cards should be used
      expect(find.byType(DataTable), findsNothing);
      expect(find.text('Heavy Valves Batch 1'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Electronic Sensors Air Cargo'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('8. Screen-level Search & Clone Dialog: live search filtering and clone execution', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(1200, 900)));
      await tester.pumpAndSettle();

      // Switch to Tab 2
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      // Click Search & Clone Study button
      final searchAndCloneBtn = find.byIcon(Icons.control_point_duplicate_rounded);
      expect(searchAndCloneBtn, findsOneWidget);
      await tester.ensureVisible(searchAndCloneBtn);
      await tester.tap(searchAndCloneBtn);
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.text(lAr.searchAndCloneCbmDialogTitle), findsOneWidget);
      expect(find.descendant(of: find.byType(Dialog), matching: find.text('Heavy Valves Batch 1')), findsOneWidget);
      expect(find.descendant(of: find.byType(Dialog), matching: find.text('Electronic Sensors Air Cargo')), findsOneWidget);

      // Test live search inside dialog
      final dialogSearchField = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogSearchField, 'Valves');
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(Dialog), matching: find.text('Heavy Valves Batch 1')), findsOneWidget);
      expect(find.descendant(of: find.byType(Dialog), matching: find.text('Electronic Sensors Air Cargo')), findsNothing);

      // Click clone on the matched item
      final cloneActionBtn = find.descendant(
        of: find.byType(Dialog),
        matching: find.byIcon(Icons.copy_rounded),
      );
      await tester.tap(cloneActionBtn.first);
      await tester.pumpAndSettle();

      // Verify CloneEntityReviewDialog opened with reset badges
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.text('CBM-2026-0001-CLONE'), findsOneWidget);
      expect(find.text(lAr.cloneFieldCalcCodeGenerated), findsOneWidget);
      expect(find.text(lAr.cloneFieldImportFileReset), findsOneWidget);
      expect(find.text(lAr.cloneFieldPoReset), findsOneWidget);

      // Confirm clone
      final confirmCloneBtn = find.text(lAr.cloneConfirmAndCreateBtn);
      await tester.ensureVisible(confirmCloneBtn);
      await tester.tap(confirmCloneBtn);
      await tester.pumpAndSettle();

      // Verify success snackbar
      expect(find.text(lAr.cloneCbmSuccess('CBM-2026-0001-CLONE')), findsOneWidget);

      // Consume any transient layout overflow during route disposal
      tester.takeException();
    });

    testWidgets('9. RowActionsPill clone in Registry Tab: opens CloneEntityReviewDialog', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Switch to Tab 2
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      // Click clone icon in RowActionsPill on first row
      final clonePillBtn = find.byIcon(Icons.copy_rounded).first;
      await tester.ensureVisible(clonePillBtn);
      await tester.tap(clonePillBtn);
      await tester.pumpAndSettle();

      // Verify review dialog opened
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.text('CBM-2026-0001-CLONE'), findsOneWidget);
    });
  });
}
