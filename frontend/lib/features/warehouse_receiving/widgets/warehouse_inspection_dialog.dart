import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../models/warehouse_receiving_model.dart';
import '../providers/warehouse_receiving_provider.dart';
import 'ops_ui_kit.dart';

/// Inspection verdict codes accepted by the backend (`WAREHOUSE_INSPECTION_VERDICT`).
class InspectionVerdict {
  InspectionVerdict._();
  static const acceptedFull = 'ACCEPTED_FULL';
  static const acceptedWithDiscrepancy = 'ACCEPTED_WITH_DISCREPANCY';
  static const rejectedQuarantined = 'REJECTED_QUARANTINED';

  /// Full acceptance contradicts a recorded shortage or damage (plan WR-03 / FE-05).
  static bool isFullAcceptanceAllowed({required int shortageQty, required int damagedQty}) =>
      shortageQty + damagedQty == 0;

  /// The verdict to preselect: the saved one when still consistent, otherwise the one
  /// implied by the real quantities.
  static String initial({
    required String? saved,
    required int shortageQty,
    required int damagedQty,
  }) {
    final fullAllowed = isFullAcceptanceAllowed(shortageQty: shortageQty, damagedQty: damagedQty);
    if (saved != null && saved != 'PENDING' && (saved != acceptedFull || fullAllowed)) return saved;
    return fullAllowed ? acceptedFull : acceptedWithDiscrepancy;
  }
}

class WarehouseInspectionDialog extends ConsumerStatefulWidget {
  final WarehouseReceivingModel record;
  final String? importFileCode;

  const WarehouseInspectionDialog({
    super.key,
    required this.record,
    this.importFileCode,
  });

  static Future<void> show(
    BuildContext context, {
    required WarehouseReceivingModel record,
    String? importFileCode,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WarehouseInspectionDialog(
        record: record,
        importFileCode: importFileCode,
      ),
    );
  }

  @override
  ConsumerState<WarehouseInspectionDialog> createState() => _WarehouseInspectionDialogState();
}

