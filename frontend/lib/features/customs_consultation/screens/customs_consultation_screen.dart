import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/widgets.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../customs_clearance_quotations/screens/customs_clearance_quotations_screen.dart';
import '../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../projects/providers/projects_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../providers/customs_consultation_provider.dart';
import '../../shipping_scenarios/providers/shipping_scenarios_provider.dart';
import '../widgets/widgets.dart';
import '../widgets/tabs/customs_consultation_calc_tab.dart';
import '../widgets/tabs/customs_price_lists_tab.dart';

export '../widgets/widgets.dart';
export '../widgets/tabs/customs_consultation_calc_tab.dart';
export '../widgets/tabs/customs_price_lists_tab.dart';
export '../widgets/dialogs/consultation_clone_dialog.dart';
export '../widgets/cards/consultation_tax_review_card.dart';

/// Coordinator Screen for Customs Broker Consultations & Landed Cost / Duty Reviews.
///
/// Coordinates tabs across:
/// - Tab 0: Customs Consultation & Duties Calculator Workspace
/// - Tab 1: Saved Consultations / Tax Review Log
/// - Tab 2: Broker Price Lists & Catalog Management
/// - Tab 3: Clearance Quotations & AI Extractor
class CustomsConsultationScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  final bool isTaxReviewMode;

  const CustomsConsultationScreen({
    super.key,
    this.initialIndex = 0,
    this.isTaxReviewMode = false,
  });

  @override
  ConsumerState<CustomsConsultationScreen> createState() => _CustomsConsultationScreenState();
}

