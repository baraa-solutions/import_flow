import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/performance/dispose_tracker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../projects/providers/projects_provider.dart';
import '../models/purchase_order_model.dart';
import '../providers/purchase_orders_provider.dart';
import '../widgets/create_partial_shipment_dialog.dart';
import '../widgets/po_balance_ledger_dialog.dart';
import '../widgets/po_details_dialog.dart';
import '../widgets/po_filter_toolbar.dart';
import '../widgets/po_form_dialog.dart';
import '../widgets/po_kpi_cards.dart';
import '../widgets/po_mobile_cards_view.dart';
import '../widgets/po_search_and_clone_dialog.dart';
import '../widgets/po_table_view.dart';
import '../widgets/po_visual_load_planner_dialog.dart';

class PurchaseOrdersScreen extends ConsumerStatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  ConsumerState<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends ConsumerState<PurchaseOrdersScreen>
    with DisposeTrackerMixin<PurchaseOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final po = ref.read(purchaseOrdersProvider);
      if (!po.isLoading) ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      final prj = ref.read(projectsProvider);
      if (!prj.isLoading) ref.read(projectsProvider.notifier).fetchProjects();
      final files = ref.read(importFilesProvider);
      if (!files.isLoading) ref.read(importFilesProvider.notifier).fetchImportFiles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showPODetailsDialog(BuildContext context, PurchaseOrderModel po) {
    PoDetailsDialog.show(
      context,
      po,
      onEdit: () => _showPODialog(context, po),
      onOpen3dPlanner: () => PoVisualLoadPlannerDialog.show(context, po),
    );
  }

  void _showPODialog(BuildContext context, PurchaseOrderModel? po,
      {Map<String, dynamic>? initialExtractedFields}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => POFormDialog(po: po, initialExtractedFields: initialExtractedFields),
    );
  }

  void _openSearchAndCloneDialog() {
    final state = ref.read(purchaseOrdersProvider);
    final locale = ref.read(localeProvider);
    final textDir = locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;
    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: locale,
        child: Directionality(
          textDirection: textDir,
          child: PoSearchAndCloneDialog(
            orders: state.purchaseOrders,
            onSelectPO: (po) {
              Navigator.of(ctx).pop();
              _showCloneDialog(po);
            },
          ),
        ),
      ),
    );
  }

  void _showCloneDialog(PurchaseOrderModel po) {
    final l = context.l10n;
    CloneEntityReviewDialog.show(
      context,
      entityType: context.l10n.poPurchaseOrder,
      sourceCode: po.poNumber,
      suggestedNewCode: '${po.poNumber}${TableRowCloneHelper.copyCodeSuffix}',
      sourceTitle: po.displayName,
      copiedFieldsSummary: {
        context.l10n.auditEntityImportCompany: po.companyName ?? '-',
        context.l10n.draftBlPartySupplier: po.supplierName ?? '-',
        context.l10n.poProject: po.projectName ?? '-',
        context.l10n.poCurrencyIncoterm: '${po.currencyCode ?? "USD"} (${po.incotermCode ?? "-"})',
      },
      mandatorilyResetFields: [
        l.cloneFieldStatusDraftBadge,
        l.cloneFieldShipmentUnlinked,
        l.cloneFieldAllocationsReset,
        context.l10n.poResetDeliveryAndOrderDates,
      ],
      allowCopyLineItems: true,
      allowCopyAttachments: true,
      initialCopyLineItems: true,
      initialCopyAttachments: true,
      onConfirm: ({
        required String newCode,
        required String newTitle,
        required bool copyLineItems,
        required bool copyAttachments,
        String? notes,
      }) async {
        try {
          await ref.read(purchaseOrdersProvider.notifier).clonePurchaseOrder(
            po.poId!,
            {
              'new_po_number': newCode,
              'new_po_reference': newTitle.isNotEmpty ? newTitle : null,
              'copy_items': copyLineItems,
              'copy_packing_list': copyLineItems,
              'copy_pallet_plan': copyAttachments,
              if (notes != null) 'notes': notes,
            },
          );
          if (mounted) {
            AppTheme.snackBar(context, l.clonePoSuccess(newCode),
                severity: AppSeverity.success, duration: const Duration(seconds: 3));
            ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
          }
        } catch (e) {
          if (mounted) {
            AppTheme.snackBar(context, l.clonePoError(ApiErrorText.of(l, e)),
                severity: AppSeverity.danger, duration: const Duration(seconds: 4));
          }
        }
      },
    );
  }

  Future<void> _handleToggleActive(PurchaseOrderModel po) async {
    final l = context.l10n;
    final isActive = po.isActive;
    final confirm = await AppConfirmDialog.showToggleActive(
      context,
      isCurrentlyActive: isActive,
      entityName: po.displayName,
      message: isActive ? l.confirmDeactivatePo(po.displayName) : l.confirmRestorePo(po.displayName),
      confirmLabel: isActive ? l.deactivateBtn : l.restore,
    );
    if (confirm == true) {
      if (po.isActive) {
        await ref.read(purchaseOrdersProvider.notifier).deletePurchaseOrder(po.poId!);
      } else {
        await ref.read(purchaseOrdersProvider.notifier).restorePurchaseOrder(po.poId!);
      }
    }
  }

  void _handlePrint(PurchaseOrderModel po) {
    AppTheme.snackBar(
      context,
      context.l10n.printPoAndPackingList(po.displayName, po.poNumber),
      duration: const Duration(seconds: 2),
    );
  }

  void _openBalanceLedger(PurchaseOrderModel po) {
    if (po.poId != null) {
      showPOBalanceLedgerDialog(context, ref, poId: po.poId!, poCode: po.poNumber);
    }
  }

  Widget _buildContent(PurchaseOrdersState state, AppLocalizations l, {required bool isMobileLayout}) {
    if (state.isLoading) return const AppLoadingState();
    if (state.error != null) {
      return AppErrorState(
        message: ApiErrorText.of(l, state.error, fallback: l.operationFailed),
        onRetry: () => ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders(),
      );
    }
    if (state.purchaseOrders.isEmpty) {
      return AppEmptyState(message: l.noDataFound, icon: Icons.inventory_2_outlined);
    }
    if (isMobileLayout) {
      return PoMobileCardsView(
        orders: state.purchaseOrders,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        onView: (po) => _showPODetailsDialog(context, po),
        onEdit: (po) => _showPODialog(context, po),
        onClone: _showCloneDialog,
        onBalanceLedger: _openBalanceLedger,
        onPartialShipment: (po) => showCreatePartialShipmentDialog(context, po: po),
        onToggleActive: _handleToggleActive,
        onPrint: _handlePrint,
      );
    }
    return PoTableView(
      orders: state.purchaseOrders,
      onView: (po) => _showPODetailsDialog(context, po),
      onEdit: (po) => _showPODialog(context, po),
      onClone: _showCloneDialog,
      onBalanceLedger: _openBalanceLedger,
      onPartialShipment: (po) => showCreatePartialShipmentDialog(context, po: po),
      onToggleActive: _handleToggleActive,
      onPrint: _handlePrint,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(purchaseOrdersProvider);
    final projectsList = ref.watch(projectsProvider).valueOrNull ?? [];

    final totalOrders = state.purchaseOrders.length;
    final totalFobSum = state.purchaseOrders.fold<double>(0.0, (sum, p) => sum + p.totalAmountFob);
    final totalCbmSum = state.purchaseOrders.fold<double>(0.0, (sum, p) => sum + p.totalCbm);
    final totalGrossSum =
        state.purchaseOrders.fold<double>(0.0, (sum, p) => sum + p.totalGrossWeightKg);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): _openSearchAndCloneDialog,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: PageHeader(
            icon: Icons.shopping_cart_outlined,
            title: l.purchaseOrdersTitle,
            subtitle: l.purchaseOrdersSubtitle,
            actions: [
              Builder(
                builder: (ctx) {
                  final isNarrow = MediaQuery.sizeOf(ctx).width < 768;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isNarrow)
                        SmartUploadButton(
                          module: SmartUploadModule.purchaseOrder,
                          label: '🚀 ${l.smartInvoiceExtract}',
                          onDataExtracted: (result) {
                            final fields = result.extractedFields;
                            AppTheme.snackBar(
                              context,
                              '${fields['po_number'] ?? '-'}',
                              severity: AppSeverity.success,
                              duration: const Duration(seconds: 4),
                            );
                            _showPODialog(context, null, initialExtractedFields: fields);
                          },
                        ),
                      if (!isNarrow) const SizedBox(width: 8),
                      if (!isNarrow) const BackToDashboardButton(),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppTheme.white),
                        onPressed: () =>
                            ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders(),
                      ),
                      const SizedBox(width: 10),
                    ],
                  );
                },
              ),
            ],
          ),
          body: SelectionArea(
            child: LayoutBuilder(
              builder: (context, screenConstraints) {
                final isMobile = screenConstraints.maxWidth < 768;
                final kpiMetrics = PoKpiCards(
                  totalOrders: totalOrders,
                  totalFobSum: totalFobSum,
                  totalCbmSum: totalCbmSum,
                  totalGrossSum: totalGrossSum,
                );
                final toolbar = PoFilterToolbar(
                  searchController: _searchController,
                  onSearchChanged: (v) =>
                      ref.read(purchaseOrdersProvider.notifier).setSearchQuery(v),
                  onNewPO: () => _showPODialog(context, null),
                  onSearchAndClone: _openSearchAndCloneDialog,
                  onRefresh: () =>
                      ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders(),
                  selectedProjectId: state.projectFilter,
                  selectedStatus: state.statusFilter,
                  onProjectFilterChanged: (v) =>
                      ref.read(purchaseOrdersProvider.notifier).setProjectFilter(v),
                  onStatusFilterChanged: (v) =>
                      ref.read(purchaseOrdersProvider.notifier).setStatusFilter(v),
                  projectsList: projectsList,
                  orders: state.purchaseOrders,
                );

                if (isMobile) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        kpiMetrics,
                        Padding(padding: const EdgeInsets.all(8.0), child: toolbar),
                        _buildContent(state, l, isMobileLayout: true),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    kpiMetrics,
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: toolbar),
                    const SizedBox(height: 6),
                    Expanded(child: _buildContent(state, l, isMobileLayout: false)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
