import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/financial_approval_model.dart';

/// Consolidated Budget Summary Card with Upstream Variance Alerts
///
/// Combines foreign currency breakdown, local EGP clearance expenses,
/// total approved budget calculations, and real-time variance detection.
class ConsolidatedBudgetSummaryCard extends StatelessWidget {
  final ImportBudgetModel? budget;
  final BudgetPrefillModel? prefill;
  final double? invoiceForeign;
  final String? invoiceCurrency;
  final double? invoiceEgp;
  final double? freightForeign;
  final String? freightCurrency;
  final double? freightEgp;
  final double? customsDutiesEgp;
  final double? clearanceInlandEgp;
  final String? brokerName;
  final bool showVarianceAlert;

  const ConsolidatedBudgetSummaryCard({
    super.key,
    this.budget,
    this.prefill,
    this.invoiceForeign,
    this.invoiceCurrency,
    this.invoiceEgp,
    this.freightForeign,
    this.freightCurrency,
    this.freightEgp,
    this.customsDutiesEgp,
    this.clearanceInlandEgp,
    this.brokerName,
    this.showVarianceAlert = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double invForeign;
    final String invCurr;
    final double invEgpVal;
    final double frtForeign;
    final String frtCurr;
    final double frtEgpVal;
    final double custEgp;
    final double clrEgp;
    final double grandTotalEgp;

    if (budget != null) {
      invForeign = budget!.invoiceAmountForeign;
      invCurr = budget!.invoiceCurrency;
      invEgpVal = budget!.invoiceAmountEgp;
      frtForeign = budget!.freightCostForeign;
      frtCurr = budget!.freightCurrency;
      frtEgpVal = budget!.freightCostEgp;
      custEgp = budget!.customsDutiesEgp;
      clrEgp = budget!.clearanceInlandEgp;
      grandTotalEgp = budget!.totalBudgetEgp;
    } else {
      invForeign = invoiceForeign ?? (prefill?.totalInvoiceAmount ?? 0);
      invCurr = invoiceCurrency ?? 'USD';
      invEgpVal = invoiceEgp ?? (prefill?.totalInvoiceAmountEgp ?? 0);
      frtForeign = freightForeign ?? (prefill?.estimatedFreightCost ?? 0);
      frtCurr = freightCurrency ?? 'USD';
      frtEgpVal = freightEgp ?? (prefill?.estimatedFreightCostEgp ?? 0);
      custEgp = customsDutiesEgp ?? (prefill?.estimatedCustomsDutiesEgp ?? 0);
      clrEgp = clearanceInlandEgp ?? (prefill?.estimatedClearanceFeesEgp ?? 0);
      grandTotalEgp = invEgpVal + frtEgpVal + custEgp + clrEgp;
    }

    final activeBrokerName = brokerName ?? prefill?.brokerName;
    final hasBroker = activeBrokerName != null && activeBrokerName.isNotEmpty;

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showVarianceAlert && prefill != null)
            _buildUpstreamVarianceAlertBanner(
              context: context,
              l: l,
              isDark: isDark,
              formInvoiceEgp: invEgpVal,
              formFreightEgp: frtEgpVal,
              formDutiesEgp: custEgp,
              formClearanceEgp: clrEgp,
              prefill: prefill!,
            ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.currency_exchange,
                        color: AppTheme.cobalt, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.consolidatedBudgetSummary,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.charcoal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Group 1: Foreign Currency Table
                Text(
                  '1. ${l.estimatedInvoiceValue} & ${l.estimatedFreightCost}:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppTheme.cobalt,
                  ),
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 550;
                    final table = Table(
                      border: TableBorder.all(
                        color:
                            isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
                      ),
                      columnWidths: isNarrow
                          ? const {
                              0: FixedColumnWidth(160),
                              1: FixedColumnWidth(120),
                              2: FixedColumnWidth(90),
                              3: FixedColumnWidth(120),
                            }
                          : const {
                              0: FlexColumnWidth(2.0),
                              1: FlexColumnWidth(1.5),
                              2: FlexColumnWidth(1.2),
                              3: FlexColumnWidth(1.5),
                            },
                      children: [
                        TableRow(
                          decoration:
                              const BoxDecoration(color: AppTheme.cobalt),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                l.categoryCol,
                                style: const TextStyle(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                l.amountInCurrencyCol,
                                style: const TextStyle(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                l.currencyCol,
                                style: const TextStyle(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                l.equivalentEgpCol,
                                style: const TextStyle(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                l.estimatedInvoiceValue,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : null,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(
                                invForeign.toStringAsFixed(2),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color:
                                      isDark ? AppTheme.darkTextPrimary : null,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(
                                invCurr,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color:
                                      isDark ? AppTheme.darkTextPrimary : null,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(
                                '${invEgpVal.toStringAsFixed(2)} EGP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.emerald,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                l.estimatedFreightCost,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : null,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(
                                frtForeign.toStringAsFixed(2),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color:
                                      isDark ? AppTheme.darkTextPrimary : null,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(
                                frtCurr,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color:
                                      isDark ? AppTheme.darkTextPrimary : null,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(
                                '${frtEgpVal.toStringAsFixed(2)} EGP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.emerald,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkElevatedSurface
                                : AppTheme.charcoalSurface,
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                l.totalExpenses,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color:
                                      isDark ? AppTheme.darkTextPrimary : null,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(
                                invCurr.toUpperCase() == frtCurr.toUpperCase()
                                    ? (invForeign + frtForeign)
                                        .toStringAsFixed(2)
                                    : '${invForeign.toStringAsFixed(2)} ($invCurr)\n+ ${frtForeign.toStringAsFixed(2)} ($frtCurr)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color:
                                      isDark ? AppTheme.darkTextPrimary : null,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(
                                invCurr.toUpperCase() == frtCurr.toUpperCase()
                                    ? invCurr
                                    : '-',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color:
                                      isDark ? AppTheme.darkTextPrimary : null,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(
                                '${(invEgpVal + frtEgpVal).toStringAsFixed(2)} EGP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.emerald,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );

                    return isNarrow
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 490),
                              child: table,
                            ),
                          )
                        : table;
                  },
                ),
                const SizedBox(height: 14),

                // Group 2: Local EGP Table
                Text(
                  '2. ${l.clearanceAndTransportEstimate}:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppTheme.orange,
                  ),
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 550;
                    final table = Table(
                      border: TableBorder.all(
                        color:
                            isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
                      ),
                      columnWidths: isNarrow
                          ? const {
                              0: FixedColumnWidth(180),
                              1: FixedColumnWidth(150),
                              2: FixedColumnWidth(140),
                            }
                          : const {
                              0: FlexColumnWidth(2.0),
                              1: FlexColumnWidth(1.8),
                              2: FlexColumnWidth(1.5),
                            },
                      children: [
                        TableRow(
                          decoration:
                              const BoxDecoration(color: AppTheme.orange),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                l.categoryCol,
                                style: const TextStyle(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                l.responsiblePartyLabel,
                                style: const TextStyle(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                l.equivalentEgpCol,
                                style: const TextStyle(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                l.customsAndVatEstimate,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : null,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(
                                l.customsAuthority,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : null,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(
                                '${custEgp.toStringAsFixed(2)} EGP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.wcagCobalt,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                l.clearanceAndTransportEstimate,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : null,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(
                                hasBroker
                                    ? '${l.customsBrokerLabel} $activeBrokerName'
                                    : l.customsBrokerLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: hasBroker
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isDark
                                      ? (hasBroker
                                          ? AppTheme.orange
                                          : AppTheme.darkTextSecondary)
                                      : (hasBroker
                                          ? AppTheme.charcoal
                                          : null),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(
                                '${clrEgp.toStringAsFixed(2)} EGP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.emerald,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkElevatedSurface
                                : AppTheme.charcoalSurface,
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                l.totalExpenses,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color:
                                      isDark ? AppTheme.darkTextPrimary : null,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                '-',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : null,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: CopyableText(
                                '${(custEgp + clrEgp).toStringAsFixed(2)} EGP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.emerald,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );

                    return isNarrow
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 470),
                              child: table,
                            ),
                          )
                        : table;
                  },
                ),
                const SizedBox(height: 14),

                // Total Approved Budget Bar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.emerald.withValues(alpha: 0.2)
                        : AppTheme.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.emerald.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${l.totalBudgetEgp}:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.charcoal,
                        ),
                      ),
                      CopyableText(
                        '${grandTotalEgp.toStringAsFixed(2)} EGP',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.emerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpstreamVarianceAlertBanner({
    required BuildContext context,
    required AppLocalizations l,
    required bool isDark,
    required double formInvoiceEgp,
    required double formFreightEgp,
    required double formDutiesEgp,
    required double formClearanceEgp,
    required BudgetPrefillModel prefill,
  }) {
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

  Widget _buildVarianceChip({
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
}
