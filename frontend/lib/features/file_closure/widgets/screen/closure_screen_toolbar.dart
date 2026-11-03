import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../warehouse_receiving/widgets/ops_ui_kit.dart';
import '../../models/file_closure_model.dart';

/// Toolbar with actions and search field for File Closure screen
class ClosureScreenToolbar extends StatelessWidget {
  final List<ImportFileClosureModel> records;
  final Map<int, ImportFileModel> filesMap;
  final TextEditingController searchController;
  final VoidCallback onNewCertificate;
  final VoidCallback onSearchAndClone;
  final VoidCallback onCopyTsv;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;

  const ClosureScreenToolbar({
    super.key,
    required this.records,
    required this.filesMap,
    required this.searchController,
    required this.onNewCertificate,
    required this.onSearchAndClone,
    required this.onCopyTsv,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.onSearchChanged,
    required this.onSearchCleared,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      padding: const EdgeInsetsDirectional.all(12),
      child: Row(
        children: [
          Expanded(
            child: OpsActionWrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                AppButton(
                  key: const Key('createClosureBtn'),
                  label: l.fileClosureNewCertificateBtn,
                  icon: Icons.lock_clock,
                  size: AppButtonSize.small,
                  onPressed: onNewCertificate,
                ),
                AppButton(
                  key: const Key('searchAndCloneClosureBtn'),
                  label: l.searchAndCloneFileClosureBtn,
                  icon: Icons.difference_outlined,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: onSearchAndClone,
                ),
                AppButton(
                  key: const Key('copyClosureTableTsvBtn'),
                  label: l.fileClosureExportTsvBtn,
                  icon: Icons.table_chart_outlined,
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.small,
                  onPressed: onCopyTsv,
                ),
                IconButton(
                  key: const Key('exportClosureExcelBtn'),
                  icon: const Icon(Icons.description_outlined, color: AppTheme.emerald),
                  tooltip: l.exportFileClosureExcelTooltip,
                  onPressed: onExportExcel,
                ),
                IconButton(
                  key: const Key('exportClosurePdfBtn'),
                  icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson),
                  tooltip: l.exportFileClosurePdfTooltip,
                  onPressed: onExportPdf,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 240,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: l.fileClosureSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: searchController,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: onSearchCleared,
                    );
                  },
                ),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: onSearchChanged,
            ),
          ),
        ],
      ),
    );
  }
}
