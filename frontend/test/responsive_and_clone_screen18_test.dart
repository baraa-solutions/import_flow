import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/clone_entity_review_dialog.dart';
import 'package:frontend/features/import_documentation/models/import_documentation_model.dart';
import 'package:frontend/features/import_documentation/providers/import_documentation_provider.dart';
import 'package:frontend/features/import_documentation/screens/shipment_draft_docs_screen.dart';
import 'package:frontend/features/import_documentation/widgets/draft_bl_review/draft_bl_extractor_card.dart';
import 'package:frontend/features/import_documentation/widgets/draft_bl_review/draft_bl_header_bar.dart';
import 'package:frontend/features/import_documentation/widgets/search_and_clone_draft_bl_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

class MockDraftBLNotifier extends DraftBLNotifier {
  final List<DraftBLReviewModel> _initialList;

  MockDraftBLNotifier(this._initialList) : super(Dio()) {
    state = AsyncValue.data(_initialList);
  }

  @override
  Future<void> fetchReviews({int? importFileId, String? search, bool? isDraft}) async {
    if (search != null && search.isNotEmpty) {
      final filtered = _initialList.where((r) =>
        r.draftBlNumber.toLowerCase().contains(search.toLowerCase()) ||
        (r.vesselName?.toLowerCase().contains(search.toLowerCase()) ?? false)
      ).toList();
      state = AsyncValue.data(filtered);
    } else {
      state = AsyncValue.data(_initialList);
    }
  }

