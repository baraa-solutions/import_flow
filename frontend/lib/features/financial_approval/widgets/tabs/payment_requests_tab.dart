import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';
import '../dialogs/clone_payment_review_dialog.dart';
import '../financial_ui.dart';
import '../payment_request_details_dialog.dart';
import '../payment_request_form_tab.dart';
import '../search_and_clone_payment_dialog.dart';
import '../payment_requests_tab/payment_linked_po_cloner.dart';
import '../payment_requests_tab/payment_request_prefill_handler.dart';
import '../payment_requests_tab/payment_request_save_handler.dart';
import '../payment_requests_tab/payment_swift_extractor_wrapper.dart';

class PaymentRequestsTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final VoidCallback? onOpenSwiftReconciliation;
  final void Function(int? fileId)? onImportFileChanged;

  const PaymentRequestsTab({
    super.key,
    this.initialImportFileId,
    this.onOpenSwiftReconciliation,
    this.onImportFileChanged,
  });

  @override
  ConsumerState<PaymentRequestsTab> createState() => PaymentRequestsTabState();
}

class PaymentRequestsTabState extends ConsumerState<PaymentRequestsTab> {
  final _paymentFormKey = GlobalKey<FormState>();
  final TextEditingController _payTitleController = TextEditingController();
  final TextEditingController _supplierNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _exchangeRateController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _swiftCodeController = TextEditingController();
  final TextEditingController _ibanController = TextEditingController();
  final TextEditingController _payNotesController = TextEditingController();

