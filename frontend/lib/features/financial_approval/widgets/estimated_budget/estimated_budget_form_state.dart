import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../currencies/providers/currencies_provider.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';
import 'estimated_budget_dialogs.dart';

class EstimatedBudgetFormState {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final invoiceEgpController = TextEditingController();
  final invoiceForeignController = TextEditingController();
  final freightEgpController = TextEditingController();
  final freightForeignController = TextEditingController();
  final customsEgpController = TextEditingController();
  final clearanceEgpController = TextEditingController();
  final exchangeRateController = TextEditingController();
  final freightRateController = TextEditingController();
  final notesController = TextEditingController();

  String invoiceCurrency = 'USD';
  String freightCurrency = 'USD';
  int? selectedImportFileId;
  BudgetPrefillModel? prefillData;
  ImportBudgetModel? lastSavedBudget;
  bool isSaving = false;
  bool isLoadingPrefill = false;

  int? editingBudgetId;
  int? editingBudgetVersion;

  void dispose() {
    titleController.dispose();
    invoiceEgpController.dispose();
    invoiceForeignController.dispose();
    freightEgpController.dispose();
    freightForeignController.dispose();
    customsEgpController.dispose();
    clearanceEgpController.dispose();
    exchangeRateController.dispose();
    freightRateController.dispose();
    notesController.dispose();
  }

  String rateText(double? rate) =>
      (rate != null && rate > 0) ? rate.toStringAsFixed(4) : '';

  double? getExchangeRateForCurrency(WidgetRef ref, String currencyCode) {
    if (currencyCode.toUpperCase() == 'EGP') return 1.0;
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    final cur = currencies
        .where((c) =>
            c.currencyCode.toUpperCase() == currencyCode.toUpperCase())
        .firstOrNull;
    if (cur != null) {
      if (cur.isBaseCurrency) return 1.0;
      if (cur.latestCommercialRate != null && cur.latestCommercialRate! > 0) {
        return cur.latestCommercialRate!;
      }
    }
    return null;
  }

