import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';
import 'cc_dialog_shell.dart';
import 'customs_ui.dart';

/// Modal dialog for CL-04: Final Customs Release Order
/// (green release permit and start of the transport to the warehouses).
class CustomsFinalReleaseDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;
  final CustomsClearanceModel? clearanceRecord;

  const CustomsFinalReleaseDialog({
    super.key,
    required this.file,
    this.clearanceRecord,
  });

  static Future<bool?> show(
    BuildContext context,
    ImportFileModel file, {
    CustomsClearanceModel? clearanceRecord,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomsFinalReleaseDialog(
        file: file,
        clearanceRecord: clearanceRecord,
      ),
    );
  }

  @override
  ConsumerState<CustomsFinalReleaseDialog> createState() =>
      _CustomsFinalReleaseDialogState();
}

class _CustomsFinalReleaseDialogState
    extends ConsumerState<CustomsFinalReleaseDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _releasePermitNoController;
  late TextEditingController _releaseOfficerController;
  late TextEditingController _gatePassNoController;
  late TextEditingController _demurrageFeesController;
  late TextEditingController _documentUrlController;
  late TextEditingController _transportInstructionsController;
  late TextEditingController _notesController;

  /// Release type code (DomainEnumType.releaseType); the label follows the UI language.
  String _releaseType = 'FINAL_GREEN';
  DateTime _releaseDate = DateTime.now();
  DateTime? _portGateOutDate;
  bool _dispatchAuthorized = false;
  bool _isSubmitting = false;

  final List<String> _releaseTypes = DomainEnums.codesOf(DomainEnumType.releaseType);

  @override
  void initState() {
    super.initState();
    final rec = widget.clearanceRecord;
    final file = widget.file;

    // Prefill release permit number strictly from record or file
    final initialPermit = rec?.releasePermitNo ?? file.customsReleasePermitNo ?? '';
    _releasePermitNoController = TextEditingController(text: initialPermit);

    // Prefill officer name
    _releaseOfficerController = TextEditingController(
      text: rec?.releaseOfficerName ?? file.customsReleaseOfficer ?? '',
    );

    // Prefill gate pass number strictly from record or file
    final initialGatePass = rec?.gatePassNumber ?? file.customsGatePassNo ?? '';
    _gatePassNoController = TextEditingController(text: initialGatePass);

    // Prefill demurrage fees
    final demurrage = rec?.demurrageStorageFees;
    _demurrageFeesController = TextEditingController(
      text: (demurrage != null && demurrage > 0) ? demurrage.toStringAsFixed(2) : '',
    );

    // Prefill release type
    // Legacy rows hold the old ar/en label; map it to its code.
    _releaseType = DomainEnums.legacyToCode(DomainEnumType.releaseType, rec?.releaseType) ??
        DomainEnums.legacyToCode(DomainEnumType.releaseType, file.customsReleaseType) ??
        _releaseType;

    _documentUrlController = TextEditingController(
      text: rec?.releaseDocumentUrl ?? '',
    );

    _transportInstructionsController = TextEditingController(
      text: rec?.transportInstructions ??
          'Direct delivery to company warehouses - verify customs seal integrity before opening the container',
    );

    _notesController = TextEditingController(
      text: rec?.notes ?? '',
    );

    if (rec?.portGateOutDate != null) {
      _portGateOutDate = DateTime.tryParse(rec!.portGateOutDate!);
    } else {
      _portGateOutDate = null;
    }

    _dispatchAuthorized = rec?.dispatchAuthorized ?? false;
  }

  @override
  void dispose() {
    _releasePermitNoController.dispose();
    _releaseOfficerController.dispose();
    _gatePassNoController.dispose();
    _demurrageFeesController.dispose();
    _documentUrlController.dispose();
    _transportInstructionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickReleaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _releaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _releaseDate = picked);
    }
  }

  Future<void> _pickGateOutDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _portGateOutDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _portGateOutDate = picked);
    }
  }

  Future<void> _submitFinalRelease() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isSubmitting = true);

    try {
      final demurrage = double.tryParse(_demurrageFeesController.text.trim()) ?? 0.0;
      final payload = {
        'import_file_id': widget.file.importFileId,
        'clearance_id': widget.clearanceRecord?.customsClearanceId,
        'release_permit_no': _releasePermitNoController.text.trim(),
        'release_date': _releaseDate.toIso8601String(),
        'release_officer_name': _releaseOfficerController.text.trim().isNotEmpty
            ? _releaseOfficerController.text.trim()
            : null,
        'release_type': _releaseType,
        'release_document_url': _documentUrlController.text.trim().isNotEmpty
            ? _documentUrlController.text.trim()
            : null,
        'gate_pass_number': _gatePassNoController.text.trim().isNotEmpty
            ? _gatePassNoController.text.trim()
            : null,
        'port_gate_out_date': _portGateOutDate?.toIso8601String(),
        'demurrage_storage_fees': demurrage,
        'dispatch_authorized': _dispatchAuthorized,
        'transport_instructions': _transportInstructionsController.text.trim().isNotEmpty
            ? _transportInstructionsController.text.trim()
            : null,
        'notes': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      };
      final permit = _releasePermitNoController.text.trim();

      await ref
          .read(customsClearanceProvider.notifier)
          .issueFinalRelease(payload);

      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(context, l.ccRelSuccess(permit), severity: AppSeverity.success),
        );
        navigator.pop(true);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(
            context,
            l.ccRelError(ApiErrorText.of(l, e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  InputDecoration _dec(String label, {String? hint, IconData? icon, Widget? suffix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rec = widget.clearanceRecord;
    final file = widget.file;

    final decl46 = rec?.declaration46No ?? file.form46No ?? '-';
    final sadadNo = rec?.sadadNumber ?? file.customsDutySadadNo ?? '-';
    final paidAmount = (rec != null && (rec.dutyPaidAmount ?? 0) > 0)
        ? rec.dutyPaidAmount!
        : (file.customsDutyPaidAmount > 0)
            ? file.customsDutyPaidAmount
            : ((rec != null && (rec.actualDutyTotal ?? 0) > 0) ? rec.actualDutyTotal! : 0.0);

    return CcStageDialogShell(
      title: l.ccRelTitle,
      icon: Icons.verified_outlined,
      accent: AppTheme.emerald,
      chips: [
        CcHeaderChip(Icons.folder_outlined, l.ccRelChipFile(file.primaryNameWithCode)),
        CcHeaderChip(Icons.description_outlined, l.ccRelChipDecl(decl46)),
      ],
      confirmKey: const Key('customsFinalReleaseSubmitBtn'),
      confirmLabel: l.ccRelConfirm,
      loadingLabel: l.ccRelConfirming,
      confirmIcon: Icons.verified,
      isSubmitting: _isSubmitting,
      onConfirm: _submitFinalRelease,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status summary
            Container(
              padding: const EdgeInsetsDirectional.all(16),
              decoration: BoxDecoration(
                color: AppTheme.severityBackgroundOf(context, AppSeverity.success),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.emeraldBorder),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  _buildInfoChip(icon: Icons.receipt_long, label: l.ccRelSumDecl, value: decl46),
                  _buildInfoChip(icon: Icons.payment, label: l.ccRelSumSadad, value: sadadNo),
                  _buildInfoChip(
                    icon: Icons.price_check,
                    label: l.ccRelSumPaid,
                    value: '${CcFormat.money(paidAmount)} ${l.ccCurrencyShort}',
                    isHighlight: true,
                  ),
                  _buildInfoChip(
                    icon: Icons.anchor,
                    label: l.ccRelSumPort,
                    value: file.portOfDischarge ?? '-',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            CcFormSection(
              title: l.ccRelPermitSection,
              icon: Icons.fact_check,
              accent: AppTheme.emerald,
              child: Column(
                children: [
                  CcFieldRow(
                    children: [
                      TextFormField(
                        key: const Key('releasePermitNoField'),
                        controller: _releasePermitNoController,
                        textDirection: TextDirection.ltr,
                        decoration: _dec(
                          l.ccRelPermitNoLabel,
                          hint: l.ccRelPermitNoHint,
                          icon: Icons.confirmation_number_outlined,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return l.ccRelPermitRequired;
                          if (val.trim().length < 3) return l.ccRelPermitTooShort;
                          return null;
                        },
                      ),
                      InkWell(
                        onTap: _pickReleaseDate,
                        child: InputDecorator(
                          decoration: _dec(l.ccRelDateLabel, icon: Icons.calendar_today),
                          child: LtrText(CcFormat.date(_releaseDate),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CcFieldRow(
                    children: [
                      TextFormField(
                        key: const Key('releaseOfficerField'),
                        controller: _releaseOfficerController,
                        decoration: _dec(l.ccRelOfficerLabel, hint: l.ccRelOfficerHint, icon: Icons.person_outline),
                      ),
                      SearchableDropdownField<String>(
                        value: _releaseType,
                        isDense: false,
                        isRequired: true,
                        labelText: l.ccRelTypeLabel,
                        decoration: _dec(l.ccRelTypeLabel, icon: Icons.category_outlined),
                        items: _releaseTypes
                            .map((type) => SearchableDropdownItem<String>(
                                  value: type,
                                  label: DomainEnums.label(l, DomainEnumType.releaseType, type),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _releaseType = val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            CcFormSection(
              title: l.ccRelGateSection,
              icon: Icons.local_shipping,
              accent: AppTheme.emerald,
              child: Column(
                children: [
                  CcFieldRow(
                    children: [
                      TextFormField(
                        key: const Key('gatePassNoField'),
                        controller: _gatePassNoController,
                        textDirection: TextDirection.ltr,
                        decoration: _dec(
                          l.ccRelGatePassLabel,
                          hint: l.ccRelGatePassHint,
                          icon: Icons.vpn_key_outlined,
                        ),
                      ),
                      InkWell(
                        onTap: _pickGateOutDate,
                        child: InputDecorator(
                          decoration: _dec(l.ccRelGateOutDateLabel, icon: Icons.departure_board),
                          child: _portGateOutDate != null
                              ? LtrText(CcFormat.date(_portGateOutDate!),
                                  style: const TextStyle(fontWeight: FontWeight.w600))
                              : Text(l.ccRelNotSet, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CcFieldRow(
                    children: [
                      TextFormField(
                        key: const Key('demurrageFeesField'),
                        controller: _demurrageFeesController,
                        textDirection: TextDirection.ltr,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _dec(l.ccRelDemurrageLabel, hint: '0.00', icon: Icons.attach_money),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final numVal = double.tryParse(val.trim());
                            if (numVal == null || numVal < 0) return l.ccRelAmountInvalid;
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        key: const Key('documentUrlField'),
                        controller: _documentUrlController,
                        textDirection: TextDirection.ltr,
                        decoration: _dec(l.ccRelDocUrlLabel, hint: 'https://...', icon: Icons.link),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDispatchSwitch(l),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('transportInstructionsField'),
                    controller: _transportInstructionsController,
                    maxLines: 2,
                    decoration: _dec(
                      l.ccRelTransportLabel,
                      hint: l.ccRelTransportHint,
                      icon: Icons.navigation_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('notesField'),
                    controller: _notesController,
                    maxLines: 2,
                    decoration: _dec(l.ccRelNotesLabel, hint: l.ccRelNotesHint, icon: Icons.notes_outlined),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDispatchSwitch(AppLocalizations l) {
    final on = _dispatchAuthorized;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: on ? AppTheme.severityBackgroundOf(context, AppSeverity.success) : AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: on ? AppTheme.emeraldBorder : AppTheme.borderOf(context)),
      ),
      child: Row(
        children: [
          Icon(
            on ? Icons.check_circle : Icons.pause_circle_outline,
            color: on ? AppTheme.emerald : AppTheme.textMutedOf(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.ccRelDispatchTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  l.ccRelDispatchDesc,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                ),
              ],
            ),
          ),
          Switch(
            value: _dispatchAuthorized,
            activeThumbColor: AppTheme.emerald,
            onChanged: (val) => setState(() => _dispatchAuthorized = val),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    final color = isHighlight ? AppTheme.successForeground : AppTheme.textPrimaryOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: isHighlight ? AppTheme.emerald : AppTheme.textSecondaryOf(context)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
            LtrText(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ],
    );
  }
}
