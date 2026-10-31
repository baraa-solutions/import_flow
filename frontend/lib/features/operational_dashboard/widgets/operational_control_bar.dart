import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/app_shimmer_skeleton.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../providers/operational_dashboard_provider.dart';
import 'operational_format_helper.dart';

/// Control toolbar for the Operational Dashboard containing priority toggles,
/// customs broker dropdown, debounced search, and filter reset.
class OperationalControlBar extends StatelessWidget {
  final OperationalDashboardState dashboardState;
  final OperationalDashboardNotifier notifier;
  final DisplayDensityMode density;
  final TextEditingController searchController;

  static const List<String> priorities = ['All', 'Low', 'Medium', 'High', 'Critical'];

  const OperationalControlBar({
    super.key,
    required this.dashboardState,
    required this.notifier,
    required this.density,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);

    return SelectionArea(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: density.cardPadding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 600;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Priority Button Group (Scrollable if constrained on mobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.priority,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: DisplayDensityMode.clampFontSize(density.tableHeaderFontSize),
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ToggleButtons(
                          isSelected: priorities
                              .map((p) => dashboardState.selectedPriority == p)
                              .toList(),
                          onPressed: (index) => notifier.setPriority(priorities[index]),
                          borderRadius: BorderRadius.circular(6),
                          selectedColor: Colors.white,
                          fillColor: AppTheme.wcagCobalt,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                          borderColor: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                          selectedBorderColor: AppTheme.wcagCobalt,
                          constraints: BoxConstraints(
                            minHeight: density.isUltraCompact ? 28 : (density.isCompact ? 32 : 36),
                            minWidth: density.isUltraCompact ? 48 : (density.isCompact ? 54 : 60),
                          ),
                          children: priorities
                              .map(
                                (p) => Text(
                                  OperationalFormatHelper.getPriorityLabel(p, l),
                                  style: TextStyle(
                                    fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),

                  // Customs Broker Dynamic Select Dropdown
                  dashboardState.data.when(
                    loading: () => SizedBox(
                      width: isCompact ? constraints.maxWidth : 240,
                      child: ShimmerBox(
                        width: 240,
                        height: density.isUltraCompact ? 32 : (density.isCompact ? 36 : 40),
                        borderRadius: 6,
                      ),
                    ),
                    error: (_, __) => const SizedBox(),
                    data: (data) {
                      final brokers = data.availableBrokers;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.customsBrokerLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: DisplayDensityMode.clampFontSize(density.tableHeaderFontSize),
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: isCompact ? constraints.maxWidth : 240,
                            child: SearchableDropdownField<String>(
                              value: dashboardState.selectedBrokerName ?? 'All',
                              labelText: '',
                              items: [
                                SearchableDropdownItem(value: 'All', label: l.allBrokers),
                                ...brokers.map(
                                  (b) => SearchableDropdownItem(
                                    value: b.brokerName,
                                    label: b.brokerName,
                                  ),
                                ),
                              ],
                              onChanged: (val) => notifier.setBroker(val),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // Debounced Search Input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.quickSearchLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: DisplayDensityMode.clampFontSize(density.tableHeaderFontSize),
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: isCompact ? constraints.maxWidth : 260,
                        height: density.isUltraCompact ? 30 : (density.isCompact ? 34 : 38),
                        child: TextField(
                          controller: searchController,
                          style: TextStyle(fontSize: density.inputFontSize),
                          decoration: InputDecoration(
                            hintText: l.dashboardSearchHint,
                            hintStyle: TextStyle(fontSize: density.inputFontSize),
                            prefixIcon: Icon(Icons.search, size: density.buttonIconSize),
                            isDense: true,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (val) => notifier.setSearchQuery(val),
                        ),
                      ),
                    ],
                  ),

                  // Reset Filters Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade700,
                      padding: density.buttonPadding,
                      visualDensity: density.visualDensity,
                    ),
                    onPressed: () {
                      searchController.clear();
                      notifier.resetFilters();
                    },
                    icon: Icon(Icons.restart_alt, size: density.buttonIconSize, color: Colors.white),
                    label: Text(
                      l.resetFilters,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
