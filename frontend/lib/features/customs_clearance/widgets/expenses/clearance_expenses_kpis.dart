import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../models/clearance_expense_invoice_model.dart';
import '../cc_dialog_shell.dart';
import '../customs_ui.dart';

class ClearanceExpensesKpis extends StatelessWidget {
  final ClearanceInvoicesSummaryModel? summary;

  const ClearanceExpensesKpis({super.key, required this.summary});

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: highlight ? color.withValues(alpha: 0.1) : AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: highlight ? color : AppTheme.borderOf(context),
          width: highlight ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LtrText(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: highlight ? color : AppTheme.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cur = l.ccCurrencyShort;
    final totalNet = summary?.netPayableEgp ?? 0.0;
    final brokerFees = summary?.totalClearanceFeesEgp ?? 0.0;
    final portDues = summary?.totalPortDuesEgp ?? 0.0;
    final handling = summary?.totalHandlingStevedoringEgp ?? 0.0;
    final count = summary?.invoicesCount ?? 0;

    return CcFieldRow(
      gap: 12,
      children: [
        _buildMetricCard(
          context,
          title: l.ccExpKpiNet,
          value: '${CcFormat.money(totalNet)} $cur',
          subtitle: l.ccExpInvoicesCount(count),
          icon: Icons.account_balance_wallet,
          color: AppTheme.emerald,
          highlight: true,
        ),
        _buildMetricCard(
          context,
          title: l.ccExpKpiBroker,
          value: '${CcFormat.money(brokerFees)} $cur',
          subtitle: l.ccExpKpiBrokerSub,
          icon: Icons.person_search,
          color: AppTheme.cobalt,
        ),
        _buildMetricCard(
          context,
          title: l.ccExpKpiPort,
          value: '${CcFormat.money(portDues)} $cur',
          subtitle: l.ccExpKpiPortSub,
          icon: Icons.anchor,
          color: AppTheme.orange,
        ),
        _buildMetricCard(
          context,
          title: l.ccExpKpiHandling,
          value: '${CcFormat.money(handling)} $cur',
          subtitle: l.ccExpKpiHandlingSub,
          icon: Icons.forklift,
          color: AppTheme.wcagCobalt,
        ),
      ],
    );
  }
}
