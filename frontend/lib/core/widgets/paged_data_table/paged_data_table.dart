import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../localization/app_localizations.dart';
import '../../network/api_error.dart';
import '../../theme/app_theme.dart';
import '../../theme/density_provider.dart';
import '../compact_table_pagination_footer.dart';
import '../enterprise_data_table/widgets/enterprise_table_shimmer_skeleton.dart';
import 'list_query.dart';
import 'paged_list_notifier.dart';
import 'paged_table_column.dart';
import 'paged_table_column_picker_dialog.dart';
import 'row_action.dart';
import '../../services/file_save_helper.dart';

/// Standard, high-performance, virtualized Paged Data Table for ImportFlow ERP.
///
/// Features:
/// - Virtualized rows via [ListView.builder] matching current display density row height.
/// - Sticky header that stays fixed during vertical scrolling.
/// - Pinned start columns (e.g. actions, selection, codes) synced in both RTL and LTR.
/// - Column resizing with SharedPreferences persistence (`paged_table_<storageKey>_*`).
/// - Column picker modal for visibility and order customization.
/// - Integrated server-side sorting (asc/desc/none).
/// - Debounced search and filter chips in toolbar.
/// - Seamless loading state (shimmer on first load, thin progress line on subsequent pages).
/// - Keyboard shortcuts (Arrows, Enter, PageUp/PageDown, Ctrl+C to copy row as TSV, Delete).
/// - Responsive card fallback on compact screens (< 768px).
class PagedDataTable<T> extends ConsumerStatefulWidget {
  /// Unique key for persisting column widths, order, visibility, and page size in SharedPreferences.
  final String? storageKey;

  /// Column specifications.
  final List<PagedTableColumn<T>> columns;

  /// Current state from [PagedListNotifier].
  final PagedListState<T> state;

  /// Callback when query parameters change (page, size, search, sort, filters).
  final ValueChanged<ListQuery> onQueryChanged;

  /// Callback providing actions for each row item.
  final List<RowAction<T>> Function(T row)? rowActions;

  /// Double-click or Enter key handler on a focused row.
  final void Function(T row)? onOpen;

  /// Business ID extractor for row selection and focus tracking.
  final Object Function(T row)? rowKey;

  /// Whether rows can be selected with checkboxes.
  final bool selectable;

  /// Currently selected row keys.
  final Set<Object>? selectedKeys;

  /// Callback when row selection changes.
  final ValueChanged<Set<Object>>? onSelectionChanged;

  /// Widget rendered when one or more rows are selected.
  final Widget Function(Set<Object> selectedKeys)? bulkActions;

  /// Leading widget placed in the toolbar (e.g. title, primary create button).
  final Widget? toolbarLeading;

  /// Filter widgets (e.g. dropdowns) placed in the toolbar.
  final List<Widget>? toolbarFilters;

  /// Name of the stage/entity for file export (e.g. "Purchase Orders").
  final String? exportStageName;

  /// Message displayed when list is empty.
  final String? emptyMessage;

  /// Available page size options.
  final List<int> pageSizes;

  /// Callback to refresh data.
  final VoidCallback? onRefresh;

  /// Custom exporter callback for all matching items.
  final Future<void> Function(List<T> items)? onExport;

  /// Optional data source used for full exports across all pages.
  final PagedSource<T>? source;

  const PagedDataTable({
    super.key,
    this.storageKey,
    required this.columns,
    required this.state,
    required this.onQueryChanged,
    this.rowActions,
    this.onOpen,
    this.rowKey,
    this.selectable = false,
    this.selectedKeys,
    this.onSelectionChanged,
    this.bulkActions,
    this.toolbarLeading,
    this.toolbarFilters,
    this.exportStageName,
    this.emptyMessage,
    this.pageSizes = const [25, 50, 100],
    this.onRefresh,
    this.onExport,
    this.source,
  });

  @override
  ConsumerState<PagedDataTable<T>> createState() => _PagedDataTableState<T>();
}

class _PagedDataTableState<T> extends ConsumerState<PagedDataTable<T>> {
  // Column preferences
  late Set<String> _visibleColumnIds;
  late List<String> _columnOrder;
  late Map<String, double> _columnWidths;

  // Selection
  late Set<Object> _selectedKeys;

  // Scroll controllers for synchronization
  final ScrollController _headerHorizontalController = ScrollController();
  final ScrollController _bodyHorizontalController = ScrollController();
  final ScrollController _pinnedVerticalController = ScrollController();
  final ScrollController _scrollVerticalController = ScrollController();

  bool _isSyncingVertical = false;
  bool _isSyncingHorizontal = false;

  // Search input & debouncing
  late final TextEditingController _searchController;
  Timer? _searchDebounce;

