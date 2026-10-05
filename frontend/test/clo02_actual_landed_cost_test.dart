import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/financial_settlement/models/actual_landed_cost_model.dart';
import 'package:frontend/features/financial_settlement/models/financial_settlement_model.dart';
import 'package:frontend/features/financial_settlement/providers/financial_settlement_provider.dart';
import 'package:frontend/features/financial_settlement/widgets/actual_landed_cost_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';

class _MockFinancialSettlementNotifier extends FinancialSettlementNotifier {
  final ActualLandedCostCalculationResponseModel mockCalculation;
  final ApproveActualLandedCostResponseModel mockApproveResponse;

  _MockFinancialSettlementNotifier(this.mockCalculation, this.mockApproveResponse)
      : super(Dio()) {
    state = const AsyncValue.data(<LandedCostSettlementModel>[]);
  }

  @override
  Future<void> fetchSettlements({
    bool includeInactive = false,
    int? importFileId,
    String? status,
    String? search,
  }) async {
    state = const AsyncValue.data(<LandedCostSettlementModel>[]);
  }

  @override
  Future<ActualLandedCostCalculationResponseModel> calculateActualLandedCost(
    int importFileId, {
    String allocationPreference = 'Value-Based',
    String? notes,
  }) async {
    return mockCalculation;
  }

  @override
  Future<ApproveActualLandedCostResponseModel> approveActualLandedCost({
    required int importFileId,
    required String approvedBy,
    String allocationPreference = 'Value-Based',
    String? notes,
  }) async {
    return mockApproveResponse;
  }
}

