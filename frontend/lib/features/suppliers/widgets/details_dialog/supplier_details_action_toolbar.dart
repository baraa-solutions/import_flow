import 'package:flutter/material.dart';
import '../../../../core/export/widgets/export_language_dialog.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/master_data_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/supplier_model.dart';

class SupplierDetailsActionToolbar extends StatelessWidget {
  final SupplierModel supplier;
  final VoidCallback? onEdit;

  const SupplierDetailsActionToolbar({
    super.key,
    required this.supplier,
    this.onEdit,
  });

  void _showWhatsAppPreviewModal(BuildContext context) {
    final l10n = context.l10n;
    bool isArabic = l10n.isArabic;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final text = MasterDataExportService.generateSupplierWhatsAppText(supplier, isArabic: isArabic);
          return SelectionArea(
            child: AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n.whatsappPreviewTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(value: true, label: Text('عربي', style: TextStyle(fontSize: 11))),
                      ButtonSegment<bool>(value: false, label: Text('EN', style: TextStyle(fontSize: 11))),
                    ],
                    selected: {isArabic},
                    onSelectionChanged: (newSelection) {
                      setModalState(() => isArabic = newSelection.first);
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: SelectableText(
                        text,
                        style: const TextStyle(fontSize: 12, height: 1.4, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.close)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                  icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                  label: Text(l10n.copyWhatsappTextBtn, style: const TextStyle(color: Colors.white)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    CopyHelper.copy(context, text, customMessage: l10n.whatsappCopiedSuccess);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEmailPreviewModal(BuildContext context) {
    final l10n = context.l10n;
    bool isArabic = l10n.isArabic;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final subject = MasterDataExportService.generateSupplierEmailSubject(supplier, isArabic: isArabic);
          final body = MasterDataExportService.generateSupplierEmailBody(supplier, isArabic: isArabic);

          return SelectionArea(
            child: AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.mail_outline_rounded, color: AppTheme.cobalt),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n.emailPreviewTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(value: true, label: Text('عربي', style: TextStyle(fontSize: 11))),
                      ButtonSegment<bool>(value: false, label: Text('EN', style: TextStyle(fontSize: 11))),
                    ],
                    selected: {isArabic},
                    onSelectionChanged: (newSelection) {
                      setModalState(() => isArabic = newSelection.first);
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.emailSubjectPrefix(subject), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SelectableText(
                        body,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.close)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                  icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                  label: Text(l10n.copyEmailTextBtn, style: const TextStyle(color: Colors.white)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    CopyHelper.copy(context, '${l10n.emailSubjectPrefix(subject)}\n\n$body', customMessage: l10n.emailCopiedSuccess);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

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
              // 1. Print / Save PDF
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.charcoal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: Text(l10n.printSavePdfBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final lang = await ExportLanguageDialog.show(context);
                  if (lang == null) return;
                  await MasterDataExportService.printOrSaveSupplierPdf(supplier, lang: lang);
                },
              ),

              // 2. Export Excel
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E7E34),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.table_view_rounded, size: 16),
                label: Text(l10n.downloadExcelBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final lang = await ExportLanguageDialog.show(context);
                  if (lang == null) return;
                  if (!context.mounted) return;
                  final path = await MasterDataExportService.exportSupplierToExcel(context, supplier, lang: lang);
                  if (context.mounted && path != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      AppTheme.snackBar(context, l10n.excelSavedSuccess(path), severity: AppSeverity.success),
                    );
                  }
                },
              ),

              // 3. Export CSV
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.description_rounded, size: 16),
                label: Text(l10n.tableExportCsv, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final lang = await ExportLanguageDialog.show(context);
                  if (lang == null) return;
                  if (!context.mounted) return;
                  final path = await MasterDataExportService.exportSupplierToCsv(context, supplier, lang: lang);
                  if (context.mounted && path != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      AppTheme.snackBar(context, l10n.excelSavedSuccess(path), severity: AppSeverity.success),
                    );
                  }
                },
              ),

              // 4. WhatsApp Share
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: Text(l10n.whatsappShareBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => _showWhatsAppPreviewModal(context),
              ),

              // 5. Email Share
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.mail_outline_rounded, size: 16),
                label: Text(l10n.emailShareBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => _showEmailPreviewModal(context),
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
