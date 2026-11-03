import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';

/// Supported volumetric divisors for air cargo calculation.
enum AirFreightDivisorMode {
  /// General Air Freight - IATA Standard: 6000 cm³/kg (Density: 1 m³ = 166.7 kg).
  generalAir(6000.0, 166.6667),

  /// International Express Courier: 5000 cm³/kg (Density: 1 m³ = 200.0 kg).
  expressCourier(5000.0, 200.0);

  final double divisor;
  final double densityKgPerM3;

  const AirFreightDivisorMode(this.divisor, this.densityKgPerM3);

  bool get isGeneralAir => this == AirFreightDivisorMode.generalAir;
  bool get isExpressCourier => this == AirFreightDivisorMode.expressCourier;

  String title(bool isArabic) {
    if (isArabic) {
      return this == AirFreightDivisorMode.generalAir
          ? 'شحن جوي عام - معيار إياتا (قاسم 6000)'
          : 'بريد سريع دولي (قاسم 5000)';
    }
    return this == AirFreightDivisorMode.generalAir
        ? 'General Air Freight - IATA Standard (Divisor 6000)'
        : 'International Express Courier (Divisor 5000)';
  }

  String densityLabel(bool isArabic) {
    if (isArabic) {
      return this == AirFreightDivisorMode.generalAir
          ? '1 م³ = 166.7 كجم'
          : '1 م³ = 200 كجم';
    }
    return this == AirFreightDivisorMode.generalAir
        ? '1 m³ = 166.7 kg'
        : '1 m³ = 200 kg';
  }

  String description(bool isArabic) {
    if (isArabic) {
      return this == AirFreightDivisorMode.generalAir
          ? 'رحلات تجارية منتظمة وبضائع عامة عبر خطوط الطيران'
          : 'شبكات النقل السريع للطرود والمستندات والطرود البريدية';
    }
    return this == AirFreightDivisorMode.generalAir
        ? 'Scheduled commercial flights and general cargo airlines'
    : 'Express parcel networks and expedited courier services';
  }
}

/// Decoupled selector card for dual air volumetric divisors (5000 vs 6000).
/// Strictly adheres to:
/// - Root wrapped in [SelectionArea] for mouse highlighting.
/// - Pure Arabic / English language separation with ZERO bilingual parenthetical stacking.
/// - Approved theme colors and layout styling.
class DualDivisorSelectorCard extends StatelessWidget {
  final AirFreightDivisorMode selectedMode;
  final ValueChanged<AirFreightDivisorMode> onModeChanged;
  final bool showDensityExplanation;

  const DualDivisorSelectorCard({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
    this.showDensityExplanation = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = l.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final densitySummary = isArabic
        ? 'كثافة الشحن المعتمدة: 1 م³ = 166.7 كجم للشحن الجوي العام، و 200 كجم للبريد السريع الدولي.'
        : 'Standard Cargo Density: 1 m³ = 166.7 kg for General Air Freight, and 200 kg for Express Courier.';

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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.cobaltLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.tune_outlined,
                    color: AppTheme.cobalt,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic
                            ? 'معيار احتساب الوزن الحجمي الجوي'
                            : 'Air Volumetric Divisor Standard',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic
                            ? 'اختر القاسم الحجمي المعتمد وفق وسيلة النقل الجوي'
                            : 'Select volumetric divisor according to air freight carrier type',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 620;
                final generalOption = _buildOptionCard(
                  context,
                  mode: AirFreightDivisorMode.generalAir,
                  isArabic: isArabic,
                  isSelected: selectedMode == AirFreightDivisorMode.generalAir,
                  icon: Icons.flight_takeoff,
                  isDark: isDark,
                );
                final courierOption = _buildOptionCard(
                  context,
                  mode: AirFreightDivisorMode.expressCourier,
                  isArabic: isArabic,
                  isSelected: selectedMode == AirFreightDivisorMode.expressCourier,
                  icon: Icons.local_shipping_outlined,
                  isDark: isDark,
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      generalOption,
                      const SizedBox(height: 10),
                      courierOption,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: generalOption),
                    const SizedBox(width: 12),
                    Expanded(child: courierOption),
                  ],
                );
              },
            ),
            if (showDensityExplanation) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () => CopyHelper.copy(context, densitySummary),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.cobaltLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.cobaltBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppTheme.cobalt,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          densitySummary,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.sorourNavy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.copy_outlined,
                        color: AppTheme.cobalt,
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

  Widget _buildOptionCard(
    BuildContext context, {
    required AirFreightDivisorMode mode,
    required bool isArabic,
    required bool isSelected,
    required IconData icon,
    required bool isDark,
  }) {
    const activeColor = AppTheme.cobalt;
    final cardBorderColor = isSelected
        ? activeColor
        : (isDark ? AppTheme.darkBorder : Colors.grey.shade300);
    final cardBgColor = isSelected
        ? activeColor.withValues(alpha: isDark ? 0.15 : 0.07)
        : (isDark ? AppTheme.darkSurface : Colors.grey.shade50);

    return InkWell(
      onTap: () => onModeChanged(mode),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: cardBorderColor,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? activeColor : (isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mode.title(isArabic),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? activeColor
                          : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.cobalt,
                    size: 18,
                  )
                else
                  Icon(
                    Icons.radio_button_unchecked,
                    color: isDark ? AppTheme.darkBorderLight : Colors.grey.shade400,
                    size: 18,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isSelected ? activeColor : Colors.grey).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    mode.densityLabel(isArabic),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? activeColor : (isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                    ),
                  ),
                ),
                Text(
                  isArabic
                      ? 'قاسم ${mode.divisor.toInt()}'
                      : 'Divisor ${mode.divisor.toInt()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              mode.description(isArabic),
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
