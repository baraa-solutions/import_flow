import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../providers/customs_consultation_provider.dart';

/// Normalized similarity scorer for Arabic & English strings
class ExpenseSimilarityMatcher {
  static String normalize(String s) {
    var str = s.toLowerCase().trim();
    str = str.replaceAll(RegExp(r'[أإآ]'), 'ا');
    str = str.replaceAll('ة', 'ه');
    str = str.replaceAll('ى', 'ي');
    str = str.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ' ');
    return str.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static int calculateScore(String target, ExpenseCatalogItemModel catalogItem) {
    final tNorm = normalize(target);
    if (tNorm.isEmpty) return 0;

    final nameArNorm = normalize(catalogItem.canonicalNameAr);
    final nameEnNorm = normalize(catalogItem.canonicalNameEn ?? '');
    final codeNorm = normalize(catalogItem.code);

    if (tNorm == nameArNorm || tNorm == nameEnNorm || tNorm == codeNorm) {
      return 100;
    }

    // Check recognition patterns
    for (final pattern in catalogItem.recognitionPatterns) {
      final pNorm = normalize(pattern);
      if (tNorm == pNorm) return 98;
      if (tNorm.contains(pNorm) || pNorm.contains(tNorm)) return 92;
    }

    if (tNorm.contains(nameArNorm) || nameArNorm.contains(tNorm)) {
      return 85;
    }

    if (nameEnNorm.isNotEmpty && (tNorm.contains(nameEnNorm) || nameEnNorm.contains(tNorm))) {
      return 80;
    }

    // Token overlap
    final tTokens = tNorm.split(' ').where((w) => w.length > 1).toSet();
    final catTokens = '$nameArNorm $nameEnNorm $codeNorm'.split(' ').where((w) => w.length > 1).toSet();
    if (tTokens.isNotEmpty && catTokens.isNotEmpty) {
      final intersection = tTokens.intersection(catTokens);
      if (intersection.isNotEmpty) {
        final ratio = (intersection.length / tTokens.length) * 75;
        return ratio.round().clamp(10, 75);
      }
    }

    return 0;
  }
}

/// Dialog to quickly code uncoded customs clearance expense items
class QuickExpenseCodingDialog extends ConsumerStatefulWidget {
  final String currentExpenseName;
  final String? currentCategory;
  final Function(ExpenseCatalogItemModel selectedItem) onSelected;

  const QuickExpenseCodingDialog({
    super.key,
    required this.currentExpenseName,
    this.currentCategory,
    required this.onSelected,
  });

  static Future<ExpenseCatalogItemModel?> show({
    required BuildContext context,
    required WidgetRef ref,
    required String currentExpenseName,
    String? currentCategory,
    required Function(ExpenseCatalogItemModel selectedItem) onSelected,
  }) {
    return showDialog<ExpenseCatalogItemModel>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => QuickExpenseCodingDialog(
        currentExpenseName: currentExpenseName,
        currentCategory: currentCategory,
        onSelected: onSelected,
      ),
    );
  }

  @override
  ConsumerState<QuickExpenseCodingDialog> createState() => _QuickExpenseCodingDialogState();
}

