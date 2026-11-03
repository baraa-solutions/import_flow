import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/lifecycle_board_model.dart';
import '../services/lifecycle_board_export_service.dart';

/// Filter, search, and export toolbar for the Live Logistics Radar.
class RadarFilterBar extends StatelessWidget {
  final String selectedRiskFilter;
  final String selectedSampleFilter;
  final TextEditingController searchController;
  final List<LiveLogisticsTrackingItemModel> filteredItems;
  final List<ImportFileModel> allImportFiles;
  final ValueChanged<String> onRiskFilterChanged;
  final ValueChanged<String> onSampleFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ScrollController? controller;

  const RadarFilterBar({
    super.key,
    required this.selectedRiskFilter,
    required this.selectedSampleFilter,
    required this.searchController,
    required this.filteredItems,
    required this.allImportFiles,
    required this.onRiskFilterChanged,
    required this.onSampleFilterChanged,
    required this.onSearchChanged,
    this.controller,
  });

  Widget _buildRiskFilterChip(String value, String label, Color color) {
    final isSelected = selectedRiskFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isSelected ? Colors.white : color,
          fontWeight: FontWeight.bold,
        ),
      ),
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.1),
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onSelected: (_) => onRiskFilterChanged(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return SelectionArea(
      child: Container(
        color: Colors.grey.shade50,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: SingleChildScrollView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Search Box
              SizedBox(
                width: 260,
                height: 36,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: searchController,
                  builder: (context, val, _) {
                    return TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        hintText: l10n.searchLiveRadarHint,
                        hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        prefixIcon: const Icon(Icons.search, size: 16, color: AppTheme.cobalt),
                        suffixIcon: val.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                onPressed: () {
                                  searchController.clear();
                                  onSearchChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? AppTheme.darkInputBackground : Colors.white,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Risk Level Filter Chips
              _buildRiskFilterChip('ALL', l10n.riskFilterAll, Colors.grey.shade700),
              const SizedBox(width: 4),
              _buildRiskFilterChip('CRITICAL', l10n.riskFilterCritical, AppTheme.crimson),
              const SizedBox(width: 4),
              _buildRiskFilterChip('WARNING', l10n.riskFilterWarning, AppTheme.orange),
              const SizedBox(width: 4),
              _buildRiskFilterChip('SAFE', l10n.riskFilterSafe, AppTheme.emerald),
              const SizedBox(width: 12),

              // Sample Filter Dropdown
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkInputBackground : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedSampleFilter,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                    onChanged: (val) {
                      if (val != null) onSampleFilterChanged(val);
                    },
                    items: [
                      DropdownMenuItem(value: 'ALL', child: Text(l10n.sampleFilterAll)),
                      DropdownMenuItem(value: 'TESTING', child: Text(l10n.sampleFilterUnderTesting)),
                      DropdownMenuItem(value: 'APPROVED', child: Text(l10n.sampleFilterApproved)),
                      DropdownMenuItem(value: 'REJECTED', child: Text(l10n.sampleFilterRejected)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Radar Export Toolbar
              OutlinedButton.icon(
                onPressed: filteredItems.isEmpty
                    ? null
                    : () => LifecycleBoardExportService.exportRadarToTsv(
                          context: context,
                          items: filteredItems,
                          allImportFiles: allImportFiles,
                        ),
                icon: const Icon(Icons.table_chart_outlined, size: 14),
                label: Text(l10n.lifecycleExportTsvBtn, style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: filteredItems.isEmpty
                    ? null
                    : () => LifecycleBoardExportService.exportRadarToExcel(
                          context: context,
                          items: filteredItems,
                          allImportFiles: allImportFiles,
                        ),
                icon: const Icon(Icons.file_download_outlined, size: 14, color: AppTheme.emerald),
                label: Text(
                  l10n.lifecycleExportExcelBtn,
                  style: const TextStyle(fontSize: 11, color: AppTheme.emerald),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: filteredItems.isEmpty
                    ? null
                    : () => LifecycleBoardExportService.printOrSaveRadarPdf(
                          context: context,
                          items: filteredItems,
                          allImportFiles: allImportFiles,
                        ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 14, color: AppTheme.crimson),
                label: Text(
                  l10n.lifecyclePrintPdfBtn,
                  style: const TextStyle(fontSize: 11, color: AppTheme.crimson),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: filteredItems.isEmpty
                    ? null
                    : () => LifecycleBoardExportService.copyRadarDossier(
                          context: context,
                          items: filteredItems,
                          allImportFiles: allImportFiles,
                        ),
                icon: const Icon(Icons.content_copy_outlined, size: 14, color: AppTheme.cobalt),
                label: Text(
                  l10n.lifecycleCopyDossierBtn,
                  style: const TextStyle(fontSize: 11, color: AppTheme.cobalt),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: filteredItems.isEmpty
                    ? null
                    : () => LifecycleBoardExportService.copyRadarTable(
                          context: context,
                          items: filteredItems,
                          allImportFiles: allImportFiles,
                        ),
                icon: const Icon(Icons.copy_all_outlined, size: 14, color: AppTheme.cobalt),
                label: Text(
                  isAr ? 'نسخ الجدول' : 'Copy Table',
                  style: const TextStyle(fontSize: 11, color: AppTheme.cobalt),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
