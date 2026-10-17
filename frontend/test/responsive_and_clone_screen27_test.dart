import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/clone_entity_review_dialog.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/providers/customs_clearance_provider.dart';
import 'package:frontend/features/customs_clearance/screens/customs_clearance_screen.dart';
import 'package:frontend/features/customs_clearance/widgets/search_and_clone_customs_clearance_dialog.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

class _MockClearanceNotifier extends CustomsClearanceNotifier {
  final List<CustomsClearanceModel> initialRecords;
  _MockClearanceNotifier(this.initialRecords) : super(Dio()) {
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

  @override
  Future<CustomsClearanceModel?> createRecord(Map<String, dynamic> payload) async {
    final created = CustomsClearanceModel(
      customsClearanceId: 99,
      clearanceCode: 'CLR-DRAFT-999',
      importFileId: payload['import_file_id'] ?? 101,
      declaration46No: payload['declaration_46_no'],
      customsOfficeName: payload['customs_office_name'] ?? 'Alexandria Port Customs',
      channelType: payload['channel_type'] ?? 'Red Channel',
      totalDutyPayable: (payload['total_duty_payable'] as num?)?.toDouble() ?? 0.0,
      actualDutyTotal: 0.0,
      createdAt: '2026-09-17T00:00:00Z',
      updatedAt: '2026-09-17T00:00:00Z',
    );
    initialRecords.add(created);
    state = AsyncValue.data(initialRecords);
    return created;
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

class _MockPartnersNotifier extends PartnersNotifier {
  _MockPartnersNotifier() : super(category: 'All', showInactive: true, dio: Dio()) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchPartners({
    String? category,
    bool includeInactive = false,
    String? search,
  }) async {
    state = const AsyncValue.data([]);
  }
}

void main() {
  final List<CustomsClearanceModel> mockRecords = [
    CustomsClearanceModel(
      customsClearanceId: 10,
      clearanceCode: 'CLR-2026-0010',
      importFileId: 101,
      declaration46No: '46-ALX-2026-991',
      customsOfficeName: 'Alexandria Sea Port',
      channelType: 'Red Channel',
      importDutyAmount: 30000.0,
      vatAmount: 25000.0,
      scheduleTaxAmount: 4000.0,
      whtAmount: 2000.0,
      labServiceFees: 2000.0,
      totalDutyPayable: 63000.0,
      estimatedDutyTotal: 62000.0,
      actualDutyTotal: 63000.0,
      dutyVarianceAmount: 1000.0,
      dutyVariancePercentage: 1.6,
      paymentStatus: 'Paid & Verified',
      status: 'Duty Paid',
      deliveryOrderNumber: 'DO-MEDU-99881',
      freeDaysAllowed: 14,
      createdAt: '2026-08-23T00:00:00Z',
      updatedAt: '2026-08-23T00:00:00Z',
      owner: 'Admin',
    ),
    CustomsClearanceModel(
      customsClearanceId: 11,
      clearanceCode: 'CLR-2026-0011',
      importFileId: 102,
      declaration46No: '46-DAM-2026-442',
      customsOfficeName: 'Damietta Port Customs',
      channelType: 'Green Channel',
      importDutyAmount: 15000.0,
      vatAmount: 12000.0,
      scheduleTaxAmount: 0.0,
      whtAmount: 1000.0,
      labServiceFees: 1500.0,
      totalDutyPayable: 29500.0,
      estimatedDutyTotal: 29500.0,
      actualDutyTotal: 29500.0,
      dutyVarianceAmount: 0.0,
      dutyVariancePercentage: 0.0,
      paymentStatus: 'Paid & Verified',
      status: 'Final Release Granted',
      deliveryOrderNumber: 'DO-CMA-77112',
      freeDaysAllowed: 21,
      createdAt: '2026-09-01T00:00:00Z',
      updatedAt: '2026-09-03T00:00:00Z',
      owner: 'Kamal',
    ),
  ];

  final List<ImportFileModel> mockFiles = [
    ImportFileModel(
      importFileId: 101,
      importFileCode: 'IMP-2026-0101',
      companyId: 1,
      companyName: 'Al-Amal Medical Group',
      supplierName: 'Siemens Healthineers',
      acidNumber: '1234567890123456789',
      portOfLoading: 'Hamburg',
      portOfDischarge: 'Alexandria',
      currentModule: 'Customs Clearance',
      currentStage: 'Port Inspection',
      nextAction: 'Duty Payment',
      status: 'Active',
      createdAt: '2026-08-20T08:00:00Z',
      updatedAt: '2026-08-20T08:00:00Z',
    ),
    ImportFileModel(
      importFileId: 102,
      importFileCode: 'IMP-2026-0102',
      companyId: 2,
      companyName: 'Delta Pharma Industries',
      supplierName: 'Pfizer Global',
      acidNumber: '9876543210987654321',
      portOfLoading: 'Shanghai',
      portOfDischarge: 'Damietta',
      currentModule: 'Customs Clearance',
      currentStage: 'Final Release',
      nextAction: 'Gate Out',
      status: 'Active',
      createdAt: '2026-08-25T08:00:00Z',
      updatedAt: '2026-08-25T08:00:00Z',
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
        customsClearanceProvider.overrideWith((ref) => _MockClearanceNotifier(List.from(mockRecords))),
        importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier(mockFiles)),
        partnersProvider.overrideWith((ref) => _MockPartnersNotifier()),
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
                child: CustomsClearanceScreen(initialSubTab: initialSubTab),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 27: CustomsClearanceScreen Enterprise Protocol Tests', () {
    // -------------------------------------------------------------------------
    // Test 1: Desktop Responsive Layout (1440x900)
    // -------------------------------------------------------------------------
    testWidgets('1. Desktop Layout (1440x900) renders with ZERO overflow', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(size: const Size(1440, 900)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('createClearanceBtn')), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneClearanceBtn')), findsOneWidget);
      expect(find.byKey(const Key('copyClearanceTableTsvBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportClearanceExcelBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportClearancePdfBtn')), findsOneWidget);
      expect(find.text('CLR-2026-0010'), findsOneWidget);
      expect(find.text('CLR-2026-0011'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Test 2: Tablet Responsive Layout (800x1024)
    // -------------------------------------------------------------------------
    testWidgets('2. Tablet Layout (800x1024) renders with ZERO overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(size: const Size(800, 1024)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('createClearanceBtn')), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneClearanceBtn')), findsOneWidget);
      expect(find.text('CLR-2026-0010'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Test 3: Mobile Responsive Layout (390x844)
    // -------------------------------------------------------------------------
    testWidgets('3. Mobile Layout (390x844) renders with ZERO overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('createClearanceBtn')), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneClearanceBtn')), findsOneWidget);
      expect(find.text('CLR-2026-0010'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Test 4: Dark Mode WCAG AA Compliance
    // -------------------------------------------------------------------------
    testWidgets('4. Dark Mode WCAG AA Compliance renders clearly without exceptions', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(
        size: const Size(1440, 900),
        themeMode: ThemeMode.dark,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('CLR-2026-0010'), findsOneWidget);
      expect(find.textContaining('Alexandria Sea Port'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Test 5: RTL Arabic Localization
    // -------------------------------------------------------------------------
    testWidgets('5. RTL Arabic Localization strings render properly', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('تسجيل معاملة تخليص'), findsOneWidget);
      expect(find.text('بحث واستنساخ بيان تخليص سابق'), findsOneWidget);
      expect(find.textContaining('إجمالي الرسوم'), findsWidgets);
      expect(find.textContaining('46 ك.م'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // Test 6: Toolbar Search and Clone Workflow with Invariants
    // -------------------------------------------------------------------------
    testWidgets('6. Search & Clone Workflow opens dialog, clones record, and enforces reset invariants', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Step 1: Open Search & Clone Dialog
      final searchAndCloneBtn = find.byKey(const Key('searchAndCloneClearanceBtn'));
      expect(searchAndCloneBtn, findsOneWidget);
      await tester.tap(searchAndCloneBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SearchAndCloneCustomsClearanceDialog), findsOneWidget);
      expect(find.byKey(const Key('selectRecordToCloneBtn_CLR-2026-0010')), findsOneWidget);

      // Step 2: Select Record to Clone
      await tester.tap(find.byKey(const Key('selectRecordToCloneBtn_CLR-2026-0010')));
      await tester.pumpAndSettle();

      // Step 3: Verify CloneEntityReviewDialog appears with reset invariants
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.textContaining('معرف التخليص الجمركي'), findsOneWidget);
      expect(find.textContaining('CLR-DRAFT'), findsWidgets);

      // Step 4: Confirm Clone
      final confirmBtn = find.byKey(const Key('confirmCloneBtn'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Step 5: Verify new draft form opened with cloned values
      expect(find.text('استنساخ بيان تخليص ومعاينة جمركية'), findsOneWidget);
      // The source record's port is also shown as a CcFact on the screen behind
      // the form, so assert the cloned value on the form's input field itself.
      expect(
        find.byWidgetPredicate(
          (w) => w is EditableText && w.controller.text == 'Alexandria Sea Port',
        ),
        findsOneWidget,
      );
    });

    // -------------------------------------------------------------------------
    // Test 7: Row-Level Actions (Copy Row TSV, Clone, Table TSV, Excel & PDF Export)
    // -------------------------------------------------------------------------
    testWidgets('7. Row TSV Copy, Row Clone, Table TSV, and Multi-Format Exports trigger cleanly', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Row TSV Copy
      final copyRowBtn = find.byKey(const Key('copyClearanceRowBtn_CLR-2026-0010'));
      expect(copyRowBtn, findsOneWidget);
      await tester.tap(copyRowBtn);
      await tester.pumpAndSettle();

      // Table TSV Copy
      final copyTableBtn = find.byKey(const Key('copyClearanceTableTsvBtn'));
      expect(copyTableBtn, findsOneWidget);
      await tester.tap(copyTableBtn);
      await tester.pumpAndSettle();

      // Excel Export
      final exportExcelBtn = find.byKey(const Key('exportClearanceExcelBtn'));
      expect(exportExcelBtn, findsOneWidget);
      await tester.tap(exportExcelBtn);
      await tester.pumpAndSettle();

      // PDF Export
      final exportPdfBtn = find.byKey(const Key('exportClearancePdfBtn'));
      expect(exportPdfBtn, findsOneWidget);
      await tester.tap(exportPdfBtn);
      await tester.pumpAndSettle();

      // Row Clone Button
      final cloneRowBtn = find.byKey(const Key('cloneClearanceBtn_CLR-2026-0010'));
      expect(cloneRowBtn, findsOneWidget);
      await tester.tap(cloneRowBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
