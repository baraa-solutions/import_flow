import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/extraction_progress_dialog.dart';
import '../../customs_consultation/widgets/price_list_form_dialog.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../transport_locations/providers/transport_locations_provider.dart';
import '../models/customs_clearance_quotation_model.dart';
import '../providers/customs_clearance_quotations_provider.dart';
import '../services/customs_clearance_quotations_export_service.dart';

class CustomsClearanceQuotationsScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const CustomsClearanceQuotationsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<CustomsClearanceQuotationsScreen> createState() =>
      _CustomsClearanceQuotationsScreenState();
}

class _CustomsClearanceQuotationsScreenState
    extends ConsumerState<CustomsClearanceQuotationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customsClearanceQuotationsProvider.notifier).fetchRFQs();
      ref.read(clearancePriceListProvider.notifier).fetchPriceList();
      ref.read(partnersProvider.notifier).fetchPartners();
      ref.read(importFilesProvider.notifier).fetchImportFiles();
      ref.read(transportLocationsProvider.notifier).fetchLocations();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (widget.embedded) {
      return SelectionArea(
        child: Container(
          color: const Color(0xFFF4F6F8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.request_quote_rounded, color: AppTheme.cobalt, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      l10n.clearanceQuotesEmbeddedTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppTheme.charcoal),
                      tooltip: l10n.refresh,
                      onPressed: () {
                        ref.invalidate(customsClearanceQuotationsProvider);
                        ref.invalidate(clearancePriceListProvider);
                        ref.invalidate(partnersProvider);
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: Text(l10n.clearanceQuotesSmartExtractorBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _showSmartExtractorDialog(null),
                    ),
                  ],
                ),
              ),
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.cobalt,
                  indicatorWeight: 3,
                  labelColor: AppTheme.cobalt,
                  unselectedLabelColor: Colors.grey.shade600,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                      text: l10n.clearanceQuotesTabRfqs,
                    ),
                    Tab(
                      icon: const Icon(Icons.price_change_rounded, size: 18),
                      text: l10n.clearanceQuotesTabPriceLists,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRFQsTab(),
                    _buildPriceListsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SelectionArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.request_quote_rounded, color: Colors.amber, size: 26),
              const SizedBox(width: 10),
              Text(
                l10n.clearanceQuotesScreenTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          backgroundColor: AppTheme.charcoal,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: l10n.refresh,
              onPressed: () {
                ref.invalidate(customsClearanceQuotationsProvider);
                ref.invalidate(clearancePriceListProvider);
                ref.invalidate(partnersProvider);
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.cobalt,
            indicatorWeight: 3.5,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey.shade400,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(
                icon: const Icon(Icons.compare_arrows_rounded),
                text: l10n.clearanceQuotesTabRfqs,
              ),
              Tab(
                icon: const Icon(Icons.price_change_rounded),
                text: l10n.clearanceQuotesTabPriceLists,
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildRFQsTab(),
            _buildPriceListsTab(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: RFQS & EVALUATOR
  // ===========================================================================

  Widget _buildRFQsTab() {
    final l10n = context.l10n;
    final rfqsState = ref.watch(customsClearanceQuotationsProvider);

    return rfqsState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.crimson),
            const SizedBox(height: 12),
            Text('${l10n.clearanceQuotesErrorLoadingRfqs} $e', style: const TextStyle(color: AppTheme.crimson)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
              onPressed: () => ref.read(customsClearanceQuotationsProvider.notifier).fetchRFQs(),
            ),
          ],
        ),
      ),
      data: (rfqs) {
        final filtered = rfqs.where((r) {
          final q = _searchCtrl.text.trim().toLowerCase();
          final matchesQuery = q.isEmpty ||
              r.rfqCode.toLowerCase().contains(q) ||
              r.title.toLowerCase().contains(q) ||
              r.portName.toLowerCase().contains(q);
          final matchesStatus = _selectedStatusFilter == 'ALL' || r.status == _selectedStatusFilter;
          return matchesQuery && matchesStatus;
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            children: [
              // Top Action & Filter Toolbar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: l10n.clearanceQuotesSearchHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedStatusFilter,
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(value: 'ALL', child: Text(l10n.clearanceQuotesStatusAll)),
                        DropdownMenuItem(value: 'Draft', child: Text(l10n.clearanceQuotesStatusDraft)),
                        DropdownMenuItem(value: 'Quotations Received', child: Text(l10n.clearanceQuotesStatusReceived)),
                        DropdownMenuItem(value: 'Awarded', child: Text(l10n.clearanceQuotesStatusAwarded)),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatusFilter = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Action & Export Buttons Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: Text(l10n.clearanceQuotesSmartExtractorBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _showSmartExtractorDialog(null),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                      label: Text(l10n.clearanceQuotesCreateRfqBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _showCreateRFQDialog(),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.table_view_rounded, size: 16, color: AppTheme.cobalt),
                      label: Text(l10n.clearanceQuotesExportTsvBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: filtered.isEmpty ? null : () => CustomsClearanceQuotationsExportService.exportRfqsTsv(context, filtered),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.grid_on_rounded, size: 16, color: AppTheme.emerald),
                      label: Text(l10n.clearanceQuotesExportExcelBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: filtered.isEmpty ? null : () => CustomsClearanceQuotationsExportService.exportRfqsExcel(context, filtered),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: AppTheme.crimson),
                      label: Text(l10n.clearanceQuotesPrintPdfBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: filtered.isEmpty ? null : () => CustomsClearanceQuotationsExportService.printOrSaveRfqsPdf(context, filtered),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy_all_rounded, size: 16, color: AppTheme.charcoal),
                      label: Text(l10n.clearanceQuotesCopyDossierBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: filtered.isEmpty ? null : () => CustomsClearanceQuotationsExportService.copyRfqDossier(context, filtered),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Content List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              l10n.clearanceQuotesNoRfqsFound,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, idx) => _buildRFQCard(filtered[idx]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRFQCard(CustomsClearanceRFQModel rfq) {
    final l10n = context.l10n;
    Color statusColor = Colors.grey;
    String statusDisplay = rfq.status;
    if (rfq.status == 'Awarded') {
      statusColor = AppTheme.emerald;
      statusDisplay = l10n.clearanceQuotesStatusAwarded;
    } else if (rfq.status == 'Quotations Received') {
      statusColor = AppTheme.cobalt;
      statusDisplay = l10n.clearanceQuotesStatusReceived;
    } else if (rfq.status == 'Draft') {
      statusDisplay = l10n.clearanceQuotesStatusDraft;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => CopyHelper.copy(context, rfq.rfqCode),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.charcoal.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              rfq.rfqCode,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                            ),
                            const SizedBox(width: 5),
                            const Icon(Icons.copy_rounded, size: 14, color: AppTheme.charcoal),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      rfq.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_all_rounded, size: 18, color: AppTheme.cobalt),
                      tooltip: l10n.clearanceQuotesCopyDossierBtn,
                      onPressed: () => CustomsClearanceQuotationsExportService.copyRfqDossier(context, [rfq]),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        statusDisplay,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Cargo & Location Details Row
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _buildInfoBadge(Icons.anchor_rounded, l10n.clearanceQuotesBadgePort, rfq.portName),
                _buildInfoBadge(Icons.local_shipping_rounded, l10n.clearanceQuotesBadgeShipmentType, '${rfq.shipmentType} (${rfq.containersCount})'),
                if (rfq.hsCode != null && rfq.hsCode!.isNotEmpty)
                  _buildInfoBadge(Icons.category_rounded, l10n.clearanceQuotesBadgeHsCode, rfq.hsCode!),
                _buildInfoBadge(Icons.scale_rounded, l10n.clearanceQuotesBadgeWeight, '${rfq.grossWeightKg} ${l10n.kgUnit}'),
                _buildInfoBadge(Icons.view_in_ar_rounded, l10n.clearanceQuotesBadgeVolume, '${rfq.cbm} ${l10n.cbmUnit}'),
                if (rfq.lowestClearanceCost > 0)
                  _buildInfoBadge(Icons.monetization_on_rounded, l10n.clearanceQuotesBadgeLowestCost, '${rfq.lowestClearanceCost.toStringAsFixed(2)} ${l10n.egpCurrency}', color: AppTheme.emerald),
                if (rfq.fastestTurnaroundDays > 0)
                  _buildInfoBadge(Icons.timer_rounded, l10n.clearanceQuotesBadgeFastestDuration, l10n.clearanceQuotesDaysCount(rfq.fastestTurnaroundDays), color: AppTheme.cobalt),
              ],
            ),

            if (rfq.status == 'Awarded' && rfq.awardedProviderName != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: AppTheme.emerald, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${l10n.clearanceQuotesAwardedBannerPrefix} ${rfq.awardedProviderName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 24),

            // Competing Quotations Table / Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.clearanceQuotesReceivedQuotesHeader(rfq.quotations.length),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF6C5CE7)),
                      label: Text(l10n.clearanceQuotesSmartExtractQuoteBtn, style: const TextStyle(color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () => _showSmartExtractorDialog(rfq.rfqId),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cobalt,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(l10n.clearanceQuotesAddManualQuoteBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _showAddQuotationDialog(rfq.rfqId),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (rfq.quotations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(l10n.clearanceQuotesNoQuotesYet, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                  columns: [
                    DataColumn(label: Text(l10n.clearanceQuotesColStatusActions, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text(l10n.clearanceQuotesColBroker, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text(l10n.clearanceQuotesColClearanceFee, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text(l10n.clearanceQuotesColInlandTransport, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text(l10n.clearanceQuotesColInspectionFee, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text(l10n.clearanceQuotesColPortExpenses, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text(l10n.clearanceQuotesColMiscellaneous, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text(l10n.clearanceQuotesColEstimatedTotal, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text(l10n.clearanceQuotesColDuration, style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: rfq.quotations.map((q) {
                    final isAwarded = q.isAwarded;
                    final rowSummary = '${q.providerName} | ${l10n.clearanceQuotesColEstimatedTotal}: ${q.totalCost.toStringAsFixed(0)} ${q.currency} | ${l10n.clearanceQuotesDaysCount(q.estimatedTurnaroundDays)}';
                    return DataRow(
                      color: isAwarded ? WidgetStateProperty.all(AppTheme.emerald.withOpacity(0.06)) : null,
                      cells: [
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                              tooltip: l10n.copy,
                              onPressed: () => CopyHelper.copy(context, rowSummary),
                            ),
                            if (isAwarded)
                              Chip(
                                avatar: const Icon(Icons.check, size: 14, color: Colors.white),
                                label: Text(l10n.clearanceQuotesStatusAwardedBadge, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: AppTheme.emerald,
                                padding: EdgeInsets.zero,
                              )
                            else
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.emerald,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                                child: Text(l10n.clearanceQuotesAwardAndApproveBtn, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () => _awardQuotation(rfq.rfqId, q.quotationId!),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 18),
                              onPressed: () => _deleteQuotation(q.quotationId!),
                            ),
                          ],
                        )),
                        DataCell(CopyableTableCell(
                          value: q.providerName,
                          rowSummary: rowSummary,
                          child: Text(q.providerName, style: TextStyle(fontWeight: isAwarded ? FontWeight.bold : FontWeight.normal)),
                        )),
                        DataCell(CopyableTableCell(
                          value: '${q.clearanceFee.toStringAsFixed(0)} ${q.currency}',
                          rowSummary: rowSummary,
                          child: Text('${q.clearanceFee.toStringAsFixed(0)} ${q.currency}'),
                        )),
                        DataCell(CopyableTableCell(
                          value: '${q.inlandTransportFee.toStringAsFixed(0)} ${q.currency}',
                          rowSummary: rowSummary,
                          child: Text('${q.inlandTransportFee.toStringAsFixed(0)} ${q.currency}'),
                        )),
                        DataCell(CopyableTableCell(
                          value: '${q.inspectionFee.toStringAsFixed(0)} ${q.currency}',
                          rowSummary: rowSummary,
                          child: Text('${q.inspectionFee.toStringAsFixed(0)} ${q.currency}'),
                        )),
                        DataCell(CopyableTableCell(
                          value: '${q.portExpenses.toStringAsFixed(0)} ${q.currency}',
                          rowSummary: rowSummary,
                          child: Text('${q.portExpenses.toStringAsFixed(0)} ${q.currency}'),
                        )),
                        DataCell(CopyableTableCell(
                          value: '${q.miscellaneousFee.toStringAsFixed(0)} ${q.currency}',
                          rowSummary: rowSummary,
                          child: Text('${q.miscellaneousFee.toStringAsFixed(0)} ${q.currency}'),
                        )),
                        DataCell(CopyableTableCell(
                          value: '${q.totalCost.toStringAsFixed(0)} ${q.currency}',
                          rowSummary: rowSummary,
                          child: Text(
                            '${q.totalCost.toStringAsFixed(0)} ${q.currency}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: isAwarded ? AppTheme.emerald : AppTheme.charcoal),
                          ),
                        )),
                        DataCell(CopyableTableCell(
                          value: l10n.clearanceQuotesDaysCount(q.estimatedTurnaroundDays),
                          rowSummary: rowSummary,
                          child: Text(l10n.clearanceQuotesDaysCount(q.estimatedTurnaroundDays)),
                        )),

                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String label, String value, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey.shade700),
        const SizedBox(width: 5),
        Text('$label ', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
        Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color ?? AppTheme.charcoal)),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: PRICE LISTS MASTER
  // ===========================================================================

  Widget _buildPriceListsTab() {
    final l10n = context.l10n;
    final priceListState = ref.watch(clearancePriceListProvider);

    return priceListState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('${l10n.clearanceQuotesErrorLoadingPriceList} $e', style: const TextStyle(color: AppTheme.crimson))),
      data: (items) {
        return Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.clearanceQuotesPriceListTitle,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                      ),
                      const SizedBox(height: 4),
                      Text(l10n.clearanceQuotesPriceListSubtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.table_view_rounded, size: 16, color: AppTheme.cobalt),
                          label: Text(l10n.clearanceQuotesExportTsvBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: items.isEmpty ? null : () => CustomsClearanceQuotationsExportService.exportPriceListTsv(context, items),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.grid_on_rounded, size: 16, color: AppTheme.emerald),
                          label: Text(l10n.clearanceQuotesExportExcelBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: items.isEmpty ? null : () => CustomsClearanceQuotationsExportService.exportPriceListExcel(context, items),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: AppTheme.crimson),
                          label: Text(l10n.clearanceQuotesPrintPdfBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: items.isEmpty ? null : () => CustomsClearanceQuotationsExportService.printOrSavePriceListPdf(context, items),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          ),
                          icon: const Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                          label: Text(l10n.clearanceQuotesManagePriceListBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            final partners = ref.read(partnersProvider).value ?? [];
                            final brokersList = partners.where((p) => p.partnerType == 'Customs Broker' || p.partnerType == 'مستخلص جمركي' || p.partnerType == 'Customs Clearance').toList();
                            showPriceListFormDialog(
                              context,
                              ref,
                              brokersList: brokersList.isNotEmpty ? brokersList : partners,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(l10n.clearanceQuotesAddPriceItemBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _showAddPriceItemDialog(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(l10n.clearanceQuotesNoPriceItemsFound, style: TextStyle(color: Colors.grey.shade600)),
                      )
                    : Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: SingleChildScrollView(
                          child: SizedBox(
                            width: double.infinity,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                              columns: [
                                DataColumn(label: Text(l10n.clearanceQuotesColPriceDelete, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l10n.clearanceQuotesColBroker, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l10n.clearanceQuotesColPricePort, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l10n.clearanceQuotesColPriceServiceType, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l10n.clearanceQuotesColPriceContainerType, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l10n.clearanceQuotesColPriceStandardRate, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(l10n.clearanceQuotesColPriceNotes, style: const TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: items.map((item) {
                                final rowSummary = '${item.providerName} | ${item.portName} | ${item.serviceCategory} | ${item.containerType} | ${item.unitPrice.toStringAsFixed(2)} ${item.currency}';
                                return DataRow(cells: [
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                                        tooltip: l10n.copy,
                                        onPressed: () => CopyHelper.copy(context, rowSummary),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 18),
                                        onPressed: () => ref.read(clearancePriceListProvider.notifier).deletePriceItem(item.priceItemId),
                                      ),
                                    ],
                                  )),
                                  DataCell(CopyableTableCell(
                                    value: item.providerName,
                                    rowSummary: rowSummary,
                                    child: Text(item.providerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  )),
                                  DataCell(CopyableTableCell(
                                    value: item.portName,
                                    rowSummary: rowSummary,
                                    child: Text(item.portName),
                                  )),
                                  DataCell(CopyableTableCell(
                                    value: item.serviceCategory,
                                    rowSummary: rowSummary,
                                    child: Text(item.serviceCategory),
                                  )),
                                  DataCell(CopyableTableCell(
                                    value: item.containerType,
                                    rowSummary: rowSummary,
                                    child: Text(item.containerType),
                                  )),
                                  DataCell(CopyableTableCell(
                                    value: '${item.unitPrice.toStringAsFixed(2)} ${item.currency}',
                                    rowSummary: rowSummary,
                                    child: Text('${item.unitPrice.toStringAsFixed(2)} ${item.currency}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                                  )),
                                  DataCell(CopyableTableCell(
                                    value: item.notes ?? '-',
                                    rowSummary: rowSummary,
                                    child: Text(item.notes ?? '-'),
                                  )),

                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // DIALOGS & ACTIONS
  // ===========================================================================

  Future<void> _showCreateRFQDialog({
    String? initialBrokerName,
    String? initialPortName,
  }) async {
    final l10n = context.l10n;
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(
      text: initialBrokerName != null ? 'طلب تخليص جمركي - $initialBrokerName' : l10n.clearanceQuotesDialogCreateRfqTitle,
    );
    final commodityCtrl = TextEditingController();
    final hsCodeCtrl = TextEditingController();
    final grossWeightCtrl = TextEditingController(text: '10000');
    final cbmCtrl = TextEditingController(text: '30');
    int containersCount = 1;
    String shipmentType = 'Ocean FCL (40HQ)';
    String portName = initialPortName ?? 'Alexandria Port';
    int? selectedImportFileId;

    final importFiles = ref.read(importFilesProvider).value ?? [];
    final locations = ref.read(transportLocationsProvider).value ?? [];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.add_task_rounded, color: AppTheme.emerald),
              const SizedBox(width: 10),
              Text(l10n.clearanceQuotesDialogCreateRfqTitle),
            ],
          ),
          content: SelectionArea(
            child: SizedBox(
              width: 600,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.clearanceQuotesFieldRfqTitle,
                          prefixIcon: const Icon(Icons.title_rounded),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            tooltip: l10n.copy,
                            onPressed: () => CopyHelper.copy(ctx, titleCtrl.text),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? l10n.clearanceQuotesFieldRfqTitleRequired : null,
                      ),
                      const SizedBox(height: 12),
                      SearchableDropdownField<int>(
                        value: selectedImportFileId,
                        labelText: l10n.clearanceQuotesFieldLinkImportFile,
                        searchHintText: l10n.searchPlaceholder,
                        items: importFiles
                            .map((f) => SearchableDropdownItem<int>(
                                  value: f.importFileId,
                                  label: '${f.primaryNameWithCode} - ${f.companyName}',
                                ))
                            .toList(),
                        onChanged: (val) {
                          setDState(() {
                            selectedImportFileId = val;
                            final match = importFiles.where((f) => f.importFileId == val).firstOrNull;
                            if (match != null) {
                              if (match.portOfDischarge != null && match.portOfDischarge!.isNotEmpty) {
                                portName = match.portOfDischarge!;
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SearchableDropdownField<String>(
                        value: portName,
                        labelText: l10n.clearanceQuotesFieldClearancePort,
                        searchHintText: l10n.searchPlaceholder,
                        items: locations
                            .map((l) => SearchableDropdownItem<String>(
                                  value: l.locationName,
                                  label: l.locationName,
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDState(() => portName = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SearchableDropdownField<String>(
                              value: shipmentType,
                              labelText: l10n.clearanceQuotesFieldShipmentType,
                              items: const [
                                SearchableDropdownItem(value: 'Ocean FCL (40HQ)', label: 'Ocean FCL (40HQ)'),
                                SearchableDropdownItem(value: 'Ocean FCL (20GP)', label: 'Ocean FCL (20GP)'),
                                SearchableDropdownItem(value: 'Ocean LCL', label: 'Ocean LCL'),
                                SearchableDropdownItem(value: 'Air Freight', label: 'Air Freight'),
                              ],
                              onChanged: (v) {
                                if (v != null) setDState(() => shipmentType = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              initialValue: containersCount.toString(),
                              decoration: InputDecoration(labelText: l10n.clearanceQuotesFieldContainersCount),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => containersCount = int.tryParse(v) ?? 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: grossWeightCtrl,
                              decoration: InputDecoration(
                                labelText: l10n.clearanceQuotesFieldGrossWeightKg,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  tooltip: l10n.copy,
                                  onPressed: () => CopyHelper.copy(ctx, grossWeightCtrl.text),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: cbmCtrl,
                              decoration: InputDecoration(
                                labelText: l10n.clearanceQuotesFieldCbm,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  tooltip: l10n.copy,
                                  onPressed: () => CopyHelper.copy(ctx, cbmCtrl.text),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              child: Text(l10n.cancel),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
              child: Text(l10n.clearanceQuotesSubmitCreateRfqBtn),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newRfq = CustomsClearanceRFQModel(
                  rfqId: 0,
                  rfqCode: '',
                  title: titleCtrl.text.trim(),
                  portName: portName,
                  importFileId: selectedImportFileId,
                  commodityDescription: commodityCtrl.text.trim().isNotEmpty ? commodityCtrl.text.trim() : null,
                  hsCode: hsCodeCtrl.text.trim().isNotEmpty ? hsCodeCtrl.text.trim() : null,
                  shipmentType: shipmentType,
                  containersCount: containersCount,
                  packagesCount: 0,
                  grossWeightKg: double.tryParse(grossWeightCtrl.text) ?? 0.0,
                  cbm: double.tryParse(cbmCtrl.text) ?? 0.0,
                  status: 'Draft',
                  lowestClearanceCost: 0.0,
                  fastestTurnaroundDays: 0,
                  createdAt: '',
                );

                await ref.read(customsClearanceQuotationsProvider.notifier).createRFQ(newRfq);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddQuotationDialog(int rfqId, {Map<String, dynamic>? prefill}) async {
    final l10n = context.l10n;
    final formKey = GlobalKey<FormState>();
    final partners = ref.read(partnersProvider).value?.where((p) => p.partnerType == 'Customs Broker' || p.partnerType == 'Freight Forwarder').toList() ?? [];

    int? selectedProviderId = prefill?['provider_id'] ?? (partners.isNotEmpty ? partners.first.partnerId : 1);
    String selectedProviderName = prefill?['provider_name'] ?? (partners.isNotEmpty ? partners.first.partnerName : l10n.clearanceQuotesColBroker);

    final clearanceFeeCtrl = TextEditingController(text: prefill?['clearance_fee']?.toString() ?? '3000');
    final inlandFeeCtrl = TextEditingController(text: prefill?['inland_transport_fee']?.toString() ?? '6000');
    final inspectionFeeCtrl = TextEditingController(text: prefill?['inspection_fee']?.toString() ?? '1500');
    final portExpCtrl = TextEditingController(text: prefill?['port_expenses']?.toString() ?? '2000');
    final miscCtrl = TextEditingController(text: prefill?['miscellaneous_fee']?.toString() ?? '500');
    final daysCtrl = TextEditingController(text: prefill?['transit_clearance_days']?.toString() ?? '3');
    final remarksCtrl = TextEditingController(text: prefill?['notes']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          double total = (double.tryParse(clearanceFeeCtrl.text) ?? 0.0) +
              (double.tryParse(inlandFeeCtrl.text) ?? 0.0) +
              (double.tryParse(inspectionFeeCtrl.text) ?? 0.0) +
              (double.tryParse(portExpCtrl.text) ?? 0.0) +
              (double.tryParse(miscCtrl.text) ?? 0.0);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AppTheme.cobalt),
                const SizedBox(width: 10),
                Text(l10n.clearanceQuotesDialogAddQuoteTitle),
              ],
            ),
            content: SelectionArea(
              child: SizedBox(
                width: 580,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SearchableDropdownField<int>(
                          value: selectedProviderId,
                          labelText: l10n.clearanceQuotesFieldCustomsBroker,
                          searchHintText: l10n.searchPlaceholder,
                          items: partners
                              .map((p) => SearchableDropdownItem<int>(
                                    value: p.partnerId!,
                                    label: '${p.partnerName} (${p.partnerType})',
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDState(() {
                                selectedProviderId = val;
                                final match = partners.where((p) => p.partnerId == val).firstOrNull;
                                if (match != null) selectedProviderName = match.partnerName;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: clearanceFeeCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.clearanceQuotesFieldClearanceFeeEgp,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    tooltip: l10n.copy,
                                    onPressed: () => CopyHelper.copy(ctx, clearanceFeeCtrl.text),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setDState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: inlandFeeCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.clearanceQuotesFieldInlandFeeEgp,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    tooltip: l10n.copy,
                                    onPressed: () => CopyHelper.copy(ctx, inlandFeeCtrl.text),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setDState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: inspectionFeeCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.clearanceQuotesFieldInspectionFeeEgp,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    tooltip: l10n.copy,
                                    onPressed: () => CopyHelper.copy(ctx, inspectionFeeCtrl.text),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setDState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: portExpCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.clearanceQuotesFieldPortExpEgp,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    tooltip: l10n.copy,
                                    onPressed: () => CopyHelper.copy(ctx, portExpCtrl.text),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setDState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: miscCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.clearanceQuotesFieldMiscFeeEgp,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    tooltip: l10n.copy,
                                    onPressed: () => CopyHelper.copy(ctx, miscCtrl.text),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setDState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: daysCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.clearanceQuotesFieldEstimatedDays,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    tooltip: l10n.copy,
                                    onPressed: () => CopyHelper.copy(ctx, daysCtrl.text),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () => CopyHelper.copy(ctx, '${total.toStringAsFixed(2)} ${l10n.egpCurrency}'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.emerald),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.copy_rounded, size: 16, color: AppTheme.emerald),
                                    const SizedBox(width: 6),
                                    Text(l10n.clearanceQuotesTotalEstimatedQuoteLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Text('${total.toStringAsFixed(2)} ${l10n.egpCurrency}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.emerald)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(child: Text(l10n.cancel), onPressed: () => Navigator.pop(ctx)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, foregroundColor: Colors.white),
                child: Text(l10n.clearanceQuotesSubmitSaveQuoteBtn),
                onPressed: () async {
                  final quote = CustomsClearanceQuotationItemModel(
                    providerId: selectedProviderId ?? 1,
                    providerName: selectedProviderName,
                    clearanceFee: double.tryParse(clearanceFeeCtrl.text) ?? 0.0,
                    inlandTransportFee: double.tryParse(inlandFeeCtrl.text) ?? 0.0,
                    inspectionFee: double.tryParse(inspectionFeeCtrl.text) ?? 0.0,
                    portExpenses: double.tryParse(portExpCtrl.text) ?? 0.0,
                    miscellaneousFee: double.tryParse(miscCtrl.text) ?? 0.0,
                    totalCost: total,
                    estimatedTurnaroundDays: int.tryParse(daysCtrl.text) ?? 3,
                    remarks: remarksCtrl.text.trim().isNotEmpty ? remarksCtrl.text.trim() : null,
                  );

                  await ref.read(customsClearanceQuotationsProvider.notifier).addQuotation(rfqId, quote);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
  }

    Future<void> _showSmartExtractorDialog(int? targetRfqId) async {
    await showSmartClearanceExtractorDialog(
      context,
      ref,
      targetRfqId: targetRfqId,
      onExtracted: (extracted) {
        final rfqs = ref.read(customsClearanceQuotationsProvider).value ?? [];
        final rfqId = targetRfqId ?? (rfqs.isNotEmpty ? rfqs.first.rfqId : null);
        if (rfqId != null) {
          _showAddQuotationDialog(rfqId, prefill: extracted);
        } else {
          _showCreateRFQDialog();
        }
      },
    );
  }

  Future<void> _showAddPriceItemDialog() async {
    final l10n = context.l10n;
    final formKey = GlobalKey<FormState>();
    final partners = ref.read(partnersProvider).value?.where((p) => p.partnerType == 'Customs Broker' || p.partnerType == 'Freight Forwarder').toList() ?? [];
    final locations = ref.read(transportLocationsProvider).value ?? [];

    int selectedProviderId = partners.isNotEmpty ? partners.first.partnerId! : 1;
    String selectedProviderName = partners.isNotEmpty ? partners.first.partnerName : l10n.clearanceQuotesColBroker;
    String portName = locations.isNotEmpty ? locations.first.locationName : 'Alexandria Port';
    String category = l10n.clearanceQuotesCatClearanceFee;
    String containerType = '40HQ';
    final priceCtrl = TextEditingController(text: '3500');
    final notesCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l10n.clearanceQuotesDialogAddPriceItemTitle),
          content: SelectionArea(
            child: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SearchableDropdownField<int>(
                      value: selectedProviderId,
                      labelText: l10n.clearanceQuotesFieldCustomsBroker,
                      searchHintText: l10n.searchPlaceholder,
                      items: partners.map((p) => SearchableDropdownItem<int>(value: p.partnerId!, label: p.partnerName)).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDState(() {
                            selectedProviderId = val;
                            final m = partners.where((p) => p.partnerId == val).firstOrNull;
                            if (m != null) selectedProviderName = m.partnerName;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      value: portName,
                      labelText: l10n.clearanceQuotesFieldClearancePort,
                      searchHintText: l10n.searchPlaceholder,
                      items: locations.map((l) => SearchableDropdownItem<String>(value: l.locationName, label: l.locationName)).toList(),
                      onChanged: (val) {
                        if (val != null) setDState(() => portName = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      value: category,
                      labelText: l10n.clearanceQuotesFieldServiceCategory,
                      items: [
                        SearchableDropdownItem(value: l10n.clearanceQuotesCatClearanceFee, label: l10n.clearanceQuotesCatClearanceFee),
                        SearchableDropdownItem(value: l10n.clearanceQuotesCatInlandTransport, label: l10n.clearanceQuotesCatInlandTransport),
                        SearchableDropdownItem(value: l10n.clearanceQuotesCatInspectionFee, label: l10n.clearanceQuotesCatInspectionFee),
                        SearchableDropdownItem(value: l10n.clearanceQuotesCatPortCharges, label: l10n.clearanceQuotesCatPortCharges),
                      ],
                      onChanged: (val) {
                        if (val != null) setDState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SearchableDropdownField<String>(
                            value: containerType,
                            labelText: l10n.clearanceQuotesColPriceContainerType,
                            items: const [
                              SearchableDropdownItem(value: '40HQ', label: '40HQ'),
                              SearchableDropdownItem(value: '40GP', label: '40GP'),
                              SearchableDropdownItem(value: '20GP', label: '20GP'),
                              SearchableDropdownItem(value: 'LCL', label: 'LCL'),
                              SearchableDropdownItem(value: 'Air', label: 'Air'),
                            ],
                            onChanged: (val) {
                              if (val != null) setDState(() => containerType = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: priceCtrl,
                            decoration: InputDecoration(
                              labelText: l10n.clearanceQuotesFieldStandardPriceEgp,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                tooltip: l10n.copy,
                                onPressed: () => CopyHelper.copy(ctx, priceCtrl.text),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v == null || v.trim().isEmpty) ? l10n.clearanceQuotesFieldStandardPriceRequired : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(child: Text(l10n.cancel), onPressed: () => Navigator.pop(ctx)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
              child: Text(l10n.clearanceQuotesSubmitSavePriceItemBtn),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newItem = ClearancePriceListItemModel(
                  priceItemId: 0,
                  providerId: selectedProviderId,
                  providerName: selectedProviderName,
                  portName: portName,
                  serviceCategory: category,
                  containerType: containerType,
                  unitPrice: double.tryParse(priceCtrl.text) ?? 0.0,
                  currency: l10n.egpCurrency,
                  notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                );

                await ref.read(clearancePriceListProvider.notifier).createPriceItem(newItem);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _awardQuotation(int rfqId, int quotationId) async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppTheme.emerald),
            const SizedBox(width: 8),
            Text(l10n.clearanceQuotesConfirmAwardTitle),
          ],
        ),
        content: Text(l10n.clearanceQuotesConfirmAwardContent),
        actions: [
          TextButton(child: Text(l10n.cancel), onPressed: () => Navigator.pop(ctx, false)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
            child: Text(l10n.clearanceQuotesConfirmAwardBtn),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(customsClearanceQuotationsProvider.notifier).awardQuotation(rfqId, quotationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.clearanceQuotesAwardSuccessSnackbar),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
    }
  }

  Future<void> _deleteQuotation(int quotationId) async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearanceQuotesConfirmDeleteQuoteTitle),
        content: Text(l10n.clearanceQuotesConfirmDeleteQuoteContent),
        actions: [
          TextButton(child: Text(l10n.cancel), onPressed: () => Navigator.pop(ctx, false)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
            child: Text(l10n.delete),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(customsClearanceQuotationsProvider.notifier).deleteQuotation(quotationId);
    }
  }
}

/// Global helper to show the Smart Clearance Quotation Extractor dialog from any screen/tab
const String _sampleClearanceQuoteText = '''
مقايسة وعرض أسعار تخليص جمركي
المخلص الجمركي: مكتب الأهرام للتخليص الجمركي
ميناء الوصول: ميناء الإسكندرية البحري (Alexandria Port)
نوع الحاوية: 40HQ - عدد 2 حاوية
أتعاب التخليص الجمركي: 3,500 جنيه
مصاريف الشحن والتفريغ: 1,800 جنيه
رسوم الفحص والعرض (صادرات وواردات): 2,400 جنيه
مصاريف نولون نقل داخلي للمصنع: 4,500 جنيه
المصروفات النثرية والوزن: 600 جنيه
إجمالي المقايسة التقديرية: 12,800 EGP
''';

  const String _accClearanceQuoteText = '''
شركة اسكندرية للأعمال الجمركية (ACC)
شريف سقسلي
عرض أسعار ومقايسة تخليص جمركي
التاريخ: 2026/04/01
ميناء الإسكندرية والدخيلة

LCL
EGP 1,250.00 اتعاب تخليص ( فاتوره)
EGP 4,750.00 مصاريف تخليص واحد طن
EGP 1,000.00 مصاريف تخليص كل طن زيادة

20FT
EGP 2,500.00 اتعاب تخليص ( فاتوره)
EGP 7,500.00 مصاريف تخليص ١ حاوية
EGP 1,500.00 كل حاوية زيادة

40FT
EGP 2,500.00 اتعاب تخليص ( فاتوره)
EGP 7,500.00 مصاريف تخليص ١ حاوية
EGP 2,000.00 كل حاوية زيادة

تكاليف اخري : (اجراءات تخليص)
EGP 1,000.00 ACID تسجيل الشحنة الجمركي المبدئي
EGP 250.00 - 250.00 بريد - دمغات
EGP 2,500.00 - 3,500.00 عرض الواردات + اعتماد الايباك
EGP 5,000.00 عرض امن عام القاهره
EGP 500.00 - 1,000.00 - 1,500.00 امن عام ( اسكندرية - كفر الشيخ - البحيرة )
EGP 500.00 وثيقة تامين
EGP 250.00 عرض اكس راي
EGP 1,000.00 تطبيق اتفاقيات
EGP 350.00 الافراج تحت التحفظ
EGP 250.00 سيل الجمرك والترصيص
EGP 3,000.00 مطافي ومفرقعات ودمغة موازين
EGP 3,000.00 افراج نهائي واشعاع وكيمياء
EGP 750.00 ( 250 / 250 / 250 ) سحب اذن تسليم وتصوير ومنافستو
EGP 300.00 توكيل
EGP 1,500.00 تفريغ
EGP 500.00 فحص كيمياء
EGP 500.00 فحص اشعاع
EGP 1,000.00 لجنة فحص خارجي
EGP 350.00 منافستو
EGP 250.00 تصوير مستندات
EGP 500.00 اكراميات ولجان

النقل من الإسكندرية للقاهرة
EGP 6,150.00 نقل سيارة 1 طن دبابة للقاهرة
EGP 8,200.00 نقل سيارة جامبو حتى 4 طن للقاهرة
EGP 14,150.00 نقل سيارة فرداني حتى 7 طن للقاهرة
EGP 14,800.00 نقل حاوية 20 قدم وزن اقل من 10 طن للقاهرة
EGP 16,500.00 نقل حاوية 20 قدم وزن اكبر من 10 طن للقاهرة
EGP 18,400.00 نقل حاوية 20*2 للقاهرة
EGP 18,400.00 نقل حاوية 40 قدم للقاهرة

بياتة الحاويات
EGP 3,600.00 بياتة شاحنة 20*2
EGP 3,600.00 بياتة شاحنة 40*1
EGP 3,000.00 بياتة شاحنة 20*1

مصاريف الميناء والتعامل
EGP 1,000.00 كارتة ابوقير
EGP 3,500.00 تعتيق ونقل وزن داخل الميناء ( قماش )

شروط وبنود خارج الجدول:
بخلاف مصاريف كشف الحاويات المشتركة من 1000 إلى 5000 جنيه
بخلاف كشف التجميع للحاويات من 1500 إلى 3000 جنيه
بخلاف رسوم المعامل وفحص العينات الكيماوية من 500 إلى 2000 جنيه
بخلاف أتعاب فتح شهادة الترانزيت ونقل جمركي من 2000 إلى 4000 جنيه
بخلاف رسوم توكيلات ملاحية وإيصالات رسمية من 1000 إلى 5000 جنيه
''';
  
void _normalizeExtractedRateData(Map<String, dynamic> extracted) {
  if (extracted['rate_options'] is List && (extracted['rate_options'] as List).isNotEmpty) {
    final opts = extracted['rate_options'] as List;
    final primaryOpt = opts.firstWhere(
      (o) => (o as Map)['container_type'] == '40HQ',
      orElse: () => opts.first,
    ) as Map<String, dynamic>;

    final currentTotal = (extracted['total_estimated_clearance_cost'] as num?)?.toDouble() ?? 0.0;
    final currentType = extracted['container_type'] as String?;

    if (currentType == null || currentType.isEmpty || currentTotal < 2000.0) {
      extracted['container_type'] = primaryOpt['container_type'];
      extracted['clearance_fee'] = primaryOpt['clearance_fee'];
      extracted['inland_transport_fee'] = primaryOpt['inland_transport_fee'];
      extracted['inspection_fee'] = primaryOpt['inspection_fee'];
      extracted['port_expenses'] = primaryOpt['port_expenses'];
      extracted['total_estimated_clearance_cost'] = primaryOpt['total_estimated_clearance_cost'];
      if (primaryOpt['notes'] != null) {
        extracted['notes'] = primaryOpt['notes'];
      }
    }
  }
}


Widget _buildQuotationValidationBanner(
  BuildContext ctx,
  AppLocalizations l10n,
  Map<String, dynamic>? valReport,
  List<dynamic>? expensesCatalog,
) {
  if (valReport == null && (expensesCatalog == null || expensesCatalog.isEmpty)) {
    return const SizedBox.shrink();
  }

  final bannerStatus = valReport?['banner_status']?.toString() ?? 'safe';
  final expectedCount = valReport?['expected_item_count'] ?? valReport?['expected_count'] ?? expensesCatalog?.length ?? 0;
  final extractedCount = valReport?['extracted_item_count'] ?? valReport?['extracted_count'] ?? expensesCatalog?.length ?? 0;
  final codedCount = (valReport?['coded_items_count'] as num?)?.toInt() ?? 0;
  final uncodedCount = (valReport?['uncoded_items_count'] as num?)?.toInt() ?? 0;
  final gapPct = (valReport?['gap_percentage'] as num?)?.toDouble() ?? 0.0;
  final multiSplitCount = (valReport?['multi_value_items_count'] as num?)?.toInt() ?? 0;
  final rangeCount = (valReport?['range_items_count'] as num?)?.toInt() ?? 0;
  final outsideCount = (valReport?['outside_table_items_count'] as num?)?.toInt() ?? 0;

  final isCritical = bannerStatus == 'critical';
  final isWarning = bannerStatus == 'warning';

  final Color borderColor = isCritical
      ? AppTheme.crimson
      : (isWarning ? Colors.amber.shade700 : AppTheme.emerald);
  final Color bgColor = isCritical
      ? const Color(0xFFFDE8E8)
      : (isWarning ? const Color(0xFFFEF3C7) : const Color(0xFFE8F5E9));
  final Color textColor = isCritical
      ? AppTheme.crimson
      : (isWarning ? Colors.amber.shade900 : const Color(0xFF1B5E20));
  final IconData icon = isCritical
      ? Icons.error_outline_rounded
      : (isWarning ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded);
  final String title = isCritical
      ? l10n.quotationValidationBannerCriticalTitle
      : (isWarning ? l10n.quotationValidationBannerWarningTitle : l10n.quotationValidationBannerSafeTitle);

  final isAr = Localizations.localeOf(ctx).languageCode == 'ar';
  final message = isAr
      ? (valReport?['message_ar']?.toString() ?? title)
      : (valReport?['message_en']?.toString() ?? title);

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: borderColor, width: 1.2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: borderColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                side: BorderSide(color: borderColor),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.copy_rounded, size: 13),
              label: Text(l10n.quotationValidationCopyReportBtn, style: const TextStyle(fontSize: 11)),
              onPressed: () {
                final buffer = StringBuffer();
                buffer.writeln('=== ${l10n.quotationValidationCopyReportBtn} ===');
                buffer.writeln(l10n.quotationValidationExpectedCount(expectedCount));
                buffer.writeln(l10n.quotationValidationExtractedCount(extractedCount));
                buffer.writeln(l10n.quotationValidationGapPercentage(gapPct.toStringAsFixed(1)));
                buffer.writeln('$title: $message');
                if (multiSplitCount > 0) {
                  buffer.writeln('- $multiSplitCount ${l10n.quotationValidationMultiValueBadge}');
                }
                if (rangeCount > 0) {
                  buffer.writeln('- $rangeCount ${l10n.quotationValidationRangeBadge}');
                }
                if (outsideCount > 0) {
                  buffer.writeln('- $outsideCount ${l10n.quotationValidationOutsideTableBadge}');
                }
                CopyHelper.copy(ctx, buffer.toString());
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(l10n.quotationValidationReportCopiedToast),
                    backgroundColor: AppTheme.emerald,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(message, style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.9))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: borderColor.withOpacity(0.5)),
              ),
              child: Text(
                l10n.quotationValidationExpectedCount(expectedCount),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: borderColor.withOpacity(0.5)),
              ),
              child: Text(
                l10n.quotationValidationExtractedCount(extractedCount),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: borderColor.withOpacity(0.5)),
              ),
              child: Text(
                l10n.quotationValidationGapPercentage(gapPct.toStringAsFixed(1)),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
              ),
            ),
            if (codedCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.cobalt),
                ),
                child: Text(
                  '$codedCount بند مكوّد',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                ),
              ),
            if (uncodedCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.crimson),
                ),
                child: Text(
                  '$uncodedCount بحاجة لتكويد',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.crimson),
                ),
              ),
            if (multiSplitCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Text(
                  '$multiSplitCount ${l10n.quotationValidationMultiValueBadge}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                ),
              ),
            if (rangeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF7C3AED)),
                ),
                child: Text(
                  '⚡ $rangeCount ${l10n.quotationValidationRangeBadge}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                ),
              ),
            if (outsideCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blueGrey.shade600),
                ),
                child: Text(
                  '$outsideCount ${l10n.quotationValidationOutsideTableBadge}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}


Widget _buildFeeColumnWidget(String label, String value, {bool isTotal = false}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          fontSize: isTotal ? 12 : 11,
          fontWeight: FontWeight.bold,
          color: isTotal ? AppTheme.emerald : AppTheme.charcoal,
        ),
      ),
    ],
  );
}

/// Global helper to show the unified Smart AI Clearance Quotation & Estimate Extractor dialog
Future<void> showSmartClearanceExtractorDialog(
  BuildContext context,
  WidgetRef ref, {
  int? targetRfqId,
  Function(Map<String, dynamic> extracted)? onExtracted,
}) async {
  final l10n = AppLocalizations.of(context);
  final textCtrl = TextEditingController();
  bool isExtracting = false;
  Map<String, dynamic>? extractedResult;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF6C5CE7)),
            const SizedBox(width: 10),
            Text(l10n.clearanceQuotesSmartExtractorDialogTitle),
          ],
        ),
        content: SelectionArea(
          child: SizedBox(
            width: 820,
            height: 660,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.clearanceQuotesSmartExtractorPrompt),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 120,
                    child: TextField(
                      controller: textCtrl,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: l10n.clearanceQuotesSmartExtractorInputHint,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.paste_rounded, size: 16),
                        label: Text(l10n.clearanceQuotesPasteClipboardBtn, style: const TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null && data!.text!.isNotEmpty) {
                            textCtrl.text = data.text!;
                            setDState(() {});
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.bolt_rounded, size: 16, color: Colors.amber),
                        label: Text(l10n.clearanceQuotesSampleAccBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                        onPressed: () {
                          textCtrl.text = _accClearanceQuoteText;
                          setDState(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.description_outlined, size: 14, color: AppTheme.cobalt),
                        label: Text(l10n.clearanceQuotesSampleStandardBtn, style: const TextStyle(fontSize: 12, color: AppTheme.cobalt)),
                        onPressed: () {
                          textCtrl.text = _sampleClearanceQuoteText;
                          setDState(() {});
                        },
                      ),
                      const Spacer(),
                      if (textCtrl.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_all_rounded, size: 18),
                          tooltip: l10n.clearanceQuotesClearInputTooltip,
                          onPressed: () => setDState(() => textCtrl.clear()),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), foregroundColor: Colors.white),
                        icon: isExtracting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.bolt_rounded),
                        label: Text(isExtracting ? l10n.clearanceQuotesExtractingState : l10n.clearanceQuotesExtractFromTextBtn),
                        onPressed: isExtracting
                            ? null
                            : () async {
                                final text = textCtrl.text.trim();
                                if (text.isEmpty) return;
                                setDState(() => isExtracting = true);
                                try {
                                  final dio = ref.read(uploadDioProvider);
                                  final formData = FormData.fromMap({'raw_text': text});
                                  final resp = await dio.post(
                                    '${ApiConstants.baseUrl}/smart-upload/parse-text/clearance-quotation',
                                    data: formData,
                                    options: Options(receiveTimeout: const Duration(seconds: 120)),
                                  );
                                  if (resp.statusCode == 200 && resp.data != null) {
                                    final fields = resp.data['extracted_fields'] as Map<String, dynamic>?;
                                    if (fields != null) {
                                      _normalizeExtractedRateData(fields);
                                    }
                                    setDState(() {
                                      extractedResult = fields;
                                    });
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${l10n.errorPrefix}: $e'), backgroundColor: AppTheme.crimson),
                                    );
                                  }
                                } finally {
                                  setDState(() => isExtracting = false);
                                }
                              },
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.upload_file_rounded),
                        label: Text(l10n.clearanceQuotesUploadDocBtn),
                        onPressed: () async {
                          final result = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'xlsx', 'xls', 'docx', 'doc', 'png', 'jpg', 'jpeg', 'txt'],
                            withData: true,
                          );
                          if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
                          final file = result.files.first;

                          final progressCtrl = ExtractionProgressController();
                          progressCtrl.update(
                            percent: 0.15,
                            status: l10n.clearanceQuotesOcrUploadingState,
                            stepLabel: l10n.clearanceQuotesOcrStep1,
                            currentStep: 1,
                          );

                          if (context.mounted) {
                            ExtractionProgressDialog.show(
                              context: context,
                              title: l10n.clearanceQuotesOcrDialogTitle,
                              fileName: file.name,
                              controller: progressCtrl,
                            );
                          }

                          setDState(() => isExtracting = true);
                          try {
                            final dio = ref.read(uploadDioProvider);
                            final formData = FormData.fromMap({
                              'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
                              'module_name': 'clearance-quotation',
                            });
                            final resp = await dio.post(
                              '${ApiConstants.baseUrl}/smart-upload/upload',
                              data: formData,
                              options: Options(receiveTimeout: const Duration(seconds: 120)),
                              onSendProgress: (sent, total) {
                                if (total > 0) {
                                  final ratio = sent / total;
                                  progressCtrl.update(
                                    percent: 0.15 + (ratio * 0.35),
                                    status: l10n.clearanceQuotesOcrProgressState((ratio * 100).round()),
                                    stepLabel: l10n.clearanceQuotesOcrStep2,
                                    currentStep: 2,
                                  );
                                  if (ratio >= 0.99) {
                                    progressCtrl.startAutoAdvance(
                                      targetPercent: 0.92,
                                      duration: const Duration(seconds: 5),
                                      step4Status: l10n.clearanceQuotesOcrStep4State,
                                    );
                                  }
                                }
                              },
                            );

                            progressCtrl.complete();
                            await Future.delayed(const Duration(milliseconds: 300));
                            if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

                            if (resp.statusCode == 200 && resp.data != null) {
                              final fields = resp.data['extracted_fields'] as Map<String, dynamic>?;
                              if (fields != null) {
                                _normalizeExtractedRateData(fields);
                              }
                              setDState(() {
                                extractedResult = fields;
                              });
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.of(context, rootNavigator: true).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${l10n.errorPrefix}: $e'), backgroundColor: AppTheme.crimson),
                              );
                            }
                          } finally {
                            setDState(() => isExtracting = false);
                          }
                        },
                      ),
                    ],
                  ),
                if (extractedResult != null) ...[
                  const SizedBox(height: 14),
                  _buildQuotationValidationBanner(
                    ctx,
                    l10n,
                    extractedResult!['validation_report'] as Map<String, dynamic>?,
                    extractedResult!['expenses_catalog'] as List<dynamic>?,
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.emerald),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${l10n.clearanceQuotesExtractedBrokerPrefix} ${extractedResult!['broker_name'] ?? l10n.clearanceQuotesColBroker}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('${l10n.clearanceQuotesExtractedPortPrefix} ${extractedResult!['port_name'] ?? '-'} | ${l10n.clearanceQuotesSelectedContainerLabel}: ${extractedResult!['container_type'] ?? '-'}'),
                                Text('${l10n.clearanceQuotesExtractedTotalPrefix} ${extractedResult!['total_estimated_clearance_cost']} ${l10n.egpCurrency}', style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                                  tooltip: l10n.copy,
                                  onPressed: () {
                                    final summary = '${extractedResult!['broker_name'] ?? l10n.clearanceQuotesColBroker} - ${extractedResult!['port_name'] ?? '-'} - ${extractedResult!['total_estimated_clearance_cost']} ${l10n.egpCurrency}';
                                    CopyHelper.copy(ctx, summary);
                                  },
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), foregroundColor: Colors.white),
                                  icon: const Icon(Icons.price_change_outlined, size: 16),
                                  label: Text(l10n.clearanceQuotesSaveAsPriceListBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    final valReport = extractedResult?['validation_report'] as Map<String, dynamic>?;
                                    if (valReport?['requires_modal_confirmation'] == true) {
                                      final expCount = valReport?['expected_item_count'] ?? valReport?['expected_count'] ?? 0;
                                      final extCount = valReport?['extracted_item_count'] ?? valReport?['extracted_count'] ?? 0;
                                      final gap = (valReport?['gap_percentage'] as num?)?.toDouble() ?? 0.0;
                                      final proceed = await showDialog<bool>(
                                        context: ctx,
                                        builder: (modalCtx) => AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          title: Row(
                                            children: [
                                              const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 24),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  l10n.quotationValidationConfirmTitle,
                                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.crimson),
                                                ),
                                              ),
                                            ],
                                          ),
                                          content: Text(
                                            l10n.quotationValidationConfirmMessage(expCount, extCount, gap.toStringAsFixed(1)),
                                            style: const TextStyle(fontSize: 13, height: 1.4),
                                          ),
                                          actions: [
                                            TextButton(
                                              child: Text(l10n.quotationValidationReviewBtn),
                                              onPressed: () => Navigator.pop(modalCtx, false),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
                                              child: Text(l10n.quotationValidationProceedBtn),
                                              onPressed: () => Navigator.pop(modalCtx, true),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (proceed != true) return;
                                    }
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                    if (!context.mounted) return;
                                    final partners = ref.read(partnersProvider).value ?? [];
                                    final brokersList = partners.where((p) => p.partnerType == 'Customs Broker' || p.partnerType == 'مستخلص جمركي' || p.partnerType == 'Customs Clearance').toList();
                                    final listToPass = brokersList.isNotEmpty ? brokersList : partners;
                                    showPriceListFormDialog(
                                      context,
                                      ref,
                                      brokersList: listToPass,
                                      initialExtractedData: extractedResult,
                                    );
                                  },
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
                                  icon: const Icon(Icons.check),
                                  label: Text(l10n.clearanceQuotesApplyExtractedQuoteBtn),
                                  onPressed: () async {
                                    final valReport = extractedResult?['validation_report'] as Map<String, dynamic>?;
                                    if (valReport?['requires_modal_confirmation'] == true) {
                                      final expCount = valReport?['expected_item_count'] ?? valReport?['expected_count'] ?? 0;
                                      final extCount = valReport?['extracted_item_count'] ?? valReport?['extracted_count'] ?? 0;
                                      final gap = (valReport?['gap_percentage'] as num?)?.toDouble() ?? 0.0;
                                      final proceed = await showDialog<bool>(
                                        context: ctx,
                                        builder: (modalCtx) => AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          title: Row(
                                            children: [
                                              const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 24),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  l10n.quotationValidationConfirmTitle,
                                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.crimson),
                                                ),
                                              ),
                                            ],
                                          ),
                                          content: Text(
                                            l10n.quotationValidationConfirmMessage(expCount, extCount, gap.toStringAsFixed(1)),
                                            style: const TextStyle(fontSize: 13, height: 1.4),
                                          ),
                                          actions: [
                                            TextButton(
                                              child: Text(l10n.quotationValidationReviewBtn),
                                              onPressed: () => Navigator.pop(modalCtx, false),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
                                              child: Text(l10n.quotationValidationProceedBtn),
                                              onPressed: () => Navigator.pop(modalCtx, true),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (proceed != true) return;
                                    }
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                    if (!context.mounted) return;
                                    if (onExtracted != null) {
                                      onExtracted(extractedResult!);
                                    } else {
                                      final partners = ref.read(partnersProvider).value ?? [];
                                      final brokersList = partners.where((p) => p.partnerType == 'Customs Broker' || p.partnerType == 'مستخلص جمركي' || p.partnerType == 'Customs Clearance').toList();
                                      final listToPass = brokersList.isNotEmpty ? brokersList : partners;
                                      showPriceListFormDialog(
                                        context,
                                        ref,
                                        brokersList: listToPass,
                                        initialExtractedData: extractedResult,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Multi-container Rate Options Selector in Dialog
                        if (extractedResult!['rate_options'] is List && (extractedResult!['rate_options'] as List).isNotEmpty) ...[
                          const Divider(height: 16),
                          Text(l10n.clearanceQuotesRateOptionsTitle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: (extractedResult!['rate_options'] as List).map<Widget>((opt) {
                              final optMap = opt as Map<String, dynamic>;
                              final cType = optMap['container_type']?.toString() ?? 'Option';
                              final optTotal = optMap['total_estimated_clearance_cost'] ?? 0;
                              final isSelected = (extractedResult!['container_type'] == cType);
                              return ChoiceChip(
                                avatar: Icon(isSelected ? Icons.check_circle : Icons.inventory_2_outlined, size: 14, color: isSelected ? Colors.white : AppTheme.cobalt),
                                label: Text('$cType : $optTotal ${l10n.egpCurrency}', style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : AppTheme.charcoal)),
                                selected: isSelected,
                                selectedColor: AppTheme.cobalt,
                                backgroundColor: Colors.white,
                                onSelected: (selected) {
                                  if (selected) {
                                    setDState(() {
                                      extractedResult!['container_type'] = cType;
                                      extractedResult!['clearance_fee'] = optMap['clearance_fee'];
                                      extractedResult!['inland_transport_fee'] = optMap['inland_transport_fee'];
                                      extractedResult!['inspection_fee'] = optMap['inspection_fee'];
                                      extractedResult!['port_expenses'] = optMap['port_expenses'];
                                      extractedResult!['total_estimated_clearance_cost'] = optTotal;
                                      extractedResult!['notes'] = optMap['notes'];
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ],

                        // Detailed Cost Breakdown Row in Dialog
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildFeeColumnWidget(l10n.clearanceQuotesBreakdownClearanceFee, '${extractedResult!['clearance_fee'] ?? 0} ${l10n.egpCurrency}'),
                              _buildFeeColumnWidget(l10n.clearanceQuotesBreakdownInlandFee, '${extractedResult!['inland_transport_fee'] ?? 0} ${l10n.egpCurrency}'),
                              _buildFeeColumnWidget(l10n.clearanceQuotesBreakdownInspectionFee, '${extractedResult!['inspection_fee'] ?? 0} ${l10n.egpCurrency}'),
                              _buildFeeColumnWidget(l10n.clearanceQuotesBreakdownPortExpenses, '${extractedResult!['port_expenses'] ?? 0} ${l10n.egpCurrency}'),
                              _buildFeeColumnWidget(l10n.clearanceQuotesBreakdownEstimatedTotal, '${extractedResult!['total_estimated_clearance_cost'] ?? 0} ${l10n.egpCurrency}', isTotal: true),
                            ],
                          ),
                        ),

                        // Expandable Expenses Catalog in Dialog
                        if (extractedResult!['expenses_catalog'] is List && (extractedResult!['expenses_catalog'] as List).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              dense: true,
                              leading: const Icon(Icons.receipt_long, size: 18, color: Color(0xFF6C5CE7)),
                              title: Text(
                                l10n.clearanceQuotesExpensesCatalogCount((extractedResult!['expenses_catalog'] as List).length),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7)),
                              ),
                              children: [
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 180),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: (extractedResult!['expenses_catalog'] as List).length,
                                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                                    itemBuilder: (ctx, i) {
                                      final itm = (extractedResult!['expenses_catalog'] as List)[i] as Map<String, dynamic>;
                                      final isMulti = itm['is_multi_value_split'] == true;
                                      final isRange = itm['price_type'] == 'range';
                                      final isOutside = itm['source_location'] == 'outside_table';

                                      Color itemBg = Colors.transparent;
                                      if (isMulti) {
                                        itemBg = Colors.amber.shade50;
                                      } else if (isRange) {
                                        itemBg = const Color(0xFFF5F3FF);
                                      }

                                      final priceStr = isRange
                                          ? '${itm['price_min'] ?? 0} - ${itm['price_max'] ?? 0} ${l10n.egpCurrency}'
                                          : '${itm['price']} ${l10n.egpCurrency}';

                                      return Container(
                                        color: itemBg,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      itm['item_name']?.toString() ?? '',
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                                  if (isMulti)
                                                    Tooltip(
                                                      message: l10n.quotationValidationMultiValueTooltip,
                                                      child: Container(
                                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: Colors.amber.shade100,
                                                          borderRadius: BorderRadius.circular(3),
                                                          border: Border.all(color: Colors.amber.shade700, width: 0.8),
                                                        ),
                                                        child: Text(
                                                          l10n.quotationValidationMultiValueBadge,
                                                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                                        ),
                                                      ),
                                                    ),
                                                  if (isRange)
                                                    Tooltip(
                                                      message: l10n.quotationValidationRangeTooltip(itm['price_min'] ?? '', itm['price_max'] ?? ''),
                                                      child: Container(
                                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFEDE9FE),
                                                          borderRadius: BorderRadius.circular(3),
                                                          border: Border.all(color: const Color(0xFF7C3AED), width: 0.8),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.bolt, size: 9, color: Color(0xFF7C3AED)),
                                                            const SizedBox(width: 1),
                                                            Text(
                                                              l10n.quotationValidationRangeBadge,
                                                              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  if (isOutside)
                                                    Tooltip(
                                                      message: l10n.quotationValidationOutsideTableTooltip,
                                                      child: Container(
                                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: Colors.blueGrey.shade100,
                                                          borderRadius: BorderRadius.circular(3),
                                                          border: Border.all(color: Colors.blueGrey.shade600, width: 0.8),
                                                        ),
                                                        child: Text(
                                                          l10n.quotationValidationOutsideTableBadge,
                                                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(itm['category']?.toString() ?? '', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                            ),
                                            Text(
                                              priceStr,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isRange ? const Color(0xFF7C3AED) : AppTheme.emerald,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(itm['pricing_unit']?.toString() ?? '', style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(child: Text(l10n.close), onPressed: () => Navigator.pop(ctx)),
      ],
    ),
    ),
  );
}
