import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/cargo_shipping/models/cargo_shipping_model.dart';

void main() {
  group('Screen 26 / 52: Cargo Shipping Tracking & Container Allocation Localization Tests', () {
    const AppLocalizations ar = AppLocalizationsAr();
    const AppLocalizations en = AppLocalizationsEn();

    test('All Cargo Shipping getters should have non-empty Arabic and English translations', () {
      final List<String> arStrings = [
        ar.cargoShippingAllocationsTitle,
        ar.cargoShippingTrackingTitle,
        ar.cargoShippingFormTab,
        ar.cargoShippingRegistryTab,
        ar.cargoShippingStep1Title,
        ar.cargoShippingStep2Title,
        ar.cargoShippingUploadBlLabel,
        ar.cargoShippingUploadBlSuccess('BL-12345'),
        ar.cargoShippingLoadSuccessSnack('IMP-2026-001'),
        ar.cargoShippingLinkedFileBannerPrefix,
        ar.cargoShippingSupplierLabel,
        ar.cargoShippingCodeLabel,
        ar.cargoShippingCancelStartNew,
        ar.cargoShippingImportFileLabel,
        ar.cargoShippingImportFileHint,
        ar.cargoShippingImportFileDefault,
        ar.cargoShippingPreviouslyRegistered,
        ar.cargoShippingSelectFileValidator,
        ar.cargoShippingShipmentTypeLabel,
        ar.cargoShippingFclLabel,
        ar.cargoShippingLclLabel,
        ar.cargoShippingAggregatedCargoMetrics('40.00', '2274'),
        ar.cargoShippingCargoStackingLabel,
        ar.cargoShippingStackable,
        ar.cargoShippingNonStackable,
        ar.cargoShippingAutoRecommendation(2, '40HC', '95.0', '80.0'),
        ar.cargoShippingContainersHeader,
        ar.cargoShippingBookingMatchRequired(1, 1),
        ar.cargoShippingBookingLimitReached,
        ar.cargoShippingBookingStatusBadge('BKG-01', '1x 40HC'),
        ar.cargoShippingBookingStatusMatch,
        ar.cargoShippingBookingStatusMismatch,
        ar.cargoShippingAddContainerType,
        ar.cargoShippingContainerType,
        ar.cargoShippingQty,
        ar.cargoShippingVgmWeight,
        ar.cargoShippingUnitDetailsHeader,
        ar.cargoShippingUnitPrefix(1),
        ar.cargoShippingContainerNo,
        ar.cargoShippingSealNo,
        ar.cargoShippingCfsHeader,
        ar.cargoShippingCfsWarehouseLabel,
        ar.cargoShippingImportFileTrackingLabel,
        ar.cargoShippingImportFileTrackingHint,
        ar.cargoShippingMetricTotalContainers,
        ar.cargoShippingMetricInProgress,
        ar.cargoShippingMetricGatedIn,
        ar.cargoShippingMetricSlaBreached,
        ar.cargoShippingContainerCardHeader(1, 'MSCU1234567', '40HC', 'SL-99001'),
        ar.cargoShippingSlaBreachedBadge,
        ar.cargoShippingQuickSaveContainer,
        ar.cargoShippingMilestone1,
        ar.cargoShippingMilestone2,
        ar.cargoShippingMilestone3,
        ar.cargoShippingMilestone4,
        ar.cargoShippingMilestone5,
        ar.cargoShippingMilestone1Title,
        ar.cargoShippingMilestone2Title,
        ar.cargoShippingMilestone3Title,
        ar.cargoShippingMilestone4Title,
        ar.cargoShippingMilestone5Title,
        ar.cargoShippingPickMilestone1,
        ar.cargoShippingPickMilestone2,
        ar.cargoShippingPickMilestone3,
        ar.cargoShippingPickMilestone4,
        ar.cargoShippingPickMilestone5,
        ar.cargoShippingPickBtn,
        ar.cargoShippingSetNowBtn,
        ar.cargoShippingNotesHeader('MSCU1234567'),
        ar.cargoShippingSelectMilestoneTarget,
        ar.cargoShippingTagDriverDelayed,
        ar.cargoShippingTagPermitPending,
        ar.cargoShippingTagContainerInspection,
        ar.cargoShippingTagPortCongestion,
        ar.cargoShippingTagPalletizedCargo,
        ar.cargoShippingTagVisualCheck,
        ar.cargoShippingNoteHint('1. Assignment'),
        ar.cargoShippingSaveNote,
        ar.cargoShippingClearNote,
        ar.cargoShippingLclTrackingHeader('Shanghai CFS Warehouse'),
        ar.cargoShippingQuickSaveLcl,
        ar.cargoShippingLclMilestone1,
        ar.cargoShippingLclMilestone2,
        ar.cargoShippingLclMilestone3,
        ar.cargoShippingLclMilestone4,
        ar.cargoShippingLclMilestone5,
        ar.cargoShippingLclPickMilestone1,
        ar.cargoShippingLclPickMilestone2,
        ar.cargoShippingLclPickMilestone3,
        ar.cargoShippingLclPickMilestone4,
        ar.cargoShippingLclPickMilestone5,
        ar.cargoShippingAutoCompleteCycle,
        ar.cargoShippingClearStartNew,
        ar.cargoShippingSaveDraft,
        ar.cargoShippingSaveStudy,
        ar.cargoShippingUpdateStudy,
        ar.cargoShippingClickToSetDateTime,
        ar.cargoShippingDateSequenceError,
        ar.cargoShippingSelectFileFirstForContainer,
        ar.cargoShippingSaveContainerMilestoneSuccess('MSCU123', 'Gated In'),
        ar.cargoShippingQuickSaveError('Connection error'),
        ar.cargoShippingSelectFileFirstForLcl,
        ar.cargoShippingSaveLclMilestoneSuccess('Gated In'),
        ar.cargoShippingLclSaveError('Connection error'),
        ar.cargoShippingAutoCompleteSuccess,
        ar.cargoShippingFillRequiredFields,
        ar.cargoShippingSelectLinkedFilePrompt,
        ar.cargoShippingDraftSaveSuccess,
        ar.cargoShippingStudySaveSuccess('CS-001'),
        ar.cargoShippingDuplicateWarningTitle,
        ar.cargoShippingGoToSavedRegistry,
        ar.cargoShippingRegistrySearchHint,
        ar.cargoShippingStatusFilterLabel,
        ar.cargoShippingStatusAll,
        ar.cargoShippingStatusCargoReady,
        ar.cargoShippingStatusCompleted,
        ar.cargoShippingSlaFilterLabel,
        ar.cargoShippingSlaAll,
        ar.cargoShippingSlaOnTimeFilter,
        ar.cargoShippingSlaBreachedFilter,
        ar.cargoShippingActiveFilterLabel,
        ar.cargoShippingActiveAll,
        ar.cargoShippingActiveOnly,
        ar.cargoShippingDeletedOnly,
        ar.cargoShippingNoMatchingRecords,
        ar.cargoShippingCreateNewRecord,
        ar.cargoShippingSoftDeletedBadge,
        ar.cargoShippingGatedCountBadge(2, 2),
        ar.cargoShippingSlaBreached,
        ar.cargoShippingSlaOnTime,
        ar.cargoShippingEditTooltip,
        ar.cargoShippingRestoreTooltip,
        ar.cargoShippingRestoreSuccess('CS-001'),
        ar.cargoShippingDeleteSuccess('CS-001'),
        ar.cargoShippingDeleteConfirmTitle,
        ar.cargoShippingDeleteConfirmMessage('CS-001', 'IMP-001'),
        ar.cargoShippingConfirmDeleteBtn,
        ar.cargoShippingStatusAssigned,
        ar.cargoShippingStatusArrivedAtSupplier,
        ar.cargoShippingStatusArrivedAtCfs,
        ar.cargoShippingStatusLoadingInProgress,
        ar.cargoShippingStatusLoadingCompleted,
        ar.cargoShippingStatusGatedIn,
        ar.cargoShippingStatusPendingAssignment,
        ar.cargoShippingAiExtractorBtn,
        ar.cargoShippingExportManifestBtn,
        ar.cargoShippingManifestCopySuccess,
        ar.cargoShippingCopyFieldTooltip,
        ar.cargoShippingAcidPrefix,
        ar.cargoShippingManifestHeader,
        ar.cargoShippingColUnitNumber,
        ar.cargoShippingColContainerNo,
        ar.cargoShippingColContainerType,
        ar.cargoShippingColSealNo,
        ar.cargoShippingColGrossWeight,
        ar.cargoShippingColVgmStatus,
        ar.cargoShippingColVgmRef,
        ar.cargoShippingColTrackingStatus,
        // Screen 52 SLA Tracking getters
        ar.cargoShippingSlaStageTitle,
        ar.cargoShippingSlaExportTsvBtn,
        ar.cargoShippingSlaExportExcelBtn,
        ar.cargoShippingSlaPrintPdfBtn,
        ar.cargoShippingSlaCopyDossierBtn,
        ar.cargoShippingSlaCopyDossierSuccess,
        ar.cargoShippingSlaDossierHeader,
        ar.cargoShippingSlaExportTsvDialogTitle,
        ar.cargoShippingSlaExportExcelDialogTitle,
        ar.cargoShippingSlaTsvHeaderUnit,
        ar.cargoShippingSlaTsvHeaderContainerNo,
        ar.cargoShippingSlaTsvHeaderContainerType,
        ar.cargoShippingSlaTsvHeaderSealNo,
        ar.cargoShippingSlaTsvHeaderAssignmentDate,
        ar.cargoShippingSlaTsvHeaderArrivalDate,
        ar.cargoShippingSlaTsvHeaderLoadingStartDate,
        ar.cargoShippingSlaTsvHeaderLoadingEndDate,
        ar.cargoShippingSlaTsvHeaderPortGateInDate,
        ar.cargoShippingSlaTsvHeaderSlaStatus,
        ar.cargoShippingSlaTsvHeaderTrackingStatus,
        ar.cargoShippingSlaTsvHeaderNotes,
        ar.cargoShippingSlaSummaryHeader,
        ar.cargoShippingSlaCopyContainerSuccess,
        ar.cargoShippingSlaCopySealSuccess,
        ar.cargoShippingSlaCopyMilestoneSuccess,
      ];

      final List<String> enStrings = [
        en.cargoShippingAllocationsTitle,
        en.cargoShippingTrackingTitle,
        en.cargoShippingFormTab,
        en.cargoShippingRegistryTab,
        en.cargoShippingStep1Title,
        en.cargoShippingStep2Title,
        en.cargoShippingUploadBlLabel,
        en.cargoShippingUploadBlSuccess('BL-12345'),
        en.cargoShippingLoadSuccessSnack('IMP-2026-001'),
        en.cargoShippingLinkedFileBannerPrefix,
        en.cargoShippingSupplierLabel,
        en.cargoShippingCodeLabel,
        en.cargoShippingCancelStartNew,
        en.cargoShippingImportFileLabel,
        en.cargoShippingImportFileHint,
        en.cargoShippingImportFileDefault,
        en.cargoShippingPreviouslyRegistered,
        en.cargoShippingSelectFileValidator,
        en.cargoShippingShipmentTypeLabel,
        en.cargoShippingFclLabel,
        en.cargoShippingLclLabel,
        en.cargoShippingAggregatedCargoMetrics('40.00', '2274'),
        en.cargoShippingCargoStackingLabel,
        en.cargoShippingStackable,
        en.cargoShippingNonStackable,
        en.cargoShippingAutoRecommendation(2, '40HC', '95.0', '80.0'),
        en.cargoShippingContainersHeader,
        en.cargoShippingBookingMatchRequired(1, 1),
        en.cargoShippingBookingLimitReached,
        en.cargoShippingBookingStatusBadge('BKG-01', '1x 40HC'),
        en.cargoShippingBookingStatusMatch,
        en.cargoShippingBookingStatusMismatch,
        en.cargoShippingAddContainerType,
        en.cargoShippingContainerType,
        en.cargoShippingQty,
        en.cargoShippingVgmWeight,
        en.cargoShippingUnitDetailsHeader,
        en.cargoShippingUnitPrefix(1),
        en.cargoShippingContainerNo,
        en.cargoShippingSealNo,
        en.cargoShippingCfsHeader,
        en.cargoShippingCfsWarehouseLabel,
        en.cargoShippingImportFileTrackingLabel,
        en.cargoShippingImportFileTrackingHint,
        en.cargoShippingMetricTotalContainers,
        en.cargoShippingMetricInProgress,
        en.cargoShippingMetricGatedIn,
        en.cargoShippingMetricSlaBreached,
        en.cargoShippingContainerCardHeader(1, 'MSCU1234567', '40HC', 'SL-99001'),
        en.cargoShippingSlaBreachedBadge,
        en.cargoShippingQuickSaveContainer,
        en.cargoShippingMilestone1,
        en.cargoShippingMilestone2,
        en.cargoShippingMilestone3,
        en.cargoShippingMilestone4,
        en.cargoShippingMilestone5,
        en.cargoShippingMilestone1Title,
        en.cargoShippingMilestone2Title,
        en.cargoShippingMilestone3Title,
        en.cargoShippingMilestone4Title,
        en.cargoShippingMilestone5Title,
        en.cargoShippingPickMilestone1,
        en.cargoShippingPickMilestone2,
        en.cargoShippingPickMilestone3,
        en.cargoShippingPickMilestone4,
        en.cargoShippingPickMilestone5,
        en.cargoShippingPickBtn,
        en.cargoShippingSetNowBtn,
        en.cargoShippingNotesHeader('MSCU1234567'),
        en.cargoShippingSelectMilestoneTarget,
        en.cargoShippingTagDriverDelayed,
        en.cargoShippingTagPermitPending,
        en.cargoShippingTagContainerInspection,
        en.cargoShippingTagPortCongestion,
        en.cargoShippingTagPalletizedCargo,
        en.cargoShippingTagVisualCheck,
        en.cargoShippingNoteHint('1. Assignment'),
        en.cargoShippingSaveNote,
        en.cargoShippingClearNote,
        en.cargoShippingLclTrackingHeader('Shanghai CFS Warehouse'),
        en.cargoShippingQuickSaveLcl,
        en.cargoShippingLclMilestone1,
        en.cargoShippingLclMilestone2,
        en.cargoShippingLclMilestone3,
        en.cargoShippingLclMilestone4,
        en.cargoShippingLclMilestone5,
        en.cargoShippingLclPickMilestone1,
        en.cargoShippingLclPickMilestone2,
        en.cargoShippingLclPickMilestone3,
        en.cargoShippingLclPickMilestone4,
        en.cargoShippingLclPickMilestone5,
        en.cargoShippingAutoCompleteCycle,
        en.cargoShippingClearStartNew,
        en.cargoShippingSaveDraft,
        en.cargoShippingSaveStudy,
        en.cargoShippingUpdateStudy,
        en.cargoShippingClickToSetDateTime,
        en.cargoShippingDateSequenceError,
        en.cargoShippingSelectFileFirstForContainer,
        en.cargoShippingSaveContainerMilestoneSuccess('MSCU123', 'Gated In'),
        en.cargoShippingQuickSaveError('Connection error'),
        en.cargoShippingSelectFileFirstForLcl,
        en.cargoShippingSaveLclMilestoneSuccess('Gated In'),
        en.cargoShippingLclSaveError('Connection error'),
        en.cargoShippingAutoCompleteSuccess,
        en.cargoShippingFillRequiredFields,
        en.cargoShippingSelectLinkedFilePrompt,
        en.cargoShippingDraftSaveSuccess,
        en.cargoShippingStudySaveSuccess('CS-001'),
        en.cargoShippingDuplicateWarningTitle,
        en.cargoShippingGoToSavedRegistry,
        en.cargoShippingRegistrySearchHint,
        en.cargoShippingStatusFilterLabel,
        en.cargoShippingStatusAll,
        en.cargoShippingStatusCargoReady,
        en.cargoShippingStatusCompleted,
        en.cargoShippingSlaFilterLabel,
        en.cargoShippingSlaAll,
        en.cargoShippingSlaOnTimeFilter,
        en.cargoShippingSlaBreachedFilter,
        en.cargoShippingActiveFilterLabel,
        en.cargoShippingActiveAll,
        en.cargoShippingActiveOnly,
        en.cargoShippingDeletedOnly,
        en.cargoShippingNoMatchingRecords,
        en.cargoShippingCreateNewRecord,
        en.cargoShippingSoftDeletedBadge,
        en.cargoShippingGatedCountBadge(2, 2),
        en.cargoShippingSlaBreached,
        en.cargoShippingSlaOnTime,
        en.cargoShippingEditTooltip,
        en.cargoShippingRestoreTooltip,
        en.cargoShippingRestoreSuccess('CS-001'),
        en.cargoShippingDeleteSuccess('CS-001'),
        en.cargoShippingDeleteConfirmTitle,
        en.cargoShippingDeleteConfirmMessage('CS-001', 'IMP-001'),
        en.cargoShippingConfirmDeleteBtn,
        en.cargoShippingStatusAssigned,
        en.cargoShippingStatusArrivedAtSupplier,
        en.cargoShippingStatusArrivedAtCfs,
        en.cargoShippingStatusLoadingInProgress,
        en.cargoShippingStatusLoadingCompleted,
        en.cargoShippingStatusGatedIn,
        en.cargoShippingStatusPendingAssignment,
        en.cargoShippingAiExtractorBtn,
        en.cargoShippingExportManifestBtn,
        en.cargoShippingManifestCopySuccess,
        en.cargoShippingCopyFieldTooltip,
        en.cargoShippingAcidPrefix,
        en.cargoShippingManifestHeader,
        en.cargoShippingColUnitNumber,
        en.cargoShippingColContainerNo,
        en.cargoShippingColContainerType,
        en.cargoShippingColSealNo,
        en.cargoShippingColGrossWeight,
        en.cargoShippingColVgmStatus,
        en.cargoShippingColVgmRef,
        en.cargoShippingColTrackingStatus,
        // Screen 52 SLA Tracking getters
        en.cargoShippingSlaStageTitle,
        en.cargoShippingSlaExportTsvBtn,
        en.cargoShippingSlaExportExcelBtn,
        en.cargoShippingSlaPrintPdfBtn,
        en.cargoShippingSlaCopyDossierBtn,
        en.cargoShippingSlaCopyDossierSuccess,
        en.cargoShippingSlaDossierHeader,
        en.cargoShippingSlaExportTsvDialogTitle,
        en.cargoShippingSlaExportExcelDialogTitle,
        en.cargoShippingSlaTsvHeaderUnit,
        en.cargoShippingSlaTsvHeaderContainerNo,
        en.cargoShippingSlaTsvHeaderContainerType,
        en.cargoShippingSlaTsvHeaderSealNo,
        en.cargoShippingSlaTsvHeaderAssignmentDate,
        en.cargoShippingSlaTsvHeaderArrivalDate,
        en.cargoShippingSlaTsvHeaderLoadingStartDate,
        en.cargoShippingSlaTsvHeaderLoadingEndDate,
        en.cargoShippingSlaTsvHeaderPortGateInDate,
        en.cargoShippingSlaTsvHeaderSlaStatus,
        en.cargoShippingSlaTsvHeaderTrackingStatus,
        en.cargoShippingSlaTsvHeaderNotes,
        en.cargoShippingSlaSummaryHeader,
        en.cargoShippingSlaCopyContainerSuccess,
        en.cargoShippingSlaCopySealSuccess,
        en.cargoShippingSlaCopyMilestoneSuccess,
      ];

      expect(arStrings.length, enStrings.length);
      for (int i = 0; i < arStrings.length; i++) {
        expect(arStrings[i].trim().isNotEmpty, isTrue, reason: 'Arabic string at index $i is empty');
        expect(enStrings[i].trim().isNotEmpty, isTrue, reason: 'English string at index $i is empty');
      }
    });

    test('ContainerLoadingModel localized status helpers', () {
      final container = ContainerLoadingModel(
        containerType: '40HC',
        quantity: 1,
        containerNo: 'MSCU1234567',
        sealNo: 'SL-99001',
        trackingStatus: 'GATED_IN_AT_PORT',
      );

      expect(container.getLocalizedStatus(ar), 'دخلت الميناء');
      expect(container.getLocalizedStatus(en), 'Gated-in at Port');
      expect(container.arabicStatusLabel, 'دخلت الميناء');

      final loadedContainer = container.copyWith(trackingStatus: 'LOADING_COMPLETED');
      expect(loadedContainer.getLocalizedStatus(ar), 'اكتمل التحميل');
      expect(loadedContainer.getLocalizedStatus(en), 'Loading Completed');
      expect(loadedContainer.arabicStatusLabel, 'اكتمل التحميل');
    });

    test('LclLoadingTrackingModel localized status helpers', () {
      final lcl = LclLoadingTrackingModel(
        shipmentType: 'LCL',
        cfsWarehouseName: 'Shanghai CFS',
        trackingStatus: 'ARRIVED_AT_CFS',
      );

      expect(lcl.getLocalizedStatus(ar), 'وصلت لمخزن التجميع المشترك');
      expect(lcl.getLocalizedStatus(en), 'Arrived at CFS');
      expect(lcl.arabicStatusLabel, 'وصلت لمخزن التجميع المشترك');

      final gatedLcl = LclLoadingTrackingModel(
        shipmentType: 'LCL',
        cfsWarehouseName: 'Shanghai CFS',
        trackingStatus: 'GATED_IN_AT_PORT',
      );
      expect(gatedLcl.getLocalizedStatus(ar), 'دخلت الميناء');
      expect(gatedLcl.getLocalizedStatus(en), 'Gated-in at Port');
      expect(gatedLcl.arabicStatusLabel, 'دخلت الميناء');
    });

    test('Screen 26 Allocations (VGM) anti-stacking and manifest localization', () {
      // Confirm Arabic has no stacked English words for allocations
      expect(ar.cargoShippingUploadBlLabel.contains('B/L'), isFalse);
      expect(ar.cargoShippingUploadBlLabel.contains('PDF'), isFalse);
      expect(ar.cargoShippingFclLabel.contains('FCL'), isFalse);
      expect(ar.cargoShippingLclLabel.contains('LCL'), isFalse);
      expect(ar.cargoShippingContainersHeader.contains('VGM'), isFalse);
      expect(ar.cargoShippingVgmWeight.contains('VGM'), isFalse);

      // Confirm English has clean professional terms
      expect(en.cargoShippingUploadBlLabel, 'Upload & Extract Bill of Lading');
      expect(en.cargoShippingFclLabel, 'Full Container Load (FCL)');
      expect(en.cargoShippingLclLabel, 'LCL (Less than Container Load - CFS)');

      // Confirm manifest columns and headers
      expect(ar.cargoShippingManifestHeader, 'بيان تخصيص الحاويات والوزن الإجمالي المعتمد للشحن');
      expect(en.cargoShippingManifestHeader, 'Container Allocations & Verified Gross Mass (VGM) Manifest');
      expect(ar.cargoShippingAiExtractorBtn, 'المحلل الذكي للبوالص والفواتير');
      expect(en.cargoShippingAiExtractorBtn, 'Smart Invoice & B/L Analyzer');
      expect(ar.cargoShippingExportManifestBtn, 'نسخ بيان الحاويات والشحن');
      expect(en.cargoShippingExportManifestBtn, 'Copy Container Manifest (TSV)');
    });

    test('Screen 52: Cargo Shipping 48h SLA Tracking zero-Latin & anti-stacking test', () {
      final latinRegex = RegExp(r'[a-zA-Z]');

      final screen52ArStrings = [
        ar.cargoShippingSlaStageTitle,
        ar.cargoShippingSlaExportTsvBtn,
        ar.cargoShippingSlaExportExcelBtn,
        ar.cargoShippingSlaPrintPdfBtn,
        ar.cargoShippingSlaCopyDossierBtn,
        ar.cargoShippingSlaCopyDossierSuccess,
        ar.cargoShippingSlaDossierHeader,
        ar.cargoShippingSlaExportTsvDialogTitle,
        ar.cargoShippingSlaExportExcelDialogTitle,
        ar.cargoShippingSlaTsvHeaderUnit,
        ar.cargoShippingSlaTsvHeaderContainerNo,
        ar.cargoShippingSlaTsvHeaderContainerType,
        ar.cargoShippingSlaTsvHeaderSealNo,
        ar.cargoShippingSlaTsvHeaderAssignmentDate,
        ar.cargoShippingSlaTsvHeaderArrivalDate,
        ar.cargoShippingSlaTsvHeaderLoadingStartDate,
        ar.cargoShippingSlaTsvHeaderLoadingEndDate,
        ar.cargoShippingSlaTsvHeaderPortGateInDate,
        ar.cargoShippingSlaTsvHeaderSlaStatus,
        ar.cargoShippingSlaTsvHeaderTrackingStatus,
        ar.cargoShippingSlaTsvHeaderNotes,
        ar.cargoShippingSlaSummaryHeader,
        ar.cargoShippingSlaCopyContainerSuccess,
        ar.cargoShippingSlaCopySealSuccess,
        ar.cargoShippingSlaCopyMilestoneSuccess,
      ];

      for (final s in screen52ArStrings) {
        expect(
          latinRegex.hasMatch(s),
          isFalse,
          reason: 'Arabic string "$s" contains Latin characters: ${latinRegex.allMatches(s).map((m) => m.group(0)).join(", ")}',
        );
      }

      // Verify specific Arabic and English titles
      expect(ar.cargoShippingSlaStageTitle, 'متابعة حركة الشحن وتحميل وتوريد الحاويات والتتبع الزمني 48 ساعة');
      expect(en.cargoShippingSlaStageTitle, 'Cargo Shipping Tracking (48h SLA)');
      expect(ar.cargoShippingSlaExportTsvBtn, 'تصدير جدول نصوص');
      expect(en.cargoShippingSlaExportTsvBtn, 'Export TSV');
      expect(ar.cargoShippingSlaExportExcelBtn, 'تصدير جدول إكسيل');
      expect(en.cargoShippingSlaExportExcelBtn, 'Export Excel');
      expect(ar.cargoShippingSlaPrintPdfBtn, 'طباعة وحفظ مستند');
      expect(en.cargoShippingSlaPrintPdfBtn, 'Print & Save Document');
      expect(ar.cargoShippingSlaCopyDossierBtn, 'نسخ الملخص الشامل');
      expect(en.cargoShippingSlaCopyDossierBtn, 'Copy SLA Dossier');
    });
  });
}
