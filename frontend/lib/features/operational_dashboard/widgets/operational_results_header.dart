import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../providers/operational_dashboard_provider.dart';
import '../services/operational_dashboard_export_service.dart';
import 'operational_format_helper.dart';

/// Results counter, active filters summary, and export toolbar for the Operational Dashboard.
class OperationalResultsHeader extends StatelessWidget {
  final OperationalDashboardState dashboardState;
  final DisplayDensityMode density;
  final bool isArabic;

  const OperationalResultsHeader({
    super.key,
    required this.dashboardState,
    required this.density,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);

    return SelectionArea(
      child: dashboardState.data.maybeWhen(
        data: (dashboardData) {
          final count = dashboardData.shipmentCount;
          final shipments = dashboardData.shipments;
          final dt = DateTime.tryParse(dashboardData.lastUpdatedAt) ?? DateTime.now();
          final lastUpdated =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

          final List<String> activeFilters = [];
          if (dashboardState.selectedPriority != 'All') {
            activeFilters.add(
              '${l.priority} ${OperationalFormatHelper.getPriorityLabel(dashboardState.selectedPriority, l)}',
            );
          }
          if (dashboardState.selectedBrokerName != null &&
              dashboardState.selectedBrokerName != 'All') {
            activeFilters.add('${l.customsBrokerLabel} ${dashboardState.selectedBrokerName}');
          }
          if (dashboardState.searchQuery.isNotEmpty) {
            activeFilters.add('${l.quickSearchLabel} "${dashboardState.searchQuery}"');
          }
          if (dashboardState.selectedPhase != null) {
            activeFilters.add(
              '${l.currentPhase}: ${OperationalFormatHelper.formatStageName(dashboardState.selectedPhase, isArabic: isArabic)}',
            );
          }
          final filterSummary = activeFilters.join(' | ');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CopyableText(
                    '${l.matchingShipments}: $count ${l.shipmentCountUnit}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: density.tableHeaderFontSize,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                  Text(
                    '${l.lastUpdated}: $lastUpdated',
                    style: TextStyle(
                      fontSize: DisplayDensityMode.clampFontSize(density.tableCellSecondaryFontSize),
                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 4 Linked Output Actions (TSV, Excel, PDF, Dossier)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: density.visualDensity,
                      foregroundColor: AppTheme.cobalt,
                      side: BorderSide(color: AppTheme.cobalt.withValues(alpha: 0.4)),
                    ),
                    icon: Icon(Icons.table_view_outlined, size: density.buttonIconSize, color: AppTheme.cobalt),
                    label: Text(
                      l.operationalExportTsvBtn,
                      style: TextStyle(
                        fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: shipments.isEmpty
                        ? null
                        : () async {
                            await OperationalDashboardExportService.exportTsv(
                              context: context,
                              shipments: shipments,
                              filterSummary: filterSummary,
                            );
                          },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: density.visualDensity,
                      foregroundColor: AppTheme.emerald,
                      side: BorderSide(color: AppTheme.emerald.withValues(alpha: 0.4)),
                    ),
                    icon: Icon(Icons.file_present_outlined, size: density.buttonIconSize, color: AppTheme.emerald),
                    label: Text(
                      l.operationalExportExcelBtn,
                      style: TextStyle(
                        fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: shipments.isEmpty
                        ? null
                        : () async {
                            await OperationalDashboardExportService.exportCsv(
                              context: context,
                              shipments: shipments,
                              filterSummary: filterSummary,
                            );
                          },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: density.visualDensity,
                      foregroundColor: AppTheme.crimson,
                      side: BorderSide(color: AppTheme.crimson.withValues(alpha: 0.4)),
                    ),
                    icon: Icon(Icons.print_outlined, size: density.buttonIconSize, color: AppTheme.crimson),
                    label: Text(
                      l.operationalExportPdfBtn,
                      style: TextStyle(
                        fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: shipments.isEmpty
                        ? null
                        : () async {
                            await OperationalDashboardExportService.printPdf(
                              context: context,
                              shipments: shipments,
                              filterSummary: filterSummary,
                              username: 'Sorour Admin',
                            );
                          },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: density.visualDensity,
                      foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      side: BorderSide(color: isDark ? AppTheme.darkBorderLight : Colors.grey.shade400),
                    ),
                    icon: Icon(
                      Icons.copy_all_outlined,
                      size: density.buttonIconSize,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                    label: Text(
                      l.operationalCopyDossierBtn,
                      style: TextStyle(
                        fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: shipments.isEmpty
                        ? null
                        : () {
                            OperationalDashboardExportService.copyDossier(
                              context: context,
                              shipments: shipments,
                              filterSummary: filterSummary,
                            );
                          },
                  ),
                ],
              ),
            ],
          );
        },
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}
