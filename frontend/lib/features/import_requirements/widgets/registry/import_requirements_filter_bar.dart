import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

class ImportRequirementsFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String statusFilter;
  final String riskFilter;
  final String activeFilter;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onRiskChanged;
  final ValueChanged<String?> onActiveChanged;
  final VoidCallback onSearchChanged;

  const ImportRequirementsFilterBar({
    super.key,
    required this.searchController,
    required this.statusFilter,
    required this.riskFilter,
    required this.activeFilter,
    required this.onStatusChanged,
    required this.onRiskChanged,
    required this.onActiveChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cloudWhite),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: searchController,
              builder: (context, val, _) {
                return TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: l10n.searchRequirementsHint,
                    prefixIcon: const Icon(Icons.search, color: AppTheme.cobalt),
                    suffixIcon: val.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged();
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (_) => onSearchChanged(),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SearchableDropdownField<String>(
              labelText: l10n.complianceStatusFilterLabel,
              value: statusFilter,
              items: [
                SearchableDropdownItem(value: 'All', label: l10n.partnerCatAll),
                SearchableDropdownItem(value: 'Draft', label: l10n.overallStatusDraftOption),
                SearchableDropdownItem(value: 'In Progress', label: l10n.overallStatusInProgressOption),
                SearchableDropdownItem(value: 'Complete', label: l10n.overallStatusCompleteOption),
                SearchableDropdownItem(value: 'Confirmed', label: l10n.overallStatusConfirmedOption),
              ],
              onChanged: onStatusChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SearchableDropdownField<String>(
              labelText: l10n.riskLevelFilterLabel,
              value: riskFilter,
              items: [
                SearchableDropdownItem(value: 'All', label: l10n.partnerCatAll),
                SearchableDropdownItem(value: 'Low', label: l10n.riskLevelLowOption),
                SearchableDropdownItem(value: 'Medium', label: l10n.riskLevelMediumOption),
                SearchableDropdownItem(value: 'High', label: l10n.riskLevelHighOption),
              ],
              onChanged: onRiskChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SearchableDropdownField<String>(
              labelText: l10n.activeDeletedFilterLabel,
              value: activeFilter,
              items: [
                SearchableDropdownItem(value: 'All', label: l10n.allRecordsActiveAndDeleted),
                SearchableDropdownItem(value: 'Active', label: l10n.activeOnlyOption),
                SearchableDropdownItem(value: 'Deleted', label: l10n.deletedOnlyOption),
              ],
              onChanged: onActiveChanged,
            ),
          ),
        ],
      ),
    );
  }
}
