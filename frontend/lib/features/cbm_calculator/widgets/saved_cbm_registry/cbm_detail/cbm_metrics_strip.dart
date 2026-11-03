import 'package:flutter/material.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/container_requirement_engine.dart';
import '../../../models/cbm_calculator_model.dart';

class CbmMetricsStrip extends StatelessWidget {
  final CBMCalculationModel calc;
  final ContainerRecommendationResult containerRec;
  final bool isArabic;
  final bool isDark;

  const CbmMetricsStrip({
    super.key,
    required this.calc,
    required this.containerRec,
    required this.isArabic,
    required this.isDark,
  });

  Widget _buildDetailCardBadge(
    BuildContext context,
    String title,
    String val,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  val,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.cbmStandardMetricsTitle,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildDetailCardBadge(
              context,
              l.totalCbmVolumeMetric,
              '${calc.totalCbm.toStringAsFixed(4)} m³',
              Icons.view_in_ar_rounded,
              AppTheme.wcagOrange,
            ),
            _buildDetailCardBadge(
              context,
              l.airChargeableWtMetric,
              '${calc.airChargeableWeightKg.toStringAsFixed(1)} KG',
              Icons.airplanemode_active,
              AppTheme.wcagCobalt,
            ),
            _buildDetailCardBadge(
              context,
              l.totalGrossWeightRegistryMetric,
              '${calc.totalGrossWeightKg.toStringAsFixed(1)} KG',
              Icons.scale_rounded,
              AppTheme.cobalt,
            ),
            _buildDetailCardBadge(
              context,
              l.cargoStackingInstructions,
              calc.isStackable ? l.stackableOption : l.nonStackableOption,
              Icons.inventory_2_rounded,
              calc.isStackable ? AppTheme.emerald : AppTheme.wcagOrange,
            ),
            _buildDetailCardBadge(
              context,
              l.cbmShipmentMode,
              calc.shipmentModeLabel(l),
              Icons.flight_takeoff_rounded,
              AppTheme.cobalt,
            ),
            _buildDetailCardBadge(
              context,
              l.shippingStrategyCol,
              calc.shippingMethodLabel(l),
              Icons.directions_boat_rounded,
              AppTheme.wcagCobalt,
            ),
            _buildDetailCardBadge(
              context,
              l.recommendedContainerCol,
              isArabic
                  ? containerRec.recommendationSummary
                  : containerRec.recommendationSummaryEn,
              Icons.local_shipping_rounded,
              AppTheme.wcagOrange,
            ),
          ],
        ),
      ],
    );
  }
}
