import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/lifecycle_board_model.dart';
import '../services/lifecycle_board_export_service.dart';
import 'lifecycle_board_helpers.dart';

/// Top toolbar for the Kanban shipments table with filter chips, export actions, and search input.
class KanbanTableTopBar extends StatelessWidget {
  final List<ShipmentStageCardModel> filteredShipments;
  final List<PhaseSummaryModel> phases;
  final List<ImportFileModel> allImportFiles;
  final int? selectedPhaseId;
  final String? selectedStepCode;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  const KanbanTableTopBar({
    super.key,
    required this.filteredShipments,
    required this.phases,
    required this.allImportFiles,
    required this.selectedPhaseId,
    required this.selectedStepCode,
    required this.searchController,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredCount = filteredShipments.length;

    String selectedTitle = l10n.allShipmentsAllPhases;
    Color badgeColor = AppTheme.cobalt;

    if (selectedStepCode != null) {
      final cleanStepName = DisplayNameResolver.resolveStepName(selectedStepCode!, isArabic: isAr);
      selectedTitle = cleanStepName;
      final phaseStr = kLifecycleStepPhases[selectedStepCode!];
      final phaseId = int.tryParse(phaseStr ?? '1') ?? 1;
      final p = phases.firstWhere((ph) => ph.phaseId == phaseId, orElse: () => phases[0]);
      badgeColor = parseHexColor(p.colorHex);
    } else if (selectedPhaseId != null) {
      final p = phases.firstWhere((ph) => ph.phaseId == selectedPhaseId, orElse: () => phases[0]);
      selectedTitle = l10n.lifecyclePhaseName(p.phaseId, p.titleAr, p.titleEn);
      badgeColor = parseHexColor(p.colorHex);
    }

    return SelectionArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(7),
            topEnd: Radius.circular(7),
          ),
          border: Border(
            bottom: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    if (selectedStepCode != null) ...[
                      const SizedBox(width: 5),
                      LtrText(
                        selectedStepCode!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l10n.shipmentsCountFormatted(filteredCount),
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Kanban Export Toolbar
              OutlinedButton.icon(
                onPressed: filteredShipments.isEmpty
                    ? null
                    : () => LifecycleBoardExportService.exportKanbanToTsv(
                          context: context,
                          shipments: filteredShipments,
                          allImportFiles: allImportFiles,
                          filterTitle: selectedTitle,
                        ),
                icon: Icon(
                  Icons.table_chart_outlined,
                  size: 14,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
                label: Text(
                  l10n.lifecycleExportTsvBtn,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                ),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: filteredShipments.isEmpty
                    ? null
                    : () => LifecycleBoardExportService.exportKanbanToExcel(
                          context: context,
                          shipments: filteredShipments,
                          allImportFiles: allImportFiles,
                          filterTitle: selectedTitle,
                        ),
                icon: const Icon(Icons.file_download_outlined, size: 14, color: AppTheme.emerald),
                label: Text(
                  l10n.lifecycleExportExcelBtn,
                  style: const TextStyle(fontSize: 11, color: AppTheme.emerald),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                ),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: filteredShipments.isEmpty
                    ? null
                    : () => LifecycleBoardExportService.printOrSaveKanbanPdf(
                          context: context,
                          shipments: filteredShipments,
                          phases: phases,
                          allImportFiles: allImportFiles,
                          filterTitle: selectedTitle,
                        ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 14, color: AppTheme.crimson),
                label: Text(
                  l10n.lifecyclePrintPdfBtn,
                  style: const TextStyle(fontSize: 11, color: AppTheme.crimson),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                ),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: filteredShipments.isEmpty
                    ? null
                    : () => LifecycleBoardExportService.copyKanbanDossier(
                          context: context,
                          shipments: filteredShipments,
                          phases: phases,
                          allImportFiles: allImportFiles,
                          filterTitle: selectedTitle,
                        ),
                icon: const Icon(Icons.content_copy_outlined, size: 14, color: AppTheme.cobalt),
                label: Text(
                  l10n.lifecycleCopyDossierBtn,
                  style: const TextStyle(fontSize: 11, color: AppTheme.cobalt),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                ),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: filteredShipments.isEmpty
                    ? null
                    : () => LifecycleBoardExportService.copyKanbanTable(
                          context: context,
                          shipments: filteredShipments,
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
                  side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 220,
                height: 32,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: searchController,
                  builder: (context, val, _) {
                    return TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.searchLifecycleTableHint,
                        hintStyle: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400,
                        ),
                        prefixIcon: const Icon(Icons.search, size: 14, color: AppTheme.cobalt),
                        suffixIcon: val.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  size: 12,
                                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                                ),
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
                          borderRadius: BorderRadius.circular(5),
                          borderSide: BorderSide(
                            color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: BorderSide(
                            color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
