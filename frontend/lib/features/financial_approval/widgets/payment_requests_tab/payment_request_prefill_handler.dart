import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../currencies/providers/currencies_provider.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../../suppliers/providers/suppliers_provider.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';

class PaymentRequestPrefillResult {
  final BudgetPrefillModel? prefillData;
  final String title;
  final int? selectedSupplierId;
  final String supplierName;
  final String? paymentType;
  final double invoiceAmount;
  final String currencyCode;
  final double? effectiveRate;
  final String bankName;
  final String swiftCode;
  final String iban;

  const PaymentRequestPrefillResult({
    required this.prefillData,
    required this.title,
    required this.selectedSupplierId,
    required this.supplierName,
    required this.paymentType,
    required this.invoiceAmount,
    required this.currencyCode,
    required this.effectiveRate,
    required this.bankName,
    required this.swiftCode,
    required this.iban,
  });
}

class PaymentRequestPrefillHandler {
  PaymentRequestPrefillHandler._();

  static double? getExchangeRateForCurrency(
      WidgetRef ref, String currencyCode) {
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

  static Future<PaymentRequestPrefillResult?> resolvePrefill({
    required WidgetRef ref,
    required int fileId,
    required String defaultCurrency,
  }) async {
    BudgetPrefillModel? prefill;
    try {
      prefill = await ref
          .read(importBudgetsProvider.notifier)
          .fetchBudgetPrefill(fileId);
    } catch (_) {
      prefill = null;
    }

    final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final impFile =
        importFiles.where((f) => f.importFileId == fileId).firstOrNull;

    double calculatedInvoiceAmount = 0.0;
    String calculatedCurrency = defaultCurrency;

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
        : ((supObj?.accountNumber != null && supObj!.accountNumber!.isNotEmpty)
            ? supObj.accountNumber!
            : (prefill?.iban ?? prefill?.accountNumber ?? ''));

    final dynamicRate =
        getExchangeRateForCurrency(ref, calculatedCurrency);
    final double? effRate = (dynamicRate != null && dynamicRate > 0)
        ? dynamicRate
        : (prefill != null && prefill.exchangeRate > 0
            ? prefill.exchangeRate
            : null);

    final fCode = impFile?.primaryNameWithCode ??
        prefill?.importFileTitle ??
        'IMP-$fileId';
    final compName = impFile?.companyName ?? '';
    final title = compName.isNotEmpty ? '$fCode - $compName' : fCode;

    return PaymentRequestPrefillResult(
      prefillData: prefill,
      title: title,
      selectedSupplierId: effectiveSupplierId,
      supplierName: effectiveSupplierName,
      paymentType: prefill?.paymentTermsSummary,
      invoiceAmount: calculatedInvoiceAmount,
      currencyCode: calculatedCurrency,
      effectiveRate: effRate,
      bankName: effectiveBankName,
      swiftCode: effectiveSwiftCode,
      iban: effectiveIban,
    );
  }
}
