import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/customs_consultation_model.dart';
import '../../currencies/models/currency_model.dart';
import 'broker_cost_row.dart';
import '../../../core/widgets/buttons/app_button.dart';

class BrokerQuoteDetailsCard extends ConsumerWidget {
  final int? selectedBrokerId;
  final bool isLoadingPriceList;
  final List<CustomsBrokerQuoteItemModel> brokerQuoteItems;
  final String? brokerPriceListTitle;
  final String categoryFilter;
  final bool isExpanded;
  final List<CurrencyModel> currenciesList;
  final double? referenceUsdExchangeRate;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onAddCustomExpense;
  final VoidCallback? onReloadPriceList;
  final VoidCallback onApplyAll;
  final VoidCallback onDisableAll;
  final Function(int, CustomsBrokerQuoteItemModel) onUpdateItem;

  const BrokerQuoteDetailsCard({
    super.key,
    required this.selectedBrokerId,
    required this.isLoadingPriceList,
    required this.brokerQuoteItems,
    required this.brokerPriceListTitle,
    required this.categoryFilter,
    required this.isExpanded,
    required this.currenciesList,
    this.referenceUsdExchangeRate,
    required this.onToggleExpanded,
    required this.onCategoryChanged,
    required this.onAddCustomExpense,
    this.onReloadPriceList,
    required this.onApplyAll,
    required this.onDisableAll,
    required this.onUpdateItem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (selectedBrokerId == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppTheme.wcagCobalt, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.selectBrokerFirstMsg,
                  style: const TextStyle(fontSize: 13, color: AppTheme.charcoal),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isLoadingPriceList) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: const Padding(
          padding: EdgeInsets.all(30),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(strokeWidth: 2.5),
                SizedBox(width: 14),
                Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }

    final appliedCount = brokerQuoteItems.where((i) => i.isApplicable).length;

    // Currency totals (M2-2 Multi-Currency)
    final egpTotal = brokerQuoteItems
        .where((i) => i.isApplicable && i.currency.toUpperCase() == 'EGP')
        .fold(0.0, (sum, itm) => sum + itm.totalAmount);

    final usdTotal = brokerQuoteItems
        .where((i) => i.isApplicable && i.currency.toUpperCase() == 'USD')
        .fold(0.0, (sum, itm) => sum + itm.totalAmount);

    final otherCurrenciesTotal = brokerQuoteItems
        .where((i) => i.isApplicable && i.currency.toUpperCase() != 'EGP' && i.currency.toUpperCase() != 'USD')
        .fold(0.0, (sum, itm) => sum + itm.totalAmount);

    final hasUsdRate = referenceUsdExchangeRate != null && referenceUsdExchangeRate! > 0;
    final convertedGrandTotalEgp = egpTotal + (hasUsdRate ? usdTotal * referenceUsdExchangeRate! : 0.0);

    final baseCategories = [
      'All',
      'Clearance Fees',
      'Procedures & Approvals',
      'Inland Transport',
      'Port & Handling',
      'Other Fees',
    ];
    final itemCats = brokerQuoteItems.map((i) => i.category.trim()).where((c) => c.isNotEmpty).toSet();
    final categories = [
      ...baseCategories,
      ...itemCats.where((c) => !baseCategories.contains(c) && !baseCategories.any((b) => b != 'All' && c.contains(b))),
    ];

    String getCategoryLabel(String cat) {
      if (cat == 'All') return l.allCategoriesItem;
      if (!isAr) return cat;
      switch (cat) {
        case 'Clearance Fees':
          return 'أتعاب التخليص';
        case 'Procedures & Approvals':
          return 'إجراءات وموافقات';
        case 'Inland Transport':
          return 'نقل داخلي';
        case 'Port & Handling':
          return 'مصاريف ومناولة الميناء';
        case 'Port Handling & Storage':
          return 'مناولة وتخزين بالميناء';
        case 'Other Fees':
          return 'رسوم ومصاريف أخرى';
        default:
          return cat;
      }
    }

    final filteredItems = categoryFilter == 'All'
        ? brokerQuoteItems
        : brokerQuoteItems.where((i) {
            if (categoryFilter == 'Port & Handling') {
              return i.category.contains('Port');
            }
            return i.category.trim() == categoryFilter || i.category.contains(categoryFilter);
          }).toList();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.request_quote, color: AppTheme.cobalt, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.clearanceQuotesTab,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                      ),
                      if (brokerPriceListTitle != null)
                        Text(
                          brokerPriceListTitle!,
                          style: const TextStyle(fontSize: 11, color: AppTheme.charcoal),
                        ),
                    ],
                  ),
                ),
                if (onReloadPriceList != null) ...[
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.cobalt, size: 20),
                    tooltip: l.liveRefresh,
                    onPressed: onReloadPriceList,
                  ),
                  const SizedBox(width: 4),
                ],
                IconButton(
                  icon: const Icon(Icons.copy_all, color: AppTheme.cobalt, size: 20),
                  tooltip: context.l10n.ccCopyQuoteItems,
                  onPressed: () {
                    final buffer = StringBuffer();
                    buffer.writeln('Item\tCategory\tUnit\tPrice\tCurrency\tQty\tApplicable\tTotal');
                    for (final itm in brokerQuoteItems) {
                      buffer.writeln('${itm.expenseName}\t${itm.category}\t${itm.unitType}\t${itm.unitPrice}\t${itm.currency}\t${itm.qty}\t${itm.isApplicable}\t${itm.totalAmount}');
                    }
                    CopyHelper.copy(
                      context,
                      buffer.toString(),
                      customMessage: context.l10n.ccCopiedAllQuoteItemsToClipboard,
                    );
                  },
                ),
                const SizedBox(width: 4),
                AppButton(
                  label: l.addCustomExpenseRow,
                  icon: Icons.add,
                  variant: AppButtonVariant.secondary,
                  onPressed: onAddCustomExpense,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: AppTheme.charcoal),
                  tooltip: l.clearanceQuotesTab,
                  onPressed: onToggleExpanded,
                ),
              ],
            ),
            if (isExpanded) ...[
              const Divider(height: 20),

              // Category Filter Bar & Bulk Actions
              Row(
                children: [
                  Text('${l.filterCategoryLabel}: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories.map((cat) {
                          final isSelected = categoryFilter == cat;
                          final label = getCategoryLabel(cat);
                          return Padding(
                            padding: const EdgeInsetsDirectional.only(start: 6),
                            child: ChoiceChip(
                              label: Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              selected: isSelected,
                              selectedColor: AppTheme.cobalt.withValues(alpha: 0.15),
                              onSelected: (_) => onCategoryChanged(cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  AppButton(
                    label: l.applyAllQuoteItems,
                    icon: Icons.check_box_outlined,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: onApplyAll,
                  ),
                  AppButton(
                    label: l.disableAllQuoteItems,
                    icon: Icons.disabled_by_default_outlined,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: onDisableAll,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Items List
              if (filteredItems.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppTheme.charcoalSurface, borderRadius: BorderRadius.circular(6)),
                  child: Text(l.noResultsFound),
                )
              else
                ...filteredItems.map((item) {
                  final idx = brokerQuoteItems.indexOf(item);
                  return buildBrokerCostRow(
                    context: context,
                    onUpdate: onUpdateItem,
                    index: idx,
                    item: item,
                    currenciesList: currenciesList,
                    ref: ref,
                    referenceUsdExchangeRate: referenceUsdExchangeRate,
                  );
                }),

              const Divider(height: 24),

              // Summary Bar (M2-2 Multi-Currency Breakdown)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet, color: AppTheme.cobalt, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${l.totalExpenses} ($appliedCount):',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.end,
                      children: [
                        if (egpTotal > 0 || (usdTotal == 0 && otherCurrenciesTotal == 0)) ...[
                          Text(
                            '${egpTotal.toStringAsFixed(2)} EGP',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.cobalt),
                          ),
                        ],
                        if (usdTotal > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.orangeLight,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.wcagOrange.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '${usdTotal.toStringAsFixed(2)} USD',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.wcagOrange),
                            ),
                          ),
                        ],
                        if (usdTotal > 0 && hasUsdRate) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '≈ ${convertedGrandTotalEgp.toStringAsFixed(0)} ج.م',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.emerald),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

