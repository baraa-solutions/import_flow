import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../services/central_docs_archive_export_service.dart';
import '../idoc_ui.dart';

class ArchiveExportToolbar extends StatelessWidget {
  final Map<String, dynamic> data;

  const ArchiveExportToolbar({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final exportService = CentralDocsArchiveExportService(context: context, data: data);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderOf(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IdocUi.fit(AppButton(
            label: l10n.centralDocsExportTsvBtn,
            icon: Icons.table_chart_outlined,
            variant: AppButtonVariant.primary,
            onPressed: () => exportService.exportToTsv(),
          )),
          IdocUi.fit(AppButton(
            label: l10n.centralDocsExportExcelBtn,
            icon: Icons.file_download_outlined,
            variant: AppButtonVariant.success,
            onPressed: () => exportService.exportToExcel(),
          )),
          IdocUi.fit(AppButton(
            label: l10n.centralDocsPrintPdfBtn,
            icon: Icons.picture_as_pdf_outlined,
            variant: AppButtonVariant.danger,
            onPressed: () => exportService.printOrSavePdf(),
          )),
          IdocUi.fit(AppButton(
            label: l10n.centralDocsCopyDossierBtn,
            icon: Icons.copy_all_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () => exportService.copyDossierToClipboard(),
          )),
        ],
      ),
    );
  }
}
