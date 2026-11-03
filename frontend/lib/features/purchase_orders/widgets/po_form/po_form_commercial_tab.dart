import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../currencies/providers/currencies_provider.dart';
import '../../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../../customs_tariff/widgets/duty_calculator_dialog.dart';
import '../../../import_companies/providers/import_companies_provider.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../../incoterms/providers/incoterms_provider.dart';
import '../../../projects/providers/projects_provider.dart';
import '../../../suppliers/providers/suppliers_provider.dart';
import '../../models/purchase_order_model.dart';
import '../po_form_dialog.dart';
import '../po_reconciliation_warning_dialog.dart';
import 'po_form_header_card.dart';
import 'po_form_items_tab.dart';
import 'po_form_summary_bar.dart';

/// Tab 1: Commercial Header, Line Items, and Financial Summary.
class POFormCommercialTab extends StatelessWidget {
  final POFormDialogState dialog;

  const POFormCommercialTab({super.key, required this.dialog});

  @override
  Widget build(BuildContext context) {
    final ref = dialog.ref;
    final projects = ref.watch(projectsProvider).valueOrNull ?? [];
    final companies = ref.watch(importCompaniesProvider).valueOrNull ?? [];
    final suppliers = ref.watch(suppliersProvider).valueOrNull ?? [];
    final incoterms = ref.watch(incotermsProvider).valueOrNull ?? [];
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];
    final tariffs = ref.watch(customsTariffProvider).valueOrNull ?? [];
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    final reconciliation = evaluatePOReconciliation(
      invoiceItems: dialog.dialogItems,
      packingItems: dialog.dialogPackingItems,
      tariffs: tariffs,
    );
    final Set<String> mismatchedHs = reconciliation.items
        .where((i) => !i.isMatched || i.isMissingInPacking || i.isMissingInInvoice)
        .map((i) => i.hsCode)
        .toSet();

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.only(top: 8, end: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          POFormHeaderCard(
            guideMatchResult: dialog.poGuideMatchResult,
            importFiles: importFiles,
            projects: projects,
            companies: companies,
            suppliers: suppliers,
            incoterms: incoterms,
            currencies: currencies,
            selectedImportFileId: dialog.selectedImportFileId,
            onImportFileChanged: (v) {
              dialog.updateState(() => dialog.selectedImportFileId = v);
              dialog.loadPoGuide();
            },
            poReferenceCtrl: dialog.poReferenceCtrl,
            piCtrl: dialog.piCtrl,
            orderDate: dialog.selectedOrderDate,
            onOrderDateChanged: (d) {
              dialog.updateState(() {
                dialog.selectedOrderDate = d;
                dialog.updateExchangeRate(dialog.selectedCurrencyId, currencies);
              });
            },
            selectedProjectId: dialog.selectedProjectId,
            onProjectChanged: (v) => dialog.updateState(() => dialog.selectedProjectId = v),
            selectedCompanyId: dialog.selectedCompanyId,
            onCompanyChanged: (v) => dialog.updateState(() => dialog.selectedCompanyId = v),
            selectedSupplierId: dialog.selectedSupplierId,
            onSupplierChanged: (v) {
              dialog.updateState(() => dialog.selectedSupplierId = v);
              dialog.loadPoGuide();
            },
            selectedIncotermId: dialog.selectedIncotermId,
            onIncotermChanged: (v) {
              dialog.updateState(() => dialog.selectedIncotermId = v);
              dialog.loadPoGuide();
            },
            selectedCurrencyId: dialog.selectedCurrencyId,
            onCurrencyChanged: (v) {
              dialog.updateState(() {
                dialog.selectedCurrencyId = v;
                dialog.updateExchangeRate(v, currencies);
              });
            },
            selectedCountryOfOrigin: dialog.selectedCountryOfOrigin,
            onCountryOfOriginChanged: (v) {
              dialog.updateState(() => dialog.selectedCountryOfOrigin = v);
              dialog.loadPoGuide();
            },
            selectedStatus: dialog.selectedStatus,
            onStatusChanged: (v) => dialog.updateState(() => dialog.selectedStatus = v),
            rateCtrl: dialog.rateCtrl,
            rateHelperText: dialog.rateHelperText,
            selectedPaymentTerms: dialog.selectedPaymentTerms,
            onPaymentTermsChanged: (v) => dialog.updateState(() => dialog.selectedPaymentTerms = v),
            onInvoiceDataExtracted: (ext) => dialog.applyExtractedFields(ext, targetTab: 'invoice'),
          ),
          const SizedBox(height: 14),
          POFormItemsTab(
            items: dialog.dialogItems,
            tariffs: tariffs,
            currencies: currencies,
            selectedCurrencyId: dialog.selectedCurrencyId,
            selectedCountryOfOrigin: dialog.selectedCountryOfOrigin,
            mismatchedHsCodes: mismatchedHs,
            onItemUpdated: (idx, item) {
              dialog.updateState(() {
                if (idx < dialog.dialogItems.length) {
                  dialog.dialogItems[idx] = item;
                } else {
                  dialog.dialogItems.add(item);
                }
              });
            },
            onItemAdded: () => dialog.updateState(() => dialog.dialogItems.add(
                  POLineItemModel(
                    descriptionAr: 'بند جديد ${dialog.dialogItems.length + 1}',
                    quantity: 1,
                    unitPrice: 0,
                  ),
                )),
            onItemCloned: dialog.cloneLineItem,
            onItemRemoved: (idx) => dialog.updateState(() => dialog.dialogItems.removeAt(idx)),
            onOpenDutyCalculator: () {
              final extracted = dialog.dialogItems
                  .map((i) => {'description': i.descriptionAr, 'hs_code': i.hsCode ?? '', 'price': (i.quantity * i.unitPrice)})
                  .toList();
              final curr = currencies.where((c) => c.currencyId == dialog.selectedCurrencyId).firstOrNull;
              showDutyCalculatorDialog(
                context,
                ref,
                initialCurrency: curr?.currencyCode ?? 'USD',
                initialImportFileId: dialog.selectedImportFileId,
                initialExtractedLines: extracted,
              );
            },
          ),
          POFormSummaryBar(
            items: dialog.dialogItems,
            currencies: currencies,
            selectedCurrencyId: dialog.selectedCurrencyId,
            exchangeRate: double.tryParse(dialog.rateCtrl.text.trim()) ?? 1.0,
            tariffs: tariffs,
            notesCtrl: dialog.notesCtrl,
          ),
        ],
      ),
    );
  }
}
