import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/comprehensive_dossier_model.dart';
import '../../services/comprehensive_report_export_service.dart';

/// Multi-format export toolbar (PDF, Excel, TSV, Clipboard) for ComprehensiveDossierExportDialog
class ComprehensiveDossierToolbar extends StatelessWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel dossier;

  const ComprehensiveDossierToolbar({
    super.key,
    required this.file,
    required this.dossier,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cloudWhite.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr
                ? 'تصدير الحزم والملفات للمراجعة والجهات الرسمية (Mandatory Save As Dialog):'
                : 'Export Packages & Official Dossiers (Mandatory Save As Dialog):',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.flatCharcoal),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                key: const Key('exportDossierPdfBtn'),
                onPressed: () => ComprehensiveReportExportService.exportToPdf(
                  context: context,
                  file: file,
                  dossier: dossier,
                ),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('تصدير PDF رسمي (Cairo A4)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.flatCrimson,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                key: const Key('exportDossierExcelBtn'),
                onPressed: () => ComprehensiveReportExportService.exportToExcel(
                  context: context,
                  file: file,
                  dossier: dossier,
                ),
                icon: const Icon(Icons.table_view, size: 18),
                label: const Text('تصدير Excel (CSV UTF-8)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.flatEmerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                key: const Key('exportDossierTsvBtn'),
                onPressed: () => ComprehensiveReportExportService.exportToTsv(
                  context: context,
                  file: file,
                  dossier: dossier,
                ),
                icon: const Icon(Icons.text_snippet, size: 18),
                label: const Text('تصدير TSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.flatCobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('copyDossierClipboardBtn'),
                onPressed: () {
                  final text = ComprehensiveReportExportService.buildDossierText(
                    context: context,
                    file: file,
                    dossier: dossier,
                  );
                  CopyHelper.copy(
                    context,
                    text,
                    customMessage: isAr
                        ? 'تم نسخ تقرير الملف الشامل للحافظة بنجاح!'
                        : 'Comprehensive dossier report copied to clipboard!',
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: Text(isAr ? 'نسخ للحافظة' : 'Copy to Clipboard'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.flatCharcoal,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
