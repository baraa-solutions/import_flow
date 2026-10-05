import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/file_save_helper.dart';
import '../../services/table_export_service.dart';
import '../../theme/app_theme.dart';
import 'models/enterprise_column.dart';
import 'widgets/enterprise_table_column_picker_dialog.dart';
import 'widgets/enterprise_table_header_toolbar.dart';
import 'widgets/enterprise_table_pagination_bar.dart';
import 'widgets/enterprise_table_shimmer_skeleton.dart';
import '../../utils/bidi_text.dart';

export 'models/enterprise_column.dart';
export 'widgets/enterprise_table_column_picker_dialog.dart';
export 'widgets/enterprise_table_header_toolbar.dart';
export 'widgets/enterprise_table_pagination_bar.dart';
export 'widgets/enterprise_table_shimmer_skeleton.dart';

/// The standard, high-performance, unified Enterprise Data Table for Sorour Logistics ERP.
///
/// Features:
/// - Generic data typing `<T>`
/// - Column reordering, visibility customization, and user persistence via [SharedPreferences]
/// - Multi-column interactive sorting with visual indicators
/// - Instant global search with debouncing & cell matching
/// - Virtualized/sliced client and server pagination
/// - 1-Click export to CSV/Excel (UTF-8 with BOM for Arabic characters)
/// - 1-Click copy to clipboard (TSV format compatible with Excel)
/// - Multi-row selection with bulk actions
/// - Animated skeleton shimmer loading placeholder
/// - Universal text selection via [SelectionArea]
class EnterpriseDataTable<T> extends StatefulWidget {
  final List<T> data;
  final List<EnterpriseColumn<T>> columns;
  final String? storageKey;
  final String? title;
  final Widget? titleLeading;
  final bool isLoading;
  final String emptyMessage;
  final IconData emptyIcon;
  final bool enableSelection;
  final Set<T>? selectedItems;
  final ValueChanged<Set<T>>? onSelectionChanged;
  final Widget? bulkActions;
  final List<Widget>? extraActions;
  final ValueChanged<T>? onRowTap;
  final String? initialSortColumnId;
  final bool initialSortAscending;
  final int initialPageSize;
  final List<int> availablePageSizes;
  final bool enableExport;
  final String? exportFileName;
  final double rowHeight;
  final double headerHeight;
  final bool Function(T item, String query)? customFilter;

  const EnterpriseDataTable({
    super.key,
    required this.data,
    required this.columns,
    this.storageKey,
    this.title,
    this.titleLeading,
    this.isLoading = false,
    this.emptyMessage = 'لا توجد بيانات مطابقة للعرض',
    this.emptyIcon = Icons.inbox_outlined,
    this.enableSelection = false,
    this.selectedItems,
    this.onSelectionChanged,
    this.bulkActions,
    this.extraActions,
    this.onRowTap,
    this.initialSortColumnId,
    this.initialSortAscending = true,
    this.initialPageSize = 25,
    this.availablePageSizes = const [10, 25, 50, 100],
    this.enableExport = true,
    this.exportFileName,
    this.rowHeight = 50,
    this.headerHeight = 44,
    this.customFilter,
  });

  @override
  State<EnterpriseDataTable<T>> createState() => _EnterpriseDataTableState<T>();
}

class _EnterpriseDataTableState<T> extends State<EnterpriseDataTable<T>> {
  late Set<String> _visibleColumnIds;
  List<String> _columnOrder = [];
  Map<String, double> _columnWidths = {};
  String _searchQuery = '';
  String? _sortColumnId;
  bool _isAscending = true;
  int _currentPage = 1;
  late int _pageSize;
  Set<T> _internalSelectedItems = {};

  @override
  void initState() {
    super.initState();
    _visibleColumnIds = widget.columns.where((c) => c.isVisible).map((c) => c.id).toSet();
    _columnOrder = widget.columns.map((c) => c.id).toList();
    _sortColumnId = widget.initialSortColumnId;
    _isAscending = widget.initialSortAscending;
    _pageSize = widget.initialPageSize;
    if (widget.selectedItems != null) {
      _internalSelectedItems = Set<T>.from(widget.selectedItems!);
    }
    _loadPreferences();
  }

