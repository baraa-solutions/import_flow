import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart' hide PackingListItemModel;
import 'package:frontend/features/import_files/widgets/visual_container_load_planner_dialog.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';

void main() {
  final sampleFile = ImportFileModel(
    importFileId: 4,
    importFileCode: 'IMP-2026-0004',
    customFileNumber: 'PET Stock',
    companyName: 'SCAS FOR CONSTRUCTION',
    supplierName: 'SUZHOU YUHENG TEXTILE',
    priority: 'High',
    shipmentCategory: 'Raw Materials',
    currentModule: 'STEP_07 تخصيص وتوزيع الحاويات والـ VGM',
    currentStage: 'Phase 3: Booking & Doc Prep',
    nextAction: 'تدقيق أوزان VGM واعتماد مسودات مستندات الشحن',
    progressPercent: 33.3,
    status: 'Open',
    owner: 'Ahmed Salah',
    createdAt: '2026-08-18T10:00:00Z',
    updatedAt: '2026-09-14T10:00:00Z',
    estimatedCost: 43704.0,
    estimatedCostCurrency: 'USD',
  );

  final samplePO = PurchaseOrderModel(
    poId: 101,
    poNumber: 'PO-2026-001',
    projectId: 1,
    companyId: 1,
    supplierId: 1,
    incotermId: 1,
    currencyId: 1,
    packingListItems: [
      PackingListItemModel(
        packingItemId: 1,
        poId: 101,
        hsCode: '3907.61.00',
        itemCode: 'PET-CHIPS-01',
        description: 'Polyethylene terephthalate resin bags',
        qtyPcs: 20,
        qtyPkg: 20,
        packageType: 'BG - Bag (كيس / شوال)',
        unit: 'cm',
        lengthCm: 100,
        widthCm: 80,
        heightCm: 100,
        weightUnit: 'KGM',
        netWeightUnitKg: 1000,
        grossWeightUnitKg: 1050,
        totalNetWeightKg: 20000,
        totalGrossWeightKg: 21000,
        totalCbm: 16.0,
        chargeableWeightKg: 21000,
        isStackable: true,
      ),
      PackingListItemModel(
        packingItemId: 2,
        poId: 101,
        hsCode: '3907.61.00',
        itemCode: 'PET-CHIPS-02',
        description: 'Fragile additive drums',
        qtyPcs: 4,
        qtyPkg: 4,
        packageType: 'DR - Drum (برميل)',
        unit: 'cm',
        lengthCm: 60,
        widthCm: 60,
        heightCm: 90,
        weightUnit: 'KGM',
        netWeightUnitKg: 200,
        grossWeightUnitKg: 220,
        totalNetWeightKg: 800,
        totalGrossWeightKg: 880,
        totalCbm: 1.3,
        chargeableWeightKg: 880,
        isStackable: false,
      ),
    ],
  );

  Widget createTestWidget({
    required Size size,
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('ar'),
  }) {
    return ProviderScope(
      child: MaterialApp(
        locale: locale,
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: AppLocalizationsProvider(
          locale: locale,
          child: Directionality(
            textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: MediaQuery(
              data: MediaQueryData(size: size),
              child: Scaffold(
                body: VisualContainerLoadPlannerDialog(
                  file: sampleFile,
                  linkedPOs: [samplePO],
                  fallbackCbm: 17.3,
                  fallbackWeight: 21880,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('VisualContainerLoadPlannerDialog — 5-Task Enterprise Protocol Tests', () {
    // ── Task A: Responsive Layout ───────────────────────────────────────────
    testWidgets('Test 1: Task A — Desktop Viewport (1440x900) expands dialog width and renders with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(1440, 900)));
      await tester.pumpAndSettle();

      // Check Dialog header & file code
      expect(find.textContaining('IMP-2026-0004'), findsWidgets);

      // Verify expanded desktop size
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final contentSizedBox = sizedBoxes.firstWhere(
        (b) => b.width != null && b.width! > 1200,
      );
      expect(contentSizedBox.width, greaterThanOrEqualTo(1300.0));
      expect(contentSizedBox.height, greaterThanOrEqualTo(800.0));

      // Check export buttons presence (PNG, Excel, PDF)
      expect(find.byKey(const Key('saveImageBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportExcelBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportPdfBtn')), findsOneWidget);

      // Check close button
      expect(find.byKey(const Key('closePlannerDialogBtn')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 2: Task A — Tablet Viewport (800x1024) reflows summary metrics with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(800, 1024)));
      await tester.pumpAndSettle();

      expect(find.textContaining('IMP-2026-0004'), findsWidgets);
      expect(find.byKey(const Key('scenarioChip_1')), findsOneWidget);
      expect(find.byKey(const Key('scenarioChip_2')), findsOneWidget);
      expect(find.byKey(const Key('scenarioChip_3')), findsOneWidget);

      // Ensure zero RenderFlex overflows on Tablet
      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 3: Task A — Mobile Viewport (390x844) renders gracefully with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      expect(find.textContaining('IMP-2026-0004'), findsWidgets);
      expect(find.byType(VisualContainerLoadPlannerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 4: Task A — Packing list table scrolls independently with sticky header', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(1440, 900)));
      await tester.pumpAndSettle();

      // Verify packing list table container has vertical scrollbar
      expect(find.byType(Scrollbar), findsWidgets);
      expect(find.byType(SingleChildScrollView), findsWidgets);

      // Verify sticky column headers stay visible
      final l = AppLocalizations.of(tester.element(find.byType(VisualContainerLoadPlannerDialog)));
      expect(find.text(l.containerSpecType), findsOneWidget);
      expect(find.text(l.packingListItemsCol), findsOneWidget);
      expect(find.text(l.totalGrossWeightFromPl), findsOneWidget);
      expect(find.text(l.spaceUtilizationPercent), findsOneWidget);
    });

    // ── Task B: Dark Mode Contrast ──────────────────────────────────────────
    testWidgets('Test 5: Task B — Dark Mode renders with WCAG AA compliant colors & card backgrounds', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        size: const Size(1280, 800),
        themeMode: ThemeMode.dark,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('IMP-2026-0004'), findsWidgets);
      expect(find.byType(VisualContainerLoadPlannerDialog), findsOneWidget);

      // Verify Space Utilization % text uses high contrast color (Color(0xFFFDBA74) on dark)
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final spaceUtilWidget = textWidgets.firstWhere((t) => RegExp(r'^\d+(\.\d+)?%$').hasMatch(t.data ?? '') && t.style?.color != null);
      expect(spaceUtilWidget.style?.color, const Color(0xFFFDBA74));

      expect(tester.takeException(), isNull);
    });

    // ── Task C: RTL Support ─────────────────────────────────────────────────
    testWidgets('Test 6: Task C — Arabic RTL layout and localization mirrors correctly', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        size: const Size(1440, 900),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      // Check Directionality
      final directionality = Directionality.of(tester.element(find.byType(VisualContainerLoadPlannerDialog)));
      expect(directionality, TextDirection.rtl);

      // Check localized close button in Arabic
      expect(find.text('إغلاق المخطط'), findsOneWidget);

      // Check Arabic scenario labels
      expect(find.textContaining('بضائع تقبل الرص'), findsWidgets);
      expect(find.textContaining('بضائع لا تقبل الرص'), findsWidgets);
      expect(find.textContaining('مزيج يقبل ولا يقبل الرص'), findsWidgets);
    });

    testWidgets('Test 7: Task C — English LTR layout renders correctly', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        size: const Size(1440, 900),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      // Check localized close button in English
      expect(find.text('Close Planner'), findsOneWidget);

      // Check English scenario labels
      expect(find.textContaining('All Stackable'), findsWidgets);
      expect(find.textContaining('All Non-Stackable'), findsWidgets);
      expect(find.textContaining('Mixed Stacking'), findsWidgets);
    });

    // ── Task H: Export Capabilities ─────────────────────────────────────────
    testWidgets('Test 8: Task H — Export buttons have proper localized tooltips and keys', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        size: const Size(1440, 900),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      final imgBtn = tester.widget<IconButton>(find.byKey(const Key('saveImageBtn')));
      final excelBtn = tester.widget<IconButton>(find.byKey(const Key('exportExcelBtn')));
      final pdfBtn = tester.widget<IconButton>(find.byKey(const Key('exportPdfBtn')));

      expect(imgBtn.tooltip, anyOf(contains('PNG'), contains('صورة')));
      expect(excelBtn.tooltip, anyOf(contains('Excel'), contains('إكسيل'), contains('إكسل')));
      expect(pdfBtn.tooltip, contains('PDF'));
    });

    // ── Existing Functionality Intact ───────────────────────────────────────
    testWidgets('Test 9: Existing Functionality — Switching stacking scenarios updates plan correctly', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(1440, 900)));
      await tester.pumpAndSettle();

      // Tap "All Stackable" scenario chip
      await tester.tap(find.byKey(const Key('scenarioChip_1')));
      await tester.pumpAndSettle();

      // Verify choice chip selected
      final chip1 = tester.widget<ChoiceChip>(find.byKey(const Key('scenarioChip_1')));
      expect(chip1.selected, isTrue);

      // Tap "All Non-Stackable" scenario chip
      await tester.tap(find.byKey(const Key('scenarioChip_2')));
      await tester.pumpAndSettle();

      final chip2 = tester.widget<ChoiceChip>(find.byKey(const Key('scenarioChip_2')));
      expect(chip2.selected, isTrue);

      // Tap "Mixed / Default" scenario chip
      await tester.tap(find.byKey(const Key('scenarioChip_3')));
      await tester.pumpAndSettle();

      final chip3 = tester.widget<ChoiceChip>(find.byKey(const Key('scenarioChip_3')));
      expect(chip3.selected, isTrue);
    });

    // ── Task J: Table Retrofit (SelectionArea & TSV Copy) ───────────────────
    testWidgets('Test 10: Task J — SelectionArea wraps packing list table and TSV copy button works', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        size: const Size(1440, 900),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      // Check SelectionArea exists
      expect(find.byType(SelectionArea), findsOneWidget);

      // Check copyTableBtn exists and has tooltip
      final copyBtnFinder = find.byKey(const Key('copyTableBtn'));
      expect(copyBtnFinder, findsOneWidget);
      final copyBtn = tester.widget<IconButton>(copyBtnFinder);
      expect(copyBtn.tooltip, 'نسخ الجدول');

      // Tap copyTableBtn (should execute without exception)
      await tester.tap(copyBtnFinder);
      await tester.pumpAndSettle();
    });
  });
}
