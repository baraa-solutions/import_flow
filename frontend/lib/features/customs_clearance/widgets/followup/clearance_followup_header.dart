import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/customs_clearance_model.dart';

/// Top header for ClearanceFollowupDialog
class ClearanceFollowupHeader extends StatelessWidget {
  final CustomsClearanceModel clearanceRecord;
  final ImportFileModel? importFile;
  final VoidCallback onClose;

  const ClearanceFollowupHeader({
    super.key,
    required this.clearanceRecord,
    required this.importFile,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = clearanceRecord;
    final f = importFile;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      child: Row(
        children: [
          const Icon(Icons.checklist_rtl_rounded, color: AppTheme.emerald, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.isArabic
                      ? 'سجل المتابعات الميدانية للتخليص الجمركي'
                      : 'Field Customs Clearance Follow-up Logs',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${r.clearanceCode} | ${f != null ? f.importFileCode : "File #${r.importFileId}"}'
                  '${r.declaration46No != null ? " | شهادة 46: ${r.declaration46No}" : ""}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
