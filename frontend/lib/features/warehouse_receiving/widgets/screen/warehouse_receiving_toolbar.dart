import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../models/warehouse_receiving_model.dart';
import '../ops_ui_kit.dart';

/// Top toolbar for Warehouse Receiving Screen (actions, search, status filter, export)
class WarehouseReceivingToolbar extends StatelessWidget {
  final List<WarehouseReceivingModel> records;
  final TextEditingController searchController;
  final String selectedStatusFilter;
  final VoidCallback onAddRecord;
  final VoidCallback onSearchAndClone;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final VoidCallback onCopyTsv;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;

  const WarehouseReceivingToolbar({
    super.key,
    required this.records,
    required this.searchController,
    required this.selectedStatusFilter,
    required this.onAddRecord,
    required this.onSearchAndClone,
    required this.onSearchChanged,
    required this.onStatusFilterChanged,
    required this.onCopyTsv,
    required this.onExportExcel,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      padding: const EdgeInsetsDirectional.all(12),
      child: OpsActionWrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          AppButton(
            key: const Key('createGrnBtn'),
            label: l.warehouseReceivingNewGrnBtn,
            icon: Icons.local_shipping,
            size: AppButtonSize.small,
            onPressed: onAddRecord,
          ),
          AppButton(
            key: const Key('searchAndCloneGrnBtn'),
            label: l.searchAndCloneWarehouseReceivingBtn,
            icon: Icons.difference_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: onSearchAndClone,
          ),
          SizedBox(
            width: 220,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: l.warehouseReceivingSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: searchController,
                  builder: (context, value, _) {
                    return value.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                          )
                        : const SizedBox.shrink();
                  },
                ),
                isDense: true,
                contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 10),
                border: const OutlineInputBorder(),
              ),
              onChanged: onSearchChanged,
            ),
          ),
          SizedBox(
            width: 220,
            child: SearchableDropdownField<String>(
              value: selectedStatusFilter,
              items: [
                SearchableDropdownItem(value: 'All', label: l.warehouseReceivingStatusAll),
                SearchableDropdownItem(
                  value: 'Draft / Pending Warehouse Count',
                  label: l.warehouseReceivingStatusDraft,
                ),
                SearchableDropdownItem(
                  value: 'Goods Received',
                  label: l.warehouseReceivingStatusGoodsReceived,
                ),
                SearchableDropdownItem(
                  value: 'Discrepancy Reported',
                  label: l.warehouseReceivingStatusDiscrepancy,
                ),
              ],
              onChanged: (val) {
                if (val != null) onStatusFilterChanged(val);
              },
            ),
          ),
          AppButton(
            key: const Key('copyGrnTableTsvBtn'),
            label: l.warehouseReceivingExportTsvBtn,
            icon: Icons.table_chart_outlined,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.small,
            onPressed: onCopyTsv,
          ),
          IconButton(
            key: const Key('exportGrnExcelBtn'),
            icon: const Icon(Icons.description_outlined, color: AppTheme.emerald, size: 20),
            tooltip: l.exportWarehouseReceivingExcelTooltip,
            onPressed: onExportExcel,
          ),
          IconButton(
            key: const Key('exportGrnPdfBtn'),
            icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson, size: 20),
            tooltip: l.exportWarehouseReceivingPdfTooltip,
            onPressed: onExportPdf,
          ),
        ],
      ),
    );
  }
}
