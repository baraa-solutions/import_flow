import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/metric_card.dart';
import '../models/customs_clearance_model.dart';
import '../services/final_duty_payment_export_service.dart';
import 'clearance_details_dialog.dart';
import 'customs_ui.dart';

/// Screen 62: Customs Clearance - Final Duty Payment & Release SubTab.
class FinalDutyPaymentTab extends ConsumerStatefulWidget {
  final List<CustomsClearanceModel> records;
  final VoidCallback? onRefresh;
  final void Function(CustomsClearanceModel record)? onView;
  final void Function(CustomsClearanceModel record)? onPay;
  final void Function(CustomsClearanceModel record)? onRelease;

  const FinalDutyPaymentTab({
    super.key,
    required this.records,
    this.onRefresh,
    this.onView,
    this.onPay,
    this.onRelease,
  });

  @override
  ConsumerState<FinalDutyPaymentTab> createState() => _FinalDutyPaymentTabState();
}

class _FinalDutyPaymentTabState extends ConsumerState<FinalDutyPaymentTab> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'ALL'; // ALL, PAID, PENDING, RELEASED
  bool _isExporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CustomsClearanceModel> get _filteredRecords {
    return widget.records.where((r) {
      if (_statusFilter == 'PAID' && !CcStatus.isPaid(r)) {
        return false;
      }
      if (_statusFilter == 'PENDING' && CcStatus.isPaid(r)) {
        return false;
      }
      if (_statusFilter == 'RELEASED' && !CcStatus.isReleased(r)) {
        return false;
      }

      final q = _searchController.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      final clr = r.clearanceCode.toLowerCase();
      final decl = (r.declaration46No ?? '').toLowerCase();
      final office = r.customsOfficeName.toLowerCase();
      final channel = r.channelType.toLowerCase();
      final receipt = (r.bankReceiptNo ?? '').toLowerCase();
      final permit = (r.releasePermitNo ?? '').toLowerCase();
      final status = r.status.toLowerCase();

      return clr.contains(q) ||
          decl.contains(q) ||
          office.contains(q) ||
          channel.contains(q) ||
          receipt.contains(q) ||
          permit.contains(q) ||
          status.contains(q);
    }).toList();
  }

  void _copyRowSummary(CustomsClearanceModel r, AppLocalizations l) {
    final isPaid = CcStatus.isPaid(r);
    final actual = CcFormat.fixed(r.effectiveDutyTotal);
    final est = CcFormat.fixed(r.estimatedDutyTotal);
    final variance = '${CcFormat.signedFixed(r.dutyVarianceAmount)} (${CcFormat.percent(r.dutyVariancePercentage)})';
    final paymentStatusStr = isPaid ? l.finalDutyStatusPaidVerified : l.finalDutyStatusPendingPayment;
    final rowSummary =
        "${r.clearanceCode}\t${r.declaration46No ?? '-'}\t${r.customsOfficeName}\t${r.channelType}\t$actual ${l.finalDutyCurrencyEgp}\t$est ${l.finalDutyCurrencyEgp}\t$variance\t$paymentStatusStr\t${r.bankReceiptNo ?? '-'}\t${r.releasePermitNo ?? '-'}\t${r.status}";

    CopyHelper.copy(context, rowSummary, customMessage: l.finalDutyCopyRowSummarySuccess);
  }

  Future<void> _runExport(Future<void> Function() action) async {
    setState(() => _isExporting = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final records = widget.records;
    final filtered = _filteredRecords;

    final kpis = FinalDutyKpis.from(records);

    final metrics = [
      MetricCardData(
        title: '${l.finalDutyKpiOutstanding} (${l.egpCurrency})',
        value: CcFormat.money(kpis.outstanding),
        icon: Icons.account_balance_wallet_outlined,
        color: AppTheme.cobalt,
      ),
      MetricCardData(
        title: '${l.finalDutyKpiTotalPaid} (${l.egpCurrency})',
        value: CcFormat.money(kpis.totalPaid),
        icon: Icons.check_circle_outline,
        color: AppTheme.emerald,
      ),
      MetricCardData(
        title: l.finalDutyKpiPendingPayment,
        value: kpis.pendingCount.toString(),
        icon: Icons.pending_actions_outlined,
        color: AppTheme.orange,
      ),
      MetricCardData(
        title: '${l.finalDutyKpiNetVariance} (${l.egpCurrency})',
        value: CcFormat.signedMoney(kpis.netVariance),
        icon: Icons.compare_arrows_outlined,
        color: kpis.netVariance.abs() > CcUi.varianceWarnThresholdEgp ? AppTheme.crimson : AppTheme.charcoal,
      ),
    ];

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CcSectionCard(
              title: l.finalDutyScreenTitle,
              icon: Icons.receipt_long,
              accent: AppTheme.emerald,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.finalDutyScreenSubtitle,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AppButton(
                        label: l.finalDutyExportTsvBtn,
                        icon: Icons.table_view,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        onPressed: _isExporting
                            ? null
                            : () => _runExport(
                                  () => FinalDutyPaymentExportService.saveFinalDutyTsvToFile(context, filtered),
                                ),
                      ),
                      AppButton(
                        label: l.finalDutyExportExcelBtn,
                        icon: Icons.grid_on,
                        variant: AppButtonVariant.success,
                        size: AppButtonSize.small,
                        onPressed: _isExporting
                            ? null
                            : () => _runExport(
                                  () => FinalDutyPaymentExportService.saveFinalDutyCsvToFile(context, filtered),
                                ),
                      ),
                      AppButton(
                        label: l.finalDutyPrintPdfBtn,
                        icon: Icons.picture_as_pdf,
                        variant: AppButtonVariant.danger,
                        size: AppButtonSize.small,
                        onPressed: _isExporting
                            ? null
                            : () => _runExport(
                                  () => FinalDutyPaymentExportService.printOrSaveFinalDutyPdf(context, filtered),
                                ),
                      ),
                      AppButton(
                        label: l.finalDutyCopyDossierBtn,
                        icon: Icons.copy_all,
                        variant: AppButtonVariant.ghost,
                        size: AppButtonSize.small,
                        onPressed: () => FinalDutyPaymentExportService.copyDossierToClipboard(context, filtered),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            CcUi.metrics(metrics),
            const SizedBox(height: 16),

            // Duty Ledger & Release Status Table Card
            CcSectionCard(
              title: l.customsClearanceDutyLedgerTableTitle,
              icon: Icons.payments_outlined,
              accent: AppTheme.emerald,
              margin: EdgeInsets.zero,
              trailing: LtrText(
                '${filtered.length} / ${records.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryOf(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search & Filter Toolbar
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 320,
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: l.finalDutySearchHint,
                            prefixIcon: const Icon(Icons.search, size: 18),
                            isDense: true,
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l.finalDutyCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, _searchController.text),
                                ),
                              ],
                            ),
                            contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        children: [
                          _buildFilterChip('ALL', l.finalDutyFilterAll),
                          _buildFilterChip('PAID', l.finalDutyFilterPaid),
                          _buildFilterChip('PENDING', l.finalDutyFilterPending),
                          _buildFilterChip('RELEASED', l.finalDutyFilterReleased),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    SizedBox(
                      height: 160,
                      child: CcStateView.empty(message: l.finalDutyEmptyRecords),
                    )
                  else
                    _buildLedgerTable(filtered, l),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerTable(List<CustomsClearanceModel> filtered, AppLocalizations l) {
    DataColumn col(String label, {bool numeric = false}) => DataColumn(
          numeric: numeric,
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAltOf(context)),
        columns: [
          col(l.customsClearanceColActions),
          col(l.customsClearanceColClearanceCode),
          col(l.customsClearanceColDecl46),
          col(l.customsClearanceColCustomsOffice),
          col(l.customsClearanceChannelLabel),
          col(l.customsClearanceColActualDuty, numeric: true),
          col(l.customsClearanceColEstimatedDuty, numeric: true),
          col(l.customsClearanceColDutyVariance, numeric: true),
          col(l.customsClearanceColPaymentStatus),
          col(l.finalDutyColBankReceipt),
          col(l.finalDutyColReleasePermit),
        ],
        rows: filtered.map((r) => _buildRow(r, l)).toList(),
      ),
    );
  }

  /// Copyable code cell (LTR), or a muted dash when empty.
  DataCell _codeCell(String? value, String rowSummary, {Color? color, double size = 12}) {
    final has = value != null && value.isNotEmpty;
    return DataCell(
      CopyableTableCell(
        value: has ? value : '-',
        rowSummary: rowSummary,
        child: has
            ? InkWell(
                onTap: () => CopyHelper.copy(context, value),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LtrText(
                      value,
                      style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: color),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.copy, size: 11, color: color ?? AppTheme.textMutedOf(context)),
                  ],
                ),
              )
            : Text('-', style: TextStyle(color: AppTheme.textMutedOf(context))),
      ),
    );
  }

  DataRow _buildRow(CustomsClearanceModel r, AppLocalizations l) {
    final isPaid = CcStatus.isPaid(r);
    final isReleased = CcStatus.isReleased(r);
    final canPay = CcStatus.canPay(r);
    final canRelease = CcStatus.canRelease(r);
    final actual = r.effectiveDutyTotal;
    final actualDutyStr = '${CcFormat.money(actual)} ${l.finalDutyCurrencyEgp}';
    final estDutyStr = '${CcFormat.money(r.estimatedDutyTotal)} ${l.finalDutyCurrencyEgp}';
    final varianceStr = '${CcFormat.signedMoney(r.dutyVarianceAmount)} (${CcFormat.percent(r.dutyVariancePercentage)})';
    final paymentStatusStr = isPaid ? l.finalDutyStatusPaidVerified : l.finalDutyStatusPendingPayment;
    final channelLabel = CcUi.channelStyle(l, r.channelType).label;
    final statusLabel = CcUi.statusStyle(l, r.status).label;
    final bankReceiptStr = r.bankReceiptNo ?? '-';
    final releasePermitStr = r.releasePermitNo ?? '-';
    final rowSummary =
        "${r.clearanceCode}\t${r.declaration46No ?? '-'}\t${r.customsOfficeName}\t$channelLabel\t$actualDutyStr\t$estDutyStr\t$varianceStr\t$paymentStatusStr\t$bankReceiptStr\t$releasePermitStr\t$statusLabel";

    DataCell textCell(String value, Widget child) =>
        DataCell(CopyableTableCell(value: value, rowSummary: rowSummary, child: child));

    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 16, color: AppTheme.textSecondaryOf(context)),
                tooltip: l.finalDutyCopyRowSummaryBtn,
                onPressed: () => _copyRowSummary(r, l),
              ),
              const SizedBox(width: 4),
              if (isPaid || isReleased)
                AppButton(
                  label: l.view,
                  icon: Icons.visibility_outlined,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  onPressed: () {
                    if (widget.onView != null) {
                      widget.onView!(r);
                    } else {
                      ClearanceDetailsDialog.show(context, record: r);
                    }
                  },
                )
              else
                AppButton(
                  label: l.customsClearanceBtnPayReconcile,
                  icon: Icons.payment,
                  variant: AppButtonVariant.success,
                  size: AppButtonSize.small,
                  onPressed: canPay && widget.onPay != null ? () => widget.onPay!(r) : null,
                ),
              if (canRelease) ...[
                const SizedBox(width: 6),
                AppButton(
                  label: l.customsClearanceBtnFinalRelease,
                  icon: Icons.assignment_turned_in,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: widget.onRelease != null ? () => widget.onRelease!(r) : null,
                ),
              ],
            ],
          ),
        ),
        _codeCell(r.clearanceCode, rowSummary, color: AppTheme.cobalt),
        _codeCell(r.declaration46No, rowSummary),
        textCell(r.customsOfficeName, Text(r.customsOfficeName, style: const TextStyle(fontSize: 12))),
        textCell(channelLabel, Text(channelLabel, style: const TextStyle(fontSize: 12))),
        textCell(
          actualDutyStr,
          LtrText(
            actualDutyStr,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppTheme.successForeground, fontSize: 12),
          ),
        ),
        textCell(estDutyStr, LtrText(estDutyStr, style: const TextStyle(fontSize: 12))),
        textCell(
          varianceStr,
          LtrText(
            varianceStr,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: (r.dutyVarianceAmount ?? 0).abs() > CcUi.varianceWarnThresholdEgp
                  ? AppTheme.warningForeground
                  : AppTheme.textSecondaryOf(context),
            ),
          ),
        ),
        textCell(
          paymentStatusStr,
          CcStatusChip(
            label: paymentStatusStr,
            severity: isPaid ? AppSeverity.success : AppSeverity.warning,
            icon: isPaid ? Icons.check_circle_outline : Icons.warning_amber_rounded,
          ),
        ),
        _codeCell(r.bankReceiptNo, rowSummary, color: AppTheme.infoForeground, size: 11.5),
        _codeCell(r.releasePermitNo, rowSummary, color: AppTheme.successForeground, size: 11.5),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.white : AppTheme.textPrimaryOf(context),
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.cobalt,
      backgroundColor: AppTheme.surfaceAltOf(context),
      showCheckmark: false,
      onSelected: (selected) {
        if (selected) setState(() => _statusFilter = value);
      },
    );
  }
}
