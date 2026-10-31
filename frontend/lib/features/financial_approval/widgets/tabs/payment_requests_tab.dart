import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../../../currencies/providers/currencies_provider.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../../suppliers/providers/suppliers_provider.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';
import '../dialogs/clone_payment_review_dialog.dart';
import '../financial_ui.dart';
import '../payment_request_details_dialog.dart';
import '../payment_request_form_tab.dart';
import '../search_and_clone_payment_dialog.dart';
import '../swift_ocr_extractor_card.dart';

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
  final TextEditingController _paySwiftRawTextController =
      TextEditingController();

  bool _isPaySwiftExpanded = true;
  bool _isPaySwiftExtracting = false;
  Map<String, dynamic>? _payExtractedSwiftSummary;
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
    _paySwiftRawTextController.dispose();
    super.dispose();
  }

  double? _getExchangeRateForCurrency(String currencyCode) {
    if (currencyCode.toUpperCase() == 'EGP') return 1.0;
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    final cur = currencies
        .where(
            (c) => c.currencyCode.toUpperCase() == currencyCode.toUpperCase())
        .firstOrNull;
    if (cur != null) {
      if (cur.isBaseCurrency) return 1.0;
      if (cur.latestCommercialRate != null && cur.latestCommercialRate! > 0) {
        return cur.latestCommercialRate!;
      }
    }
    return null;
  }

  Future<BudgetPrefillModel?> _fetchPrefillOrNull(int fileId) async {
    try {
      return await ref
          .read(importBudgetsProvider.notifier)
          .fetchBudgetPrefill(fileId);
    } catch (e) {
      _showApiError(e);
      return null;
    }
  }

  bool _isVersionConflict(Object e) {
    if (e is! DioException || e.response?.statusCode != 409) return false;
    final data = e.response?.data;
    final detail = (data is Map)
        ? (data['detail'] is Map ? data['detail'] as Map : data)
        : const {};
    return detail.containsKey('current_version') ||
        detail.containsKey('submitted_version');
  }

  bool _isCodedError(Object e) {
    if (e is! DioException) return false;
    final data = e.response?.data;
    return data is Map && data['detail'] is Map;
  }

  void _showApiError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, ApiError.message(e),
          severity: AppSeverity.danger),
    );
  }

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
      final prefill = await _fetchPrefillOrNull(fileId);
      final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
      final impFile =
          importFiles.where((f) => f.importFileId == fileId).firstOrNull;

      double calculatedInvoiceAmount = 0.0;
      String calculatedCurrency = _currencyCode;

      if (prefill != null && prefill.totalInvoiceAmount > 0) {
        calculatedInvoiceAmount = prefill.totalInvoiceAmount;
        if (prefill.invoiceCurrency.isNotEmpty) {
          calculatedCurrency = prefill.invoiceCurrency;
        }
      }

      final suppliersList = ref.read(suppliersProvider).valueOrNull ?? [];
      final targetSupId = impFile?.supplierId ?? prefill?.supplierId;
      final supObj = suppliersList
          .where((s) =>
              (targetSupId != null && s.supplierId == targetSupId) ||
              (impFile != null &&
                  s.companyName.trim().toLowerCase() ==
                      impFile.supplierName.trim().toLowerCase()) ||
              (prefill != null &&
                  s.companyName.trim().toLowerCase() ==
                      prefill.supplierName.trim().toLowerCase()))
          .firstOrNull;

      final effectiveSupplierId = supObj?.supplierId ?? targetSupId;
      final effectiveSupplierName = supObj?.companyName ??
          (impFile != null && impFile.supplierName.isNotEmpty
              ? impFile.supplierName
              : (prefill?.beneficiaryName ?? prefill?.supplierName ?? ''));
      final effectiveBankName =
          (supObj?.bankName != null && supObj!.bankName!.isNotEmpty)
              ? supObj.bankName!
              : (prefill?.bankName ?? '');
      final effectiveSwiftCode =
          (supObj?.swiftCode != null && supObj!.swiftCode!.isNotEmpty)
              ? supObj.swiftCode!
              : (prefill?.swiftCode ?? '');
      final effectiveIban = (supObj?.iban != null && supObj!.iban!.isNotEmpty)
          ? supObj.iban!
          : ((supObj?.accountNumber != null &&
                  supObj!.accountNumber!.isNotEmpty)
              ? supObj.accountNumber!
              : (prefill?.iban ?? prefill?.accountNumber ?? ''));

      if (mounted) {
        final dynamicRate = _getExchangeRateForCurrency(calculatedCurrency);
        final double? effRate = (dynamicRate != null && dynamicRate > 0)
            ? dynamicRate
            : (prefill != null && prefill.exchangeRate > 0
                ? prefill.exchangeRate
                : null);
        if (effRate == null) _warnFxMissing(calculatedCurrency);

        final fCode = impFile?.primaryNameWithCode ??
            prefill?.importFileTitle ??
            'IMP-$fileId';
        final compName = impFile?.companyName ?? '';

        setState(() {
          _payPrefillData = prefill;
          _payTitleController.text =
              compName.isNotEmpty ? '$fCode - $compName' : fCode;
          _selectedSupplierId = effectiveSupplierId;
          _supplierNameController.text = effectiveSupplierName;
          final summary = prefill?.paymentTermsSummary;
          if (summary != null && summary.isNotEmpty) {
            _paymentType = FinancialUi.normalizePaymentType(summary);
          }

          if (calculatedInvoiceAmount > 0) {
            _amountController.text = calculatedInvoiceAmount.toStringAsFixed(2);
          } else {
            _amountController.text = '';
          }

          _currencyCode = calculatedCurrency;
          _exchangeRateController.text = _rateText(effRate);
          _bankNameController.text = effectiveBankName;
          _swiftCodeController.text = effectiveSwiftCode;
          _ibanController.text = effectiveIban;
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
      if (_editingPaymentId != null) {
        if (_editingPaymentVersion != null) {
          payload['version'] = _editingPaymentVersion;
        }
        final updated = await ref
            .read(paymentRequestsProvider.notifier)
            .updatePaymentRequest(_editingPaymentId!, payload);
        if (mounted && updated != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              context.l10n.paymentRequestUpdatedSuccess(updated.paymentCode),
              severity: AppSeverity.success,
            ),
          );
          setState(() {
            _editingPaymentId = null;
            _editingPaymentCode = null;
            _editingPaymentVersion = null;
          });
          _showPaymentDetailsDialog(updated);
        }
      } else {
        final created = await ref
            .read(paymentRequestsProvider.notifier)
            .createPaymentRequest(payload);
        if (mounted && created != null) {
          final taskMsg = (created.smartTaskCode != null)
              ? ' (${created.smartTaskCode})'
              : '';
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              '${context.l10n.paymentRequestCreatedSuccess(created.paymentCode)}$taskMsg',
              severity: AppSeverity.success,
            ),
          );
          _showPaymentDetailsDialog(created);
        }
      }
    } catch (e) {
      if (_isVersionConflict(e)) {
        final data = (e as DioException).response?.data;
        final conflict = (data is Map<String, dynamic> && data['detail'] is Map)
            ? Map<String, dynamic>.from(data['detail'] as Map)
            : (data is Map<String, dynamic> ? data : <String, dynamic>{});
        if (mounted) {
          final resolution = await ConcurrencyConflictDialog.show(
            context,
            entityName:
                conflict['entity'] as String? ?? 'PaymentRequestSession',
            recordId: conflict['record_id'] ?? _editingPaymentId,
            currentVersion: (conflict['current_version'] as num?)?.toInt() ??
                ((_editingPaymentVersion ?? 1) + 1),
            submittedVersion:
                (conflict['submitted_version'] as num?)?.toInt() ??
                    (_editingPaymentVersion ?? 1),
            updatedAt: conflict['updated_at'] as String?,
            updatedBy: conflict['updated_by'] as String?,
            serverMessage: conflict['message'] as String?,
            currentDraftData: payload,
          );
          if (mounted && resolution == ConcurrencyResolution.discardAndReload) {
            setState(() {
              _editingPaymentId = null;
              _editingPaymentCode = null;
              _editingPaymentVersion = null;
            });
            await ref
                .read(paymentRequestsProvider.notifier)
                .fetchPaymentRequests();
          }
        }
        return;
      }
      if (mounted && _isCodedError(e)) {
        _showApiError(e);
      } else if (mounted) {
        await showErrorDetailsDialog(
          context,
          title: context.l10n.savePaymentFailedTitle,
          error: e,
          onRetry: () async {
            await _savePaymentRequest();
          },
        );
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
    final l = context.l10n;

    final clonedItem = LinkedPOItemModel(
      poId: 0,
      poNumber: '${po.poNumber}${TableRowCloneHelper.copyCodeSuffix}',
      poReference: TableRowCloneHelper.withCodeSuffix(po.poReference),
      piNumber: po.piNumber,
      projectId: po.projectId,
      projectName: po.projectName,
      paymentTerms: po.paymentTerms,
      currency: po.currency,
      totalAmount: po.totalAmount,
      status: 'Draft',
    );

    setState(() {
      final currentList =
          List<LinkedPOItemModel>.from(_payPrefillData!.linkedPos);
      final idx = currentList.indexOf(po);
      if (idx >= 0) {
        currentList.insert(idx + 1, clonedItem);
      } else {
        currentList.add(clonedItem);
      }
      _payPrefillData = BudgetPrefillModel(
        importFileId: _payPrefillData!.importFileId,
        importFileCode: _payPrefillData!.importFileCode,
        importFileTitle: _payPrefillData!.importFileTitle,
        incoterm: _payPrefillData!.incoterm,
        supplierId: _payPrefillData!.supplierId,
        supplierName: _payPrefillData!.supplierName,
        beneficiaryName: _payPrefillData!.beneficiaryName,
        bankName: _payPrefillData!.bankName,
        swiftCode: _payPrefillData!.swiftCode,
        accountNumber: _payPrefillData!.accountNumber,
        iban: _payPrefillData!.iban,
        paymentTermsSummary: _payPrefillData!.paymentTermsSummary,
        linkedPos: currentList,
        totalInvoiceAmount:
            _payPrefillData!.totalInvoiceAmount + po.totalAmount,
        invoiceCurrency: _payPrefillData!.invoiceCurrency,
        totalInvoiceAmountEgp: _payPrefillData!.totalInvoiceAmountEgp +
            (po.totalAmount * _payPrefillData!.exchangeRate),
        estimatedFreightCost: _payPrefillData!.estimatedFreightCost,
        freightCurrency: _payPrefillData!.freightCurrency,
        estimatedFreightCostEgp: _payPrefillData!.estimatedFreightCostEgp,
        estimatedCustomsDutiesEgp: _payPrefillData!.estimatedCustomsDutiesEgp,
        estimatedClearanceFeesEgp: _payPrefillData!.estimatedClearanceFeesEgp,
        estimatedGrandTotalEgp: _payPrefillData!.estimatedGrandTotalEgp +
            (po.totalAmount * _payPrefillData!.exchangeRate),
        exchangeRate: _payPrefillData!.exchangeRate,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        l.poAllocationClonedSuccess,
        severity: AppSeverity.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _applySwiftParsedData(Map<String, dynamic> p, {String? fileName}) {
    setState(() {
      _payExtractedSwiftSummary = p;
      if (p['amount'] != null && (p['amount'] as num) > 0) {
        _amountController.text = (p['amount'] as num).toString();
      }
      if (p['currency'] != null && (p['currency'] as String).isNotEmpty) {
        _currencyCode = (p['currency'] as String).toUpperCase();
        _exchangeRateController.text =
            _rateText(_getExchangeRateForCurrency(_currencyCode));
      }
      if (p['beneficiary_name'] != null &&
          (p['beneficiary_name'] as String).isNotEmpty) {
        _supplierNameController.text = p['beneficiary_name'];
        final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
        final bName = (p['beneficiary_name'] as String)
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '');
        final matchedSup = suppliers.where((s) {
          final sName =
              s.companyName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          return sName.isNotEmpty &&
              (sName.contains(bName) || bName.contains(sName));
        }).firstOrNull;
        if (matchedSup != null) {
          _selectedSupplierId = matchedSup.supplierId;
          if (matchedSup.bankName != null && matchedSup.bankName!.isNotEmpty) {
            _bankNameController.text = matchedSup.bankName!;
          }
          if (matchedSup.swiftCode != null &&
              matchedSup.swiftCode!.isNotEmpty &&
              (p['beneficiary_bank_swift'] == null ||
                  (p['beneficiary_bank_swift'] as String).isEmpty)) {
            _swiftCodeController.text = matchedSup.swiftCode!;
          }
          final supIban = matchedSup.iban ?? matchedSup.accountNumber;
          if (supIban != null &&
              supIban.isNotEmpty &&
              (p['beneficiary_account_or_iban'] == null ||
                  (p['beneficiary_account_or_iban'] as String).isEmpty)) {
            _ibanController.text = supIban;
          }
        }
      }
      if (p['beneficiary_bank_swift'] != null &&
          (p['beneficiary_bank_swift'] as String).isNotEmpty) {
        _swiftCodeController.text = p['beneficiary_bank_swift'];
      }
      if (p['beneficiary_account_or_iban'] != null &&
          (p['beneficiary_account_or_iban'] as String).isNotEmpty) {
        _ibanController.text = p['beneficiary_account_or_iban'];
      }
      if (p['value_date'] != null && (p['value_date'] as String).isNotEmpty) {
        try {
          final d = DateTime.parse(p['value_date']);
          _dueDate = d;
        } catch (_) {}
      }

      final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
      final piNum = p['pi_number']
          ?.toString()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      final poNum = p['po_number']
          ?.toString()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      final transRef = p['transaction_reference']
          ?.toString()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');

      if (_paySelectedImportFileId == null) {
        final matchedFile = importFiles.where((f) {
          final fCode = f.importFileCode
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '');
          final cNum = (f.customFileNumber ?? '')
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '');
          final pNum = (f.poNumber ?? '')
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (piNum != null &&
              piNum.isNotEmpty &&
              (fCode.contains(piNum) ||
                  cNum.contains(piNum) ||
                  pNum.contains(piNum))) {
            return true;
          }
          if (poNum != null &&
              poNum.isNotEmpty &&
              (fCode.contains(poNum) ||
                  cNum.contains(poNum) ||
                  pNum.contains(poNum))) {
            return true;
          }
          if (transRef != null &&
              transRef.isNotEmpty &&
              (fCode.contains(transRef) || cNum.contains(transRef))) {
            return true;
          }
          return false;
        }).firstOrNull;
        if (matchedFile != null) {
          _paySelectedImportFileId = matchedFile.importFileId;
          widget.onImportFileChanged?.call(matchedFile.importFileId);
        }
      }

      final l = context.l10n;
      if (_payTitleController.text.trim().isEmpty &&
          p['beneficiary_name'] != null) {
        final refNo = p['transaction_reference'] ?? '';
        final piText =
            p['pi_number'] != null ? ' - PI: ${p['pi_number']}' : '';
        _payTitleController.text =
            '${l.swiftPaymentPrefix}: ${p['beneficiary_name']}$piText ($refNo)';
      }
      final notesParts = <String>[];
      if (p['transaction_reference'] != null) {
        notesParts.add('SWIFT Ref: ${p['transaction_reference']}');
      }
      if (p['pi_number'] != null) notesParts.add('PI: ${p['pi_number']}');
      if (p['ordering_customer_name'] != null) {
        notesParts
            .add('${l.orderingCustomerPrefix}: ${p['ordering_customer_name']}');
      }
      if (p['payment_details'] != null) {
        notesParts.add('${l.paymentDetailsPrefix}: ${p['payment_details']}');
      }
      if (notesParts.isNotEmpty) {
        _payNotesController.text = notesParts.join(' | ');
      }
    });

    if (mounted) {
      final l = context.l10n;
      final msg = fileName != null
          ? l.swiftDataExtractedSuccess(fileName)
          : l.swiftMatchedSuccess;
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, msg, severity: AppSeverity.success),
      );
    }
  }

  Map<String, dynamic> _parseSwiftClientFallback(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) {
      return {'success': false, 'error': context.l10n.emptyTextError};
    }

    String? transRef;
    final refMatch = RegExp(
            r'(?:^|[\r\n])\s*:?20(?:/TRANSACTION\s+REFERENCE(?:\s+NUMBER)?)?\s*[:/]?\s*([^\r\n]+)',
            caseSensitive: false)
        .firstMatch(text);
    if (refMatch != null) {
      final rawVal = refMatch.group(1)?.trim() ?? '';
      final parts = rawVal
          .split('|')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      transRef = parts.isNotEmpty ? parts.first : rawVal;
    } else {
      final fbRef = RegExp(
              r'(?:Reference(?:\s+No|\s+Number)?|TRN|Ref\s*#?|Transaction\s+(?:Ref|Reference|Id)|Bank\s+Ref|رقم\s+(?:المرجع|المعاملة|الحوالة|العملية)|الرقم\s+المرجعي)\s*[:=-]?\s*([A-Za-z0-9/\-_.]+)',
              caseSensitive: false)
          .firstMatch(text);
      if (fbRef != null) {
        transRef = fbRef.group(1)?.trim();
      }
    }
    if (transRef != null) {
      transRef = transRef.replaceAll(RegExp(r'^[ |:/]+|[ |:/]+$'), '');
    }

    String currency = 'USD';
    double amount = 0.0;
    String? valueDate;

    final valMatch = RegExp(
            r'(?:^|[\r\n])\s*:?32A(?:/Value\s+Date,?\s*CCY,?\s*Amount)?\s*[:/]?\s*(\d{6})\s*([A-Za-z0-9]{3})\s*([0-9.,]+)',
            caseSensitive: false)
        .firstMatch(text);
    if (valMatch != null) {
      final rawDate = valMatch.group(1)!;
      var rawCurr = valMatch.group(2)!.toUpperCase();
      if (rawCurr == 'U5D' || rawCurr == 'U50' || rawCurr == 'US0') {
        rawCurr = 'USD';
      }
      if (rawCurr == 'E0R' || rawCurr == 'EVR' || rawCurr == 'FUR') {
        rawCurr = 'EUR';
      }
      if (rawCurr == 'E6P' || rawCurr == 'ECP') rawCurr = 'EGP';
      if (rawCurr == '6BP') rawCurr = 'GBP';
      currency = rawCurr;

      final rawAmtStr = valMatch.group(3)!.trim();
      if (!rawAmtStr.contains(',') &&
          !rawAmtStr.contains('.') &&
          rawAmtStr.length > 4 &&
          rawAmtStr.endsWith('00')) {
        amount = (double.tryParse(rawAmtStr) ?? 0.0) / 100.0;
      } else {
        final rawAmt = rawAmtStr.replaceAll(',', '.');
        amount = double.tryParse(rawAmt) ?? 0.0;
      }
      try {
        final yy = int.parse(rawDate.substring(0, 2));
        final mm = int.parse(rawDate.substring(2, 4));
        final dd = int.parse(rawDate.substring(4, 6));
        final y = yy < 70 ? 2000 + yy : 1900 + yy;
        valueDate =
            '$y-${mm.toString().padLeft(2, '0')}-${dd.toString().padLeft(2, '0')}';
      } catch (_) {}
    } else {
      final labeledAmt = RegExp(
              r'(?:Amount|Value|Sum|Total(?:\s+Amount)?|المبلغ|القيمة|الصافي|إجمالي\s+المبلغ)\s*[:=]?\s*(?:([A-Za-z]{3}|\$|€|£|¥)\s*([0-9.,]+)|([0-9.,]+)\s*([A-Za-z]{3}|\$|€|£|¥))',
              caseSensitive: false)
          .firstMatch(text);
      if (labeledAmt != null) {
        final c1 = labeledAmt.group(1);
        final a1 = labeledAmt.group(2);
        final a2 = labeledAmt.group(3);
        final c2 = labeledAmt.group(4);
        final rawC = c1 ?? c2 ?? 'USD';
        final rawA = a1 ?? a2 ?? '0';

        if (rawC == '\$') {
          currency = 'USD';
        } else if (rawC == '€') {
          currency = 'EUR';
        } else if (rawC == '£') {
          currency = 'GBP';
        } else if (rawC == '¥') {
          currency = 'CNY';
        } else if (rawC.length == 3) {
          currency = rawC.toUpperCase();
        }

        var cleanA = rawA.trim().replaceAll(RegExp(r'\.+$'), '');
        if (cleanA.contains(',') && cleanA.contains('.')) {
          if (cleanA.indexOf(',') < cleanA.indexOf('.')) {
            cleanA = cleanA.replaceAll(',', '');
          } else {
            cleanA = cleanA.replaceAll('.', '').replaceAll(',', '.');
          }
        } else if (cleanA.contains(',')) {
          if (cleanA.split(',').last.length == 2) {
            cleanA = cleanA.replaceAll(',', '.');
          } else {
            cleanA = cleanA.replaceAll(',', '');
          }
        }
        amount = double.tryParse(cleanA) ?? 0.0;
      }
    }

    String? beneficiaryAccount;
    String? beneficiaryName;
    final benMatch = RegExp(
            r'(?:^|[\r\n])\s*:?59[A]?\s*(?:/Beneficiary\s+Customer)?\s*[:/]?\s*(?:/([A-Za-z0-9]+))?\s*\n?([^\n\r:]+)(?:\n([^\n\r:]+))?',
            caseSensitive: false)
        .firstMatch(text);
    if (benMatch != null) {
      beneficiaryAccount = benMatch.group(1)?.trim();
      beneficiaryName = benMatch.group(2)?.trim();
    } else {
      final benGen = RegExp(
              r'(?:Beneficiary(?:\s+Customer|\s+Name)?|Payee|To\s+the\s+order\s+of|المستفيد|المورد|اسم\s+المستفيد|اسم\s+المورد)\s*[:=]\s*([^\r\n]+)',
              caseSensitive: false)
          .firstMatch(text);
      if (benGen != null) beneficiaryName = benGen.group(1)?.trim();
      final ibanGen = RegExp(
              r'(?:IBAN|Account(?:\s+No|\s+Number)?|رقم\s+(?:الحساب|الآيبان)|الآيبان)\s*[:=]?\s*([A-Za-z0-9]{8,34})',
              caseSensitive: false)
          .firstMatch(text);
      if (ibanGen != null) beneficiaryAccount = ibanGen.group(1)?.trim();
    }

    String? swiftCode;
    final swiftMatch = RegExp(
            r'(?:^|[\r\n])\s*:?57[AD]?(?:/Account\s+with\s+Bank)?\s*[:/]?\s*([A-Za-z0-9]{8,11})',
            caseSensitive: false)
        .firstMatch(text);
    if (swiftMatch != null) {
      swiftCode = swiftMatch.group(1)?.trim().toUpperCase();
    } else {
      final swiftGen = RegExp(
              r'(?:SWIFT(?:\s+Code)?|BIC|Bank\s+SWIFT|كود\s+السويفت|سويفت)\s*[:=]?\s*([A-Za-z0-9]{8,11})',
              caseSensitive: false)
          .firstMatch(text);
      if (swiftGen != null) swiftCode = swiftGen.group(1)?.trim().toUpperCase();
    }

    String? piNumber;
    String? details;
    final dtMatch = RegExp(
            r'(?:^|[\r\n])\s*:?70(?:/DETAILS\s+OF\s+PAYMENT)?\s*[:/]?\s*([^\r\n:]+(?:\n[^\r\n:]+)?)',
            caseSensitive: false)
        .firstMatch(text);
    if (dtMatch != null) {
      details = dtMatch.group(1)?.trim();
      final piMatch = RegExp(
              r'(?:PI|Proforma\s+Invoice|فاتورة\s+مبدئية)\s*(?:NO\.?|#)?\s*([A-Za-z0-9\-_.]+)',
              caseSensitive: false)
          .firstMatch(details ?? '');
      if (piMatch != null) piNumber = piMatch.group(1)?.trim();
    } else {
      final piMatch = RegExp(
              r'(?:PI|Proforma\s+Invoice|فاتورة\s+مبدئية)\s*(?:NO\.?|#)?\s*([A-Za-z0-9\-_.]+)',
              caseSensitive: false)
          .firstMatch(text);
      if (piMatch != null) piNumber = piMatch.group(1)?.trim();
    }

    String? orderingCustomer;
    final ordMatch = RegExp(
            r'(?:^|[\r\n])\s*:?50[KA]?(?:/ORDERING\s+CUST(?:OMER)?)?\s*[:/]?\s*(?:/([A-Za-z0-9]+))?\s*\n?([^\n\r:]+)(?:\n([^\n\r:]+))?',
            caseSensitive: false)
        .firstMatch(text);
    if (ordMatch != null) {
      orderingCustomer = ordMatch.group(2)?.trim();
    } else {
      final ordGen = RegExp(
              r'(?:Ordering\s+Customer|Applicant|Sender|Remitter|الآمر\s+بالتحويل|طالب\s+التحويل|الشركة\s+المستوردة|العميل)\s*[:=]\s*([^\r\n]+)',
              caseSensitive: false)
          .firstMatch(text);
      if (ordGen != null) orderingCustomer = ordGen.group(1)?.trim();
    }

    return {
      'success': true,
      'transaction_reference': transRef,
      'amount': amount,
      'currency': currency,
      'value_date': valueDate,
      'beneficiary_name': beneficiaryName,
      'beneficiary_account_or_iban': beneficiaryAccount,
      'beneficiary_bank_swift': swiftCode,
      'payment_details': details,
      'pi_number': piNumber,
      'ordering_customer_name': orderingCustomer,
    };
  }

  Future<void> _autoFillFromSwiftText(String text) async {
    setState(() => _isPaySwiftExtracting = true);
    try {
      Map<String, dynamic>? parsed;
      try {
        final res = await ref
            .read(paymentRequestsProvider.notifier)
            .smartExtractSwift(rawText: text);
        if (res['success'] == true && res['parsed_swift'] != null) {
          parsed = res['parsed_swift'] as Map<String, dynamic>;
        }
      } catch (_) {}

      if (parsed == null ||
          ((parsed['amount'] as num?) == 0 &&
              parsed['beneficiary_name'] == null)) {
        final clientFallback = _parseSwiftClientFallback(text);
        if (clientFallback['success'] == true) {
          parsed = clientFallback;
        }
      }

      if (parsed != null) {
        _applySwiftParsedData(parsed);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              context.l10n.swiftTextParseError,
              severity: AppSeverity.warning,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isPaySwiftExtracting = false);
    }
  }

  Future<void> _autoFillFromSwiftFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'docx',
          'doc',
          'xlsx',
          'xls',
          'csv',
          'jpg',
          'jpeg',
          'png',
          'webp',
          'bmp',
          'txt'
        ],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _isPaySwiftExtracting = true);

      final res = await ref
          .read(paymentRequestsProvider.notifier)
          .smartExtractSwiftFromFile(
            fileBytes: file.bytes!,
            filename: file.name,
          );
      if (res['success'] == true && res['parsed_swift'] != null) {
        if (res['raw_text'] != null &&
            (res['raw_text'] as String).isNotEmpty) {
          _paySwiftRawTextController.text = res['raw_text'] as String;
        }
        _applySwiftParsedData(res['parsed_swift'] as Map<String, dynamic>,
            fileName: file.name);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              context.l10n.swiftFileExtractError(res['error'].toString()),
              severity: AppSeverity.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.swiftFileExtractError(ApiError.message(e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPaySwiftExtracting = false);
    }
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

  Widget _buildPaySwiftExtractorWidget() {
    return SwiftOcrExtractorCard(
      rawSwiftTextController: _paySwiftRawTextController,
      isSmartSectionExpanded: _isPaySwiftExpanded,
      onToggleExpanded: () =>
          setState(() => _isPaySwiftExpanded = !_isPaySwiftExpanded),
      isExtracting: _isPaySwiftExtracting,
      onPickAndExtractFile: () => _autoFillFromSwiftFile(),
      onExtractFromText: () =>
          _autoFillFromSwiftText(_paySwiftRawTextController.text),
      isAutoFillMode: true,
      autoFillSummary: _payExtractedSwiftSummary,
      onReset: () {
        setState(() {
          _payExtractedSwiftSummary = null;
          _paySwiftRawTextController.clear();
        });
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
        swiftExtractorWidget: _buildPaySwiftExtractorWidget(),
      ),
    );
  }
}
