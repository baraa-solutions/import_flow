import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/financial_approval_model.dart';

class BudgetVarianceAlertBanner extends StatelessWidget {
  final double formInvoiceEgp;
  final double formFreightEgp;
  final double formDutiesEgp;
  final double formClearanceEgp;
  final BudgetPrefillModel prefill;

  const BudgetVarianceAlertBanner({
    super.key,
    required this.formInvoiceEgp,
    required this.formFreightEgp,
    required this.formDutiesEgp,
    required this.formClearanceEgp,
    required this.prefill,
  });

  static Widget _buildVarianceChip({
    required BuildContext context,
    required String label,
    required double formVal,
    required double liveVal,
    required double diff,
    required bool isDark,
  }) {
    final isPositive = diff > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPositive ? AppTheme.orange : AppTheme.cobaltBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.l10n.faVarianceChipLine(
              formVal.toStringAsFixed(2),
              liveVal.toStringAsFixed(2),
              '${isPositive ? '+' : ''}${diff.toStringAsFixed(2)}',
            ),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isPositive ? AppTheme.orange : AppTheme.cobalt,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double liveInvoiceEgp = prefill.totalInvoiceAmountEgp;
    final double liveFreightEgp = prefill.estimatedFreightCostEgp;
    final double liveDutiesEgp = prefill.estimatedCustomsDutiesEgp;
    final double liveClearanceEgp = prefill.estimatedClearanceFeesEgp;

    final diffInvoice = liveInvoiceEgp - formInvoiceEgp;
    final diffFreight = liveFreightEgp - formFreightEgp;
    final diffDuties = liveDutiesEgp - formDutiesEgp;
    final diffClearance = liveClearanceEgp - formClearanceEgp;

    final bool hasVariance = diffInvoice.abs() > 1.0 ||
        diffFreight.abs() > 1.0 ||
        diffDuties.abs() > 1.0 ||
        diffClearance.abs() > 1.0;

    if (!hasVariance) return const SizedBox.shrink();

    final double totalDiff =
        diffInvoice + diffFreight + diffDuties + diffClearance;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.orangeLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.wcagOrange, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppTheme.wcagOrange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: AppTheme.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.faUpstreamVarianceTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? AppTheme.orange : AppTheme.wcagOrange,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.faUpstreamVarianceBody,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: totalDiff > 0 ? AppTheme.orange : AppTheme.cobalt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${totalDiff > 0 ? "+" : ""}${totalDiff.toStringAsFixed(2)} EGP',
                  style: const TextStyle(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (diffInvoice.abs() > 1.0)
                _buildVarianceChip(
                  context: context,
                  label: l.estimatedInvoiceValue,
                  formVal: formInvoiceEgp,
                  liveVal: liveInvoiceEgp,
                  diff: diffInvoice,
                  isDark: isDark,
                ),
              if (diffFreight.abs() > 1.0)
                _buildVarianceChip(
                  context: context,
                  label: l.estimatedFreightCost,
                  formVal: formFreightEgp,
                  liveVal: liveFreightEgp,
                  diff: diffFreight,
                  isDark: isDark,
                ),
              if (diffDuties.abs() > 1.0)
                _buildVarianceChip(
                  context: context,
                  label: l.customsAndVatEstimate,
                  formVal: formDutiesEgp,
                  liveVal: liveDutiesEgp,
                  diff: diffDuties,
                  isDark: isDark,
                ),
              if (diffClearance.abs() > 1.0)
                _buildVarianceChip(
                  context: context,
                  label: l.clearanceAndTransportEstimate,
                  formVal: formClearanceEgp,
                  liveVal: liveClearanceEgp,
                  diff: diffClearance,
                  isDark: isDark,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
