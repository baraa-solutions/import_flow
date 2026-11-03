import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../settlement_ui.dart';

class LandedCostMetricStrip extends StatelessWidget {
  final double totalExpenses;
  final double totalLanded;
  final double? landedVariance;
  final double? estimatedCostDisplay;

  const LandedCostMetricStrip({
    super.key,
    required this.totalExpenses,
    required this.totalLanded,
    required this.landedVariance,
    required this.estimatedCostDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final egp = l10n.financialSettlementCurrencyEgp;
    final varianceColor = landedVariance == null
        ? AppTheme.textSecondary
        : landedVariance! > 0
            ? AppTheme.crimson
            : AppTheme.emerald;

    return MetricCardStrip(
      padding: EdgeInsets.zero,
      metrics: [
        MetricCardData(
          title: l10n.estimatedCostHeader,
          value: estimatedCostDisplay != null ? '${formatSettlementMoney(estimatedCostDisplay!)} $egp' : '-',
          icon: Icons.request_quote_outlined,
          color: AppTheme.cobalt,
        ),
        MetricCardData(
          title: l10n.totalExpensesCardTitle,
          value: '${formatSettlementMoney(totalExpenses)} $egp',
          icon: Icons.receipt_long_outlined,
          color: AppTheme.orange,
        ),
        MetricCardData(
          title: l10n.totalLandedCostCardTitle,
          value: '${formatSettlementMoney(totalLanded)} $egp',
          icon: Icons.account_balance_wallet_outlined,
          color: AppTheme.emerald,
        ),
        MetricCardData(
          title: l10n.settlementCmpVarianceLabel,
          value: landedVariance != null ? formatSettlementPercent(landedVariance!, digits: 2) : '-',
          icon: landedVariance == null
              ? Icons.remove
              : landedVariance! > 0
                  ? Icons.trending_up
                  : Icons.trending_down,
          color: varianceColor,
        ),
      ],
    );
  }
}

class LandedCostSummaryCards extends StatelessWidget {
  final double totalFob;
  final double totalExpenses;
  final double totalLanded;
  final double? fobVariance;
  final double? landedVariance;
  final double? estimatedCostDisplay;

  const LandedCostSummaryCards({
    super.key,
    required this.totalFob,
    required this.totalExpenses,
    required this.totalLanded,
    required this.fobVariance,
    required this.landedVariance,
    required this.estimatedCostDisplay,
  });

  Widget _buildCard(BuildContext context, String title, double? est, double act, double? variance, {bool highlight = false}) {
    final l10n = context.l10n;
    final varColor = variance == null ? null : (variance > 0 ? AppTheme.crimson : AppTheme.emerald);

    final estStr = est != null ? est.toStringAsFixed(2) : '-';
    final summary = '$title: ${l10n.estAbbreviation} $estStr | ${l10n.actAbbreviation} ${act.toStringAsFixed(2)}${variance != null ? " (${variance > 0 ? '+' : ''}${variance.toStringAsFixed(2)}%)" : ""}';

    return Card(
      elevation: highlight ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        side: highlight
            ? const BorderSide(color: AppTheme.charcoal, width: 1.5)
            : BorderSide(color: SettlementTokens.border),
      ),
      child: InkWell(
        onTap: () => CopyHelper.copy(context, summary, customMessage: title),
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                  ),
                  const Icon(Icons.copy, size: 14, color: AppTheme.textMuted),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.estAbbreviation, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      LtrText(
                        est != null ? formatSettlementMoney(est) : '-',
                        style: const TextStyle(fontSize: 15, color: AppTheme.cobalt, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(l10n.actAbbreviation, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      LtrText(
                        formatSettlementMoney(act),
                        style: const TextStyle(fontSize: 15, color: AppTheme.emerald, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              if (variance != null) ...[
                const SizedBox(height: 8),
                SettlementStatusChip(
                  label: formatSettlementPercent(variance, digits: 2),
                  color: varColor!,
                  icon: variance > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  dense: true,
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildCard(context, l10n.fobValueCardTitle, null, totalFob, fobVariance)),
        const SizedBox(width: 16),
        Expanded(child: _buildCard(context, l10n.totalExpensesCardTitle, null, totalExpenses, null)),
        const SizedBox(width: 16),
        Expanded(child: _buildCard(context, l10n.totalLandedCostCardTitle, estimatedCostDisplay, totalLanded, landedVariance, highlight: true)),
      ],
    );
  }
}

class LandedCostSummaryBanner extends StatelessWidget {
  final double? landedVariance;

  const LandedCostSummaryBanner({
    super.key,
    required this.landedVariance,
  });

  @override
  Widget build(BuildContext context) {
    if (landedVariance == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    if (landedVariance! > 10) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.crimson.withValues(alpha: 0.1),
          border: Border.all(color: AppTheme.crimson),
          borderRadius: BorderRadius.circular(SettlementTokens.radius),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: AppTheme.crimson),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                l10n.landedCostOverBudgetBanner(landedVariance!.toStringAsFixed(2)),
                style: const TextStyle(color: AppTheme.crimson, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } else if (landedVariance! < 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.emerald.withValues(alpha: 0.1),
          border: Border.all(color: AppTheme.emerald),
          borderRadius: BorderRadius.circular(SettlementTokens.radius),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.emerald),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                l10n.landedCostUnderBudgetBanner(landedVariance!.abs().toStringAsFixed(2)),
                style: const TextStyle(color: AppTheme.emerald, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
