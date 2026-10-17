import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/smart_upload_button.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';
import 'customs_ui.dart';

/// Standard dialog footer: neutral cancel + one primary action with an in-button
/// spinner (repeat taps are blocked while [isLoading]).
List<Widget> ccDialogActions({
  required BuildContext context,
  required String confirmLabel,
  required VoidCallback? onConfirm,
  required bool isLoading,
  AppButtonVariant confirmVariant = AppButtonVariant.primary,
}) {
  return [
    AppButton(
      label: context.l10n.cancel,
      variant: AppButtonVariant.secondary,
      size: AppButtonSize.small,
      onPressed: isLoading ? null : () => Navigator.pop(context),
    ),
    AppButton(
      label: confirmLabel,
      variant: confirmVariant,
      size: AppButtonSize.small,
      isLoading: isLoading,
      onPressed: onConfirm,
    ),
  ];
}

Widget _copyIcon(BuildContext context, TextEditingController c) => IconButton(
      icon: const Icon(Icons.copy, size: 16),
      tooltip: context.l10n.customsClearanceCopyFieldTooltip,
      onPressed: () => CopyHelper.copy(context, c.text),
    );

/// Create / edit / clone dialog of a clearance record.
class ClearanceFormDialog extends ConsumerStatefulWidget {
  const ClearanceFormDialog({super.key, this.recordToEdit, this.isCloneDraft = false});

  final CustomsClearanceModel? recordToEdit;
  final bool isCloneDraft;

  @override
  ConsumerState<ClearanceFormDialog> createState() => _ClearanceFormDialogState();
}

