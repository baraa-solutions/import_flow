// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/import_file_po_linker.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../purchase_orders/models/purchase_order_model.dart' hide PackingListItemModel;
import '../models/import_file_model.dart';
import '../../experience_guide/models/guide_entry_model.dart';
import '../../experience_guide/providers/experience_guide_provider.dart';
import '../../comprehensive_report/services/comprehensive_dossier_service.dart';
import '../../shipment_updates/providers/shipment_updates_provider.dart';
import '../../customs_clearance/providers/customs_clearance_provider.dart';
import '../../warehouse_receiving/providers/warehouse_receiving_provider.dart';
import 'file_details/file_details_header_card.dart';
import 'file_details/file_details_overview_tab.dart';
import 'file_details/file_details_stages_timeline_tab.dart';
import 'file_details/file_details_financial_summary_tab.dart';
import 'file_details/file_details_documents_tab.dart';
import 'file_details/file_details_actions_bar.dart';
import 'file_details/shipment_acid_status_badge.dart';
import 'file_details/courier_tracking_action_button.dart';

/// 🚢 Modular Coordinator for Import File Details Dialog
///
/// Decomposed into clean dedicated sub-components (< 400 lines Coordinator):
/// - Header & Milestone Cockpit: [FileDetailsHeaderCard]
/// - Overview Tab: [FileDetailsOverviewTab]
/// - Stages & Timeline Tab: [FileDetailsStagesTimelineTab]
/// - Financial Summary Tab: [FileDetailsFinancialSummaryTab]
/// - Documents Registry Tab: [FileDetailsDocumentsTab]
/// - Bottom Action Toolbar: [FileDetailsActionsBar]
class ImportFileDetailsDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;
  final List<PurchaseOrderModel> linkedPOs;
  final Set<String> invoiceNumbers;
  final double totalPackingListCbm;
  final double totalPackingListWeight;
  final int totalPackingListsCount;
  final VoidCallback? onEditPressed;

  const ImportFileDetailsDialog({
    super.key,
    required this.file,
    required this.linkedPOs,
    required this.invoiceNumbers,
    required this.totalPackingListCbm,
    required this.totalPackingListWeight,
    required this.totalPackingListsCount,
    this.onEditPressed,
  });

  @override
  ConsumerState<ImportFileDetailsDialog> createState() => ImportFileDetailsDialogState();
}

class ImportFileDetailsDialogState extends ConsumerState<ImportFileDetailsDialog> {
  GuideMatchResultModel? _guideMatchResult;

