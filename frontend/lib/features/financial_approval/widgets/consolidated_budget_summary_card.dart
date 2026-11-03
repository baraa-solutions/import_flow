import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../models/financial_approval_model.dart';
import 'budget_summary/budget_foreign_currency_table.dart';
import 'budget_summary/budget_local_clearance_table.dart';
import 'budget_summary/budget_variance_alert_banner.dart';

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
            BudgetVarianceAlertBanner(
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
                    const Icon(Icons.currency_exchange, color: AppTheme.cobalt, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.consolidatedBudgetSummary,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Group 1: Foreign Currency Table
                BudgetForeignCurrencyTable(
                  invForeign: invForeign,
                  invCurr: invCurr,
                  invEgpVal: invEgpVal,
                  frtForeign: frtForeign,
                  frtCurr: frtCurr,
                  frtEgpVal: frtEgpVal,
                ),
                const SizedBox(height: 14),

                // Group 2: Local EGP Table
                BudgetLocalClearanceTable(
                  custEgp: custEgp,
                  clrEgp: clrEgp,
                  activeBrokerName: activeBrokerName,
                  hasBroker: hasBroker,
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
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
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
}
