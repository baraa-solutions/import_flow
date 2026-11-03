import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../import_files/models/import_file_model.dart';
import '../settlement_ui.dart';

class LandedCostFileSelector extends StatelessWidget {
  final List<ImportFileModel> importFiles;
  final int? selectedImportFileId;
  final String selectedImportFileCode;
  final ValueChanged<int?> onFileSelected;

  const LandedCostFileSelector({
    super.key,
    required this.importFiles,
    required this.selectedImportFileId,
    required this.selectedImportFileCode,
    required this.onFileSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final items = importFiles.map((file) {
      final supplier = file.supplierName.isNotEmpty ? file.supplierName : l10n.unknownSupplierFallback;
      final company = file.companyName.isNotEmpty ? file.companyName : '';
      final label = '${file.primaryNameWithCode} — $supplier ${company.isNotEmpty ? "($company)" : ""}';
      return SearchableDropdownItem<int>(
        value: file.importFileId,
        label: label,
      );
    }).toList();

    return SettlementPanel(
      child: Row(
        children: [
          Expanded(
            child: SearchableDropdownField<int>(
              labelText: l10n.settlementCmpFileLabel,
              searchHintText: l10n.selectImportFileDropdownHint,
              value: selectedImportFileId,
              items: items,
              onChanged: onFileSelected,
            ),
          ),
          if (selectedImportFileCode.isNotEmpty) ...[
            const SizedBox(width: 12),
            InkWell(
              onTap: () => CopyHelper.copy(
                context,
                selectedImportFileCode,
                customMessage: l10n.settlementCmpCopiedFileCode,
              ),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                    const SizedBox(width: 6),
                    LtrText(
                      selectedImportFileCode,
                      style: const TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
