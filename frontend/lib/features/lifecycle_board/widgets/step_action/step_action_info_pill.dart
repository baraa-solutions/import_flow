import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/lifecycle_board_model.dart';

class StepActionInfoPill extends StatelessWidget {
  final ShipmentStageCardModel shipment;

  const StepActionInfoPill({super.key, required this.shipment});

  Widget _buildInfoCol(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => CopyHelper.copy(context, value),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.0,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                        color: color ?? AppTheme.textPrimaryOf(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.copy_rounded,
                    size: 11,
                    color: AppTheme.textMutedOf(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final estimatedVal = shipment.estimatedCost != null
        ? '${shipment.estimatedCost!.toStringAsFixed(0)} ${shipment.estimatedCostCurrency ?? ""}'
        : '-';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        children: [
          _buildInfoCol(context, l10n.importFileLabel, shipment.importFileCode, isBold: true, color: AppTheme.cobalt),
          _buildInfoCol(context, l10n.importingCompanyLabel, shipment.companyName),
          _buildInfoCol(context, l10n.foreignSupplierLabel, shipment.supplierName),
          _buildInfoCol(context, l10n.purchaseOrderLabel, shipment.poNumber ?? 'N/A'),
          _buildInfoCol(context, l10n.estimatedValueLabel, estimatedVal, isBold: true, color: AppTheme.emerald),
        ],
      ),
    );
  }
}
