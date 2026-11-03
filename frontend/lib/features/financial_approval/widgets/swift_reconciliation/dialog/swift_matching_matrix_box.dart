import 'package:flutter/material.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../models/financial_approval_model.dart';

class SwiftMatchingMatrixBox extends StatelessWidget {
  final PaymentRequestModel pay;
  final double transferredAmt;
  final int? safeDays;

  const SwiftMatchingMatrixBox({
    super.key,
    required this.pay,
    required this.transferredAmt,
    required this.safeDays,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final variance = transferredAmt - pay.requestedAmount;

    Color varianceColor;
    IconData varianceIcon;
    String varianceText;

    if (transferredAmt <= 0) {
      varianceColor = AppTheme.textMuted;
      varianceIcon = Icons.hourglass_empty;
      varianceText = l10n.swiftWaitingAmountEntry;
    } else if (variance.abs() < 0.001) {
      varianceColor = AppTheme.emerald;
      varianceIcon = Icons.check_circle;
      varianceText = l10n.swiftBadgeMatchedFull;
    } else if (variance < 0) {
      varianceColor = AppTheme.crimson;
      varianceIcon = Icons.arrow_downward;
      varianceText = l10n.swiftBadgeDeficit(
        variance.abs().toStringAsFixed(2),
        pay.currencyCode,
      );
    } else {
      varianceColor = AppTheme.orange;
      varianceIcon = Icons.arrow_upward;
      varianceText = l10n.swiftBadgeSurplus(
        variance.toStringAsFixed(2),
        pay.currencyCode,
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: varianceColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: varianceColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(varianceIcon, color: varianceColor, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.swiftMatchingMatrixTitle,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: varianceColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                safeDays != null ? l10n.swiftDaysBetweenDates(safeDays!) : '-',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (safeDays != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: safeDays! <= 3
                        ? AppTheme.emeraldLight
                        : (safeDays! <= 7
                            ? AppTheme.orangeLight
                            : AppTheme.crimsonLight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    safeDays! <= 3
                        ? l10n.swiftExecutionInstantTag(safeDays!)
                        : (safeDays! <= 7
                            ? l10n.swiftExecutionReasonableTag(safeDays!)
                            : l10n.swiftExecutionDelayedTag(safeDays!)),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: safeDays! <= 3
                          ? AppTheme.wcagEmerald
                          : (safeDays! <= 7
                              ? AppTheme.wcagOrange
                              : AppTheme.crimson),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${l10n.swiftRequestedAmountLabel}: ${pay.requestedAmount.toStringAsFixed(2)} ${pay.currencyCode}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.swiftTransferredAmountLabel}: ${transferredAmt.toStringAsFixed(2)} ${pay.currencyCode}',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: varianceColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  varianceText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: varianceColor,
                  ),
                ),
              ),
              if (variance != 0) ...[
                const SizedBox(width: 8),
                Text(
                  '${l10n.swiftVarianceLabel}: ${variance >= 0 ? "+" : ""}${variance.toStringAsFixed(2)} ${pay.currencyCode}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: varianceColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
