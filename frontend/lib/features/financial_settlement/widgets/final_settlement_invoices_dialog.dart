import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/metric_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/invoices_aggregation_model.dart';
import '../providers/financial_settlement_provider.dart';
import 'settlement_ui.dart';
import '../../logistics_invoices/screens/logistics_invoices_screen.dart';

class FinalSettlementInvoicesDialog extends ConsumerStatefulWidget {
  final int importFileId;
  final String importFileCode;

  const FinalSettlementInvoicesDialog({
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
      builder: (ctx) => FinalSettlementInvoicesDialog(
        importFileId: importFileId,
        importFileCode: importFileCode,
      ),
    );
  }

  @override
  ConsumerState<FinalSettlementInvoicesDialog> createState() =>
      _FinalSettlementInvoicesDialogState();
}

class _FinalSettlementInvoicesDialogState
    extends ConsumerState<FinalSettlementInvoicesDialog> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  InvoicesAggregationResponseModel? _aggregationData;

  String _selectedPartyFilter = 'ALL';
  final _settledByController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default to the signed-in user (no hard-coded sample name).
    _settledByController.text = ref.read(authProvider).user?.fullName ?? '';
    _loadData();
  }

  @override
  void dispose() {
    _settledByController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ref
          .read(financialSettlementProvider.notifier)
          .fetchInvoicesAggregation(widget.importFileId);
      if (mounted) {
        setState(() {
          _aggregationData = data;
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

  Future<void> _handleConfirmSettlement() async {
    if (_aggregationData == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final req = ConfirmInvoicesSettlementRequestModel(
        importFileId: widget.importFileId,
        settlementNotes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      final res = await ref
          .read(financialSettlementProvider.notifier)
          .confirmInvoicesSettlement(req);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppTheme.emerald,
            behavior: SnackBarBehavior.floating,
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
            backgroundColor: AppTheme.crimson,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.85).clamp(800.0, 1250.0);
    final dialogHeight = (screenSize.height * 0.88).clamp(600.0, 850.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 16,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            _buildHeader(l10n),
            Expanded(
              child: _isLoading
                  ? SettlementStateView.loading(message: l10n.settlementClo01Loading)
                  : _errorMessage != null
                      ? SettlementStateView.error(
                          message: _errorMessage!,
                          actionLabel: l10n.settlementRetry,
                          onAction: _loadData,
                        )
                      : _buildBody(l10n),
            ),
            _buildFooter(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    final settled = _aggregationData?.financialSettlementStatus == 'INVOICES_SETTLED';
    return SettlementDialogHeader(
      icon: Icons.receipt_long_rounded,
      title: l10n.settlementClo01Title,
      subtitle: l10n.settlementClo01Subtitle(widget.importFileCode),
      trailing: _aggregationData == null
          ? null
          : SettlementStatusChip(
              label: settled
                  ? l10n.settlementClo01StatusSettled
                  : l10n.settlementClo01StatusPending,
              color: settled ? AppTheme.emerald : AppTheme.cobalt,
              icon: settled ? Icons.check_circle : Icons.hourglass_top_rounded,
              dense: true,
            ),
      onClose: () => Navigator.of(context).pop(false),
      closeTooltip: l10n.settlementClose,
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final data = _aggregationData!;
    final filteredInvoices = _selectedPartyFilter == 'ALL'
        ? data.invoices
        : data.invoices
            .where((inv) => inv.partyType == _selectedPartyFilter)
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildKpiMetricStrip(data, l10n),
          const SizedBox(height: 16),
          if (settlementWarningLines(l10n, data.messages, data.unsettledWarnings).isNotEmpty) ...[
            _buildWarningsCard(
                settlementWarningLines(l10n, data.messages, data.unsettledWarnings), l10n),
            const SizedBox(height: 16),
          ],
          _buildPartiesFilterChips(data, l10n),
          const SizedBox(height: 16),
          _buildInvoicesTable(filteredInvoices, l10n),
          const SizedBox(height: 20),
          _buildSignOffForm(l10n),
        ],
      ),
    );
  }

  Widget _buildKpiMetricStrip(
      InvoicesAggregationResponseModel data, AppLocalizations l10n) {
    final egp = l10n.financialSettlementCurrencyEgp;
    final hasRemaining = data.totalRemainingEgp > 0;
    return SettlementMetricStrips(
      metrics: [
        MetricCardData(
          title: l10n.settlementClo01KpiTotal,
          value: '${formatSettlementMoney(data.totalAmountEgp)} $egp',
          icon: Icons.account_balance_wallet_outlined,
          color: AppTheme.charcoal,
          tooltip: l10n.settlementClo01KpiTotalSub(data.totalInvoicesCount),
        ),
        MetricCardData(
          title: l10n.settlementClo01KpiPaid,
          value: '${formatSettlementMoney(data.totalPaidEgp)} $egp',
          icon: Icons.check_circle_outline_rounded,
          color: AppTheme.emerald,
          tooltip: l10n.settlementClo01KpiPaidSub,
        ),
        MetricCardData(
          title: l10n.settlementClo01KpiRemaining,
          value: '${formatSettlementMoney(data.totalRemainingEgp)} $egp',
          icon: Icons.pending_actions_rounded,
          color: hasRemaining ? AppTheme.crimson : AppTheme.emerald,
          tooltip: hasRemaining
              ? l10n.settlementClo01KpiRemainingSubDue
              : l10n.settlementClo01KpiRemainingSubNone,
        ),
        MetricCardData(
          title: l10n.settlementClo01KpiWht,
          value: '${formatSettlementMoney(data.totalWithholdingTaxEgp)} $egp',
          icon: Icons.account_balance_outlined,
          color: AppTheme.orange,
          tooltip: l10n.settlementClo01KpiWhtSub,
        ),
        MetricCardData(
          title: l10n.settlementClo01KpiReady,
          value: '${data.settlementReadinessPercent.toStringAsFixed(1)}%',
          icon: Icons.speed_rounded,
          color: AppTheme.cobalt,
          tooltip: l10n.settlementClo01KpiReadySub,
        ),
      ],
    );
  }

  Widget _buildWarningsCard(List<String> warnings, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settlementClo01WarningsTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.orange,
                  ),
                ),
                const SizedBox(height: 4),
                ...warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: AppTheme.orange)),
                        Expanded(
                          child: Text(w, style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartiesFilterChips(
      InvoicesAggregationResponseModel data, AppLocalizations l10n) {
    final partyFilters = <MapEntry<String, String>>[
      MapEntry('ALL', l10n.settlementClo01PartyAll(data.invoices.length)),
      MapEntry('SUPPLIER', l10n.settlementClo01PartySupplier),
      MapEntry('CARRIER', l10n.settlementClo01PartyCarrier),
      MapEntry('INSURANCE', l10n.settlementClo01PartyInsurance),
      MapEntry('CUSTOMS', l10n.settlementClo01PartyCustoms),
      MapEntry('BROKER', l10n.settlementClo01PartyBroker),
      MapEntry('TRANSPORT', l10n.settlementClo01PartyTransport),
      MapEntry('DEMURRAGE', l10n.settlementClo01PartyDemurrage),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...partyFilters.map((filter) {
            final isSelected = _selectedPartyFilter == filter.key;
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8.0),
              child: FilterChip(
                label: Text(filter.value),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedPartyFilter = filter.key;
                  });
                },
                selectedColor: AppTheme.charcoal,
                checkmarkColor: AppTheme.white,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.white : AppTheme.charcoal,
                ),
                backgroundColor: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppTheme.charcoal : SettlementTokens.border,
                  ),
                ),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8.0),
            child: ActionChip(
              avatar: const Icon(Icons.add_circle_outline, size: 16, color: Colors.white),
              label: const Text('إدارة فواتير الخدمات اللوجستية (LSI)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF0D9488),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => LogisticsInvoicesScreen(
                      initialShipmentId: widget.importFileId,
                    ),
                  ),
                );
                _loadData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesTable(
      List<AggregatedInvoiceItemModel> invoices, AppLocalizations l10n) {
    if (invoices.isEmpty) {
      return SettlementPanel(
        filled: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SettlementStateView.empty(
          message: l10n.settlementClo01NoInvoices,
          icon: Icons.receipt_long_outlined,
        ),
      );
    }

    final egp = l10n.financialSettlementCurrencyEgp;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        border: Border.all(color: SettlementTokens.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(SettlementTokens.tableHeadFill),
            columnSpacing: 16,
            horizontalMargin: 16,
            headingRowHeight: 40,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 64,
            columns: [
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColInvoice)),
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColParty)),
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColCategory)),
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColOriginal), numeric: true),
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColTotal), numeric: true),
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColPaid), numeric: true),
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColRemaining), numeric: true),
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColPayStatus)),
              DataColumn(label: settlementHeadCell(l10n.settlementClo01ColSource)),
            ],
            rows: invoices.map((inv) {
              final isPaid = inv.paymentStatus == 'PAID' || inv.remainingAmountEgp == 0;
              final isPartial = inv.paymentStatus == 'PARTIAL';
              final statusColor = isPaid
                  ? AppTheme.emerald
                  : isPartial
                      ? AppTheme.orange
                      : AppTheme.crimson;
              final statusLabel = isPaid
                  ? l10n.settlementClo01PaidFull
                  : isPartial
                      ? l10n.settlementClo01PaidPartial
                      : l10n.settlementClo01Unpaid;

              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LtrText(
                          inv.invoiceNo,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        if (inv.paymentReference != null)
                          Text(
                            inv.paymentReference!,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          inv.partyName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          inv.partyTypeAr,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(inv.categoryAr, style: const TextStyle(fontSize: 11))),
                  DataCell(
                    SettlementMoneyText(
                      inv.currency == 'EGP'
                          ? '${formatSettlementMoney(inv.amountEgp)} $egp'
                          : '${formatSettlementMoney(inv.amountFc)} ${inv.currency}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  DataCell(
                    SettlementMoneyText(
                      '${formatSettlementMoney(inv.amountEgp)} $egp',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(
                    SettlementMoneyText(
                      '${formatSettlementMoney(inv.paidAmountEgp)} $egp',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.emerald,
                      ),
                    ),
                  ),
                  DataCell(
                    SettlementMoneyText(
                      '${formatSettlementMoney(inv.remainingAmountEgp)} $egp',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: inv.remainingAmountEgp > 0
                            ? AppTheme.crimson
                            : AppTheme.textMuted,
                      ),
                    ),
                  ),
                  DataCell(
                    SettlementStatusChip(
                      label: statusLabel,
                      color: statusColor,
                      dense: true,
                    ),
                  ),
                  DataCell(
                    Text(
                      inv.sourceModule,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSignOffForm(AppLocalizations l10n) {
    return SettlementPanel(
      filled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettlementSectionHeader(
            title: l10n.settlementClo01SignOffTitle,
            icon: Icons.verified_user_outlined,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _settledByController,
                  decoration: InputDecoration(
                    labelText: l10n.settlementClo01SettledByLabel,
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: l10n.settlementClo01NotesLabel,
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.edit_note, size: 18),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(AppLocalizations l10n) {
    return SettlementDialogFooter(
      actions: [
        SettlementFit(child: AppButton(
          key: const Key('finalSettlementInvoicesCancelBtn'),
          label: l10n.settlementCancel,
          icon: Icons.close,
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        )),
        SettlementFit(child: AppButton(
          key: const Key('confirmInvoicesSettlementBtn'),
          label: _isSubmitting
              ? l10n.settlementClo01Confirming
              : l10n.settlementClo01Confirm,
          icon: Icons.check_circle,
          variant: AppButtonVariant.success,
          isLoading: _isSubmitting,
          onPressed: (_isLoading || _isSubmitting) ? null : _handleConfirmSettlement,
        )),
      ],
    );
  }
}
