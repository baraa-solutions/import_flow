import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../models/financial_approval_model.dart';
import '../../experience_guide/models/guide_entry_model.dart';
import '../../experience_guide/providers/experience_guide_provider.dart';
import '../../experience_guide/widgets/experience_guide_alert_banner.dart';
import 'supplier_advance_payment/supplier_advance_payment_header.dart';
import 'supplier_advance_payment/advance_payment_calculation_section.dart';
import 'supplier_advance_payment/advance_payment_banking_section.dart';
import 'supplier_advance_payment/advance_payment_submit_handler.dart';
import 'supplier_advance_payment/advance_payment_prefill_service.dart';

/// Shows the Foreign Supplier Advance Payment Request Dialog (FN-01)
Future<PaymentRequestModel?> showSupplierAdvancePaymentDialog(
  BuildContext context,
  WidgetRef ref, {
  required int importFileId,
  required String importFileCode,
  String? fileTitle,
  int? supplierId,
  required String supplierName,
  int? projectId,
  int? poId,
  double? totalAmountForeign,
  String currency = 'USD',
}) {
  return showDialog<PaymentRequestModel>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => SupplierAdvancePaymentDialog(
      importFileId: importFileId,
      importFileCode: importFileCode,
      fileTitle: fileTitle,
      supplierId: supplierId,
      supplierName: supplierName,
      projectId: projectId,
      poId: poId,
      totalAmountForeign: totalAmountForeign,
      currency: currency,
    ),
  );
}

/// Dedicated Dialog for Issuing Supplier Advance Payment Requests (FN-01)
class SupplierAdvancePaymentDialog extends ConsumerStatefulWidget {
  final int importFileId;
  final String importFileCode;
  final String? fileTitle;
  final int? supplierId;
  final String supplierName;
  final int? projectId;
  final int? poId;
  final double? totalAmountForeign;
  final String currency;

  const SupplierAdvancePaymentDialog({
    super.key,
    required this.importFileId,
    required this.importFileCode,
    this.fileTitle,
    this.supplierId,
    required this.supplierName,
    this.projectId,
    this.poId,
    this.totalAmountForeign,
    this.currency = 'USD',
  });

  @override
  ConsumerState<SupplierAdvancePaymentDialog> createState() =>
      _SupplierAdvancePaymentDialogState();
}

