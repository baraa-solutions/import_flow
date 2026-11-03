import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../providers/demurrage_provider.dart';
import 'ancillary_fees_section.dart';
import 'demurrage_lookups.dart';

/// Start a new container tracking session.
class AddTrackingDialog extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  const AddTrackingDialog({super.key, this.initialImportFileId});

  static Future<void> show(BuildContext context, {int? initialImportFileId}) =>
      showDialog<void>(context: context, builder: (_) => AddTrackingDialog(initialImportFileId: initialImportFileId));

  @override
  ConsumerState<AddTrackingDialog> createState() => _AddTrackingDialogState();
}

class _AddTrackingDialogState extends ConsumerState<AddTrackingDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedImportFileId;
  String _carrier = DemurrageLookups.carriers.first;
  String _port = DemurrageLookups.ports.first;
  String? _terminal;
  String _cType = DemurrageLookups.containerTypes.first;
  String _blNo = '';
  String _cNo = '';
  DateTime _dischargeDate = DateTime.now().subtract(const Duration(days: 5));
  bool _isSaving = false;
  final List<Map<String, dynamic>> _ancillaryFees = [];

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    final terms = DemurrageLookups.terminalsByPort[_port] ?? [];
    if (terms.isNotEmpty) {
      _terminal = terms.first;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_selectedImportFileId == null) {
      messenger.showSnackBar(
        AppTheme.snackBar(
          context,
          l.pleaseSelectImportFileError,
          severity: AppSeverity.warning,
        ),
      );
      return;
    }

    _formKey.currentState!.save();
    setState(() => _isSaving = true);

    final payload = {
      'import_file_id': _selectedImportFileId!,
      'carrier_name': _carrier,
      'port_name': _port,
      if (_terminal != null && _terminal!.isNotEmpty) 'terminal_name': _terminal,
      'bill_of_lading_no': _blNo,
      'discharge_date': fmtDemurrageDate(_dischargeDate),
      'containers': [
        {'container_no': _cNo, 'container_type': _cType}
      ],
      if (_ancillaryFees.isNotEmpty) 'ancillary_fees': _ancillaryFees,
      // exchange_rate is resolved by the backend at the discharge date.
    };

    final success = await ref.read(demurrageProvider.notifier).createTracking(payload);

    final error = ref.read(demurrageProvider).errorObject;
    if (!mounted) return;
    final snack = AppTheme.snackBar(
      context,
      success ? l.trackingCreatedSuccessSnack : ApiErrorText.of(l, error, fallback: l.saveTrackingErrorSnack),
      severity: success ? AppSeverity.success : AppSeverity.danger,
    );
    navigator.pop();
    messenger.showSnackBar(snack);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final terminals = DemurrageLookups.terminalsByPort[_port] ?? [];

    return SelectionArea(
      child: Form(
        key: _formKey,
        child: CcStageDialogShell(
          title: l.addTrackingDialogTitle,
          icon: Icons.add_road_rounded,
          maxWidth: 680,
          confirmLabel: l.saveAndStartTrackingBtn,
          confirmVariant: AppButtonVariant.primary,
          confirmIcon: Icons.play_circle_outline,
          isSubmitting: _isSaving,
          onConfirm: _submit,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CcFormSection(
                title: l.addTrackingDialogTitle,
                icon: Icons.directions_boat_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Mandatory Import File selection (FE05-T01)
                    CcField(
                      label: l.importFileLabel,
                      isRequired: true,
                      child: SearchableDropdownField<int>(
                        hintText: l.selectImportFilePrompt,
                        value: _selectedImportFileId,
                        items: importFiles
                            .map((f) => SearchableDropdownItem(
                                  value: f.importFileId,
                                  label: '${f.importFileCode} - ${f.companyName}',
                                ))
                            .toList(),
                        onChanged: (id) => setState(() => _selectedImportFileId = id),
                        validator: (id) => id == null ? l.pleaseSelectImportFileError : null,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Carrier & Port & Terminal Selection
                    CcFieldRow(
                      children: [
                        SearchableDropdownField<String>(
                          labelText: l.shippingLineFieldLabel,
                          value: _carrier,
                          items: DemurrageLookups.carriers
                              .map((c) => SearchableDropdownItem(value: c, label: c))
                              .toList(),
                          onChanged: (c) => setState(() => _carrier = c ?? _carrier),
                        ),
                        SearchableDropdownField<String>(
                          labelText: l.arrivalPortFieldLabel,
                          value: _port,
                          items: DemurrageLookups.ports
                              .map((p) => SearchableDropdownItem(value: p, label: p))
                              .toList(),
                          onChanged: (p) {
                            if (p != null) {
                              setState(() {
                                _port = p;
                                final terms = DemurrageLookups.terminalsByPort[p] ?? [];
                                _terminal = terms.isNotEmpty ? terms.first : null;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Terminal selection
                    SearchableDropdownField<String>(
                      labelText: 'محطة الحاويات',
                      value: _terminal,
                      items: terminals
                          .map((t) => SearchableDropdownItem(value: t, label: t))
                          .toList(),
                      onChanged: (t) => setState(() => _terminal = t),
                    ),
                    const SizedBox(height: 14),

                    CcField(
                      label: l.blNumberFieldLabel,
                      isRequired: true,
                      child: TextFormField(
                        decoration: ccInputDecoration(prefix: Icons.description_outlined),
                        validator: (v) => (v == null || v.trim().isEmpty) ? l.requiredFieldValidation : null,
                        onSaved: (v) => _blNo = v ?? '',
                      ),
                    ),
                    const SizedBox(height: 14),
                    CcFieldRow(
                      children: [
                        CcField(
                          label: l.containerNumberFieldLabel,
                          isRequired: true,
                          child: TextFormField(
                            decoration: ccInputDecoration(prefix: Icons.inventory_2_outlined),
                            validator: (v) => (v == null || v.trim().isEmpty) ? l.requiredFieldValidation : null,
                            onSaved: (v) => _cNo = v ?? '',
                          ),
                        ),
                        SearchableDropdownField<String>(
                          labelText: l.containerTypeFieldLabel,
                          value: _cType,
                          items: DemurrageLookups.containerTypes
                              .map((t) => SearchableDropdownItem(value: t, label: t))
                              .toList(),
                          onChanged: (t) => setState(() => _cType = t ?? _cType),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    CcField(
                      label: l.portDischargeDateTile,
                      child: CcDateTile(
                        date: _dischargeDate,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dischargeDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => _dischargeDate = picked);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Ancillary Terminal Fees Section (الرسوم الإضافية بالمحطة)
              AncillaryFeesSection(
                fees: _ancillaryFees,
                onFeesChanged: () => setState(() {}),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
