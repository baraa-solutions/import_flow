import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/import_file_po_linker.dart';
import '../../../experience_guide/widgets/smart_shipment_reference_card.dart';
import '../../../purchase_orders/models/purchase_order_model.dart' hide PackingListItemModel;
import '../../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../models/import_file_model.dart';
import '../dialogs/add_edit_import_file_dialog.dart';
import '../import_file_details_dialog.dart';
import '../visual_container_load_planner_dialog.dart';

/// Helper launcher methods for sub-dialogs triggered from the Master Import Report.
class MasterReportDialogHelpers {
  const MasterReportDialogHelpers._();

  /// Opens the Visual Container Load Planner dialog.
  static void showVisualLoadPlan(
    BuildContext context,
    ImportFileModel file,
    List<PurchaseOrderModel> pos,
    double totalCbm,
    double totalWeight,
  ) {
    showDialog(
      context: context,
      builder: (context) => VisualContainerLoadPlannerDialog(
        file: file,
        linkedPOs: pos,
        fallbackCbm: totalCbm,
        fallbackWeight: totalWeight,
      ),
    );
  }

  /// Opens the Smart Shipment Reference Card inside a dialog.
  static void showSmartReference(
    BuildContext context,
    WidgetRef ref,
    ImportFileModel file, [
    List<PurchaseOrderModel>? linkedPOs,
  ]) {
    final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
    final effectivePOs = linkedPOs ?? ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SelectionArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850, maxHeight: 800),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isArabic ? 'المرجع الذكي للشحنة' : 'Shipment Smart Reference',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.cobalt),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SmartShipmentReferenceCard(
                        importFileId: file.importFileId,
                        initialHsCode: file.hsCode,
                        initialCategory: file.productCategory,
                        initialPod: file.portOfDischarge,
                        initialSupplier: file.supplierName,
                        initialCarrier: file.selectedScenario,
                        linkedPOs: effectivePOs,
                        file: file,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Navigates from report row directly to Import File Details dialog.
  static Future<void> showImportFileDetails(
    BuildContext context,
    WidgetRef ref,
    ImportFileModel file,
  ) async {
    var poState = ref.read(purchaseOrdersProvider);
    if (poState.purchaseOrders.isEmpty) {
      await ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      poState = ref.read(purchaseOrdersProvider);
    }
    final allPOs = poState.purchaseOrders;
    final linkedPOs = ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs);
    final metrics = ImportFilePoLinker.computeMetrics(file: file, linkedPOs: linkedPOs);
    final currentLocale = ref.read(localeProvider);
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: currentLocale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: ImportFileDetailsDialog(
            file: file,
            linkedPOs: linkedPOs,
            invoiceNumbers: metrics.invoices,
            totalPackingListCbm: metrics.cbm,
            totalPackingListWeight: metrics.weightKg,
            totalPackingListsCount: metrics.plCount,
            onEditPressed: () => AddEditImportFileDialog.show(context, ref, fileToEdit: file),
          ),
        );
      },
    );
  }
}
