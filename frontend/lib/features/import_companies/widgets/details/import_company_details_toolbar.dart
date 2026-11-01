import 'package:flutter/material.dart';

import '../../../../core/export/widgets/export_language_dialog.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/master_data_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/import_company_model.dart';
import 'import_company_share_modals.dart';

class ImportCompanyDetailsToolbar extends StatelessWidget {
  final ImportCompanyModel company;
  final VoidCallback? onEdit;

  const ImportCompanyDetailsToolbar({
    super.key,
    required this.company,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 1. Copy All Info
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.copy_all_rounded, size: 16),
                label: Text(
                  l10n.importCompanyCopySummaryBtn,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  final fullText = MasterDataExportService.generateImporterWhatsAppText(
                    company,
                    isArabic: context.l10n.isArabic,
                  );
                  CopyHelper.copy(context, fullText, customMessage: l10n.importCompanyCopySummarySuccess);
                },
              ),

              // 2. Print / Save PDF
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.charcoal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: Text(
                  l10n.printSavePdfBtn,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final lang = await ExportLanguageDialog.show(context);
                  if (lang == null) return;
                  await MasterDataExportService.printOrSaveImporterPdf(company, lang: lang);
                },
              ),

              // 3. Export Excel
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E7E34),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.table_view_rounded, size: 16),
                label: Text(
                  l10n.downloadExcelBtn,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final lang = await ExportLanguageDialog.show(context);
                  if (lang == null) return;
                  if (!context.mounted) return;
                  final path = await MasterDataExportService.exportImporterToExcel(context, company, lang: lang);
                  if (context.mounted && path != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      AppTheme.snackBar(context, l10n.excelSavedSuccess(path), severity: AppSeverity.success),
                    );
                  }
                },
              ),

              // 4. Export CSV
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.description_rounded, size: 16),
                label: Text(
                  l10n.tableExportCsv,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final lang = await ExportLanguageDialog.show(context);
                  if (lang == null) return;
                  if (!context.mounted) return;
                  final path = await MasterDataExportService.exportImporterToCsv(context, company, lang: lang);
                  if (context.mounted && path != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      AppTheme.snackBar(context, l10n.excelSavedSuccess(path), severity: AppSeverity.success),
                    );
                  }
                },
              ),

              // 5. WhatsApp Share
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: Text(
                  l10n.whatsappShareBtn,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => ImportCompanyShareModals.showWhatsAppPreview(context, company),
              ),

              // 6. Email Share
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.mail_outline_rounded, size: 16),
                label: Text(
                  l10n.emailShareBtn,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => ImportCompanyShareModals.showEmailPreview(context, company),
              ),
            ],
          ),

          // Right Buttons: Edit & Close
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onEdit != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.charcoal,
                    side: const BorderSide(color: AppTheme.charcoal),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(l10n.edit, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(context);
                    onEdit!();
                  },
                ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.close, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
