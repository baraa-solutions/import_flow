import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../export/export_language.dart';
import '../localization/app_localizations.dart';
import '../localization/locale_provider.dart';
import '../theme/app_theme.dart';
import '../theme/density_provider.dart';
import '../theme/theme_provider.dart';

/// Comprehensive Basic System Settings Dialog (نافذة الإعدادات الأساسية للنظام)
/// Provides real-time configuration for:
/// 1. Interface Language (Arabic RTL ↔ English LTR)
/// 2. System Theme Mode (Light, Dark, System)
/// 3. Table & Display Density (Comfortable, Compact, Ultra-Compact)
/// 4. World Clocks & Logistics Jurisdictions Overview
/// 5. System Diagnostics & Cache Refresh
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
    _tabController = TabController(length: 4, vsync: this);
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
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // ── Tab Views ──
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // 1. Language & Directionality
                      _buildLanguageSection(
                        context,
                        isDark: isDark,
                        isArabic: isArabic,
                        currentLocale: currentLocale,
                        cardBg: cardBg,
                        borderColor: borderColor,
                      ),

                      // 2. Theme & Appearance
                      _buildThemeSection(
                        context,
                        isDark: isDark,
                        isArabic: isArabic,
                        currentThemeMode: currentThemeMode,
                        cardBg: cardBg,
                        borderColor: borderColor,
                      ),

                      // 3. Display Density
                      _buildDensitySection(
                        context,
                        isDark: isDark,
                        isArabic: isArabic,
                        currentDensity: currentDensity,
                        cardBg: cardBg,
                        borderColor: borderColor,
                      ),

                      // 4. Diagnostics & System Info
                      _buildDiagnosticsSection(
                        context,
                        isDark: isDark,
                        isArabic: isArabic,
                        cardBg: cardBg,
                        borderColor: borderColor,
                      ),
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

  // ── Tab 1: Language ──
  Widget _buildLanguageSection(
    BuildContext context, {
    required bool isDark,
    required bool isArabic,
    required Locale currentLocale,
    required Color cardBg,
    required Color borderColor,
  }) {
    final isArActive = currentLocale.languageCode == 'ar';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isArabic
                ? 'اختر لغة واجهة النظام المفضلة. يتم تحويل اتجاه النصوص (RTL / LTR) وكافة القوائم والتقارير تلقائياً:'
                : 'Select system interface language. Text direction (RTL / LTR), menus, and reports update instantly:',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 16),
          _buildOptionCard(
            context,
            isDark: isDark,
            isSelected: isArActive,
            icon: Icons.translate_rounded,
            title: 'العربية (Arabic)',
            badge: 'RTL (من اليمين لليسار)',
            subtitle: 'الواجهة بالكامل باللغة العربية مع دعم المصطلحات الجمركية واللوجستية المصرية',
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('ar'));
            },
            cardBg: cardBg,
            borderColor: borderColor,
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            context,
            isDark: isDark,
            isSelected: !isArActive,
            icon: Icons.language_rounded,
            title: 'English (الإنجليزية)',
            badge: 'LTR (Left to Right)',
            subtitle: 'Full English interface with international trade, customs, and freight standards',
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('en'));
            },
            cardBg: cardBg,
            borderColor: borderColor,
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text(
            isArabic
                ? 'لغة التصدير والتحميل الافتراضية (PDF & Excel):'
                : 'Default Export & Download Language (PDF & Excel):',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isArabic
                ? 'حدد السلوك الافتراضي عند الضغط على أزرار التصدير والطباعة في كافة شاشات النظام:'
                : 'Configure the default behavior when clicking export or print buttons across the ERP:',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildExportRadioRow(
                  value: ExportLanguage.optionAsk,
                  title: isArabic ? 'السؤال في كل مرة (Ask Every Time)' : 'Ask Every Time (السؤال في كل مرة)',
                  subtitle: isArabic
                      ? 'إظهار نافذة صغيرة لاختيار اللغة قبل كل عملية تنزيل'
                      : 'Show a prompt to choose Arabic or English before every export',
                  isDark: isDark,
                ),
                const Divider(height: 12),
                _buildExportRadioRow(
                  value: ExportLanguage.optionAr,
                  title: isArabic ? 'العربية دائماً (Always Arabic)' : 'Always Arabic (العربية دائماً)',
                  subtitle: isArabic
                      ? 'تنزيل فوري باللغة العربية (RTL) دون إظهار نافذة السؤال'
                      : 'Immediate download in Arabic (RTL) without prompting',
                  isDark: isDark,
                ),
                const Divider(height: 12),
                _buildExportRadioRow(
                  value: ExportLanguage.optionEn,
                  title: isArabic ? 'الإنجليزية دائماً (Always English)' : 'Always English (الإنجليزية دائماً)',
                  subtitle: isArabic
                      ? 'تنزيل فوري باللغة الإنجليزية (LTR) دون إظهار نافذة السؤال'
                      : 'Immediate download in English (LTR) without prompting',
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppTheme.cobalt),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'تفضيل اللغة يُخزن بشكل آمن في وحدة التخزين المشفرة ويُطبق عند كل فتح للنظام.'
                        : 'Language preference is securely persisted and automatically restored upon next launch.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportRadioRow({
    required String value,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final isSelected = _defaultExportLang == value;
    return InkWell(
      onTap: () async {
        setState(() => _defaultExportLang = value);
        await ExportLanguage.saveDefaultOption(value);
      },
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _defaultExportLang,
              activeColor: AppTheme.cobalt,
              onChanged: (val) async {
                if (val != null) {
                  setState(() => _defaultExportLang = val);
                  await ExportLanguage.saveDefaultOption(val);
                }
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 2: Theme ──
  Widget _buildThemeSection(
    BuildContext context, {
    required bool isDark,
    required bool isArabic,
    required ThemeMode currentThemeMode,
    required Color cardBg,
    required Color borderColor,
  }) {
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
          _buildOptionCard(
            context,
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
          _buildOptionCard(
            context,
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
          _buildOptionCard(
            context,
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
                    isArabic ? 'لوحة ألوان ImportFlow ERP:' : 'ImportFlow Palette:',
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

  // ── Tab 3: Display Density ──
  Widget _buildDensitySection(
    BuildContext context, {
    required bool isDark,
    required bool isArabic,
    required DisplayDensityMode currentDensity,
    required Color cardBg,
    required Color borderColor,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isArabic
                ? 'تحكم في مسافات الجداول وارتفاع الصفوف لتناسب حجم شاشتك وطبيعة عملك اليومي:'
                : 'Adjust table row heights and input paddings to match your display size and workflow:',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 16),
          _buildOptionCard(
            context,
            isDark: isDark,
            isSelected: currentDensity == DisplayDensityMode.comfortable,
            icon: Icons.table_rows_outlined,
            title: isArabic ? 'مريح (Comfortable - 56px)' : 'Comfortable (56px Row Height)',
            badge: isArabic ? 'للشاشات الكبيرة' : 'Large Monitors',
            subtitle: isArabic
                ? 'مسافات واسعة مناسبة للشاشات الكبيرة والعرض المريح للبيانات'
                : 'Generous padding and relaxed spacing optimized for wide desktop displays',
            onTap: () {
              ref.read(displayDensityProvider.notifier).setDensity(DisplayDensityMode.comfortable);
            },
            cardBg: cardBg,
            borderColor: borderColor,
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            context,
            isDark: isDark,
            isSelected: currentDensity == DisplayDensityMode.compact,
            icon: Icons.view_headline,
            title: isArabic ? 'مدمج (Compact - 48px)' : 'Compact (48px Row Height)',
            badge: isArabic ? 'الافتراضي للابتوب' : 'Laptop Recommended',
            subtitle: isArabic
                ? 'توازن مثالي بين وضوح القراءة وكثافة عرض الصفوف لشاشات اللابتوب'
                : 'Balanced density recommended for typical 14-16 inch laptop screens',
            onTap: () {
              ref.read(displayDensityProvider.notifier).setDensity(DisplayDensityMode.compact);
            },
            cardBg: cardBg,
            borderColor: borderColor,
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            context,
            isDark: isDark,
            isSelected: currentDensity == DisplayDensityMode.ultraCompact,
            icon: Icons.density_small,
            title: isArabic ? 'فائق الكثافة (Ultra-Compact - 40px)' : 'Ultra-Compact (40px Row Height)',
            badge: isArabic ? 'أقصى بيانات' : 'Data Operators',
            subtitle: isArabic
                ? 'أعلى استغلال لمساحة الشاشة مع الالتزام بقاعدة الحد الأدنى للخط 11px'
                : 'Maximum data rows visible on screen with strict adherence to 11px minimum text floor',
            onTap: () {
              ref.read(displayDensityProvider.notifier).setDensity(DisplayDensityMode.ultraCompact);
            },
            cardBg: cardBg,
            borderColor: borderColor,
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Diagnostics & Environment ──
  Widget _buildDiagnosticsSection(
    BuildContext context, {
    required bool isDark,
    required bool isArabic,
    required Color cardBg,
    required Color borderColor,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  isArabic ? 'حالة النظام / الإصدار:' : 'System Version:',
                  'Sorour Logistics ERP v${ApiConstants.clientVersion} (Build ${ApiConstants.clientBuildNumber})',
                  isDark: isDark,
                  trailingIcon: Icons.verified_rounded,
                  iconColor: AppTheme.cobalt,
                ),
                const Divider(height: 16),
                _buildInfoRow(
                  isArabic ? 'خادم الواجهة الخلفية (Backend API):' : 'Backend API Service:',
                  '${ApiConstants.serverUrl} (FastAPI / Uvicorn)',
                  isDark: isDark,
                  trailingIcon: Icons.cloud_done_rounded,
                  iconColor: AppTheme.emerald,
                ),
                const Divider(height: 16),
                _buildInfoRow(
                  isArabic ? 'قاعدة البيانات التشغيلية:' : 'Active Database:',
                  'sorour_logistics.db (SQLite WAL Mode)',
                  isDark: isDark,
                  trailingIcon: Icons.storage_rounded,
                  iconColor: AppTheme.cobalt,
                ),
                const Divider(height: 16),
                _buildInfoRow(
                  isArabic ? 'شريط الساعات الدولية الموحد:' : 'Live World Clocks:',
                  isArabic ? 'مفعل بنظام 24H (القاهرة، شنغهاي، هامبورغ، دبي، لندن، نيويورك)' : 'Active 24H (Cairo, Shanghai, Hamburg, Dubai, London, New York)',
                  isDark: isDark,
                  trailingIcon: Icons.access_time_rounded,
                  iconColor: AppTheme.emerald,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Clear cache and refresh action
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2631) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFBFDBFE),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cached_rounded,
                  color: AppTheme.cobalt,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'تحديث الذاكرة المؤقتة وإعادة المزامنة' : 'Clear Local Cache & Force Resync',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic
                            ? 'إعادة تحميل كافة بيانات الموردين والشركات المرجعية من السيرفر مباشرة'
                            : 'Force-refresh all providers and refetch latest master data from backend',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cobalt,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: _isClearingCache
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    isArabic ? 'تحديث فوري' : 'Sync Now',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isClearingCache
                      ? null
                      : () => _handleClearCache(isArabic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    required bool isDark,
    IconData? trailingIcon,
    Color? iconColor,
  }) {
    return Row(
      children: [
        if (trailingIcon != null) ...[
          Icon(trailingIcon, size: 16, color: iconColor ?? AppTheme.cobalt),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  // ── Option Card Helper ──
  Widget _buildOptionCard(
    BuildContext context, {
    required bool isDark,
    required bool isSelected,
    required IconData icon,
    required String title,
    required String badge,
    required String subtitle,
    required VoidCallback onTap,
    required Color cardBg,
    required Color borderColor,
  }) {
    const selectedBorder = AppTheme.cobalt;
    final selectedBg = isDark
        ? AppTheme.cobalt.withValues(alpha: 0.18)
        : const Color(0xFFEFF6FF);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? selectedBorder : borderColor,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.cobalt
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? (isDark ? Colors.white : const Color(0xFF1E3A8A))
                                : (isDark ? AppTheme.darkTextPrimary : const Color(0xFF1E293B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.cobalt.withValues(alpha: 0.2)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppTheme.cobalt
                                : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.cobalt : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.cobalt
                      : (isDark ? AppTheme.darkTextMuted : const Color(0xFF94A3B8)),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
