import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../export/export_language.dart';
import '../../localization/locale_provider.dart';
import '../../theme/app_theme.dart';
import 'settings_option_card.dart';

class SettingsLanguageSection extends StatelessWidget {
  final bool isDark;
  final bool isArabic;
  final Locale currentLocale;
  final Color cardBg;
  final Color borderColor;
  final String defaultExportLang;
  final ValueChanged<String> onExportLangChanged;
  final WidgetRef ref;

  const SettingsLanguageSection({
    super.key,
    required this.isDark,
    required this.isArabic,
    required this.currentLocale,
    required this.cardBg,
    required this.borderColor,
    required this.defaultExportLang,
    required this.onExportLangChanged,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
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
          SettingsOptionCard(
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
          SettingsOptionCard(
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
                ),
                const Divider(height: 12),
                _buildExportRadioRow(
                  value: ExportLanguage.optionAr,
                  title: isArabic ? 'العربية دائماً (Always Arabic)' : 'Always Arabic (العربية دائماً)',
                  subtitle: isArabic
                      ? 'تنزيل فوري باللغة العربية (RTL) دون إظهار نافذة السؤال'
                      : 'Immediate download in Arabic (RTL) without prompting',
                ),
                const Divider(height: 12),
                _buildExportRadioRow(
                  value: ExportLanguage.optionEn,
                  title: isArabic ? 'الإنجليزية دائماً (Always English)' : 'Always English (الإنجليزية دائماً)',
                  subtitle: isArabic
                      ? 'تنزيل فوري باللغة الإنجليزية (LTR) دون إظهار نافذة السؤال'
                      : 'Immediate download in English (LTR) without prompting',
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
  }) {
    final isSelected = defaultExportLang == value;
    return InkWell(
      onTap: () async {
        onExportLangChanged(value);
        await ExportLanguage.saveDefaultOption(value);
      },
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // ignore: deprecated_member_use
            Radio<String>(
              value: value,
              // ignore: deprecated_member_use
              groupValue: defaultExportLang,
              activeColor: AppTheme.cobalt,
              // ignore: deprecated_member_use
              onChanged: (val) async {
                if (val != null) {
                  onExportLangChanged(val);
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
}
