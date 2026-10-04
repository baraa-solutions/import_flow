import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/customs_clearance_model.dart';
import '../services/discrepancy_and_damage_export_service.dart';

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

  void _showAddProtocolDialog(AppLocalizations l) {
    final formKey = GlobalKey<FormState>();
    final declCtrl = TextEditingController(text: '46-ALX-IMP-2026-');
    final containerCtrl = TextEditingController();
    final damageTypeCtrl = TextEditingController();
    final damagedQtyCtrl = TextEditingController(text: '1');
    final lossCtrl = TextEditingController(text: '5000');
    final partyCtrl = TextEditingController();
    final committeeCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String claimStatus = 'CLAIM_SUBMITTED';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.report_problem, color: AppTheme.crimson),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.discrepancyDamageAddDialogTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SelectionArea(
            child: SizedBox(
              width: 560,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: declCtrl,
                              decoration: InputDecoration(
                                labelText: l.discrepancyDamageFieldDeclarationNo,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l.discrepancyDamageCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, declCtrl.text),
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? l.discrepancyDamageValidationRequired : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: containerCtrl,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                labelText: l.discrepancyDamageFieldContainerNo,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l.discrepancyDamageCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, containerCtrl.text),
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? l.discrepancyDamageValidationRequired : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: damageTypeCtrl,
                              decoration: InputDecoration(
                                labelText: l.discrepancyDamageFieldDamageType,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l.discrepancyDamageCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, damageTypeCtrl.text),
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? l.discrepancyDamageValidationRequired : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: damagedQtyCtrl,
                              decoration: InputDecoration(
                                labelText: l.discrepancyDamageFieldDamagedQty,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l.discrepancyDamageCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, damagedQtyCtrl.text),
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? l.discrepancyDamageValidationRequired : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: lossCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: l.discrepancyDamageFieldEstimatedLoss,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l.discrepancyDamageCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, lossCtrl.text),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return l.discrepancyDamageValidationRequired;
                                }
                                final n = double.tryParse(v.trim());
                                if (n == null || n < 0) {
                                  return l.discrepancyDamageValidationPositiveNumber;
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: partyCtrl,
                              decoration: InputDecoration(
                                labelText: l.discrepancyDamageFieldResponsibleParty,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l.discrepancyDamageCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, partyCtrl.text),
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? l.discrepancyDamageValidationRequired : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: claimStatus,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: l.discrepancyDamageColClaimStatus,
                                border: const OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'CLAIM_SUBMITTED',
                                  child: Text(l.discrepancyDamageClaimSubmitted),
                                ),
                                DropdownMenuItem(
                                  value: 'APPROVED',
                                  child: Text(l.discrepancyDamageClaimApproved),
                                ),
                                DropdownMenuItem(
                                  value: 'UNDER_REVIEW',
                                  child: Text(l.discrepancyDamageClaimUnderReview),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => claimStatus = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: committeeCtrl,
                              decoration: InputDecoration(
                                labelText: l.discrepancyDamageFieldCommittee,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l.discrepancyDamageCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, committeeCtrl.text),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: l.discrepancyDamageFieldNotes,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: l.discrepancyDamageCopyFieldTooltip,
                            onPressed: () => CopyHelper.copy(context, notesCtrl.text),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
              icon: const Icon(Icons.check, size: 16),
              label: Text(l.customsClearanceDamageSaveButton),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newProtocol = {
                    'protocol_no': 'DMG-ALX-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                    'declaration_no': declCtrl.text.trim(),
                    'container_no': containerCtrl.text.trim(),
                    'damage_type': damageTypeCtrl.text.trim(),
                    'damaged_qty': damagedQtyCtrl.text.trim(),
                    'estimated_loss_egp': double.tryParse(lossCtrl.text.trim()) ?? 0.0,
                    'responsible_party': partyCtrl.text.trim(),
                    'insurance_claim_status': claimStatus,
                    'committee': committeeCtrl.text.trim(),
                    'date': DateTime.now().toString().substring(0, 10),
                    'notes': notesCtrl.text.trim(),
                  };

                  widget.onAddProtocol?.call(newProtocol);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l.discrepancyDamageSaveSuccess),
                      backgroundColor: AppTheme.emerald,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    ).then((_) {
      declCtrl.dispose();
      containerCtrl.dispose();
      damageTypeCtrl.dispose();
      damagedQtyCtrl.dispose();
      lossCtrl.dispose();
      partyCtrl.dispose();
      committeeCtrl.dispose();
      notesCtrl.dispose();
    });
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
    final submittedClaims = widget.discrepancyProtocols
        .where((p) => p['insurance_claim_status'] == 'CLAIM_SUBMITTED')
        .length;
    final approvedClaims = widget.discrepancyProtocols
        .where((p) => p['insurance_claim_status'] == 'APPROVED')
        .length;

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header Banner Card ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.crimson.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.report_problem_rounded, color: AppTheme.crimson, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.discrepancyDamageScreenTitle,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.charcoal),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l.discrepancyDamageScreenSubtitle,
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  // Action Toolbar (4 Standard Export Actions + New Joint Protocol)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // TSV Export
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal.shade800,
                          side: BorderSide(color: Colors.teal.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: const Icon(Icons.table_chart_outlined, size: 16),
                        label: Text(l.discrepancyDamageExportTsvBtn, style: const TextStyle(fontSize: 12)),
                        onPressed: _isExporting
                            ? null
                            : () async {
                                setState(() => _isExporting = true);
                                try {
                                  await DiscrepancyAndDamageExportService.saveDiscrepanciesTsvToFile(
                                    context,
                                    widget.discrepancyProtocols,
                                  );
                                } finally {
                                  if (mounted) setState(() => _isExporting = false);
                                }
                              },
                      ),
                      // Excel Export
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade800,
                          side: BorderSide(color: Colors.green.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: const Icon(Icons.file_present_outlined, size: 16),
                        label: Text(l.discrepancyDamageExportExcelBtn, style: const TextStyle(fontSize: 12)),
                        onPressed: _isExporting
                            ? null
                            : () async {
                                setState(() => _isExporting = true);
                                try {
                                  await DiscrepancyAndDamageExportService.saveDiscrepanciesCsvToFile(
                                    context,
                                    widget.discrepancyProtocols,
                                  );
                                } finally {
                                  if (mounted) setState(() => _isExporting = false);
                                }
                              },
                      ),
                      // PDF Report
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade800,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                        label: Text(l.discrepancyDamagePrintPdfBtn, style: const TextStyle(fontSize: 12)),
                        onPressed: _isExporting
                            ? null
                            : () async {
                                setState(() => _isExporting = true);
                                try {
                                  await DiscrepancyAndDamageExportService.printOrSaveDiscrepancyPdf(
                                    context,
                                    widget.discrepancyProtocols,
                                  );
                                } finally {
                                  if (mounted) setState(() => _isExporting = false);
                                }
                              },
                      ),
                      // Plain text dossier copy
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.cobalt,
                          side: const BorderSide(color: AppTheme.cobalt),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: const Icon(Icons.copy_all_outlined, size: 16),
                        label: Text(l.discrepancyDamageCopyDossierBtn, style: const TextStyle(fontSize: 12)),
                        onPressed: () => DiscrepancyAndDamageExportService.copyDossierToClipboard(
                          context,
                          widget.discrepancyProtocols,
                        ),
                      ),
                      // New Joint Protocol Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.crimson,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(l.discrepancyDamageAddProtocolBtn),
                        onPressed: () => _showAddProtocolDialog(l),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 4 KPI Summary Cards ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: l.discrepancyDamageKpiTotalProtocols,
                    value: '$totalProtocols',
                    icon: Icons.assignment_outlined,
                    color: AppTheme.charcoal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: l.discrepancyDamageKpiTotalLoss,
                    value: '${totalLoss.toStringAsFixed(2)} ${l.discrepancyDamageCurrencyEgp}',
                    icon: Icons.trending_down_rounded,
                    color: AppTheme.crimson,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: l.discrepancyDamageKpiClaimsSubmitted,
                    value: '$submittedClaims',
                    icon: Icons.pending_actions_rounded,
                    color: AppTheme.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: l.discrepancyDamageKpiClaimsApproved,
                    value: '$approvedClaims',
                    icon: Icons.verified_user_rounded,
                    color: AppTheme.emerald,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Discrepancy & Damage Table Card ──────────────────────────────
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search & Filters Header
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, color: AppTheme.crimson, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l.discrepancyDamageSummaryHeader,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        // Search Field
                        SizedBox(
                          width: 280,
                          child: TextField(
                            controller: _searchController,
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
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Filter Chips
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
                    const Divider(height: 24),

                    // Protocols Data Table
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.inventory_rounded, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                l.discrepancyDamageEmptyRecords,
                                style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                          columns: [
                            DataColumn(label: Text(l.discrepancyDamageColActions, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.discrepancyDamageColProtocolNo, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.discrepancyDamageColDeclarationNo, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.discrepancyDamageColContainerNo, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.discrepancyDamageColDamageType, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.discrepancyDamageColDamagedQty, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.discrepancyDamageColEstimatedLoss, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.discrepancyDamageColResponsibleParty, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.discrepancyDamageColClaimStatus, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.discrepancyDamageColDate, style: const TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: filtered.map((p) {
                            final isApproved = p['insurance_claim_status'] == 'APPROVED';
                            final isUnderReview = p['insurance_claim_status'] == 'UNDER_REVIEW';
                            final claimStr = DiscrepancyAndDamageExportService.getClaimStatusLabel(
                              context,
                              p['insurance_claim_status'] as String?,
                            );
                            final loss = (p['estimated_loss_egp'] as num?)?.toStringAsFixed(2) ?? '0.00';
                            final protoNo = (p['protocol_no'] ?? '').toString();
                            final declNo = (p['declaration_no'] ?? '').toString();
                            final containerNo = (p['container_no'] ?? '').toString();
                            final damageType = (p['damage_type'] ?? '').toString();
                            final damagedQty = (p['damaged_qty'] ?? '').toString();
                            final party = (p['responsible_party'] ?? '').toString();
                            final date = (p['date'] ?? '').toString();
                            final notes = (p['notes'] ?? '-').toString();

                            final rowSummary = "$protoNo\t$declNo\t$containerNo\t$damageType\t$damagedQty\t$loss ${l.discrepancyDamageCurrencyEgp}\t$party\t$claimStr\t$date\t$notes";

                            return DataRow(cells: [
                              // Actions (Quick Row Summary Copy)
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                                      tooltip: l.discrepancyDamageCopyRowSummaryBtn,
                                      onPressed: () => CopyHelper.copy(
                                        context,
                                        rowSummary,
                                        customMessage: l.discrepancyDamageCopyRowSummarySuccess,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Protocol No Badge
                              DataCell(
                                CopyableTableCell(
                                  value: protoNo,
                                  rowSummary: rowSummary,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          protoNo,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.copy, size: 12, color: AppTheme.crimson),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Declaration No Badge
                              DataCell(
                                CopyableTableCell(
                                  value: declNo,
                                  rowSummary: rowSummary,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(declNo, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.copy, size: 11, color: Colors.blueGrey),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Container No Badge
                              DataCell(
                                CopyableTableCell(
                                  value: containerNo,
                                  rowSummary: rowSummary,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          containerNo,
                                          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.copy, size: 11, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Damage Type
                              DataCell(
                                CopyableTableCell(
                                  value: damageType,
                                  rowSummary: rowSummary,
                                  child: Text(damageType, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ),
                              // Damaged Qty
                              DataCell(
                                CopyableTableCell(
                                  value: damagedQty,
                                  rowSummary: rowSummary,
                                  child: Text(damagedQty),
                                ),
                              ),
                              // Estimated Loss
                              DataCell(
                                CopyableTableCell(
                                  value: '$loss ${l.discrepancyDamageCurrencyEgp}',
                                  rowSummary: rowSummary,
                                  child: Text(
                                    '$loss ${l.discrepancyDamageCurrencyEgp}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson),
                                  ),
                                ),
                              ),
                              // Responsible Party
                              DataCell(
                                CopyableTableCell(
                                  value: party,
                                  rowSummary: rowSummary,
                                  child: Text(party),
                                ),
                              ),
                              // Claim Status
                              DataCell(
                                CopyableTableCell(
                                  value: claimStr,
                                  rowSummary: rowSummary,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isApproved
                                          ? Colors.green.shade50
                                          : (isUnderReview ? Colors.amber.shade50 : Colors.blue.shade50),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isApproved
                                            ? Colors.green.shade300
                                            : (isUnderReview ? Colors.amber.shade300 : Colors.blue.shade300),
                                      ),
                                    ),
                                    child: Text(
                                      isApproved
                                          ? '✅ $claimStr'
                                          : (isUnderReview ? '⏳ $claimStr' : '📋 $claimStr'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isApproved
                                            ? Colors.green.shade900
                                            : (isUnderReview ? Colors.amber.shade900 : Colors.blue.shade900),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Date
                              DataCell(
                                CopyableTableCell(
                                  value: date,
                                  rowSummary: rowSummary,
                                  child: Text(date),
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({required String label, required String value}) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selectedColor: AppTheme.crimson.withOpacity(0.15),
      checkmarkColor: AppTheme.crimson,
      onSelected: (_) {
        setState(() => _statusFilter = value);
      },
    );
  }
}
