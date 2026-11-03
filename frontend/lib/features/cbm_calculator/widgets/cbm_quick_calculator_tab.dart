import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/container_requirement_engine.dart';
import '../models/cbm_calculator_model.dart';
import 'cbm_active_session_banner.dart';
import 'cbm_items_table.dart';
import 'cbm_results_summary_header.dart';
import 'cbm_stacking_banner.dart';
import 'dual_divisor_selector_card.dart';
import 'volumetric_weight_comparison_tile.dart';

class CbmQuickCalculatorTab extends StatefulWidget {
  final List<CBMItemModel> quickItems;
  final String quickShipmentMode;
  final bool isStackable;
  final int? activeSessionId;
  final String? activeSessionCode;
  final String? activeSessionTitle;
  final ScrollController scrollController;
  final int lastFocusedItemIndex;
  final VoidCallback onSaveChanges;
  final VoidCallback onNewBlankSession;
  final ValueChanged<String> onShipmentModeChanged;
  final ValueChanged<bool> onStackableChanged;
  final VoidCallback onCompareContainers;
  final VoidCallback onVisualLoadPlan;
  final VoidCallback onAddPackageLine;
  final VoidCallback onSaveCalculation;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final VoidCallback onCopyPackagesTsv;
  final VoidCallback onCopyStudyReport;
  final void Function(int index, CBMItemModel item) onItemUpdated;
  final void Function(int index) onCloneItem;
  final void Function(int index) onDeleteItem;

  const CbmQuickCalculatorTab({
    super.key,
    required this.quickItems,
    required this.quickShipmentMode,
    required this.isStackable,
    required this.activeSessionId,
    required this.activeSessionCode,
    required this.activeSessionTitle,
    required this.scrollController,
    required this.lastFocusedItemIndex,
    required this.onSaveChanges,
    required this.onNewBlankSession,
    required this.onShipmentModeChanged,
    required this.onStackableChanged,
    required this.onCompareContainers,
    required this.onVisualLoadPlan,
    required this.onAddPackageLine,
    required this.onSaveCalculation,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.onCopyPackagesTsv,
    required this.onCopyStudyReport,
    required this.onItemUpdated,
    required this.onCloneItem,
    required this.onDeleteItem,
  });

  @override
  State<CbmQuickCalculatorTab> createState() => _CbmQuickCalculatorTabState();
}

class _CbmQuickCalculatorTabState extends State<CbmQuickCalculatorTab> {
  AirFreightDivisorMode _airDivisorMode = AirFreightDivisorMode.generalAir;

  @override
  Widget build(BuildContext context) {
    double totalCbm = 0.0;
    double totalGrossWt = 0.0;

    for (var item in widget.quickItems) {
      final lM = item.lengthM;
      final wM = item.widthM;
      final hM = item.heightM;
      totalCbm += item.quantity * lM * wM * hM;
      totalGrossWt += item.quantity * item.grossWeightPerUnitKg;
    }

    final dualRec = ContainerRequirementEngine.calculateBoth(
      totalCbm: totalCbm,
      totalWeightKg: totalGrossWt,
    );

    final isAirOrCourier = widget.quickShipmentMode == 'air' ||
        widget.quickShipmentMode == 'express' ||
        widget.quickShipmentMode == 'courier';

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
          if (widget.quickItems.isNotEmpty) {
            final targetIdx = (widget.lastFocusedItemIndex >= 0 && widget.lastFocusedItemIndex < widget.quickItems.length)
                ? widget.lastFocusedItemIndex
                : widget.quickItems.length - 1;
            widget.onCloneItem(targetIdx);
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyD, meta: true): () {
          if (widget.quickItems.isNotEmpty) {
            final targetIdx = (widget.lastFocusedItemIndex >= 0 && widget.lastFocusedItemIndex < widget.quickItems.length)
                ? widget.lastFocusedItemIndex
                : widget.quickItems.length - 1;
            widget.onCloneItem(targetIdx);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scrollbar(
          controller: widget.scrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Active Editing Session Banner
                if (widget.activeSessionId != null && widget.activeSessionCode != null) ...[
                  CbmActiveSessionBanner(
                    activeSessionCode: widget.activeSessionCode!,
                    activeSessionTitle: widget.activeSessionTitle,
                    onSaveChanges: widget.onSaveChanges,
                    onNewBlankSession: widget.onNewBlankSession,
                  ),
                ],

                // Live Results Summary Cards Header
                CbmResultsSummaryHeader(
                  items: widget.quickItems,
                  shipmentMode: widget.quickShipmentMode,
                  isStackable: widget.isStackable,
                ),
                const SizedBox(height: 12),

                // Air Freight vs Express Courier Volumetric Assessment
                if (isAirOrCourier) ...[
                  DualDivisorSelectorCard(
                    selectedMode: _airDivisorMode,
                    onModeChanged: (mode) => setState(() => _airDivisorMode = mode),
                    showDensityExplanation: true,
                  ),
                  const SizedBox(height: 12),
                  VolumetricWeightComparisonTile(
                    actualGrossWeightKg: totalGrossWt,
                    totalCbm: totalCbm,
                    activeMode: _airDivisorMode,
                  ),
                  const SizedBox(height: 12),
                ],

                // Smart Mode & Cargo Stacking Skill Banner
                CbmStackingBanner(
                  isStackable: widget.isStackable,
                  onStackableChanged: widget.onStackableChanged,
                  onCompareContainers: widget.onCompareContainers,
                  onVisualLoadPlan: widget.onVisualLoadPlan,
                  dualRec: dualRec,
                ),
                const SizedBox(height: 12),

                // Dynamic Line Items Table
                CbmItemsTable(
                  items: widget.quickItems,
                  shipmentMode: widget.quickShipmentMode,
                  activeSessionId: widget.activeSessionId,
                  onShipmentModeChanged: widget.onShipmentModeChanged,
                  onAddPackageLine: widget.onAddPackageLine,
                  onSaveCalculation: widget.onSaveCalculation,
                  onExportExcel: widget.onExportExcel,
                  onExportPdf: widget.onExportPdf,
                  onCopyPackagesTsv: widget.onCopyPackagesTsv,
                  onCopyStudyReport: widget.onCopyStudyReport,
                  onItemUpdated: widget.onItemUpdated,
                  onCloneItem: widget.onCloneItem,
                  onDeleteItem: widget.onDeleteItem,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
