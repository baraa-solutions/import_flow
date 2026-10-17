import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';
import 'cc_dialog_shell.dart';
import 'customs_ui.dart';

/// Modal dialog for CL-03: Customs Duty Payment Receipt
/// (Sadad / E-Finance payment and the bank receipt).
class CustomsDutyPaymentDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;
  final CustomsClearanceModel? clearanceRecord;

  const CustomsDutyPaymentDialog({
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
      builder: (context) => CustomsDutyPaymentDialog(
        file: file,
        clearanceRecord: clearanceRecord,
      ),
    );
  }

  @override
  ConsumerState<CustomsDutyPaymentDialog> createState() =>
      _CustomsDutyPaymentDialogState();
}

class _CustomsDutyPaymentDialogState
    extends ConsumerState<CustomsDutyPaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _sadadNumberController;
  late TextEditingController _receiptNumberController;
  late TextEditingController _dutyPaidAmountController;
  late TextEditingController _receiptFileUrlController;
  late TextEditingController _notesController;

  // Codes (DomainEnumType.paymentMethod / dutyBank); labels follow the UI language.
  String _paymentMethod = 'SADAD_EFINANCE';
  String? _bankName;
  DateTime _paymentDate = DateTime.now();
  bool _isSubmitting = false;

  // Codes first; a stored value that is not a known code/legacy label stays selectable.
  List<String> get _paymentMethods => [
        ...DomainEnums.codesOf(DomainEnumType.paymentMethod),
        if (!DomainEnums.isCode(DomainEnumType.paymentMethod, _paymentMethod)) _paymentMethod,
      ];

  List<String> get _bankNames => [
        ...DomainEnums.codesOf(DomainEnumType.dutyBank),
        if (_bankName != null && !DomainEnums.isCode(DomainEnumType.dutyBank, _bankName!)) _bankName!,
      ];

  @override
  void initState() {
    super.initState();
    final rec = widget.clearanceRecord;
    final file = widget.file;

    // Prefill sadad number strictly from record or file
    final initialSadad = rec?.sadadNumber ?? file.customsDutySadadNo ?? '';
    _sadadNumberController = TextEditingController(text: initialSadad);

    // Prefill receipt number
    _receiptNumberController = TextEditingController(
      text: rec?.bankReceiptNo ?? file.customsDutyReceiptNo ?? '',
    );

    // Prefill duty paid amount
    double initialAmount = 0.0;
    if (rec != null && (rec.actualDutyTotal ?? 0) > 0) {
      initialAmount = rec.actualDutyTotal!;
    } else if (rec != null && (rec.dutyPaidAmount ?? 0) > 0) {
      initialAmount = rec.dutyPaidAmount!;
    } else if (rec != null && (rec.estimatedDutyTotal ?? 0) > 0) {
      initialAmount = rec.estimatedDutyTotal!;
    } else if (file.customsDutyPaidAmount > 0) {
      initialAmount = file.customsDutyPaidAmount;
    }
    _dutyPaidAmountController = TextEditingController(
      text: initialAmount > 0 ? initialAmount.toStringAsFixed(2) : '',
    );

    // Prefill payment method
    // Legacy rows hold the old ar/en label; map it to its code.
    final storedMethod = rec?.paymentMethod.trim() ?? '';
    if (storedMethod.isNotEmpty) {
      _paymentMethod = DomainEnums.initialCode(DomainEnumType.paymentMethod, storedMethod, storedMethod);
    }
    final storedBank = rec?.payingBankName?.trim() ?? '';
    if (storedBank.isNotEmpty) {
      _bankName = DomainEnums.initialCode(DomainEnumType.dutyBank, storedBank, storedBank);
    } else {
      _bankName = null;
    }

    _receiptFileUrlController = TextEditingController(
      text: rec?.receiptFileUrl ?? '',
    );

    _notesController = TextEditingController(
      text: rec?.notes ?? '',
    );

    if (rec?.paymentDate != null) {
      final parsed = DateTime.tryParse(rec!.paymentDate!);
      if (parsed != null) _paymentDate = parsed;
    } else if (file.customsDutyPaymentDate != null) {
      final parsed = DateTime.tryParse(file.customsDutyPaymentDate!);
      if (parsed != null) _paymentDate = parsed;
    }
  }

  @override
  void dispose() {
    _sadadNumberController.dispose();
    _receiptNumberController.dispose();
    _dutyPaidAmountController.dispose();
    _receiptFileUrlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _submitDutyPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_dutyPaidAmountController.text.trim());
      final payload = {
        'import_file_id': widget.file.importFileId,
        'clearance_id': widget.clearanceRecord?.clearanceId,
        'sadad_number': _sadadNumberController.text.trim(),
        'bank_receipt_no': _receiptNumberController.text.trim(),
        'payment_method': _paymentMethod,
        'payment_date': _paymentDate.toIso8601String(),
        'duty_paid_amount': amount,
        'paying_bank_name': _bankName,
        'receipt_file_url': _receiptFileUrlController.text.trim().isNotEmpty
            ? _receiptFileUrlController.text.trim()
            : null,
        'payment_notes': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      };
      final sadad = _sadadNumberController.text.trim();

      await ref
          .read(customsClearanceProvider.notifier)
          .recordDutyPayment(payload);

      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(
            context,
            l.ccDutySuccess(sadad, CcFormat.money(amount)),
            severity: AppSeverity.success,
          ),
        );
        navigator.pop(true);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(
            context,
            l.ccDutyError(ApiErrorText.of(l, e)),
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rec = widget.clearanceRecord;
    final file = widget.file;

    final decl46 = rec?.declaration46No ?? file.form46No ?? '-';
    final claimNo = rec?.nafezaClaimNumber ?? '-';
    final assessedTotal = (rec != null && (rec.actualDutyTotal ?? 0) > 0)
        ? rec.actualDutyTotal!
        : (rec != null && (rec.estimatedDutyTotal ?? 0) > 0)
            ? rec.estimatedDutyTotal!
            : 0.0;

    return CcStageDialogShell(
      title: l.ccDutyDialogTitle,
      icon: Icons.receipt_long_rounded,
      accent: AppTheme.emerald,
      chips: [
        CcHeaderChip(Icons.folder_outlined, file.importFileCode, ltr: true),
        CcHeaderChip(Icons.description_outlined, l.ccDutyChipDecl(decl46)),
        CcHeaderChip(Icons.payment_outlined, l.ccDutyChipClaim(claimNo)),
      ],
      confirmKey: const Key('submitDutyPaymentBtn'),
      confirmLabel: l.ccDutyConfirm,
      loadingLabel: l.ccDutyConfirming,
      isSubmitting: _isSubmitting,
      onConfirm: _submitDutyPayment,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFinancialSummaryBanner(l, assessedTotal),
            const SizedBox(height: 20),
            _buildPaymentFormSection(l),
            const SizedBox(height: 20),
            _buildAttachmentAndNotesSection(l),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummaryBanner(AppLocalizations l, double assessedTotal) {
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: AppTheme.severityBackgroundOf(context, AppSeverity.success),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.emeraldBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsetsDirectional.all(10),
            decoration: const BoxDecoration(color: AppTheme.emeraldLight, shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.emerald, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.ccDutyAssessedTotalLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                assessedTotal > 0
                    ? CcMoneyText(assessedTotal, currency: l.ccCurrencyShort, fontSize: 20, color: AppTheme.successForeground)
                    : Text(
                        l.ccDutyAwaitingAssessment,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successForeground,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.emerald,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_clock_rounded, size: 14, color: AppTheme.white),
                const SizedBox(width: 6),
                Text(
                  l.ccDutyStageBadge,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentFormSection(AppLocalizations l) {
    return CcFormSection(
      title: l.ccDutyPaymentSection,
      icon: Icons.account_balance_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CcFieldRow(
            children: [
              CcField(
                label: l.ccDutySadadLabel,
                isRequired: true,
                child: TextFormField(
                  key: const Key('sadadNumberField'),
                  controller: _sadadNumberController,
                  textDirection: TextDirection.ltr,
                  decoration: ccInputDecoration(
                    hint: l.ccDutySadadHint,
                    prefix: Icons.pin_rounded,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l.ccDutySadadRequired;
                    if (v.trim().length < 3) return l.ccDutySadadTooShort;
                    return null;
                  },
                ),
              ),
              CcField(
                label: l.ccDutyReceiptLabel,
                isRequired: true,
                child: TextFormField(
                  key: const Key('dutyReceiptNumberField'),
                  controller: _receiptNumberController,
                  textDirection: TextDirection.ltr,
                  decoration: ccInputDecoration(hint: l.ccDutyReceiptHint, prefix: Icons.receipt_rounded),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l.ccDutyReceiptRequired : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CcFieldRow(
            children: [
              CcField(
                label: l.ccDutyAmountLabel,
                isRequired: true,
                child: TextFormField(
                  key: const Key('dutyPaidAmountField'),
                  controller: _dutyPaidAmountController,
                  textDirection: TextDirection.ltr,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: ccInputDecoration(
                    hint: '0.00',
                    prefix: Icons.payments_rounded,
                    suffixText: l.ccCurrencyShort,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l.ccDutyAmountRequired;
                    final val = double.tryParse(v.trim());
                    if (val == null || val <= 0) return l.ccDutyAmountInvalid;
                    return null;
                  },
                ),
              ),
              CcField(
                label: l.ccDutyDateLabel,
                isRequired: true,
                child: KeyedSubtree(
                  key: const Key('dutyPaymentDatePicker'),
                  child: CcDateTile(date: _paymentDate, onTap: _pickDate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CcFieldRow(
            children: [
              CcField(
                label: l.ccDutyMethodLabel,
                isRequired: true,
                child: SearchableDropdownField<String>(
                  key: const Key('paymentMethodField'),
                  value: _paymentMethod,
                  isDense: false,
                  isRequired: true,
                  labelText: l.ccDutyMethodLabel,
                  decoration: ccInputDecoration(prefix: Icons.credit_card_rounded),
                  items: _paymentMethods
                      .map((m) => SearchableDropdownItem<String>(
                            value: m,
                            label: DomainEnums.label(l, DomainEnumType.paymentMethod, m),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _paymentMethod = v);
                  },
                ),
              ),
              CcField(
                label: l.ccDutyBankLabel,
                isRequired: true,
                child: SearchableDropdownField<String>(
                  key: const Key('bankNameField'),
                  value: _bankName,
                  isDense: false,
                  isRequired: true,
                  labelText: l.ccDutyBankLabel,
                  decoration: ccInputDecoration(prefix: Icons.account_balance_outlined),
                  items: _bankNames
                      .map((b) => SearchableDropdownItem<String>(
                            value: b,
                            label: DomainEnums.label(l, DomainEnumType.dutyBank, b),
                          ))
                      .toList(),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l.ccDutyBankRequired : null,
                  onChanged: (v) {
                    if (v != null) setState(() => _bankName = v);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentAndNotesSection(AppLocalizations l) {
    return CcFormSection(
      title: l.ccDutyAttachmentsSection,
      icon: Icons.attachment_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CcField(
            label: l.ccDutyReceiptFileLabel,
            child: TextFormField(
              key: const Key('receiptFileUrlField'),
              controller: _receiptFileUrlController,
              textDirection: TextDirection.ltr,
              decoration: ccInputDecoration(hint: l.ccDutyReceiptFileHint, prefix: Icons.link_rounded),
            ),
          ),
          const SizedBox(height: 16),
          CcField(
            label: l.ccDutyNotesLabel,
            child: TextFormField(
              key: const Key('dutyPaymentNotesField'),
              controller: _notesController,
              maxLines: 2,
              decoration: ccInputDecoration(hint: l.ccDutyNotesHint),
            ),
          ),
        ],
      ),
    );
  }
}
