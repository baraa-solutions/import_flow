import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Bottom pagination bar for [EnterpriseDataTable].
class EnterpriseTablePaginationBar extends StatelessWidget {
  final int totalCount;
  final int currentPage; // 1-indexed
  final int pageSize; // items per page, e.g. 10, 25, 50, 100, -1 for All
  final List<int> availablePageSizes;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  const EnterpriseTablePaginationBar({
    super.key,
    required this.totalCount,
    required this.currentPage,
    required this.pageSize,
    this.availablePageSizes = const [10, 25, 50, 100],
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalCount == 0) return const SizedBox.shrink();

    final isAll = pageSize <= 0;
    final totalPages = isAll ? 1 : (totalCount / pageSize).ceil();
    final clampedCurrentPage = currentPage.clamp(1, totalPages > 0 ? totalPages : 1);

    final startItem = isAll ? 1 : ((clampedCurrentPage - 1) * pageSize + 1);
    final endItem = isAll ? totalCount : (clampedCurrentPage * pageSize).clamp(0, totalCount);

    final isDark = AppTheme.isDark(context);

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
            width: 1.0,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Items per page selector & Range text
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'الصفوف بالصفحة:',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      DropdownButton<int>(
                        value: availablePageSizes.contains(pageSize) ? pageSize : availablePageSizes.first,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                        items: [
                          ...availablePageSizes.map((size) {
                            return DropdownMenuItem<int>(
                              value: size,
                              child: Text('$size'),
                            );
                          }),
                          const DropdownMenuItem<int>(
                            value: -1,
                            child: Text('الكل'),
                          ),
                        ],
                        onChanged: (newSize) {
                          if (newSize != null) onPageSizeChanged(newSize);
                        },
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'عرض $startItem - $endItem من إجمالي $totalCount',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 8),

                  // Right: Page navigation controls
                  if (!isAll && totalPages > 1)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // First Page
                        IconButton(
                          tooltip: 'الصفحة الأولى',
                          icon: const Icon(Icons.first_page_rounded),
                          iconSize: 17,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          splashRadius: 14,
                          onPressed: clampedCurrentPage > 1 ? () => onPageChanged(1) : null,
                        ),

                        // Previous Page
                        IconButton(
                          tooltip: 'الصفحة السابقة',
                          icon: const Icon(Icons.chevron_left_rounded),
                          iconSize: 17,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          splashRadius: 14,
                          onPressed: clampedCurrentPage > 1 ? () => onPageChanged(clampedCurrentPage - 1) : null,
                        ),

                        // Page Indicator
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E2631) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '$clampedCurrentPage / $totalPages',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                            ),
                          ),
                        ),

                        // Next Page
                        IconButton(
                          tooltip: 'الصفحة التالية',
                          icon: const Icon(Icons.chevron_right_rounded),
                          iconSize: 17,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          splashRadius: 14,
                          onPressed: clampedCurrentPage < totalPages ? () => onPageChanged(clampedCurrentPage + 1) : null,
                        ),

                        // Last Page
                        IconButton(
                          tooltip: 'الصفحة الأخيرة',
                          icon: const Icon(Icons.last_page_rounded),
                          iconSize: 17,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          splashRadius: 14,
                          onPressed: clampedCurrentPage < totalPages ? () => onPageChanged(totalPages) : null,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
