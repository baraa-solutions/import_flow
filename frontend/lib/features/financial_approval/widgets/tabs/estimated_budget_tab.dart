import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../../../currencies/providers/currencies_provider.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';
import '../../services/financial_export_service.dart';
import '../banners/upstream_variance_alert_banner.dart';
import '../budget_details_dialog.dart';
import '../consolidated_budget_summary_card.dart';
import '../dialogs/clone_budget_review_dialog.dart';
import '../duplicate_budget_dialog.dart';
import '../financial_ui.dart';
import '../search_and_clone_budget_dialog.dart';

class EstimatedBudgetTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final void Function(int? fileId)? onImportFileChanged;

  const EstimatedBudgetTab({
    super.key,
    this.initialImportFileId,
    this.onImportFileChanged,
  });

  @override
  ConsumerState<EstimatedBudgetTab> createState() => EstimatedBudgetTabState();
}

class EstimatedBudgetTabState extends ConsumerState<EstimatedBudgetTab> {
  final _budgetFormKey = GlobalKey<FormState>();
  final TextEditingController _bgtTitleController = TextEditingController();
  final TextEditingController _invoiceEgpController = TextEditingController();
  final TextEditingController _invoiceForeignController = TextEditingController();
  final TextEditingController _freightEgpController = TextEditingController();
  final TextEditingController _freightForeignController = TextEditingController();
  final TextEditingController _customsEgpController = TextEditingController();
  final TextEditingController _clearanceEgpController = TextEditingController();
  final TextEditingController _bgtExchangeRateController = TextEditingController();
  final TextEditingController _bgtFreightRateController = TextEditingController();
  final TextEditingController _bgtNotesController = TextEditingController();

  String _bgtInvoiceCurrency = 'USD';
  String _bgtFreightCurrency = 'USD';
  int? _bgtSelectedImportFileId;
  BudgetPrefillModel? _bgtPrefillData;
  ImportBudgetModel? _lastSavedBudget;
  bool _isSavingBudget = false;
  bool _isLoadingBgtPrefill = false;

  int? _editingBudgetId;
  int? _editingBudgetVersion;

  int? get selectedImportFileId => _bgtSelectedImportFileId;

  @override
  void initState() {
    super.initState();
    if (widget.initialImportFileId != null) {
      Future.microtask(() {
        _onBgtImportFileSelected(widget.initialImportFileId);
      });
    }
  }