  // Keyboard navigation & focus
  int _focusedIndex = 0;
  final FocusNode _tableFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _visibleColumnIds = widget.columns.map((c) => c.id).toSet();
    _columnOrder = widget.columns.map((c) => c.id).toList();
    _columnWidths = {for (final c in widget.columns) c.id: c.width};
    _selectedKeys = widget.selectedKeys != null ? Set.from(widget.selectedKeys!) : {};

    _searchController = TextEditingController(text: widget.state.query.search);

    _setupScrollSynchronization();
    _loadPreferences();
  }

  @override
  void didUpdateWidget(covariant PagedDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedKeys != null && widget.selectedKeys != oldWidget.selectedKeys) {
      _selectedKeys = Set.from(widget.selectedKeys!);
    }
    if (widget.state.query.search != _searchController.text && !_searchController.value.isComposingRangeValid) {
      _searchController.text = widget.state.query.search;
    }
    final itemsCount = widget.state.data?.items.length ?? 0;
    if (widget.state.query.page != oldWidget.state.query.page ||
        widget.state.data != oldWidget.state.data) {
      if (itemsCount == 0) {
        _focusedIndex = 0;
      } else if (_focusedIndex >= itemsCount) {
        _focusedIndex = itemsCount - 1;
      }
    }
    // Check if new columns were added
    for (final col in widget.columns) {
      if (!_columnOrder.contains(col.id)) {
        _columnOrder.add(col.id);
        _visibleColumnIds.add(col.id);
        _columnWidths[col.id] = col.width;
      }
    }
  }

  void _setupScrollSynchronization() {
    // Sync horizontal header with horizontal body
    _bodyHorizontalController.addListener(() {
      if (_isSyncingHorizontal) return;
      _isSyncingHorizontal = true;
      if (_headerHorizontalController.hasClients &&
          _headerHorizontalController.offset != _bodyHorizontalController.offset) {
        _headerHorizontalController.jumpTo(_bodyHorizontalController.offset);
      }
      _isSyncingHorizontal = false;
    });

    _headerHorizontalController.addListener(() {
      if (_isSyncingHorizontal) return;
      _isSyncingHorizontal = true;
      if (_bodyHorizontalController.hasClients &&
          _bodyHorizontalController.offset != _headerHorizontalController.offset) {
        _bodyHorizontalController.jumpTo(_headerHorizontalController.offset);
      }
      _isSyncingHorizontal = false;
    });

    // Sync vertical pinned pane with scrolling pane
    _pinnedVerticalController.addListener(() {
      if (_isSyncingVertical) return;
      _isSyncingVertical = true;
      if (_scrollVerticalController.hasClients &&
          _scrollVerticalController.offset != _pinnedVerticalController.offset) {
        _scrollVerticalController.jumpTo(_pinnedVerticalController.offset);
      }
      _isSyncingVertical = false;
    });

    _scrollVerticalController.addListener(() {
      if (_isSyncingVertical) return;
      _isSyncingVertical = true;
      if (_pinnedVerticalController.hasClients &&
          _pinnedVerticalController.offset != _scrollVerticalController.offset) {
        _pinnedVerticalController.jumpTo(_scrollVerticalController.offset);
      }
      _isSyncingVertical = false;
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _headerHorizontalController.dispose();
    _bodyHorizontalController.dispose();
    _pinnedVerticalController.dispose();
    _scrollVerticalController.dispose();
    _tableFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    if (widget.storageKey == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyCols = 'paged_table_${widget.storageKey}_columns';
      final keyOrder = 'paged_table_${widget.storageKey}_columns_order';
      final keyWidths = 'paged_table_${widget.storageKey}_column_widths';
      final keyPageSize = 'paged_table_${widget.storageKey}_page_size';

      final savedCols = prefs.getStringList(keyCols);
      final savedOrder = prefs.getStringList(keyOrder);
      final savedWidthsJson = prefs.getString(keyWidths);
      final savedSize = prefs.getInt(keyPageSize);

      if (mounted) {
        setState(() {
          if (savedCols != null && savedCols.isNotEmpty) {
            _visibleColumnIds = savedCols.toSet();
            // Locked columns stay visible
            for (final col in widget.columns) {
              if (!col.hideable) _visibleColumnIds.add(col.id);
            }
          }
          if (savedOrder != null && savedOrder.isNotEmpty) {
            final valid = savedOrder.where((id) => widget.columns.any((c) => c.id == id)).toList();
            final missing = widget.columns.where((c) => !valid.contains(c.id)).map((c) => c.id);
            _columnOrder = [...valid, ...missing];
          }
          if (savedWidthsJson != null) {
            try {
              final decoded = jsonDecode(savedWidthsJson) as Map<String, dynamic>;
              for (final entry in decoded.entries) {
                _columnWidths[entry.key] = (entry.value as num).toDouble();
              }
            } catch (_) {}
          }
          if (savedSize != null && savedSize != widget.state.query.pageSize) {
            widget.onQueryChanged(widget.state.query.copyWith(pageSize: savedSize, page: 1));
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    if (widget.storageKey == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyCols = 'paged_table_${widget.storageKey}_columns';
      final keyOrder = 'paged_table_${widget.storageKey}_columns_order';
      final keyWidths = 'paged_table_${widget.storageKey}_column_widths';
      final keyPageSize = 'paged_table_${widget.storageKey}_page_size';

      await prefs.setStringList(keyCols, _visibleColumnIds.toList());
      await prefs.setStringList(keyOrder, _columnOrder);
      await prefs.setString(keyWidths, jsonEncode(_columnWidths));
      await prefs.setInt(keyPageSize, widget.state.query.pageSize);
    } catch (_) {}
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      widget.onQueryChanged(widget.state.query.copyWith(search: query, page: 1));
    });
  }

  void _toggleSort(PagedTableColumn<T> col) {
    if (col.sortKey == null) return;
    final currentSort = widget.state.query.sort;
    final ascKey = col.sortKey!;
    final descKey = '-$ascKey';

    String? newSort;
    if (currentSort == ascKey) {
      newSort = descKey;
    } else if (currentSort == descKey) {
      newSort = null;
    } else {
      newSort = ascKey;
    }

    widget.onQueryChanged(widget.state.query.copyWith(
      sort: newSort,
      clearSort: newSort == null,
      page: 1,
    ));
  }

  void _handleColumnResize(PagedTableColumn<T> col, double delta, BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final effectiveDelta = isRtl ? -delta : delta;

    setState(() {
      final currentWidth = _columnWidths[col.id] ?? col.width;
      final newWidth = max(col.minWidth, currentWidth + effectiveDelta);
      _columnWidths[col.id] = newWidth;
    });
    _savePreferences();
  }

  Object _getRowKey(T row, int index) {
    if (widget.rowKey != null) {
      return widget.rowKey!(row);
    }
    return index;
  }

  void _toggleRowSelection(Object key) {
    setState(() {
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
      } else {
        _selectedKeys.add(key);
      }
    });
    widget.onSelectionChanged?.call(_selectedKeys);
  }

  void _toggleSelectAll(List<T> items) {
    setState(() {
      final allKeys = items.asMap().entries.map((e) => _getRowKey(e.value, e.key)).toSet();
      if (_selectedKeys.containsAll(allKeys)) {
        _selectedKeys.removeAll(allKeys);
      } else {
        _selectedKeys.addAll(allKeys);
      }
    });
    widget.onSelectionChanged?.call(_selectedKeys);
  }

  void _copyRowAsTsv(T row, List<PagedTableColumn<T>> activeColumns, AppLocalizations l) {
    final values = activeColumns.map((col) {
      if (col.exportValue != null) {
        return col.exportValue!(row);
      }
      return '';
    }).toList();

    Clipboard.setData(ClipboardData(text: values.join('\t')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.tableRowCopied),
        backgroundColor: AppTheme.emerald,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _scrollToFocusedIndex(int index) {
    if (!_scrollVerticalController.hasClients) return;
    final density = ref.read(displayDensityProvider);
    final rowHeight = density.rowHeight;
    final targetOffset = index * rowHeight;
    final currentOffset = _scrollVerticalController.offset;
    final viewportHeight = _scrollVerticalController.position.viewportDimension;

    if (targetOffset < currentOffset) {
      _scrollVerticalController.jumpTo(max(0.0, targetOffset));
    } else if (targetOffset + rowHeight > currentOffset + viewportHeight) {
      final newOffset = targetOffset + rowHeight - viewportHeight;
      _scrollVerticalController.jumpTo(min(_scrollVerticalController.position.maxScrollExtent, newOffset));
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyF) {
      _searchFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    final items = widget.state.data?.items ?? [];
    if (items.isEmpty) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final newIndex = min(items.length - 1, _focusedIndex + 1);
      setState(() {
        _focusedIndex = newIndex;
      });
      _scrollToFocusedIndex(newIndex);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final newIndex = max(0, _focusedIndex - 1);
      setState(() {
        _focusedIndex = newIndex;
      });
      _scrollToFocusedIndex(newIndex);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_focusedIndex < 0 || _focusedIndex >= items.length) return KeyEventResult.ignored;
      final focusedRow = items[_focusedIndex];
      if (widget.onOpen != null) {
        widget.onOpen!(focusedRow);
      } else if (widget.rowActions != null) {
        final actions = widget.rowActions!(focusedRow);
        final viewAction = actions.where((a) => a.kind == RowActionKind.view).firstOrNull;
        if (viewAction != null) {
          RowActionsBar.executeAction(context, viewAction, focusedRow, ref: ref);
        }
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      if (widget.state.query.page > 1) {
        widget.onQueryChanged(widget.state.query.copyWith(page: widget.state.query.page - 1));
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      final totalPages = widget.state.data?.totalPages ?? 1;
      if (widget.state.query.page < totalPages) {
        widget.onQueryChanged(widget.state.query.copyWith(page: widget.state.query.page + 1));
      }
      return KeyEventResult.handled;
    } else if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyC) {
      if (_focusedIndex < 0 || _focusedIndex >= items.length) return KeyEventResult.ignored;
      final activeColumns = _getActiveColumns();
      final focusedRow = items[_focusedIndex];
      _copyRowAsTsv(focusedRow, activeColumns, context.l10n);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.delete) {
      if (_focusedIndex < 0 || _focusedIndex >= items.length) return KeyEventResult.ignored;
      final focusedRow = items[_focusedIndex];
      if (widget.rowActions != null) {
        final actions = widget.rowActions!(focusedRow);
        final delAction = actions.where((a) => a.kind == RowActionKind.delete).firstOrNull;
        if (delAction != null) {
          RowActionsBar.executeAction(context, delAction, focusedRow, ref: ref);
        }
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  List<PagedTableColumn<T>> _getActiveColumns() {
    final colMap = {for (final c in widget.columns) c.id: c};
    final active = <PagedTableColumn<T>>[];

    for (final id in _columnOrder) {
      if (colMap.containsKey(id) && _visibleColumnIds.contains(id)) {
        active.add(colMap[id]!);
      }
    }
    return active;
  }

  @override
  Widget build(BuildContext context) {
    final density = ref.watch(displayDensityProvider);
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);
    final isMobile = AppTheme.isMobile(context);

    // Filter active columns
    final activeColumns = _getActiveColumns();
    final pinnedColumns = activeColumns.where((c) => c.pinned).toList();
    final scrollColumns = activeColumns.where((c) => !c.pinned).toList();

    // Sum widths
    final pinnedWidth = pinnedColumns.fold<double>(
      0.0,
      (sum, col) => sum + (_columnWidths[col.id] ?? col.width),
    );
    final scrollWidth = scrollColumns.fold<double>(
      0.0,
      (sum, col) => sum + (_columnWidths[col.id] ?? col.width),
    );

    return Focus(
      focusNode: _tableFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.border,
          ),
          boxShadow: AppTheme.shadowSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Toolbar ───────────────────────────────────────────────────
            _buildToolbar(context, l, isDark, activeColumns),

            // ── Table Body or Alternate State ─────────────────────────────
            Expanded(
              child: _buildBodyContent(
                context: context,
                l: l,
                density: density,
                isDark: isDark,
                isMobile: isMobile,
                activeColumns: activeColumns,
                pinnedColumns: pinnedColumns,
                scrollColumns: scrollColumns,
                pinnedWidth: pinnedWidth,
                scrollWidth: scrollWidth,
              ),
            ),

            // ── Pagination Footer ─────────────────────────────────────────
            CompactTablePaginationFooter(
              currentPage: widget.state.query.page,
              totalPages: widget.state.data?.totalPages ?? 1,
              totalCount: widget.state.data?.total ?? 0,
              pageSize: widget.state.query.pageSize,
              availablePageSizes: widget.pageSizes,
              isMobile: isMobile,
              onPageChanged: (newPage) {
                widget.onQueryChanged(widget.state.query.copyWith(page: newPage));
              },
              onPageSizeChanged: (newSize) {
                widget.onQueryChanged(widget.state.query.copyWith(pageSize: newSize, page: 1));
                _savePreferences();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    AppLocalizations l,
    bool isDark,
    List<PagedTableColumn<T>> activeColumns,
  ) {
    final total = widget.state.data?.total ?? 0;
    final hasSelection = widget.selectable && _selectedKeys.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.border,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Toolbar leading (title / custom widget)
              if (widget.toolbarLeading != null) ...[
                widget.toolbarLeading!,
                const SizedBox(width: 12),
              ],

              // Bulk actions if any selected
              if (hasSelection && widget.bulkActions != null) ...[
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.cobaltLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l.tableSelectedCount(_selectedKeys.length),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.cobalt,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: widget.bulkActions!(_selectedKeys)),
                    ],
                  ),
                ),
              ] else ...[
                // Search field
                SizedBox(
                  width: 240,
                  height: 34,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: l.tableSearchHint,
                      prefixIcon: const Icon(Icons.search, size: 16),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: isDark ? AppTheme.darkBorder : AppTheme.border,
                        ),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),

                // Toolbar filters slot
                if (widget.toolbarFilters != null) ...[
                  const SizedBox(width: 8),
                  ...widget.toolbarFilters!,
                ],

                const Spacer(),

                // Total count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCardBackground : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.border,
                    ),
                  ),
                  child: Text(
                    l.tableTotalCount(total),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Export button
                if (widget.onExport != null || widget.exportStageName != null) ...[
                  _buildExportButton(context, l, isDark),
                  const SizedBox(width: 6),
                ],

                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: l.refresh,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    if (widget.onRefresh != null) {
                      widget.onRefresh!();
                    } else {
                      widget.onQueryChanged(widget.state.query);
                    }
                  },
                ),

                // Column picker button
                IconButton(
                  icon: const Icon(Icons.view_column_outlined, size: 18),
                  tooltip: l.tableCustomizeColumns,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    PagedTableColumnPickerDialog.show<T>(
                      context: context,
                      allColumns: widget.columns,
                      visibleColumnIds: _visibleColumnIds,
                      currentColumnOrder: _columnOrder,
                      onConfigurationChanged: (visible, order) {
                        setState(() {
                          _visibleColumnIds = visible;
                          _columnOrder = order;
                        });
                        _savePreferences();
                      },
                      onResetToDefaults: () {
                        setState(() {
                          _visibleColumnIds = widget.columns.map((c) => c.id).toSet();
                          _columnOrder = widget.columns.map((c) => c.id).toList();
                          _columnWidths = {for (final c in widget.columns) c.id: c.width};
                        });
                        _savePreferences();
                      },
                    );
                  },
                ),
              ],
            ],
          ),
          if (widget.state.query.filters.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...widget.state.query.filters.entries.map((entry) {
                  return Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${entry.key}: ${entry.value}', style: const TextStyle(fontSize: 11)),
                    onDeleted: () {
                      final newFilters = Map<String, dynamic>.from(widget.state.query.filters)..remove(entry.key);
                      widget.onQueryChanged(widget.state.query.copyWith(filters: newFilters, page: 1));
                    },
                  );
                }),
                TextButton(
                  onPressed: () {
                    widget.onQueryChanged(widget.state.query.copyWith(filters: {}, page: 1));
                  },
                  child: Text(l.tableClearFilters, style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExportButton(
    BuildContext context,
    AppLocalizations l,
    bool isDark,
  ) {
    return PopupMenuButton<String>(
      key: const Key('paged_data_table_export_button'),
      tooltip: l.tableExportCsv,
      icon: _isExporting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.file_download_outlined, size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onSelected: (value) => _handleExport(value),
      itemBuilder: (context) => [
        PopupMenuItem(
          key: const Key('paged_data_table_export_csv_item'),
          value: 'csv',
          child: Row(
            children: [
              const Icon(Icons.description_outlined, size: 16),
              const SizedBox(width: 8),
              Text(l.tableExportCsv),
            ],
          ),
        ),
        PopupMenuItem(
          key: const Key('paged_data_table_export_excel_item'),
          value: 'excel',
          child: Row(
            children: [
              const Icon(Icons.table_view_outlined, size: 16),
              const SizedBox(width: 8),
              Text(l.tableExportExcel),
            ],
          ),
        ),
      ],
    );
  }

  bool _isExporting = false;

  Future<List<T>> _fetchAllRowsForExport() async {
    if (widget.source == null) {
      return widget.state.data?.items ?? [];
    }

    final all = <T>[];
    int page = 1;
    const pageSize = 200;
    const maxRows = 10000;
    bool cancelled = false;

    final totalCount = widget.state.data?.total ?? 0;
    BuildContext? dialogContext;

    if (totalCount > pageSize && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogContext = ctx;
          return StatefulBuilder(
            builder: (ctx, setDState) {
              return AlertDialog(
                title: Text(context.l10n.loading),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    Text('${all.length} / ${min(totalCount, maxRows)}'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      cancelled = true;
                      Navigator.of(ctx).pop();
                    },
                    child: Text(context.l10n.cancel),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    try {
      while (all.length < maxRows && !cancelled) {
        final query = widget.state.query.copyWith(page: page, pageSize: pageSize);
        final res = await widget.source!.fetchPage(query);
        if (cancelled) break;
        all.addAll(res.items);
        if (res.items.length < pageSize || all.length >= res.total || page >= res.totalPages) {
          break;
        }
        page++;
      }
    } finally {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }
    }

    if (all.length > maxRows) {
      return all.sublist(0, maxRows);
    }
    return all;
  }

  Future<void> _handleExport(String format) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final rows = await _fetchAllRowsForExport();
      if (widget.onExport != null) {
        await widget.onExport!(rows);
      } else {
        await _exportCsvDefault(rows);
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportCsvDefault(List<T> items) async {
    final activeColumns = _getActiveColumns();
    final headerRow = activeColumns.map((c) => '"${c.label(context.l10n).replaceAll('"', '""')}"').join(',');
    final rows = <String>[headerRow];
    for (final item in items) {
      final line = activeColumns.map((c) {
        final val = c.exportValue != null ? c.exportValue!(item) : '';
        return '"${val.replaceAll('"', '""')}"';
      }).join(',');
      rows.add(line);
    }
    final csvContent = '\uFEFF${rows.join('\r\n')}';
    final bytes = utf8.encode(csvContent);
    await FileSaveHelper.exportAndSaveFile(
      context: context,
      bytes: bytes,
      stageName: widget.exportStageName ?? 'Export',
      importFileNameOrCode: widget.state.query.search.isNotEmpty ? widget.state.query.search : 'data',
      extension: 'csv',
    );
  }

  Widget _buildBodyContent({
    required BuildContext context,
    required AppLocalizations l,
    required DisplayDensityMode density,
    required bool isDark,
    required bool isMobile,
    required List<PagedTableColumn<T>> activeColumns,
    required List<PagedTableColumn<T>> pinnedColumns,
    required List<PagedTableColumn<T>> scrollColumns,
    required double pinnedWidth,
    required double scrollWidth,
  }) {
    // 1. Initial Loading State -> Shimmer skeleton
    if (widget.state.isLoading && widget.state.data == null) {
      return EnterpriseTableShimmerSkeleton(
        rowCount: 8,
        columnCount: activeColumns.isNotEmpty ? activeColumns.length : 5,
      );
    }

    // 2. Error State without data -> Error banner with Retry
    if (widget.state.error != null && widget.state.data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.crimson),
              const SizedBox(height: 12),
              Text(
                widget.state.error is String
                    ? widget.state.error as String
                    : (ApiError.message(widget.state.error).isNotEmpty
                        ? ApiError.message(widget.state.error)
                        : l.genericErrorMessage),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppTheme.crimson, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(l.tableRetry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (widget.onRefresh != null) {
                    widget.onRefresh!();
                  } else {
                    widget.onQueryChanged(widget.state.query);
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    final items = widget.state.data?.items ?? [];

    // 3. Empty State
    if (items.isEmpty) {
      final isFiltered = widget.state.query.search.isNotEmpty || widget.state.query.filters.isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFiltered ? Icons.filter_alt_off_outlined : Icons.inbox_outlined,
                size: 48,
                color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                isFiltered ? l.tableNoResults : (widget.emptyMessage ?? l.tableNoData),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textCaption,
                ),
              ),
              if (isFiltered) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: Text(l.tableClearFilters),
                  onPressed: () {
                    _searchController.clear();
                    widget.onQueryChanged(
                      widget.state.query.copyWith(search: '', filters: {}, page: 1),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }

    // 4. Mobile Cards Layout (< 768px)
    if (isMobile) {
      return Column(
        children: [
          if (widget.state.error != null && widget.state.data != null)
            _buildInlineErrorBanner(context, l, isDark),
          Expanded(
            child: _buildMobileCardList(context, items, activeColumns, density, isDark),
          ),
        ],
      );
    }

    // 5. Desktop Virtualized Table Layout
    return Column(
      children: [
        if (widget.state.error != null && widget.state.data != null)
          _buildInlineErrorBanner(context, l, isDark),

        // Header
        _buildTableHeader(
          context: context,
          density: density,
          isDark: isDark,
          pinnedColumns: pinnedColumns,
          scrollColumns: scrollColumns,
          pinnedWidth: pinnedWidth,
          scrollWidth: scrollWidth,
          items: items,
        ),

        // Subsequent loading indicator (keeps old rows visible without flickering)
        if (widget.state.isLoading)
          const SizedBox(
            height: 2,
            child: LinearProgressIndicator(
              color: AppTheme.cobalt,
              backgroundColor: Colors.transparent,
            ),
          )
        else
          const SizedBox(height: 2),

        // Virtualized rows
        Expanded(
          child: _buildTableRows(
            context: context,
            density: density,
            isDark: isDark,
            pinnedColumns: pinnedColumns,
            scrollColumns: scrollColumns,
            pinnedWidth: pinnedWidth,
            scrollWidth: scrollWidth,
            items: items,
          ),
        ),
      ],
    );
  }

  Widget _buildInlineErrorBanner(
    BuildContext context,
    AppLocalizations l,
    bool isDark,
  ) {
    final errorMsg = widget.state.error is String
        ? widget.state.error as String
        : (ApiError.message(widget.state.error).isNotEmpty
            ? ApiError.message(widget.state.error)
            : l.genericErrorMessage);

    return Container(
      key: const Key('paged_data_table_inline_error_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.crimson.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.crimson.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppTheme.crimson),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMsg,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.crimson,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            key: const Key('paged_data_table_inline_retry_button'),
            icon: const Icon(Icons.refresh, size: 14),
            label: Text(l.tableRetry),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.crimson,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              if (widget.onRefresh != null) {
                widget.onRefresh!();
              } else {
                widget.onQueryChanged(widget.state.query);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader({
    required BuildContext context,
    required DisplayDensityMode density,
    required bool isDark,
    required List<PagedTableColumn<T>> pinnedColumns,
    required List<PagedTableColumn<T>> scrollColumns,
    required double pinnedWidth,
    required double scrollWidth,
    required List<T> items,
  }) {
    final bgColor = isDark ? AppTheme.darkSurface : AppTheme.charcoal.withValues(alpha: 0.06);

    return Container(
      height: density.headerHeight,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.border,
          ),
        ),
      ),
      child: Row(
        children: [
          // Pinned header pane
          if (pinnedColumns.isNotEmpty || widget.selectable || widget.rowActions != null)
            SizedBox(
              width: pinnedWidth + (widget.selectable ? 44.0 : 0.0) + (widget.rowActions != null ? 120.0 : 0.0),
              child: Row(
                children: [
                  // Select all checkbox
                  if (widget.selectable)
                    SizedBox(
                      width: 44,
                      child: Checkbox(
                        value: items.isNotEmpty &&
                            items.asMap().entries.every((e) => _selectedKeys.contains(_getRowKey(e.value, e.key))),
                        onChanged: (_) => _toggleSelectAll(items),
                      ),
                    ),
                  // Pinned columns
                  ...pinnedColumns.map((col) => _buildHeaderCell(context, col, isDark)),
                  // Row actions header
                  if (widget.rowActions != null)
                    SizedBox(
                      width: 120,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          context.l10n.tableActions,
                          style: TextStyle(
                            fontSize: density.tableHeaderFontSize,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Horizontally scrolling header pane
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _headerHorizontalController,
              child: SizedBox(
                width: scrollWidth,
                child: Row(
                  children: scrollColumns.map((col) => _buildHeaderCell(context, col, isDark)).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(BuildContext context, PagedTableColumn<T> col, bool isDark) {
    final l = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final width = _columnWidths[col.id] ?? col.width;
    final isSortable = col.sortKey != null;
    final isSortedAsc = widget.state.query.sort == col.sortKey;
    final isSortedDesc = widget.state.query.sort == '-${col.sortKey}';

    return SizedBox(
      width: width,
      height: density.headerHeight,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: isSortable ? () => _toggleSort(col) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: col.numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        col.label(l),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: density.tableHeaderFontSize,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                    ),
                    if (isSortable) ...[
                      const SizedBox(width: 4),
                      if (isSortedAsc)
                        Icon(Icons.arrow_upward, size: 14, color: AppTheme.primaryOf(context))
                      else if (isSortedDesc)
                        Icon(Icons.arrow_downward, size: 14, color: AppTheme.primaryOf(context))
                      else
                        const Icon(Icons.unfold_more, size: 14, color: AppTheme.textMuted),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Resize handle
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) => _handleColumnResize(col, details.primaryDelta ?? 0, context),
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: Container(
                width: 8,
                height: double.infinity,
                alignment: Alignment.center,
                child: Container(
                  width: 1,
                  height: 16,
                  color: isDark ? AppTheme.darkBorder : AppTheme.borderStrong,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRows({
    required BuildContext context,
    required DisplayDensityMode density,
    required bool isDark,
    required List<PagedTableColumn<T>> pinnedColumns,
    required List<PagedTableColumn<T>> scrollColumns,
    required double pinnedWidth,
    required double scrollWidth,
    required List<T> items,
  }) {
    final pinnedExtraWidth = (widget.selectable ? 44.0 : 0.0) + (widget.rowActions != null ? 120.0 : 0.0);
    final totalPinnedWidth = pinnedWidth + pinnedExtraWidth;

    return Row(
      children: [
        // Pinned pane ListView.builder (virtualized)
        if (totalPinnedWidth > 0)
          SizedBox(
            key: const Key('paged_data_table_pinned_pane'),
            width: totalPinnedWidth,
            child: ListView.builder(
              itemExtent: density.rowHeight,
              controller: _pinnedVerticalController,
              itemCount: items.length,
              itemBuilder: (ctx, index) {
                final row = items[index];
                final key = _getRowKey(row, index);
                final isSelected = _selectedKeys.contains(key);
                final isFocused = _focusedIndex == index;
                final isEven = index.isEven;

                final rowBg = isFocused
                    ? AppTheme.cobaltLight
                    : isSelected
                        ? AppTheme.cobalt.withValues(alpha: 0.08)
                        : (isEven
                            ? (isDark ? AppTheme.darkSurface : AppTheme.surface)
                            : (isDark ? AppTheme.darkCardBackground : AppTheme.surfaceAlt));

                return Container(
                  height: density.rowHeight,
                  decoration: BoxDecoration(
                    color: rowBg,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppTheme.darkBorder : AppTheme.border,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            _tableFocusNode.requestFocus();
                            setState(() => _focusedIndex = index);
                            if (widget.selectable) _toggleRowSelection(key);
                          },
                          onDoubleTap: () => widget.onOpen?.call(row),
                          child: Row(
                            children: [
                              if (widget.selectable)
                                SizedBox(
                                  width: 44,
                                  child: Checkbox(
                                    value: isSelected,
                                    onChanged: (_) => _toggleRowSelection(key),
                                  ),
                                ),
                              ...pinnedColumns.map((col) => _buildCellWidget(context, col, row, density)),
                            ],
                          ),
                        ),
                      ),
                      if (widget.rowActions != null)
                        SizedBox(
                          width: 120,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: RowActionsBar<T>(
                              row: row,
                              actions: widget.rowActions!(row),
                              iconSize: 14,
                              showAsPill: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

        // Scrolling pane ListView.builder (virtualized)
        Expanded(
          key: const Key('paged_data_table_scrolling_pane'),
          child: Scrollbar(
            controller: _bodyHorizontalController,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _bodyHorizontalController,
              child: SizedBox(
                width: scrollWidth,
                child: Scrollbar(
                  controller: _scrollVerticalController,
                  child: ListView.builder(
                    itemExtent: density.rowHeight,
                    controller: _scrollVerticalController,
                    itemCount: items.length,
                    itemBuilder: (ctx, index) {
                      final row = items[index];
                      final key = _getRowKey(row, index);
                      final isSelected = _selectedKeys.contains(key);
                      final isFocused = _focusedIndex == index;
                      final isEven = index.isEven;

                      final rowBg = isFocused
                          ? AppTheme.cobaltLight
                          : isSelected
                              ? AppTheme.cobalt.withValues(alpha: 0.08)
                              : (isEven
                                  ? (isDark ? AppTheme.darkSurface : AppTheme.surface)
                                  : (isDark ? AppTheme.darkCardBackground : AppTheme.surfaceAlt));

                      return InkWell(
                        onTap: () {
                          _tableFocusNode.requestFocus();
                          setState(() => _focusedIndex = index);
                          if (widget.selectable) _toggleRowSelection(key);
                        },
                        onDoubleTap: () => widget.onOpen?.call(row),
                        child: Container(
                          height: density.rowHeight,
                          decoration: BoxDecoration(
                            color: rowBg,
                            border: Border(
                              bottom: BorderSide(
                                color: isDark ? AppTheme.darkBorder : AppTheme.border,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: scrollColumns
                                .map((col) => _buildCellWidget(context, col, row, density))
                                .toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCellWidget(
    BuildContext context,
    PagedTableColumn<T> col,
    T row,
    DisplayDensityMode density,
  ) {
    final width = _columnWidths[col.id] ?? col.width;

    Widget cellChild = col.cell(context, row);

    // LTR island for numeric, codes, dates
    if (col.numeric) {
      cellChild = Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: cellChild,
        ),
      );
    }

    return SizedBox(
      width: width,
      height: density.rowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: col.numeric ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          child: cellChild,
        ),
      ),
    );
  }

  Widget _buildMobileCardList(
    BuildContext context,
    List<T> items,
    List<PagedTableColumn<T>> activeColumns,
    DisplayDensityMode density,
    bool isDark,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final row = items[index];
        final key = _getRowKey(row, index);
        final isSelected = _selectedKeys.contains(key);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: isDark ? AppTheme.darkCardBackground : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? AppTheme.cobalt : (isDark ? AppTheme.darkBorder : AppTheme.border),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...activeColumns.take(4).map((col) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          col.label(context.l10n),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textCaption,
                          ),
                        ),
                        Flexible(child: col.cell(context, row)),
                      ],
                    ),
                  );
                }),
                if (widget.rowActions != null) ...[
                  const Divider(height: 16),
                  RowActionsBar<T>(
                    row: row,
                    actions: widget.rowActions!(row),
                    iconSize: 16,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
