import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../models/warehouse_receiving_model.dart';
import '../providers/warehouse_receiving_provider.dart';

/// Discrepancy & damage report for a GRN (shortage / damage / broken seal).
class GrnDiscrepancyReportDialog extends ConsumerStatefulWidget {
  final WarehouseReceivingModel record;
  const GrnDiscrepancyReportDialog({super.key, required this.record});

  @override
  ConsumerState<GrnDiscrepancyReportDialog> createState() =>
      _GrnDiscrepancyReportDialogState();
}

class _GrnDiscrepancyReportDialogState
    extends ConsumerState<GrnDiscrepancyReportDialog> {
  final _formKey = GlobalKey<FormState>();
  String _selectedDiscrepancyType = 'Shortage and Damage';
  late TextEditingController _notesCtrl;
  bool _quarantineAssigned = false;
  bool _fileClaim = false;
  late TextEditingController _claimRefCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl =
        TextEditingController(text: widget.record.discrepancyNotes ?? '');
    _claimRefCtrl =
        TextEditingController(text: widget.record.insuranceClaimRef ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _claimRefCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final successBar = AppTheme.snackBar(
      context,
      l10n.warehouseReceivingDiscrepancySuccessSnack,
      severity: AppSeverity.success,
    );
    try {
      final payload = {
        'discrepancy_type': _selectedDiscrepancyType,
        'discrepancy_notes': _notesCtrl.text.trim(),
        'quarantine_zone_assigned': _quarantineAssigned,
        'insurance_claim_filed': _fileClaim,
        'insurance_claim_ref': _fileClaim ? _claimRefCtrl.text.trim() : null,
      };

      await ref
          .read(warehouseReceivingProvider.notifier)
          .reportDiscrepancy(widget.record.receivingId, payload);
      nav.pop();
      messenger.showSnackBar(successBar);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(AppTheme.snackBar(
          context, ApiErrorText.of(l10n, e),
          severity: AppSeverity.danger));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dialogWidth =
        (MediaQuery.of(context).size.width - 32).clamp(320.0, 560.0);
    return AlertDialog(
      titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsetsDirectional.all(8),
            decoration: BoxDecoration(
              color:
                  AppTheme.severityBackgroundOf(context, AppSeverity.warning),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded,
                color: AppTheme.severityForegroundOf(
                    context, AppSeverity.warning)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              l.warehouseReceivingDiscrepancyDialogTitle(widget.record.grnCode),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SelectionArea(
        child: SizedBox(
          width: dialogWidth,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SearchableDropdownField<String>(
                    value: _selectedDiscrepancyType,
                    labelText: l.warehouseReceivingDiscrepancyTypeLabel,
                    items: [
                      SearchableDropdownItem(
                          value: 'Shortage and Damage',
                          label: l
                              .warehouseReceivingDiscrepancyTypeShortageAndDamage),
                      SearchableDropdownItem(
                          value: 'Shortage Only',
                          label:
                              l.warehouseReceivingDiscrepancyTypeShortageOnly),
                      SearchableDropdownItem(
                          value: 'Damage Only',
                          label: l.warehouseReceivingDiscrepancyTypeDamageOnly),
                      SearchableDropdownItem(
                          value: 'Broken Seal Discrepancy',
                          label: l.warehouseReceivingDiscrepancyTypeBrokenSeal),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedDiscrepancyType = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                        labelText: l.warehouseReceivingDiscrepancyNotesLabel,
                        border: const OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l.warehouseReceivingDiscrepancyNotesValidator
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAltOf(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.borderOf(context)),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        children: [
                          SwitchListTile(
                            dense: true,
                            title: Text(l.warehouseReceivingQuarantineSwitch,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700)),
                            value: _quarantineAssigned,
                            onChanged: (val) =>
                                setState(() => _quarantineAssigned = val),
                          ),
                          Divider(height: 1, color: AppTheme.borderOf(context)),
                          SwitchListTile(
                            dense: true,
                            title: Text(
                                l.warehouseReceivingInsuranceClaimSwitch,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700)),
                            value: _fileClaim,
                            onChanged: (val) =>
                                setState(() => _fileClaim = val),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_fileClaim) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _claimRefCtrl,
                      validator: (v) =>
                          (_fileClaim && (v == null || v.trim().isEmpty))
                              ? l.wrClaimRefRequired
                              : null,
                      decoration: InputDecoration(
                        labelText: l.warehouseReceivingClaimRefLabel,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l.warehouseReceivingCopyFieldTooltip,
                          onPressed: () =>
                              CopyHelper.copy(context, _claimRefCtrl.text),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 16),
      actions: [
        AppButton(
          label: l.cancel,
          variant: AppButtonVariant.secondary,
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        AppButton(
          label: l.warehouseReceivingCertifyDiscrepancyBtn,
          variant: AppButtonVariant.danger,
          icon: Icons.report_gmailerrorred_outlined,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _submit,
        ),
      ],
    );
  }
}
