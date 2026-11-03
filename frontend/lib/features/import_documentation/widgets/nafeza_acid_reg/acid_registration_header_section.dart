import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../experience_guide/models/guide_entry_model.dart';
import '../../../experience_guide/widgets/experience_guide_alert_banner.dart';

class AcidRegistrationHeaderSection extends StatelessWidget {
  final GuideMatchResultModel? acidGuideMatchResult;
  final String exporterName;
  final String podName;
  final String polName;
  final int? editingAcidSessionId;
  final String? editingAcidCode;
  final VoidCallback onCancelEdit;
  final List<dynamic> importFiles;
  final int? selectedImportFileId;
  final ValueChanged<int?> onImportFileChanged;

  const AcidRegistrationHeaderSection({
    super.key,
    required this.acidGuideMatchResult,
    required this.exporterName,
    required this.podName,
    required this.polName,
    required this.editingAcidSessionId,
    required this.editingAcidCode,
    required this.onCancelEdit,
    required this.importFiles,
    required this.selectedImportFileId,
    required this.onImportFileChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Smart Experience Guide Alert Banner
        if (acidGuideMatchResult != null && acidGuideMatchResult!.matchedEntries.isNotEmpty)
          ExperienceGuideAlertBanner(
            matchResult: acidGuideMatchResult!,
            supplier: exporterName,
            portOfDischarge: podName,
            portOfLoading: polName,
          ),

        // Informational Alert
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cobaltLight : AppTheme.infoBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppTheme.wcagCobalt.withValues(alpha: 0.5) : AppTheme.cobaltBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppTheme.wcagCobalt, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.acidInfoBanner,
                  style: TextStyle(
                    color: isDark ? AppTheme.darkHyperlink : AppTheme.infoForeground,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Edit Mode Banner
        if (editingAcidSessionId != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.orangeLight : AppTheme.warningBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppTheme.wcagOrange : AppTheme.orange, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note, color: AppTheme.orange, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CopyableText(
                        '${l.activeEditModeBanner}: ${editingAcidCode ?? ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.orange : AppTheme.warningForeground,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.acidSessionLoadedForEdit(editingAcidCode ?? ''),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                AppButton(
                  label: l.cancelEdit,
                  onPressed: onCancelEdit,
                  variant: AppButtonVariant.secondary,
                  icon: Icons.close,
                ),
              ],
            ),
          ),
        ],

        // File Selector Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecorationOf(context),
          child: SearchableDropdownField<int>(
            labelText: l.selectImportFileAcidLabel,
            hintText: l.searchFileOrSupplierHint,
            value: selectedImportFileId,
            isRequired: true,
            items: importFiles.map((f) => SearchableDropdownItem<int>(
              value: f.importFileId,
              label: '${f.primaryNameWithCode}${f.poNumber != null && f.poNumber!.isNotEmpty ? " [PO: ${f.poNumber!}]" : ""} — ${f.supplierName} (${f.companyName})',
            )).toList(),
            onChanged: onImportFileChanged,
          ),
        ),
      ],
    );
  }
}
