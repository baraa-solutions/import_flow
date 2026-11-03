import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../broker_quotation_comparison_table.dart';

class BrokerQuoteToolbar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final BrokerQuoteSortOption sortBy;
  final ValueChanged<BrokerQuoteSortOption> onSortChanged;
  final VoidCallback? onExportTsv;

  const BrokerQuoteToolbar({
    super.key,
    required this.searchCtrl,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.sortBy,
    required this.onSortChanged,
    this.onExportTsv,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: searchCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: l10n.clearanceQuotesSearchHint,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: onClearSearch,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                isDense: true,
              ),
              onChanged: onSearchChanged,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.borderOf(context)),
            color: AppTheme.surfaceOf(context),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<BrokerQuoteSortOption>(
              value: sortBy,
              icon: const Icon(Icons.sort_rounded, size: 18),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                fontWeight: FontWeight.w600,
              ),
              onChanged: (opt) {
                if (opt != null) onSortChanged(opt);
              },
              items: [
                DropdownMenuItem(
                  value: BrokerQuoteSortOption.lowestTotal,
                  child: Text(l10n.clearanceQuotesBadgeLowestCost),
                ),
                DropdownMenuItem(
                  value: BrokerQuoteSortOption.fastestTurnaround,
                  child: Text(l10n.clearanceQuotesBadgeFastestDuration),
                ),
                DropdownMenuItem(
                  value: BrokerQuoteSortOption.lowestClearanceFee,
                  child: Text(l10n.clearanceQuotesColClearanceFee),
                ),
                DropdownMenuItem(
                  value: BrokerQuoteSortOption.brokerName,
                  child: Text(l10n.clearanceQuotesColBroker),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.table_view_rounded, color: AppTheme.cobalt, size: 20),
          tooltip: l10n.clearanceQuotesExportTsvBtn,
          onPressed: onExportTsv,
        ),
      ],
    );
  }
}
