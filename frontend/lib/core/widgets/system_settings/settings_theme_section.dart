import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import 'settings_option_card.dart';

class SettingsThemeSection extends StatelessWidget {
  final bool isDark;
  final bool isArabic;
  final ThemeMode currentThemeMode;
  final Color cardBg;
  final Color borderColor;
  final WidgetRef ref;

  const SettingsThemeSection({
    super.key,
    required this.isDark,
    required this.isArabic,
    required this.currentThemeMode,
    required this.cardBg,
    required this.borderColor,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isArabic
                ? 'اختر مظهر النظام المعتمد. يلتزم النظام بلوحة الألوان القياسية (Charcoal, Cobalt, Emerald, Orange, Crimson):'
                : 'Select application theme. Strict compliance with enterprise palette (Charcoal, Cobalt, Emerald, Orange, Crimson):',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 16),
          SettingsOptionCard(
            isDark: isDark,
            isSelected: currentThemeMode == ThemeMode.light,
            icon: Icons.light_mode_rounded,
            title: isArabic ? 'الوضع النهاري (Light Mode)' : 'Light Theme',
            badge: isArabic ? 'مكتبي قياسي' : 'Default Enterprise',
            subtitle: isArabic
                ? 'خلفية بيضاء نقية مع عناصر تباين عالية لبيئة العمل المكتبية النهارية'
                : 'High-contrast clean white surface optimized for desktop office productivity',
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
            },
            cardBg: cardBg,
            borderColor: borderColor,
          ),
          const SizedBox(height: 12),
          SettingsOptionCard(
            isDark: isDark,
            isSelected: currentThemeMode == ThemeMode.dark,
            icon: Icons.dark_mode_rounded,
            title: isArabic ? 'الوضع الليلي عالي التباين (Dark Mode)' : 'Dark Theme',
            badge: 'WCAG AA Compliant',
            subtitle: isArabic
                ? 'تصميم رمادي داكن (#182029) عالي التباين (> 4.5:1) ومريح للعينين'
                : 'High-contrast desktop slate design (> 4.5:1) compliant with WCAG AA standards',
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
            },
            cardBg: cardBg,
            borderColor: borderColor,
          ),
          const SizedBox(height: 12),
          SettingsOptionCard(
            isDark: isDark,
            isSelected: currentThemeMode == ThemeMode.system,
            icon: Icons.settings_brightness_rounded,
            title: isArabic ? 'تلقائي حسب نظام التشغيل (System)' : 'System Mode',
            badge: 'Auto Sync',
            subtitle: isArabic
                ? 'يتوافق تلقائياً مع مظهر نظام Windows المفعل حالياً'
                : 'Automatically matches the host Windows OS theme configuration',
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
            },
            cardBg: cardBg,
            borderColor: borderColor,
          ),
          const SizedBox(height: 16),
          // Enterprise Palette Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    isArabic ? 'لوحة ألوان هوية سرور:' : 'Sorour Logistics Palette:',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _buildColorBadge('Charcoal', AppTheme.charcoal),
                    const SizedBox(width: 6),
                    _buildColorBadge('Cobalt', AppTheme.cobalt),
                    const SizedBox(width: 6),
                    _buildColorBadge('Emerald', AppTheme.emerald),
                    const SizedBox(width: 6),
                    _buildColorBadge('Orange', AppTheme.orange),
                    const SizedBox(width: 6),
                    _buildColorBadge('Crimson', AppTheme.crimson),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorBadge(String label, Color color) {
    return Tooltip(
      message: label,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4, spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}