class _QuickExpenseCodingDialogState extends ConsumerState<QuickExpenseCodingDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final catalogState = ref.read(expenseCatalogProvider);
      if (catalogState.valueOrNull == null || catalogState.valueOrNull!.isEmpty) {
        ref.read(expenseCatalogProvider.notifier).fetchCatalog();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final catalogAsync = ref.watch(expenseCatalogProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: SelectionArea(
        child: Container(
          width: 720,
          height: 620,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cobaltLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, color: AppTheme.cobalt, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAr ? 'التكويد السريع للبند واختيار الكتالوج' : 'Quick Item Coding & Catalog Link',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              isAr ? 'البند المطلوب تكويده: ' : 'Target Item: ',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.crimsonLight,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.crimsonBorder),
                                ),
                                child: Text(
                                  widget.currentExpenseName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.crimson),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Search & Filter Bar
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: isAr ? 'ابحث بالاسم أو الكود...' : 'Search by name or code...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SearchableDropdownField<String>(
                      value: _selectedCategory,
                      labelText: isAr ? 'الفئة' : 'Category',
                      items: [
                        SearchableDropdownItem(value: 'All', label: l.allCategoriesItem),
                        SearchableDropdownItem(value: 'Clearance Fees', label: isAr ? 'أتعاب التخليص' : 'Clearance Fees'),
                        SearchableDropdownItem(value: 'Procedures & Approvals', label: isAr ? 'إجراءات وموافقات' : 'Procedures & Approvals'),
                        SearchableDropdownItem(value: 'Inland Transport', label: isAr ? 'نقل داخلي' : 'Inland Transport'),
                        SearchableDropdownItem(value: 'Port & Handling', label: isAr ? 'مصاريف ومناولة الميناء' : 'Port & Handling'),
                        SearchableDropdownItem(value: 'Other Fees', label: isAr ? 'رسوم ومصاريف أخرى' : 'Other Fees'),
                      ],
                      onChanged: (v) => setState(() => _selectedCategory = v ?? 'All'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Catalog List with Smart Suggestions
              Expanded(
                child: catalogAsync.when(
                  loading: () => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2.5),
                        SizedBox(height: 12),
                        Text('جاري تحميل كتالوج المصروفات المعتمد...', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Text('خطأ في تحميل الكتالوج: $err', style: const TextStyle(color: AppTheme.crimson)),
                  ),
                  data: (catalog) {
                    if (catalog.isEmpty) {
                      return Center(
                        child: Text(
                          isAr ? 'لا توجد بنود مسجلة في كتالوج المصروفات.' : 'No items in expense catalog.',
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      );
                    }

                    // Score and filter
                    final scoredItems = catalog.map((item) {
                      final score = ExpenseSimilarityMatcher.calculateScore(widget.currentExpenseName, item);
                      return MapEntry(item, score);
                    }).toList();

                    // Filter
                    final filtered = scoredItems.where((entry) {
                      final item = entry.key;
                      final matchCat = _selectedCategory == 'All' || item.category == _selectedCategory;
                      if (!matchCat) return false;

                      if (_searchQuery.isEmpty) return true;
                      final q = _searchQuery.toLowerCase();
                      return item.canonicalNameAr.toLowerCase().contains(q) ||
                          (item.canonicalNameEn?.toLowerCase().contains(q) ?? false) ||
                          item.code.toLowerCase().contains(q);
                    }).toList();

                    // Sort: top similarity score first, then by code
                    filtered.sort((a, b) {
                      if (b.value != a.value) {
                        return b.value.compareTo(a.value);
                      }
                      return a.key.code.compareTo(b.key.code);
                    });

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          isAr ? 'لم يتم العثور على نتائج مطابقة للبحث.' : 'No matching catalog items found.',
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, color: AppTheme.cloudWhite),
                      itemBuilder: (ctx, i) {
                        final item = filtered[i].key;
                        final score = filtered[i].value;
                        final isSmartSuggestion = score >= 60;

                        return Container(
                          decoration: BoxDecoration(
                            color: isSmartSuggestion
                                ? AppTheme.emeraldLight.withValues(alpha: 0.35)
                                : (i.isEven ? AppTheme.white : AppTheme.charcoalSurface),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              // Code Chip
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.cobalt,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.code,
                                  style: const TextStyle(
                                    color: AppTheme.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Name & Category
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            isAr ? item.canonicalNameAr : (item.canonicalNameEn ?? item.canonicalNameAr),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: AppTheme.charcoal,
                                            ),
                                          ),
                                        ),
                                        if (isSmartSuggestion) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.emerald,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.auto_awesome, size: 10, color: AppTheme.white),
                                                const SizedBox(width: 2),
                                                Text(
                                                  isAr ? 'اقتراح ذكي ($score%)' : 'Smart Suggestion ($score%)',
                                                  style: const TextStyle(color: AppTheme.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.category} • ${item.unitType}',
                                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),

                              // Select & Link Action Button
                              AppButton(
                                label: isAr ? 'اختيار وربط' : 'Select & Link',
                                icon: Icons.link_rounded,
                                variant: isSmartSuggestion ? AppButtonVariant.success : AppButtonVariant.secondary,
                                size: AppButtonSize.small,
                                onPressed: () {
                                  // Call addPattern in background to train the catalog
                                  ref.read(expenseCatalogProvider.notifier).addPattern(item.code, widget.currentExpenseName);
                                  widget.onSelected(item);
                                  Navigator.of(context).pop(item);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isAr
                                          ? '✨ تم ربط البند بنجاح بالكود المعتمد: ${item.code}'
                                          : '✨ Linked item to code: ${item.code}'),
                                      backgroundColor: AppTheme.emerald,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isAr
                        ? '💡 يؤدي اختيار البند إلى ربطه فورياً وتعليم النظام للتعرف عليه مستقبلاً'
                        : '💡 Selecting an item links it immediately and teaches future recognition',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                  AppButton(
                    label: l.cancel,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
