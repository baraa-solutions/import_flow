import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../financial_approval/providers/financial_approval_provider.dart';
import '../../models/customs_consultation_model.dart';
import '../../providers/customs_consultation_provider.dart';
import '../../utils/customs_consultation_payload_builder.dart';
import '../post_save_status_dialog.dart';
import 'consultation_calc_logic_helper.dart';

/// Handles validation, diff-confirmation, mutations, and post-save workflows.
class ConsultationCalcSaveHelper {
  static Future<void> saveConsultation({
    required BuildContext context,
    required WidgetRef ref,
    required GlobalKey<FormState> formKey,
    required String title,
    required bool isTaxReviewMode,
    required int? selectedBrokerId,
    required String selectedBrokerName,
    required String? brokerContactPerson,
    required int? brokerPriceListId,
    required int? selectedImportFileId,
    required int? selectedPoId,
    required int? selectedProjectId,
    required double? fxRate,
    required bool isEstimatingDuty,
    required List<CustomsItemCalcRow> rawCalcLines,
    required double? engineGrandTotal,
    required String? currentEstimateCacheKey,
    required TextEditingController estimatedDutiesController,
    required TextEditingController notesController,
    required List<CustomsChecklistItemModel> checklist,
    required List<CustomsBrokerQuoteItemModel> brokerQuoteItems,
    required int? editingConsultationId,
    required String? editingConsultationCode,
    required void Function(bool isSaving) setSaving,
    required void Function(CustomsConsultationModel saved) onSavedSuccess,
    required void Function(CustomsConsultationModel existing) loadConsultation,
  }) async {
    final l = context.l10n;

    if (fxRate == null || fxRate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.customsFxRateRequired,
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    if (isEstimatingDuty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          'يرجى الانتظار حتى انتهاء حساب الرسوم الجمركية من محرك الجمارك.',
          severity: AppSeverity.warning,
        ),
      );
      return;
    }

    if (rawCalcLines.any((l) => l.isTariffMissing)) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.customsMissingTariffBlockSave,
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    if ((selectedImportFileId != null || selectedPoId != null) &&
        (engineGrandTotal == null ||
            currentEstimateCacheKey == null ||
            rawCalcLines.any((l) => !l.isCalculated))) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          'لم يتم حساب تقدير الرسوم الجمركية بعد بواسطة محرك الجمارك.',
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    final validationErrors = ConsultationCalcLogicHelper.validateConsultationForm(
      title: title,
      isTaxReviewMode: isTaxReviewMode,
      selectedBrokerId: selectedBrokerId,
      checklist: checklist,
      l: l,
    );

    if (validationErrors.isNotEmpty) {
      formKey.currentState?.validate();
      await showErrorDetailsDialog(
        context,
        title: '⚠️ ${l.customsStudyValidationAlertsTitle}',
        error: l.completeRequiredDataErrorMsg,
        validationIssues: validationErrors,
      );
      return;
    }

    final estimatedDuties = engineGrandTotal ??
        (double.tryParse(estimatedDutiesController.text.trim()) ?? 0.0);
    final totalBrokerFees = isTaxReviewMode
        ? 0.0
        : brokerQuoteItems.fold(
            0.0, (sum, itm) => sum + (itm.isApplicable ? itm.totalAmount : 0.0));

    // Confirm field diffs if editing
    if (editingConsultationId != null) {
      final oldConsultation = (ref.read(customsConsultationsProvider).valueOrNull ?? [])
          .where((c) => c.consultationId == editingConsultationId)
          .firstOrNull;

      if (oldConsultation != null) {
        final changes = ConsultationCalcLogicHelper.buildFieldChangesDiff(
          oldConsultation: oldConsultation,
          titleToSave: title,
          selectedBrokerName: selectedBrokerName,
          estimatedDuties: estimatedDuties,
          selectedImportFileId: selectedImportFileId,
          checklistLength: checklist.length,
          l: l,
        );

        if (changes.isNotEmpty) {
          final confirmed = await showChangeDiffConfirmationDialog(
            context,
            title: l.reviewCustomsStudyDiffTitle,
            itemReference: editingConsultationCode ?? title,
            changes: changes,
          );
          if (!confirmed) return;
        }
      }
    }