  void warnFxMissing(BuildContext context, String currency) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, context.l10n.faFxRateMissing(currency),
          severity: AppSeverity.warning),
    );
  }

  String? validateExchangeRate(BuildContext context, String? v) {
    final r = double.tryParse((v ?? '').trim());
    if (r == null || r <= 0) return context.l10n.faExchangeRateInvalid;
    return null;
  }

  String? validateFreightExchangeRate(BuildContext context, String? v) {
    final frt = double.tryParse(freightForeignController.text.trim()) ?? 0;
    if (frt <= 0) return null;
    final r = double.tryParse((v ?? '').trim());
    if (r == null || r <= 0) return context.l10n.faExchangeRateInvalid;
    return null;
  }

  void reset() {
    editingBudgetId = null;
    editingBudgetVersion = null;
    selectedImportFileId = null;
    prefillData = null;
    notesController.clear();
  }

  void onInvoiceCurrencyChanged(
    BuildContext context,
    WidgetRef ref,
    String? val,
    VoidCallback notify,
  ) {
    if (val != null) {
      invoiceCurrency = val;
      final rate = getExchangeRateForCurrency(ref, val);
      exchangeRateController.text = rateText(rate);
      if (rate != null) {
        final inv = double.tryParse(invoiceForeignController.text) ?? 0;
        invoiceEgpController.text = (inv * rate).toStringAsFixed(2);
      }
      if (rate == null) warnFxMissing(context, val);
      notify();
    }
  }

  void onFreightCurrencyChanged(
    BuildContext context,
    WidgetRef ref,
    String? val,
    VoidCallback notify,
  ) {
    if (val != null) {
      freightCurrency = val;
      final rate = getExchangeRateForCurrency(ref, val);
      freightRateController.text = rateText(rate);
      if (rate != null) {
        final frt = double.tryParse(freightForeignController.text) ?? 0;
        freightEgpController.text = (frt * rate).toStringAsFixed(2);
      }
      if (rate == null) warnFxMissing(context, val);
      notify();
    }
  }

  void syncCurrentBudgetWithLiveCosts(
    BuildContext context,
    VoidCallback notify,
  ) {
    if (editingBudgetId == null) {
      if (prefillData != null) {
        if (prefillData!.totalInvoiceAmount > 0) {
          invoiceForeignController.text =
              prefillData!.totalInvoiceAmount.toStringAsFixed(2);
          invoiceCurrency = prefillData!.invoiceCurrency;
        }
        if (prefillData!.totalInvoiceAmountEgp > 0) {
          invoiceEgpController.text =
              prefillData!.totalInvoiceAmountEgp.toStringAsFixed(2);
        }
        if (prefillData!.estimatedFreightCost > 0) {
          freightForeignController.text =
              prefillData!.estimatedFreightCost.toStringAsFixed(2);
          freightCurrency = prefillData!.freightCurrency;
        }
        if (prefillData!.estimatedFreightCostEgp > 0) {
          freightEgpController.text =
              prefillData!.estimatedFreightCostEgp.toStringAsFixed(2);
        }
        if (prefillData!.estimatedCustomsDutiesEgp > 0) {
          customsEgpController.text =
              prefillData!.estimatedCustomsDutiesEgp.toStringAsFixed(2);
        }
        if (prefillData!.estimatedClearanceFeesEgp > 0) {
          clearanceEgpController.text =
              prefillData!.estimatedClearanceFeesEgp.toStringAsFixed(2);
        }
        if (prefillData!.exchangeRate > 0) {
          exchangeRateController.text = rateText(prefillData!.exchangeRate);
        }
        notify();
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.faPrefilledLiveCosts,
            severity: AppSeverity.success,
          ),
        );
      }
    }
  }

  void loadBudgetForEdit(
    BuildContext context,
    WidgetRef ref,
    ImportBudgetModel b,
    VoidCallback notify,
  ) {
    editingBudgetId = b.budgetId;
    editingBudgetVersion = b.version;
    titleController.text = b.title;
    selectedImportFileId = b.importFileId;
    invoiceForeignController.text = b.invoiceAmountForeign.toStringAsFixed(2);
    invoiceCurrency = b.invoiceCurrency;
    invoiceEgpController.text = b.invoiceAmountEgp.toStringAsFixed(2);
    freightForeignController.text = b.freightCostForeign.toStringAsFixed(2);
    freightCurrency = b.freightCurrency;
    if (b.freightCurrency == b.invoiceCurrency) {
      freightRateController.text = rateText(b.exchangeRate);
    } else {
      final frtRate = getExchangeRateForCurrency(ref, b.freightCurrency);
      freightRateController.text = rateText(frtRate ??
          (b.freightCostForeign > 0 && b.freightCostEgp > 0
              ? (b.freightCostEgp / b.freightCostForeign)
              : null));
    }
    freightEgpController.text = b.freightCostEgp.toStringAsFixed(2);
    customsEgpController.text = b.customsDutiesEgp.toStringAsFixed(2);
    clearanceEgpController.text = b.clearanceInlandEgp.toStringAsFixed(2);
    exchangeRateController.text = rateText(b.exchangeRate);
    notesController.text = b.notes ?? '';
    lastSavedBudget = b;
    notify();

    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        context.l10n.budgetLoadedForEditMsg(b.budgetCode),
        severity: AppSeverity.info,
      ),
    );
    if (b.importFileId != null) {
      loadBudgetPrefillForFile(ref, b.importFileId!, notify);
    }
  }

  Future<void> loadBudgetPrefillForFile(
    WidgetRef ref,
    int fileId,
    VoidCallback notify,
  ) async {
    try {
      final p = await ref
          .read(importBudgetsProvider.notifier)
          .fetchBudgetPrefill(fileId);
      if (p != null) {
        prefillData = p;
        notify();
      }
    } catch (_) {}
  }

  Future<void> loadBudgetForEditAndCheckSync(
    BuildContext context,
    WidgetRef ref,
    ImportBudgetModel b,
    VoidCallback notify,
  ) async {
    loadBudgetForEdit(context, ref, b, notify);
    if (b.importFileId != null) {
      isLoadingPrefill = true;
      notify();
      try {
        final prefill = await ref
            .read(importBudgetsProvider.notifier)
            .fetchBudgetPrefill(b.importFileId!);
        if (prefill != null) prefillData = prefill;
      } catch (_) {} finally {
        isLoadingPrefill = false;
        notify();
      }
    }
  }

  Future<void> onImportFileSelected({
    required BuildContext context,
    required WidgetRef ref,
    required int? fileId,
    required void Function(int?)? onImportFileChanged,
    required VoidCallback notify,
  }) async {
    onImportFileChanged?.call(fileId);
    if (fileId == null) {
      selectedImportFileId = null;
      prefillData = null;
      notify();
      return;
    }

    final existingList = ref.read(importBudgetsProvider).valueOrNull ?? [];
    final existing = existingList
        .where((b) =>
            b.importFileId == fileId &&
            b.isActive &&
            b.budgetId != editingBudgetId)
        .firstOrNull;
    if (existing != null) {
      if (context.mounted) {
        EstimatedBudgetDialogs.showDuplicateBudget(
          context: context,
          existingBudget: existing,
          onCancelSelection: () {
            selectedImportFileId = null;
            prefillData = null;
            notify();
          },
          onReviewSyncLiveCosts: () {
            loadBudgetForEditAndCheckSync(context, ref, existing, notify);
          },
          onViewAndPrintBudget: () {
            EstimatedBudgetDialogs.showBudgetDetails(
              context: context,
              budget: existing,
              prefill: prefillData,
              onEditBudget: () =>
                  loadBudgetForEdit(context, ref, existing, notify),
            );
          },
        );
      }
      return;
    }

    selectedImportFileId = fileId;
    isLoadingPrefill = true;
    notify();

    try {
      BudgetPrefillModel? prefill;
      try {
        prefill = await ref
            .read(importBudgetsProvider.notifier)
            .fetchBudgetPrefill(fileId);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, ApiError.message(e),
                severity: AppSeverity.danger),
          );
        }
      }

      final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
      final impFile =
          importFiles.where((f) => f.importFileId == fileId).firstOrNull;

      double calculatedInvoiceAmount = 0.0;
      String calculatedCurrency = invoiceCurrency;

      if (prefill != null && prefill.totalInvoiceAmount > 0) {
        calculatedInvoiceAmount = prefill.totalInvoiceAmount;
        if (prefill.invoiceCurrency.isNotEmpty) {
          calculatedCurrency = prefill.invoiceCurrency;
        }
      }

      if (context.mounted) {
        final dynamicRate =
            getExchangeRateForCurrency(ref, calculatedCurrency);
        final double? effRate = (dynamicRate != null && dynamicRate > 0)
            ? dynamicRate
            : (prefill != null && prefill.exchangeRate > 0
                ? prefill.exchangeRate
                : null);
        if (effRate == null && calculatedCurrency.isNotEmpty) {
          warnFxMissing(context, calculatedCurrency);
        }

        final freightCost = prefill?.estimatedFreightCost ?? 0.0;
        final freightCurr =
            (prefill != null && prefill.freightCurrency.isNotEmpty)
                ? prefill.freightCurrency
                : freightCurrency;
        final freightRate = freightCurr == calculatedCurrency
            ? effRate
            : getExchangeRateForCurrency(ref, freightCurr);
        if (freightRate == null &&
            freightCurr.isNotEmpty &&
            freightCost > 0) {
          warnFxMissing(context, freightCurr);
        }
        final freightEgp = freightCost * (freightRate ?? 0.0);

        final customsDutiesEgp =
            prefill?.estimatedCustomsDutiesEgp ?? 0.0;
        final clearanceFeesEgp =
            prefill?.estimatedClearanceFeesEgp ?? 0.0;

        final fCode = impFile?.primaryNameWithCode ??
            prefill?.importFileTitle ??
            'IMP-$fileId';
        final compName = impFile?.companyName ?? '';

        prefillData = prefill;
        titleController.text =
            compName.isNotEmpty ? '$fCode - $compName' : fCode;

        invoiceForeignController.text = calculatedInvoiceAmount > 0
            ? calculatedInvoiceAmount.toStringAsFixed(2)
            : '';
        invoiceCurrency = calculatedCurrency;
        invoiceEgpController.text =
            (calculatedInvoiceAmount > 0 && effRate != null)
                ? (calculatedInvoiceAmount * effRate).toStringAsFixed(2)
                : '';

        freightForeignController.text =
            freightCost > 0 ? freightCost.toStringAsFixed(2) : '';
        freightCurrency = freightCurr;
        freightRateController.text = rateText(freightRate);
        freightEgpController.text =
            (freightCost > 0 && freightRate != null)
                ? freightEgp.toStringAsFixed(2)
                : '';

        customsEgpController.text =
            customsDutiesEgp > 0 ? customsDutiesEgp.toStringAsFixed(2) : '';
        clearanceEgpController.text = clearanceFeesEgp > 0
            ? clearanceFeesEgp.toStringAsFixed(2)
            : '';
        exchangeRateController.text = rateText(effRate);
      }
    } finally {
      if (context.mounted) {
        isLoadingPrefill = false;
        notify();
      }
    }
  }

  ImportBudgetModel buildTempBudgetModel() {
    final invForeign =
        double.tryParse(invoiceForeignController.text.trim()) ?? 0.0;
    final invEgp = double.tryParse(invoiceEgpController.text.trim()) ?? 0.0;
    final frtForeign =
        double.tryParse(freightForeignController.text.trim()) ?? 0.0;
    final frtEgp = double.tryParse(freightEgpController.text.trim()) ?? 0.0;
    final custEgp = double.tryParse(customsEgpController.text.trim()) ?? 0.0;
    final clrEgp = double.tryParse(clearanceEgpController.text.trim()) ?? 0.0;
    final rate = double.tryParse(exchangeRateController.text.trim()) ?? 0.0;

    return ImportBudgetModel(
      budgetId: 0,
      budgetCode: 'BGT-PREVIEW',
      title: titleController.text.trim(),
      importFileId: selectedImportFileId,
      invoiceAmountForeign: invForeign,
      invoiceCurrency: invoiceCurrency,
      invoiceAmountEgp: invEgp,
      freightCostForeign: frtForeign,
      freightCurrency: freightCurrency,
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

  Map<String, dynamic> buildPayload(double rate) {
    final invForeign =
        double.tryParse(invoiceForeignController.text.trim()) ?? 0.0;
    final invEgp = double.tryParse(invoiceEgpController.text.trim()) ?? 0.0;
    final frtForeign =
        double.tryParse(freightForeignController.text.trim()) ?? 0.0;
    final frtEgp = double.tryParse(freightEgpController.text.trim()) ?? 0.0;
    final custEgp = double.tryParse(customsEgpController.text.trim()) ?? 0.0;
    final clrEgp = double.tryParse(clearanceEgpController.text.trim()) ?? 0.0;

    return <String, dynamic>{
      'title': titleController.text.trim(),
      'import_file_id': selectedImportFileId,
      'invoice_amount_foreign': invForeign,
      'invoice_currency': invoiceCurrency,
      'invoice_amount_egp': invEgp,
      'freight_cost_foreign': frtForeign,
      'freight_currency': freightCurrency,
      'freight_cost_egp': frtEgp,
      'customs_duties_egp': custEgp,
      'clearance_inland_egp': clrEgp,
      'exchange_rate': rate,
      'notes': notesController.text.trim(),
    };
  }
}