  @override
  void didUpdateWidget(covariant EnterpriseDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedItems != null) {
      _internalSelectedItems = Set<T>.from(widget.selectedItems!);
    }
    for (final col in widget.columns) {
      if (!_columnOrder.contains(col.id)) {
        _columnOrder.add(col.id);
      }
    }
  }

  Future<void> _loadPreferences() async {
    if (widget.storageKey == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyCols = 'enterprise_table_${widget.storageKey}_columns';
      final keyOrder = 'enterprise_table_${widget.storageKey}_columns_order';
      final keyWidths = 'enterprise_table_${widget.storageKey}_column_widths';
      final keyPageSize = 'enterprise_table_${widget.storageKey}_page_size';

      final savedCols = prefs.getStringList(keyCols);
      final savedOrder = prefs.getStringList(keyOrder);
      final savedWidthsJson = prefs.getString(keyWidths);
      final savedSize = prefs.getInt(keyPageSize);

      if (mounted) {
        setState(() {
          if (savedCols != null && savedCols.isNotEmpty) {
            _visibleColumnIds = savedCols.toSet();
            // Ensure locked columns remain visible
            for (final col in widget.columns) {
              if (col.isLocked) _visibleColumnIds.add(col.id);
            }
          }
          if (savedOrder != null && savedOrder.isNotEmpty) {
            final validSaved = savedOrder.where((id) => widget.columns.any((c) => c.id == id)).toList();
            final missing = widget.columns.where((c) => !validSaved.contains(c.id)).map((c) => c.id);
            _columnOrder = [...validSaved, ...missing];
          }
          if (savedWidthsJson != null) {
            try {
              final decoded = jsonDecode(savedWidthsJson) as Map<String, dynamic>;
              _columnWidths = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
            } catch (_) {}
          }
          if (savedSize != null) {
            _pageSize = savedSize;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    if (widget.storageKey == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyCols = 'enterprise_table_${widget.storageKey}_columns';
      final keyOrder = 'enterprise_table_${widget.storageKey}_columns_order';
      final keyWidths = 'enterprise_table_${widget.storageKey}_column_widths';
      final keyPageSize = 'enterprise_table_${widget.storageKey}_page_size';

      await prefs.setStringList(keyCols, _visibleColumnIds.toList());
      await prefs.setStringList(keyOrder, _columnOrder);
      await prefs.setString(keyWidths, jsonEncode(_columnWidths));
      await prefs.setInt(keyPageSize, _pageSize);
    } catch (_) {}
  }

  List<EnterpriseColumn<T>> get _activeColumns {
    final colMap = {for (final c in widget.columns) c.id: c};
    final List<EnterpriseColumn<T>> ordered = [];
    for (final id in _columnOrder) {
      final col = colMap[id];
      if (col != null && _visibleColumnIds.contains(id)) {
        ordered.add(col);
      }
    }
    for (final c in widget.columns) {
      if (_visibleColumnIds.contains(c.id) && !ordered.any((col) => col.id == c.id)) {
        ordered.add(c);
      }
    }
    return ordered;
  }

  List<T> get _filteredAndSortedData {
    // 1. Filter
    List<T> result = widget.data;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((item) {
        if (widget.customFilter != null && widget.customFilter!(item, query)) {
          return true;
        }
        for (final col in _activeColumns) {
          if (!col.isSearchable) continue;
          final searchVal = col.searchValue?.call(item) ?? col.exportValue?.call(item);
          if (searchVal != null && searchVal.toLowerCase().contains(query)) {
            return true;
          }
        }
        return false;
      }).toList();
    }

    // 2. Sort
    if (_sortColumnId != null) {
      final col = widget.columns.firstWhere(
        (c) => c.id == _sortColumnId,
        orElse: () => widget.columns.first,
      );

      result = List<T>.from(result)..sort((a, b) {
        int cmp = 0;
        if (col.sortComparator != null) {
          cmp = col.sortComparator!(a, b);
        } else {
          final aStr = col.exportValue?.call(a) ?? col.searchValue?.call(a) ?? '';
          final bStr = col.exportValue?.call(b) ?? col.searchValue?.call(b) ?? '';
          cmp = aStr.compareTo(bStr);
        }
        return _isAscending ? cmp : -cmp;
      });
    }

    return result;
  }

  List<T> get _pagedData {
    final list = _filteredAndSortedData;
    if (_pageSize <= 0) return list;

    final totalPages = (list.length / _pageSize).ceil();
    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    }
    if (_currentPage < 1) _currentPage = 1;

    final start = (_currentPage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, list.length);
    if (start >= list.length) return [];
    return list.sublist(start, end);
  }

  void _onSort(String columnId) {
    setState(() {
      if (_sortColumnId == columnId) {
        if (_isAscending) {
          _isAscending = false;
        } else {
          _sortColumnId = null; // reset to natural order
          _isAscending = true;
        }
      } else {
        _sortColumnId = columnId;
        _isAscending = true;
      }
    });
  }

  void _handleSelectAll(bool? checked) {
    setState(() {
      if (checked == true) {
        _internalSelectedItems.addAll(_filteredAndSortedData);
      } else {
        _internalSelectedItems.clear();
      }
      widget.onSelectionChanged?.call(_internalSelectedItems);
    });
  }

  void _handleRowSelect(T item, bool? checked) {
    setState(() {
      if (checked == true) {
        _internalSelectedItems.add(item);
      } else {
        _internalSelectedItems.remove(item);
      }
      widget.onSelectionChanged?.call(_internalSelectedItems);
    });
  }

  Future<void> _exportToCSV() async {
    final activeCols = _activeColumns;
    final dataToExport = _filteredAndSortedData;
    if (dataToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات لتصديرها'), backgroundColor: AppTheme.orange),
      );
      return;
    }

    const bom = '\uFEFF';
    final headers = activeCols.map((c) => '"${c.title.replaceAll('"', '""')}"').join(',');
    final rows = dataToExport.map((item) {
      return activeCols.map((c) {
        final val = c.exportValue?.call(item) ?? c.searchValue?.call(item) ?? '';
        return '"${val.replaceAll('"', '""').replaceAll('\n', ' ')}"';
      }).join(',');
    }).toList();

    final csvContent = '$bom$headers\n${rows.join('\n')}';
    final fileName = widget.exportFileName ??
        'Export_${widget.title?.replaceAll(' ', '_') ?? "Table"}_${DateTime.now().millisecondsSinceEpoch}.csv';

    await FileSaveHelper.saveText(
      context: context,
      textContent: csvContent,
      defaultFileName: fileName,
      dialogTitle: 'تصدير بيانات الجدول إلى Excel / CSV',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  Future<void> _copyToClipboard() async {
    final activeCols = _activeColumns;
    final dataToExport = _filteredAndSortedData;
    if (dataToExport.isEmpty) return;

    final headers = activeCols.map((c) => c.title.replaceAll('\t', ' ')).join('\t');
    final rows = dataToExport.map((item) {
      return activeCols.map((c) {
        final val = c.exportValue?.call(item) ?? c.searchValue?.call(item) ?? '';
        return val.replaceAll('\t', ' ').replaceAll('\n', ' ');
      }).join('\t');
    }).toList();

    final tsvContent = '$headers\n${rows.join('\n')}';
    await Clipboard.setData(ClipboardData(text: stripBidiIsolates(tsvContent)));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('تم نسخ ${dataToExport.length} سجل إلى الحافظة بتنسيق Excel بنجاح'),
            ],
          ),
          backgroundColor: AppTheme.emerald,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _exportToPdf() async {
    final activeCols = _activeColumns;
    final dataToExport = _filteredAndSortedData;
    if (dataToExport.isEmpty) return;

    final headers = activeCols.map((c) => c.title).toList();
    final rows = dataToExport.map((item) {
      return activeCols.map((c) {
        return c.exportValue?.call(item) ?? c.searchValue?.call(item) ?? '';
      }).toList();
    }).toList();

    final title = widget.title ?? 'جدول بيانات النظام';
    final stageName = widget.storageKey ?? 'EnterpriseDataTable';
    final importFileNameOrCode = widget.exportFileName ?? 'Report';

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: stageName,
      importFileNameOrCode: importFileNameOrCode,
      headerContext: TableExportHeaderContext(
        title: title,
        subtitle: 'Sorour Logistics ERP — عدد السجلات: ${rows.length}',
      ),
    );
  }

  void _openColumnPicker() {
    EnterpriseTableColumnPickerDialog.show<T>(
      context: context,
      allColumns: widget.columns,
      visibleColumnIds: _visibleColumnIds,
      currentColumnOrder: _columnOrder,
      onColumnsChanged: (newSet) {
        setState(() {
          _visibleColumnIds = newSet;
        });
        _savePreferences();
      },
      onConfigurationChanged: (visibleIds, orderedIds) {
        setState(() {
          _visibleColumnIds = visibleIds;
          _columnOrder = orderedIds;
        });
        _savePreferences();
      },
      onResetToDefaults: () {
        setState(() {
          _visibleColumnIds = widget.columns.where((c) => c.isVisible).map((c) => c.id).toSet();
          _columnOrder = widget.columns.map((c) => c.id).toList();
          _columnWidths.clear();
        });
        _savePreferences();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCols = _activeColumns;
    final totalCount = widget.data.length;
    final filteredData = _filteredAndSortedData;
    final filteredCount = filteredData.length;
    final pagedData = _pagedData;
    final isAllSelected = filteredData.isNotEmpty &&
        filteredData.every((item) => _internalSelectedItems.contains(item));

    final isDark = AppTheme.isDark(context);

    return SelectionArea(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.border,
          ),
          boxShadow: isDark
              ? const [
                  BoxShadow(
                      color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
                ]
              : AppTheme.shadowSoft,
        ),
        // Clip children (header band, pagination) to the rounded corners.
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Header Toolbar
            EnterpriseTableHeaderToolbar(
              title: widget.title,
              titleLeading: widget.titleLeading,
              totalCount: totalCount,
              filteredCount: filteredCount,
              selectedCount: _internalSelectedItems.length,
              searchQuery: _searchQuery,
              onSearchChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                  _currentPage = 1;
                });
              },
              onClearSearch: () {
                setState(() {
                  _searchQuery = '';
                  _currentPage = 1;
                });
              },
              onOpenColumnPicker: _openColumnPicker,
              onExportCSV: widget.enableExport ? _exportToCSV : null,
              onExportPDF: widget.enableExport ? _exportToPdf : null,
              onCopyToClipboard: widget.enableExport ? _copyToClipboard : null,
              extraActions: widget.extraActions,
              bulkActions: widget.bulkActions,
            ),

            // 2. Table Body / Shimmer / Empty State
            if (widget.isLoading)
              EnterpriseTableShimmerSkeleton(
                rowCount: _pageSize > 0 && _pageSize <= 10 ? _pageSize : 6,
                columnCount: activeCols.length + (widget.enableSelection ? 1 : 0),
              )
            else if (filteredCount == 0)
              _buildEmptyState()
            else
              _buildTable(activeCols, pagedData, isAllSelected),

            // 3. Bottom Pagination Bar
            EnterpriseTablePaginationBar(
              totalCount: filteredCount,
              currentPage: _currentPage,
              pageSize: _pageSize,
              availablePageSizes: widget.availablePageSizes,
              onPageChanged: (newPage) => setState(() => _currentPage = newPage),
              onPageSizeChanged: (newSize) {
                setState(() {
                  _pageSize = newSize;
                  _currentPage = 1;
                });
                _savePreferences();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _searchQuery.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon in a soft circular badge (empty-state illustration).
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppTheme.surfaceAltOf(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: Icon(
              isFiltered ? Icons.search_off_rounded : widget.emptyIcon,
              size: 36,
              color: AppTheme.textMutedOf(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered ? 'لا توجد نتائج مطابقة لبحثك "$_searchQuery"' : widget.emptyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.5,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
          if (isFiltered) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('مسح البحث وإظهار كافة السجلات'),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _currentPage = 1;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTable(
    List<EnterpriseColumn<T>> activeCols,
    List<T> pagedData,
    bool isAllSelected,
  ) {
    final isDark = AppTheme.isDark(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 800),
        child: DataTable(
          headingRowHeight: widget.headerHeight,
          dataRowMinHeight: widget.rowHeight,
          dataRowMaxHeight: widget.rowHeight + 8,
          horizontalMargin: 16,
          columnSpacing: 20,
          dividerThickness: 1,
          border: TableBorder(
            horizontalInside: BorderSide(
              color: isDark ? AppTheme.darkBorder : const Color(0xFFEEF2F6),
            ),
            top: BorderSide(color: AppTheme.borderOf(context)),
          ),
          headingRowColor: WidgetStateProperty.all(
            isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
          ),
          showCheckboxColumn: false, // handled via our custom checkbox column
          columns: [
            // Optional Selection Checkbox Column
            if (widget.enableSelection)
              DataColumn(
                label: SizedBox(
                  width: 32,
                  child: Checkbox(
                    value: isAllSelected,
                    onChanged: _handleSelectAll,
                  ),
                ),
              ),

            // Active Columns
            ...activeCols.map((col) {
              final isSorted = _sortColumnId == col.id;
              final colWidth = _columnWidths[col.id] ?? col.width;

              // The InkWell fills the full header-cell height (and the full width for columns with
              // an explicit width) so the sort tap target stays close to DataColumn.onSort's cell target.
              final headerContent = InkWell(
                key: ValueKey('enterprise_table_header_${col.id}'),
                onTap: col.isSortable ? () => _onSort(col.id) : null,
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: widget.headerHeight,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          col.title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                            color: isSorted
                                ? AppTheme.cobalt
                                : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                          ),
                          textAlign: col.textAlign,
                        ),
                      ),
                      if (col.isSortable) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isSorted
                              ? (_isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                              : Icons.unfold_more_rounded,
                          size: 14,
                          color: isSorted ? AppTheme.cobalt : AppTheme.textMutedOf(context),
                        ),
                      ],
                    ],
                  ),
                  ),
                ),
              );

              final resizeHandle = MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    final isRtl = Directionality.of(context) == TextDirection.rtl;
                    final delta = isRtl ? -details.delta.dx : details.delta.dx;
                    setState(() {
                      final currentW = _columnWidths[col.id] ?? col.width ?? 130.0;
                      final newW = (currentW + delta).clamp(50.0, 800.0);
                      _columnWidths[col.id] = newW;
                    });
                  },
                  onHorizontalDragEnd: (_) => _savePreferences(),
                  onDoubleTap: () {
                    setState(() => _columnWidths.remove(col.id));
                    _savePreferences();
                  },
                  child: Container(
                    width: 14,
                    height: widget.headerHeight,
                    alignment: Alignment.center,
                    child: Container(
                      width: 2,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              );

              final Widget labelWidget = colWidth != null
                  ? SizedBox(
                      width: colWidth,
                      child: Row(
                        children: [
                          Expanded(child: headerContent),
                          resizeHandle,
                        ],
                      ),
                    )
                  : Row(
                      // DataTable gives heading labels unbounded width, so this row
                      // shrink-wraps; the InkWell still spans the full cell height.
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        headerContent,
                        const SizedBox(width: 4),
                        resizeHandle,
                      ],
                    );

              return DataColumn(
                tooltip: col.tooltip,
                // Sorting is handled by the header InkWell above (with its own arrow icon).
                // Setting DataColumn.onSort too nests two tap targets around the
                // columnHeader semantics node, which Flutter >= 3.44 rejects.
                label: labelWidget,
              );
            }),
          ],
          rows: pagedData.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isEven = index.isEven;
            final isSelected = _internalSelectedItems.contains(item);

            return DataRow(
              selected: isSelected,
              color: WidgetStateProperty.resolveWith((states) {
                if (isSelected) return AppTheme.cobalt.withValues(alpha: 0.10);
                if (states.contains(WidgetState.hovered)) {
                  return isDark
                      ? AppTheme.darkElevatedSurface.withValues(alpha: 0.5)
                      : AppTheme.infoBackground.withValues(alpha: 0.7);
                }
                return isEven
                    ? (isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt)
                    : (isDark ? AppTheme.darkCardBackground : AppTheme.surface);
              }),
              onSelectChanged: widget.onRowTap != null
                  ? (_) => widget.onRowTap!(item)
                  : null,
              cells: [
                // Selection Checkbox Cell
                if (widget.enableSelection)
                  DataCell(
                    SizedBox(
                      width: 32,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (val) => _handleRowSelect(item, val),
                      ),
                    ),
                  ),

                // Data Cells
                ...activeCols.map((col) {
                  final colWidth = _columnWidths[col.id] ?? col.width;
                  Widget cellContent = col.cellBuilder(context, item, index);
                  if (col.isNumeric) {
                    // LTR island: keeps signs, ranges and codes in order under RTL.
                    cellContent = Directionality(
                      textDirection: TextDirection.ltr,
                      child: cellContent,
                    );
                  }
                  if (colWidth != null) {
                    cellContent = SizedBox(
                      width: colWidth,
                      child: Align(
                        alignment: col.alignment,
                        child: cellContent,
                      ),
                    );
                  } else {
                    cellContent = Align(
                      alignment: col.alignment,
                      child: cellContent,
                    );
                  }
                  return DataCell(cellContent);
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