    setSaving(true);
    try {
      final payload = CustomsConsultationPayloadBuilder.buildSavePayload(
        title: title,
        brokerId: selectedBrokerId,
        brokerName: selectedBrokerName,
        brokerContactPerson: brokerContactPerson,
        brokerPriceListId: brokerPriceListId,
        importFileId: selectedImportFileId,
        poId: selectedPoId,
        projectId: selectedProjectId,
        estimatedDutiesEgp: estimatedDuties,
        totalBrokerFeesEgp: totalBrokerFees,
        notes: notesController.text.trim(),
        checklistItems: checklist.map((item) => item.toJson()).toList(),
        brokerQuoteItems: brokerQuoteItems.map((item) => item.toJson()).toList(),
        isTaxReviewMode: isTaxReviewMode,
      );

      if (editingConsultationId != null) {
        final updated = await ref
            .read(customsConsultationsProvider.notifier)
            .updateConsultation(editingConsultationId, payload);
        if (context.mounted && updated != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              '${l.customsStudyUpdatedSuccess} (${updated.consultationCode})',
              severity: AppSeverity.success,
            ),
          );
          onSavedSuccess(updated);
          Future.delayed(const Duration(milliseconds: 400), () {
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (ctx) => PostSaveStatusDialog(saved: updated),
              );
            }
          });
        }
      } else {
        final created = await ref
            .read(customsConsultationsProvider.notifier)
            .createConsultation(payload);
        if (context.mounted && created != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              '${l.customsStudySavedSuccess} (${created.consultationCode})',
              severity: AppSeverity.success,
            ),
          );
          onSavedSuccess(created);
          Future.delayed(const Duration(milliseconds: 400), () {
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (ctx) => PostSaveStatusDialog(saved: created),
              );
            }
          });
        }
      }

      // Check budget linkage warning
      if (selectedImportFileId != null && context.mounted) {
        final budgets = ref.read(importBudgetsProvider).valueOrNull ?? [];
        final linkedBudget = budgets
            .where((b) => b.importFileId == selectedImportFileId && b.isActive)
            .firstOrNull;
        if (linkedBudget != null && context.mounted) {
          final warningMsg =
              context.l10n.ccCostLinkageAlertThisImportFile(linkedBudget.budgetCode);
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                AppTheme.snackBar(
                  context,
                  warningMsg,
                  severity: AppSeverity.warning,
                  duration: const Duration(seconds: 8),
                  action: SnackBarAction(
                    label: context.l10n.ccOK,
                    textColor: AppTheme.white,
                    onPressed: () {},
                  ),
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      if (context.mounted && ApiErrorText.code(e) == ApiErrorCode.consultationExists) {
        final existingId = ApiErrorText.detail(e)?['consultation_id'];
        final existingCode = ApiErrorText.detail(e)?['consultation_code'];
        showExistingRecordSnack(
          context,
          message: ApiErrorText.of(l, e),
          actionLabel: l.openExistingRecord,
          onOpen: () async {
            bool matches(CustomsConsultationModel c) =>
                c.consultationId == existingId ||
                (existingCode != null && c.consultationCode == existingCode);
            var list = ref.read(customsConsultationsProvider).valueOrNull ??
                const <CustomsConsultationModel>[];
            var found = list.where(matches).toList();
            if (found.isEmpty) {
              await ref
                  .read(customsConsultationsProvider.notifier)
                  .fetchConsultations();
              list = ref.read(customsConsultationsProvider).valueOrNull ??
                  const <CustomsConsultationModel>[];
              found = list.where(matches).toList();
            }
            if (found.isNotEmpty && context.mounted) {
              loadConsultation(found.first);
            }
          },
        );
      } else if (context.mounted) {
        await showErrorDetailsDialog(
          context,
          title: '❌ ${l.unableToSaveCustomsStudy}',
          error: e,
        );
      }
    } finally {
      setSaving(false);
    }
  }
}
