import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

/// Decoupled regulatory banner evaluating ACID compliance & postal courier exemption feasibility.
/// Criteria for Egyptian customs postal parcel exemption:
/// - Gross Weight <= 50 kg
/// - Customs Value <= $2000 USD
///
/// If exceeded: Requires mandatory ACID number, Bank Form 4, CargoX filing, and Nafeza import release.
/// If compliant: Direct postal release exempt from ACID, Bank Form 4, and CargoX.
class AcidComplianceFeasibilityBanner extends StatelessWidget {
  final double grossWeightKg;
  final double customsValueUsd;

  const AcidComplianceFeasibilityBanner({
    super.key,
    required this.grossWeightKg,
    required this.customsValueUsd,
  });

  static const double maxPostalWeightKg = 50.0;
  static const double maxPostalValueUsd = 2000.0;

  bool get isExempt =>
      grossWeightKg <= maxPostalWeightKg && customsValueUsd <= maxPostalValueUsd;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = l.isArabic;
    final exempt = isExempt;

    final bannerColor = exempt ? AppTheme.emerald : AppTheme.crimson;
    final bannerBg = exempt ? AppTheme.emeraldLight : AppTheme.crimsonLight;
    final bannerBorder = exempt ? AppTheme.emeraldBorder : AppTheme.crimsonBorder;

    final alertText = exempt
        ? (isArabic
            ? 'ميزة جمركية: الشحنة مؤهلة للإفراج المباشر للطرود البريدية. معفاة من التسجيل المسبق (ACID) ونموذج 4 البنكي ومحفظة CargoX.'
            : 'Customs Advantage: Cargo is eligible for direct postal parcel release. Exempt from ACID registration, Bank Form 4, and CargoX wallet filing.')
        : (isArabic
            ? 'تنبيه تنظيمي: الشحنة تتجاوز حدود البريد السريع المعفى (الوزن > 50 كجم أو القيمة > 2000 دولار). يلزم استخراج رقم تسجيل مسبق للشحنات (ACID) وإجراءات استيرادية كاملة عبر نافذة.'
            : 'Regulatory Alert: Cargo exceeds exempt express courier parcel limits (Gross Weight > 50 kg or Value > \$2,000). Advance Cargo Information (ACID) registration and full import procedures via Nafeza are mandatory.');

    final weightUnit = isArabic ? 'كجم' : 'kg';

    return SelectionArea(
      child: InkWell(
        onTap: () => CopyHelper.copy(context, alertText),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bannerBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: bannerBorder, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    exempt ? Icons.verified_user_outlined : Icons.gavel_rounded,
                    color: bannerColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alertText,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: exempt ? AppTheme.wcagEmerald : AppTheme.wcagCrimson,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildThresholdPill(
                              label: isArabic ? 'الوزن القائم' : 'Gross Weight',
                              currentValue: '${grossWeightKg.toStringAsFixed(1)} $weightUnit',
                              limitValue: '≤ 50 $weightUnit',
                              isPass: grossWeightKg <= maxPostalWeightKg,
                              isArabic: isArabic,
                            ),
                            _buildThresholdPill(
                              label: isArabic ? 'القيمة الجمركية' : 'Customs Value',
                              currentValue: '\$${customsValueUsd.toStringAsFixed(0)}',
                              limitValue: '≤ \$2000',
                              isPass: customsValueUsd <= maxPostalValueUsd,
                              isArabic: isArabic,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: bannerColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: bannerColor.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    exempt ? Icons.check_circle_outline : Icons.error_outline,
                                    size: 13,
                                    color: bannerColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    exempt
                                        ? (isArabic ? 'إفراج بريدي معفى' : 'Postal Parcel Exempt')
                                        : (isArabic ? 'إجراءات استيرادية كاملة' : 'Full Commercial Import'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: bannerColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: isArabic ? 'نسخ نص التنبيه' : 'Copy alert text',
                    child: Icon(
                      Icons.copy_outlined,
                      size: 14,
                      color: bannerColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThresholdPill({
    required String label,
    required String currentValue,
    required String limitValue,
    required bool isPass,
    required bool isArabic,
  }) {
    final pillColor = isPass ? AppTheme.emerald : AppTheme.crimson;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: pillColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $currentValue ($limitValue)',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isPass ? AppTheme.wcagEmerald : AppTheme.wcagCrimson,
        ),
      ),
    );
  }
}