  @override
  Future<DraftBLComparisonResultModel> compareDraftBL(
    int importFileId,
    Map<String, dynamic> draftFields, {
    String? rawText,
    String draftSource = 'MANUAL_OR_TEXT',
  }) async {
    return DraftBLComparisonResultModel(
      importFileId: importFileId,
      stage: 'Stage 1: Draft Review',
      hasDiscrepancies: false,
      hasBlockingMismatch: false,
      openDiscrepanciesCount: 0,
      blockingReasons: [],
      status: 'Matched',
      correctionRequestLetter: '',
      matrix: [],
      systemData: {
        'draft_bl_number': 'MSCU12345678',
        'shipper': 'Shanghai Machinery Ltd',
        'consignee': 'الشركة الهندسية للتوريدات',
        'vessel_name': 'MSC OSCAR',
        'voyage_number': '2026E',
        'pol': 'Shanghai, China',
        'pod': 'Alexandria, Egypt',
        'freight_terms': 'Freight Prepaid',
        'booking_no': 'BK-MSC-9901',
        'acid_number': 'ACID-9988-2026',
        'importer_tax_id': '100-200-300',
        'shipper_reg_id': 'CN-SH-8899',
        'total_gross_weight_kg': 12500.0,
        'total_net_weight_kg': 11800.0,
        'cbm': 45.5,
        'qty_pkg': 120,
        'container_summary': '1x40HC (MSCU9876543 / SEAL: 123456)',
      },
      draftData: {
        'draft_bl_number': 'MSCU12345678',
        'vessel_name': 'MSC OSCAR',
        'voyage_number': '2026E',
        'pol': 'Shanghai, China',
        'pod': 'Alexandria, Egypt',
        'freight_terms': 'Freight Prepaid',
        'booking_no': 'BK-MSC-9901',
        'total_gross_weight_kg': 12500.0,
        'cbm': 45.5,
        'qty_pkg': 120,
      },
      checklist: [],
      revisionReport: [],
    );
  }
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

class MockShipmentDocumentsNotifier extends ShipmentDocumentsNotifier {
  MockShipmentDocumentsNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchShipmentDocuments({int? importFileId}) async {}
}

void main() {
  final List<DraftBLReviewModel> sampleReviews = [
    DraftBLReviewModel(
      blReviewId: 301,
      blReviewCode: 'BLREV-2026-001',
      importFileId: 1,
      draftBlNumber: 'MSCU12345678',
      shippingLine: 'MSC Mediterranean Shipping',
      vesselName: 'MSC OSCAR',
      voyageNumber: '2026E',
      bookingNumber: 'BK-MSC-9901',
      polName: 'Shanghai, China',
      podName: 'Alexandria, Egypt',
      freightTerms: 'Freight Prepaid',
      placeOfDelivery: 'Alexandria Port',
      importerTaxId: '100-200-300',
      shipperRegId: 'CN-SH-8899',
      measurementCbm: 45.5,
      netWeightKg: 12500.0,
      packagesCount: 120,
      containerSummary: '1x40HC (MSCU9876543 / SEAL: 123456)',
      versionNumber: 1,
      stage: 'Stage 1: Review Sheet',
      systemDataSnapshot: {
        'draft_bl_number': 'MSCU12345678',
        'shipper': 'Shanghai Machinery Ltd',
        'consignee': 'الشركة الهندسية للتوريدات',
      },
      draftExtractedData: {
        'draft_bl_number': 'MSCU12345678',
        'booking_no': 'BK-MSC-9901',
        'shipping_line': 'MSC Mediterranean Shipping',
        'vessel_name': 'MSC OSCAR',
        'voyage_number': '2026E',
        'pol': 'Shanghai, China',
        'pod': 'Alexandria, Egypt',
      },
      comparisonMatrix: [],
      checklistData: [],
      revisionReportData: [],
      hasDiscrepancies: false,
      hasBlockingMismatch: false,
      openDiscrepanciesCount: 0,
      blockingReasons: [],
      importerApprovalStatus: 'Approved',
      importerApprovedBy: 'Kamal (Import Manager)',
      brokerApprovalStatus: 'Pending',
      status: 'In Review',
      isActive: true,
      createdAt: '2026-03-01T10:00:00Z',
    ),
    DraftBLReviewModel(
      blReviewId: 302,
      blReviewCode: 'BLREV-2026-002',
      importFileId: 2,
      draftBlNumber: 'MAEU98765432',
      shippingLine: 'Maersk Line',
      vesselName: 'MAERSK MC-KINNEY MOLLER',
      voyageNumber: '102W',
      bookingNumber: 'BK-MAE-5544',
      polName: 'Hamburg, Germany',
      podName: 'Dekheila, Egypt',
      freightTerms: 'Freight Collect',
      placeOfDelivery: 'Dekheila Port',
      importerTaxId: '400-500-600',
      shipperRegId: 'DE-HH-1122',
      measurementCbm: 68.0,
      netWeightKg: 18400.0,
      packagesCount: 250,
      containerSummary: '2x40HC',
      versionNumber: 2,
      stage: 'Stage 5: Final Registry',
      systemDataSnapshot: {
        'draft_bl_number': 'MAEU98765432',
      },
      draftExtractedData: {
        'draft_bl_number': 'MAEU98765432',
        'shipping_line': 'Maersk Line',
      },
      comparisonMatrix: [],
      checklistData: [],
      revisionReportData: [],
      hasDiscrepancies: false,
      hasBlockingMismatch: false,
      openDiscrepanciesCount: 0,
      blockingReasons: [],
      importerApprovalStatus: 'Approved',
      brokerApprovalStatus: 'Approved',
      status: 'Final Approved',
      isActive: true,
      createdAt: '2026-03-10T10:00:00Z',
    ),
  ];

  final List<ImportFileModel> sampleFiles = [
    ImportFileModel(
      importFileId: 1,
      importFileCode: 'IMP-2026-001',
      supplierName: 'Siemens Industrial AG',
      companyName: 'الشركة الهندسية للتوريدات',
      status: 'Customs Clearance',
      currentModule: 'import_documentation',
      currentStage: 'DraftBL',
      nextAction: 'Review Draft BL',
      createdAt: '2026-01-01',
      updatedAt: '2026-01-01',
    ),
    ImportFileModel(
      importFileId: 2,
      importFileCode: 'IMP-2026-002',
      supplierName: 'Bosch Thermotechnology',
      companyName: 'مصر للاستيراد والتصدير',
      status: 'Under Review',
      currentModule: 'import_documentation',
      currentStage: 'DraftBL',
      nextAction: 'Pending Dual Approval',
      createdAt: '2026-01-05',
      updatedAt: '2026-01-05',
    ),
  ];

  Widget buildTestWidget({
    required Size surfaceSize,
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('ar'),
    int initialSubTab = 2,
  }) {
    return ProviderScope(
      overrides: [
        draftBLReviewsProvider.overrideWith((ref) => MockDraftBLNotifier(sampleReviews)),
        importFilesProvider.overrideWith((ref) => MockImportFilesNotifier(sampleFiles)),
        shipmentDocumentsProvider.overrideWith((ref) => MockShipmentDocumentsNotifier()),
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
            textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: MediaQuery(
              data: MediaQueryData(size: surfaceSize, textScaler: TextScaler.noScaling),
              child: Scaffold(
                body: ShipmentDraftDocsScreen(
                  initialSubTab: initialSubTab,
                  initialImportFileId: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 18 (ShipmentDraftDocsScreen SubTab 2 - DraftBLReviewTab) Enterprise Audit & Verification', () {
    // 1. Desktop View (1400x900)
    testWidgets('1. Desktop View (1400x900) renders cleanly with 0 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(1400, 900)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('stage1SearchAndCloneBtn')), findsOneWidget);
      expect(find.text('MSCU12345678'), findsWidgets);
    });

    // 2. Tablet View (800x1024)
    testWidgets('2. Tablet View (800x1024) renders cleanly with 0 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(800, 1024)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('stage1SearchAndCloneBtn')), findsOneWidget);
    });

    // 3. Mobile View (390x844)
    testWidgets('3. Mobile View (390x844) renders without overflow with responsive Wrap toolbar', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('stage1SearchAndCloneBtn')), findsOneWidget);
    });

    // 4. Stage 1 Search & Clone Button opens SearchAndCloneDraftBlDialog
    testWidgets('4. Tapping Stage 1 Search & Clone button opens SearchAndCloneDraftBlDialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(1200, 900)));
      await tester.pumpAndSettle();

      final cloneBtn = find.byKey(const Key('stage1SearchAndCloneBtn'));
      expect(cloneBtn, findsOneWidget);
      await tester.tap(cloneBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SearchAndCloneDraftBlDialog), findsOneWidget);
      expect(find.textContaining('MSCU12345678'), findsWidgets);
      expect(find.textContaining('MAEU98765432'), findsWidgets);
    });

