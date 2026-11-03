import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';

class UpstreamVarianceAlertBanner extends ConsumerWidget {
  final ImportBudgetModel? budget;
  final BudgetPrefillModel? prefill;
  final double? formInvoiceEgp;
  final double? formFreightEgp;
  final double? formDutiesEgp;
  final double? formClearanceEgp;
  final VoidCallback? onFillLiveCosts;
  final void Function(dynamic)? onRecalculateSuccess;

  const UpstreamVarianceAlertBanner({
    super.key,
    this.budget,
    this.prefill,
    this.formInvoiceEgp,
    this.formFreightEgp,
    this.formDutiesEgp,
    this.formClearanceEgp,
    this.onFillLiveCosts,
    this.onRecalculateSuccess,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (prefill == null) return const SizedBox.shrink();

    final activePrefill = prefill!;
    final double actualFormInvoiceEgp = budget != null
        ? budget!.invoiceAmountEgp
        : (formInvoiceEgp ?? 0.0);
    final double actualFormFreightEgp = budget != null
        ? budget!.freightCostEgp
        : (formFreightEgp ?? 0.0);
    final double actualFormDutiesEgp = budget != null
        ? budget!.customsDutiesEgp
        : (formDutiesEgp ?? 0.0);
    final double actualFormClearanceEgp = budget != null
        ? budget!.clearanceInlandEgp
        : (formClearanceEgp ?? 0.0);

    final double liveInvoiceEgp = activePrefill.totalInvoiceAmountEgp;
    final double liveFreightEgp = activePrefill.estimatedFreightCostEgp;
    final double liveDutiesEgp = activePrefill.estimatedCustomsDutiesEgp;
    final double liveClearanceEgp = activePrefill.estimatedClearanceFeesEgp;

    final diffInvoice = liveInvoiceEgp - actualFormInvoiceEgp;
    final diffFreight = liveFreightEgp - actualFormFreightEgp;
    final diffDuties = liveDutiesEgp - actualFormDutiesEgp;
    final diffClearance = liveClearanceEgp - actualFormClearanceEgp;

    final bool hasVariance = diffInvoice.abs() > 1.0 ||
        diffFreight.abs() > 1.0 ||
        diffDuties.abs() > 1.0 ||
        diffClearance.abs() > 1.0;

    if (!hasVariance) return const SizedBox.shrink();

    final double totalDiff =
        diffInvoice + diffFreight + diffDuties + diffClearance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = context.l10n;

    return SelectionArea(
      child: Container(
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
                              : AppTheme.wcagOrange,
                        ),
                      ),
                    ],
                  ),
                ),
                if (budget != null)
                  // CRE-001: Saved budget — use centralized recalculation engine
                  RecalculateButton(
                    entityType: 'import_budget',
                    entityId: budget!.budgetId,
                    sourcePage: 'VarianceAlertBanner',
                    label: l.faSyncBudgetLiveNow,
                    onSuccess: (result) {
                      ref.invalidate(importBudgetsProvider);
                      onRecalculateSuccess?.call(result);
                    },
                  )
                else if (onFillLiveCosts != null)
                  // Draft budget (not yet saved) — prefill form fields from live data
                  AppButton(
                    label: l.faFillLiveCosts,
                    variant: AppButtonVariant.warning,
                    size: AppButtonSize.small,
                    icon: Icons.sync,
                    onPressed: onFillLiveCosts,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (diffClearance.abs() > 1.0)
                  _buildVarianceChip(
                    context: context,
                    label: l.faVarianceClearance,
                    formVal: actualFormClearanceEgp,
                    liveVal: liveClearanceEgp,
                    diff: diffClearance,
                    isDark: isDark,
                    extraInfo: activePrefill.brokerName != null
                        ? '(${activePrefill.brokerName})'
                        : null,
                  ),
                if (diffFreight.abs() > 1.0)
                  _buildVarianceChip(
                    context: context,
                    label: l.faVarianceFreight,
                    formVal: actualFormFreightEgp,
                    liveVal: liveFreightEgp,
                    diff: diffFreight,
                    isDark: isDark,
                  ),
                if (diffDuties.abs() > 1.0)
                  _buildVarianceChip(
                    context: context,
                    label: l.faVarianceDuties,
                    formVal: actualFormDutiesEgp,
                    liveVal: liveDutiesEgp,
                    diff: diffDuties,
                    isDark: isDark,
                  ),
                if (diffInvoice.abs() > 1.0)
                  _buildVarianceChip(
                    context: context,
                    label: l.faVarianceInvoice,
                    formVal: actualFormInvoiceEgp,
                    liveVal: liveInvoiceEgp,
                    diff: diffInvoice,
                    isDark: isDark,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.faVarianceTotal(
                  '${totalDiff > 0 ? '+' : ''}${totalDiff.toStringAsFixed(2)}',
                  (actualFormInvoiceEgp +
                          actualFormFreightEgp +
                          actualFormDutiesEgp +
                          actualFormClearanceEgp +
                          totalDiff)
                      .toStringAsFixed(2)),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: totalDiff > 0 ? AppTheme.crimson : AppTheme.wcagEmerald,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildVarianceChip({
    required BuildContext context,
    required String label,
    required double formVal,
    required double liveVal,
    required double diff,
    required bool isDark,
    String? extraInfo,
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
            '$label ${extraInfo ?? ""}',
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
                '${isPositive ? '+' : ''}${diff.toStringAsFixed(2)}'),
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
}
