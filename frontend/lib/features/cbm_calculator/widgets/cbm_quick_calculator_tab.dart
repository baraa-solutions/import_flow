import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/container_requirement_engine.dart';
import '../models/cbm_calculator_model.dart';
import 'cbm_active_session_banner.dart';
import 'cbm_items_table.dart';
import 'cbm_results_summary_header.dart';
import 'cbm_stacking_banner.dart';

class CbmQuickCalculatorTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    double totalCbm = 0.0;
    double totalGrossWt = 0.0;

    for (var item in quickItems) {
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

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
          if (quickItems.isNotEmpty) {
            final targetIdx = (lastFocusedItemIndex >= 0 && lastFocusedItemIndex < quickItems.length)
                ? lastFocusedItemIndex
                : quickItems.length - 1;
            onCloneItem(targetIdx);
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyD, meta: true): () {
          if (quickItems.isNotEmpty) {
            final targetIdx = (lastFocusedItemIndex >= 0 && lastFocusedItemIndex < quickItems.length)
                ? lastFocusedItemIndex
                : quickItems.length - 1;
            onCloneItem(targetIdx);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Active Editing Session Banner
                if (activeSessionId != null && activeSessionCode != null) ...[
                  CbmActiveSessionBanner(
                    activeSessionCode: activeSessionCode!,
                    activeSessionTitle: activeSessionTitle,
                    onSaveChanges: onSaveChanges,
                    onNewBlankSession: onNewBlankSession,
                  ),
                ],

                // Live Results Summary Cards Header
                CbmResultsSummaryHeader(
                  items: quickItems,
                  shipmentMode: quickShipmentMode,
                  isStackable: isStackable,
                ),
                const SizedBox(height: 12),

                // Smart Mode & Cargo Stacking Skill Banner
                CbmStackingBanner(
                  isStackable: isStackable,
                  onStackableChanged: onStackableChanged,
                  onCompareContainers: onCompareContainers,
                  onVisualLoadPlan: onVisualLoadPlan,
                  dualRec: dualRec,
                ),
                const SizedBox(height: 12),

                // Dynamic Line Items Table
                CbmItemsTable(
                  items: quickItems,
                  shipmentMode: quickShipmentMode,
                  activeSessionId: activeSessionId,
                  onShipmentModeChanged: onShipmentModeChanged,
                  onAddPackageLine: onAddPackageLine,
                  onSaveCalculation: onSaveCalculation,
                  onExportExcel: onExportExcel,
                  onExportPdf: onExportPdf,
                  onCopyPackagesTsv: onCopyPackagesTsv,
                  onCopyStudyReport: onCopyStudyReport,
                  onItemUpdated: onItemUpdated,
                  onCloneItem: onCloneItem,
                  onDeleteItem: onDeleteItem,
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