class _WarehouseInspectionDialogState extends ConsumerState<WarehouseInspectionDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _committeeCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _insuranceRefCtrl;
  late TextEditingController _supplierRefCtrl;
  late TextEditingController _claimAmountCtrl;

  late String _selectedVerdict;
  String? _selectedRootCause;
  late String _claimCurrency;
  late bool _quarantineAssigned;
  late bool _insuranceClaimFiled;
  late bool _supplierClaimFiled;
  bool _isLoading = false;

  bool get _fullAllowed => InspectionVerdict.isFullAcceptanceAllowed(
        shortageQty: widget.record.totalShortageQty,
        damagedQty: widget.record.totalDamagedQty,
      );

  @override
  void initState() {
    super.initState();
    final rec = widget.record;
    final hasDiscrepancy = (rec.totalShortageQty + rec.totalDamagedQty) > 0;

    // Nothing is invented: the committee and notes start from what is saved, and the
    // server fills the standard committee when it is left empty.
    _committeeCtrl = TextEditingController(text: rec.inspectionCommittee ?? '');
    _notesCtrl = TextEditingController(text: rec.discrepancyNotes ?? '');
    _insuranceRefCtrl = TextEditingController(text: rec.insuranceClaimRef ?? '');
    _supplierRefCtrl = TextEditingController(text: rec.supplierClaimRef ?? '');
    _claimAmountCtrl = TextEditingController(
      text: (rec.claimAmountEstimated ?? 0) > 0 ? rec.claimAmountEstimated!.toStringAsFixed(0) : '',
    );

    _selectedVerdict = InspectionVerdict.initial(
      saved: rec.inspectionVerdict,
      shortageQty: rec.totalShortageQty,
      damagedQty: rec.totalDamagedQty,
    );

    _selectedRootCause = rec.rootCause ?? (hasDiscrepancy ? null : 'None - Clean Delivery');
    _claimCurrency = rec.claimCurrency;
    _quarantineAssigned = rec.quarantineZoneAssigned;
    _insuranceClaimFiled = rec.insuranceClaimFiled;
    _supplierClaimFiled = rec.supplierClaimFiled;

    Future.microtask(() {
      if (mounted) ref.read(currenciesProvider.notifier).fetchCurrencies(includeInactive: false);
    });
  }

  @override
  void dispose() {
    _committeeCtrl.dispose();
    _notesCtrl.dispose();
    _insuranceRefCtrl.dispose();
    _supplierRefCtrl.dispose();
    _claimAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportInspectionReport() async {
    final l10n = context.l10n;
    final rec = widget.record;
    final headers = [
      l10n.wrItemCodeLabel,
      l10n.wrColItemName,
      l10n.warehouseReceivingColInvoicedQty,
      l10n.warehouseReceivingColAcceptedQty,
      l10n.warehouseReceivingColShortageQty,
      l10n.warehouseReceivingColDamagedQty,
      l10n.warehouseReceivingColStatus,
    ];

    final rows = rec.grnItems.map((item) {
      final status = (item.shortageQty > 0 || item.damagedQty > 0) ? l10n.wrLineStatusDiscrepancy : l10n.wrLineStatusClean;
      return [
        item.itemCode,
        item.itemName,
        item.invoicedQty.toString(),
        item.acceptedQty.toString(),
        item.shortageQty.toString(),
        item.damagedQty.toString(),
        status,
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      stageName: 'Warehouse Inspection Protocol',
      importFileNameOrCode: widget.importFileCode ?? rec.grnCode,
      headers: headers,
      rows: rows,
    );
  }

  Future<void> _submitProtocol() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      final claimAmountRaw = double.tryParse(_claimAmountCtrl.text.trim());
      final claimAmount = (claimAmountRaw != null && claimAmountRaw > 0) ? claimAmountRaw : null;
      final committee = _committeeCtrl.text.trim();
      // The server derives the discrepancy type; the verdict is the user's decision.
      final payload = {
        'inspection_date': DateTime.now().toIso8601String(),
        if (committee.isNotEmpty) 'inspection_committee': committee,
        'inspection_verdict': _selectedVerdict,
        'root_cause': _selectedRootCause,
        'discrepancy_notes': _notesCtrl.text.trim(),
        'quarantine_zone_assigned': _quarantineAssigned,
        'insurance_claim_filed': _insuranceClaimFiled,
        'insurance_claim_ref': _insuranceClaimFiled ? _insuranceRefCtrl.text.trim() : null,
        'supplier_claim_filed': _supplierClaimFiled,
        'supplier_claim_ref': _supplierClaimFiled ? _supplierRefCtrl.text.trim() : null,
        'claim_amount_estimated': claimAmount,
        'claim_currency': (claimAmount != null && _claimCurrency.isNotEmpty) ? _claimCurrency : null,
      };

      await ref.read(warehouseReceivingProvider.notifier).submitInspectionProtocol(
            widget.record.receivingId,
            payload,
          );

      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.wrInspSuccess(widget.record.grnCode)),
          backgroundColor: AppTheme.emerald,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(ApiErrorText.of(l10n, e)),
          backgroundColor: AppTheme.crimson,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppTheme.isDark(context);
    final rec = widget.record;
    final totalDiscrepancy = rec.totalShortageQty + rec.totalDamagedQty;
    final discrepancyRate = rec.totalInvoicedQty > 0
        ? (totalDiscrepancy / rec.totalInvoicedQty * 100).toStringAsFixed(1)
        : '0.0';
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];
    final fileLabel = widget.importFileCode ?? 'IMP-FILE-${rec.importFileId}';

    return AlertDialog(
      titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.verified_user_rounded, color: AppTheme.cobalt, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.wrInspTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  l10n.wrInspSubtitle(rec.grnCode, fileLabel),
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                ),
              ],
            ),
          ),
          AppButton(
            key: const Key('exportInspectionProtocolBtn'),
            label: l10n.wrInspExportBtn,
            icon: Icons.file_download_outlined,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.small,
            onPressed: _exportInspectionReport,
          ),
        ],
      ),
      content: SizedBox(
        width: (MediaQuery.of(context).size.width - 48).clamp(360.0, 860.0),
        height: (MediaQuery.of(context).size.height * 0.7).clamp(360.0, 560.0),
        child: SelectionArea(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetricStrip(l10n, isDark, rec, totalDiscrepancy, discrepancyRate),
                  const SizedBox(height: 16),
                  if (rec.grnItems.isNotEmpty) ...[
                    _buildItemsTable(l10n, isDark, rec),
                    const SizedBox(height: 16),
                  ],
                  _buildVerdictRow(l10n),
                  const SizedBox(height: 12),
                  _buildRootCauseRow(l10n),
                  const SizedBox(height: 14),
                  _buildClaimsPanel(l10n, isDark, currencies.map((c) => c.currencyCode).toList()),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        AppButton(
          label: l10n.cancel,
          variant: AppButtonVariant.secondary,
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        AppButton(
          key: const Key('certifyInspectionProtocolBtn'),
          label: l10n.wrInspCertifyBtn,
          icon: Icons.verified,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _submitProtocol,
        ),
      ],
    );
  }

  Widget _buildMetricStrip(AppLocalizations l10n, bool isDark, WarehouseReceivingModel rec, int totalDiscrepancy, String rate) {
    return Container(
      key: const Key('inspectionMetricStrip'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        children: [
          _buildMetricTile(l10n.warehouseReceivingMetricInvoiced, '${rec.totalInvoicedQty}', AppTheme.charcoal),
          _buildMetricTile(l10n.warehouseReceivingMetricAccepted, '${rec.totalAcceptedQty}', AppTheme.emerald),
          _buildMetricTile(l10n.warehouseReceivingMetricShortage, '${rec.totalShortageQty}',
              totalDiscrepancy > 0 ? AppTheme.orange : AppTheme.charcoal),
          _buildMetricTile(l10n.warehouseReceivingMetricDamaged, '${rec.totalDamagedQty}',
              rec.totalDamagedQty > 0 ? AppTheme.crimson : AppTheme.charcoal),
          _buildMetricTile(l10n.wrInspMetricRate, '$rate%', totalDiscrepancy > 0 ? AppTheme.crimson : AppTheme.emerald),
        ],
      ),
    );
  }

  Widget _buildItemsTable(AppLocalizations l10n, bool isDark, WarehouseReceivingModel rec) {
    const headStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.bold);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.wrInspItemsHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderOf(context)),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          constraints: const BoxConstraints(maxHeight: 140),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 34,
              headingRowColor: OpsTableStyle.headingColor(context),
              columnSpacing: 18,
              columns: [
                DataColumn(label: Text(l10n.wrItemCodeLabel, style: headStyle)),
                DataColumn(label: Text(l10n.wrColItemName, style: headStyle)),
                DataColumn(label: Text(l10n.wrColInvoiced, style: headStyle), numeric: true),
                DataColumn(label: Text(l10n.wrColAccepted, style: headStyle), numeric: true),
                DataColumn(label: Text(l10n.wrColShortage, style: headStyle), numeric: true),
                DataColumn(label: Text(l10n.wrColDamaged, style: headStyle), numeric: true),
              ],
              rows: rec.grnItems.map((item) {
                return DataRow(cells: [
                  DataCell(LtrText(item.itemCode, style: const TextStyle(fontSize: 11))),
                  DataCell(Text(item.itemName, style: const TextStyle(fontSize: 11))),
                  DataCell(Text('${item.invoicedQty}', style: const TextStyle(fontSize: 11))),
                  DataCell(Text('${item.acceptedQty}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald))),
                  DataCell(Text('${item.shortageQty}',
                      style: TextStyle(fontSize: 11, color: item.shortageQty > 0 ? AppTheme.orange : null))),
                  DataCell(Text('${item.damagedQty}',
                      style: TextStyle(fontSize: 11, color: item.damagedQty > 0 ? AppTheme.crimson : null))),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerdictRow(AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: _committeeCtrl,
            decoration: InputDecoration(
              labelText: l10n.wrInspCommitteeLabel,
              helperText: l10n.wrInspCommitteeHint,
              prefixIcon: const Icon(Icons.people_alt_outlined, size: 18),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SearchableDropdownField<String>(
            key: const Key('inspectionVerdictField'),
            value: _selectedVerdict,
            labelText: l10n.wrInspVerdictLabel,
            decoration: InputDecoration(
              labelText: l10n.wrInspVerdictLabel,
              helperText: _fullAllowed ? null : l10n.wrInspFullBlockedHint,
              isDense: true,
            ),
            items: [
              // FE-05: full acceptance is not offered while shortage or damage is recorded.
              if (_fullAllowed)
                SearchableDropdownItem(value: InspectionVerdict.acceptedFull, label: l10n.wrInspVerdictFull),
              SearchableDropdownItem(value: InspectionVerdict.acceptedWithDiscrepancy, label: l10n.wrInspVerdictDiscrepancy),
              SearchableDropdownItem(value: InspectionVerdict.rejectedQuarantined, label: l10n.wrInspVerdictRejected),
            ],
            validator: (v) => (v == null || v.isEmpty) ? l10n.wrInspVerdictRequired : null,
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _selectedVerdict = v;
                  if (v == InspectionVerdict.rejectedQuarantined) {
                    _quarantineAssigned = true;
                  }
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRootCauseRow(AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: SearchableDropdownField<String>(
            value: _selectedRootCause,
            labelText: l10n.wrInspRootCauseLabel,
            items: [
              SearchableDropdownItem(value: 'None - Clean Delivery', label: l10n.wrRootCauseNone),
              SearchableDropdownItem(value: 'Port Handling & Rough Unloading', label: l10n.wrRootCausePort),
              SearchableDropdownItem(value: 'Inland Transit Vibration & Shock', label: l10n.wrRootCauseInland),
              SearchableDropdownItem(value: 'Supplier Packaging Defect', label: l10n.wrRootCausePackaging),
              SearchableDropdownItem(value: 'Container Water Ingress & Humidity', label: l10n.wrRootCauseWater),
              SearchableDropdownItem(value: 'Supplier Factory Shortage', label: l10n.wrRootCauseFactory),
              SearchableDropdownItem(value: 'Other / Under Investigation', label: l10n.wrRootCauseOther),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _selectedRootCause = v);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n.wrInspNotesLabel,
              border: const OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? l10n.wrInspNotesRequired : null,
          ),
        ),
      ],
    );
  }

  Widget _buildClaimsPanel(AppLocalizations l10n, bool isDark, List<String> currencyCodes) {
    final codes = {...currencyCodes, if (_claimCurrency.isNotEmpty) _claimCurrency}.toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : AppTheme.orange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.orange.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 18, color: AppTheme.orange),
              const SizedBox(width: 6),
              Text(
                l10n.wrInspClaimsHeader,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.orange),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    title: Text(l10n.wrInspInsuranceClaim, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    value: _insuranceClaimFiled,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _insuranceClaimFiled = v ?? false),
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    title: Text(l10n.wrInspSupplierCredit, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    value: _supplierClaimFiled,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _supplierClaimFiled = v ?? false),
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    title: Text(l10n.wrInspQuarantine, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    value: _quarantineAssigned,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _quarantineAssigned = v),
                  ),
                ),
              ),
            ],
          ),
          if (_insuranceClaimFiled || _supplierClaimFiled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (_insuranceClaimFiled) ...[
                  Expanded(
                    child: TextFormField(
                      controller: _insuranceRefCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.wrInspInsuranceRef,
                        prefixIcon: const Icon(Icons.tag, size: 16),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_supplierClaimFiled) ...[
                  Expanded(
                    child: TextFormField(
                      controller: _supplierRefCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.wrInspSupplierRef,
                        prefixIcon: const Icon(Icons.receipt_long, size: 16),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _claimAmountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: l10n.wrInspClaimAmount,
                            prefixIcon: const Icon(Icons.attach_money, size: 16),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return null;
                            final n = double.tryParse(t);
                            return (n == null || n < 0) ? l10n.wrQtyInvalid : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: SearchableDropdownField<String>(
                          key: const Key('inspectionClaimCurrencyField'),
                          value: _claimCurrency,
                          labelText: l10n.wrInspClaimCurrency,
                          searchHintText: l10n.wrInspCurrencySearch,
                          items: codes.map((c) => SearchableDropdownItem(value: c, label: c)).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _claimCurrency = v);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context))),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}
