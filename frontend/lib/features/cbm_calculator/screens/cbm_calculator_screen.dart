import '../../../core/performance/dispose_tracker.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../projects/models/project_model.dart';
import '../../purchase_orders/models/purchase_order_model.dart';
import '../widgets/saved_cbm_registry_tab.dart';
import '../widgets/container_comparison_dialog.dart';
import '../widgets/save_cbm_calc_dialog.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/container_requirement_engine.dart';

import '../../import_files/providers/import_files_provider.dart';
import '../../projects/providers/projects_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/cbm_calculator_model.dart';
import '../providers/cbm_calculator_provider.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/localization/stored_text.dart';
import '../../container_loader/widgets/container_loader_tab.dart';

class CBMCalculatorScreen extends ConsumerStatefulWidget {
  const CBMCalculatorScreen({super.key});

  @override
  ConsumerState<CBMCalculatorScreen> createState() => _CBMCalculatorScreenState();
}

class _CBMCalculatorScreenState extends ConsumerState<CBMCalculatorScreen> with SingleTickerProviderStateMixin, DisposeTrackerMixin<CBMCalculatorScreen> {
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

  void _onPackageTypeSelected(int idx, String? v) {
    if (v == null || idx < 0 || idx >= _quickItems.length) return;
    final item = _quickItems[idx];
    double newLen = item.length;
    double newWid = item.width;
    String newUnit = item.unit;
    if (v == 'Euro Pallet (120x80)') {
      newLen = kEuroPalletLengthCm;
      newWid = kEuroPalletWidthCm;
      newUnit = 'cm';
    } else if (v == 'Standard Pallet (120x100)') {
      newLen = kStandardPalletLengthCm;
      newWid = kStandardPalletWidthCm;
      newUnit = 'cm';
    }
    setState(() {
      _quickItems[idx] = CBMItemModel(
        packageType: v,
        quantity: item.quantity,
        length: newLen,
        width: newWid,
        height: item.height,
        unit: newUnit,
        grossWeightPerUnitKg: item.grossWeightPerUnitKg,
        isStackable: item.isStackable,
      );
    });
  }

