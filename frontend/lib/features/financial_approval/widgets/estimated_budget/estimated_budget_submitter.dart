import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';
import 'estimated_budget_dialogs.dart';
import 'estimated_budget_form_state.dart';

abstract final class EstimatedBudgetSubmitter {
  static bool _isVersionConflict(Object e) {
    if (e is! DioException || e.response?.statusCode != 409) return false;
    final data = e.response?.data;
    final detail = (data is Map)
        ? (data['detail'] is Map ? data['detail'] as Map : data)
        : const {};
    return detail.containsKey('current_version') ||
        detail.containsKey('submitted_version');
  }

  static bool _isCodedError(Object e) {
    if (e is! DioException) return false;
    final data = e.response?.data;
    return data is Map && data['detail'] is Map;
  }

  static void _showApiError(BuildContext context, Object e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, ApiError.message(e),
          severity: AppSeverity.danger),
    );
  }

  static Future<ImportBudgetModel?> persistBudget({
    required BuildContext context,
    required WidgetRef ref,
    required EstimatedBudgetFormState state,
    required VoidCallback notify,
    required Future<void> Function() onRetrySave,
  }) async {
    if (!state.formKey.currentState!.validate()) return null;

    final rateInput =
        double.tryParse(state.exchangeRateController.text.trim());
    if (rateInput == null || rateInput <= 0) {
      state.warnFxMissing(context, state.invoiceCurrency);
      return null;
    }
    final frtForeign =
        double.tryParse(state.freightForeignController.text.trim()) ?? 0.0;
    if (frtForeign > 0) {
      final frtRateInput =
          double.tryParse(state.freightRateController.text.trim());
      if (frtRateInput == null || frtRateInput <= 0) {
        state.warnFxMissing(context, state.freightCurrency);
        return null;
      }
    }

    state.isSaving = true;
    notify();

    final payload = state.buildPayload(rateInput);

    try {
      if (state.editingBudgetId != null) {
        if (state.editingBudgetVersion != null) {
          payload['version'] = state.editingBudgetVersion;
        }
        final updated = await ref
            .read(importBudgetsProvider.notifier)
            .updateImportBudget(state.editingBudgetId!, payload);
        if (context.mounted && updated != null) {
          state.lastSavedBudget = updated;
          state.editingBudgetId = null;
          state.editingBudgetVersion = null;
          notify();
          return updated;
        }
      } else {
        final created = await ref
            .read(importBudgetsProvider.notifier)
            .createImportBudget(payload);
        if (context.mounted && created != null) {
          state.lastSavedBudget = created;
          notify();
          return created;
        }
      }
    } catch (e) {
      if (_isVersionConflict(e)) {
        final data = (e as DioException).response?.data;
        final conflict = (data is Map<String, dynamic> && data['detail'] is Map)
            ? Map<String, dynamic>.from(data['detail'] as Map)
            : (data is Map<String, dynamic> ? data : <String, dynamic>{});
        if (context.mounted) {
          final resolution =
              await EstimatedBudgetDialogs.showConcurrencyConflict(
            context: context,
            conflict: conflict,
            editingBudgetId: state.editingBudgetId,
            editingBudgetVersion: state.editingBudgetVersion,
            currentDraftData: payload,
          );
          if (context.mounted &&
              resolution == ConcurrencyResolution.discardAndReload) {
            state.editingBudgetId = null;
            state.editingBudgetVersion = null;
            notify();
            await ref.read(importBudgetsProvider.notifier).fetchImportBudgets();
          }
        }
        return null;
      }
      if (context.mounted && _isCodedError(e)) {
        _showApiError(context, e);
      } else if (context.mounted) {
        await EstimatedBudgetDialogs.showSaveError(
          context: context,
          error: e,
          onRetry: onRetrySave,
        );
      }
      return null;
    } finally {
      if (context.mounted) {
        state.isSaving = false;
        notify();
      }
    }
    return null;
  }

  static Future<void> saveImportBudget({
    required BuildContext context,
    required WidgetRef ref,
    required EstimatedBudgetFormState state,
    required VoidCallback notify,
  }) async {
    final isUpdate = state.editingBudgetId != null;
    final bgt = await persistBudget(
      context: context,
      ref: ref,
      state: state,
      notify: notify,
      onRetrySave: () => saveImportBudget(
        context: context,
        ref: ref,
        state: state,
        notify: notify,
      ),
    );
    if (bgt != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          isUpdate
              ? context.l10n.budgetUpdatedSuccess(bgt.budgetCode)
              : context.l10n.budgetCreatedSuccess(bgt.budgetCode),
          severity: AppSeverity.success,
        ),
      );
      EstimatedBudgetDialogs.showBudgetDetails(
        context: context,
        budget: bgt,
        prefill: state.prefillData,
        onEditBudget: () => state.loadBudgetForEdit(context, ref, bgt, notify),
      );
    }
  }

  static Future<void> saveAndApproveBudget({
    required BuildContext context,
    required WidgetRef ref,
    required EstimatedBudgetFormState state,
    required VoidCallback notify,
  }) async {
    final saved = await persistBudget(
      context: context,
      ref: ref,
      state: state,
      notify: notify,
      onRetrySave: () => saveAndApproveBudget(
        context: context,
        ref: ref,
        state: state,
        notify: notify,
      ),
    );
    if (saved == null || !context.mounted) return;
    try {
      state.isSaving = true;
      notify();
      final approved = await ref
          .read(importBudgetsProvider.notifier)
          .approveImportBudget(saved.budgetId);
      if (context.mounted && approved != null) {
        state.lastSavedBudget = approved;
        notify();
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.budgetApprovedSuccess(approved.budgetCode),
            severity: AppSeverity.success,
          ),
        );
        EstimatedBudgetDialogs.showBudgetDetails(
          context: context,
          budget: approved,
          prefill: state.prefillData,
          onEditBudget: () =>
              state.loadBudgetForEdit(context, ref, approved, notify),
        );
      }
    } catch (e) {
      if (context.mounted) _showApiError(context, e);
    } finally {
      if (context.mounted) {
        state.isSaving = false;
        notify();
      }
    }
  }
}
