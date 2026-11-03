import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/project_model.dart';
import 'projects_helpers.dart';

/// Responsive data table for Screen 31: Projects & Cost Centers.
class ProjectsTableView extends StatelessWidget {
  final AsyncValue<List<ProjectModel>> projectsAsync;
  final void Function(ProjectModel project) onView;
  final void Function(ProjectModel project) onEdit;
  final void Function(ProjectModel project) onToggleActive;
  final void Function(ProjectModel project) onCopySummary;
  final VoidCallback onRetry;

  const ProjectsTableView({
    super.key,
    required this.projectsAsync,
    required this.onView,
    required this.onEdit,
    required this.onToggleActive,
    required this.onCopySummary,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return projectsAsync.when(
      loading: () => const AppLoadingState(),
      error: (err, stack) => AppErrorState(
        message: l10n.projectsFetchError(err.toString()),
        onRetry: onRetry,
      ),
      data: (projects) {
        if (projects.isEmpty) {
          return AppEmptyState(
            message: l10n.noProjectsFound,
            icon: Icons.folder_open_outlined,
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width > 1100
                        ? MediaQuery.of(context).size.width - 300
                        : 1050,
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(170),
                      1: FixedColumnWidth(120),
                      2: FlexColumnWidth(3),
                      3: FlexColumnWidth(2.5),
                      4: FlexColumnWidth(2),
                      5: FixedColumnWidth(190),
                      6: FixedColumnWidth(130),
                      7: FixedColumnWidth(95),
                    },
                    children: [
                      // Header Row
                      TableRow(
                        decoration: const BoxDecoration(color: AppTheme.charcoal),
                        children: [
                          l10n.actionsCol,
                          l10n.projectCodeCol,
                          l10n.projectNameAndOwnerCol,
                          l10n.companyAndSupplierCol,
                          l10n.typeAndCategoryCol,
                          l10n.budgetUsdCol,
                          l10n.capabilitiesCol,
                          l10n.statusCol,
                        ]
                            .map((h) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  child: Text(
                                    h,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),

                      // Data Rows
                      ...projects.asMap().entries.map((entry) {
                        final p = entry.value;
                        final isEven = entry.key % 2 == 0;
                        final isActive = p.isActive;

                        final categoriesText = p.shipmentCategory
                            .split(',')
                            .map((c) => ProjectsHelpers.getCategoryLabel(context, c))
                            .join(', ');
                        final rowSummary =
                            ProjectsHelpers.buildProjectRowSummary(context, p);
                        final budgetText = ProjectsHelpers.formatBudget(context, p);
                        final incotermText =
                            p.incotermCode ?? l10n.projectIncotermFallback;

                        return TableRow(
                          decoration: BoxDecoration(
                            color: isEven ? Colors.white : Colors.grey.shade50,
                          ),
                          children: [
                            // Actions
                            _cell(
                              value: p.projectCode,
                              rowSummary: rowSummary,
                              child: RowActionsPill(
                                onView: () => onView(p),
                                onEdit: () => onEdit(p),
                                onPrint: () => onCopySummary(p),
                                printTooltip: l10n.projectCopySummaryBtn,
                                onDelete: () => onToggleActive(p),
                                deleteTooltip: isActive
                                    ? l10n.deactivateProjectTooltip
                                    : l10n.activateProjectTooltip,
                              ),
                            ),
                            // Code
                            _cell(
                              value: p.projectCode,
                              rowSummary: rowSummary,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.cobalt.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: CopyableText(
                                  p.projectCode,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.cobalt,
                                  ),
                                ),
                              ),
                            ),

                            // Project Name & Owner
                            _cell(
                              value: '${p.projectName} (${p.projectOwner})',
                              rowSummary: rowSummary,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CopyableText(
                                    p.projectName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isActive
                                          ? AppTheme.charcoal
                                          : Colors.grey.shade700,
                                      decoration: isActive
                                          ? TextDecoration.none
                                          : TextDecoration.lineThrough,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.projectOwnerLabel(p.projectOwner),
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),

                            // Import Company & Supplier
                            _cell(
                              value:
                                  '${p.companyName ?? l10n.projectCompanyFallback(p.companyId)} - ${p.supplierName ?? '#${p.supplierId}'}',
                              rowSummary: rowSummary,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.companyName ??
                                        l10n.projectCompanyFallback(p.companyId),
                                    style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.projectSupplierLabel(
                                        p.supplierName ?? '#${p.supplierId}'),
                                    style: const TextStyle(
                                        fontSize: 11, color: AppTheme.cobalt),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Type & Category
                            _cell(
                              value:
                                  '${ProjectsHelpers.getImportTypeLabel(context, p.importType)} - $categoriesText ($incotermText)',
                              rowSummary: rowSummary,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ProjectsHelpers.getImportTypeLabel(
                                        context, p.importType),
                                    style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$categoriesText ($incotermText)',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),

                            // Budget USD & Commitments & Target End Date
                            _cell(
                              value: '$budgetText ${p.targetEndDate ?? ""}'.trim(),
                              rowSummary: rowSummary,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    budgetText,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: p.totalBudgetUsd != null
                                          ? AppTheme.emerald
                                          : Colors.grey,
                                    ),
                                  ),
                                  if (p.totalCommittedUsd != null &&
                                      (p.totalCommittedUsd! > 0 ||
                                          (p.poCount ?? 0) > 0)) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${l10n.projectCommitmentsLabel}: \$${p.totalCommittedUsd!.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontSize: 10.5,
                                          color: AppTheme.cobalt,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    if (p.remainingBudgetUsd != null)
                                      Text(
                                        '${l10n.projectRemainingBudgetLabel}: \$${p.remainingBudgetUsd!.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: p.remainingBudgetUsd! >= 0
                                              ? AppTheme.emerald
                                              : AppTheme.crimson,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    if (p.budgetUtilizationPercent != null &&
                                        p.budgetUtilizationPercent! > 0)
                                      Text(
                                        '${l10n.projectUtilizationLabel}: ${p.budgetUtilizationPercent!.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: AppTheme.textSecondaryOf(context),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ] else if ((p.poCount ?? 0) > 0 &&
                                      p.totalCommittedUsd == null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${l10n.projectCommitmentsLabel}: —',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: AppTheme.severityForegroundOf(
                                            context, AppSeverity.warning),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${l10n.projectRemainingBudgetLabel}: —',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textSecondaryOf(context),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (p.missingRateCurrencies.isNotEmpty) ...[
                                      const SizedBox(height: 1),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            size: 12,
                                            color: AppTheme.severityForegroundOf(
                                                context, AppSeverity.warning),
                                          ),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              l10n.projectMissingRateCurrencies(
                                                  p.missingRateCurrencies.join(', ')),
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                color:
                                                    AppTheme.severityForegroundOf(
                                                        context, AppSeverity.warning),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (p.committedByCurrency.isNotEmpty) ...[
                                      const SizedBox(height: 1),
                                      Text(
                                        p.committedByCurrency.entries
                                            .map((e) =>
                                                '${e.value.toStringAsFixed(2)} ${e.key}')
                                            .join(' + '),
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: AppTheme.textSecondaryOf(context),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                  if (p.targetEndDate != null &&
                                      p.targetEndDate!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.event_outlined,
                                            size: 12, color: Colors.grey),
                                        const SizedBox(width: 3),
                                        Text(
                                          p.targetEndDate!,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Capabilities Badges (Multi-Shipment / Multi-Company)
                            _cell(
                              value:
                                  '${p.allowMultiShipment ? l10n.capMultiShipment : ""} ${p.allowMultiCompany ? l10n.capMultiCompany : ""}'
                                      .trim(),
                              rowSummary: rowSummary,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (p.allowMultiShipment)
                                    _capBadge(l10n.capMultiShipment, AppTheme.cobalt),
                                  if (p.allowMultiCompany) ...[
                                    const SizedBox(height: 3),
                                    _capBadge(l10n.capMultiCompany, AppTheme.orange),
                                  ],
                                ],
                              ),
                            ),

                            // Status
                            _cell(
                              value: ProjectsHelpers.getStatusLabel(context, p.status),
                              rowSummary: rowSummary,
                              child: _statusBadge(context, p.status),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _capBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _statusBadge(BuildContext context, String status) {
    return AppStatusBadge.fromStatus(
      status: status,
      label: ProjectsHelpers.getStatusLabel(context, status),
      size: AppStatusBadgeSize.small,
    );
  }

  Widget _cell({
    required Widget child,
    required String value,
    String? rowSummary,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: CopyableTableCell(
            value: value,
            rowSummary: rowSummary,
            child: child,
          ),
        ),
      );
}
