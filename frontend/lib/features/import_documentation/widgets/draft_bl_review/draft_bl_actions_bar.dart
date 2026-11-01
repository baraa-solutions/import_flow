import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/widgets.dart';

/// Primary action bar for Draft B/L review workflows:
/// - Final Approval / Certify B/L
/// - Request amendment (Carrier correction letter)
/// - Export PDF via FileSaveHelper
/// - Export Excel sheet
/// - Upload & OCR re-extract document
/// - Save temporary draft session
class DraftBlActionsBar extends StatelessWidget {
  final VoidCallback? onApproveBl;
  final VoidCallback? onRequestAmendment;
  final VoidCallback? onExportPdf;
  final VoidCallback? onExportExcel;
  final VoidCallback? onOcrReExtract;
  final VoidCallback? onSaveTempDraft;
  final VoidCallback? onPrintBl;

  final bool isApproving;
  final bool isSavingDraft;
  final bool isExtracting;
  final bool isLoading;
  final bool hasBlockingMismatch;

  const DraftBlActionsBar({
    super.key,
    this.onApproveBl,
    this.onRequestAmendment,
    this.onExportPdf,
    this.onExportExcel,
    this.onOcrReExtract,
    this.onSaveTempDraft,
    this.onPrintBl,
    this.isApproving = false,
    this.isSavingDraft = false,
    this.isExtracting = false,
    this.isLoading = false,
    this.hasBlockingMismatch = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 1. Temporary Draft
          if (onSaveTempDraft != null)
            AppButton(
              key: const Key('draftBlSaveDraftBtn'),
              label: l.idocASaveTempDraft,
              icon: Icons.bookmark_added_outlined,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              isLoading: isSavingDraft,
              onPressed: isLoading ? null : onSaveTempDraft,
            ),

          // 2. Final Approval / Certify
          if (onApproveBl != null)
            AppButton(
              key: const Key('draftBlCertifyBtn'),
              label: l.idocAFinalApprovalOfDocuments,
              icon: Icons.verified_rounded,
              variant: AppButtonVariant.success,
              size: AppButtonSize.small,
              isLoading: isApproving,
              onPressed: isLoading ? null : onApproveBl,
            ),

          // 3. Request Amendment / Revision Report
          if (onRequestAmendment != null)
            AppButton(
              label: l.draftBlRevisionReportCarrierButton,
              icon: Icons.assignment_late,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              onPressed: onRequestAmendment,
            ),

          // 4. OCR / File Re-extract
          if (onOcrReExtract != null)
            AppButton(
              label: isExtracting ? l.draftBlExtractingFileProgress : l.draftBlUploadAndExtractButton,
              icon: Icons.document_scanner,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              isLoading: isExtracting,
              onPressed: isExtracting ? null : onOcrReExtract,
            ),

          // 5. Export PDF (via FileSaveHelper)
          if (onExportPdf != null)
            AppButton(
              label: l.draftBlDownloadPdfButton,
              icon: Icons.picture_as_pdf,
              variant: AppButtonVariant.danger,
              size: AppButtonSize.small,
              onPressed: onExportPdf,
            ),

          // 6. Export Excel
          if (onExportExcel != null)
            AppButton(
              label: l.draftBlDownloadExcelButton,
              icon: Icons.table_chart,
              variant: AppButtonVariant.success,
              size: AppButtonSize.small,
              onPressed: onExportExcel,
            ),

          // 7. Print
          if (onPrintBl != null)
            AppButton(
              label: l.draftBlPrintButton,
              icon: Icons.print,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: onPrintBl,
            ),
        ],
      ),
    );
  }
}
