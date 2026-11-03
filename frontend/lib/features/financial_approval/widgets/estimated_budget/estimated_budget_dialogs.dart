import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../models/financial_approval_model.dart';
import '../budget_details_dialog.dart';
import '../dialogs/clone_budget_review_dialog.dart';
import '../duplicate_budget_dialog.dart';
import '../search_and_clone_budget_dialog.dart';

abstract final class EstimatedBudgetDialogs {
  static void showDuplicateBudget({
    required BuildContext context,
    required ImportBudgetModel existingBudget,
    required VoidCallback onCancelSelection,
    required VoidCallback onReviewSyncLiveCosts,
    required VoidCallback onViewAndPrintBudget,
  }) {
    DuplicateBudgetDialog.show(
      context,
      existingBudget: existingBudget,
      onCancelSelection: onCancelSelection,
      onReviewSyncLiveCosts: onReviewSyncLiveCosts,
      onViewAndPrintBudget: onViewAndPrintBudget,
    );
  }

  static void showSearchAndClone({
    required BuildContext context,
    required List<ImportBudgetModel> budgets,
    required void Function(ImportBudgetModel) onSelectBudget,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: SearchAndCloneBudgetDialog(
            budgets: budgets,
            onSelectBudget: onSelectBudget,
          ),
        ),
      ),
    );
  }

  static void showCloneReview({
    required BuildContext context,
    required WidgetRef ref,
    required ImportBudgetModel budget,
    required void Function(ImportBudgetModel) onCloned,
  }) {
    CloneBudgetReviewDialog.show(
      context: context,
      ref: ref,
      budget: budget,
      onCloned: onCloned,
    );
  }

  static void showBudgetDetails({
    required BuildContext context,
    required ImportBudgetModel budget,
    BudgetPrefillModel? prefill,
    required VoidCallback onEditBudget,
  }) {
    BudgetDetailsDialog.show(
      context,
      budget: budget,
      prefill:
          prefill?.importFileId == budget.importFileId ? prefill : null,
      onEditBudget: onEditBudget,
    );
  }

  static Future<ConcurrencyResolution?> showConcurrencyConflict({
    required BuildContext context,
    required Map<String, dynamic> conflict,
    required int? editingBudgetId,
    required int? editingBudgetVersion,
    required Map<String, dynamic> currentDraftData,
  }) {
    return ConcurrencyConflictDialog.show(
      context,
      entityName: conflict['entity'] as String? ?? 'ImportBudgetApproval',
      recordId: conflict['record_id'] ?? editingBudgetId,
      currentVersion: (conflict['current_version'] as num?)?.toInt() ??
          ((editingBudgetVersion ?? 1) + 1),
      submittedVersion: (conflict['submitted_version'] as num?)?.toInt() ??
          (editingBudgetVersion ?? 1),
      updatedAt: conflict['updated_at'] as String?,
      updatedBy: conflict['updated_by'] as String?,
      serverMessage: conflict['message'] as String?,
      currentDraftData: currentDraftData,
    );
  }

  static Future<void> showSaveError({
    required BuildContext context,
    required Object error,
    required Future<void> Function() onRetry,
  }) {
    return showErrorDetailsDialog(
      context,
      title: context.l10n.saveBudgetFailedTitle,
      error: error,
      onRetry: onRetry,
    );
  }
}
