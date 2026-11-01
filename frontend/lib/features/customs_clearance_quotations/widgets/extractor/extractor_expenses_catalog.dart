import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ltr_text.dart';

/// Single fee item display column
class ExtractorFeeColumn extends StatelessWidget {
  const ExtractorFeeColumn(this.label, this.value, {super.key, this.isTotal = false});

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
        const SizedBox(height: 2),
        LtrText(
          value,
          style: TextStyle(
            fontSize: isTotal ? 12.5 : 11.5,
            fontWeight: FontWeight.bold,
            color: isTotal ? AppTheme.successForeground : AppTheme.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }
}

/// Expandable expenses catalog breakdown
class ExtractorExpensesCatalog extends StatelessWidget {
  const ExtractorExpensesCatalog({super.key, required this.items, required this.egp});

  final List items;
  final String egp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        dense: true,
        leading: const Icon(Icons.receipt_long, size: 18, color: AppTheme.cobalt),
        title: Text(
          l10n.clearanceQuotesExpensesCatalogCount(items.length),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
        ),
        children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.borderOf(context)),
              itemBuilder: (ctx, i) => _row(ctx, l10n, items[i] as Map<String, dynamic>),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(BuildContext context, String text, AppSeverity severity, String tooltip, {IconData? icon}) {
    final fg = AppTheme.severityForegroundOf(context, severity);
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsetsDirectional.symmetric(horizontal: 4),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: AppTheme.severityBackgroundOf(context, severity),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: fg, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 10, color: fg),
              const SizedBox(width: 1),
            ],
            Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, AppLocalizations l10n, Map<String, dynamic> itm) {
    final isMulti = itm['is_multi_value_split'] == true;
    final isRange = itm['price_type'] == 'range';
    final isOutside = itm['source_location'] == 'outside_table';

    Color itemBg = Colors.transparent;
    if (isMulti) {
      itemBg = AppTheme.severityBackgroundOf(context, AppSeverity.warning);
    } else if (isRange) {
      itemBg = AppTheme.severityBackgroundOf(context, AppSeverity.info);
    }

    final priceStr = isRange
        ? '${itm['price_min'] ?? 0} - ${itm['price_max'] ?? 0} $egp'
        : '${itm['price']} $egp';

    return Container(
      color: itemBg,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    itm['item_name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
                if (isMulti)
                  _tag(context, l10n.quotationValidationMultiValueBadge, AppSeverity.warning,
                      l10n.quotationValidationMultiValueTooltip),
                if (isRange)
                  _tag(context, l10n.quotationValidationRangeBadge, AppSeverity.info,
                      l10n.quotationValidationRangeTooltip(itm['price_min'] ?? '', itm['price_max'] ?? ''),
                      icon: Icons.bolt),
                if (isOutside)
                  _tag(context, l10n.quotationValidationOutsideTableBadge, AppSeverity.info,
                      l10n.quotationValidationOutsideTableTooltip),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              itm['category']?.toString() ?? '',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
            ),
          ),
          LtrText(
            priceStr,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isRange ? AppTheme.infoForeground : AppTheme.successForeground,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            itm['pricing_unit']?.toString() ?? '',
            style: TextStyle(fontSize: 11, color: AppTheme.textMutedOf(context)),
          ),
        ],
      ),
    );
  }
}