void main() {
  final sampleCategory = ActualLandedCostCategoryBreakdownModel(
    category: 'Ocean / Air Freight',
    categoryAr: 'النولون والشحن الدولي',
    estimatedAmountEgp: 120000.0,
    actualAmountEgp: 110000.0,
    varianceEgp: -10000.0,
    variancePct: -8.33,
    varianceStatus: 'FAVORABLE',
    invoicesCount: 1,
    sourceNote: 'فاتورة خط ميرسك الأصلية',
  );

  final sampleItem = ActualLandedCostItemLineModel(
    poItemId: 101,
    itemCode: 'ITEM-PET-01',
    itemNameAr: 'حبيبات بلاستيك بولي إيثيلين خام',
    hsCode: '3901.10.00',
    quantity: 1000.0,
    unitOfMeasure: 'KG',
    fobUnitPriceFc: 1.5,
    fobTotalFc: 1500.0,
    fobTotalEgp: 75000.0,
    currency: 'USD',
    grossWeightKg: 1050.0,
    cbm: 2.2,
    allocatedFreightEgp: 11000.0,
    allocatedInsuranceEgp: 2000.0,
    allocatedCustomsDutiesEgp: 5000.0,
    allocatedTaxesFeesEgp: 10500.0,
    allocatedClearanceBrokerageEgp: 4500.0,
    allocatedPortHandlingEgp: 3000.0,
    allocatedInlandTransportEgp: 4000.0,
    allocatedOtherExpensesEgp: 1000.0,
    totalActualLandedCostEgp: 116000.0,
    actualUnitLandedCostEgp: 116.0,
    estimatedUnitLandedCostEgp: 120.0,
    unitCostVarianceEgp: -4.0,
    unitCostVariancePct: -3.33,
    markupFactor: 1.547,
    varianceStatus: 'FAVORABLE',
  );

  final sampleCalculation = ActualLandedCostCalculationResponseModel(
    importFileId: 44,
    importFileCode: 'IMP-2026-0044',
    financialSettlementStatus: 'SETTLED',
    currency: 'USD',
    fxRate: 50.0,
    allocationPreference: 'Value-Based',
    totalFobEgp: 75000.0,
    totalActualExpensesEgp: 41000.0,
    actualTotalLandedCostEgp: 116000.0,
    actualMarkupFactor: 1.547,
    estimatedTotalLandedCostEgp: 120000.0,
    landedVarianceEgp: -4000.0,
    landedVariancePct: -3.33,
    varianceStatus: 'FAVORABLE',
    varianceStatusAr: 'وفر وتكلفة أقل من التقديري (توفير)',
    categoriesBreakdown: [sampleCategory],
    itemsBreakdown: [sampleItem],
    summaryNotes: 'تمت مطابقة كافة فواتير الشحن والتخليص الفعلي بنجاح.',
  );

  final sampleApproveResponse = ApproveActualLandedCostResponseModel(
    success: true,
    importFileId: 44,
    importFileCode: 'IMP-2026-0044',
    settlementId: 10,
    settlementCode: 'LCS-2026-0010',
    financialSettlementStatus: 'COST_ALLOCATED',
    actualLandedCostTotalEgp: 116000.0,
    actualLandedCostMarkupFactor: 1.547,
    landedVarianceEgp: -4000.0,
    landedVariancePct: -3.33,
    varianceStatus: 'FAVORABLE',
    progressPercent: 99.0,
    currentStage: 'Stage 9: Landed Cost & File Closure',
    currentModule: 'CLO-02 Actual Landed Cost Calculation',
    nextTaskCode: 'TSK-0903-44',
    nextTaskTitle: 'إصدار وتصدير التقرير والملف الشامل PDF/Excel (CLO-03)',
    message: 'تم اعتماد تكلفة الوصول الفعلية للشحنة IMP-2026-0044 بنجاح.',
  );

  group('CLO-02: Actual Landed Cost Model & Calculation Tests', () {
    test('ActualLandedCostCategoryBreakdownModel parses and serializes correctly', () {
      final json = sampleCategory.toJson();
      final parsed = ActualLandedCostCategoryBreakdownModel.fromJson(json);

      expect(parsed.category, equals('Ocean / Air Freight'));
      expect(parsed.categoryAr, equals('النولون والشحن الدولي'));
      expect(parsed.estimatedAmountEgp, equals(120000.0));
      expect(parsed.actualAmountEgp, equals(110000.0));
      expect(parsed.varianceEgp, equals(-10000.0));
      expect(parsed.variancePct, closeTo(-8.33, 0.01));
      expect(parsed.varianceStatus, equals('FAVORABLE'));
      expect(parsed.invoicesCount, equals(1));
    });

    test('ActualLandedCostItemLineModel parses and verifies unit cost variance', () {
      final json = sampleItem.toJson();
      final parsed = ActualLandedCostItemLineModel.fromJson(json);

      expect(parsed.itemCode, equals('ITEM-PET-01'));
      expect(parsed.quantity, equals(1000.0));
      expect(parsed.actualUnitLandedCostEgp, equals(116.0));
      expect(parsed.estimatedUnitLandedCostEgp, equals(120.0));
      expect(parsed.unitCostVarianceEgp, equals(-4.0));
      expect(parsed.markupFactor, closeTo(1.547, 0.001));
      expect(parsed.totalActualLandedCostEgp, equals(116000.0));
      expect(parsed.fobTotalEgp, equals(75000.0));
      // Total expenses allocated = 116000 - 75000 = 41000
      expect(parsed.totalActualLandedCostEgp - parsed.fobTotalEgp, equals(41000.0));
    });

    test('ActualLandedCostCalculationResponseModel mathematical consistency', () {
      final json = sampleCalculation.toJson();
      final parsed = ActualLandedCostCalculationResponseModel.fromJson(json);

      expect(parsed.importFileId, equals(44));
      expect(parsed.importFileCode, equals('IMP-2026-0044'));
      expect(parsed.totalFobEgp + parsed.totalActualExpensesEgp, equals(parsed.actualTotalLandedCostEgp));
      expect(parsed.actualTotalLandedCostEgp / parsed.totalFobEgp, closeTo(parsed.actualMarkupFactor, 0.001));
      expect(parsed.categoriesBreakdown.length, equals(1));
      expect(parsed.itemsBreakdown.length, equals(1));
    });

    test('ApproveActualLandedCostResponseModel parses correctly', () {
      final json = sampleApproveResponse.toJson();
      final parsed = ApproveActualLandedCostResponseModel.fromJson(json);

      expect(parsed.success, isTrue);
      expect(parsed.financialSettlementStatus, equals('COST_ALLOCATED'));
      expect(parsed.actualLandedCostTotalEgp, equals(116000.0));
      expect(parsed.progressPercent, equals(99.0));
      expect(parsed.nextTaskCode, equals('TSK-0903-44'));
      expect(parsed.nextTaskTitle, contains('CLO-03'));
    });

    test('ImportFileModel handles actual landed cost fields properly', () {
      final file = ImportFileModel(
        importFileId: 44,
        importFileCode: 'IMP-2026-0044',
        companyName: 'Sorour Logistics',
        supplierName: 'Bavaria Chemical',
        currentStage: 'Stage 9: Landed Cost & File Closure',
        currentModule: 'CLO-02 Actual Landed Cost Calculation',
        nextAction: 'إصدار وتصدير التقرير والملف الشامل PDF/Excel (CLO-03)',
        createdAt: '2026-09-18T10:00:00Z',
        updatedAt: '2026-09-18T16:00:00Z',
        actualLandedCostTotalEgp: 116000.0,
        actualLandedCostMarkupFactor: 1.547,
        actualLandedCostVarianceEgp: -4000.0,
        actualLandedCostVariancePct: -3.33,
        actualLandedCostCalculatedAt: '2026-09-18T16:00:00Z',
      );

      final json = file.toJson();
      expect(json['actual_landed_cost_total_egp'], equals(116000.0));
      expect(json['actual_landed_cost_markup_factor'], equals(1.547));
      expect(json['actual_landed_cost_variance_egp'], equals(-4000.0));
      expect(json['actual_landed_cost_variance_pct'], equals(-3.33));
      expect(json['actual_landed_cost_calculated_at'], equals('2026-09-18T16:00:00Z'));

      final parsed = ImportFileModel.fromJson(json);
      expect(parsed.actualLandedCostTotalEgp, equals(116000.0));
      expect(parsed.actualLandedCostMarkupFactor, equals(1.547));
      expect(parsed.actualLandedCostVarianceEgp, equals(-4000.0));
      expect(parsed.actualLandedCostVariancePct, equals(-3.33));
      expect(parsed.actualLandedCostCalculatedAt, equals('2026-09-18T16:00:00Z'));
    });
  });

  group('CLO-02: ActualLandedCostDialog Widget Tests', () {
    testWidgets('Renders KPI strip, dropdown, dual tabs, and action buttons', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockNotifier = _MockFinancialSettlementNotifier(
        sampleCalculation,
        sampleApproveResponse,
      );

      Widget createTestWidget() {
        return ProviderScope(
          overrides: [
            financialSettlementProvider.overrideWith((ref) => mockNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    key: const Key('openDialogBtn'),
                    onPressed: () => ActualLandedCostDialog.show(
                      ctx,
                      importFileId: 44,
                      importFileCode: 'IMP-2026-0044',
                    ),
                    child: const Text('Open Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('openDialogBtn')));
      await tester.pumpAndSettle();

      // Check Header
      expect(find.text('محرك احتساب تكلفة الوصول الفعلية والانحراف (CLO-02)'), findsOneWidget);
      expect(find.byKey(const Key('actualLandedCostCloseBtn')), findsOneWidget);

      // Check KPI Cards
      expect(find.text('إجمالي البضاعة FOB'), findsOneWidget);
      expect(find.text('المصاريف الفعلية المسددة'), findsOneWidget);
      expect(find.text('تكلفة الوصول الشاملة الفعلية'), findsOneWidget);
      expect(find.text('معامل التضخيم الفعلي'), findsOneWidget);
      expect(find.text('الانحراف المالي الشامل'), findsOneWidget);

      // Check Allocation preference selector
      expect(find.byKey(const Key('actualLandedCostAllocationDropdown')), findsOneWidget);

      // Check Tab Bar
      expect(find.byKey(const Key('actualLandedCostExpensesTab')), findsOneWidget);
      expect(find.byKey(const Key('actualLandedCostItemsTab')), findsOneWidget);

      // Verify category in Tab 1
      expect(find.text('النولون والشحن الدولي'), findsOneWidget);

      // Switch to Tab 2 (Items Breakdown)
      await tester.tap(find.byKey(const Key('actualLandedCostItemsTab')));
      await tester.pumpAndSettle();

      // Verify item details in Tab 2
      expect(find.text('ITEM-PET-01'), findsOneWidget);
      expect(find.text('حبيبات بلاستيك بولي إيثيلين خام'), findsOneWidget);

      // Verify action buttons
      expect(find.byKey(const Key('actualLandedCostCancelBtn')), findsOneWidget);
      expect(find.byKey(const Key('actualLandedCostApproveBtn')), findsOneWidget);

      // No sample signer is prefilled any more (defaults to the signed-in user).
      await tester.ensureVisible(find.byKey(const Key('actualLandedCostApprovedByField')));
      await tester.enterText(find.byKey(const Key('actualLandedCostApprovedByField')), 'Finance Manager');
      await tester.pumpAndSettle();

      // Tap Approve button
      await tester.tap(find.byKey(const Key('actualLandedCostApproveBtn')));
      await tester.pumpAndSettle();

      // Verify SnackBar message displayed
      expect(find.text('تم اعتماد تكلفة الوصول الفعلية للشحنة IMP-2026-0044 بنجاح.'), findsOneWidget);
    });
  });
}
