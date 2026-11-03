import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../utils/customs_expense_group_helper.dart';
import 'price_list_custom_item_dialog.dart';
import 'price_list_item_row.dart';
import 'price_list_match_helper.dart';

/// Items table section with toolbar, search, quick filter chips, grouped categories, and editable item rows.
class PriceListItemsTableSection extends StatelessWidget {
  final WidgetRef ref;
  final List<Map<String, dynamic>> itemsState;
  final Set<CustomsExpenseGroup> expandedGroups;
  final String itemSearchQuery;
  final String selectedCategoryFilter;
  final String quickFilterChip;
  final double? usdRefRate;
  final double dialogWidth;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryFilterChanged;
  final ValueChanged<String> onQuickFilterChanged;
  final ValueChanged<CustomsExpenseGroup> onToggleGroup;
  final VoidCallback onExpandAll;
  final VoidCallback onCollapseAll;
  final VoidCallback onFillStandardRates;
  final VoidCallback onZeroOutRates;
  final void Function(int realIndex) onCloneRow;
  final void Function(int realIndex) onDeleteCustomItem;
  final void Function(Map<String, dynamic> itemData) onAddCustomItemSaved;
  final void Function(void Function()) onStateChanged;

  const PriceListItemsTableSection({
    super.key,
    required this.ref,
    required this.itemsState,
    required this.expandedGroups,
    required this.itemSearchQuery,
    required this.selectedCategoryFilter,
    required this.quickFilterChip,
    required this.usdRefRate,
    required this.dialogWidth,
    required this.onSearchChanged,
    required this.onCategoryFilterChanged,
    required this.onQuickFilterChanged,
    required this.onToggleGroup,
    required this.onExpandAll,
    required this.onCollapseAll,
    required this.onFillStandardRates,
    required this.onZeroOutRates,
    required this.onCloneRow,
    required this.onDeleteCustomItem,
    required this.onAddCustomItemSaved,
    required this.onStateChanged,
  });

  Widget _buildQuickFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required Color activeColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : AppTheme.charcoalSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.cloudWhite,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? activeColor : AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : AppTheme.charcoal,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : AppTheme.cloudWhite,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.white : AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final q = itemSearchQuery.trim().toLowerCase();
    final filteredItems = itemsState.where((itm) {
      final name = (itm['expense_name']?.toString() ?? '').toLowerCase();
      final code = (itm['code']?.toString() ?? '').toLowerCase();
      final notes = (itm['notes']?.toString() ?? '').toLowerCase();
      final cat = (itm['category']?.toString() ?? '').toLowerCase();

      final matchSearch = q.isEmpty ||
          name.contains(q) ||
          code.contains(q) ||
          notes.contains(q) ||
          cat.contains(q);

      final matchCat = selectedCategoryFilter == 'All' ||
          cat == selectedCategoryFilter.toLowerCase() ||
          cat.contains(selectedCategoryFilter.toLowerCase()) ||
          selectedCategoryFilter.toLowerCase().contains(cat);

      final stdPrice = (itm['standard_price'] as num?)?.toDouble() ?? 0.0;
      final minP = (itm['min_price'] as num?)?.toDouble();
      final maxP = (itm['max_price'] as num?)?.toDouble();
      final pType = itm['price_type']?.toString() ?? '';
      final isNegotiable = pType == 'negotiable' || (stdPrice == 0.0 && minP == null && maxP == null);
      final isPriced = (stdPrice > 0) || (minP != null && minP > 0) || (maxP != null && maxP > 0);
      final isForeign = (itm['currency']?.toString() ?? 'EGP').toUpperCase() != 'EGP';
      final isUncoded = itm['is_uncoded'] == true || (itm['code'] == null || itm['code'].toString().trim().isEmpty);

      bool matchChip = true;
      switch (quickFilterChip) {
        case 'priced':
          matchChip = isPriced && !isNegotiable;
          break;
        case 'negotiable':
          matchChip = isNegotiable;
          break;
        case 'foreign':
          matchChip = isForeign;
          break;
        case 'uncoded':
          matchChip = isUncoded;
          break;
        case 'all':
        default:
          matchChip = true;
          break;
      }

      return matchSearch && matchCat && matchChip;
    }).toList();

    final countPriced = itemsState.where((itm) {
      final stdP = (itm['standard_price'] as num?)?.toDouble() ?? 0.0;
      final minP = (itm['min_price'] as num?)?.toDouble();
      final maxP = (itm['max_price'] as num?)?.toDouble();
      final pType = itm['price_type']?.toString() ?? '';
      return (stdP > 0 || (minP != null && minP > 0) || (maxP != null && maxP > 0)) && pType != 'negotiable';
    }).length;

