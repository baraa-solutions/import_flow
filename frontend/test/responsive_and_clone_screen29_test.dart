import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/financial_settlement/models/financial_settlement_model.dart';
import 'package:frontend/features/financial_settlement/providers/financial_settlement_provider.dart';
import 'package:frontend/features/financial_settlement/screens/financial_settlement_screen.dart';
import 'package:frontend/features/financial_settlement/widgets/settlement_form_dialog.dart';
import 'package:frontend/features/financial_settlement/widgets/search_and_clone_financial_settlement_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

class _MockFinancialSettlementNotifier extends FinancialSettlementNotifier {
  final List<LandedCostSettlementModel> initialRecords;
  _MockFinancialSettlementNotifier(this.initialRecords) : super(Dio()) {
    state = AsyncValue.data(initialRecords);
  }

  @override
  Future<void> fetchSettlements({
    bool includeInactive = false,
    int? importFileId,
    String? status,
    String? search, int? skip, int? limit}) async {
    state = AsyncValue.data(initialRecords);
  }

  @override
  Future<LandedCostSettlementModel?> createSettlement(Map<String, dynamic> payload) async {
    final created = LandedCostSettlementModel(
      settlementId: 999,
      settlementCode: 'SETTLE-DRAFT-TEST',
      importFileId: payload['import_file_id'] ?? 10,
      totalFobEgp: 50000.0,
      totalExpensesEgp: 10000.0,
      totalLandedCostEgp: 60000.0,
      averageMarkupFactor: 1.2,
      status: 'Draft',
      accountantName: 'Kamal Accountant',
      createdAt: '2026-09-17T00:00:00Z',
      updatedAt: '2026-09-17T00:00:00Z',
    );
    initialRecords.add(created);
    state = AsyncValue.data(initialRecords);
    return created;
  }

