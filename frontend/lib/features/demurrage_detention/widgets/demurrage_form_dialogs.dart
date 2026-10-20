import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/demurrage_model.dart';
import '../providers/demurrage_provider.dart';
import '../../currencies/providers/currencies_provider.dart';

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

  static const Map<String, List<String>> terminalsByPort = {
    'Alexandria Port': [
      'Alexandria Container Terminal (ACCHCO)',
      'Alexandria Old Terminal',
      'Tahya Misr Multipurpose Terminal',
    ],
    'Dekheila Port': [
      'Dekheila Container Terminal (ACCHCO)',
      'Dekheila Berth 96 Terminal',
    ],
    'Damietta Port': [
      'Damietta Container Handling (DCHC)',
      'Damietta Alliance Terminal',
    ],
    'Port Said East': [
      'Suez Canal Container Terminal (SCCT - APMT)',
    ],
    'Port Said West': [
      'Port Said Container Handling (PSCCHC)',
    ],
    'Sokhna Port': [
      'DP World Sokhna Terminal',
      'Basin 2 Container Terminal',
    ],
    'Adabiya Port': [
      'Adabiya Port Terminal',
    ],
    'Cairo Dry Port (6th of October)': [
      'October Dry Port (ODP)',
    ],
  };

  static const List<String> ancillaryFeeTypes = [
    'كشف وفحص بالأشعة (X-Ray Inspection)',
    'وزن ميزان بسكول (Weighing & Scales)',
    'سيل جمركي ملاحي (Customs/Carrier Seal)',
    'حراسة ومراقبة ساحة (Yard Guarding)',
    'تطهير وتبخير (Fumigation & Cleaning)',
    'أذونات ونولون إضافي (Ancillary Clearance Permit)',
  ];
}

