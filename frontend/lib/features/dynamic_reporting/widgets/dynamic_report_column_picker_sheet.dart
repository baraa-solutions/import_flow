import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/dynamic_report_models.dart';

class DynamicReportColumnPickerSheet extends StatefulWidget {
  final List<DynamicReportColumn> masterColumns;
  final String Function(BuildContext context, String colId) getColumnLabel;
  final String Function(BuildContext context, String catId) getCategoryTitle;
  final VoidCallback onApply;
  final VoidCallback onStateChanged;

  const DynamicReportColumnPickerSheet({
    super.key,
    required this.masterColumns,
    required this.getColumnLabel,
    required this.getCategoryTitle,
    required this.onApply,
    required this.onStateChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required List<DynamicReportColumn> masterColumns,
    required String Function(BuildContext context, String colId) getColumnLabel,
    required String Function(BuildContext context, String catId) getCategoryTitle,
    required VoidCallback onApply,
    required VoidCallback onStateChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => DynamicReportColumnPickerSheet(
        masterColumns: masterColumns,
        getColumnLabel: getColumnLabel,
        getCategoryTitle: getCategoryTitle,
        onApply: onApply,
        onStateChanged: onStateChanged,
      ),
    );
  }

  @override
  State<DynamicReportColumnPickerSheet> createState() => _DynamicReportColumnPickerSheetState();
}

class _DynamicReportColumnPickerSheetState extends State<DynamicReportColumnPickerSheet> {
  String _filterText = '';

  static const List<String> _categories = [
    'file_project',
    'commercial_po',
    'shipping_logistics',
    'packages_cbm',
    'customs_nafeza',
    'banking_swift',
    'eco_radar',
    'scas_tracker',
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.view_column, color: AppTheme.cobalt, size: 26),
                const SizedBox(width: 10),
                Text(l.dynColumnPickerTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.dynColumnPickerSubtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: l.dynSearchColumnsPlaceholder,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() => _filterText = val.trim().toLowerCase());
                    },
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                  onPressed: () {
                    setState(() {
                      for (var col in widget.masterColumns) {
                        col.isVisible = true;
                      }
                    });
                    widget.onStateChanged();
                  },
                  icon: const Icon(Icons.select_all, size: 18),
                  label: Text(l.dynSelectAll),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                  onPressed: () {
                    setState(() {
                      for (var col in widget.masterColumns) {
                        col.isVisible = false;
                      }
                    });
                    widget.onStateChanged();
                  },
                  icon: const Icon(Icons.deselect, size: 18),
                  label: Text(l.dynDeselectAll),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, catIdx) {
                  final catId = _categories[catIdx];
                  final catCols = widget.masterColumns.where((col) {
                    if (col.categoryId != catId) return false;
                    if (_filterText.isEmpty) return true;
                    final label = widget.getColumnLabel(context, col.id).toLowerCase();
                    return label.contains(_filterText) || col.id.toLowerCase().contains(_filterText);
                  }).toList();

                  if (catCols.isEmpty) return const SizedBox.shrink();

                  final allChecked = catCols.every((c) => c.isVisible);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        title: Row(
                          children: [
                            Text(
                              widget.getCategoryTitle(context, catId),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${catCols.where((c) => c.isVisible).length}/${catCols.length}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(allChecked ? Icons.check_box : Icons.check_box_outline_blank, color: AppTheme.cobalt),
                          tooltip: allChecked ? l.dynDeselectAll : l.dynSelectAll,
                          onPressed: () {
                            setState(() {
                              final target = !allChecked;
                              for (var col in catCols) {
                                col.isVisible = target;
                              }
                            });
                            widget.onStateChanged();
                          },
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: catCols.map((col) {
                                return FilterChip(
                                  selected: col.isVisible,
                                  label: Text(widget.getColumnLabel(context, col.id), style: const TextStyle(fontSize: 12)),
                                  selectedColor: AppTheme.cobalt.withValues(alpha: 0.2),
                                  checkmarkColor: AppTheme.cobalt,
                                  onSelected: (val) {
                                    setState(() => col.isVisible = val);
                                    widget.onStateChanged();
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, minimumSize: const Size.fromHeight(48)),
              onPressed: () {
                widget.onApply();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.check, color: Colors.white),
              label: Text(l.dynApplyColumnsBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
