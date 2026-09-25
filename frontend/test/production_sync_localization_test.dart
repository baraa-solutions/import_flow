import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';

void main() {
  group('Screen 59: Production Sync Screen & Hub Localization Tests', () {
    const ar = AppLocalizationsAr();
    const en = AppLocalizationsEn();

    test('All Screen 59 getters return non-empty strings and no missing translations', () {
      // Titles and Subtitles
      expect(ar.prodSyncScreenTitle.isNotEmpty, true);
      expect(en.prodSyncScreenTitle.isNotEmpty, true);
      expect(ar.prodSyncScreenSubtitle.isNotEmpty, true);
      expect(en.prodSyncScreenSubtitle.isNotEmpty, true);
      expect(ar.prodSyncHubDialogTitle.isNotEmpty, true);
      expect(en.prodSyncHubDialogTitle.isNotEmpty, true);
      expect(ar.prodSyncHubDialogSubtitle.isNotEmpty, true);
      expect(en.prodSyncHubDialogSubtitle.isNotEmpty, true);

      // Tabs
      expect(ar.prodSyncTabCompareTables.isNotEmpty, true);
      expect(en.prodSyncTabCompareTables.isNotEmpty, true);
      expect(ar.prodSyncTabSchemaUpgrade.isNotEmpty, true);
      expect(en.prodSyncTabSchemaUpgrade.isNotEmpty, true);
      expect(ar.prodSyncTabSafetyBackups.isNotEmpty, true);
      expect(en.prodSyncTabSafetyBackups.isNotEmpty, true);

      // Dev & Prod DB Cards
      expect(ar.prodSyncDevDbTitle.isNotEmpty, true);
      expect(en.prodSyncDevDbTitle.isNotEmpty, true);
      expect(ar.prodSyncDevDbSubtitle.isNotEmpty, true);
      expect(en.prodSyncDevDbSubtitle.isNotEmpty, true);
      expect(ar.prodSyncDevDbUpgradeSub.isNotEmpty, true);
      expect(en.prodSyncDevDbUpgradeSub.isNotEmpty, true);
      expect(ar.prodSyncProdDbTitle.isNotEmpty, true);
      expect(en.prodSyncProdDbTitle.isNotEmpty, true);
      expect(ar.prodSyncProdDbSubtitle.isNotEmpty, true);
      expect(en.prodSyncProdDbSubtitle.isNotEmpty, true);
      expect(ar.prodSyncProdDbUpgradeSub.isNotEmpty, true);
      expect(en.prodSyncProdDbUpgradeSub.isNotEmpty, true);

      // DB Metrics
      expect(ar.prodSyncDbSize(1024), contains('1024'));
      expect(en.prodSyncDbSize(1024), contains('1024'));
      expect(ar.prodSyncDbTablesCount(25), contains('25'));
      expect(en.prodSyncDbTablesCount(25), contains('25'));
      expect(ar.prodSyncDbRecordsCount(500), contains('500'));
      expect(en.prodSyncDbRecordsCount(500), contains('500'));

      // Sync & Differences Status
      expect(ar.prodSyncFullySynchronizedTitle(25), contains('25'));
      expect(en.prodSyncFullySynchronizedTitle(25), contains('25'));
      expect(ar.prodSyncFullySynchronizedSub.isNotEmpty, true);
      expect(en.prodSyncFullySynchronizedSub.isNotEmpty, true);
      expect(ar.prodSyncDifferencesDetectedTitle(3), contains('3'));
      expect(en.prodSyncDifferencesDetectedTitle(3), contains('3'));
      expect(ar.prodSyncDifferencesDetectedSub.isNotEmpty, true);
      expect(en.prodSyncDifferencesDetectedSub.isNotEmpty, true);
      expect(ar.prodSyncUpgradeReadyTitle(2), contains('2'));
      expect(en.prodSyncUpgradeReadyTitle(2), contains('2'));
      expect(ar.prodSyncUpgradeReadySub.isNotEmpty, true);
      expect(en.prodSyncUpgradeReadySub.isNotEmpty, true);

      // Safety Banner
      expect(ar.prodSyncSafetyGuaranteeTitle.isNotEmpty, true);
      expect(en.prodSyncSafetyGuaranteeTitle.isNotEmpty, true);
      expect(ar.prodSyncSafetyGuaranteeBody.isNotEmpty, true);
      expect(en.prodSyncSafetyGuaranteeBody.isNotEmpty, true);

      // Action Buttons
      expect(ar.prodSyncSyncNowBtn.isNotEmpty, true);
      expect(en.prodSyncSyncNowBtn.isNotEmpty, true);
      expect(ar.prodSyncUpgradeBtn.isNotEmpty, true);
      expect(en.prodSyncUpgradeBtn.isNotEmpty, true);
      expect(ar.prodSyncPullFromProdBtn.isNotEmpty, true);
      expect(en.prodSyncPullFromProdBtn.isNotEmpty, true);
      expect(ar.prodSyncCreateSnapshotBtn.isNotEmpty, true);
      expect(en.prodSyncCreateSnapshotBtn.isNotEmpty, true);
      expect(ar.prodSyncCreateDevSnapshotBtn.isNotEmpty, true);
      expect(en.prodSyncCreateDevSnapshotBtn.isNotEmpty, true);

      // Tables Comparison List
      expect(ar.prodSyncTablesMatchHeader(10, 20), contains('10'));
      expect(ar.prodSyncTablesMatchHeader(10, 20), contains('20'));
      expect(en.prodSyncTablesMatchHeader(10, 20), contains('10'));
      expect(en.prodSyncTablesMatchHeader(10, 20), contains('20'));
      expect(ar.prodSyncTablesUpgradeHeader(5, 20), contains('5'));
      expect(ar.prodSyncTablesUpgradeHeader(5, 20), contains('20'));
      expect(en.prodSyncTablesUpgradeHeader(5, 20), contains('5'));
      expect(en.prodSyncTablesUpgradeHeader(5, 20), contains('20'));
      expect(ar.prodSyncSearchTablesHint.isNotEmpty, true);
      expect(en.prodSyncSearchTablesHint.isNotEmpty, true);
      expect(ar.prodSyncDevRecordsCount(150), contains('150'));
      expect(en.prodSyncDevRecordsCount(150), contains('150'));
      expect(ar.prodSyncProdRecordsCount(120), contains('120'));
      expect(en.prodSyncProdRecordsCount(120), contains('120'));
      expect(ar.prodSyncTableStatusUpdated.isNotEmpty, true);
      expect(en.prodSyncTableStatusUpdated.isNotEmpty, true);

      // Backups View
      expect(ar.prodSyncBackupsSectionHeader.isNotEmpty, true);
      expect(en.prodSyncBackupsSectionHeader.isNotEmpty, true);
      expect(ar.prodSyncBackupsSectionSub.isNotEmpty, true);
      expect(en.prodSyncBackupsSectionSub.isNotEmpty, true);
      expect(ar.prodSyncBackupsDialogSub.isNotEmpty, true);
      expect(en.prodSyncBackupsDialogSub.isNotEmpty, true);
      expect(ar.prodSyncNoBackupsFound.isNotEmpty, true);
      expect(en.prodSyncNoBackupsFound.isNotEmpty, true);
      expect(ar.prodSyncNoBackupsDialogSub.isNotEmpty, true);
      expect(en.prodSyncNoBackupsDialogSub.isNotEmpty, true);
      expect(ar.prodSyncRestoreToProdBtn.isNotEmpty, true);
      expect(en.prodSyncRestoreToProdBtn.isNotEmpty, true);
      expect(ar.prodSyncRestoreToDevBtn.isNotEmpty, true);
      expect(en.prodSyncRestoreToDevBtn.isNotEmpty, true);
      expect(ar.prodSyncBackupCreatedAt('2026-08-24'), contains('2026-08-24'));
      expect(en.prodSyncBackupCreatedAt('2026-08-24'), contains('2026-08-24'));
      expect(ar.prodSyncBackupSize(512), contains('512'));
      expect(en.prodSyncBackupSize(512), contains('512'));
      expect(ar.prodSyncBackupTag('prod'), contains('prod'));
      expect(en.prodSyncBackupTag('prod'), contains('prod'));

      // Confirmation Dialogs & Errors
      expect(ar.prodSyncConfirmUpgradeTitle.isNotEmpty, true);
      expect(en.prodSyncConfirmUpgradeTitle.isNotEmpty, true);
      expect(ar.prodSyncConfirmUpgradeWhatHappens.isNotEmpty, true);
      expect(en.prodSyncConfirmUpgradeWhatHappens.isNotEmpty, true);
      expect(ar.prodSyncConfirmUpgradeWhatWontHappen.isNotEmpty, true);
      expect(en.prodSyncConfirmUpgradeWhatWontHappen.isNotEmpty, true);
      expect(ar.prodSyncConfirmUpgradeSubmitBtn.isNotEmpty, true);
      expect(en.prodSyncConfirmUpgradeSubmitBtn.isNotEmpty, true);
      expect(ar.prodSyncConfirmRestoreTitle.isNotEmpty, true);
      expect(en.prodSyncConfirmRestoreTitle.isNotEmpty, true);
      expect(ar.prodSyncConfirmRestoreMsg('الإنتاج'), contains('الإنتاج'));
      expect(en.prodSyncConfirmRestoreMsg('Production'), contains('Production'));
      expect(ar.prodSyncConfirmRestoreWarning.isNotEmpty, true);
      expect(en.prodSyncConfirmRestoreWarning.isNotEmpty, true);
      expect(ar.prodSyncConfirmRestoreSubmitBtn.isNotEmpty, true);
      expect(en.prodSyncConfirmRestoreSubmitBtn.isNotEmpty, true);
      expect(ar.prodSyncTargetProdLabel.isNotEmpty, true);
      expect(en.prodSyncTargetProdLabel.isNotEmpty, true);
      expect(ar.prodSyncTargetDevLabel.isNotEmpty, true);
      expect(en.prodSyncTargetDevLabel.isNotEmpty, true);
      expect(ar.prodSyncBackupCreatedSuccess('backup_01.db'), contains('backup_01.db'));
      expect(en.prodSyncBackupCreatedSuccess('backup_01.db'), contains('backup_01.db'));
      expect(ar.prodSyncSyncError('NetworkErr'), contains('NetworkErr'));
      expect(en.prodSyncSyncError('NetworkErr'), contains('NetworkErr'));
      expect(ar.prodSyncPullError('IOErr'), contains('IOErr'));
      expect(en.prodSyncPullError('IOErr'), contains('IOErr'));
      expect(ar.prodSyncRestoreError('RestoreErr'), contains('RestoreErr'));
      expect(en.prodSyncRestoreError('RestoreErr'), contains('RestoreErr'));
      expect(ar.prodSyncComparingDatabasesProgress.isNotEmpty, true);
      expect(en.prodSyncComparingDatabasesProgress.isNotEmpty, true);
      expect(ar.prodSyncErrorFetchingComparison('Fail'), contains('Fail'));
      expect(en.prodSyncErrorFetchingComparison('Fail'), contains('Fail'));

      // New Screen 59 exports, badges, and headers
      expect(ar.prodSyncExportTsvBtn.isNotEmpty, true);
      expect(en.prodSyncExportTsvBtn.isNotEmpty, true);
      expect(ar.prodSyncExportExcelBtn.isNotEmpty, true);
      expect(en.prodSyncExportExcelBtn.isNotEmpty, true);
      expect(ar.prodSyncExportPdfBtn.isNotEmpty, true);
      expect(en.prodSyncExportPdfBtn.isNotEmpty, true);
      expect(ar.prodSyncCopyDossierBtn.isNotEmpty, true);
      expect(en.prodSyncCopyDossierBtn.isNotEmpty, true);
      expect(ar.prodSyncCopyDossierSuccess.isNotEmpty, true);
      expect(en.prodSyncCopyDossierSuccess.isNotEmpty, true);
      expect(ar.prodSyncExportTsvSuccess.isNotEmpty, true);
      expect(en.prodSyncExportTsvSuccess.isNotEmpty, true);
      expect(ar.prodSyncExportExcelSuccess.isNotEmpty, true);
      expect(en.prodSyncExportExcelSuccess.isNotEmpty, true);
      expect(ar.prodSyncCopyRowSummaryBtn.isNotEmpty, true);
      expect(en.prodSyncCopyRowSummaryBtn.isNotEmpty, true);
      expect(ar.prodSyncCopyRowSummarySuccess.isNotEmpty, true);
      expect(en.prodSyncCopyRowSummarySuccess.isNotEmpty, true);
      expect(ar.prodSyncCopyFieldTooltip.isNotEmpty, true);
      expect(en.prodSyncCopyFieldTooltip.isNotEmpty, true);
      expect(ar.prodSyncVersionBadgeLabel.isNotEmpty, true);
      expect(en.prodSyncVersionBadgeLabel.isNotEmpty, true);
      expect(ar.prodSyncDevDbPathBadge.isNotEmpty, true);
      expect(en.prodSyncDevDbPathBadge.isNotEmpty, true);
      expect(ar.prodSyncProdDbPathBadge.isNotEmpty, true);
      expect(en.prodSyncProdDbPathBadge.isNotEmpty, true);
      expect(ar.prodSyncBackupTagBadge.isNotEmpty, true);
      expect(en.prodSyncBackupTagBadge.isNotEmpty, true);
      expect(ar.prodSyncBackupFilenameBadge.isNotEmpty, true);
      expect(en.prodSyncBackupFilenameBadge.isNotEmpty, true);
      expect(ar.prodSyncTsvHeaderTableName.isNotEmpty, true);
      expect(en.prodSyncTsvHeaderTableName.isNotEmpty, true);
      expect(ar.prodSyncTsvHeaderDevCount.isNotEmpty, true);
      expect(en.prodSyncTsvHeaderDevCount.isNotEmpty, true);
      expect(ar.prodSyncTsvHeaderProdCount.isNotEmpty, true);
      expect(en.prodSyncTsvHeaderProdCount.isNotEmpty, true);
      expect(ar.prodSyncTsvHeaderDiff.isNotEmpty, true);
      expect(en.prodSyncTsvHeaderDiff.isNotEmpty, true);
      expect(ar.prodSyncTsvHeaderStatus.isNotEmpty, true);
      expect(en.prodSyncTsvHeaderStatus.isNotEmpty, true);
      expect(ar.prodSyncTsvHeaderBackupFile.isNotEmpty, true);
      expect(en.prodSyncTsvHeaderBackupFile.isNotEmpty, true);
      expect(ar.prodSyncTsvHeaderBackupTag.isNotEmpty, true);
      expect(en.prodSyncTsvHeaderBackupTag.isNotEmpty, true);
      expect(ar.prodSyncTsvHeaderBackupSize.isNotEmpty, true);
      expect(en.prodSyncTsvHeaderBackupSize.isNotEmpty, true);
      expect(ar.prodSyncTsvHeaderBackupDate.isNotEmpty, true);
      expect(en.prodSyncTsvHeaderBackupDate.isNotEmpty, true);
      expect(ar.prodSyncScreenHeaderTitle.isNotEmpty, true);
      expect(en.prodSyncScreenHeaderTitle.isNotEmpty, true);
      expect(ar.prodSyncScreenHeaderSubtitle.isNotEmpty, true);
      expect(en.prodSyncScreenHeaderSubtitle.isNotEmpty, true);
      expect(ar.prodSyncRefreshSystemStatusTooltip.isNotEmpty, true);
      expect(en.prodSyncRefreshSystemStatusTooltip.isNotEmpty, true);
      expect(ar.prodSyncTabUpdatesAndBackups.isNotEmpty, true);
      expect(en.prodSyncTabUpdatesAndBackups.isNotEmpty, true);
      expect(ar.prodSyncTabDevToolsAndDiff.isNotEmpty, true);
      expect(en.prodSyncTabDevToolsAndDiff.isNotEmpty, true);
      expect(ar.prodSyncSystemUpToDateMsg.isNotEmpty, true);
      expect(en.prodSyncSystemUpToDateMsg.isNotEmpty, true);
      expect(ar.prodSyncCheckingCloudUpdates.isNotEmpty, true);
      expect(en.prodSyncCheckingCloudUpdates.isNotEmpty, true);
      expect(ar.prodSyncOfflineModeMsg.isNotEmpty, true);
      expect(en.prodSyncOfflineModeMsg.isNotEmpty, true);
      expect(ar.prodSyncCheckUpdatesBtn.isNotEmpty, true);
      expect(en.prodSyncCheckUpdatesBtn.isNotEmpty, true);
      expect(ar.prodSyncWhatsNewInVersion('1.0.53'), contains('1.0.53'));
      expect(en.prodSyncWhatsNewInVersion('1.0.53'), contains('1.0.53'));
      expect(ar.prodSyncSchemaEngineTitle.isNotEmpty, true);
      expect(en.prodSyncSchemaEngineTitle.isNotEmpty, true);
      expect(ar.prodSyncSchemaEngineDesc.isNotEmpty, true);
      expect(en.prodSyncSchemaEngineDesc.isNotEmpty, true);
      expect(ar.prodSyncCreateInstantBackupBtn.isNotEmpty, true);
      expect(en.prodSyncCreateInstantBackupBtn.isNotEmpty, true);
      expect(ar.prodSyncBackupsArchiveHeader(5), contains('5'));
      expect(en.prodSyncBackupsArchiveHeader(5), contains('5'));
      expect(ar.prodSyncRefreshListTooltip.isNotEmpty, true);
      expect(en.prodSyncRefreshListTooltip.isNotEmpty, true);
      expect(ar.prodSyncNoBackupsInFolder.isNotEmpty, true);
      expect(en.prodSyncNoBackupsInFolder.isNotEmpty, true);
      expect(ar.prodSyncAutoPreUpgradeTag.isNotEmpty, true);
      expect(en.prodSyncAutoPreUpgradeTag.isNotEmpty, true);
      expect(ar.prodSyncManualBackupTag.isNotEmpty, true);
      expect(en.prodSyncManualBackupTag.isNotEmpty, true);
      expect(ar.prodSyncRestoreActionBtn.isNotEmpty, true);
      expect(en.prodSyncRestoreActionBtn.isNotEmpty, true);
      expect(ar.prodSyncCompareTablesBtn.isNotEmpty, true);
      expect(en.prodSyncCompareTablesBtn.isNotEmpty, true);
      expect(ar.prodSyncDbNotFoundNotice.isNotEmpty, true);
      expect(en.prodSyncDbNotFoundNotice.isNotEmpty, true);
      expect(ar.prodSyncDbLastModified('2026-09-08'), contains('2026-09-08'));
      expect(en.prodSyncDbLastModified('2026-09-08'), contains('2026-09-08'));
      expect(ar.prodSyncDbSizeLabel(1024), contains('1024'));
      expect(en.prodSyncDbSizeLabel(1024), contains('1024'));
      expect(ar.prodSyncConfirmRestoreTitleDialog.isNotEmpty, true);
      expect(en.prodSyncConfirmRestoreTitleDialog.isNotEmpty, true);
      expect(ar.prodSyncConfirmRestoreMsgDialog('test.db'), contains('test.db'));
      expect(en.prodSyncConfirmRestoreMsgDialog('test.db'), contains('test.db'));
      expect(ar.prodSyncConfirmRestoreSafeNotice.isNotEmpty, true);
      expect(en.prodSyncConfirmRestoreSafeNotice.isNotEmpty, true);
      expect(ar.prodSyncCancelAction.isNotEmpty, true);
      expect(en.prodSyncCancelAction.isNotEmpty, true);
      expect(ar.prodSyncRestoreNowAction.isNotEmpty, true);
      expect(en.prodSyncRestoreNowAction.isNotEmpty, true);
      expect(ar.prodSyncActionStarting('Test'), contains('Test'));
      expect(en.prodSyncActionStarting('Test'), contains('Test'));
      expect(ar.prodSyncActionSuccess('Test'), contains('Test'));
      expect(en.prodSyncActionSuccess('Test'), contains('Test'));
      expect(ar.prodSyncActionFailed('Test'), contains('Test'));
      expect(en.prodSyncActionFailed('Test'), contains('Test'));
      expect(ar.prodSyncActionUnexpectedErr('Err'), contains('Err'));
      expect(en.prodSyncActionUnexpectedErr('Err'), contains('Err'));
      expect(ar.prodSyncDiffStatusNewRecords(3), contains('3'));
      expect(en.prodSyncDiffStatusNewRecords(3), contains('3'));
      expect(ar.prodSyncDiffStatusNewTable.isNotEmpty, true);
      expect(en.prodSyncDiffStatusNewTable.isNotEmpty, true);
      expect(ar.prodSyncDiffStatusProdSurplus(4), contains('4'));
      expect(en.prodSyncDiffStatusProdSurplus(4), contains('4'));
      expect(ar.prodSyncDiffStatusMatched.isNotEmpty, true);
      expect(en.prodSyncDiffStatusMatched.isNotEmpty, true);
      expect(ar.prodSyncDiffFilterModified.isNotEmpty, true);
      expect(en.prodSyncDiffFilterModified.isNotEmpty, true);
      expect(ar.prodSyncDiffFilterAll(10), contains('10'));
      expect(en.prodSyncDiffFilterAll(10), contains('10'));
      expect(ar.prodSyncDiffFilterMatched.isNotEmpty, true);
      expect(en.prodSyncDiffFilterMatched.isNotEmpty, true);
      expect(ar.prodSyncDiffPanelTitle.isNotEmpty, true);
      expect(en.prodSyncDiffPanelTitle.isNotEmpty, true);
      expect(ar.prodSyncDiffPanelSubtitle.isNotEmpty, true);
      expect(en.prodSyncDiffPanelSubtitle.isNotEmpty, true);
      expect(ar.prodSyncDiffCheckBtn.isNotEmpty, true);
      expect(en.prodSyncDiffCheckBtn.isNotEmpty, true);
      expect(ar.prodSyncDiffEmptyInstruction.isNotEmpty, true);
      expect(en.prodSyncDiffEmptyInstruction.isNotEmpty, true);
      expect(ar.prodSyncDiffAllMatchedSuccess.isNotEmpty, true);
      expect(en.prodSyncDiffAllMatchedSuccess.isNotEmpty, true);
      expect(ar.prodSyncDiffNoSearchResults.isNotEmpty, true);
      expect(en.prodSyncDiffNoSearchResults.isNotEmpty, true);
      expect(ar.prodSyncTerminalTitle.isNotEmpty, true);
      expect(en.prodSyncTerminalTitle.isNotEmpty, true);
      expect(ar.prodSyncTerminalReadyMsg.isNotEmpty, true);
      expect(en.prodSyncTerminalReadyMsg.isNotEmpty, true);
      expect(ar.prodSyncTerminalRunningMsg.isNotEmpty, true);
      expect(en.prodSyncTerminalRunningMsg.isNotEmpty, true);
      expect(ar.prodSyncTerminalCopyTooltip.isNotEmpty, true);
      expect(en.prodSyncTerminalCopyTooltip.isNotEmpty, true);
      expect(ar.prodSyncTerminalClearTooltip.isNotEmpty, true);
      expect(en.prodSyncTerminalClearTooltip.isNotEmpty, true);
      expect(ar.prodSyncTerminalCopiedToast.isNotEmpty, true);
      expect(en.prodSyncTerminalCopiedToast.isNotEmpty, true);
      expect(ar.prodSyncProgressTablesCount(5, 10, 50), contains('5'));
      expect(en.prodSyncProgressTablesCount(5, 10, 50), contains('5'));
    });

    test('Arabic translations contain pure Arabic text without Latin characters', () {
      final latinRegex = RegExp(r'[a-zA-Z]');

      final pureArabicStaticStrings = [
        ar.prodSyncScreenTitle,
        ar.prodSyncScreenSubtitle,
        ar.prodSyncHubDialogTitle,
        ar.prodSyncHubDialogSubtitle,
        ar.prodSyncTabCompareTables,
        ar.prodSyncTabSchemaUpgrade,
        ar.prodSyncTabSafetyBackups,
        ar.prodSyncDevDbTitle,
        ar.prodSyncDevDbSubtitle,
        ar.prodSyncDevDbUpgradeSub,
        ar.prodSyncProdDbTitle,
        ar.prodSyncProdDbSubtitle,
        ar.prodSyncProdDbUpgradeSub,
        ar.prodSyncFullySynchronizedSub,
        ar.prodSyncDifferencesDetectedSub,
        ar.prodSyncUpgradeReadySub,
        ar.prodSyncSafetyGuaranteeTitle,
        ar.prodSyncSafetyGuaranteeBody,
        ar.prodSyncSyncNowBtn,
        ar.prodSyncUpgradeBtn,
        ar.prodSyncPullFromProdBtn,
        ar.prodSyncCreateSnapshotBtn,
        ar.prodSyncCreateDevSnapshotBtn,
        ar.prodSyncSearchTablesHint,
        ar.prodSyncTableStatusUpdated,
        ar.prodSyncBackupsSectionHeader,
        ar.prodSyncBackupsSectionSub,
        ar.prodSyncBackupsDialogSub,
        ar.prodSyncNoBackupsFound,
        ar.prodSyncNoBackupsDialogSub,
        ar.prodSyncRestoreToProdBtn,
        ar.prodSyncRestoreToDevBtn,
        ar.prodSyncConfirmUpgradeTitle,
        ar.prodSyncConfirmUpgradeWhatHappens,
        ar.prodSyncConfirmUpgradeWhatWontHappen,
        ar.prodSyncConfirmUpgradeSubmitBtn,
        ar.prodSyncConfirmRestoreTitle,
        ar.prodSyncConfirmRestoreWarning,
        ar.prodSyncConfirmRestoreSubmitBtn,
        ar.prodSyncTargetProdLabel,
        ar.prodSyncTargetDevLabel,
        ar.prodSyncComparingDatabasesProgress,
        ar.prodSyncExportTsvBtn,
        ar.prodSyncExportExcelBtn,
        ar.prodSyncExportPdfBtn,
        ar.prodSyncCopyDossierBtn,
        ar.prodSyncCopyDossierSuccess,
        ar.prodSyncExportTsvSuccess,
        ar.prodSyncExportExcelSuccess,
        ar.prodSyncCopyRowSummaryBtn,
        ar.prodSyncCopyRowSummarySuccess,
        ar.prodSyncCopyFieldTooltip,
        ar.prodSyncVersionBadgeLabel,
        ar.prodSyncDevDbPathBadge,
        ar.prodSyncProdDbPathBadge,
        ar.prodSyncBackupTagBadge,
        ar.prodSyncBackupFilenameBadge,
        ar.prodSyncTsvHeaderTableName,
        ar.prodSyncTsvHeaderDevCount,
        ar.prodSyncTsvHeaderProdCount,
        ar.prodSyncTsvHeaderDiff,
        ar.prodSyncTsvHeaderStatus,
        ar.prodSyncTsvHeaderBackupFile,
        ar.prodSyncTsvHeaderBackupTag,
        ar.prodSyncTsvHeaderBackupSize,
        ar.prodSyncTsvHeaderBackupDate,
        ar.prodSyncScreenHeaderTitle,
        ar.prodSyncScreenHeaderSubtitle,
        ar.prodSyncRefreshSystemStatusTooltip,
        ar.prodSyncTabUpdatesAndBackups,
        ar.prodSyncTabDevToolsAndDiff,
        ar.prodSyncSystemUpToDateMsg,
        ar.prodSyncCheckingCloudUpdates,
        ar.prodSyncOfflineModeMsg,
        ar.prodSyncCheckUpdatesBtn,
        ar.prodSyncSchemaEngineTitle,
        ar.prodSyncSchemaEngineDesc,
        ar.prodSyncCreateInstantBackupBtn,
        ar.prodSyncRefreshListTooltip,
        ar.prodSyncNoBackupsInFolder,
        ar.prodSyncAutoPreUpgradeTag,
        ar.prodSyncManualBackupTag,
        ar.prodSyncRestoreActionBtn,
        ar.prodSyncCompareTablesBtn,
        ar.prodSyncDbNotFoundNotice,
        ar.prodSyncConfirmRestoreTitleDialog,
        ar.prodSyncConfirmRestoreSafeNotice,
        ar.prodSyncCancelAction,
        ar.prodSyncRestoreNowAction,
        ar.prodSyncDiffStatusNewTable,
        ar.prodSyncDiffStatusMatched,
        ar.prodSyncDiffFilterModified,
        ar.prodSyncDiffFilterMatched,
        ar.prodSyncDiffPanelTitle,
        ar.prodSyncDiffPanelSubtitle,
        ar.prodSyncDiffCheckBtn,
        ar.prodSyncDiffEmptyInstruction,
        ar.prodSyncDiffAllMatchedSuccess,
        ar.prodSyncDiffNoSearchResults,
        ar.prodSyncTerminalTitle,
        ar.prodSyncTerminalReadyMsg,
        ar.prodSyncTerminalRunningMsg,
        ar.prodSyncTerminalCopyTooltip,
        ar.prodSyncTerminalClearTooltip,
        ar.prodSyncTerminalCopiedToast,
        ar.prodSyncProgressTablesCount('', '', ''),
      ];

      for (final text in pureArabicStaticStrings) {
        expect(
          latinRegex.hasMatch(text),
          false,
          reason: 'String "$text" contains English/Latin characters!',
        );
      }
    });

    test('No stacked bilingual text is present in static labels', () {
      expect(ar.prodSyncScreenTitle.contains('('), false);
      expect(ar.prodSyncTabCompareTables.contains('('), false);
      expect(ar.prodSyncTabSafetyBackups.contains('('), false);
      expect(ar.prodSyncDevDbTitle.contains('('), false);
      expect(ar.prodSyncProdDbTitle.contains('('), false);
      expect(ar.prodSyncCreateSnapshotBtn.contains('('), false);
      expect(ar.prodSyncPullFromProdBtn.contains('('), false);
    });
  });
}
