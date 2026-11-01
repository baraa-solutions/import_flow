import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../customs_tariff/providers/customs_tariff_provider.dart';
import '../l10n/po_fulfillment_l10n.dart';
import '../models/purchase_order_model.dart';
import 'create_partial_shipment_dialog.dart';
import 'po_details/po_details_3d_planner_tab.dart';
import 'po_details/po_details_actions_bar.dart';
import 'po_details/po_details_allocations_tab.dart';
import 'po_details/po_details_items_tab.dart';
import 'po_details/po_details_packing_tab.dart';
import 'po_details/po_resolved_metrics.dart';

/// The decomposed coordinator dialog for Purchase Order Details.
///
/// Features:
/// - Tab 1: Commercial PO Line Items & Summary ([PoDetailsItemsTab])
/// - Tab 2: Review Packing List & Package Type Summary ([PoDetailsPackingTab])
/// - Tab 3: Shipment Allocations Ledger & Balance Progress ([PoDetailsAllocationsTab])
/// - Tab 4: Interactive 3D Container Load Planner & Simulation ([PoDetails3dPlannerTab])
/// - Overflow-free responsive layout & actions toolbar ([PoDetailsActionsBar])
class PoDetailsDialog extends ConsumerStatefulWidget {
  final PurchaseOrderModel po;
  final VoidCallback? onEdit;
  final VoidCallback? onOpen3dPlanner;

  const PoDetailsDialog({
    super.key,
    required this.po,
    this.onEdit,
    this.onOpen3dPlanner,
  });

  static Future<void> show(
    BuildContext context,
    PurchaseOrderModel po, {
    VoidCallback? onEdit,
    VoidCallback? onOpen3dPlanner,
  }) {
    return showDialog(
      context: context,
      builder: (dialogCtx) => PoDetailsDialog(
        po: po,
        onEdit: onEdit,
        onOpen3dPlanner: onOpen3dPlanner,
      ),
    );
  }

  static String formatWeight(double val) => POResolvedMetrics.formatWeight(val);
  static List<CargoItem> extractCargoItems(PurchaseOrderModel po) =>
      PoDetails3dPlannerTab.extractCargoItems(po);

  @override
  ConsumerState<PoDetailsDialog> createState() => _PoDetailsDialogState();
}

/// Backward-compatible alias matching uppercase PO convention
typedef PODetailsDialog = PoDetailsDialog;

class _PoDetailsDialogState extends ConsumerState<PoDetailsDialog> {
  PurchaseOrderModel get po => widget.po;

  @override
  Widget build(BuildContext context) {
    final tariffs = ref.read(customsTariffProvider).valueOrNull ?? [];
    if (tariffs.isEmpty) {
      ref.read(customsTariffProvider.notifier).fetchTariffs();
    }

    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final metrics = POResolvedMetrics.compute(
      po: po,
      tariffs: tariffs,
      l10n: l,
    );

    return SelectionArea(
      child: DefaultTabController(
        length: 4,
        child: AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : null,
          title: Row(
            children: [
              const Icon(Icons.inventory_2, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  po.displayName != po.poNumber
                      ? '${l.purchaseOrdersTitle}: ${po.displayName} (${po.poNumber})'
                      : '${l.purchaseOrdersTitle}: ${po.displayName}',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              AppStatusBadge.fromStatus(
                status: po.status,
                label: po.statusLabel(l),
              ),
            ],
          ),
          content: SizedBox(
            width: math.min(1180.0, MediaQuery.of(context).size.width - 32),
            height: math.min(780.0, MediaQuery.of(context).size.height - 48),
            child: Column(
              children: [
                Container(
                  color: isDark
                      ? AppTheme.darkCardBackground
                      : AppTheme.charcoalSurface,
                  child: TabBar(
                    labelColor: AppTheme.cobalt,
                    unselectedLabelColor: AppTheme.textMuted,
                    indicatorColor: AppTheme.cobalt,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.receipt_long, size: 18),
                        text: l.poLineItemsTab,
                      ),
                      Tab(
                        icon: const Icon(Icons.fact_check, size: 18),
                        text: l.reviewPackingListTab,
                      ),
                      Tab(
                        icon: const Icon(Icons.local_shipping_outlined, size: 18),
                        text: l.poAllocationsListTitle,
                      ),
                      Tab(
                        icon: const Icon(Icons.view_in_ar_rounded, size: 18),
                        text: l.containerLoadPlan3dTitle,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Commercial PO Line Items & Summary Card
                      PoDetailsItemsTab(
                        po: po,
                        metrics: metrics,
                        onAllocatePressed: () =>
                            showCreatePartialShipmentDialog(context, po: po),
                      ),

                      // Tab 2: Review Packing List
                      PoDetailsPackingTab(
                        po: po,
                        metrics: metrics,
                        onOpen3dPlanner: widget.onOpen3dPlanner,
                      ),

                      // Tab 3: Shipment Allocations Ledger & Balance
                      PoDetailsAllocationsTab(
                        po: po,
                        metrics: metrics,
                      ),

                      // Tab 4: 3D Container Load Planner
                      PoDetails3dPlannerTab(
                        po: po,
                        onEdit: widget.onEdit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsOverflowButtonSpacing: 8,
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            PoDetailsActionsBar(
              po: po,
              metrics: metrics,
              onEdit: widget.onEdit,
              onOpen3dPlanner: widget.onOpen3dPlanner,
            ),
          ],
        ),
      ),
    );
  }
}
