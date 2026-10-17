import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/features/customs_consultation/providers/customs_consultation_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/shipment_updates/providers/shipment_updates_provider.dart';
import 'package:frontend/features/shipment_updates/screens/shipment_update_engine_screen.dart';
import 'package:frontend/features/shipment_updates/widgets/shipment_update_dialog.dart';

class MockImportFilesNotifier extends ImportFilesNotifier {
  final List<ImportFileModel> files;
  MockImportFilesNotifier(this.files) : super(Dio()) {
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
  }) async {
    state = AsyncValue.data(files);
  }
}

class MockShipmentUpdatesNotifier extends ShipmentUpdatesNotifier {
  MockShipmentUpdatesNotifier() : super(Dio()) {
    state = ShipmentUpdatesState(logs: [], isLoading: false);
  }
  @override
  Future<void> fetchLogs({int? importFileId, String? updateCategory, String? targetPhase, String? search, int skip = 0, int limit = 200}) async {
    state = ShipmentUpdatesState(logs: [], isLoading: false, selectedFileId: importFileId);
  }
}

class MockCustomsConsultationNotifier extends CustomsConsultationNotifier {
  MockCustomsConsultationNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }
  @override
  Future<void> fetchConsultations({
    bool includeInactive = false,
    String? search,
    int? brokerId,
    int? poId,
    int? projectId,
    String? status,
  }) async {
    state = const AsyncValue.data([]);
  }
}

