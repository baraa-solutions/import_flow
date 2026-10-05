import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../providers/goods_in_transit_provider.dart';
import '../services/goods_in_transit_export_service.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../inland_transport/widgets/inland_transport_dialog.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
class GoodsInTransitScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const GoodsInTransitScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<GoodsInTransitScreen> createState() => _GoodsInTransitScreenState();
}

class _GoodsInTransitScreenState extends ConsumerState<GoodsInTransitScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedStatusFilter = 'In-Transit Only';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final gitAsync = ref.watch(goodsInTransitProvider);

    final tabs = [
      const VerticalNavTabItem(
        icon: Icons.local_shipping_outlined,
        titleEn: 'Goods In Transit (GIT) Ledger',
        titleAr: 'رصيد البضاعة بالطريق وتتبع الشحنات',
      ),
    ];

    final bodyContent = SelectionArea(
      child: gitAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(l.gitErrorFetchingData(err), style: const TextStyle(color: Colors.red)),
        ),
        data: (allItems) {
          final filteredItems = allItems.where((item) {
            if (_selectedStatusFilter == 'In-Transit Only' && item.isDeliveredToWarehouse) {
              return false;
            }
            if (_selectedStatusFilter == 'Delivered Only' && !item.isDeliveredToWarehouse) {
              return false;
            }
            if (_searchCtrl.text.trim().isEmpty) return true;
            final q = _searchCtrl.text.trim().toLowerCase();
            return item.importFileCode.toLowerCase().contains(q) ||
                item.poNumber.toLowerCase().contains(q) ||
                item.itemCode.toLowerCase().contains(q) ||
                item.itemName.toLowerCase().contains(q);
          }).toList();

          final activeItems = allItems.where((i) => !i.isDeliveredToWarehouse).toList();
          final uniqueFiles = activeItems.map((i) => i.importFileCode).toSet().length;
          final uniquePos = activeItems.map((i) => i.poNumber).toSet().length;
          final totalQty = activeItems.fold<double>(0.0, (s, i) => s + i.invoicedQty);
          final totalPkgs = activeItems.fold<int>(0, (s, i) => s + i.packagesCount);
          final totalContainers = activeItems.fold<int>(0, (s, i) => s + i.containersCount);

          return SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 950;
                    final actionButtons = Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: isNarrow ? WrapAlignment.start : WrapAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.charcoal,
                            side: BorderSide(color: Colors.teal.shade300),
                          ),
                          icon: const Icon(Icons.copy_all_outlined, size: 16),
                          label: Text(l.gitCopyDossierBtn),
                          onPressed: () => GoodsInTransitExportService.copyDossierToClipboard(context, filteredItems),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.charcoal,
                            side: BorderSide(color: Colors.teal.shade300),
                          ),
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                          label: Text(l.gitPrintPdfBtn),
                          onPressed: () => GoodsInTransitExportService.printOrSaveGitPdf(context, filteredItems),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.charcoal,
                            side: BorderSide(color: Colors.teal.shade300),
                          ),
                          icon: const Icon(Icons.file_copy_outlined, size: 16),
                          label: Text(l.gitExportTsvBtn),
                          onPressed: () => GoodsInTransitExportService.saveGitTsvToFile(context, filteredItems),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                          icon: const Icon(Icons.file_download_outlined, size: 16),
                          label: Text(l.gitExportExcelBtn),
                          onPressed: () => GoodsInTransitExportService.saveGitCsvToFile(context, filteredItems),
                        ),
                        ElevatedButton.icon(
                          key: const Key('inlandTransportScreenBtn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.local_shipping_rounded, size: 16),
                          label: const Text('حجز وتنسيق النقل (TR-01)'),
                          onPressed: () {
                            final files = ref.read(importFilesProvider).valueOrNull ?? [];
                            if (files.isNotEmpty) {
                              final target = files.firstWhere(
                                (f) => f.inlandTransportStatus != 'Arrived Warehouse' && f.isActive,
                                orElse: () => files.first,
                              );
                              InlandTransportDialog.show(context, target);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('لا توجد ملفات استيراد متاحة لحجز النقل'),
                                  backgroundColor: AppTheme.flatOrange,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    );

                    if (isNarrow) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.inventory_2, color: Colors.teal, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l.gitInfoBannerTitle,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l.gitInfoBannerSubtitle,
                                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            actionButtons,
                          ],
                        ),
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2, color: Colors.teal, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.gitInfoBannerTitle,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l.gitInfoBannerSubtitle,
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: actionButtons,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // KPI Metrics Bar
                Row(
                  children: [
                    Expanded(child: _buildMetricCard(l.gitKpiInTransitShipments, l.gitKpiShipmentsValue(uniqueFiles), Icons.folder_open, Colors.blue)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildMetricCard(l.gitKpiPurchaseOrders, l.gitKpiPurchaseOrdersValue(uniquePos), Icons.receipt_long, Colors.purple)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildMetricCard(l.gitKpiInvoicedQuantity, l.gitKpiQuantityValue(totalQty.toStringAsFixed(0)), Icons.category, Colors.indigo)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildMetricCard(l.gitKpiPackagesCount, l.gitKpiPackagesValue(totalPkgs), Icons.all_inbox, Colors.teal)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildMetricCard(l.gitKpiActiveContainers, l.gitKpiContainersValue(totalContainers), Icons.directions_boat, AppTheme.emerald)),
                  ],
                ),
                const SizedBox(height: 16),

                // Search & Filter Bar
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 320,
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: l.gitSearchHint,
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _searchCtrl,
                                  builder: (context, value, _) {
                                    if (value.text.isEmpty) return const SizedBox.shrink();
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                                          tooltip: l.gitCopyFieldTooltip,
                                          onPressed: () => CopyHelper.copy(context, _searchCtrl.text),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            setState(() {});
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 16),
                          DropdownButton<String>(
                            value: _selectedStatusFilter,
                            underline: const SizedBox(),
                            items: [
                              DropdownMenuItem(value: 'All', child: Text(l.gitFilterAll)),
                              DropdownMenuItem(value: 'In-Transit Only', child: Text(l.gitFilterInTransitOnly)),
                              DropdownMenuItem(value: 'Delivered Only', child: Text(l.gitFilterDeliveredOnly)),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedStatusFilter = val);
                            },
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: AppTheme.cobalt),
                            tooltip: l.gitRefreshTooltip,
                            onPressed: () => ref.read(goodsInTransitProvider.notifier).initLedger(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Goods In Transit Table
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.table_chart_outlined, color: AppTheme.emerald, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l.gitTableSectionHeader,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        if (filteredItems.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(child: Text(l.gitNoDataFound)),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                              columns: [
                                DataColumn(label: Text(l.gitColActions, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l.gitColFileCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l.gitColPoNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l.gitColItemCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l.gitColItemName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l.gitColInvoicedQty, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l.gitColPackagesCount, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l.gitColContainers, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l.gitColCertifiedDate, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l.gitColLedgerStatus, style: const TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: filteredItems.map((item) {
                                final allFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
                                final isAr = Localizations.localeOf(context).languageCode == 'ar';
                                final rawCode = item.importFileCode;
                                final shipName = DisplayNameResolver.resolveShipmentNameByCode(rawCode, shipments: allFiles, isArabic: isAr);
                                final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: allFiles, isArabic: isAr);
                                final isDelivered = item.isDeliveredToWarehouse;
                                final statusStr = isDelivered ? l.gitStatusDeliveredToWarehouse : l.gitStatusInTransit;
                                final rowSummary =
                                    '$shipTitle\t${item.poNumber}\t${item.itemCode}\t${item.itemName}\t${item.invoicedQty.toStringAsFixed(0)}\t${item.packagesCount} ${item.packageType}\t${item.containersCount} × ${item.containerType}\t${item.certifiedDate}\t$statusStr';

                                return DataRow(cells: [
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                                          tooltip: l.gitCopyRowSummaryBtn,
                                          onPressed: () => CopyHelper.copy(
                                            context,
                                            rowSummary,
                                            customMessage: l.gitCopyRowSummarySuccess,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Import File Code badge
                                  DataCell(
                                    CopyableTableCell(
                                      value: shipTitle,
                                      rowSummary: rowSummary,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            shipName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.charcoal,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (rawCode.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: InkWell(
                                                onTap: () => CopyHelper.copy(
                                                  context,
                                                  rawCode,
                                                  customMessage: '${l.gitColFileCode}: $rawCode',
                                                ),
                                                borderRadius: BorderRadius.circular(4),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.charcoal.withOpacity(0.08),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        rawCode,
                                                        style: TextStyle(
                                                          fontSize: DisplayDensityMode.clampFontSize(11.0),
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.grey.shade700,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      const Icon(Icons.copy, size: 11, color: Colors.grey),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // PO Number badge
                                  DataCell(
                                    CopyableTableCell(
                                      value: item.poNumber,
                                      rowSummary: rowSummary,
                                      child: InkWell(
                                        onTap: () => CopyHelper.copy(
                                          context,
                                          item.poNumber,
                                          customMessage: '${l.gitColPoNumber}: ${item.poNumber}',
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            LtrText(item.poNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.copy, size: 12, color: AppTheme.cobalt),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Item Code badge
                                  DataCell(
                                    CopyableTableCell(
                                      value: item.itemCode,
                                      rowSummary: rowSummary,
                                      child: InkWell(
                                        onTap: () => CopyHelper.copy(
                                          context,
                                          item.itemCode,
                                          customMessage: '${l.gitColItemCode}: ${item.itemCode}',
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(item.itemCode, style: const TextStyle(fontFamily: 'monospace')),
                                            const SizedBox(width: 4),
                                            Icon(Icons.copy, size: 12, color: Colors.grey.shade600),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Item Description
                                  DataCell(
                                    CopyableTableCell(
                                      value: item.itemName,
                                      rowSummary: rowSummary,
                                      child: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  // Invoiced Qty
                                  DataCell(
                                    CopyableTableCell(
                                      value: item.invoicedQty.toStringAsFixed(0),
                                      rowSummary: rowSummary,
                                      child: Text(
                                        l.gitKpiQuantityValue(item.invoicedQty.toStringAsFixed(0)),
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                                      ),
                                    ),
                                  ),
                                  // Packages
                                  DataCell(
                                    CopyableTableCell(
                                      value: '${item.packagesCount} ${item.packageType}',
                                      rowSummary: rowSummary,
                                      child: Text('${item.packagesCount} ${item.packageType}'),
                                    ),
                                  ),
                                  // Containers
                                  DataCell(
                                    CopyableTableCell(
                                      value: '${item.containersCount} × ${item.containerType}',
                                      rowSummary: rowSummary,
                                      child: Text('${item.containersCount} × ${item.containerType}'),
                                    ),
                                  ),
                                  // Certified Date
                                  DataCell(
                                    CopyableTableCell(
                                      value: item.certifiedDate,
                                      rowSummary: rowSummary,
                                      child: Text(item.certifiedDate),
                                    ),
                                  ),
                                  // Ledger Status
                                  DataCell(
                                    CopyableTableCell(
                                      value: statusStr,
                                      rowSummary: rowSummary,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (isDelivered ? Colors.green : Colors.teal).shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: (isDelivered ? Colors.green : Colors.teal).shade300),
                                        ),
                                        child: Text(
                                          statusStr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isDelivered ? Colors.green.shade900 : Colors.teal.shade900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return VerticalStageScaffold(
      stageCode: 'PHASE-6: STEP_19',
      titleEn: 'Goods In Transit (GIT) Inventory Ledger',
      titleAr: 'رصيد ومطابقة البضاعة في الطريق',
      headerIcon: Icons.local_shipping,
      headerColor: AppTheme.emerald,
      tabs: tabs,
      selectedIndex: 0,
      onTabSelected: (_) {},
      headerActions: [
        IconButton(
          icon: Icon(Icons.refresh, color: Colors.white70, size: density.buttonIconSize),
          tooltip: l.warehouseReceivingRefreshTooltip,
          onPressed: () => ref.invalidate(goodsInTransitProvider),
        ),
      ],
      body: bodyContent,
    );
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: color), overflow: TextOverflow.ellipsis),
                Text(title, style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(11.0), color: Colors.grey.shade700), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

