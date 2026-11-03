import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../theme/density_provider.dart';
import 'settings_option_card.dart';

class SettingsDensitySection extends StatelessWidget {
  final bool isDark;
  final bool isArabic;
  final DisplayDensityMode currentDensity;
  final Color cardBg;
  final Color borderColor;
  final WidgetRef ref;

  const SettingsDensitySection({
    super.key,
    required this.isDark,
    required this.isArabic,
    required this.currentDensity,
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
                ? 'تحكم في مسافات الجداول وارتفاع الصفوف لتناسب حجم شاشتك وطبيعة عملك اليومي:'
                : 'Adjust table row heights and input paddings to match your display size and workflow:',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 16),
          SettingsOptionCard(
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
          SettingsOptionCard(
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
          SettingsOptionCard(
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
}
