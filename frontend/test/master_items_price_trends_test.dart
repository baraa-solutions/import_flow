import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/financial_settlement/models/financial_settlement_model.dart';
import 'package:frontend/features/financial_settlement/providers/financial_settlement_provider.dart';
import 'package:frontend/features/master_items/models/item_price_history_model.dart';
import 'package:frontend/features/master_items/models/item_price_trends_model.dart';
import 'package:frontend/features/master_items/models/item_supplier_catalog_model.dart';
import 'package:frontend/features/master_items/models/master_item_model.dart';
import 'package:frontend/features/master_items/providers/item_price_trends_provider.dart';
import 'package:frontend/features/master_items/providers/master_items_provider.dart';
import 'package:frontend/features/master_items/screens/item_price_trends_screen.dart';
import 'package:frontend/features/master_items/widgets/deal_breakdown_drawer.dart';
import 'package:frontend/features/master_items/widgets/price_history_timeline_table.dart';
import 'package:frontend/features/master_items/widgets/price_trends_kpi_cards.dart';
import 'package:frontend/features/master_items/widgets/supplier_comparison_radar_card.dart';

void main() {
  const testItem = MasterItemModel(
    itemId: 101,
    itemCode: 'ITEM-VALVE-001',
    descriptionAr: 'صمام أمان صناعي 2 بوصة',
    descriptionEn: 'Industrial Safety Valve 2 inch',
    tariffId: 12,
    hsCode: '848180',
    defaultUom: 'PCS',
    defaultPkgType: 'Carton',
    cbmPerUnit: 0.05,
    grossWeightKg: 12.5,
    lastCustomsDutyPct: 5.0,
    lastVatPct: 14.0,
  );

  final testHistory = [
    const ItemPriceHistoryModel(
      historyId: 1,
      itemId: 101,
      supplierId: 10,
      supplierName: 'Wenzhou Valve Co.',
      poId: 501,
      poNumber: 'PO-2026-001',
      importFileId: 301,
      importFileCode: 'IMP-2026-010',
      unitPriceFx: 12.50,
      currency: 'USD',
      exchangeRate: 50.0,
      unitPriceEgp: 625.0,
      landedCostEgp: 865.0,
      landedCostMarkup: 38.4,
      quantity: 500,
      poDate: '2026-01-15',
    ),
    const ItemPriceHistoryModel(
      historyId: 2,
      itemId: 101,
      supplierId: 11,
      supplierName: 'Shanghai Flow Dynamics',
      poId: 502,
      poNumber: 'PO-2026-002',
      importFileId: 302,
      importFileCode: 'IMP-2026-020',
      unitPriceFx: 13.80,
      currency: 'USD',
      exchangeRate: 50.0,
      unitPriceEgp: 690.0,
      landedCostEgp: 950.0,
      landedCostMarkup: 37.6,
      quantity: 400,
      poDate: '2026-04-10',
    ),
    const ItemPriceHistoryModel(
      historyId: 3,
      itemId: 101,
      supplierId: 10,
      supplierName: 'Wenzhou Valve Co.',
      poId: 503,
      poNumber: 'PO-2026-003',
      importFileId: 303,
      importFileCode: 'IMP-2026-030',
      unitPriceFx: 12.00,
      currency: 'USD',
      exchangeRate: 50.0,
      unitPriceEgp: 600.0,
      landedCostEgp: 830.0,
      landedCostMarkup: 38.3,
      quantity: 600,
      poDate: '2026-08-20',
    ),
  ];

  final testTrends = ItemPriceTrendsModel(
    itemId: 101,
    itemCode: 'ITEM-VALVE-001',
    descriptionAr: 'صمام أمان صناعي 2 بوصة',
    totalPurchasesCount: 3,
    averageUnitPriceFx: 12.766,
    minUnitPriceFx: 12.00,
    maxUnitPriceFx: 13.80,
    averageLandedCostEgp: 881.67,
    averageMarkupPercent: 38.1,
    history: testHistory,
  );

  final testSuppliers = [
    const ItemSupplierCatalogModel(
      catalogId: 1,
      itemId: 101,
      supplierId: 10,
      supplierName: 'Wenzhou Valve Co.',
      supplierItemCode: 'WZ-V2-001',
      lastConfirmedPrice: 12.00,
      lastConfirmedCurrency: 'USD',
      preferredIncoterm: 'FOB',
      leadTimeDays: 25,
      minOrderQty: 200,
      isPreferredSupplier: true,
    ),
    const ItemSupplierCatalogModel(
      catalogId: 2,
      itemId: 101,
      supplierId: 11,
      supplierName: 'Shanghai Flow Dynamics',
      supplierItemCode: 'SH-FD-200',
      lastConfirmedPrice: 13.50,
      lastConfirmedCurrency: 'USD',
      preferredIncoterm: 'CIF',
      leadTimeDays: 35,
      minOrderQty: 100,
      isPreferredSupplier: false,
    ),
  ];

  Widget createTestWidget(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            child: child,
          ),
        ),
      ),
    );
  }

  group('Session 3: Price Trends Radar & Deal Comparison Components', () {
    testWidgets('1. PriceTrendsKpiCards renders 4 executive KPI metrics',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestWidget(
          PriceTrendsKpiCards(trends: testTrends, item: testItem),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Cards exist
      expect(find.text('أقل سعر شراء'), findsOneWidget);
      expect(find.text('أعلى سعر شراء'), findsOneWidget);
      expect(find.text('متوسط معامل الإضافة'), findsOneWidget);
      expect(find.text('مؤشر استقرار السعر'), findsOneWidget);

      // Verify formatted values
      expect(find.text('12.00 USD'), findsOneWidget); // min price
      expect(find.text('13.80 USD'), findsOneWidget); // max price
      expect(find.textContaining('38.1%'), findsOneWidget); // markup
      expect(find.text('86% استقرار'), findsOneWidget);
    });

    testWidgets('2. PriceHistoryTimelineTable renders historical deals accurately',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      ItemPriceHistoryModel? inspectedDeal;

      await tester.pumpWidget(
        createTestWidget(
          PriceHistoryTimelineTable(
            trends: testTrends,
            onInspectBreakdown: (deal) => inspectedDeal = deal,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check table header
      expect(find.text('سجل الصفقات التاريخية وتكلفة الوصول الفعلية'), findsOneWidget);
      expect(find.text('3 صفقات مسجلة'), findsOneWidget);
      expect(find.text('نسخ جدول البيانات'), findsOneWidget);

      // Check rows rendered
      expect(find.text('PO-2026-001'), findsOneWidget);
      expect(find.text('PO-2026-002'), findsOneWidget);
      expect(find.text('PO-2026-003'), findsOneWidget);
      expect(find.text('IMP-2026-010'), findsOneWidget);

      // Verify breakdown inspection trigger
      final breakdownIcons = find.byIcon(Icons.pie_chart_outline_rounded);
      expect(breakdownIcons, findsNWidgets(3));

      // Scroll horizontally to bring the action icon into hit-test area
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(-600, 0));
      await tester.pumpAndSettle();

      await tester.tap(breakdownIcons.first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(inspectedDeal, isNotNull);
      expect(inspectedDeal!.poNumber, equals('PO-2026-001'));
    });

    testWidgets('3. SupplierComparisonRadarCard benchmarks multiple suppliers',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestWidget(
          const SupplierComparisonRadarCard(item: testItem),
          overrides: [
            itemSuppliersProvider(101).overrideWith((ref) => Future.value(testSuppliers)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('مقارنة أسعار الموردين وعروض الشراء المعتمدة'), findsOneWidget);

      // Check suppliers rendered
      expect(find.text('Wenzhou Valve Co.'), findsOneWidget);
      expect(find.text('Shanghai Flow Dynamics'), findsOneWidget);
      expect(find.text('مفضل'), findsOneWidget);
      expect(find.text('أفضل سعر'), findsOneWidget);

      // Check savings banner
      expect(find.textContaining('تحليل وفورات التوريد'), findsOneWidget);
    });

    testWidgets('4. DealBreakdownDrawer slides in with landed cost components',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool closed = false;

      await tester.pumpWidget(
        createTestWidget(
          DealBreakdownDrawer(
            deal: testHistory.first,
            item: testItem,
            onClose: () => closed = true,
          ),
          overrides: [
            financialSettlementProvider.overrideWith((ref) => _MockFinancialSettlementNotifier()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Verify titles and breakdown categories
      expect(find.text('تفكيك تكلفة الوصول الفعلية'), findsOneWidget);
      expect(find.text('الرسوم والضرائب الجمركية'), findsOneWidget);
      expect(find.text('النولون والشحن الدولي'), findsOneWidget);
      expect(find.text('أرضيات الموانئ وغرامات التأخير'), findsOneWidget);
      expect(find.text('أتعاب التخليص ومصاريف النافذة'), findsOneWidget);
      expect(find.text('النقل الداخلي والتعتيق'), findsOneWidget);
      expect(find.text('نسخ تفكيك التكلفة'), findsOneWidget);

      // Tap close
      await tester.tap(find.text('إغلاق'));
      await tester.pump();
      expect(closed, isTrue);
    });

    testWidgets('5. ItemPriceTrendsScreen renders complete Type C dashboard',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const mockState = MasterItemsState(
        items: [testItem],
        total: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            masterItemsProvider.overrideWith(() => _MockMasterItemsNotifier(mockState)),
            itemPriceTrendsProvider.overrideWith(() => _MockPriceTrendsNotifier(testTrends)),
            itemSuppliersProvider(101).overrideWith((ref) => Future.value(testSuppliers)),
            financialSettlementProvider.overrideWith((ref) => _MockFinancialSettlementNotifier()),
          ],
          child: const MaterialApp(
            home: ItemPriceTrendsScreen(initialItemId: 101),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // PageHeader Title & Prominent Copy Button
      expect(find.text('رادار تحليل اتجاه الأسعار ومقارنة الصفقات'), findsOneWidget);
      expect(find.text('نسخ التقرير الفني للمقارنة'), findsOneWidget);

      // Verify SelectionArea wraps body
      expect(find.byType(SelectionArea), findsOneWidget);

      // Verify Item Specs bar
      expect(find.text('ITEM-VALVE-001'), findsOneWidget);
      expect(find.text('848180'), findsOneWidget);

      // Verify KPI Cards & Tables loaded
      expect(find.text('أقل سعر شراء'), findsOneWidget);
      expect(find.text('سجل الصفقات التاريخية وتكلفة الوصول الفعلية'), findsOneWidget);
    });
  });
}

class _MockMasterItemsNotifier extends AutoDisposeAsyncNotifier<MasterItemsState>
    implements MasterItemsNotifier {
  final MasterItemsState _initial;
  _MockMasterItemsNotifier(this._initial);

  @override
  FutureOr<MasterItemsState> build() => _initial;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPriceTrendsNotifier extends ItemPriceTrendsNotifier {
  final ItemPriceTrendsModel _trends;
  _MockPriceTrendsNotifier(this._trends);

  @override
  FutureOr<ItemPriceTrendsModel> build(int arg) => _trends;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockFinancialSettlementNotifier
    extends StateNotifier<AsyncValue<List<LandedCostSettlementModel>>>
    implements FinancialSettlementNotifier {
  _MockFinancialSettlementNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
