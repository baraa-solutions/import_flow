import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../models/estimated_landed_cost_model.dart';
import '../providers/financial_settlement_provider.dart';
import 'settlement_ui.dart';

/// Shows the Estimated Landed Cost Simulation Dialog (PL-08).
Future<void> showEstimatedLandedCostDialog(
  BuildContext context,
  WidgetRef ref, {
  required int importFileId,
  EstimatedLandedCostSimulationRequestModel? initialRequest,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => EstimatedLandedCostDialog(
      importFileId: importFileId,
      initialRequest: initialRequest,
    ),
  );
}

class EstimatedLandedCostDialog extends ConsumerStatefulWidget {
  final int importFileId;
  final EstimatedLandedCostSimulationRequestModel? initialRequest;

  const EstimatedLandedCostDialog({
    super.key,
    required this.importFileId,
    this.initialRequest,
  });

  @override
  ConsumerState<EstimatedLandedCostDialog> createState() =>
      _EstimatedLandedCostDialogState();
}

class _EstimatedLandedCostDialogState
    extends ConsumerState<EstimatedLandedCostDialog>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  EstimatedLandedCostSimulationModel? _data;

  // Controllers for overrides
  late final TextEditingController _fxRateController;
  late final TextEditingController _freightController;
  late final TextEditingController _insuranceController;
  late final TextEditingController _clearanceController;
  late final TextEditingController _portController;
  late final TextEditingController _transportController;
  late final TextEditingController _bankFeesController;
  late final TextEditingController _otherFeesController;
  String _selectedAllocation = 'Value-Based';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _fxRateController = TextEditingController();
    _freightController = TextEditingController();
    _insuranceController = TextEditingController();
    _clearanceController = TextEditingController();
    _portController = TextEditingController();
    _transportController = TextEditingController();
    _bankFeesController = TextEditingController();
    _otherFeesController = TextEditingController();

    if (widget.initialRequest != null) {
      _applyRequestToControllers(widget.initialRequest!);
    }

    _loadSimulation();
  }

  void _applyRequestToControllers(
      EstimatedLandedCostSimulationRequestModel req) {
    if (req.exchangeRateOverride != null) {
      _fxRateController.text = req.exchangeRateOverride!.toString();
    }
    if (req.freightAmountEgpOverride != null) {
      _freightController.text = req.freightAmountEgpOverride!.toString();
    }
    if (req.insuranceAmountEgpOverride != null) {
      _insuranceController.text = req.insuranceAmountEgpOverride!.toString();
    }
    if (req.clearanceFeesEgpOverride != null) {
      _clearanceController.text = req.clearanceFeesEgpOverride!.toString();
    }
    if (req.portHandlingEgpOverride != null) {
      _portController.text = req.portHandlingEgpOverride!.toString();
    }
    if (req.inlandTransportEgpOverride != null) {
      _transportController.text = req.inlandTransportEgpOverride!.toString();
    }
    if (req.bankFeesEgpOverride != null) {
      _bankFeesController.text = req.bankFeesEgpOverride!.toString();
    }
    if (req.otherExpensesEgpOverride != null) {
      _otherFeesController.text = req.otherExpensesEgpOverride!.toString();
    }
    _selectedAllocation = req.allocationPreference;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fxRateController.dispose();
    _freightController.dispose();
    _insuranceController.dispose();
    _clearanceController.dispose();
    _portController.dispose();
    _transportController.dispose();
    _bankFeesController.dispose();
    _otherFeesController.dispose();
    super.dispose();
  }

  Future<void> _loadSimulation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final req = _buildRequestFromControllers();
      final result = await ref
          .read(financialSettlementProvider.notifier)
          .simulateEstimatedLandedCost(widget.importFileId, req.toJson());

      if (mounted) {
        setState(() {
          _data = result;
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

  EstimatedLandedCostSimulationRequestModel _buildRequestFromControllers() {
    return EstimatedLandedCostSimulationRequestModel(
      exchangeRateOverride: double.tryParse(_fxRateController.text.trim()),
      freightAmountEgpOverride: double.tryParse(_freightController.text.trim()),
      insuranceAmountEgpOverride:
          double.tryParse(_insuranceController.text.trim()),
      clearanceFeesEgpOverride:
          double.tryParse(_clearanceController.text.trim()),
      portHandlingEgpOverride: double.tryParse(_portController.text.trim()),
      inlandTransportEgpOverride:
          double.tryParse(_transportController.text.trim()),
      bankFeesEgpOverride: double.tryParse(_bankFeesController.text.trim()),
      otherExpensesEgpOverride: double.tryParse(_otherFeesController.text.trim()),
      allocationPreference: _selectedAllocation,
    );
  }

  void _copyTsvToClipboard() {
    if (_data == null) return;
    final buffer = StringBuffer();
    buffer.writeln(
        "Line\tItem Code\tItem Name\tHS Code\tQty\tFOB Unit FC\tFOB Unit EGP\tFOB Total EGP\tCustoms Duty EGP\tVAT & Taxes EGP\tFreight EGP\tClearance & Port EGP\tInland Transport EGP\tTotal Landed EGP\tUnit Landed EGP\tUnit Landed FC\tMarkup Factor\tMarkup %");
    for (final itm in _data!.itemsBreakdown) {
      buffer.writeln(
          "${itm.lineNo}\t${itm.itemCode}\t${itm.itemName}\t${itm.hsCode}\t${itm.qty}\t${itm.unitPriceFc}\t${itm.fobUnitEgp}\t${itm.fobTotalEgp}\t${itm.allocatedCustomsDutyEgp}\t${itm.allocatedVatEgp}\t${itm.allocatedFreightEgp}\t${itm.allocatedClearanceAndPortEgp}\t${itm.allocatedInlandTransportEgp}\t${itm.totalLandedCostEgp}\t${itm.unitLandedCostEgp}\t${itm.unitLandedCostFc}\t${itm.markupFactor}\t${itm.markupPercent}%");
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.settlementEstCopySuccess),
        backgroundColor: AppTheme.emerald,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _exportCsv() async {
    if (_data == null) return;
    final buffer = StringBuffer();
    // UTF-8 BOM for Arabic support in Excel
    buffer.write('\uFEFF');
    buffer.writeln(context.l10n.settlementEstCsvHeader);
    for (final itm in _data!.itemsBreakdown) {
      buffer.writeln(
          '${itm.lineNo},"${itm.itemCode}","${itm.itemName}","${itm.hsCode}",${itm.qty},${itm.unitPriceFc},${itm.fobUnitEgp},${itm.fobTotalEgp},${itm.allocatedCustomsDutyEgp},${itm.allocatedVatEgp},${itm.allocatedFreightEgp},${itm.allocatedClearanceAndPortEgp},${itm.allocatedInlandTransportEgp},${itm.totalLandedCostEgp},${itm.unitLandedCostEgp},${itm.unitLandedCostFc},${itm.markupFactor},${itm.markupPercent}%');
    }

    await FileSaveHelper.exportAndSaveFile(
      context: context,
      bytes: utf8.encode(buffer.toString()),
      stageName: 'Landed Cost Simulation',
      importFileNameOrCode: _data!.importFileCode,
      extension: 'csv',
    );
  }

  bool get _isDirty {
    final req = widget.initialRequest;
    if (_fxRateController.text.trim() != (req?.exchangeRateOverride?.toString() ?? '')) return true;
    if (_freightController.text.trim() != (req?.freightAmountEgpOverride?.toString() ?? '')) return true;
    if (_insuranceController.text.trim() != (req?.insuranceAmountEgpOverride?.toString() ?? '')) return true;
    if (_clearanceController.text.trim() != (req?.clearanceFeesEgpOverride?.toString() ?? '')) return true;
    if (_portController.text.trim() != (req?.portHandlingEgpOverride?.toString() ?? '')) return true;
    if (_transportController.text.trim() != (req?.inlandTransportEgpOverride?.toString() ?? '')) return true;
    if (_bankFeesController.text.trim() != (req?.bankFeesEgpOverride?.toString() ?? '')) return true;
    if (_otherFeesController.text.trim() != (req?.otherExpensesEgpOverride?.toString() ?? '')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width - 32).clamp(360.0, 1150.0);
    final dialogHeight = (screenSize.height - 48).clamp(500.0, 850.0);

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
            children: [
              _buildHeader(l10n),
              Expanded(
                child: _isLoading
                    ? SettlementStateView.loading(message: l10n.settlementEstLoading)
                    : _errorMessage != null
                        ? SettlementStateView.error(
                            message: l10n.settlementEstError(_errorMessage!),
                            actionLabel: l10n.settlementRetry,
                            onAction: _loadSimulation,
                          )
                        : _buildContent(l10n),
              ),
              _buildBottomBar(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    final data = _data;
    return SettlementDialogHeader(
      icon: Icons.calculate,
      title: l10n.settlementEstTitle,
      subtitle: data != null
          ? l10n.settlementEstSubtitle(
              data.importFileCode,
              data.currency,
              '${data.exchangeRate}',
              data.incoterm,
            )
          : l10n.settlementEstSubtitleLoading,
      onClose: () => UnsavedChangesGuard.maybePop(context, isDirty: _isDirty),
      closeTooltip: l10n.settlementClose,
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    if (_data == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Executive Summary Banner
          _buildExecutiveSummaryBanner(),
          const SizedBox(height: 12),

          if (_data!.messages.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(SettlementTokens.radius),
                border: Border.all(color: AppTheme.orange.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final m in _data!.messages)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.orange),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(settlementMessageText(l10n, m), style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // 2. KPI strip (shared metric widgets)
          _buildKpiStrip(l10n),
          const SizedBox(height: 12),

          // 3. Overrides & Recalculate Panel (Collapsible)
          _buildOverridesPanel(l10n),
          const SizedBox(height: 16),

          // 4. Tabs Section
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.cobalt,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.cobalt,
            tabs: [
              Tab(
                icon: const Icon(Icons.table_chart_outlined),
                text: l10n.settlementEstTabItems,
              ),
              Tab(
                icon: const Icon(Icons.receipt_long_outlined),
                text: l10n.settlementEstTabExpenses,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 380,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildItemsTable(l10n),
                _buildExpensesTable(l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveSummaryBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cobalt.withOpacity(0.08),
        border: Border.all(color: AppTheme.cobalt.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: AppTheme.cobalt, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _data!.executiveSummaryAr,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: AppTheme.charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiStrip(AppLocalizations l10n) {
    final d = _data!;
    final egp = l10n.financialSettlementCurrencyEgp;
    String whole(double v) => formatSettlementWhole(v);

    return SettlementMetricStrips(
      metrics: [
        MetricCardData(
          title: l10n.settlementEstKpiFob,
          value: '${whole(d.totalFobEgp)} $egp',
          tooltip: '${whole(d.totalFobFc)} ${d.currency}',
          icon: Icons.inventory_2,
          color: AppTheme.cobalt,
        ),
        MetricCardData(
          title: l10n.settlementEstKpiFreightIns,
          value: '${whole(d.totalFreightEgp + d.totalInsuranceEgp)} $egp',
          icon: Icons.sailing,
          color: AppTheme.wcagEmerald,
          tooltip: l10n.settlementEstKpiFreightSub(whole(d.totalFreightEgp)),
        ),
        MetricCardData(
          title: l10n.settlementEstKpiCustoms,
          value: '${whole(d.totalCustomsAndTaxesEgp)} $egp',
          icon: Icons.account_balance,
          color: AppTheme.orange,
          tooltip: d.totalCustomsDutyEgp > 0 || d.totalVatAndFeesEgp > 0
              ? '${l10n.settlementEstKpiDuty}: ${whole(d.totalCustomsDutyEgp)} | ${l10n.settlementEstKpiVatFees}: ${whole(d.totalVatAndFeesEgp)}'
              : l10n.settlementEstKpiCustomsSub,
        ),
        MetricCardData(
          title: l10n.settlementEstKpiPort,
          value: '${whole(d.totalClearanceAndPortEgp + d.totalInlandTransportEgp)} $egp',
          icon: Icons.local_shipping,
          color: AppTheme.charcoal,
          tooltip: l10n.settlementEstKpiPortSub,
        ),
        MetricCardData(
          title: l10n.settlementEstKpiLanded,
          value: '${whole(d.totalLandedCostEgp)} $egp',
          tooltip: '${whole(d.totalLandedCostFc)} ${d.currency}',
          icon: Icons.monetization_on,
          color: AppTheme.emerald,
        ),
        MetricCardData(
          title: l10n.settlementEstKpiMarkup,
          value: '×${d.averageMarkupFactor.toStringAsFixed(3)}',
          tooltip: '+${d.averageMarkupPercent.toStringAsFixed(1)}%',
          icon: Icons.trending_up,
          color: AppTheme.crimson,
        ),
      ],
    );
  }

  Widget _buildOverridesPanel(AppLocalizations l10n) {
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.all(12),
      backgroundColor: SettlementTokens.panelFill,
      collapsedBackgroundColor: SettlementTokens.panelFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        side: BorderSide(color: SettlementTokens.border),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        side: BorderSide(color: SettlementTokens.border),
      ),
      leading: const Icon(Icons.tune, color: AppTheme.cobalt, size: 20),
      title: Text(
        l10n.settlementEstOverridesTitle,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        l10n.settlementEstOverridesSubtitle,
        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildOverrideField(l10n.settlementEstFxLabel, _fxRateController, l10n.settlementEstFxHint),
            _buildOverrideField(l10n.settlementEstFreightLabel, _freightController, l10n.settlementEstFreightHint),
            _buildOverrideField(l10n.settlementEstInsuranceLabel, _insuranceController, l10n.settlementEstInsuranceHint),
            _buildOverrideField(l10n.settlementEstClearanceLabel, _clearanceController, '4500'),
            _buildOverrideField(l10n.settlementEstPortLabel, _portController, '5000'),
            _buildOverrideField(l10n.settlementEstTransportLabel, _transportController, '7500'),
            _buildOverrideField(l10n.settlementEstBankLabel, _bankFeesController, '2500'),
            _buildOverrideField(l10n.settlementEstOtherLabel, _otherFeesController, '2000'),
            SizedBox(
              width: 220,
              child: SearchableDropdownField<String>(
                key: const Key('estimatedLandedCostAllocationDropdown'),
                value: _selectedAllocation,
                labelText: l10n.financialSettlementAllocationRuleLabel,
                searchHintText: l10n.financialSettlementAllocationRuleSearchHint,
                items: [
                  SearchableDropdownItem(value: 'Value-Based', label: l10n.financialSettlementRuleValueBased),
                  SearchableDropdownItem(value: 'Weight-Based', label: l10n.financialSettlementRuleWeightBased),
                  SearchableDropdownItem(value: 'Volume-Based', label: l10n.financialSettlementRuleVolumeBased),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedAllocation = val;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            SettlementFit(child: AppButton(
              label: l10n.settlementEstResetDefaults,
              icon: Icons.refresh,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () {
                _fxRateController.clear();
                _freightController.clear();
                _insuranceController.clear();
                _clearanceController.clear();
                _portController.clear();
                _transportController.clear();
                _bankFeesController.clear();
                _otherFeesController.clear();
                _selectedAllocation = 'Value-Based';
                _loadSimulation();
              },
            )),
            SettlementFit(child: AppButton(
              label: l10n.settlementEstRecalculate,
              icon: Icons.play_arrow,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              onPressed: _loadSimulation,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildOverrideField(
      String label, TextEditingController ctrl, String hint) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildTableFrame(Widget table) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: SettlementTokens.border),
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: table,
          ),
        ),
      ),
    );
  }

  Widget _buildItemsTable(AppLocalizations l10n) {
    if (_data!.itemsBreakdown.isEmpty) {
      return SettlementStateView.empty(
        message: l10n.settlementEstNoItems,
        icon: Icons.inventory_2_outlined,
      );
    }

    return _buildTableFrame(
      DataTable(
        headingRowColor: WidgetStateProperty.all(SettlementTokens.tableHeadFill),
        columnSpacing: 16,
        horizontalMargin: 12,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 44,
        columns: [
          DataColumn(label: settlementHeadCell(l10n.settlementEstColNo), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColItemCode)),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColItemName)),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColHs)),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColQty), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColFobUnit), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColFobTotal), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColDuty), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColVat), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColFreight), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColTotalLanded), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColUnitLanded), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColUnitLandedFc), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColMarkup), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColMarkupPct), numeric: true),
        ],
        rows: _data!.itemsBreakdown.map((itm) {
          return DataRow(cells: [
            DataCell(SettlementMoneyText('${itm.lineNo}')),
            DataCell(LtrText(itm.itemCode, style: const TextStyle(fontWeight: FontWeight.w600))),
            DataCell(Text(itm.itemName)),
            DataCell(LtrText(itm.hsCode, style: const TextStyle(fontFamily: 'monospace'))),
            DataCell(SettlementMoneyText('${itm.qty}')),
            DataCell(SettlementMoneyText('${itm.unitPriceFc.toStringAsFixed(2)} ${_data!.currency}')),
            DataCell(SettlementMoneyText(formatSettlementMoney(itm.fobTotalEgp))),
            DataCell(SettlementMoneyText(formatSettlementMoney(itm.allocatedCustomsDutyEgp))),
            DataCell(SettlementMoneyText(formatSettlementMoney(itm.allocatedVatEgp))),
            DataCell(SettlementMoneyText(formatSettlementMoney(
                itm.allocatedFreightEgp + itm.allocatedClearanceAndPortEgp + itm.allocatedInlandTransportEgp))),
            DataCell(SettlementMoneyText(
              formatSettlementMoney(itm.totalLandedCostEgp),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
            )),
            DataCell(SettlementMoneyText(
              formatSettlementMoney(itm.unitLandedCostEgp),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
            )),
            DataCell(SettlementMoneyText(
              '${itm.unitLandedCostFc.toStringAsFixed(2)} ${_data!.currency}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            )),
            DataCell(SettlementMoneyText(
              '×${itm.markupFactor.toStringAsFixed(3)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange),
            )),
            DataCell(SettlementMoneyText(
              '+${itm.markupPercent.toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange),
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildExpensesTable(AppLocalizations l10n) {
    if (_data!.expensesBreakdown.isEmpty) {
      return SettlementStateView.empty(
        message: l10n.settlementEstNoExpenses,
        icon: Icons.receipt_long_outlined,
      );
    }

    return _buildTableFrame(
      DataTable(
        headingRowColor: WidgetStateProperty.all(SettlementTokens.tableHeadFill),
        columns: [
          DataColumn(label: settlementHeadCell(l10n.settlementEstColExpCategory)),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColDescription)),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColAmountEgp), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColAmountFc), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColSource)),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColAllocRule)),
        ],
        rows: _data!.expensesBreakdown.map((exp) {
          return DataRow(cells: [
            DataCell(Text(exp.category, style: const TextStyle(fontWeight: FontWeight.w600))),
            DataCell(Text(exp.description)),
            DataCell(SettlementMoneyText(
              formatSettlementMoney(exp.amountEgp),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal),
            )),
            DataCell(SettlementMoneyText('${exp.amountFc.toStringAsFixed(2)} ${exp.currency}')),
            DataCell(Text(exp.source)),
            DataCell(Text(exp.allocationRule)),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n) {
    return SettlementDialogFooter(
      leading: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          SettlementFit(child: AppButton(
            label: l10n.settlementEstExportBtn,
            icon: Icons.file_download,
            variant: AppButtonVariant.success,
            onPressed: _data == null ? null : _exportCsv,
          )),
          SettlementFit(child: AppButton(
            label: l10n.settlementEstCopyTsvBtn,
            icon: Icons.copy,
            variant: AppButtonVariant.secondary,
            onPressed: _data == null ? null : _copyTsvToClipboard,
          )),
        ],
      ),
      actions: [
        SettlementFit(child: AppButton(
          label: l10n.settlementClose,
          icon: Icons.close,
          variant: AppButtonVariant.secondary,
          onPressed: () => UnsavedChangesGuard.maybePop(context, isDirty: _isDirty),
        )),
      ],
    );
  }
}