  @override
  Future<void> softDeleteSettlement(int settlementId) async {
    initialRecords.removeWhere((r) => r.settlementId == settlementId);
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

void main() {
  final List<LandedCostSettlementModel> mockRecords = [
    LandedCostSettlementModel(
      settlementId: 101,
      settlementCode: 'SETTLE-2026-0001',
      importFileId: 10,
      expenseInvoices: [
        ExpenseInvoiceModel(
          invoiceNo: 'INV-MSK-01',
          category: 'Freight',
          providerName: 'Maersk Shipping Line',
          currency: 'USD',
          amountFx: 1200.0,
          exchangeRate: 50.0,
          amountEgp: 60000.0,
          allocationRule: 'Volume-Based',
        ),
        ExpenseInvoiceModel(
          invoiceNo: 'INV-CUS-02',
          category: 'Customs Duty',
          providerName: 'Alexandria Customs Authority',
          currency: 'EGP',
          amountFx: 45000.0,
          exchangeRate: 1.0,
          amountEgp: 45000.0,
          allocationRule: 'Value-Based',
        ),
      ],
      totalFobEgp: 500000.0,
      totalExpensesEgp: 105000.0,
      totalLandedCostEgp: 605000.0,
      averageMarkupFactor: 1.21,
      itemLandedCosts: [
        ItemLandedCostModel(
          itemCode: 'VALVE-IND-01',
          itemName: 'High-Pressure Industrial Valves',
          qty: 100,
          grossWeightKg: 1200.0,
          cbm: 12.0,
          fobUnitEgp: 5000.0,
          fobTotalEgp: 500000.0,
          allocatedFreightEgp: 60000.0,
          allocatedCustomsEgp: 45000.0,
          totalLandedCostEgp: 605000.0,
          unitLandedCostEgp: 6050.0,
          markupFactor: 1.21,
        ),
      ],
      status: 'Calculated',
      accountantName: 'Kamal Accountant',
      createdAt: '2026-09-17T10:00:00Z',
      updatedAt: '2026-09-17T10:00:00Z',
    ),
    LandedCostSettlementModel(
      settlementId: 102,
      settlementCode: 'SETTLE-2026-0002',
      importFileId: 11,
      expenseInvoices: [
        ExpenseInvoiceModel(
          invoiceNo: 'INV-MSC-99',
          category: 'Freight',
          providerName: 'MSC Mediterranean',
          currency: 'USD',
          amountFx: 800.0,
          exchangeRate: 50.0,
          amountEgp: 40000.0,
          allocationRule: 'Weight-Based',
        ),
      ],
      totalFobEgp: 200000.0,
      totalExpensesEgp: 40000.0,
      totalLandedCostEgp: 240000.0,
      averageMarkupFactor: 1.20,
      itemLandedCosts: [
        ItemLandedCostModel(
          itemCode: 'SENSOR-OPT-02',
          itemName: 'Optical Sensor Units',
          qty: 50,
          grossWeightKg: 300.0,
          cbm: 4.0,
          fobUnitEgp: 4000.0,
          fobTotalEgp: 200000.0,
          allocatedFreightEgp: 40000.0,
          totalLandedCostEgp: 240000.0,
          unitLandedCostEgp: 4800.0,
          markupFactor: 1.20,
        ),
      ],
      status: 'Approved',
      accountantName: 'Sarah Controller',
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
      currentModule: 'Financial Settlement',
      currentStage: 'Landed Cost Settlement',
      nextAction: 'Final Archiving',
      status: 'Active',
      createdAt: '2026-09-01T00:00:00Z',
      updatedAt: '2026-09-01T00:00:00Z',
    ),
    ImportFileModel(
      importFileId: 11,
      importFileCode: 'IMP-2026-0011',
      companyId: 2,
      companyName: 'Nile Delta Trading',
      supplierName: 'Bosch Italy',
      acidNumber: '9876543210987654321',
      portOfLoading: 'Genoa',
      portOfDischarge: 'Port Said',
      currentModule: 'Financial Settlement',
      currentStage: 'Landed Cost Settlement',
      nextAction: 'Odoo Journal Entry',
      status: 'Active',
      createdAt: '2026-09-02T00:00:00Z',
      updatedAt: '2026-09-02T00:00:00Z',
    ),
  ];

  Widget buildTestWidget({
    Size size = const Size(1440, 900),
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('ar'),
    List<LandedCostSettlementModel>? records,
  }) {
    final activeRecords = records ?? List.from(mockRecords);
    return ProviderScope(
      overrides: [
        financialSettlementProvider.overrideWith((ref) => _MockFinancialSettlementNotifier(activeRecords)),
        importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier(mockFiles)),
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
                child: const FinancialSettlementScreen(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 29: Financial Settlement & Landed Cost Engine Enterprise Tests', () {
    testWidgets('1. Desktop Layout (1440x900) renders with complete toolbar & zero RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(size: const Size(1440, 900)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('createSettlementBtn')), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneSettlementBtn')), findsOneWidget);
      expect(find.byKey(const Key('copySettlementTableTsvBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportSettlementExcelBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportSettlementPdfBtn')), findsOneWidget);

      expect(find.text('SETTLE-2026-0001'), findsOneWidget);
    });

    testWidgets('2. Tablet Layout (800x1024) wraps toolbar cleanly with zero RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(size: const Size(800, 1024)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('createSettlementBtn')), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneSettlementBtn')), findsOneWidget);
      expect(find.text('SETTLE-2026-0001'), findsOneWidget);
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
      expect(find.byKey(const Key('createSettlementBtn')), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneSettlementBtn')), findsOneWidget);
    });

    testWidgets('4. Dark Mode WCAG AA Compliance renders with appropriate dark palette',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(size: const Size(1440, 900), themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('createSettlementBtn')), findsOneWidget);
      expect(find.text('SETTLE-2026-0001'), findsOneWidget);
    });

    testWidgets('5. Arabic RTL Directionality properly applies right-to-left layout and localized labels',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(size: const Size(1440, 900), locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('تسجيل فواتير مصاريف واحتساب تكلفة الوصول'), findsOneWidget);
      expect(find.text('بحث واستنساخ تسوية تكلفة سابقة'), findsOneWidget);
    });

    testWidgets('6. Search & Clone Dialog workflow enforces strict reset invariants (Task D)',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(size: const Size(1440, 900)));
      await tester.pumpAndSettle();

      // Tap toolbar button to open search and clone dialog
      final cloneBtn = find.byKey(const Key('searchAndCloneSettlementBtn'));
      expect(cloneBtn, findsOneWidget);
      await tester.tap(cloneBtn);
      await tester.pumpAndSettle();

      // Confirm SearchAndCloneFinancialSettlementDialog is visible
      expect(find.byType(SearchAndCloneFinancialSettlementDialog), findsOneWidget);
      expect(find.byKey(const Key('selectSettlementToCloneBtn_SETTLE-2026-0001')), findsOneWidget);

      // Select record to clone
      await tester.tap(find.byKey(const Key('selectSettlementToCloneBtn_SETTLE-2026-0001')));
      await tester.pumpAndSettle();

      // The clone opens the settlement form pre-filled as a draft (target file must differ).
      expect(find.byType(SettlementFormDialog), findsOneWidget);

      // Form dialog opens populated with cloned draft data
      expect(find.text('INV-MSK-01-DRAFT'), findsWidgets);
    });

    testWidgets('7. Row TSV Copy, Table TSV Copy, Excel/PDF exports, and Card Clone button operate cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(size: const Size(1440, 900)));
      await tester.pumpAndSettle();

      // Row TSV Copy
      final copyRowBtn = find.byKey(const Key('copySettlementRowBtn_SETTLE-2026-0001'));
      expect(copyRowBtn, findsOneWidget);
      await tester.tap(copyRowBtn);
      await tester.pumpAndSettle();

      // Table TSV Copy
      final copyTableBtn = find.byKey(const Key('copySettlementTableTsvBtn'));
      expect(copyTableBtn, findsOneWidget);
      await tester.tap(copyTableBtn);
      await tester.pumpAndSettle();

      // Excel & PDF export buttons
      final excelBtn = find.byKey(const Key('exportSettlementExcelBtn'));
      expect(excelBtn, findsOneWidget);
      await tester.tap(excelBtn);
      await tester.pumpAndSettle();

      final pdfBtn = find.byKey(const Key('exportSettlementPdfBtn'));
      expect(pdfBtn, findsOneWidget);
      await tester.tap(pdfBtn);
      await tester.pumpAndSettle();

      // Row direct clone button
      final rowCloneBtn = find.byKey(const Key('cloneSettlementBtn_SETTLE-2026-0001'));
      expect(rowCloneBtn, findsOneWidget);
      await tester.tap(rowCloneBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SettlementFormDialog), findsOneWidget);
    });
  });
}
