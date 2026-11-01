import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/customs_consultation_model.dart';
import '../consultation_metric_badge.dart';
import '../nafeza_fee_breakdown_card.dart';

/// Card displaying landed cost financial summary, duty/tax breakdown, and official Nafeza schedule.
class ConsultationCalcSummaryCard extends StatelessWidget {
  final double totalFobForeign;
  final double totalFobEgp;
  final double totalCifForeign;
  final double totalCifEgp;
  final double totalDutyEgp;
  final double totalVatEgp;
  final double totalScheduleTaxEgp;
  final double totalDevFeeEgp;
  final double totalServiceFeeEgp;
  final double totalTaxesAndDutiesEgp;
  final double totalBrokerFeesEgp;
  final String customsCurrency;
  final double? engineGrandTotal;
  final bool isEstimatingDuty;
  final VoidCallback onApplyAndLinkFinancialEstimate;

  // Nafeza context
  final List<CustomsItemCalcRow> calcLines;
  final double totalFreightEgp;
  final double totalInsuranceEgp;
  final double exchangeRate;
  final int? editingConsultationId;
  final String? editingConsultationCode;
  final int? selectedBrokerId;
  final String selectedBrokerName;
  final String title;
  final List<CustomsChecklistItemModel> checklist;
  final List<CustomsBrokerQuoteItemModel> brokerQuoteItems;
  final int? selectedImportFileId;

  const ConsultationCalcSummaryCard({
    super.key,
    required this.totalFobForeign,
    required this.totalFobEgp,
    required this.totalCifForeign,
    required this.totalCifEgp,
    required this.totalDutyEgp,
    required this.totalVatEgp,
    required this.totalScheduleTaxEgp,
    required this.totalDevFeeEgp,
    required this.totalServiceFeeEgp,
    required this.totalTaxesAndDutiesEgp,
    this.totalBrokerFeesEgp = 0.0,
    required this.customsCurrency,
    this.engineGrandTotal,
    this.isEstimatingDuty = false,
    required this.onApplyAndLinkFinancialEstimate,
    required this.calcLines,
    required this.totalFreightEgp,
    required this.totalInsuranceEgp,
    required this.exchangeRate,
    this.editingConsultationId,
    this.editingConsultationCode,
    this.selectedBrokerId,
    required this.selectedBrokerName,
    required this.title,
    required this.checklist,
    required this.brokerQuoteItems,
    this.selectedImportFileId,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final egpLabel = l.financialSettlementCurrencyEgp;

    final effectiveDutiesAndTaxes = engineGrandTotal ?? totalTaxesAndDutiesEgp;
    final totalLandedCost = totalCifEgp + effectiveDutiesAndTaxes + totalBrokerFeesEgp;

    return SelectionArea(
      child: Card(
        elevation: 2,
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      color: AppTheme.emerald, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.financialSettlementStageTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          ),
                        ),
                        Text(
                          l.customsCalculationEngineSub,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
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
              const Divider(height: 20),

              // Landed Cost & Metric Badges Matrix
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkElevatedSurface
                      : AppTheme.charcoal.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.cobalt.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
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
                          title: l.otherTaxesCol,
                          value:
                              '${(totalScheduleTaxEgp + totalDevFeeEgp + totalServiceFeeEgp).toStringAsFixed(2)} $egpLabel',
                          color: AppTheme.orange,
                        ),
                        ConsultationMetricBadge(
                          title: l.totalTaxesAndDutiesCol,
                          value:
                              '${effectiveDutiesAndTaxes.toStringAsFixed(2)} $egpLabel',
                          color: AppTheme.crimson,
                        ),
                        ConsultationMetricBadge(
                          title: l.totalLandedCostCardTitle,
                          value: '${totalLandedCost.toStringAsFixed(2)} $egpLabel',
                          color: AppTheme.emerald,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Nafeza Fee Breakdown Schedule
              NafezaFeeBreakdownCard(
                calcLines: calcLines,
                totalDutyEgp: totalDutyEgp,
                totalVatEgp: totalVatEgp,
                totalServiceFeeEgp: totalServiceFeeEgp,
                totalScheduleTaxEgp: totalScheduleTaxEgp,
                totalFreightEgp: totalFreightEgp,
                totalInsuranceEgp: totalInsuranceEgp,
                exchangeRate: exchangeRate,
                editingConsultationId: editingConsultationId,
                editingConsultationCode: editingConsultationCode,
                selectedBrokerId: selectedBrokerId,
                selectedBrokerName: selectedBrokerName,
                title: title,
                checklist: checklist,
                brokerQuoteItems: brokerQuoteItems,
                selectedImportFileId: selectedImportFileId,
                customsCurrency: customsCurrency,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