class _ClearanceFormDialogState extends ConsumerState<ClearanceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedImportFileId;
  final TextEditingController _decl46Ctrl = TextEditingController();
  final TextEditingController _officeCtrl = TextEditingController(text: 'Alexandria Port Customs');
  final TextEditingController _doNumberCtrl = TextEditingController();
  final TextEditingController _freeDaysCtrl = TextEditingController(text: '14');
  String _channelType = 'Red Channel';
  final TextEditingController _dutyCtrl = TextEditingController(text: '0');
  final TextEditingController _vatCtrl = TextEditingController(text: '0');
  final TextEditingController _scheduleTaxCtrl = TextEditingController(text: '0');
  final TextEditingController _whtCtrl = TextEditingController(text: '0');
  final TextEditingController _labFeesCtrl = TextEditingController(text: '0');
  final TextEditingController _estimatedDutyCtrl = TextEditingController(text: '0');
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final r = widget.recordToEdit;
    if (r != null) {
      _selectedImportFileId = r.importFileId;
      _decl46Ctrl.text = widget.isCloneDraft ? '' : (r.declaration46No ?? '');
      _officeCtrl.text = r.customsOfficeName;
      _doNumberCtrl.text = widget.isCloneDraft ? '' : (r.deliveryOrderNumber ?? '');
      _freeDaysCtrl.text = r.freeDaysAllowed.toString();
      _channelType = r.channelType;
      _dutyCtrl.text = r.importDutyAmount.toString();
      _vatCtrl.text = r.vatAmount.toString();
      _scheduleTaxCtrl.text = r.scheduleTaxAmount.toString();
      _whtCtrl.text = r.whtAmount.toString();
      _labFeesCtrl.text = r.labServiceFees.toString();
      _estimatedDutyCtrl.text = r.estimatedDutyTotal.toString();
    }
  }

  void _applyExtractedNafezaData(Map<String, dynamic> ext, AppLocalizations l) {
    setState(() {
      if (ext['declaration_no'] != null && ext['declaration_no'].toString().isNotEmpty) {
        _decl46Ctrl.text = ext['declaration_no'].toString();
      }
      if (ext['customs_office_name'] != null && ext['customs_office_name'].toString().isNotEmpty) {
        _officeCtrl.text = ext['customs_office_name'].toString();
      }
      if (ext['channel_type'] != null && ext['channel_type'].toString().isNotEmpty) {
        _channelType = ext['channel_type'].toString();
      }
      if (ext['import_duty'] != null) _dutyCtrl.text = ext['import_duty'].toString();
      if (ext['vat_amount'] != null) _vatCtrl.text = ext['vat_amount'].toString();
      if (ext['schedule_tax'] != null) _scheduleTaxCtrl.text = ext['schedule_tax'].toString();
      if (ext['wht_amount'] != null) _whtCtrl.text = ext['wht_amount'].toString();
      if (ext['lab_service_fees'] != null) _labFeesCtrl.text = ext['lab_service_fees'].toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, l.customsClearanceExtractNafezaSuccess, severity: AppSeverity.success),
    );
  }

  @override
  void dispose() {
    _decl46Ctrl.dispose();
    _officeCtrl.dispose();
    _doNumberCtrl.dispose();
    _freeDaysCtrl.dispose();
    _dutyCtrl.dispose();
    _vatCtrl.dispose();
    _scheduleTaxCtrl.dispose();
    _whtCtrl.dispose();
    _labFeesCtrl.dispose();
    _estimatedDutyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(AppLocalizations l) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final duty = double.tryParse(_dutyCtrl.text) ?? 0.0;
    final vat = double.tryParse(_vatCtrl.text) ?? 0.0;
    final sched = double.tryParse(_scheduleTaxCtrl.text) ?? 0.0;
    final wht = double.tryParse(_whtCtrl.text) ?? 0.0;
    final lab = double.tryParse(_labFeesCtrl.text) ?? 0.0;
    final total = duty + vat + sched + wht + lab;

    final payload = {
      'import_file_id': _selectedImportFileId,
      'declaration_46_no': _decl46Ctrl.text.trim().isNotEmpty ? _decl46Ctrl.text.trim() : null,
      'customs_office_name': _officeCtrl.text.trim(),
      'channel_type': _channelType,
      'delivery_order_number': _doNumberCtrl.text.trim().isNotEmpty ? _doNumberCtrl.text.trim() : null,
      'free_days_allowed': int.tryParse(_freeDaysCtrl.text) ?? 14,
      'import_duty_amount': duty,
      'vat_amount': vat,
      'schedule_tax_amount': sched,
      'wht_amount': wht,
      'lab_service_fees': lab,
      'total_duty_payable': total,
      'estimated_duty_total': double.tryParse(_estimatedDutyCtrl.text) ?? 0.0,
    };

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final successBar = AppTheme.snackBar(context, l.customsClearanceSaveRecordSuccess, severity: AppSeverity.success);
    try {
      await ref.read(customsClearanceProvider.notifier).createRecord(payload);
      navigator.pop();
      messenger.showSnackBar(successBar);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        AppTheme.snackBar(
          context,
          l.customsClearanceSaveRecordError(ApiErrorText.of(l, e)),
          severity: AppSeverity.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _dec(String label, {Widget? suffix}) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, suffixIcon: suffix);

  Widget _numField(TextEditingController c, String label) => TextFormField(
        controller: c,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        decoration: _dec(label),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final titleText = widget.isCloneDraft
        ? l.cloneCustomsClearanceDialogTitle
        : (widget.recordToEdit == null
            ? l.customsClearanceNewDialogTitle
            : l.customsClearanceEditDialogTitle(widget.recordToEdit!.clearanceCode));

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.gavel_rounded, color: AppTheme.cobalt),
          const SizedBox(width: 10),
          Expanded(child: Text(titleText, maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          SmartUploadButton(
            module: SmartUploadModule.customsClearance,
            compact: true,
            label: l.customsClearanceExtractNafezaBtn,
            onDataExtracted: (res) => _applyExtractedNafezaData(res.extractedFields, l),
          ),
        ],
      ),
      content: SelectionArea(
        child: SizedBox(
          width: (MediaQuery.of(context).size.width - 32).clamp(320.0, 720.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CcSectionCard(
                    title: l.ccFormSectionDeclaration,
                    icon: Icons.description_outlined,
                    child: Column(
                      children: [
                        SearchableDropdownField<int>(
                          value: _selectedImportFileId,
                          labelText: l.customsClearanceImportFileLabel,
                          searchHintText: l.customsClearanceImportFileSearchHint,
                          isRequired: true,
                          items: importFiles
                              .map((f) => SearchableDropdownItem<int>(
                                    value: f.importFileId,
                                    label: '${f.primaryNameWithCode} - ${f.companyName}',
                                    subtitle: 'PO: ${f.poNumber ?? "N/A"} | ACID: ${f.acidNumber ?? "N/A"}',
                                  ))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedImportFileId = val),
                          validator: (val) => val == null ? l.customsClearanceSelectFileValidator : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _decl46Ctrl,
                                textDirection: TextDirection.ltr,
                                decoration: _dec(l.customsClearanceDecl46Label, suffix: _copyIcon(context, _decl46Ctrl)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _doNumberCtrl,
                                textDirection: TextDirection.ltr,
                                decoration: _dec(l.customsClearanceDoNumberLabel, suffix: _copyIcon(context, _doNumberCtrl)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _freeDaysCtrl,
                                keyboardType: TextInputType.number,
                                textDirection: TextDirection.ltr,
                                decoration: _dec(l.customsClearanceFreeDaysInputLabel),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _officeCtrl,
                                decoration: _dec(l.customsClearanceOfficeInputLabel),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? l.customsClearanceOfficeValidator : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SearchableDropdownField<String>(
                                value: _channelType,
                                isDense: false,
                                isRequired: true,
                                labelText: l.customsClearanceChannelLabel,
                                decoration: _dec(l.customsClearanceChannelLabel),
                                items: [
                                  SearchableDropdownItem(
                                    value: 'Red Channel',
                                    label: l.customsClearanceChannelRed,
                                    icon: Icons.flag_rounded,
                                  ),
                                  SearchableDropdownItem(
                                    value: 'Green Channel',
                                    label: l.customsClearanceChannelGreen,
                                    icon: Icons.check_circle_outline,
                                  ),
                                  SearchableDropdownItem(
                                    value: 'Yellow Channel',
                                    label: l.customsClearanceChannelYellow,
                                    icon: Icons.flag_outlined,
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _channelType = val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  CcSectionCard(
                    title: l.customsClearanceDutyBreakdownHeader,
                    icon: Icons.calculate_outlined,
                    accent: AppTheme.emerald,
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _numField(_dutyCtrl, l.customsClearanceImportDutyInput)),
                            const SizedBox(width: 8),
                            Expanded(child: _numField(_vatCtrl, l.customsClearanceVatInput)),
                            const SizedBox(width: 8),
                            Expanded(child: _numField(_scheduleTaxCtrl, l.customsClearanceScheduleTaxInput)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _numField(_whtCtrl, l.customsClearanceWhtInput)),
                            const SizedBox(width: 8),
                            Expanded(child: _numField(_labFeesCtrl, l.customsClearanceLabFeesInput)),
                            const SizedBox(width: 8),
                            Expanded(child: _numField(_estimatedDutyCtrl, l.customsClearanceEstimatedDutyInput)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: ccDialogActions(
        context: context,
        confirmLabel: l.customsClearanceSaveRecordBtn,
        isLoading: _isLoading,
        onConfirm: _isLoading ? null : () => _save(l),
      ),
    );
  }
}

/// Fallback pay-duty dialog (used when the record's import file is not loaded).
/// Posts to `/customs-clearance/{id}/pay-duty`; bank and payment date are
/// optional for the backend but offered here.
class ClearanceDutyPaymentFallbackDialog extends ConsumerStatefulWidget {
  const ClearanceDutyPaymentFallbackDialog({super.key, required this.record});

  final CustomsClearanceModel record;

  @override
  ConsumerState<ClearanceDutyPaymentFallbackDialog> createState() =>
      _ClearanceDutyPaymentFallbackDialogState();
}

class _ClearanceDutyPaymentFallbackDialogState
    extends ConsumerState<ClearanceDutyPaymentFallbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _receiptCtrl = TextEditingController();
  final TextEditingController _actualPaidCtrl = TextEditingController();
  final TextEditingController _varianceReasonCtrl = TextEditingController();
  String? _bankCode;
  late DateTime _paymentDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final rec = widget.record;
    _actualPaidCtrl.text =
        rec.effectiveDutyTotal?.toString() ?? '';
    _receiptCtrl.text = rec.bankReceiptNo ?? '';
    _varianceReasonCtrl.text = rec.dutyVarianceReason ?? '';
    final storedBank = rec.payingBankName?.trim() ?? '';
    if (storedBank.isNotEmpty) {
      _bankCode = DomainEnums.initialCode(DomainEnumType.dutyBank, storedBank, storedBank);
    }
    final stored = rec.paymentDate != null ? DateTime.tryParse(rec.paymentDate!) : null;
    _paymentDate = stored ?? DateTime.now();
  }

  @override
  void dispose() {
    _receiptCtrl.dispose();
    _actualPaidCtrl.dispose();
    _varianceReasonCtrl.dispose();
    super.dispose();
  }

  void _applyExtractedPayment(Map<String, dynamic> ext) {
    setState(() {
      if (ext['receipt_number'] != null) _receiptCtrl.text = ext['receipt_number'].toString();
      if (ext['actual_paid_amount'] != null) _actualPaidCtrl.text = ext['actual_paid_amount'].toString();
    });
  }

  Future<void> _submit(AppLocalizations l) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final successBar = AppTheme.snackBar(context, l.customsClearancePaymentSuccess, severity: AppSeverity.success);
    try {
      await ref.read(customsClearanceProvider.notifier).submitDutyPayment(
        widget.record.customsClearanceId,
        {
          'bank_receipt_no': _receiptCtrl.text.trim(),
          'actual_duty_total': double.tryParse(_actualPaidCtrl.text) ?? widget.record.totalDutyPayable,
          'duty_variance_reason':
              _varianceReasonCtrl.text.trim().isNotEmpty ? _varianceReasonCtrl.text.trim() : null,
          if (_bankCode != null && _bankCode!.isNotEmpty) 'paying_bank_name': _bankCode,
          'payment_date': DateTime(_paymentDate.year, _paymentDate.month, _paymentDate.day).toIso8601String(),
        },
      );
      navigator.pop();
      messenger.showSnackBar(successBar);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        AppTheme.snackBar(
          context,
          l.customsClearancePaymentError(ApiErrorText.of(l, e)),
          severity: AppSeverity.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final est = widget.record.estimatedDutyTotal ?? 0;
    final act = double.tryParse(_actualPaidCtrl.text) ?? widget.record.totalDutyPayable ?? 0;
    final diff = act - est;
    final diffPercent = est > 0 ? ((diff / est) * 100).toStringAsFixed(1) : '0.0';
    final warn = diff.abs() > 500;
    final varianceColor = warn ? AppTheme.warningForeground : AppTheme.successForeground;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.payments_outlined, color: AppTheme.emerald),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.customsClearanceDutyPaymentDialogTitle(widget.record.clearanceCode),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SmartUploadButton(
            module: SmartUploadModule.customsClearance,
            compact: true,
            label: l.customsClearanceExtractReceiptBtn,
            onDataExtracted: (res) => _applyExtractedPayment(res.extractedFields),
          ),
        ],
      ),
      content: SelectionArea(
        child: SizedBox(
          width: (MediaQuery.of(context).size.width - 32).clamp(320.0, 580.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsetsDirectional.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.severityBackgroundOf(
                          context, warn ? AppSeverity.warning : AppSeverity.success),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: varianceColor.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                l.customsClearanceEstimatorDutyBoxLabel(CcFormat.money(est)),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                l.customsClearanceNafezaDutyBoxLabel(CcFormat.money(act)),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: AppTheme.successForeground),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l.customsClearanceVarianceBoxLabel,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            CcMoneyText(diff, signed: true, color: varianceColor),
                            Text('($diffPercent%)',
                                textDirection: TextDirection.ltr,
                                style: TextStyle(fontWeight: FontWeight.bold, color: varianceColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _actualPaidCtrl,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                        labelText: l.customsClearanceActualPaidInput,
                        border: const OutlineInputBorder(),
                        isDense: true),
                    validator: (v) => v == null || v.isEmpty ? l.poRecRequired : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _receiptCtrl,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: l.customsClearanceBankReceiptInput,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _copyIcon(context, _receiptCtrl),
                    ),
                    validator: (v) => v == null || v.isEmpty ? l.poRecRequired : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SearchableDropdownField<String>(
                          key: const Key('ccPayingBankField'),
                          value: _bankCode,
                          isDense: false,
                          labelText: l.ccPayingBankLabel,
                          decoration: InputDecoration(
                            labelText: l.ccPayingBankLabel,
                            prefixIcon: const Icon(Icons.account_balance_outlined, size: 18),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final b in DomainEnums.codesOf(DomainEnumType.dutyBank))
                              SearchableDropdownItem<String>(
                                value: b,
                                label: DomainEnums.label(l, DomainEnumType.dutyBank, b),
                              ),
                          ],
                          onChanged: (v) => setState(() => _bankCode = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CcDateField(
                          key: const Key('ccPaymentDateField'),
                          label: l.ccPaymentDateLabel,
                          value: _paymentDate,
                          onChanged: (d) => setState(() => _paymentDate = d),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _varianceReasonCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                        labelText: l.customsClearanceVarianceReasonInput,
                        border: const OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: ccDialogActions(
        context: context,
        confirmLabel: l.customsClearanceConfirmPaymentBtn,
        confirmVariant: AppButtonVariant.success,
        isLoading: _isLoading,
        onConfirm: _isLoading ? null : () => _submit(l),
      ),
    );
  }
}

/// Fallback final-release dialog. Posts to `/customs-clearance/{id}/complete-release`;
/// the release date is optional for the backend (defaults to now) but offered here.
class ClearanceFinalReleaseFallbackDialog extends ConsumerStatefulWidget {
  const ClearanceFinalReleaseFallbackDialog({super.key, required this.record});

  final CustomsClearanceModel record;

  @override
  ConsumerState<ClearanceFinalReleaseFallbackDialog> createState() =>
      _ClearanceFinalReleaseFallbackDialogState();
}

class _ClearanceFinalReleaseFallbackDialogState
    extends ConsumerState<ClearanceFinalReleaseFallbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _releaseNoCtrl = TextEditingController();
  late DateTime _releaseDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _releaseNoCtrl.text = widget.record.releasePermitNo ?? '';
    final stored = widget.record.releaseDate != null ? DateTime.tryParse(widget.record.releaseDate!) : null;
    _releaseDate = stored ?? DateTime.now();
  }

  @override
  void dispose() {
    _releaseNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations l) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final successBar = AppTheme.snackBar(context, l.customsClearanceReleaseSuccess, severity: AppSeverity.success);
    try {
      await ref.read(customsClearanceProvider.notifier).completeRelease(
        widget.record.customsClearanceId,
        {
          'release_permit_no': _releaseNoCtrl.text.trim(),
          'release_date': DateTime(_releaseDate.year, _releaseDate.month, _releaseDate.day).toIso8601String(),
        },
      );
      navigator.pop();
      messenger.showSnackBar(successBar);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        AppTheme.snackBar(
          context,
          l.customsClearanceReleaseError(ApiErrorText.of(l, e)),
          severity: AppSeverity.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.verified_user, color: AppTheme.wcagCobalt),
          const SizedBox(width: 10),
          Expanded(child: Text(l.customsClearanceFinalReleaseDialogTitle)),
        ],
      ),
      content: SelectionArea(
        child: SizedBox(
          width: (MediaQuery.of(context).size.width - 32).clamp(320.0, 500.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.customsClearanceFinalReleaseDialogDesc,
                  style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _releaseNoCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l.customsClearanceReleasePermitInput,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _copyIcon(context, _releaseNoCtrl),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l.ccRelPermitRequired;
                    if (v.trim().length < 3) return l.ccRelPermitTooShort;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CcDateField(
                  key: const Key('ccReleaseDateField'),
                  label: l.ccReleaseDateLabel,
                  value: _releaseDate,
                  onChanged: (d) => setState(() => _releaseDate = d),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: ccDialogActions(
        context: context,
        confirmLabel: l.customsClearanceConfirmReleaseBtn,
        isLoading: _isLoading,
        onConfirm: _isLoading ? null : () => _submit(l),
      ),
    );
  }
}
