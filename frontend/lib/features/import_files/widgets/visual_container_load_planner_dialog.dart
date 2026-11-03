// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/utils/import_file_po_linker.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../purchase_orders/models/purchase_order_model.dart';
import '../models/import_file_model.dart';
import 'load_planner/load_planner_3d_viewport.dart';
import 'load_planner/load_planner_actions_bar.dart';
import 'load_planner/load_planner_export_helper.dart';
import 'load_planner/load_planner_header.dart';
import 'load_planner/load_planner_manifest_table.dart';
import 'load_planner/load_planner_stats_bar.dart';

/// 🚢 Modular Dialog Coordinator for Visual Container Load Planner & Simulation.
///
/// Refactored into clean dedicated sub-components (< 350 lines Coordinator):
/// - Header & Export Actions Strip: [LoadPlannerHeader]
/// - Stacking Scenario Switcher: [LoadPlannerActionsBar]
/// - Summary Metrics Strip: [LoadPlannerStatsBar]
/// - Packing List Summary Table: [LoadPlannerManifestTable]
/// - 3D Container Visual Renderings: [LoadPlanner3dViewport]
/// - Export & Clipboard Services: [LoadPlannerExportHelper]
class VisualContainerLoadPlannerDialog extends StatefulWidget {
  final ImportFileModel file;
  final List<PurchaseOrderModel> linkedPOs;
  final double? fallbackCbm;
  final double? fallbackWeight;

  const VisualContainerLoadPlannerDialog({
    super.key,
    required this.file,
    required this.linkedPOs,
    this.fallbackCbm,
    this.fallbackWeight,
  });

  @override
  State<VisualContainerLoadPlannerDialog> createState() =>
      _VisualContainerLoadPlannerDialogState();
}

