import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../providers/warehouse_receiving_provider.dart';
import '../services/warehouse_received_report_export_service.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../../core/services/display_name_resolver.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
class WarehouseReceivedReportScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const WarehouseReceivedReportScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<WarehouseReceivedReportScreen> createState() => _WarehouseReceivedReportScreenState();
}

class _WarehouseReceivedReportScreenState extends ConsumerState<WarehouseReceivedReportScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!ref.read(warehouseReceivingProvider).isLoading) {
        ref.read(warehouseReceivingProvider.notifier).fetchRecords();
      }
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final recordsAsync = ref.watch(warehouseReceivingProvider);

    final tabs = [
      VerticalNavTabItem(
        icon: Icons.inventory_2_outlined,
        titleEn: 'Received Shipments Detailed Report',
        titleAr: l.whReportTabTitle,
      ),
    ];

    final bodyContent = SelectionArea(
      child: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(l.whReportErrorFetchingData(err), style: const TextStyle(color: Colors.red)),
        ),
        data: (records) {
          final allItems = WarehouseReceivedReportItem.fromReceivingRecords(records);

          final filtered = allItems.where((i) {
            if (_searchCtrl.text.trim().isEmpty) return true;
            final q = _searchCtrl.text.trim().toLowerCase();
            return i.importFileCode.toLowerCase().contains(q) ||
                i.poNumber.toLowerCase().contains(q) ||
                i.itemCode.toLowerCase().contains(q) ||
                i.itemName.toLowerCase().contains(q) ||
                i.warehouseName.toLowerCase().contains(q);
          }).toList();

          final totalInvoiced = filtered.fold<int>(0, (s, i) => s + i.invoicedQty);
          final totalReceived = filtered.fold<int>(0, (s, i) => s + i.receivedQty);
          final totalDamaged = filtered.fold<int>(0, (s, i) => s + i.damagedQty);
          final totalShortage = filtered.fold<int>(0, (s, i) => s + i.shortageQty);
          final totalSamples = filtered.fold<int>(0, (s, i) => s + i.samplesQty);
          final totalVariance = filtered.fold<int>(0, (s, i) => s + i.varianceQty);

          return SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Header Card with Responsive 4-Action Export Toolbar
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 1100;
                    final exportButtons = Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: isNarrow ? WrapAlignment.start : WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.indigo.shade800,
                            side: BorderSide(color: Colors.indigo.shade300),
                          ),
                          icon: const Icon(Icons.table_chart_outlined, size: 16),
                          label: Text(l.whReportExportTsvBtn),
                          onPressed: () => WarehouseReceivedReportExportService.saveReportTsvToFile(
                            context,
                            filtered,
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.file_download_outlined, size: 16),
                          label: Text(l.whReportExportExcelBtn),
                          onPressed: () => WarehouseReceivedReportExportService.saveReportCsvToFile(
                            context,
                            filtered,
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.indigo.shade800,
                            side: BorderSide(color: Colors.indigo.shade300),
                          ),
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                          label: Text(l.whReportPrintPdfBtn),
                          onPressed: () => WarehouseReceivedReportExportService.printOrSaveReportPdf(
                            context,
                            filtered,
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.indigo.shade800,
                            side: BorderSide(color: Colors.indigo.shade300),
                          ),
                          icon: const Icon(Icons.copy_all_outlined, size: 16),
                          label: Text(l.whReportCopyDossierBtn),
                          onPressed: () => WarehouseReceivedReportExportService.copyDossierToClipboard(
                            context,
                            filtered,
                          ),
                        ),
                      ],
                    );

                    if (isNarrow) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.assessment_outlined, color: Colors.indigo, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l.whReportInfoBannerTitle,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppTheme.charcoal,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l.whReportInfoBannerSubtitle,
                                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            exportButtons,
                          ],
                        ),
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.assessment_outlined, color: Colors.indigo, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.whReportInfoBannerTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.charcoal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l.whReportInfoBannerSubtitle,
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: exportButtons,
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
                    Expanded(
                      child: _buildMetricCard(
                        l.whReportKpiInvoicedQty,
                        l.whReportUnitsValue(totalInvoiced),
                        Icons.receipt_long,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricCard(
                        l.whReportKpiReceivedQty,
                        l.whReportUnitsValue(totalReceived),
                        Icons.inventory,
                        AppTheme.emerald,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricCard(
                        l.whReportKpiDamagedQty,
                        l.whReportUnitsValue(totalDamaged),
                        Icons.broken_image,
                        AppTheme.crimson,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricCard(
                        l.whReportKpiShortageQty,
                        l.whReportUnitsValue(totalShortage),
                        Icons.remove_circle_outline,
                        AppTheme.orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricCard(
                        l.whReportKpiSamplesQty,
                        l.whReportUnitsValue(totalSamples),
                        Icons.science,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricCard(
                        l.whReportKpiVarianceQty,
                        '${totalVariance >= 0 ? "+" : ""}${l.whReportUnitsValue(totalVariance)}',
                        Icons.compare_arrows,
                        totalVariance == 0 ? Colors.green : AppTheme.crimson,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar with Copy Suffix Button
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: l.whReportSearchHint,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _searchCtrl,
                          builder: (context, value, _) {
                            if (value.text.isEmpty) return const SizedBox.shrink();
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  tooltip: l.whReportCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(
                                    context,
                                    _searchCtrl.text,
                                    customMessage: l.whReportSearchCopied,
                                  ),
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
                ),
                const SizedBox(height: 16),

                // Report Table
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
                            const Icon(Icons.fact_check, color: AppTheme.cobalt, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l.whReportTableSectionHeader,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(child: Text(l.whReportNoDataFound)),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                              columns: [
                                DataColumn(
                                  label: Text(
                                    l.whReportColImportFile,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    l.whReportColPoNumber,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    l.whReportColContainerAndTruck,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    l.whReportColItemAndDescription,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    l.whReportColInvoicedQty,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    l.whReportColShortageQty,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    l.whReportColDamagedQty,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    l.whReportColSamplesQty,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    l.whReportColReceivedQty,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    l.whReportColVarianceQty,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    l.whReportColReceiptStatus,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    l.whReportColActions,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                              rows: filtered.map((item) {
                                final allFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
                                final isAr = Localizations.localeOf(context).languageCode == 'ar';
                                final rawCode = item.importFileCode;
                                final shipName = DisplayNameResolver.resolveShipmentNameByCode(rawCode, shipments: allFiles, isArabic: isAr);
                                final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: allFiles, isArabic: isAr);
                                final variance = item.varianceQty;
                                final rowSummary = item.toRowSummary(l);

                                return DataRow(cells: [
                                  // 1. Import File Code (Resolved Name + Clickable Copy Badge)
                                  DataCell(
                                    CopyableTableCell(
                                      value: shipTitle,
                                      rowSummary: rowSummary,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          if (shipName != rawCode) ...[
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
                                            const SizedBox(height: 2),
                                          ],
                                          if (rawCode.isNotEmpty)
                                            InkWell(
                                              onTap: () => CopyHelper.copy(
                                                context,
                                                rawCode,
                                                customMessage: l.whReportCopyBadgeSuccess(
                                                  l.whReportColImportFile,
                                                  rawCode,
                                                ),
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
                                        ],
                                      ),
                                    ),
                                  ),

                                  // 2. PO Number (Clickable Copy Badge)
                                  DataCell(
                                    CopyableTableCell(
                                      value: item.poNumber,
                                      rowSummary: rowSummary,
                                      child: InkWell(
                                        onTap: () => CopyHelper.copy(
                                          context,
                                          item.poNumber,
                                          customMessage: l.whReportCopyBadgeSuccess(
                                            l.whReportColPoNumber,
                                            item.poNumber,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            LtrText(
                                              item.poNumber,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.cobalt,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.copy, size: 12, color: AppTheme.cobalt),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 3. Container & Truck Info
                                  DataCell(
                                    CopyableTableCell(
                                      value: item.containerInfo,
                                      rowSummary: rowSummary,
                                      child: Text(item.containerInfo),
                                    ),
                                  ),

                                  // 4. Item Code & Description (Clickable Code Copy Badge)
                                  DataCell(
                                    CopyableTableCell(
                                      value: '${item.itemCode} - ${item.itemName}',
                                      rowSummary: rowSummary,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          InkWell(
                                            onTap: () => CopyHelper.copy(
                                              context,
                                              item.itemCode,
                                              customMessage: l.whReportCopyBadgeSuccess(
                                                l.whReportColItemAndDescription,
                                                item.itemCode,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  item.itemCode,
                                                  style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.copy, size: 10, color: Colors.grey),
                                              ],
                                            ),
                                          ),
                                          Text(item.itemName, style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // 5. Invoiced Qty
                                  DataCell(
                                    CopyableTableCell(
                                      value: '${item.invoicedQty}',
                                      rowSummary: rowSummary,
                                      child: Text(
                                        '${item.invoicedQty}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),

                                  // 6. Shortage Qty
                                  DataCell(
                                    CopyableTableCell(
                                      value: '${item.shortageQty}',
                                      rowSummary: rowSummary,
                                      child: Text(
                                        '${item.shortageQty}',
                                        style: TextStyle(
                                          color: item.shortageQty > 0 ? AppTheme.orange : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 7. Damaged Qty
                                  DataCell(
                                    CopyableTableCell(
                                      value: '${item.damagedQty}',
                                      rowSummary: rowSummary,
                                      child: Text(
                                        '${item.damagedQty}',
                                        style: TextStyle(
                                          color: item.damagedQty > 0 ? AppTheme.crimson : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 8. Samples Qty
                                  DataCell(
                                    CopyableTableCell(
                                      value: '${item.samplesQty}',
                                      rowSummary: rowSummary,
                                      child: Text(
                                        '${item.samplesQty}',
                                        style: TextStyle(
                                          color: item.samplesQty > 0 ? Colors.purple : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 9. Received Qty
                                  DataCell(
                                    CopyableTableCell(
                                      value: '${item.receivedQty}',
                                      rowSummary: rowSummary,
                                      child: Text(
                                        '${item.receivedQty}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.emerald,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 10. Variance Qty
                                  DataCell(
                                    CopyableTableCell(
                                      value: '${variance >= 0 ? "+" : ""}$variance',
                                      rowSummary: rowSummary,
                                      child: Text(
                                        '${variance >= 0 ? "+" : ""}$variance',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: variance == 0
                                              ? Colors.green
                                              : (variance < 0 ? AppTheme.crimson : Colors.blue),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 11. Receipt Status
                                  DataCell(
                                    CopyableTableCell(
                                      value: l.whReportStatusApprovedAndReceived,
                                      rowSummary: rowSummary,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.green.shade300),
                                        ),
                                        child: Text(
                                          l.whReportStatusApprovedAndReceived,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 12. Quick Row Copy Action
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                                      tooltip: l.whReportCopyRowSummaryBtn,
                                      onPressed: () => CopyHelper.copy(
                                        context,
                                        rowSummary,
                                        customMessage: l.whReportCopyRowSummarySuccess,
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
      titleEn: 'Warehouse Received Shipments & Audit Report',
      titleAr: l.whReportScaffoldTitle,
      headerIcon: Icons.inventory_2_outlined,
      headerColor: AppTheme.cobalt,
      tabs: tabs,
      selectedIndex: 0,
      onTabSelected: (_) {},
      headerActions: [
        IconButton(
          icon: Icon(Icons.refresh, color: Colors.white70, size: density.buttonIconSize),
          tooltip: l.warehouseReceivingRefreshTooltip,
          onPressed: () {
            ref.read(warehouseReceivingProvider.notifier).fetchRecords();
            ref.read(importFilesProvider.notifier).fetchImportFiles();
          },
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
                Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color), overflow: TextOverflow.ellipsis),
                Text(title, style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(11.0), color: Colors.grey.shade700), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
