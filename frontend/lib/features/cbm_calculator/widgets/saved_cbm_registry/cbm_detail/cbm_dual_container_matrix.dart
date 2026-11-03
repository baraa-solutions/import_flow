import 'package:flutter/material.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/container_requirement_engine.dart';
import '../../../models/cbm_calculator_model.dart';

class CbmDualContainerMatrix extends StatelessWidget {
  final CBMCalculationModel calc;
  final ContainerDualRecommendationResult dualRec;
  final bool isDark;

  const CbmDualContainerMatrix({
    super.key,
    required this.calc,
    required this.dualRec,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkElevatedSurface
            : AppTheme.cobaltLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.cobaltBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.compare_arrows_rounded,
                    color: AppTheme.cobalt,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l.cbmContainerComparisonTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  calc.isStackable
                      ? l.cbmScenarioApprovedStackable
                      : l.cbmScenarioApprovedNonStackable,
                  style: const TextStyle(
                    color: AppTheme.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Table(
            border: TableBorder.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkCardBackground
                      : AppTheme.charcoal.withValues(alpha: 0.06),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      l.cbmScenarioHypothesisCol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      l.cbmScenarioStackableCol,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: AppTheme.emerald,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      l.cbmScenarioNonStackableCol,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: AppTheme.orange,
                      ),
                    ),
                  ),
                ],
              ),
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      l.cbmRequiredContainerCount,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${dualRec.stackableResult.requiredContainersCount} x ${dualRec.stackableResult.recommendedContainerCode}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.emerald,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${dualRec.nonStackableResult.requiredContainersCount} x ${dualRec.nonStackableResult.recommendedContainerCode}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.orange,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      l.cbmSpaceUtilizationPercent,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${dualRec.stackableResult.spaceUtilizationPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${dualRec.nonStackableResult.spaceUtilizationPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
