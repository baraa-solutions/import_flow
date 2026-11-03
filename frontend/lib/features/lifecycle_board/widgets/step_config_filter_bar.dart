import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/step_config_provider.dart';
import '../services/step_config_export_service.dart';

/// Top search and filter bar for Step Configuration management, including export actions.
class StepConfigFilterBar extends StatelessWidget {
  final StepConfigState state;
  final StepConfigNotifier notifier;
  final TextEditingController searchController;
  final VoidCallback onClearSearch;

  const StepConfigFilterBar({
    super.key,
    required this.state,
    required this.notifier,
    required this.searchController,
    required this.onClearSearch,
  });

  Widget _buildPhaseFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.flatCobalt,
      backgroundColor: const Color(0xFFF1F5F9),
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.maybeLocaleOf(context)?.languageCode == 'ar' ||
        Directionality.of(context) == TextDirection.rtl;

    return SelectionArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        color: Colors.white,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 950;

            final searchAndFilters = Row(
              children: [
                // Search box with copy suffix button
                SizedBox(
                  width: isNarrow ? 220 : 280,
                  height: 38,
                  child: TextField(
                    controller: searchController,
                    onChanged: notifier.setSearchQuery,
                    decoration: InputDecoration(
                      hintText: l.stepConfigSearchHint,
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
                      suffixIcon: searchController.text.isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 15, color: AppTheme.flatCobalt),
                                  tooltip: l.stepConfigSearchCopied,
                                  onPressed: () {
                                    CopyHelper.copy(
                                      context,
                                      searchController.text,
                                      customMessage: l.stepConfigSearchCopied,
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 15, color: Colors.grey),
                                  onPressed: onClearSearch,
                                ),
                              ],
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Phase Filter Pills
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPhaseFilterChip(
                          label: l.stepConfigPhaseAll,
                          isSelected: state.selectedPhaseFilter == null,
                          onSelected: () => notifier.setFilterPhase(null),
                        ),
                        for (int i = 1; i <= 6; i++) ...[
                          const SizedBox(width: 6),
                          _buildPhaseFilterChip(
                            label: l.stepConfigPhaseLabel(i),
                            isSelected: state.selectedPhaseFilter == i,
                            onSelected: () => notifier.setFilterPhase(i),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );

            final exportToolbar = Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () => StepConfigExportService.saveTsvToFile(
                    context,
                    state.filteredConfigs,
                    isArabic: isAr,
                  ),
                  icon: const Icon(Icons.table_view_rounded, size: 16),
                  label: Text(l.stepConfigExportTsvBtn, style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2C3E50),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => StepConfigExportService.saveCsvToFile(
                    context,
                    state.filteredConfigs,
                    isArabic: isAr,
                  ),
                  icon: const Icon(Icons.description_outlined, size: 16, color: Color(0xFF27AE60)),
                  label: Text(l.stepConfigExportExcelBtn, style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF27AE60),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => StepConfigExportService.printOrSavePdf(
                    context,
                    state.filteredConfigs,
                    isArabic: isAr,
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: Text(l.stepConfigPrintPdfBtn, style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.flatCobalt,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => StepConfigExportService.copyDossierToClipboard(
                    context,
                    state.filteredConfigs,
                    isArabic: isAr,
                  ),
                  icon: const Icon(Icons.copy_all_rounded, size: 16),
                  label: Text(l.stepConfigCopyDossierBtn, style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C3E50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  searchAndFilters,
                  const SizedBox(height: 10),
                  exportToolbar,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: searchAndFilters),
                const SizedBox(width: 16),
                exportToolbar,
              ],
            );
          },
        ),
      ),
    );
  }
}
