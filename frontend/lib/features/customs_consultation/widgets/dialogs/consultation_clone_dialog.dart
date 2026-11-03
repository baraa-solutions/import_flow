import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/customs_consultation_model.dart';
import '../../providers/customs_consultation_provider.dart';
import '../search_and_clone_consultation_dialog.dart';

/// Opens the two-step Search & Clone dialog flow for Customs Consultations (UX-CLONE-011).
class ConsultationCloneDialog {
  const ConsultationCloneDialog._();

  /// Step 1: Open the search dialog to let the user select a consultation to clone.
  static void openSearchAndClone({
    required BuildContext context,
    required WidgetRef ref,
    required List<CustomsConsultationModel> consultations,
    required ValueChanged<CustomsConsultationModel> onCloned,
  }) {
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isArabic ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: textDir,
          child: SelectionArea(
            child: SearchAndCloneConsultationDialog(
              consultations: consultations,
              onSelectConsultation: (consultation) {
                Navigator.of(dialogCtx).pop();
                openCloneReview(
                  context: context,
                  ref: ref,
                  source: consultation,
                  onCloned: onCloned,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Step 2: Open the clone review & confirmation dialog.
  static void openCloneReview({
    required BuildContext context,
    required WidgetRef ref,
    required CustomsConsultationModel source,
    required ValueChanged<CustomsConsultationModel> onCloned,
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
          child: SelectionArea(
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
                final cloned = await ref.read(customsConsultationsProvider.notifier).cloneConsultation(
                  source.consultationId,
                  payload,
                );
                if (cloned != null) {
                  if (!context.mounted) return;
                  onCloned(cloned);
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    AppTheme.snackBar(
                      context,
                      l.cloneConsultationSuccess(cloned.consultationCode),
                      severity: AppSeverity.success,
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
