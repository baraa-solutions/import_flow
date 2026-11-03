import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/financial_approval_model.dart';

class SavedBudgetCardMetrics extends StatelessWidget {
  final ImportBudgetModel budget;
  final bool isDark;

  const SavedBudgetCardMetrics({
    super.key,
    required this.budget,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _buildMetricsGrid(context),
          const SizedBox(height: 12),
          _buildGrandTotalBar(context),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 850;
        final box1 = _buildCostBox(
          title: context.l10n.estimatedInvoiceValue,
          foreignVal: '${budget.invoiceAmountForeign.toStringAsFixed(2)} ${budget.invoiceCurrency}',
          egpVal: '${budget.invoiceAmountEgp.toStringAsFixed(2)} EGP',
          icon: Icons.inventory_2_outlined,
          color: AppTheme.cobalt,
        );
        final box2 = _buildCostBox(
          title: context.l10n.estimatedFreightCost,
          foreignVal: '${budget.freightCostForeign.toStringAsFixed(2)} ${budget.freightCurrency}',
          egpVal: '${budget.freightCostEgp.toStringAsFixed(2)} EGP',
          icon: Icons.directions_boat_outlined,
          color: AppTheme.wcagCobalt,
        );
        final box3 = _buildCostBox(
          title: context.l10n.customsAndVatEstimate,
          foreignVal: 'Customs',
          egpVal: '${budget.customsDutiesEgp.toStringAsFixed(2)} EGP',
          icon: Icons.account_balance_outlined,
          color: AppTheme.wcagCobalt,
        );
        final box4 = _buildCostBox(
          title: context.l10n.clearanceAndTransportEstimate,
          foreignVal: context.l10n.customsBrokerLabel,
          egpVal: '${budget.clearanceInlandEgp.toStringAsFixed(2)} EGP',
          icon: Icons.local_shipping_outlined,
          color: AppTheme.wcagEmerald,
        );

        if (isNarrow) {
          return Column(
            children: [
              Row(children: [box1, const SizedBox(width: 8), box2]),
              const SizedBox(height: 8),
              Row(children: [box3, const SizedBox(width: 8), box4]),
            ],
          );
        }

        return Row(
          children: [
            box1,
            const SizedBox(width: 10),
            box2,
            const SizedBox(width: 10),
            box3,
            const SizedBox(width: 10),
            box4,
          ],
        );
      },
    );
  }

  Widget _buildCostBox({
    required String title,
    required String foreignVal,
    required String egpVal,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            CopyableText(
              foreignVal,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              showIcon: false,
            ),
            const SizedBox(height: 2),
            CopyableText(
              egpVal,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
              showIcon: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrandTotalBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.emerald.withValues(alpha: 0.15)
            : AppTheme.emerald.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? AppTheme.emerald.withValues(alpha: 0.6)
              : AppTheme.emerald.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalPart = Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.monetization_on, color: AppTheme.emerald, size: 20),
              Text(
                '${context.l10n.totalBudgetEgp}:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              CopyableText(
                '${budget.totalBudgetEgp.toStringAsFixed(2)} EGP',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.emerald),
                showIcon: false,
              ),
            ],
          );

          final metaPart = Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${context.l10n.exchangeRateCol}: ',
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong),
                  ),
                  CopyableText(
                    '${budget.exchangeRate.toStringAsFixed(2)} EGP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                    showIcon: false,
                  ),
                ],
              ),
              if (budget.approvedBy != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${context.l10n.approvedByLabel} ',
                      style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong),
                    ),
                    CopyableText(
                      budget.approvedBy!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                      showIcon: false,
                    ),
                  ],
                ),
            ],
          );

          return SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                totalPart,
                metaPart,
              ],
            ),
          );
        },
      ),
    );
  }
}
