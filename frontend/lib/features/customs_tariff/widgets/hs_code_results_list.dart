import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/customs_tariff_model.dart';
import '../providers/customs_tariff_provider.dart';

class HsCodeResultsList extends ConsumerWidget {
  final List<CustomsTariffModel> filtered;
  final CustomsTariffModel? selectedTariff;
  final ValueChanged<CustomsTariffModel> onSelectTariff;
  final String searchQuery;

  const HsCodeResultsList({
    super.key,
    required this.filtered,
    required this.selectedTariff,
    required this.onSelectTariff,
    required this.searchQuery,
  });

  void _copyTariffSummary(BuildContext context, WidgetRef ref, CustomsTariffModel item) async {
    final l = context.l10n;
    final ags = await ref.read(customsTariffProvider.notifier).fetchAgreements(item.hsCode);
    if (context.mounted) {
      final text = MasterDataExportService.generateTariffWhatsAppText(item, ags);
      CopyHelper.copy(context, text, customMessage: l.hsExplorerCopySummarySuccess);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l.hsMatchingResultsHeader,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l.hsItemsCount(filtered.length),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppTheme.cobalt,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            l.hsNoMatchingItemFound(searchQuery),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = filtered[idx];
                      final isSelected = selectedTariff?.tariffId == item.tariffId;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: AppTheme.cobalt.withValues(alpha: 0.08),
                        title: Row(
                          children: [
                            Text(
                              item.hsCode,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isSelected ? AppTheme.cobalt : AppTheme.charcoal,
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => CopyHelper.copy(context, item.hsCode, customMessage: l.hsExplorerCopySummarySuccess),
                              borderRadius: BorderRadius.circular(4),
                              child: Tooltip(
                                message: l.hsExplorerCopyHsCodeTooltip,
                                child: const Padding(
                                  padding: EdgeInsets.all(2.0),
                                  child: Icon(Icons.copy_rounded, size: 13, color: AppTheme.cobalt),
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          item.hsDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.hasMultiplePhases) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.amber.shade400),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.timeline_rounded, size: 11, color: Colors.amber.shade900),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${item.totalVersions} مراحل',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green.shade300),
                              ),
                              child: Text(
                                l.hsDutyRateTag(item.customsDutyRate),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.copy_all_rounded, size: 16, color: Colors.grey),
                              tooltip: l.hsExplorerCopySummaryBtn,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              onPressed: () => _copyTariffSummary(context, ref, item),
                            ),
                          ],
                        ),
                        onTap: () => onSelectTariff(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
