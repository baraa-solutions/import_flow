import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../consultation_metric_badge.dart';

/// Financial summary metric matrix and duties estimate linking action bar.
class DutiesCalcActionsBar extends StatelessWidget {
  final String customsCurrency;
  final double totalFobForeign;
  final double totalFobEgp;
  final double totalCifForeign;
  final double totalCifEgp;
  final double totalDutyEgp;
  final double totalVatEgp;
  final double totalTaxesAndDutiesEgp;
  final double? engineGrandTotal;
  final bool isEstimatingDuty;
  final VoidCallback onApplyAndLinkFinancialEstimate;

  const DutiesCalcActionsBar({
    super.key,
    required this.customsCurrency,
    required this.totalFobForeign,
    required this.totalFobEgp,
    required this.totalCifForeign,
    required this.totalCifEgp,
    required this.totalDutyEgp,
    required this.totalVatEgp,
    required this.totalTaxesAndDutiesEgp,
    this.engineGrandTotal,
    this.isEstimatingDuty = false,
    required this.onApplyAndLinkFinancialEstimate,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final egpLabel = l.financialSettlementCurrencyEgp;

    return SelectionArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.charcoal.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.cobalt.withValues(alpha: 0.3),
          ),
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConsultationMetricBadge(
              title: l.fobEgpCol,
              value:
                  '${totalFobForeign.toStringAsFixed(2)} $customsCurrency\n(${totalFobEgp.toStringAsFixed(2)} $egpLabel)',
              color: AppTheme.charcoal,
            ),
            ConsultationMetricBadge(
              title: l.cifEgpCol,
              value:
                  '${totalCifForeign.toStringAsFixed(2)} $customsCurrency\n(${totalCifEgp.toStringAsFixed(2)} $egpLabel)',
              color: AppTheme.cobalt,
            ),
            ConsultationMetricBadge(
              title: l.customsDutyCol,
              value: '${totalDutyEgp.toStringAsFixed(2)} $egpLabel',
              color: AppTheme.cobalt,
            ),
            ConsultationMetricBadge(
              title: l.vatCol,
              value: '${totalVatEgp.toStringAsFixed(2)} $egpLabel',
              color: AppTheme.emerald,
            ),
            ConsultationMetricBadge(
              title: l.totalTaxesAndDutiesCol,
              value:
                  '${(engineGrandTotal ?? totalTaxesAndDutiesEgp).toStringAsFixed(2)} $egpLabel',
              color: AppTheme.crimson,
            ),
            if (isEstimatingDuty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.cobalt,
                  ),
                ),
              ),
            AppButton(
              label: l.applyAndLinkFinancialEstimate,
              icon: Icons.done_all,
              variant: AppButtonVariant.success,
              size: AppButtonSize.small,
              onPressed: onApplyAndLinkFinancialEstimate,
            ),
          ],
        ),
      ),
    );
  }
}
