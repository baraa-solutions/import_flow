import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

/// Decoupled breakdown card showing estimated administrative and regulatory savings
/// when an express courier shipment qualifies for Egyptian customs postal parcel exemption:
/// - CargoX document upload & wallet units (~$150 - $200)
/// - Bank Form 4 commission & SWIFT fees (~$50 - $100)
/// - Dedicated customs broker fees (~$100 - $200)
///
/// Total estimated direct operational savings: ~$300 - $500 per shipment.
class PostalSavingsBreakdownCard extends StatelessWidget {
  final double grossWeightKg;
  final double customsValueUsd;
  final VoidCallback? onApplyCourierAdvantage;

  const PostalSavingsBreakdownCard({
    super.key,
    required this.grossWeightKg,
    required this.customsValueUsd,
    this.onApplyCourierAdvantage,
  });

  bool get isExempt => grossWeightKg <= 50.0 && customsValueUsd <= 2000.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = l.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final reportSummary = isArabic
        ? '''تقرير وفر التكاليف للشحنات المعفاة بريدياً:
1. توفير وحدات محفظة كارجو إكس: 150 - 200 دولار
2. توفير عمولة فتح نموذج 4 وسويفت التحويل البنكي: 50 - 100 دولار
3. توفير أتعاب مخلص جمركي خاص ومصاريف التخزين: 100 - 200 دولار
إجمالي الوفر التشغيلي المقدر: 300 - 500 دولار للشحنة الواحدة.'''
        : '''Postal Exemption Cost Savings Report:
1. CargoX wallet filing units savings: \$150 - \$200
2. Bank Form 4 opening commission & SWIFT savings: \$50 - \$100
3. Private customs broker fees savings: \$100 - \$200
Total estimated operational savings: \$300 - \$500 per shipment.''';

    return SelectionArea(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isExempt
                ? AppTheme.emerald.withValues(alpha: 0.5)
                : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
            width: isExempt ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.savings_outlined,
                    color: AppTheme.emerald,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic
                            ? 'وفر التكاليف التشغيلية المقدر للإفراج البريدي السريع'
                            : 'Estimated Operational Savings for Express Postal Release',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic
                            ? 'مقارنة التكاليف غير المباشرة المستبعدة عند الاستيراد بالطرود البريدية'
                            : 'Indirect regulatory overhead waived under express courier postal release',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.emeraldBorder),
                  ),
                  child: Text(
                    isArabic ? 'وفر 300 - 500 دولار' : 'Save \$300 - \$500',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.wcagEmerald,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildSavingsRow(
              context,
              icon: Icons.account_balance_wallet_outlined,
              title: isArabic
                  ? 'توفير وحدات محفظة كارجو إكس'
                  : 'CargoX Wallet Document Units',
              description: isArabic
                  ? 'إعفاء من شراء وحدات منصة التحقق الرقمي كارجو إكس ورفع الفواتير وبوالص الشحن'
                  : 'Exempt from purchasing CargoX verification credits and uploading foreign docs',
              savingsAmount: isArabic ? '150 - 200 دولار' : '\$150 - \$200',
              isDark: isDark,
            ),
            const Divider(height: 16),
            _buildSavingsRow(
              context,
              icon: Icons.account_balance_outlined,
              title: isArabic
                  ? 'توفير عمولة فتح نموذج 4 وسويفت التحويل البنكي'
                  : 'Bank Form 4 Commission & SWIFT Fees',
              description: isArabic
                  ? 'إعفاء من دورة المستندات البنكية ومصاريف السويفت وعمولات اعتماد نموذج 4'
                  : 'Exempt from banking dossier lifecycle, SWIFT dispatch fees, and Form 4 charges',
              savingsAmount: isArabic ? '50 - 100 دولار' : '\$50 - \$100',
              isDark: isDark,
            ),
            const Divider(height: 16),
            _buildSavingsRow(
              context,
              icon: Icons.badge_outlined,
              title: isArabic
                  ? 'توفير أتعاب مخلص جمركي خاص ومصاريف التخزين'
                  : 'Customs Broker & Port Handling Fees',
              description: isArabic
                  ? 'تخليص مركزي مباشر بواسطة شركة النقل السريع دون توكيل مخلص مستقل أو رسوم أرضيات'
                  : 'Direct expedited clearance by courier operator without private broker retainers',
              savingsAmount: isArabic ? '100 - 200 دولار' : '\$100 - \$200',
              isDark: isDark,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isDark ? AppTheme.darkSurface : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.speed,
                          color: AppTheme.emerald,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            isArabic
                                ? 'زمن إفراج قياسي: 24-48 ساعة بدلاً من 7-10 أيام'
                                : 'Release turnaround: 24-48 hours vs 7-10 days',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: isArabic ? 'نسخ تقرير الوفر' : 'Copy Savings Report',
                  icon: Icons.copy,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () => CopyHelper.copy(context, reportSummary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String savingsAmount,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => CopyHelper.copy(context, '$title: $savingsAmount'),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 18,
              color: AppTheme.emerald,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.emeraldLight.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.emeraldBorder),
              ),
              child: Text(
                savingsAmount,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.wcagEmerald,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