void main() {
  group('Screen 42: Operational & Daily Shipment Updates Engine Localization Tests', () {
    late AppLocalizations ar;
    late AppLocalizations en;

    setUp(() {
      ar = const AppLocalizationsAr();
      en = const AppLocalizationsEn();
    });

    test('All Screen 42 getters return non-empty strings in Arabic and English', () {
      // Screen & Section Titles
      expect(ar.shipmentUpdateEngineTitle, isNotEmpty);
      expect(en.shipmentUpdateEngineTitle, isNotEmpty);
      expect(ar.shipmentUpdateRefreshTooltip, isNotEmpty);
      expect(en.shipmentUpdateRefreshTooltip, isNotEmpty);
      expect(ar.shipmentUpdateNoShipmentsRegistered, isNotEmpty);
      expect(en.shipmentUpdateNoShipmentsRegistered, isNotEmpty);
      expect(ar.shipmentUpdateSelectShipmentPrompt, isNotEmpty);
      expect(en.shipmentUpdateSelectShipmentPrompt, isNotEmpty);
      expect(ar.shipmentUpdateComprehensiveDailyCheckinBtn, isNotEmpty);
      expect(en.shipmentUpdateComprehensiveDailyCheckinBtn, isNotEmpty);
      expect(ar.shipmentUpdateCustomsSecTitle, isNotEmpty);
      expect(en.shipmentUpdateCustomsSecTitle, isNotEmpty);
      expect(ar.shipmentUpdateCustomsNoStudies, isNotEmpty);
      expect(en.shipmentUpdateCustomsNoStudies, isNotEmpty);
      expect(ar.shipmentUpdateCustomsEmptyPrompt, isNotEmpty);
      expect(en.shipmentUpdateCustomsEmptyPrompt, isNotEmpty);

      // Buttons & Actions
      expect(ar.shipmentUpdateBtnPrintPdf, isNotEmpty);
      expect(en.shipmentUpdateBtnPrintPdf, isNotEmpty);
      expect(ar.shipmentUpdateBtnViewChecklist, isNotEmpty);
      expect(en.shipmentUpdateBtnViewChecklist, isNotEmpty);
      expect(ar.shipmentUpdateBtnEditDocs, isNotEmpty);
      expect(en.shipmentUpdateBtnEditDocs, isNotEmpty);
      expect(ar.shipmentUpdateBtnRecordDailyUpdate, isNotEmpty);
      expect(en.shipmentUpdateBtnRecordDailyUpdate, isNotEmpty);

      // Phases
      expect(ar.shipmentUpdatePhase1Name, isNotEmpty);
      expect(en.shipmentUpdatePhase1Name, isNotEmpty);
      expect(ar.shipmentUpdatePhase2Name, isNotEmpty);
      expect(en.shipmentUpdatePhase2Name, isNotEmpty);
      expect(ar.shipmentUpdatePhase3Name, isNotEmpty);
      expect(en.shipmentUpdatePhase3Name, isNotEmpty);
      expect(ar.shipmentUpdatePhase4Name, isNotEmpty);
      expect(en.shipmentUpdatePhase4Name, isNotEmpty);
      expect(ar.shipmentUpdatePhase5Name, isNotEmpty);
      expect(en.shipmentUpdatePhase5Name, isNotEmpty);
      expect(ar.shipmentUpdatePhase6Name, isNotEmpty);
      expect(en.shipmentUpdatePhase6Name, isNotEmpty);
      expect(ar.shipmentUpdatePhase7Name, isNotEmpty);
      expect(en.shipmentUpdatePhase7Name, isNotEmpty);
      expect(ar.shipmentUpdatePhase8Name, isNotEmpty);
      expect(en.shipmentUpdatePhase8Name, isNotEmpty);
      expect(ar.shipmentUpdatePhase9Name, isNotEmpty);
      expect(en.shipmentUpdatePhase9Name, isNotEmpty);
      expect(ar.shipmentUpdatePhase10Name, isNotEmpty);
      expect(en.shipmentUpdatePhase10Name, isNotEmpty);

      // Status
      expect(ar.shipmentUpdateStatusCompleted, isNotEmpty);
      expect(en.shipmentUpdateStatusCompleted, isNotEmpty);
      expect(ar.shipmentUpdateStatusCurrent, isNotEmpty);
      expect(en.shipmentUpdateStatusCurrent, isNotEmpty);
      expect(ar.shipmentUpdateStatusFuture, isNotEmpty);
      expect(en.shipmentUpdateStatusFuture, isNotEmpty);

      // Columns
      expect(ar.shipmentUpdateColActions, isNotEmpty);
      expect(en.shipmentUpdateColActions, isNotEmpty);
      expect(ar.shipmentUpdateColCode, isNotEmpty);
      expect(en.shipmentUpdateColCode, isNotEmpty);
      expect(ar.shipmentUpdateColDate, isNotEmpty);
      expect(en.shipmentUpdateColDate, isNotEmpty);
      expect(ar.shipmentUpdateColType, isNotEmpty);
      expect(en.shipmentUpdateColType, isNotEmpty);
      expect(ar.shipmentUpdateColTargetStage, isNotEmpty);
      expect(en.shipmentUpdateColTargetStage, isNotEmpty);
      expect(ar.shipmentUpdateColNotes, isNotEmpty);
      expect(en.shipmentUpdateColNotes, isNotEmpty);
      expect(ar.shipmentUpdateColCostAdjustment, isNotEmpty);
      expect(en.shipmentUpdateColCostAdjustment, isNotEmpty);
      expect(ar.shipmentUpdateColAssignedUser, isNotEmpty);
      expect(en.shipmentUpdateColAssignedUser, isNotEmpty);

      // Badges
      expect(ar.shipmentUpdateBadgeDaily, isNotEmpty);
      expect(en.shipmentUpdateBadgeDaily, isNotEmpty);
      expect(ar.shipmentUpdateBadgeCostAdj, isNotEmpty);
      expect(en.shipmentUpdateBadgeCostAdj, isNotEmpty);
      expect(ar.shipmentUpdateBadgeFollowUp, isNotEmpty);
      expect(en.shipmentUpdateBadgeFollowUp, isNotEmpty);
      expect(ar.shipmentUpdateBadgeFutureAlert, isNotEmpty);
      expect(en.shipmentUpdateBadgeFutureAlert, isNotEmpty);

      // Metrics
      expect(ar.shipmentUpdateMetricEstDuties, isNotEmpty);
      expect(en.shipmentUpdateMetricEstDuties, isNotEmpty);
      expect(ar.shipmentUpdateMetricApprovedDocs, isNotEmpty);
      expect(en.shipmentUpdateMetricApprovedDocs, isNotEmpty);
      expect(ar.shipmentUpdateMetricBlockingIssues, isNotEmpty);
      expect(en.shipmentUpdateMetricBlockingIssues, isNotEmpty);
      expect(ar.shipmentUpdateMetricZeroBlocking, isNotEmpty);
      expect(en.shipmentUpdateMetricZeroBlocking, isNotEmpty);
      expect(ar.shipmentUpdateMetricReadinessRate, isNotEmpty);
      expect(en.shipmentUpdateMetricReadinessRate, isNotEmpty);

      // Dialogs
      expect(ar.shipmentUpdateDialogTitle, isNotEmpty);
      expect(en.shipmentUpdateDialogTitle, isNotEmpty);
      expect(ar.shipmentUpdateFieldShipmentLabel, isNotEmpty);
      expect(en.shipmentUpdateFieldShipmentLabel, isNotEmpty);
      expect(ar.shipmentUpdateFieldShipmentRequired, isNotEmpty);
      expect(en.shipmentUpdateFieldShipmentRequired, isNotEmpty);
      expect(ar.shipmentUpdateFieldCategoryLabel, isNotEmpty);
      expect(en.shipmentUpdateFieldCategoryLabel, isNotEmpty);
      expect(ar.shipmentUpdateCatOptFollowUp, isNotEmpty);
      expect(en.shipmentUpdateCatOptFollowUp, isNotEmpty);
      expect(ar.shipmentUpdateCatOptCostAdjustment, isNotEmpty);
      expect(en.shipmentUpdateCatOptCostAdjustment, isNotEmpty);
      expect(ar.shipmentUpdateCatOptFutureAlert, isNotEmpty);
      expect(en.shipmentUpdateCatOptFutureAlert, isNotEmpty);
      expect(ar.shipmentUpdateCatOptDailyCheckin, isNotEmpty);
      expect(en.shipmentUpdateCatOptDailyCheckin, isNotEmpty);
      expect(ar.shipmentUpdateFieldTargetStageLabel, isNotEmpty);
      expect(en.shipmentUpdateFieldTargetStageLabel, isNotEmpty);
      expect(ar.shipmentUpdateFieldCostItemLabel, isNotEmpty);
      expect(en.shipmentUpdateFieldCostItemLabel, isNotEmpty);
      expect(ar.shipmentUpdateFieldPrevCostLabel, isNotEmpty);
      expect(en.shipmentUpdateFieldPrevCostLabel, isNotEmpty);
      expect(ar.shipmentUpdateFieldNewCostLabel, isNotEmpty);
      expect(en.shipmentUpdateFieldNewCostLabel, isNotEmpty);
      expect(ar.shipmentUpdateFieldAlertPriorityLabel, isNotEmpty);
      expect(en.shipmentUpdateFieldAlertPriorityLabel, isNotEmpty);
      expect(ar.shipmentUpdatePriorityLow, isNotEmpty);
      expect(en.shipmentUpdatePriorityLow, isNotEmpty);
      expect(ar.shipmentUpdatePriorityNormal, isNotEmpty);
      expect(en.shipmentUpdatePriorityNormal, isNotEmpty);
      expect(ar.shipmentUpdatePriorityHigh, isNotEmpty);
      expect(en.shipmentUpdatePriorityHigh, isNotEmpty);
      expect(ar.shipmentUpdatePriorityCritical, isNotEmpty);
      expect(en.shipmentUpdatePriorityCritical, isNotEmpty);
      expect(ar.shipmentUpdateFieldDateLabel, isNotEmpty);
      expect(en.shipmentUpdateFieldDateLabel, isNotEmpty);
      expect(ar.shipmentUpdateFieldNotesLabel, isNotEmpty);
      expect(en.shipmentUpdateFieldNotesLabel, isNotEmpty);
      expect(ar.shipmentUpdateFieldNotesHint, isNotEmpty);
      expect(en.shipmentUpdateFieldNotesHint, isNotEmpty);
      expect(ar.shipmentUpdateFieldNotesRequired, isNotEmpty);
      expect(en.shipmentUpdateFieldNotesRequired, isNotEmpty);
      expect(ar.shipmentUpdateBtnSaveUpdate, isNotEmpty);
      expect(en.shipmentUpdateBtnSaveUpdate, isNotEmpty);
      expect(ar.shipmentUpdateBtnCancel, isNotEmpty);
      expect(en.shipmentUpdateBtnCancel, isNotEmpty);
      expect(ar.shipmentUpdateSuccessSaved, isNotEmpty);
      expect(en.shipmentUpdateSuccessSaved, isNotEmpty);

      // Export & Copy Tools (Task B & Task C)
      expect(ar.shipmentUpdatesExportTsvBtn, isNotEmpty);
      expect(en.shipmentUpdatesExportTsvBtn, isNotEmpty);
      expect(ar.shipmentUpdatesExportTsvSuccess, isNotEmpty);
      expect(en.shipmentUpdatesExportTsvSuccess, isNotEmpty);
      expect(ar.shipmentUpdatesExportExcelBtn, isNotEmpty);
      expect(en.shipmentUpdatesExportExcelBtn, isNotEmpty);
      expect(ar.shipmentUpdatesExportPdfBtn, isNotEmpty);
      expect(en.shipmentUpdatesExportPdfBtn, isNotEmpty);
      expect(ar.shipmentUpdateCopySummaryBtn, isNotEmpty);
      expect(en.shipmentUpdateCopySummarySuccess, isNotEmpty);
      expect(ar.shipmentUpdateCodeBadgeLabel, isNotEmpty);
      expect(en.shipmentUpdateCodeBadgeLabel, isNotEmpty);
      expect(ar.shipmentUpdateConsultCodeBadgeLabel, isNotEmpty);
      expect(en.shipmentUpdateConsultCodeBadgeLabel, isNotEmpty);
      expect(ar.shipmentUpdateCopyFieldTooltip, isNotEmpty);
      expect(en.shipmentUpdateCopyFieldTooltip, isNotEmpty);

      // TSV Headers
      expect(ar.shipmentUpdatesTsvHeaderCode, isNotEmpty);
      expect(en.shipmentUpdatesTsvHeaderCode, isNotEmpty);
      expect(ar.shipmentUpdatesTsvHeaderDate, isNotEmpty);
      expect(en.shipmentUpdatesTsvHeaderDate, isNotEmpty);
      expect(ar.shipmentUpdatesTsvHeaderCategory, isNotEmpty);
      expect(en.shipmentUpdatesTsvHeaderCategory, isNotEmpty);
      expect(ar.shipmentUpdatesTsvHeaderPhase, isNotEmpty);
      expect(en.shipmentUpdatesTsvHeaderPhase, isNotEmpty);
      expect(ar.shipmentUpdatesTsvHeaderNotes, isNotEmpty);
      expect(en.shipmentUpdatesTsvHeaderNotes, isNotEmpty);
      expect(ar.shipmentUpdatesTsvHeaderCostItem, isNotEmpty);
      expect(en.shipmentUpdatesTsvHeaderCostItem, isNotEmpty);
      expect(ar.shipmentUpdatesTsvHeaderPrevCost, isNotEmpty);
      expect(en.shipmentUpdatesTsvHeaderPrevCost, isNotEmpty);
      expect(ar.shipmentUpdatesTsvHeaderNewCost, isNotEmpty);
      expect(en.shipmentUpdatesTsvHeaderNewCost, isNotEmpty);
      expect(ar.shipmentUpdatesTsvHeaderPriority, isNotEmpty);
      expect(en.shipmentUpdatesTsvHeaderPriority, isNotEmpty);
      expect(ar.shipmentUpdatesTsvHeaderAssignedUser, isNotEmpty);
      expect(en.shipmentUpdatesTsvHeaderAssignedUser, isNotEmpty);
      expect(ar.shipmentUpdatesTsvHeaderStatus, isNotEmpty);
      expect(en.shipmentUpdatesTsvHeaderStatus, isNotEmpty);

      // Consultation & Doc Statuses
      expect(ar.shipmentUpdateConsultStatusInProgress, isNotEmpty);
      expect(en.shipmentUpdateConsultStatusInProgress, isNotEmpty);
      expect(ar.shipmentUpdateConsultStatusClearanceReady, isNotEmpty);
      expect(en.shipmentUpdateConsultStatusClearanceReady, isNotEmpty);
      expect(ar.shipmentUpdateConsultStatusBlocked, isNotEmpty);
      expect(en.shipmentUpdateConsultStatusBlocked, isNotEmpty);
      expect(ar.shipmentUpdateConsultStatusActionRequired, isNotEmpty);
      expect(en.shipmentUpdateConsultStatusActionRequired, isNotEmpty);
      expect(ar.shipmentUpdateConsultStatusCompleted, isNotEmpty);
      expect(en.shipmentUpdateConsultStatusCompleted, isNotEmpty);

      expect(ar.shipmentUpdateDocStatusApproved, isNotEmpty);
      expect(en.shipmentUpdateDocStatusApproved, isNotEmpty);
      expect(ar.shipmentUpdateDocStatusPending, isNotEmpty);
      expect(en.shipmentUpdateDocStatusPending, isNotEmpty);
      expect(ar.shipmentUpdateDocStatusReceived, isNotEmpty);
      expect(en.shipmentUpdateDocStatusReceived, isNotEmpty);
      expect(ar.shipmentUpdateDocStatusVerified, isNotEmpty);
      expect(en.shipmentUpdateDocStatusVerified, isNotEmpty);
      expect(ar.shipmentUpdateDocStatusRejected, isNotEmpty);
      expect(en.shipmentUpdateDocStatusRejected, isNotEmpty);

      expect(ar.shipmentUpdateCostLabel, isNotEmpty);
      expect(en.shipmentUpdateCostLabel, isNotEmpty);
      expect(ar.shipmentUpdateCostCurrencyUsd, isNotEmpty);
      expect(en.shipmentUpdateCostCurrencyUsd, isNotEmpty);
    });

    test('All Screen 42 Arabic strings adhere strictly to the zero Latin character rule', () {
      final latinRegex = RegExp(r'[A-Za-z]');
      final arabicStrings = [
        ar.shipmentUpdateEngineTitle,
        ar.shipmentUpdateRefreshTooltip,
        ar.shipmentUpdateNoShipmentsRegistered,
        ar.shipmentUpdateSelectShipmentPrompt,
        ar.shipmentUpdateComprehensiveDailyCheckinBtn,
        ar.shipmentUpdateCustomsSecTitle,
        ar.shipmentUpdateCustomsNoStudies,
        ar.shipmentUpdateCustomsEmptyPrompt,
        ar.shipmentUpdateBtnPrintPdf,
        ar.shipmentUpdateBtnViewChecklist,
        ar.shipmentUpdateBtnEditDocs,
        ar.shipmentUpdateBtnRecordDailyUpdate,
        ar.shipmentUpdatePhase1Name,
        ar.shipmentUpdatePhase2Name,
        ar.shipmentUpdatePhase3Name,
        ar.shipmentUpdatePhase4Name,
        ar.shipmentUpdatePhase5Name,
        ar.shipmentUpdatePhase6Name,
        ar.shipmentUpdatePhase7Name,
        ar.shipmentUpdatePhase8Name,
        ar.shipmentUpdatePhase9Name,
        ar.shipmentUpdatePhase10Name,
        ar.shipmentUpdateStatusCompleted,
        ar.shipmentUpdateStatusCurrent,
        ar.shipmentUpdateStatusFuture,
        ar.shipmentUpdateColActions,
        ar.shipmentUpdateColCode,
        ar.shipmentUpdateColDate,
        ar.shipmentUpdateColType,
        ar.shipmentUpdateColTargetStage,
        ar.shipmentUpdateColNotes,
        ar.shipmentUpdateColCostAdjustment,
        ar.shipmentUpdateColAssignedUser,
        ar.shipmentUpdateBadgeDaily,
        ar.shipmentUpdateBadgeCostAdj,
        ar.shipmentUpdateBadgeFollowUp,
        ar.shipmentUpdateBadgeFutureAlert,
        ar.shipmentUpdateMetricEstDuties,
        ar.shipmentUpdateMetricApprovedDocs,
        ar.shipmentUpdateMetricBlockingIssues,
        ar.shipmentUpdateMetricZeroBlocking,
        ar.shipmentUpdateMetricReadinessRate,
        ar.shipmentUpdateDialogTitle,
        ar.shipmentUpdateFieldShipmentLabel,
        ar.shipmentUpdateFieldShipmentRequired,
        ar.shipmentUpdateFieldCategoryLabel,
        ar.shipmentUpdateCatOptFollowUp,
        ar.shipmentUpdateCatOptCostAdjustment,
        ar.shipmentUpdateCatOptFutureAlert,
        ar.shipmentUpdateCatOptDailyCheckin,
        ar.shipmentUpdateFieldTargetStageLabel,
        ar.shipmentUpdateFieldCostItemLabel,
        ar.shipmentUpdateFieldPrevCostLabel,
        ar.shipmentUpdateFieldNewCostLabel,
        ar.shipmentUpdateFieldAlertPriorityLabel,
        ar.shipmentUpdatePriorityLow,
        ar.shipmentUpdatePriorityNormal,
        ar.shipmentUpdatePriorityHigh,
        ar.shipmentUpdatePriorityCritical,
        ar.shipmentUpdateFieldDateLabel,
        ar.shipmentUpdateFieldNotesLabel,
        ar.shipmentUpdateFieldNotesHint,
        ar.shipmentUpdateFieldNotesRequired,
        ar.shipmentUpdateBtnSaveUpdate,
        ar.shipmentUpdateBtnCancel,
        ar.shipmentUpdateSuccessSaved,
        ar.shipmentUpdatesExportTsvBtn,
        ar.shipmentUpdatesExportTsvSuccess,
        ar.shipmentUpdatesExportExcelBtn,
        ar.shipmentUpdatesExportPdfBtn,
        ar.shipmentUpdateCopySummaryBtn,
        ar.shipmentUpdateCopySummarySuccess,
        ar.shipmentUpdateCodeBadgeLabel,
        ar.shipmentUpdateConsultCodeBadgeLabel,
        ar.shipmentUpdateCopyFieldTooltip,
        ar.shipmentUpdatesTsvHeaderCode,
        ar.shipmentUpdatesTsvHeaderDate,
        ar.shipmentUpdatesTsvHeaderCategory,
        ar.shipmentUpdatesTsvHeaderPhase,
        ar.shipmentUpdatesTsvHeaderNotes,
        ar.shipmentUpdatesTsvHeaderCostItem,
        ar.shipmentUpdatesTsvHeaderPrevCost,
        ar.shipmentUpdatesTsvHeaderNewCost,
        ar.shipmentUpdatesTsvHeaderPriority,
        ar.shipmentUpdatesTsvHeaderAssignedUser,
        ar.shipmentUpdatesTsvHeaderStatus,
        ar.shipmentUpdateConsultStatusInProgress,
        ar.shipmentUpdateConsultStatusClearanceReady,
        ar.shipmentUpdateConsultStatusBlocked,
        ar.shipmentUpdateConsultStatusActionRequired,
        ar.shipmentUpdateConsultStatusCompleted,
        ar.shipmentUpdateDocStatusApproved,
        ar.shipmentUpdateDocStatusPending,
        ar.shipmentUpdateDocStatusReceived,
        ar.shipmentUpdateDocStatusVerified,
        ar.shipmentUpdateDocStatusRejected,
        ar.shipmentUpdateCostLabel,
        ar.shipmentUpdateCostCurrencyUsd,
      ];

      for (final s in arabicStrings) {
        expect(latinRegex.hasMatch(s), isFalse, reason: 'Found Latin characters in: "$s"');
      }
    });

    test('Zero stacked Arabic + English in titles and labels', () {
      // Screen title must not contain English in Arabic mode
      expect(ar.shipmentUpdateEngineTitle.contains('Operational'), isFalse);
      expect(ar.shipmentUpdateEngineTitle.contains('Daily'), isFalse);
      expect(ar.shipmentUpdateEngineTitle.contains('Engine'), isFalse);

      // Customs title must not contain English in Arabic mode
      expect(ar.shipmentUpdateCustomsSecTitle.contains('Customs Consultation'), isFalse);
      expect(ar.shipmentUpdateCustomsSecTitle.contains('Inspection Records'), isFalse);

      // Cost adjustment badge & column must not contain English in Arabic mode
      expect(ar.shipmentUpdateBadgeCostAdj.contains('Cost Adjustment'), isFalse);
      expect(ar.shipmentUpdateColCostAdjustment.contains('Cost Adjustment'), isFalse);

      // Blocking issues metric must not contain English in Arabic mode
      expect(ar.shipmentUpdateMetricBlockingIssues.contains('Blocking'), isFalse);

      // Dialog priority options must not contain English in Arabic mode
      expect(ar.shipmentUpdatePriorityNormal.contains('Normal'), isFalse);
      expect(ar.shipmentUpdatePriorityHigh.contains('High Priority'), isFalse);
      expect(ar.shipmentUpdatePriorityCritical.contains('Critical Alert'), isFalse);

      // English titles must not contain Arabic characters
      final arabicRegex = RegExp(r'[\u0600-\u06FF]');
      expect(arabicRegex.hasMatch(en.shipmentUpdateEngineTitle), isFalse);
      expect(arabicRegex.hasMatch(en.shipmentUpdateComprehensiveDailyCheckinBtn), isFalse);
      expect(arabicRegex.hasMatch(en.shipmentUpdateCustomsSecTitle), isFalse);
      expect(arabicRegex.hasMatch(en.shipmentUpdateDialogTitle), isFalse);
      expect(arabicRegex.hasMatch(en.shipmentUpdateBadgeDaily), isFalse);
      expect(arabicRegex.hasMatch(en.shipmentUpdateBadgeCostAdj), isFalse);
      expect(arabicRegex.hasMatch(en.shipmentUpdateBadgeFollowUp), isFalse);
      expect(arabicRegex.hasMatch(en.shipmentUpdateBadgeFutureAlert), isFalse);
      expect(arabicRegex.hasMatch(en.shipmentUpdateBtnPrintPdf), isFalse);
      expect(arabicRegex.hasMatch(en.shipmentUpdateBtnViewChecklist), isFalse);
    });

    test('Parametrized methods produce correct output for both languages', () {
      expect(ar.shipmentUpdateCountBadge(5), contains('5'));
      expect(en.shipmentUpdateCountBadge(5), contains('5'));

      expect(ar.shipmentUpdateCustomsStudiesCount(2), contains('2'));
      expect(ar.shipmentUpdateCustomsStudiesCount(2), contains('دراسة'));
      expect(en.shipmentUpdateCustomsStudiesCount(2), contains('2'));
      expect(en.shipmentUpdateCustomsStudiesCount(2).toLowerCase(), contains('stud'));

      expect(ar.shipmentUpdateBrokerPrefix('Ahmad'), contains('Ahmad'));
      expect(en.shipmentUpdateBrokerPrefix('Ahmad'), contains('Ahmad'));

      expect(ar.shipmentUpdateMetricDocsRatio(3, 7), contains('3'));
      expect(ar.shipmentUpdateMetricDocsRatio(3, 7), contains('7'));
      expect(en.shipmentUpdateMetricDocsRatio(3, 7), contains('3'));
      expect(en.shipmentUpdateMetricDocsRatio(3, 7), contains('7'));

      expect(ar.shipmentUpdateMetricBlockingCount(4), contains('4'));
      expect(en.shipmentUpdateMetricBlockingCount(4), contains('4'));

      expect(ar.shipmentUpdateConsultDialogEditTitle('CS-101'), contains('CS-101'));
      expect(en.shipmentUpdateConsultDialogEditTitle('CS-101'), contains('CS-101'));

      expect(ar.shipmentUpdatePipelineTitle('FILE-001'), contains('FILE-001'));
      expect(en.shipmentUpdatePipelineTitle('FILE-001'), contains('FILE-001'));
    });

    testWidgets('Screen renders properly without layout exceptions under Arabic locale', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testFile = ImportFileModel(
        importFileId: 1,
        importFileCode: 'IMP-2026-001',
        customFileNumber: 'FILE-001',
        companyName: 'Al-Amal Co.',
        supplierName: 'Global Exporter',
        currentModule: 'Phase 6',
        currentStage: 'Phase 6',
        nextAction: 'Customs Clearance',
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) {
              final n = LocaleNotifier();
              n.setLocale(const Locale('ar'));
              return n;
            }),
            importFilesProvider.overrideWith((ref) => MockImportFilesNotifier([testFile])),
            shipmentUpdatesProvider.overrideWith((ref) => MockShipmentUpdatesNotifier()),
            customsConsultationsProvider.overrideWith((ref) => MockCustomsConsultationNotifier()),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: ShipmentUpdateEngineScreen(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Screen title in pure Arabic
      expect(find.text(ar.shipmentUpdateEngineTitle), findsOneWidget);
      // Ensure no English title stacked
      expect(find.textContaining('Operational & Daily Update Engine'), findsNothing);
    });

    testWidgets('Screen renders properly without layout exceptions under English locale', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testFile = ImportFileModel(
        importFileId: 1,
        importFileCode: 'IMP-2026-001',
        customFileNumber: 'FILE-001',
        companyName: 'Al-Amal Co.',
        supplierName: 'Global Exporter',
        currentModule: 'Phase 6',
        currentStage: 'Phase 6',
        nextAction: 'Customs Clearance',
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) {
              final n = LocaleNotifier();
              n.setLocale(const Locale('en'));
              return n;
            }),
            importFilesProvider.overrideWith((ref) => MockImportFilesNotifier([testFile])),
            shipmentUpdatesProvider.overrideWith((ref) => MockShipmentUpdatesNotifier()),
            customsConsultationsProvider.overrideWith((ref) => MockCustomsConsultationNotifier()),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('en'),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Scaffold(
                  body: ShipmentUpdateEngineScreen(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Screen title in pure English
      expect(find.text(en.shipmentUpdateEngineTitle), findsOneWidget);
      // Ensure no Arabic title
      expect(find.text(ar.shipmentUpdateEngineTitle), findsNothing);
    });

    testWidgets('ShipmentUpdateDialog renders pure Arabic without stacked text', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testFile = ImportFileModel(
        importFileId: 1,
        importFileCode: 'IMP-2026-001',
        customFileNumber: 'FILE-001',
        companyName: 'Al-Amal Co.',
        supplierName: 'Global Exporter',
        currentModule: 'Phase 6',
        currentStage: 'Phase 6',
        nextAction: 'Customs Clearance',
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) {
              final n = LocaleNotifier();
              n.setLocale(const Locale('ar'));
              return n;
            }),
            importFilesProvider.overrideWith((ref) => MockImportFilesNotifier([testFile])),
            shipmentUpdatesProvider.overrideWith((ref) => MockShipmentUpdatesNotifier()),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: ShipmentUpdateDialog(
                    initialFileId: 1,
                    initialFileCode: 'FILE-001',
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(ar.shipmentUpdateDialogTitle), findsOneWidget);
      expect(find.text(ar.shipmentUpdateBtnSaveUpdate), findsOneWidget);
      expect(find.text(ar.shipmentUpdateBtnCancel), findsOneWidget);

      // Verify no stacked English in dialog
      expect(find.textContaining('(Normal)'), findsNothing);
      expect(find.textContaining('(High Priority)'), findsNothing);
      expect(find.textContaining('(Critical Alert)'), findsNothing);
    });

    testWidgets('ShipmentUpdateDialog renders pure English without Arabic text', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testFile = ImportFileModel(
        importFileId: 1,
        importFileCode: 'IMP-2026-001',
        customFileNumber: 'FILE-001',
        companyName: 'Al-Amal Co.',
        supplierName: 'Global Exporter',
        currentModule: 'Phase 6',
        currentStage: 'Phase 6',
        nextAction: 'Customs Clearance',
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) {
              final n = LocaleNotifier();
              n.setLocale(const Locale('en'));
              return n;
            }),
            importFilesProvider.overrideWith((ref) => MockImportFilesNotifier([testFile])),
            shipmentUpdatesProvider.overrideWith((ref) => MockShipmentUpdatesNotifier()),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('en'),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Scaffold(
                  body: ShipmentUpdateDialog(
                    initialFileId: 1,
                    initialFileCode: 'FILE-001',
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(en.shipmentUpdateDialogTitle), findsOneWidget);
      expect(find.text(en.shipmentUpdateBtnSaveUpdate), findsOneWidget);
      expect(find.text(en.shipmentUpdateBtnCancel), findsOneWidget);

      // Verify no Arabic text in English dialog
      expect(find.text(ar.shipmentUpdateDialogTitle), findsNothing);
      expect(find.text(ar.shipmentUpdateBtnSaveUpdate), findsNothing);
    });
  });
}
