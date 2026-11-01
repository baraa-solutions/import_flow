import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../core/widgets/smart_upload_button.dart';
import '../../models/customs_clearance_model.dart';
import '../../providers/customs_clearance_provider.dart';
import '../customs_ui.dart';
import 'clearance_dialog_actions.dart';

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
                      suffixIcon: ccCopyIcon(context, _receiptCtrl),
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
