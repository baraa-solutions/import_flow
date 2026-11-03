import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/expense_catalog_model.dart';

/// Data table and listing widget for reference expense catalog items.
class ExpenseCatalogDataTable extends StatelessWidget {
  final List<ExpenseCatalogModel> items;
  final bool isLoading;
  final void Function(ExpenseCatalogModel item)? onView;
  final void Function(ExpenseCatalogModel item)? onEdit;
  final void Function(ExpenseCatalogModel item)? onAddPattern;
  final void Function(ExpenseCatalogModel item)? onDeactivate;

  const ExpenseCatalogDataTable({
    super.key,
    required this.items,
    required this.isLoading,
    this.onView,
    this.onEdit,
    this.onAddPattern,
    this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return Center(
        child: Text(
          isArabic ? 'لا توجد بنود مصروفات مطابقة' : 'No expense items found',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: InkWell(
                    onTap: () => CopyHelper.copy(context, item.code),
                    child: Text(
                      item.code,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: AppTheme.cobalt,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.canonicalNameAr,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (item.canonicalNameEn != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '(${item.canonicalNameEn})',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Chip(
                            label: Text(item.category, style: const TextStyle(fontSize: 10.5)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            backgroundColor: isDark ? const Color(0xFF253140) : const Color(0xFFF1F5F9),
                          ),
                          Chip(
                            label: Text(item.unitType, style: const TextStyle(fontSize: 10.5)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                          if (item.allowComposite)
                            Chip(
                              label: Text(isArabic ? 'مجمع' : 'Composite', style: const TextStyle(fontSize: 10.5, color: Colors.orange)),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      if (item.recognitionPatterns.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            ...item.recognitionPatterns.map(
                              (pat) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.emerald.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  pat,
                                  style: const TextStyle(fontSize: 10.5, color: AppTheme.emerald),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      tooltip: isArabic ? 'إضافة مرادف ذكي' : 'Add Recognition Pattern',
                      color: AppTheme.emerald,
                      onPressed: onAddPattern != null ? () => onAddPattern!(item) : null,
                    ),
                    const SizedBox(width: 4),
                    RowActionsPill(
                      onView: onView != null ? () => onView!(item) : null,
                      viewTooltip: isArabic ? 'عرض وتفاصيل البند' : 'View Item Details',
                      onEdit: onEdit != null ? () => onEdit!(item) : null,
                      editTooltip: isArabic ? 'تعديل البند' : 'Edit',
                      onDelete: onDeactivate != null ? () => onDeactivate!(item) : null,
                      deleteTooltip: isArabic ? 'تعطيل البند' : 'Deactivate',
                      confirmDelete: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