class _CustomsConsultationScreenState extends ConsumerState<CustomsConsultationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final Set<int> _visitedTabs = {widget.initialIndex};
  final GlobalKey<CustomsConsultationCalcTabState> _calcTabKey =
      GlobalKey<CustomsConsultationCalcTabState>();

  int? _selectedImportFileId;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    final tabCount = widget.isTaxReviewMode ? 2 : 4;
    final initialIdx = widget.initialIndex < tabCount ? widget.initialIndex : 0;
    _visitedTabs.add(initialIdx);
    _tabController = TabController(length: tabCount, vsync: this, initialIndex: initialIdx);
    _tabController.addListener(() {
      if (!_visitedTabs.contains(_tabController.index)) {
        setState(() => _visitedTabs.add(_tabController.index));
      }
    });

    Future.microtask(() {
      _refreshAllProviders();
    });
  }

  void _refreshAllProviders() {
    if (!ref.read(customsConsultationsProvider).isLoading) {
      ref.read(customsConsultationsProvider.notifier).fetchConsultations();
    }
    if (!ref.read(importFilesProvider).isLoading) {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    if (!ref.read(purchaseOrdersProvider).isLoading) {
      ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
    }
    if (!ref.read(customsTariffProvider).isLoading) {
      ref.read(customsTariffProvider.notifier).fetchTariffs();
    }
    if (!ref.read(currenciesProvider).isLoading) {
      ref.read(currenciesProvider.notifier).fetchCurrencies();
    }
    if (!ref.read(shippingScenariosProvider).isLoading) {
      ref.read(shippingScenariosProvider.notifier).fetchSessions();
    }
    if (!ref.read(partnersProvider).isLoading) {
      ref.read(partnersProvider.notifier).fetchPartners();
    }
    if (!ref.read(projectsProvider).isLoading) {
      ref.read(projectsProvider.notifier).fetchProjects();
    }
    if (!widget.isTaxReviewMode) {
      if (!ref.read(clearanceExpenseTypesProvider).isLoading) {
        ref.read(clearanceExpenseTypesProvider.notifier).fetchExpenseTypes();
      }
      if (!ref.read(brokerPriceListsProvider).isLoading) {
        ref.read(brokerPriceListsProvider.notifier).fetchPriceLists();
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final consultationsState = ref.watch(customsConsultationsProvider);
    final consultationsList = consultationsState.valueOrNull ?? [];

    final tabs = widget.isTaxReviewMode
        ? [
            VerticalNavTabItem(
              icon: Icons.calculate_outlined,
              titleEn: 'Customs Duty Workspace',
              titleAr: l.taxReviewWorkspaceTab,
            ),
            VerticalNavTabItem(
              icon: Icons.history_edu_outlined,
              titleEn: 'Tax Review Log',
              titleAr: l.taxReviewLogTab,
              badge: consultationsList.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${consultationsList.where((s) => s.estimatedDutiesEgp > 0).length}',
                        style: const TextStyle(
                          color: AppTheme.cobalt,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
          ]
        : [
            VerticalNavTabItem(
              icon: Icons.gavel_outlined,
              titleEn: 'Customs Workspace',
              titleAr: l.customsWorkspaceTab,
            ),
            VerticalNavTabItem(
              icon: Icons.history_edu_outlined,
              titleEn: 'Consultations Log',
              titleAr: l.consultationsLogTab,
              badge: consultationsList.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${consultationsList.length}',
                        style: const TextStyle(
                          color: AppTheme.cobalt,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
            VerticalNavTabItem(
              icon: Icons.price_change_outlined,
              titleEn: 'Broker Price Lists & Catalog',
              titleAr: l.brokerPriceListsTab,
            ),
            VerticalNavTabItem(
              icon: Icons.request_quote_rounded,
              titleEn: 'Clearance Quotes & AI Extractor',
              titleAr: l.clearanceQuotesTab,
            ),
          ];

    return VerticalStageScaffold(
      stageCode: widget.isTaxReviewMode ? 'PHASE-1: STEP_02-TAX' : 'PHASE-1: STEP_02',
      isDirty: _isDirty,
      onDiscard: () {
        setState(() => _isDirty = false);
        _calcTabKey.currentState?.resetForm();
      },
      titleEn: widget.isTaxReviewMode
          ? 'Customs Duty Review & Tax Calculation Workspace'
          : 'Customs Broker Consultation & Inspection Workspace',
      titleAr: widget.isTaxReviewMode
          ? l.customsDutyReviewTitle
          : l.customsStudiesTitle,
      headerIcon: widget.isTaxReviewMode ? Icons.calculate_outlined : Icons.gavel_outlined,
      headerColor: widget.isTaxReviewMode ? AppTheme.emerald : AppTheme.cobalt,
      tabs: tabs,
      selectedIndex: _tabController.index,
      onTabSelected: (index) {
        _visitedTabs.add(index);
        setState(() => _tabController.index = index);
      },
      selectedImportFileId: _selectedImportFileId,
      onShipmentStatusChanged: () {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      },
      headerActions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          tooltip: l.liveRefresh,
          onPressed: _refreshAllProviders,
        ),
      ],
      body: SelectionArea(
        child: IndexedStack(
          index: _tabController.index,
          children: [
            // TAB 0: CUSTOMS CONSULTATION & DUTY CALC WORKSPACE
            _visitedTabs.contains(0)
                ? CustomsConsultationCalcTab(
                    key: _calcTabKey,
                    isTaxReviewMode: widget.isTaxReviewMode,
                    onDirtyChanged: (dirty) => setState(() => _isDirty = dirty),
                    onImportFileChanged: (fId) => setState(() => _selectedImportFileId = fId),
                    onSaved: (saved) {
                      setState(() {
                        _isDirty = false;
                        _visitedTabs.add(1);
                        _tabController.animateTo(1);
                      });
                    },
                  )
                : const SizedBox.shrink(),

            // TAB 1: SAVED CONSULTATIONS / TAX REVIEW LOG
            _visitedTabs.contains(1)
                ? SavedConsultationsTab(
                    isTaxReviewOnly: widget.isTaxReviewMode,
                    onEdit: (session) {
                      setState(() {
                        _visitedTabs.add(0);
                        _tabController.animateTo(0);
                      });
                      _calcTabKey.currentState?.loadConsultation(session);
                    },
                    onViewDetails: showConsultationDetailsDialog,
                  )
                : const SizedBox.shrink(),

            if (!widget.isTaxReviewMode) ...[
              // TAB 2: BROKER PRICE LISTS & CATALOG MANAGEMENT
              _visitedTabs.contains(2)
                  ? const CustomsPriceListsTab()
                  : const SizedBox.shrink(),

              // TAB 3: CLEARANCE QUOTATIONS & SMART AI EXTRACTOR
              _visitedTabs.contains(3)
                  ? const CustomsClearanceQuotationsScreen(embedded: true)
                  : const SizedBox.shrink(),
            ],
          ],
        ),
      ),
    );
  }
}
