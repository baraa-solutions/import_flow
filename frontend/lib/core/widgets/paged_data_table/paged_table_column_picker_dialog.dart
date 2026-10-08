import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../theme/app_theme.dart';
import 'paged_table_column.dart';

/// Modal dialog allowing users to customize column visibility and ordering for [PagedDataTable].
class PagedTableColumnPickerDialog<T> extends StatefulWidget {
  final List<PagedTableColumn<T>> allColumns;
  final Set<String> visibleColumnIds;
  final List<String>? currentColumnOrder;
  final void Function(Set<String> visibleIds, List<String> orderedIds) onConfigurationChanged;
  final VoidCallback onResetToDefaults;

  const PagedTableColumnPickerDialog({
    super.key,
    required this.allColumns,
    required this.visibleColumnIds,
    this.currentColumnOrder,
    required this.onConfigurationChanged,
    required this.onResetToDefaults,
  });

  static Future<void> show<T>({
    required BuildContext context,
    required List<PagedTableColumn<T>> allColumns,
    required Set<String> visibleColumnIds,
    List<String>? currentColumnOrder,
    required void Function(Set<String> visibleIds, List<String> orderedIds) onConfigurationChanged,
    required VoidCallback onResetToDefaults,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => PagedTableColumnPickerDialog<T>(
        allColumns: allColumns,
        visibleColumnIds: visibleColumnIds,
        currentColumnOrder: currentColumnOrder,
        onConfigurationChanged: onConfigurationChanged,
        onResetToDefaults: onResetToDefaults,
      ),
    );
  }

  @override
  State<PagedTableColumnPickerDialog<T>> createState() =>
      _PagedTableColumnPickerDialogState<T>();
}

class _PagedTableColumnPickerDialogState<T>
    extends State<PagedTableColumnPickerDialog<T>> {
  late Set<String> _selectedIds;
  late List<PagedTableColumn<T>> _orderedColumns;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.visibleColumnIds);

    final initialOrder = widget.currentColumnOrder ?? widget.allColumns.map((c) => c.id).toList();
    final colMap = {for (final c in widget.allColumns) c.id: c};
    _orderedColumns = [];
    for (final id in initialOrder) {
      if (colMap.containsKey(id)) {
        _orderedColumns.add(colMap[id]!);
      }
    }
    for (final c in widget.allColumns) {
      if (!_orderedColumns.any((col) => col.id == c.id)) {
        _orderedColumns.add(c);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);

    final filteredColumns = _orderedColumns.where((col) {
      if (_filter.isEmpty) return true;
      final title = col.label(l).toLowerCase();
      return title.contains(_filter.toLowerCase());
    }).toList();

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkCardBackground : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.view_column_outlined, color: AppTheme.primaryOf(context), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.tableCustomizeColumns,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.restore, size: 16),
                    label: Text(l.resetToDefaults, style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      widget.onResetToDefaults();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Filter field
              TextField(
                decoration: InputDecoration(
                  hintText: l.tableSearchHint,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.border),
                  ),
                ),
                onChanged: (val) => setState(() => _filter = val),
              ),
              const SizedBox(height: 12),

              // Columns list
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: _filter.isEmpty,
                  itemCount: filteredColumns.length,
                  onReorderItem: (oldIndex, newIndex) {
                    if (_filter.isNotEmpty) return;
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _orderedColumns.removeAt(oldIndex);
                      _orderedColumns.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (ctx, index) {
                    final col = filteredColumns[index];
                    final isChecked = _selectedIds.contains(col.id);
                    final isLocked = !col.hideable;

                    return ListTile(
                      key: ValueKey(col.id),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Checkbox(
                        value: isChecked || isLocked,
                        onChanged: isLocked
                            ? null
                            : (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedIds.add(col.id);
                                  } else {
                                    // Ensure at least one column remains visible
                                    if (_selectedIds.length > 1) {
                                      _selectedIds.remove(col.id);
                                    }
                                  }
                                });
                              },
                      ),
                      title: Text(
                        col.label(l),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (col.pinned)
                            const Tooltip(
                              message: 'Pinned',
                              child: Icon(Icons.push_pin, size: 14, color: AppTheme.cobalt),
                            ),
                          if (isLocked)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.lock, size: 14, color: AppTheme.textMuted),
                            ),
                          if (_filter.isEmpty)
                            const Icon(Icons.drag_handle, size: 18, color: AppTheme.textMuted),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l.cancel),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      widget.onConfigurationChanged(
                        _selectedIds,
                        _orderedColumns.map((c) => c.id).toList(),
                      );
                      Navigator.of(context).pop();
                    },
                    child: Text(l.apply),
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
