import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/ltr_text.dart';
import 'extractor_expenses_catalog.dart';

/// Extracted quotation result panel with rate option switcher and fee breakdown
class ExtractorResultPanel extends StatelessWidget {
  final Map<String, dynamic> result;
  final VoidCallback onSaveAsPriceList;
  final VoidCallback onApplyQuote;
  final void Function(String containerType, Map<String, dynamic> optMap) onSelectRateOption;

  const ExtractorResultPanel({
    super.key,
    required this.result,
    required this.onSaveAsPriceList,
    required this.onApplyQuote,
    required this.onSelectRateOption,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final egp = l10n.egpCurrency;
    final hasOptions = result['rate_options'] is List && (result['rate_options'] as List).isNotEmpty;
    final hasCatalog = result['expenses_catalog'] is List && (result['expenses_catalog'] as List).isNotEmpty;

    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: AppTheme.severityBackgroundOf(context, AppSeverity.success),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.emerald),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.clearanceQuotesExtractedBrokerPrefix} ${result['broker_name'] ?? l10n.clearanceQuotesColBroker}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    '${l10n.clearanceQuotesExtractedPortPrefix} ${result['port_name'] ?? '-'} | ${l10n.clearanceQuotesSelectedContainerLabel}: ${result['container_type'] ?? '-'}',
                  ),
                  LtrText(
                    '${l10n.clearanceQuotesExtractedTotalPrefix} ${result['total_estimated_clearance_cost']} $egp',
                    style: const TextStyle(
                      color: AppTheme.successForeground,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                    tooltip: l10n.copy,
                    onPressed: () {
                      final summary =
                          '${result['broker_name'] ?? l10n.clearanceQuotesColBroker} - ${result['port_name'] ?? '-'} - ${result['total_estimated_clearance_cost']} $egp';
                      CopyHelper.copy(context, summary);
                    },
                  ),
                  AppButton(
                    label: l10n.clearanceQuotesSaveAsPriceListBtn,
                    icon: Icons.price_change_outlined,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: onSaveAsPriceList,
                  ),
                  AppButton(
                    label: l10n.clearanceQuotesApplyExtractedQuoteBtn,
                    icon: Icons.check,
                    variant: AppButtonVariant.success,
                    size: AppButtonSize.small,
                    onPressed: onApplyQuote,
                  ),
                ],
              ),
            ],
          ),
          if (hasOptions) ...[
            Divider(height: 16, color: AppTheme.borderOf(context)),
            Text(l10n.clearanceQuotesRateOptionsTitle,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: (result['rate_options'] as List).map<Widget>((opt) {
                final optMap = opt as Map<String, dynamic>;
                final cType = optMap['container_type']?.toString() ?? 'Option';
                final optTotal = optMap['total_estimated_clearance_cost'] ?? 0;
                final isSelected = result['container_type'] == cType;
                return ChoiceChip(
                  avatar: Icon(
                    isSelected ? Icons.check_circle : Icons.inventory_2_outlined,
                    size: 14,
                    color: isSelected ? AppTheme.white : AppTheme.cobalt,
                  ),
                  label: Text(
                    '$cType : $optTotal $egp',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppTheme.white : AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.cobalt,
                  backgroundColor: AppTheme.surfaceOf(context),
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) {
                      onSelectRateOption(cType, optMap);
                    }
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsetsDirectional.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 16,
              runSpacing: 8,
              children: [
                ExtractorFeeColumn(l10n.clearanceQuotesBreakdownClearanceFee, '${result['clearance_fee'] ?? 0} $egp'),
                ExtractorFeeColumn(l10n.clearanceQuotesBreakdownInlandFee, '${result['inland_transport_fee'] ?? 0} $egp'),
                ExtractorFeeColumn(l10n.clearanceQuotesBreakdownInspectionFee, '${result['inspection_fee'] ?? 0} $egp'),
                ExtractorFeeColumn(l10n.clearanceQuotesBreakdownPortExpenses, '${result['port_expenses'] ?? 0} $egp'),
                ExtractorFeeColumn(l10n.clearanceQuotesBreakdownEstimatedTotal,
                    '${result['total_estimated_clearance_cost'] ?? 0} $egp',
                    isTotal: true),
              ],
            ),
          ),
          if (hasCatalog) ...[
            const SizedBox(height: 8),
            ExtractorExpensesCatalog(items: result['expenses_catalog'] as List, egp: egp),
          ],
        ],
      ),
    );
  }
}
