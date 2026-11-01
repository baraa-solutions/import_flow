import 'package:flutter/material.dart';

import '../../models/purchase_order_model.dart';
import 'packing/po_master_pallet_plan_section.dart';
import 'packing/po_packing_list_items_table.dart';
import 'packing/po_packing_summary_reports.dart';
import 'packing/po_packing_validation_banners.dart';
import 'po_resolved_metrics.dart';

/// Review Packing List Tab (BP-003).
///
/// Features:
/// - Reconciliation & Discrepancy Status Banner
/// - Validation Status Banner (weight & dimension checks)
/// - 3D Simulation Quick Action Banner
/// - Master Pallet Plan Table (pallet types, counts, weights, dimensions)
/// - Packing List Items Table (dimensions, weights, CBM, copy action)
/// - Summary By HS Code Report table
/// - Summary By Package Type Report table
class PoDetailsPackingTab extends StatelessWidget {
  final PurchaseOrderModel po;
  final POResolvedMetrics metrics;
  final VoidCallback? onOpen3dPlanner;

  const PoDetailsPackingTab({
    super.key,
    required this.po,
    required this.metrics,
    this.onOpen3dPlanner,
  });

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PoPackingValidationBanners(
              po: po,
              metrics: metrics,
              onOpen3dPlanner: onOpen3dPlanner,
            ),
            PoMasterPalletPlanSection(
              palletPlanItems: po.palletPlanItems,
              onOpen3dPlanner: onOpen3dPlanner,
            ),
            PoPackingListItemsTable(
              packingListItems: po.packingListItems,
              metrics: metrics,
            ),
            const SizedBox(height: 20),
            PoPackingSummaryReports(
              metrics: metrics,
            ),
          ],
        ),
      ),
    );
  }
}
