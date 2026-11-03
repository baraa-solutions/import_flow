import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/container_requirement_engine.dart';

class PoPlanner3dControlsToolbar extends StatelessWidget {
  final CargoOrientationPreference activeOrientationMode;
  final bool? activeStackingMode;
  final String viewProjection;
  final void Function(CargoOrientationPreference orientation, bool? stacking) onStackingModeSelected;
  final ValueChanged<String> onProjectionSelected;

  const PoPlanner3dControlsToolbar({
    super.key,
    required this.activeOrientationMode,
    required this.activeStackingMode,
    required this.viewProjection,
    required this.onStackingModeSelected,
    required this.onProjectionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoalSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '🔄 ${l.stackingSimulationModeLabel}:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              ChoiceChip(
                label: Text('✨ ${l.smartHybridOption}'),
                selected: activeOrientationMode == CargoOrientationPreference.smartHybrid &&
                    activeStackingMode == true,
                selectedColor: AppTheme.emerald,
                labelStyle: TextStyle(
                  color: (activeOrientationMode == CargoOrientationPreference.smartHybrid &&
                          activeStackingMode == true)
                      ? AppTheme.white
                      : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) {
                    onStackingModeSelected(CargoOrientationPreference.smartHybrid, true);
                  }
                },
              ),
              ChoiceChip(
                label: Text('📐 ${l.flatOnlyOption}'),
                selected: activeOrientationMode == CargoOrientationPreference.flatOnly &&
                    activeStackingMode == true,
                selectedColor: AppTheme.cobalt,
                labelStyle: TextStyle(
                  color: (activeOrientationMode == CargoOrientationPreference.flatOnly &&
                          activeStackingMode == true)
                      ? AppTheme.white
                      : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) {
                    onStackingModeSelected(CargoOrientationPreference.flatOnly, true);
                  }
                },
              ),
              ChoiceChip(
                label: Text('🚫 ${l.simulationModeFloorOnly}'),
                selected: activeStackingMode == false,
                selectedColor: AppTheme.wcagOrange,
                labelStyle: TextStyle(
                  color: activeStackingMode == false
                      ? AppTheme.white
                      : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) {
                    onStackingModeSelected(activeOrientationMode, false);
                  }
                },
              ),
              ChoiceChip(
                label: Text('🔀 ${l.simulationModeActualMixed}'),
                selected: activeStackingMode == null,
                selectedColor: AppTheme.charcoal,
                labelStyle: TextStyle(
                  color: activeStackingMode == null
                      ? AppTheme.white
                      : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) {
                    onStackingModeSelected(activeOrientationMode, null);
                  }
                },
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '👁️ ${l.projectionLabel}:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              ChoiceChip(
                label: Text(l.poBothViews),
                selected: viewProjection == 'both',
                selectedColor: AppTheme.cobalt,
                labelStyle: TextStyle(
                  color: viewProjection == 'both'
                      ? AppTheme.white
                      : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) onProjectionSelected('both');
                },
              ),
              ChoiceChip(
                label: Text('📐 ${l.sideViewProjection}'),
                selected: viewProjection == 'side',
                selectedColor: AppTheme.cobalt,
                labelStyle: TextStyle(
                  color: viewProjection == 'side'
                      ? AppTheme.white
                      : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) onProjectionSelected('side');
                },
              ),
              ChoiceChip(
                label: Text('🔝 ${l.topViewProjection}'),
                selected: viewProjection == 'top',
                selectedColor: AppTheme.cobalt,
                labelStyle: TextStyle(
                  color: viewProjection == 'top'
                      ? AppTheme.white
                      : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) onProjectionSelected('top');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