    final countNegotiable = itemsState.where((itm) {
      final stdP = (itm['standard_price'] as num?)?.toDouble() ?? 0.0;
      final minP = (itm['min_price'] as num?)?.toDouble();
      final maxP = (itm['max_price'] as num?)?.toDouble();
      final pType = itm['price_type']?.toString() ?? '';
      return pType == 'negotiable' || (stdP == 0.0 && minP == null && maxP == null);
    }).length;

    final countForeign = itemsState.where((itm) {
      return (itm['currency']?.toString() ?? 'EGP').toUpperCase() != 'EGP';
    }).length;

    final countUncoded = itemsState.where((itm) {
      final c = itm['code']?.toString() ?? '';
      return itm['is_uncoded'] == true || c.trim().isEmpty;
    }).length;

    // Group filteredItems into categories
    final groupedMap = <CustomsExpenseGroup, List<Map<String, dynamic>>>{};
    for (final grp in CustomsExpenseGroup.values) {
      groupedMap[grp] = [];
    }
    for (final itm in filteredItems) {
      final grp = CustomsExpenseGroup.classify(
        name: itm['expense_name']?.toString() ?? '',
        category: itm['category']?.toString(),
        currency: itm['currency']?.toString(),
        code: itm['code']?.toString(),
      );
      groupedMap[grp]!.add(itm);
    }
    final activeGroups = CustomsExpenseGroup.values.where((g) => groupedMap[g]!.isNotEmpty).toList();

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Toolbar: Search, Category Filter & Quick Actions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: dialogWidth - 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 200,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: isAr ? 'بحث بالاسم، الكود، الملاحظات...' : 'Search name, code, notes...',
                                prefixIcon: const Icon(Icons.search, size: 16),
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              onChanged: onSearchChanged,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 200,
                            child: SearchableDropdownField<String>(
                              value: selectedCategoryFilter,
                              labelText: l.filterCategoryLabel,
                              items: [
                                SearchableDropdownItem(value: 'All', label: l.allCategoriesItem),
                                SearchableDropdownItem(value: 'Clearance Fees', label: getCategoryLabel('Clearance Fees', context)),
                                SearchableDropdownItem(value: 'Procedures & Approvals', label: getCategoryLabel('Procedures & Approvals', context)),
                                SearchableDropdownItem(value: 'Inland Transport', label: getCategoryLabel('Inland Transport', context)),
                                SearchableDropdownItem(value: 'Port & Handling', label: getCategoryLabel('Port & Handling', context)),
                                SearchableDropdownItem(value: 'Other Fees', label: getCategoryLabel('Other Fees', context)),
                              ],
                              onChanged: (v) => onCategoryFilterChanged(v ?? 'All'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppButton(
                            label: isAr ? 'توسيع الكل' : 'Expand All',
                            icon: Icons.unfold_more_rounded,
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.small,
                            onPressed: onExpandAll,
                          ),
                          const SizedBox(width: 6),
                          AppButton(
                            label: isAr ? 'طي الكل' : 'Collapse All',
                            icon: Icons.unfold_less_rounded,
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.small,
                            onPressed: onCollapseAll,
                          ),
                          const SizedBox(width: 6),
                          AppButton(
                            label: l.addCustomItemOrAliasBtn,
                            icon: Icons.qr_code_2,
                            variant: AppButtonVariant.primary,
                            size: AppButtonSize.small,
                            onPressed: () {
                              PriceListCustomItemDialog.show(
                                context: context,
                                ref: ref,
                                onItemSaved: onAddCustomItemSaved,
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          AppButton(
                            label: l.fillStandardRatesBtn,
                            icon: Icons.flash_on,
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.small,
                            onPressed: onFillStandardRates,
                          ),
                          const SizedBox(width: 6),
                          AppButton(
                            label: l.zeroOutRatesBtn,
                            icon: Icons.clear_all,
                            variant: AppButtonVariant.danger,
                            size: AppButtonSize.small,
                            onPressed: onZeroOutRates,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Advanced Filter Chips & Match Count Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildQuickFilterChip(
                            label: isAr ? 'الكل' : 'All',
                            count: itemsState.length,
                            isSelected: quickFilterChip == 'all',
                            activeColor: AppTheme.cobalt,
                            icon: Icons.list_alt_rounded,
                            onTap: () => onQuickFilterChanged('all'),
                          ),
                          const SizedBox(width: 6),
                          _buildQuickFilterChip(
                            label: isAr ? 'مسعر فقط' : 'Priced Only',
                            count: countPriced,
                            isSelected: quickFilterChip == 'priced',
                            activeColor: AppTheme.emerald,
                            icon: Icons.monetization_on_outlined,
                            onTap: () => onQuickFilterChanged('priced'),
                          ),
                          const SizedBox(width: 6),
                          _buildQuickFilterChip(
                            label: isAr ? 'تفاوضي فقط' : 'Negotiable Only',
                            count: countNegotiable,
                            isSelected: quickFilterChip == 'negotiable',
                            activeColor: AppTheme.wcagOrange,
                            icon: Icons.handshake_outlined,
                            onTap: () => onQuickFilterChanged('negotiable'),
                          ),
                          const SizedBox(width: 6),
                          _buildQuickFilterChip(
                            label: isAr ? 'عملات أجنبية' : 'Foreign Currency',
                            count: countForeign,
                            isSelected: quickFilterChip == 'foreign',
                            activeColor: AppTheme.cobalt,
                            icon: Icons.currency_exchange_rounded,
                            onTap: () => onQuickFilterChanged('foreign'),
                          ),
                          const SizedBox(width: 6),
                          _buildQuickFilterChip(
                            label: isAr ? 'بحاجة لتكويد' : 'Uncoded Only',
                            count: countUncoded,
                            isSelected: quickFilterChip == 'uncoded',
                            activeColor: AppTheme.crimson,
                            icon: Icons.warning_amber_rounded,
                            onTap: () => onQuickFilterChanged('uncoded'),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_list_rounded, size: 13, color: AppTheme.cobalt),
                            const SizedBox(width: 4),
                            Text(
                              isAr
                                  ? '${filteredItems.length} بند مطابق من إجمالي ${itemsState.length}'
                                  : '${filteredItems.length} matching of ${itemsState.length}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Grouped Items Table
          Expanded(
            child: activeGroups.isEmpty
                ? Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      isAr ? 'لم يتم العثور على بنود مطابقة للبحث أو الفلتر' : 'No items match filter',
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: activeGroups.length,
                    itemBuilder: (ctx, gIdx) {
                      final grp = activeGroups[gIdx];
                      final grpItems = groupedMap[grp]!;
                      final isGrpExpanded = itemSearchQuery.isNotEmpty || expandedGroups.contains(grp);

                      final pricedCount = grpItems.where((i) {
                        final pType = i['price_type']?.toString() ?? '';
                        final stdP = (i['standard_price'] as num?)?.toDouble() ?? 0.0;
                        final minP = (i['min_price'] as num?)?.toDouble();
                        return pType == 'negotiable' || stdP > 0 || (minP != null && minP > 0);
                      }).length;

                      final egpSubtotal = grpItems
                          .where((i) => (i['currency']?.toString() ?? 'EGP') == 'EGP')
                          .fold(0.0, (sum, i) => sum + ((i['standard_price'] as num?)?.toDouble() ?? 0.0));
                      final usdSubtotal = grpItems
                          .where((i) => (i['currency']?.toString() ?? 'EGP') == 'USD')
                          .fold(0.0, (sum, i) => sum + ((i['standard_price'] as num?)?.toDouble() ?? 0.0));

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: grp.badgeColor.withValues(alpha: 0.35)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            InkWell(
                              onTap: () => onToggleGroup(grp),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: grp.badgeColor.withValues(alpha: 0.08),
                                  borderRadius: isGrpExpanded
                                      ? const BorderRadius.vertical(top: Radius.circular(7))
                                      : BorderRadius.circular(7),
                                ),
                                child: Row(
                                  children: [
                                    Icon(grp.icon, size: 18, color: grp.badgeColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              grp.localizedTitle(isAr),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: grp.badgeColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: grp.badgeColor.withValues(alpha: 0.4)),
                                            ),
                                            child: Text(
                                              isAr
                                                  ? '${grpItems.length} بند • $pricedCount مسعر'
                                                  : '${grpItems.length} items • $pricedCount priced',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: grp.badgeColor),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (egpSubtotal > 0) ...[
                                      Text(
                                        '${egpSubtotal.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    if (usdSubtotal > 0) ...[
                                      Text(
                                        '\$${usdSubtotal.toStringAsFixed(0)} USD',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.wcagOrange),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Icon(
                                      isGrpExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                      color: grp.badgeColor,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isGrpExpanded) ...[
                              const Divider(height: 1, color: AppTheme.cloudWhite),
                              ...grpItems.asMap().entries.map((entry) {
                                final itemIdxInGrp = entry.key;
                                final itm = entry.value;
                                final realIdx = itemsState.indexOf(itm);
                                final isCustomItem = itm['expense_type_id'] == null;

                                return PriceListItemRow(
                                  ref: ref,
                                  item: itm,
                                  indexInGroup: itemIdxInGrp,
                                  realIndex: realIdx,
                                  usdRefRate: usdRefRate,
                                  onClone: () => onCloneRow(realIdx),
                                  onDelete: isCustomItem ? () => onDeleteCustomItem(realIdx) : null,
                                  onStateChanged: onStateChanged,
                                );
                              }),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
