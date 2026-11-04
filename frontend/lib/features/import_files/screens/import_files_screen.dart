// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/performance/dispose_tracker.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/utils/import_file_po_linker.dart';
import '../../../core/widgets/widgets.dart';

import '../../experience_guide/widgets/smart_shipment_reference_card.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../import_documentation/widgets/smart_invoice_bl_extractor_dialog.dart';
import '../../purchase_orders/models/purchase_order_model.dart' hide PackingListItemModel;
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../shipping_scenarios/providers/shipping_scenarios_provider.dart';
import '../../simulation/widgets/what_if_simulator_dialog.dart';
import '../../smart_checklists/widgets/smart_checklist_dialog.dart';

import '../models/import_file_model.dart';
import '../providers/import_files_provider.dart';
import '../widgets/dialogs/add_edit_import_file_dialog.dart';
import '../widgets/dialogs/master_report_dialog.dart';
import '../widgets/dialogs/search_clone_import_file_dialog.dart';
import '../widgets/import_file_details_dialog.dart';
import '../widgets/import_files_compact_toolbar.dart';
import '../widgets/sections/import_files_export_helper.dart';
import '../widgets/sections/import_files_mobile_list.dart';
import '../widgets/sections/import_files_table_columns.dart';

/// Primary Master Screen for managing Import Files (Type B List Screen).
/// Coordinates search, filters, pagination, compact toolbar, mobile view, and modular dialogs.
class ImportFilesScreen extends ConsumerStatefulWidget {
  final String? initialSearchQuery;
  final int? highlightedFileId;

  const ImportFilesScreen({
    super.key,
    this.initialSearchQuery,
    this.highlightedFileId,
  });

  @override
  ConsumerState<ImportFilesScreen> createState() => _ImportFilesScreenState();
}

