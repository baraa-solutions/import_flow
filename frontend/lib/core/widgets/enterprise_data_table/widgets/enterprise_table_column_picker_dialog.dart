import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../models/enterprise_column.dart';

/// Interactive modal dialog allowing users to customize column visibility and ordering for [EnterpriseDataTable].
class EnterpriseTableColumnPickerDialog<T> extends StatefulWidget {
  final List<EnterpriseColumn<T>> allColumns;
  final Set<String> visibleColumnIds;
  final List<String>? currentColumnOrder;
  final ValueChanged<Set<String>> onColumnsChanged;
  final void Function(Set<String> visibleIds, List<String> orderedIds)? onConfigurationChanged;
  final VoidCallback onResetToDefaults;

  const EnterpriseTableColumnPickerDialog({
    super.key,
    required this.allColumns,
    required this.visibleColumnIds,
    this.currentColumnOrder,
    required this.onColumnsChanged,
    this.onConfigurationChanged,
    required this.onResetToDefaults,
  });

  static Future<void> show<T>({
    required BuildContext context,
    required List<EnterpriseColumn<T>> allColumns,
    required Set<String> visibleColumnIds,
    List<String>? currentColumnOrder,
    required ValueChanged<Set<String>> onColumnsChanged,
    void Function(Set<String> visibleIds, List<String> orderedIds)? onConfigurationChanged,
    required VoidCallback onResetToDefaults,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => EnterpriseTableColumnPickerDialog<T>(
        allColumns: allColumns,
        visibleColumnIds: visibleColumnIds,
        currentColumnOrder: currentColumnOrder,
        onColumnsChanged: onColumnsChanged,
        onConfigurationChanged: onConfigurationChanged,
        onResetToDefaults: onResetToDefaults,
      ),
    );
  }

  @override
  State<EnterpriseTableColumnPickerDialog<T>> createState() =>
      _EnterpriseTableColumnPickerDialogState<T>();
}

class _EnterpriseTableColumnPickerDialogState<T>
    extends State<EnterpriseTableColumnPickerDialog<T>> {
  late Set<String> _selectedIds;
  late List<EnterpriseColumn<T>> _orderedColumns;
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
      if (!_orderedColumns.any((oc) => oc.id == c.id)) {
        _orderedColumns.add(c);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final filteredColumns = _orderedColumns.where((col) {
      if (_filter.isEmpty) return true;
      return col.title.toLowerCase().contains(_filter.toLowerCase()) ||
          col.id.toLowerCase().contains(_filter.toLowerCase());
    }).toList();

    return SelectionArea(
      child: AlertDialog(
        title: Row(
        children: [
          const Icon(Icons.view_column_rounded, color: AppTheme.cobalt),
          const SizedBox(width: 8),
          const Text('تخصيص وترتيب أعمدة الجدول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(
            '${_selectedIds.length} من ${widget.allColumns.length} عمود معروض',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 480,
        child: Column(
          children: [
            // Search field
            TextField(
              decoration: InputDecoration(
                hintText: 'بحث في الأعمدة...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (val) => setState(() => _filter = val.trim()),
            ),
            const SizedBox(height: 10),

            // Hint banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppTheme.cobalt),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'يمكنك تفعيل وإخفاء الأعمدة، أو سحبها بالضغط المطول لإعادة ترتيب ظهورها في الجدول',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Quick Selection buttons
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.select_all, size: 16),
                  label: const Text('تحديد الكل', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    setState(() {
                      _selectedIds = widget.allColumns.map((c) => c.id).toSet();
                    });
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.deselect, size: 16),
                  label: const Text('إلغاء غير المقفل', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    setState(() {
                      _selectedIds = widget.allColumns
                          .where((c) => c.isLocked)
                          .map((c) => c.id)
                          .toSet();
                    });
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16, color: AppTheme.orange),
                  label: const Text('إعادة ضبط افتراضي', style: TextStyle(fontSize: 12, color: AppTheme.orange)),
                  onPressed: () {
                    widget.onResetToDefaults();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 6),

            // Columns list (Reorderable if not filtered)
            Expanded(
              child: _filter.isNotEmpty
                  ? ListView.builder(
                      itemCount: filteredColumns.length,
                      itemBuilder: (context, index) => _buildColumnTile(filteredColumns[index], index, isReorderable: false),
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: true,
                      itemCount: _orderedColumns.length,
                      // ignore: deprecated_member_use
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }
                          final item = _orderedColumns.removeAt(oldIndex);
                          _orderedColumns.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) => _buildColumnTile(
                        _orderedColumns[index],
                        index,
                        key: ValueKey('col_${_orderedColumns[index].id}'),
                        isReorderable: true,
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.cobalt,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            widget.onColumnsChanged(_selectedIds);
            widget.onConfigurationChanged?.call(
              _selectedIds,
              _orderedColumns.map((c) => c.id).toList(),
            );
            Navigator.pop(context);
          },
          child: const Text('تطبيق التعديلات'),
        ),
      ],
    ),
  );
}

  Widget _buildColumnTile(EnterpriseColumn<T> col, int index, {Key? key, required bool isReorderable}) {
    final isChecked = _selectedIds.contains(col.id);

    return ListTile(
      key: key,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      leading: Checkbox(
        value: isChecked,
        onChanged: col.isLocked
            ? null
            : (val) {
                setState(() {
                  if (val == true) {
                    _selectedIds.add(col.id);
                  } else {
                    if (_selectedIds.length > 1) {
                      _selectedIds.remove(col.id);
                    }
                  }
                });
              },
      ),
      title: Row(
        children: [
          Text(
            col.title,
            style: TextStyle(
              fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
              color: col.isLocked ? Colors.grey.shade600 : null,
            ),
          ),
          if (col.isLocked) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('مثبت', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ),
          ],
        ],
      ),
      subtitle: Text(
        'المعرف: ${col.id}',
        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
      ),
      trailing: isReorderable
          ? const Icon(Icons.drag_indicator_rounded, size: 18, color: Colors.grey)
          : null,
    );
  }
}
