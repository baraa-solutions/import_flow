import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/system_settings_dialog.dart';
import '../../app_update/widgets/update_indicator_pill.dart';
import '../../auth/models/user_model.dart';
import '../../notifications/widgets/notification_bell_widget.dart';
import '../../smart_tasks/widgets/email_settings_dialog.dart';
import 'home_system_info_dialog.dart';

Color getRoleColor(String role) {
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

class HomeCollapsedRail extends ConsumerWidget {
  final int selectedIndex;
  final UserModel? user;
  final VoidCallback onExpandSidebar;

  const HomeCollapsedRail({
    super.key,
    required this.selectedIndex,
    required this.user,
    required this.onExpandSidebar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';

    return Column(
      children: [
        const SizedBox(height: 8),
        IconButton(
          icon: const Icon(Icons.menu, color: Colors.white, size: 20),
          tooltip: l.expandSidebar,
          onPressed: onExpandSidebar,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Tooltip(
            message: l.appTitle,
            child: Image.asset(
              'assets/brand/sorour_logo_icon.png',
              width: 26,
              height: 26,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const Divider(color: Colors.white24, height: 10),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              _buildRailIcon(ref, Icons.view_kanban_outlined, l.lifecycleBoard, 48, selectedIndex, AppTheme.cobalt),
              _buildRailIcon(ref, Icons.dashboard_customize_outlined, l.operationalDashboard, 0, selectedIndex, AppTheme.emerald),
              const Divider(color: Colors.white12, height: 8),
              _buildRailIcon(ref, Icons.analytics_outlined, l.phase1, 4, selectedIndex, Colors.amber.shade700),
              _buildRailIcon(ref, Icons.app_registration_outlined, l.phase2, 11, selectedIndex, AppTheme.cobalt),
              _buildRailIcon(ref, Icons.assignment_turned_in_outlined, l.phase3, 25, selectedIndex, Colors.teal),
              _buildRailIcon(ref, Icons.verified_user_outlined, l.phase4, 54, selectedIndex, AppTheme.crimson),
              _buildRailIcon(ref, Icons.anchor_outlined, l.phase5, 27, selectedIndex, Colors.purple),
              _buildRailIcon(ref, Icons.inventory_outlined, l.phase6, 28, selectedIndex, AppTheme.emerald),
              const Divider(color: Colors.white12, height: 8),
              _buildRailIcon(ref, Icons.manage_search_outlined, isArabic ? 'استعلامات' : 'Inquiries', 49, selectedIndex, Colors.indigoAccent),
              _buildRailIcon(ref, Icons.folder_special_outlined, l.shipmentPlanning, 1, selectedIndex, Colors.cyan),
              _buildRailIcon(ref, Icons.storage_outlined, l.masterData, 32, selectedIndex, Colors.teal),
              _buildRailIcon(ref, Icons.summarize_outlined, l.dashboardAndReports, 47, selectedIndex, Colors.indigo),
            ],
          ),
        ),
        const Divider(color: Colors.white24, height: 8),
        const NotificationBellWidget(),
        if (EmailSettingsDialog.canAccess(user))
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
          tooltip: l.themeToggleTooltip,
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
        const UpdateIndicatorPill(compact: true),
        const SizedBox(height: 6),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 16),
          tooltip: l.systemInfoTooltip,
          onPressed: () => HomeSystemInfoDialog.show(context),
        ),
        const SizedBox(height: 6),
        if (user != null)
          Tooltip(
            message: '${user!.fullName} (${user!.role})',
            child: CircleAvatar(
              backgroundColor: getRoleColor(user!.role).withValues(alpha: 0.2),
              radius: 12,
              child: Icon(Icons.person, color: getRoleColor(user!.role), size: 14),
            ),
          ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildRailIcon(WidgetRef ref, IconData icon, String tooltip, int index, int selectedIndex, Color color) {
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
            color: isSelected ? color.withValues(alpha: 0.3) : Colors.transparent,
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
}
