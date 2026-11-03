import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/localization/stored_text.dart';
import '../../../core/performance/dispose_tracker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/widgets/widgets.dart';
import '../../container_loader/widgets/container_loader_tab.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../projects/providers/projects_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/cbm_calculator_model.dart';
import '../providers/cbm_calculator_provider.dart';
import '../utils/cbm_export_helper.dart';
import '../widgets/cbm_quick_calculator_tab.dart';
import '../widgets/cbm_screen_header.dart';
import '../widgets/container_comparison_dialog.dart';
import '../widgets/save_cbm_calc_dialog.dart';
import '../widgets/saved_cbm_registry_tab.dart';

class CBMCalculatorScreen extends ConsumerStatefulWidget {
  const CBMCalculatorScreen({super.key});

  @override
  ConsumerState<CBMCalculatorScreen> createState() => _CBMCalculatorScreenState();
}

class _CBMCalculatorScreenState extends ConsumerState<CBMCalculatorScreen>
    with SingleTickerProviderStateMixin, DisposeTrackerMixin<CBMCalculatorScreen> {
  late TabController _tabController;

  // Active Editing Session State
  int? _activeSessionId;
  String? _activeSessionCode;
  String? _activeSessionTitle;
  String? _activeSessionNotes;
  int? _activeSessionImportFileId;

  // Quick Calculator State
  String _quickShipmentMode = 'air';
  bool _isStackable = true;
  final List<CBMItemModel> _quickItems = [
    CBMItemModel(
      packageType: 'Carton',
      quantity: 10,
      length: 100,
      width: 50,
      height: 40,
      unit: 'cm',
      grossWeightPerUnitKg: 15,
      isStackable: true,
    ),
  ];

  final ScrollController _quickTabScrollController = ScrollController();
  int _lastFocusedItemIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() {
      if (!ref.read(cbmCalculatorProvider).isLoading) {
        ref.read(cbmCalculatorProvider.notifier).fetchCalculations();
      }
      if (!ref.read(projectsProvider).isLoading) {
        ref.read(projectsProvider.notifier).fetchProjects();
      }
      if (!ref.read(purchaseOrdersProvider).isLoading) {
        ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      }
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quickTabScrollController.dispose();
    super.dispose();
  }

  void _cloneQuickItem(int idx) {
    if (idx < 0 || idx >= _quickItems.length) return;
    final src = _quickItems[idx];
    final cloned = CBMItemModel(
      packageType: src.packageType,
      quantity: src.quantity,
      length: src.length,
      width: src.width,
      height: src.height,
      unit: src.unit,
      grossWeightPerUnitKg: src.grossWeightPerUnitKg,
      isStackable: src.isStackable,
    );
    setState(() {
      _quickItems.insert(idx + 1, cloned);
      _lastFocusedItemIndex = idx + 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        context.l10n.cargoItemClonedSuccess,
        severity: AppSeverity.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearActiveSession() {
    setState(() {
      _activeSessionId = null;
      _activeSessionCode = null;
      _activeSessionTitle = null;
      _activeSessionNotes = null;
      _activeSessionImportFileId = null;
      _quickItems.clear();
      _quickItems.add(
        CBMItemModel(
          packageType: 'Carton',
          quantity: 10,
          length: 100,
          width: 50,
          height: 40,
          unit: 'cm',
          grossWeightPerUnitKg: 15,
          isStackable: true,
        ),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, context.l10n.newBlankSession, severity: AppSeverity.info),
    );
  }

  void _loadSessionForEditing(CBMCalculationModel calc) {
    setState(() {
      _activeSessionId = calc.calcId;
      _activeSessionCode = calc.calcCode;
      _activeSessionTitle = calc.title;
      _activeSessionNotes = calc.notes;
      _activeSessionImportFileId = calc.importFileId;
      _isStackable = calc.isStackable;
      _quickShipmentMode = calc.shipmentMode == 'AIR' || calc.shipmentMode == 'SEA'
          ? calc.shipmentMode!.toLowerCase()
          : (DomainEnums.legacyToCode(DomainEnumType.shippingMethod, calc.recommendedShippingMethod) == 'AIR'
              ? 'air'
              : 'sea');

      _quickItems.clear();
      if (calc.items.isNotEmpty) {
        _quickItems.addAll(calc.items.map((i) => CBMItemModel(
              itemId: i.itemId,
              calcId: i.calcId,
              packageType: i.packageType.isNotEmpty ? i.packageType : 'Carton',
              quantity: i.quantity > 0 ? i.quantity : 1,
              length: i.length > 0 ? i.length : (i.lengthCm > 0 ? i.lengthCm : 100.0),
              width: i.width > 0 ? i.width : (i.widthCm > 0 ? i.widthCm : 80.0),
              height: i.height > 0 ? i.height : (i.heightCm > 0 ? i.heightCm : 60.0),
              unit: (i.unit.isNotEmpty) ? i.unit : 'cm',
              grossWeightPerUnitKg: i.grossWeightPerUnitKg,
              isStackable: i.isStackable,
            )));
      } else {
        _quickItems.add(
          CBMItemModel(
            packageType: 'Carton',
            quantity: 1,
            length: 100,
            width: 80,
            height: 60,
            unit: 'cm',
            grossWeightPerUnitKg: 20,
            isStackable: _isStackable,
          ),
        );
      }
    });
    _tabController.animateTo(0);
  }

  Future<void> _updateActiveSessionDirectly() async {
    if (_activeSessionId == null) return;
    final l = context.l10n;
    final payload = {
      'title': _activeSessionTitle ?? storedText.calculationSessionTitle,
      'import_file_id': _activeSessionImportFileId,
      'notes': _activeSessionNotes,
      'is_stackable': _isStackable,
      'shipment_mode': _quickShipmentMode.toUpperCase(),
      'items': _quickItems.map((i) => i.toCreateJson()).toList(),
    };
    final ok = await ref.read(cbmCalculatorProvider.notifier).updateCalculation(_activeSessionId!, payload);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, '${l.saveChangesInSession} [$_activeSessionCode]', severity: AppSeverity.success),
      );
      ref.read(cbmCalculatorProvider.notifier).fetchCalculations();
    } else {
      final err = ref.read(cbmCalculatorProvider).errorText(l);
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, err, severity: AppSeverity.danger));
    }
  }

  void _showSaveCalcDialog(BuildContext context) {
    SaveCbmCalcDialog.show(
      context,
      items: _quickItems,
      isStackable: _isStackable,
      quickShipmentMode: _quickShipmentMode,
      activeSessionId: _activeSessionId,
      activeSessionCode: _activeSessionCode,
      activeSessionTitle: _activeSessionTitle,
      activeSessionNotes: _activeSessionNotes,
      activeSessionImportFileId: _activeSessionImportFileId,
      onClearActiveSession: _clearActiveSession,
      onSavedSuccess: () => _tabController.animateTo(1),
    );
  }

  void _showContainerComparisonDialog(BuildContext context) {
    double totalCbm = 0.0, totalGrossWt = 0.0;
    for (var item in _quickItems) {
      totalCbm += item.quantity * item.lengthM * item.widthM * item.heightM;
      totalGrossWt += item.quantity * item.grossWeightPerUnitKg;
    }
    final dualRec = ContainerRequirementEngine.calculateBoth(totalCbm: totalCbm, totalWeightKg: totalGrossWt);
    ContainerComparisonDialog.show(context, dualRec: dualRec, totalCbm: totalCbm, totalWeightKg: totalGrossWt);
  }

  void _showVisualLoadPlanDialog(BuildContext context) {
    CargoLoadPlannerDialog.showFromCbmItems(context, items: _quickItems);
  }

  void _addDefaultPackageLine() {
    setState(() {
      _quickItems.add(
        CBMItemModel(
          packageType: 'Carton',
          quantity: 1,
          length: 100,
          width: 80,
          height: 60,
          unit: 'cm',
          grossWeightPerUnitKg: 20,
          isStackable: _isStackable,
        ),
      );
    });
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : AppTheme.charcoalSurface,
      body: SelectionArea(
        child: Column(
          children: [
            CbmScreenHeader(tabController: _tabController),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  CbmQuickCalculatorTab(
                    quickItems: _quickItems,
                    quickShipmentMode: _quickShipmentMode,
                    isStackable: _isStackable,
                    activeSessionId: _activeSessionId,
                    activeSessionCode: _activeSessionCode,
                    activeSessionTitle: _activeSessionTitle,
                    scrollController: _quickTabScrollController,
                    lastFocusedItemIndex: _lastFocusedItemIndex,
                    onSaveChanges: _updateActiveSessionDirectly,
                    onNewBlankSession: _clearActiveSession,
                    onShipmentModeChanged: (mode) => setState(() => _quickShipmentMode = mode),
                    onStackableChanged: (stackable) => setState(() => _isStackable = stackable),
                    onCompareContainers: () => _showContainerComparisonDialog(context),
                    onVisualLoadPlan: () => _showVisualLoadPlanDialog(context),
                    onAddPackageLine: _addDefaultPackageLine,
                    onSaveCalculation: () => _showSaveCalcDialog(context),
                    onExportExcel: () => CbmExportHelper.exportQuickItemsToExcel(
                      context,
                      items: _quickItems,
                      shipmentMode: _quickShipmentMode,
                      activeSessionCode: _activeSessionCode,
                    ),
                    onExportPdf: () => CbmExportHelper.exportQuickItemsToPdf(
                      context,
                      items: _quickItems,
                      shipmentMode: _quickShipmentMode,
                      activeSessionCode: _activeSessionCode,
                      activeSessionTitle: _activeSessionTitle,
                    ),
                    onCopyPackagesTsv: () => CbmExportHelper.copyQuickItemsAsTsv(
                      context,
                      items: _quickItems,
                      shipmentMode: _quickShipmentMode,
                    ),
                    onCopyStudyReport: () => CbmExportHelper.copyTechnicalFreightSummary(
                      context,
                      items: _quickItems,
                      isStackable: _isStackable,
                    ),
                    onItemUpdated: (idx, updated) => setState(() => _quickItems[idx] = updated),
                    onCloneItem: _cloneQuickItem,
                    onDeleteItem: (idx) => setState(() => _quickItems.removeAt(idx)),
                  ),
                  SavedCbmRegistryTab(
                    onLoadSession: _loadSessionForEditing,
                    onSwitchToCalculator: () => _tabController.animateTo(0),
                  ),
                  const ContainerLoaderTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
