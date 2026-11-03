import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import 'dual_divisor_selector_card.dart';

/// Decoupled comparative metrics tile for Air Freight vs Express Courier volumetric calculations.
/// Strictly adheres to:
/// - Root wrapped in [SelectionArea] for mouse highlighting.
/// - Pure Arabic / English language separation with ZERO bilingual parenthetical stacking.
/// - Safe clipboard copying via [CopyHelper.copy].
/// - Approved theme colors ([AppTheme.cobalt], [AppTheme.orange], [AppTheme.emerald], [AppTheme.charcoal]).
class VolumetricWeightComparisonTile extends StatelessWidget {
  final double actualGrossWeightKg;
  final double totalCbm;
  final AirFreightDivisorMode? activeMode;

  const VolumetricWeightComparisonTile({
    super.key,
    required this.actualGrossWeightKg,
    required this.totalCbm,
    this.activeMode,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = l.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Density calculations:
    // Volume in cm3 = totalCbm * 1,000,000
    // Courier (5000): cm3 / 5000 = totalCbm * 200.0
    // General Air (6000): cm3 / 6000 = totalCbm * 166.6667
    final totalVolumeCm3 = totalCbm * 1000000.0;
    final volumetricCourierKg = totalVolumeCm3 > 0 ? totalVolumeCm3 / 5000.0 : 0.0;
    final volumetricAirKg = totalVolumeCm3 > 0 ? totalVolumeCm3 / 6000.0 : 0.0;

    final chargeableCourierKg = math.max(actualGrossWeightKg, volumetricCourierKg);
    final chargeableAirKg = math.max(actualGrossWeightKg, volumetricAirKg);
    final chargeableDiffKg = (chargeableCourierKg - chargeableAirKg).abs();

    // Volumetric penalty alert: volumetric weight is higher than actual gross weight
    final isVolumetricPenalty = (volumetricCourierKg > actualGrossWeightKg && actualGrossWeightKg > 0) ||
        (volumetricAirKg > actualGrossWeightKg && actualGrossWeightKg > 0);

    final penaltyText = isArabic
        ? 'تنبيه وزني: الوزن الحجمي أكبر من الوزن الفعلي، يتم احتساب رسوم الشحن على الوزن الحجمي الأعلى (وزن مدفوع إضافي).'
        : 'Volumetric Warning: Volumetric weight exceeds actual gross weight; freight charges apply to the higher volumetric weight.';

    final unitKg = isArabic ? 'كجم' : 'kg';
    final unitCbm = isArabic ? 'م³' : 'm³';

    return SelectionArea(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
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
                const Icon(
                  Icons.compare_arrows_rounded,
                  color: AppTheme.cobalt,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'مقارنة الوزن الحجمي والمحتسب (قاسم 5000 مقابل 6000)'
                        : 'Volumetric & Chargeable Weight Comparison (Divisor 5000 vs 6000)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.cobaltLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${totalCbm.toStringAsFixed(4)} $unitCbm',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.sorourNavy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                final cards = [
                  _buildMetricCard(
                    context,
                    title: isArabic ? 'الوزن الفعلي القائم' : 'Actual Gross Weight',
                    value: '${actualGrossWeightKg.toStringAsFixed(2)} $unitKg',
                    icon: Icons.fitness_center,
                    color: AppTheme.charcoal,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    context,
                    title: isArabic ? 'حجمي البريد السريع (÷5000)' : 'Courier Volumetric (÷5000)',
                    value: '${volumetricCourierKg.toStringAsFixed(2)} $unitKg',
                    icon: Icons.local_shipping_outlined,
                    color: AppTheme.sorourDeepBlue,
                    subtitle: isArabic
                        ? 'المحتسب: ${chargeableCourierKg.toStringAsFixed(2)} $unitKg'
                        : 'Chargeable: ${chargeableCourierKg.toStringAsFixed(2)} $unitKg',
                    isHighlighted: activeMode?.isExpressCourier ?? false,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    context,
                    title: isArabic ? 'حجمي الطيران العام (÷6000)' : 'General Air Volumetric (÷6000)',
                    value: '${volumetricAirKg.toStringAsFixed(2)} $unitKg',
                    icon: Icons.flight_takeoff,
                    color: AppTheme.cobalt,
                    subtitle: isArabic
                        ? 'المحتسب: ${chargeableAirKg.toStringAsFixed(2)} $unitKg'
                        : 'Chargeable: ${chargeableAirKg.toStringAsFixed(2)} $unitKg',
                    isHighlighted: activeMode?.isGeneralAir ?? false,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    context,
                    title: isArabic ? 'فرق الوزن الخاضع للرسوم' : 'Chargeable Difference',
                    value: chargeableDiffKg > 0.001
                        ? '+${chargeableDiffKg.toStringAsFixed(2)} $unitKg'
                        : '0.00 $unitKg',
                    icon: Icons.price_change_outlined,
                    color: chargeableDiffKg > 0 ? AppTheme.orange : AppTheme.emerald,
                    subtitle: isArabic
                        ? (chargeableDiffKg > 0.001 ? 'فائض لصالح البريد السريع' : 'متطابقان')
                        : (chargeableDiffKg > 0.001 ? 'Higher for Courier' : 'Equal'),
                    isDark: isDark,
                  ),
                ];

                if (isNarrow) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 8),
                          Expanded(child: cards[1]),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: cards[2]),
                          const SizedBox(width: 8),
                          Expanded(child: cards[3]),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 10),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 10),
                    Expanded(child: cards[2]),
                    const SizedBox(width: 10),
                    Expanded(child: cards[3]),
                  ],
                );
              },
            ),
            if (isVolumetricPenalty) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () => CopyHelper.copy(context, penaltyText),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.orangeLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.orange),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          penaltyText,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.wcagOrange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.copy_outlined,
                        color: AppTheme.wcagOrange,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    bool isHighlighted = false,
    required bool isDark,
  }) {
    final borderColor = isHighlighted
        ? AppTheme.cobalt
        : (isDark ? AppTheme.darkBorder : Colors.grey.shade300);
    final bgColor = isHighlighted
        ? AppTheme.cobaltLight.withValues(alpha: isDark ? 0.2 : 0.08)
        : (isDark ? AppTheme.darkSurface : Colors.grey.shade50);

    final copyPayload = subtitle != null ? '$title: $value ($subtitle)' : '$title: $value';

    return InkWell(
      onTap: () => CopyHelper.copy(context, copyPayload),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: isHighlighted ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.copy_outlined,
                  size: 12,
                  color: isDark ? AppTheme.darkTextMuted : Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isHighlighted ? AppTheme.cobalt : (isDark ? AppTheme.darkTextPrimary : color),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
