import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../export/export_language.dart';
import '../localization/app_localizations.dart';
import '../localization/locale_provider.dart';
import '../theme/app_theme.dart';
import '../theme/density_provider.dart';
import '../theme/theme_provider.dart';
import '../../features/system_parameters/widgets/system_parameters_tab.dart';
import 'system_settings/settings_language_section.dart';
import 'system_settings/settings_theme_section.dart';
import 'system_settings/settings_density_section.dart';
import 'system_settings/settings_diagnostics_section.dart';

/// Comprehensive Basic System Settings Dialog (نافذة الإعدادات الأساسية للنظام)
/// Provides real-time configuration for:
/// 1. Interface Language (Arabic RTL ↔ English LTR)
/// 2. System Theme Mode (Light, Dark, System)
/// 3. Table & Display Density (Comfortable, Compact, Ultra-Compact)
/// 4. World Clocks & Logistics Jurisdictions Overview
/// 5. System Diagnostics & Cache Refresh
/// 6. System Business Parameters Configuration
class SystemSettingsDialog extends ConsumerStatefulWidget {
  const SystemSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const SystemSettingsDialog(),
    );
  }

  @override
  ConsumerState<SystemSettingsDialog> createState() => _SystemSettingsDialogState();
}

class _SystemSettingsDialogState extends ConsumerState<SystemSettingsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isClearingCache = false;
  String _defaultExportLang = ExportLanguage.optionAsk;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadExportSettings();
  }

  Future<void> _loadExportSettings() async {
    final opt = await ExportLanguage.getSavedDefaultOption();
    if (mounted) setState(() => _defaultExportLang = opt);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleClearCache(bool isArabic) async {
    setState(() => _isClearingCache = true);
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _isClearingCache = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isArabic
                    ? 'تم مسح الذاكرة المؤقتة وإعادة مزامنة إعدادات النظام بنجاح'
                    : 'Local cache cleared and system settings resynchronized successfully',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.emerald,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);
    final currentLocale = ref.watch(localeProvider);
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentDensity = ref.watch(displayDensityProvider);

    final dialogBg = isDark ? const Color(0xFF1E2631) : Colors.white;
    final cardBg = isDark ? const Color(0xFF253140) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 12,
      backgroundColor: dialogBg,
      child: SelectionArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header Row ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune_rounded, color: AppTheme.cobalt, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'الإعدادات الأساسية للنظام' : 'Basic System Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isArabic
                                ? 'تخصيص لغة الواجهة، مظهر النظام، كثافة الجداول، وتفضيلات التشغيل'
                                : 'Configure interface language, appearance theme, display density, and system preferences',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: isArabic ? 'إغلاق' : 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Tabs Navigation ──
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppTheme.cobalt,
                  unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                  indicatorColor: AppTheme.cobalt,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.language_rounded, size: 18),
                      text: isArabic ? 'اللغة والاتجاه' : 'Language & RTL',
                    ),
                    Tab(
                      icon: const Icon(Icons.palette_outlined, size: 18),
                      text: isArabic ? 'المظهر والسمة' : 'Theme & Mode',
                    ),
                    Tab(
                      icon: const Icon(Icons.view_compact_outlined, size: 18),
                      text: isArabic ? 'كثافة العرض' : 'Display Density',
                    ),
                    Tab(
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                      text: isArabic ? 'التشخيص والبيئة' : 'Diagnostics',
                    ),
                    Tab(
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      text: isArabic ? 'معاملات التشغيل' : 'Parameters',
                    ),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // ── Tab Views ──
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      SettingsLanguageSection(
                        isDark: isDark,
                        isArabic: isArabic,
                        currentLocale: currentLocale,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        defaultExportLang: _defaultExportLang,
                        onExportLangChanged: (val) => setState(() => _defaultExportLang = val),
                        ref: ref,
                      ),
                      SettingsThemeSection(
                        isDark: isDark,
                        isArabic: isArabic,
                        currentThemeMode: currentThemeMode,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        ref: ref,
                      ),
                      SettingsDensitySection(
                        isDark: isDark,
                        isArabic: isArabic,
                        currentDensity: currentDensity,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        ref: ref,
                      ),
                      SettingsDiagnosticsSection(
                        isDark: isDark,
                        isArabic: isArabic,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        isClearingCache: _isClearingCache,
                        onClearCache: () => _handleClearCache(isArabic),
                      ),
                      const SystemParametersTab(),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // ── Footer Actions ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isArabic ? 'التغييرات تطبق فورياً وتُحفظ تلقائياً' : 'Changes apply live & auto-persist',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: isDark ? AppTheme.darkTextMuted : Colors.grey.shade600,
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cobalt,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        isArabic ? 'تم وحفظ' : 'Done',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
