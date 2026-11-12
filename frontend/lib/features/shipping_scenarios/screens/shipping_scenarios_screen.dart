import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/performance/dispose_tracker.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../currencies/providers/currencies_provider.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../projects/providers/projects_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../transport_locations/providers/transport_locations_provider.dart';
import '../models/shipping_scenario_model.dart';
import '../providers/shipping_scenarios_provider.dart';
import '../widgets/saved_scenarios_registry_tab.dart';
import '../widgets/search_and_clone_study_dialog.dart';
import '../widgets/shipping_scenario_evaluator_tab.dart';
import '../widgets/shipping_scenarios_dialogs.dart';

class ShippingScenariosScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  final int? initialImportFileId;
  final bool isEmbedded;

  const ShippingScenariosScreen({
    super.key,
    this.initialIndex = 0,
    this.initialImportFileId,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<ShippingScenariosScreen> createState() => _ShippingScenariosScreenState();
}

class _ShippingScenariosScreenState extends ConsumerState<ShippingScenariosScreen>
    with SingleTickerProviderStateMixin, DisposeTrackerMixin<ShippingScenariosScreen> {
  late TabController _tabController;
  final GlobalKey<ShippingScenarioEvaluatorTabState> _evaluatorKey = GlobalKey<ShippingScenarioEvaluatorTabState>();
  bool _hasVisitedTab0 = false;
  bool _hasVisitedTab1 = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );

    if (widget.initialIndex == 0) _hasVisitedTab0 = true;
    if (widget.initialIndex == 1) _hasVisitedTab1 = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void didUpdateWidget(ShippingScenariosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex && widget.initialIndex != _tabController.index) {
      _tabController.animateTo(widget.initialIndex);
      if (widget.initialIndex == 0) _hasVisitedTab0 = true;
      if (widget.initialIndex == 1) _hasVisitedTab1 = true;
    }
  }

  /// Switches the visible tab. The [IndexedStack] and the side nav read `_tabController.index`
  /// during build, so the change must go through `setState`; the tab is inflated on first visit.
  void _switchToTab(int index) {
    if (!mounted) return;
    setState(() {
      _tabController.index = index;
      if (index == 0) _hasVisitedTab0 = true;
      if (index == 1) _hasVisitedTab1 = true;
    });
  }

  /// Opens [session] in the evaluator tab. Loading waits one frame so the evaluator exists
  /// even when the screen was opened directly on the saved-evaluations log.
  void _openInEvaluator(ShippingEvaluationModel session, {bool showLoadedSnackbar = true}) {
    _switchToTab(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _evaluatorKey.currentState?.loadSessionForEditing(session, showLoadedSnackbar: showLoadedSnackbar);
    });
  }

  void _refreshData({bool force = false}) {
    if (force) {
      ref.invalidate(shippingScenariosProvider);
      ref.invalidate(purchaseOrdersProvider);
      ref.invalidate(projectsProvider);
      ref.invalidate(allPartnersProvider);
      ref.invalidate(transportLocationsProvider);
      ref.invalidate(currenciesProvider);
      ref.invalidate(importFilesProvider);
    }
    if (!ref.read(shippingScenariosProvider).isLoading) {
      ref.read(shippingScenariosProvider.notifier).fetchSessions();
    }
    if (!ref.read(allPartnersProvider).isLoading) {
      ref.read(allPartnersProvider.notifier).fetchPartners();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openSearchAndCloneStudyDialog(BuildContext context) {
    final state = ref.read(shippingScenariosProvider);
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';

    showDialog(
      context: context,
      builder: (dialogCtx) => SelectionArea(
        child: AppLocalizationsProvider(
          locale: isArabic ? const Locale('ar') : const Locale('en'),
          child: Directionality(
            textDirection: textDir,
            child: SearchAndCloneStudyDialog(
              sessions: state.sessions,
              onSelectStudy: (session) {
                Navigator.of(dialogCtx).pop();
                ShippingScenariosDialogs.showCloneStudyReviewDialog(
                  context,
                  ref,
                  session,
                  onClonedSuccess: (cloned) => _openInEvaluator(cloned, showLoadedSnackbar: false),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(shippingScenariosProvider);

    if (widget.isEmbedded) {
      return SelectionArea(
        child: ShippingScenarioEvaluatorTab(
          key: _evaluatorKey,
          initialImportFileId: widget.initialImportFileId,
          onRefreshData: () => _refreshData(force: true),
        ),
      );
    }

    final tabs = [
      const VerticalNavTabItem(
        icon: Icons.analytics_outlined,
        titleEn: 'Scenarios Evaluator',
        titleAr: 'دراسة وسيناريوهات الشحن',
      ),
      VerticalNavTabItem(
        icon: Icons.history_edu_outlined,
        titleEn: 'Saved Evaluations Log',
        titleAr: 'سجل الدراسات المحفوظة',
        badge: state.sessions.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${state.sessions.length}',
                  style: const TextStyle(color: AppTheme.cobalt, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
    ];

    return SelectionArea(
      child: VerticalStageScaffold(
        stageCode: 'STEP_01',
        titleEn: 'Freight Shipping Scenarios & Carrier Evaluation',
        titleAr: 'دراسات وسيناريوهات الشحن والمفاضلة',
        headerIcon: Icons.alt_route_outlined,
        headerColor: AppTheme.cobalt,
        tabs: tabs,
        selectedIndex: _tabController.index,
        onTabSelected: _switchToTab,
        selectedImportFileId: widget.initialImportFileId,
        onShipmentStatusChanged: () => _refreshData(force: true),
        headerActions: [
          AppButton(
            key: const ValueKey('searchAndCloneStudyBtn'),
            label: l.searchAndCloneStudyBtn,
            icon: Icons.copy_all_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => _openSearchAndCloneStudyDialog(context),
          ),
          const SizedBox(width: 8),
          SmartUploadButton(
            module: SmartUploadModule.freightQuotation,
            label: '🚀 ${l.extractFreightQuotes}',
            onDataExtracted: (result) {
              _evaluatorKey.currentState?.applySmartExtractedFreightQuotes(result.extractedFields);
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.white),
            tooltip: l.liveRefresh,
            onPressed: () => _refreshData(force: true),
          ),
        ],
        body: IndexedStack(
          index: _tabController.index,
          children: [
            _hasVisitedTab0
                ? ShippingScenarioEvaluatorTab(
                    key: _evaluatorKey,
                    initialImportFileId: widget.initialImportFileId,
                    onSwitchToRegistry: () => _switchToTab(1),
                    onRefreshData: () => _refreshData(force: true),
                  )
                : const SizedBox.shrink(),
            _hasVisitedTab1
                ? SavedScenariosRegistryTab(
                    onEditSession: _openInEvaluator,
                    onSwitchToEvaluator: () => _switchToTab(0),
                  )
                : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
