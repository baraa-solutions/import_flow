import '../../../../core/widgets/table_row_clone_helper.dart';
import '../../models/financial_approval_model.dart';

class PaymentLinkedPoCloner {
  PaymentLinkedPoCloner._();

  static BudgetPrefillModel clonePoItem({
    required BudgetPrefillModel currentPrefill,
    required LinkedPOItemModel po,
  }) {
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

    final currentList = List<LinkedPOItemModel>.from(currentPrefill.linkedPos);
    final idx = currentList.indexOf(po);
    if (idx >= 0) {
      currentList.insert(idx + 1, clonedItem);
    } else {
      currentList.add(clonedItem);
    }

    return BudgetPrefillModel(
      importFileId: currentPrefill.importFileId,
      importFileCode: currentPrefill.importFileCode,
      importFileTitle: currentPrefill.importFileTitle,
      incoterm: currentPrefill.incoterm,
      supplierId: currentPrefill.supplierId,
      supplierName: currentPrefill.supplierName,
      beneficiaryName: currentPrefill.beneficiaryName,
      bankName: currentPrefill.bankName,
      swiftCode: currentPrefill.swiftCode,
      accountNumber: currentPrefill.accountNumber,
      iban: currentPrefill.iban,
      paymentTermsSummary: currentPrefill.paymentTermsSummary,
      linkedPos: currentList,
      totalInvoiceAmount: currentPrefill.totalInvoiceAmount + po.totalAmount,
      invoiceCurrency: currentPrefill.invoiceCurrency,
      totalInvoiceAmountEgp: currentPrefill.totalInvoiceAmountEgp +
          (po.totalAmount * currentPrefill.exchangeRate),
      estimatedFreightCost: currentPrefill.estimatedFreightCost,
      freightCurrency: currentPrefill.freightCurrency,
      estimatedFreightCostEgp: currentPrefill.estimatedFreightCostEgp,
      estimatedCustomsDutiesEgp: currentPrefill.estimatedCustomsDutiesEgp,
      estimatedClearanceFeesEgp: currentPrefill.estimatedClearanceFeesEgp,
      estimatedGrandTotalEgp: currentPrefill.estimatedGrandTotalEgp +
          (po.totalAmount * currentPrefill.exchangeRate),
      exchangeRate: currentPrefill.exchangeRate,
    );
  }
}
