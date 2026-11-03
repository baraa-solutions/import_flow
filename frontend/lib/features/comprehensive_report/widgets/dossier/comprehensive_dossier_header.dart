import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../import_files/models/import_file_model.dart';

/// Top header for ComprehensiveDossierExportDialog
class ComprehensiveDossierHeader extends StatelessWidget {
  final ImportFileModel file;
  final VoidCallback onOpenFullScreen;
  final VoidCallback onClose;

  const ComprehensiveDossierHeader({
    super.key,
    required this.file,
    required this.onOpenFullScreen,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.flatCharcoal,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(10),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_turned_in, color: AppTheme.cloudWhite, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isAr ? 'إصدار وتصدير تقرير الملف الشامل' : 'Issue & Export Comprehensive Dossier',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${isAr ? "شحنة" : "Shipment"}: ${file.primaryNameWithCode}  |  ${isAr ? "المورد" : "Supplier"}: ${file.supplierName}',
                  style: const TextStyle(
                    color: AppTheme.cloudWhite,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cobalt,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.fullscreen, size: 16),
            label: Text(
              isAr ? 'فتح بالشاشة كاملة' : 'Open Full Screen',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: onOpenFullScreen,
          ),
          const SizedBox(width: 8),
          IconButton(
            key: const Key('comprehensiveDossierCloseBtn'),
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: onClose,
            tooltip: isAr ? 'إغلاق' : 'Close',
          ),
        ],
      ),
    );
  }
}
