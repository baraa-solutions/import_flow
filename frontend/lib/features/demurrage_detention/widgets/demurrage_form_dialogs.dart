import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../models/demurrage_model.dart';
import '../providers/demurrage_provider.dart';

/// Static lookup lists shared by the demurrage forms and the simulator.
class DemurrageLookups {
  DemurrageLookups._();

  static const List<String> carriers = [
    'MSC',
    'Maersk',
    'CMA CGM',
    'COSCO',
    'Hapag-Lloyd',
    'ONE',
    'Evergreen',
    'Yang Ming',
  ];

  static const List<String> containerTypes = [
    '20ft Standard',
    '40ft Standard',
    '40ft High Cube',
    '20ft Reefer',
    '40ft Reefer',
    '45ft High Cube',
  ];

  static const List<String> ports = [
    'Alexandria Port',
    'Dekheila Port',
    'Damietta Port',
    'Port Said East',
    'Port Said West',
    'Sokhna Port',
    'Adabiya Port',
    'Cairo Dry Port (6th of October)',
  ];
}

String _fmtDate(DateTime dt) => dt.toIso8601String().split('T').first;

/// Start a new container tracking session.
class AddTrackingDialog extends ConsumerStatefulWidget {
  const AddTrackingDialog({super.key});

  static Future<void> show(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const AddTrackingDialog());

  @override
  ConsumerState<AddTrackingDialog> createState() => _AddTrackingDialogState();
}

class _AddTrackingDialogState extends ConsumerState<AddTrackingDialog> {
  final _formKey = GlobalKey<FormState>();
  String _carrier = DemurrageLookups.carriers.first;
  String _port = DemurrageLookups.ports.first;
  String _cType = DemurrageLookups.containerTypes.first;
  String _blNo = '';
  String _cNo = '';
  DateTime _dischargeDate = DateTime.now().subtract(const Duration(days: 5));
  bool _isSaving = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _isSaving = true);

    final success = await ref.read(demurrageProvider.notifier).createTracking({
      'carrier_name': _carrier,
      'port_name': _port,
      'bill_of_lading_no': _blNo,
      'discharge_date': _fmtDate(_dischargeDate),
      'containers': [
        {'container_no': _cNo, 'container_type': _cType}
      ],
      'currency': 'USD',
      // exchange_rate is resolved by the backend at the discharge date.
    });

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
    return Form(
      key: _formKey,
      child: CcStageDialogShell(
        title: l.addTrackingDialogTitle,
        icon: Icons.add_road_rounded,
        maxWidth: 640,
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
                children: [
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
                        onChanged: (p) => setState(() => _port = p ?? _port),
                      ),
                    ],
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
          ],
        ),
      ),
    );
  }
}

/// Record / correct the gate-out and empty-return dates of a tracking.
class UpdateTrackingDatesDialog extends ConsumerStatefulWidget {
  const UpdateTrackingDatesDialog({super.key, required this.item});

  final DemurrageTrackingModel item;

  static Future<void> show(BuildContext context, DemurrageTrackingModel item) =>
      showDialog<void>(context: context, builder: (_) => UpdateTrackingDatesDialog(item: item));

  @override
  ConsumerState<UpdateTrackingDatesDialog> createState() => _UpdateTrackingDatesDialogState();
}

