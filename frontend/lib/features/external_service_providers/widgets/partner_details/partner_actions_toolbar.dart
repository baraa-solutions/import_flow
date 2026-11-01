import 'package:flutter/material.dart';

import '../../../../core/export/widgets/export_language_dialog.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/master_data_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/partner_model.dart';
import '../partner_statement_of_account_dialog.dart';
import 'partner_share_modals.dart';

class PartnerActionsToolbar extends StatelessWidget {
  final PartnerModel partner;
  final VoidCallback? onEdit;
  final VoidCallback onClose;

  const PartnerActionsToolbar({
    super.key,
    required this.partner,
    this.onEdit,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : const Color(0xFFF1F5F9),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(
            top: BorderSide(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          // Left Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 1. Print / Save PDF
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.charcoal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: Text(l10n.printSavePdfBtn,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final lang = await ExportLanguageDialog.show(context);
                  if (lang == null) return;
                  await MasterDataExportService.printOrSavePartnerPdf(partner,
                      lang: lang);
                },
              ),

              // 2. Export Excel
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E7E34),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.table_view_rounded, size: 16),
                label: Text(l10n.downloadExcelBtn,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final lang = await ExportLanguageDialog.show(context);
                  if (lang == null) return;
                  if (!context.mounted) return;
                  final path =
                      await MasterDataExportService.exportPartnerToExcel(
                          context, partner,
                          lang: lang);
                  if (context.mounted && path != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      AppTheme.snackBar(context, l10n.excelSavedSuccess(path),
                          severity: AppSeverity.success),
                    );
                  }
                },
              ),

              // 3. Export CSV
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.description_rounded, size: 16),
                label: Text(l10n.tableExportCsv,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final lang = await ExportLanguageDialog.show(context);
                  if (lang == null) return;
                  if (!context.mounted) return;
                  final path =
                      await MasterDataExportService.exportPartnerToCsv(
                          context, partner,
                          lang: lang);
                  if (context.mounted && path != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      AppTheme.snackBar(context, l10n.excelSavedSuccess(path),
                          severity: AppSeverity.success),
                    );
                  }
                },
              ),

              // 4. WhatsApp Share
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: Text(l10n.whatsappShareBtn,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () =>
                    PartnerShareModals.showWhatsAppPreview(context, partner),
              ),

              // 5. Email Share
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.mail_outline_rounded, size: 16),
                label: Text(l10n.emailShareBtn,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () =>
                    PartnerShareModals.showEmailPreview(context, partner),
              ),

              // 6. Statement of Account Shortcut
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.cobalt,
                  side: const BorderSide(color: AppTheme.cobalt),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: Text(l10n.partnerStatementShortcutBtn,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  PartnerStatementOfAccountDialog.show(context, partner);
                },
              ),
            ],
          ),

          // Right Action Buttons: Edit & Close
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onEdit != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.charcoal,
                    side: const BorderSide(color: AppTheme.charcoal),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(l10n.editPartnerBtn,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    onClose();
                    onEdit!();
                  },
                ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onClose,
                child: Text(l10n.closeBtn,
                    style: const TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
