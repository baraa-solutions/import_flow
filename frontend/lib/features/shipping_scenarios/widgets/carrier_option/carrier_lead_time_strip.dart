import 'package:flutter/material.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../currencies/models/currency_model.dart';
import '../../models/shipping_scenario_model.dart';
import '../../utils/shipping_scenario_calculator.dart';

class CarrierLeadTimeStrip extends StatelessWidget {
  final ShippingScenarioItemModel item;
  final Map<String, dynamic> calculation;
  final List<CurrencyModel> currenciesList;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const CarrierLeadTimeStrip({
    super.key,
    required this.item,
    required this.calculation,
    required this.currenciesList,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    if (calculation.isEmpty) return const SizedBox.shrink();

    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = (Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar') == 'ar';
    final hasRealDates = item.sailingDate.isNotEmpty && item.estimatedArrivalDate.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cobaltMedium : AppTheme.cobaltLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              hasRealDates
                  ? l.polToPodLeadTimeStrip(
                      item.polName ?? '-',
                      item.podName ?? '-',
                      calculation["vesselLeadTime"] as int,
                      calculation["totalDays"] as int,
                    )
                  : (isArabic
                      ? 'يرجى تحديد تواريخ الإبحار والوصول لاحتساب مدد الشحن'
                      : 'Select sailing & arrival dates to calculate transit lead times'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
            const SizedBox(width: 16),
            Row(
              children: [
                AppButton(
                  label: isExpanded
                      ? l.hideQuote
                      : (item.totalQuotationAmount != null
                          ? '${l.quoteDetails} [${item.totalQuotationAmount!.toStringAsFixed(0)} ${item.quotationCurrency ?? "—"}]'
                          : '${l.quoteDetails} [—]'),
                  icon: isExpanded ? Icons.expand_less : Icons.expand_more,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: onToggleExpanded,
                ),
                if (item.totalQuotationAmount == null) ...[
                  const SizedBox(width: 6),
                  Builder(
                    builder: (context) {
                      final missing = ShippingScenarioCalculator.calculateTotalQuoteValue(
                        item: item,
                        currencies: currenciesList,
                      ).missingCurrencies;
                      final missingStr = missing.isNotEmpty ? missing.join(', ') : (item.quotationCurrency ?? '—');
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.wcagOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.wcagOrange, width: 0.8),
                        ),
                        child: Text(
                          l.rateMissingWarning(missingStr),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.wcagOrange),
                        ),
                      );
                    },
                  ),
                ],
                if (hasRealDates) ...[
                  const SizedBox(width: 10),
                  Text(
                    '${l.avgWarehouseArrivalMetric}: ${calculation["expectedWhDate"]}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
