import 'package:flutter/material.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/container_requirement_engine.dart';

class PoLoadPlannerControlsBar extends StatelessWidget {
  final CargoOrientationPreference activeOrientationMode;
  final bool? activeStackingMode;
  final String viewProjection;
  final bool isArabic;
  final void Function(CargoOrientationPreference orientation, bool? stacking) onModeChanged;
  final ValueChanged<String> onProjectionChanged;

  const PoLoadPlannerControlsBar({
    super.key,
    required this.activeOrientationMode,
    required this.activeStackingMode,
    required this.viewProjection,
    required this.isArabic,
    required this.onModeChanged,
    required this.onProjectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.charcoalSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cloudWhite),
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
                '🔄 ${context.l10n.stackingSimulationModeLabel}:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
              ),
              ChoiceChip(
                label: Text('✨ ${context.l10n.smartHybridOption}'),
                selected: activeOrientationMode == CargoOrientationPreference.smartHybrid && activeStackingMode == true,
                selectedColor: AppTheme.emerald,
                labelStyle: TextStyle(
                  color: (activeOrientationMode == CargoOrientationPreference.smartHybrid && activeStackingMode == true) ? AppTheme.white : AppTheme.charcoal,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) {
                    onModeChanged(CargoOrientationPreference.smartHybrid, true);
                  }
                },
              ),
              ChoiceChip(
                label: Text('📐 ${context.l10n.flatOnlyOption}'),
                selected: activeOrientationMode == CargoOrientationPreference.flatOnly && activeStackingMode == true,
                selectedColor: AppTheme.cobalt,
                labelStyle: TextStyle(
                  color: (activeOrientationMode == CargoOrientationPreference.flatOnly && activeStackingMode == true) ? AppTheme.white : AppTheme.charcoal,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) {
                    onModeChanged(CargoOrientationPreference.flatOnly, true);
                  }
                },
              ),
              ChoiceChip(
                label: Text('🚫 ${context.l10n.simulationModeFloorOnly}'),
                selected: activeStackingMode == false,
                selectedColor: AppTheme.wcagOrange,
                labelStyle: TextStyle(
                  color: activeStackingMode == false ? AppTheme.white : AppTheme.charcoal,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) {
                    onModeChanged(activeOrientationMode, false);
                  }
                },
              ),
              ChoiceChip(
                label: Text('🔀 ${context.l10n.simulationModeActualMixed}'),
                selected: activeStackingMode == null,
                selectedColor: AppTheme.charcoal,
                labelStyle: TextStyle(
                  color: activeStackingMode == null ? AppTheme.white : AppTheme.charcoal,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) {
                    onModeChanged(activeOrientationMode, null);
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
                '👁️ ${context.l10n.projectionLabel}:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
              ),
              ChoiceChip(
                label: Text(isArabic ? '🖼️ كلاهما' : '🖼️ Both Views'),
                selected: viewProjection == 'both',
                selectedColor: AppTheme.cobalt,
                labelStyle: TextStyle(
                  color: viewProjection == 'both' ? AppTheme.white : AppTheme.charcoal,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) onProjectionChanged('both');
                },
              ),
              ChoiceChip(
                label: Text('📐 ${context.l10n.sideViewProjection}'),
                selected: viewProjection == 'side',
                selectedColor: AppTheme.cobalt,
                labelStyle: TextStyle(
                  color: viewProjection == 'side' ? AppTheme.white : AppTheme.charcoal,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) onProjectionChanged('side');
                },
              ),
              ChoiceChip(
                label: Text('🔝 ${context.l10n.topViewProjection}'),
                selected: viewProjection == 'top',
                selectedColor: AppTheme.cobalt,
                labelStyle: TextStyle(
                  color: viewProjection == 'top' ? AppTheme.white : AppTheme.charcoal,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) onProjectionChanged('top');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
