import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/customs_consultation_model.dart';
import '../../providers/customs_consultation_provider.dart';
import '../search_and_clone_consultation_dialog.dart';

class ConsultationCloneHandler {
  ConsultationCloneHandler._();

  static void openCloneReviewDialog({
    required BuildContext context,
    required WidgetRef ref,
    required CustomsConsultationModel source,
    required void Function(CustomsConsultationModel) onEdit,
  }) {
    final l = context.l10n;
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final initialTitle = '${source.title}${TableRowCloneHelper.copySuffix}';

    final copiedMap = <String, String>{
      l.customsBrokerLabel: source.brokerName.isNotEmpty ? source.brokerName : '—',
      l.customsInspectionReadiness: '${source.checklistItems.length} ${l.itemsAndDocsCount}',
    };
    if (source.estimatedDutiesEgp > 0) {
      copiedMap[l.totalTaxesAndDutiesCol] = '${source.estimatedDutiesEgp.toStringAsFixed(2)} ${context.l10n.financialSettlementCurrencyEgp}';
    }
    if (source.brokerQuoteItems.isNotEmpty) {
      copiedMap[l.clearanceBrokerFeeItem] = '${source.brokerQuoteItems.length}';
    }

    final mandatorilyReset = <String>[
      l.cloneFieldConsultationCodeGenerated,
      l.cloneFieldImportFileReset,
      l.cloneFieldChecklistReset,
      l.cloneFieldStatusDraftBadge,
    ];

    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: isArabic ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: textDir,
          child: CloneEntityReviewDialog(
            entityType: l.cloneConsultationDialogTitle,
            sourceCode: source.consultationCode,
            sourceTitle: initialTitle,
            suggestedNewCode: '${source.consultationCode}-CLONE',
            copiedFieldsSummary: copiedMap,
            mandatorilyResetFields: mandatorilyReset,
            allowCopyLineItems: true,
            onConfirm: ({
              required String newCode,
              required String newTitle,
              required bool copyLineItems,
              required bool copyAttachments,
              String? notes,
            }) async {
              final messenger = ScaffoldMessenger.of(context);
              final payload = {
                'new_consultation_code': newCode,
                'new_title': newTitle,
                'copy_checklist_items': copyLineItems,
                'copy_broker_quote_items': copyLineItems,
                'notes': notes,
              };
              try {
                final cloned = await ref.read(customsConsultationsProvider.notifier).cloneConsultation(
                  source.consultationId,
                  payload,
                );
                if (cloned != null) {
                  if (!context.mounted) return;
                  onEdit(cloned);
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(AppTheme.snackBar(context, l.cloneConsultationSuccess(cloned.consultationCode), severity: AppSeverity.success));
                }
              } catch (e) {
                if (!context.mounted) return;
                messenger.showSnackBar(AppTheme.snackBar(context, l.cloneConsultationError(e.toString()), severity: AppSeverity.danger));
              }
            },
          ),
        ),
      ),
    );
  }

  static void openSearchAndCloneDialog({
    required BuildContext context,
    required WidgetRef ref,
    required List<CustomsConsultationModel> consultations,
    required void Function(CustomsConsultationModel) onEdit,
  }) {
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isArabic ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: textDir,
          child: SearchAndCloneConsultationDialog(
            consultations: consultations,
            onSelectConsultation: (consultation) {
              Navigator.of(dialogCtx).pop();
              openCloneReviewDialog(
                context: context,
                ref: ref,
                source: consultation,
                onEdit: onEdit,
              );
            },
          ),
        ),
      ),
    );
  }

  static Future<void> handleDeleteOrRestore({
    required BuildContext context,
    required WidgetRef ref,
    required CustomsConsultationModel session,
  }) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (session.isActive == false) {
      final confirm = await AppConfirmDialog.showDelete(
        context,
        title: l.deleteConsultationTitle,
        message: l.deleteConsultationMsg(session.consultationCode, session.title),
      );
      if (confirm == true) {
        try {
          await ref.read(customsConsultationsProvider.notifier).restoreConsultation(session.consultationId);
          if (context.mounted) {
            messenger.showSnackBar(AppTheme.snackBar(context, l.restoreConsultationSuccess(session.consultationCode), severity: AppSeverity.success));
          }
        } catch (e) {
          if (context.mounted) {
            messenger.showSnackBar(AppTheme.snackBar(context, ApiErrorText.of(l, e), severity: AppSeverity.danger));
          }
        }
      }
    } else {
      final confirm = await AppConfirmDialog.showDelete(
        context,
        title: l.deleteConsultationTitle,
        message: l.deleteConsultationMsg(session.consultationCode, session.title),
      );
      if (confirm == true) {
        try {
          await ref.read(customsConsultationsProvider.notifier).softDeleteConsultation(session.consultationId);
          if (context.mounted) {
            messenger.showSnackBar(AppTheme.snackBar(context, l.deleteConsultationSuccess(session.consultationCode), severity: AppSeverity.success));
          }
        } catch (e) {
          if (context.mounted) {
            messenger.showSnackBar(AppTheme.snackBar(context, ApiErrorText.of(l, e), severity: AppSeverity.danger));
          }
        }
      }
    }
  }
}
