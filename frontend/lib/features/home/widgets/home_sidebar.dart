import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/directional_icon.dart';
import '../../../core/widgets/system_settings_dialog.dart';
import '../../app_update/widgets/update_indicator_pill.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/widgets/notification_bell_widget.dart';
import '../../production_sync/providers/production_sync_provider.dart';
import '../../smart_tasks/widgets/email_settings_dialog.dart';
import 'home_collapsed_rail.dart';
import 'home_sidebar_nav_list.dart';
import 'home_system_info_dialog.dart';

class HomeSidebar extends ConsumerStatefulWidget {
  final int selectedIndex;
  final UserModel? user;
  final VoidCallback onCollapse;

  const HomeSidebar({
    super.key,
    required this.selectedIndex,
    required this.user,
    required this.onCollapse,
  });

  @override
  ConsumerState<HomeSidebar> createState() => _HomeSidebarState();
}

class _HomeSidebarState extends ConsumerState<HomeSidebar> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final user = widget.user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 4, 2),
          child: Row(
            children: [
              Image.asset('assets/brand/sorour_logo_dark.png', height: 32, fit: BoxFit.contain),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.appTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                    Text(l.appSubtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const DirectionalIcon(Icons.keyboard_double_arrow_left, color: Colors.white70, size: 17),
                tooltip: l.collapseSidebar,
                onPressed: widget.onCollapse,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(AppTheme.isDark(context) ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: Colors.white60, size: 14),
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
              if (EmailSettingsDialog.canAccess(user)) ...[
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
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(5),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 11),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: l.quickSearch,
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5), size: 14),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, color: Colors.white54, size: 12), onPressed: () => setState(() => _searchQuery = ''))
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
        ),
        const Divider(color: Colors.white24, height: 1),
        Expanded(
          child: HomeSidebarNavList(
            searchQuery: _searchQuery,
            selectedIndex: widget.selectedIndex,
            user: user,
          ),
        ),
        const Divider(color: Colors.white24, height: 1),
        if (user != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.black.withValues(alpha: 0.15),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: getRoleColor(user.role).withValues(alpha: 0.2),
                  radius: 13,
                  child: Icon(Icons.person, color: getRoleColor(user.role), size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(user.role, style: TextStyle(color: getRoleColor(user.role), fontSize: 11, fontWeight: FontWeight.bold)),
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
        InkWell(
          onTap: () => HomeSystemInfoDialog.show(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.black.withValues(alpha: 0.28),
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
                        color: AppTheme.emerald.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, color: AppTheme.emerald, size: 5),
                          const SizedBox(width: 3.5),
                          Text('Port: ${ApiConstants.serverPort}', style: const TextStyle(color: AppTheme.emerald, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
}
