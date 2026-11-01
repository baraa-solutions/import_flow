import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../projects/providers/projects_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/cbm_calculator_model.dart';
import '../providers/cbm_calculator_provider.dart';
import 'saved_cbm_registry/cbm_detail_dialog.dart';
import 'saved_cbm_registry/cbm_print_report_dialog.dart';
import 'saved_cbm_registry/cbm_registry_actions.dart';
import 'saved_cbm_registry/cbm_registry_mobile_list.dart';
import 'saved_cbm_registry/cbm_registry_summary_cards.dart';
import 'saved_cbm_registry/cbm_registry_table.dart';

/// Lightweight coordinator tab for saved CBM calculations registry.
class SavedCbmRegistryTab extends ConsumerStatefulWidget {
  final void Function(CBMCalculationModel session) onLoadSession;
  final VoidCallback onSwitchToCalculator;

  const SavedCbmRegistryTab({
    super.key,
    required this.onLoadSession,
    required this.onSwitchToCalculator,
  });

  @override
  ConsumerState<SavedCbmRegistryTab> createState() =>
      _SavedCbmRegistryTabState();
}

class _SavedCbmRegistryTabState extends ConsumerState<SavedCbmRegistryTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cbmCalculatorProvider);
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final poList = ref.watch(purchaseOrdersProvider).purchaseOrders;
    final projectsList = ref.watch(projectsProvider).valueOrNull ?? [];

    final l = context.l10n;
    final totalCalcs = state.calculations.length;
    final activeCalcs = state.calculations.where((c) => c.isActive).length;
    final totalCbmAll =
        state.calculations.fold<double>(0, (sum, c) => sum + c.totalCbm);
    final totalWeightAll = state.calculations
        .fold<double>(0, (sum, c) => sum + c.totalGrossWeightKg);

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Top Summary Cards ─────────────────────────────────────────────
          CbmRegistrySummaryCards(
            totalCalcs: totalCalcs,
            activeCalcs: activeCalcs,
            totalCbmAll: totalCbmAll,
            totalWeightAll: totalWeightAll,
            onRefresh: () =>
                ref.read(cbmCalculatorProvider.notifier).fetchCalculations(),
          ),

          // ─── Search & Filter Bar ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 750;
                final searchField = AppSearchField(
                  controller: _searchController,
                  hint: l.searchCalculationsHint,
                  onChanged: (v) => setState(() {
                    ref
                        .read(cbmCalculatorProvider.notifier)
                        .setSearchQuery(v.trim());
                  }),
                );

                final actionWidgets = <Widget>[
                  FilterChip(
                    avatar: Icon(
                      state.showInactive
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 16,
                      color: state.showInactive
                          ? AppTheme.crimson
                          : AppTheme.textMuted,
                    ),
                    label: Text(
                      state.showInactive ? l.showDeleted : l.hideDeleted,
                      style: TextStyle(
                        fontSize: 12,
                        color: state.showInactive
                            ? AppTheme.crimson
                            : (isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textStrong),
                        fontWeight: state.showInactive
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: state.showInactive,
                    selectedColor: AppTheme.crimson.withValues(alpha: 0.12),
                    checkmarkColor: AppTheme.crimson,
                    onSelected: (val) => ref
                        .read(cbmCalculatorProvider.notifier)
                        .toggleShowInactive(val),
                  ),
                  AppButton(
                    label: l.searchAndCloneCbmBtn,
                    icon: Icons.control_point_duplicate_rounded,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    onPressed: () =>
                        CbmRegistryActions.openSearchAndCloneCBMDialog(
                      context,
                      ref,
                      state.calculations,
                    ),
                  ),
                  AppButton(
                    label: l.exportExcel,
                    icon: Icons.table_chart,
                    variant: AppButtonVariant.success,
                    size: AppButtonSize.small,
                    onPressed: () => CbmRegistryActions.exportCbmListToExcel(
                      context,
                      state.calculations,
                    ),
                  ),
                  AppButton(
                    label: l.exportPdf,
                    icon: Icons.picture_as_pdf,
                    variant: AppButtonVariant.danger,
                    size: AppButtonSize.small,
                    onPressed: () => CbmRegistryActions.exportCbmListToPdf(
                      context,
                      state.calculations,
                    ),
                  ),
                  AppButton(
                    label: l.copyTable,
                    icon: Icons.content_copy,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: () => CbmRegistryActions.copyCbmTableAsTsv(
                      context,
                      state.calculations,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${state.calculations.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cobalt,
                      ),
                    ),
                  ),
                ];

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: actionWidgets,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 16),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: actionWidgets,
                    ),
                  ],
                );
              },
            ),
          ),

          // ─── Data Presentation ─────────────────────────────────────────────
          Expanded(
            child: state.isLoading
                ? const AppLoadingState()
                : state.calculations.isEmpty
                    ? AppEmptyState(
                        icon: Icons.inventory_2_outlined,
                        message: l.noDataFound,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 768) {
                            return CbmRegistryMobileList(
                              calculations: state.calculations,
                              onView: (calc) => _showDetail(
                                context,
                                calc,
                                importFiles,
                                poList,
                                projectsList,
                              ),
                              onEdit: (calc) => widget.onLoadSession(calc),
                              onClone: (calc) =>
                                  CbmRegistryActions.showCloneReviewDialog(
                                context,
                                ref,
                                calc,
                              ),
                              onPrint: (calc) => CbmPrintReportDialog.show(
                                context,
                                calc: calc,
                              ),
                              onDelete: (calc) =>
                                  CbmRegistryActions.handleDeleteOrRestore(
                                context,
                                ref,
                                calc,
                              ),
                            );
                          }
                          return CbmRegistryTable(
                            calculations: state.calculations,
                            importFiles: importFiles,
                            onView: (calc) => _showDetail(
                              context,
                              calc,
                              importFiles,
                              poList,
                              projectsList,
                            ),
                            onEdit: (calc) => widget.onLoadSession(calc),
                            onClone: (calc) =>
                                CbmRegistryActions.showCloneReviewDialog(
                              context,
                              ref,
                              calc,
                            ),
                            onPrint: (calc) => CbmPrintReportDialog.show(
                              context,
                              calc: calc,
                            ),
                            onDelete: (calc) =>
                                CbmRegistryActions.handleDeleteOrRestore(
                              context,
                              ref,
                              calc,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showDetail(
    BuildContext context,
    CBMCalculationModel calc,
    List<ImportFileModel> importFiles,
    List poList,
    List projectsList,
  ) {
    CbmDetailDialog.show(
      context,
      calc: calc,
      importFiles: importFiles,
      onLoadSession: widget.onLoadSession,
      onEditMetadata: (c) =>
          CbmRegistryActions.showEditCalcDialog(context, ref, c),
      onLinkPo: (c) => CbmRegistryActions.showLinkToPODialog(
        context,
        ref,
        c,
        poList,
        projectsList,
      ),
      onPrintReport: (c) => CbmPrintReportDialog.show(context, calc: c),
    );
  }
}
