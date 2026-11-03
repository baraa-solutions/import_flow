import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../consultation_metric_badge.dart';

/// Top metric badges and calculation action triggers.
class ConsultationCalcActionsBar extends StatelessWidget {
  final int liveReadinessPct;
  final int itemsAndDocsCount;
  final int blockingCount;
  final VoidCallback onTapBlockingIssues;
  final bool isTaxReviewMode;
  final VoidCallback? onCompareQuotes;
  final VoidCallback onSearchAndClone;
  final VoidCallback onRefresh;
  final VoidCallback onClearForm;
  final VoidCallback onExportTsv;
  final VoidCallback onExportExcel;
  final VoidCallback onPrintPdf;
  final VoidCallback onCopyDossier;
  final VoidCallback? onExtractQuote;
  final VoidCallback onSaveDraft;
  final VoidCallback onSave;
  final bool isSaving;
  final bool isEditing;

  const ConsultationCalcActionsBar({
    super.key,
    required this.liveReadinessPct,
    required this.itemsAndDocsCount,
    required this.blockingCount,
    required this.onTapBlockingIssues,
    required this.isTaxReviewMode,
    this.onCompareQuotes,
    required this.onSearchAndClone,
    required this.onRefresh,
    required this.onClearForm,
    required this.onExportTsv,
    required this.onExportExcel,
    required this.onPrintPdf,
    required this.onCopyDossier,
    this.onExtractQuote,
    required this.onSaveDraft,
    required this.onSave,
    this.isSaving = false,
    this.isEditing = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConsultationMetricBadge(
            title: l.customsInspectionReadiness,
            value: '$liveReadinessPct%',
            color: AppTheme.cobalt,
          ),
          ConsultationMetricBadge(
            title: l.itemsAndDocsCount,
            value: '$itemsAndDocsCount',
            color: AppTheme.textMuted,
          ),
          ConsultationMetricBadge(
            title: l.blockingIssuesCount,
            value: '$blockingCount',
            color: blockingCount > 0 ? AppTheme.crimson : AppTheme.emerald,
            onTap: onTapBlockingIssues,
          ),
          if (!isTaxReviewMode && onCompareQuotes != null)
            AppButton(
              label: l.clearanceQuotesScreenTitle,
              icon: Icons.compare_arrows_rounded,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: onCompareQuotes,
            ),
          Tooltip(
            message: l.searchAndCloneConsultationBtn,
            child: AppButton(
              key: const ValueKey('searchAndCloneConsultationBtn'),
              label: l.searchAndCloneConsultationBtn,
              icon: Icons.control_point_duplicate_rounded,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              onPressed: onSearchAndClone,
            ),
          ),
          AppButton(
            label: l.liveRefresh,
            icon: Icons.refresh,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: onRefresh,
          ),
          AppButton(
            label: l.clearAndStartNew,
            icon: Icons.cleaning_services_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: onClearForm,
          ),
          AppButton(
            label: l.customsTaxExportTsvBtn,
            icon: Icons.table_view_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: onExportTsv,
          ),
          AppButton(
            label: l.customsTaxExportExcelBtn,
            icon: Icons.description_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: onExportExcel,
          ),
          AppButton(
            label: l.customsTaxPrintPdfBtn,
            icon: Icons.picture_as_pdf_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: onPrintPdf,
          ),
          AppButton(
            label: l.customsTaxCopyDossierBtn,
            icon: Icons.copy_all_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: onCopyDossier,
          ),
          if (!isTaxReviewMode && onExtractQuote != null)
            AppButton(
              label: l.smartClearanceQuoteExtractor,
              icon: Icons.auto_awesome,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              onPressed: onExtractQuote,
            ),
          AppButton(
            label: l.saveDraftContinueLater,
            icon: Icons.save_outlined,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            onPressed: isSaving ? null : onSaveDraft,
          ),
          AppButton(
            label: isEditing
                ? l.saveConsultationChanges
                : (isTaxReviewMode
                    ? l.saveTaxReviewSession
                    : l.saveCustomsStudy),
            icon: isEditing ? Icons.save_as : Icons.save,
            variant: AppButtonVariant.success,
            size: AppButtonSize.small,
            isLoading: isSaving,
            onPressed: isSaving ? null : onSave,
          ),
        ],
      ),
    );
  }
}
