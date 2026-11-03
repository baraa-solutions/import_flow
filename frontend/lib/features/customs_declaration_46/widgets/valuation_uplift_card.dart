import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../l10n/valuation_uplift_l10n.dart';

/// ⚖️ Customs Valuation Uplift Card — ImportFlow ERP (EPIC-CUST-VAL)
///
/// Compares the supplier's commercial invoice CIF with the customs-assessed CIF
/// (الوعاء المقبول جمركياً), visualizes valuation uplift variances, and guarantees
/// accounting segregation (Supplier AP 401 undistorted vs. Goods in Transit 151 Landed Cost Addition).
class ValuationUpliftCard extends StatelessWidget {
  final double commercialCifEgp;
  final double customsAssessedCifEgp;
  final double? commercialCifUsd;
  final double? customsAssessedCifUsd;
  final double? customsExchangeRate;
  final bool isValuationUplifted;
  final double? valuationUpliftAmountEgp;
  final String? valuationUpliftReason;
  final VoidCallback? onRecompute;
  final bool isEditable;
  final ValueChanged<double>? onCommercialCifChanged;
  final ValueChanged<double>? onAssessedCifChanged;
  final ValueChanged<String>? onReasonChanged;

  const ValuationUpliftCard({
    super.key,
    required this.commercialCifEgp,
    required this.customsAssessedCifEgp,
    this.commercialCifUsd,
    this.customsAssessedCifUsd,
    this.customsExchangeRate,
    required this.isValuationUplifted,
    this.valuationUpliftAmountEgp,
    this.valuationUpliftReason,
    this.onRecompute,
    this.isEditable = false,
    this.onCommercialCifChanged,
    this.onAssessedCifChanged,
    this.onReasonChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    final effectiveUplift = valuationUpliftAmountEgp ??
        ((customsAssessedCifEgp > commercialCifEgp && commercialCifEgp > 0)
            ? (customsAssessedCifEgp - commercialCifEgp)
            : 0.0);

    final upliftPercentage = (commercialCifEgp > 0 && effectiveUplift > 0)
        ? (effectiveUplift / commercialCifEgp) * 100
        : 0.0;

    final isActuallyUplifted = isValuationUplifted || effectiveUplift > 0;

    return SelectionArea(
      child: Container(
        decoration: AppTheme.cardDecorationOf(context),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Title, Subtitle, Status Badge, and Copy Action
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isActuallyUplifted ? AppTheme.orangeLight : AppTheme.cobaltLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isActuallyUplifted ? Icons.trending_up : Icons.verified_outlined,
                    color: isActuallyUplifted ? AppTheme.orange : AppTheme.cobalt,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            l.valuationUpliftTitle,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.sorourNavy,
                                ),
                          ),
                          const SizedBox(width: 12),
                          AppStatusBadge(
                            label: isActuallyUplifted ? l.statusUplifted : l.statusMatched,
                            severity: isActuallyUplifted ? AppSeverity.warning : AppSeverity.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.valuationUpliftSubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                AppButton(
                  label: l.copyValuationSummaryBtn,
                  variant: AppButtonVariant.secondary,
                  icon: Icons.copy,
                  size: AppButtonSize.small,
                  onPressed: () {
                    final summaryText = [
                      l.valuationUpliftTitle,
                      '${l.commercialInvoiceCifLabel}: ${CcFormat.money(commercialCifEgp)} ${l.egpSuffix}',
                      '${l.customsAssessedCifLabel}: ${CcFormat.money(customsAssessedCifEgp)} ${l.egpSuffix}',
                      '${l.valuationDifferenceLabel}: ${CcFormat.money(effectiveUplift)} ${l.egpSuffix} (+${upliftPercentage.toStringAsFixed(1)}%)',
                      if (valuationUpliftReason != null && valuationUpliftReason!.isNotEmpty)
                        '${l.valuationReasonLabel}: $valuationUpliftReason',
                    ].join('\n');

                    CopyHelper.copy(
                      context,
                      summaryText,
                      customMessage: l.valuationCopiedSuccess,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 20),

            // Comparison Metrics Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 650;
                final cards = [
                  // Commercial Supplier CIF
                  _buildMetricBox(
                    context: context,
                    title: l.commercialInvoiceCifLabel,
                    amountEgp: commercialCifEgp,
                    amountUsd: commercialCifUsd,
                    accentColor: AppTheme.cobalt,
                    icon: Icons.receipt_long_outlined,
                    egpSuffix: l.egpSuffix,
                    usdSuffix: l.usdSuffix,
                  ),
                  // Customs Assessed CIF
                  _buildMetricBox(
                    context: context,
                    title: l.customsAssessedCifLabel,
                    amountEgp: customsAssessedCifEgp,
                    amountUsd: customsAssessedCifUsd,
                    accentColor: isActuallyUplifted ? AppTheme.orange : AppTheme.emerald,
                    icon: Icons.account_balance_outlined,
                    egpSuffix: l.egpSuffix,
                    usdSuffix: l.usdSuffix,
                  ),
                  // Valuation Uplift Difference
                  _buildMetricBox(
                    context: context,
                    title: l.valuationDifferenceLabel,
                    amountEgp: effectiveUplift,
                    percentage: isActuallyUplifted ? upliftPercentage : null,
                    accentColor: isActuallyUplifted ? AppTheme.crimson : AppTheme.emerald,
                    icon: Icons.compare_arrows_outlined,
                    egpSuffix: l.egpSuffix,
                    usdSuffix: l.usdSuffix,
                  ),
                ];

                if (isCompact) {
                  return Column(
                    children: cards
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: c,
                            ))
                        .toList(),
                  );
                }

                return Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 16),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 16),
                    Expanded(child: cards[2]),
                  ],
                );
              },
            ),

            // Uplift Legal/Official Reason (if present)
            if (valuationUpliftReason != null && valuationUpliftReason!.trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.warningBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.orangeLight),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.orange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.valuationReasonLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.warningForeground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            valuationUpliftReason!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.charcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            // Accounting Segregation & Landed Cost Integrity Notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_tree_outlined, color: AppTheme.cobalt, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l.supplierAccountDesc,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.charcoal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: AppTheme.emerald, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l.landedCostAccountDesc,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.charcoal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBox({
    required BuildContext context,
    required String title,
    required double amountEgp,
    double? amountUsd,
    double? percentage,
    required Color accentColor,
    required IconData icon,
    required String egpSuffix,
    required String usdSuffix,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (percentage != null && percentage > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.orangeLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '+${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: AppTheme.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LtrText(
            '${CcFormat.money(amountEgp)} $egpSuffix',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          if (amountUsd != null && amountUsd > 0) ...[
            const SizedBox(height: 4),
            LtrText(
              '${CcFormat.money(amountUsd)} $usdSuffix',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
