import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

/// Scenario switching action bar for the Visual Container Load Planner.
/// Allows toggling between All Stackable, All Non-Stackable, and Mixed Stacking modes.
class LoadPlannerActionsBar extends StatelessWidget {
  final bool? activeStackingMode;
  final ValueChanged<bool?> onScenarioChanged;

  const LoadPlannerActionsBar({
    super.key,
    required this.activeStackingMode,
    required this.onScenarioChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '🔄 ${l.cargoStackingScenariosTitle}:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                key: const Key('scenarioChip_1'),
                label: Text('📦 1. ${l.allStackableChip}'),
                selected: activeStackingMode == true,
                selectedColor: AppTheme.emerald,
                backgroundColor: isDark ? AppTheme.darkCardBackground : null,
                labelStyle: TextStyle(
                  color: activeStackingMode == true
                      ? Colors.white
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) onScenarioChanged(true);
                },
              ),
              ChoiceChip(
                key: const Key('scenarioChip_2'),
                label: Text('🚫 2. ${l.allNonStackableChip}'),
                selected: activeStackingMode == false,
                selectedColor: Colors.orange.shade800,
                backgroundColor: isDark ? AppTheme.darkCardBackground : null,
                labelStyle: TextStyle(
                  color: activeStackingMode == false
                      ? Colors.white
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) onScenarioChanged(false);
                },
              ),
              ChoiceChip(
                key: const Key('scenarioChip_3'),
                label: Text('🔀 3. ${l.mixedStackingChip}'),
                selected: activeStackingMode == null,
                selectedColor: AppTheme.cobalt,
                backgroundColor: isDark ? AppTheme.darkCardBackground : null,
                labelStyle: TextStyle(
                  color: activeStackingMode == null
                      ? Colors.white
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) onScenarioChanged(null);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
