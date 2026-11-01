import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/providers/ai_assistant_provider.dart';
import '../../core/providers/focus_mode_provider.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/providers/workspace_tabs_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ai_assistant_panel.dart';
import '../../core/widgets/command_palette_dialog.dart';
import '../../core/widgets/keyboard_shortcuts_dialog.dart';
import '../../core/widgets/unified_top_bar.dart';
import '../../core/widgets/unsaved_changes_dialog.dart';
import '../app_update/widgets/post_update_notice.dart';
import '../app_update/widgets/update_banner.dart';
import '../app_update/widgets/update_notifier_host.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/providers/auth_route_guard.dart';
import '../auth/screens/force_change_password_screen.dart';
import 'widgets/home_collapsed_rail.dart';
import 'widgets/home_mobile_top_nav.dart';
import 'widgets/home_screen_registry.dart';
import 'widgets/home_sidebar.dart';
import 'widgets/multi_tab_workspace_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final List<Widget> _screens = kHomeScreenRegistry;
  bool _isSidebarCollapsed = false;

  Future<void> _toggleFullscreen() async {
    final l10n = context.l10n;
    if (!kIsWeb && Platform.isWindows) {
      try {
        final isFull = await windowManager.isFullScreen();
        await windowManager.setFullScreen(!isFull);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, !isFull ? l10n.fullscreenEnabledToast : l10n.fullscreenDisabledToast),
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

        final bool isCollapsed = isTablet ? true : (isDesktop ? _isSidebarCollapsed : true);
        final double sidebarWidth = isMobile ? 0 : (isCollapsed ? 52 : 255);

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => CommandPaletteDialog.show(context, ref),
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => CommandPaletteDialog.show(context, ref),
            const SingleActivator(LogicalKeyboardKey.tab, control: true): _onNextTab,
            const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true): _onPreviousTab,
            const SingleActivator(LogicalKeyboardKey.tab, meta: true): _onNextTab,
            const SingleActivator(LogicalKeyboardKey.tab, meta: true, shift: true): _onPreviousTab,
            const SingleActivator(LogicalKeyboardKey.keyW, control: true): _onCloseTab,
            const SingleActivator(LogicalKeyboardKey.keyW, meta: true): _onCloseTab,
            const SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true): () => ref.read(focusModeProvider.notifier).toggle(),
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (ref.read(focusModeProvider)) ref.read(focusModeProvider.notifier).disable();
            },
            const SingleActivator(LogicalKeyboardKey.f11): _toggleFullscreen,
            const SingleActivator(LogicalKeyboardKey.f1): _showShortcutsHelp,
            const SingleActivator(LogicalKeyboardKey.slash, control: true): _showShortcutsHelp,
            const SingleActivator(LogicalKeyboardKey.slash, meta: true): _showShortcutsHelp,
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              drawer: isMobile
                  ? Drawer(
                      backgroundColor: AppTheme.isDark(context) ? const Color(0xFF141A22) : AppTheme.charcoal,
                      child: SafeArea(
                        child: HomeSidebar(
                          selectedIndex: currentRouteIndex,
                          user: user,
                          onCollapse: () => Navigator.of(context).pop(),
                        ),
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
                            color: AppTheme.isDark(context) ? const Color(0xFF141A22) : AppTheme.charcoal,
                            child: isCollapsed
                                ? HomeCollapsedRail(
                                    selectedIndex: currentRouteIndex,
                                    user: user,
                                    onExpandSidebar: () => setState(() => _isSidebarCollapsed = false),
                                  )
                                : HomeSidebar(
                                    selectedIndex: currentRouteIndex,
                                    user: user,
                                    onCollapse: () => setState(() => _isSidebarCollapsed = true),
                                  ),
                          ),
                        Expanded(
                          child: Stack(
                            children: [
                              const UpdateNotifierHost(key: ValueKey('home_update_notifier_host')),
                              const PostUpdateNotice(key: ValueKey('home_post_update_notice')),
                              Column(
                                children: [
                                  if (isMobile && !ref.watch(focusModeProvider)) const HomeMobileTopNav(),
                                  if (!ref.watch(focusModeProvider)) const UnifiedTopBar(),
                                  if (!ref.watch(focusModeProvider)) const UpdateBanner(),
                                  if (!ref.watch(focusModeProvider) && tabsState.tabs.length > 1)
                                    const MultiTabWorkspaceBar(),
                                  Expanded(
                                    child: SelectionArea(
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: IgnorePointer(
                                              child: ExcludeSemantics(
                                                child: Center(
                                                  child: Opacity(
                                                    opacity: AppTheme.isDark(context) ? 0.035 : 0.045,
                                                    child: Image.asset(
                                                      'assets/brand/sorour_logo_watermark.png',
                                                      width: isMobile ? 260 : 450,
                                                      fit: BoxFit.contain,
                                                      filterQuality: FilterQuality.medium,
                                                      cacheWidth: 900,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          tabsState.tabs.isEmpty
                                              ? _screens[0]
                                              : IndexedStack(
                                                  index: safeActiveTabIndex < tabsState.tabs.length ? safeActiveTabIndex : 0,
                                                  children: [
                                                    for (final tab in tabsState.tabs)
                                                      KeyedSubtree(
                                                        key: ValueKey('${tab.id}_${ref.watch(localeProvider).languageCode}'),
                                                        child: _screens[tab.routeIndex < _screens.length ? tab.routeIndex : 0],
                                                      ),
                                                  ],
                                                ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (!ref.watch(focusModeProvider)) const AiAssistantOverlay(),
                              if (ref.watch(focusModeProvider))
                                PositionedDirectional(
                                  bottom: 24,
                                  start: 0,
                                  end: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.charcoal.withValues(alpha: 0.92),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.6), width: 1.0),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.35),
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
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 12),
                                          InkWell(
                                            borderRadius: BorderRadius.circular(14),
                                            onTap: () => ref.read(focusModeProvider.notifier).disable(),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.close_rounded, size: 13, color: Colors.white),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    Directionality.of(context) == TextDirection.rtl ? 'خروج من وضع التركيز (Esc)' : 'Exit Focus (Esc)',
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
                        if (isDesktop && ref.watch(aiAssistantProvider).isPanelOpen) const AiAssistantDockedPanel(),
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
}
