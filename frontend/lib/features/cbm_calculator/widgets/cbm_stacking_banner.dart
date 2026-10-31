import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/widgets/widgets.dart';

class CbmStackingBanner extends StatelessWidget {
  final bool isStackable;
  final ValueChanged<bool> onStackableChanged;
  final VoidCallback onCompareContainers;
  final VoidCallback onVisualLoadPlan;
  final ContainerDualRecommendationResult dualRec;

  const CbmStackingBanner({
    super.key,
    required this.isStackable,
    required this.onStackableChanged,
    required this.onCompareContainers,
    required this.onVisualLoadPlan,
    required this.dualRec,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final modeRec = dualRec.modeRecommendation;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: modeRec.isAirSuggested
            ? (isDark ? AppTheme.cobalt.withValues(alpha: 0.15) : AppTheme.cobaltLight)
            : (modeRec.isLclSuggested
                ? (isDark ? AppTheme.orange.withValues(alpha: 0.15) : AppTheme.orangeLight)
                : AppTheme.cobalt.withValues(alpha: isDark ? 0.15 : 0.08)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: modeRec.isAirSuggested
              ? AppTheme.cobaltBorder
              : (modeRec.isLclSuggested ? AppTheme.orange : AppTheme.cobalt.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.inventory_2, color: AppTheme.cobalt, size: 22),
                  const SizedBox(width: 4),
                  Text(
                    l.cargoStackingInstructions,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(width: 4),
                  ChoiceChip(
                    label: Text(l.stackableOption),
                    selected: isStackable,
                    selectedColor: AppTheme.cobalt,
                    labelStyle: TextStyle(
                      color: isStackable ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    onSelected: (val) => onStackableChanged(true),
                  ),
                  ChoiceChip(
                    label: Text(l.nonStackableOption),
                    selected: !isStackable,
                    selectedColor: AppTheme.wcagOrange,
                    labelStyle: TextStyle(
                      color: !isStackable ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    onSelected: (val) => onStackableChanged(false),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppButton(
                    label: l.compareContainersMatrix,
                    icon: Icons.table_chart,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    onPressed: onCompareContainers,
                  ),
                  AppButton(
                    label: l.visualLoadPlanSimulator,
                    icon: Icons.view_in_ar,
                    variant: AppButtonVariant.success,
                    size: AppButtonSize.small,
                    onPressed: onVisualLoadPlan,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
            ),
            child: Row(
              children: [
                Icon(
                  modeRec.isAirSuggested
                      ? Icons.airplanemode_active
                      : (modeRec.isLclSuggested ? Icons.inventory : Icons.directions_boat),
                  color: modeRec.isAirSuggested
                      ? AppTheme.cobalt
                      : (modeRec.isLclSuggested ? AppTheme.wcagOrange : AppTheme.cobalt),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic ? modeRec.reasonAr : modeRec.reasonEn,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: modeRec.isAirSuggested
                          ? AppTheme.wcagCobalt
                          : (modeRec.isLclSuggested ? AppTheme.wcagOrange : AppTheme.charcoal),
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
}
