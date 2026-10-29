import 'package:flutter/material.dart';
import 'budget_details_dialog.dart';
import 'budget_email_share_dialog.dart';
import 'budget_whatsapp_share_dialog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/financial_approval_model.dart';
import '../providers/financial_approval_provider.dart';
import '../services/financial_export_service.dart';
import 'financial_ui.dart';

class SavedBudgetsRegistryTab extends ConsumerStatefulWidget {
  final void Function(ImportBudgetModel budget) onEditBudget;
  final VoidCallback onSwitchToForm;
  final void Function(ImportBudgetModel budget)? onCloneBudget;
  final VoidCallback? onSearchAndClone;

  const SavedBudgetsRegistryTab({
    super.key,
    required this.onEditBudget,
    required this.onSwitchToForm,
    this.onCloneBudget,
    this.onSearchAndClone,
  });

  @override
  ConsumerState<SavedBudgetsRegistryTab> createState() =>
      _SavedBudgetsRegistryTabState();
}

class _SavedBudgetsRegistryTabState
    extends ConsumerState<SavedBudgetsRegistryTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'ALL'; // ALL, Approved, Pending Review, Draft

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgetsState = ref.watch(importBudgetsProvider);
    final budgetsList = budgetsState.valueOrNull ?? [];

    return SelectionArea(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
            if (widget.onSearchAndClone != null) {
              widget.onSearchAndClone!();
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: _buildHistoryRegistryTab(budgetsList),
        ),
      ),
    );
  }

  Widget _buildHistoryRegistryTab(List<ImportBudgetModel> budgetsList) {
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

    final filtered = budgetsList.where((b) {
      if (!b.isActive) return false;
      final q = _searchController.text.trim().toLowerCase();
      final matchQuery = q.isEmpty ||
          b.budgetCode.toLowerCase().contains(q) ||
          b.title.toLowerCase().contains(q) ||
          (b.importFileCode != null &&
              b.importFileCode!.toLowerCase().contains(q)) ||
          (b.approvedBy != null && b.approvedBy!.toLowerCase().contains(q));

      if (!matchQuery) return false;

      if (_selectedStatusFilter == 'Approved') {
        return b.budgetStatus.toLowerCase().contains('approved');
      } else if (_selectedStatusFilter == 'Pending') {
        return b.budgetStatus.toLowerCase().contains('pending') ||
            b.budgetStatus.toLowerCase().contains('draft');
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Summary metrics (shared compact strip) + page actions ----------
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
                    onPressed: widget.onSwitchToForm,
                  )),
                ],
              ),
            ],
          ),
        ),

        // ─── Filter & Search Toolbar (Responsive LayoutBuilder) ───────────────
        Container(
          color: isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: LayoutBuilder(
            builder: (layoutCtx, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final searchField = SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
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
                      valueListenable: _searchController,
                      builder: (context, value, _) {
                        return value.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
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
                      '${l.allStatuses} (${budgetsList.where((b) => b.isActive).length})',
                      'ALL',
                      isDark),
                  _buildFilterChip(
                      '${l.approvedBudgetsMetric} ($approvedBudgets)',
                      'Approved',
                      isDark),
                  _buildFilterChip(
                      '${l.pendingBudgetsMetric} ($pendingBudgets)',
                      'Pending',
                      isDark),
                  if (widget.onSearchAndClone != null)
                    FinancialUi.fit(AppButton(
                      key: const Key('searchAndCloneBudgetRegistryBtn'),
                      label: l.searchAndCloneBudgetBtn,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      icon: Icons.copy_all,
                      onPressed: widget.onSearchAndClone,
                    )),
                  FinancialUi.fit(AppButton(
                    label: l.exportExcel,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    icon: Icons.table_chart_outlined,
                    onPressed: () async {
                      final path =
                          await FinancialExportService.exportBudgetsListToExcel(
                              context: context, list: filtered);
                      if (path != null && mounted) {
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

        Divider(
            height: 1,
            thickness: 1,
            color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),

        // ─── List of Saved Budget Cards ──────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final budget = filtered[index];
                    return _buildBudgetCard(budget, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBudgetCard(ImportBudgetModel budget, bool isDark) {
    final isApproved = budget.budgetStatus.toLowerCase().contains('approved');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isApproved
              ? (isDark ? AppTheme.wcagEmerald : AppTheme.emeraldBorder)
              : (isDark ? AppTheme.wcagOrange : AppTheme.orange),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Bar (Responsive LayoutBuilder)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isApproved
                  ? (isDark
                      ? AppTheme.wcagEmerald.withValues(alpha: 0.35)
                      : AppTheme.emeraldLight.withValues(alpha: 0.5))
                  : (isDark
                      ? AppTheme.wcagOrange.withValues(alpha: 0.35)
                      : AppTheme.orangeLight.withValues(alpha: 0.5)),
              borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(9), topEnd: Radius.circular(9)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 850;
                final codeSection = InkWell(
                  onTap: () => CopyHelper.copy(context, budget.budgetCode,
                      customMessage:
                          context.l10n.budgetCodeCopied(budget.budgetCode)),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.charcoal,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long,
                            color: AppTheme.white, size: 14),
                        const SizedBox(width: 6),
                        CopyableText(budget.budgetCode,
                            style: const TextStyle(
                                color: AppTheme.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                            showIcon: false),
                        const SizedBox(width: 4),
                        Icon(Icons.copy,
                            color: AppTheme.white.withValues(alpha: 0.7), size: 11),
                      ],
                    ),
                  ),
                );

                final fileSection = (budget.importFileCode != null ||
                        budget.importFileId != null)
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppTheme.cobalt.withValues(alpha: 0.3)),
                        ),
                        child: CopyableText(
                          budget.importFileCode ?? 'IMP-${budget.importFileId}',
                          style: const TextStyle(
                              color: AppTheme.cobalt,
                              fontWeight: FontWeight.bold,
                              fontSize: 11),
                          showIcon: false,
                        ),
                      )
                    : null;

                final actionsSection = RowActionsPill(
                  onView: () => _showBudgetDetailsDialog(budget),
                  onEdit: () => widget.onEditBudget(budget),
                  onClone: widget.onCloneBudget != null
                      ? () => widget.onCloneBudget!(budget)
                      : null,
                  onPrint: () => FinancialExportService.printOrSaveBudgetPdf(
                      budget: budget),
                  onDelete: () => _confirmDeleteBudget(budget),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.start,
                          children: [
                            actionsSection,
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                codeSection,
                                if (fileSection != null) fileSection,
                                FinancialStatusChip(
                                    status: budget.budgetStatus),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      CopyableText(
                        budget.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.charcoal,
                        ),
                        showIcon: false,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    actionsSection,
                    const SizedBox(width: 10),
                    codeSection,
                    if (fileSection != null) ...[
                      const SizedBox(width: 10),
                      fileSection,
                    ],
                    const SizedBox(width: 10),
                    Expanded(
                      child: CopyableText(
                        budget.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.charcoal,
                        ),
                        overflow: TextOverflow.ellipsis,
                        showIcon: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    FinancialStatusChip(status: budget.budgetStatus),
                  ],
                );
              },
            ),
          ),

          // 2. Metrics 4-Box Grid (Adaptive 4-column or 2x2 grid)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 850;
                    final box1 = _buildCostBox(
                      title: context.l10n.estimatedInvoiceValue,
                      foreignVal:
                          '${budget.invoiceAmountForeign.toStringAsFixed(2)} ${budget.invoiceCurrency}',
                      egpVal:
                          '${budget.invoiceAmountEgp.toStringAsFixed(2)} EGP',
                      icon: Icons.inventory_2_outlined,
                      color: AppTheme.cobalt,
                      isDark: isDark,
                    );
                    final box2 = _buildCostBox(
                      title: context.l10n.estimatedFreightCost,
                      foreignVal:
                          '${budget.freightCostForeign.toStringAsFixed(2)} ${budget.freightCurrency}',
                      egpVal: '${budget.freightCostEgp.toStringAsFixed(2)} EGP',
                      icon: Icons.directions_boat_outlined,
                      color: AppTheme.wcagCobalt,
                      isDark: isDark,
                    );
                    final box3 = _buildCostBox(
                      title: context.l10n.customsAndVatEstimate,
                      foreignVal: 'Customs',
                      egpVal:
                          '${budget.customsDutiesEgp.toStringAsFixed(2)} EGP',
                      icon: Icons.account_balance_outlined,
                      color: AppTheme.wcagCobalt,
                      isDark: isDark,
                    );
                    final box4 = _buildCostBox(
                      title: context.l10n.clearanceAndTransportEstimate,
                      foreignVal: context.l10n.customsBrokerLabel,
                      egpVal:
                          '${budget.clearanceInlandEgp.toStringAsFixed(2)} EGP',
                      icon: Icons.local_shipping_outlined,
                      color: AppTheme.wcagEmerald,
                      isDark: isDark,
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          Row(children: [box1, const SizedBox(width: 8), box2]),
                          const SizedBox(height: 8),
                          Row(children: [box3, const SizedBox(width: 8), box4]),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        box1,
                        const SizedBox(width: 10),
                        box2,
                        const SizedBox(width: 10),
                        box3,
                        const SizedBox(width: 10),
                        box4,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Grand Total Highlight Bar (Adaptive LayoutBuilder)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.emerald.withValues(alpha: 0.15)
                        : AppTheme.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.emerald.withValues(alpha: 0.6)
                          : AppTheme.emerald.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final totalPart = Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(Icons.monetization_on,
                              color: AppTheme.emerald, size: 20),
                          Text(
                            '${context.l10n.totalBudgetEgp}:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.charcoal,
                            ),
                          ),
                          CopyableText(
                            '${budget.totalBudgetEgp.toStringAsFixed(2)} EGP',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.emerald),
                            showIcon: false,
                          ),
                        ],
                      );

                      final metaPart = Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${context.l10n.exchangeRateCol}: ',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.textStrong),
                              ),
                              CopyableText(
                                '${budget.exchangeRate.toStringAsFixed(2)} EGP',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.charcoal,
                                ),
                                showIcon: false,
                              ),
                            ],
                          ),
                          if (budget.approvedBy != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${context.l10n.approvedByLabel} ',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.textStrong),
                                ),
                                CopyableText(
                                  budget.approvedBy!,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.cobalt),
                                  showIcon: false,
                                ),
                              ],
                            ),
                        ],
                      );

                      return SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            totalPart,
                            metaPart,
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 3. Quick Action Buttons Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkInputBackground
                  : AppTheme.charcoalSurface,
              border: Border(
                  top: BorderSide(
                      color:
                          isDark ? AppTheme.darkBorder : AppTheme.cloudWhite)),
              borderRadius: const BorderRadiusDirectional.only(
                  bottomStart: Radius.circular(9),
                  bottomEnd: Radius.circular(9)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 1. Details Modal
                FinancialUi.fit(AppButton(
                  label: context.l10n.viewDetails,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  icon: Icons.visibility_outlined,
                  onPressed: () => _showBudgetDetailsDialog(budget),
                )),
                // 2. Clone Action
                if (widget.onCloneBudget != null)
                  FinancialUi.fit(AppButton(
                    label: context.l10n.cloneBudgetTooltip,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    icon: Icons.copy_rounded,
                    onPressed: () => widget.onCloneBudget!(budget),
                  )),
                // 3. Edit & Load to Form
                FinancialUi.fit(AppButton(
                  label: context.l10n.editInForm,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  icon: Icons.edit_outlined,
                  onPressed: () => widget.onEditBudget(budget),
                )),
                // 4. Print PDF
                FinancialUi.fit(AppButton(
                  label: context.l10n.printSavePdfBtn,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  icon: Icons.print_outlined,
                  onPressed: () => FinancialExportService.printOrSaveBudgetPdf(
                      budget: budget),
                )),
                // 5. Export Excel
                FinancialUi.fit(AppButton(
                  label: context.l10n.downloadExcelBtn,
                  variant: AppButtonVariant.success,
                  size: AppButtonSize.small,
                  icon: Icons.table_chart,
                  onPressed: () async {
                    final path =
                        await FinancialExportService.exportBudgetToExcel(
                            context: context, budget: budget);
                    if (path != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        AppTheme.snackBar(
                          context,
                          context.l10n.excelSavedSuccess(path),
                          severity: AppSeverity.success,
                        ),
                      );
                    }
                  },
                )),
                // 6. WhatsApp
                FinancialUi.fit(AppButton(
                  label: context.l10n.whatsappShareBtn,
                  variant: AppButtonVariant.success,
                  size: AppButtonSize.small,
                  icon: Icons.chat,
                  onPressed: () => _showWhatsAppShareDialog(budget),
                )),
                // 7. Email
                FinancialUi.fit(AppButton(
                  label: context.l10n.emailShareBtn,
                  variant: AppButtonVariant.warning,
                  size: AppButtonSize.small,
                  icon: Icons.email_outlined,
                  onPressed: () => _showEmailShareDialog(budget),
                )),
                // 8. Copy Summary
                FinancialUi.fit(AppButton(
                  label: context.l10n.copySummaryBtn,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  icon: Icons.copy,
                  onPressed: () {
                    final text =
                        FinancialExportService.generateBudgetWhatsAppText(
                            budget);
                    CopyHelper.copy(context, text,
                        customMessage: context.l10n.budgetSummaryCopied);
                  },
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostBox({
    required String title,
    required String foreignVal,
    required String egpVal,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.3)),
          boxShadow: [
            BoxShadow(
                color: AppTheme.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textStrong,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            CopyableText(
              foreignVal,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color),
              showIcon: false,
            ),
            const SizedBox(height: 2),
            CopyableText(
              egpVal,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
              showIcon: false,
            ),
          ],
        ),
      ),
    );
  }

  void _showBudgetDetailsDialog(ImportBudgetModel budget) {
    BudgetDetailsDialog.show(
      context,
      budget: budget,
      onEditBudget: () => widget.onEditBudget(budget),
    );
  }

  void _showBudgetWhatsAppShareDialog(ImportBudgetModel budget) {
    BudgetWhatsAppShareDialog.show(context, budget: budget);
  }

  void _showWhatsAppShareDialog(ImportBudgetModel budget) =>
      _showBudgetWhatsAppShareDialog(budget);

  void _showBudgetEmailShareDialog(ImportBudgetModel budget) {
    BudgetEmailShareDialog.show(context, budget: budget);
  }

  void _showEmailShareDialog(ImportBudgetModel budget) =>
      _showBudgetEmailShareDialog(budget);

  Future<void> _confirmDeleteBudget(ImportBudgetModel budget) async {
    final l = context.l10n;

    final confirm = await AppConfirmDialog.showDelete(
      context,
      title: l.confirmDeleteBudgetTitle,
      message: l.confirmDeleteBudgetMessage(budget.budgetCode, budget.title),
      entityName: '${budget.budgetCode} - ${budget.title}',
    );

    if (confirm == true) {
      try {
        await ref
            .read(importBudgetsProvider.notifier)
            .softDeleteImportBudget(budget.budgetId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l.budgetDeletedSuccess(budget.budgetCode),
              severity: AppSeverity.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l.deleteErrorMsg(ApiError.message(e)),
              severity: AppSeverity.danger,
            ),
          );
        }
      }
    }
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _selectedStatusFilter == value;
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
        if (selected) setState(() => _selectedStatusFilter = value);
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final l = context.l10n;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 56,
            color: isDark ? AppTheme.darkBorder : AppTheme.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            l.noMatchingBudgets,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textStrong,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.noBudgetsPlaceholderMessage,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: l.approveNewBudgetNow,
            variant: AppButtonVariant.success,
            icon: Icons.add,
            onPressed: widget.onSwitchToForm,
          ),
        ],
      ),
    );
  }
}
