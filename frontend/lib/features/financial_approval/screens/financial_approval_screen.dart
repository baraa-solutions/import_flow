import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/widgets/concurrency_conflict_dialog.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../../../core/widgets/master_data_toolbar.dart';
import '../../../core/widgets/error_details_dialog.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../models/financial_approval_model.dart';
import '../providers/financial_approval_provider.dart';
import '../services/financial_export_service.dart';
import '../../../core/widgets/metric_card.dart';
import '../widgets/financial_ui.dart';
import '../widgets/saved_budgets_registry_tab.dart';
import '../widgets/async_action_button.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../../../core/widgets/table_row_clone_helper.dart';
import '../widgets/search_and_clone_payment_dialog.dart';
import '../widgets/search_and_clone_budget_dialog.dart';
import '../../simulation/widgets/what_if_simulator_dialog.dart';
import 'swift_reconciliation_screen.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/widgets/recalculate_button.dart';

import 'package:frontend/core/widgets/ltr_text.dart';

class FinancialApprovalScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  final int? initialImportFileId;
  const FinancialApprovalScreen(
      {super.key, this.initialIndex = 0, this.initialImportFileId});

  @override
  ConsumerState<FinancialApprovalScreen> createState() =>
      _FinancialApprovalScreenState();
}

class _FinancialApprovalScreenState
    extends ConsumerState<FinancialApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Payment Request Form State (BP-012)
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

  // Import Budget Form State (BP-013)
  final _budgetFormKey = GlobalKey<FormState>();
  final TextEditingController _bgtTitleController = TextEditingController();
  final TextEditingController _invoiceEgpController =
      TextEditingController();
  final TextEditingController _invoiceForeignController =
      TextEditingController();
  final TextEditingController _freightEgpController =
      TextEditingController();
  final TextEditingController _freightForeignController =
      TextEditingController();
  final TextEditingController _customsEgpController =
      TextEditingController();
  final TextEditingController _clearanceEgpController =
      TextEditingController();
  final TextEditingController _bgtExchangeRateController =
      TextEditingController();
  final TextEditingController _bgtFreightRateController =
      TextEditingController();
  final TextEditingController _bgtNotesController = TextEditingController();

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

  String _bgtInvoiceCurrency = 'USD';
  String _bgtFreightCurrency = 'USD';
  int? _bgtSelectedImportFileId;
  BudgetPrefillModel? _bgtPrefillData;
  ImportBudgetModel? _lastSavedBudget;
  bool _isSavingBudget = false;
  bool _isLoadingBgtPrefill = false;

  // Search & Filter
  String _searchQuery = '';
  String _statusFilter = 'All';

  // Edit Mode for Tab 1 (Payment Requests)
  int? _editingPaymentId;
  String? _editingPaymentCode;
  int? _editingPaymentVersion;

  // Edit Mode for Tab 2 (Import Budgets)
  int? _editingBudgetId;
  int? _editingBudgetVersion;
  late final Set<int> _visitedTabs = {widget.initialIndex};

  /// Latest commercial rate for [currencyCode], or null when none is registered
  /// (the user must then type one: there is no silent fallback rate).
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

  /// Loads the prefill; on a backend error (e.g. 400 FA_FX_RATE_MISSING) the
  /// backend message is shown and null is returned so the form stays usable.
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

  /// Optimistic-lock conflict (409 carrying version info), as opposed to the
  /// business 409s (FA_PAYMENT_LOCKED, FA_SWIFT_REF_ALREADY_USED, ...).
  bool _isVersionConflict(Object e) {
    if (e is! DioException || e.response?.statusCode != 409) return false;
    final data = e.response?.data;
    final detail = (data is Map)
        ? (data['detail'] is Map ? data['detail'] as Map : data)
        : const {};
    return detail.containsKey('current_version') ||
        detail.containsKey('submitted_version');
  }

  /// Backend error with a structured `detail` map: `{code, message, ...}`.
  bool _isCodedError(Object e) {
    if (e is! DioException) return false;
    final data = e.response?.data;
    return data is Map && data['detail'] is Map;
  }

  void _showApiError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ApiError.message(e)),
          backgroundColor: AppTheme.crimson),
    );
  }

  String _rateText(double? rate) =>
      (rate != null && rate > 0) ? rate.toStringAsFixed(4) : '';

  String? _validateExchangeRate(String? v) {
    final r = double.tryParse((v ?? '').trim());
    if (r == null || r <= 0) return context.l10n.faExchangeRateInvalid;
    return null;
  }

  String? _validateFreightExchangeRate(String? v) {
    final frt = double.tryParse(_freightForeignController.text.trim()) ?? 0;
    if (frt <= 0) return null;
    final r = double.tryParse((v ?? '').trim());
    if (r == null || r <= 0) return context.l10n.faExchangeRateInvalid;
    return null;
  }

  void _warnFxMissing(String currency) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(context.l10n.faFxRateMissing(currency)),
          backgroundColor: AppTheme.orange),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 5, vsync: this, initialIndex: widget.initialIndex);
    _tabController.addListener(() {
      if (!_visitedTabs.contains(_tabController.index)) {
        setState(() => _visitedTabs.add(_tabController.index));
      }
    });
    Future.microtask(() {
      if (!ref.read(currenciesProvider).isLoading) {
        ref.read(currenciesProvider.notifier).fetchCurrencies();
      }
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
      if (!ref.read(suppliersProvider).isLoading) {
        ref.read(suppliersProvider.notifier).fetchSuppliers();
      }
      if (!ref.read(paymentRequestsProvider).isLoading) {
        ref.read(paymentRequestsProvider.notifier).fetchPaymentRequests();
      }
      if (!ref.read(importBudgetsProvider).isLoading) {
        ref.read(importBudgetsProvider.notifier).fetchImportBudgets();
      }
      if (!ref.read(purchaseOrdersProvider).isLoading) {
        ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      }

      if (widget.initialImportFileId != null) {
        _onPayImportFileSelected(widget.initialImportFileId);
        _onBgtImportFileSelected(widget.initialImportFileId);
      }
    });
  }

  @override
  void didUpdateWidget(FinancialApprovalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _visitedTabs.add(widget.initialIndex);
      _tabController.animateTo(widget.initialIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _payTitleController.dispose();
    _supplierNameController.dispose();
    _amountController.dispose();
    _exchangeRateController.dispose();
    _bankNameController.dispose();
    _swiftCodeController.dispose();
    _ibanController.dispose();
    _payNotesController.dispose();
    _paySwiftRawTextController.dispose();

    _bgtTitleController.dispose();
    _invoiceEgpController.dispose();
    _invoiceForeignController.dispose();
    _freightEgpController.dispose();
    _freightForeignController.dispose();
    _customsEgpController.dispose();
    _clearanceEgpController.dispose();
    _bgtExchangeRateController.dispose();
    _bgtFreightRateController.dispose();
    _bgtNotesController.dispose();
    super.dispose();
  }

  // ── Auto-Fetch & Duplicate Guard for Tab 1 (Payment Requests) ──────────────
  Future<void> _onPayImportFileSelected(int? fileId) async {
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

      // Use server prefill only (FE02-T07)
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

  // ── Auto-Fetch & Duplicate Guard for Tab 2 (Budget Approval) ───────────────
  Future<void> _onBgtImportFileSelected(int? fileId) async {
    if (fileId == null) {
      setState(() {
        _bgtSelectedImportFileId = null;
        _bgtPrefillData = null;
      });
      return;
    }

    // Check for existing Budget Approval duplicate
    final existingList = ref.read(importBudgetsProvider).valueOrNull ?? [];
    final existing = existingList
        .where((b) =>
            b.importFileId == fileId &&
            b.isActive &&
            b.budgetId != _editingBudgetId)
        .firstOrNull;
    if (existing != null) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.orange),
                  const SizedBox(width: 8),
                  Text(context.l10n.duplicateBudgetTitle),
                ],
              ),
              content: Text(
                context.l10n.duplicateBudgetMessage(
                    existing.budgetCode, existing.title),
              ),
              actions: [
                AppButton(
                  label: context.l10n.cancelSelection,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _bgtSelectedImportFileId = null;
                      _bgtPrefillData = null;
                    });
                  },
                ),
                AppButton(
                  label: context.l10n.faReviewSyncBudgetLiveCosts,
                  variant: AppButtonVariant.primary,
                  icon: Icons.sync,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _loadBudgetForEditAndCheckSync(existing);
                  },
                ),
                AppButton(
                  label: context.l10n.viewAndPrintBudget,
                  variant: AppButtonVariant.success,
                  icon: Icons.print,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showBudgetDetailsDialog(existing);
                  },
                ),
              ],
            );
          },
        );
      }
      return;
    }

    setState(() {
      _bgtSelectedImportFileId = fileId;
      _isLoadingBgtPrefill = true;
    });

    try {
      final prefill = await _fetchPrefillOrNull(fileId);
      final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
      final impFile =
          importFiles.where((f) => f.importFileId == fileId).firstOrNull;

      // Use server prefill only (FE02-T07)
      double calculatedInvoiceAmount = 0.0;
      String calculatedCurrency = _bgtInvoiceCurrency;

      if (prefill != null && prefill.totalInvoiceAmount > 0) {
        calculatedInvoiceAmount = prefill.totalInvoiceAmount;
        if (prefill.invoiceCurrency.isNotEmpty) {
          calculatedCurrency = prefill.invoiceCurrency;
        }
      }

      if (mounted) {
        final dynamicRate = _getExchangeRateForCurrency(calculatedCurrency);
        final double? effRate = (dynamicRate != null && dynamicRate > 0)
            ? dynamicRate
            : (prefill != null && prefill.exchangeRate > 0
                ? prefill.exchangeRate
                : null);
        if (effRate == null && calculatedCurrency.isNotEmpty) {
          _warnFxMissing(calculatedCurrency);
        }

        final freightCost = prefill?.estimatedFreightCost ?? 0.0;
        final freightCurr =
            (prefill != null && prefill.freightCurrency.isNotEmpty)
                ? prefill.freightCurrency
                : _bgtFreightCurrency;
        final freightRate = freightCurr == calculatedCurrency
            ? effRate
            : _getExchangeRateForCurrency(freightCurr);
        if (freightRate == null && freightCurr.isNotEmpty && freightCost > 0) {
          _warnFxMissing(freightCurr);
        }
        final freightEgp = freightCost * (freightRate ?? 0.0);

        final customsDutiesEgp = prefill?.estimatedCustomsDutiesEgp ?? 0.0;
        final clearanceFeesEgp = prefill?.estimatedClearanceFeesEgp ?? 0.0;

        final fCode = impFile?.primaryNameWithCode ??
            prefill?.importFileTitle ??
            'IMP-$fileId';
        final compName = impFile?.companyName ?? '';

        setState(() {
          _bgtPrefillData = prefill;
          _bgtTitleController.text =
              compName.isNotEmpty ? '$fCode - $compName' : fCode;

          _invoiceForeignController.text = calculatedInvoiceAmount > 0
              ? calculatedInvoiceAmount.toStringAsFixed(2)
              : '';
          _bgtInvoiceCurrency = calculatedCurrency;
          _invoiceEgpController.text =
              (calculatedInvoiceAmount > 0 && effRate != null)
                  ? (calculatedInvoiceAmount * effRate).toStringAsFixed(2)
                  : '';

          _freightForeignController.text = freightCost > 0
              ? freightCost.toStringAsFixed(2)
              : '';
          _bgtFreightCurrency = freightCurr;
          _bgtFreightRateController.text = _rateText(freightRate);
          _freightEgpController.text = (freightCost > 0 && freightRate != null)
              ? freightEgp.toStringAsFixed(2)
              : '';

          _customsEgpController.text = customsDutiesEgp > 0
              ? customsDutiesEgp.toStringAsFixed(2)
              : '';
          _clearanceEgpController.text = clearanceFeesEgp > 0
              ? clearanceFeesEgp.toStringAsFixed(2)
              : '';
          _bgtExchangeRateController.text = _rateText(effRate);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingBgtPrefill = false);
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
            SnackBar(
                content: Text(context.l10n
                    .paymentRequestUpdatedSuccess(updated.paymentCode)),
                backgroundColor: AppTheme.emerald),
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
            SnackBar(
              content: Text(
                  '${context.l10n.paymentRequestCreatedSuccess(created.paymentCode)}$taskMsg'),
              backgroundColor: AppTheme.emerald,
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

  void _loadPaymentRequestForEdit(PaymentRequestModel p) {
    setState(() {
      _visitedTabs.add(0);
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
    _tabController.animateTo(0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.paymentLoadedForEditMsg(p.paymentCode)),
        backgroundColor: AppTheme.cobalt,
      ),
    );
  }

  void _loadBudgetForEdit(ImportBudgetModel b) {
    setState(() {
      _visitedTabs.add(1);
      _editingBudgetId = b.budgetId;
      _editingBudgetVersion = b.version;
      _bgtTitleController.text = b.title;
      _bgtSelectedImportFileId = b.importFileId;
      _invoiceForeignController.text =
          b.invoiceAmountForeign.toStringAsFixed(2);
      _bgtInvoiceCurrency = b.invoiceCurrency;
      _invoiceEgpController.text = b.invoiceAmountEgp.toStringAsFixed(2);
      _freightForeignController.text = b.freightCostForeign.toStringAsFixed(2);
      _bgtFreightCurrency = b.freightCurrency;
      if (b.freightCurrency == b.invoiceCurrency) {
        _bgtFreightRateController.text = _rateText(b.exchangeRate);
      } else {
        final frtRate = _getExchangeRateForCurrency(b.freightCurrency);
        _bgtFreightRateController.text = _rateText(frtRate ??
            (b.freightCostForeign > 0 && b.freightCostEgp > 0
                ? (b.freightCostEgp / b.freightCostForeign)
                : null));
      }
      _freightEgpController.text = b.freightCostEgp.toStringAsFixed(2);
      _customsEgpController.text = b.customsDutiesEgp.toStringAsFixed(2);
      _clearanceEgpController.text = b.clearanceInlandEgp.toStringAsFixed(2);
      _bgtExchangeRateController.text = _rateText(b.exchangeRate);
      _bgtNotesController.text = b.notes ?? '';
      _lastSavedBudget = b;
    });
    _tabController.animateTo(1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.budgetLoadedForEditMsg(b.budgetCode)),
        backgroundColor: AppTheme.cobalt,
      ),
    );
    if (b.importFileId != null) {
      _loadBudgetPrefillForFile(b.importFileId!);
    }
  }

  Future<void> _loadBudgetPrefillForFile(int fileId) async {
    try {
      final p = await _fetchPrefillOrNull(fileId);
      if (mounted && p != null) {
        setState(() => _bgtPrefillData = p);
      }
    } catch (_) {
      // Only reachable if the widget was disposed during setState: nothing to show.
    }
  }

  Future<void> _loadBudgetForEditAndCheckSync(ImportBudgetModel b) async {
    _loadBudgetForEdit(b);
    if (b.importFileId != null) {
      setState(() => _isLoadingBgtPrefill = true);
      try {
        final prefill = await _fetchPrefillOrNull(b.importFileId!);
        if (mounted) {
          setState(() {
            if (prefill != null) _bgtPrefillData = prefill;
            _isLoadingBgtPrefill = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingBgtPrefill = false);
      }
    }
  }

  Future<void> _syncCurrentBudgetWithLiveCosts() async {
    if (_editingBudgetId == null) {
      if (_bgtPrefillData != null) {
        setState(() {
          if (_bgtPrefillData!.totalInvoiceAmount > 0) {
            _invoiceForeignController.text =
                _bgtPrefillData!.totalInvoiceAmount.toStringAsFixed(2);
            _bgtInvoiceCurrency = _bgtPrefillData!.invoiceCurrency;
          }
          if (_bgtPrefillData!.totalInvoiceAmountEgp > 0) {
            _invoiceEgpController.text =
                _bgtPrefillData!.totalInvoiceAmountEgp.toStringAsFixed(2);
          }
          if (_bgtPrefillData!.estimatedFreightCost > 0) {
            _freightForeignController.text =
                _bgtPrefillData!.estimatedFreightCost.toStringAsFixed(2);
            _bgtFreightCurrency = _bgtPrefillData!.freightCurrency;
          }
          if (_bgtPrefillData!.estimatedFreightCostEgp > 0) {
            _freightEgpController.text =
                _bgtPrefillData!.estimatedFreightCostEgp.toStringAsFixed(2);
          }
          if (_bgtPrefillData!.estimatedCustomsDutiesEgp > 0) {
            _customsEgpController.text =
                _bgtPrefillData!.estimatedCustomsDutiesEgp.toStringAsFixed(2);
          }
          if (_bgtPrefillData!.estimatedClearanceFeesEgp > 0) {
            _clearanceEgpController.text =
                _bgtPrefillData!.estimatedClearanceFeesEgp.toStringAsFixed(2);
          }
          if (_bgtPrefillData!.exchangeRate > 0) {
            _bgtExchangeRateController.text =
                _rateText(_bgtPrefillData!.exchangeRate);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.faPrefilledLiveCosts),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
      return;
    }
    // Saved budget sync is handled by the RecalculateButton widget embedded in the toolbar.
    // This code path is only reached for new (unsaved) budgets where prefill fills form fields.
    // CRE-001: No sync logic lives in this method for saved budgets.
  }

  Widget _buildUpstreamVarianceAlertBanner(
      {ImportBudgetModel? bgt, BudgetPrefillModel? prefill}) {
    final activePrefill = prefill ?? _bgtPrefillData;
    if (activePrefill == null) return const SizedBox.shrink();

    final double formInvoiceEgp = bgt != null
        ? bgt.invoiceAmountEgp
        : (double.tryParse(_invoiceEgpController.text.trim()) ?? 0.0);
    final double formFreightEgp = bgt != null
        ? bgt.freightCostEgp
        : (double.tryParse(_freightEgpController.text.trim()) ?? 0.0);
    final double formDutiesEgp = bgt != null
        ? bgt.customsDutiesEgp
        : (double.tryParse(_customsEgpController.text.trim()) ?? 0.0);
    final double formClearanceEgp = bgt != null
        ? bgt.clearanceInlandEgp
        : (double.tryParse(_clearanceEgpController.text.trim()) ?? 0.0);

    final double liveInvoiceEgp = activePrefill.totalInvoiceAmountEgp;
    final double liveFreightEgp = activePrefill.estimatedFreightCostEgp;
    final double liveDutiesEgp = activePrefill.estimatedCustomsDutiesEgp;
    final double liveClearanceEgp = activePrefill.estimatedClearanceFeesEgp;

    final diffInvoice = liveInvoiceEgp - formInvoiceEgp;
    final diffFreight = liveFreightEgp - formFreightEgp;
    final diffDuties = liveDutiesEgp - formDutiesEgp;
    final diffClearance = liveClearanceEgp - formClearanceEgp;

    final bool hasVariance = diffInvoice.abs() > 1.0 ||
        diffFreight.abs() > 1.0 ||
        diffDuties.abs() > 1.0 ||
        diffClearance.abs() > 1.0;

    if (!hasVariance) return const SizedBox.shrink();

    final double totalDiff =
        diffInvoice + diffFreight + diffDuties + diffClearance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.orangeLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.wcagOrange, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppTheme.wcagOrange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: AppTheme.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.faUpstreamVarianceTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? AppTheme.orange : AppTheme.wcagOrange,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.faUpstreamVarianceBody,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.wcagOrange,
                      ),
                    ),
                  ],
                ),
              ),
              if (bgt != null)
                // CRE-001: Saved budget — use centralized recalculation engine
                RecalculateButton(
                  entityType: 'import_budget',
                  entityId: bgt.budgetId,
                  sourcePage: 'VarianceAlertBanner',
                  label: context.l10n.faSyncBudgetLiveNow,
                  onSuccess: (result) {
                    ref.invalidate(importBudgetsProvider);
                    if (mounted) setState(() {});
                  },
                )
              else
                // Draft budget (not yet saved) — prefill form fields from live data
                AppButton(
                  label: context.l10n.faFillLiveCosts,
                  variant: AppButtonVariant.warning,
                  size: AppButtonSize.small,
                  icon: Icons.sync,
                  onPressed: _syncCurrentBudgetWithLiveCosts,
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (diffClearance.abs() > 1.0)
                _buildVarianceChip(
                  label: context.l10n.faVarianceClearance,
                  formVal: formClearanceEgp,
                  liveVal: liveClearanceEgp,
                  diff: diffClearance,
                  isDark: isDark,
                  extraInfo: activePrefill.brokerName != null
                      ? '(${activePrefill.brokerName})'
                      : null,
                ),
              if (diffFreight.abs() > 1.0)
                _buildVarianceChip(
                  label: context.l10n.faVarianceFreight,
                  formVal: formFreightEgp,
                  liveVal: liveFreightEgp,
                  diff: diffFreight,
                  isDark: isDark,
                ),
              if (diffDuties.abs() > 1.0)
                _buildVarianceChip(
                  label: context.l10n.faVarianceDuties,
                  formVal: formDutiesEgp,
                  liveVal: liveDutiesEgp,
                  diff: diffDuties,
                  isDark: isDark,
                ),
              if (diffInvoice.abs() > 1.0)
                _buildVarianceChip(
                  label: context.l10n.faVarianceInvoice,
                  formVal: formInvoiceEgp,
                  liveVal: liveInvoiceEgp,
                  diff: diffInvoice,
                  isDark: isDark,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.faVarianceTotal(
                '${totalDiff > 0 ? '+' : ''}${totalDiff.toStringAsFixed(2)}',
                (formInvoiceEgp +
                        formFreightEgp +
                        formDutiesEgp +
                        formClearanceEgp +
                        totalDiff)
                    .toStringAsFixed(2)),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: totalDiff > 0 ? AppTheme.crimson : AppTheme.wcagEmerald,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVarianceChip({
    required String label,
    required double formVal,
    required double liveVal,
    required double diff,
    required bool isDark,
    String? extraInfo,
  }) {
    final isPositive = diff > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPositive ? AppTheme.orange : AppTheme.cobaltBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ${extraInfo ?? ""}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.l10n.faVarianceChipLine(
                formVal.toStringAsFixed(2),
                liveVal.toStringAsFixed(2),
                '${isPositive ? '+' : ''}${diff.toStringAsFixed(2)}'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isPositive ? AppTheme.orange : AppTheme.cobalt,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePaymentRequest(PaymentRequestModel p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: AppTheme.orange, size: 22),
            const SizedBox(width: 8),
            Text(context.l10n.confirmDeletePaymentTitle,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
            context.l10n.confirmDeletePaymentMessage(p.paymentCode, p.title)),
        actions: [
          AppButton(
            label: context.l10n.cancel,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          AppButton(
            label: context.l10n.delete,
            variant: AppButtonVariant.danger,
            icon: Icons.delete,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref
            .read(paymentRequestsProvider.notifier)
            .softDeletePaymentRequest(p.paymentId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(context.l10n.paymentDeletedSuccess(p.paymentCode)),
                backgroundColor: AppTheme.emerald),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(context.l10n.deleteErrorMsg(ApiError.message(e))),
                backgroundColor: AppTheme.crimson),
          );
        }
      }
    }
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
    final l = context.l10n;

    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: CloneEntityReviewDialog(
            entityType: l.clonePaymentRequestDialogTitle,
            sourceCode: p.paymentCode,
            sourceTitle: p.title,
            suggestedNewCode: l.autoGeneratedCode,
            copiedFieldsSummary: {
              l.beneficiarySupplierLabel: p.beneficiaryName ?? p.supplierName,
              l.requestedAmountLabel:
                  '${p.requestedAmount.toStringAsFixed(2)} ${p.currencyCode}',
              l.paymentTypeLabel: p.paymentType,
              if (p.bankName != null && p.bankName!.isNotEmpty)
                l.bankNameLabel: p.bankName!,
            },
            mandatorilyResetFields: [
              l.cloneFieldPaymentStatusReset,
              l.cloneFieldSwiftReceiptReset,
              l.cloneFieldBankingDetailsCopied,
              l.cloneFieldPaymentCodeGenerated,
            ],
            allowCopyLineItems: true,
            onConfirm: ({
              required String newCode,
              required String newTitle,
              required bool copyLineItems,
              required bool copyAttachments,
              String? notes,
            }) async {
              try {
                final payload = <String, dynamic>{
                  'new_title': newTitle,
                  'unlink_import_file': !copyLineItems,
                  if (notes != null && notes.trim().isNotEmpty)
                    'remarks': notes.trim(),
                };
                final cloned = await ref
                    .read(paymentRequestsProvider.notifier)
                    .clonePaymentRequest(p.paymentId, payload);

                if (mounted && cloned != null) {
                  _loadPaymentRequestForEdit(cloned);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              color: AppTheme.orange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.clonePaymentRequestSuccess(cloned.paymentCode),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppTheme.emerald,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            l.clonePaymentRequestError(ApiError.message(e))),
                        backgroundColor: AppTheme.crimson),
                  );
                }
              }
            },
          ),
        ),
      ),
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
      _payPrefillData = _payPrefillData!.copyWith(
        linkedPos: currentList,
        estimatedGrandTotalEgp: _payPrefillData!.estimatedGrandTotalEgp +
            (po.totalAmount * _payPrefillData!.exchangeRate),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.poAllocationClonedSuccess),
        backgroundColor: AppTheme.emerald,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openSearchAndCloneBudgetDialog() {
    final budgets = ref.read(importBudgetsProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: SearchAndCloneBudgetDialog(
            budgets: budgets,
            onSelectBudget: (b) => _openCloneBudgetReviewDialog(b),
          ),
        ),
      ),
    );
  }

  void _openCloneBudgetReviewDialog(ImportBudgetModel b) {
    final l = context.l10n;

    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: CloneEntityReviewDialog(
            entityType: l.cloneBudgetDialogTitle,
            sourceCode: b.budgetCode,
            sourceTitle: b.title,
            suggestedNewCode: l.autoGeneratedCode,
            copiedFieldsSummary: {
              l.estimatedInvoiceValue:
                  '${b.invoiceAmountForeign.toStringAsFixed(2)} ${b.invoiceCurrency}',
              l.estimatedFreightCost:
                  '${b.freightCostForeign.toStringAsFixed(2)} ${b.freightCurrency}',
              l.customsAndVatEstimate:
                  '${b.customsDutiesEgp.toStringAsFixed(2)} EGP',
              l.clearanceAndTransportEstimate:
                  '${b.clearanceInlandEgp.toStringAsFixed(2)} EGP',
              l.exchangeRateLabel: b.exchangeRate.toStringAsFixed(2),
              l.totalBudgetEgp: '${b.totalBudgetEgp.toStringAsFixed(2)} EGP',
            },
            mandatorilyResetFields: [
              l.cloneFieldBudgetStatusReset,
              l.cloneFieldCertificationsReset,
              l.cloneFieldExchangeRatesCopied,
              l.cloneFieldBudgetCodeGenerated,
            ],
            allowCopyLineItems: true,
            onConfirm: ({
              required String newCode,
              required String newTitle,
              required bool copyLineItems,
              required bool copyAttachments,
              String? notes,
            }) async {
              try {
                final payload = <String, dynamic>{
                  'new_title': newTitle,
                  'unlink_import_file': !copyLineItems,
                  if (notes != null && notes.trim().isNotEmpty)
                    'remarks': notes.trim(),
                };
                final cloned = await ref
                    .read(importBudgetsProvider.notifier)
                    .cloneImportBudget(b.budgetId, payload);

                if (mounted && cloned != null) {
                  _loadBudgetForEdit(cloned);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              color: AppTheme.orange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.cloneBudgetSuccess(cloned.budgetCode),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppTheme.emerald,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(l.cloneBudgetError(ApiError.message(e))),
                        backgroundColor: AppTheme.crimson),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLinkedPOCardsList(AppLocalizations l, bool isDark) {
    if (_payPrefillData == null || _payPrefillData!.linkedPos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: _payPrefillData!.linkedPos.map((po) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CopyableText(
                          po.displayName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.cobalt,
                              fontSize: 13),
                        ),
                        if (po.displayName != po.poNumber)
                          CopyableText(po.poNumber,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkCardBackground
                              : AppTheme.orangeLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: isDark
                                  ? AppTheme.wcagOrange
                                  : AppTheme.orange),
                        ),
                        child: Text(
                          po.paymentTerms,
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isDark ? AppTheme.orange : AppTheme.wcagOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            size: 16, color: AppTheme.cobalt),
                        tooltip: l.clonePoAllocationTooltip,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        onPressed: () => _cloneLinkedPoItem(po),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l.invoiceAmount}:',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textStrong),
                  ),
                  Text(
                    '${po.totalAmount.toStringAsFixed(2)} ${po.currency}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.emerald),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAmountField(AppLocalizations l) {
    return TextFormField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
          labelText: '${l.requestedAmountLabel} *',
          border: const OutlineInputBorder()),
      validator: (v) =>
          (v == null || double.tryParse(v) == null || double.parse(v) <= 0)
              ? l.requiredField
              : null,
    );
  }

  Widget _buildCurrencyDropdown(AppLocalizations l) {
    return SearchableDropdownField<String>(
      value: _currencyCode,
      labelText: '${l.currencyCol} *',
      searchHintText: l.search,
      items: () {
        final curList = ref.watch(currenciesProvider).valueOrNull ?? [];
        final list = curList.isNotEmpty
            ? curList
                .map((c) => SearchableDropdownItem<String>(
                      value: c.currencyCode,
                      label: '${c.currencyCode} - ${c.currencyName}',
                    ))
                .toList()
            : [
                const SearchableDropdownItem(value: 'USD', label: 'USD'),
                const SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                const SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                const SearchableDropdownItem(value: 'GBP', label: 'GBP'),
                const SearchableDropdownItem(value: 'CNY', label: 'CNY'),
                const SearchableDropdownItem(value: 'SAR', label: 'SAR'),
                const SearchableDropdownItem(value: 'AED', label: 'AED'),
              ];
        if (!list.any((i) => i.value == _currencyCode)) {
          list.add(SearchableDropdownItem(
              value: _currencyCode, label: _currencyCode));
        }
        return list;
      }(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _currencyCode = val;
            final rate = _getExchangeRateForCurrency(val);
            _exchangeRateController.text = _rateText(rate);
            if (rate == null) _warnFxMissing(val);
          });
        }
      },
    );
  }

  Widget _buildBgtInvoiceCurrencyDropdown(AppLocalizations l) {
    return SearchableDropdownField<String>(
      value: _bgtInvoiceCurrency,
      labelText: '${l.invoiceCurrencyLabel} *',
      searchHintText: l.search,
      items: () {
        final curList = ref.watch(currenciesProvider).valueOrNull ?? [];
        final list = curList.isNotEmpty
            ? curList
                .map((c) => SearchableDropdownItem<String>(
                      value: c.currencyCode,
                      label: '${c.currencyCode} - ${c.currencyName}',
                    ))
                .toList()
            : [
                const SearchableDropdownItem(value: 'USD', label: 'USD'),
                const SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                const SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                const SearchableDropdownItem(value: 'GBP', label: 'GBP'),
                const SearchableDropdownItem(value: 'CNY', label: 'CNY'),
                const SearchableDropdownItem(value: 'SAR', label: 'SAR'),
                const SearchableDropdownItem(value: 'AED', label: 'AED'),
              ];
        if (!list.any((i) => i.value == _bgtInvoiceCurrency)) {
          list.add(SearchableDropdownItem(
              value: _bgtInvoiceCurrency, label: _bgtInvoiceCurrency));
        }
        return list;
      }(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _bgtInvoiceCurrency = val;
            final rate = _getExchangeRateForCurrency(val);
            _bgtExchangeRateController.text = _rateText(rate);
            if (rate != null) {
              final inv = double.tryParse(_invoiceForeignController.text) ?? 0;
              _invoiceEgpController.text = (inv * rate).toStringAsFixed(2);
            }
            if (rate == null) _warnFxMissing(val);
          });
        }
      },
    );
  }

  Widget _buildBgtFreightCurrencyDropdown(AppLocalizations l) {
    return SearchableDropdownField<String>(
      value: _bgtFreightCurrency,
      labelText: '${l.freightCurrencyLabel} *',
      searchHintText: l.search,
      items: () {
        final curList = ref.watch(currenciesProvider).valueOrNull ?? [];
        final list = curList.isNotEmpty
            ? curList
                .map((c) => SearchableDropdownItem<String>(
                      value: c.currencyCode,
                      label: '${c.currencyCode} - ${c.currencyName}',
                    ))
                .toList()
            : [
                const SearchableDropdownItem(value: 'USD', label: 'USD'),
                const SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                const SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                const SearchableDropdownItem(value: 'GBP', label: 'GBP'),
                const SearchableDropdownItem(value: 'CNY', label: 'CNY'),
                const SearchableDropdownItem(value: 'SAR', label: 'SAR'),
                const SearchableDropdownItem(value: 'AED', label: 'AED'),
              ];
        if (!list.any((i) => i.value == _bgtFreightCurrency)) {
          list.add(SearchableDropdownItem(
              value: _bgtFreightCurrency, label: _bgtFreightCurrency));
        }
        return list;
      }(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _bgtFreightCurrency = val;
            final rate = _getExchangeRateForCurrency(val);
            _bgtFreightRateController.text = _rateText(rate);
            if (rate != null) {
              final frt = double.tryParse(_freightForeignController.text) ?? 0;
              _freightEgpController.text = (frt * rate).toStringAsFixed(2);
            }
            if (rate == null) _warnFxMissing(val);
          });
        }
      },
    );
  }

  Widget _buildExchangeRateField(AppLocalizations l) {
    return TextFormField(
      controller: _exchangeRateController,
      keyboardType: TextInputType.number,
      validator: _validateExchangeRate,
      decoration: InputDecoration(
          labelText: '${l.exchangeRateCol} (EGP) *',
          border: const OutlineInputBorder()),
    );
  }

  Widget _buildRequestDateField(AppLocalizations l) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _requestDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) setState(() => _requestDate = d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: '${l.requestDateLabel} *',
            border: const OutlineInputBorder()),
        child: Text(_requestDate.toString().substring(0, 10)),
      ),
    );
  }

  Widget _buildDueDateField(AppLocalizations l) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _dueDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) setState(() => _dueDate = d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: '${l.dueDateLabel} *',
            border: const OutlineInputBorder()),
        child: Text(_dueDate.toString().substring(0, 10)),
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
        // Auto-match supplier from Master Data
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

      // Auto-match Import File if available
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
        }
      }

      final l = context.l10n;
      if (_payTitleController.text.trim().isEmpty &&
          p['beneficiary_name'] != null) {
        final refNo = p['transaction_reference'] ?? '';
        final piText = p['pi_number'] != null ? ' - PI: ${p['pi_number']}' : '';
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
        SnackBar(content: Text(msg), backgroundColor: AppTheme.emerald),
      );
    }
  }

  Map<String, dynamic> _parseSwiftClientFallback(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) {
      return {'success': false, 'error': context.l10n.emptyTextError};
    }

    // 1. Transaction Ref (:20)
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

    // 2. Value Date, Currency, Amount (:32A)
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

    // 3. Beneficiary Customer (:59)
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

    // 4. Beneficiary Bank / SWIFT (:57A)
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

    // 5. Details of Payment (:70)
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

    // 6. Ordering Customer (:50K)
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
      } catch (_) {
        // Fallback to client parser
      }

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
            SnackBar(
                content: Text(context.l10n.swiftTextParseError),
                backgroundColor: AppTheme.orange),
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
        if (res['raw_text'] != null && (res['raw_text'] as String).isNotEmpty) {
          _paySwiftRawTextController.text = res['raw_text'] as String;
        }
        _applySwiftParsedData(res['parsed_swift'] as Map<String, dynamic>,
            fileName: file.name);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(context.l10n
                    .swiftFileExtractError(res['error'].toString())),
                backgroundColor: AppTheme.crimson),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(context.l10n.swiftFileExtractError(ApiError.message(e))),
              backgroundColor: AppTheme.crimson),
        );
      }
    } finally {
      if (mounted) setState(() => _isPaySwiftExtracting = false);
    }
  }

  Future<ImportBudgetModel?> _persistBudget() async {
    if (!_budgetFormKey.currentState!.validate()) return null;

    final rateInput = double.tryParse(_bgtExchangeRateController.text.trim());
    if (rateInput == null || rateInput <= 0) {
      _warnFxMissing(_bgtInvoiceCurrency);
      return null;
    }
    final frtForeign =
        double.tryParse(_freightForeignController.text.trim()) ?? 0.0;
    if (frtForeign > 0) {
      final frtRateInput =
          double.tryParse(_bgtFreightRateController.text.trim());
      if (frtRateInput == null || frtRateInput <= 0) {
        _warnFxMissing(_bgtFreightCurrency);
        return null;
      }
    }

    setState(() => _isSavingBudget = true);
    final invForeign =
        double.tryParse(_invoiceForeignController.text.trim()) ?? 0.0;
    final invEgp = double.tryParse(_invoiceEgpController.text.trim()) ?? 0.0;
    final frtEgp = double.tryParse(_freightEgpController.text.trim()) ?? 0.0;
    final custEgp = double.tryParse(_customsEgpController.text.trim()) ?? 0.0;
    final clrEgp = double.tryParse(_clearanceEgpController.text.trim()) ?? 0.0;
    final rate = rateInput;

    final payload = <String, dynamic>{
      'title': _bgtTitleController.text.trim(),
      'import_file_id': _bgtSelectedImportFileId,
      'invoice_amount_foreign': invForeign,
      'invoice_currency': _bgtInvoiceCurrency,
      'invoice_amount_egp': invEgp,
      'freight_cost_foreign': frtForeign,
      'freight_currency': _bgtFreightCurrency,
      'freight_cost_egp': frtEgp,
      'customs_duties_egp': custEgp,
      'clearance_inland_egp': clrEgp,
      'exchange_rate': rate,
      'notes': _bgtNotesController.text.trim(),
    };

    try {
      if (_editingBudgetId != null) {
        if (_editingBudgetVersion != null) {
          payload['version'] = _editingBudgetVersion;
        }
        final updated = await ref
            .read(importBudgetsProvider.notifier)
            .updateImportBudget(_editingBudgetId!, payload);
        if (mounted && updated != null) {
          setState(() {
            _lastSavedBudget = updated;
            _editingBudgetId = null;
            _editingBudgetVersion = null;
          });
          return updated;
        }
      } else {
        final created = await ref
            .read(importBudgetsProvider.notifier)
            .createImportBudget(payload);
        if (mounted && created != null) {
          setState(() => _lastSavedBudget = created);
          return created;
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
            entityName: conflict['entity'] as String? ?? 'ImportBudgetApproval',
            recordId: conflict['record_id'] ?? _editingBudgetId,
            currentVersion: (conflict['current_version'] as num?)?.toInt() ??
                ((_editingBudgetVersion ?? 1) + 1),
            submittedVersion:
                (conflict['submitted_version'] as num?)?.toInt() ??
                    (_editingBudgetVersion ?? 1),
            updatedAt: conflict['updated_at'] as String?,
            updatedBy: conflict['updated_by'] as String?,
            serverMessage: conflict['message'] as String?,
            currentDraftData: payload,
          );
          if (mounted && resolution == ConcurrencyResolution.discardAndReload) {
            setState(() {
              _editingBudgetId = null;
              _editingBudgetVersion = null;
            });
            await ref.read(importBudgetsProvider.notifier).fetchImportBudgets();
          }
        }
        return null;
      }
      if (mounted && _isCodedError(e)) {
        _showApiError(e);
      } else if (mounted) {
        await showErrorDetailsDialog(
          context,
          title: context.l10n.saveBudgetFailedTitle,
          error: e,
          onRetry: () async {
            await _saveImportBudget();
          },
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isSavingBudget = false);
    }
    return null;
  }

  Future<void> _saveImportBudget() async {
    final isUpdate = _editingBudgetId != null;
    final bgt = await _persistBudget();
    if (bgt != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isUpdate
              ? context.l10n.budgetUpdatedSuccess(bgt.budgetCode)
              : context.l10n.budgetCreatedSuccess(bgt.budgetCode)),
          backgroundColor: AppTheme.emerald,
        ),
      );
      _showBudgetDetailsDialog(bgt);
    }
  }

  Future<void> _saveAndApproveBudget() async {
    final saved = await _persistBudget();
    if (saved == null || !mounted) return;
    try {
      setState(() => _isSavingBudget = true);
      final approved = await ref
          .read(importBudgetsProvider.notifier)
          .approveImportBudget(saved.budgetId);
      if (mounted && approved != null) {
        setState(() => _lastSavedBudget = approved);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(context.l10n.budgetApprovedSuccess(approved.budgetCode)),
            backgroundColor: AppTheme.emerald,
          ),
        );
        _showBudgetDetailsDialog(approved);
      }
    } catch (e) {
      if (mounted) _showApiError(e);
    } finally {
      if (mounted) setState(() => _isSavingBudget = false);
    }
  }

  void _showPaymentDetailsDialog(PaymentRequestModel pay) {
    final swiftController =
        TextEditingController(text: pay.swiftReferenceNo ?? '');
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.paymentRequestDetailsTitle(pay.paymentCode),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              FinancialStatusChip(status: pay.status),
            ],
          ),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pay.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.charcoal)),
                  const SizedBox(height: 6),
                  Text(
                      context.l10n.beneficiarySupplierDetails(
                          pay.beneficiaryName ?? pay.supplierName),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                      '${context.l10n.paymentTypeLabel}: ${pay.paymentType} | ${context.l10n.requestDateLabel}: ${pay.requestDate.isNotEmpty ? pay.requestDate : "-"} | ${context.l10n.dueDateLabel}: ${pay.dueDate}'),
                  const Divider(),
                  Row(
                    children: [
                      _buildMetricBadge(
                          context.l10n.foreignAmountMetric,
                          '${pay.requestedAmount} ${pay.currencyCode}',
                          AppTheme.cobalt),
                      const SizedBox(width: 10),
                      _buildMetricBadge(context.l10n.exchangeRateCol,
                          '${pay.exchangeRate} EGP', AppTheme.orange),
                      const SizedBox(width: 10),
                      _buildMetricBadge(
                          context.l10n.equivalentEgpCol,
                          '${pay.requestedAmountEgp.toStringAsFixed(2)} EGP',
                          AppTheme.emerald),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppTheme.cobaltLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.cobaltBorder)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${context.l10n.beneficiaryBankDetails}:',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.cobalt)),
                        const SizedBox(height: 4),
                        Text(
                            '${context.l10n.bankNameLabel}: ${pay.bankName ?? "-"}'),
                        Text(
                            '${context.l10n.swiftCodeLabel}: ${pay.swiftCode ?? "-"}'),
                        Text(
                            '${context.l10n.ibanAccountLabel}: ${pay.ibanAccountNo ?? "-"}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── EXPORT & SHARING ACTION TOOLBAR ────────────────────────
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.charcoalSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cloudWhite),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.share_outlined,
                                size: 16, color: AppTheme.cobalt),
                            const SizedBox(width: 6),
                            Text(context.l10n.exportAndShareOptionsTitle,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.charcoal)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            // 1. Print / Save PDF
                            AppButton(
                              label: context.l10n.printSavePdfBtn,
                              variant: AppButtonVariant.primary,
                              size: AppButtonSize.small,
                              icon: Icons.print,
                              onPressed: () {
                                FinancialExportService.printPaymentRequestPdf(
                                    payment: pay);
                              },
                            ),
                            // 2. Export Excel
                            AppButton(
                              label: context.l10n.downloadExcelBtn,
                              variant: AppButtonVariant.secondary,
                              size: AppButtonSize.small,
                              icon: Icons.table_chart,
                              onPressed: () async {
                                final path = await FinancialExportService
                                    .exportSinglePaymentRequestToExcel(
                                  context: context,
                                  payment: pay,
                                );
                                if (path != null && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(context.l10n
                                            .excelSavedSuccess(path)),
                                        backgroundColor: AppTheme.emerald),
                                  );
                                }
                              },
                            ),
                            // 3. WhatsApp Sharing
                            AppButton(
                              label: context.l10n.whatsappShareBtn,
                              variant: AppButtonVariant.success,
                              size: AppButtonSize.small,
                              icon: Icons.chat,
                              onPressed: () {
                                _showWhatsAppShareDialog(pay);
                              },
                            ),
                            // 4. Email Sharing
                            AppButton(
                              label: context.l10n.emailShareBtn,
                              variant: AppButtonVariant.warning,
                              size: AppButtonSize.small,
                              icon: Icons.email_outlined,
                              onPressed: () {
                                _showEmailShareDialog(pay);
                              },
                            ),
                            // 5. Copy Summary
                            AppButton(
                              label: context.l10n.copySummaryBtn,
                              variant: AppButtonVariant.secondary,
                              size: AppButtonSize.small,
                              icon: Icons.copy,
                              onPressed: () {
                                final text = FinancialExportService
                                    .generatePaymentWhatsAppText(pay);
                                CopyHelper.copy(context, text);
                              },
                            ),
                            // 6. SWIFT Smart Reconcile & Auto Match
                            AppButton(
                              label: context.l10n.extractAndMatchSwiftBtn,
                              variant: AppButtonVariant.primary,
                              size: AppButtonSize.small,
                              icon: Icons.auto_awesome,
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() => _tabController.index = 3);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (pay.status == 'Approved') ...[
                    const Divider(),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: swiftController,
                      builder: (context, value, _) {
                        final isEmpty = value.text.trim().isEmpty;
                        return TextField(
                          controller: swiftController,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: context.l10n.swiftReferenceInputLabel,
                            errorText: isEmpty ? context.l10n.fieldRequired : null,
                            border: const OutlineInputBorder(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            AppButton(
              label: context.l10n.close,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(context),
            ),
            if (pay.status == 'Draft' || pay.status == 'Pending Approval') ...[
              AsyncActionButton(
                label: context.l10n.approvePaymentAction,
                onAction: () async {
                  final nav = Navigator.of(context);
                  await ref
                      .read(paymentRequestsProvider.notifier)
                      .approvePaymentRequest(pay.paymentId);
                  nav.pop();
                },
              ),
            ],
            if (pay.status == 'Approved') ...[
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: swiftController,
                builder: (context, value, _) {
                  final canPay = value.text.trim().isNotEmpty;
                  return AsyncActionButton(
                    label: context.l10n.markAsPaidAction,
                    variant: AppButtonVariant.success,
                    enabled: canPay,
                    onAction: () async {
                      if (!canPay) return;
                      final nav = Navigator.of(context);
                      await ref
                          .read(paymentRequestsProvider.notifier)
                          .executePayment(pay.paymentId,
                              swiftRef: swiftController.text.trim());
                      nav.pop();
                    },
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }

  void _showWhatsAppShareDialog(PaymentRequestModel pay) {
    final text = FinancialExportService.generatePaymentWhatsAppText(pay);
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.chat, color: AppTheme.emerald),
            const SizedBox(width: 8),
            Text(context.l10n.sendPaymentWhatsAppTitle,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: context.l10n.whatsAppNumberLabel,
                    hintText: context.l10n.whatsAppNumberHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.phone_android),
                  ),
                ),
                const SizedBox(height: 12),
                Text(context.l10n.messagePreviewLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.charcoal)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cloudWhite,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.cloudWhite),
                  ),
                  child: SelectableText(
                    text,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.charcoal,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton(
            label: context.l10n.cancel,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(ctx),
          ),
          AppButton(
            label: context.l10n.copySummaryBtn,
            variant: AppButtonVariant.secondary,
            icon: Icons.copy,
            onPressed: () {
              CopyHelper.copy(ctx, text);
            },
          ),
          AppButton(
            label: context.l10n.openWhatsAppBtn,
            variant: AppButtonVariant.success,
            icon: Icons.open_in_new,
            onPressed: () {
              final phone =
                  phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
              final encoded = Uri.encodeComponent(text);
              final url = phone.isNotEmpty
                  ? 'https://wa.me/$phone?text=$encoded'
                  : 'https://wa.me/?text=$encoded';
              FinancialExportService.launchUrlNative(url);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showEmailShareDialog(PaymentRequestModel pay) {
    final subject = FinancialExportService.generatePaymentEmailSubject(pay);
    final body = FinancialExportService.generatePaymentEmailBody(pay);
    final toController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.email, color: AppTheme.orange),
            const SizedBox(width: 8),
            Text(context.l10n.sendPaymentEmailTitle,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: toController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: context.l10n.recipientEmailLabel,
                    hintText: 'accounting@company.com',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.alternate_email),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.charcoalSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.cloudWhite),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.emailSubjectLabel(subject),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                      const Divider(height: 12),
                      SelectableText(
                        body,
                        style: const TextStyle(fontSize: 11, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton(
            label: context.l10n.cancel,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(ctx),
          ),
          AppButton(
            label: context.l10n.copySummaryBtn,
            variant: AppButtonVariant.secondary,
            icon: Icons.copy,
            onPressed: () {
              CopyHelper.copy(ctx, 'Subject: $subject\n\n$body');
            },
          ),
          AppButton(
            label: context.l10n.openEmailClientBtn,
            variant: AppButtonVariant.primary,
            icon: Icons.send,
            onPressed: () {
              final to = toController.text.trim();
              final encodedSubject = Uri.encodeComponent(subject);
              final encodedBody = Uri.encodeComponent(body);
              final url =
                  'mailto:$to?subject=$encodedSubject&body=$encodedBody';
              FinancialExportService.launchUrlNative(url);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showBudgetDetailsDialog(ImportBudgetModel bgt) {
    // Created once, so dialog rebuilds do not refetch (or re-show errors).
    final Future<BudgetPrefillModel?> prefillFuture = bgt.importFileId != null
        ? _fetchPrefillOrNull(bgt.importFileId!)
        : Future.value(null);
    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<BudgetPrefillModel?>(
          future: prefillFuture,
          builder: (dialogCtx, snapshot) {
            final prefill = snapshot.data ??
                (bgt.importFileId == _bgtPrefillData?.importFileId
                    ? _bgtPrefillData
                    : null);

            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.l10n.budgetDetailsTitle(bgt.budgetCode),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  FinancialStatusChip(status: bgt.budgetStatus),
                ],
              ),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bgt.title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.charcoal)),
                      const SizedBox(height: 12),

                      // Upstream Variance Alert Banner inside Modal
                      if (prefill != null) ...[
                        _buildUpstreamVarianceAlertBanner(
                            bgt: bgt, prefill: prefill),
                        const SizedBox(height: 8),
                      ],

                      // Multi-currency details in modal with live prefill
                      _buildConsolidatedBudgetSummary(
                          bgt: bgt, prefill: prefill),

                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.charcoalSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.cloudWhite),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.share_outlined,
                                    size: 16, color: AppTheme.cobalt),
                                const SizedBox(width: 6),
                                Text(context.l10n.exportAndShareOptionsTitle,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.charcoal)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                // 1. Print / Save PDF
                                AppButton(
                                  label: context.l10n.printSavePdfBtn,
                                  variant: AppButtonVariant.primary,
                                  size: AppButtonSize.small,
                                  icon: Icons.print,
                                  onPressed: () {
                                    FinancialExportService.printOrSaveBudgetPdf(
                                      budget: bgt,
                                      prefill: prefill,
                                    );
                                  },
                                ),
                                // 2. Export Excel
                                AppButton(
                                  label: context.l10n.downloadExcelBtn,
                                  variant: AppButtonVariant.secondary,
                                  size: AppButtonSize.small,
                                  icon: Icons.table_chart,
                                  onPressed: () async {
                                    final path = await FinancialExportService
                                        .exportBudgetToExcel(
                                      context: context,
                                      budget: bgt,
                                      prefill: prefill,
                                    );
                                    if (path != null && mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(context.l10n
                                                .excelSavedSuccess(path)),
                                            backgroundColor: AppTheme.emerald),
                                      );
                                    }
                                  },
                                ),
                                // 3. WhatsApp Sharing
                                AppButton(
                                  label: context.l10n.whatsappShareBtn,
                                  variant: AppButtonVariant.success,
                                  size: AppButtonSize.small,
                                  icon: Icons.chat,
                                  onPressed: () {
                                    _showBudgetWhatsAppShareDialog(
                                        bgt, prefill);
                                  },
                                ),
                                // 4. Email Sharing
                                AppButton(
                                  label: context.l10n.emailShareBtn,
                                  variant: AppButtonVariant.warning,
                                  size: AppButtonSize.small,
                                  icon: Icons.email_outlined,
                                  onPressed: () {
                                    _showBudgetEmailShareDialog(bgt, prefill);
                                  },
                                ),
                                // 5. Copy Summary
                                AppButton(
                                  label: context.l10n.copySummaryBtn,
                                  variant: AppButtonVariant.secondary,
                                  size: AppButtonSize.small,
                                  icon: Icons.copy,
                                  onPressed: () {
                                    final text = FinancialExportService
                                        .generateBudgetWhatsAppText(
                                            bgt, prefill);
                                    CopyHelper.copy(context, text);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                AppButton(
                  label: context.l10n.close,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.pop(ctx),
                ),
                if (bgt.importFileId != null)
                  // CRE-001: Centralized recalculation engine — no sync logic in dialog
                  RecalculateButton(
                    entityType: 'import_budget',
                    entityId: bgt.budgetId,
                    sourcePage: 'BudgetDetailsDialog',
                    label: context.l10n.faSyncLiveCosts,
                    onSuccess: (result) {
                      Navigator.of(ctx).pop();
                      ref.invalidate(importBudgetsProvider);
                    },
                  ),
                if (bgt.budgetStatus == 'Pending Review' ||
                    bgt.budgetStatus == 'Draft' ||
                    bgt.budgetStatus == 'Needs Revalidation') ...[
                  AsyncActionButton(
                    label: context.l10n.approveAndCertifyBudget,
                    variant: AppButtonVariant.success,
                    onAction: () async {
                      final nav = Navigator.of(ctx);
                      await ref
                          .read(importBudgetsProvider.notifier)
                          .approveImportBudget(bgt.budgetId);
                      nav.pop();
                    },
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  void _showBudgetWhatsAppShareDialog(ImportBudgetModel bgt,
      [BudgetPrefillModel? prefill]) {
    final text = FinancialExportService.generateBudgetWhatsAppText(
        bgt, prefill ?? _bgtPrefillData);
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.chat, color: AppTheme.emerald),
            const SizedBox(width: 8),
            Text(context.l10n.sendBudgetWhatsAppTitle,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: context.l10n.whatsAppNumberLabel,
                    hintText: context.l10n.whatsAppNumberHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.phone_android),
                  ),
                ),
                const SizedBox(height: 12),
                Text(context.l10n.messagePreviewLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.charcoal)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cloudWhite,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.cloudWhite),
                  ),
                  child: SelectableText(
                    text,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.charcoal,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton(
            label: context.l10n.cancel,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(ctx),
          ),
          AppButton(
            label: context.l10n.copySummaryBtn,
            variant: AppButtonVariant.secondary,
            icon: Icons.copy,
            onPressed: () {
              CopyHelper.copy(ctx, text);
            },
          ),
          AppButton(
            label: context.l10n.openWhatsAppBtn,
            variant: AppButtonVariant.success,
            icon: Icons.open_in_new,
            onPressed: () {
              final phone =
                  phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
              final encoded = Uri.encodeComponent(text);
              final url = phone.isNotEmpty
                  ? 'https://wa.me/$phone?text=$encoded'
                  : 'https://wa.me/?text=$encoded';
              FinancialExportService.launchUrlNative(url);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showBudgetEmailShareDialog(ImportBudgetModel bgt,
      [BudgetPrefillModel? prefill]) {
    final subject = FinancialExportService.generateBudgetEmailSubject(bgt);
    final body = FinancialExportService.generateBudgetEmailBody(
        bgt, prefill ?? _bgtPrefillData);
    final toController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.email, color: AppTheme.orange),
            const SizedBox(width: 8),
            Text(context.l10n.sendBudgetEmailTitle,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: toController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: context.l10n.recipientEmailLabel,
                    hintText: 'cfo@company.com',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.alternate_email),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.charcoalSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.cloudWhite),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.emailSubjectLabel(subject),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                      const Divider(height: 12),
                      SelectableText(
                        body,
                        style: const TextStyle(fontSize: 11, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton(
            label: context.l10n.cancel,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(ctx),
          ),
          AppButton(
            label: context.l10n.copySummaryBtn,
            variant: AppButtonVariant.secondary,
            icon: Icons.copy,
            onPressed: () {
              CopyHelper.copy(ctx, 'Subject: $subject\n\n$body');
            },
          ),
          AppButton(
            label: context.l10n.openEmailClientBtn,
            variant: AppButtonVariant.primary,
            icon: Icons.send,
            onPressed: () {
              final to = toController.text.trim();
              final encodedSubject = Uri.encodeComponent(subject);
              final encodedBody = Uri.encodeComponent(body);
              final url =
                  'mailto:$to?subject=$encodedSubject&body=$encodedBody';
              FinancialExportService.launchUrlNative(url);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final suppliersState = ref.watch(suppliersProvider);
    final paymentsState = ref.watch(paymentRequestsProvider);
    final budgetsState = ref.watch(importBudgetsProvider);

    final suppliersList = suppliersState.valueOrNull ?? [];

    final tabs = [
      const VerticalNavTabItem(
        icon: Icons.payment_outlined,
        titleEn: 'Payment Requests',
        titleAr: 'طلبات السداد المالي للمورد',
      ),
      const VerticalNavTabItem(
        icon: Icons.pie_chart_outline,
        titleEn: 'Import Budget Approval',
        titleAr: 'اعتماد الميزانية الاستيرادية',
      ),
      VerticalNavTabItem(
        icon: Icons.account_balance_wallet_outlined,
        titleEn: 'Saved Budgets Registry',
        titleAr: 'سجل الميزانيات المعتمدة',
        badge: (budgetsState.valueOrNull?.length ?? 0) > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${budgetsState.valueOrNull?.length ?? 0}',
                  style: const TextStyle(
                      color: AppTheme.emerald,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
      VerticalNavTabItem(
        icon: Icons.history_edu_outlined,
        titleEn: 'Payment Requests Registry',
        titleAr: 'سجل طلبات السداد والتحويلات',
        badge: (paymentsState.valueOrNull?.length ?? 0) > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${paymentsState.valueOrNull?.length ?? 0}',
                  style: const TextStyle(
                      color: AppTheme.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
      const VerticalNavTabItem(
        icon: Icons.auto_awesome,
        titleEn: 'SWIFT MT103 Reconciliation',
        titleAr: 'استخراج ومطابقة السويفت (MT103)',
      ),
    ];

    return VerticalStageScaffold(
      stageCode: 'PHASE-1: STEP_04',
      titleEn: 'Financial Approvals & Budget Management',
      titleAr: 'الموافقات المالية وإدارة الميزانية',
      headerIcon: Icons.account_balance_wallet_outlined,
      headerColor: AppTheme.orange,
      tabs: tabs,
      selectedIndex: _tabController.index,
      onTabSelected: (index) => setState(() {
        _visitedTabs.add(index);
        _tabController.index = index;
      }),
      selectedImportFileId: _paySelectedImportFileId ??
          _bgtSelectedImportFileId ??
          widget.initialImportFileId,
      onShipmentStatusChanged: () {
        ref.read(paymentRequestsProvider.notifier).fetchPaymentRequests();
        ref.read(importBudgetsProvider.notifier).fetchImportBudgets();
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      },
      headerActions: [
        FinancialUi.fit(AppButton(
          label: l.whatIfSimulatorButton,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.small,
          icon: Icons.analytics_outlined,
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const WhatIfSimulatorDialog(),
            );
          },
        )),
        IconButton(
          icon: Icon(Icons.refresh, color: AppTheme.white.withValues(alpha: 0.7)),
          tooltip: l.liveRefreshTooltip,
          onPressed: () {
            ref.read(paymentRequestsProvider.notifier).fetchPaymentRequests();
            ref.read(importBudgetsProvider.notifier).fetchImportBudgets();
            ref.read(importFilesProvider.notifier).fetchImportFiles();
            ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
            ref.read(suppliersProvider.notifier).fetchSuppliers();
            ref.read(currenciesProvider.notifier).fetchCurrencies();
          },
        ),
      ],
      body: IndexedStack(
        index: _tabController.index,
        children: [
          // ── TAB 1: PAYMENT REQUEST FORM (BP-012) ───────────────────────────
          if (_visitedTabs.contains(0))
            CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyD, control: true):
                    () {
                  _openSearchAndClonePaymentDialog();
                },
              },
              child: Focus(
                autofocus: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _paymentFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          color: isDark
                              ? AppTheme.darkCardBackground
                              : AppTheme.white,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 700;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_editingPaymentId != null)
                                      Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 14),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppTheme.darkCardBackground
                                              : AppTheme.orangeLight,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: isDark
                                                  ? AppTheme.wcagOrange
                                                  : AppTheme.orange),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.edit_note,
                                                color: AppTheme.orange),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${l.activeEditModeBanner}: $_editingPaymentCode',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? AppTheme.orange
                                                      : AppTheme.wcagOrange,
                                                ),
                                              ),
                                            ),
                                            FinancialUi.fit(AppButton(
                                              label: l.cancelEdit,
                                              variant:
                                                  AppButtonVariant.secondary,
                                              icon: Icons.close,
                                              onPressed: () {
                                                setState(() {
                                                  _editingPaymentId = null;
                                                  _editingPaymentCode = null;
                                                  _editingPaymentVersion = null;
                                                  _payTitleController.clear();
                                                  _supplierNameController
                                                      .clear();
                                                  _amountController.clear();
                                                  _payNotesController.clear();
                                                  _paySelectedImportFileId =
                                                      null;
                                                  _payPrefillData = null;
                                                });
                                              },
                                            )),
                                          ],
                                        ),
                                      ),

                                    // Form Header with Responsive Search & Clone Action Button
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      runSpacing: 8,
                                      spacing: 12,
                                      children: [
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: constraints.maxWidth > 400
                                                ? constraints.maxWidth - 200
                                                : constraints.maxWidth,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  _editingPaymentId != null
                                                      ? '${l.editPaymentRequestTitle} ($_editingPaymentCode)'
                                                      : l.createPaymentRequestTitle,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? AppTheme
                                                            .darkTextPrimary
                                                        : AppTheme.charcoal,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (_isLoadingPayPrefill) ...[
                                                const SizedBox(width: 10),
                                                const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2)),
                                              ],
                                            ],
                                          ),
                                        ),
                                        FinancialUi.fit(AppButton(
                                          key: const ValueKey(
                                              'searchAndClonePaymentRequestBtn'),
                                          label:
                                              l.searchAndClonePaymentRequestBtn,
                                          variant: AppButtonVariant.secondary,
                                          size: AppButtonSize.small,
                                          icon: Icons.copy_all,
                                          onPressed:
                                              _openSearchAndClonePaymentDialog,
                                        )),
                                      ],
                                    ),
                                    const Divider(),
                                    const SizedBox(height: 6),

                                    // Smart AI SWIFT MT103 Interactive Extractor & Auto-Fill Box
                                    _buildPaySwiftExtractorWidget(),
                                    const SizedBox(height: 12),

                                    // Row 1: Import File & Payment Title
                                    if (isNarrow)
                                      Column(
                                        children: [
                                          SearchableDropdownField<int?>(
                                            value: _paySelectedImportFileId,
                                            labelText: '${l.importFile} *',
                                            searchHintText: l.search,
                                            items: [
                                              SearchableDropdownItem<int?>(
                                                value: null,
                                                label: '-- ${l.notLinked} --',
                                              ),
                                              ...(ref
                                                          .watch(
                                                              importFilesProvider)
                                                          .valueOrNull ??
                                                      [])
                                                  .map((f) =>
                                                      SearchableDropdownItem<
                                                          int?>(
                                                        value: f.importFileId,
                                                        label:
                                                            '${f.primaryNameWithCode} - ${f.companyName}',
                                                        subtitle: f.companyName,
                                                      )),
                                            ],
                                            onChanged: _onPayImportFileSelected,
                                          ),
                                          const SizedBox(height: 12),
                                          TextFormField(
                                            controller: _payTitleController,
                                            decoration: InputDecoration(
                                                labelText:
                                                    '${l.paymentTitleLabel} *',
                                                border:
                                                    const OutlineInputBorder()),
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                    ? l.requiredField
                                                    : null,
                                          ),
                                        ],
                                      )
                                    else
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child:
                                                SearchableDropdownField<int?>(
                                              value: _paySelectedImportFileId,
                                              labelText: '${l.importFile} *',
                                              searchHintText: l.search,
                                              items: [
                                                SearchableDropdownItem<int?>(
                                                  value: null,
                                                  label: '-- ${l.notLinked} --',
                                                ),
                                                ...(ref
                                                            .watch(
                                                                importFilesProvider)
                                                            .valueOrNull ??
                                                        [])
                                                    .map((f) =>
                                                        SearchableDropdownItem<
                                                            int?>(
                                                          value: f.importFileId,
                                                          label:
                                                              '${f.primaryNameWithCode} - ${f.companyName}',
                                                          subtitle:
                                                              f.companyName,
                                                        )),
                                              ],
                                              onChanged:
                                                  _onPayImportFileSelected,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 3,
                                            child: TextFormField(
                                              controller: _payTitleController,
                                              decoration: InputDecoration(
                                                  labelText:
                                                      '${l.paymentTitleLabel} *',
                                                  border:
                                                      const OutlineInputBorder()),
                                              validator: (v) => (v == null ||
                                                      v.trim().isEmpty)
                                                  ? l.requiredField
                                                  : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 12),

                                    // Row 2: Supplier Master Data, Beneficiary Name, Payment Type
                                    if (constraints.maxWidth < 750)
                                      Column(
                                        children: [
                                          SearchableDropdownField<int?>(
                                            value: _selectedSupplierId,
                                            labelText:
                                                l.selectSupplierFromMasterData,
                                            searchHintText: l.search,
                                            items: suppliersList
                                                .map((s) =>
                                                    SearchableDropdownItem<
                                                        int?>(
                                                      value: s.supplierId,
                                                      label: s.companyName,
                                                      subtitle: s
                                                          .foreignExporterCountry,
                                                    ))
                                                .toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                final sup = suppliersList
                                                    .firstWhere((s) =>
                                                        s.supplierId == val);
                                                setState(() {
                                                  _selectedSupplierId = val;
                                                  _supplierNameController.text =
                                                      sup.companyName;
                                                  if (sup.bankName != null &&
                                                      sup.bankName!.isNotEmpty) {
                                                    _bankNameController.text =
                                                        sup.bankName!;
                                                  }
                                                  if (sup.swiftCode != null &&
                                                      sup.swiftCode!.isNotEmpty) {
                                                    _swiftCodeController.text =
                                                        sup.swiftCode!;
                                                  }
                                                  if (sup.iban != null &&
                                                      sup.iban!.isNotEmpty) {
                                                    _ibanController.text =
                                                        sup.iban!;
                                                  } else if (sup
                                                              .accountNumber !=
                                                          null &&
                                                      sup.accountNumber!
                                                          .isNotEmpty) {
                                                    _ibanController.text =
                                                        sup.accountNumber!;
                                                  }
                                                });
                                              }
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          TextFormField(
                                            controller: _supplierNameController,
                                            decoration: InputDecoration(
                                                labelText:
                                                    '${l.beneficiarySupplierLabel} *',
                                                border:
                                                    const OutlineInputBorder()),
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                    ? l.requiredField
                                                    : null,
                                          ),
                                          const SizedBox(height: 12),
                                          SearchableDropdownField<String>(
                                            key: const ValueKey(
                                                'payment_type_dropdown'),
                                            value: _paymentType,
                                            labelText:
                                                '${l.paymentTypeLabel} *',
                                            searchHintText: l.search,
                                            items:
                                                FinancialUi.paymentTypeItems(l),
                                            onChanged: (v) {
                                              if (v != null) {
                                                setState(
                                                    () => _paymentType = v);
                                              }
                                            },
                                          ),
                                        ],
                                      )
                                    else
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child:
                                                SearchableDropdownField<int?>(
                                              value: _selectedSupplierId,
                                              labelText: l
                                                  .selectSupplierFromMasterData,
                                              searchHintText: l.search,
                                              items: suppliersList
                                                  .map((s) =>
                                                      SearchableDropdownItem<
                                                          int?>(
                                                        value: s.supplierId,
                                                        label: s.companyName,
                                                        subtitle: s
                                                            .foreignExporterCountry,
                                                      ))
                                                  .toList(),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  final sup = suppliersList
                                                      .firstWhere((s) =>
                                                          s.supplierId == val);
                                                  setState(() {
                                                    _selectedSupplierId = val;
                                                    _supplierNameController
                                                        .text = sup.companyName;
                                                    if (sup.bankName != null &&
                                                        sup.bankName!
                                                            .isNotEmpty) {
                                                      _bankNameController.text =
                                                          sup.bankName!;
                                                    }
                                                    if (sup.swiftCode != null &&
                                                        sup.swiftCode!
                                                            .isNotEmpty) {
                                                      _swiftCodeController
                                                              .text =
                                                          sup.swiftCode!;
                                                    }
                                                    if (sup.iban != null &&
                                                        sup.iban!.isNotEmpty) {
                                                      _ibanController.text =
                                                          sup.iban!;
                                                    } else if (sup
                                                                .accountNumber !=
                                                            null &&
                                                        sup.accountNumber!
                                                            .isNotEmpty) {
                                                      _ibanController.text =
                                                          sup.accountNumber!;
                                                    }
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 2,
                                            child: TextFormField(
                                              controller:
                                                  _supplierNameController,
                                              decoration: InputDecoration(
                                                  labelText:
                                                      '${l.beneficiarySupplierLabel} *',
                                                  border:
                                                      const OutlineInputBorder()),
                                              validator: (v) => (v == null ||
                                                      v.trim().isEmpty)
                                                  ? l.requiredField
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 2,
                                            child:
                                                SearchableDropdownField<String>(
                                              key: const ValueKey(
                                                  'payment_type_dropdown'),
                                              value: _paymentType,
                                              labelText:
                                                  '${l.paymentTypeLabel} *',
                                              searchHintText: l.search,
                                              items:
                                                  FinancialUi.paymentTypeItems(
                                                      l),
                                              onChanged: (v) {
                                                if (v != null) {
                                                  setState(
                                                      () => _paymentType = v);
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 12),

                                    if (_openSameTypeRequest != null) ...[
                                      Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppTheme.darkCardBackground
                                              : AppTheme.orangeLight,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: AppTheme.wcagOrange,
                                              width: 1.5),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                                Icons.warning_amber_rounded,
                                                color: AppTheme.wcagOrange,
                                                size: 20),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                l.faOpenPaymentSameType(
                                                    _openSameTypeRequest!
                                                        .paymentCode),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? AppTheme.darkTextPrimary
                                                      : AppTheme.charcoal,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            AppButton(
                                              label: l.viewDetails,
                                              variant:
                                                  AppButtonVariant.secondary,
                                              size: AppButtonSize.small,
                                              onPressed: () =>
                                                  _showPaymentDetailsDialog(
                                                      _openSameTypeRequest!),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    if (_payPrefillData != null &&
                                        _payPrefillData!.totalInvoiceAmount >
                                            0) ...[
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            context.l10n.faPercentFromPo(
                                                _payPrefillData!
                                                    .totalInvoiceAmount
                                                    .toStringAsFixed(2),
                                                _currencyCode),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? AppTheme.darkTextSecondary
                                                  : AppTheme.textStrong,
                                            ),
                                          ),
                                          ...[10.0, 20.0, 30.0, 50.0, 100.0]
                                              .map((pct) {
                                            final isSel =
                                                _paySelectedPercentage == pct;
                                            return ChoiceChip(
                                              label: Text(
                                                  '${pct.toStringAsFixed(0)}%'),
                                              selected: isSel,
                                              selectedColor:
                                                  AppTheme.wcagOrange,
                                              labelStyle: TextStyle(
                                                fontSize: 11,
                                                color: isSel
                                                    ? AppTheme.white
                                                    : (isDark
                                                        ? AppTheme
                                                            .darkTextPrimary
                                                        : AppTheme.charcoal),
                                                fontWeight: isSel
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onSelected: (_) =>
                                                  _applyAdvancePercentageToAmount(
                                                      pct),
                                            );
                                          }),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                    ],

                                    // Row 3: Amount, Currency, Exchange Rate, Request Date, Due Date (5 fields responsive)
                                    if (constraints.maxWidth >= 1100)
                                      Row(
                                        children: [
                                          Expanded(child: _buildAmountField(l)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                              child: _buildCurrencyDropdown(l)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                              child:
                                                  _buildExchangeRateField(l)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                              child: _buildRequestDateField(l)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                              child: _buildDueDateField(l)),
                                        ],
                                      )
                                    else if (constraints.maxWidth >= 700)
                                      Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                  child: _buildAmountField(l)),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                  child: _buildCurrencyDropdown(
                                                      l)),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                  child:
                                                      _buildExchangeRateField(
                                                          l)),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                  child: _buildRequestDateField(
                                                      l)),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                  child: _buildDueDateField(l)),
                                            ],
                                          ),
                                        ],
                                      )
                                    else
                                      Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                  child: _buildAmountField(l)),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                  child: _buildCurrencyDropdown(
                                                      l)),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          _buildExchangeRateField(l),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                  child: _buildRequestDateField(
                                                      l)),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                  child: _buildDueDateField(l)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 16),

                                    // Supplier Banking Details Card (WCAG AA)
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppTheme.darkElevatedSurface
                                            : AppTheme.cobaltLight
                                                .withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: isDark
                                                ? AppTheme.darkBorder
                                                : AppTheme.cobaltBorder),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${l.beneficiaryBankDetails}:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isDark
                                                  ? AppTheme.darkTextPrimary
                                                  : AppTheme.cobalt,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          if (isNarrow)
                                            Column(
                                              children: [
                                                TextFormField(
                                                  controller:
                                                      _bankNameController,
                                                  decoration: InputDecoration(
                                                      labelText:
                                                          l.bankNameLabel,
                                                      border:
                                                          const OutlineInputBorder()),
                                                ),
                                                const SizedBox(height: 10),
                                                TextFormField(
                                                  controller:
                                                      _swiftCodeController,
                                                  textDirection:
                                                      TextDirection.ltr,
                                                  decoration: InputDecoration(
                                                      labelText:
                                                          l.swiftCodeLabel,
                                                      border:
                                                          const OutlineInputBorder()),
                                                ),
                                                const SizedBox(height: 10),
                                                TextFormField(
                                                  controller: _ibanController,
                                                  textDirection:
                                                      TextDirection.ltr,
                                                  decoration: InputDecoration(
                                                      labelText:
                                                          l.ibanAccountLabel,
                                                      border:
                                                          const OutlineInputBorder()),
                                                ),
                                              ],
                                            )
                                          else
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    controller:
                                                        _bankNameController,
                                                    decoration: InputDecoration(
                                                        labelText:
                                                            l.bankNameLabel,
                                                        border:
                                                            const OutlineInputBorder()),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: TextFormField(
                                                    controller:
                                                        _swiftCodeController,
                                                    textDirection:
                                                        TextDirection.ltr,
                                                    decoration: InputDecoration(
                                                        labelText:
                                                            l.swiftCodeLabel,
                                                        border:
                                                            const OutlineInputBorder()),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: TextFormField(
                                                    controller: _ibanController,
                                                    textDirection:
                                                        TextDirection.ltr,
                                                    decoration: InputDecoration(
                                                        labelText:
                                                            l.ibanAccountLabel,
                                                        border:
                                                            const OutlineInputBorder()),
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Linked Purchase Orders Section
                                    if (_payPrefillData != null &&
                                        _payPrefillData!
                                            .linkedPos.isNotEmpty) ...[
                                      Text(
                                        '${l.linkedPurchaseOrdersTitle}:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark
                                              ? AppTheme.darkTextPrimary
                                              : AppTheme.charcoal,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (constraints.maxWidth < 768)
                                        _buildMobileLinkedPOCardsList(l, isDark)
                                      else
                                        Table(
                                          border: TableBorder.all(
                                              color: isDark
                                                  ? AppTheme.darkBorder
                                                  : AppTheme.cloudWhite),
                                          columnWidths: const {
                                            0: FlexColumnWidth(1.5),
                                            1: FlexColumnWidth(1.5),
                                            2: FlexColumnWidth(1.8),
                                            3: FlexColumnWidth(1.2),
                                            4: FlexColumnWidth(1.4),
                                            5: FlexColumnWidth(1.2),
                                            6: FixedColumnWidth(40),
                                          },
                                          children: [
                                            TableRow(
                                              decoration: BoxDecoration(
                                                  color: isDark
                                                      ? AppTheme
                                                          .darkElevatedSurface
                                                      : AppTheme.charcoal),
                                              children: [
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    child: Text(l.poNumberCol,
                                                        style: const TextStyle(
                                                            color:
                                                                AppTheme.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12))),
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    child: Text(
                                                        l.projectNameCol,
                                                        style: const TextStyle(
                                                            color:
                                                                AppTheme.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12))),
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    child: Text(
                                                        l.paymentTypeLabel,
                                                        style: const TextStyle(
                                                            color:
                                                                AppTheme.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12))),
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    child: Text(l.currencyCol,
                                                        style: const TextStyle(
                                                            color:
                                                                AppTheme.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12))),
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    child: Text(l.invoiceAmount,
                                                        style: const TextStyle(
                                                            color:
                                                                AppTheme.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12))),
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    child: Text(l.statusCol,
                                                        style: const TextStyle(
                                                            color:
                                                                AppTheme.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12))),
                                                const SizedBox.shrink(),
                                              ],
                                            ),
                                            ..._payPrefillData!.linkedPos
                                                .map((po) {
                                              return TableRow(
                                                children: [
                                                  Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            CopyableText(
                                                                po.displayName,
                                                                style: const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: AppTheme
                                                                        .cobalt)),
                                                            if (po.displayName !=
                                                                po.poNumber)
                                                              CopyableText(
                                                                  po.poNumber,
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                      color: isDark
                                                                          ? AppTheme
                                                                              .darkTextSecondary
                                                                          : AppTheme
                                                                              .textMuted))
                                                          ])),
                                                  Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      child: CopyableText(
                                                          po.projectName ??
                                                              '-')),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: isDark
                                                            ? AppTheme
                                                                .darkCardBackground
                                                            : AppTheme
                                                                .orangeLight,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                        border: Border.all(
                                                            color: isDark
                                                                ? AppTheme
                                                                    .wcagOrange
                                                                : AppTheme
                                                                    .orange),
                                                      ),
                                                      child: CopyableText(
                                                        po.paymentTerms,
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: isDark
                                                                ? AppTheme
                                                                    .orange
                                                                : AppTheme
                                                                    .wcagOrange,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      child: CopyableText(
                                                          po.currency,
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600))),
                                                  Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      child: CopyableText(
                                                          '${po.totalAmount.toStringAsFixed(2)} ${po.currency}',
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: AppTheme
                                                                  .emerald))),
                                                  Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      child: CopyableText(
                                                          po.status,
                                                          style: const TextStyle(
                                                              fontSize: 11,
                                                              color: AppTheme
                                                                  .cobalt))),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    child: IconButton(
                                                      icon: const Icon(
                                                          Icons.copy_rounded,
                                                          size: 16,
                                                          color:
                                                              AppTheme.cobalt),
                                                      tooltip: l
                                                          .clonePoAllocationTooltip,
                                                      onPressed: () =>
                                                          _cloneLinkedPoItem(
                                                              po),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }),
                                          ],
                                        ),
                                      const SizedBox(height: 16),
                                    ],

                                    TextFormField(
                                      controller: _payNotesController,
                                      decoration: InputDecoration(
                                          labelText: l.paymentNotesLabel,
                                          border: const OutlineInputBorder()),
                                    ),
                                    const SizedBox(height: 20),
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 12,
                                      runSpacing: 10,
                                      children: [
                                        if (_editingPaymentId != null)
                                          FinancialUi.fit(AppButton(
                                            label: l.cancelEdit,
                                            variant: AppButtonVariant.secondary,
                                            icon: Icons.close,
                                            onPressed: () {
                                              setState(() {
                                                _editingPaymentId = null;
                                                _editingPaymentCode = null;
                                                _editingPaymentVersion = null;
                                                _paySelectedImportFileId = null;
                                                _payPrefillData = null;
                                                _payTitleController.clear();
                                                _supplierNameController.clear();
                                                _amountController.clear();
                                                _bankNameController.clear();
                                                _swiftCodeController.clear();
                                                _ibanController.clear();
                                                _payNotesController.clear();
                                              });
                                            },
                                          ))
                                        else
                                          const SizedBox.shrink(),
                                        FinancialUi.fit(AppButton(
                                          label: _editingPaymentId != null
                                              ? l.savePaymentChangesButton
                                              : l.issuePaymentRequestButton,
                                          variant: AppButtonVariant.primary,
                                          icon: _editingPaymentId != null
                                              ? Icons.save
                                              : Icons.send,
                                          isLoading: _isSavingPayment,
                                          onPressed: _isSavingPayment
                                              ? null
                                              : _savePaymentRequest,
                                        )),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox.shrink(),

          // ── TAB 2: IMPORT BUDGET APPROVAL FORM (BP-013) ────────────────────
          if (_visitedTabs.contains(1))
            CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyD, control: true):
                    () {
                  _openSearchAndCloneBudgetDialog();
                },
              },
              child: Focus(
                autofocus: true,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 700;
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;

                    return SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 12 : 20),
                      child: Form(
                        key: _budgetFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              elevation: isDark ? 0 : 2,
                              color: isDark
                                  ? AppTheme.darkCardBackground
                                  : AppTheme.white,
                              surfaceTintColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                    color: isDark
                                        ? AppTheme.darkBorder
                                        : AppTheme.cloudWhite),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(isMobile ? 14 : 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header with Clone Button
                                    isMobile
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      l.importBudgetSetupTitle,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: isDark
                                                            ? AppTheme
                                                                .darkTextPrimary
                                                            : AppTheme.charcoal,
                                                      ),
                                                    ),
                                                  ),
                                                  if (_isLoadingBgtPrefill)
                                                    const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth:
                                                                    2)),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              FinancialUi.fit(AppButton(
                                                key: const Key(
                                                    'searchAndCloneBudgetBtn'),
                                                label:
                                                    l.searchAndCloneBudgetBtn,
                                                variant:
                                                    AppButtonVariant.secondary,
                                                size: AppButtonSize.small,
                                                icon: Icons.copy_all,
                                                onPressed:
                                                    _openSearchAndCloneBudgetDialog,
                                              )),
                                            ],
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        l.importBudgetSetupTitle,
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isDark
                                                              ? AppTheme
                                                                  .darkTextPrimary
                                                              : AppTheme
                                                                  .charcoal,
                                                        ),
                                                      ),
                                                    ),
                                                    if (_isLoadingBgtPrefill) ...[
                                                      const SizedBox(width: 12),
                                                      const SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child:
                                                              CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2)),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              FinancialUi.fit(AppButton(
                                                key: const Key(
                                                    'searchAndCloneBudgetBtn'),
                                                label:
                                                    l.searchAndCloneBudgetBtn,
                                                variant:
                                                    AppButtonVariant.secondary,
                                                size: AppButtonSize.small,
                                                icon: Icons.copy_all,
                                                onPressed:
                                                    _openSearchAndCloneBudgetDialog,
                                              )),
                                            ],
                                          ),
                                    Divider(
                                        color: isDark
                                            ? AppTheme.darkBorder
                                            : AppTheme.cloudWhite),
                                    const SizedBox(height: 10),

                                    // Row 1: Import File & Title
                                    if (isMobile) ...[
                                      SearchableDropdownField<int?>(
                                        value: _bgtSelectedImportFileId,
                                        labelText: '${l.importFile} *',
                                        searchHintText: l.search,
                                        items: [
                                          SearchableDropdownItem<int?>(
                                            value: null,
                                            label: '-- ${l.notLinked} --',
                                          ),
                                          ...(ref
                                                      .watch(
                                                          importFilesProvider)
                                                      .valueOrNull ??
                                                  [])
                                              .map((f) =>
                                                  SearchableDropdownItem<int?>(
                                                    value: f.importFileId,
                                                    label:
                                                        '${f.primaryNameWithCode} - ${f.companyName}',
                                                    subtitle: f.companyName,
                                                  )),
                                        ],
                                        onChanged: _onBgtImportFileSelected,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _bgtTitleController,
                                        decoration: InputDecoration(
                                          labelText: '${l.budgetTitleLabel} *',
                                          border: const OutlineInputBorder(),
                                          fillColor: isDark
                                              ? AppTheme.darkElevatedSurface
                                              : AppTheme.white,
                                          filled: isDark,
                                        ),
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                                ? l.requiredField
                                                : null,
                                      ),
                                    ] else
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child:
                                                SearchableDropdownField<int?>(
                                              value: _bgtSelectedImportFileId,
                                              labelText: '${l.importFile} *',
                                              searchHintText: l.search,
                                              items: [
                                                SearchableDropdownItem<int?>(
                                                  value: null,
                                                  label: '-- ${l.notLinked} --',
                                                ),
                                                ...(ref
                                                            .watch(
                                                                importFilesProvider)
                                                            .valueOrNull ??
                                                        [])
                                                    .map((f) =>
                                                        SearchableDropdownItem<
                                                            int?>(
                                                          value: f.importFileId,
                                                          label:
                                                              '${f.primaryNameWithCode} - ${f.companyName}',
                                                          subtitle:
                                                              f.companyName,
                                                        )),
                                              ],
                                              onChanged:
                                                  _onBgtImportFileSelected,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 3,
                                            child: TextFormField(
                                              controller: _bgtTitleController,
                                              decoration: InputDecoration(
                                                labelText:
                                                    '${l.budgetTitleLabel} *',
                                                border:
                                                    const OutlineInputBorder(),
                                                fillColor: isDark
                                                    ? AppTheme
                                                        .darkElevatedSurface
                                                    : AppTheme.white,
                                                filled: isDark,
                                              ),
                                              validator: (v) => (v == null ||
                                                      v.trim().isEmpty)
                                                  ? l.requiredField
                                                  : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 16),

                                    // Upstream Variance Alert Banner
                                    _buildUpstreamVarianceAlertBanner(),
                                    const SizedBox(height: 12),

                                    // Multi-Currency Live Consolidated Breakdown Tables
                                    _buildConsolidatedBudgetSummary(
                                        prefill: _bgtPrefillData),
                                    const SizedBox(height: 16),

                                    // Cost & Currency Inputs
                                    if (isMobile) ...[
                                      _buildBgtInvoiceCurrencyDropdown(l),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _invoiceForeignController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText:
                                              ' ()',
                                          border: const OutlineInputBorder(),
                                          fillColor: isDark
                                              ? AppTheme.darkElevatedSurface
                                              : AppTheme.white,
                                          filled: isDark,
                                        ),
                                        onChanged: (v) {
                                          final f = double.tryParse(v) ?? 0;
                                          final r = double.tryParse(
                                                  _bgtExchangeRateController
                                                      .text) ??
                                              0;
                                          _invoiceEgpController.text =
                                              (f * r).toStringAsFixed(2);
                                          setState(() {});
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _bgtExchangeRateController,
                                        keyboardType: TextInputType.number,
                                        validator: _validateExchangeRate,
                                        decoration: InputDecoration(
                                          labelText:
                                              ' (EGP)',
                                          border: const OutlineInputBorder(),
                                          fillColor: isDark
                                              ? AppTheme.darkElevatedSurface
                                              : AppTheme.white,
                                          filled: isDark,
                                        ),
                                        onChanged: (v) {
                                          final r = double.tryParse(v) ?? 0;
                                          final inv = double.tryParse(
                                                  _invoiceForeignController
                                                      .text) ??
                                              0;
                                          _invoiceEgpController.text =
                                              (inv * r).toStringAsFixed(2);
                                          setState(() {});
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      _buildBgtFreightCurrencyDropdown(l),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _freightForeignController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText:
                                              ' ()',
                                          border: const OutlineInputBorder(),
                                          fillColor: isDark
                                              ? AppTheme.darkElevatedSurface
                                              : AppTheme.white,
                                          filled: isDark,
                                        ),
                                        onChanged: (v) {
                                          final f = double.tryParse(v) ?? 0;
                                          final r = double.tryParse(
                                                  _bgtFreightRateController
                                                      .text) ??
                                              0;
                                          _freightEgpController.text =
                                              (f * r).toStringAsFixed(2);
                                          setState(() {});
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _bgtFreightRateController,
                                        keyboardType: TextInputType.number,
                                        validator: _validateFreightExchangeRate,
                                        decoration: InputDecoration(
                                          labelText:
                                              ' (EGP)',
                                          border: const OutlineInputBorder(),
                                          fillColor: isDark
                                              ? AppTheme.darkElevatedSurface
                                              : AppTheme.white,
                                          filled: isDark,
                                        ),
                                        onChanged: (v) {
                                          final r = double.tryParse(v) ?? 0;
                                          final frt = double.tryParse(
                                                  _freightForeignController
                                                      .text) ??
                                              0;
                                          _freightEgpController.text =
                                              (frt * r).toStringAsFixed(2);
                                          setState(() {});
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _customsEgpController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText:
                                              ' (EGP)',
                                          border: const OutlineInputBorder(),
                                          fillColor: isDark
                                              ? AppTheme.darkElevatedSurface
                                              : AppTheme.white,
                                          filled: isDark,
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _clearanceEgpController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText:
                                              ' (EGP)',
                                          border: const OutlineInputBorder(),
                                          fillColor: isDark
                                              ? AppTheme.darkElevatedSurface
                                              : AppTheme.white,
                                          filled: isDark,
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ] else ...[
                                      // Row A: Invoice Currency, Value & Exchange Rate
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child:
                                                _buildBgtInvoiceCurrencyDropdown(
                                                    l),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 3,
                                            child: TextFormField(
                                              controller:
                                                  _invoiceForeignController,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText:
                                                    ' ()',
                                                border:
                                                    const OutlineInputBorder(),
                                                fillColor: isDark
                                                    ? AppTheme
                                                        .darkElevatedSurface
                                                    : AppTheme.white,
                                                filled: isDark,
                                              ),
                                              onChanged: (v) {
                                                final f =
                                                    double.tryParse(v) ?? 0;
                                                final r = double.tryParse(
                                                        _bgtExchangeRateController
                                                            .text) ??
                                                    0;
                                                _invoiceEgpController.text =
                                                    (f * r).toStringAsFixed(2);
                                                setState(() {});
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 2,
                                            child: TextFormField(
                                              controller:
                                                  _bgtExchangeRateController,
                                              keyboardType:
                                                  TextInputType.number,
                                              validator: _validateExchangeRate,
                                              decoration: InputDecoration(
                                                labelText:
                                                    ' (EGP)',
                                                border:
                                                    const OutlineInputBorder(),
                                                fillColor: isDark
                                                    ? AppTheme
                                                        .darkElevatedSurface
                                                    : AppTheme.white,
                                                filled: isDark,
                                              ),
                                              onChanged: (v) {
                                                final r =
                                                    double.tryParse(v) ?? 0;
                                                final inv = double.tryParse(
                                                        _invoiceForeignController
                                                            .text) ??
                                                    0;
                                                _invoiceEgpController.text =
                                                    (inv * r)
                                                        .toStringAsFixed(2);
                                                setState(() {});
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Row B: Freight Currency, Cost & Freight Rate
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child:
                                                _buildBgtFreightCurrencyDropdown(
                                                    l),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 3,
                                            child: TextFormField(
                                              controller:
                                                  _freightForeignController,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText:
                                                    ' ()',
                                                border:
                                                    const OutlineInputBorder(),
                                                fillColor: isDark
                                                    ? AppTheme
                                                        .darkElevatedSurface
                                                    : AppTheme.white,
                                                filled: isDark,
                                              ),
                                              onChanged: (v) {
                                                final f =
                                                    double.tryParse(v) ?? 0;
                                                final r = double.tryParse(
                                                        _bgtFreightRateController
                                                            .text) ??
                                                    0;
                                                _freightEgpController.text =
                                                    (f * r).toStringAsFixed(2);
                                                setState(() {});
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 2,
                                            child: TextFormField(
                                              controller:
                                                  _bgtFreightRateController,
                                              keyboardType:
                                                  TextInputType.number,
                                              validator:
                                                  _validateFreightExchangeRate,
                                              decoration: InputDecoration(
                                                labelText:
                                                    ' (EGP)',
                                                border:
                                                    const OutlineInputBorder(),
                                                fillColor: isDark
                                                    ? AppTheme
                                                        .darkElevatedSurface
                                                    : AppTheme.white,
                                                filled: isDark,
                                              ),
                                              onChanged: (v) {
                                                final r =
                                                    double.tryParse(v) ?? 0;
                                                final frt = double.tryParse(
                                                        _freightForeignController
                                                            .text) ??
                                                    0;
                                                _freightEgpController.text =
                                                    (frt * r)
                                                        .toStringAsFixed(2);
                                                setState(() {});
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Row B: Local EGP Duties & Clearance
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _customsEgpController,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText:
                                                    '${l.customsAndVatEstimate} (EGP)',
                                                border:
                                                    const OutlineInputBorder(),
                                                fillColor: isDark
                                                    ? AppTheme
                                                        .darkElevatedSurface
                                                    : AppTheme.white,
                                                filled: isDark,
                                              ),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextFormField(
                                              controller:
                                                  _clearanceEgpController,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText:
                                                    '${l.clearanceAndTransportEstimate} (EGP)',
                                                border:
                                                    const OutlineInputBorder(),
                                                fillColor: isDark
                                                    ? AppTheme
                                                        .darkElevatedSurface
                                                    : AppTheme.white,
                                                filled: isDark,
                                              ),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 16),

                                    TextFormField(
                                      controller: _bgtNotesController,
                                      decoration: InputDecoration(
                                        labelText: l.budgetApprovalNotes,
                                        border: const OutlineInputBorder(),
                                        fillColor: isDark
                                            ? AppTheme.darkElevatedSurface
                                            : AppTheme.white,
                                        filled: isDark,
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Responsive Action Buttons Wrap
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            // 1. Live Refresh
                                            FinancialUi.fit(AppButton(
                                              label: l.refresh,
                                              variant:
                                                  AppButtonVariant.secondary,
                                              icon: Icons.refresh,
                                              onPressed: () {
                                                ref
                                                    .read(importBudgetsProvider
                                                        .notifier)
                                                    .fetchImportBudgets();
                                                ref
                                                    .read(
                                                        paymentRequestsProvider
                                                            .notifier)
                                                    .fetchPaymentRequests();
                                                ref
                                                    .read(importFilesProvider
                                                        .notifier)
                                                    .fetchImportFiles();
                                              },
                                            )),

                                            // 2. Clear Form & Start New
                                            FinancialUi.fit(AppButton(
                                              label: l.reset,
                                              variant:
                                                  AppButtonVariant.secondary,
                                              icon: Icons
                                                  .cleaning_services_outlined,
                                              onPressed: () {
                                                setState(() {
                                                  _editingBudgetId = null;
                                                  _editingBudgetVersion = null;
                                                  _bgtSelectedImportFileId =
                                                      null;
                                                  _bgtPrefillData = null;
                                                  _bgtNotesController.clear();
                                                });
                                              },
                                            )),

                                            // 3. Save Draft & Continue Later
                                            FinancialUi.fit(AppButton(
                                              label: _editingBudgetId != null
                                                  ? l.saveBudgetChanges
                                                  : l.saveDraft,
                                              variant: AppButtonVariant.primary,
                                              icon: Icons.save_outlined,
                                              onPressed: _isSavingBudget
                                                  ? null
                                                  : _saveImportBudget,
                                            )),

                                            // 4. Final Approval
                                            FinancialUi.fit(AppButton(
                                              label: _editingBudgetId != null
                                                  ? l.saveAndApproveBudget
                                                  : l.approveAndCertifyBudget,
                                              variant: AppButtonVariant.success,
                                              icon: Icons.verified,
                                              isLoading: _isSavingBudget,
                                              onPressed: _isSavingBudget
                                                  ? null
                                                  : _saveAndApproveBudget,
                                            )),
                                          ],
                                        ),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            FinancialUi.fit(AppButton(
                                              label: l.exportExcel,
                                              variant:
                                                  AppButtonVariant.secondary,
                                              icon: Icons.table_chart,
                                              onPressed: () async {
                                                final bgt = _lastSavedBudget ??
                                                    _buildTempBudgetModel();
                                                final messenger =
                                                    ScaffoldMessenger.of(
                                                        context);
                                                final path =
                                                    await FinancialExportService
                                                        .exportBudgetToExcel(
                                                  context: context,
                                                  budget: bgt,
                                                  prefill: _bgtPrefillData,
                                                );
                                                if (path != null && mounted) {
                                                  messenger.showSnackBar(
                                                    SnackBar(
                                                        content:
                                                            Text('✅ $path'),
                                                        backgroundColor:
                                                            AppTheme.emerald),
                                                  );
                                                }
                                              },
                                            )),
                                            FinancialUi.fit(AppButton(
                                              label: l.print,
                                              variant: AppButtonVariant.primary,
                                              icon: Icons.print,
                                              onPressed: () {
                                                final bgt = _lastSavedBudget ??
                                                    _buildTempBudgetModel();
                                                FinancialExportService
                                                    .printOrSaveBudgetPdf(
                                                  budget: bgt,
                                                  prefill: _bgtPrefillData,
                                                );
                                              },
                                            )),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
          else
            const SizedBox.shrink(),

          // ── TAB 3: SAVED BUDGETS REGISTRY (سجل الميزانيات الاستيرادية المعتمدة) ───
          if (_visitedTabs.contains(2))
            CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyD, control: true):
                    () {
                  _openSearchAndCloneBudgetDialog();
                },
              },
              child: Focus(
                autofocus: true,
                child: SavedBudgetsRegistryTab(
                  onEditBudget: _loadBudgetForEdit,
                  onCloneBudget: _openCloneBudgetReviewDialog,
                  onSearchAndClone: _openSearchAndCloneBudgetDialog,
                  onSwitchToForm: () => setState(() {
                    _visitedTabs.add(1);
                    _tabController.index = 1;
                  }),
                ),
              ),
            )
          else
            const SizedBox.shrink(),

          // ── TAB 4: PAYMENT REQUESTS REGISTRY (سجل طلبات السداد والتحويلات) ─────────
          if (_visitedTabs.contains(3))
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary metrics (shared compact strip)
                  paymentsState.maybeWhen(
                    data: (payments) {
                      final pending = payments.where((p) {
                        final s = p.status.toLowerCase();
                        return s.contains('pending') || s == 'draft';
                      }).length;
                      final paid = payments
                          .where((p) => p.status.toLowerCase() == 'paid')
                          .length;
                      final totalEgp = payments.fold<double>(
                          0.0, (sum, p) => sum + p.requestedAmountEgp);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FinancialUi.metrics([
                          MetricCardData(
                            icon: Icons.receipt_long_outlined,
                            title: l.swiftTotalRequestsMetric,
                            value: '${payments.length}',
                            color: AppTheme.cobalt,
                          ),
                          MetricCardData(
                            icon: Icons.hourglass_top_rounded,
                            title: l.statusPendingReview,
                            value: '$pending',
                            color: AppTheme.orange,
                          ),
                          MetricCardData(
                            icon: Icons.check_circle_outline,
                            title: l.paidStatus,
                            value: '$paid',
                            color: AppTheme.emerald,
                          ),
                          MetricCardData(
                            icon: Icons.monetization_on_outlined,
                            title: l.totalValueEgpMetric,
                            value: '${totalEgp.toStringAsFixed(2)} EGP',
                            color: AppTheme.emerald,
                          ),
                        ]),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),

                  // Top Master Data Toolbar
                  paymentsState.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (payments) {
                      final filtered = payments.where((p) {
                        final matchQ = _searchQuery.isEmpty ||
                            p.paymentCode
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()) ||
                            p.supplierName
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()) ||
                            p.title
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()) ||
                            (p.importFileCode ?? '')
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase());
                        final matchS =
                            _statusFilter == 'All' || p.status == _statusFilter;
                        return matchQ && matchS;
                      }).toList();

                      return MasterDataToolbarWidget(
                        moduleEndpoint: 'financial-approval',
                        title:
                            '${l.paymentRequestsLogTitle} (${filtered.length})',
                        onExportExcel: () => FinancialExportService
                            .exportPaymentRequestsListToExcel(
                                context: context, list: filtered),
                        onRefreshNeeded: () => ref
                            .read(paymentRequestsProvider.notifier)
                            .fetchPaymentRequests(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Search & Filters Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: l.searchPaymentsHint,
                            prefixIcon: const Icon(Icons.search),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 220,
                        child: SearchableDropdownField<String>(
                          value: _statusFilter,
                          labelText: l.filterByStatus,
                          searchHintText: l.search,
                          items: [
                            SearchableDropdownItem(
                                value: 'All', label: l.allStatuses),
                            SearchableDropdownItem(
                                value: 'Draft', label: l.draftStatus),
                            SearchableDropdownItem(
                                value: 'Approved',
                                label: l.approvedBudgetsMetric),
                            SearchableDropdownItem(
                                value: 'Paid', label: l.paidStatus),
                            SearchableDropdownItem(
                                value: 'Reconciled', label: l.reconciledStatus),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _statusFilter = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Standardized Saved Registry Table Container
                  Expanded(
                    child: paymentsState.when(
                      loading: () => const FinancialStateView.loading(),
                      error: (err, stack) => FinancialStateView.error(
                        message: l.faLoadFailed(ApiError.message(err)),
                        actionLabel: l.retry,
                        onAction: () => ref
                            .read(paymentRequestsProvider.notifier)
                            .fetchPaymentRequests(),
                      ),
                      data: (payments) {
                        final allFiles =
                            ref.watch(importFilesProvider).valueOrNull ?? [];
                        final isAr =
                            Localizations.localeOf(context).languageCode ==
                                'ar';
                        final filtered = payments.where((p) {
                          final matchQ = _searchQuery.isEmpty ||
                              p.paymentCode
                                  .toLowerCase()
                                  .contains(_searchQuery.toLowerCase()) ||
                              p.supplierName
                                  .toLowerCase()
                                  .contains(_searchQuery.toLowerCase()) ||
                              p.title
                                  .toLowerCase()
                                  .contains(_searchQuery.toLowerCase()) ||
                              (p.importFileCode ?? '')
                                  .toLowerCase()
                                  .contains(_searchQuery.toLowerCase());
                          final matchS = _statusFilter == 'All' ||
                              p.status == _statusFilter;
                          return matchQ && matchS;
                        }).toList();

                        if (filtered.isEmpty) {
                          return FinancialStateView.empty(
                            icon: Icons.receipt_long_outlined,
                            message: l.noMatchingPayments,
                          );
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: AppTheme.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.cloudWhite),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(
                                          AppTheme.charcoal),
                                      headingTextStyle: const TextStyle(
                                          color: AppTheme.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                      columns: [
                                        DataColumn(
                                          label: Row(
                                            children: [
                                              const Icon(Icons.bolt,
                                                  color: AppTheme.orange,
                                                  size: 18),
                                              const SizedBox(width: 6),
                                              Text(l.actionsCol,
                                                  style: const TextStyle(
                                                      color: AppTheme.white,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        DataColumn(
                                            label: Text(l.paymentCodeCol,
                                                style: const TextStyle(
                                                    color: AppTheme.white,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        DataColumn(
                                            label: Text(l.importFile,
                                                style: const TextStyle(
                                                    color: AppTheme.white,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        DataColumn(
                                            label: Text(
                                                l.beneficiarySupplierLabel,
                                                style: const TextStyle(
                                                    color: AppTheme.white,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        DataColumn(
                                            label: Text(l.bankSwiftCol,
                                                style: const TextStyle(
                                                    color: AppTheme.white,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        DataColumn(
                                            label: Text(l.paymentTypeLabel,
                                                style: const TextStyle(
                                                    color: AppTheme.white,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        DataColumn(
                                            numeric: true,
                                            label: Text(l.requestedAmountLabel,
                                                style: const TextStyle(
                                                    color: AppTheme.white,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        DataColumn(
                                            numeric: true,
                                            label: Text(l.equivalentEgpCol,
                                                style: const TextStyle(
                                                    color: AppTheme.white,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        DataColumn(
                                            label: Text(l.requestDueDateCol,
                                                style: const TextStyle(
                                                    color: AppTheme.white,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        DataColumn(
                                            label: Text(l.statusCol,
                                                style: const TextStyle(
                                                    color: AppTheme.white,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                      ],
                                      rows:
                                          filtered.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final p = entry.value;
                                        final isEven = index % 2 == 0;
                                        final rawFileCode = p.importFileCode ??
                                            (p.importFileId != null
                                                ? 'IMP-${p.importFileId}'
                                                : '');
                                        final resolvedShipName =
                                            DisplayNameResolver
                                                .resolveShipmentNameByCode(
                                                    rawFileCode,
                                                    shipments: allFiles,
                                                    isArabic: isAr);
                                        final resolvedShipTitle =
                                            DisplayNameResolver
                                                .resolveShipmentTitleByCode(
                                                    rawFileCode,
                                                    shipments: allFiles,
                                                    isArabic: isAr);
                                        final rowSummary = [
                                          p.paymentCode,
                                          resolvedShipTitle,
                                          p.beneficiaryName ?? p.supplierName,
                                          '${p.bankName ?? "-"} ${p.swiftCode ?? ""}'
                                              .trim(),
                                          p.paymentType,
                                          '${p.requestedAmount.toStringAsFixed(2)} ${p.currencyCode}',
                                          '${p.requestedAmountEgp.toStringAsFixed(2)} EGP',
                                          '${p.requestDate} / ${p.dueDate}',
                                          p.status,
                                        ].join('\t');

                                        return DataRow(
                                          color: WidgetStateProperty.all(isEven
                                              ? AppTheme.white
                                              : AppTheme.charcoalSurface),
                                          cells: [
                                            DataCell(
                                              RowActionsPill(
                                                onView: () =>
                                                    _showPaymentDetailsDialog(
                                                        p),
                                                onEdit: () =>
                                                    _loadPaymentRequestForEdit(
                                                        p),
                                                onClone: () =>
                                                    _openClonePaymentReviewDialog(
                                                        p),
                                                onPrint: () =>
                                                    FinancialExportService
                                                        .printPaymentRequestPdf(
                                                            payment: p),
                                                onDelete: () =>
                                                    _confirmDeletePaymentRequest(
                                                        p),
                                              ),
                                            ),
                                            DataCell(
                                              CopyableTableCell(
                                                value: p.paymentCode,
                                                rowSummary: rowSummary,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.cobalt
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    border: Border.all(
                                                        color: AppTheme.cobalt
                                                            .withValues(alpha: 0.3)),
                                                  ),
                                                  child: LtrText(
                                                    p.paymentCode,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: AppTheme.cobalt,
                                                        fontSize: 12),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              CopyableTableCell(
                                                value: resolvedShipTitle,
                                                rowSummary: rowSummary,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      resolvedShipName,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              AppTheme.charcoal,
                                                          fontSize: 12),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    if (rawFileCode.isNotEmpty)
                                                      Container(
                                                        margin: const EdgeInsets
                                                            .only(top: 2),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 5,
                                                                vertical: 1),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AppTheme
                                                              .charcoal
                                                              .withValues(
                                                                  alpha: 0.08),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: Text(
                                                          rawFileCode,
                                                          style: const TextStyle(
                                                              fontSize: 10,
                                                              color: AppTheme
                                                                  .textStrong,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              CopyableTableCell(
                                                value:
                                                    '${p.beneficiaryName ?? p.supplierName} - ${p.title}',
                                                rowSummary: rowSummary,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                        p.beneficiaryName ??
                                                            p.supplierName,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13)),
                                                    Text(p.title,
                                                        style: const TextStyle(
                                                            fontSize: 11,
                                                            color: AppTheme
                                                                .textSecondary)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              CopyableTableCell(
                                                value:
                                                    '${p.bankName ?? "-"} ${p.swiftCode ?? ""}'
                                                        .trim(),
                                                rowSummary: rowSummary,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(p.bankName ?? '-',
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500)),
                                                    if (p.swiftCode != null &&
                                                        p.swiftCode!.isNotEmpty)
                                                      Text(
                                                          'SWIFT: ${p.swiftCode}',
                                                          style: const TextStyle(
                                                              fontSize: 10,
                                                              color: AppTheme
                                                                  .textStrong)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              CopyableTableCell(
                                                value: p.paymentType,
                                                rowSummary: rowSummary,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.orangeLight,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                    border: Border.all(
                                                        color: AppTheme.orange),
                                                  ),
                                                  child: Text(p.paymentType,
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: AppTheme
                                                              .wcagOrange)),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              CopyableTableCell(
                                                value:
                                                    '${p.requestedAmount.toStringAsFixed(2)} ${p.currencyCode}',
                                                rowSummary: rowSummary,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.cobaltLight,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: LtrText(
                                                    '${p.requestedAmount.toStringAsFixed(2)} ${p.currencyCode}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            AppTheme.wcagCobalt,
                                                        fontSize: 12),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              CopyableTableCell(
                                                value:
                                                    '${p.requestedAmountEgp.toStringAsFixed(2)} EGP',
                                                rowSummary: rowSummary,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isDark
                                                        ? AppTheme
                                                            .darkCardBackground
                                                        : AppTheme.emeraldLight,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: LtrText(
                                                    '${p.requestedAmountEgp.toStringAsFixed(2)} EGP',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: AppTheme
                                                            .wcagEmerald,
                                                        fontSize: 12),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              CopyableTableCell(
                                                value:
                                                    '${p.requestDate} - ${p.dueDate}',
                                                rowSummary: rowSummary,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                        '${l.requestDateLabel}: ${p.requestDate.isNotEmpty ? p.requestDate : "-"}',
                                                        style: const TextStyle(
                                                            fontSize: 11)),
                                                    Text(
                                                        '${l.dueDateLabel}: ${p.dueDate}',
                                                        style: const TextStyle(
                                                            fontSize: 10,
                                                            color: AppTheme
                                                                .textStrong)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              CopyableTableCell(
                                                value: p.status,
                                                rowSummary: rowSummary,
                                                child: FinancialStatusChip(
                                                    status: p.status),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox.shrink(),

          // ── TAB 4: SWIFT MT103 PARSER & RECONCILIATION ───────────────────────
          if (_visitedTabs.contains(4))
            const SwiftReconciliationScreen(isEmbedded: true)
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  ImportBudgetModel _buildTempBudgetModel() {
    final invForeign =
        double.tryParse(_invoiceForeignController.text.trim()) ?? 0.0;
    final invEgp = double.tryParse(_invoiceEgpController.text.trim()) ?? 0.0;
    final frtForeign =
        double.tryParse(_freightForeignController.text.trim()) ?? 0.0;
    final frtEgp = double.tryParse(_freightEgpController.text.trim()) ?? 0.0;
    final custEgp = double.tryParse(_customsEgpController.text.trim()) ?? 0.0;
    final clrEgp = double.tryParse(_clearanceEgpController.text.trim()) ?? 0.0;
    final rate = double.tryParse(_bgtExchangeRateController.text.trim()) ?? 0.0;

    return ImportBudgetModel(
      budgetId: 0,
      budgetCode: 'BGT-PREVIEW',
      title: _bgtTitleController.text.trim(),
      importFileId: _bgtSelectedImportFileId,
      invoiceAmountForeign: invForeign,
      invoiceCurrency: _bgtInvoiceCurrency,
      invoiceAmountEgp: invEgp,
      freightCostForeign: frtForeign,
      freightCurrency: _bgtFreightCurrency,
      freightCostEgp: frtEgp,
      customsDutiesEgp: custEgp,
      clearanceInlandEgp: clrEgp,
      exchangeRate: rate,
      totalBudgetEgp: invEgp + frtEgp + custEgp + clrEgp,
      budgetStatus: 'Pending Review',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  Widget _buildConsolidatedBudgetSummary(
      {ImportBudgetModel? bgt, BudgetPrefillModel? prefill}) {
    final double invForeign;
    final String invCurr;
    final double invEgp;
    final double frtForeign;
    final String frtCurr;
    final double frtEgp;
    final double custEgp;
    final double clrEgp;
    final double grandTotalEgp;

    if (bgt != null) {
      invForeign = bgt.invoiceAmountForeign;
      invCurr = bgt.invoiceCurrency;
      invEgp = bgt.invoiceAmountEgp;
      frtForeign = bgt.freightCostForeign;
      frtCurr = bgt.freightCurrency;
      frtEgp = bgt.freightCostEgp;
      custEgp = bgt.customsDutiesEgp;
      clrEgp = bgt.clearanceInlandEgp;
      grandTotalEgp = bgt.totalBudgetEgp;
    } else {
      invForeign = double.tryParse(_invoiceForeignController.text) ??
          (prefill?.totalInvoiceAmount ?? 0);
      invCurr = _bgtInvoiceCurrency;
      invEgp = double.tryParse(_invoiceEgpController.text) ??
          (prefill?.totalInvoiceAmountEgp ?? 0);
      frtForeign = double.tryParse(_freightForeignController.text) ??
          (prefill?.estimatedFreightCost ?? 0);
      frtCurr = _bgtFreightCurrency;
      frtEgp = double.tryParse(_freightEgpController.text) ??
          (prefill?.estimatedFreightCostEgp ?? 0);
      custEgp = double.tryParse(_customsEgpController.text) ??
          (prefill?.estimatedCustomsDutiesEgp ?? 0);
      clrEgp = double.tryParse(_clearanceEgpController.text) ??
          (prefill?.estimatedClearanceFeesEgp ?? 0);
      grandTotalEgp = invEgp + frtEgp + custEgp + clrEgp;
    }

    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.currency_exchange,
                  color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.consolidatedBudgetSummary,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color:
                        isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Group 1: Foreign Currency Table
          Text(
            '1. ${l.estimatedInvoiceValue} & ${l.estimatedFreightCost}:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isDark ? AppTheme.cobalt : AppTheme.cobalt,
            ),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 550;
              final table = Table(
                border: TableBorder.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                columnWidths: isNarrow
                    ? const {
                        0: FixedColumnWidth(160),
                        1: FixedColumnWidth(120),
                        2: FixedColumnWidth(90),
                        3: FixedColumnWidth(120),
                      }
                    : const {
                        0: FlexColumnWidth(2.0),
                        1: FlexColumnWidth(1.5),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(1.5),
                      },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: AppTheme.cobalt),
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(l.categoryCol,
                              style: const TextStyle(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11))),
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(l.amountInCurrencyCol,
                              style: const TextStyle(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11))),
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(l.currencyCol,
                              style: const TextStyle(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11))),
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(l.equivalentEgpCol,
                              style: const TextStyle(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11))),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(l.estimatedInvoiceValue,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : null))),
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: CopyableText(invForeign.toStringAsFixed(2),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : null))),
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: CopyableText(invCurr,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : null))),
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: CopyableText(
                              '${invEgp.toStringAsFixed(2)} EGP',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.emerald,
                                  fontSize: 12))),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(l.estimatedFreightCost,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : null))),
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: CopyableText(frtForeign.toStringAsFixed(2),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : null))),
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: CopyableText(frtCurr,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : null))),
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: CopyableText(
                              '${frtEgp.toStringAsFixed(2)} EGP',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.emerald,
                                  fontSize: 12))),
                    ],
                  ),
                  TableRow(
                    decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkElevatedSurface
                            : AppTheme.charcoalSurface),
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(l.totalExpenses,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : null))),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: CopyableText(
                          invCurr.toUpperCase() == frtCurr.toUpperCase()
                              ? (invForeign + frtForeign).toStringAsFixed(2)
                              : '${invForeign.toStringAsFixed(2)} ($invCurr)\n+ ${frtForeign.toStringAsFixed(2)} ($frtCurr)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextPrimary : null),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: CopyableText(
                          invCurr.toUpperCase() == frtCurr.toUpperCase()
                              ? invCurr
                              : '-',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextPrimary : null),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: CopyableText(
                          '${(invEgp + frtEgp).toStringAsFixed(2)} EGP',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.emerald,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              );

              return isNarrow
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 490),
                        child: table,
                      ),
                    )
                  : table;
            },
          ),
          const SizedBox(height: 14),

          // Group 2: Local EGP Table
          Text(
            '2. ${l.clearanceAndTransportEstimate}:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isDark ? AppTheme.orange : AppTheme.orange,
            ),
          ),
          const SizedBox(height: 6),
          Builder(
            builder: (context) {
              final brokerName = prefill?.brokerName;
              final hasBroker = brokerName != null && brokerName.isNotEmpty;
              return LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 550;
                  final table = Table(
                    border: TableBorder.all(
                        color:
                            isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                    columnWidths: isNarrow
                        ? const {
                            0: FixedColumnWidth(180),
                            1: FixedColumnWidth(150),
                            2: FixedColumnWidth(140),
                          }
                        : const {
                            0: FlexColumnWidth(2.0),
                            1: FlexColumnWidth(1.8),
                            2: FlexColumnWidth(1.5),
                          },
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: AppTheme.orange),
                        children: [
                          Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(l.categoryCol,
                                  style: const TextStyle(
                                      color: AppTheme.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11))),
                          Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(l.responsiblePartyLabel,
                                  style: const TextStyle(
                                      color: AppTheme.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11))),
                          Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(l.equivalentEgpCol,
                                  style: const TextStyle(
                                      color: AppTheme.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11))),
                        ],
                      ),
                      TableRow(
                        children: [
                          Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(l.customsAndVatEstimate,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : null))),
                          Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(l.customsAuthority,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : null))),
                          Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(
                                  '${custEgp.toStringAsFixed(2)} EGP',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.wcagCobalt,
                                      fontSize: 12))),
                        ],
                      ),
                      TableRow(
                        children: [
                          Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(l.clearanceAndTransportEstimate,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : null))),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: CopyableText(
                              hasBroker
                                  ? '${l.customsBrokerLabel} $brokerName'
                                  : l.customsBrokerLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: hasBroker
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isDark
                                    ? (hasBroker
                                        ? AppTheme.orange
                                        : AppTheme.darkTextSecondary)
                                    : (hasBroker ? AppTheme.charcoal : null),
                              ),
                            ),
                          ),
                          Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(
                                  '${clrEgp.toStringAsFixed(2)} EGP',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.emerald,
                                      fontSize: 12))),
                        ],
                      ),
                      TableRow(
                        decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkElevatedSurface
                                : AppTheme.charcoalSurface),
                        children: [
                          Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(l.totalExpenses,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : null))),
                          Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text('-',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : null))),
                          Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(
                                  '${(custEgp + clrEgp).toStringAsFixed(2)} EGP',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.emerald,
                                      fontSize: 12))),
                        ],
                      ),
                    ],
                  );

                  return isNarrow
                      ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 470),
                            child: table,
                          ),
                        )
                      : table;
                },
              );
            },
          ),
          const SizedBox(height: 14),

          // Total Approved Budget Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.emerald.withValues(alpha: 0.2)
                  : AppTheme.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${l.totalBudgetEgp}:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color:
                        isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
                CopyableText(
                  '${grandTotalEgp.toStringAsFixed(2)} EGP',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.emerald),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaySwiftExtractorWidget() {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cloudWhite),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.cobalt, AppTheme.wcagCobalt],
                begin: AlignmentDirectional.centerEnd,
                end: AlignmentDirectional.centerStart,
              ),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: AppTheme.orange, size: 20),
                const SizedBox(width: 6),
                const Icon(Icons.bolt, color: AppTheme.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.swiftExtractorTitle,
                    style: const TextStyle(
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                IconButton(
                  icon: Icon(
                      _isPaySwiftExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppTheme.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip:
                      _isPaySwiftExpanded ? l.collapseSidebar : l.actionsCol,
                  onPressed: () => setState(
                      () => _isPaySwiftExpanded = !_isPaySwiftExpanded),
                ),
              ],
            ),
          ),

          // Collapsible Body
          if (_isPaySwiftExpanded)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 650;
                      final textArea = Stack(
                        children: [
                          TextField(
                            controller: _paySwiftRawTextController,
                            maxLines: 5,
                            minLines: 4,
                            style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                height: 1.4,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.charcoal),
                            decoration: InputDecoration(
                              hintText: l.swiftPasteText,
                              hintStyle: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.textMuted),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              contentPadding:
                                  const EdgeInsetsDirectional.fromSTEB(
                                      12, 12, 12, 40),
                            ),
                          ),
                          PositionedDirectional(
                            start: 8,
                            bottom: 8,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () async {
                                    final d = await Clipboard.getData(
                                        Clipboard.kTextPlain);
                                    if (d != null &&
                                        d.text != null &&
                                        d.text!.isNotEmpty) {
                                      _paySwiftRawTextController.text = d.text!;
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppTheme.darkElevatedSurface
                                          : AppTheme.cloudWhite,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.paste,
                                            size: 12, color: AppTheme.charcoal),
                                        const SizedBox(width: 4),
                                        Text(l.swiftPasteText,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    _paySwiftRawTextController.clear();
                                    setState(
                                        () => _payExtractedSwiftSummary = null);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppTheme.darkElevatedSurface
                                          : AppTheme.charcoalSurface,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.clear,
                                            size: 12,
                                            color: AppTheme.textSecondary),
                                        const SizedBox(width: 4),
                                        Text(l.reset,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                      final actionButtons = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FinancialUi.fit(AppButton(
                            label: l.swiftUploadDocument,
                            variant: AppButtonVariant.primary,
                            icon: Icons.upload_file,
                            onPressed: _isPaySwiftExtracting
                                ? null
                                : _autoFillFromSwiftFile,
                          )),
                          const SizedBox(height: 8),
                          FinancialUi.fit(AppButton(
                            label: l.swiftExecuteReconciliation,
                            variant: AppButtonVariant.primary,
                            icon: Icons.bolt,
                            isLoading: _isPaySwiftExtracting,
                            onPressed: _isPaySwiftExtracting
                                ? null
                                : () {
                                    final txt =
                                        _paySwiftRawTextController.text.trim();
                                    if (txt.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('⚠️ ${l.swiftPasteText}'),
                                            backgroundColor: AppTheme.orange),
                                      );
                                      return;
                                    }
                                    _autoFillFromSwiftText(txt);
                                  },
                          )),
                        ],
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            textArea,
                            const SizedBox(height: 10),
                            actionButtons,
                          ],
                        );
                      } else {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: textArea),
                            const SizedBox(width: 14),
                            SizedBox(width: 200, child: actionButtons),
                          ],
                        );
                      }
                    },
                  ),

                  // Extracted Summary Badges (if extracted)
                  if (_payExtractedSwiftSummary != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkCardBackground
                            : AppTheme.emeraldLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isDark
                                ? AppTheme.emerald.withValues(alpha: 0.4)
                                : AppTheme.emeraldBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppTheme.emerald, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Text(
                                    '${l.requestedAmountLabel}: ${_payExtractedSwiftSummary!['amount']} ${_payExtractedSwiftSummary!['currency']}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: isDark
                                            ? AppTheme.darkTextPrimary
                                            : AppTheme.charcoal)),
                                Text(
                                    '${l.beneficiarySupplierLabel}: ${_payExtractedSwiftSummary!['beneficiary_name'] ?? "-"}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: isDark
                                            ? AppTheme.darkTextPrimary
                                            : AppTheme.charcoal)),
                                Text(
                                    '${l.paymentCodeCol}: ${_payExtractedSwiftSummary!['transaction_reference'] ?? "-"}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: isDark
                                            ? AppTheme.darkTextPrimary
                                            : AppTheme.charcoal)),
                                Text(
                                    '${l.swiftCodeLabel}: ${_payExtractedSwiftSummary!['beneficiary_bank_swift'] ?? "-"}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppTheme.darkTextPrimary
                                            : AppTheme.charcoal)),
                                Text(
                                    '${l.ibanAccountLabel}: ${_payExtractedSwiftSummary!['beneficiary_account_or_iban'] ?? "-"}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppTheme.darkTextPrimary
                                            : AppTheme.charcoal)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricBadge(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          CopyableText(value,
              style: TextStyle(
                  fontSize: 14, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
