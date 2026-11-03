import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/cbm_calculator_model.dart';
import 'items_table/cbm_table_header_row.dart';
import 'items_table/cbm_table_item_row.dart';
import 'items_table/cbm_table_toolbar.dart';

class CbmItemsTable extends StatelessWidget {
  final List<CBMItemModel> items;
  final String shipmentMode;
  final int? activeSessionId;
  final ValueChanged<String> onShipmentModeChanged;
  final VoidCallback onAddPackageLine;
  final VoidCallback onSaveCalculation;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final VoidCallback onCopyPackagesTsv;
  final VoidCallback onCopyStudyReport;
  final void Function(int index, CBMItemModel updatedItem) onItemUpdated;
  final void Function(int index) onCloneItem;
  final void Function(int index) onDeleteItem;

  const CbmItemsTable({
    super.key,
    required this.items,
    required this.shipmentMode,
    required this.activeSessionId,
    required this.onShipmentModeChanged,
    required this.onAddPackageLine,
    required this.onSaveCalculation,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.onCopyPackagesTsv,
    required this.onCopyStudyReport,
    required this.onItemUpdated,
    required this.onCloneItem,
    required this.onDeleteItem,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Items Table Header & Action Card
        CbmTableToolbar(
          shipmentMode: shipmentMode,
          activeSessionId: activeSessionId,
          onShipmentModeChanged: onShipmentModeChanged,
          onAddPackageLine: onAddPackageLine,
          onSaveCalculation: onSaveCalculation,
          onExportExcel: onExportExcel,
          onExportPdf: onExportPdf,
          onCopyPackagesTsv: onCopyPackagesTsv,
          onCopyStudyReport: onCopyStudyReport,
        ),
        const SizedBox(height: 8),

        // Dynamic Line Items List Table
        Card(
          elevation: 1,
          color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: shipmentMode == 'air' ? 1380 : 1260,
              ),
              child: SizedBox(
                width: math.max(
                  shipmentMode == 'air' ? 1380.0 : 1260.0,
                  MediaQuery.of(context).size.width - 64,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Table Header Bar
                    CbmTableHeaderRow(shipmentMode: shipmentMode),
                    const Divider(height: 1),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (ctx, idx) {
                        final item = items[idx];
                        return CbmTableItemRow(
                          index: idx,
                          activeSessionId: activeSessionId,
                          item: item,
                          shipmentMode: shipmentMode,
                          totalItemsCount: items.length,
                          onItemUpdated: (updated) => onItemUpdated(idx, updated),
                          onClone: () => onCloneItem(idx),
                          onDelete: () => onDeleteItem(idx),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
