import 'package:flutter/material.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/copyable_data_helper.dart';

class SwiftAuditFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String selectedStatusFilter;
  final int totalRequests;
  final int pendingSwift;
  final int matchedSwift;
  final int discrepancySwift;
  final ValueChanged<String> onStatusFilterChanged;
  final VoidCallback onSearchChanged;

  const SwiftAuditFilterBar({
    super.key,
    required this.searchController,
    required this.selectedStatusFilter,
    required this.totalRequests,
    required this.pendingSwift,
    required this.matchedSwift,
    required this.discrepancySwift,
    required this.onStatusFilterChanged,
    required this.onSearchChanged,
  });

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.white : AppTheme.charcoal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.cobalt,
      backgroundColor: AppTheme.charcoalSurface,
      onSelected: (selected) {
        if (selected) onStatusFilterChanged(value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: searchController,
              builder: (context, val, child) {
                return TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: l10n.swiftSearchPlaceholder,
                    prefixIcon: const Icon(Icons.search, color: AppTheme.cobalt),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (val.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged();
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                          tooltip: l10n.swiftCopyBtn,
                          onPressed: () => CopyHelper.copy(context, searchController.text),
                        ),
                      ],
                    ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => onSearchChanged(),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip(l10n.swiftFilterAll(totalRequests), 'ALL'),
              _buildFilterChip(l10n.swiftFilterPending(pendingSwift), 'PENDING'),
              _buildFilterChip(l10n.swiftFilterMatched(matchedSwift), 'MATCHED'),
              _buildFilterChip(l10n.swiftFilterVariances(discrepancySwift), 'DEFICIT'),
            ],
          ),
        ],
      ),
    );
  }
}
