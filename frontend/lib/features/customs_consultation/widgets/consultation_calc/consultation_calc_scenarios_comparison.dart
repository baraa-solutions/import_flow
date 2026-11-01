import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/customs_consultation_model.dart';
import '../recalculation_variance_comparison_card.dart';

/// Card for Trade Agreements, Exemptions Comparison, and Reconciliation Scenario Matrix.
class ConsultationCalcScenariosComparison extends StatelessWidget {
  final List<CustomsItemCalcRow> calcLines;
  final CustomsRecalculationResponseModel? recalculationResult;
  final TextEditingController? preliminaryRateController;
  final VoidCallback? onApplyNewFees;
  final VoidCallback? onCloseRecalculation;
  final VoidCallback? onFetchReconciledFinalInvoice;
  final bool isRecalculating;
  final bool isTaxReviewMode;
  final String customsCurrency;

  const ConsultationCalcScenariosComparison({
    super.key,
    required this.calcLines,
    this.recalculationResult,
    this.preliminaryRateController,
    this.onApplyNewFees,
    this.onCloseRecalculation,
    this.onFetchReconciledFinalInvoice,
    this.isRecalculating = false,
    required this.isTaxReviewMode,
    required this.customsCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final egpLabel = l.financialSettlementCurrencyEgp;

    final exemptionLines = calcLines
        .where((l) =>
            l.hasExemption ||
            l.priorApprovalNote != null ||
            (l.regulatoryAuthority != null && l.regulatoryAuthority!.isNotEmpty))
        .toList();

    final hasContent = exemptionLines.isNotEmpty ||
        recalculationResult != null ||
        isTaxReviewMode;

    if (!hasContent) {
      return const SizedBox.shrink();
    }

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
                  const Icon(Icons.policy_outlined, color: AppTheme.cobalt, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.poRegulatoryConditionsTradeAgreementsByHS,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          ),
                        ),
                        Text(
                          l.preferentialAgreementsSubheader,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (isTaxReviewMode && onFetchReconciledFinalInvoice != null) ...[
                    AppButton(
                      label: l.fetchReconciledFinalInvoice,
                      icon: Icons.flash_on,
                      variant: AppButtonVariant.success,
                      size: AppButtonSize.small,
                      isLoading: isRecalculating,
                      onPressed: isRecalculating ? null : onFetchReconciledFinalInvoice,
                    ),
                  ],
                ],
              ),
              const Divider(height: 20),

              // Recalculation Variance Scenario (if active)
              if (recalculationResult != null) ...[
                if (recalculationResult!.hasDifferentCurrencies &&
                    preliminaryRateController != null) ...[
                  SizedBox(
                    width: 320,
                    child: TextFormField(
                      controller: preliminaryRateController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            '${l.ccPreliminaryRateLabel} (${recalculationResult!.preliminaryCurrency} → EGP)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                RecalculationVarianceComparisonCard(
                  recalculationResult: recalculationResult!,
                  onApplyNewFees: onApplyNewFees ?? () {},
                  onClose: onCloseRecalculation ?? () {},
                ),
                const SizedBox(height: 16),
              ],

              // Trade Agreements & Preferential Tariff Exemption Matrix
              if (exemptionLines.isNotEmpty) ...[
                Text(
                  l.poRegulatoryConditionsTradeAgreementsByHS,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 8),
                ...exemptionLines.map((line) {
                  final double baseRate = line.baseDutyRate;
                  final double prefRate = line.dutyRate;
                  final double savingsRate = (baseRate - prefRate).clamp(0.0, 100.0);
                  final double dutySavingsEgp = (line.cifEgp * (savingsRate / 100.0));

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: line.hasExemption
                          ? (isDark
                              ? AppTheme.emerald.withValues(alpha: 0.12)
                              : AppTheme.emeraldLight.withValues(alpha: 0.6))
                          : (isDark
                              ? AppTheme.orange.withValues(alpha: 0.12)
                              : AppTheme.orangeLight.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: line.hasExemption
                            ? AppTheme.emeraldBorder
                            : AppTheme.orange,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              line.hasExemption
                                  ? Icons.verified
                                  : Icons.warning_amber_rounded,
                              color: line.hasExemption
                                  ? AppTheme.emerald
                                  : AppTheme.wcagOrange,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${l.ccHSCode}: ${line.hsCode}${line.countryOfOrigin != null ? " • ${line.countryOfOrigin}" : ""}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: line.hasExemption
                                      ? AppTheme.wcagEmerald
                                      : AppTheme.wcagOrange,
                                ),
                              ),
                            ),
                            if (line.hasExemption) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.emeraldBorder,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.wcagEmerald),
                                ),
                                child: Text(
                                  line.appliedAgreementName ?? l.ccExemption,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.wcagEmerald,
                                  ),
                                ),
                              ),
                              if (dutySavingsEgp > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cobaltLight,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppTheme.cobaltBorder),
                                  ),
                                  child: Text(
                                    '${l.customsDutyCol}: ${dutySavingsEgp.toStringAsFixed(2)} $egpLabel (-$savingsRate%)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.wcagCobalt,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                        if (line.exemptionConditionsNote != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            line.exemptionConditionsNote!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.charcoal,
                            ),
                          ),
                        ],
                        if (line.requiredDocument != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            line.requiredDocument!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.wcagCobalt,
                            ),
                          ),
                        ],
                        if (line.priorApprovalNote != null &&
                            line.priorApprovalNote!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            line.priorApprovalNote!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.charcoal,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