  @override
  void initState() {
    super.initState();
    final container = ProviderScope.containerOf(context, listen: false);
    container.invalidate(smartReferenceCardProvider(widget.file.importFileId));
    container.invalidate(similarShipmentsProvider(widget.file.importFileId));
    container.invalidate(detectedPatternsProvider);
    _loadExperienceGuide();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final poState = ref.read(purchaseOrdersProvider);
      if (poState.purchaseOrders.isEmpty && !poState.isLoading) {
        await ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
        if (mounted) {
          _loadExperienceGuide();
        }
      }
    });
  }

  Future<void> _loadExperienceGuide() async {
    try {
      final allHsCodes = <String>{};
      final allCategories = <String>{};
      final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
      final livePOs = ImportFilePoLinker.getLinkedPOs(file: widget.file, allPOs: allPOs);
      final effectivePOs = livePOs.isNotEmpty ? livePOs : widget.linkedPOs;

      for (final po in effectivePOs) {
        for (final pli in po.packingListItems) {
          if (pli.hsCode.trim().isNotEmpty) allHsCodes.add(pli.hsCode.trim());
          if (pli.description != null && pli.description!.trim().isNotEmpty) {
            allCategories.add(pli.description!.trim());
          }
        }
        for (final it in po.items) {
          if (it.hsCode != null && it.hsCode!.trim().isNotEmpty) {
            allHsCodes.add(it.hsCode!.trim());
          }
          if (it.mainDescription != null && it.mainDescription!.trim().isNotEmpty) {
            allCategories.add(it.mainDescription!.trim());
          }
        }
      }
      if (widget.file.hsCode != null && widget.file.hsCode!.trim().isNotEmpty) {
        allHsCodes.add(widget.file.hsCode!.trim());
      }
      if (widget.file.productCategory != null && widget.file.productCategory!.trim().isNotEmpty) {
        allCategories.add(widget.file.productCategory!.trim());
      }

      final res = await ref.read(experienceGuideProvider.notifier).matchShipment(
        supplier: widget.file.supplierName,
        hsCode: allHsCodes.isNotEmpty ? allHsCodes.first : widget.file.hsCode,
        productCategory: allCategories.isNotEmpty ? allCategories.first : widget.file.productCategory,
        portOfDischarge: widget.file.portOfDischarge,
        incoterm: widget.file.incotermCode,
        importFileReference: widget.file.importFileCode,
      );
      if (mounted) {
        setState(() {
          _guideMatchResult = res;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final isDark = AppTheme.isDark(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final allPOs = ref.watch(purchaseOrdersProvider).purchaseOrders;
    final liveLinkedPOs = ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs);
    final linkedPOs = liveLinkedPOs.isNotEmpty ? liveLinkedPOs : widget.linkedPOs;

    final metrics = ImportFilePoLinker.computeMetrics(file: file, linkedPOs: linkedPOs);
    final totalPackingListCbm = metrics.cbm > 0 ? metrics.cbm : widget.totalPackingListCbm;
    final totalPackingListWeight = metrics.weightKg > 0 ? metrics.weightKg : widget.totalPackingListWeight;
    final totalPackingListsCount = metrics.plCount > 0 ? metrics.plCount : widget.totalPackingListsCount;
    final rawInvoices = metrics.invoices.isNotEmpty ? metrics.invoices : widget.invoiceNumbers;
    final poNumbersToExclude = <String>{
      if (file.poNumber != null && file.poNumber!.trim().toUpperCase().startsWith('PO-')) file.poNumber!.trim(),
      for (final po in linkedPOs)
        if (po.poNumber.trim().toUpperCase().startsWith('PO-')) po.poNumber.trim(),
    };
    final invoiceNumbers = rawInvoices.where((inv) =>
      !poNumbersToExclude.contains(inv) &&
      !(inv.toUpperCase().startsWith('PO-') && !inv.toUpperCase().contains('INV') && !inv.toUpperCase().contains('PI'))
    ).toSet();

    final dossierAsync = ref.watch(comprehensiveDossierProvider(file.importFileId));
    final dossier = dossierAsync.valueOrNull;
    final updatesState = ref.watch(shipmentUpdatesProvider);
    final clearanceState = ref.watch(customsClearanceProvider);
    final warehouseState = ref.watch(warehouseReceivingProvider);

    return SelectionArea(
      child: DefaultTabController(
        length: 4,
        child: AlertDialog(
          titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
          contentPadding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 0),
          actionsPadding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 14),
          title: FileDetailsHeaderCard(
            file: file,
            dossier: dossier,
            guideMatchResult: _guideMatchResult,
            totalCbm: totalPackingListCbm,
            grossWeightKg: totalPackingListWeight,
          ),
          content: SizedBox(
            width: 960,
            height: 480,
            child: Column(
              children: [
                // ── Courier & ACID Smart Metadata Bar ─────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      ShipmentAcidStatusBadge.fromImportFile(file, compact: true),
                      const SizedBox(width: 8),
                      CourierTrackingActionButton.fromImportFile(file, compact: true),
                    ],
                  ),
                ),
                Container(
                  color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
                  child: TabBar(
                    indicatorColor: AppTheme.cobalt,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.dashboard_outlined, size: 18),
                        text: isAr ? 'نظرة عامة' : 'Overview',
                      ),
                      Tab(
                        icon: const Icon(Icons.route_outlined, size: 18),
                        text: isAr ? 'مراحل الشحنة والمسار' : 'Stages & Timeline',
                      ),
                      Tab(
                        icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                        text: isAr ? 'الملخص المالي والتكاليف' : 'Financial Summary',
                      ),
                      Tab(
                        icon: const Icon(Icons.folder_shared_outlined, size: 18),
                        text: isAr ? 'سجل المستندات' : 'Documents Registry',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      FileDetailsOverviewTab(
                        file: file,
                        linkedPOs: linkedPOs,
                        invoiceNumbers: invoiceNumbers,
                        totalPackingListCbm: totalPackingListCbm,
                        totalPackingListWeight: totalPackingListWeight,
                        totalPackingListsCount: totalPackingListsCount,
                        dossier: dossier,
                      ),
                      FileDetailsStagesTimelineTab(
                        file: file,
                        dossier: dossier,
                        guideMatchResult: _guideMatchResult,
                        linkedPOs: linkedPOs,
                        onGuideReload: _loadExperienceGuide,
                      ),
                      FileDetailsFinancialSummaryTab(
                        file: file,
                        dossier: dossier,
                      ),
                      FileDetailsDocumentsTab(
                        file: file,
                        dossier: dossier,
                        linkedPOs: linkedPOs,
                        invoiceNumbers: invoiceNumbers,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FileDetailsActionsBar(
              file: file,
              dossier: dossier,
              updatesState: updatesState,
              clearanceState: clearanceState,
              warehouseState: warehouseState,
              onEditPressed: widget.onEditPressed,
              onClose: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
