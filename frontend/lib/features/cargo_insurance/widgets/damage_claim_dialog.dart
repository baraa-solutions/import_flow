import 'package:flutter/material.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';

/// 📋 Dialog for filing a Cargo Insurance Damage Claim
class DamageClaimDialog extends StatefulWidget {
  final int? receivingId, importFileId;
  final String? initialGrnCode, initialPolicyNumber, initialProtocolNumber;
  final double? initialClaimAmount;
  final String? initialCurrency, initialDamageNotes, initialSurveyor;
  final Future<void> Function(Map<String, dynamic> claimData)? onClaimSubmitted;

  const DamageClaimDialog({
    super.key,
    this.receivingId,
    this.importFileId,
    this.initialGrnCode,
    this.initialPolicyNumber,
    this.initialProtocolNumber,
    this.initialClaimAmount,
    this.initialCurrency,
    this.initialDamageNotes,
    this.initialSurveyor,
    this.onClaimSubmitted,
  });

  @override
  State<DamageClaimDialog> createState() => _DamageClaimDialogState();
}

class _DamageClaimDialogState extends State<DamageClaimDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _grnCtrl, _policyCtrl, _protocolCtrl, _amountCtrl, _surveyorCtrl, _notesCtrl;
  late String _currency;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _grnCtrl = TextEditingController(text: widget.initialGrnCode ?? '');
    _policyCtrl = TextEditingController(text: widget.initialPolicyNumber ?? '');
    _protocolCtrl = TextEditingController(text: widget.initialProtocolNumber ?? '');
    _amountCtrl = TextEditingController(text: widget.initialClaimAmount?.toStringAsFixed(2) ?? '');
    _surveyorCtrl = TextEditingController(text: widget.initialSurveyor ?? '');
    _notesCtrl = TextEditingController(text: widget.initialDamageNotes ?? '');
    _currency = widget.initialCurrency ?? 'USD';
  }

  @override
  void dispose() {
    for (final c in [_grnCtrl, _policyCtrl, _protocolCtrl, _amountCtrl, _surveyorCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final nav = Navigator.of(context), messenger = ScaffoldMessenger.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar', l10n = context.l10n;

    final payload = {
      'receiving_id': widget.receivingId,
      'import_file_id': widget.importFileId,
      'grn_code': _grnCtrl.text.trim(),
      'policy_number': _policyCtrl.text.trim(),
      'inspection_protocol_number': _protocolCtrl.text.trim(),
      'surveyor_agency': _surveyorCtrl.text.trim(),
      'claim_amount_estimated': double.tryParse(_amountCtrl.text.trim()) ?? 0.0,
      'claim_currency': _currency,
      'discrepancy_notes': _notesCtrl.text.trim(),
      'insurance_claim_filed': true,
      'filed_at': DateTime.now().toIso8601String(),
    };

    try {
      if (widget.onClaimSubmitted != null) await widget.onClaimSubmitted!(payload);
      if (!mounted) return;
      nav.pop(payload);
      messenger.showSnackBar(AppTheme.snackBar(
        context,
        isAr ? 'تم تسجيل المطالبة التأمينية بنجاح' : 'Damage claim submitted successfully',
        severity: AppSeverity.success,
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(AppTheme.snackBar(context, ApiErrorText.of(l10n, e), severity: AppSeverity.danger));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final width = (MediaQuery.sizeOf(context).width - 32).clamp(320.0, 580.0);

    return SelectionArea(
      child: AlertDialog(
        backgroundColor: AppTheme.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 18, 16, 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsetsDirectional.all(8),
              decoration: BoxDecoration(
                color: AppTheme.crimson.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Icon(Icons.assignment_late_outlined, color: AppTheme.crimson, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'تسجيل مطالبة تأمين بضائع' : 'Cargo Damage Claim',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    isAr ? 'توثيق هوالك البضاعة ومحضر المعاينة' : 'Document goods damage & survey report',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              splashRadius: 18,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        content: SizedBox(
          width: width,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildField(_grnCtrl, isAr ? 'إذن الاستلام' : 'GRN Reference', isAr, req: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildField(_policyCtrl, isAr ? 'وثيقة التأمين' : 'Policy Number', isAr, req: true)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildField(_protocolCtrl, isAr ? 'محضر المعاينة' : 'Survey Protocol', isAr, req: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildField(_surveyorCtrl, isAr ? 'خبير المعاينة' : 'Surveyor Agency', isAr)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildField(_amountCtrl, isAr ? 'قيمة التلف التقديرية' : 'Estimated Damage', isAr, req: true, num: true),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SearchableDropdownField<String>(
                          labelText: isAr ? 'العملة' : 'Currency',
                          value: _currency,
                          decoration: InputDecoration(
                            labelText: isAr ? 'العملة' : 'Currency',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          items: ['USD', 'EGP', 'EUR'].map((c) => SearchableDropdownItem(value: c, label: c)).toList(),
                          onChanged: (val) => val != null ? setState(() => _currency = val) : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: isAr ? 'بيان الأضرار والملاحظات' : 'Damage Description & Notes',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? (isAr ? 'يجب إدخال بيان الأضرار' : 'Description is required')
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
        actions: [
          AppButton(
            label: isAr ? 'إلغاء' : 'Cancel',
            variant: AppButtonVariant.secondary,
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          ),
          AppButton(
            label: isAr ? 'تسجيل المطالبة' : 'Submit Claim',
            variant: AppButtonVariant.danger,
            icon: Icons.assignment_late_outlined,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, bool isAr, {bool req = false, bool num = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        suffixIcon: IconButton(
          icon: const Icon(Icons.copy_rounded, size: 14),
          splashRadius: 16,
          tooltip: isAr ? 'نسخ' : 'Copy',
          onPressed: () => CopyHelper.copy(context, ctrl.text),
        ),
      ),
      validator: (v) {
        if (!req) return null;
        if (v == null || v.trim().isEmpty) return isAr ? 'هذا الحقل مطلوب' : 'Field is required';
        if (num && (double.tryParse(v.trim()) == null || double.parse(v.trim()) <= 0)) {
          return isAr ? 'أدخل قيمة صحيحة' : 'Enter valid number';
        }
        return null;
      },
    );
  }
}
