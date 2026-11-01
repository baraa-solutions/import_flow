import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/original_documents_collection_model.dart';
import '../../services/original_docs_export_service.dart';
import '../idoc_ui.dart';

/// Action toolbar for saving draft, completing collection, and exporting dossier.
/// Wrapped in [SelectionArea] with unified canonical AppButton widgets.
class OriginalDocsActionsBar extends StatelessWidget {
  final bool isSaving;
  final ImportFileModel? selectedImportFile;
  final List<OriginalDocumentItemModel> documents;
  final List<CourierEntryModel> couriers;
  final OriginalDocumentsCollectionSessionModel? existingSession;
  final String notesText;
  final String overrideReasonText;
  final VoidCallback onSaveDraft;
  final VoidCallback onCompleteCollection;

  const OriginalDocsActionsBar({
    super.key,
    required this.isSaving,
    required this.selectedImportFile,
    required this.documents,
    required this.couriers,
    required this.existingSession,
    required this.notesText,
    required this.overrideReasonText,
    required this.onSaveDraft,
    required this.onCompleteCollection,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final file = selectedImportFile;

    return SelectionArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IdocUi.fit(
                    AppButton(
                      label: l.saveDraftSessionBtn,
                      icon: Icons.save_outlined,
                      variant: AppButtonVariant.primary,
                      isLoading: isSaving,
                      onPressed: isSaving ? null : onSaveDraft,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IdocUi.fit(
                    AppButton(
                      label: l.completeCollectionBtn,
                      icon: Icons.check_circle,
                      variant: AppButtonVariant.success,
                      isLoading: isSaving,
                      onPressed: isSaving ? null : onCompleteCollection,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Row(
                children: [
                  IdocUi.fit(
                    AppButton(
                      label: l.originalDocsExportTsvBtn,
                      icon: Icons.table_chart_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: file == null
                          ? null
                          : () => OriginalDocsExportService.exportDocumentsTsv(
                                context: context,
                                file: file,
                                documents: documents,
                                couriers: couriers,
                              ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IdocUi.fit(
                    AppButton(
                      label: l.originalDocsExportExcelBtn,
                      icon: Icons.file_download_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: file == null
                          ? null
                          : () => OriginalDocsExportService.exportDocumentsExcel(
                                context: context,
                                file: file,
                                documents: documents,
                                couriers: couriers,
                              ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IdocUi.fit(
                    AppButton(
                      label: l.originalDocsPrintPdfBtn,
                      icon: Icons.print_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: file == null
                          ? null
                          : () => OriginalDocsExportService.printDocumentsPdf(
                                context: context,
                                file: file,
                                documents: documents,
                                couriers: couriers,
                                session: existingSession,
                                notes: notesText,
                                overrideReason: overrideReasonText,
                              ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IdocUi.fit(
                    AppButton(
                      label: l.originalDocsCopyDossierBtn,
                      icon: Icons.copy_all_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: file == null
                          ? null
                          : () => OriginalDocsExportService.copyDocumentsDossier(
                                context: context,
                                file: file,
                                documents: documents,
                                couriers: couriers,
                                session: existingSession,
                                notes: notesText,
                                overrideReason: overrideReasonText,
                              ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
