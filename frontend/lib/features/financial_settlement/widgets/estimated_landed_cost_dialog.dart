import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../models/estimated_landed_cost_model.dart';
import '../providers/financial_settlement_provider.dart';
import 'estimated/est_landed_cost_overrides_panel.dart';
import 'estimated/est_landed_cost_summary.dart';
import 'estimated/est_landed_cost_tables.dart';
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

    CopyHelper.copy(context, buffer.toString(), customMessage: context.l10n.settlementEstCopySuccess);
  }

  Future<void> _exportCsv() async {
    if (_data == null) return;
    final buffer = StringBuffer();
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
        child: SelectionArea(
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
    final data = _data;
    if (data == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EstLandedCostSummary(data: data),
          const SizedBox(height: 12),
          EstLandedCostOverridesPanel(
            fxRateController: _fxRateController,
            freightController: _freightController,
            insuranceController: _insuranceController,
            clearanceController: _clearanceController,
            portController: _portController,
            transportController: _transportController,
            bankFeesController: _bankFeesController,
            otherFeesController: _otherFeesController,
            selectedAllocation: _selectedAllocation,
            onAllocationChanged: (val) => setState(() => _selectedAllocation = val),
            onReset: () {
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
            onRecalculate: _loadSimulation,
          ),
          const SizedBox(height: 16),
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
                EstLandedCostTables.buildItemsTable(context, data),
                EstLandedCostTables.buildExpensesTable(context, data),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n) {
    return SettlementDialogFooter(
      leading: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          SettlementFit(
            child: AppButton(
              label: l10n.settlementEstExportBtn,
              icon: Icons.file_download,
              variant: AppButtonVariant.success,
              onPressed: _data == null ? null : _exportCsv,
            ),
          ),
          SettlementFit(
            child: AppButton(
              label: l10n.settlementEstCopyTsvBtn,
              icon: Icons.copy,
              variant: AppButtonVariant.secondary,
              onPressed: _data == null ? null : _copyTsvToClipboard,
            ),
          ),
        ],
      ),
      actions: [
        SettlementFit(
          child: AppButton(
            label: l10n.settlementClose,
            icon: Icons.close,
            variant: AppButtonVariant.secondary,
            onPressed: () => UnsavedChangesGuard.maybePop(context, isDirty: _isDirty),
          ),
        ),
      ],
    );
  }
}