  @override
  void dispose() {
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
      AppTheme.snackBar(context, context.l10n.faFxRateMissing(currency),
          severity: AppSeverity.warning),
    );
  }

  Future<void> _onBgtImportFileSelected(int? fileId) async {
    widget.onImportFileChanged?.call(fileId);
    if (fileId == null) {
      setState(() {
        _bgtSelectedImportFileId = null;
        _bgtPrefillData = null;
      });
      return;
    }

    final existingList = ref.read(importBudgetsProvider).valueOrNull ?? [];
    final existing = existingList
        .where((b) =>
            b.importFileId == fileId &&
            b.isActive &&
            b.budgetId != _editingBudgetId)
        .firstOrNull;
    if (existing != null) {
      if (mounted) {
        DuplicateBudgetDialog.show(
          context,
          existingBudget: existing,
          onCancelSelection: () {
            setState(() {
              _bgtSelectedImportFileId = null;
              _bgtPrefillData = null;
            });
          },
          onReviewSyncLiveCosts: () {
            loadBudgetForEditAndCheckSync(existing);
          },
          onViewAndPrintBudget: () {
            _showBudgetDetailsDialog(existing);
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

  void loadBudgetForEdit(ImportBudgetModel b) {
    setState(() {
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
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        context.l10n.budgetLoadedForEditMsg(b.budgetCode),
        severity: AppSeverity.info,
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
    } catch (_) {}
  }

  Future<void> loadBudgetForEditAndCheckSync(ImportBudgetModel b) async {
    loadBudgetForEdit(b);
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
          AppTheme.snackBar(
            context,
            context.l10n.faPrefilledLiveCosts,
            severity: AppSeverity.success,
          ),
        );
      }
      return;
    }
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
    CloneBudgetReviewDialog.show(
      context: context,
      ref: ref,
      budget: b,
      onCloned: (cloned) {
        loadBudgetForEdit(cloned);
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
        AppTheme.snackBar(
          context,
          isUpdate
              ? context.l10n.budgetUpdatedSuccess(bgt.budgetCode)
              : context.l10n.budgetCreatedSuccess(bgt.budgetCode),
          severity: AppSeverity.success,
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
          AppTheme.snackBar(
            context,
            context.l10n.budgetApprovedSuccess(approved.budgetCode),
            severity: AppSeverity.success,
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

  void _showBudgetDetailsDialog(ImportBudgetModel bgt) {
    BudgetDetailsDialog.show(
      context,
      budget: bgt,
      prefill: _bgtPrefillData?.importFileId == bgt.importFileId
          ? _bgtPrefillData
          : null,
      onEditBudget: () => loadBudgetForEdit(bgt),
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
            _openSearchAndCloneBudgetDialog();
          },
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 700;
              final isDark = Theme.of(context).brightness == Brightness.dark;

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
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                l.importBudgetSetupTitle,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? AppTheme.darkTextPrimary
                                                      : AppTheme.charcoal,
                                                ),
                                              ),
                                            ),
                                            if (_isLoadingBgtPrefill)
                                              const AppLoadingState.inline(),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        FinancialUi.fit(AppButton(
                                          key: const Key(
                                              'searchAndCloneBudgetBtn'),
                                          label: l.searchAndCloneBudgetBtn,
                                          variant: AppButtonVariant.secondary,
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
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? AppTheme
                                                            .darkTextPrimary
                                                        : AppTheme.charcoal,
                                                  ),
                                                ),
                                              ),
                                              if (_isLoadingBgtPrefill) ...[
                                                const SizedBox(width: 12),
                                                const AppLoadingState.inline(),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        FinancialUi.fit(AppButton(
                                          key: const Key(
                                              'searchAndCloneBudgetBtn'),
                                          label: l.searchAndCloneBudgetBtn,
                                          variant: AppButtonVariant.secondary,
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
                                                .watch(importFilesProvider)
                                                .valueOrNull ??
                                            [])
                                        .map((f) => SearchableDropdownItem<int?>(
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
                                      child: SearchableDropdownField<int?>(
                                        value: _bgtSelectedImportFileId,
                                        labelText: '${l.importFile} *',
                                        searchHintText: l.search,
                                        items: [
                                          SearchableDropdownItem<int?>(
                                            value: null,
                                            label: '-- ${l.notLinked} --',
                                          ),
                                          ...(ref
                                                      .watch(importFilesProvider)
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
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
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
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 16),

                              // Upstream Variance Alert Banner
                              UpstreamVarianceAlertBanner(
                                budget: _lastSavedBudget,
                                prefill: _bgtPrefillData,
                                formInvoiceEgp: double.tryParse(
                                    _invoiceEgpController.text.trim()),
                                formFreightEgp: double.tryParse(
                                    _freightEgpController.text.trim()),
                                formDutiesEgp: double.tryParse(
                                    _customsEgpController.text.trim()),
                                formClearanceEgp: double.tryParse(
                                    _clearanceEgpController.text.trim()),
                                onFillLiveCosts: _syncCurrentBudgetWithLiveCosts,
                                onRecalculateSuccess: (result) {
                                  if (mounted) setState(() {});
                                },
                              ),
                              const SizedBox(height: 12),

                              // Multi-Currency Live Consolidated Breakdown Tables
                              ConsolidatedBudgetSummaryCard(
                                budget: _lastSavedBudget,
                                prefill: _bgtPrefillData,
                                showVarianceAlert: true,
                              ),
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
                                        '${l.estimatedInvoiceValue} ($_bgtInvoiceCurrency)',
                                    border: const OutlineInputBorder(),
                                    fillColor: isDark
                                        ? AppTheme.darkElevatedSurface
                                        : AppTheme.white,
                                    filled: isDark,
                                  ),
                                  onChanged: (v) {
                                    final f = double.tryParse(v) ?? 0;
                                    final r = double.tryParse(
                                            _bgtExchangeRateController.text) ??
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
                                        '${l.exchangeRateLabel} (EGP)',
                                    border: const OutlineInputBorder(),
                                    fillColor: isDark
                                        ? AppTheme.darkElevatedSurface
                                        : AppTheme.white,
                                    filled: isDark,
                                  ),
                                  onChanged: (v) {
                                    final r = double.tryParse(v) ?? 0;
                                    final inv = double.tryParse(
                                            _invoiceForeignController.text) ??
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
                                        '${l.estimatedFreightCost} ($_bgtFreightCurrency)',
                                    border: const OutlineInputBorder(),
                                    fillColor: isDark
                                        ? AppTheme.darkElevatedSurface
                                        : AppTheme.white,
                                    filled: isDark,
                                  ),
                                  onChanged: (v) {
                                    final f = double.tryParse(v) ?? 0;
                                    final r = double.tryParse(
                                            _bgtFreightRateController.text) ??
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
                                        '${l.freightExchangeRateLabel} (EGP)',
                                    border: const OutlineInputBorder(),
                                    fillColor: isDark
                                        ? AppTheme.darkElevatedSurface
                                        : AppTheme.white,
                                    filled: isDark,
                                  ),
                                  onChanged: (v) {
                                    final r = double.tryParse(v) ?? 0;
                                    final frt = double.tryParse(
                                            _freightForeignController.text) ??
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
                                        '${l.customsAndVatEstimate} (EGP)',
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
                                        '${l.clearanceAndTransportEstimate} (EGP)',
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
                                          _buildBgtInvoiceCurrencyDropdown(l),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: _invoiceForeignController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText:
                                              '${l.estimatedInvoiceValue} ($_bgtInvoiceCurrency)',
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
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: _bgtExchangeRateController,
                                        keyboardType: TextInputType.number,
                                        validator: _validateExchangeRate,
                                        decoration: InputDecoration(
                                          labelText:
                                              '${l.exchangeRateLabel} (EGP)',
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
                                          _buildBgtFreightCurrencyDropdown(l),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: _freightForeignController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText:
                                              '${l.estimatedFreightCost} ($_bgtFreightCurrency)',
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
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: _bgtFreightRateController,
                                        keyboardType: TextInputType.number,
                                        validator: _validateFreightExchangeRate,
                                        decoration: InputDecoration(
                                          labelText:
                                              '${l.freightExchangeRateLabel} (EGP)',
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
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Row C: Local EGP Duties & Clearance
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _customsEgpController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText:
                                              '${l.customsAndVatEstimate} (EGP)',
                                          border: const OutlineInputBorder(),
                                          fillColor: isDark
                                              ? AppTheme.darkElevatedSurface
                                              : AppTheme.white,
                                          filled: isDark,
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _clearanceEgpController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText:
                                              '${l.clearanceAndTransportEstimate} (EGP)',
                                          border: const OutlineInputBorder(),
                                          fillColor: isDark
                                              ? AppTheme.darkElevatedSurface
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
                                crossAxisAlignment: WrapCrossAlignment.center,
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
                                        variant: AppButtonVariant.secondary,
                                        icon: Icons.refresh,
                                        onPressed: () {
                                          ref
                                              .read(importBudgetsProvider.notifier)
                                              .fetchImportBudgets();
                                          ref
                                              .read(paymentRequestsProvider
                                                  .notifier)
                                              .fetchPaymentRequests();
                                          ref
                                              .read(
                                                  importFilesProvider.notifier)
                                              .fetchImportFiles();
                                        },
                                      )),

                                      // 2. Clear Form & Start New
                                      FinancialUi.fit(AppButton(
                                        label: l.reset,
                                        variant: AppButtonVariant.secondary,
                                        icon: Icons.cleaning_services_outlined,
                                        onPressed: () {
                                          setState(() {
                                            _editingBudgetId = null;
                                            _editingBudgetVersion = null;
                                            _bgtSelectedImportFileId = null;
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
                                        variant: AppButtonVariant.secondary,
                                        icon: Icons.table_chart,
                                        onPressed: () async {
                                          final bgt = _lastSavedBudget ??
                                              _buildTempBudgetModel();
                                          final path =
                                              await FinancialExportService
                                                  .exportBudgetToExcel(
                                            context: context,
                                            budget: bgt,
                                            prefill: _bgtPrefillData,
                                          );
                                          if (path != null && mounted) {
                                            ScaffoldMessenger.of(this.context)
                                                .showSnackBar(
                                              AppTheme.snackBar(
                                                this.context,
                                                '✅ $path',
                                                severity: AppSeverity.success,
                                              ),
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
      ),
    );
  }
}
