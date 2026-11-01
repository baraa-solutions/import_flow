import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../currencies/providers/currencies_provider.dart';
import '../../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../../import_companies/providers/import_companies_provider.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../../incoterms/providers/incoterms_provider.dart';
import '../../../projects/providers/projects_provider.dart';
import '../../../suppliers/providers/suppliers_provider.dart';
import '../../models/purchase_order_model.dart';
import '../po_report_preview_dialog.dart';

/// Helper to trigger the comprehensive PO report preview.
class PoFormPreviewHelper {
  static void showReport({
    required BuildContext context,
    required WidgetRef ref,
    required PurchaseOrderModel? po,
    required String piNumber,
    required DateTime orderDate,
    required int? companyId,
    required int? supplierId,
    required int? incotermId,
    required int? currencyId,
    required double exchangeRate,
    required String? countryOfOrigin,
    required String? paymentTerms,
    required int? projectId,
    required int? importFileId,
    required List<POLineItemModel> items,
    required List<PackingListItemModel> packingItems,
    required List<PalletPlanItemModel> palletPlanItems,
    required bool isDirectVolumeMode,
    required String notes,
    required VoidCallback onConfirmSave,
  }) {
    final companies = ref.read(importCompaniesProvider).valueOrNull ?? [];
    final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
    final incoterms = ref.read(incotermsProvider).valueOrNull ?? [];
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    final projects = ref.read(projectsProvider).valueOrNull ?? [];
    final tariffs = ref.read(customsTariffProvider).valueOrNull ?? [];
    final files = ref.read(importFilesProvider).valueOrNull ?? [];

    POReportPreviewDialog.show(
      context: context,
      poNumber: po?.poNumber ?? 'PO-NEW (Draft)',
      piNumber: piNumber.trim().isNotEmpty ? piNumber.trim() : null,
      orderDate: orderDate,
      companyName: companies.where((c) => c.companyId == companyId).firstOrNull?.importerName ?? 'Select Company',
      supplierName: suppliers.where((s) => s.supplierId == supplierId).firstOrNull?.companyName ?? 'Select Supplier',
      incoterm: incoterms.where((i) => i.incotermId == incotermId).firstOrNull?.incotermCode ?? 'EXW',
      currency: currencies.where((c) => c.currencyId == currencyId).firstOrNull?.currencyCode ?? 'USD',
      exchangeRate: exchangeRate,
      countryOfOrigin: countryOfOrigin,
      paymentTerms: paymentTerms,
      projectName: projects.where((p) => p.projectId == projectId).firstOrNull?.projectName,
      importFileCode: files.where((f) => f.importFileId == importFileId).firstOrNull?.primaryNameWithCode,
      items: items,
      packingItems: packingItems,
      palletItems: isDirectVolumeMode ? palletPlanItems : <PalletPlanItemModel>[],
      tariffs: tariffs,
      isDirectVolumeMode: isDirectVolumeMode,
      notes: notes.trim(),
      onConfirmSave: onConfirmSave,
    );
  }
}
