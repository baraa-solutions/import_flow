import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/workspace_tabs_provider.dart';
import '../theme/app_theme.dart';
import '../theme/density_provider.dart';
import '../../features/home/widgets/multi_tab_workspace_bar.dart';
import 'global_header_shortcuts_bar.dart';
import 'system_live_clock_widget.dart';

/// Unified single-row top application header for ImportFlow ERP.
/// Consolidates global shortcuts, live international world clocks, breadcrumbs,
/// and density controls into a single streamlined row (32px - 44px height),
/// recovering massive vertical screen real estate for data tables.
class UnifiedTopBar extends ConsumerWidget {
  const UnifiedTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = ref.watch(displayDensityProvider);
    final tabsState = ref.watch(workspaceTabsProvider);
    final isDark = AppTheme.isDark(context);
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    final activeTab = tabsState.activeTab;
    final activeTitle = activeTab != null
        ? getLocalizedTabTitle(context, activeTab.routeIndex, activeTab.title)
        : (isArabic ? 'لوحة التحكم' : 'Dashboard');

    return Container(
      width: double.infinity,
      height: density.topBarHeight,
      padding: EdgeInsets.symmetric(
        horizontal: density.isUltraCompact ? 8 : (density.isCompact ? 10 : 12),
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A22) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. App Branding (Icon + System Name)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(density.isUltraCompact ? 2.5 : 3.5),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  Icons.local_shipping_rounded,
                  size: density.isUltraCompact ? 13 : 15,
                  color: AppTheme.cobalt,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'ImportFlow',
                style: TextStyle(
                  fontSize: density.isUltraCompact ? 11.5 : 12.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.charcoal,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),

          const SizedBox(width: 6),
          Container(
            height: 14,
            width: 1,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          const SizedBox(width: 6),

          // 2. Active Screen Breadcrumbs: الرئيسية / [اسم الصفحة]
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    ref.read(workspaceTabsProvider.notifier).selectTab('dashboard');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                    child: Text(
                      isArabic ? 'الرئيسية' : 'Home',
                      style: TextStyle(
                        fontSize: density.isUltraCompact ? 10.5 : 11.5,
                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (activeTab != null && activeTab.id != 'dashboard') ...[
                  Text(
                    ' / ',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      activeTitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: density.isUltraCompact ? 10.5 : 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.cobaltLight : AppTheme.cobalt,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 6),
          Container(
            height: 14,
            width: 1,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          const SizedBox(width: 6),

          // 3. Smart World Clock Dropdown Button
          const WorldClockDropdownButton(),

          const SizedBox(width: 6),
          Container(
            height: 14,
            width: 1,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          const SizedBox(width: 4),

          // 4. Quick Actions Toolbar (Commands, Email, Lang, Theme, Density, Focus Mode, F1, F11)
          const Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
              child: GlobalHeaderShortcutsBar(),
            ),
          ),

          const SizedBox(width: 4),

          // 5. Live Sync Beacon
          Tooltip(
            message: isArabic
                ? 'متزامن مع التوقيت العالمي بنظام 24 ساعة'
                : 'Synchronized with 24-Hour Universal Live Time',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.emerald,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.emerald.withValues(alpha: 0.6),
                        blurRadius: 3,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  '24H LIVE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}