class _ImportFilesScreenState extends ConsumerState<ImportFilesScreen> with DisposeTrackerMixin<ImportFilesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _screenFocusNode = FocusNode();
  String? _selectedStatusFilter = 'All';
  int? _highlightedFileId;

  void _showAddEditFileDialog([ImportFileModel? fileToEdit]) {
    AddEditImportFileDialog.show(context, ref, fileToEdit: fileToEdit, searchQuery: _searchController.text, statusFilter: _selectedStatusFilter);
  }

  void _promptAndShowMasterReport() => promptAndShowMasterReport(context, ref);
  void _openSearchAndCloneDialog() => SearchAndCloneImportFileDialog.show(context, ref);
  void _showCloneDialog(ImportFileModel file) => SearchAndCloneImportFileDialog.showCloneDialog(context, ref, file);

  void _showImportFileDetailsDialog(BuildContext context, ImportFileModel file) async {
    var poState = ref.read(purchaseOrdersProvider);
    if (poState.purchaseOrders.isEmpty) {
      await ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      poState = ref.read(purchaseOrdersProvider);
    }
    final linkedPOs = ImportFilePoLinker.getLinkedPOs(file: file, allPOs: poState.purchaseOrders);
    final metrics = ImportFilePoLinker.computeMetrics(file: file, linkedPOs: linkedPOs);
    final currentLocale = ref.read(localeProvider);
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: currentLocale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: ImportFileDetailsDialog(
          file: file,
          linkedPOs: linkedPOs,
          invoiceNumbers: metrics.invoices,
          totalPackingListCbm: metrics.cbm,
          totalPackingListWeight: metrics.weightKg,
          totalPackingListsCount: metrics.plCount,
          onEditPressed: () => _showAddEditFileDialog(file),
        ),
      ),
    );
  }

  void _showSmartReferenceDialog(BuildContext context, ImportFileModel file) {
    final linkedPOs = ImportFilePoLinker.getLinkedPOs(file: file, allPOs: ref.read(purchaseOrdersProvider).purchaseOrders);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850, maxHeight: 800),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isArabic ? 'المرجع الذكي للشحنة (Smart Reference)' : 'Shipment Smart Reference',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.cobalt),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: SmartShipmentReferenceCard(
                      importFileId: file.importFileId,
                      initialHsCode: file.hsCode,
                      initialCategory: file.productCategory,
                      initialPod: file.portOfDischarge,
                      initialSupplier: file.supplierName,
                      initialCarrier: file.selectedScenario,
                      linkedPOs: linkedPOs,
                      file: file,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
      _searchController.text = widget.initialSearchQuery!;
    }
    _highlightedFileId = widget.highlightedFileId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _screenFocusNode.requestFocus();
    });
    Future.microtask(() {
      final paginatedState = ref.read(paginatedImportFilesProvider);
      if (!paginatedState.isLoading) ref.read(paginatedImportFilesProvider.notifier).fetchPage(1);
      final companiesState = ref.read(importCompaniesProvider);
      if (companiesState is! AsyncLoading && (companiesState.value == null || companiesState.value!.isEmpty)) {
        ref.read(importCompaniesProvider.notifier).fetchCompanies();
      }
      final posState = ref.read(purchaseOrdersProvider);
      if (!posState.isLoading && posState.purchaseOrders.isEmpty) {
        ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      }
      final scenariosState = ref.read(shippingScenariosProvider);
      if (!scenariosState.isLoading && scenariosState.sessions.isEmpty) {
        ref.read(shippingScenariosProvider.notifier).fetchSessions();
      }
    });
  }

  @override
  void dispose() {
    _screenFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paginatedState = ref.watch(paginatedImportFilesProvider);
    final allPOs = ref.watch(purchaseOrdersProvider).purchaseOrders;
    final Map<int, List<PurchaseOrderModel>> linkedPOsCache = {};

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
          final items = ref.read(paginatedImportFilesProvider).items;
          if (items.isEmpty) return;
          if (_highlightedFileId != null) {
            final selected = items.firstWhere((f) => f.importFileId == _highlightedFileId, orElse: () => items.first);
            _showCloneDialog(selected);
          } else {
            _openSearchAndCloneDialog();
          }
        },
      },
      child: Focus(
        focusNode: _screenFocusNode,
        autofocus: true,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: PageHeader(
            icon: Icons.folder_special,
            title: l.importFilesManagementTitle,
            actions: [
              Builder(
                builder: (ctx) {
                  final isNarrow = MediaQuery.sizeOf(ctx).width < 768;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isNarrow)
                        SmartUploadButton(
                          module: SmartUploadModule.importFile,
                          label: l.uploadImportDocument,
                          onDataExtracted: (result) {
                            final fields = result.extractedFields;
                            AppTheme.snackBar(
                              context,
                              '${fields['commodity_description'] ?? fields['invoice_number'] ?? 'Extracted successfully'}',
                              severity: AppSeverity.success,
                            );
                          },
                        ),
                      if (!isNarrow) const SizedBox(width: 8),
                      if (!isNarrow) const BackToDashboardButton(),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: () => ref.read(paginatedImportFilesProvider.notifier).fetchPage(1),
                      ),
                      const SizedBox(width: 10),
                    ],
                  );
                },
              ),
            ],
          ),
          body: SelectionArea(
            child: LayoutBuilder(
              builder: (context, screenConstraints) {
                final isMobile = screenConstraints.maxWidth < AppTheme.tabletBreakpoint;
                return Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: isMobile ? 8 : 16,
                    end: isMobile ? 8 : 16,
                    top: isMobile ? 4 : 6,
                    bottom: 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Unified Compact Toolbar (Desktop & Mobile Modes)
                      ImportFilesCompactToolbar(
                        searchController: _searchController,
                        selectedStatusFilter: _selectedStatusFilter,
                        isMobile: isMobile,
                        onStatusFilterChanged: (val) {
                          setState(() => _selectedStatusFilter = val);
                          ref.read(paginatedImportFilesProvider.notifier).fetchPage(1, search: _searchController.text, status: val);
                        },
                        onSearchChanged: (val) {
                          ref.read(paginatedImportFilesProvider.notifier).fetchPage(1, search: val, status: _selectedStatusFilter);
                        },
                        onAddNew: () => _showAddEditFileDialog(),
                        onSearchAndClone: _openSearchAndCloneDialog,
                        onShowNotes: () => StageNotesCard.showAsDialog(context, screenCode: 'import_files', title: 'ملاحظات ومرفقات - ملفات الاستيراد'),
                        onGenerateMasterReport: _promptAndShowMasterReport,
                        onOpenSmartExtractor: () => showDialog(context: context, builder: (_) => const SmartInvoiceBLExtractorDialog()),
                        onOpenSimulator: () => showDialog(context: context, builder: (_) => const WhatIfSimulatorDialog()),
                        onImportExcel: () => ImportFilesExportHelper.importFromExcel(context, ref),
                        onCopyTsv: () => ImportFilesExportHelper.copyTableAsTsv(context, ref),
                        onRefresh: () => ref.read(paginatedImportFilesProvider.notifier).fetchPage(paginatedState.page),
                        onExportExcel: () => ImportFilesExportHelper.exportToExcel(context, ref),
                        onExportPdf: () => ImportFilesExportHelper.exportToPdf(context, ref),
                      ),
                      const SizedBox(height: 6),

                      // Files Data Table / Mobile List
                      Expanded(
                        child: paginatedState.isLoading
                            ? const ImportFilesTableShimmerSkeleton()
                            : paginatedState.error != null
                                ? Center(
                                    child: AppErrorState(
                                      error: paginatedState.error,
                                      compact: true,
                                      onRetry: () => ref.read(paginatedImportFilesProvider.notifier).fetchPage(paginatedState.page),
                                    ),
                                  )
                                : paginatedState.items.isEmpty
                                    ? Center(child: AppEmptyState(message: l.noImportFilesFound))
                                    : Card(
                                        elevation: isDark ? 0 : 2,
                                        margin: EdgeInsets.zero,
                                        color: isDark ? AppTheme.darkCardBackground : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(
                                              child: LayoutBuilder(
                                                builder: (context, constraints) {
                                                  if (constraints.maxWidth < 768) {
                                                    return ImportFilesMobileList(
                                                      items: paginatedState.items,
                                                      highlightedFileId: _highlightedFileId,
                                                      linkedPOsCache: linkedPOsCache,
                                                      allPOs: allPOs,
                                                      onViewDetails: (file) => _showImportFileDetailsDialog(context, file),
                                                      onEdit: (file) => _showAddEditFileDialog(file),
                                                      onClone: (file) => _showCloneDialog(file),
                                                      onSmartReference: (file) => _showSmartReferenceDialog(context, file),
                                                      onSmartChecklist: (file) => SmartChecklistDialog.show(context, file),
                                                      onStopShipment: (file) => StopShipmentDialog.show(context, importFile: file, currentPhaseName: file.currentModule, onSuccess: () => ref.read(paginatedImportFilesProvider.notifier).fetchPage(paginatedState.page)),
                                                      onReopenShipment: (file) => ReopenShipmentDialog.show(context, importFile: file, onSuccess: () => ref.read(paginatedImportFilesProvider.notifier).fetchPage(paginatedState.page)),
                                                      onOpenComprehensiveReport: (fileId) {
                                                        ref.read(selectedComprehensiveReportFileIdProvider.notifier).state = fileId;
                                                        selectNavigationIndex(ref, 47, tabTitle: 'تقرير الشحنة الشامل المدمج');
                                                      },
                                                    );
                                                  }
                                                  final density = ref.watch(displayDensityProvider);
                                                  const double tableTotalWidth = 215.0 + 160.0 + 180.0 + 180.0 + 190.0 + 150.0 + 105.0 + 110.0 + 160.0 + 110.0 + 170.0 + 140.0 + 110.0 + (20.0 * 12) + 32.0;
                                                  final isAr = Directionality.of(context) == TextDirection.rtl || ref.watch(localeProvider).languageCode == 'ar';

                                                  return EnterpriseDataTable<ImportFileModel>(
                                                    data: paginatedState.items,
                                                    storageKey: 'import_files_master_table',
                                                    isLoading: paginatedState.isLoading,
                                                    showHeaderToolbar: false,
                                                    showPagination: false,
                                                    isScrollable: true,
                                                    stickyHeader: true,
                                                    verticalScrollbarOnLeft: true,
                                                    minWidth: tableTotalWidth,
                                                    headerHeight: density.headerHeight,
                                                    rowHeight: density.rowHeight + 14,
                                                    columns: buildImportFilesTableColumns(
                                                      context: context,
                                                      ref: ref,
                                                      l: l,
                                                      isDark: isDark,
                                                      isAr: isAr,
                                                      density: density,
                                                      paginatedState: paginatedState,
                                                      linkedPOsCache: linkedPOsCache,
                                                      allPOs: allPOs,
                                                      onViewDetails: (file) => _showImportFileDetailsDialog(context, file),
                                                      onEdit: (file) => _showAddEditFileDialog(file),
                                                      onClone: (file) => _showCloneDialog(file),
                                                      onSmartReference: (file) => _showSmartReferenceDialog(context, file),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            // Compact Table Pagination Footer
                                            if (!paginatedState.isLoading && paginatedState.items.isNotEmpty)
                                              CompactTablePaginationFooter(
                                                currentPage: paginatedState.page,
                                                totalPages: paginatedState.totalPages,
                                                totalCount: paginatedState.total,
                                                pageSize: paginatedState.pageSize,
                                                isMobile: isMobile,
                                                onPageChanged: (newPage) => ref.read(paginatedImportFilesProvider.notifier).fetchPage(
                                                  newPage,
                                                  search: _searchController.text,
                                                  status: _selectedStatusFilter,
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
          ),
        ),
      ),
    );
  }
}
