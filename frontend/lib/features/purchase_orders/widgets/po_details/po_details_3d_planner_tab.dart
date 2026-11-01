import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/container_requirement_engine.dart';
import '../../models/purchase_order_model.dart';
import 'planner3d/po_cargo_extractor.dart';
import 'planner3d/po_planner_3d_container_card.dart';
import 'planner3d/po_planner_3d_controls_toolbar.dart';
import 'planner3d/po_planner_3d_empty_state.dart';
import 'planner3d/po_planner_3d_export_bar.dart';
import 'planner3d/po_planner_3d_fleet_banner.dart';

/// 3D Container Load Planner & Simulation Tab.
///
/// Features:
/// - Cargo extraction from Pallet Plan or Packing List items
/// - Multi-container 3D algorithmic placement simulation
/// - Interactive orientation & stacking mode switches
/// - Dual projection view (side view / top view / both)
/// - Export simulation to PNG image & PDF report
/// - Detailed cargo coordinates & package grouping tables
class PoDetails3dPlannerTab extends StatefulWidget {
  final PurchaseOrderModel po;
  final VoidCallback? onEdit;

  const PoDetails3dPlannerTab({
    super.key,
    required this.po,
    this.onEdit,
  });

  /// Extracts cargo items from a purchase order's pallet plan or packing list.
  static List<CargoItem> extractCargoItems(PurchaseOrderModel po) =>
      PoCargoExtractor.extract(po);

  @override
  State<PoDetails3dPlannerTab> createState() => _PoDetails3dPlannerTabState();
}

class _PoDetails3dPlannerTabState extends State<PoDetails3dPlannerTab> {
  String _viewProjection = 'both';
  late bool? _activeStackingMode;
  CargoOrientationPreference _activeOrientationMode =
      CargoOrientationPreference.smartHybrid;
  final GlobalKey _tab3dRepaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final items = PoDetails3dPlannerTab.extractCargoItems(widget.po);
    _activeStackingMode = items.any((i) => !i.isStackable) ? null : true;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final cargoItems = PoDetails3dPlannerTab.extractCargoItems(widget.po);

    if (cargoItems.isEmpty) {
      return PoPlanner3dEmptyState(onEdit: widget.onEdit);
    }

    final plan = ContainerRequirementEngine.planShipment(
      cargoItems,
      forceStackable: _activeStackingMode,
      forceOrientation: _activeOrientationMode,
    );

    final totalPkgs = cargoItems.length;
    final stackableInActive = _activeStackingMode == true
        ? totalPkgs
        : (_activeStackingMode == false
            ? 0
            : cargoItems.where((c) => c.isStackable).length);
    final nonStackableInActive = totalPkgs - stackableInActive;

    final totalPlanWeight = plan.fold(0.0, (s, p) => s + p.totalWeight);
    final totalPlanVolume = plan.fold(0.0, (s, p) => s + p.totalVolume);

    final Map<String, int> containerCounts = {};
    for (final p in plan) {
      if (p.containerCode != 'FAILED') {
        containerCounts[p.containerCode] =
            (containerCounts[p.containerCode] ?? 0) + 1;
      }
    }
    final fleetSummary = containerCounts.isEmpty
        ? l.poNoSuitableContainers
        : containerCounts.entries.map((e) => '${e.value} x ${e.key}').join(' + ');

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Export Actions Bar (PNG & PDF)
            PoPlanner3dExportBar(
              repaintKey: _tab3dRepaintKey,
              po: widget.po,
              plan: plan,
              fleetSummary: fleetSummary,
              totalPlanWeight: totalPlanWeight,
              totalPlanVolume: totalPlanVolume,
              totalPkgs: totalPkgs,
              isArabic: isArabic,
            ),
            const SizedBox(height: 10),

            // Controls & Stacking Filter Toolbar
            PoPlanner3dControlsToolbar(
              activeOrientationMode: _activeOrientationMode,
              activeStackingMode: _activeStackingMode,
              viewProjection: _viewProjection,
              onStackingModeSelected: (CargoOrientationPreference orientation, bool? stacking) {
                setState(() {
                  _activeOrientationMode = orientation;
                  _activeStackingMode = stacking;
                });
              },
              onProjectionSelected: (proj) {
                setState(() => _viewProjection = proj);
              },
            ),
            const SizedBox(height: 10),

            // Fleet KPI Summary Banner
            PoPlanner3dFleetBanner(
              fleetSummary: fleetSummary,
              totalPkgs: totalPkgs,
              stackableInActive: stackableInActive,
              nonStackableInActive: nonStackableInActive,
              totalPlanWeight: totalPlanWeight,
              totalPlanVolume: totalPlanVolume,
            ),
            const SizedBox(height: 12),

            // Plan Containers List
            RepaintBoundary(
              key: _tab3dRepaintKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: plan.asMap().entries.map((pEntry) {
                  return PoPlanner3dContainerCard(
                    pIdx: pEntry.key,
                    res: pEntry.value,
                    viewProjection: _viewProjection,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
