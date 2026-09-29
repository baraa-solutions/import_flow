import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import 'directional_icon.dart';

/// Ultra-compact, standardized bottom pagination footer for Data Tables in ImportFlow ERP.
///
/// Designed to sit seamlessly at the bottom edge of a table container with ZERO gray margin,
/// a clean 1px border divider, and an ultra-streamlined height (32px - 36px) to maximize vertical
/// table viewport.
class CompactTablePaginationFooter extends StatelessWidget {
  final int currentPage; // 1-indexed
  final int totalPages;
  final int totalCount;
  final int? pageSize;
  final List<int>? availablePageSizes;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;
  final String? customCountLabel;
  final bool isMobile;

  const CompactTablePaginationFooter({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalCount,
    this.pageSize,
    this.availablePageSizes,
    required this.onPageChanged,
    this.onPageSizeChanged,
    this.customCountLabel,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = AppTheme.isDark(context);

    final safeTotalPages = totalPages > 0 ? totalPages : 1;
    final safeCurrentPage = currentPage.clamp(1, safeTotalPages);

    final int startItem;
    final int endItem;
    if (pageSize != null && pageSize! > 0) {
      startItem = totalCount == 0 ? 0 : (safeCurrentPage - 1) * pageSize! + 1;
      final calcEnd = safeCurrentPage * pageSize!;
      endItem = calcEnd > totalCount ? totalCount : calcEnd;
    } else {
      startItem = totalCount == 0 ? 0 : 1;
      endItem = totalCount;
    }

    return Container(
      height: isMobile ? 36 : 34,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: 2,
      ),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Count / Range & Optional Page Size Selector
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onPageSizeChanged != null && availablePageSizes != null && availablePageSizes!.isNotEmpty && pageSize != null) ...[
                  Text(
                    l.rowsPerPageLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  DropdownButton<int>(
                    value: availablePageSizes!.contains(pageSize) ? pageSize : availablePageSizes!.first,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                    items: availablePageSizes!.map((s) {
                      return DropdownMenuItem<int>(
                        value: s,
                        child: Text('$s'),
                      );
                    }).toList(),
                    onChanged: (newSize) {
                      if (newSize != null && newSize != pageSize) {
                        onPageSizeChanged!(newSize);
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 12,
                    width: 1,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  const SizedBox(width: 10),
                ],

                // Count Range Text
                Flexible(
                  child: Text(
                    customCountLabel ??
                        (pageSize != null
                            ? '$startItem - $endItem / $totalCount'
                            : '$totalCount'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right: Compact Navigation Buttons (26px height, zero padding)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // First Page
              IconButton(
                icon: const DirectionalIcon(Icons.first_page),
                tooltip: l.firstPageTooltip,
                iconSize: 17,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                splashRadius: 14,
                onPressed: safeCurrentPage > 1 ? () => onPageChanged(1) : null,
              ),

              // Previous Page
              IconButton(
                icon: const DirectionalIcon(Icons.chevron_left),
                tooltip: l.previousPageTooltip,
                iconSize: 17,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                splashRadius: 14,
                onPressed: safeCurrentPage > 1 ? () => onPageChanged(safeCurrentPage - 1) : null,
              ),

              // Page Indicator Pill
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
                  '$safeCurrentPage / $safeTotalPages',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
              ),

              // Next Page
              IconButton(
                icon: const DirectionalIcon(Icons.chevron_right),
                tooltip: l.nextPageTooltip,
                iconSize: 17,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                splashRadius: 14,
                onPressed: safeCurrentPage < safeTotalPages ? () => onPageChanged(safeCurrentPage + 1) : null,
              ),

              // Last Page
              IconButton(
                icon: const DirectionalIcon(Icons.last_page),
                tooltip: l.lastPageTooltip,
                iconSize: 17,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                splashRadius: 14,
                onPressed: safeCurrentPage < safeTotalPages ? () => onPageChanged(safeTotalPages) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
