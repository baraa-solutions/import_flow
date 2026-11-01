import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/cbm_calculator_model.dart';

/// Mobile card list for CBM registry records on narrow viewports.
class CbmRegistryMobileList extends StatelessWidget {
  final List<CBMCalculationModel> calculations;
  final void Function(CBMCalculationModel calc) onView;
  final void Function(CBMCalculationModel calc) onEdit;
  final void Function(CBMCalculationModel calc) onClone;
  final void Function(CBMCalculationModel calc) onPrint;
  final void Function(CBMCalculationModel calc) onDelete;

  const CbmRegistryMobileList({
    super.key,
    required this.calculations,
    required this.onView,
    required this.onEdit,
    required this.onClone,
    required this.onPrint,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: ListView.separated(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
        itemCount: calculations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final calc = calculations[index];
          final isAir = calc.isAirRecommended;

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: !calc.isActive
                  ? (isDark
                      ? AppTheme.crimson.withValues(alpha: 0.2)
                      : AppTheme.crimsonLight)
                  : (isDark ? AppTheme.darkCardBackground : AppTheme.white),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Code, Title, Mode chip
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => onView(calc),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              calc.calcCode,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppTheme.darkHyperlink
                                    : AppTheme.cobalt,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              calc.title ?? calc.calcCode,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.charcoal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AppStatusBadge(
                      label: calc.shippingMethodLabel(l),
                      severity: isAir ? AppSeverity.info : AppSeverity.success,
                      size: AppStatusBadgeSize.small,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Metrics row
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${l.totalCbmVolumeMetric}: ${calc.totalCbm.toStringAsFixed(2)} m³',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.wcagOrange,
                      ),
                    ),
                    Text(
                      '${l.grossWeightMetric}: ${calc.totalGrossWeightKg.toStringAsFixed(0)} kg',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textStrong,
                      ),
                    ),
                    if (calc.totalVolumetricWeightKg > 0)
                      Text(
                        '${l.volumetricWeight}: ${calc.totalVolumetricWeightKg.toStringAsFixed(0)} kg',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.cobalt,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                // Stacking / packages count
                Text(
                  '${l.stackingCol}: ${calc.isStackable ? l.stackable : l.nonStackable} | ${calc.items.length} ${l.itemsAndPackagesCol}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
                ),

                const Divider(height: 16),

                // Actions pill at bottom start
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: RowActionsPill(
                    onView: () => onView(calc),
                    onEdit: () => onEdit(calc),
                    onClone: () => onClone(calc),
                    cloneTooltip: l.cloneRowTooltip,
                    onPrint: () => onPrint(calc),
                    onDelete: () => onDelete(calc),
                    viewTooltip: l.viewDetails,
                    editTooltip: l.edit,
                    printTooltip: l.exportPdf,
                    deleteTooltip: calc.isActive ? l.delete : l.restore,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
