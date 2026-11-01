import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';
import '../../services/financial_export_service.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../financial_ui.dart';

class SavedBudgetsMetricsToolbar extends StatelessWidget {
  final List<ImportBudgetModel> budgetsList;
  final List<ImportBudgetModel> filteredBudgets;
  final TextEditingController searchController;
  final String selectedStatusFilter;
  final ValueChanged<String> onStatusFilterChanged;
  final VoidCallback onSwitchToForm;
  final VoidCallback? onSearchAndClone;
  final WidgetRef ref;

  const SavedBudgetsMetricsToolbar({
    super.key,
    required this.budgetsList,
    required this.filteredBudgets,
    required this.searchController,
    required this.selectedStatusFilter,
    required this.onStatusFilterChanged,
    required this.onSwitchToForm,
    this.onSearchAndClone,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalBudgets = budgetsList.length;
    final approvedBudgets = budgetsList
        .where((b) =>
            b.isActive && (b.budgetStatus.toLowerCase().contains('approved')))
        .length;
    final pendingBudgets = budgetsList
        .where((b) =>
            b.isActive &&
            (b.budgetStatus.toLowerCase().contains('pending') ||
                b.budgetStatus.toLowerCase().contains('draft')))
        .length;
    final totalValueEgp = budgetsList
        .where((b) => b.isActive)
        .fold<double>(0.0, (sum, b) => sum + b.totalBudgetEgp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Summary metrics strip + page actions ----------
        Container(
          color: isDark ? AppTheme.darkScaffoldBackground : AppTheme.cloudWhite,
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FinancialUi.metrics([
                MetricCardData(
                  icon: Icons.account_balance_wallet_outlined,
                  title: l.totalBudgetsMetric,
                  value: '$totalBudgets',
                  color: AppTheme.cobalt,
                ),
                MetricCardData(
                  icon: Icons.verified_rounded,
                  title: l.approvedBudgetsMetric,
                  value: '$approvedBudgets',
                  color: AppTheme.emerald,
                ),
                MetricCardData(
                  icon: Icons.hourglass_top_rounded,
                  title: l.pendingBudgetsMetric,
                  value: '$pendingBudgets',
                  color: AppTheme.orange,
                ),
                MetricCardData(
                  icon: Icons.monetization_on_outlined,
                  title: l.totalValueEgpMetric,
                  value: totalValueEgp > 1000000
                      ? '${(totalValueEgp / 1000000).toStringAsFixed(2)}M EGP'
                      : '${totalValueEgp.toStringAsFixed(0)} EGP',
                  color: AppTheme.emerald,
                ),
              ]),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FinancialUi.fit(AppButton(
                    label: l.refresh,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    icon: Icons.refresh_rounded,
                    onPressed: () {
                      ref
                          .read(importBudgetsProvider.notifier)
                          .fetchImportBudgets();
                      ref.read(importFilesProvider.notifier).fetchImportFiles();
                    },
                  )),
                  FinancialUi.fit(AppButton(
                    label: l.approveNewBudgetAction,
                    variant: AppButtonVariant.success,
                    size: AppButtonSize.small,
                    icon: Icons.add_circle_outline,
                    onPressed: onSwitchToForm,
                  )),
                ],
              ),
            ],
          ),
        ),

        // ─── Filter & Search Toolbar ───────────────────────────────
        Container(
          color: isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: LayoutBuilder(
            builder: (layoutCtx, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final searchField = SizedBox(
                height: 38,
                child: TextField(
                  controller: searchController,
                  style: TextStyle(
                    color:
                        isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: l.searchBudgetsHint,
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textMuted,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: searchController,
                      builder: (context, value, _) {
                        return value.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () => searchController.clear(),
                              )
                            : const SizedBox.shrink();
                      },
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppTheme.darkInputBackground
                        : AppTheme.charcoalSurface,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                          color: isDark
                              ? AppTheme.darkBorder
                              : AppTheme.cloudWhite),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                          color: isDark
                              ? AppTheme.darkBorder
                              : AppTheme.cloudWhite),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: AppTheme.cobalt, width: 1.5),
                    ),
                  ),
                ),
              );

              final actionChipsAndButtons = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildFilterChip(
                      label: '${l.allStatuses} (${budgetsList.where((b) => b.isActive).length})',
                      value: 'ALL',
                      isDark: isDark),
                  _buildFilterChip(
                      label: '${l.approvedBudgetsMetric} ($approvedBudgets)',
                      value: 'Approved',
                      isDark: isDark),
                  _buildFilterChip(
                      label: '${l.pendingBudgetsMetric} ($pendingBudgets)',
                      value: 'Pending',
                      isDark: isDark),
                  if (onSearchAndClone != null)
                    FinancialUi.fit(AppButton(
                      key: const Key('searchAndCloneBudgetRegistryBtn'),
                      label: l.searchAndCloneBudgetBtn,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      icon: Icons.copy_all,
                      onPressed: onSearchAndClone,
                    )),
                  FinancialUi.fit(AppButton(
                    label: l.exportExcel,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    icon: Icons.table_chart_outlined,
                    onPressed: () async {
                      final path =
                          await FinancialExportService.exportBudgetsListToExcel(
                              context: context, list: filteredBudgets);
                      if (path != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          AppTheme.snackBar(
                            context,
                            l.excelSavedSuccess(path),
                            severity: AppSeverity.success,
                          ),
                        );
                      }
                    },
                  )),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 10),
                    actionChipsAndButtons,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: searchField),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: actionChipsAndButtons,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required bool isDark,
  }) {
    final isSelected = selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? AppTheme.white
              : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.cobalt,
      backgroundColor:
          isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoalSurface,
      side: BorderSide(
        color: isSelected
            ? AppTheme.cobalt
            : (isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
      ),
      onSelected: (selected) {
        if (selected) onStatusFilterChanged(value);
      },
    );
  }
}
