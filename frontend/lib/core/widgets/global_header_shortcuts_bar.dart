import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../localization/app_localizations.dart';
import '../localization/app_localizations_ar.dart';
import '../localization/locale_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../../features/smart_tasks/widgets/smart_email_listener_dialog.dart';
import '../../features/smart_tasks/widgets/email_settings_dialog.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../providers/focus_mode_provider.dart';
import 'ai_assistant_top_bar_button.dart';
import 'command_palette_dialog.dart';
import 'display_density_selector.dart';
import 'keyboard_shortcuts_dialog.dart';
import 'system_settings_dialog.dart';

/// Centralized quick shortcut actions toolbar.
/// Displayed in the top system header row next to the live date and week badge,
/// freeing up the entire MultiTabWorkspaceBar exclusively for open screen tabs.
class GlobalHeaderShortcutsBar extends ConsumerWidget {
  const GlobalHeaderShortcutsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = AppTheme.isDark(context);
    final isArabic = l10n is AppLocalizationsAr;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Command Palette Quick Action Pill (Ctrl + K)
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => CommandPaletteDialog.show(context, ref),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2631) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.travel_explore_rounded,
                  size: 14,
                  color: isDark ? AppTheme.cobaltLight : AppTheme.cobalt,
                ),
                const SizedBox(width: 4),
                Text(
                  isArabic ? 'الأوامر' : 'Commands',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade300 : AppTheme.charcoal,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Ctrl+K',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.cobaltLight : AppTheme.cobalt,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),

        // 2. AI Smart Import Assistant Quick Action (Moved from bottom-right overlay, downsized)
        const AiAssistantTopBarButton(),
        const SizedBox(width: 2),

        // 3. Smart Email Listener Quick Action
        IconButton(
          tooltip: isArabic ? 'المستمع الذكي للبريد وإشعارات الوصول' : 'Smart Email & Arrival Notice Listener',
          icon: Icon(
            Icons.mark_email_read_outlined,
            size: 16,
            color: isDark ? AppTheme.cobaltLight : AppTheme.cobalt,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          splashRadius: 14,
          onPressed: () => SmartEmailListenerDialog.show(context),
        ),

        // 3. Email Server Settings (IMAP/SMTP) — admin only (backend returns 403 otherwise)
        if (EmailSettingsDialog.canAccess(ref.watch(authProvider).user))
          IconButton(
            tooltip: isArabic ? 'إعدادات ربط البريد (IMAP/SMTP)' : 'Email Server Settings (IMAP/SMTP)',
            icon: Icon(
              Icons.settings_suggest_rounded,
              size: 16,
              color: isDark ? Colors.cyanAccent.shade200 : Colors.teal.shade700,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            splashRadius: 14,
            onPressed: () => EmailSettingsDialog.show(context),
          ),
        const SizedBox(width: 2),

        // 4. Language Switcher Pill (EN / عربي)
        Tooltip(
          message: isArabic
              ? 'تبديل لغة الواجهة (English / العربية)'
              : 'Toggle Interface Language (English / Arabic)',
          child: InkWell(
            borderRadius: BorderRadius.circular(5),
            onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2631) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language_rounded, size: 13, color: AppTheme.cobalt),
                  const SizedBox(width: 3),
                  Text(
                    isArabic ? 'EN' : 'عربي',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 5. Theme Toggle Button (Light / Dark)
        IconButton(
          tooltip: l10n.themeToggleTooltip,
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 16,
            color: isDark ? Colors.amber.shade300 : AppTheme.charcoal,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          splashRadius: 14,
          onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
        ),

        // 6. Basic System Settings Dialog Button
        IconButton(
          tooltip: isArabic ? 'الإعدادات الأساسية للنظام' : 'Basic System Settings',
          icon: Icon(
            Icons.settings_outlined,
            size: 16,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          splashRadius: 14,
          onPressed: () => SystemSettingsDialog.show(context),
        ),
        const SizedBox(width: 2),

        // 7. Global Display Density Selector
        const DisplayDensitySelector(compact: true),
        const SizedBox(width: 2),

        // 7b. Focus Mode Toggle (Ctrl + Shift + F)
        IconButton(
          tooltip: isArabic
              ? 'وضع التركيز (Ctrl+Shift+F)'
              : 'Focus Mode (Ctrl+Shift+F)',
          icon: Icon(
            ref.watch(focusModeProvider)
                ? Icons.fit_screen_rounded
                : Icons.filter_center_focus_rounded,
            size: 16,
            color: ref.watch(focusModeProvider)
                ? AppTheme.emerald
                : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          splashRadius: 14,
          onPressed: () => ref.read(focusModeProvider.notifier).toggle(),
        ),
        const SizedBox(width: 2),

        // 8. Keyboard Shortcuts Guide Button (F1)
        IconButton(
          tooltip: l10n.shortcutShowHelp,
          icon: Icon(
            Icons.keyboard_outlined,
            size: 16,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          splashRadius: 14,
          onPressed: () => KeyboardShortcutsDialog.show(context),
        ),

        // 9. Fullscreen Toggle Button (F11)
        IconButton(
          tooltip: l10n.shortcutToggleFullscreen,
          icon: Icon(
            Icons.fullscreen_rounded,
            size: 18,
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          splashRadius: 14,
          onPressed: () async {
            if (!kIsWeb && Platform.isWindows) {
              try {
                final isFull = await windowManager.isFullScreen();
                await windowManager.setFullScreen(!isFull);
                if (context.mounted) {
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
          },
        ),
      ],
    );
  }
}