  String _paymentType = FinancialUi.advancePaymentCode;
  String _currencyCode = 'USD';
  DateTime _requestDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 12));
  int? _selectedSupplierId;
  int? _paySelectedImportFileId;
  BudgetPrefillModel? _payPrefillData;
  double? _paySelectedPercentage;
  bool _isSavingPayment = false;
  bool _isLoadingPayPrefill = false;

  // Edit Mode
  int? _editingPaymentId;
  String? _editingPaymentCode;
  int? _editingPaymentVersion;

  int? get selectedImportFileId => _paySelectedImportFileId;

  PaymentRequestModel? get _openSameTypeRequest {
    if (_paySelectedImportFileId == null) return null;
    final payments = ref.read(paymentRequestsProvider).valueOrNull ?? [];
    final targetType = FinancialUi.normalizePaymentType(_paymentType);
    return payments.where((p) {
      if (p.importFileId != _paySelectedImportFileId) return false;
      if (!p.isActive) return false;
      if (p.paymentId == _editingPaymentId) return false;
      if (FinancialUi.normalizePaymentType(p.paymentType) != targetType) {
        return false;
      }
      const openStatuses = {'Draft', 'Pending Approval', 'Approved'};
      return openStatuses.contains(p.status);
    }).firstOrNull;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialImportFileId != null) {
      Future.microtask(() {
        _onPayImportFileSelected(widget.initialImportFileId);
      });
    }
  }

  @override
  void dispose() {
    _payTitleController.dispose();
    _supplierNameController.dispose();
    _amountController.dispose();
    _exchangeRateController.dispose();
    _bankNameController.dispose();
    _swiftCodeController.dispose();
    _ibanController.dispose();
    _payNotesController.dispose();
    super.dispose();
  }

  double? _getExchangeRateForCurrency(String currencyCode) =>
      PaymentRequestPrefillHandler.getExchangeRateForCurrency(
          ref, currencyCode);

  String _rateText(double? rate) =>
      (rate != null && rate > 0) ? rate.toStringAsFixed(4) : '';

  void _warnFxMissing(String currency) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, context.l10n.faFxRateMissing(currency),
          severity: AppSeverity.warning),
    );
  }

  void _applyAdvancePercentageToAmount(double pct) {
    setState(() {
      _paySelectedPercentage = pct;
      final baseAmount = _payPrefillData?.totalInvoiceAmount ?? 0.0;
      if (baseAmount > 0) {
        _amountController.text =
            (baseAmount * (pct / 100.0)).toStringAsFixed(2);
      }
    });
  }

  Future<void> _onPayImportFileSelected(int? fileId) async {
    widget.onImportFileChanged?.call(fileId);
    if (fileId == null) {
      setState(() {
        _paySelectedImportFileId = null;
        _payPrefillData = null;
      });
      return;
    }

    setState(() {
      _paySelectedImportFileId = fileId;
      _isLoadingPayPrefill = true;
    });

    try {
      final res = await PaymentRequestPrefillHandler.resolvePrefill(
        ref: ref,
        fileId: fileId,
        defaultCurrency: _currencyCode,
      );

      if (mounted && res != null) {
        if (res.effectiveRate == null) _warnFxMissing(res.currencyCode);

        setState(() {
          _payPrefillData = res.prefillData;
          _payTitleController.text = res.title;
          _selectedSupplierId = res.selectedSupplierId;
          _supplierNameController.text = res.supplierName;
          if (res.paymentType != null && res.paymentType!.isNotEmpty) {
            _paymentType =
                FinancialUi.normalizePaymentType(res.paymentType!);
          }
          if (res.invoiceAmount > 0) {
            _amountController.text = res.invoiceAmount.toStringAsFixed(2);
          } else {
            _amountController.text = '';
          }
          _currencyCode = res.currencyCode;
          _exchangeRateController.text = _rateText(res.effectiveRate);
          _bankNameController.text = res.bankName;
          _swiftCodeController.text = res.swiftCode;
          _ibanController.text = res.iban;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingPayPrefill = false);
    }
  }

  Future<void> _savePaymentRequest() async {
    if (!_paymentFormKey.currentState!.validate()) return;

    final rate = double.tryParse(_exchangeRateController.text.trim());
    if (rate == null || rate <= 0) {
      _warnFxMissing(_currencyCode);
      return;
    }
    setState(() => _isSavingPayment = true);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    final payload = <String, dynamic>{
      'title': _payTitleController.text.trim(),
      'import_file_id': _paySelectedImportFileId,
      'supplier_id': _selectedSupplierId,
      'supplier_name': _supplierNameController.text.trim(),
      'beneficiary_name': _supplierNameController.text.trim(),
      'payment_type': _paymentType,
      'requested_amount': amount,
      'currency_code': _currencyCode,
      'exchange_rate': rate,
      'request_date': _requestDate.toString().substring(0, 10),
      'due_date': _dueDate.toString().substring(0, 10),
      'bank_name': _bankNameController.text.trim(),
      'swift_code': _swiftCodeController.text.trim(),
      'iban_account_no': _ibanController.text.trim(),
      'notes': _payNotesController.text.trim(),
      'advance_percentage': _paySelectedPercentage,
    };

    try {
      final saved = await PaymentRequestSaveHandler.save(
        context: context,
        ref: ref,
        payload: payload,
        editingPaymentId: _editingPaymentId,
        editingPaymentVersion: _editingPaymentVersion,
        onDiscardAndReload: () {
          if (mounted) {
            setState(() {
              _editingPaymentId = null;
              _editingPaymentCode = null;
              _editingPaymentVersion = null;
            });
          }
        },
        onRetry: _savePaymentRequest,
      );

      if (mounted && saved != null) {
        setState(() {
          _editingPaymentId = null;
          _editingPaymentCode = null;
          _editingPaymentVersion = null;
        });
        _showPaymentDetailsDialog(saved);
      }
    } finally {
      if (mounted) setState(() => _isSavingPayment = false);
    }
  }

  void loadPaymentRequestForEdit(PaymentRequestModel p) {
    setState(() {
      _editingPaymentId = p.paymentId;
      _editingPaymentCode = p.paymentCode;
      _editingPaymentVersion = p.version;
      _paySelectedImportFileId = p.importFileId;
      _payTitleController.text = p.title;
      _selectedSupplierId = p.supplierId;
      _supplierNameController.text = p.beneficiaryName ?? p.supplierName;
      _paymentType = FinancialUi.normalizePaymentType(p.paymentType);
      _amountController.text = p.requestedAmount.toStringAsFixed(2);
      _currencyCode = p.currencyCode;
      _exchangeRateController.text = _rateText(p.exchangeRate);
      _bankNameController.text = p.bankName ?? '';
      _swiftCodeController.text = p.swiftCode ?? '';
      _ibanController.text = p.ibanAccountNo ?? '';
      _payNotesController.text = p.notes ?? '';
      _paySelectedPercentage = p.advancePercentage;
      _dueDate = DateTime.tryParse(p.dueDate) ??
          DateTime.now().add(const Duration(days: 12));
      _requestDate = p.requestDate.isNotEmpty
          ? (DateTime.tryParse(p.requestDate) ?? DateTime.now())
          : DateTime.now();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        context.l10n.paymentLoadedForEditMsg(p.paymentCode),
        severity: AppSeverity.info,
      ),
    );
  }

  void _openSearchAndClonePaymentDialog() {
    final payments = ref.read(paymentRequestsProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: SearchAndClonePaymentDialog(
            payments: payments,
            onSelectPayment: (p) => _openClonePaymentReviewDialog(p),
          ),
        ),
      ),
    );
  }

  void _openClonePaymentReviewDialog(PaymentRequestModel p) {
    ClonePaymentReviewDialog.show(
      context: context,
      ref: ref,
      payment: p,
      onCloned: (cloned) {
        loadPaymentRequestForEdit(cloned);
      },
    );
  }

  void _cloneLinkedPoItem(LinkedPOItemModel po) {
    if (_payPrefillData == null) return;
    setState(() {
      _payPrefillData = PaymentLinkedPoCloner.clonePoItem(
        currentPrefill: _payPrefillData!,
        po: po,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        context.l10n.poAllocationClonedSuccess,
        severity: AppSeverity.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPaymentDetailsDialog(PaymentRequestModel pay) {
    PaymentRequestDetailsDialog.show(
      context,
      payment: pay,
      onOpenSwiftReconciliation: widget.onOpenSwiftReconciliation,
      onStatusChanged: () {
        ref.read(paymentRequestsProvider.notifier).fetchPaymentRequests();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: PaymentRequestFormTab(
        formKey: _paymentFormKey,
        editingPaymentId: _editingPaymentId,
        editingPaymentCode: _editingPaymentCode,
        onCancelEdit: () {
          setState(() {
            _editingPaymentId = null;
            _editingPaymentCode = null;
            _payTitleController.clear();
            _supplierNameController.clear();
            _amountController.clear();
            _bankNameController.clear();
            _swiftCodeController.clear();
            _ibanController.clear();
            _payNotesController.clear();
            _payPrefillData = null;
            _paySelectedPercentage = null;
          });
        },
        payTitleController: _payTitleController,
        supplierNameController: _supplierNameController,
        amountController: _amountController,
        exchangeRateController: _exchangeRateController,
        bankNameController: _bankNameController,
        swiftCodeController: _swiftCodeController,
        ibanController: _ibanController,
        payNotesController: _payNotesController,
        currencyCode: _currencyCode,
        onCurrencyChanged: (val) {
          setState(() => _currencyCode = val);
        },
        requestDate: _requestDate,
        onRequestDateChanged: (val) => setState(() => _requestDate = val),
        dueDate: _dueDate,
        onDueDateChanged: (val) => setState(() => _dueDate = val),
        selectedImportFileId: _paySelectedImportFileId,
        onImportFileChanged: (val) => _onPayImportFileSelected(val),
        paymentType: _paymentType,
        onPaymentTypeChanged: (val) {
          setState(() => _paymentType = val);
        },
        selectedSupplierId: _selectedSupplierId,
        onSupplierChanged: (val) {
          setState(() => _selectedSupplierId = val);
        },
        payPrefillData: _payPrefillData,
        isLoadingPayPrefill: _isLoadingPayPrefill,
        isSavingPayment: _isSavingPayment,
        onSavePaymentRequest: _savePaymentRequest,
        onSearchAndClone: _openSearchAndClonePaymentDialog,
        onCloneLinkedPoItem: (po) => _cloneLinkedPoItem(po),
        openSameTypeRequest: _openSameTypeRequest,
        onViewOpenSameTypeRequest: (pay) => loadPaymentRequestForEdit(pay),
        selectedPercentage: _paySelectedPercentage,
        onSelectPercentage: (pct) => _applyAdvancePercentageToAmount(pct),
        swiftExtractorWidget: PaymentSwiftExtractorWrapper(
          amountController: _amountController,
          exchangeRateController: _exchangeRateController,
          supplierNameController: _supplierNameController,
          bankNameController: _bankNameController,
          swiftCodeController: _swiftCodeController,
          ibanController: _ibanController,
          payTitleController: _payTitleController,
          payNotesController: _payNotesController,
          getExchangeRateForCurrency: _getExchangeRateForCurrency,
          formatRateText: _rateText,
          currentImportFileId: _paySelectedImportFileId,
          onApplyFields: ({
            required Map<String, dynamic> summary,
            required String currency,
            required DateTime? dueDate,
            required int? supplierId,
            required int? importFileId,
          }) {
            setState(() {
              _currencyCode = currency;
              if (dueDate != null) _dueDate = dueDate;
              if (supplierId != null) _selectedSupplierId = supplierId;
              if (importFileId != null && _paySelectedImportFileId == null) {
                _paySelectedImportFileId = importFileId;
                widget.onImportFileChanged?.call(importFileId);
              }
            });
          },
        ),
      ),
    );
  }
}
