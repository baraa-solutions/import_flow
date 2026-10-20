import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/directional_icon.dart';
import '../../auth/providers/auth_provider.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../import_files/widgets/import_file_details_dialog.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../providers/shipment_inquiry_provider.dart';
import '../services/shipment_inquiry_export_service.dart';
import '../widgets/shipment_inquiry_filter_panel.dart';
import '../widgets/smart_insight_bar.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
class ShipmentInquiryScreen extends ConsumerStatefulWidget {
  const ShipmentInquiryScreen({super.key});

  @override
  ConsumerState<ShipmentInquiryScreen> createState() => _ShipmentInquiryScreenState();
}

class _ShipmentInquiryScreenState extends ConsumerState<ShipmentInquiryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
      ref.read(suppliersProvider.notifier).fetchSuppliers();
      ref.read(importCompaniesProvider.notifier).fetchCompanies();
    });
  }

  void _openDetails(ImportFileModel file) {
    showDialog(
      context: context,
      builder: (ctx) => ImportFileDetailsDialog(
        file: file,
        linkedPOs: const [],
        invoiceNumbers: const {},
        totalPackingListCbm: 0.0,
        totalPackingListWeight: 0.0,
        totalPackingListsCount: 0,
      ),
    );
  }

  void _openClone(ImportFileModel file) {
    final l = AppLocalizations.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final arrowSymbol = DirectionalArrow.symbolForArabic(isAr);
    CloneEntityReviewDialog.show(
      context,
      entityType: l.cloneImportFileDialogTitle,
      sourceCode: file.importFileCode,
      suggestedNewCode: '${file.importFileCode}-CLONE',
      sourceTitle: file.customFileNumber ?? file.companyName,
      copiedFieldsSummary: {
        l.importingCompany: file.companyName.isNotEmpty ? file.companyName : '-',
        l.foreignSupplier: file.supplierName.isNotEmpty ? file.supplierName : '-',
        l.portsOfLoadingAndDischarge: '${file.portOfLoading ?? '-'} $arrowSymbol ${file.portOfDischarge ?? '-'}',
        l.transportModeIncoterm: '${file.shipmentMode} (${file.incotermCode})',
      },
      mandatorilyResetFields: [
        l.cloneFieldStatusDraftBadge,
        l.cloneFieldCustomsClearedReset,
        l.cloneFieldFinancialReset,
        l.cloneFieldAcidReset,
        l.cloneFieldPoReset,
      ],
      allowCopyLineItems: true,
      allowCopyAttachments: false,
      initialCopyLineItems: true,
      initialCopyAttachments: false,
      onConfirm: ({
        required String newCode,
        required String newTitle,
        required bool copyLineItems,
        required bool copyAttachments,
        String? notes,
      }) async {
        final cloned = await ref.read(importFilesProvider.notifier).cloneImportFile(
          file.importFileId,
          {
            'target_import_file_code': newCode.trim(),
            'new_import_file_code': newCode.trim(),
            'target_custom_file_number': newTitle.trim().isNotEmpty ? newTitle.trim() : null,
            'copy_invoices_data': copyLineItems,
            'copy_packing_lists': copyLineItems,
            'copy_items': copyLineItems,
            'copy_attachments': copyAttachments,
            if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.clonedSuccessfullyToast(cloned?.importFileCode ?? newCode)),
              backgroundColor: AppTheme.emerald,
            ),
          );
        }
      },
    );
  }

  void _printSingleShipment(ImportFileModel file) {
    final user = ref.read(authProvider).user;
    final l = context.l10n;
    final username = user?.fullName ?? user?.username ?? l.inqOperatorManagerDefault;
    ShipmentInquiryExportService.printSingleShipmentSummary(
      context: context,
      file: file,
      username: username,
    );
  }

  String _buildFilterSummary(AppLocalizations l) {
    final filters = ref.read(shipmentInquiryStateProvider).filters;
    final parts = <String>[];
    if (filters.supplierId != null) parts.add('${l.inqSupplier}: ${filters.supplierId}');
    if (filters.companyId != null) parts.add('${l.inqImporter}: ${filters.companyId}');
    if (filters.hsCodeOrProduct.isNotEmpty) parts.add('${l.inqHsCodeOrProduct}: ${filters.hsCodeOrProduct}');
    if (filters.incotermCode != null && filters.incotermCode != 'All') {
      parts.add('${l.inqIncoterm}: ${filters.incotermCode}');
    }
    if (filters.portOfLoading != null && filters.portOfLoading!.isNotEmpty) {
      parts.add('${l.inqPortOfLoading}: ${filters.portOfLoading}');
    }
    if (filters.portOfDischarge != null && filters.portOfDischarge!.isNotEmpty) {
      parts.add('${l.inqPortOfDischarge}: ${filters.portOfDischarge}');
    }
    if (filters.shipmentMode != null && filters.shipmentMode != 'All') {
      parts.add('${l.inqShippingMode}: ${filters.shipmentMode}');
    }
    if (filters.carrier != null && filters.carrier!.isNotEmpty) {
      parts.add('${l.inqCarrier}: ${filters.carrier}');
    }
    if (filters.search.isNotEmpty) parts.add('${l.inqSearchPrefix}: ${filters.search}');

    return parts.isEmpty ? l.inqAllRegisteredShipments : parts.join(' | ');
  }

  void _handlePrintPdf() {
    final shipments = ref.read(filteredShipmentsProvider);
    final insights = ref.read(shipmentInquiryInsightsProvider);
    final user = ref.read(authProvider).user;
    final l = context.l10n;
    final username = user?.fullName ?? user?.username ?? l.inqOperatorManagerDefault;

    ShipmentInquiryExportService.printPdf(
      context: context,
      files: shipments,
      filterSummary: _buildFilterSummary(l),
      username: username,
      insights: insights,
    );
  }

  void _handleExportExcel() {
    final shipments = ref.read(filteredShipmentsProvider);
    ShipmentInquiryExportService.exportCsv(context: context, files: shipments);
  }

  void _handleExportTsv() {
    final shipments = ref.read(filteredShipmentsProvider);
    ShipmentInquiryExportService.exportTsv(context: context, files: shipments);
  }

  void _handleCopyDossier() {
    final shipments = ref.read(filteredShipmentsProvider);
    final l = context.l10n;
    ShipmentInquiryExportService.copyDossier(
      context: context,
      files: shipments,
      filterSummary: _buildFilterSummary(l),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final importFilesAsync = ref.watch(importFilesProvider);
    final shipments = ref.watch(filteredShipmentsProvider);
    final stats = ref.watch(shipmentInquiryStatsProvider);
    final inquiryState = ref.watch(shipmentInquiryStateProvider);

    final totalCount = stats['total_count'] as int? ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SelectionArea(
        child: Column(
          children: [
            // Screen Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  const BackToDashboardButton(),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.travel_explore_rounded, color: AppTheme.cobalt, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.inqScreenTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.charcoal,
                          ),
                        ),
                        Text(
                          l.inqSubtitle,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // Auto-refresh action button
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppTheme.cobalt),
                    tooltip: l.inqLiveRefreshTooltip,
                    onPressed: () {
                      ref.read(importFilesProvider.notifier).fetchImportFiles();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Content
            Expanded(
              child: importFilesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('${l.inqLoadError}: $err', style: const TextStyle(color: AppTheme.crimson)),
                ),
                data: (_) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 1. Filter Panel (Matching Mockup)
                      ShipmentInquiryFilterPanel(
                        onSearch: () {
                          // Filter is already updated in provider
                        },
                        onExportPrint: _handlePrintPdf,
                      ),
                      const SizedBox(height: 16),

                      // 2. Smart Insight Bar (Layer 1 — UX-SEARCH-013 Section 3.1)
                      const SmartInsightBar(),
                      const SizedBox(height: 16),

                      // 3. Grid Table Header & Export Toolbar (Layer 2 — UX-SEARCH-013 Section 3.2 & 4.2)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.table_view_rounded, size: 20, color: AppTheme.cobalt),
                                const SizedBox(width: 8),
                                Text(
                                  l.inqResultsTableTitle,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.charcoal,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cobalt.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    l.inqShowingMatchingCount(totalCount),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                  ),
                                ),
                              ],
                            ),
                            // Export Actions Toolbar
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppTheme.crimson),
                                  label: Text(l.inqExportPdfBtn, style: const TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: _handlePrintPdf,
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.table_chart_outlined, size: 16, color: AppTheme.emerald),
                                  label: Text(l.inqExportExcelBtn, style: const TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: _handleExportExcel,
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.file_present_outlined, size: 16, color: AppTheme.cobalt),
                                  label: Text(l.inqExportTsvBtn, style: const TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  onPressed: _handleExportTsv,
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.copy_all_outlined, size: 18, color: AppTheme.charcoal),
                                  tooltip: l.inqCopyDossierTooltip,
                                  onPressed: _handleCopyDossier,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 4. Interactive Shipments Grid
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: shipments.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(40),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                                      const SizedBox(height: 12),
                                      Text(
                                        l.inqEmptyShipmentsTitle,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F3F5)),
                                  dataRowMaxHeight: 58,
                                  dataRowMinHeight: 46,
                                  horizontalMargin: 14,
                                  columnSpacing: 18,
                                  columns: [
                                    DataColumn(
                                      label: Text(
                                        l.inqColActions,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                    DataColumn(
                                      label: _buildSortableHeader(l.inqColShipmentName, ShipmentInquirySortField.shipmentName, inquiryState),
                                    ),
                                    DataColumn(
                                      label: _buildSortableHeader(l.inqColDate, ShipmentInquirySortField.date, inquiryState),
                                    ),
                                    DataColumn(
                                      label: _buildSortableHeader(l.inqColSupplier, ShipmentInquirySortField.supplierName, inquiryState),
                                    ),
                                    DataColumn(
                                      label: _buildSortableHeader(l.inqColImporter, ShipmentInquirySortField.companyName, inquiryState),
                                    ),
                                    DataColumn(
                                      label: _buildSortableHeader(l.inqColItemAndHs, ShipmentInquirySortField.itemAndHs, inquiryState),
                                    ),
                                    DataColumn(
                                      label: _buildSortableHeader(l.inqColRoute, ShipmentInquirySortField.route, inquiryState),
                                    ),
                                    DataColumn(
                                      label: _buildSortableHeader(l.inqColShippingMode, ShipmentInquirySortField.shippingMode, inquiryState),
                                    ),
                                    DataColumn(
                                      label: _buildSortableHeader(l.inqColIncoterm, ShipmentInquirySortField.incoterm, inquiryState),
                                    ),
                                    DataColumn(
                                      label: _buildSortableHeader(l.inqColFreightCost, ShipmentInquirySortField.freightCost, inquiryState),
                                      numeric: true,
                                    ),
                                    DataColumn(
                                      label: _buildSortableHeader(l.inqColFinalCost, ShipmentInquirySortField.finalCost, inquiryState),
                                      numeric: true,
                                    ),
                                    DataColumn(
                                      label: _buildSortableHeader(l.inqColStatus, ShipmentInquirySortField.status, inquiryState),
                                    ),
                                  ],
                                  rows: shipments.map((file) {
                                    final row = ShipmentInquiryReportRow.fromImportFile(file, l);
                                    final rowTsvSummary = '${row.shipmentName}\t${file.importFileCode}\t${row.fileDate}\t${row.supplierName}\t${row.companyName}\t${row.itemAndHs}\t${row.route}\t${row.shippingMode}\t${row.incoterm}\t${row.freightCost.toStringAsFixed(0)} ${row.currency}\t${row.finalCost.toStringAsFixed(0)} ${row.finalCostCurrency}\t${row.status}';

                                    return DataRow(
                                      onSelectChanged: (_) => _openDetails(file),
                                      cells: [
                                        // Actions: View Details | Clone | Print Single | Quick Copy TSV
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Details Button
                                              IconButton(
                                                icon: const Icon(Icons.visibility_outlined, color: AppTheme.charcoal, size: 18),
                                                tooltip: l.inqActionDetails,
                                                onPressed: () => _openDetails(file),
                                              ),
                                              // Clone Button (UX-CLONE-011)
                                              IconButton(
                                                icon: const Icon(Icons.copy_all_rounded, color: AppTheme.cobalt, size: 18),
                                                tooltip: l.inqActionClone,
                                                onPressed: () => _openClone(file),
                                              ),
                                              // Print Single Row Dossier
                                              IconButton(
                                                icon: const Icon(Icons.print_outlined, color: AppTheme.crimson, size: 18),
                                                tooltip: l.inqPrintRowTooltip,
                                                onPressed: () => _printSingleShipment(file),
                                              ),
                                              // Quick Row Copy Button
                                              IconButton(
                                                icon: const Icon(Icons.copy_rounded, color: AppTheme.emerald, size: 18),
                                                tooltip: l.inqCopyRowTooltip,
                                                onPressed: () {
                                                  CopyHelper.copy(
                                                    context,
                                                    rowTsvSummary,
                                                    customMessage: l.inqCopiedRowSuccess,
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Shipment Name & File Code
                                        DataCell(
                                          CopyableTableCell(
                                            value: '${row.shipmentName} (${file.importFileCode})',
                                            rowSummary: rowTsvSummary,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  row.shipmentName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    LtrText(
                                                      file.importFileCode,
                                                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    InkWell(
                                                      onTap: () => CopyHelper.copy(
                                                        context,
                                                        file.importFileCode,
                                                        customMessage: l.inqCopiedCodeSuccess,
                                                      ),
                                                      child: Tooltip(
                                                        message: l.inqCopyCodeTooltip,
                                                        child: Icon(
                                                          Icons.copy_rounded,
                                                          size: 11,
                                                          color: Colors.grey.shade500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Date
                                        DataCell(
                                          CopyableTableCell(
                                            value: row.fileDate,
                                            rowSummary: rowTsvSummary,
                                            child: Text(
                                              row.fileDate.isNotEmpty ? row.fileDate : '-',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ),

                                        // Foreign Supplier
                                        DataCell(
                                          CopyableTableCell(
                                            value: row.supplierName,
                                            rowSummary: rowTsvSummary,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.business_outlined, size: 15, color: AppTheme.cobalt),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    row.supplierName,
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Importing Company
                                        DataCell(
                                          CopyableTableCell(
                                            value: row.companyName,
                                            rowSummary: rowTsvSummary,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.blueGrey.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                row.companyName,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.charcoal,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Item & HS Code
                                        DataCell(
                                          CopyableTableCell(
                                            value: row.itemAndHs,
                                            rowSummary: rowTsvSummary,
                                            child: Text(
                                              row.itemAndHs,
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ),

                                        // Route (POL -> POD)
                                        DataCell(
                                          CopyableTableCell(
                                            value: row.route,
                                            rowSummary: rowTsvSummary,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.alt_route_rounded, size: 15, color: Colors.teal),
                                                const SizedBox(width: 6),
                                                Text(
                                                  row.route,
                                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Shipping Mode
                                        DataCell(
                                          CopyableTableCell(
                                            value: row.shippingMode,
                                            rowSummary: rowTsvSummary,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.directions_boat_outlined, size: 15, color: AppTheme.cobalt),
                                                const SizedBox(width: 6),
                                                Text(
                                                  row.shippingMode,
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Incoterm
                                        DataCell(
                                          CopyableTableCell(
                                            value: row.incoterm,
                                            rowSummary: rowTsvSummary,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _getIncotermColor(row.incoterm).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: _getIncotermColor(row.incoterm).withOpacity(0.4)),
                                              ),
                                              child: Text(
                                                row.incoterm,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getIncotermColor(row.incoterm),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Freight Cost
                                        DataCell(
                                          CopyableTableCell(
                                            value: '${row.freightCost.toStringAsFixed(0)} ${row.currency}',
                                            rowSummary: rowTsvSummary,
                                            child: Text(
                                              '${row.freightCost.toStringAsFixed(0)} ${row.currency}',
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.charcoal,
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Final Cost
                                        DataCell(
                                          CopyableTableCell(
                                            value: '${row.finalCost.toStringAsFixed(0)} ${row.finalCostCurrency}',
                                            rowSummary: rowTsvSummary,
                                            child: Text(
                                              '${row.finalCost.toStringAsFixed(0)} ${row.finalCostCurrency}',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal.shade800,
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Status
                                        DataCell(
                                          CopyableTableCell(
                                            value: row.status,
                                            rowSummary: rowTsvSummary,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(row.status).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: _getStatusColor(row.status).withOpacity(0.35)),
                                              ),
                                              child: Text(
                                                row.status,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getStatusColor(row.status),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortableHeader(
    String title,
    ShipmentInquirySortField field,
    ShipmentInquiryState state,
  ) {
    final isSelected = state.sortField == field;
    return InkWell(
      onTap: () {
        ref.read(shipmentInquiryStateProvider.notifier).sortBy(field);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isSelected ? AppTheme.cobalt : AppTheme.charcoal,
            ),
          ),
          if (isSelected)
            Icon(
              state.isAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: AppTheme.cobalt,
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('مكتمل') || s.contains('completed') || s.contains('cleared') || s.contains('مفرج')) {
      return AppTheme.emerald;
    }
    if (s.contains('جار') || s.contains('in_progress') || s.contains('active') || s.contains('قيد')) {
      return AppTheme.cobalt;
    }
    if (s.contains('متأخر') || s.contains('delayed') || s.contains('overdue')) {
      return AppTheme.crimson;
    }
    if (s.contains('مسود') || s.contains('draft')) {
      return Colors.blueGrey;
    }
    return AppTheme.orange;
  }

  Color _getIncotermColor(String inco) {
    switch (inco.toUpperCase()) {
      case 'EXW':
        return Colors.orange.shade800;
      case 'FOB':
        return AppTheme.cobalt;
      case 'CIF':
      case 'CIP':
        return AppTheme.emerald;
      case 'DDP':
        return Colors.purple.shade700;
      default:
        return AppTheme.charcoal;
    }
  }
}
