import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../import_files/models/import_file_model.dart';
import '../../models/po_reconciliation_session_model.dart';
import 'dialogs/reconciliation_print_report_dialog.dart';
import 'dialogs/reconciliation_session_details_modal.dart';
import 'dialogs/reconciliation_session_lifecycle_dialogs.dart';
import 'dialogs/reconciliation_validation_dialogs.dart';

export 'dialogs/reconciliation_print_report_dialog.dart';
export 'dialogs/reconciliation_session_details_modal.dart';
export 'dialogs/reconciliation_session_lifecycle_dialogs.dart';
export 'dialogs/reconciliation_validation_dialogs.dart';

/// Modal dialogs and confirmation alerts for PO Reconciliation.
class PoReconciliationDialogs {
  static Widget buildSessionStatusBadge(BuildContext context, String status) =>
      ReconciliationSessionDetailsModal.buildSessionStatusBadge(context, status);

  static void showInputValidationDialog(
    BuildContext context, {
    required String title,
    required List<String> issues,
    required List<String> recommendations,
  }) =>
      ReconciliationValidationDialogs.showInputValidationDialog(
        context,
        title: title,
        issues: issues,
        recommendations: recommendations,
      );

  static void showSaveSuccessReportDialog(
    BuildContext context,
    POReconciliationSessionModel sess, {
    required List<ImportFileModel> importFiles,
    required VoidCallback onPrintReport,
  }) =>
      ReconciliationValidationDialogs.showSaveSuccessReportDialog(
        context,
        sess,
        importFiles: importFiles,
        onPrintReport: onPrintReport,
      );

  static Future<bool?> showVarianceAlertConfirmDialog(BuildContext context) =>
      ReconciliationValidationDialogs.showVarianceAlertConfirmDialog(context);

  static void showSessionDetailsModal(
    BuildContext context,
    POReconciliationSessionModel sess, {
    required List<ImportFileModel> importFiles,
    required ValueChanged<POReconciliationSessionModel> onLoadIntoEditor,
  }) =>
      ReconciliationSessionDetailsModal.show(
        context,
        sess,
        importFiles: importFiles,
        onLoadIntoEditor: onLoadIntoEditor,
      );

  static void showPrintReportDialog(
    BuildContext context,
    POReconciliationSessionModel sess, {
    required List<ImportFileModel> importFiles,
    required String Function(BuildContext context, String status) getLocalizedSessionStatus,
  }) =>
      ReconciliationPrintReportDialog.show(
        context,
        sess,
        importFiles: importFiles,
        getLocalizedSessionStatus: getLocalizedSessionStatus,
      );

  static Future<bool?> confirmDeleteSession(BuildContext context, POReconciliationSessionModel sess) =>
      ReconciliationSessionLifecycleDialogs.confirmDeleteSession(context, sess);

  static Future<bool?> showExistingSessionConfirmDialog(
    BuildContext context, {
    required String statusLabel,
    required String updater,
    required String updatedTime,
    required String sessionCode,
  }) =>
      ReconciliationSessionLifecycleDialogs.showExistingSessionConfirmDialog(
        context,
        statusLabel: statusLabel,
        updater: updater,
        updatedTime: updatedTime,
        sessionCode: sessionCode,
      );

  static Future<bool?> showExistingSessionNoticeDialog(
    BuildContext context,
    POReconciliationSessionModel existing, {
    required String statusLabel,
    required String updater,
    required String updatedTime,
  }) =>
      ReconciliationSessionLifecycleDialogs.showExistingSessionNoticeDialog(
        context,
        existing,
        statusLabel: statusLabel,
        updater: updater,
        updatedTime: updatedTime,
      );

  static Future<POReconciliationSessionModel?> promptExistingSessionIfAny({
    required BuildContext context,
    required WidgetRef ref,
    required int fileId,
  }) =>
      ReconciliationSessionLifecycleDialogs.promptExistingSessionIfAny(
        context: context,
        ref: ref,
        fileId: fileId,
      );

  static Future<void> deleteSessionWithConfirmation({
    required BuildContext context,
    required WidgetRef ref,
    required POReconciliationSessionModel sess,
  }) =>
      ReconciliationSessionLifecycleDialogs.deleteSessionWithConfirmation(
        context: context,
        ref: ref,
        sess: sess,
      );
}