class _VisualContainerLoadPlannerDialogState
    extends State<VisualContainerLoadPlannerDialog> {
  final GlobalKey _containerVisualKey = GlobalKey();
  final ScrollController _tableScrollController = ScrollController();

  // Active Stacking Mode: null = Mixed Stacking, true = All Stackable, false = All Non-Stackable
  bool? _activeStackingMode;

  // Export Loading States
  bool _isExportingImage = false;
  bool _isExportingExcel = false;
  bool _isExportingPdf = false;

  late List<CargoItem> _baseCargoItems;

  @override
  void initState() {
    super.initState();
    _baseCargoItems = ImportFilePoLinker.buildCargoItems(
      pos: widget.linkedPOs,
      file: widget.file,
      fallbackCbm: widget.fallbackCbm ?? 0.0,
      fallbackWeight: widget.fallbackWeight ?? 0.0,
    );
    _activeStackingMode =
        _baseCargoItems.any((i) => !i.isStackable) ? null : true;
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  void _handleCopyTable(AppLocalizations l, List<ContainerPackingResult> plan) {
    LoadPlannerExportHelper.copyTableTsv(
      context: context,
      l: l,
      plan: plan,
    );
  }

  Future<void> _handleSaveImage(AppLocalizations l) async {
    if (_isExportingImage) return;
    setState(() => _isExportingImage = true);

    try {
      await LoadPlannerExportHelper.saveImage(
        context: context,
        visualKey: _containerVisualKey,
        file: widget.file,
        activeStackingMode: _activeStackingMode,
        l: l,
      );
    } finally {
      if (mounted) setState(() => _isExportingImage = false);
    }
  }

  Future<void> _handleExportExcel({
    required AppLocalizations l,
    required List<ContainerPackingResult> plan,
    required double totalPlanWeight,
    required double totalPlanVolume,
    required int totalPkgs,
    required int stackableInActive,
    required int nonStackableInActive,
    required String fleetSummaryText,
  }) async {
    if (_isExportingExcel) return;
    setState(() => _isExportingExcel = true);

    try {
      await LoadPlannerExportHelper.exportExcel(
        context: context,
        file: widget.file,
        activeStackingMode: _activeStackingMode,
        plan: plan,
        totalPlanWeight: totalPlanWeight,
        totalPlanVolume: totalPlanVolume,
        totalPkgs: totalPkgs,
        stackableInActive: stackableInActive,
        nonStackableInActive: nonStackableInActive,
        fleetSummaryText: fleetSummaryText,
        l: l,
      );
    } finally {
      if (mounted) setState(() => _isExportingExcel = false);
    }
  }

  Future<void> _handleExportPdf({
    required AppLocalizations l,
    required List<ContainerPackingResult> plan,
    required double totalPlanWeight,
    required double totalPlanVolume,
    required int totalPkgs,
    required String fleetSummaryText,
  }) async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);

    try {
      await LoadPlannerExportHelper.exportPdf(
        context: context,
        visualKey: _containerVisualKey,
        file: widget.file,
        activeStackingMode: _activeStackingMode,
        plan: plan,
        totalPlanWeight: totalPlanWeight,
        totalPlanVolume: totalPlanVolume,
        totalPkgs: totalPkgs,
        fleetSummaryText: fleetSummaryText,
        l: l,
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final screenSize = MediaQuery.of(context).size;
    final double screenW = screenSize.width;
    final double screenH = screenSize.height;

    // STEP 1 — Responsive sizing on Desktop, Tablet & Mobile
    final double dialogWidth;
    final double dialogHeight;

    if (screenW >= AppTheme.desktopBreakpoint) {
      dialogWidth = (screenW * 0.95).clamp(1150.0, 1480.0);
      dialogHeight = (screenH * 0.90).clamp(720.0, 940.0);
    } else if (screenW >= AppTheme.tabletBreakpoint) {
      dialogWidth = (screenW * 0.95).clamp(740.0, 1150.0);
      dialogHeight = (screenH * 0.90).clamp(620.0, 880.0);
    } else {
      dialogWidth = screenW * 0.96;
      dialogHeight = (screenH * 0.92).clamp(500.0, 800.0);
    }

    // Compute plan dynamically based on active stacking scenario
    final plan = ContainerRequirementEngine.planShipment(
      _baseCargoItems,
      forceStackable: _activeStackingMode,
    );

    // Metrics for active plan
    final totalPkgs = _baseCargoItems.length;
    final stackableInActive = _activeStackingMode == true
        ? totalPkgs
        : (_activeStackingMode == false
            ? 0
            : _baseCargoItems.where((c) => c.isStackable).length);
    final nonStackableInActive = totalPkgs - stackableInActive;

    final totalPlanWeight = plan.fold(0.0, (s, p) => s + p.totalWeight);
    final totalPlanVolume = plan.fold(0.0, (s, p) => s + p.totalVolume);

    // Fleet Summary
    final Map<String, int> containerCounts = {};
    for (final p in plan) {
      if (p.containerCode != 'FAILED') {
        containerCounts[p.containerCode] =
            (containerCounts[p.containerCode] ?? 0) + 1;
      }
    }
    final fleetSummaryText = containerCounts.entries
        .map((e) => '${e.value} x ${e.key}')
        .join(' + ');

    return SelectionArea(
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        actionsPadding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 14),
        title: LoadPlannerHeader(
          file: widget.file,
          fleetSummaryText: fleetSummaryText,
          planLength: plan.length,
          isExportingImage: _isExportingImage,
          isExportingExcel: _isExportingExcel,
          isExportingPdf: _isExportingPdf,
          onCopyTable: () => _handleCopyTable(l, plan),
          onSaveImage: () => _handleSaveImage(l),
          onExportExcel: () => _handleExportExcel(
            l: l,
            plan: plan,
            totalPlanWeight: totalPlanWeight,
            totalPlanVolume: totalPlanVolume,
            totalPkgs: totalPkgs,
            stackableInActive: stackableInActive,
            nonStackableInActive: nonStackableInActive,
            fleetSummaryText: fleetSummaryText,
          ),
          onExportPdf: () => _handleExportPdf(
            l: l,
            plan: plan,
            totalPlanWeight: totalPlanWeight,
            totalPlanVolume: totalPlanVolume,
            totalPkgs: totalPkgs,
            fleetSummaryText: fleetSummaryText,
          ),
        ),
        content: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
            children: [
              // 1. Stacking Scenario Buttons Strip
              LoadPlannerActionsBar(
                activeStackingMode: _activeStackingMode,
                onScenarioChanged: (mode) {
                  setState(() => _activeStackingMode = mode);
                },
              ),
              const SizedBox(height: 8),

              // 2. Summary Metrics Strip
              LoadPlannerStatsBar(
                totalPkgs: totalPkgs,
                totalPlanWeight: totalPlanWeight,
                totalPlanVolume: totalPlanVolume,
                stackableInActive: stackableInActive,
                nonStackableInActive: nonStackableInActive,
              ),
              const SizedBox(height: 8),

              // 3. Packing List Summary Table
              LoadPlannerManifestTable(
                plan: plan,
                tableScrollController: _tableScrollController,
              ),
              const SizedBox(height: 10),

              // 4. Main Container Visual Renderings
              Expanded(
                child: LoadPlanner3dViewport(
                  plan: plan,
                  visualKey: _containerVisualKey,
                ),
              ),
            ],
          ),
        ),
        actions: [
          AppButton(
            key: const Key('closePlannerDialogBtn'),
            label: l.closePlannerBtn,
            icon: Icons.close,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