class _UpdateTrackingDatesDialogState extends ConsumerState<UpdateTrackingDatesDialog> {
  late DateTime? _gateOut;
  late DateTime? _emptyReturn;
  late final DateTime _discharge;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _gateOut = item.gateOutDate != null ? DateTime.tryParse(item.gateOutDate!) : null;
    _emptyReturn = item.emptyReturnDate != null ? DateTime.tryParse(item.emptyReturnDate!) : null;
    _discharge = DateTime.tryParse(item.dischargeDate) ?? DateTime.now();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _isSaving = true);
    final ok = await ref.read(demurrageProvider.notifier).updateTrackingDates(
          widget.item.trackingId,
          gateOutDate: _gateOut != null ? _fmtDate(_gateOut!) : null,
          emptyReturnDate: _emptyReturn != null ? _fmtDate(_emptyReturn!) : null,
        );
    final error = ref.read(demurrageProvider).errorObject;
    if (!mounted) return;
    final snack = AppTheme.snackBar(
      context,
      ok ? l.datesUpdatedAndRecalculatedSuccessSnack : ApiErrorText.of(l, error, fallback: l.datesUpdateErrorSnack),
      severity: ok ? AppSeverity.success : AppSeverity.danger,
    );
    navigator.pop();
    messenger.showSnackBar(snack);
  }

  Future<DateTime?> _pick(DateTime initial, DateTime first) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: DateTime(2030),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final item = widget.item;
    return CcStageDialogShell(
      title: l.updateTrackingDatesDialogTitle(item.trackingCode),
      icon: Icons.edit_calendar_outlined,
      maxWidth: 520,
      chips: [
        CcHeaderChip(Icons.tag, item.trackingCode, ltr: true),
        CcHeaderChip(Icons.directions_boat_outlined, item.carrierName),
      ],
      confirmLabel: l.saveAndRecalculateBtn,
      confirmVariant: AppButtonVariant.primary,
      confirmIcon: Icons.calculate_outlined,
      isSubmitting: _isSaving,
      onConfirm: _submit,
      body: CcFormSection(
        title: l.updateGateOutAndReturnDatesBtn,
        icon: Icons.event_available_outlined,
        child: Column(
          children: [
            CcField(
              label: l.gateOutDateTile,
              child: CcDateTile(
                date: _gateOut,
                placeholder: l.notRecordedOption,
                onTap: () async {
                  final picked = await _pick(_gateOut ?? _discharge, _discharge);
                  if (picked != null) setState(() => _gateOut = picked);
                },
              ),
            ),
            const SizedBox(height: 14),
            CcField(
              label: l.emptyReturnDateTile,
              child: CcDateTile(
                date: _emptyReturn,
                placeholder: l.notRecordedOption,
                onTap: () async {
                  final picked = await _pick(_emptyReturn ?? (_gateOut ?? _discharge), _gateOut ?? _discharge);
                  if (picked != null) setState(() => _emptyReturn = picked);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add a carrier tariff policy.
class AddPolicyDialog extends ConsumerStatefulWidget {
  const AddPolicyDialog({super.key});

  static Future<void> show(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const AddPolicyDialog());

  @override
  ConsumerState<AddPolicyDialog> createState() => _AddPolicyDialogState();
}

class _AddPolicyDialogState extends ConsumerState<AddPolicyDialog> {
  final _formKey = GlobalKey<FormState>();
  String _carrier = DemurrageLookups.carriers.first;
  String _cType = DemurrageLookups.containerTypes.first;
  int _demFree = 14;
  int _detFree = 7;
  int _storFree = 5;
  double? _storRate; // required: no hard-coded storage rate
  bool _isSaving = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _isSaving = true);
    final ok = await ref.read(demurrageProvider.notifier).createPolicy({
      'carrier_name': _carrier,
      'container_type': _cType,
      'demurrage_free_days': _demFree,
      'detention_free_days': _detFree,
      'port_storage_free_days': _storFree,
      'port_storage_daily_rate_egp': _storRate,
      'currency': 'USD',
    });
    final error = ref.read(demurrageProvider).errorObject;
    if (!mounted) return;
    final snack = AppTheme.snackBar(
      context,
      ok ? l.policyCreatedSuccessSnack : ApiErrorText.of(l, error, fallback: l.genericErrorSnack),
      severity: ok ? AppSeverity.success : AppSeverity.danger,
    );
    navigator.pop();
    messenger.showSnackBar(snack);
  }

  Widget _daysField(String label, int initial, ValueChanged<int> onSaved, int fallback, AppLocalizations l) {
    return CcField(
      label: label,
      child: TextFormField(
        initialValue: initial.toString(),
        decoration: ccInputDecoration(suffixText: l.whatIfDaysUnit),
        keyboardType: TextInputType.number,
        onSaved: (v) => onSaved(int.tryParse(v ?? '') ?? fallback),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Form(
      key: _formKey,
      child: CcStageDialogShell(
        title: l.addPolicyDialogTitle,
        icon: Icons.policy_outlined,
        maxWidth: 640,
        confirmLabel: l.savePolicyBtn,
        confirmVariant: AppButtonVariant.primary,
        confirmIcon: Icons.save_outlined,
        isSubmitting: _isSaving,
        onConfirm: _submit,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CcFormSection(
              title: l.addPolicyDialogTitle,
              icon: Icons.rule_folder_outlined,
              child: Column(
                children: [
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
                  CcFieldRow(
                    children: [
                      _daysField(l.demurrageFreeDaysFieldLabel, _demFree, (v) => _demFree = v, 14, l),
                      _daysField(l.detentionFreeDaysFieldLabel, _detFree, (v) => _detFree = v, 7, l),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CcFieldRow(
                    children: [
                      _daysField(l.portStorageFreeDaysFieldLabel, _storFree, (v) => _storFree = v, 5, l),
                      CcField(
                        label: l.dailyStorageRateEgpFieldLabel,
                        isRequired: true,
                        child: TextFormField(
                          decoration: ccInputDecoration(suffixText: l.egpCurrency),
                          keyboardType: TextInputType.number,
                          validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? l.requiredFieldValidation : null,
                          onSaved: (v) => _storRate = double.tryParse(v ?? ''),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
