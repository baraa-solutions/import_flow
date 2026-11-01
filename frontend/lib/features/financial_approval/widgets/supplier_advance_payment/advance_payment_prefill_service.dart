import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../currencies/providers/currencies_provider.dart';
import '../../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../../suppliers/providers/suppliers_provider.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';

class AdvancePaymentPrefillData {
  final double basePoAmount;
  final String currency;
  final int? selectedSupplierId;
  final int? primaryPoId;
  final String beneficiaryName;
  final String bankName;
  final String swiftCode;
  final String iban;
  final double? exchangeRate;

  const AdvancePaymentPrefillData({
    required this.basePoAmount,
    required this.currency,
    required this.selectedSupplierId,
    required this.primaryPoId,
    required this.beneficiaryName,
    required this.bankName,
    required this.swiftCode,
    required this.iban,
    required this.exchangeRate,
  });
}

class AdvancePaymentPrefillService {
  AdvancePaymentPrefillService._();

  static double? resolveExchangeRate(WidgetRef ref, String currCode) {
    if (currCode.toUpperCase() == 'EGP') return 1.0;
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    final cur = currencies
        .where((c) => c.currencyCode.toUpperCase() == currCode.toUpperCase())
        .firstOrNull;
    if (cur != null) {
      if (cur.isBaseCurrency) return 1.0;
      if (cur.latestCommercialRate != null && cur.latestCommercialRate! > 0) {
        return cur.latestCommercialRate!;
      }
    }
    return null;
  }

  static Future<AdvancePaymentPrefillData> loadPrefill({
    required WidgetRef ref,
    required int importFileId,
    required String initialCurrency,
    required int? initialSupplierId,
    required String supplierName,
    required int? initialPoId,
    required double? totalAmountForeign,
  }) async {
    BudgetPrefillModel? prefill;
    try {
      prefill = await ref
          .read(importBudgetsProvider.notifier)
          .fetchBudgetPrefill(importFileId);
    } catch (_) {}

    final poList = ref.read(purchaseOrdersProvider).purchaseOrders;
    final linkedPOs = poList.where((po) => po.importFileId == importFileId).toList();

    int? primaryPoId = initialPoId;
    if (linkedPOs.isNotEmpty && primaryPoId == null) {
      primaryPoId = linkedPOs.first.poId;
    }

    double poTotal = 0.0;
    if (prefill != null && prefill.totalInvoiceAmount > 0) {
      poTotal = prefill.totalInvoiceAmount;
    } else if (totalAmountForeign != null &&
        totalAmountForeign > 0 &&
        initialCurrency.isNotEmpty) {
      poTotal = totalAmountForeign;
    }

    final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
    final supObj = suppliers
        .where((s) =>
            (initialSupplierId != null && s.supplierId == initialSupplierId) ||
            s.companyName.trim().toLowerCase() == supplierName.trim().toLowerCase() ||
            (prefill != null &&
                s.companyName.trim().toLowerCase() ==
                    prefill.supplierName.trim().toLowerCase()))
        .firstOrNull;

    final effBank = (supObj?.bankName != null && supObj!.bankName!.isNotEmpty)
        ? supObj.bankName!
        : (prefill?.bankName ?? '');
    final effSwift = (supObj?.swiftCode != null && supObj!.swiftCode!.isNotEmpty)
        ? supObj.swiftCode!
        : (prefill?.swiftCode ?? '');
    final effIban = (supObj?.iban != null && supObj!.iban!.isNotEmpty)
        ? supObj.iban!
        : ((supObj?.accountNumber != null && supObj!.accountNumber!.isNotEmpty)
            ? supObj.accountNumber!
            : (prefill?.iban ?? prefill?.accountNumber ?? ''));
    final effBeneficiary = (supObj?.companyName != null && supObj!.companyName.isNotEmpty)
        ? supObj.companyName
        : (prefill?.beneficiaryName ?? supplierName);

    final effCurr = (prefill != null && prefill.invoiceCurrency.isNotEmpty)
        ? prefill.invoiceCurrency
        : initialCurrency;
    final effRate = resolveExchangeRate(ref, effCurr);

    return AdvancePaymentPrefillData(
      basePoAmount: poTotal,
      currency: effCurr,
      selectedSupplierId: supObj?.supplierId ?? initialSupplierId,
      primaryPoId: primaryPoId,
      beneficiaryName: effBeneficiary,
      bankName: effBank,
      swiftCode: effSwift,
      iban: effIban,
      exchangeRate: effRate,
    );
  }
}