class _SupplierAdvancePaymentDialogState
    extends ConsumerState<SupplierAdvancePaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _exchangeRateController;
  late TextEditingController _beneficiaryController;
  late TextEditingController _bankNameController;
  late TextEditingController _swiftController;
  late TextEditingController _ibanController;
  late TextEditingController _notesController;

  double _basePoAmount = 0.0;
  String _currency = 'USD';
  double _selectedPercentage = 30.0;
  bool _isCustomPercentage = false;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isLoadingPrefill = true;
  bool _isSubmitting = false;
  int? _selectedSupplierId;
  int? _primaryPoId;
  GuideMatchResultModel? _guideMatchResult;

  static const List<double> _standardPercentages = [
    10.0,
    20.0,
    30.0,
    50.0,
    100.0,
  ];

  @override
  void initState() {
    super.initState();
    _currency = widget.currency;
    _selectedSupplierId = widget.supplierId;
    _primaryPoId = widget.poId;
    _basePoAmount = widget.totalAmountForeign ?? 0.0;

    _titleController = TextEditingController(
      text: 'Advance Payment (30%) - ${widget.importFileCode} - ${widget.supplierName}',
    );
    _amountController = TextEditingController();
    _exchangeRateController = TextEditingController();
    _beneficiaryController = TextEditingController(text: widget.supplierName);
    _bankNameController = TextEditingController();
    _swiftController = TextEditingController();
    _ibanController = TextEditingController();
    _notesController = TextEditingController();

    _loadPrefillData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _exchangeRateController.dispose();
    _beneficiaryController.dispose();
    _bankNameController.dispose();
    _swiftController.dispose();
    _ibanController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefillData() async {
    setState(() => _isLoadingPrefill = true);
    final data = await AdvancePaymentPrefillService.loadPrefill(
      ref: ref,
      importFileId: widget.importFileId,
      initialCurrency: widget.currency,
      initialSupplierId: widget.supplierId,
      supplierName: widget.supplierName,
      initialPoId: widget.poId,
      totalAmountForeign: widget.totalAmountForeign,
    );

    if (mounted) {
      if (data.exchangeRate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.faFxRateMissing(data.currency),
            severity: AppSeverity.warning,
          ),
        );
      }
      setState(() {
        _basePoAmount = data.basePoAmount;
        _currency = data.currency;
        _selectedSupplierId = data.selectedSupplierId;
        _primaryPoId = data.primaryPoId;
        _beneficiaryController.text = data.beneficiaryName;
        _bankNameController.text = data.bankName;
        _swiftController.text = data.swiftCode;
        _ibanController.text = data.iban;
        _exchangeRateController.text = (data.exchangeRate != null && data.exchangeRate! > 0)
            ? data.exchangeRate!.toStringAsFixed(4)
            : '';

        _calculateAndApplyAmount(_selectedPercentage);
        _isLoadingPrefill = false;
      });
    }
    _loadGuide();
  }

  Future<void> _loadGuide() async {
    try {
      final res =
          await ref.read(experienceGuideProvider.notifier).matchShipment(
                supplier: widget.supplierName,
                paymentMethod: 'ADVANCE_PAYMENT',
                importFileReference: widget.importFileCode,
              );
      if (mounted) {
        setState(() => _guideMatchResult = res);
      }
    } catch (_) {}
  }

  void _calculateAndApplyAmount(double percentage) {
    setState(() {
      _selectedPercentage = percentage;
      _isCustomPercentage = !_standardPercentages.contains(percentage);
      final calculated = _basePoAmount * (percentage / 100.0);
      _amountController.text =
          calculated > 0 ? calculated.toStringAsFixed(2) : '';
      _titleController.text =
          'Advance Payment (${percentage.toStringAsFixed(0)}%) - ${widget.importFileCode} - ${widget.supplierName}';
    });
  }

  void _onAmountManuallyChanged(String val) {
    final amount = double.tryParse(val) ?? 0.0;
    if (_basePoAmount > 0 && amount > 0) {
      final calculatedPct = (amount / _basePoAmount) * 100.0;
      setState(() {
        _selectedPercentage = double.parse(calculatedPct.toStringAsFixed(1));
        _isCustomPercentage =
            !_standardPercentages.contains(_selectedPercentage);
      });
    }
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);
    final created = await AdvancePaymentSubmitHandler.submit(
      context: context,
      ref: ref,
      formKey: _formKey,
      importFileId: widget.importFileId,
      primaryPoId: _primaryPoId,
      selectedSupplierId: _selectedSupplierId,
      projectId: widget.projectId,
      selectedPercentage: _selectedPercentage,
      currency: _currency,
      dueDate: _dueDate,
      titleController: _titleController,
      amountController: _amountController,
      exchangeRateController: _exchangeRateController,
      beneficiaryController: _beneficiaryController,
      bankNameController: _bankNameController,
      swiftController: _swiftController,
      ibanController: _ibanController,
      notesController: _notesController,
    );
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (created != null) {
        Navigator.pop(context, created);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth - 32).clamp(360.0, 740.0);

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
        ),
      ),
      child: SelectionArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogWidth,
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SupplierAdvancePaymentHeader(
                  importFileCode: widget.importFileCode,
                  supplierName: widget.supplierName,
                  isDark: isDark,
                  onClose: () => Navigator.pop(context),
                ),
                const SizedBox(height: 16),
                if (_isLoadingPrefill)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: AppLoadingState(message: context.l10n.faAdvanceLoadingPo),
                  )
                else
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_guideMatchResult != null &&
                                _guideMatchResult!.matchedEntries.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ExperienceGuideAlertBanner(
                                  matchResult: _guideMatchResult!,
                                  supplier: widget.supplierName,
                                ),
                              ),
                            AdvancePaymentCalculationSection(
                              basePoAmount: _basePoAmount,
                              currency: _currency,
                              amountController: _amountController,
                              exchangeRateController: _exchangeRateController,
                              selectedPercentage: _selectedPercentage,
                              isCustomPercentage: _isCustomPercentage,
                              standardPercentages: _standardPercentages,
                              isDark: isDark,
                              onSelectPercentage: _calculateAndApplyAmount,
                              onEnableCustomPercentage: () =>
                                  setState(() => _isCustomPercentage = true),
                              onAmountChanged: _onAmountManuallyChanged,
                              onExchangeRateChanged: () => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            AdvancePaymentBankingSection(
                              titleController: _titleController,
                              beneficiaryController: _beneficiaryController,
                              bankNameController: _bankNameController,
                              swiftController: _swiftController,
                              ibanController: _ibanController,
                              notesController: _notesController,
                              dueDate: _dueDate,
                              onDueDateChanged: (d) => setState(() => _dueDate = d),
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 8,
                  children: [
                    AppButton(
                      label: context.l10n.cancel,
                      variant: AppButtonVariant.secondary,
                      onPressed:
                          _isSubmitting ? null : () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    AppButton(
                      label: _isSubmitting
                          ? (context.l10n.faIssuingNotifying)
                          : (context.l10n.faIssueAndNotify),
                      variant: AppButtonVariant.warning,
                      icon: Icons.send_rounded,
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _handleSubmit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
