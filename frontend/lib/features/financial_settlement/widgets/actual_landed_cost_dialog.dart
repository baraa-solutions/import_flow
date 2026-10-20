import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/actual_landed_cost_model.dart';
import '../providers/financial_settlement_provider.dart';
import 'settlement_ui.dart';

class ActualLandedCostDialog extends ConsumerStatefulWidget {
  final int importFileId;
  final String importFileCode;

  const ActualLandedCostDialog({
    super.key,
    required this.importFileId,
    required this.importFileCode,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int importFileId,
    required String importFileCode,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ActualLandedCostDialog(
        importFileId: importFileId,
        importFileCode: importFileCode,
      ),
    );
  }

  @override
  ConsumerState<ActualLandedCostDialog> createState() => _ActualLandedCostDialogState();
}

class _ActualLandedCostDialogState extends ConsumerState<ActualLandedCostDialog>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  ActualLandedCostCalculationResponseModel? _calcData;

  String _selectedAllocationPreference = 'Value-Based';
  late TabController _tabController;

  final _approvedByController = TextEditingController();
  String _defaultApprovedBy = '';
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default to the signed-in user (no hard-coded sample name).
    _defaultApprovedBy = ref.read(authProvider).user?.fullName ?? '';
    _approvedByController.text = _defaultApprovedBy;
    _tabController = TabController(length: 2, vsync: this);
    _loadCalculation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _approvedByController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCalculation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ref
          .read(financialSettlementProvider.notifier)
          .calculateActualLandedCost(
            widget.importFileId,
            allocationPreference: _selectedAllocationPreference,
          );
      if (mounted) {
        setState(() {
          _calcData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ApiErrorText.of(context.l10n, e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleApprove() async {
    if (_approvedByController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.settlementClo02ApproveRequired),
          backgroundColor: AppTheme.flatCrimson,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final res = await ref
          .read(financialSettlementProvider.notifier)
          .approveActualLandedCost(
            importFileId: widget.importFileId,
            approvedBy: _approvedByController.text.trim(),
            allocationPreference: _selectedAllocationPreference,
            notes: _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppTheme.flatEmerald,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiErrorText.of(context.l10n, e)),
            backgroundColor: AppTheme.flatCrimson,
          ),
        );
      }
    }
  }

  bool get _isDirty {
    if (_notesController.text.trim().isNotEmpty) return true;
    if (_selectedAllocationPreference != 'Value-Based') return true;
    if (_approvedByController.text.trim() != _defaultApprovedBy) return true;
    return false;
  }

  Color _varianceColor(String status) {
    if (status == 'UNFAVORABLE') return AppTheme.flatCrimson;
    if (status == 'MATCHED') return AppTheme.flatCobalt;
    return AppTheme.flatEmerald;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return UnsavedChangesGuard(
      isDirty: _isDirty,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1200,
            maxHeight: 880,
          ),
          child: Column(
            children: [
              SettlementDialogHeader(
                icon: Icons.calculate_outlined,
                title: l10n.settlementClo02Title,
                subtitle: l10n.settlementClo02Subtitle(widget.importFileCode),
                closeKey: const Key('actualLandedCostCloseBtn'),
                closeTooltip: l10n.settlementClose,
                onClose: () => UnsavedChangesGuard.maybePop(context, isDirty: _isDirty),
              ),
              Expanded(
                child: _isLoading
                    ? SettlementStateView.loading(message: l10n.settlementClo02Loading)
                    : _errorMessage != null
                        ? _buildErrorView(l10n)
                        : _buildContent(l10n),
              ),
              if (!_isLoading && _errorMessage == null) _buildFooter(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(AppLocalizations l10n) {
    return SettlementStateView.error(
      message: '${l10n.settlementClo02ErrorTitle}\n${_errorMessage ?? ''}',
      actionLabel: l10n.settlementRetry,
      onAction: _loadCalculation,
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    final calc = _calcData!;
    return Column(
      children: [
        _buildKpiStrip(calc, l10n),
        _buildMessages(calc, l10n),
        _buildAllocationControlBar(l10n),
        _buildTabBar(l10n),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCategoriesVarianceTab(calc, l10n),
              _buildItemsLandedCostTab(calc, l10n),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiStrip(
      ActualLandedCostCalculationResponseModel calc, AppLocalizations l10n) {
    final egp = l10n.financialSettlementCurrencyEgp;
    final varianceColor = _varianceColor(calc.varianceStatus);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 8),
      child: SettlementMetricStrips(
        metrics: [
          MetricCardData(
            title: l10n.settlementClo02KpiFob,
            value: '${formatSettlementMoney(calc.totalFobEgp)} $egp',
            icon: Icons.inventory_2_outlined,
            color: AppTheme.flatCobalt,
            tooltip: l10n.settlementClo02KpiFobSub(calc.currency, calc.fxRate.toStringAsFixed(2)),
          ),
          MetricCardData(
            title: l10n.settlementClo02KpiExpenses,
            value: '${formatSettlementMoney(calc.totalActualExpensesEgp)} $egp',
            icon: Icons.receipt_long_outlined,
            color: AppTheme.flatOrange,
            tooltip: l10n.settlementClo02KpiExpensesSub,
          ),
          MetricCardData(
            title: l10n.settlementClo02KpiLanded,
            value: '${formatSettlementMoney(calc.actualTotalLandedCostEgp)} $egp',
            icon: Icons.account_balance_wallet_outlined,
            color: AppTheme.flatCharcoal,
            tooltip: l10n.settlementClo02KpiLandedSub(
                '${formatSettlementMoney(calc.estimatedTotalLandedCostEgp)} $egp'),
          ),
          MetricCardData(
            title: l10n.settlementClo02KpiMarkup,
            value: '${calc.actualMarkupFactor.toStringAsFixed(3)}x',
            icon: Icons.trending_up,
            color: AppTheme.flatCobalt,
            tooltip: l10n.settlementClo02KpiMarkupSub,
          ),
          MetricCardData(
            title: l10n.settlementClo02KpiVariance,
            value: formatSettlementPercent(calc.landedVariancePct),
            icon: calc.varianceStatus == 'FAVORABLE'
                ? Icons.arrow_downward
                : calc.varianceStatus == 'UNFAVORABLE'
                    ? Icons.arrow_upward
                    : Icons.check,
            color: varianceColor,
            tooltip: l10n.settlementClo02KpiVarianceSub(
                '${formatSettlementMoney(calc.landedVarianceEgp)} $egp',
                calc.varianceStatusAr),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(
      ActualLandedCostCalculationResponseModel calc, AppLocalizations l10n) {
    final lines = [
      ...calc.messages.map((m) => settlementMessageText(l10n, m)),
      if (calc.reconciliationDifferenceEgp != 0)
        l10n.settlementReconciliationNote(
            '${formatSettlementMoney(calc.reconciliationDifferenceEgp)} ${l10n.financialSettlementCurrencyEgp}'),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(SettlementTokens.radius),
          border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.orange),
                  const SizedBox(width: 6),
                  Expanded(child: Text(line, style: const TextStyle(fontSize: 12))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationControlBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune, size: 18, color: AppTheme.flatCharcoal),
              const SizedBox(width: 8),
              Text(
                l10n.settlementClo02AllocationLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.flatCharcoal,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 260,
                child: SearchableDropdownField<String>(
                  key: const Key('actualLandedCostAllocationDropdown'),
                  value: _selectedAllocationPreference,
                  labelText: l10n.financialSettlementAllocationRuleLabel,
                  searchHintText: l10n.financialSettlementAllocationRuleSearchHint,
                  items: [
                    SearchableDropdownItem(value: 'Value-Based', label: l10n.financialSettlementRuleValueBased),
                    SearchableDropdownItem(value: 'Weight-Based', label: l10n.financialSettlementRuleWeightBased),
                    SearchableDropdownItem(value: 'Volume-Based', label: l10n.financialSettlementRuleVolumeBased),
                    SearchableDropdownItem(value: 'Equal', label: l10n.financialSettlementRuleEqual),
                  ],
                  onChanged: (val) {
                    if (val != null && val != _selectedAllocationPreference) {
                      setState(() {
                        _selectedAllocationPreference = val;
                      });
                      _loadCalculation();
                    }
                  },
                ),
              ),
            ],
          ),
          Text(
            l10n.settlementClo02Counts(
              _calcData?.itemsBreakdown.length ?? 0,
              _calcData?.categoriesBreakdown.length ?? 0,
            ),
            style: const TextStyle(fontSize: 12, color: AppTheme.textStrong),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(AppLocalizations l10n) {
    return Container(
      color: SettlementTokens.panelFill,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.flatCobalt,
        unselectedLabelColor: AppTheme.flatCharcoal.withValues(alpha: 0.7),
        indicatorColor: AppTheme.flatCobalt,
        indicatorWeight: 3,
        tabs: [
          Tab(
            key: const Key('actualLandedCostExpensesTab'),
            icon: const Icon(Icons.pie_chart_outline, size: 18),
            text: l10n.settlementClo02TabExpenses(_calcData?.categoriesBreakdown.length ?? 0),
          ),
          Tab(
            key: const Key('actualLandedCostItemsTab'),
            icon: const Icon(Icons.view_list_outlined, size: 18),
            text: l10n.settlementClo02TabItems(_calcData?.itemsBreakdown.length ?? 0),
          ),
        ],
      ),
    );
  }

  Widget _buildTableFrame(Widget table) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SettlementTokens.radius),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: SettlementTokens.border),
              borderRadius: BorderRadius.circular(SettlementTokens.radius),
            ),
            child: table,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesVarianceTab(
      ActualLandedCostCalculationResponseModel calc, AppLocalizations l10n) {
    if (calc.categoriesBreakdown.isEmpty) {
      return SettlementStateView.empty(
        message: l10n.settlementClo02NoExpenses,
        icon: Icons.receipt_long_outlined,
      );
    }
    final egp = l10n.financialSettlementCurrencyEgp;

    return _buildTableFrame(
      DataTable(
        headingRowColor: WidgetStateProperty.all(SettlementTokens.tableHeadFill),
        columnSpacing: 18,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 64,
        columns: [
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColExpense)),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColEstimated), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColActual), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColVariance), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColPct), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColStatus)),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColInvoices), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColSource)),
        ],
        rows: calc.categoriesBreakdown.map((cat) {
          Color statusColor = AppTheme.flatEmerald;
          String statusText = l10n.settlementClo02StatusSaving;
          if (cat.varianceStatus == 'UNFAVORABLE') {
            statusColor = AppTheme.flatCrimson;
            statusText = l10n.settlementClo02StatusOver;
          } else if (cat.varianceStatus == 'MATCHED') {
            statusColor = AppTheme.flatCobalt;
            statusText = l10n.settlementClo02StatusMatched;
          }

          return DataRow(
            cells: [
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(cat.categoryAr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(cat.category, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              DataCell(SettlementMoneyText('${formatSettlementMoney(cat.estimatedAmountEgp)} $egp', style: const TextStyle(fontSize: 12))),
              DataCell(SettlementMoneyText('${formatSettlementMoney(cat.actualAmountEgp)} $egp', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              DataCell(
                SettlementMoneyText(
                  '${cat.varianceEgp >= 0 ? '+' : ''}${formatSettlementMoney(cat.varianceEgp)} $egp',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ),
              DataCell(
                SettlementMoneyText(
                  formatSettlementPercent(cat.variancePct),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
              DataCell(SettlementStatusChip(label: statusText, color: statusColor, dense: true)),
              DataCell(SettlementMoneyText('${cat.invoicesCount}', style: const TextStyle(fontSize: 12))),
              DataCell(
                SizedBox(
                  width: 220,
                  child: Text(
                    cat.sourceNote,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textStrong),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemsLandedCostTab(
      ActualLandedCostCalculationResponseModel calc, AppLocalizations l10n) {
    if (calc.itemsBreakdown.isEmpty) {
      return SettlementStateView.empty(
        message: l10n.settlementClo02NoItems,
        icon: Icons.inventory_2_outlined,
      );
    }
    final egp = l10n.financialSettlementCurrencyEgp;

    return _buildTableFrame(
      DataTable(
        headingRowColor: WidgetStateProperty.all(SettlementTokens.tableHeadFill),
        columnSpacing: 16,
        columns: [
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColItemCode)),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColItemName)),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColHs)),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColQty), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColFobPrice), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColFobTotal), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColAllocated), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColItemTotal), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColUnitActual), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColUnitEstimated), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColUnitVariance), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColMarkup), numeric: true),
        ],
        rows: calc.itemsBreakdown.map((item) {
          final varColor = _varianceColor(item.varianceStatus);
          final totalExpensesAllocated = item.totalActualLandedCostEgp - item.fobTotalEgp;

          return DataRow(
            cells: [
              DataCell(LtrText(item.itemCode, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
              DataCell(
                SizedBox(
                  width: 140,
                  child: Text(
                    item.itemNameAr,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(LtrText(item.hsCode, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
              DataCell(SettlementMoneyText('${item.quantity.toStringAsFixed(0)} ${item.unitOfMeasure}', style: const TextStyle(fontSize: 12))),
              DataCell(SettlementMoneyText('${item.fobUnitPriceFc.toStringAsFixed(2)} ${item.currency}', style: const TextStyle(fontSize: 12))),
              DataCell(SettlementMoneyText('${formatSettlementMoney(item.fobTotalEgp)} $egp', style: const TextStyle(fontSize: 12))),
              DataCell(SettlementMoneyText('${formatSettlementMoney(totalExpensesAllocated)} $egp', style: const TextStyle(fontSize: 12, color: AppTheme.flatOrange))),
              DataCell(SettlementMoneyText('${formatSettlementMoney(item.totalActualLandedCostEgp)} $egp', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              DataCell(
                SettlementMoneyText(
                  '${formatSettlementMoney(item.actualUnitLandedCostEgp)} $egp',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.flatCobalt),
                ),
              ),
              DataCell(SettlementMoneyText('${formatSettlementMoney(item.estimatedUnitLandedCostEgp)} $egp', style: const TextStyle(fontSize: 12))),
              DataCell(
                SettlementMoneyText(
                  formatSettlementPercent(item.unitCostVariancePct),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: varColor),
                ),
              ),
              DataCell(
                SettlementStatusChip(
                  label: '${item.markupFactor.toStringAsFixed(3)}x',
                  color: AppTheme.flatCobalt,
                  dense: true,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFooter(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: SettlementTokens.panelFill,
        borderRadius: const BorderRadiusDirectional.only(
          bottomStart: Radius.circular(12),
          bottomEnd: Radius.circular(12),
        ),
        border: Border(top: BorderSide(color: SettlementTokens.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  key: const Key('actualLandedCostApprovedByField'),
                  controller: _approvedByController,
                  decoration: InputDecoration(
                    labelText: l10n.settlementClo02ApprovedByLabel,
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: TextField(
                  key: const Key('actualLandedCostNotesField'),
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: l10n.settlementClo02NotesLabel,
                    prefixIcon: const Icon(Icons.notes, size: 18),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SettlementFit(child: AppButton(
                key: const Key('actualLandedCostCancelBtn'),
                label: l10n.settlementCancel,
                icon: Icons.cancel_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: _isSubmitting
                    ? null
                    : () => UnsavedChangesGuard.maybePop(context, isDirty: _isDirty),
              )),
              const SizedBox(width: 12),
              SettlementFit(child: AppButton(
                key: const Key('actualLandedCostApproveBtn'),
                label: _isSubmitting
                    ? l10n.settlementClo02Approving
                    : l10n.settlementClo02Approve,
                icon: Icons.verified,
                variant: AppButtonVariant.success,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _handleApprove,
              )),
            ],
          ),
        ],
      ),
    );
  }
}
