import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';
import '../../../customs_clearance_quotations/models/customs_clearance_quotation_model.dart';

class BrokerQuoteKpis extends StatelessWidget {
  final int totalCount;
  final CustomsClearanceQuotationItemModel? lowestCostQuote;
  final CustomsClearanceQuotationItemModel? fastestQuote;
  final CustomsClearanceQuotationItemModel? awardedQuote;

  const BrokerQuoteKpis({
    super.key,
    required this.totalCount,
    this.lowestCostQuote,
    this.fastestQuote,
    this.awardedQuote,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SummaryPill(
          icon: Icons.format_list_numbered,
          label: l10n.clearanceQuotesTabRfqs,
          value: '$totalCount',
          color: AppTheme.charcoal,
        ),
        if (lowestCostQuote != null)
          SummaryPill(
            icon: Icons.savings_outlined,
            label: l10n.clearanceQuotesBadgeLowestCost,
            value:
                '${CcFormat.money(lowestCostQuote!.totalCost)} ${lowestCostQuote!.currency} (${lowestCostQuote!.providerName})',
            color: AppTheme.emerald,
            highlight: true,
          ),
        if (fastestQuote != null)
          SummaryPill(
            icon: Icons.bolt_outlined,
            label: l10n.clearanceQuotesBadgeFastestDuration,
            value:
                '${l10n.clearanceQuotesDaysCount(fastestQuote!.estimatedTurnaroundDays)} (${fastestQuote!.providerName})',
            color: AppTheme.cobalt,
          ),
        if (awardedQuote != null)
          SummaryPill(
            icon: Icons.verified_rounded,
            label: l10n.clearanceQuotesStatusAwarded,
            value: awardedQuote!.providerName,
            color: AppTheme.emerald,
            highlight: true,
          ),
      ],
    );
  }
}

class SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool highlight;

  const SummaryPill({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? color.withValues(alpha: 0.12)
            : AppTheme.charcoalSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: highlight ? color.withValues(alpha: 0.4) : AppTheme.cloudWhite,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppTheme.textMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
