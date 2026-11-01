import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/widgets.dart';
import '../idoc_ui_b.dart';

class CooReviewInputActionsBar extends StatelessWidget {
  final VoidCallback? onSaveDraft;
  final VoidCallback? onRunComparison;
  final bool isSavingDraft;
  final bool isLoading;

  const CooReviewInputActionsBar({
    super.key,
    required this.onSaveDraft,
    required this.onRunComparison,
    required this.isSavingDraft,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        IdocBUi.fit(
          AppButton(
            key: const Key('cooSaveDraftInputBtn'),
            label: context.l10n.cooSaveDraftSessionBtn,
            onPressed: onSaveDraft,
            variant: AppButtonVariant.secondary,
            icon: Icons.bookmark_added_outlined,
            isLoading: isSavingDraft,
          ),
        ),
        IdocBUi.fit(
          AppButton(
            label: context.l10n.cooRunComparisonButton,
            onPressed: onRunComparison,
            variant: AppButtonVariant.success,
            icon: Icons.compare_arrows,
            isLoading: isLoading,
          ),
        ),
      ],
    );
  }
}

class CooReviewMatrixActionsBar extends StatelessWidget {
  final VoidCallback onExportPdf;
  final VoidCallback onExportExcel;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onCertify;
  final bool isSavingDraft;
  final bool isCertifying;

  const CooReviewMatrixActionsBar({
    super.key,
    required this.onExportPdf,
    required this.onExportExcel,
    required this.onSaveDraft,
    required this.onCertify,
    required this.isSavingDraft,
    required this.isCertifying,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        IdocBUi.fit(
          AppButton(
            label: context.l10n.cooExportPdfButton,
            onPressed: onExportPdf,
            variant: AppButtonVariant.secondary,
            icon: Icons.picture_as_pdf,
          ),
        ),
        IdocBUi.fit(
          AppButton(
            label: context.l10n.cooExportExcelButton,
            onPressed: onExportExcel,
            variant: AppButtonVariant.secondary,
            icon: Icons.table_chart,
          ),
        ),
        IdocBUi.fit(
          AppButton(
            key: const Key('cooSaveDraftBtn'),
            label: context.l10n.idocBCooSaveDraftBtn,
            onPressed: onSaveDraft,
            variant: AppButtonVariant.secondary,
            icon: Icons.bookmark_added_outlined,
            isLoading: isSavingDraft,
          ),
        ),
        IdocBUi.fit(
          AppButton(
            key: const Key('cooCertifyBtn'),
            label: context.l10n.idocBCooCertifyBtn,
            onPressed: onCertify,
            variant: AppButtonVariant.success,
            icon: Icons.verified_rounded,
            isLoading: isCertifying,
          ),
        ),
      ],
    );
  }
}

class CooReviewJustificationActionsBar extends StatelessWidget {
  final VoidCallback? onSaveWithJustification;
  final VoidCallback? onSaveDraftJustification;
  final VoidCallback onReturnToEdit;
  final bool isCertifying;
  final bool isSavingDraft;

  const CooReviewJustificationActionsBar({
    super.key,
    required this.onSaveWithJustification,
    required this.onSaveDraftJustification,
    required this.onReturnToEdit,
    required this.isCertifying,
    required this.isSavingDraft,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        IdocBUi.fit(
          AppButton(
            key: const Key('cooSaveWithJustificationBtn'),
            label: context.l10n.cooSaveWithJustificationButton,
            onPressed: onSaveWithJustification,
            variant: AppButtonVariant.success,
            icon: Icons.check_circle,
            isLoading: isCertifying,
          ),
        ),
        IdocBUi.fit(
          AppButton(
            key: const Key('cooSaveDraftJustificationBtn'),
            label: context.l10n.idocBCooSaveDraftAsBtn,
            onPressed: onSaveDraftJustification,
            variant: AppButtonVariant.secondary,
            icon: Icons.bookmark_added_outlined,
            isLoading: isSavingDraft,
          ),
        ),
        IdocBUi.fit(
          AppButton(
            label: context.l10n.cooReturnToEditAndNotifySupplierButton,
            onPressed: onReturnToEdit,
            variant: AppButtonVariant.secondary,
            icon: Icons.edit_note,
          ),
        ),
      ],
    );
  }
}

class CooReviewRegistryActionsBar extends StatelessWidget {
  final VoidCallback onSearchAndClone;
  final VoidCallback onCopyTable;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final VoidCallback onNewDraft;

  const CooReviewRegistryActionsBar({
    super.key,
    required this.onSearchAndClone,
    required this.onCopyTable,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.onNewDraft,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        IdocBUi.fit(
          AppButton(
            key: const Key('searchAndCloneCooBtn'),
            label: context.l10n.searchAndCloneCooBtn,
            onPressed: onSearchAndClone,
            variant: AppButtonVariant.secondary,
            icon: Icons.copy_all,
          ),
        ),
        IdocBUi.fit(
          AppButton(
            key: const Key('cooRegistryCopyBtn'),
            label: context.l10n.idocBCopyTable,
            onPressed: onCopyTable,
            variant: AppButtonVariant.secondary,
            icon: Icons.copy,
          ),
        ),
        IdocBUi.fit(
          AppButton(
            key: const Key('cooRegistryExcelBtn'),
            label: context.l10n.idocBExportExcel,
            onPressed: onExportExcel,
            variant: AppButtonVariant.secondary,
            icon: Icons.table_chart,
          ),
        ),
        IdocBUi.fit(
          AppButton(
            key: const Key('cooRegistryPdfBtn'),
            label: context.l10n.idocBExportPdf,
            onPressed: onExportPdf,
            variant: AppButtonVariant.secondary,
            icon: Icons.picture_as_pdf,
          ),
        ),
        IdocBUi.fit(
          AppButton(
            label: context.l10n.cooReviewNewDraftButton,
            onPressed: onNewDraft,
            icon: Icons.add,
          ),
        ),
      ],
    );
  }
}
