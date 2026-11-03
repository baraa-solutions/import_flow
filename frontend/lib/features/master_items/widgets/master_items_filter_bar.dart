import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../providers/master_items_provider.dart';

/// Standard product categories for Master Items in ImportFlow ERP
const List<String> kMasterItemCategories = [
  'All',
  'Raw Materials',
  'Spare Parts',
  'Finished Goods',
  'Machinery & Equipment',
  'Chemicals',
  'Electronics',
  'Packaging',
  'General Cargo',
];

/// Localized labels for categories
String getCategoryLabelAr(String category) {
  switch (category) {
    case 'All':
      return 'جميع الفئات';
    case 'Raw Materials':
      return 'مواد خام';
    case 'Spare Parts':
      return 'قطع غيار';
    case 'Finished Goods':
      return 'بضائع تامة الصنع';
    case 'Machinery & Equipment':
      return 'آلات ومعدات';
    case 'Chemicals':
      return 'كيماويات';
    case 'Electronics':
      return 'إلكترونيات';
    case 'Packaging':
      return 'مواد تغليف';
    case 'General Cargo':
      return 'بضائع عامة';
    default:
      return category;
  }
}

/// Compact category filter designed to plug directly into [ActionToolbar.filters]
class MasterItemsCategoryFilter extends ConsumerWidget {
  final double? width;

  const MasterItemsCategoryFilter({
    super.key,
    this.width = 150.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(masterItemsProvider).value;
    final selectedCategory = state?.selectedCategory ?? 'All';

    // Collect any extra distinct categories from loaded data
    final allCategories = <String>{'All', ...kMasterItemCategories};
    if (state != null) {
      for (final item in state.items) {
        if (item.productCategory != null && item.productCategory!.trim().isNotEmpty) {
          allCategories.add(item.productCategory!.trim());
        }
      }
    }

    return Container(
      width: width,
      height: density.buttonHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.black12,
          width: 0.8,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: allCategories.contains(selectedCategory) ? selectedCategory : 'All',
          isDense: true,
          isExpanded: true,
          icon: Icon(
            Icons.filter_list_rounded,
            size: density.buttonIconSize,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.cobalt,
          ),
          style: TextStyle(
            fontSize: density.inputFontSize,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            fontFamily: 'Cairo',
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          items: allCategories.map((cat) {
            final label = getCategoryLabelAr(cat);
            return DropdownMenuItem<String>(
              value: cat,
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: density.inputFontSize,
                  fontWeight: cat == selectedCategory ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
          onChanged: (cat) {
            ref.read(masterItemsProvider.notifier).setCategory(cat == 'All' ? null : cat);
          },
        ),
      ),
    );
  }
}

/// Standalone Compact Filter Bar for Master Items
class MasterItemsFilterBar extends ConsumerWidget {
  final TextEditingController? searchController;
  final VoidCallback? onReset;

  const MasterItemsFilterBar({
    super.key,
    this.searchController,
    this.onReset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = ref.watch(displayDensityProvider);
    final state = ref.watch(masterItemsProvider).value;
    final selectedCategory = state?.selectedCategory;

    final hasActiveFilter = (selectedCategory != null && selectedCategory != 'All') ||
        (searchController != null && searchController!.text.isNotEmpty);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MasterItemsCategoryFilter(),
        if (hasActiveFilter) ...[
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(
              Icons.filter_alt_off_rounded,
              size: density.buttonIconSize + 2,
              color: AppTheme.crimson,
            ),
            tooltip: 'إعادة ضبط الفلاتر',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: density.buttonHeight,
              minHeight: density.buttonHeight,
            ),
            onPressed: () {
              searchController?.clear();
              ref.read(masterItemsProvider.notifier).setSearchQuery('');
              ref.read(masterItemsProvider.notifier).setCategory(null);
              onReset?.call();
            },
          ),
        ],
      ],
    );
  }
}
