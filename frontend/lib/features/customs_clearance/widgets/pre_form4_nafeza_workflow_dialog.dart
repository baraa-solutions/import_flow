import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';
import 'cc_dialog_shell.dart';
import 'pre_form4/pre_form4_bank_link_card.dart';
import 'pre_form4/pre_form4_payment_request_card.dart';
import 'pre_form4/pre_form4_tariff_coding_card.dart';

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
      body: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cobalt.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.25)),
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
            PreForm4TariffCodingCard(
              isCompleted: _isTariffCodingCompleted,
              completionDate: _record.tariffCodingDate,
              dateController: _tariffCodingDateController,
              notesController: _tariffCodingNotesController,
              isSubmitting: _isSubmittingTariff,
              onSubmit: () => _submitTariffCoding(l),
            ),
            const SizedBox(height: 16),
            PreForm4BankLinkCard(
              isCompleted: _isBankLinkCompleted,
              completionDate: _record.bankLinkAcceptedDate,
              isTariffCodingCompleted: _isTariffCodingCompleted,
              dateController: _bankLinkDateController,
              bankNameController: _bankNameController,
              notesController: _bankLinkNotesController,
              isSubmitting: _isSubmittingBankLink,
              onSubmit: () => _submitBankLink(l),
            ),
            const SizedBox(height: 16),
            PreForm4PaymentRequestCard(
              isCompleted: _isPaymentRequestCompleted,
              completionDate: _record.dutyPaymentRequestedDate,
              isBankLinkCompleted: _isBankLinkCompleted,
              dateController: _paymentRequestDateController,
              claimNumberController: _claimNumberController,
              estimatedAmountController: _estimatedAmountController,
              notesController: _paymentRequestNotesController,
              isSubmitting: _isSubmittingPaymentRequest,
              onSubmit: () => _submitPaymentRequest(l),
            ),
          ],
        ),
      ),
    );
  }
}
