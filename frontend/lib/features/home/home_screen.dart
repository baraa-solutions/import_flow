import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/constants/api_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/widgets/command_palette_dialog.dart';
import '../../core/widgets/directional_icon.dart';
import '../../core/widgets/keyboard_shortcuts_dialog.dart';
import '../../core/widgets/unsaved_changes_dialog.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/providers/focus_mode_provider.dart';
import '../../core/providers/workspace_tabs_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/density_provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/unified_top_bar.dart';
import 'widgets/multi_tab_workspace_bar.dart';
import '../audit_logs/screens/audit_logs_screen.dart';

import '../auth/models/user_model.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/providers/auth_route_guard.dart';
import '../auth/screens/force_change_password_screen.dart';
import '../cargo_shipping/screens/cargo_shipping_screen.dart';
import '../cbm_calculator/screens/cbm_calculator_screen.dart';
import '../comprehensive_report/screens/import_file_comprehensive_report_screen.dart';
import '../currencies/screens/currencies_screen.dart';
import '../customs_clearance/screens/customs_clearance_screen.dart';
import '../customs_consultation/screens/customs_consultation_screen.dart';
import '../customs_tariff/screens/customs_tariff_screen.dart';
import '../demurrage_detention/screens/demurrage_detention_screen.dart';
import '../dynamic_reporting/screens/dynamic_report_builder_screen.dart';
import '../external_service_providers/screens/partners_screen.dart';
import '../file_closure/screens/file_closure_screen.dart';
import '../financial_approval/screens/financial_approval_screen.dart';
import '../financial_approval/screens/swift_reconciliation_screen.dart';
import '../financial_settlement/screens/financial_settlement_screen.dart';
import '../freight_booking/screens/freight_booking_screen.dart';
import '../freight_quotations/screens/freight_quotations_screen.dart';
import '../shipping_scenarios/screens/shipping_scenarios_screen.dart';
import '../import_companies/screens/import_companies_screen.dart';
import '../import_documentation/screens/bank_form4_screen.dart';
import '../cargo_insurance/screens/cargo_insurance_screen.dart';
import '../import_documentation/screens/central_docs_archive_screen.dart';
import '../import_documentation/screens/customs_declaration46_screen.dart';
import '../import_documentation/screens/nafeza_acid_screen.dart';
import '../import_documentation/screens/original_docs_and_cargox_screen.dart';
import '../import_documentation/screens/po_packing_reconciliation_screen.dart';
import '../import_documentation/screens/draft_bl_review_screen.dart';
import '../import_documentation/screens/smart_invoice_bl_match_screen.dart';
import '../import_documentation/screens/draft_coo_review_screen.dart';
import '../import_documentation/screens/draft_inspection_review_screen.dart';
import '../import_documentation/screens/docs_customs_approval_screen.dart';
import '../import_files/screens/import_files_screen.dart';
import '../import_requirements/screens/import_requirements_screen.dart';
import '../incoterms/screens/incoterms_screen.dart';
import '../notifications/widgets/notification_bell_widget.dart';
import '../operational_dashboard/screens/operational_dashboard_screen.dart';
import '../projects/screens/projects_screen.dart';
import '../lifecycle_board/screens/lifecycle_board_screen.dart';
import '../lifecycle_board/screens/step_config_management_screen.dart';
import '../purchase_orders/screens/purchase_orders_screen.dart';
import '../shipment_updates/screens/shipment_update_engine_screen.dart';
import '../smart_tasks/screens/smart_tasks_screen.dart';
import '../suppliers/screens/suppliers_screen.dart';
import '../transport_locations/screens/transport_locations_screen.dart';
import '../warehouse_receiving/screens/inbound_warehouse_hub_screen.dart';
import '../production_sync/screens/production_sync_screen.dart';
import '../production_sync/widgets/production_sync_hub_dialog.dart';
import '../app_update/widgets/post_update_notice.dart';
import '../app_update/widgets/app_update_panel.dart';
import '../app_update/widgets/update_banner.dart';
import '../app_update/widgets/update_indicator_pill.dart';
import '../app_update/widgets/update_notifier_host.dart';
import '../production_sync/providers/production_sync_provider.dart';
import '../auth/screens/users_management_screen.dart';
import '../shipment_inquiry/screens/shipment_inquiry_screen.dart';
import '../smart_tasks/widgets/smart_email_listener_dialog.dart';
import '../smart_tasks/widgets/email_settings_dialog.dart';
import '../../core/widgets/ai_assistant_panel.dart';
import '../../core/providers/ai_assistant_provider.dart';
import '../../core/widgets/system_settings_dialog.dart';
import '../system_observability/screens/system_observability_screen.dart';


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final List<Widget> _screens = const [
        // 0..3: Core Workspace (Phase 1)
        OperationalDashboardScreen(),
        ImportFilesScreen(),
        PurchaseOrdersScreen(),
        CBMCalculatorScreen(),

        // 4..5: Phase 1 Freight Studies, Timeline & Scenarios (Study & Saved Records)
        ShippingScenariosScreen(key: ValueKey('shipping_scenarios_tab0'), initialIndex: 0),
        ShippingScenariosScreen(key: ValueKey('shipping_scenarios_tab1'), initialIndex: 1),

        // 6..7: Phase 1 Customs Broker Consultation
        CustomsConsultationScreen(initialIndex: 0),
        CustomsConsultationScreen(initialIndex: 1),

        // 8..10: Phase 2 Financial Approvals
        FinancialApprovalScreen(initialIndex: 0),
        FinancialApprovalScreen(initialIndex: 1),
        FinancialApprovalScreen(initialIndex: 2),

        // 11..15: Phase 3 Nafeza & ACID Engine (Dedicated Screen with Vertical Tabs)
        NafezaAcidScreen(initialSubTab: 0),
        NafezaAcidScreen(initialSubTab: 1),
        NafezaAcidScreen(initialSubTab: 2),
        NafezaAcidScreen(initialSubTab: 3),
        NafezaAcidScreen(initialSubTab: 4),

        // 16..17: Bank Form 4 & Endorsement (Dedicated Screen with Vertical Tabs)
        BankForm4Screen(initialSubTab: 0),
        BankForm4Screen(initialSubTab: 1),

        // 18..22: Phase 3 Decomposed Draft Document Review Stages (Dedicated Full-Width Screens)
        DraftBLReviewScreen(key: ValueKey('draft_bl_review_screen')), // 18: Draft B/L Review & Approval
        DraftCOOReviewScreen(key: ValueKey('draft_coo_review_screen')), // 19: Draft COO / EUR.1 Review
        DocsCustomsApprovalScreen(key: ValueKey('docs_customs_approval_screen')), // 20: Docs Customs Approval & Rectifications
        POPackingReconciliationScreen(key: ValueKey('po_packing_reconciliation_screen')), // 21: PO & Packing Reconciliation
        SmartInvoiceBLMatchScreen(key: ValueKey('smart_invoice_bl_match_screen')), // 22: Smart Invoice vs B/L Match

        // 23..24: Phase 6 Customs Declaration 46 (Dedicated Screen with Vertical Tabs)
        CustomsDeclaration46Screen(initialSubTab: 0),
        CustomsDeclaration46Screen(initialSubTab: 1),

        // 25..30: Execution Phases (Phases 4 -> 10)
        FreightBookingScreen(),
        CargoShippingScreen(key: ValueKey('cargo_shipping_allocations_0'), initialSubTab: 0), // 26: Freight Allocations (VGM)
        CustomsClearanceScreen(),
        InboundWarehouseHubScreen(key: ValueKey('inbound_hub_grn'), initialSubTab: 1),
        FinancialSettlementScreen(key: ValueKey('settlement_tab0'), initialSubTab: 0),
        FileClosureScreen(),

        // 31..34: Master Data
        ProjectsScreen(),
        ImportCompaniesScreen(),
        SuppliersScreen(),
        PartnersScreen(),

        // 35..39: Reference Master Tables & Audit
        IncotermsScreen(),
        CustomsTariffScreen(key: ValueKey('customs_tariff_tab0'), initialTabIndex: 0),
        TransportLocationsScreen(),
        CurrenciesScreen(),
        AuditLogsScreen(),

        // 40..47: Smart Engines & Reporting
        SmartTasksScreen(),
        DynamicReportBuilderScreen(),
        ShipmentUpdateEngineScreen(),
        ImportRequirementsScreen(),
        DemurrageDetentionScreen(),
        CustomsTariffScreen(key: ValueKey('customs_tariff_tab1'), initialTabIndex: 1), // 45: HS Code Explorer & Duty Calculator
        SwiftReconciliationScreen(),
        ImportFileComprehensiveReportScreen(),

        // 48: Native 6-Phase Lifecycle Operations Board
        LifecycleBoardScreen(),

        // 49: Freight Quotations Comparison & Fast Awarding (Operational Workspace)
        FreightQuotationsScreen(key: ValueKey('freight_quotations_operational')),

        // 50: Landed Cost Comparison (Integrated in Financial Settlement Hub)
        FinancialSettlementScreen(key: ValueKey('settlement_tab1'), initialSubTab: 1),

        // 51: Central Shipment Documents Archive & Discrepancies Summary Hub
        CentralDocsArchiveScreen(),

        // 52: Cargo Shipping Tracking (48h SLA Tracking Subtab)
        CargoShippingScreen(key: ValueKey('cargo_shipping_tracking_1'), initialSubTab: 1),

        // 53: Draft Inspection Certificate (Dedicated Full-Width Screen)
        DraftInspectionReviewScreen(key: ValueKey('draft_inspection_review_screen')),

        // 54: CargoX Blockchain & ACI Dispatch Hub → Phase 4 Standalone Screen (subTab 1)
        OriginalDocsAndCargoXScreen(key: ValueKey('original_docs_cargox_1'), initialSubTab: 1),

        // 55: Customs Clearance Quotations & AI Extractor (Dedicated Subtab 3 in Customs Studies)
        CustomsConsultationScreen(key: ValueKey('customs_consultation_quotes_3'), initialIndex: 3),

        // 56: Customs Duty Review & Estimator Workspace (Dedicated Tax Review Mode)
        CustomsConsultationScreen(key: ValueKey('customs_duty_tax_review_56'), isTaxReviewMode: true),

        // 57: Originals Collection → Phase 4 Standalone Screen (subTab 0)
        OriginalDocsAndCargoXScreen(key: ValueKey('original_docs_cargox_0'), initialSubTab: 0),

        // 58: OriginalDocsAndCargoXScreen — default (subTab 0, Original Docs)
        OriginalDocsAndCargoXScreen(key: ValueKey('original_docs_cargox_default')),

        // 59: Production Sync & Deployment Hub (In-App Sync Utility)
        ProductionSyncScreen(),

        // 60: Drawing Samples / Shortage (subTab 1)
        CustomsClearanceScreen(key: ValueKey('customs_clearance_tab_1'), initialSubTab: 1),

        // 61: Discrepancy / Damage (subTab 2)
        CustomsClearanceScreen(key: ValueKey('customs_clearance_tab_2'), initialSubTab: 2),

        // 62: Final Customs Payment (subTab 3)
        CustomsClearanceScreen(key: ValueKey('customs_clearance_tab_3'), initialSubTab: 3),

        // 63: Goods In Transit (GIT) Inventory Ledger (Inbound Hub Tab 0)
        InboundWarehouseHubScreen(key: ValueKey('inbound_hub_git'), initialSubTab: 0),

        // 64: Warehouse Received Shipments Detailed Report (Inbound Hub Tab 2)
        InboundWarehouseHubScreen(key: ValueKey('inbound_hub_rep'), initialSubTab: 2),

        // 65: Cargo & Marine Insurance Certificate Module
        CargoInsuranceScreen(),

        // 66: Users Management & RBAC (ADMIN only)
        UsersManagementScreen(),

        // 67: Configurable Step Skip-Risk Classification & Governance (Manager Only - Section 10)
        StepConfigManagementScreen(),

        // 68: Smart Shipment Inquiry, History & Cloning (KB-INQ-013)
        ShipmentInquiryScreen(),

        // 69: System Observability, Telemetry & Health Center
        SystemObservabilityScreen(),
      ];

  bool _isSidebarCollapsed = false;
  String _searchQuery = '';

  Future<void> _toggleFullscreen() async {
    final l10n = context.l10n;
    if (!kIsWeb && Platform.isWindows) {
      try {
        final isFull = await windowManager.isFullScreen();
        await windowManager.setFullScreen(!isFull);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(!isFull ? l10n.fullscreenEnabledToast : l10n.fullscreenDisabledToast),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              width: 320,
            ),
          );
        }
      } catch (_) {}
    }
  }

  void _onNextTab() {
    ref.read(workspaceTabsProvider.notifier).selectNextTab();
  }

  void _onPreviousTab() {
    ref.read(workspaceTabsProvider.notifier).selectPreviousTab();
  }

  void _onCloseTab() async {
    final activeTab = ref.read(workspaceTabsProvider).activeTab;
    if (activeTab == null || !activeTab.isClosable) return;
    if (activeTab.isDirty) {
      final l10n = context.l10n;
      final confirmed = await UnsavedChangesDialog.show(
        context,
        customMessage: '${l10n.unsavedChangesMessage}\n(${activeTab.title})',
      );
      if (!confirmed) return;
      ref.read(workspaceTabsProvider.notifier).setTabDirty(activeTab.id, false);
    }
    ref.read(workspaceTabsProvider.notifier).closeActiveTab();
  }

  void _showShortcutsHelp() {
    KeyboardShortcutsDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    // Route guard: an account flagged must_change_password sees only the
    // password-change screen (logout allowed) until the flag is cleared.
    if (requiresPasswordChange(ref.watch(authProvider))) {
      return const ForceChangePasswordScreen();
    }
    final selectedIndex = ref.watch(navigationIndexProvider);
    final tabsState = ref.watch(workspaceTabsProvider);
    final activeTab = tabsState.activeTab;
    final currentRouteIndex = activeTab?.routeIndex ?? (selectedIndex < _screens.length ? selectedIndex : 0);
    final activeTabIndex = tabsState.tabs.indexWhere((t) => t.id == tabsState.activeTabId);
    final safeActiveTabIndex = (activeTabIndex != -1) ? activeTabIndex : 0;
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isDesktop = screenWidth >= 1200;
        final isTablet = screenWidth >= 768 && screenWidth < 1200;
        final isMobile = screenWidth < 768;

        // Auto-adapt sidebar based on responsive breakpoints:
        // - Mobile: 0 width inline, accessible via Drawer
        // - Tablet: mini icon rail (52px)
        // - Desktop: full sidebar (255px) or manually collapsed (52px)
        final bool isCollapsed = isTablet ? true : (isDesktop ? _isSidebarCollapsed : true);
        final double sidebarWidth = isMobile ? 0 : (isCollapsed ? 52 : 255);

        return CallbackShortcuts(
          bindings: {
            // Command Palette (Ctrl + K / Cmd + K)
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
                CommandPaletteDialog.show(context, ref),
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
                CommandPaletteDialog.show(context, ref),

            // Tab Navigation (Ctrl + Tab / Ctrl + Shift + Tab / Cmd + Tab)
            const SingleActivator(LogicalKeyboardKey.tab, control: true): _onNextTab,
            const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true): _onPreviousTab,
            const SingleActivator(LogicalKeyboardKey.tab, meta: true): _onNextTab,
            const SingleActivator(LogicalKeyboardKey.tab, meta: true, shift: true): _onPreviousTab,

            // Close Active Tab (Ctrl + W / Cmd + W)
            const SingleActivator(LogicalKeyboardKey.keyW, control: true): _onCloseTab,
            const SingleActivator(LogicalKeyboardKey.keyW, meta: true): _onCloseTab,

            // Focus Mode Toggle (Ctrl + Shift + F)
            const SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true): () {
              ref.read(focusModeProvider.notifier).toggle();
            },
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (ref.read(focusModeProvider)) {
                ref.read(focusModeProvider.notifier).disable();
              }
            },

            // Fullscreen Toggle (F11)
            const SingleActivator(LogicalKeyboardKey.f11): _toggleFullscreen,

            // Shortcuts Help Guide (F1 / Ctrl + / / Cmd + /)
            const SingleActivator(LogicalKeyboardKey.f1): _showShortcutsHelp,
            const SingleActivator(LogicalKeyboardKey.slash, control: true): _showShortcutsHelp,
            const SingleActivator(LogicalKeyboardKey.slash, meta: true): _showShortcutsHelp,
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
          drawer: isMobile
              ? Drawer(
                  backgroundColor: AppTheme.isDark(context)
                      ? const Color(0xFF141A22)
                      : AppTheme.charcoal,
                  child: SafeArea(
                    child: _buildFullSidebar(currentRouteIndex, user),
                  ),
                )
              : null,
          body: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axisDirection == AxisDirection.down ||
                  notification.metrics.axisDirection == AxisDirection.up ||
                  notification.metrics.axisDirection == AxisDirection.right ||
                  notification.metrics.axisDirection == AxisDirection.left) {
                final aiState = ref.read(aiAssistantProvider);
                if (!aiState.isGreetingDismissed) {
                  ref.read(aiAssistantProvider.notifier).dismissGreeting();
                }
              }
              return false;
            },
            child: Stack(
              children: [
                Row(
                  children: [
                    if (!isMobile && !ref.watch(focusModeProvider))
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        width: sidebarWidth,
                        color: AppTheme.isDark(context)
                            ? const Color(0xFF141A22)
                            : AppTheme.charcoal,
                        child: isCollapsed
                            ? _buildCollapsedRail(currentRouteIndex, user)
                            : _buildFullSidebar(currentRouteIndex, user),
                      ),

                    // Main Content View with Unified Top Bar & Multi-Tab Workspace Bar
                    Expanded(
                      child: Stack(
                        children: [
                          // Zero-size update listeners as the FIRST Stack children: their
                          // position never changes, so toggling focus mode (which adds /
                          // removes Column children) does not dispose and re-create them.
                          // Always mounted (also in focus mode): mandatory dialog, 24 h
                          // re-check and the one-time "update ready" SnackBar.
                          const UpdateNotifierHost(key: ValueKey('home_update_notifier_host')),
                          // One-time "updated to vX" / failed-update notice from /last-result.
                          const PostUpdateNotice(key: ValueKey('home_post_update_notice')),
                          Column(
                            children: [
                              if (isMobile && !ref.watch(focusModeProvider)) _buildMobileTopNav(context),
                              if (!ref.watch(focusModeProvider)) const UnifiedTopBar(),
                              if (!ref.watch(focusModeProvider)) const UpdateBanner(),
                              if (!ref.watch(focusModeProvider) && tabsState.tabs.length > 1)
                                const MultiTabWorkspaceBar(),
                              Expanded(
                                child: tabsState.tabs.isEmpty
                                    ? _screens[0]
                                    : IndexedStack(
                                        index: safeActiveTabIndex < tabsState.tabs.length
                                            ? safeActiveTabIndex
                                            : 0,
                                        children: [
                                          for (final tab in tabsState.tabs)
                                            KeyedSubtree(
                                              key: ValueKey('${tab.id}_${ref.watch(localeProvider).languageCode}'),
                                              child: _screens[tab.routeIndex < _screens.length
                                                  ? tab.routeIndex
                                                  : 0],
                                            ),
                                        ],
                                      ),
                              ),
                            ],
                          ),

                          // Floating Persistent AI Assistant Overlay (Launcher & Bubble, or Modal on <1200px)
                          if (!ref.watch(focusModeProvider))
                            const AiAssistantOverlay(),

                          // Floating Focus Mode Action Pill
                          if (ref.watch(focusModeProvider))
                            PositionedDirectional(
                              bottom: 24,
                              start: 0,
                              end: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.charcoal.withOpacity(0.92),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: AppTheme.cobalt.withOpacity(0.6), width: 1.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.35),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.fit_screen_rounded, size: 16, color: AppTheme.emerald),
                                      const SizedBox(width: 8),
                                      Text(
                                        tabsState.activeTab != null
                                            ? getLocalizedTabTitle(context, tabsState.activeTab!.routeIndex, tabsState.activeTab!.title)
                                            : (Directionality.of(context) == TextDirection.rtl ? 'وضع التركيز' : 'Focus Mode'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () => ref.read(focusModeProvider.notifier).disable(),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.close_rounded, size: 13, color: Colors.white),
                                              const SizedBox(width: 4),
                                              Text(
                                                Directionality.of(context) == TextDirection.rtl
                                                    ? 'خروج من وضع التركيز (Esc)'
                                                    : 'Exit Focus (Esc)',
                                                style: const TextStyle(color: Colors.white, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Docked Side Panel for AI Assistant on Desktop (>=1200px)
                    if (isDesktop && ref.watch(aiAssistantProvider).isPanelOpen)
                      const AiAssistantDockedPanel(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  },
);

  }



  // ─── Mobile Top Nav with Hamburger Button (<768px width) ─────────────────

  Widget _buildMobileTopNav(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A22) : AppTheme.charcoal,
        border: Border(
          bottom: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.black12, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 22),
              tooltip: l.expandSidebar,
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.cobalt,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.appTitle,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: Colors.white70,
              size: 15,
            ),
            tooltip: l.themeToggleTooltip,
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            icon: const Icon(Icons.language, color: Colors.white70, size: 15),
            tooltip: l.languageToggleTooltip,
            onPressed: () => ref.read(localeProvider.notifier).toggleLocale(),
          ),
        ],
      ),
    );
  }

  // ─── Mini Icon Rail (52px width) ───────────────────────────────────────────

  Widget _buildCollapsedRail(int selectedIndex, dynamic user) {
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    return Column(
      children: [
        const SizedBox(height: 8),
        IconButton(
          icon: const Icon(Icons.menu, color: Colors.white, size: 20),
          tooltip: context.l10n.expandSidebar,
          onPressed: () => setState(() => _isSidebarCollapsed = false),
        ),
        const Divider(color: Colors.white24, height: 10),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              _buildRailIcon(Icons.view_kanban_outlined, context.l10n.lifecycleBoard, 48, selectedIndex, AppTheme.cobalt),
              _buildRailIcon(Icons.dashboard_customize_outlined, context.l10n.operationalDashboard, 0, selectedIndex, AppTheme.emerald),
              const Divider(color: Colors.white12, height: 8),
              _buildRailIcon(Icons.analytics_outlined, context.l10n.phase1, 4, selectedIndex, Colors.amber.shade700),
              _buildRailIcon(Icons.app_registration_outlined, context.l10n.phase2, 11, selectedIndex, AppTheme.cobalt),
              _buildRailIcon(Icons.assignment_turned_in_outlined, context.l10n.phase3, 25, selectedIndex, Colors.teal),
              _buildRailIcon(Icons.verified_user_outlined, context.l10n.phase4, 54, selectedIndex, AppTheme.crimson),
              _buildRailIcon(Icons.anchor_outlined, context.l10n.phase5, 27, selectedIndex, Colors.purple),
              _buildRailIcon(Icons.inventory_outlined, context.l10n.phase6, 28, selectedIndex, AppTheme.emerald),
              const Divider(color: Colors.white12, height: 8),
              _buildRailIcon(Icons.manage_search_outlined, isArabic ? 'استعلامات' : 'Inquiries', 49, selectedIndex, Colors.indigoAccent),
              _buildRailIcon(Icons.folder_special_outlined, context.l10n.shipmentPlanning, 1, selectedIndex, Colors.cyan),
              _buildRailIcon(Icons.storage_outlined, context.l10n.masterData, 32, selectedIndex, Colors.teal),
              _buildRailIcon(Icons.summarize_outlined, context.l10n.dashboardAndReports, 47, selectedIndex, Colors.indigo),
            ],
          ),
        ),
        const Divider(color: Colors.white24, height: 8),
        const NotificationBellWidget(),
        if (EmailSettingsDialog.canAccess(user as UserModel?))
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.mail_outline_rounded, color: Colors.white70, size: 16),
          tooltip: isArabic ? 'إعدادات ومزامنة البريد الإلكتروني' : 'Email Integration & Settings',
          onPressed: () => EmailSettingsDialog.show(context),
        ),
        const SizedBox(height: 6),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            AppTheme.isDark(context) ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: Colors.white70,
            size: 16,
          ),
          tooltip: context.l10n.themeToggleTooltip,
          onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
        ),
        const SizedBox(height: 6),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 16),
          tooltip: isArabic ? 'الإعدادات الأساسية للنظام' : 'Basic System Settings',
          onPressed: () => SystemSettingsDialog.show(context),
        ),
        const SizedBox(height: 6),
        // Update state dot (hides itself when up to date).
        const UpdateIndicatorPill(compact: true),
        const SizedBox(height: 6),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 16),
          tooltip: context.l10n.systemInfoTooltip,
          onPressed: () => _showSystemInfoDialog(context),
        ),
        const SizedBox(height: 6),
        if (user != null)
          Tooltip(
            message: '${user.fullName} (${user.role})',
            child: CircleAvatar(
              backgroundColor: _getRoleColor(user.role).withOpacity(0.2),
              radius: 12,
              child: Icon(Icons.person, color: _getRoleColor(user.role), size: 14),
            ),
          ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildRailIcon(IconData icon, String tooltip, int index, int selectedIndex, Color color) {
    final isSelected = selectedIndex == index;
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: () => selectNavigationIndex(ref, index),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isSelected ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Icon(
            icon,
            size: 17,
            color: isSelected ? color : Colors.white70,
          ),
        ),
      ),
    );
  }

  // ─── Full Sidebar (235px width) ────────────────────────────────────────────

  Widget _buildFullSidebar(int selectedIndex, dynamic user) {
    final l = context.l10n;
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo & Header (Row 1: logo + title + collapse)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 4, 2),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.local_shipping_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.appTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5),
                    ),
                    Text(
                      l.appSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Collapse button only in this row
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                // Points toward the sidebar's own edge: left in LTR, right in RTL.
                icon: const DirectionalIcon(Icons.keyboard_double_arrow_left,
                    color: Colors.white70, size: 17),
                tooltip: l.collapseSidebar,
                onPressed: () => setState(() => _isSidebarCollapsed = true),
              ),
            ],
          ),
        ),
        // Action Buttons Row (Row 2: theme + lang + notifications + email)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  AppTheme.isDark(context) ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: Colors.white60,
                  size: 14,
                ),
                tooltip: l.themeToggleTooltip,
                onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: const Icon(Icons.language, color: Colors.white60, size: 14),
                tooltip: l.languageToggleTooltip,
                onPressed: () => ref.read(localeProvider.notifier).toggleLocale(),
              ),
              const NotificationBellWidget(),
              if (EmailSettingsDialog.canAccess(user as UserModel?))
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: const Icon(Icons.mail_outline_rounded, color: Colors.white60, size: 14),
                tooltip: isArabic ? 'إعدادات ومزامنة البريد الإلكتروني' : 'Email Integration & Settings',
                onPressed: () => EmailSettingsDialog.show(context),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: const Icon(Icons.settings_outlined, color: Colors.white60, size: 14),
                tooltip: isArabic ? 'الإعدادات الأساسية للنظام' : 'Basic System Settings',
                onPressed: () => SystemSettingsDialog.show(context),
              ),
            ],
          ),
        ),


        // Quick Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(5),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 11),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: l.quickSearch,
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 11),
                prefixIcon: Icon(Icons.search,
                    color: Colors.white.withOpacity(0.5), size: 14),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: Colors.white54, size: 12),
                        onPressed: () =>
                            setState(() => _searchQuery = ''),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
        ),
        const Divider(color: Colors.white24, height: 1),


        // Navigation Hubs List (Organized strictly according to Shipment Workflow & Stages)
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 2),
            children: [
              // =========================================================
              // HUB 1: MASTER DATA & REGISTRIES (البيانات والجداول الأساسية)
              // =========================================================
              _buildHubTile(
                icon: Icons.storage_outlined,
                titleEn: 'Master Data & Tables',
                titleAr: 'البيانات والجداول الأساسية',
                color: Colors.teal,
                initiallyExpanded: false,
                children: [
                  _buildMenuItem(Icons.domain_outlined, 'Import Companies', 'الشركات المستوردة', 32, selectedIndex),
                  _buildMenuItem(Icons.business_outlined, 'Foreign Suppliers', 'دليل الموردين الأجانب', 33, selectedIndex),
                  _buildMenuItem(Icons.account_balance_outlined, 'Partners & Banks', 'الشركاء والبنوك ومقدمو الخدمات', 34, selectedIndex),
                  _buildMenuItem(Icons.assignment_outlined, 'Projects & Cost Centers', 'المشاريع ومراكز التكلفة', 31, selectedIndex),
                  _buildMenuItem(Icons.location_on_outlined, 'Ports & Locations', 'الموانئ والمنافذ الجمركية', 37, selectedIndex),
                  _buildMenuItem(Icons.handshake_outlined, 'Incoterms Rules', 'الشروط التجارية الدولية', 35, selectedIndex),
                  _buildMenuItem(Icons.description_outlined, 'Customs Tariff & HS Explorer', 'جدول ومستكشف التعريفة الجمركية', 36, selectedIndex),
                  _buildMenuItem(Icons.currency_exchange_outlined, 'Currencies & Rates', 'العملات وأسعار الصرف', 38, selectedIndex),
                ],
              ),

              // =========================================================
              // HUB 2: SHIPMENT PLANNING & SOURCING (ملفات وأوامر الشراء)
              // =========================================================
              _buildHubTile(
                icon: Icons.folder_special_outlined,
                titleEn: 'Shipment Planning',
                titleAr: 'تخطيط الشحنة وأوامر الشراء',
                color: Colors.cyan,
                initiallyExpanded: false,
                children: [
                  _buildMenuItem(Icons.folder_special_outlined, 'Import Files', 'ملفات الشحنات الاستيرادية', 1, selectedIndex),
                  _buildMenuItem(Icons.shopping_cart_outlined, 'Purchase Orders & Origin', 'أوامر الشراء وإثبات المنشأ', 2, selectedIndex),
                ],
              ),

              // =========================================================
              // PHASE 1: PRE-PLANNING & STUDIES (التخطيط والدراسات المسبقة)
              // =========================================================
              _buildHubTile(
                icon: Icons.analytics_outlined,
                titleEn: '1. Pre-Planning & Studies',
                titleAr: 'المرحلة 1: التخطيط والدراسات المسبقة',
                color: Colors.amber.shade800,
                initiallyExpanded: false,
                children: [
                  _buildMenuItem(Icons.analytics_outlined, 'Freight Studies & Saved Log', 'دراسة النولون والجدول الزمني والسجلات المحفوظة', 4, selectedIndex),
                  _buildMenuItem(Icons.gavel_outlined, 'Customs Studies & Clearance RFQ', 'الدراسات الجمركية وعروض التخليص ومراجعة الضرائب', 6, selectedIndex),
                  _buildMenuItem(Icons.verified_outlined, 'Import Regulatory Requirements', 'متطلبات واشتراطات الاستيراد للشحنة', 43, selectedIndex),
                ],
              ),

              // =========================================================
              // PHASE 2: SHIPMENT INITIATION (بداية الشحنة والتسجيل المسبق)
              // =========================================================
              _buildHubTile(
                icon: Icons.app_registration_outlined,
                titleEn: '2. Shipment Initiation',
                titleAr: 'المرحلة 2: بداية الشحنة والتسجيل المسبق',
                color: AppTheme.cobalt,
                initiallyExpanded: false,
                children: [
                  _buildMenuItem(Icons.account_balance_wallet_outlined, 'Finance Approvals & Budget', 'اعتمادات الميزانية وسداد الموردين', 8, selectedIndex),
                  _buildMenuItem(Icons.qr_code_2_outlined, 'ACID Operations', 'الرقم التعريفي المبدئي للشحنة ACID', 11, selectedIndex),
                ],
              ),

              // =========================================================
              // PHASE 3: BOOKING & DOC PREPARATION (حجز الشحن والتدقيق المبدئي)
              // =========================================================
              _buildHubTile(
                icon: Icons.assignment_turned_in_outlined,
                titleEn: '3. Booking & Doc Prep',
                titleAr: 'المرحلة 3: حجز الشحن والتدقيق المستندي المبدئي',
                color: Colors.teal,
                initiallyExpanded: false,
                children: [
                  _buildMenuItem(Icons.bookmark_added_outlined, 'Freight Booking', 'حجز النولون وتأكيد الخط الملاحي', 25, selectedIndex),
                  _buildMenuItem(Icons.directions_boat_outlined, 'Cargo Shipping & Tracking', 'حركة وتتبع الشحن وتوزيع الحاويات', 26, selectedIndex),
                  _buildMenuItem(Icons.shield_outlined, 'Cargo Insurance', 'شهادات ووثائق التأمين على البضائع', 65, selectedIndex),
                  _buildMenuItem(Icons.fact_check_outlined, '1. PO & Packing Reconciliation', '1. مطابقة الفاتورة والباكينج مع أمر الشراء', 21, selectedIndex),
                  _buildMenuItem(Icons.assignment_turned_in_outlined, '2. Draft B/L Review & Approval', '2. مراجعة واعتماد مسودة بوليصة الشحن', 18, selectedIndex),
                  _buildMenuItem(Icons.auto_awesome, '3. Smart Invoice vs B/L Match', '3. المطابقة الذكية بين الفاتورة والبوليصة', 22, selectedIndex),
                  _buildMenuItem(Icons.flag_circle_outlined, '4. Draft COO & EUR.1 Review', '4. مسودة شهادة المنشأ و EUR.1', 19, selectedIndex),
                  _buildMenuItem(Icons.security_outlined, '5. Inspection Review (COC)', '5. شهادات الفحص والتفتيش والمطابقة', 53, selectedIndex),
                  _buildMenuItem(Icons.verified_user_outlined, '6. Docs Customs Approval Hub', '6. مركز اعتماد المستندات وتعديلات المورد', 20, selectedIndex),
                  _buildMenuItem(Icons.inventory_2_outlined, 'Central Docs & Rectifications Hub', 'الأرشيف المركزي لمستندات وتعديلات الشحنة', 51, selectedIndex),
                ],
              ),

              // =========================================================
              // PHASE 4: DIGITAL & BANKING (التوثيق الرقمي والاعتماد البنكي)
              // =========================================================
              _buildHubTile(
                icon: Icons.verified_user_outlined,
                titleEn: '4. Digital & Banking',
                titleAr: 'المرحلة 4: التوثيق الرقمي والاعتماد البنكي',
                color: AppTheme.crimson,
                initiallyExpanded: false,
                children: [
                  _buildMenuItem(Icons.cloud_upload_outlined, 'Original Docs & CargoX Hub', 'أصول المستندات ومنظومة CargoX الرقمية', 54, selectedIndex),
                  _buildMenuItem(Icons.account_balance_outlined, 'Bank Form 4', 'النموذج الإحصائي والتحويل البنكي نموذج 4', 16, selectedIndex),
                ],
              ),

              // =========================================================
              // PHASE 5: PORT & CLEARANCE (الميناء والتخليص الجمركي)
              // =========================================================
              _buildHubTile(
                icon: Icons.anchor_outlined,
                titleEn: '5. Port & Clearance',
                titleAr: 'المرحلة 5: الميناء والتخليص الجمركي',
                color: Colors.purple,
                initiallyExpanded: false,
                children: [
                  _buildMenuItem(Icons.description_outlined, 'Customs Declaration 46', 'شهادة الإجراءات الجمركية إقرار 46 ك.م', 23, selectedIndex),
                  _buildMenuItem(Icons.fact_check_outlined, 'Customs Clearance Hub', 'متابعة التخليص والكشف والعينات والرسوم', 27, selectedIndex),
                  _buildMenuItem(Icons.timer_outlined, 'Demurrage & Detention', 'تتبع غرامات الأرضيات وحراسات الحاويات', 44, selectedIndex),
                ],
              ),

              // =========================================================
              // PHASE 6: INBOUND & CLOSURE (الاستلام والتسوية المالية)
              // =========================================================
              _buildHubTile(
                icon: Icons.inventory_outlined,
                titleEn: '6. Inbound & Closure',
                titleAr: 'المرحلة 6: الاستلام المخزني والتسوية المالية',
                color: AppTheme.emerald,
                initiallyExpanded: false,
                children: [
                  _buildMenuItem(Icons.warehouse_outlined, 'Inbound & Warehouse Hub', 'مركز الاستلام والمخازن والبضاعة بالطريق', 28, selectedIndex),
                  _buildMenuItem(Icons.price_check_outlined, 'Landed Cost & Settlement Hub', 'تكلفة الوصول والتسوية المالية ومقارنة الفروق', 29, selectedIndex),
                  _buildMenuItem(Icons.task_alt_outlined, 'Import File Final Closure', 'الإغلاق المالي والإداري لملف الاستيراد', 30, selectedIndex),
                ],
              ),

              // =========================================================
              // HUB: INQUIRIES & TOOLS (استعلامات)
              // =========================================================
              _buildHubTile(
                icon: Icons.manage_search_outlined,
                titleEn: 'Inquiries',
                titleAr: 'استعلامات',
                color: Colors.indigoAccent,
                initiallyExpanded: false,
                children: [
                  _buildMenuItem(Icons.travel_explore_rounded, 'Shipment History & Inquiry', 'استعلام وسجل الشحنات والتكاليف التاريخية', 68, selectedIndex),
                  _buildMenuItem(Icons.request_quote_outlined, 'Freight RFQ & Quotations Comparison', 'طلب ومقارنة عروض النولون والترسية', 49, selectedIndex),
                  _buildMenuItem(Icons.calculate_outlined, 'Cargo Measurement Engine', 'حاسبة الأحجام وتوزيع الحاويات (CBM)', 3, selectedIndex),
                ],
              ),

              // =========================================================
              // HUB 3: DASHBOARDS & AUDIT (لوحات القيادة والتقارير الرقابية)
              // =========================================================
              _buildHubTile(
                icon: Icons.analytics_outlined,
                titleEn: 'Dashboard & Reports',
                titleAr: 'لوحة القيادة والتقارير والرقابة',
                color: Colors.blueGrey,
                initiallyExpanded: false,
                children: [
                  _buildMenuItem(Icons.dashboard_customize_outlined, 'Operational Dashboard', 'لوحة التحكم ومؤشرات الأداء', 0, selectedIndex),
                  _buildMenuItem(Icons.view_kanban_outlined, 'Lifecycle Operations Board', 'لوحة تتبع ومراحل الشحنات التفاعلية', 48, selectedIndex),
                  _buildMenuItem(Icons.summarize_outlined, 'Master Shipment Report', 'تقرير الشحنة الشامل المدمج', 47, selectedIndex),
                  _buildMenuItem(Icons.assessment_outlined, 'Dynamic Report Builder', 'مُنشئ التقارير المخصصة', 41, selectedIndex),
                  _buildMenuItem(Icons.published_with_changes_outlined, 'Quick Update Engine', 'محرك التحديث السريع', 42, selectedIndex),
                  _buildMenuItem(Icons.task_alt_outlined, 'Smart Tasks & Alerts', 'المهام والتنبيهات الذكية', 40, selectedIndex),
                  _buildActionMenuItem(
                    icon: Icons.mark_email_read_outlined,
                    titleEn: 'Smart Email & Inbox Listener',
                    titleAr: 'المستمع الذكي للبريد وإشعارات الوصول',
                    color: AppTheme.cobalt,
                    onTap: () => SmartEmailListenerDialog.show(context),
                  ),
                  // Email server settings — admin only (backend returns 403 otherwise)
                  if (EmailSettingsDialog.canAccess(user))
                  _buildActionMenuItem(
                    icon: Icons.settings_suggest_rounded,
                    titleEn: 'Email Server Settings (IMAP/SMTP)',
                    titleAr: 'إعدادات ربط البريد (IMAP/SMTP)',
                    color: Colors.cyanAccent.shade700,
                    onTap: () => EmailSettingsDialog.show(context),
                  ),
                  _buildMenuItem(Icons.history_edu_outlined, 'System Audit Logs', 'سجل التدقيق والرقابة', 39, selectedIndex),
                  _buildMenuItem(Icons.sync_alt_rounded, 'Production Sync Hub', 'مركز مزامنة وتحديث الإنتاج', 59, selectedIndex),
                  // Users Management & RBAC — ADMIN and MANAGER
                  if (user == null || user.isAdmin || user.isManager)
                    _buildMenuItem(Icons.manage_accounts_rounded, 'Users & Permissions', 'إدارة المستخدمين والصلاحيات', 66, selectedIndex),
                  // Step Skip-Risk Classification Settings — Manager / Admin only (Section 10.7)
                  if (user != null && user.canManageStepConfig)
                    _buildMenuItem(Icons.admin_panel_settings_rounded, 'Step Risk & Skip Config', 'إعدادات تصنيف مخاطر المراحل وحوكمة التخطي', 67, selectedIndex),
                  // System Observability, Telemetry & Health Center — ADMIN and MANAGER
                  if (user == null || user.isAdmin || user.isManager)
                    _buildMenuItem(Icons.monitor_heart_outlined, 'System Observability & Health', 'مركز مراقبة وصحة النظام', 69, selectedIndex),
                ],
              ),
            ],
          ),
        ),

        const Divider(color: Colors.white24, height: 1),

        // User Profile & RBAC Footer
        if (user != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.black.withOpacity(0.15),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(user.role).withOpacity(0.2),
                  radius: 13,
                  child: Icon(Icons.person, color: _getRoleColor(user.role), size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.role,
                        style: TextStyle(color: _getRoleColor(user.role), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 16),
                  tooltip: l.userOptions,
                  onSelected: (val) {
                    if (val == 'LOGOUT') {
                      ref.read(authProvider.notifier).logout();
                    } else {
                      ref.read(authProvider.notifier).switchDemoRole(val);
                    }
                  },
                  itemBuilder: (ctx) => [
                    // Demo role switching is a debug-only development aid.
                    if (kDebugMode) ...[
                      PopupMenuItem(value: 'ADMIN', child: Text(l.switchAsAdmin)),
                      PopupMenuItem(value: 'MANAGER', child: Text(l.switchAsManager)),
                      PopupMenuItem(value: 'OPERATOR', child: Text(l.switchAsSpecialist)),
                      const PopupMenuDivider(),
                    ],
                    PopupMenuItem(
                      value: 'LOGOUT',
                      child: Row(
                        children: [
                          const Icon(Icons.logout, color: AppTheme.crimson, size: 16),
                          const SizedBox(width: 8),
                          Text(l.logout, style: const TextStyle(color: AppTheme.crimson)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // System Version & Port Status Footer
        InkWell(
          onTap: () => _showSystemInfoDialog(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.black.withOpacity(0.28),
            child: Consumer(
              builder: (context, r, _) {
                final versionAsync = r.watch(systemVersionInfoProvider);
                final versionText = versionAsync.when(
                  data: (info) => 'v${info.version} (Build ${info.buildNumber})',
                  loading: () => 'v... (Loading)',
                  error: (_, __) => 'v${ApiConstants.clientVersion} (Build ${ApiConstants.clientBuildNumber})',
                );
                final versionRow = Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.verified_outlined, color: AppTheme.cobalt, size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              versionText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.emerald.withOpacity(0.4), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: AppTheme.emerald, size: 5),
                          SizedBox(width: 3.5),
                          Text(
                            'Port: 28080',
                            style: TextStyle(color: AppTheme.emerald, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Always-visible update state (hides itself, gap included, when up to date).
                    const UpdateIndicatorPill(padding: EdgeInsetsDirectional.only(bottom: 5)),
                    versionRow,
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return AppTheme.crimson;
      case 'MANAGER':
        return AppTheme.cobalt;
      case 'OPERATOR':
        return AppTheme.emerald;
      default:
        return Colors.grey;
    }
  }

  Widget _buildHubTile({
    required IconData icon,
    required String titleEn,
    required String titleAr,
    required Color color,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    final isSearching = _searchQuery.isNotEmpty;
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final title = isArabic ? titleAr : titleEn;

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        hoverColor: const Color(0x0AFFFFFF),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0x0DFFFFFF)),
        ),
        child: Material(
          color: const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(6),
          child: ExpansionTile(
            key: isSearching ? UniqueKey() : null,
            initiallyExpanded: isSearching ? true : initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            childrenPadding: const EdgeInsets.only(bottom: 2),
            leading: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Color.fromRGBO(
                    color.red, color.green, color.blue, 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            iconColor: color,
            collapsedIconColor: Colors.white54,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String titleEn, String titleAr,
      int index, int selectedIndex) {
    // Filter by search (both EN and AR)
    if (_searchQuery.isNotEmpty &&
        !titleEn.toLowerCase().contains(_searchQuery) &&
        !titleAr.toLowerCase().contains(_searchQuery)) {
      return const SizedBox.shrink();
    }

    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final density = ref.watch(displayDensityProvider);
    final title = isArabic ? titleAr : titleEn;
    final isSelected = selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: isSelected
            ? const BorderDirectional(start: BorderSide(color: AppTheme.cobalt, width: 3))
            : null,
      ),
      child: Material(
        color: isSelected ? AppTheme.cobaltMedium : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => selectNavigationIndex(ref, index),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 6,
              vertical: density == DisplayDensityMode.ultraCompact ? 4 : 6,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: density == DisplayDensityMode.ultraCompact ? 13.0 : 14.0,
                  color: isSelected
                      ? AppTheme.cobalt
                      : const Color(0xCCECF0F1), // cloudWhite 80%
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.cloudWhite,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: density.sidebarNavFontSize,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionMenuItem({
    required IconData icon,
    required String titleEn,
    required String titleAr,
    required VoidCallback onTap,
    Color? color,
  }) {
    if (_searchQuery.isNotEmpty &&
        !titleEn.toLowerCase().contains(_searchQuery) &&
        !titleAr.toLowerCase().contains(_searchQuery)) {
      return const SizedBox.shrink();
    }

    final density = ref.watch(displayDensityProvider);
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final title = isArabic ? titleAr : titleEn;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 6,
              vertical: density == DisplayDensityMode.ultraCompact ? 4 : 6,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: density == DisplayDensityMode.ultraCompact ? 13.0 : 14.0,
                  color: color ?? const Color(0xCCECF0F1),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color ?? AppTheme.cloudWhite,
                      fontWeight: FontWeight.w600,
                      fontSize: density.sidebarNavFontSize,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  void _showSystemInfoDialog(BuildContext context) {
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, r, _) {
          final versionAsync = r.watch(systemVersionInfoProvider);
          final version = versionAsync.whenOrNull(data: (i) => i.version) ?? ApiConstants.clientVersion;
          final buildNum = versionAsync.whenOrNull(data: (i) => i.buildNumber) ?? ApiConstants.clientBuildNumber;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppTheme.charcoal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_shipping_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.appTitle,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        Text(
                          l.appSubtitle,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoRow(Icons.verified, l.systemVersion, 'v$version (Release)'),
                  const Divider(height: 14),
                  _buildInfoRow(Icons.build_circle_outlined, l.buildId, 'Build $version+$buildNum'),
                  const Divider(height: 14),
                  _buildInfoRow(Icons.dns_outlined, l.backendEngine, 'FastAPI (Port 28080)'),
                  const Divider(height: 14),
                  _buildInfoRow(Icons.storage_outlined, l.database, 'SQLite (sorour_logistics.db)'),
                  const Divider(height: 14),
                  _buildInfoRow(Icons.offline_pin_outlined, l.operatingMode,
                      'Standalone Offline / Local Engine'),
                  const Divider(height: 14),
                  _buildInfoRow(Icons.shield_outlined, l.licenseAndRights,
                      '© 2026 Sorour Logistics. All rights reserved.'),
                  const Divider(height: 20),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l.updateAboutSectionTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const AppUpdatePanel(),
                ],
                ),
              ),
            ),
            actionsPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            actions: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: Text(l.syncHub,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ProductionSyncHubDialog.show(context);
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l.close,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }


  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.cobalt),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 11.5, color: Colors.black87, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
