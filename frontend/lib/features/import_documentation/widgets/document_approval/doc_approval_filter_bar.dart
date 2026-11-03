import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../import_files/models/import_file_model.dart';
import '../idoc_ui.dart';

class DocApprovalFilterBar extends StatelessWidget {
  final int? selectedImportFileId;
  final List<ImportFileModel> importFiles;
  final ValueChanged<int?> onFileChanged;
  final bool isRunningMatrixCheck;
  final VoidCallback onRunMatrixCheck;
  final VoidCallback onAutoGenerate;
  final VoidCallback onRaiseTicket;
  final String selectedStatusFilter;
  final ValueChanged<String> onStatusFilterChanged;

  const DocApprovalFilterBar({
    super.key,
    required this.selectedImportFileId,
    required this.importFiles,
    required this.onFileChanged,
    required this.isRunningMatrixCheck,
    required this.onRunMatrixCheck,
    required this.onAutoGenerate,
    required this.onRaiseTicket,
    required this.selectedStatusFilter,
    required this.onStatusFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return SelectionArea(
      child: Card(
        elevation: 2,
        color: isDark ? AppTheme.darkCardBackground : null,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 320,
                  child: SearchableDropdownField<int>(
                    value: selectedImportFileId,
                    labelText: context.l10n.customsApprovalImportFileLabel,
                    searchHintText: context.l10n.customsApprovalSearchFileHint,
                    items: importFiles.map((f) {
                      return SearchableDropdownItem(
                        value: f.importFileId,
                        label: '${f.primaryNameWithCode} - ${f.companyName} (${f.supplierName})',
                      );
                    }).toList(),
                    onChanged: onFileChanged,
                  ),
                ),
                const SizedBox(width: 12),
                IdocUi.fit(AppButton(
                  label: context.l10n.customsApprovalRunAiMatrixButton,
                  icon: Icons.auto_awesome,
                  variant: AppButtonVariant.primary,
                  isLoading: isRunningMatrixCheck,
                  onPressed: isRunningMatrixCheck ? null : onRunMatrixCheck,
                )),
                const SizedBox(width: 8),
                IdocUi.fit(AppButton(
                  label: context.l10n.customsApprovalAutoGenerateStandardListButton,
                  icon: Icons.playlist_add_check,
                  variant: AppButtonVariant.secondary,
                  onPressed: onAutoGenerate,
                )),
                const SizedBox(width: 8),
                IdocUi.fit(AppButton(
                  label: context.l10n.customsApprovalRaiseTicketButton,
                  icon: Icons.report_problem_outlined,
                  variant: AppButtonVariant.warning,
                  onPressed: onRaiseTicket,
                )),
                const SizedBox(width: 16),
                const VerticalDivider(width: 1, thickness: 1),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: selectedStatusFilter,
                  underline: const SizedBox.shrink(),
                  icon: Icon(Icons.filter_list, size: 18, color: AppTheme.textPrimaryOf(context)),
                  borderRadius: BorderRadius.circular(8),
                  dropdownColor: isDark ? AppTheme.darkCardBackground : null,
                  items: [
                    DropdownMenuItem(
                      value: 'All',
                      child: Text(
                        context.l10n.customsApprovalFilterAll,
                        style: TextStyle(color: AppTheme.textPrimaryOf(context)),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Pending',
                      child: Text(
                        context.l10n.customsApprovalFilterPending,
                        style: TextStyle(color: AppTheme.textPrimaryOf(context)),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Approved',
                      child: Text(
                        context.l10n.customsApprovalFilterApproved,
                        style: TextStyle(color: AppTheme.textPrimaryOf(context)),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Rejected',
                      child: Text(
                        context.l10n.customsApprovalFilterRejected,
                        style: TextStyle(color: AppTheme.textPrimaryOf(context)),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Discrepancy',
                      child: Text(
                        context.l10n.customsApprovalFilterDiscrepancy,
                        style: TextStyle(color: AppTheme.textPrimaryOf(context)),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) onStatusFilterChanged(val);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