String _fmtDate(DateTime dt) => dt.toIso8601String().split('T').first;

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
  final TextEditingController _customFeeNameController = TextEditingController();
  final TextEditingController _customFeeAmountController = TextEditingController();
  String _customFeeCurrency = 'USD';

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    final terms = DemurrageLookups.terminalsByPort[_port] ?? [];
    if (terms.isNotEmpty) {
      _terminal = terms.first;
    }
  }

  @override
  void dispose() {
    _customFeeNameController.dispose();
    _customFeeAmountController.dispose();
    super.dispose();
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
      'discharge_date': _fmtDate(_dischargeDate),
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

    return Form(
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
                    labelText: 'محطة الحاويات (Terminal / Depot)',
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
            CcFormSection(
              title: 'الرسوم الإضافية بالمحطة (Ancillary Fees)',
              icon: Icons.receipt_long_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: SearchableDropdownField<String>(
                          labelText: 'نوع الرسم الإضافي',
                          value: _customFeeNameController.text.isNotEmpty ? _customFeeNameController.text : null,
                          items: DemurrageLookups.ancillaryFeeTypes
                              .map((f) => SearchableDropdownItem(value: f, label: f))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _customFeeNameController.text = v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _customFeeAmountController,
                          decoration: ccInputDecoration(
                            prefix: Icons.attach_money_rounded,
                            hint: 'المبلغ',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 90,
                        child: SearchableDropdownField<String>(
                          labelText: 'العملة',
                          value: _customFeeCurrency,
                          items: const [
                            SearchableDropdownItem(value: 'USD', label: 'USD'),
                            SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                          ],
                          onChanged: (c) {
                            if (c != null) setState(() => _customFeeCurrency = c);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: AppButton(
                          label: 'إضافة',
                          icon: Icons.add,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.small,
                          onPressed: () {
                            final name = _customFeeNameController.text.trim();
                            final amt = double.tryParse(_customFeeAmountController.text.trim());
                            if (name.isNotEmpty && amt != null && amt > 0) {
                              setState(() {
                                _ancillaryFees.add({
                                  'fee_name': name,
                                  'fee_amount': amt,
                                  'currency': _customFeeCurrency,
                                });
                                _customFeeNameController.clear();
                                _customFeeAmountController.clear();
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_ancillaryFees.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _ancillaryFees.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final fee = entry.value;
                        return Chip(
                          backgroundColor: AppTheme.cobalt.withValues(alpha: 0.08),
                          label: Text(
                            '${fee['fee_name']}: ${fee['fee_amount']} ${fee['currency']}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() => _ancillaryFees.removeAt(idx)),
                        );
                      }).toList(),
                    ),
                  ],
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
  late List<Map<String, dynamic>> _ancillaryFees;
  final TextEditingController _customFeeNameController = TextEditingController();
  final TextEditingController _customFeeAmountController = TextEditingController();
  String _customFeeCurrency = 'USD';

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _gateOut = item.gateOutDate != null ? DateTime.tryParse(item.gateOutDate!) : null;
    _emptyReturn = item.emptyReturnDate != null ? DateTime.tryParse(item.emptyReturnDate!) : null;
    _discharge = DateTime.tryParse(item.dischargeDate) ?? DateTime.now();
    _ancillaryFees = item.ancillaryFees
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  void dispose() {
    _customFeeNameController.dispose();
    _customFeeAmountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_emptyReturn != null && _gateOut == null) {
      messenger.showSnackBar(
        AppTheme.snackBar(
          context,
          'لا يمكن تسجيل إعادة الحاوية الفارغة بدون تاريخ خروجها من الميناء (Gate-Out).',
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final ok = await ref.read(demurrageProvider.notifier).updateTrackingDates(
          widget.item.trackingId,
          gateOutDate: _gateOut != null ? _fmtDate(_gateOut!) : null,
          emptyReturnDate: _emptyReturn != null ? _fmtDate(_emptyReturn!) : null,
          ancillaryFees: _ancillaryFees,
        );
    final error = ref.read(demurrageProvider).errorObject;
    if (!mounted) return;
    final snack = AppTheme.snackBar(
      context,
      ok ? l.datesUpdatedAndRecalculatedSuccessSnack : ApiErrorText.of(l, error, fallback: l.datesUpdateErrorSnack),
      severity: ok ? AppSeverity.success : AppSeverity.danger,
    );
    if (ok) {
      navigator.pop();
    } else {
      setState(() => _isSaving = false);
    }
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
      maxWidth: 620,
      chips: [
        CcHeaderChip(Icons.tag, item.trackingCode, ltr: true),
        CcHeaderChip(Icons.directions_boat_outlined, item.carrierName),
      ],
      confirmLabel: l.saveAndRecalculateBtn,
      confirmVariant: AppButtonVariant.primary,
      confirmIcon: Icons.calculate_outlined,
      isSubmitting: _isSaving,
      onConfirm: _submit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CcFormSection(
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
          const SizedBox(height: 16),
          CcFormSection(
            title: 'الرسوم الإضافية بالمحطة (Ancillary Fees)',
            icon: Icons.receipt_long_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SearchableDropdownField<String>(
                        labelText: 'نوع الرسم الإضافي',
                        value: _customFeeNameController.text.isNotEmpty ? _customFeeNameController.text : null,
                        items: DemurrageLookups.ancillaryFeeTypes
                            .map((f) => SearchableDropdownItem(value: f, label: f))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _customFeeNameController.text = v);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _customFeeAmountController,
                        decoration: ccInputDecoration(
                          prefix: Icons.attach_money_rounded,
                          hint: 'المبلغ',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: SearchableDropdownField<String>(
                        labelText: 'العملة',
                        value: _customFeeCurrency,
                        items: const [
                          SearchableDropdownItem(value: 'USD', label: 'USD'),
                          SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                        ],
                        onChanged: (c) {
                          if (c != null) setState(() => _customFeeCurrency = c);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: AppButton(
                        label: 'إضافة',
                        icon: Icons.add,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        onPressed: () {
                          final name = _customFeeNameController.text.trim();
                          final amt = double.tryParse(_customFeeAmountController.text.trim());
                          if (name.isNotEmpty && amt != null && amt > 0) {
                            setState(() {
                              _ancillaryFees.add({
                                'fee_name': name,
                                'fee_amount': amt,
                                'currency': _customFeeCurrency,
                              });
                              _customFeeNameController.clear();
                              _customFeeAmountController.clear();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (_ancillaryFees.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _ancillaryFees.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final fee = entry.value;
                      final feeName = fee['fee_name'] ?? fee['fee_type'] ?? 'رسم إضافي';
                      final feeAmt = fee['fee_amount'] ?? fee['amount_usd'] ?? 0;
                      final feeCurr = fee['currency'] ?? 'USD';
                      return Chip(
                        backgroundColor: AppTheme.cobalt.withValues(alpha: 0.08),
                        label: Text(
                          '$feeName: $feeAmt $feeCurr',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setState(() => _ancillaryFees.removeAt(idx)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
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
  String _currency = 'USD';
  int _demFree = 14;
  int _detFree = 7;
  int _storFree = 5;
  double? _storRate; // required: no hard-coded storage rate
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(currenciesProvider).isLoading) {
        ref.read(currenciesProvider.notifier).fetchCurrencies();
      }
    });
  }

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
      'currency': _currency,
      'demurrage_free_days': _demFree,
      'detention_free_days': _detFree,
      'port_storage_free_days': _storFree,
      'port_storage_daily_rate_egp': _storRate,
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
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];
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
                      SearchableDropdownField<String>(
                        labelText: l.currencyFieldLabel,
                        value: currencies.any((c) => c.currencyCode == _currency)
                            ? _currency
                            : (_currency.isNotEmpty ? _currency : 'USD'),
                        items: (currencies.isNotEmpty
                                ? currencies.map((c) => c.currencyCode).toList()
                                : ['USD', 'EUR', 'EGP', 'CNY', 'GBP', 'SAR', 'AED'])
                            .map((code) => SearchableDropdownItem<String>(value: code, label: code))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _currency = v);
                        },
                      ),
                      _daysField(l.demurrageFreeDaysFieldLabel, _demFree, (v) => _demFree = v, 14, l),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CcFieldRow(
                    children: [
                      _daysField(l.detentionFreeDaysFieldLabel, _detFree, (v) => _detFree = v, 7, l),
                      _daysField(l.portStorageFreeDaysFieldLabel, _storFree, (v) => _storFree = v, 5, l),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CcFieldRow(
                    children: [
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
                      const SizedBox(),
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

/// Confirm posting demurrage/detention charges to a linked import file's financial settlement.
class DemurragePushToSettlementConfirmDialog extends StatelessWidget {
  const DemurragePushToSettlementConfirmDialog({
    super.key,
    required this.item,
  });

  final DemurrageTrackingModel item;

  static Future<bool?> show(BuildContext context, DemurrageTrackingModel item) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DemurragePushToSettlementConfirmDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fileCode = item.importFileCode ?? (item.importFileId != null ? '#${item.importFileId}' : '-');
    final rateStr = item.exchangeRate != null ? item.exchangeRate!.toStringAsFixed(4) : '-';

    return CcStageDialogShell(
      key: const Key('pushToSettlementConfirmDialog'),
      title: l.demPushConfirmTitle,
      icon: Icons.receipt_long_rounded,
      accent: AppTheme.emerald,
      maxWidth: 520,
      confirmLabel: l.demPushConfirmBtn,
      confirmVariant: AppButtonVariant.success,
      confirmIcon: Icons.receipt_long_rounded,
      confirmKey: const Key('pushToSettlementConfirmBtn'),
      cancelKey: const Key('pushToSettlementCancelBtn'),
      isSubmitting: false,
      onConfirm: () => Navigator.of(context).pop(true),
      chips: [
        CcHeaderChip(Icons.folder_outlined, fileCode, ltr: true),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              l.demPushConfirmMessage,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ),
          const SizedBox(height: 12),
          CcFormSection(
            title: l.totalEstimatedCostLabel,
            icon: Icons.monetization_on_outlined,
            child: Column(
              children: [
                CcFieldRow(
                  children: [
                    CcFact(
                      label: l.demPushConfirmFileCode,
                      value: fileCode,
                      mono: true,
                    ),
                    CcFact(
                      label: l.demPushConfirmRate,
                      value: rateStr,
                      mono: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CcFieldRow(
                  children: [
                    CcFact(
                      label: l.demPushConfirmDemurrageFx,
                      value: '${item.totalDemurrageFx.toStringAsFixed(2)} ${item.currency}',
                      mono: true,
                    ),
                    CcFact(
                      label: l.demPushConfirmDetentionFx,
                      value: '${item.totalDetentionFx.toStringAsFixed(2)} ${item.currency}',
                      mono: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CcFieldRow(
                  children: [
                    CcFact(
                      label: l.demPushConfirmStorageEgp,
                      value: '${item.totalStorageEgp.toStringAsFixed(2)} EGP',
                      mono: true,
                    ),
                    CcFact(
                      label: l.demPushConfirmTotalEgp,
                      value: '${item.totalCostEgp.toStringAsFixed(2)} EGP',
                      mono: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

