import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../l10n/po_fulfillment_l10n.dart';
import '../models/purchase_order_model.dart';

/// PO Fulfillment Progress & Balance Widget (EPIC-PO-PART).
/// Displays progress bar and quantities: contracted, shipped, received, remaining.
/// Wrapped in SelectionArea, purely localized, using canonical enterprise widgets.
class POFulfillmentProgressWidget extends StatelessWidget {
  final double contractedQuantity;
  final double shippedQuantity;
  final double receivedQuantity;
  final double remainingQuantity;
  final double fulfillmentPercent;
  final String fulfillmentStatus;
  final String? poNumber;
  final VoidCallback? onAllocatePressed;
  final bool isCompact;

  const POFulfillmentProgressWidget({
    super.key,
    required this.contractedQuantity,
    required this.shippedQuantity,
    required this.receivedQuantity,
    required this.remainingQuantity,
    required this.fulfillmentPercent,
    required this.fulfillmentStatus,
    this.poNumber,
    this.onAllocatePressed,
    this.isCompact = false,
  });

  factory POFulfillmentProgressWidget.fromPO({
    Key? key,
    required PurchaseOrderModel po,
    VoidCallback? onAllocatePressed,
    bool isCompact = false,
  }) {
    final contracted = po.effectiveContractedQuantity;
    final shipped = po.totalShippedQuantity;
    final received = po.totalReceivedQuantity;
    final remaining = po.remainingBalanceQuantity > 0
        ? po.remainingBalanceQuantity
        : (contracted > shipped ? contracted - shipped : 0.0);
    final percent = po.fulfillmentRate;

    return POFulfillmentProgressWidget(
      key: key,
      contractedQuantity: contracted,
      shippedQuantity: shipped,
      receivedQuantity: received,
      remainingQuantity: remaining,
      fulfillmentPercent: percent,
      fulfillmentStatus: po.fulfillmentStatus,
      poNumber: po.displayName,
      onAllocatePressed: onAllocatePressed,
      isCompact: isCompact,
    );
  }

  factory POFulfillmentProgressWidget.fromBalanceSummary({
    Key? key,
    required POBalanceSummaryModel balance,
    VoidCallback? onAllocatePressed,
    bool isCompact = false,
  }) {
    return POFulfillmentProgressWidget(
      key: key,
      contractedQuantity: balance.totalContractedQty,
      shippedQuantity: balance.totalShippedQty,
      receivedQuantity: balance.totalReceivedQty,
      remainingQuantity: balance.totalRemainingQty,
      fulfillmentPercent: balance.overallFulfillmentPercent,
      fulfillmentStatus: balance.fulfillmentStatus,
      poNumber: balance.poNumber,
      onAllocatePressed: onAllocatePressed,
      isCompact: isCompact,
    );
  }

  String _statusLabel(AppLocalizations l, String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
      case 'PENDING':
        return l.poStatusOpen;
      case 'PARTIALLY_SHIPPED':
      case 'PARTIAL':
        return l.poStatusPartiallyShipped;
      case 'FULLY_SHIPPED':
      case 'FULL':
      case 'COMPLETED':
        return l.poStatusFullyShipped;
      case 'OVER_SHIPPED':
      case 'OVER':
        return l.poStatusOverShipped;
      default:
        return status;
    }
  }

  Color _progressColor() {
    if (fulfillmentPercent >= 100.0) {
      return AppTheme.emerald;
    } else if (fulfillmentPercent > 0.0) {
      return AppTheme.cobalt;
    } else {
      return AppTheme.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clampedPercent = (fulfillmentPercent / 100.0).clamp(0.0, 1.0);

    return SelectionArea(
      child: Container(
        decoration: AppTheme.cardDecorationOf(context),
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _progressColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: _progressColor(),
                    size: isCompact ? 18 : 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              l.poFulfillmentProgressTitle,
                              style: TextStyle(
                                fontSize: isCompact ? 13.5 : 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (poNumber != null && poNumber!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isDark ? AppTheme.darkBorder : AppTheme.border).withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                poNumber!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (!isCompact)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            l.poFulfillmentSubtitle,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AppStatusBadge.fromStatus(
                  status: fulfillmentStatus,
                  label: _statusLabel(l, fulfillmentStatus),
                ),
                if (onAllocatePressed != null) ...[
                  const SizedBox(width: 8),
                  AppButton(
                    label: l.poCreatePartialShipmentBtn,
                    icon: Icons.add_task_rounded,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    onPressed: onAllocatePressed,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar with Percentage
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: clampedPercent,
                      minHeight: isCompact ? 8 : 10,
                      backgroundColor: isDark ? AppTheme.darkBorder : AppTheme.border.withValues(alpha: 0.6),
                      valueColor: AlwaysStoppedAnimation<Color>(_progressColor()),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${fulfillmentPercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: isCompact ? 12.5 : 14,
                    fontWeight: FontWeight.bold,
                    color: _progressColor(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quantities Grid
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: l.poContractedQty,
                    value: contractedQuantity,
                    unit: l.poUnitsLabel,
                    icon: Icons.assignment_outlined,
                    color: AppTheme.cobalt,
                    isCompact: isCompact,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: l.poShippedQty,
                    value: shippedQuantity,
                    unit: l.poUnitsLabel,
                    icon: Icons.local_shipping_outlined,
                    color: AppTheme.emerald,
                    isCompact: isCompact,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: l.poReceivedQty,
                    value: receivedQuantity,
                    unit: l.poUnitsLabel,
                    icon: Icons.warehouse_outlined,
                    color: AppTheme.wcagEmerald,
                    isCompact: isCompact,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: l.poRemainingQty,
                    value: remainingQuantity,
                    unit: l.poUnitsLabel,
                    icon: Icons.pending_actions_outlined,
                    color: remainingQuantity > 0 ? AppTheme.orange : AppTheme.darkTextSecondary,
                    isCompact: isCompact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final IconData icon;
  final Color color;
  final bool isCompact;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isDark ? AppTheme.darkBorder : AppTheme.border).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: isCompact ? 13 : 15, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isCompact ? 10.5 : 11.5,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value.toStringAsFixed(value % 1 == 0 ? 0 : 2),
                style: TextStyle(
                  fontSize: isCompact ? 13.5 : 15.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
