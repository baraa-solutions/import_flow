import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/metric_card.dart';
import '../models/customs_clearance_model.dart';
import '../services/discrepancy_and_damage_export_service.dart';
import 'customs_ui.dart';
import 'discrepancy_protocol_dialog.dart';

/// Screen 61: Customs Clearance - Discrepancy & Damage Registry SubTab.
class DiscrepancyAndDamageTab extends ConsumerStatefulWidget {
  final List<CustomsClearanceModel> records;
  final List<Map<String, dynamic>> discrepancyProtocols;
  final VoidCallback? onRefresh;
  final ValueChanged<Map<String, dynamic>>? onAddProtocol;

  const DiscrepancyAndDamageTab({
    super.key,
    required this.records,
    required this.discrepancyProtocols,
    this.onRefresh,
    this.onAddProtocol,
  });

  @override
  ConsumerState<DiscrepancyAndDamageTab> createState() => _DiscrepancyAndDamageTabState();
}

class _DiscrepancyAndDamageTabState extends ConsumerState<DiscrepancyAndDamageTab> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'ALL'; // ALL, CLAIM_SUBMITTED, APPROVED, UNDER_REVIEW
  bool _isExporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredProtocols {
    return widget.discrepancyProtocols.where((p) {
      if (_statusFilter != 'ALL' && p['insurance_claim_status'] != _statusFilter) {
        return false;
      }
      final q = _searchController.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      final protoNo = (p['protocol_no'] ?? '').toString().toLowerCase();
      final declNo = (p['declaration_no'] ?? '').toString().toLowerCase();
      final containerNo = (p['container_no'] ?? '').toString().toLowerCase();
      final damageType = (p['damage_type'] ?? '').toString().toLowerCase();
      final party = (p['responsible_party'] ?? '').toString().toLowerCase();
      final notes = (p['notes'] ?? '').toString().toLowerCase();
      return protoNo.contains(q) ||
          declNo.contains(q) ||
          containerNo.contains(q) ||
          damageType.contains(q) ||
          party.contains(q) ||
          notes.contains(q);
    }).toList();
  }

  Future<void> _addProtocol() async {
    final l = context.l10n;
    final protocol = await showAddDiscrepancyProtocolDialog(context);
    if (protocol == null || !mounted) return;
    widget.onAddProtocol?.call(protocol);
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, l.discrepancyDamageSaveSuccess, severity: AppSeverity.success),
    );
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
    final filtered = _filteredProtocols;

    // KPI Metrics calculation
    final totalProtocols = widget.discrepancyProtocols.length;
    final totalLoss = widget.discrepancyProtocols.fold<double>(
      0.0,
      (sum, p) => sum + ((p['estimated_loss_egp'] as num?)?.toDouble() ?? 0.0),
    );
    final submittedClaims =
        widget.discrepancyProtocols.where((p) => p['insurance_claim_status'] == 'CLAIM_SUBMITTED').length;
    final approvedClaims =
        widget.discrepancyProtocols.where((p) => p['insurance_claim_status'] == 'APPROVED').length;

    final metrics = [
      MetricCardData(
        title: l.discrepancyDamageKpiTotalProtocols,
        value: '$totalProtocols',
        icon: Icons.assignment_outlined,
        color: AppTheme.charcoal,
      ),
      MetricCardData(
        title: '${l.discrepancyDamageKpiTotalLoss} (${l.egpCurrency})',
        value: CcFormat.money(totalLoss),
        icon: Icons.trending_down_rounded,
        color: AppTheme.crimson,
      ),
      MetricCardData(
        title: l.discrepancyDamageKpiClaimsSubmitted,
        value: '$submittedClaims',
        icon: Icons.pending_actions_rounded,
        color: AppTheme.orange,
      ),
      MetricCardData(
        title: l.discrepancyDamageKpiClaimsApproved,
        value: '$approvedClaims',
        icon: Icons.verified_user_rounded,
        color: AppTheme.emerald,
      ),
    ];

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CcSectionCard(
              title: l.discrepancyDamageScreenTitle,
              icon: Icons.report_problem_rounded,
              accent: AppTheme.crimson,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.discrepancyDamageScreenSubtitle,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AppButton(
                        label: l.discrepancyDamageExportTsvBtn,
                        icon: Icons.table_chart_outlined,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        onPressed: _isExporting
                            ? null
                            : () => _runExport(
                                  () => DiscrepancyAndDamageExportService.saveDiscrepanciesTsvToFile(
                                    context,
                                    widget.discrepancyProtocols,
                                  ),
                                ),
                      ),
                      AppButton(
                        label: l.discrepancyDamageExportExcelBtn,
                        icon: Icons.file_present_outlined,
                        variant: AppButtonVariant.success,
                        size: AppButtonSize.small,
                        onPressed: _isExporting
                            ? null
                            : () => _runExport(
                                  () => DiscrepancyAndDamageExportService.saveDiscrepanciesCsvToFile(
                                    context,
                                    widget.discrepancyProtocols,
                                  ),
                                ),
                      ),
                      AppButton(
                        label: l.discrepancyDamagePrintPdfBtn,
                        icon: Icons.picture_as_pdf_outlined,
                        variant: AppButtonVariant.danger,
                        size: AppButtonSize.small,
                        onPressed: _isExporting
                            ? null
                            : () => _runExport(
                                  () => DiscrepancyAndDamageExportService.printOrSaveDiscrepancyPdf(
                                    context,
                                    widget.discrepancyProtocols,
                                  ),
                                ),
                      ),
                      AppButton(
                        label: l.discrepancyDamageCopyDossierBtn,
                        icon: Icons.copy_all_outlined,
                        variant: AppButtonVariant.ghost,
                        size: AppButtonSize.small,
                        onPressed: () => DiscrepancyAndDamageExportService.copyDossierToClipboard(
                          context,
                          widget.discrepancyProtocols,
                        ),
                      ),
                      AppButton(
                        label: l.discrepancyDamageAddProtocolBtn,
                        icon: Icons.add,
                        size: AppButtonSize.small,
                        onPressed: _addProtocol,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            CcUi.metrics(metrics),
            const SizedBox(height: 16),
            CcSectionCard(
              title: l.discrepancyDamageSummaryHeader,
              icon: Icons.inventory_2_outlined,
              accent: AppTheme.crimson,
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 300,
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: l.discrepancyDamageSearchHint,
                            isDense: true,
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _searchController,
                              builder: (context, val, _) {
                                if (val.text.isEmpty) return const SizedBox.shrink();
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 14),
                                      tooltip: l.discrepancyDamageCopyFieldTooltip,
                                      onPressed: () => CopyHelper.copy(context, _searchController.text),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildFilterChip(label: l.discrepancyDamageFilterAll, value: 'ALL'),
                          _buildFilterChip(label: l.discrepancyDamageFilterSubmitted, value: 'CLAIM_SUBMITTED'),
                          _buildFilterChip(label: l.discrepancyDamageFilterApproved, value: 'APPROVED'),
                          _buildFilterChip(label: l.discrepancyDamageFilterUnderReview, value: 'UNDER_REVIEW'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    SizedBox(
                      height: 170,
                      child: CcStateView.empty(
                        message: l.discrepancyDamageEmptyRecords,
                        icon: Icons.inventory_rounded,
                      ),
                    )
                  else
                    _buildTable(filtered, l),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> filtered, AppLocalizations l) {
    DataColumn col(String label, {bool numeric = false}) => DataColumn(
          numeric: numeric,
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAltOf(context)),
        columns: [
          col(l.discrepancyDamageColActions),
          col(l.discrepancyDamageColProtocolNo),
          col(l.discrepancyDamageColDeclarationNo),
          col(l.discrepancyDamageColContainerNo),
          col(l.discrepancyDamageColDamageType),
          col(l.discrepancyDamageColDamagedQty, numeric: true),
          col(l.discrepancyDamageColEstimatedLoss, numeric: true),
          col(l.discrepancyDamageColResponsibleParty),
          col(l.discrepancyDamageColClaimStatus),
          col(l.discrepancyDamageColDate),
        ],
        rows: filtered.map((p) => _buildRow(p, l)).toList(),
      ),
    );
  }

  /// Copyable code pill (LTR) for protocol / declaration / container numbers.
  Widget _codeBadge(String text, AppSeverity severity, {bool mono = false}) {
    final fg = AppTheme.severityForegroundOf(context, severity);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.severityBackgroundOf(context, severity),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LtrText(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: fg,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.copy, size: 12, color: fg),
        ],
      ),
    );
  }

  DataRow _buildRow(Map<String, dynamic> p, AppLocalizations l) {
    final status = p['insurance_claim_status'] as String?;
    final isApproved = status == 'APPROVED';
    final isUnderReview = status == 'UNDER_REVIEW';
    final claimStr = DiscrepancyAndDamageExportService.getClaimStatusLabel(context, status);
    final lossValue = (p['estimated_loss_egp'] as num?)?.toDouble() ?? 0.0;
    final loss = lossValue.toStringAsFixed(2);
    final lossStr = '${CcFormat.money(lossValue)} ${l.discrepancyDamageCurrencyEgp}';
    final protoNo = (p['protocol_no'] ?? '').toString();
    final declNo = (p['declaration_no'] ?? '').toString();
    final containerNo = (p['container_no'] ?? '').toString();
    final damageType = (p['damage_type'] ?? '').toString();
    final damagedQty = (p['damaged_qty'] ?? '').toString();
    final party = (p['responsible_party'] ?? '').toString();
    final date = (p['date'] ?? '').toString();
    final notes = (p['notes'] ?? '-').toString();

    final rowSummary =
        "$protoNo\t$declNo\t$containerNo\t$damageType\t$damagedQty\t$loss ${l.discrepancyDamageCurrencyEgp}\t$party\t$claimStr\t$date\t$notes";

    DataCell cell(String value, Widget child) =>
        DataCell(CopyableTableCell(value: value, rowSummary: rowSummary, child: child));

    return DataRow(cells: [
      DataCell(
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
          tooltip: l.discrepancyDamageCopyRowSummaryBtn,
          onPressed: () => CopyHelper.copy(
            context,
            rowSummary,
            customMessage: l.discrepancyDamageCopyRowSummarySuccess,
          ),
        ),
      ),
      cell(protoNo, _codeBadge(protoNo, AppSeverity.danger)),
      cell(declNo, _codeBadge(declNo, AppSeverity.info)),
      cell(containerNo, _codeBadge(containerNo, AppSeverity.info, mono: true)),
      cell(damageType, Text(damageType, style: const TextStyle(fontWeight: FontWeight.w600))),
      cell(damagedQty, LtrText(damagedQty)),
      cell(
        lossStr,
        LtrText(
          lossStr,
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson),
        ),
      ),
      cell(party, Text(party)),
      cell(
        claimStr,
        CcStatusChip(
          label: claimStr,
          severity: isApproved
              ? AppSeverity.success
              : (isUnderReview ? AppSeverity.warning : AppSeverity.info),
          icon: isApproved
              ? Icons.check_circle_outline
              : (isUnderReview ? Icons.hourglass_top_outlined : Icons.assignment_outlined),
        ),
      ),
      cell(date, LtrText(date)),
    ]);
  }

  Widget _buildFilterChip({required String label, required String value}) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selectedColor: AppTheme.crimsonLight,
      checkmarkColor: AppTheme.crimson,
      onSelected: (_) {
        setState(() => _statusFilter = value);
      },
    );
  }
}