  /*
      newLen = kStandardPalletLengthCm;
      newWid = kStandardPalletWidthCm;
      newUnit = 'cm';
    }
    setState(() {
      _quickItems[idx] = CBMItemModel(
        packageType: v,
        quantity: item.quantity,
        length: newLen,
        width: newWid,
        height: item.height,
        unit: newUnit,
        grossWeightPerUnitKg: item.grossWeightPerUnitKg,
        isStackable: item.isStackable,
      );
    });
        backgroundColor: AppTheme.emerald,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  */
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
      AppTheme.snackBar(
        context,
        context.l10n.newBlankSession,
        severity: AppSeverity.info,
      ),
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
      // The stored mode wins; legacy rows (null) fall back to the recommendation.
      _quickShipmentMode = calc.shipmentMode == 'AIR' || calc.shipmentMode == 'SEA'
          ? calc.shipmentMode!.toLowerCase()
          : (DomainEnums.legacyToCode(DomainEnumType.shippingMethod, calc.recommendedShippingMethod) == 'AIR' ? 'air' : 'sea');

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
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          '${l.saveChangesInSession} [$_activeSessionCode]',
          severity: AppSeverity.success,
        ),
      );
      ref.read(cbmCalculatorProvider.notifier).fetchCalculations();
    } else if (mounted) {
      final err = ref.read(cbmCalculatorProvider).errorText(l);
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          err,
          severity: AppSeverity.danger,
        ),
      );
    }
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(cbmCalculatorProvider);
    final projectsList = ref.watch(projectsProvider).valueOrNull ?? [];
    final poList = ref.watch(purchaseOrdersProvider).purchaseOrders;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : AppTheme.charcoalSurface,
      body: SelectionArea(
        child: Column(
          children: [
          // Header Banner (Responsive LayoutBuilder)
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 1600;
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 16 : 24,
                  vertical: isCompact ? 12 : 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [AppTheme.darkScaffoldBackground, AppTheme.cobaltMedium]
                        : [AppTheme.charcoal, AppTheme.cobalt],
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                  ),
                ),
                child: isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calculate_outlined, color: AppTheme.white, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.cbmCalculatorTitle,
                                      style: const TextStyle(color: AppTheme.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      l.cbmCalculatorSubtitle,
                                      style: const TextStyle(color: AppTheme.cloudWhite, fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const BackToDashboardButton(),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            indicatorColor: AppTheme.orange,
                            indicatorWeight: 3,
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            unselectedLabelColor: Colors.white70,
                            labelColor: AppTheme.orange,
                            tabs: [
                              Tab(icon: const Icon(Icons.speed), text: l.quickOperationalCalculatorTab),
                              Tab(icon: const Icon(Icons.history), text: l.savedCalculationsRegistryTab),
                              Tab(icon: const Icon(Icons.view_in_ar_rounded), text: context.l10n.isArabic ? 'محاكي تحميل الحاويات 3D' : 'Container 3D Loader'),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          const Icon(Icons.calculate_outlined, color: AppTheme.white, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.cbmCalculatorTitle,
                                  style: const TextStyle(color: AppTheme.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  l.cbmCalculatorSubtitle,
                                  style: const TextStyle(color: AppTheme.cloudWhite, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const BackToDashboardButton(),
                          const SizedBox(width: 10),
                          Flexible(
                            child: TabBar(
                              controller: _tabController,
                              isScrollable: true,
                              indicatorColor: AppTheme.orange,
                              indicatorWeight: 3,
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              unselectedLabelColor: Colors.white70,
                              labelColor: AppTheme.orange,
                              tabs: [
                                Tab(icon: const Icon(Icons.speed), text: l.quickOperationalCalculatorTab),
                                Tab(icon: const Icon(Icons.history), text: l.savedCalculationsRegistryTab),
                                Tab(icon: const Icon(Icons.view_in_ar_rounded), text: context.l10n.isArabic ? 'محاكي تحميل الحاويات 3D' : 'Container 3D Loader'),
                              ],
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),


          // Main View Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Interactive Standalone Calculator
                _buildQuickCalculatorTab(context),

                // Tab 2: Saved History Registry
                _buildSavedRegistryTab(context, state, projectsList, poList),

                // Tab 3: Container Loader 3D/2D Simulator
                const ContainerLoaderTab(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: QUICK OPERATIONAL CALCULATOR
  // ---------------------------------------------------------------------------
  Widget _buildQuickCalculatorTab(BuildContext context) {
    final l = context.l10n;
    // Compute local totals
    double totalCbm = 0.0;
    double totalGrossWt = 0.0;
    double totalVolumetricWt = 0.0;
    double totalFloorAreaM2 = 0.0;

    for (var item in _quickItems) {
      final lM = item.lengthM;
      final wM = item.widthM;
      final hM = item.heightM;
      final cbm = item.quantity * lM * wM * hM;
      final volWt = item.quantity * lM * wM * hM * kAirVolumetricKgPerCbm;
      final gross = item.quantity * item.grossWeightPerUnitKg;
      final floor = item.quantity * lM * wM;
      totalFloorAreaM2 += floor;

      totalCbm += cbm;
      totalVolumetricWt += volWt;
      totalGrossWt += gross;
    }

    final chargeableWt = totalGrossWt > totalVolumetricWt ? totalGrossWt : totalVolumetricWt;
    final totalLdm = ContainerRequirementEngine.calculateLdm(floorAreaM2: totalFloorAreaM2);
    final totalChargeableCbm = ContainerRequirementEngine.calculateLclChargeableCbm(
      physicalCbm: totalCbm,
      floorAreaM2: totalFloorAreaM2,
      isStackable: _isStackable,
    );
    final totalRevenueTon = ContainerRequirementEngine.calculateOceanRevenueTon(
      chargeableCbm: totalChargeableCbm,
      totalGrossWeightKg: totalGrossWt,
    );

    final dualRec = ContainerRequirementEngine.calculateBoth(totalCbm: totalCbm, totalWeightKg: totalGrossWt);
    final containerRec = _isStackable ? dualRec.stackableResult : dualRec.nonStackableResult;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final modeRec = dualRec.modeRecommendation;
    String recMethod = isArabic ? modeRec.recommendedModeAr : modeRec.recommendedMode;
    String recContainer = isArabic ? modeRec.reasonAr : modeRec.reasonEn;
    if (totalCbm >= 15.0) {
      recContainer = isArabic ? containerRec.recommendationSummary : containerRec.recommendationSummaryEn;
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
          if (_quickItems.isNotEmpty) {
            final targetIdx = (_lastFocusedItemIndex >= 0 && _lastFocusedItemIndex < _quickItems.length)
                ? _lastFocusedItemIndex
                : _quickItems.length - 1;
            _cloneQuickItem(targetIdx);
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyD, meta: true): () {
          if (_quickItems.isNotEmpty) {
            final targetIdx = (_lastFocusedItemIndex >= 0 && _lastFocusedItemIndex < _quickItems.length)
                ? _lastFocusedItemIndex
                : _quickItems.length - 1;
            _cloneQuickItem(targetIdx);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scrollbar(
          controller: _quickTabScrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _quickTabScrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Active Editing Session Banner (If editing a saved calculation)
                if (_activeSessionId != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkElevatedSurface : AppTheme.orangeLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.wcagOrange, width: 1.5),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_note, color: AppTheme.wcagOrange, size: 24),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${l.activeEditSessionBanner}: [$_activeSessionCode] - ${_activeSessionTitle ?? ""}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.wcagOrange),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l.activeEditSessionHint,
                                  style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.wcagOrange),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppButton(
                              label: '${l.saveChangesInSession} [$_activeSessionCode]',
                              icon: Icons.check,
                              variant: AppButtonVariant.success,
                              size: AppButtonSize.small,
                              onPressed: _updateActiveSessionDirectly,
                            ),
                            const SizedBox(width: 8),
                            AppButton(
                              label: l.newBlankSession,
                              icon: Icons.add,
                              variant: AppButtonVariant.secondary,
                              size: AppButtonSize.small,
                              onPressed: _clearActiveSession,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Live Results Summary Cards Header (Responsive LayoutBuilder)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cards = [
                      _buildResultCardItem(
                        l.totalCbmVolumeMetric,
                        '${totalCbm.toStringAsFixed(4)} m³',
                        Icons.view_in_ar,
                        AppTheme.orange,
                        subtitle: '${isArabic ? "المساحة الأرضية" : "Floor Area"}: ${totalFloorAreaM2.toStringAsFixed(2)} m²',
                      ),
                      if (_quickShipmentMode == 'sea') ...[
                        _buildResultCardItem(
                          isArabic ? 'طن الإيراد (Revenue Ton)' : 'Revenue Ton (W/M)',
                          '${totalRevenueTon.toStringAsFixed(3)} RT',
                          Icons.waves,
                          AppTheme.cobalt,
                          subtitle: totalRevenueTon > totalChargeableCbm
                              ? (isArabic ? 'محاسبة بالوزن الفعلي' : 'Billed by gross weight')
                              : (isArabic ? 'محاسبة بالحجم التكعيبي' : 'Billed by volume'),
                        ),
                        if (!_isStackable && totalChargeableCbm > totalCbm)
                          _buildResultCardItem(
                            isArabic ? 'الحجم المحاسبي (فراغ ضائع)' : 'Billed CBM (Loss of Height)',
                            '${totalChargeableCbm.toStringAsFixed(3)} m³',
                            Icons.vertical_align_top,
                            AppTheme.wcagOrange,
                            subtitle: '+${(totalChargeableCbm - totalCbm).toStringAsFixed(3)} m³ ${isArabic ? "فراغ رأسي محتسب" : "lost height penalty"}',
                          ),
                        _buildResultCardItem(l.grossWeightMetric, '${totalGrossWt.toStringAsFixed(1)} KG', Icons.scale, AppTheme.emerald,
                            subtitle: '${(totalGrossWt / 1000.0).toStringAsFixed(3)} ${isArabic ? "طن متري" : "Metric Ton"}'),
                      ] else if (_quickShipmentMode == 'road') ...[
                        _buildResultCardItem(
                          isArabic ? 'أمتار التحميل (LDM)' : 'Loading Meters (LDM)',
                          '${totalLdm.toStringAsFixed(2)} LDM',
                          Icons.local_shipping,
                          AppTheme.emerald,
                          subtitle: '${(totalLdm / kStandardTrailerMaxLdm * 100).toStringAsFixed(1)}% ${isArabic ? "من تريلا 13.6م" : "of 13.6m trailer"}',
                        ),
                        _buildResultCardItem(
                          isArabic ? 'المساحة الأرضية' : 'Floor Footprint',
                          '${totalFloorAreaM2.toStringAsFixed(2)} m²',
                          Icons.square_foot,
                          AppTheme.cobalt,
                          subtitle: isArabic ? 'عرض التريلا القياسي 2.40م' : 'Based on 2.40m trailer width',
                        ),
                        _buildResultCardItem(l.grossWeightMetric, '${totalGrossWt.toStringAsFixed(1)} KG', Icons.scale, AppTheme.orange),
                      ],
                      if (_quickShipmentMode == 'air') ...[
                        _buildResultCardItem(l.airChargeableWtMetric, '${chargeableWt.toStringAsFixed(2)} KG', Icons.airplanemode_active, AppTheme.cobalt,
                            subtitle: '${l.volumetricWeight}: ${totalVolumetricWt.toStringAsFixed(2)} kg'),
                        _buildResultCardItem(l.grossWeightMetric, '${totalGrossWt.toStringAsFixed(2)} KG', Icons.scale, AppTheme.emerald),
                      ],
                      _buildResultCardItem(l.recommendedShippingMetric, recMethod, Icons.directions_boat,
                          modeRec.isAirSuggested ? AppTheme.cobalt : (modeRec.isLclSuggested ? AppTheme.wcagOrange : AppTheme.cobalt),
                          subtitle: recContainer),
                    ];

                    if (constraints.maxWidth > 950) {
                      return Row(
                        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: c))).toList(),
                      );
                    } else if (constraints.maxWidth > 550) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: cards
                            .map((c) => SizedBox(
                                  width: (constraints.maxWidth - 8) / 2,
                                  child: c,
                                ))
                            .toList(),
                      );
                    } else {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: cards
                            .map((c) => SizedBox(
                                  width: constraints.maxWidth,
                                  child: c,
                                ))
                            .toList(),
                      );
                    }
                  },
                ),
            const SizedBox(height: 12),

            // Smart Mode & Cargo Stacking Skill Banner (MD-019.1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: modeRec.isAirSuggested
                    ? (isDark ? AppTheme.cobalt.withValues(alpha: 0.15) : AppTheme.cobaltLight)
                    : (modeRec.isLclSuggested ? (isDark ? AppTheme.orange.withValues(alpha: 0.15) : AppTheme.orangeLight) : AppTheme.cobalt.withValues(alpha: isDark ? 0.15 : 0.08)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: modeRec.isAirSuggested
                      ? AppTheme.cobaltBorder
                      : (modeRec.isLclSuggested ? AppTheme.orange : AppTheme.cobalt.withValues(alpha: 0.3)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2, color: AppTheme.cobalt, size: 22),
                          const SizedBox(width: 4),
                          Text(l.cargoStackingInstructions, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                          const SizedBox(width: 4),
                          ChoiceChip(
                            label: Text(l.stackableOption),
                            selected: _isStackable,
                            selectedColor: AppTheme.cobalt,
                            labelStyle: TextStyle(color: _isStackable ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal), fontWeight: FontWeight.bold, fontSize: 11),
                            onSelected: (val) => setState(() => _isStackable = true),
                          ),
                          ChoiceChip(
                            label: Text(l.nonStackableOption),
                            selected: !_isStackable,
                            selectedColor: AppTheme.wcagOrange,
                            labelStyle: TextStyle(color: !_isStackable ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal), fontWeight: FontWeight.bold, fontSize: 11),
                            onSelected: (val) => setState(() => _isStackable = false),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          AppButton(
                            label: l.compareContainersMatrix,
                            icon: Icons.table_chart,
                            variant: AppButtonVariant.primary,
                            size: AppButtonSize.small,
                            onPressed: () => _showContainerComparisonDialog(context, dualRec, totalCbm, totalGrossWt),
                          ),
                          AppButton(
                            label: l.visualLoadPlanSimulator,
                            icon: Icons.view_in_ar,
                            variant: AppButtonVariant.success,
                            size: AppButtonSize.small,
                            onPressed: () => _showVisualLoadPlanDialog(context, _quickItems),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          modeRec.isAirSuggested ? Icons.airplanemode_active : (modeRec.isLclSuggested ? Icons.inventory : Icons.directions_boat),
                          color: modeRec.isAirSuggested ? AppTheme.cobalt : (modeRec.isLclSuggested ? AppTheme.wcagOrange : AppTheme.cobalt),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isArabic ? modeRec.reasonAr : modeRec.reasonEn,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: modeRec.isAirSuggested ? AppTheme.wcagCobalt : (modeRec.isLclSuggested ? AppTheme.wcagOrange : AppTheme.charcoal),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Items Table Header & Add Row Action Card (Responsive Overflow-Free Layout)
            Card(
              elevation: 2,
              color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.format_list_bulleted, color: AppTheme.cobalt),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            l.packageMeasurementsTitle,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Shipment Mode Selector (Air vs Sea)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkElevatedSurface : AppTheme.cloudWhite,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              ChoiceChip(
                                label: Text(l.airFreightMode),
                                selected: _quickShipmentMode == 'air',
                                selectedColor: AppTheme.cobalt,
                                labelStyle: TextStyle(
                                  color: _quickShipmentMode == 'air' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => setState(() => _quickShipmentMode = 'air'),
                              ),
                              ChoiceChip(
                                label: Text(l.seaFreightMode),
                                selected: _quickShipmentMode == 'sea',
                                selectedColor: AppTheme.emerald,
                                labelStyle: TextStyle(
                                  color: _quickShipmentMode == 'sea' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => setState(() => _quickShipmentMode = 'sea'),
                              ),
                              ChoiceChip(
                                label: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'شحن بري (Road/LDM)' : 'Road Freight (LDM)'),
                                selected: _quickShipmentMode == 'road',
                                selectedColor: AppTheme.wcagOrange,
                                labelStyle: TextStyle(
                                  color: _quickShipmentMode == 'road' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => setState(() => _quickShipmentMode = 'road'),
                              ),
                            ],
                          ),
                        ),
                        AppButton(
                          label: l.addPackageLine,
                          icon: Icons.add,
                          variant: AppButtonVariant.primary,
                          onPressed: () {
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
                          },
                        ),
                        AppButton(
                          label: _activeSessionId != null ? l.saveChanges : l.saveCalculationSession,
                          icon: Icons.save_outlined,
                          variant: AppButtonVariant.success,
                          onPressed: () => _showSaveCalcDialog(context, _quickItems),
                        ),
                        AppButton(
                          label: Directionality.of(context) == TextDirection.rtl || Localizations.localeOf(context).languageCode == 'ar'
                                ? 'تصدير إكسيل'
                                : 'Export Excel',
                          icon: Icons.table_chart,
                          variant: AppButtonVariant.success,
                          onPressed: () => _exportQuickItemsToExcel(context),
                        ),
                        AppButton(
                          label: Directionality.of(context) == TextDirection.rtl || Localizations.localeOf(context).languageCode == 'ar'
                                ? 'تصدير PDF'
                                : 'Export PDF',
                          icon: Icons.picture_as_pdf,
                          variant: AppButtonVariant.danger,
                          onPressed: () => _exportQuickItemsToPdf(context),
                        ),
                        AppButton(
                          label: Directionality.of(context) == TextDirection.rtl || Localizations.localeOf(context).languageCode == 'ar'
                                ? 'نسخ الطرود'
                                : 'Copy Packages',
                          icon: Icons.content_copy,
                          variant: AppButtonVariant.secondary,
                          onPressed: () => _copyQuickItemsAsTsv(context),
                        ),
                        AppButton(
                          label: Directionality.of(context) == TextDirection.rtl || Localizations.localeOf(context).languageCode == 'ar'
                                ? 'نسخ التقرير الفني'
                                : 'Copy Study Report',
                          icon: Icons.assignment_outlined,
                          variant: AppButtonVariant.primary,
                          onPressed: () => _copyTechnicalFreightSummary(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Dynamic Line Items List (Horizontally & Vertically Scrollable with Explicit Scrollbar)
            SelectionArea(
              child: Card(
                elevation: 1,
                color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: _quickShipmentMode == 'air' ? 1380 : 1260,
                  ),
                  child: SizedBox(
                    width: math.max(
                      _quickShipmentMode == 'air' ? 1380.0 : 1260.0,
                      MediaQuery.of(context).size.width - 64,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Table Header Bar
                        Container(
                          color: isDark ? AppTheme.darkElevatedSurface : AppTheme.cloudWhite,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              SizedBox(width: 32, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                              const SizedBox(width: 8),
                              SizedBox(width: 160, child: Text(l.packageTypeCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                              const SizedBox(width: 8),
                              SizedBox(width: 95, child: Text(l.unitCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                              const SizedBox(width: 8),
                              SizedBox(width: 80, child: Text(l.qtyCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                              const SizedBox(width: 8),
                              SizedBox(width: 100, child: Text(l.lengthCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                              const SizedBox(width: 8),
                              SizedBox(width: 100, child: Text(l.widthCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                              const SizedBox(width: 8),
                              SizedBox(width: 100, child: Text(l.heightCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                              const SizedBox(width: 8),
                              SizedBox(width: 145, child: Text(l.stackingCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                              if (_quickShipmentMode == 'air') ...[
                                const SizedBox(width: 8),
                                SizedBox(width: 120, child: Text(l.grossWtPerUnitCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                              ],
                              const SizedBox(width: 14),
                              SizedBox(width: 140, child: Text(l.calculatedOutputsCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                              const SizedBox(width: 96),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          itemCount: _quickItems.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (ctx, idx) {
                            final item = _quickItems[idx];
                            final lM = item.lengthM;
                            final wM = item.widthM;
                            final hM = item.heightM;
                            final itemCbm = item.quantity * lM * wM * hM;
                            final itemVolWt = item.quantity * lM * wM * hM * kAirVolumetricKgPerCbm;
                            final itemGross = item.quantity * item.grossWeightPerUnitKg;

                            return Row(
                              key: ValueKey('row_${idx}_${_activeSessionId}_${item.itemId}'),
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: AppTheme.cobalt.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Text('#${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                ),
                                const SizedBox(width: 8),
                                // Package Type Dropdown (width: 160)
                                SizedBox(
                                  width: 160,
                                  child: SearchableDropdownField<String>(
                                    key: ValueKey('cbm_type_${idx}_$_activeSessionId'),
                                    value: item.packageType,
                                    labelText: l.packageTypeCol,
                                    searchHintText: l.packageTypeCol,
                                    items: ['Carton', 'Euro Pallet (120x80)', 'Standard Pallet (120x100)', 'Custom Pallet', 'Wooden Crate', 'Drum', 'Bag', 'Loose Box']
                                        .map((t) => SearchableDropdownItem<String>(value: t, label: t))
                                        .toList(),
                                    onChanged: (v) => _onPackageTypeSelected(idx, v),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 95,
                                  child: SearchableDropdownField<String>(
                                    /*
                                        .map((t) => SearchableDropdownItem<String>(value: t, label: t))
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          _quickItems[idx] = CBMItemModel(
                                            packageType: v,
                                            quantity: item.quantity,
                                            length: item.length,
                                            width: item.width,
                                            height: item.height,
                                            unit: item.unit,
                                            grossWeightPerUnitKg: item.grossWeightPerUnitKg,
                                            isStackable: item.isStackable,
                                          );
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Dimension Unit Selector (mm, cm, m) (width: 95)
                                SizedBox(
                                  width: 95,
                                  child: SearchableDropdownField<String>(
                                    */ key: ValueKey('cbm_unit_${idx}_$_activeSessionId'),
                                    value: item.unit,
                                    labelText: l.unitCol,
                                    searchHintText: l.unitCol,
                                    items: const [
                                      SearchableDropdownItem<String>(value: 'mm', label: 'mm'),
                                      SearchableDropdownItem<String>(value: 'cm', label: 'cm'),
                                      SearchableDropdownItem<String>(value: 'm', label: 'm'),
                                    ],
                                    onChanged: (u) {
                                      if (u != null) {
                                        setState(() {
                                          _quickItems[idx] = CBMItemModel(
                                            packageType: item.packageType,
                                            quantity: item.quantity,
                                            length: item.length,
                                            width: item.width,
                                            height: item.height,
                                            unit: u,
                                            grossWeightPerUnitKg: item.grossWeightPerUnitKg,
                                            isStackable: item.isStackable,
                                          );
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Quantity (width: 80)
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    key: ValueKey('cbm_qty_${idx}_$_activeSessionId'),
                                    initialValue: item.quantity.toString(),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(labelText: l.qtyCol, isDense: true, border: const OutlineInputBorder()),
                                    onChanged: (v) {
                                      final q = int.tryParse(v) ?? 1;
                                      setState(() {
                                        _quickItems[idx] = CBMItemModel(
                                          packageType: item.packageType,
                                          quantity: q,
                                          length: item.length,
                                          width: item.width,
                                          height: item.height,
                                          unit: item.unit,
                                          grossWeightPerUnitKg: item.grossWeightPerUnitKg,
                                          isStackable: item.isStackable,
                                        );
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Length (width: 100)
                                SizedBox(
                                  width: 100,
                                  child: TextFormField(
                                    key: ValueKey('cbm_len_${idx}_$_activeSessionId'),
                                    initialValue: item.length.toString(),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(labelText: '${l.lengthCol} (${item.unit})', isDense: true, border: const OutlineInputBorder()),
                                    onChanged: (v) {
                                      final len = double.tryParse(v) ?? 0.0;
                                      setState(() {
                                        _quickItems[idx] = CBMItemModel(
                                          packageType: item.packageType,
                                          quantity: item.quantity,
                                          length: len,
                                          width: item.width,
                                          height: item.height,
                                          unit: item.unit,
                                          grossWeightPerUnitKg: item.grossWeightPerUnitKg,
                                          isStackable: item.isStackable,
                                        );
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Width (width: 100)
                                SizedBox(
                                  width: 100,
                                  child: TextFormField(
                                    key: ValueKey('cbm_wid_${idx}_$_activeSessionId'),
                                    initialValue: item.width.toString(),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(labelText: '${l.widthCol} (${item.unit})', isDense: true, border: const OutlineInputBorder()),
                                    onChanged: (v) {
                                      final w = double.tryParse(v) ?? 0.0;
                                      setState(() {
                                        _quickItems[idx] = CBMItemModel(
                                          packageType: item.packageType,
                                          quantity: item.quantity,
                                          length: item.length,
                                          width: w,
                                          height: item.height,
                                          unit: item.unit,
                                          grossWeightPerUnitKg: item.grossWeightPerUnitKg,
                                          isStackable: item.isStackable,
                                        );
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Height (width: 100)
                                SizedBox(
                                  width: 100,
                                  child: TextFormField(
                                    key: ValueKey('cbm_hei_${idx}_$_activeSessionId'),
                                    initialValue: item.height.toString(),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(labelText: '${l.heightCol} (${item.unit})', isDense: true, border: const OutlineInputBorder()),
                                    onChanged: (v) {
                                      final h = double.tryParse(v) ?? 0.0;
                                      setState(() {
                                        _quickItems[idx] = CBMItemModel(
                                          packageType: item.packageType,
                                          quantity: item.quantity,
                                          length: item.length,
                                          width: item.width,
                                          height: h,
                                          unit: item.unit,
                                          grossWeightPerUnitKg: item.grossWeightPerUnitKg,
                                          isStackable: item.isStackable,
                                        );
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Cargo Stacking Type (Stackable vs Non-Stackable) (width: 145)
                                SizedBox(
                                  width: 145,
                                  child: SearchableDropdownField<bool>(
                                    key: ValueKey('cbm_stack_${idx}_$_activeSessionId'),
                                    value: item.isStackable,
                                    labelText: l.stackingCol,
                                    searchHintText: l.stackingCol,
                                    items: [
                                      SearchableDropdownItem<bool>(value: true, label: l.stackableOption),
                                      SearchableDropdownItem<bool>(value: false, label: l.nonStackableOption),
                                    ],
                                    onChanged: (st) {
                                      if (st != null) {
                                        setState(() {
                                          _quickItems[idx] = CBMItemModel(
                                            packageType: item.packageType,
                                            quantity: item.quantity,
                                            length: item.length,
                                            width: item.width,
                                            height: item.height,
                                            unit: item.unit,
                                            grossWeightPerUnitKg: item.grossWeightPerUnitKg,
                                            isStackable: st,
                                          );
                                        });
                                      }
                                    },
                                  ),
                                ),
                                if (_quickShipmentMode == 'air') ...[
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 120,
                                    child: TextFormField(
                                      key: ValueKey('cbm_wt_${idx}_$_activeSessionId'),
                                      initialValue: item.grossWeightPerUnitKg.toString(),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(labelText: l.grossWtPerUnitCol, isDense: true, border: const OutlineInputBorder()),
                                      onChanged: (v) {
                                        final gw = double.tryParse(v) ?? 0.0;
                                        setState(() {
                                          _quickItems[idx] = CBMItemModel(
                                            packageType: item.packageType,
                                            quantity: item.quantity,
                                            length: item.length,
                                            width: item.width,
                                            height: item.height,
                                            unit: item.unit,
                                            grossWeightPerUnitKg: gw,
                                            isStackable: item.isStackable,
                                          );
                                        });
                                      },
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 14),

                                // Computed line outputs badge (width: 140)
                                SizedBox(
                                  width: 140,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CopyableText(
                                        '${l.cbmRowLineCbm}: ${itemCbm.toStringAsFixed(4)} m³',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange, fontSize: 12),
                                      ),
                                      if (_quickShipmentMode == 'air') ...[
                                        CopyableText(
                                          '${l.cbmRowLineGross}: ${itemGross.toStringAsFixed(1)} kg',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                        ),
                                        CopyableText(
                                          '${l.cbmRowLineAirVol}: ${itemVolWt.toStringAsFixed(1)} kg',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.cobalt),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // Clone row button
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt),
                                  tooltip: l.cloneQuickItemTooltip,
                                  onPressed: () {
                                    setState(() => _lastFocusedItemIndex = idx);
                                    _cloneQuickItem(idx);
                                  },
                                ),
                                if (_quickItems.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.crimson),
                                    tooltip: l.deleteRowTooltip,
                                    onPressed: () {
                                      setState(() {
                                        _quickItems.removeAt(idx);
                                      });
                                    },
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
              ),
             ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
    ),
  );
  }

  Widget _buildResultCardItem(String title, String value, IconData icon, Color color, {String? subtitle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  CopyableText(
                    value,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    CopyableText(
                      subtitle,
                      style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: SAVED CALCULATIONS REGISTRY (سجل دراسة وحسابات الشحن)
  // ---------------------------------------------------------------------------

  void _showSaveCalcDialog(BuildContext context, List<CBMItemModel> items) {
    SaveCbmCalcDialog.show(
      context,
      items: items,
      isStackable: _isStackable,
      quickShipmentMode: _quickShipmentMode,
      activeSessionId: _activeSessionId,
      activeSessionCode: _activeSessionCode,
      activeSessionTitle: _activeSessionTitle,
      activeSessionNotes: _activeSessionNotes,
      activeSessionImportFileId: _activeSessionImportFileId,
      onClearActiveSession: _clearActiveSession,
      onSavedSuccess: () {
        _tabController.animateTo(1);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CALCULATION DETAILS DIALOG (سجل وتفاصيل دراسة الحساب - تصميم مطابق لدراسة الشحن)
  // ---------------------------------------------------------------------------

  void _showContainerComparisonDialog(BuildContext context, ContainerDualRecommendationResult dualRec, double totalCbm, double totalWeightKg) {
    ContainerComparisonDialog.show(
      context,
      dualRec: dualRec,
      totalCbm: totalCbm,
      totalWeightKg: totalWeightKg,
    );
  }

  void _showVisualLoadPlanDialog(BuildContext context, List<CBMItemModel> quickItems) {
    CargoLoadPlannerDialog.showFromCbmItems(context, items: quickItems);
  }

  Widget _buildSavedRegistryTab(
    BuildContext context,
    CBMCalculatorState state,
    List<ProjectModel> projectsList,
    List<PurchaseOrderModel> poList,
  ) {
    return SavedCbmRegistryTab(
      onLoadSession: _loadSessionForEditing,
      onSwitchToCalculator: () => _tabController.animateTo(0),
    );
  }

  Future<void> _exportQuickItemsToExcel(BuildContext context) async {
    if (_quickItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.cbmNoPackageLinesToExport,
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    final headers = [
      context.l10n.cargoShippingColUnitNumber,
      context.l10n.packageTypeCol,
      context.l10n.unitCol,
      context.l10n.qtyCol,
      context.l10n.lengthCol,
      context.l10n.widthCol,
      context.l10n.heightCol,
      context.l10n.cbmStackable,
      if (_quickShipmentMode == 'air') context.l10n.cbmGrossWtUnitKg,
      context.l10n.cbmTotalCBM,
      if (_quickShipmentMode == 'air') context.l10n.cbmVolumetricWtKg,
      if (_quickShipmentMode == 'air') context.l10n.cbmChargeableWtKg,
    ];

    final rows = _quickItems.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final item = entry.value;
      final totalCbm = item.lengthM * item.widthM * item.heightM * item.quantity;
      final totalVol = item.lengthM * item.widthM * item.heightM * item.quantity * kAirVolumetricKgPerCbm;
      final totalGross = item.grossWeightPerUnitKg * item.quantity;
      final chargeable = math.max(totalVol, totalGross);

      return [
        '$idx',
        item.packageType,
        item.unit,
        '${item.quantity}',
        '${item.length}',
        '${item.width}',
        '${item.height}',
        item.isStackable ? (context.l10n.projectMultiShipmentYes) : (context.l10n.projectMultiShipmentNo),
        if (_quickShipmentMode == 'air') '${item.grossWeightPerUnitKg}',
        totalCbm.toStringAsFixed(3),
        if (_quickShipmentMode == 'air') totalVol.toStringAsFixed(1),
        if (_quickShipmentMode == 'air') chargeable.toStringAsFixed(1),
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.cbmPackageMeasurements,
      importFileNameOrCode: _activeSessionCode ?? 'Quick_CBM',
    );
  }

  Future<void> _exportQuickItemsToPdf(BuildContext context) async {
    if (_quickItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.cbmNoPackageLinesToExport,
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    final headers = [
      '#',
      context.l10n.cooRegistryColType,
      context.l10n.qtyCol,
      context.l10n.cbmDimensions,
      context.l10n.cbmRowLineCbm,
      if (_quickShipmentMode == 'air') context.l10n.cbmVolWt,
      if (_quickShipmentMode == 'air') context.l10n.cbmChargeable,
    ];

    final rows = _quickItems.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final item = entry.value;
      final totalCbm = item.lengthM * item.widthM * item.heightM * item.quantity;
      final totalVol = item.lengthM * item.widthM * item.heightM * item.quantity * kAirVolumetricKgPerCbm;
      final totalGross = item.grossWeightPerUnitKg * item.quantity;
      final chargeable = math.max(totalVol, totalGross);

      return [
        '$idx',
        item.packageType,
        '${item.quantity}',
        '${item.length}x${item.width}x${item.height} ${item.unit}',
        totalCbm.toStringAsFixed(3),
        if (_quickShipmentMode == 'air') totalVol.toStringAsFixed(1),
        if (_quickShipmentMode == 'air') chargeable.toStringAsFixed(1),
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.cbmCBMCalculator,
      importFileNameOrCode: _activeSessionCode ?? 'Quick_CBM',
      headerContext: TableExportHeaderContext(
        title: context.l10n.cbmPackageMeasurementsSpecification,
        subtitle: 'Sorour Logistics ERP — ${_activeSessionTitle ?? "Quick CBM"}',
        metadata: {
          context.l10n.cbmShipmentMode: _quickShipmentMode == 'air' ? (context.l10n.cbmAir) : (context.l10n.cbmSea),
          context.l10n.cbmPackageLines: '${_quickItems.length}',
          context.l10n.date: DateTime.now().toString().substring(0, 10),
        },
      ),
    );
  }

  void _copyQuickItemsAsTsv(BuildContext context) {
    if (_quickItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.cbmNoPackageLinesToCopy,
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    final headers = [
      context.l10n.cargoShippingColUnitNumber,
      context.l10n.packageTypeCol,
      context.l10n.unitCol,
      context.l10n.qtyCol,
      context.l10n.lengthCol,
      context.l10n.widthCol,
      context.l10n.heightCol,
      context.l10n.cbmStackable,
      if (_quickShipmentMode == 'air') context.l10n.cbmGrossWtUnitKg,
      context.l10n.cbmTotalCBM,
      if (_quickShipmentMode == 'air') context.l10n.cbmVolumetricWtKg,
      if (_quickShipmentMode == 'air') context.l10n.cbmChargeableWtKg,
    ];

    final rows = _quickItems.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final item = entry.value;
      final totalCbm = item.lengthM * item.widthM * item.heightM * item.quantity;
      final totalVol = item.lengthM * item.widthM * item.heightM * item.quantity * kAirVolumetricKgPerCbm;
      final totalGross = item.grossWeightPerUnitKg * item.quantity;
      final chargeable = math.max(totalVol, totalGross);

      return [
        '$idx',
        item.packageType,
        item.unit,
        '${item.quantity}',
        '${item.length}',
        '${item.width}',
        '${item.height}',
        item.isStackable ? (context.l10n.projectMultiShipmentYes) : (context.l10n.projectMultiShipmentNo),
        if (_quickShipmentMode == 'air') '${item.grossWeightPerUnitKg}',
        totalCbm.toStringAsFixed(3),
        if (_quickShipmentMode == 'air') totalVol.toStringAsFixed(1),
        if (_quickShipmentMode == 'air') chargeable.toStringAsFixed(1),
      ];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: context.l10n.cbmPackagesTableCopiedToClipboard,
    );
  }

  void _copyTechnicalFreightSummary(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    double totalCbm = 0.0;
    double totalGrossWt = 0.0;
    double totalVolumetricWt = 0.0;
    double totalFloorAreaM2 = 0.0;
    int totalPackagesCount = 0;

    for (var item in _quickItems) {
      final lM = item.lengthM;
      final wM = item.widthM;
      final hM = item.heightM;
      final cbm = item.quantity * lM * wM * hM;
      final volWt = item.quantity * lM * wM * hM * kAirVolumetricKgPerCbm;
      final gross = item.quantity * item.grossWeightPerUnitKg;
      final floor = item.quantity * lM * wM;
      totalFloorAreaM2 += floor;
      final floorArea = ContainerRequirementEngine.calculateFloorAreaM2(lengthM: lM, widthM: wM, quantity: item.quantity);

      totalCbm += cbm;
      totalVolumetricWt += volWt;
      totalGrossWt += gross;
      totalFloorAreaM2 += floorArea;
      totalPackagesCount += item.quantity;
    }

    final totalLdm = ContainerRequirementEngine.calculateLdm(floorAreaM2: totalFloorAreaM2);
    final totalChargeableCbm = ContainerRequirementEngine.calculateLclChargeableCbm(
      physicalCbm: totalCbm,
      floorAreaM2: totalFloorAreaM2,
      isStackable: _isStackable,
    );
    final totalRevenueTon = ContainerRequirementEngine.calculateOceanRevenueTon(
      chargeableCbm: totalChargeableCbm,
      totalGrossWeightKg: totalGrossWt,
    );
    final airChargeableWt = totalGrossWt > totalVolumetricWt ? totalGrossWt : totalVolumetricWt;
    final dualRec = ContainerRequirementEngine.calculateBoth(totalCbm: totalCbm, totalWeightKg: totalGrossWt);
    final containerRec = _isStackable ? dualRec.stackableResult : dualRec.nonStackableResult;

    final buffer = StringBuffer();
    if (isArabic) {
      buffer.writeln('### تقرير دراسة قياسات وحسابات الشحن');
      buffer.writeln('---');
      buffer.writeln('#### 1. ملخص القياسات والأوزان:');
      buffer.writeln('* **إجمالي الطرود:** $totalPackagesCount طرد (${_quickItems.length} بنود)');
      buffer.writeln('* **المساحة الأرضية المشغولة:** ${totalFloorAreaM2.toStringAsFixed(2)} م²');
      buffer.writeln('* **الحجم الفعلي الصافي:** ${totalCbm.toStringAsFixed(4)} م³');
      buffer.writeln('* **إجمالي الوزن القائم:** ${totalGrossWt.toStringAsFixed(1)} كجم (${(totalGrossWt / 1000.0).toStringAsFixed(3)} طن متري)');
      buffer.writeln('* **قابلية الرص:** ${_isStackable ? "قابل للرص" : "غير قابل للرص أرضي فقط"}');
      buffer.writeln('');
      buffer.writeln('#### 2. الحسابات المحاسبية حسب وسيلة الشحن:');
      buffer.writeln('* **الشحن البحري LCL (طن الإيراد):** ${totalRevenueTon.toStringAsFixed(3)} RT');
      if (!_isStackable) {
        buffer.writeln('* **الحجم المحاسبي البحري (فاقد الارتفاع):** ${totalChargeableCbm.toStringAsFixed(3)} م³ (فرق فراغ رأسي: +${(totalChargeableCbm - totalCbm).toStringAsFixed(3)} م³)');
      }
      buffer.writeln('* **الشحن الجوي (الوزن المحاسبي الخاضع للرسوم):** ${airChargeableWt.toStringAsFixed(1)} كجم (الوزن الحجمي: ${totalVolumetricWt.toStringAsFixed(1)} كجم)');
      buffer.writeln('* **الشحن البري (أمتار التحميل):** ${totalLdm.toStringAsFixed(2)} LDM (من أصل 13.6 LDM للتريلا القياسية)');
      buffer.writeln('');
      buffer.writeln('#### 3. التوصية التشغيلية للمعدات والحاويات:');
      buffer.writeln('* **الوسيلة المقترحة:** ${dualRec.modeRecommendation.recommendedModeAr}');
      buffer.writeln('* **المعدات والحاويات:** ${containerRec.recommendationSummary}');
    } else {
      buffer.writeln('### Freight & CBM Study Technical Report');
      buffer.writeln('---');
      buffer.writeln('#### 1. Cargo Summary Metrics:');
      buffer.writeln('* **Total Packages:** $totalPackagesCount units (${_quickItems.length} line items)');
      buffer.writeln('* **Floor Footprint:** ${totalFloorAreaM2.toStringAsFixed(2)} m²');
      buffer.writeln('* **Physical Volume:** ${totalCbm.toStringAsFixed(4)} CBM');
      buffer.writeln('* **Total Gross Weight:** ${totalGrossWt.toStringAsFixed(1)} kg (${(totalGrossWt / 1000.0).toStringAsFixed(3)} Metric Tons)');
      buffer.writeln('* **Stackability:** ${_isStackable ? "Stackable" : "Non-Stackable (Floor only)"}');
      buffer.writeln('');
      buffer.writeln('#### 2. Freight Mode Chargeable Metrics:');
      buffer.writeln('* **Ocean LCL Revenue Ton (W/M applied):** ${totalRevenueTon.toStringAsFixed(3)} RT');
      if (!_isStackable) {
        buffer.writeln('* **Ocean LCL Billed CBM (Loss of Height @ 2.20m):** ${totalChargeableCbm.toStringAsFixed(3)} CBM (+${(totalChargeableCbm - totalCbm).toStringAsFixed(3)} CBM lost clearance)');
      }
      buffer.writeln('* **Air Chargeable Weight:** ${airChargeableWt.toStringAsFixed(1)} kg (Volumetric Wt: ${totalVolumetricWt.toStringAsFixed(1)} kg)');
      buffer.writeln('* **Road Freight (LDM):** ${totalLdm.toStringAsFixed(2)} LDM (out of 13.6m standard trailer)');
      buffer.writeln('');
      buffer.writeln('#### 3. Equipment & Container Allocation:');
      buffer.writeln('* **Recommended Mode:** ${dualRec.modeRecommendation.recommendedMode}');
      buffer.writeln('* **Container Spec:** ${containerRec.recommendationSummaryEn}');
    }

    CopyHelper.copy(context, buffer.toString());
    AppTheme.snackBar(context, isArabic ? 'تم نسخ التقرير الفني للشحنة بنجاح' : 'Freight study summary copied to clipboard', severity: AppSeverity.success);
  }
}
