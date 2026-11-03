import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/customs_tariff_model.dart';

class HsCodeSearchToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final List<CustomsTariffModel> filteredItems;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onQuickQuerySelected;

  const HsCodeSearchToolbar({
    super.key,
    required this.searchController,
    required this.filteredItems,
    required this.onQueryChanged,
    required this.onQuickQuerySelected,
  });

  static void copyFilteredTariffsTsv(BuildContext context, List<CustomsTariffModel> items) {
    final l = context.l10n;
    final sb = StringBuffer();
    sb.writeln([
      l.hsExplorerTsvHeaderHsCode,
      l.hsExplorerTsvHeaderDescription,
      l.hsExplorerTsvHeaderCategory,
      l.hsExplorerTsvHeaderDutyRate,
      l.hsExplorerTsvHeaderVatRate,
      l.hsExplorerTsvHeaderScheduleRate,
      l.hsExplorerTsvHeaderDevFeeRate,
      l.hsExplorerTsvHeaderImportFeeRate,
      l.hsExplorerTsvHeaderServiceFeeRate,
      l.hsExplorerTsvHeaderRegulatoryAuthority,
      l.hsExplorerTsvHeaderAcidRequired,
      l.hsExplorerTsvHeaderCooRequired,
      l.hsExplorerTsvHeaderInspectionRequired,
      l.hsExplorerTsvHeaderStatus,
    ].join('\t'));

    for (final t in items) {
      sb.writeln([
        t.hsCode,
        t.hsDescription.replaceAll('\t', ' ').replaceAll('\n', ' '),
        t.categoryLabel(l) ?? '—',
        t.customsDutyRate,
        t.vatRate,
        t.scheduleTaxRate,
        t.developmentFeeRate,
        t.importFeeRate,
        t.customsServiceFeeRate,
        t.regulatoryAuthority ?? '—',
        t.requiresAcid ? '1' : '0',
        t.requiresCoo ? '1' : '0',
        t.requiresInspection ? '1' : '0',
        t.isActive ? '1' : '0',
      ].join('\t'));
    }

    CopyHelper.copy(
      context,
      sb.toString(),
      customMessage: l.hsExplorerExportTsvSuccess,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    final quickQueries = [
      '8415820010',
      '3925900090',
      '0202300000',
      '1001990000',
      '1507100000',
      '1701999000',
      l.hsQuickQueryAc,
      l.hsQuickQueryPlastics,
      l.hsQuickQueryMeat,
      l.hsQuickQueryWheat,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Bar Header
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.saved_search, color: AppTheme.cobalt, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      l.hsExplorerTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.charcoal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l.hsExplorerSubtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                const BackToDashboardButton(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.cobalt,
                    side: const BorderSide(color: AppTheme.cobalt),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  icon: const Icon(Icons.table_chart_outlined, size: 16),
                  label: Text(l.hsExplorerExportTsvBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => copyFilteredTariffsTsv(context, filteredItems),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cobalt,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: Text(l.hsExplorerExportExcelBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => MasterDataExportService.exportTariffsToExcel(context, filteredItems),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Search Bar & Filter Chips
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: searchController,
                      builder: (context, val, _) {
                        return TextField(
                          controller: searchController,
                          onChanged: onQueryChanged,
                          decoration: InputDecoration(
                            hintText: l.hsSearchPlaceholder,
                            prefixIcon: const Icon(Icons.search, color: AppTheme.cobalt),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (val.text.isNotEmpty) ...[
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                                    tooltip: l.hsExplorerCopyHsCodeTooltip,
                                    onPressed: () => CopyHelper.copy(context, searchController.text),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.grey),
                                    onPressed: () {
                                      searchController.clear();
                                      onQueryChanged('');
                                    },
                                  ),
                                ],
                              ],
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    l.hsQuickSearchExamples,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: quickQueries.map((q) {
                          final isSelected = searchController.text == q;
                          return Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: ActionChip(
                              label: Text(q, style: const TextStyle(fontSize: 11)),
                              backgroundColor: isSelected
                                  ? AppTheme.cobalt.withValues(alpha: 0.15)
                                  : Colors.grey.shade100,
                              labelStyle: TextStyle(
                                color: isSelected ? AppTheme.cobalt : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              onPressed: () => onQuickQuerySelected(q),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