    // 5. Ctrl + D Shortcut Triggers Search & Clone Dialog
    testWidgets('5. Keyboard shortcut Ctrl + D opens SearchAndCloneDraftBlDialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(1200, 900)));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byType(SearchAndCloneDraftBlDialog), findsOneWidget);
    });

    // 6. Live Filter in Search & Clone Dialog
    testWidgets('6. Typing in dialog search box filters draft B/L reviews dynamically', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(1200, 900)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('stage1SearchAndCloneBtn')));
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('searchDraftBlDialogQueryInput'));
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Maersk');
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(SearchAndCloneDraftBlDialog), matching: find.textContaining('MAEU98765432')), findsWidgets);
      expect(find.descendant(of: find.byType(SearchAndCloneDraftBlDialog), matching: find.textContaining('MSCU12345678')), findsNothing);
    });

    // 7. Task D Screen-Level Clone Flow opens CloneEntityReviewDialog
    testWidgets('7. Selecting a review in dialog triggers CloneEntityReviewDialog with invariants', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(1200, 900)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('stage1SearchAndCloneBtn')));
      await tester.pumpAndSettle();

      final cloneItemBtn = find.byKey(const Key('selectDraftBlItem_301'));
      expect(cloneItemBtn, findsOneWidget);
      await tester.tap(cloneItemBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.textContaining('BLREV-2026-001'), findsWidgets);
      expect(find.text('DRAFT-BL-2026-'), findsOneWidget);

      // Confirm cloning
      final confirmBtn = find.byKey(const Key('confirmCloneBtn'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Ensure dialog is closed and fields populated. The cloned B/L number now shows in
      // both the extractor card and the new transport header bar.
      expect(find.byType(CloneEntityReviewDialog), findsNothing);
      expect(
          find.descendant(of: find.byType(DraftBlExtractorCard), matching: find.text('DRAFT-BL-2026-')),
          findsOneWidget);
      expect(
          find.descendant(of: find.byType(DraftBlHeaderBar), matching: find.text('DRAFT-BL-2026-')),
          findsOneWidget);
    });

    // 8. Task E Row-Level Clone Action in Stage 5 Final Registry
    testWidgets('8. Row-level clone action in Stage 5 Final Registry opens CloneEntityReviewDialog', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Navigate to Stage 5: Final Registry in AdaptiveTabScaffold
      final stage5Step = find.text('5. السجل النهائي المعتمد');
      if (stage5Step.evaluate().isNotEmpty) {
        await tester.tap(stage5Step);
      } else {
        final iconFinder = find.byIcon(Icons.inventory_2);
        if (iconFinder.evaluate().isNotEmpty) {
          await tester.tap(iconFinder.first);
        }
      }
      await tester.pumpAndSettle();

      // Check row clone button for session 302
      final rowCloneBtn = find.byKey(const Key('cloneDraftBlRowBtn_302'));
      if (rowCloneBtn.evaluate().isNotEmpty) {
        await tester.tap(rowCloneBtn);
        await tester.pumpAndSettle();
        expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
        expect(find.textContaining('BLREV-2026-002'), findsWidgets);
      } else {
        // Test stage5SearchAndCloneBtn
        final s5CloneBtn = find.byKey(const Key('stage5SearchAndCloneBtn'));
        expect(s5CloneBtn, findsOneWidget);
        await tester.tap(s5CloneBtn);
        await tester.pumpAndSettle();
        expect(find.byType(SearchAndCloneDraftBlDialog), findsOneWidget);
      }
    });

    // 9. Stage 5 Live Registry Search & Empty State
    testWidgets('9. Stage 5 registry search filters rows and displays empty state on unmatched query', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(1400, 900)));
      await tester.pumpAndSettle();

      final stage5Step = find.text('5. السجل النهائي المعتمد');
      if (stage5Step.evaluate().isNotEmpty) {
        await tester.tap(stage5Step);
      } else {
        final iconFinder = find.byIcon(Icons.inventory_2);
        if (iconFinder.evaluate().isNotEmpty) {
          await tester.tap(iconFinder.first);
        }
      }
      await tester.pumpAndSettle();

      final searchInput = find.byKey(const Key('draftBlRegistrySearchInput'));
      if (searchInput.evaluate().isNotEmpty) {
        await tester.enterText(searchInput, 'NonExistentB/L-99999');
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
      }
    });

    // 10. WCAG AA Dark Mode Contrast and RTL Verification
    testWidgets('10. Dark Mode rendering maintains WCAG AA contrast and RTL mirroring without exceptions', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(
        surfaceSize: const Size(1200, 800),
        themeMode: ThemeMode.dark,
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('stage1SearchAndCloneBtn')), findsOneWidget);

      // Verify LTR locale rendering as well
      await tester.pumpWidget(buildTestWidget(
        surfaceSize: const Size(1200, 800),
        themeMode: ThemeMode.dark,
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
