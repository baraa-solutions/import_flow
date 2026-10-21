import 'dart:math' as math;
import '../../projects/providers/projects_provider.dart';
import '../../../core/utils/container_requirement_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/app_localizations_en.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/cbm_calculator_model.dart';
import '../providers/cbm_calculator_provider.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/services/table_export_service.dart';

class SavedCbmRegistryTab extends ConsumerStatefulWidget {
  final void Function(CBMCalculationModel session) onLoadSession;
  final VoidCallback onSwitchToCalculator;

  const SavedCbmRegistryTab({
    super.key,
    required this.onLoadSession,
    required this.onSwitchToCalculator,
  });

  @override
  ConsumerState<SavedCbmRegistryTab> createState() => _SavedCbmRegistryTabState();
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

    return _buildSavedRegistryTab(context, state, importFiles, poList);
  }

  Widget _buildSavedRegistryTab(
    BuildContext context,
    CBMCalculatorState state,
    List<ImportFileModel> importFiles,
    List poList,
  ) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final totalCalcs = state.calculations.length;
    final activeCalcs = state.calculations.where((c) => c.isActive).length;
    final totalCbmAll = state.calculations.fold<double>(0, (sum, c) => sum + c.totalCbm);
    final totalWeightAll = state.calculations.fold<double>(0, (sum, c) => sum + c.totalGrossWeightKg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── Top Summary Cards (Matching Shipping Study Style) ───────────────
        Container(
          color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _histStatCard(
                    icon: Icons.folder_copy_rounded,
                    label: l.totalCalculationsMetric,
                    value: '$totalCalcs',
                    color: AppTheme.cobalt,
                  ),
                  _histStatCard(
                    icon: Icons.check_circle_rounded,
                    label: l.activeSessionsMetric,
                    value: '$activeCalcs',
                    color: AppTheme.emerald,
                  ),
                  _histStatCard(
                    icon: Icons.view_in_ar_rounded,
                    label: l.totalCbmVolumeMetric,
                    value: '${totalCbmAll.toStringAsFixed(2)} m³',
                    color: AppTheme.wcagOrange,
                  ),
                  _histStatCard(
                    icon: Icons.scale_rounded,
                    label: l.totalGrossWeightRegistryMetric,
                    value: '${totalWeightAll.toStringAsFixed(0)} kg',
                    color: AppTheme.cobalt,
                  ),
                ],
              ),
              // Live Refresh button
              AppButton(
                label: l.refreshRegistry,
                icon: Icons.refresh_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => ref.read(cbmCalculatorProvider.notifier).fetchCalculations(),
              ),
            ],
          ),
        ),

        // ─── Search & Filter Bar ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
            boxShadow: [BoxShadow(color: AppTheme.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 750;
              final searchField = AppSearchField(
                controller: _searchController,
                hint: l.searchCalculationsHint,
                onChanged: (v) => setState(() {
                  ref.read(cbmCalculatorProvider.notifier).setSearchQuery(v.trim());
                }),
              );

              final actionWidgets = <Widget>[
                FilterChip(
                  avatar: Icon(
                    state.showInactive ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                    color: state.showInactive ? AppTheme.crimson : AppTheme.textMuted,
                  ),
                  label: Text(
                    state.showInactive ? l.showDeleted : l.hideDeleted,
                    style: TextStyle(
                      fontSize: 12,
                      color: state.showInactive ? AppTheme.crimson : (isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong),
                      fontWeight: state.showInactive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: state.showInactive,
                  selectedColor: AppTheme.crimson.withValues(alpha: 0.12),
                  checkmarkColor: AppTheme.crimson,
                  onSelected: (val) => ref.read(cbmCalculatorProvider.notifier).toggleShowInactive(val),
                ),
                // Search & Clone Study button (Task D)
                AppButton(
                  label: l.searchAndCloneCbmBtn,
                  icon: Icons.control_point_duplicate_rounded,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  onPressed: () => _openSearchAndCloneCBMDialog(context, state.calculations),
                ),
                // Task J Export & Copy Buttons
                AppButton(
                  label: Directionality.of(context) == TextDirection.rtl || Localizations.localeOf(context).languageCode == 'ar'
                        ? 'تصدير إكسيل'
                        : 'Export Excel',
                  icon: Icons.table_chart,
                  variant: AppButtonVariant.success,
                  size: AppButtonSize.small,
                  onPressed: () => _exportCbmListToExcel(context, state.calculations),
                ),
                AppButton(
                  label: Directionality.of(context) == TextDirection.rtl || Localizations.localeOf(context).languageCode == 'ar'
                        ? 'تصدير PDF'
                        : 'Export PDF',
                  icon: Icons.picture_as_pdf,
                  variant: AppButtonVariant.danger,
                  size: AppButtonSize.small,
                  onPressed: () => _exportCbmListToPdf(context, state.calculations),
                ),
                AppButton(
                  label: Directionality.of(context) == TextDirection.rtl || Localizations.localeOf(context).languageCode == 'ar'
                        ? 'نسخ الجدول'
                        : 'Copy Table',
                  icon: Icons.content_copy,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () => _copyCbmTableAsTsv(context, state.calculations),
                ),
                // Results count chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${state.calculations.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
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

        // ─── Data Table ──────────────────────────────────────────────────────
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
                          return _buildMobileCBMCardList(context, state.calculations);
                        }
                        return SingleChildScrollView(
                          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
                          child: Card(
                            elevation: 2,
                            color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: SelectionArea(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                headingRowHeight: 48,
                                dataRowMinHeight: 52,
                                dataRowMaxHeight: 60,
                                horizontalMargin: 16,
                                columnSpacing: 18,
                                dividerThickness: 0.5,
                                headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal),
                                headingTextStyle: const TextStyle(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.3,
                                ),
                                columns: [
                                  DataColumn(label: SizedBox(
                                    width: 168,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.bolt_rounded, size: 14, color: AppTheme.orange),
                                        const SizedBox(width: 4),
                                        Text(l.actionsCol, style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ],
                                    ),
                                  )),
                                  DataColumn(label: Text(l.calcCodeCol)),
                                  DataColumn(label: Text(l.importFileIdLabel)),
                                  DataColumn(label: Text(l.calculationSessionTitle)),
                                  DataColumn(label: Text(l.totalCbmVolumeMetric)),
                                  DataColumn(label: Text(l.volumetricWeight)),
                                  DataColumn(label: Text(l.grossWeightMetric)),
                                  DataColumn(label: Text(l.stackingCol)),
                                  DataColumn(label: Text(l.shippingStrategyCol)),
                                  DataColumn(label: Text(l.recommendedContainerCol)),
                                  DataColumn(label: Text(l.linkPoProjectCol)),
                                ],
                                rows: state.calculations.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final calc = entry.value;
                                  final isEven = idx.isEven;
                                  final rowColor = !calc.isActive
                                      ? (isDark ? AppTheme.crimson.withValues(alpha: 0.3) : AppTheme.crimsonLight)
                                      : isEven
                                          ? (isDark ? AppTheme.darkCardBackground : AppTheme.white)
                                          : (isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoalSurface);

                                  return DataRow(
                                    color: WidgetStateProperty.all(rowColor),
                                    onSelectChanged: (_) => _showDetailDialog(context, calc),
                                    cells: [
                                      // ⚡ 1. ACTIONS — أول عمود دائماً مرئي بواسطة RowActionsPill
                                      DataCell(
                                        RowActionsPill(
                                          onView: () => _showDetailDialog(context, calc),
                                          onEdit: () => widget.onLoadSession(calc),
                                          onClone: () => _showCloneReviewDialog(context, calc),
                                          cloneTooltip: l.cloneRowTooltip,
                                          onPrint: () => _showPrintReportDialog(context, calc),
                                          onDelete: () => _handleDeleteOrRestore(context, calc),
                                          viewTooltip: l.viewDetails,
                                          editTooltip: l.edit,
                                          printTooltip: l.exportPdf,
                                          deleteTooltip: calc.isActive ? l.delete : l.restore,
                                        ),
                                      ),


                                  // 2. Calc Code
                                  DataCell(
                                    CopyableTableCell(
                                      value: calc.calcCode,
                                      rowSummary: '${calc.calcCode} | ${calc.importFileCode ?? "—"} | ${calc.title ?? ""} | ${calc.totalCbm.toStringAsFixed(3)} m³ | ${calc.airChargeableWeightKg.toStringAsFixed(1)} kg | ${calc.totalGrossWeightKg.toStringAsFixed(1)} kg',
                                      child: InkWell(
                                        onTap: () => _showDetailDialog(context, calc),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cobalt.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.25)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (!calc.isActive)
                                                const Padding(
                                                  padding: EdgeInsetsDirectional.only(end: 4),
                                                  child: Icon(Icons.block, size: 12, color: AppTheme.crimson),
                                                ),
                                              Text(
                                                calc.calcCode,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: calc.isActive ? AppTheme.cobalt : AppTheme.crimson,
                                                  fontSize: 12,
                                                  decoration: calc.isActive ? TextDecoration.none : TextDecoration.lineThrough,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 3. Import File
                                  () {
                                    final rawFileCode = calc.importFileCode ?? (calc.importFileId != null ? 'IMP-${calc.importFileId}' : null);
                                    final resolvedShipmentTitle = rawFileCode != null
                                        ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isAr)
                                        : null;
                                    return DataCell(
                                      CopyableTableCell(
                                        value: resolvedShipmentTitle != null ? '$resolvedShipmentTitle ($rawFileCode)' : (rawFileCode ?? '—'),
                                        rowSummary: calc.calcCode,
                                        child: rawFileCode == null
                                            ? const Text('—', style: TextStyle(color: AppTheme.textMuted))
                                            : Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  if (resolvedShipmentTitle != null && resolvedShipmentTitle != rawFileCode)
                                                    Padding(
                                                      padding: const EdgeInsets.only(bottom: 2),
                                                      child: Text(
                                                        resolvedShipmentTitle,
                                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.cobalt.withValues(alpha: 0.08),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          rawFileCode,
                                                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.cobalt, fontSize: 10.5),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      InkWell(
                                                        onTap: () => CopyHelper.copy(
                                                          context,
                                                          rawFileCode,
                                                          customMessage: '${l.importFile}: $rawFileCode',
                                                        ),
                                                        borderRadius: BorderRadius.circular(4),
                                                        child: const Padding(
                                                          padding: EdgeInsets.all(2.0),
                                                          child: Icon(Icons.copy_rounded, size: 10, color: AppTheme.cobalt),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                      ),
                                    );
                                  }(),

                                  // 4. Title
                                  DataCell(
                                    CopyableTableCell(
                                      value: calc.title ?? l.calculationSessionTitle,
                                      rowSummary: calc.calcCode,
                                      child: SizedBox(
                                        width: 180,
                                        child: Text(
                                          calc.title ?? l.calculationSessionTitle,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 5. Volume CBM
                                  DataCell(
                                    CopyableTableCell(
                                      value: '${calc.totalCbm.toStringAsFixed(3)} m³',
                                      rowSummary: calc.calcCode,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.orangeLight,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppTheme.orange),
                                        ),
                                        child: Text(
                                          '${calc.totalCbm.toStringAsFixed(3)} m³',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.wcagOrange, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 6. Air Chargeable Weight
                                  DataCell(
                                    CopyableTableCell(
                                      value: '${calc.airChargeableWeightKg.toStringAsFixed(1)} kg',
                                      rowSummary: calc.calcCode,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.cobaltLight,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${calc.airChargeableWeightKg.toStringAsFixed(1)} kg',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.wcagCobalt, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 7. Gross Weight
                                  DataCell(
                                    CopyableTableCell(
                                      value: '${calc.totalGrossWeightKg.toStringAsFixed(1)} kg',
                                      rowSummary: calc.calcCode,
                                      child: Text('${calc.totalGrossWeightKg.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                    ),
                                  ),

                                  // 8. Stacking
                                  DataCell(
                                    CopyableTableCell(
                                      value: calc.isStackable ? l.cbmStackingAccepts : l.cbmStackingRejects,
                                      rowSummary: calc.calcCode,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: calc.isStackable ? AppTheme.emeraldLight : AppTheme.crimsonLight,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: calc.isStackable ? AppTheme.emeraldBorder : AppTheme.crimsonBorder),
                                        ),
                                        child: Text(
                                          calc.isStackable ? l.cbmStackingAccepts : l.cbmStackingRejects,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: calc.isStackable ? AppTheme.wcagEmerald : AppTheme.crimson,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 9. Shipping Recommendation
                                  DataCell(
                                    CopyableTableCell(
                                      value: calc.shippingMethodLabel(l),
                                      rowSummary: calc.calcCode,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: AppTheme.cobaltLight, borderRadius: BorderRadius.circular(8)),
                                        child: Text(calc.shippingMethodLabel(l), style: const TextStyle(color: AppTheme.cobalt, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ),

                                  // 10. Container Suggestion
                                  DataCell(
                                    CopyableTableCell(
                                      value: calc.containerTypeLabel(l),
                                      rowSummary: calc.calcCode,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: AppTheme.orangeLight, borderRadius: BorderRadius.circular(8)),
                                        child: Text(calc.containerTypeLabel(l), style: const TextStyle(color: AppTheme.wcagOrange, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ),

                                  // 11. Linked PO / Project
                                  DataCell(
                                    CopyableTableCell(
                                      value: calc.poNumber != null
                                          ? 'PO: ${calc.poNumber}'
                                          : calc.projectName != null
                                              ? 'PRJ: ${calc.projectName}'
                                              : l.cbmNotLinked,
                                      rowSummary: calc.calcCode,
                                      child: Text(
                                        calc.poNumber != null
                                            ? 'PO: ${calc.poNumber}'
                                            : calc.projectName != null
                                                ? 'PRJ: ${calc.projectName}'
                                                : l.cbmNotLinked,
                                        style: TextStyle(
                                          color: calc.poNumber != null ? AppTheme.emerald : AppTheme.textMuted,
                                          fontWeight: calc.poNumber != null ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                       ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _handleDeleteOrRestore(BuildContext context, CBMCalculationModel calc) async {
    final l = context.l10n;
    if (calc.isActive) {
      final confirm = await AppConfirmDialog.show(
        context,
        title: l.confirmSoftDelete,
        message: '${l.confirmDeleteCalcMessage} "${calc.calcCode} - ${calc.title}"?',
        confirmLabel: l.delete,
        cancelLabel: l.cancel,
        confirmVariant: AppButtonVariant.danger,
        icon: Icons.warning_rounded,
      );
      if (confirm == true) {
        await ref.read(cbmCalculatorProvider.notifier).deleteCalculation(calc.calcId!);
      }
    } else {
      await ref.read(cbmCalculatorProvider.notifier).restoreCalculation(calc.calcId!);
    }
  }

  void _showCloneReviewDialog(BuildContext context, CBMCalculationModel calc) {
    final l = context.l10n;
    CloneEntityReviewDialog.show(
      context,
      entityType: l.cloneCbmDialogTitle,
      sourceCode: calc.calcCode,
      suggestedNewCode: '${calc.calcCode}-CLONE',
      sourceTitle: calc.title ?? calc.calcCode,
      copiedFieldsSummary: {
        l.calculationSessionTitle: calc.title ?? '-',
        l.totalCbmVolumeMetric: '${calc.totalCbm.toStringAsFixed(2)} m³',
        l.grossWeightMetric: '${calc.totalGrossWeightKg.toStringAsFixed(0)} kg',
        l.stackingCol: calc.isStackable ? l.stackable : l.nonStackable,
        l.shippingStrategyCol: calc.shippingMethodLabel(l),
      },
      mandatorilyResetFields: [
        l.cloneFieldCalcCodeGenerated,
        l.cloneFieldImportFileReset,
        l.cloneFieldPoReset,
      ],
      allowCopyLineItems: true,
      allowCopyAttachments: false,
      initialCopyLineItems: true,
      initialCopyAttachments: false,
      onConfirm: ({
        required newCode,
        required newTitle,
        required copyLineItems,
        required copyAttachments,
        notes,
      }) async {
        final cloned = await ref.read(cbmCalculatorProvider.notifier).cloneCalculation(
          calc.calcId!,
          newCode: newCode,
          newTitle: newTitle,
          copyItems: copyLineItems,
          notes: notes,
        );
        if (cloned != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.cloneCbmSuccess(cloned.calcCode)),
              backgroundColor: AppTheme.emerald,
            ),
          );
        }
      },
    );
  }

  Future<void> _openSearchAndCloneCBMDialog(BuildContext context, List<CBMCalculationModel> calculations) async {
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final locale = isArabic ? const Locale('ar') : const Locale('en');
    final selectedCalc = await showDialog<CBMCalculationModel>(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: locale,
        child: Directionality(
          textDirection: textDir,
          child: _SearchAndCloneCBMDialog(
            calculations: calculations,
            onSelectCalculation: (calc) {
              Navigator.of(ctx).pop(calc);
            },
          ),
        ),
      ),
    );
    if (selectedCalc != null && context.mounted) {
      _showCloneReviewDialog(context, selectedCalc);
    }
  }

  Widget _buildMobileCBMCardList(
    BuildContext context,
    List<CBMCalculationModel> calcs,
  ) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
      itemCount: calcs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final calc = calcs[index];
        final isAir = calc.isAirRecommended;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: !calc.isActive
                ? (isDark ? AppTheme.crimson.withValues(alpha: 0.2) : AppTheme.crimsonLight)
                : (isDark ? AppTheme.darkCardBackground : AppTheme.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Code, Title, Mode chip
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showDetailDialog(context, calc),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            calc.calcCode,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            calc.title ?? calc.calcCode,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AppStatusBadge(
                    label: calc.shippingMethodLabel(l),
                    severity: isAir ? AppSeverity.info : AppSeverity.success,
                    size: AppStatusBadgeSize.small,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Metrics row
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    '${l.totalCbmVolumeMetric}: ${calc.totalCbm.toStringAsFixed(2)} m³',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.wcagOrange),
                  ),
                  Text(
                    '${l.grossWeightMetric}: ${calc.totalGrossWeightKg.toStringAsFixed(0)} kg',
                    style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong),
                  ),
                  if (calc.totalVolumetricWeightKg > 0)
                    Text(
                      '${l.volumetricWeight}: ${calc.totalVolumetricWeightKg.toStringAsFixed(0)} kg',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.cobalt),
                    ),
                ],
              ),
              const SizedBox(height: 4),

              // Stacking / packages count
              Text(
                '${l.stackingCol}: ${calc.isStackable ? l.stackable : l.nonStackable} | ${calc.items.length} ${l.itemsAndPackagesCol}',
                style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
              ),

              const Divider(height: 16),

              // Actions pill at bottom start
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: RowActionsPill(
                  onView: () => _showDetailDialog(context, calc),
                  onEdit: () => widget.onLoadSession(calc),
                  onClone: () => _showCloneReviewDialog(context, calc),
                  cloneTooltip: l.cloneRowTooltip,
                  onPrint: () => _showPrintReportDialog(context, calc),
                  onDelete: () => _handleDeleteOrRestore(context, calc),
                  viewTooltip: l.viewDetails,
                  editTooltip: l.edit,
                  printTooltip: l.exportPdf,
                  deleteTooltip: calc.isActive ? l.delete : l.restore,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// بطاقة إحصائية صغيرة في شريط ملخص السجل
  Widget _histStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SAVE CALCULATION DIALOG
  // ---------------------------------------------------------------------------
  void _showDetailDialog(BuildContext context, CBMCalculationModel calc) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final rawFileCode = calc.importFileCode ?? (calc.importFileId != null ? 'IMP-${calc.importFileId}' : null);
    final resolvedShipmentTitle = rawFileCode != null
        ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isArabic)
        : null;
    final containerRec = ContainerRequirementEngine.calculate(
      totalCbm: calc.totalCbm,
      totalWeightKg: calc.totalGrossWeightKg,
      isStackable: calc.isStackable,
    );
    final dualRec = ContainerRequirementEngine.calculateBoth(
      totalCbm: calc.totalCbm,
      totalWeightKg: calc.totalGrossWeightKg,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardBackground : null,
        title: Row(
          children: [
            const Icon(Icons.view_in_ar_rounded, color: AppTheme.cobalt, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l.cbmSessionDetailsTitle(calc.calcCode),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
              ),
            ),
            AppStatusBadge(
              label: calc.isActive ? l.cbmSessionActiveBadge : l.cbmSessionCancelledBadge,
              severity: calc.isActive ? AppSeverity.success : AppSeverity.danger,
              size: AppStatusBadgeSize.small,
            ),
            const SizedBox(width: 8),
            AppStatusBadge(
              label: calc.poNumber != null
                  ? l.cbmSessionLinkedPo(calc.poNumber!)
                  : (rawFileCode != null
                      ? (resolvedShipmentTitle != null && resolvedShipmentTitle != rawFileCode
                          ? '$resolvedShipmentTitle ($rawFileCode)'
                          : l.cbmSessionImportFile(rawFileCode))
                      : l.cbmSessionStandalone),
              severity: AppSeverity.info,
              size: AppStatusBadgeSize.small,
            ),
          ],
        ),
        content: SizedBox(
          width: 920,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Overview Card (Matching Shipping Evaluation Style)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkElevatedSurface : AppTheme.emeraldLight.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.emeraldBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              calc.title ?? l.calculationSessionTitle,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            ),
                            if (calc.notes != null && calc.notes!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(l.cbmCargoNotes(calc.notes!), style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal, fontSize: 12)),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              l.cbmCreationDate(calc.createdAt != null ? calc.createdAt.toString().substring(0, 16) : "—"),
                              style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (rawFileCode != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  resolvedShipmentTitle != null && resolvedShipmentTitle != rawFileCode
                                      ? '$resolvedShipmentTitle ($rawFileCode)'
                                      : l.cbmSessionImportFile(rawFileCode),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                ),
                              ),
                            if (calc.poNumber != null) ...[
                              const SizedBox(height: 4),
                              Text(l.cbmSessionLinkedPo(calc.poNumber!), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 11)),
                            ],
                            const SizedBox(height: 4),
                            Text(l.cbmStrategy(calc.shippingMethodLabel(l)), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Metrics Strip Cards Row
                Text(l.cbmStandardMetricsTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildDetailCardBadge(l.totalCbmVolumeMetric, '${calc.totalCbm.toStringAsFixed(4)} m³', Icons.view_in_ar_rounded, AppTheme.wcagOrange),
                    _buildDetailCardBadge(l.airChargeableWtMetric, '${calc.airChargeableWeightKg.toStringAsFixed(1)} KG', Icons.airplanemode_active, AppTheme.wcagCobalt),
                    _buildDetailCardBadge(l.totalGrossWeightRegistryMetric, '${calc.totalGrossWeightKg.toStringAsFixed(1)} KG', Icons.scale_rounded, AppTheme.cobalt),
                    _buildDetailCardBadge(l.cargoStackingInstructions, calc.isStackable ? l.stackableOption : l.nonStackableOption, Icons.inventory_2_rounded, calc.isStackable ? AppTheme.emerald : AppTheme.wcagOrange),
                    _buildDetailCardBadge(l.cbmShipmentMode, calc.shipmentModeLabel(l), Icons.flight_takeoff_rounded, AppTheme.cobalt),
                    _buildDetailCardBadge(l.shippingStrategyCol, calc.shippingMethodLabel(l), Icons.directions_boat_rounded, AppTheme.wcagCobalt),
                    _buildDetailCardBadge(l.recommendedContainerCol, isArabic ? containerRec.recommendationSummary : containerRec.recommendationSummaryEn, Icons.local_shipping_rounded, AppTheme.wcagOrange),
                  ],
                ),

                const SizedBox(height: 16),

                // 3. Dual Container Matrix Comparison Box (Matching Container Comparison Style)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkElevatedSurface : AppTheme.cobaltLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cobaltBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.compare_arrows_rounded, color: AppTheme.cobalt, size: 20),
                              const SizedBox(width: 6),
                              Text(l.cbmContainerComparisonTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.cobalt, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              calc.isStackable ? l.cbmScenarioApprovedStackable : l.cbmScenarioApprovedNonStackable,
                              style: const TextStyle(color: AppTheme.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Table(
                        border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoal.withValues(alpha: 0.06)),
                            children: [
                              Padding(padding: const EdgeInsets.all(6), child: Text(l.cbmScenarioHypothesisCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                              Padding(padding: const EdgeInsets.all(6), child: Text(l.cbmScenarioStackableCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.emerald))),
                              Padding(padding: const EdgeInsets.all(6), child: Text(l.cbmScenarioNonStackableCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.orange))),
                            ],
                          ),
                          TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(6), child: Text(l.cbmRequiredContainerCount, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                              Padding(padding: const EdgeInsets.all(6), child: Text('${dualRec.stackableResult.requiredContainersCount} x ${dualRec.stackableResult.recommendedContainerCode}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: Text('${dualRec.nonStackableResult.requiredContainersCount} x ${dualRec.nonStackableResult.recommendedContainerCode}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange, fontSize: 11))),
                            ],
                          ),
                          TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(6), child: Text(l.cbmSpaceUtilizationPercent, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                              Padding(padding: const EdgeInsets.all(6), child: Text('${dualRec.stackableResult.spaceUtilizationPercent.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                              Padding(padding: const EdgeInsets.all(6), child: Text('${dualRec.nonStackableResult.spaceUtilizationPercent.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 24),

                // 4. Package Breakdown Section Header & Action Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l.packageMeasurementsTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                    AppButton(
                      label: l.visualLoadPlanSimulator,
                      icon: Icons.view_in_ar,
                      variant: AppButtonVariant.success,
                      size: AppButtonSize.small,
                      onPressed: () {
                        _showVisualLoadPlanDialog(context, calc.items);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 5. Table of Packages
                Table(
                  border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                  columnWidths: const {
                    0: FlexColumnWidth(0.6),
                    1: FlexColumnWidth(1.8),
                    2: FlexColumnWidth(1.0),
                    3: FlexColumnWidth(2.0),
                    4: FlexColumnWidth(1.4),
                    5: FlexColumnWidth(1.5),
                    6: FlexColumnWidth(1.6),
                    7: FlexColumnWidth(1.6),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoal.withValues(alpha: 0.08)),
                      children: [
                        Padding(padding: const EdgeInsets.all(8), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(l.packageTypeCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(l.qtyCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(l.cbmPackageDimensionsCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(l.grossWtPerUnitCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(l.totalGrossWeightRegistryMetric, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(l.stackingCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(l.cbmVolumeMetric, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                      ],
                    ),
                    ...calc.items.asMap().entries.map(
                      (entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final lineGross = item.quantity * item.grossWeightPerUnitKg;
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(8), child: Text('${idx + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(item.packageType, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${item.quantity}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${item.lengthCm} x ${item.widthCm} x ${item.heightCm}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${item.grossWeightPerUnitKg} kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${lineGross.toStringAsFixed(1)} kg', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.isStackable ? (isDark ? AppTheme.emerald.withValues(alpha: 0.15) : AppTheme.emeraldLight) : (isDark ? AppTheme.crimson.withValues(alpha: 0.15) : AppTheme.crimsonLight),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: item.isStackable ? (isDark ? AppTheme.emerald : AppTheme.emeraldBorder) : (isDark ? AppTheme.crimson : AppTheme.crimsonBorder)),
                                ),
                                child: Text(
                                  item.isStackable ? l.stackableOption : l.nonStackableOption,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: item.isStackable ? AppTheme.emerald : AppTheme.crimson,
                                  ),
                                ),
                              ),
                            ),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${item.totalCbm.toStringAsFixed(4)} m³', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.wcagOrange, fontSize: 11))),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton(
            label: l.cbmReopenInCalcBtn,
            icon: Icons.edit_note,
            variant: AppButtonVariant.primary,
            onPressed: () {
              Navigator.pop(dialogCtx);
              widget.onLoadSession(calc);
            },
          ),
          AppButton(
            label: l.cbmEditMetadataBtn,
            icon: Icons.edit,
            variant: AppButtonVariant.warning,
            onPressed: () {
              Navigator.pop(dialogCtx);
              _showEditCalcDialog(context, calc);
            },
          ),
          AppButton(
            label: l.cbmLinkToPoProjectBtn,
            icon: Icons.link,
            variant: AppButtonVariant.primary,
            onPressed: () {
              Navigator.pop(dialogCtx);
              _showLinkToPODialog(
                context,
                calc,
                ref.read(purchaseOrdersProvider).purchaseOrders,
                ref.read(projectsProvider).valueOrNull ?? [],
              );
            },
          ),
          AppButton(
            label: l.cbmPrintExportReportBtn,
            icon: Icons.print,
            variant: AppButtonVariant.success,
            onPressed: () {
              Navigator.pop(dialogCtx);
              _showPrintReportDialog(context, calc);
            },
          ),
          AppButton(
            label: l.close,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(dialogCtx),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCardBadge(String title, String val, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 280,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted, fontWeight: FontWeight.bold)),
                Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditCalcDialog(BuildContext context, CBMCalculationModel calc) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: calc.title ?? '');
    final notesCtrl = TextEditingController(text: calc.notes ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardBackground : null,
        title: Text(l.cbmEditMetadataDialogTitle(calc.calcCode)),
        content: SizedBox(
          width: 500,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  decoration: InputDecoration(labelText: l.cbmMetadataTitleLabel),
                  validator: (v) => v == null || v.trim().isEmpty ? l.requiredFieldValidation : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: l.cbmMetadataNotesLabel),
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton(
            label: l.cancel,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          AppButton(
            label: l.save,
            variant: AppButtonVariant.primary,
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final ok = await ref.read(cbmCalculatorProvider.notifier).updateCalculation(
                  calc.calcId!,
                  {
                    'title': titleCtrl.text.trim(),
                    'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  },
                );
                if (ok && context.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.cbmMetadataSavedSuccess)),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showPrintReportDialog(BuildContext context, CBMCalculationModel calc) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardBackground : null,
        title: Row(
          children: [
            const Icon(Icons.print_outlined, color: AppTheme.emerald),
            const SizedBox(width: 8),
            Text(l.cbmPrintableReportTitle(calc.calcCode)),
          ],
        ),
        content: SizedBox(
          width: 780,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Official Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sorour Logistics ERP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                          Text(l.cbmCalculatorTitle, style: const TextStyle(color: AppTheme.cobalt, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(l.cbmCalculatorSubtitle, style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary, fontSize: 11)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppTheme.cobalt, borderRadius: BorderRadius.circular(4)),
                            child: Text(calc.calcCode, style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(height: 4),
                          Text(l.cbmCreationDate(calc.createdAt != null ? calc.createdAt.toString().substring(0, 10) : DateTime.now().toString().substring(0, 10)), style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24, thickness: 1.5),

                  // Session Metadata
                  Row(
                    children: [
                      Expanded(child: Text('${l.calculationSessionTitle}: ${calc.title ?? "-"}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : null))),
                      if (calc.poNumber != null)
                        Text(l.cbmSessionLinkedPo(calc.poNumber!), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 12)),
                    ],
                  ),
                  if (calc.notes != null && calc.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(l.cbmCargoNotes(calc.notes!), style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted)),
                  ],
                  const SizedBox(height: 16),

                  // Summary Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoalSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildReportStat(l.totalCbmVolumeMetric, '${calc.totalCbm.toStringAsFixed(4)} m³', AppTheme.orange, isDark),
                        _buildReportStat(l.airChargeableWtMetric, '${calc.airChargeableWeightKg.toStringAsFixed(1)} kg', AppTheme.cobalt, isDark),
                        _buildReportStat(l.totalGrossWeightRegistryMetric, '${calc.totalGrossWeightKg.toStringAsFixed(1)} kg', AppTheme.cobalt, isDark),
                        _buildReportStat(l.cargoStackingInstructions, calc.isStackable ? l.stackableOption : l.nonStackableOption, AppTheme.emerald, isDark),
                        _buildReportStat(l.shippingStrategyCol, calc.shippingMethodLabel(l), AppTheme.cobalt, isDark),
                        _buildReportStat(l.recommendedContainerCol, calc.containerTypeLabel(l), AppTheme.wcagOrange, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Package Details Table
                  Text(l.packageMeasurementsTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : null)),
                  const SizedBox(height: 8),
                  Table(
                    border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.textMuted),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: isDark ? AppTheme.darkCardBackground : AppTheme.cloudWhite),
                        children: [
                          Padding(padding: const EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                          Padding(padding: const EdgeInsets.all(6), child: Text(l.packageTypeCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                          Padding(padding: const EdgeInsets.all(6), child: Text(l.qtyCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                          Padding(padding: const EdgeInsets.all(6), child: Text(l.cbmPackageDimensionsCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                          Padding(padding: const EdgeInsets.all(6), child: Text(l.grossWtPerUnitCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                          Padding(padding: const EdgeInsets.all(6), child: Text(l.stackingCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                          Padding(padding: const EdgeInsets.all(6), child: Text(l.totalGrossWeightRegistryMetric, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                          Padding(padding: const EdgeInsets.all(6), child: Text(l.cbmVolumeMetric, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                        ],
                      ),
                      ...calc.items.asMap().entries.map(
                        (entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          final lineGross = item.quantity * item.grossWeightPerUnitKg;
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(6), child: Text('${idx + 1}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                              Padding(padding: const EdgeInsets.all(6), child: Text(item.packageType, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                              Padding(padding: const EdgeInsets.all(6), child: Text('${item.quantity}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                              Padding(padding: const EdgeInsets.all(6), child: Text('${item.lengthCm}x${item.widthCm}x${item.heightCm}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                              Padding(padding: const EdgeInsets.all(6), child: Text('${item.grossWeightPerUnitKg} kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                              Padding(padding: const EdgeInsets.all(6), child: Text(item.isStackable ? l.stackableOption : l.nonStackableOption, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: item.isStackable ? AppTheme.wcagEmerald : AppTheme.crimson))),
                              Padding(padding: const EdgeInsets.all(6), child: Text('${lineGross.toStringAsFixed(1)} kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                              Padding(padding: const EdgeInsets.all(6), child: Text('${item.totalCbm.toStringAsFixed(4)} m³', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orange))),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          AppButton(
            label: l.cbmPrintDownloadCsvBtn,
            icon: Icons.download,
            variant: AppButtonVariant.success,
            onPressed: () {
              _downloadCalcCSV(context, calc);
            },
          ),
          AppButton(
            label: l.cbmPrintReportBtn,
            icon: Icons.print,
            variant: AppButtonVariant.primary,
            onPressed: () {
              _triggerReportPrint(context, calc);
            },
          ),
          AppButton(
            label: l.close,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(dialogCtx),
          ),
        ],
      ),
    );
  }

  Widget _buildReportStat(String label, String val, Color color, [bool isDark = false]) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted, fontWeight: FontWeight.bold)),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Future<void> _downloadCalcCSV(BuildContext context, CBMCalculationModel calc) async {
    final l = context.l10n;
    final buffer = StringBuffer();
    buffer.writeln('Sorour Logistics ERP - Cargo Volume & Weight Measurement Report');
    buffer.writeln('Calc Code,${calc.calcCode}');
    buffer.writeln('Title,${calc.title ?? ""}');
    buffer.writeln('Notes,${calc.notes ?? ""}');
    buffer.writeln('Total CBM,${calc.totalCbm}');
    buffer.writeln('Air Chargeable Weight (kg),${calc.airChargeableWeightKg}');
    buffer.writeln('Total Gross Weight (kg),${calc.totalGrossWeightKg}');
    buffer.writeln('Shipment Mode,${calc.shipmentModeLabel(const AppLocalizationsEn())}');
    buffer.writeln('Shipping Recommendation,${calc.shippingMethodLabel(const AppLocalizationsEn())}');
    buffer.writeln('Cargo Stacking,${calc.isStackable ? "Stackable" : "Non-Stackable"}');
    buffer.writeln('');
    buffer.writeln('Pkg #,Package Type,Qty,Length (cm),Width (cm),Height (cm),Gross Wt/Unit (kg),Stacking,Line CBM (m3),Total Gross Wt (kg)');

    for (int i = 0; i < calc.items.length; i++) {
      final item = calc.items[i];
      final lineGross = item.quantity * item.grossWeightPerUnitKg;
      buffer.writeln('${i + 1},${item.packageType},${item.quantity},${item.lengthCm},${item.widthCm},${item.heightCm},${item.grossWeightPerUnitKg},${item.isStackable ? "Stackable" : "Non-Stackable"},${item.totalCbm},$lineGross');
    }

    final filename = 'Phase1_CBM_Measurement_Report_${calc.calcCode}_${DateTime.now().millisecondsSinceEpoch}.csv';
    await FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: l.cbmDownloadCsvTitle,
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  void _triggerReportPrint(BuildContext context, CBMCalculationModel calc) {
    final l = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.cbmSendingReportToScreen(calc.calcCode)),
        backgroundColor: AppTheme.cobalt,
      ),
    );
  }

  void _showLinkToPODialog(
    BuildContext context,
    CBMCalculationModel calc,
    List poList,
    List projectsList,
  ) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int? selectedPoId = calc.poId;
    int? selectedProjectId = calc.projectId;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCardBackground : null,
          title: Text(l.cbmLinkPoDialogTitle(calc.calcCode)),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchableDropdownField<int?>(
                  value: selectedPoId,
                  labelText: l.cbmLinkSelectPoLabel,
                  searchHintText: l.cbmLinkSelectPoSearchHint,
                  items: [
                    SearchableDropdownItem<int?>(value: null, label: l.cbmSessionStandalone),
                    ...poList.map((po) => SearchableDropdownItem<int?>(
                          value: po.poId,
                          label: '${po.displayName} (${po.poNumber}) (${po.projectName ?? "Project"})',
                          subtitle: po.supplierName,
                        )),
                  ],
                  onChanged: (v) => setDialogState(() => selectedPoId = v),
                ),
                const SizedBox(height: 12),
                SearchableDropdownField<int?>(
                  value: selectedProjectId,
                  labelText: l.cbmLinkSelectProjectLabel,
                  searchHintText: l.cbmLinkSelectProjectSearchHint,
                  items: [
                    SearchableDropdownItem<int?>(value: null, label: l.cbmSessionStandalone),
                    ...projectsList.map((p) => SearchableDropdownItem<int?>(
                          value: p.projectId,
                          label: '${p.projectCode} - ${p.projectName}',
                        )),
                  ],
                  onChanged: (v) => setDialogState(() => selectedProjectId = v),
                ),
              ],
            ),
          ),
          actions: [
            AppButton(
              label: l.cancel,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () => Navigator.pop(dialogCtx),
            ),
            AppButton(
              label: l.save,
              variant: AppButtonVariant.primary,
              onPressed: () async {
                final ok = await ref
                    .read(cbmCalculatorProvider.notifier)
                    .linkToPO(calc.calcId!, poId: selectedPoId, projectId: selectedProjectId);
                if (ok && context.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.cbmLinkSavedSuccess)),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  void _showContainerComparisonDialog(BuildContext context, ContainerDualRecommendationResult dualRec, double totalCbm, double totalWeightKg) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return DefaultTabController(
          length: 2,
          child: AlertDialog(
            backgroundColor: isDark ? AppTheme.darkCardBackground : null,
            title: Row(
              children: [
                const Icon(Icons.inventory_2, color: AppTheme.cobalt),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.cbmContainerComparisonTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${l.totalCbmVolumeMetric}: ${totalCbm.toStringAsFixed(2)} m³ | ${totalWeightKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 12, color: AppTheme.cobalt, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 750,
              height: 480,
              child: Column(
                children: [
                  Container(
                    color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
                    child: TabBar(
                      indicatorColor: AppTheme.cobalt,
                      labelColor: AppTheme.white,
                      unselectedLabelColor: Colors.white70,
                      tabs: [
                        Tab(icon: const Icon(Icons.layers), text: l.allStackableOption),
                        Tab(icon: const Icon(Icons.view_array), text: l.allNonStackableOption),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildComparisonTable(context, dualRec.stackableResult),
                        _buildComparisonTable(context, dualRec.nonStackableResult),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              AppButton(
                label: l.close,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComparisonTable(BuildContext context, ContainerRecommendationResult rec) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: rec.isStackable
                  ? (isDark ? AppTheme.emerald.withValues(alpha: 0.15) : AppTheme.emerald.withValues(alpha: 0.1))
                  : (isDark ? AppTheme.orange.withValues(alpha: 0.15) : AppTheme.orange.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: rec.isStackable ? AppTheme.emerald : (isDark ? AppTheme.orange : AppTheme.wcagOrange)),
            ),
            child: Text(
              '${l.approvedRecommendation}: ${isArabic ? rec.recommendationSummary : rec.recommendationSummaryEn}',
              style: TextStyle(fontWeight: FontWeight.bold, color: rec.isStackable ? AppTheme.emerald : (isDark ? AppTheme.orange : AppTheme.wcagOrange)),
            ),
          ),
          const SizedBox(height: 12),
          Table(
            border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
            columnWidths: const {
              0: FlexColumnWidth(2.0),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoal.withValues(alpha: 0.08)),
                children: [
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(l.containerSpecCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null))),
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(l.cbmRequiredContainerCount, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null))),
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(l.cbmSpaceUtilizationPercent, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null))),
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(l.weightUtilizationCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null))),
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(l.recommendationCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null))),
                ],
              ),
              ...rec.comparisonDetails.map((detail) {
                final spec = detail['spec'] as ContainerSpec;
                final int count = detail['reqCount'] as int;
                final double volUtil = detail['spaceUtil'] as double;
                final double weightUtil = detail['payloadUtil'] as double;
                final isBest = spec.code == rec.recommendedContainerCode;

                return TableRow(
                  decoration: isBest ? BoxDecoration(color: AppTheme.emerald.withValues(alpha: 0.12)) : null,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(spec.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isBest ? AppTheme.emerald : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                          Text('${l.cbmVolumeMetric}: ${spec.internalVolumeCbm} CBM | ${l.grossWtPerUnitCol}: ${spec.maxPayloadKg} kg', style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('$count x ${spec.code}', style: TextStyle(fontWeight: FontWeight.bold, color: isBest ? AppTheme.emerald : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('${volUtil.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: volUtil > 90 ? AppTheme.emerald : AppTheme.orange)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('${weightUtil.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: weightUtil > 90 ? AppTheme.emerald : AppTheme.orange)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: isBest
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.emerald, borderRadius: BorderRadius.circular(4)),
                              child: Text(l.bestOptionBadge, style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 10)),
                            )
                          : Text(l.viableAlternative, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted)),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  void _showVisualLoadPlanDialog(BuildContext context, List<CBMItemModel> quickItems) {
    final l = context.l10n;
    // 1. Convert CBMItemModel list to CargoItem list with individual stackability
    final List<CargoItem> cargoItems = [];
    int itemCounter = 1;

    for (final item in quickItems) {
      for (int q = 0; q < item.quantity; q++) {
        // Convert dimension to cm based on the unit
        double lCm = item.length;
        double wCm = item.width;
        double hCm = item.height;
        if (item.unit == 'mm') {
          lCm /= 10;
          wCm /= 10;
          hCm /= 10;
        } else if (item.unit == 'm') {
          lCm *= 100;
          wCm *= 100;
          hCm *= 100;
        }

        // Convert weight to kg based on unit
        final double weightKg = item.grossWeightPerUnitKg;

        cargoItems.add(CargoItem(
          itemId: '$itemCounter',
          length: lCm,
          width: wCm,
          height: hCm,
          weight: weightKg,
          rotate: true,
          isStackable: item.isStackable,
          packageType: item.packageType,
        ));
        itemCounter++;
      }
    }

    if (cargoItems.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.warning),
          content: Text(l.noDataFound),
          actions: [
            AppButton(
              label: l.ok,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
      return;
    }

    // Default active view mode: null = Actual/Mixed, true = All Stackable, false = All Non-Stackable
    bool? activeStackingMode = cargoItems.any((i) => !i.isStackable) ? null : true;
    CargoOrientationPreference activeOrientationMode = CargoOrientationPreference.smartHybrid;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            // Compute plan dynamically based on the selected mode & orientation preference
            final plan = ContainerRequirementEngine.planShipment(
              cargoItems,
              forceStackable: activeStackingMode,
              forceOrientation: activeOrientationMode,
            );

            // Compute summary metrics for active plan
            final totalPkgs = cargoItems.length;
            final stackableInActive = activeStackingMode == true
                ? totalPkgs
                : (activeStackingMode == false ? 0 : cargoItems.where((c) => c.isStackable).length);
            final nonStackableInActive = totalPkgs - stackableInActive;

            final totalPlanWeight = plan.fold(0.0, (s, p) => s + p.totalWeight);
            final totalPlanVolume = plan.fold(0.0, (s, p) => s + p.totalVolume);

            // Determine container fleet text (e.g. 1 x 40HC or 1 x 40HC + 1 x 40GP)
            final Map<String, int> containerCounts = {};
            for (final p in plan) {
              if (p.containerCode != 'FAILED') {
                containerCounts[p.containerCode] = (containerCounts[p.containerCode] ?? 0) + 1;
              }
            }
            final fleetSummaryText = containerCounts.entries.map((e) => '${e.value} x ${e.key}').join(' + ');

            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkCardBackground : null,
              title: Row(
                children: [
                  const Icon(Icons.view_in_ar, color: AppTheme.cobalt, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.cbmVisualPlannerTitle,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.cobalt),
                    ),
                    child: Text(
                      '${l.requiredFleet}: $fleetSummaryText (${plan.length})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: math.min(1050.0, MediaQuery.of(context).size.width * 0.95),
                height: math.min(680.0, MediaQuery.of(context).size.height * 0.85),
                child: Column(
                  children: [
                    // 1. Scenario & Orientation Mode Switcher
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoalSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            l.chooseStackingScenario,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              ChoiceChip(
                                label: Text(l.smartHybridOption),
                                selected: activeOrientationMode == CargoOrientationPreference.smartHybrid && activeStackingMode != false,
                                selectedColor: AppTheme.emerald,
                                labelStyle: TextStyle(
                                  color: activeOrientationMode == CargoOrientationPreference.smartHybrid && activeStackingMode != false ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setDialogState(() {
                                      activeOrientationMode = CargoOrientationPreference.smartHybrid;
                                      activeStackingMode = true;
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: Text(l.flatOnlyOption),
                                selected: activeOrientationMode == CargoOrientationPreference.flatOnly && activeStackingMode != false,
                                selectedColor: AppTheme.wcagCobalt,
                                labelStyle: TextStyle(
                                  color: activeOrientationMode == CargoOrientationPreference.flatOnly && activeStackingMode != false ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setDialogState(() {
                                      activeOrientationMode = CargoOrientationPreference.flatOnly;
                                      activeStackingMode = true;
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: Text(l.allNonStackableOption),
                                selected: activeStackingMode == false,
                                selectedColor: AppTheme.wcagOrange,
                                labelStyle: TextStyle(
                                  color: activeStackingMode == false ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setDialogState(() {
                                      activeStackingMode = false;
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: Text(l.mixedStackingOption),
                                selected: activeStackingMode == null,
                                selectedColor: AppTheme.cobalt,
                                labelStyle: TextStyle(
                                  color: activeStackingMode == null ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) setDialogState(() => activeStackingMode = null);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 2. Metrics Strip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _buildMetricPill(l.packageMeasurementsTitle, '$totalPkgs', AppTheme.cobalt),
                              const SizedBox(width: 8),
                              _buildMetricPill(l.totalGrossWeightRegistryMetric, '${totalPlanWeight.toStringAsFixed(0)} kg', isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              const SizedBox(width: 8),
                              _buildMetricPill(l.totalCbmVolumeMetric, '${totalPlanVolume.toStringAsFixed(3)} m³', AppTheme.wcagOrange),
                            ],
                          ),
                          Row(
                            children: [
                              _buildMetricPill(l.stackableOption, '$stackableInActive', AppTheme.wcagEmerald),
                              const SizedBox(width: 8),
                              _buildMetricPill(l.nonStackableOption, '$nonStackableInActive', AppTheme.crimson),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 2. Table summary of container loads
                    Table(
                      border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(1.8),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(2.4),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal.withValues(alpha: 0.08)),
                          children: [
                            Padding(padding: const EdgeInsets.all(6.0), child: Text(l.containerSpecCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                            Padding(padding: const EdgeInsets.all(6.0), child: Text(l.packageTypeCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                            Padding(padding: const EdgeInsets.all(6.0), child: Text(l.grossWtPerUnitCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                            Padding(padding: const EdgeInsets.all(6.0), child: Text(l.spaceUtilizationCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                            Padding(padding: const EdgeInsets.all(6.0), child: Text(l.cbmFloorAreaUtilization, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                          ],
                        ),
                        ...plan.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final res = entry.value;
                          final placedIds = res.placedItems.map((p) => p.item.itemId).join(', ');
                          final totalPlacedCount = res.placedItems.length;

                          final double volSpaceUtil = res.spec.internalVolumeCbm > 0 ? (res.totalVolume / res.spec.internalVolumeCbm) * 100 : 0.0;
                          final double floorAreaM2 = res.placedItems.fold(0.0, (s, p) => s + p.item.floorAreaM2);
                          final double specFloorAreaM2 = (res.spec.internalLength * res.spec.internalWidth) / 10000;
                          final double floorUtil = specFloorAreaM2 > 0 ? (floorAreaM2 / specFloorAreaM2) * 100 : 0.0;

                          final bool hasNonStackable = res.placedItems.any((p) => !p.item.isStackable);
                          final double displaySpaceUtil = hasNonStackable ? math.max(volSpaceUtil, floorUtil) : volSpaceUtil;

                          String statusText = '';
                          if (res.containerCode == 'FAILED' || !res.fits) {
                            statusText = res.failureReason ?? l.operationFailed;
                          } else {
                            final nonStackInThis = res.placedItems.where((p) => !p.item.isStackable).length;
                            if (nonStackInThis > 0) {
                              statusText = '${l.nonStackableOption}: $nonStackInThis (${floorUtil.toStringAsFixed(1)}%)';
                            } else {
                              statusText = '${l.stackableOption} ($totalPlacedCount)';
                            }
                          }

                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Text(
                                  res.containerCode == 'FAILED' ? l.operationFailed : '$idx: ${res.spec.code}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 11),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Text(
                                  placedIds.isEmpty ? '-' : '$placedIds ($totalPlacedCount)',
                                  style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Text(res.containerCode == 'FAILED' ? '-' : '${res.totalWeight.toStringAsFixed(0)} kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Text(
                                  '${displaySpaceUtil.toStringAsFixed(1)}%',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orange),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: (res.containerCode == 'FAILED' || !res.fits)
                                        ? AppTheme.crimson
                                        : (hasNonStackable ? AppTheme.wcagOrange : AppTheme.wcagEmerald),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 3. Tab view or list for visual container layout drawings
                    Expanded(
                      child: ListView.builder(
                        itemCount: plan.length,
                        itemBuilder: (ctx, pIdx) {
                          final res = plan[pIdx];
                          if (res.containerCode == 'FAILED') {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppTheme.crimsonLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.crimsonBorder)),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppTheme.crimson, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          res.failureReason ?? l.operationFailed,
                                          style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        if (res.unplacedItems.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '${l.packageMeasurementsTitle}: ${res.unplacedItems.map((u) => u.itemId).join(', ')}',
                                            style: const TextStyle(color: AppTheme.crimson, fontSize: 11),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '#${pIdx + 1}: ${res.spec.name} (${res.spec.code})',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                      ),
                                      Row(
                                        children: [
                                          Text(l.cbmWoodenPalletsFloor, style: const TextStyle(fontSize: 10, color: AppTheme.wcagOrange, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: AppTheme.cobaltLight, borderRadius: BorderRadius.circular(4)),
                                            child: Text('${l.cbmInternalDimensionsLabel} ${res.spec.internalLength.toStringAsFixed(0)} x ${res.spec.internalWidth.toStringAsFixed(0)} x ${res.spec.internalHeight.toStringAsFixed(0)} cm', style: const TextStyle(fontSize: 10, color: AppTheme.cobalt)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Side View (Left Wall Removed) - Matches the Reference Image!
                                  Container(
                                    height: 190,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: AppTheme.charcoal,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: CustomPaint(
                                      painter: ContainerLoadPlanPainter(plan: res, isTopView: false),
                                      child: Container(),
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // Top View (Roof Removed)
                                  Container(
                                    height: 140,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: AppTheme.charcoal,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: CustomPaint(
                                      painter: ContainerLoadPlanPainter(plan: res, isTopView: true),
                                      child: Container(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                AppButton(
                  label: l.closePlan,
                  icon: Icons.close,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _buildMetricPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _exportCbmListToExcel(BuildContext context, List<CBMCalculationModel> calcs) async {
    if (calcs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cbmNoCalculationsToExport), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    final headers = [
      context.l10n.cbmCalcCode,
      context.l10n.colImportFile,
      context.l10n.customsTaxLogTsvHeaderTitle,
      context.l10n.poTotalCBM2,
      context.l10n.cbmVolumetricWtKg,
      context.l10n.grossWeightCol,
      context.l10n.cbmStackable,
      context.l10n.cbmShippingStrategy,
      context.l10n.recommendedContainerCol,
    ];

    final rows = calcs.map((c) {
      return [
        c.calcCode,
        c.importFileCode ?? '-',
        c.title ?? '-',
        c.totalCbm.toStringAsFixed(3),
        c.totalVolumetricWeightKg.toStringAsFixed(1),
        c.totalGrossWeightKg.toStringAsFixed(1),
        c.isStackable ? (context.l10n.projectMultiShipmentYes) : (context.l10n.projectMultiShipmentNo),
        c.shippingMethodLabel(context.l10n),
        c.recommendedContainersLabel(context.l10n),
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.cbmCBMRegistry,
      importFileNameOrCode: 'CBM_Calculations_Registry',
    );
  }

  Future<void> _exportCbmListToPdf(BuildContext context, List<CBMCalculationModel> calcs) async {
    if (calcs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cbmNoCalculationsToExport), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    final headers = [
      context.l10n.cbmCode,
      context.l10n.cbmFile,
      context.l10n.titleField,
      context.l10n.cbmRowLineCbm,
      context.l10n.cbmVolWt2,
      context.l10n.cbmGrossWt,
      context.l10n.cbmMode,
      context.l10n.containerCol,
    ];

    final rows = calcs.map((c) {
      return [
        c.calcCode,
        c.importFileCode ?? '-',
        c.title ?? '-',
        c.totalCbm.toStringAsFixed(3),
        c.totalVolumetricWeightKg.toStringAsFixed(1),
        c.totalGrossWeightKg.toStringAsFixed(1),
        c.shippingMethodLabel(context.l10n),
        c.recommendedContainersLabel(context.l10n),
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.cbmCBMRegistry,
      importFileNameOrCode: 'CBM_Calculations_Registry',
      headerContext: TableExportHeaderContext(
        title: context.l10n.cbmCBMVolumetricWeightRegistry,
        subtitle: 'Sorour Logistics ERP',
        metadata: {
          context.l10n.totalStudiesMetric: '${calcs.length}',
          context.l10n.date: DateTime.now().toString().substring(0, 10),
        },
      ),
    );
  }

  void _copyCbmTableAsTsv(BuildContext context, List<CBMCalculationModel> calcs) {
    if (calcs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cbmNoCalculationsToCopy), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    final headers = [
      context.l10n.cbmCalcCode,
      context.l10n.colImportFile,
      context.l10n.customsTaxLogTsvHeaderTitle,
      context.l10n.poTotalCBM2,
      context.l10n.cbmVolumetricWtKg,
      context.l10n.grossWeightCol,
      context.l10n.cbmStackable,
      context.l10n.cbmShippingStrategy,
      context.l10n.recommendedContainerCol,
    ];

    final rows = calcs.map((c) {
      return [
        c.calcCode,
        c.importFileCode ?? '-',
        c.title ?? '-',
        c.totalCbm.toStringAsFixed(3),
        c.totalVolumetricWeightKg.toStringAsFixed(1),
        c.totalGrossWeightKg.toStringAsFixed(1),
        c.isStackable ? (context.l10n.projectMultiShipmentYes) : (context.l10n.projectMultiShipmentNo),
        c.shippingMethodLabel(context.l10n),
        c.recommendedContainersLabel(context.l10n),
      ];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: context.l10n.cbmCBMCalculationsTableCopiedToClipboard,
    );
  }
}

// ==================================================
// Dedicated Search & Clone Dialog for CBM Calculations (UX-CLONE-011)
// ==================================================
class _SearchAndCloneCBMDialog extends StatefulWidget {
  final List<CBMCalculationModel> calculations;
  final ValueChanged<CBMCalculationModel> onSelectCalculation;

  const _SearchAndCloneCBMDialog({
    required this.calculations,
    required this.onSelectCalculation,
  });

  @override
  State<_SearchAndCloneCBMDialog> createState() => _SearchAndCloneCBMDialogState();
}

class _SearchAndCloneCBMDialogState extends State<_SearchAndCloneCBMDialog> {
  final TextEditingController _queryController = TextEditingController();
  late List<CBMCalculationModel> _filteredCalcs;

  @override
  void initState() {
    super.initState();
    _filteredCalcs = widget.calculations;
    _queryController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _queryController.removeListener(_onSearchChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _queryController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCalcs = widget.calculations;
      } else {
        _filteredCalcs = widget.calculations.where((calc) {
          final code = calc.calcCode.toLowerCase();
          final title = (calc.title ?? '').toLowerCase();
          final notes = (calc.notes ?? '').toLowerCase();
          final mode = '${calc.recommendedShippingMethod ?? ''} ${calc.shippingMethodLabel(context.l10n)}'.toLowerCase();
          return code.contains(query) ||
              title.contains(query) ||
              notes.contains(query) ||
              mode.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      child: Container(
        width: math.min(720.0, screenWidth - 32),
        height: math.min(600.0, screenHeight - 64),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.control_point_duplicate_rounded, color: AppTheme.cobalt, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.searchAndCloneCbmDialogTitle,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.searchAndCloneCbmSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            AppSearchField(
              controller: _queryController,
              hint: l.searchByCalcCodeOrTitleHint,
            ),
            const SizedBox(height: 16),

            // Results List
            Expanded(
              child: _filteredCalcs.isEmpty
                  ? AppEmptyState(
                      icon: Icons.search_off_rounded,
                      message: l.noMatchingCalcsFound,
                    )
                  : ListView.separated(
                      itemCount: _filteredCalcs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final calc = _filteredCalcs[idx];
                        final isAir = calc.isAirRecommended;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoalSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          calc.calcCode,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                                        ),
                                        const SizedBox(width: 8),
                                        AppStatusBadge(
                                          label: calc.shippingMethodLabel(l),
                                          severity: isAir ? AppSeverity.info : AppSeverity.success,
                                          size: AppStatusBadgeSize.small,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      calc.title ?? calc.calcCode,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 10,
                                      children: [
                                        Text(
                                          '${calc.totalCbm.toStringAsFixed(2)} m³',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.wcagOrange),
                                        ),
                                        Text(
                                          '${calc.totalGrossWeightKg.toStringAsFixed(0)} kg',
                                          style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                                        ),
                                        Text(
                                          '${calc.items.length} ${calc.items.length == 1 ? "item" : "items"}',
                                          style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              AppButton(
                                label: l.cloneRowTooltip,
                                icon: Icons.copy_rounded,
                                variant: AppButtonVariant.primary,
                                size: AppButtonSize.small,
                                onPressed: () => widget.onSelectCalculation(calc),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
