import 'package:flutter/material.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../models/cbm_calculator_model.dart';

class CbmPackagesBreakdownTable extends StatelessWidget {
  final CBMCalculationModel calc;
  final bool isDark;

  const CbmPackagesBreakdownTable({
    super.key,
    required this.calc,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Package Breakdown Section Header & Action Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l.packageMeasurementsTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
            AppButton(
              label: l.visualLoadPlanSimulator,
              icon: Icons.view_in_ar,
              variant: AppButtonVariant.success,
              size: AppButtonSize.small,
              onPressed: () {
                CargoLoadPlannerDialog.showFromCbmItems(
                  context,
                  items: calc.items,
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Table of Packages
        Table(
          border: TableBorder.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
          ),
          columnWidths: const {
            0: FlexColumnWidth(0.6),
            1: FlexColumnWidth(1.8),
            2: FlexColumnWidth(1.0),
            3: FlexColumnWidth(2.0),
            4: FlexColumnWidth(1.4),
            5: FlexColumnWidth(1.5),
            6: FlexColumnWidth(1.6),
            7: FlexColumnWidth(1.6),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkCardBackground
                    : AppTheme.charcoal.withValues(alpha: 0.08),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    l.packageTypeCol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    l.qtyCol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    l.cbmPackageDimensionsCol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    l.grossWtPerUnitCol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    l.totalGrossWeightRegistryMetric,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    l.stackingCol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    l.cbmVolumeMetric,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
              ],
            ),
            ...calc.items.asMap().entries.map(
              (entry) {
                final idx = entry.key;
                final item = entry.value;
                final lineGross = item.quantity * item.grossWeightPerUnitKg;
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        item.packageType,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${item.quantity}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${item.lengthCm} x ${item.widthCm} x ${item.heightCm}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${item.grossWeightPerUnitKg} kg',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${lineGross.toStringAsFixed(1)} kg',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: item.isStackable
                              ? (isDark
                                  ? AppTheme.emerald.withValues(alpha: 0.15)
                                  : AppTheme.emeraldLight)
                              : (isDark
                                  ? AppTheme.crimson.withValues(alpha: 0.15)
                                  : AppTheme.crimsonLight),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: item.isStackable
                                ? (isDark
                                    ? AppTheme.emerald
                                    : AppTheme.emeraldBorder)
                                : (isDark
                                    ? AppTheme.crimson
                                    : AppTheme.crimsonBorder),
                          ),
                        ),
                        child: Text(
                          item.isStackable ? l.stackableOption : l.nonStackableOption,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: item.isStackable
                                ? AppTheme.emerald
                                : AppTheme.crimson,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${item.totalCbm.toStringAsFixed(4)} m³',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.wcagOrange,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
