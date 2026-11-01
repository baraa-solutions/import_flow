import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../../smart_tasks/providers/smart_tasks_provider.dart';
import '../../models/import_documentation_model.dart';
import '../../providers/docs_customs_approval_provider.dart';
import '../../providers/import_documentation_provider.dart';
import '../idoc_feedback.dart';

/// Workflow service handling checklist debounced synchronization, single-step approval,
/// and dual sign-off submissions for Maritime Draft B/L.
class DraftBlWorkflowService {
  final WidgetRef ref;
  Timer? _checklistDebounce;
  bool _checklistSyncing = false;
  bool _checklistSyncQueued = false;

  DraftBlWorkflowService(this.ref);

  static void updateRow(
    DraftBLComparisonResultModel? comparison,
    int idx, {
    dynamic draftValue,
    String? status,
    String? correction,
    String? reason,
    String? respParty,
  }) {
    if (comparison == null || idx < 0 || idx >= comparison.checklist.length) return;
    final old = comparison.checklist[idx];
    final newDraft = draftValue ?? old.draftValue;
    String newStatus = status ?? old.status;
    if (draftValue != null && status == null) {
      final sysStr = (old.systemValue?.toString() ?? '').trim().toLowerCase();
      final draftStr = (newDraft?.toString() ?? '').trim().toLowerCase();
      if (draftStr.isNotEmpty && sysStr == draftStr) {
        newStatus = 'Correct';
      } else if (draftStr.isNotEmpty && sysStr != draftStr) {
        newStatus = 'Incorrect';
      }
    }
    comparison.checklist[idx] = DraftBLChecklistItemModel(
      fieldKey: old.fieldKey, fieldLabelAr: old.fieldLabelAr, fieldLabelEn: old.fieldLabelEn, sourceEntity: old.sourceEntity,
      systemValue: old.systemValue, draftValue: newDraft, status: newStatus, requiredCorrection: correction ?? (newStatus == 'Correct' ? null : old.requiredCorrection),
      reason: reason ?? old.reason, reasonCode: reason != null ? null : old.reasonCode, reasonParams: reason != null ? null : old.reasonParams,
      notes: old.notes, responsibleParty: respParty ?? old.responsibleParty, isLocked: old.isLocked, previousStatus: old.previousStatus,
    );
  }

  void dispose() {
    _checklistDebounce?.cancel();
  }

  void scheduleChecklistSync(
    BuildContext context, {
    required DraftBLReviewModel? activeSession,
    required DraftBLComparisonResultModel? comparisonResult,
    required ValueChanged<DraftBLReviewModel> onSessionUpdated,
  }) {
    if (activeSession == null || comparisonResult == null) return;
    _checklistDebounce?.cancel();
    _checklistDebounce = Timer(const Duration(milliseconds: 600), () {
      _syncChecklist(
        context,
        activeSession: activeSession,
        comparisonResult: comparisonResult,
        onSessionUpdated: onSessionUpdated,
      );
    });
  }

  Future<void> _syncChecklist(
    BuildContext context, {
    required DraftBLReviewModel activeSession,
    required DraftBLComparisonResultModel comparisonResult,
    required ValueChanged<DraftBLReviewModel> onSessionUpdated,
  }) async {
    if (!context.mounted) return;
    if (_checklistSyncing) {
      _checklistSyncQueued = true;
      return;
    }
    final items = comparisonResult.checklist;
    final isComplete = items.every((i) =>
        i.status != 'Incorrect' ||
        ((i.requiredCorrection ?? '').trim().isNotEmpty &&
            ((i.reason ?? '').trim().isNotEmpty || (i.reasonCode ?? '').isNotEmpty)));
    if (!isComplete) return;

    _checklistSyncing = true;
    try {
      final updated = await ref.read(draftBLReviewsProvider.notifier).updateDraftBLChecklist(
            activeSession.blReviewId,
            List<DraftBLChecklistItemModel>.of(items),
            reviewerName: idocCurrentUserName(ref),
          );
      if (context.mounted) onSessionUpdated(updated);
    } catch (e) {
      if (context.mounted) showIdocError(context, e, title: context.l10n.idocAChecklistSaveFailed);
    } finally {
      _checklistSyncing = false;
      if (context.mounted && _checklistSyncQueued) {
        _checklistSyncQueued = false;
        scheduleChecklistSync(
          context,
          activeSession: activeSession,
          comparisonResult: comparisonResult,
          onSessionUpdated: onSessionUpdated,
        );
      }
    }
  }

  Future<DraftBLReviewModel?> approveSingleStep(
    BuildContext context, {
    required DraftBLReviewModel session,
    required VoidCallback onFinalStageReached,
  }) async {
    try {
      final updated = await ref.read(draftBLReviewsProvider.notifier).approveDraftBL(
            session.blReviewId,
            approvedBy: idocCurrentUserName(ref),
          );
      if (!context.mounted) return null;
      if (updated.stage == 'Stage 5: Final') {
        showIdocMessage(context, context.l10n.draftBlDualApprovalCompleted);
        onFinalStageReached();
      }
      return updated;
    } catch (e) {
      if (context.mounted) showIdocError(context, e, title: context.l10n.draftBlApprovalError(''));
      return null;
    }
  }

  Future<DraftBLReviewModel?> submitApproval(
    BuildContext context, {
    required DraftBLReviewModel session,
    required String role,
    required String action,
    required String approver,
    String? notes,
    required VoidCallback onFinalStageReached,
    required VoidCallback onRejected,
  }) async {
    try {
      final updated = await ref.read(draftBLReviewsProvider.notifier).submitDualApproval(
            session.blReviewId,
            role,
            action,
            approver,
            notes: notes,
          );
      ref.invalidate(importFilesProvider);
      ref.invalidate(docsCustomsApprovalProvider);
      ref.invalidate(smartTasksProvider);

      if (context.mounted) {
        if (updated.stage == 'Stage 5: Final') {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, context.l10n.draftBlDualApprovalCompleted, severity: AppSeverity.info),
          );
          onFinalStageReached();
        } else if (action == 'Rejected') {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, context.l10n.draftBlRevisionRequiredAlert, severity: AppSeverity.info),
          );
          onRejected();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, context.l10n.draftBlRoleApprovalRegistered(role), severity: AppSeverity.info),
          );
        }
      }
      return updated;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, context.l10n.draftBlApprovalError(ApiErrorText.of(context.l10n, e)), severity: AppSeverity.info),
        );
      }
      return null;
    }
  }
}
