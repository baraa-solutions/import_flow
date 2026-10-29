import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/dynamic_report_models.dart';

class DynamicReportFilterToolbar extends StatelessWidget {
  final ReportTemplateMode templateMode;
  final ValueChanged<ReportTemplateMode> onTemplateModeChanged;
  final VoidCallback onCustomizeColumns;
  final int activeColumnCount;
  final int masterColumnCount;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String filterMode;
  final ValueChanged<String> onFilterModeChanged;
  final String filterPriority;
  final ValueChanged<String> onFilterPriorityChanged;
  final VoidCallback onExportCsv;
  final VoidCallback onExportPdf;
  final VoidCallback onCopyTsv;
  final int filteredCount;

  const DynamicReportFilterToolbar({
    super.key,
    required this.templateMode,
    required this.onTemplateModeChanged,
    required this.onCustomizeColumns,
    required this.activeColumnCount,
    required this.masterColumnCount,
    required this.searchController,
    required this.onSearchChanged,
    required this.filterMode,
    required this.onFilterModeChanged,
    required this.filterPriority,
    required this.onFilterPriorityChanged,
    required this.onExportCsv,
    required this.onExportPdf,
    required this.onCopyTsv,
    required this.filteredCount,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                // Template Selection Chips
                Text('${l.dynTemplatePresetLabel}:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: Row(
                    children: [
                      const Icon(Icons.radar, size: 16),
                      const SizedBox(width: 6),
                      Text(l.dynTemplateEco),
                    ],
                  ),
                  selected: templateMode == ReportTemplateMode.eco,
                  selectedColor: AppTheme.cobalt.withValues(alpha: 0.2),
                  onSelected: (val) {
                    if (val) onTemplateModeChanged(ReportTemplateMode.eco);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Row(
                    children: [
                      const Icon(Icons.assignment_turned_in, size: 16),
                      const SizedBox(width: 6),
                      Text(l.dynTemplateScas),
                    ],
                  ),
                  selected: templateMode == ReportTemplateMode.scas,
                  selectedColor: AppTheme.cobalt.withValues(alpha: 0.2),
                  onSelected: (val) {
                    if (val) onTemplateModeChanged(ReportTemplateMode.scas);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Row(
                    children: [
                      const Icon(Icons.tune, size: 16),
                      const SizedBox(width: 6),
                      Text(l.dynTemplateCustom),
                    ],
                  ),
                  selected: templateMode == ReportTemplateMode.custom,
                  selectedColor: AppTheme.cobalt.withValues(alpha: 0.2),
                  onSelected: (val) {
                    if (val) onTemplateModeChanged(ReportTemplateMode.custom);
                  },
                ),

                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: templateMode == ReportTemplateMode.custom ? AppTheme.cobalt : Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: onCustomizeColumns,
                  icon: const Icon(Icons.view_column, color: Colors.white, size: 18),
                  label: Text(
                    templateMode == ReportTemplateMode.custom
                        ? l.dynCustomizeColumnsBtn(activeColumnCount, masterColumnCount)
                        : l.dynCustomizeColumnsGenericBtn,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),

                const Spacer(),

                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: onExportCsv,
                      icon: const Icon(Icons.table_chart, color: Colors.white, size: 18),
                      label: Text(l.dynExportExcelBtn(filteredCount), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC0392B),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: onExportPdf,
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
                      label: Text(l.dynExportPdfBtn(filteredCount), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.charcoal,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: onCopyTsv,
                      icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                      label: Text(l.dynCopyTsvBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Search and Filters Row
            Row(
              children: [
                // Search Input
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: searchController,
                    builder: (context, val, _) {
                      return TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: l.dynSearchPlaceholder,
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (val.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                                  tooltip: l.copyValue,
                                  onPressed: () => CopyHelper.copy(context, val.text),
                                ),
                              if (val.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    searchController.clear();
                                    onSearchChanged('');
                                  },
                                ),
                            ],
                          ),
                        ),
                        onChanged: onSearchChanged,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Filter Mode
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: filterMode,
                    decoration: InputDecoration(labelText: l.dynFilterModeLabel, isDense: true, border: const OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(value: 'All', child: Text(l.dynModeAll)),
                      DropdownMenuItem(value: 'Sea FCL', child: Text(l.dynModeSeaFcl)),
                      DropdownMenuItem(value: 'Sea LCL', child: Text(l.dynModeSeaLcl)),
                      DropdownMenuItem(value: 'Air', child: Text(l.dynModeAir)),
                      DropdownMenuItem(value: 'Courier', child: Text(l.dynModeCourier)),
                      DropdownMenuItem(value: 'Land', child: Text(l.dynModeLand)),
                      DropdownMenuItem(value: 'Multimodal', child: Text(l.dynModeMultimodal)),
                    ],
                    onChanged: (v) {
                      if (v != null) onFilterModeChanged(v);
                    },
                  ),
                ),
                const SizedBox(width: 10),

                // Filter Priority
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: filterPriority,
                    decoration: InputDecoration(labelText: l.dynFilterPriorityLabel, isDense: true, border: const OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(value: 'All', child: Text(l.dynPriorityAll)),
                      DropdownMenuItem(value: 'High', child: Text(l.dynPriorityHigh)),
                      DropdownMenuItem(value: 'Critical', child: Text(l.dynPriorityCritical)),
                      DropdownMenuItem(value: 'Medium', child: Text(l.dynPriorityMedium)),
                    ],
                    onChanged: (v) {
                      if (v != null) onFilterPriorityChanged(v);
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Active Columns Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.view_column, size: 16, color: AppTheme.cobalt),
                      const SizedBox(width: 6),
                      Text(
                        l.dynActiveColumnsCount(activeColumnCount),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cobalt),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
