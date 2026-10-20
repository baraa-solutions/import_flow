import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/ltr_text.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';
import 'cc_dialog_shell.dart';

/// Pre-Form 4 Egyptian Customs Nafeza MTS Workflow Dialog (TASK-BE-10).
/// Enforces sequential business rules:
/// 1. Goods Item Tax Coding (التكويد الضريبي)
/// 2. Nafeza Bank Linkage Acceptance (قبول ربط البنك)
/// 3. Duty Payment Request / Nafeza Claim Issuance (طلب سداد الرسوم وفورمة 4)
class PreForm4NafezaWorkflowDialog extends ConsumerStatefulWidget {
  final CustomsClearanceModel clearanceRecord;

  const PreForm4NafezaWorkflowDialog({
    super.key,
    required this.clearanceRecord,
  });

  static Future<bool?> show(
    BuildContext context, {
    required CustomsClearanceModel clearanceRecord,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PreForm4NafezaWorkflowDialog(
        clearanceRecord: clearanceRecord,
      ),
    );
  }

  @override
  ConsumerState<PreForm4NafezaWorkflowDialog> createState() =>
      _PreForm4NafezaWorkflowDialogState();
}

class _PreForm4NafezaWorkflowDialogState
    extends ConsumerState<PreForm4NafezaWorkflowDialog> {
  late CustomsClearanceModel _record;

  // Step 1: Tariff Coding
  late TextEditingController _tariffCodingDateController;
  late TextEditingController _tariffCodingNotesController;
  bool _isSubmittingTariff = false;

  // Step 2: Bank Linkage
  late TextEditingController _bankLinkDateController;
  late TextEditingController _bankNameController;
  late TextEditingController _bankLinkNotesController;
  bool _isSubmittingBankLink = false;

  // Step 3: Duty Payment Request (Form 4)
  late TextEditingController _claimNumberController;
  late TextEditingController _paymentRequestDateController;
  late TextEditingController _estimatedAmountController;
  late TextEditingController _paymentRequestNotesController;
  bool _isSubmittingPaymentRequest = false;

  @override
  void initState() {
    super.initState();
    _record = widget.clearanceRecord;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // Step 1
    _tariffCodingDateController = TextEditingController(
      text: _record.tariffCodingDate ?? today,
    );
    _tariffCodingNotesController = TextEditingController();

    // Step 2
    _bankLinkDateController = TextEditingController(
      text: _record.bankLinkAcceptedDate ?? today,
    );
    _bankNameController = TextEditingController(
      text: _record.payingBankName ?? 'National Bank of Egypt (NBE)',
    );
    _bankLinkNotesController = TextEditingController();

    // Step 3
    _claimNumberController = TextEditingController(
      text: _record.nafezaClaimNumber ?? '',
    );
    _paymentRequestDateController = TextEditingController(
      text: _record.dutyPaymentRequestedDate ?? today,
    );
    final initialEst = _record.effectiveDutyTotal ?? _record.estimatedDutyTotal ?? 0.0;
    _estimatedAmountController = TextEditingController(
      text: initialEst > 0 ? initialEst.toStringAsFixed(2) : '',
    );
    _paymentRequestNotesController = TextEditingController();
  }

  @override
  void dispose() {
    _tariffCodingDateController.dispose();
    _tariffCodingNotesController.dispose();
    _bankLinkDateController.dispose();
    _bankNameController.dispose();
    _bankLinkNotesController.dispose();
    _claimNumberController.dispose();
    _paymentRequestDateController.dispose();
    _estimatedAmountController.dispose();
    _paymentRequestNotesController.dispose();
    super.dispose();
  }

  bool get _isTariffCodingCompleted =>
      _record.tariffCodingDate != null && _record.tariffCodingDate!.trim().isNotEmpty;

  bool get _isBankLinkCompleted =>
      _record.bankLinkAcceptedDate != null && _record.bankLinkAcceptedDate!.trim().isNotEmpty;

  bool get _isPaymentRequestCompleted =>
      _record.dutyPaymentRequestedDate != null &&
      _record.dutyPaymentRequestedDate!.trim().isNotEmpty;

  Future<void> _submitTariffCoding(AppLocalizations l) async {
    final date = _tariffCodingDateController.text.trim();
    if (date.isEmpty) return;

    setState(() => _isSubmittingTariff = true);
    try {
      final updated = await ref
          .read(customsClearanceProvider.notifier)
          .recordTariffCoding(
            customsClearanceId: _record.customsClearanceId,
            tariffCodingDate: date,
            notes: _tariffCodingNotesController.text.trim().isNotEmpty
                ? _tariffCodingNotesController.text.trim()
                : null,
          );
      if (updated != null && mounted) {
        setState(() => _record = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l.isArabic
                ? 'تم تسجيل واعتماد التكويد الضريبي بنجاح'
                : 'Item tax coding recorded successfully',
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            ApiErrorText.of(l, e),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingTariff = false);
    }
  }

  Future<void> _submitBankLink(AppLocalizations l) async {
    final date = _bankLinkDateController.text.trim();
    if (date.isEmpty) return;

    setState(() => _isSubmittingBankLink = true);
    try {
      final updated = await ref
          .read(customsClearanceProvider.notifier)
          .recordBankLinkAccepted(
            customsClearanceId: _record.customsClearanceId,
            bankLinkAcceptedDate: date,
            bankName: _bankNameController.text.trim().isNotEmpty
                ? _bankNameController.text.trim()
                : null,
            notes: _bankLinkNotesController.text.trim().isNotEmpty
                ? _bankLinkNotesController.text.trim()
                : null,
          );
      if (updated != null && mounted) {
        setState(() => _record = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l.isArabic
                ? 'تم قبول واعتماد ربط البنك على نافذة بنجاح'
                : 'Nafeza bank linkage accepted successfully',
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            ApiErrorText.of(l, e),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingBankLink = false);
    }
  }

  Future<void> _submitPaymentRequest(AppLocalizations l) async {
    final date = _paymentRequestDateController.text.trim();
    if (date.isEmpty) return;

    setState(() => _isSubmittingPaymentRequest = true);
    try {
      final estAmt = double.tryParse(_estimatedAmountController.text.trim());
      final updated = await ref
          .read(customsClearanceProvider.notifier)
          .requestDutyPayment(
            customsClearanceId: _record.customsClearanceId,
            dutyPaymentRequestedDate: date,
            nafezaClaimNumber: _claimNumberController.text.trim().isNotEmpty
                ? _claimNumberController.text.trim()
                : null,
            estimatedDutyAmount: estAmt,
            notes: _paymentRequestNotesController.text.trim().isNotEmpty
                ? _paymentRequestNotesController.text.trim()
                : null,
          );
      if (updated != null && mounted) {
        setState(() => _record = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l.isArabic
                ? 'تم تسجيل طلب سداد الرسوم وإصدار المطالبة بنجاح'
                : 'Duty payment request submitted successfully',
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            ApiErrorText.of(l, e),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingPaymentRequest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = l.isArabic;

    return CcStageDialogShell(
      title: isAr
          ? 'منظومة نافذة والربط البنكي — إجراءات ما قبل فورمة 4'
          : 'Nafeza Platform & Bank Linkage — Pre-Form 4 Workflow',
      icon: Icons.account_balance,
      accent: AppTheme.cobalt,
      maxWidth: 920,
      chips: [
        CcHeaderChip(Icons.tag, _record.clearanceCode, ltr: true),
        if (_record.declaration46No != null)
          CcHeaderChip(
            Icons.description_outlined,
            '${isAr ? "نموذج 46" : "Decl 46"}: ${_record.declaration46No}',
            ltr: true,
          ),
        CcHeaderChip(
          Icons.location_on_outlined,
          _record.customsOfficeName,
        ),
      ],
      confirmLabel: isAr ? 'تم وحفظ' : 'Done',
      confirmIcon: Icons.check_circle_outline,
      confirmVariant: AppButtonVariant.primary,
      isSubmitting: false,
      onConfirm: () => Navigator.of(context).pop(true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Process Overview Header Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.cobalt.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.cobalt, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isAr
                      ? 'دورة العمل الإلزامية على نافذة MTS: يجب تسجيل التكويد الضريبي للبنود أولاً، يليه قبول ربط البنك على نافذة، ثم إصدار مطالبة الرسوم وطلب فورمة 4.'
                      : 'Mandatory Nafeza MTS Workflow: Item tax coding must be completed first, followed by bank link acceptance, then Form 4 duty payment request.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // STEP 1: ITEM TAX CODING
          _buildStepCard(
            stepNumber: 1,
            title: isAr
                ? 'التكويد الضريبي للبنود على نافذة (Item Tax Coding)'
                : 'Item Tax Coding on Nafeza',
            isCompleted: _isTariffCodingCompleted,
            completionDate: _record.tariffCodingDate,
            accentColor: AppTheme.cobalt,
            icon: Icons.qr_code_2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: CustomTextField(
                        controller: _tariffCodingDateController,
                        label: isAr ? 'تاريخ التكويد الضريبي (YYYY-MM-DD)' : 'Tariff Coding Date',
                        icon: Icons.calendar_today,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: CustomTextField(
                        controller: _tariffCodingNotesController,
                        label: isAr ? 'ملاحظات التكويد (اختياري)' : 'Coding Notes (Optional)',
                        icon: Icons.note_alt_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: isAr ? Alignment.centerLeft : Alignment.centerRight,
                  child: AppButton(
                    label: _isTariffCodingCompleted
                        ? (isAr ? 'تحديث تاريخ التكويد' : 'Update Coding Date')
                        : (isAr ? 'اعتماد التكويد الضريبي' : 'Record Tax Coding'),
                    icon: Icons.check,
                    variant: _isTariffCodingCompleted
                        ? AppButtonVariant.secondary
                        : AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    isLoading: _isSubmittingTariff,
                    onPressed: () => _submitTariffCoding(l),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // STEP 2: NAFEZA BANK LINKAGE ACCEPTANCE
          _buildStepCard(
            stepNumber: 2,
            title: isAr
                ? 'قبول ربط البنك على نافذة (Bank Linkage Acceptance)'
                : 'Nafeza Bank Linkage Acceptance',
            isCompleted: _isBankLinkCompleted,
            completionDate: _record.bankLinkAcceptedDate,
            accentColor: AppTheme.emerald,
            icon: Icons.account_balance,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isTariffCodingCompleted) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isAr
                                ? 'شرط مسبق: لا يمكن قبول ربط البنك إلا بعد تسجيل التكويد الضريبي للبنود أعلاه.'
                                : 'Prerequisite: Bank linkage cannot be accepted before item tax coding is completed.',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: CustomTextField(
                        controller: _bankLinkDateController,
                        label: isAr ? 'تاريخ قبول الربط (YYYY-MM-DD)' : 'Acceptance Date',
                        icon: Icons.event_available,
                        enabled: _isTariffCodingCompleted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: CustomTextField(
                        controller: _bankNameController,
                        label: isAr ? 'اسم البنك المعتمد' : 'Bank Name',
                        icon: Icons.account_balance_outlined,
                        enabled: _isTariffCodingCompleted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: CustomTextField(
                        controller: _bankLinkNotesController,
                        label: isAr ? 'ملاحظات الربط (اختياري)' : 'Link Notes (Optional)',
                        icon: Icons.notes,
                        enabled: _isTariffCodingCompleted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: isAr ? Alignment.centerLeft : Alignment.centerRight,
                  child: AppButton(
                    label: _isBankLinkCompleted
                        ? (isAr ? 'تحديث قبول ربط البنك' : 'Update Bank Link')
                        : (isAr ? 'اعتماد وقبول ربط البنك' : 'Accept Bank Linkage'),
                    icon: Icons.check_circle_outline,
                    variant: _isBankLinkCompleted
                        ? AppButtonVariant.secondary
                        : AppButtonVariant.success,
                    size: AppButtonSize.small,
                    isLoading: _isSubmittingBankLink,
                    onPressed: _isTariffCodingCompleted
                        ? () => _submitBankLink(l)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // STEP 3: DUTY PAYMENT REQUEST & NAFEZA CLAIM (FORM 4)
          _buildStepCard(
            stepNumber: 3,
            title: isAr
                ? 'إصدار مطالبة الرسوم وطلب فورمة 4 (Duty Payment Request / Form 4)'
                : 'Duty Payment Request & Nafeza Claim',
            isCompleted: _isPaymentRequestCompleted,
            completionDate: _record.dutyPaymentRequestedDate,
            accentColor: AppTheme.cobalt,
            icon: Icons.receipt_long,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isBankLinkCompleted) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.charcoal.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.charcoal.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isAr
                                ? 'يوصى باكتمال ربط البنك أولاً قبل طلب السداد لضمان مطابقة المنظومة البنكية مع نافذة.'
                                : 'Recommended to accept bank linkage before requesting duty payment to match MTS with bank systems.',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: CustomTextField(
                        controller: _paymentRequestDateController,
                        label: isAr ? 'تاريخ طلب السداد (YYYY-MM-DD)' : 'Request Date',
                        icon: Icons.calendar_month,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: CustomTextField(
                        controller: _claimNumberController,
                        label: isAr ? 'رقم مطالبة نافذة' : 'Nafeza Claim Number',
                        icon: Icons.tag,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: CustomTextField(
                        controller: _estimatedAmountController,
                        label: isAr ? 'الرسوم التقديرية (EGP)' : 'Estimated Duty (EGP)',
                        icon: Icons.payments_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _paymentRequestNotesController,
                  label: isAr ? 'ملاحظات طلب السداد والمطالبة' : 'Payment Request Notes',
                  icon: Icons.note_alt_outlined,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: isAr ? Alignment.centerLeft : Alignment.centerRight,
                  child: AppButton(
                    label: _isPaymentRequestCompleted
                        ? (isAr ? 'تحديث طلب السداد والمطالبة' : 'Update Payment Request')
                        : (isAr ? 'إرسال طلب السداد (طلب فورمة 4)' : 'Submit Duty Payment Request'),
                    icon: Icons.send_rounded,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    isLoading: _isSubmittingPaymentRequest,
                    onPressed: () => _submitPaymentRequest(l),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required int stepNumber,
    required String title,
    required bool isCompleted,
    required String? completionDate,
    required Color accentColor,
    required IconData icon,
    required Widget child,
  }) {
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isCompleted
              ? AppTheme.emerald.withOpacity(0.4)
              : AppTheme.borderOf(context),
          width: isCompleted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppTheme.emerald.withOpacity(0.08)
                  : accentColor.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLg),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isCompleted ? AppTheme.emerald : accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? AppTheme.emerald : accentColor,
                    ),
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          isAr ? 'مكتمل' : 'Completed',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (completionDate != null) ...[
                          const SizedBox(width: 4),
                          LtrText(
                            '($completionDate)',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.charcoal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isAr ? 'في الانتظار' : 'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}
