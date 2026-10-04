import 'dart:math' as math;
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../widgets/po_form_dialog.dart';
import '../widgets/po_reconciliation_warning_dialog.dart';
import '../widgets/po_balance_ledger_dialog.dart';
import '../utils/po_packing_matcher.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';

import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/container_load_plan_painter.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/smart_upload_button.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/services/container_load_plan_export_service.dart';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/action_toolbar.dart';
import '../../../core/widgets/metric_card.dart';
import '../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../customs_tariff/widgets/hs_code_compliance_insight_card.dart';
import '../../import_files/models/import_file_model.dart' show ImportFileModel;
import '../../import_files/providers/import_files_provider.dart';
import '../../../core/performance/dispose_tracker.dart';
import '../../projects/providers/projects_provider.dart';
import '../../projects/models/project_model.dart';
import '../../../core/localization/locale_provider.dart';
import '../models/purchase_order_model.dart';
import '../providers/purchase_orders_provider.dart';
import '../../../core/widgets/table_row_clone_helper.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
class PurchaseOrdersScreen extends ConsumerStatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  ConsumerState<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends ConsumerState<PurchaseOrdersScreen> with DisposeTrackerMixin<PurchaseOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalTableScrollController = ScrollController();
  final ScrollController _verticalTableScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final poState = ref.read(purchaseOrdersProvider);
      if (!poState.isLoading) {
        ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      }
      final prjState = ref.read(projectsProvider);
      if (!prjState.isLoading) {
        ref.read(projectsProvider.notifier).fetchProjects();
      }
      final filesState = ref.read(importFilesProvider);
      if (!filesState.isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalTableScrollController.dispose();
    _verticalTableScrollController.dispose();
    super.dispose();
  }

  static String _formatWeight(double val) => PoPackingMatcher.formatWeight(val);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(purchaseOrdersProvider);
    final projectsList = ref.watch(projectsProvider).valueOrNull ?? [];

    final totalOrders = state.purchaseOrders.length;
    final totalFobSum = state.purchaseOrders.fold<double>(0.0, (sum, p) => sum + p.totalAmountFob);
    final totalCbmSum = state.purchaseOrders.fold<double>(0.0, (sum, p) => sum + p.totalCbm);
    final totalGrossSum = state.purchaseOrders.fold<double>(0.0, (sum, p) => sum + p.totalGrossWeightKg);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
          _openSearchAndCloneDialog();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: PageHeader(
            icon: Icons.shopping_cart_outlined,
            title: l.purchaseOrdersTitle,
            subtitle: l.purchaseOrdersSubtitle,
            actions: [
              Builder(
                builder: (ctx) {
                  final isNarrow = MediaQuery.sizeOf(ctx).width < 768;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isNarrow)
                        SmartUploadButton(
                          module: SmartUploadModule.purchaseOrder,
                          label: '🚀 ${l.smartInvoiceExtract}',
                          onDataExtracted: (result) {
                            final fields = result.extractedFields;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${fields['po_number'] ?? '-'}'),
                                backgroundColor: AppTheme.emerald,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                            _showPODialog(context, null, initialExtractedFields: fields);
                          },
                        ),
                      if (!isNarrow) const SizedBox(width: 8),
                      if (!isNarrow) const BackToDashboardButton(),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: () => ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders(),
                      ),
                      const SizedBox(width: 10),
                    ],
                  );
                },
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, screenConstraints) {
              final isMobile = screenConstraints.maxWidth < 768;
              if (isMobile) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSummaryMetrics(context, l, totalOrders, totalFobSum, totalCbmSum, totalGrossSum),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _buildDesktopCompactToolbar(context, isDark, l, state, projectsList),
                      ),
                      if (state.isLoading)
                        const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                      else if (state.errorMessage != null)
                        _buildErrorView(l, state.errorMessage!)
                      else if (state.purchaseOrders.isEmpty)
                        _buildEmptyView(l)
                      else
                        _buildMobilePOCardsList(
                          context,
                          state.purchaseOrders,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                        ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryMetrics(context, l, totalOrders, totalFobSum, totalCbmSum, totalGrossSum),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildDesktopCompactToolbar(context, isDark, l, state, projectsList),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: state.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : state.errorMessage != null
                            ? _buildErrorView(l, state.errorMessage!)
                            : state.purchaseOrders.isEmpty
                                ? _buildEmptyView(l)
                                : _buildPOTable(context, state.purchaseOrders),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMetrics(
    BuildContext context,
    AppLocalizations l,
    int totalOrders,
    double totalFobSum,
    double totalCbmSum,
    double totalGrossSum,
  ) {
    return MetricCardStrip(
      metrics: [
        MetricCardData(
          title: l.totalOrdersMetric,
          shortTitle: 'POs',
          value: '$totalOrders',
          icon: Icons.receipt_long,
          color: AppTheme.wcagCobalt,
        ),
        MetricCardData(
          title: l.totalFobMetric,
          shortTitle: 'PI/PO Amt',
          value: '\$${totalFobSum.toStringAsFixed(2)}',
          icon: Icons.attach_money,
          color: AppTheme.wcagEmerald,
        ),
        MetricCardData(
          title: l.totalCargoCbmMetric,
          shortTitle: 'CBM',
          value: '${totalCbmSum.toStringAsFixed(2)} m³',
          icon: Icons.view_in_ar,
          color: AppTheme.wcagOrange,
        ),
        MetricCardData(
          title: l.totalGrossWeightMetric,
          shortTitle: 'Gross Wt',
          value: '${_formatWeight(totalGrossSum)} kg',
          icon: Icons.scale,
          color: Colors.purple,
        ),
      ],
    );
  }

  Future<void> _downloadPOFile(String actionEndpoint, String defaultFileName, String dialogTitle) async {
    final url = '${ApiConstants.purchaseOrders}/$actionEndpoint';
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data != null && response.data is List<int>) {
        if (!mounted) return;
        await FileSaveHelper.saveBytes(
          context: context,
          bytes: response.data as List<int>,
          defaultFileName: defaultFileName,
          dialogTitle: dialogTitle,
          allowedExtensions: defaultFileName.endsWith('.pdf') ? ['pdf'] : ['xlsx', 'csv'],
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.errorPrefix}: $e'),
          backgroundColor: AppTheme.crimson,
        ),
      );
    }
  }

  Future<void> _handleImportExcel() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
      });
      final res = await dio.post(
        '${ApiConstants.purchaseOrders}/import-excel',
        data: formData,
      );
      if (!mounted) return;
      ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.data?['message'] ?? (isArabic ? 'تم الاستيراد بنجاح' : 'Imported successfully')),
          backgroundColor: AppTheme.emerald,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.errorPrefix}: $e'),
          backgroundColor: AppTheme.crimson,
        ),
      );
    }
  }

  void _copyPOTableTsv(List<PurchaseOrderModel> orders) {
    final l = context.l10n;
    final isArabic = Directionality.of(context) == TextDirection.rtl ||
        ref.read(localeProvider).languageCode == 'ar';
    final List<String> headers = [
      l.poReferenceCol,
      l.foreignSupplier,
      l.projectsAndCostCenters,
      l.totalFobMetric,
      l.totalCargoCbmMetric,
      l.totalGrossWeightMetric,
      l.statusCol,
    ];
    final rows = orders.map((po) => [
      po.poNumber,
      po.supplierName,
      po.projectName ?? '-',
      po.totalAmountFob.toStringAsFixed(2),
      '${po.totalCbm.toStringAsFixed(2)} m³',
      '${po.totalGrossWeightKg.toStringAsFixed(1)} kg',
      _getStatusLabel(po.status, l),
    ]).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: isArabic ? 'تم نسخ بيانات أوامر الشراء بنجاح' : 'PO table copied to clipboard',
    );
  }

  Widget _buildDesktopCompactToolbar(
    BuildContext context,
    bool isDark,
    AppLocalizations l,
    PurchaseOrdersState state,
    List<ProjectModel> projectsList,
  ) {
    final density = ref.watch(displayDensityProvider);
    final isArabic = Directionality.of(context) == TextDirection.rtl ||
        ref.watch(localeProvider).languageCode == 'ar';

    return ActionToolbar(
      primaryActions: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.wcagCobalt,
            foregroundColor: Colors.white,
            minimumSize: Size(0, density.buttonHeight),
            padding: density.buttonPadding,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: Icon(Icons.add_shopping_cart, size: density.buttonIconSize),
          label: Text(
            l.newPurchaseOrder,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
          ),
          onPressed: () => _showPODialog(context, null),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
            side: BorderSide(color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt),
            minimumSize: Size(0, density.buttonHeight),
            padding: density.buttonPadding,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: Icon(Icons.control_point_duplicate_rounded, size: density.buttonIconSize),
          label: Text(
            l.searchAndClonePoBtn,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
          ),
          onPressed: _openSearchAndCloneDialog,
        ),
      ],
      moreActionItems: [
        PopupMenuItem(
          value: 'export_excel',
          child: Row(
            children: [
              const Icon(Icons.table_view_rounded, color: AppTheme.wcagEmerald, size: 16),
              const SizedBox(width: 8),
              Text(l.exportExcel, style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export_pdf',
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson, size: 16),
              const SizedBox(width: 8),
              Text(l.exportPdf, style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copy_tsv',
          child: Row(
            children: [
              const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 16),
              const SizedBox(width: 8),
              Text(isArabic ? 'نسخ الجدول (TSV)' : 'Copy Table (TSV)', style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'download_template',
          child: Row(
            children: [
              const Icon(Icons.file_download_outlined, color: Colors.blueGrey, size: 16),
              const SizedBox(width: 8),
              Text(isArabic ? 'تنزيل نموذج إكسل' : 'Download Template', style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'import_excel',
          child: Row(
            children: [
              const Icon(Icons.upload_file, color: Colors.blueGrey, size: 16),
              const SizedBox(width: 8),
              Text(isArabic ? 'استيراد من إكسل' : 'Import Excel', style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
      ],
      onMoreActionSelected: (val) {
        switch (val) {
          case 'export_excel':
            _downloadPOFile('export-excel', 'Purchase_Orders.xlsx', isArabic ? 'تصدير أوامر الشراء إكسيل' : 'Export Purchase Orders Excel');
            break;
          case 'export_pdf':
            _downloadPOFile('export-pdf', 'Purchase_Orders.pdf', isArabic ? 'تصدير أوامر الشراء PDF' : 'Export Purchase Orders PDF');
            break;
          case 'copy_tsv':
            _copyPOTableTsv(state.purchaseOrders);
            break;
          case 'download_template':
            _downloadPOFile('template', 'Purchase_Orders_Template.xlsx', isArabic ? 'تنزيل نموذج أوامر الشراء' : 'Download Purchase Orders Template');
            break;
          case 'import_excel':
            _handleImportExcel();
            break;
        }
      },
      searchController: _searchController,
      searchHint: l.searchByPoHint,
      onSearchChanged: (v) => ref.read(purchaseOrdersProvider.notifier).setSearchQuery(v),
      filters: [
        SizedBox(
          width: 140,
          height: density.buttonHeight,
          child: SearchableDropdownField<int?>(
            value: state.projectFilter,
            labelText: '',
            decoration: InputDecoration(
              hintText: l.filterByProject,
              hintStyle: TextStyle(fontSize: density.buttonFontSize - 1),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              filled: true,
              fillColor: isDark ? AppTheme.darkInputBackground : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              ),
            ),
            items: [
              SearchableDropdownItem<int?>(value: null, label: l.allProjects),
              ...projectsList.map((p) => SearchableDropdownItem<int?>(
                    value: p.projectId,
                    label: '${p.projectCode} - ${p.projectName}',
                  )),
            ],
            onChanged: (v) => ref.read(purchaseOrdersProvider.notifier).setProjectFilter(v),
          ),
        ),
        SizedBox(
          width: 120,
          height: density.buttonHeight,
          child: SearchableDropdownField<String?>(
            value: state.statusFilter,
            labelText: '',
            decoration: InputDecoration(
              hintText: l.filterByStatus,
              hintStyle: TextStyle(fontSize: density.buttonFontSize - 1),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              filled: true,
              fillColor: isDark ? AppTheme.darkInputBackground : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              ),
            ),
            items: [
              SearchableDropdownItem<String?>(value: null, label: l.allStatuses),
              SearchableDropdownItem<String?>(value: 'Draft', label: l.statusDraft),
              SearchableDropdownItem<String?>(value: 'Approved', label: l.statusPoApproved),
              SearchableDropdownItem<String?>(value: 'In Transit', label: l.statusInTransit),
              SearchableDropdownItem<String?>(value: 'Closed', label: l.statusClosed),
            ],
            onChanged: (v) => ref.read(purchaseOrdersProvider.notifier).setStatusFilter(v),
          ),
        ),
      ],
      quickDataActions: [
        IconButton(
          icon: Icon(Icons.refresh, color: AppTheme.wcagCobalt, size: density.buttonIconSize + 2),
          tooltip: l.liveReload,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: density.buttonHeight, minHeight: density.buttonHeight),
          onPressed: () => ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders(),
        ),
      ],
    );
  }

  Widget _buildErrorView(AppLocalizations l, String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.crimson),
            const SizedBox(height: 12),
            Text(errorMessage, style: const TextStyle(color: AppTheme.crimson)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders(),
              child: Text(l.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(AppLocalizations l) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(l.noDataFound, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  String _getStatusLabel(String status, AppLocalizations l) {
    switch (status.trim().toLowerCase()) {
      case 'draft':
        return l.statusDraft;
      case 'approved':
        return l.statusPoApproved;
      case 'in transit':
        return l.statusInTransit;
      case 'closed':
        return l.statusClosed;
      default:
        return status;
    }
  }

  Widget _buildPOTable(BuildContext context, List<PurchaseOrderModel> orders) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final density = ref.watch(displayDensityProvider);
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    final Map<int, ImportFileModel> filesById = {};
    final Map<String, ImportFileModel> filesByCode = {};
    for (final f in importFiles) {
      filesById[f.importFileId] = f;
      filesByCode[f.importFileCode] = f;
    }

    final tableScrollbarTheme = ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(
        isDark ? AppTheme.wcagCobalt.withOpacity(0.8) : AppTheme.charcoal.withOpacity(0.6),
      ),
      trackColor: WidgetStateProperty.all(
        isDark ? AppTheme.darkBorder.withOpacity(0.4) : Colors.grey.shade300,
      ),
      trackBorderColor: WidgetStateProperty.all(Colors.transparent),
      thickness: WidgetStateProperty.all(10.0),
      radius: const Radius.circular(5),
    );

    // Fixed column widths for 1:1 pixel-perfect alignment between sticky header and scrolling body
    const double colActionsWidth = 230.0;
    const double colPoRefWidth = 170.0;
    const double colInvoiceDateWidth = 110.0;
    const double colImportFileWidth = 180.0;
    const double colPiNumberWidth = 140.0;
    const double colProjectsWidth = 180.0;
    const double colCompanyWidth = 180.0;
    const double colSupplierWidth = 190.0;
    const double colTotalFobWidth = 150.0;
    const double colCbmWeightWidth = 170.0;
    const double colLifecycleWidth = 120.0;

    const double tableTotalWidth = colActionsWidth +
        colPoRefWidth +
        colInvoiceDateWidth +
        colImportFileWidth +
        colPiNumberWidth +
        colProjectsWidth +
        colCompanyWidth +
        colSupplierWidth +
        colTotalFobWidth +
        colCbmWeightWidth +
        colLifecycleWidth +
        (18.0 * 10) +
        32.0;

    final headerColumns = [
      DataColumn(label: SizedBox(width: colActionsWidth, child: Text(l.actionsCol, style: const TextStyle(fontWeight: FontWeight.bold)))),
      DataColumn(label: SizedBox(width: colPoRefWidth, child: Text(l.poReferenceCol, style: const TextStyle(fontWeight: FontWeight.bold)))),
      DataColumn(label: SizedBox(width: colInvoiceDateWidth, child: Text(l.invoiceDateCol, style: const TextStyle(fontWeight: FontWeight.bold)))),
      DataColumn(label: SizedBox(width: colImportFileWidth, child: Text(l.importFileCol, style: const TextStyle(fontWeight: FontWeight.bold)))),
      DataColumn(label: SizedBox(width: colPiNumberWidth, child: Text(l.piNumberCol, style: const TextStyle(fontWeight: FontWeight.bold)))),
      DataColumn(label: SizedBox(width: colProjectsWidth, child: Text(l.projectsAndCostCenters, style: const TextStyle(fontWeight: FontWeight.bold)))),
      DataColumn(label: SizedBox(width: colCompanyWidth, child: Text(l.importingCompany, style: const TextStyle(fontWeight: FontWeight.bold)))),
      DataColumn(label: SizedBox(width: colSupplierWidth, child: Text(l.foreignSupplier, style: const TextStyle(fontWeight: FontWeight.bold)))),
      DataColumn(label: SizedBox(width: colTotalFobWidth, child: Text(l.totalFobMetric, style: const TextStyle(fontWeight: FontWeight.bold)))),
      DataColumn(label: SizedBox(width: colCbmWeightWidth, child: Text(l.cbmAndGrossWeightCol, style: const TextStyle(fontWeight: FontWeight.bold)))),
      DataColumn(label: SizedBox(width: colLifecycleWidth, child: Text(l.lifecycleBoard, style: const TextStyle(fontWeight: FontWeight.bold)))),
    ];

    final dummyBodyColumns = [
      const DataColumn(label: SizedBox(width: colActionsWidth)),
      const DataColumn(label: SizedBox(width: colPoRefWidth)),
      const DataColumn(label: SizedBox(width: colInvoiceDateWidth)),
      const DataColumn(label: SizedBox(width: colImportFileWidth)),
      const DataColumn(label: SizedBox(width: colPiNumberWidth)),
      const DataColumn(label: SizedBox(width: colProjectsWidth)),
      const DataColumn(label: SizedBox(width: colCompanyWidth)),
      const DataColumn(label: SizedBox(width: colSupplierWidth)),
      const DataColumn(label: SizedBox(width: colTotalFobWidth)),
      const DataColumn(label: SizedBox(width: colCbmWeightWidth)),
      const DataColumn(label: SizedBox(width: colLifecycleWidth)),
    ];

    return LayoutBuilder(
      builder: (context, tableConstraints) {
        return ScrollbarTheme(
          data: tableScrollbarTheme,
          child: Scrollbar(
            controller: _horizontalTableScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalTableScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableTotalWidth,
                height: tableConstraints.maxHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 1. Sticky Header Row (Pinned at Top) ──────────────
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.charcoal,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: DataTable(
                        columnSpacing: 18,
                        horizontalMargin: 16,
                        headingRowHeight: density.headerHeight,
                        dataRowMinHeight: 0,
                        dataRowMaxHeight: 0,
                        headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkSurface : AppTheme.charcoal),
                        headingTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: density.tableHeaderFontSize),
                        columns: headerColumns,
                        rows: const [],
                      ),
                    ),

                    // ── 2. Dedicated Scrollable Table Body ──────────────
                    Expanded(
                      child: ScrollbarTheme(
                        data: tableScrollbarTheme,
                        child: Scrollbar(
                          controller: _verticalTableScrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          child: SingleChildScrollView(
                            controller: _verticalTableScrollController,
                            scrollDirection: Axis.vertical,
                            child: DataTable(
                              columnSpacing: 18,
                              horizontalMargin: 16,
                              headingRowHeight: 0,
                              dataRowMinHeight: density.rowHeight,
                              dataRowMaxHeight: density.rowHeight + 4,
                              dataTextStyle: TextStyle(
                                fontSize: density.tableCellPrimaryFontSize,
                                color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                              ),
                              columns: dummyBodyColumns,
                              rows: orders.map((po) {
                final statusColor = po.status == 'Approved'
                    ? AppTheme.wcagEmerald
                    : po.status == 'In Transit'
                        ? AppTheme.wcagCobalt
                        : po.status == 'Closed'
                            ? (isDark ? const Color(0xFF64748B) : Colors.grey.shade600)
                            : AppTheme.wcagOrange;

                final invoiceDateStr = po.orderDate != null
                    ? '${po.orderDate!.year}-${po.orderDate!.month.toString().padLeft(2, '0')}-${po.orderDate!.day.toString().padLeft(2, '0')}'
                    : '-';

                final matchedFile = (po.importFileId != null ? filesById[po.importFileId] : null) ??
                    (po.importFileCode != null ? filesByCode[po.importFileCode] : null);
                final fileName = matchedFile?.displayName ?? po.importFileCode ?? (po.importFileId != null ? 'IMP-${po.importFileId}' : '-');
                final fileCode = (matchedFile != null && matchedFile.displayName != matchedFile.importFileCode)
                    ? matchedFile.importFileCode
                    : (po.importFileCode ?? (po.importFileId != null ? 'IMP-${po.importFileId}' : ''));
                final amountStr = '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}';
                final cbmWeightStr = '${po.totalCbm.toStringAsFixed(2)} m³ / ${_formatWeight(po.totalGrossWeightKg)} kg';
                final localizedStatus = _getStatusLabel(po.status, l);

                final rowSummary = [
                  po.displayName,
                  invoiceDateStr,
                  fileName,
                  po.proformaInvoiceNumber ?? '-',
                  po.projectName ?? 'PRJ-#${po.projectId}',
                  po.companyName ?? 'COMP-#${po.companyId}',
                  po.supplierName ?? 'SUP-#${po.supplierId}',
                  amountStr,
                  cbmWeightStr,
                  localizedStatus,
                ].join('\t');

                return DataRow(
                  onSelectChanged: (_) => _showPODetailsDialog(context, po),
                  cells: [
                    DataCell(
                      SizedBox(
                        width: colActionsWidth,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (po.poId != null)
                              IconButton(
                                icon: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.cobalt, size: 20),
                                tooltip: l.poBalanceLedgerTooltip,
                                onPressed: () => showPOBalanceLedgerDialog(
                                  context,
                                  ref,
                                  poId: po.poId!,
                                  poCode: po.poNumber,
                                ),
                              ),
                            RowActionsPill(
                              onView: () => _showPODetailsDialog(context, po),
                              onEdit: () => _showPODialog(context, po),
                              onClone: () => _showCloneDialog(po),
                              cloneTooltip: l.cloneRowTooltip,
                              onPrint: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l.printPoAndPackingList(po.displayName, po.poNumber)),
                                    backgroundColor: AppTheme.charcoal,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              onDelete: () async {
                                final isActive = po.isActive;
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(l.confirmActionTitle),
                                    content: Text(isActive
                                        ? l.confirmDeactivatePo(po.displayName)
                                        : l.confirmRestorePo(po.displayName)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: isActive ? AppTheme.crimson : AppTheme.cobalt),
                                        child: Text(isActive ? l.deactivateBtn : l.restore, style: const TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  if (po.isActive) {
                                    await ref.read(purchaseOrdersProvider.notifier).deletePurchaseOrder(po.poId!);
                                  } else {
                                    await ref.read(purchaseOrdersProvider.notifier).restorePurchaseOrder(po.poId!);
                                  }
                                }
                              },
                              deleteTooltip: po.isActive ? l.deactivatePoTooltip : l.restorePoTooltip,
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: colPoRefWidth,
                        child: CopyableTableCell(
                          value: po.displayName,
                          rowSummary: rowSummary,
                          child: InkWell(
                            onTap: () => _showPODetailsDialog(context, po),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        po.displayName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.cobalt,
                                          fontSize: density.tableCellPrimaryFontSize,
                                          decoration: TextDecoration.underline,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.open_in_new, size: 14, color: AppTheme.cobalt),
                                  ],
                                ),
                                if (po.poReference != null && po.poReference!.isNotEmpty && po.poReference != po.poNumber)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: LtrText(
                                      po.poNumber,
                                      style: TextStyle(fontSize: density.tableCellSecondaryFontSize, color: Colors.blueGrey.shade700, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: colInvoiceDateWidth,
                        child: CopyableTableCell(
                          value: invoiceDateStr,
                          rowSummary: rowSummary,
                          child: Text(invoiceDateStr, style: TextStyle(fontWeight: FontWeight.w600, fontSize: density.tableCellPrimaryFontSize)),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: colImportFileWidth,
                        child: CopyableTableCell(
                          value: fileName,
                          rowSummary: rowSummary,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.cobalt.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
                                ),
                                child: Text(
                                  fileName,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: density.tableCellPrimaryFontSize),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (fileCode.isNotEmpty && fileCode != fileName)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(top: 2, end: 4, start: 4),
                                  child: LtrText(
                                    fileCode,
                                    style: TextStyle(fontSize: density.tableCellSecondaryFontSize, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: colPiNumberWidth,
                        child: CopyableTableCell(
                          value: po.proformaInvoiceNumber ?? '-',
                          rowSummary: rowSummary,
                          child: Text(po.proformaInvoiceNumber ?? '-', overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: colProjectsWidth,
                        child: CopyableTableCell(
                          value: po.projectName ?? 'PRJ-#${po.projectId}',
                          rowSummary: rowSummary,
                          child: Text(po.projectName ?? 'PRJ-#${po.projectId}', overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: colCompanyWidth,
                        child: CopyableTableCell(
                          value: po.companyName ?? 'COMP-#${po.companyId}',
                          rowSummary: rowSummary,
                          child: Text(po.companyName ?? 'COMP-#${po.companyId}', overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: colSupplierWidth,
                        child: CopyableTableCell(
                          value: po.supplierName ?? 'SUP-#${po.supplierId}',
                          rowSummary: rowSummary,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(po.supplierName ?? 'SUP-#${po.supplierId}', overflow: TextOverflow.ellipsis),
                              if (po.countryOfOrigin != null && po.countryOfOrigin!.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Text(
                                    po.countryOfOrigin!,
                                    style: TextStyle(fontSize: density.tableCellSecondaryFontSize, color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: colTotalFobWidth,
                        child: CopyableTableCell(
                          value: amountStr,
                          rowSummary: rowSummary,
                          child: Text(
                            amountStr,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.tableCellPrimaryFontSize, color: isDark ? AppTheme.wcagEmerald : Colors.green.shade800),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: colCbmWeightWidth,
                        child: CopyableTableCell(
                          value: cbmWeightStr,
                          rowSummary: rowSummary,
                          child: Text(cbmWeightStr, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: colLifecycleWidth,
                        child: CopyableTableCell(
                          value: localizedStatus,
                          rowSummary: rowSummary,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor),
                            ),
                            child: Text(
                              localizedStatus,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: density.tableCellSecondaryFontSize),
                              overflow: TextOverflow.ellipsis,
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
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPODetailsDialog(BuildContext context, PurchaseOrderModel po) {
    final tariffs = ref.read(customsTariffProvider).valueOrNull ?? [];
    if (tariffs.isEmpty) {
      ref.read(customsTariffProvider.notifier).fetchTariffs();
    }
    final reconciliation = evaluatePOReconciliation(
      invoiceItems: po.items,
      packingItems: po.packingListItems,
      tariffs: tariffs,
    );
    final Set<String> mismatchedHsCodes = reconciliation.items
        .where((item) => !item.isMatched || item.isMissingInPacking || item.isMissingInInvoice)
        .map((item) => item.hsCode)
        .toSet();

    // Group packing list items by HS Code for the HS Summary Report
    final Map<String, Map<String, dynamic>> hsSummaryMap = {};
    for (final p in po.packingListItems) {
      final hs = p.hsCode.isNotEmpty ? p.hsCode : 'UNSPECIFIED';
      if (!hsSummaryMap.containsKey(hs)) {
        hsSummaryMap[hs] = {
          'hs_code': hs,
          'qty_pcs': 0.0,
          'qty_pkg': 0.0,
          'total_net': 0.0,
          'total_gross': 0.0,
          'total_cbm': 0.0,
        };
      }
      final double itemNet = (p.netWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.netWeightUnitKg) : p.totalNetWeightKg;
      final double itemGross = (p.grossWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.grossWeightUnitKg) : p.totalGrossWeightKg;
      final double itemCbm = p.calculatedCbm > 0 ? p.calculatedCbm : p.totalCbm;
      hsSummaryMap[hs]!['qty_pcs'] += p.qtyPcs;
      hsSummaryMap[hs]!['qty_pkg'] += p.qtyPkg;
      hsSummaryMap[hs]!['total_net'] += itemNet;
      hsSummaryMap[hs]!['total_gross'] += itemGross;
      hsSummaryMap[hs]!['total_cbm'] += itemCbm;
    }

    final bool isPalletized = (po.palletPlanItems.isNotEmpty && po.palletPlanItems.any((p) => p.palletCount > 0)) || po.palletCount > 0;

    final resolvedPoItems = PoPackingMatcher.resolvePoItemMetrics(
      items: po.items,
      packingListItems: po.packingListItems,
      isPalletized: isPalletized,
      tariffs: tariffs,
    );

    // Group PO Line Items by HS Code for PO Items HS Summary Report
    final Map<String, Map<String, dynamic>> poHsSummaryMap = PoPackingMatcher.buildPoHsSummaryMap(resolvedPoItems);

    // Group Packing List Items by Package Type for Summary By Package Type Report
    final Map<String, Map<String, dynamic>> packageTypeSummaryMap = PoPackingMatcher.buildPackingTypeSummaryMap(po.packingListItems);



    // Validation checks
    final List<String> validationErrors = [];
    final List<String> validationWarnings = [];
    for (int i = 0; i < po.packingListItems.length; i++) {
      final item = po.packingListItems[i];
      if (item.grossWeightUnitKg < item.netWeightUnitKg) {
        validationErrors.add('Item #${i + 1} (${item.itemCode}): Gross weight (${item.grossWeightUnitKg} kg) < Net weight (${item.netWeightUnitKg} kg)');
      }
      if (item.lengthCm <= 0 || item.widthCm <= 0 || item.heightCm <= 0) {
        validationWarnings.add('Item #${i + 1} (${item.itemCode}): Missing package dimensions; CBM calculated from unit specs.');
      }
    }

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final l = dialogCtx.l10n;
        final isArabic = Localizations.localeOf(dialogCtx).languageCode == 'ar';
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return SelectionArea(
          child: DefaultTabController(
            length: 3,
            child: AlertDialog(
            backgroundColor: isDark ? AppTheme.darkSurface : null,
            title: Row(
              children: [
                const Icon(Icons.inventory_2, color: AppTheme.cobalt),
                const SizedBox(width: 8),
                Text(
                  '${l.purchaseOrdersTitle}: ${po.displayName}',
                  style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: SizedBox(
              width: math.min(1180.0, MediaQuery.of(dialogCtx).size.width - 32),
              height: math.min(780.0, MediaQuery.of(dialogCtx).size.height - 48),
              child: Column(
                children: [
                  Container(
                    color: isDark ? AppTheme.darkCardBackground : Colors.grey.shade100,
                    child: TabBar(
                      labelColor: AppTheme.cobalt,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: AppTheme.cobalt,
                      tabs: [
                        Tab(icon: const Icon(Icons.receipt_long, size: 18), text: l.poLineItemsTab),
                        Tab(icon: const Icon(Icons.fact_check, size: 18), text: l.reviewPackingListTab),
                        Tab(icon: const Icon(Icons.view_in_ar_rounded, size: 18), text: l.containerLoadPlan3dTitle),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: Commercial PO Line Items
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Builder(builder: (context) {
                              final double palletPlanCbm = po.palletPlanItems.isNotEmpty
                                  ? po.palletPlanItems.fold<double>(
                                      0.0,
                                      (sum, p) => sum + (p.calculatedCbm > 0 ? p.calculatedCbm : (p.lengthCm * p.widthCm * p.heightCm / 1000000.0) * p.palletCount),
                                    )
                                  : (po.palletCount > 0 && po.palletLengthCm > 0 && po.palletWidthCm > 0 && po.palletHeightCm > 0
                                      ? (po.palletLengthCm * po.palletWidthCm * po.palletHeightCm / 1000000.0) * po.palletCount
                                      : (po.palletCount > 0 && po.totalCbm > 0 ? po.totalCbm : 0.0));
                              final double palletPlanGrossWeight = po.palletPlanItems.isNotEmpty
                                  ? po.palletPlanItems.fold<double>(
                                      0.0,
                                      (sum, p) => sum + (p.grossWeightPerPalletKg * p.palletCount),
                                    )
                                  : (po.palletCount > 0 && po.totalGrossWeightKg > 0 ? po.totalGrossWeightKg : 0.0);
                              final int totalPalletCount = po.palletPlanItems.isNotEmpty
                                  ? po.palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount)
                                  : po.palletCount;

                              final double effectivePackingListCbm = palletPlanCbm > 0
                                  ? palletPlanCbm
                                  : (po.totalCbm > 0
                                      ? po.totalCbm
                                      : (po.packingListItems.isNotEmpty
                                          ? po.packingListItems.fold(0.0, (sum, pl) => sum + (pl.calculatedCbm > 0 ? pl.calculatedCbm : pl.totalCbm))
                                          : 0.0));
                              final double effectivePackingListGrossWeight = palletPlanGrossWeight > 0
                                  ? palletPlanGrossWeight
                                  : (po.totalGrossWeightKg > 0
                                      ? po.totalGrossWeightKg
                                      : (po.packingListItems.isNotEmpty
                                          ? po.packingListItems.fold(0.0, (sum, pl) => sum + ((pl.grossWeightUnitKg > 0 && pl.qtyPkg > 0) ? (pl.grossWeightUnitKg * pl.qtyPkg) : pl.totalGrossWeightKg))
                                          : 0.0));
                              final double effectivePackingListNetWeight = po.totalNetWeightKg > 0
                                  ? po.totalNetWeightKg
                                  : (po.packingListItems.isNotEmpty
                                      ? po.packingListItems.fold(0.0, (sum, pl) => sum + ((pl.netWeightUnitKg > 0 && pl.qtyPkg > 0) ? (pl.netWeightUnitKg * pl.qtyPkg) : pl.totalNetWeightKg))
                                      : 0.0);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 20,
                                    runSpacing: 10,
                                    children: [
                                      _buildDetailItem(l.projectsAndCostCenters, po.projectName ?? '-', isDark: isDark),
                                      _buildDetailItem(l.importingCompany, po.companyName ?? '-', isDark: isDark),
                                      _buildDetailItem(l.foreignSupplier, po.supplierName ?? '-', isDark: isDark),
                                      _buildDetailItem(l.countryOfOriginCol, po.countryOfOrigin ?? '-', isDark: isDark),
                                      _buildDetailItem(l.incotermsRules, po.incotermCode ?? '-', isDark: isDark),
                                      _buildDetailItem(l.currency, '${po.currencyCode ?? "USD"} (${l.exchangeRateLabel}: ${po.exchangeRate})', isDark: isDark),
                                      _buildDetailItem(
                                        isArabic ? 'تاريخ الفاتورة (Invoice Date)' : 'Invoice Date',
                                        po.orderDate != null
                                            ? "${po.orderDate!.year}-${po.orderDate!.month.toString().padLeft(2, '0')}-${po.orderDate!.day.toString().padLeft(2, '0')}"
                                            : '-',
                                        isDark: isDark,
                                      ),
                                      _buildDetailItem(
                                        isArabic ? 'وحدة الكمية (Qty Unit)' : 'Qty Unit',
                                        po.items.isNotEmpty ? po.items.first.unitOfMeasure : 'PCS',
                                        isDark: isDark,
                                      ),
                                      _buildDetailItem(l.paymentTermsLabel, po.paymentTerms ?? '-', isDark: isDark),
                                      _buildDetailItem(l.totalFobMetric, '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}', isDark: isDark),
                                      _buildDetailItem(
                                        l.totalCargoCbmMetric,
                                        '${effectivePackingListCbm.toStringAsFixed(3)} m³${totalPalletCount > 0 ? " ($totalPalletCount)" : ""}',
                                        isDark: isDark,
                                      ),
                                      _buildDetailItem(
                                        l.grossWeightMetric,
                                        '${_formatWeight(effectivePackingListGrossWeight)} kg',
                                        isDark: isDark,
                                      ),
                                      _buildDetailItem(
                                        l.netWeightMetric,
                                        '${_formatWeight(effectivePackingListNetWeight)} kg',
                                        isDark: isDark,
                                      ),
                                      _buildDetailItem(
                                        isArabic ? 'إجمالي الطرود (Total Qty PKG)' : 'Total Qty PKG',
                                        PoPackingMatcher.formatPackagingSummary(
                                          packingListItems: po.packingListItems,
                                          totalPalletCount: totalPalletCount,
                                          isArabic: isArabic,
                                        ),
                                        isDark: isDark,
                                      ),
                                    ],
                                  ),

                                const SizedBox(height: 16),
                                Text(l.poLineItemsBreakdown, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                                const SizedBox(height: 6),
                                SelectionArea(
                                  child: Table(
                                    border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                                    columnWidths: const {
                                      0: FlexColumnWidth(1.0),
                                      1: FlexColumnWidth(1.5),
                                      2: FlexColumnWidth(2.0),
                                      3: FlexColumnWidth(0.9),
                                      4: FlexColumnWidth(0.8),
                                      5: FlexColumnWidth(1.2),
                                      6: FlexColumnWidth(1.0),
                                      7: FlexColumnWidth(1.1),
                                      8: FlexColumnWidth(1.0),
                                      9: FlexColumnWidth(1.0),
                                      10: FlexColumnWidth(1.1),
                                      11: FixedColumnWidth(40),
                                    },
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                                        children: [
                                          Padding(padding: const EdgeInsets.all(6), child: Text(l.itemCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(l.mainDescription, style: const TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(l.descriptionAndHsCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(l.qtyUom, style: const TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'عدد الطرود' : 'Qty PKG', style: const TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'نوع التغليف' : 'Package Type', style: const TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(l.unitPrice, style: const TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(l.lineTotal, style: const TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'الصافي (كجم)' : 'Net Wt', style: const TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'القائم (كجم)' : 'Gross Wt', style: const TextStyle(fontWeight: FontWeight.bold))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(l.volumeCbmPackingList, style: const TextStyle(fontWeight: FontWeight.bold))),
                                          const Padding(
                                            padding: EdgeInsets.all(6),
                                            child: Center(
                                              child: Icon(Icons.copy_rounded, size: 14, color: AppTheme.cobalt),
                                            ),
                                          ),
                                        ],
                                      ),
                                      ...resolvedPoItems.map(
                                        (resolved) {
                                          final item = resolved.item;
                                          final double itemCbm = resolved.cbm;
                                          final double itemNet = resolved.netWeightKg;
                                          final double itemGross = resolved.grossWeightKg;
                                          final int itemPkg = resolved.qtyPkg;
                                          final itemHs = resolved.effectiveHsCode != 'UNSPECIFIED' ? resolved.effectiveHsCode : null;
                                          final isMismatched = itemHs != null && itemHs.isNotEmpty && mismatchedHsCodes.contains(itemHs);

                                          return TableRow(
                                            decoration: isMismatched ? BoxDecoration(color: Colors.red.shade50.withOpacity(0.3)) : null,
                                            children: [
                                              Padding(padding: const EdgeInsets.all(6), child: Text(item.itemCode ?? '-')),
                                              Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Text(
                                                  item.mainDescription?.isNotEmpty == true ? item.mainDescription! : '-',
                                                  style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(item.descriptionAr, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                    if (item.countryOfOrigin != null && item.countryOfOrigin!.isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 2),
                                                        child: Text(l.itemOriginLabel(item.countryOfOrigin!), style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                                      ),
                                                    if (itemHs != null && itemHs.isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 4),
                                                        child: isMismatched
                                                            ? Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.red.shade50,
                                                                  borderRadius: BorderRadius.circular(4),
                                                                  border: Border.all(color: Colors.red.shade400, width: 1.2),
                                                                ),
                                                                child: Wrap(
                                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                                  spacing: 4,
                                                                  children: [
                                                                    const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red),
                                                                    Text(
                                                                      l.hsMismatchWarning('${item.dutyRate ?? 0}%', '${item.vatRate ?? 0}%'),
                                                                      style: TextStyle(color: Colors.red.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                                                                    ),
                                                                  ],
                                                                ),
                                                              )
                                                            : Text(
                                                                'HS: $itemHs (${l.fieldImportDuty}: ${item.dutyRate ?? 0}% / ${l.fieldVatAmount}: ${item.vatRate ?? 0}%)',
                                                                style: const TextStyle(color: AppTheme.cobalt, fontSize: 11),
                                                              ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${item.quantity} ${item.unitOfMeasure}')),
                                              Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Text(
                                                  '$itemPkg',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isPalletized ? Colors.grey : (isDark ? AppTheme.darkTextPrimary : null),
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Text(
                                                  resolved.packageType,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: isDark ? AppTheme.darkTextPrimary : null,
                                                  ),
                                                ),
                                              ),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${po.currencyCode ?? "USD"} ${item.unitPrice.toStringAsFixed(2)}')),
                                              Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Text(
                                                  '${po.currencyCode ?? "USD"} ${item.totalPrice.toStringAsFixed(2)}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                                ),
                                              ),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${_formatWeight(itemNet)} kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${_formatWeight(itemGross)} kg', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                              Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Text(
                                                  '${itemCbm.toStringAsFixed(3)} m³',
                                                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                                child: Center(
                                                  child: IconButton(
                                                    icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 16),
                                                    tooltip: isArabic ? 'نسخ السطر لإكسيل (TSV)' : 'Copy row for Excel (TSV)',
                                                    visualDensity: VisualDensity.compact,
                                                    onPressed: () => TableCopyHelper.copyRow(
                                                      dialogCtx,
                                                      [
                                                        item.itemCode ?? '-',
                                                        item.mainDescription ?? '-',
                                                        item.descriptionAr,
                                                        itemHs ?? '-',
                                                        item.quantity,
                                                        item.unitOfMeasure,
                                                        itemPkg,
                                                        resolved.packageType,
                                                        item.unitPrice,
                                                        item.totalPrice,
                                                        itemNet,
                                                        itemGross,
                                                        itemCbm,
                                                      ],
                                                      headers: [
                                                        'Item Code',
                                                        'Main Description',
                                                        'Description',
                                                        'HS Code',
                                                        'Quantity',
                                                        'Unit',
                                                        'Qty PKG',
                                                        'Package Type',
                                                        'Unit Price',
                                                        'Total Price',
                                                        'Net Weight (kg)',
                                                        'Gross Weight (kg)',
                                                        'Volume CBM',
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 20),
                                Text(
                                  isArabic ? '📊 ملخص بنود أمر التوريد حسب البند الجمركي (PO Line Items Summary By HS Code)' : '📊 PO Line Items Summary By HS Code',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                ),
                                const SizedBox(height: 6),
                                SelectionArea(
                                  child: Table(
                                    border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                                    columnWidths: const {
                                      0: FlexColumnWidth(1.6),
                                      1: FlexColumnWidth(1.0),
                                      2: FlexColumnWidth(0.9),
                                      3: FlexColumnWidth(1.1),
                                      4: FlexColumnWidth(1.1),
                                      5: FlexColumnWidth(1.1),
                                      6: FlexColumnWidth(1.3),
                                      7: FlexColumnWidth(1.4),
                                      8: FixedColumnWidth(40),
                                    },
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                                        children: [
                                          Padding(padding: const EdgeInsets.all(6), child: Text(l.hsCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'الكمية' : 'Qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'عدد الطرود' : 'Qty PKG', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'الصافي (كجم)' : 'Net Wt (kg)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'القائم (كجم)' : 'Gross Wt (kg)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'الحجم CBM' : 'Volume CBM', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'إجمالي القيمة' : 'Total Amount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'نسب الرسوم' : 'Duty / VAT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                          const Padding(padding: EdgeInsets.all(4), child: Center(child: Icon(Icons.copy_rounded, size: 14, color: AppTheme.cobalt))),
                                        ],
                                      ),
                                      ...poHsSummaryMap.values.map((summary) {
                                        final summaryHs = '${summary['hs_code']}';
                                        final isMismatched = mismatchedHsCodes.contains(summaryHs);
                                        final double net = summary['total_net'] as double;
                                        final double gross = summary['total_gross'] as double;
                                        final double cbm = summary['total_cbm'] as double;
                                        final double price = summary['total_price'] as double;
                                        final int pkg = summary['qty_pkg'] as int;

                                        return TableRow(
                                          decoration: isMismatched ? BoxDecoration(color: isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50.withOpacity(0.35)) : null,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(6),
                                              child: Text(summaryHs, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                            ),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${summary['qty']}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('$pkg', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPalletized ? Colors.grey : (isDark ? AppTheme.darkTextPrimary : null)))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${_formatWeight(net)} kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${_formatWeight(gross)} kg', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${cbm.toStringAsFixed(3)} m³', style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${po.currencyCode ?? "USD"} ${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${summary['duty_rate']}% / ${summary['vat_rate']}%', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700))),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                              child: Center(
                                                child: IconButton(
                                                  icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 16),
                                                  tooltip: isArabic ? 'نسخ السطر لإكسيل (TSV)' : 'Copy row for Excel (TSV)',
                                                  visualDensity: VisualDensity.compact,
                                                  onPressed: () => TableCopyHelper.copyRow(
                                                    dialogCtx,
                                                    [summaryHs, summary['qty'], pkg, net, gross, cbm, price, '${summary['duty_rate']}%', '${summary['vat_rate']}%'],
                                                    headers: ['HS Code', 'Qty', 'Qty PKG', 'Net Weight', 'Gross Weight', 'CBM', 'Total Amount', 'Duty Rate', 'VAT Rate'],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  isArabic
                                      ? '🛡️ بطاقات الامتثال والاتفاقيات الجمركية للبند الجمركي (Regulatory Conditions & Trade Agreements)'
                                      : '🛡️ Regulatory Conditions & Trade Agreements by HS Code',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...poHsSummaryMap.values.map((summary) {
                                  final summaryHs = '${summary['hs_code']}';
                                  final tariff = tariffs.where((t) =>
                                      t.hsCode == summaryHs ||
                                      t.hsCode.replaceAll('.', '') == summaryHs.replaceAll('.', '')).firstOrNull;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: HsCodeComplianceInsightCard(
                                      hsCode: summaryHs,
                                      tariff: tariff,
                                      countryOfOrigin: po.countryOfOrigin,
                                      isDark: isDark,
                                      isArabic: isArabic,
                                    ),
                                  );
                                }),
                                if (packageTypeSummaryMap.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  _buildPackageTypeSummaryTable(
                                    context: dialogCtx,
                                    packageTypeSummaryMap: packageTypeSummaryMap,
                                    isDark: isDark,
                                    isArabic: isArabic,
                                  ),
                                ],
                              ],
                            );
                          }),
                        ),


                      // Tab 2: BP-003 Review Packing List
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Reconciliation & Discrepancy Status Banner
                            if (po.packingListItems.isNotEmpty) ...[
                              if (reconciliation.hasDiscrepancy)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF382C10) : Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isDark ? Colors.amber.shade700 : Colors.amber.shade400),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                            isArabic
                                                ? 'حالة مطابقة الفاتورة والباكينج: يوجد اختلافات في الكميات أو البنود الجمركية'
                                                : 'Invoice & Packing Reconciliation: Discrepancies found in quantities or HS codes',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.amber.shade200 : Colors.brown),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ...(isArabic ? reconciliation.discrepancySummaryList : (reconciliation.discrepancySummaryListEn.isNotEmpty ? reconciliation.discrepancySummaryListEn : reconciliation.discrepancySummaryList)).map(
                                        (d) => Padding(
                                          padding: const EdgeInsetsDirectional.only(top: 2, start: 24),
                                          child: Text('• $d', style: TextStyle(fontSize: 11, color: isDark ? Colors.amber.shade100 : Colors.brown)),
                                        ),
                                      ),
                                      if (po.notes != null && po.notes!.contains('[مبررات اختلاف الفاتورة والباكينج]')) ...[
                                        const Divider(height: 14),
                                        Text(
                                          '${isArabic ? "المبرر المعتمد:" : "Approved Justification:"} ${po.notes!.split('[مبررات اختلاف الفاتورة والباكينج]:').last.trim()}',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                        ),
                                      ],
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF14301D) : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isDark ? Colors.green.shade700 : Colors.green.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.verified_outlined, color: Colors.green, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        isArabic
                                            ? 'مطابقة تامة: جميع بنود الفاتورة المبدئية متطابقة بالكامل مع بيان التعبئة في الأكواد الجمركية والكميات.'
                                            : 'Perfect Match: All proforma invoice line items match packing list in HS codes and quantities.',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.greenAccent : Colors.green, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                            ],

                            // Validation Status Banner
                            if (validationErrors.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(color: isDark ? const Color(0xFF381414) : Colors.red.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: isDark ? Colors.red.shade700 : Colors.red.shade300)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          isArabic ? 'أخطاء مطابقة قائمة التعبئة' : 'Packing List Validation Errors',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.redAccent : Colors.red),
                                        ),
                                      ],
                                    ),
                                    ...validationErrors.map((e) => Padding(padding: const EdgeInsetsDirectional.only(top: 4, start: 24), child: Text('• $e', style: TextStyle(fontSize: 12, color: isDark ? Colors.red.shade200 : Colors.red)))),
                                  ],
                                ),
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(color: isDark ? const Color(0xFF14301D) : Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: isDark ? Colors.green.shade700 : Colors.green.shade300)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      isArabic
                                          ? 'تم التحقق من قائمة التعبئة بنجاح — كافة الأوزان والكميات مطابقة'
                                          : 'Packing List Validation Passed — All weights and quantities verified.',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.greenAccent : Colors.green),
                                    ),
                                  ],
                                ),
                              ),

                            if (validationWarnings.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(color: isDark ? const Color(0xFF382C10) : Colors.amber.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: isDark ? Colors.amber.shade700 : Colors.amber.shade300)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: validationWarnings.map((w) => Text('⚠️ $w', style: TextStyle(fontSize: 11, color: isDark ? Colors.amber.shade200 : Colors.brown))).toList(),
                                ),
                              ),

                            if (po.packingListItems.isNotEmpty && po.palletPlanItems.isEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.view_in_ar_rounded, color: Colors.orange, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isArabic
                                            ? 'محاكاة ورص الحاويات 3D متاحة لـ ${po.packingListItems.length} صنف (${po.packingListItems.fold<int>(0, (s, p) => s + (p.qtyPkg > 0 ? p.qtyPkg.toInt() : 1))} طرد)'
                                            : '3D Container Load Simulation available for ${po.packingListItems.length} items (${po.packingListItems.fold<int>(0, (s, p) => s + (p.qtyPkg > 0 ? p.qtyPkg.toInt() : 1))} pkgs)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      ),
                                      icon: const Icon(Icons.view_in_ar_rounded, size: 15),
                                      label: Text(
                                        l.containerLoadPlan3dTitle,
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: () => _showVisualLoadPlannerDialog(context, po),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            if (po.palletPlanItems.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkCardBackground : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1), width: 1.2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.pallet, color: AppTheme.cobalt, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          l.masterPalletPlanTitle,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cobalt.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            '🔢 ${l.totalPalletsMetric}: ${l.palletCountWithUnit(po.palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount))}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.orange.withOpacity(0.4)),
                                          ),
                                          child: Text(
                                            '📐 ${l.palletCbmWithUnit(po.palletPlanItems.fold<double>(0.0, (sum, p) => sum + (p.calculatedCbm > 0 ? p.calculatedCbm : (p.lengthCm * p.widthCm * p.heightCm / 1000000.0) * p.palletCount)).toStringAsFixed(3))}',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                          icon: const Icon(Icons.view_in_ar_rounded, size: 15),
                                          label: Text(
                                            l.simulateAndLoad3d(po.palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount)),
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () => _showVisualLoadPlannerDialog(context, po),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Table(
                                      border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                                      children: [
                                        TableRow(
                                          decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                                          children: [
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.palletTypeCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.palletCountCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.palletDimensionsCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.palletWeightCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.palletTotalWeightCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.palletVolumeCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.palletStackingInstructionsCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                          ],
                                        ),
                                        ...po.palletPlanItems.map((pal) {
                                          final palCbm = pal.calculatedCbm > 0 ? pal.calculatedCbm : (pal.lengthCm * pal.widthCm * pal.heightCm / 1000000.0) * pal.palletCount;
                                          final palTotalWt = pal.grossWeightPerPalletKg * pal.palletCount;
                                          return TableRow(
                                            children: [
                                              Padding(padding: const EdgeInsets.all(6), child: Text(pal.palletType, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt))),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${pal.palletCount}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${pal.lengthCm.toStringAsFixed(0)} × ${pal.widthCm.toStringAsFixed(0)} × ${pal.heightCm.toStringAsFixed(0)} cm', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${pal.grossWeightPerPalletKg.toStringAsFixed(1)} kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${palTotalWt.toStringAsFixed(1)} kg', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${palCbm.toStringAsFixed(3)} m³', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange))),
                                              Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Text(
                                                  pal.isStackable ? l.stackableOption : l.nonStackableOption,
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pal.isStackable ? (isDark ? Colors.greenAccent : Colors.green.shade800) : Colors.orange.shade700),
                                                ),
                                              ),
                                            ],
                                          );
                                        }),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            Text(l.poPackingListTabCount(po.packingListItems.length), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                            const SizedBox(height: 6),

                            if (po.packingListItems.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(l.noPackingEntriesYetDesc, style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                              )
                            else
                              SelectionArea(
                                child: Table(
                                  border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                                  columnWidths: const {
                                    0: FlexColumnWidth(1.6),
                                    1: FlexColumnWidth(1.1),
                                    2: FlexColumnWidth(1.6),
                                    3: FlexColumnWidth(0.9),
                                    4: FlexColumnWidth(0.9),
                                    5: FlexColumnWidth(0.9),
                                    6: FlexColumnWidth(1.3),
                                    7: FlexColumnWidth(1.0),
                                    8: FlexColumnWidth(1.0),
                                    9: FlexColumnWidth(1.0),
                                    10: FixedColumnWidth(44),
                                  },
                                  children: [
                                    TableRow(
                                      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                                      children: [
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.hsCode, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.itemCode, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.mainDescription, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.qtyPcsCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.qtyPkgCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.packageTypeCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.dimensionsCmCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.netWeightCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.grossWeightCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.cbmVolumeMetric, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Center(
                                            child: Icon(Icons.copy_rounded, size: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                                          ),
                                        ),
                                      ],
                                    ),
                                    ...po.packingListItems.map(
                                      (p) {
                                        final isMismatched = reconciliation.items.any((r) => r.hsCode == p.hsCode && !r.isMatched);
                                        return TableRow(
                                          decoration: isMismatched ? BoxDecoration(color: isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50.withOpacity(0.35)) : null,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(6),
                                              child: isMismatched
                                                  ? Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: isDark ? const Color(0xFF3B151E) : Colors.red.shade50,
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: Colors.red.shade400, width: 1.1),
                                                      ),
                                                      child: Wrap(
                                                        crossAxisAlignment: WrapCrossAlignment.center,
                                                        spacing: 2,
                                                        children: [
                                                          const Icon(Icons.warning_amber_rounded, size: 11, color: Colors.red),
                                                          Text(
                                                            p.hsCode.isNotEmpty ? p.hsCode : 'None',
                                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.redAccent : Colors.red.shade900),
                                                          ),
                                                        ],
                                                      ),
                                                    )
                                                  : LtrText(p.hsCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                            ),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(p.itemCode, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(p.mainDescription ?? p.description ?? '-', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${p.qtyPcs}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${p.qtyPkg}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(p.packageType, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(p.lengthCm > 0 ? '${p.lengthCm}x${p.widthCm}x${p.heightCm}' : 'N/A', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(_formatWeight((p.netWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.netWeightUnitKg) : p.totalNetWeightKg), style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(_formatWeight((p.grossWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.grossWeightUnitKg) : p.totalGrossWeightKg), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${(p.calculatedCbm > 0 ? p.calculatedCbm : p.totalCbm).toStringAsFixed(3)} m³', style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold))),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                              child: Center(
                                                child: IconButton(
                                                  icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 16),
                                                  tooltip: isArabic ? 'نسخ السطر لإكسيل (TSV)' : 'Copy row for Excel (TSV)',
                                                  visualDensity: VisualDensity.compact,
                                                  onPressed: () => TableCopyHelper.copyRow(
                                                    dialogCtx,
                                                    [
                                                      p.hsCode,
                                                      p.itemCode,
                                                      p.mainDescription ?? p.description ?? '-',
                                                      p.qtyPcs,
                                                      p.qtyPkg,
                                                      p.packageType,
                                                      p.lengthCm > 0 ? '${p.lengthCm}x${p.widthCm}x${p.heightCm}' : 'N/A',
                                                      ((p.netWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.netWeightUnitKg) : p.totalNetWeightKg),
                                                      ((p.grossWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.grossWeightUnitKg) : p.totalGrossWeightKg),
                                                      (p.calculatedCbm > 0 ? p.calculatedCbm : p.totalCbm),
                                                    ],
                                                    headers: [
                                                      'HS Code',
                                                      'Item Code',
                                                      'Description',
                                                      'Qty (Pcs)',
                                                      'Qty (Pkg)',
                                                      'Package Type',
                                                      'Dimensions (cm)',
                                                      'Net Weight (kg)',
                                                      'Gross Weight (kg)',
                                                      'CBM (m³)',
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 20),
                            Text('📊 ${l.summaryByHsCodeReport}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                            const SizedBox(height: 6),
                            SelectionArea(
                              child: Table(
                                border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                                    children: [
                                      Padding(padding: const EdgeInsets.all(6), child: Text(l.hsCode, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                      Padding(padding: const EdgeInsets.all(6), child: Text(l.qtyPcsCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                      Padding(padding: const EdgeInsets.all(6), child: Text(l.qtyPkgCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                      Padding(padding: const EdgeInsets.all(6), child: Text(l.totalNetWeightCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                      Padding(padding: const EdgeInsets.all(6), child: Text(l.totalGrossWeightCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                      Padding(padding: const EdgeInsets.all(6), child: Text(l.totalCargoCbmMetric, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                    ],
                                  ),
                                  ...hsSummaryMap.values.map(
                                    (summary) {
                                      final summaryHs = '${summary['hs_code']}';
                                      final isMismatched = reconciliation.items.any((r) => r.hsCode == summaryHs && !r.isMatched);
                                      return TableRow(
                                        decoration: isMismatched ? BoxDecoration(color: isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50.withOpacity(0.35)) : null,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: isMismatched
                                                ? Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        summaryHs,
                                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.redAccent : Colors.red.shade900),
                                                      ),
                                                    ],
                                                  )
                                                : Text(summaryHs, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                          ),
                                          Padding(padding: const EdgeInsets.all(6), child: Text('${summary['qty_pcs']}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text('${summary['qty_pkg']}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text('${(summary['total_net'] as double).toStringAsFixed(1)} kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text('${(summary['total_gross'] as double).toStringAsFixed(1)} kg', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text('${(summary['total_cbm'] as double).toStringAsFixed(3)} m³', style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold))),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            if (packageTypeSummaryMap.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              _buildPackageTypeSummaryTable(
                                context: dialogCtx,
                                packageTypeSummaryMap: packageTypeSummaryMap,
                                isDark: isDark,
                                isArabic: isArabic,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Tab 3: 3D Container Load Planner & Simulation
                      _buildPo3dLoadPlannerTab(dialogCtx, po, isDark, isArabic, l),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.view_in_ar_rounded, size: 16),
              label: Text(
                l.containerLoadPlan3dTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showVisualLoadPlannerDialog(context, po),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.emerald,
                side: const BorderSide(color: AppTheme.emerald),
              ),
              icon: const Icon(Icons.table_chart, size: 16),
              label: Text(
                isArabic ? 'تصدير إكسيل' : 'Export Excel',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                _exportPoToExcel(dialogCtx, po, isArabic);
              },
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.crimson,
                side: const BorderSide(color: AppTheme.crimson),
              ),
              icon: const Icon(Icons.picture_as_pdf, size: 16),
              label: Text(
                isArabic ? 'تصدير PDF' : 'Export PDF',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                _exportPoToPdf(dialogCtx, po, isArabic);
              },
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.cobalt,
                side: const BorderSide(color: AppTheme.cobalt),
              ),
              icon: const Icon(Icons.copy_all, size: 16),
              label: Text(
                l.copyAllData,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                _copyPoDetailsToClipboard(dialogCtx, po, isArabic);
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cobalt,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.edit, size: 16),
              label: Text(l.editPurchaseOrder, style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(dialogCtx);
                _showPODialog(context, po);
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(l.close),
            ),
          ],
        ),
      ),
    );
  },
);
}

  void _copyPoDetailsToClipboard(BuildContext context, PurchaseOrderModel po, bool isArabic) {
    final buffer = StringBuffer();
    buffer.writeln(isArabic ? '=== بيانات أمر الشراء / الفاتورة المبدئية ===' : '=== Purchase Order / Proforma Invoice Details ===');
    buffer.writeln('${isArabic ? "اسم / مرجع أمر الشراء" : "PO Reference / Name"}: ${po.displayName}');
    if (po.displayName != po.poNumber) {
      buffer.writeln('${isArabic ? "الرقم الداخلي للنظام" : "Internal PO Code"}: ${po.poNumber}');
    }
    if (po.proformaInvoiceNumber != null && po.proformaInvoiceNumber!.isNotEmpty) {
      buffer.writeln('${isArabic ? "رقم الفاتورة المبدئية" : "Proforma Invoice"}: ${po.proformaInvoiceNumber}');
    }
    if (po.projectName != null && po.projectName!.isNotEmpty) {
      buffer.writeln('${isArabic ? "المشروع ومركز التكلفة" : "Project & Cost Center"}: ${po.projectName}');
    }
    if (po.companyName != null && po.companyName!.isNotEmpty) {
      buffer.writeln('${isArabic ? "الشركة المستوردة" : "Importing Company"}: ${po.companyName}');
    }
    if (po.supplierName != null && po.supplierName!.isNotEmpty) {
      buffer.writeln('${isArabic ? "المورد الأجنبي" : "Foreign Supplier"}: ${po.supplierName}');
    }
    if (po.countryOfOrigin != null && po.countryOfOrigin!.isNotEmpty) {
      buffer.writeln('${isArabic ? "بلد المنشأ" : "Country of Origin"}: ${po.countryOfOrigin}');
    }
    if (po.incotermCode != null && po.incotermCode!.isNotEmpty) {
      buffer.writeln('${isArabic ? "الشرط التجاري" : "Incoterms"}: ${po.incotermCode}');
    }
    buffer.writeln('${isArabic ? "العملة" : "Currency"}: ${po.currencyCode ?? "USD"} (${isArabic ? "سعر الصرف" : "FX Rate"}: ${po.exchangeRate})');
    if (po.paymentTerms != null && po.paymentTerms!.isNotEmpty) {
      buffer.writeln('${isArabic ? "شروط الدفع" : "Payment Terms"}: ${po.paymentTerms}');
    }
    buffer.writeln('${isArabic ? "إجمالي القيمة" : "Total Amount"}: ${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}');
    buffer.writeln('${isArabic ? "إجمالي الحجم CBM" : "Total CBM"}: ${po.totalCbm.toStringAsFixed(3)} m³');
    buffer.writeln('${isArabic ? "الوزن القائم / الصافي" : "Gross / Net Weight"}: ${po.totalGrossWeightKg.toStringAsFixed(1)} kg / ${po.totalNetWeightKg.toStringAsFixed(1)} kg');
    buffer.writeln('${isArabic ? "عدد الطرود" : "Total Packages"}: ${po.totalPackagesCount} ${po.packingListItems.isNotEmpty ? po.packingListItems.first.packageType : "Carton"}');
    buffer.writeln('${isArabic ? "الحالة" : "Status"}: ${po.status}');
    if (po.notes != null && po.notes!.isNotEmpty) {
      buffer.writeln('${isArabic ? "ملاحظات" : "Notes"}: ${po.notes}');
    }
    buffer.writeln();

    buffer.writeln(isArabic ? '--- بنود أمر الشراء والأكواد الجمركية ---' : '--- PO Line Items & HS Codes ---');
    buffer.writeln('Item Code\tMain Description\tDescription & HS Code\tQty / UOM\tUnit Price\tLine Total\tVolume CBM');
    for (final item in po.items) {
      buffer.writeln(
        '${item.itemCode ?? "-"}\t${item.mainDescription ?? "-"}\t${item.descriptionAr} (HS: ${item.hsCode ?? "-"})\t${item.quantity} ${item.unitOfMeasure}\t${po.currencyCode ?? "USD"} ${item.unitPrice.toStringAsFixed(2)}\t${po.currencyCode ?? "USD"} ${item.totalPrice.toStringAsFixed(2)}\t${item.totalCbm.toStringAsFixed(3)}',
      );
    }

    if (po.packingListItems.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(isArabic ? '--- بيان التعبئة (Packing List) ---' : '--- Packing List Items ---');
      buffer.writeln('HS Code\tItem Code\tDescription\tPackages\tPackage Type\tDimensions (cm)\tNet Weight (kg)\tGross Weight (kg)\tCBM');
      for (final pl in po.packingListItems) {
        final dims = pl.lengthCm > 0 ? '${pl.lengthCm}x${pl.widthCm}x${pl.heightCm}' : '-';
        final netWt = _formatWeight((pl.netWeightUnitKg > 0 && pl.qtyPkg > 0) ? (pl.qtyPkg * pl.netWeightUnitKg) : pl.totalNetWeightKg);
        final grossWt = _formatWeight((pl.grossWeightUnitKg > 0 && pl.qtyPkg > 0) ? (pl.qtyPkg * pl.grossWeightUnitKg) : pl.totalGrossWeightKg);
        final cbm = (pl.calculatedCbm > 0 ? pl.calculatedCbm : pl.totalCbm).toStringAsFixed(3);
        buffer.writeln(
          '${pl.hsCode}\t${pl.itemCode}\t${pl.description ?? pl.mainDescription ?? "-"}\t${pl.qtyPkg}\t${pl.packageType}\t$dims\t$netWt\t$grossWt\t$cbm',
        );
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isArabic ? 'تم نسخ كافة بيانات أمر الشراء للحافظة بنجاح ✅' : 'PO details copied to clipboard ✅'),
        backgroundColor: AppTheme.emerald,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _exportPoToExcel(BuildContext context, PurchaseOrderModel po, bool isArabic) async {
    final bool isPalletized = (po.palletPlanItems.isNotEmpty && po.palletPlanItems.any((p) => p.palletCount > 0)) || po.palletCount > 0;

    final headers = [
      isArabic ? 'كود الصنف' : 'Item Code',
      isArabic ? 'الوصف' : 'Description',
      isArabic ? 'بند التعريفة' : 'HS Code',
      isArabic ? 'الكمية' : 'Qty',
      isArabic ? 'الوحدة' : 'Unit',
      isArabic ? 'عدد الطرود' : 'Qty PKG',
      isArabic ? 'نوع التغليف' : 'Package Type',
      isArabic ? 'سعر الوحدة' : 'Unit Price',
      isArabic ? 'الإجمالي' : 'Total',
      isArabic ? 'الصافي (كجم)' : 'Net Wt (kg)',
      isArabic ? 'القائم (كجم)' : 'Gross Wt (kg)',
      isArabic ? 'الحجم CBM' : 'CBM',
    ];

    final tariffs = ref.read(customsTariffProvider).valueOrNull ?? [];
    final resolvedPoItems = PoPackingMatcher.resolvePoItemMetrics(
      items: po.items,
      packingListItems: po.packingListItems,
      isPalletized: isPalletized,
      tariffs: tariffs,
    );

    final rows = resolvedPoItems.map((resolved) {
      final item = resolved.item;
      return [
        item.itemCode ?? '-',
        item.mainDescription ?? item.descriptionAr,
        resolved.effectiveHsCode != 'UNSPECIFIED' ? resolved.effectiveHsCode : (item.hsCode ?? '-'),
        '${item.quantity}',
        item.unitOfMeasure,
        '${resolved.qtyPkg}',
        resolved.packageType,
        '${po.currencyCode ?? "USD"} ${item.unitPrice.toStringAsFixed(2)}',
        '${po.currencyCode ?? "USD"} ${item.totalPrice.toStringAsFixed(2)}',
        _formatWeight(resolved.netWeightKg),
        _formatWeight(resolved.grossWeightKg),
        resolved.cbm.toStringAsFixed(3),
      ];
    }).toList();

    // Section 1: PO Line Items Summary By HS Code
    final Map<String, Map<String, dynamic>> poHsSummaryMap = PoPackingMatcher.buildPoHsSummaryMap(resolvedPoItems);

    final poHsHeaders = [
      isArabic ? 'بند التعريفة' : 'HS Code',
      isArabic ? 'الكمية' : 'Qty',
      isArabic ? 'عدد الطرود' : 'Qty PKG',
      isArabic ? 'الصافي (كجم)' : 'Net Wt (kg)',
      isArabic ? 'القائم (كجم)' : 'Gross Wt (kg)',
      isArabic ? 'الحجم CBM' : 'Volume CBM',
      isArabic ? 'إجمالي القيمة' : 'Total Amount',
      isArabic ? 'نسب الرسوم' : 'Duty / VAT',
    ];

    final poHsRows = poHsSummaryMap.values.map((s) {
      return [
        '${s['hs_code']}',
        '${s['qty']}',
        '${s['qty_pkg']}',
        _formatWeight(s['total_net'] as double),
        _formatWeight(s['total_gross'] as double),
        (s['total_cbm'] as double).toStringAsFixed(3),
        '${po.currencyCode ?? "USD"} ${(s['total_price'] as double).toStringAsFixed(2)}',
        '${s['duty_rate']}% / ${s['vat_rate']}%',
      ];
    }).toList();

    final List<TableExportSection> additionalSections = [
      TableExportSection(
        title: isArabic
            ? '📊 ملخص بنود أمر التوريد حسب البند الجمركي (PO Line Items Summary By HS Code)'
            : '📊 PO Line Items Summary By HS Code',
        headers: poHsHeaders,
        rows: poHsRows,
      ),
    ];

    // Section 2: Packing List Summary By HS Code (if packing list exists)
    if (po.packingListItems.isNotEmpty) {
      final Map<String, Map<String, dynamic>> hsSummaryMap = {};
      for (final p in po.packingListItems) {
        final hs = p.hsCode.isNotEmpty ? p.hsCode : 'UNSPECIFIED';
        if (!hsSummaryMap.containsKey(hs)) {
          hsSummaryMap[hs] = {
            'hs_code': hs,
            'qty_pcs': 0.0,
            'qty_pkg': 0.0,
            'total_net': 0.0,
            'total_gross': 0.0,
            'total_cbm': 0.0,
          };
        }
        final double plNet = (p.netWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.netWeightUnitKg) : p.totalNetWeightKg;
        final double plGross = (p.grossWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.grossWeightUnitKg) : p.totalGrossWeightKg;
        final double plCbm = p.calculatedCbm > 0 ? p.calculatedCbm : p.totalCbm;
        hsSummaryMap[hs]!['qty_pcs'] += p.qtyPcs;
        hsSummaryMap[hs]!['qty_pkg'] += p.qtyPkg;
        hsSummaryMap[hs]!['total_net'] += plNet;
        hsSummaryMap[hs]!['total_gross'] += plGross;
        hsSummaryMap[hs]!['total_cbm'] += plCbm;
      }

      final plHsHeaders = [
        isArabic ? 'بند التعريفة' : 'HS Code',
        isArabic ? 'الكمية (قطع)' : 'Qty Pcs',
        isArabic ? 'عدد الطرود' : 'Qty PKG',
        isArabic ? 'الصافي (كجم)' : 'Net Wt (kg)',
        isArabic ? 'القائم (كجم)' : 'Gross Wt (kg)',
        isArabic ? 'الحجم CBM' : 'Volume CBM',
      ];

      final plHsRows = hsSummaryMap.values.map((s) {
        return [
          '${s['hs_code']}',
          '${s['qty_pcs']}',
          '${s['qty_pkg']}',
          _formatWeight(s['total_net'] as double),
          _formatWeight(s['total_gross'] as double),
          (s['total_cbm'] as double).toStringAsFixed(3),
        ];
      }).toList();

      additionalSections.add(
        TableExportSection(
          title: isArabic
              ? '📊 ملخص بيان التعبئة حسب البند الجمركي (Packing List Summary By HS Code)'
              : '📊 Packing List Summary By HS Code',
          headers: plHsHeaders,
          rows: plHsRows,
        ),
      );
    }

    // Section 3: Packing List Summary By Package Type (if packing list exists)
    final packageTypeSummaryMap = PoPackingMatcher.buildPackingTypeSummaryMap(po.packingListItems);
    if (packageTypeSummaryMap.isNotEmpty) {
      final pkgHeaders = [
        isArabic ? 'نوع التغليف' : 'Package Type',
        isArabic ? 'إجمالي الطرود' : 'Total Packages',
        isArabic ? 'الصافي (كجم)' : 'Net Wt (kg)',
        isArabic ? 'القائم (كجم)' : 'Gross Wt (kg)',
        isArabic ? 'الحجم CBM' : 'Volume CBM',
      ];

      final pkgRows = packageTypeSummaryMap.values.map((s) {
        final double qty = (s['qty_pkg'] as num).toDouble();
        final String qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1);
        return [
          '${s['package_type']}',
          qtyStr,
          _formatWeight(s['total_net'] as double),
          _formatWeight(s['total_gross'] as double),
          (s['total_cbm'] as double).toStringAsFixed(3),
        ];
      }).toList();

      additionalSections.add(
        TableExportSection(
          title: isArabic
              ? '📊 ملخص قائمة التعبئة حسب نوع التغليف (Packing List Summary By Package Type)'
              : '📊 Packing List Summary By Package Type',
          headers: pkgHeaders,
          rows: pkgRows,
        ),
      );
    }

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: isArabic ? 'أمر شراء' : 'Purchase Order',
      importFileNameOrCode: po.displayName,
      additionalSections: additionalSections,
    );
  }

  Future<void> _exportPoToPdf(BuildContext context, PurchaseOrderModel po, bool isArabic) async {
    final bool isPalletized = (po.palletPlanItems.isNotEmpty && po.palletPlanItems.any((p) => p.palletCount > 0)) || po.palletCount > 0;

    final tariffs = ref.read(customsTariffProvider).valueOrNull ?? [];
    final resolvedPoItems = PoPackingMatcher.resolvePoItemMetrics(
      items: po.items,
      packingListItems: po.packingListItems,
      isPalletized: isPalletized,
      tariffs: tariffs,
    );

    final headers = [
      isArabic ? 'كود الصنف' : 'Item Code',
      isArabic ? 'الوصف' : 'Description',
      isArabic ? 'بند التعريفة' : 'HS Code',
      isArabic ? 'الكمية' : 'Qty',
      isArabic ? 'الوحدة' : 'Unit',
      isArabic ? 'عدد الطرود' : 'Qty PKG',
      isArabic ? 'نوع التغليف' : 'Package Type',
      isArabic ? 'سعر الوحدة' : 'Unit Price',
      isArabic ? 'الإجمالي' : 'Total',
      isArabic ? 'الصافي (كجم)' : 'Net Wt (kg)',
      isArabic ? 'القائم (كجم)' : 'Gross Wt (kg)',
      isArabic ? 'الحجم CBM' : 'CBM',
    ];

    final rows = resolvedPoItems.map((resolved) {
      final item = resolved.item;
      return [
        item.itemCode ?? '-',
        item.mainDescription ?? item.descriptionAr,
        resolved.effectiveHsCode != 'UNSPECIFIED' ? resolved.effectiveHsCode : (item.hsCode ?? '-'),
        '${item.quantity}',
        item.unitOfMeasure,
        '${resolved.qtyPkg}',
        resolved.packageType,
        '${po.currencyCode ?? "USD"} ${item.unitPrice.toStringAsFixed(2)}',
        '${po.currencyCode ?? "USD"} ${item.totalPrice.toStringAsFixed(2)}',
        _formatWeight(resolved.netWeightKg),
        _formatWeight(resolved.grossWeightKg),
        resolved.cbm.toStringAsFixed(3),
      ];
    }).toList();

    // Calculate effective totals for accurate metadata
    final double palletPlanCbm = po.palletPlanItems.isNotEmpty
        ? po.palletPlanItems.fold<double>(
            0.0,
            (sum, p) => sum + (p.calculatedCbm > 0 ? p.calculatedCbm : (p.lengthCm * p.widthCm * p.heightCm / 1000000.0) * p.palletCount),
          )
        : (po.palletCount > 0 && po.palletLengthCm > 0 && po.palletWidthCm > 0 && po.palletHeightCm > 0
            ? (po.palletLengthCm * po.palletWidthCm * po.palletHeightCm / 1000000.0) * po.palletCount
            : (po.palletCount > 0 && po.totalCbm > 0 ? po.totalCbm : 0.0));
    final double palletPlanGrossWeight = po.palletPlanItems.isNotEmpty
        ? po.palletPlanItems.fold<double>(
            0.0,
            (sum, p) => sum + (p.grossWeightPerPalletKg * p.palletCount),
          )
        : (po.palletCount > 0 && po.totalGrossWeightKg > 0 ? po.totalGrossWeightKg : 0.0);
    final int totalPalletCount = po.palletPlanItems.isNotEmpty
        ? po.palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount)
        : po.palletCount;

    final double effectivePackingListCbm = palletPlanCbm > 0
        ? palletPlanCbm
        : (po.totalCbm > 0
            ? po.totalCbm
            : (po.packingListItems.isNotEmpty
                ? po.packingListItems.fold(0.0, (sum, pl) => sum + (pl.calculatedCbm > 0 ? pl.calculatedCbm : pl.totalCbm))
                : 0.0));
    final double effectivePackingListGrossWeight = palletPlanGrossWeight > 0
        ? palletPlanGrossWeight
        : (po.totalGrossWeightKg > 0
            ? po.totalGrossWeightKg
            : (po.packingListItems.isNotEmpty
                ? po.packingListItems.fold(0.0, (sum, pl) => sum + ((pl.grossWeightUnitKg > 0 && pl.qtyPkg > 0) ? (pl.grossWeightUnitKg * pl.qtyPkg) : pl.totalGrossWeightKg))
                : 0.0));
    final double effectivePackingListNetWeight = po.totalNetWeightKg > 0
        ? po.totalNetWeightKg
        : (po.packingListItems.isNotEmpty
            ? po.packingListItems.fold(0.0, (sum, pl) => sum + ((pl.netWeightUnitKg > 0 && pl.qtyPkg > 0) ? (pl.netWeightUnitKg * pl.qtyPkg) : pl.totalNetWeightKg))
            : 0.0);

    final String totalPkgSummary = PoPackingMatcher.formatPackagingSummary(
      packingListItems: po.packingListItems,
      totalPalletCount: totalPalletCount,
      isArabic: isArabic,
    );

    final metadata = <String, String>{
      isArabic ? 'اسم / مرجع أمر الشراء' : 'PO Reference / Name': po.displayName,
      if (po.displayName != po.poNumber)
        isArabic ? 'الرقم الداخلي' : 'Internal PO Code': po.poNumber,
      if (po.proformaInvoiceNumber != null && po.proformaInvoiceNumber!.isNotEmpty)
        isArabic ? 'الفاتورة المبدئية' : 'Proforma Invoice': po.proformaInvoiceNumber!,
      if (po.companyName != null && po.companyName!.isNotEmpty)
        isArabic ? 'الشركة المستوردة' : 'Importing Company': po.companyName!,
      if (po.supplierName != null && po.supplierName!.isNotEmpty)
        isArabic ? 'المورد الأجنبي' : 'Supplier': po.supplierName!,
      if (po.incotermCode != null && po.incotermCode!.isNotEmpty)
        isArabic ? 'الشرط التجاري' : 'Incoterms': po.incotermCode!,
      isArabic ? 'إجمالي القيمة' : 'Total Amount': '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}',
      isArabic ? 'إجمالي CBM' : 'Total CBM': '${effectivePackingListCbm.toStringAsFixed(3)} m³${totalPalletCount > 0 ? " ($totalPalletCount Pallets)" : ""}',
      isArabic ? 'الوزن القائم الإجمالي' : 'Total Gross Weight': '${_formatWeight(effectivePackingListGrossWeight)} kg',
      isArabic ? 'الوزن الصافي الإجمالي' : 'Total Net Weight': '${_formatWeight(effectivePackingListNetWeight)} kg',
      isArabic ? 'إجمالي الطرود' : 'Total Qty PKG': totalPkgSummary,
    };

    // Section 1: PO Line Items Summary By HS Code
    final Map<String, Map<String, dynamic>> poHsSummaryMap = PoPackingMatcher.buildPoHsSummaryMap(resolvedPoItems);

    final poHsHeaders = [
      isArabic ? 'بند التعريفة' : 'HS Code',
      isArabic ? 'الكمية' : 'Qty',
      isArabic ? 'عدد الطرود' : 'Qty PKG',
      isArabic ? 'الصافي (كجم)' : 'Net Wt (kg)',
      isArabic ? 'القائم (كجم)' : 'Gross Wt (kg)',
      isArabic ? 'الحجم CBM' : 'Volume CBM',
      isArabic ? 'إجمالي القيمة' : 'Total Amount',
      isArabic ? 'نسب الرسوم' : 'Duty / VAT',
    ];

    final poHsRows = poHsSummaryMap.values.map((s) {
      return [
        '${s['hs_code']}',
        '${s['qty']}',
        '${s['qty_pkg']}',
        _formatWeight(s['total_net'] as double),
        _formatWeight(s['total_gross'] as double),
        (s['total_cbm'] as double).toStringAsFixed(3),
        '${po.currencyCode ?? "USD"} ${(s['total_price'] as double).toStringAsFixed(2)}',
        '${s['duty_rate']}% / ${s['vat_rate']}%',
      ];
    }).toList();

    final List<TableExportSection> additionalSections = [
      TableExportSection(
        title: isArabic
            ? '📊 ملخص بنود أمر التوريد حسب البند الجمركي (PO Line Items Summary By HS Code)'
            : '📊 PO Line Items Summary By HS Code',
        headers: poHsHeaders,
        rows: poHsRows,
      ),
    ];

    // Section 2: Packing List Summary By HS Code (if packing list exists)
    if (po.packingListItems.isNotEmpty) {
      final Map<String, Map<String, dynamic>> hsSummaryMap = {};
      for (final p in po.packingListItems) {
        final hs = p.hsCode.isNotEmpty ? p.hsCode : 'UNSPECIFIED';
        if (!hsSummaryMap.containsKey(hs)) {
          hsSummaryMap[hs] = {
            'hs_code': hs,
            'qty_pcs': 0.0,
            'qty_pkg': 0.0,
            'total_net': 0.0,
            'total_gross': 0.0,
            'total_cbm': 0.0,
          };
        }
        final double plNet = (p.netWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.netWeightUnitKg) : p.totalNetWeightKg;
        final double plGross = (p.grossWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.grossWeightUnitKg) : p.totalGrossWeightKg;
        final double plCbm = p.calculatedCbm > 0 ? p.calculatedCbm : p.totalCbm;
        hsSummaryMap[hs]!['qty_pcs'] += p.qtyPcs;
        hsSummaryMap[hs]!['qty_pkg'] += p.qtyPkg;
        hsSummaryMap[hs]!['total_net'] += plNet;
        hsSummaryMap[hs]!['total_gross'] += plGross;
        hsSummaryMap[hs]!['total_cbm'] += plCbm;
      }

      final plHsHeaders = [
        isArabic ? 'بند التعريفة' : 'HS Code',
        isArabic ? 'الكمية (قطع)' : 'Qty Pcs',
        isArabic ? 'عدد الطرود' : 'Qty PKG',
        isArabic ? 'الصافي (كجم)' : 'Net Wt (kg)',
        isArabic ? 'القائم (كجم)' : 'Gross Wt (kg)',
        isArabic ? 'الحجم CBM' : 'Volume CBM',
      ];

      final plHsRows = hsSummaryMap.values.map((s) {
        return [
          '${s['hs_code']}',
          '${s['qty_pcs']}',
          '${s['qty_pkg']}',
          _formatWeight(s['total_net'] as double),
          _formatWeight(s['total_gross'] as double),
          (s['total_cbm'] as double).toStringAsFixed(3),
        ];
      }).toList();

      additionalSections.add(
        TableExportSection(
          title: isArabic
              ? '📊 ملخص بيان التعبئة حسب البند الجمركي (Packing List Summary By HS Code)'
              : '📊 Packing List Summary By HS Code',
          headers: plHsHeaders,
          rows: plHsRows,
        ),
      );
    }

    // Section 3: Packing List Summary By Package Type (if packing list exists)
    final packageTypeSummaryMap = PoPackingMatcher.buildPackingTypeSummaryMap(po.packingListItems);
    if (packageTypeSummaryMap.isNotEmpty) {
      final pkgHeaders = [
        isArabic ? 'نوع التغليف' : 'Package Type',
        isArabic ? 'إجمالي الطرود' : 'Total Packages',
        isArabic ? 'الصافي (كجم)' : 'Net Wt (kg)',
        isArabic ? 'القائم (كجم)' : 'Gross Wt (kg)',
        isArabic ? 'الحجم CBM' : 'Volume CBM',
      ];

      final pkgRows = packageTypeSummaryMap.values.map((s) {
        final double qty = (s['qty_pkg'] as num).toDouble();
        final String qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1);
        return [
          '${s['package_type']}',
          qtyStr,
          _formatWeight(s['total_net'] as double),
          _formatWeight(s['total_gross'] as double),
          (s['total_cbm'] as double).toStringAsFixed(3),
        ];
      }).toList();

      additionalSections.add(
        TableExportSection(
          title: isArabic
              ? '📊 ملخص قائمة التعبئة حسب نوع التغليف (Packing List Summary By Package Type)'
              : '📊 Packing List Summary By Package Type',
          headers: pkgHeaders,
          rows: pkgRows,
        ),
      );
    }

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: isArabic ? 'أمر شراء' : 'Purchase Order',
      importFileNameOrCode: po.displayName,
      additionalSections: additionalSections,
      headerContext: TableExportHeaderContext(
        title: isArabic ? 'بيان بنود أمر الشراء' : 'Purchase Order Items Specification',
        subtitle: 'Sorour Logistics ERP — ${po.displayName}',
        metadata: metadata,
      ),
    );
  }

  Widget _buildPackageTypeSummaryTable({
    required BuildContext context,
    required Map<String, Map<String, dynamic>> packageTypeSummaryMap,
    required bool isDark,
    required bool isArabic,
  }) {
    if (packageTypeSummaryMap.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic
              ? '📊 ملخص قائمة التعبئة حسب نوع التغليف (Packing List Summary By Package Type)'
              : '📊 Packing List Summary By Package Type',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 6),
        SelectionArea(
          child: Table(
            border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.2),
              3: FlexColumnWidth(1.2),
              4: FlexColumnWidth(1.2),
              5: FixedColumnWidth(40),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      isArabic ? 'نوع التغليف' : 'Package Type',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      isArabic ? 'إجمالي الطرود' : 'Total Packages',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      isArabic ? 'الصافي (كجم)' : 'Net Wt (kg)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      isArabic ? 'القائم (كجم)' : 'Gross Wt (kg)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      isArabic ? 'الحجم CBM' : 'Volume CBM',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(4),
                    child: Center(
                      child: Icon(Icons.copy_rounded, size: 14, color: AppTheme.cobalt),
                    ),
                  ),
                ],
              ),
              ...packageTypeSummaryMap.values.map((summary) {
                final String pkgType = '${summary['package_type']}';
                final double qty = (summary['qty_pkg'] as num).toDouble();
                final String qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1);
                final double net = summary['total_net'] as double;
                final double gross = summary['total_gross'] as double;
                final double cbm = summary['total_cbm'] as double;

                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        pkgType,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cobalt,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        qtyStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${_formatWeight(net)} kg',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${_formatWeight(gross)} kg',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${cbm.toStringAsFixed(3)} m³',
                        style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                      child: Center(
                        child: IconButton(
                          icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 16),
                          tooltip: isArabic ? 'نسخ السطر لإكسيل (TSV)' : 'Copy row for Excel (TSV)',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => TableCopyHelper.copyRow(
                            context,
                            [pkgType, qtyStr, net, gross, cbm],
                            headers: ['Package Type', 'Total Packages', 'Net Weight', 'Gross Weight', 'CBM'],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isDark = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        CopyableText(
          value,
          showIcon: false,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
        ),
      ],
    );
  }

  List<CargoItem> _extractCargoItemsFromPo(PurchaseOrderModel po) {
    final hasPalletPlan = po.palletPlanItems.isNotEmpty && po.palletPlanItems.any((p) => p.palletCount > 0);
    final hasSinglePallet = po.palletCount > 0 && po.palletLengthCm > 0 && po.palletWidthCm > 0 && po.palletHeightCm > 0;
    List<CargoItem> cargoItems = [];

    if (hasPalletPlan) {
      final double totalGross = po.packingListItems.fold<double>(
        0.0,
        (sum, p) => sum + (p.totalGrossWeightKg > 0 ? p.totalGrossWeightKg : (p.qtyPkg * p.grossWeightUnitKg)),
      );
      final int totalPallets = po.palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount);
      final double defaultPalletWeight = totalPallets > 0 && totalGross > 0 ? (totalGross / totalPallets) : 137.5;

      int globalIdx = 1;
      for (final pLine in po.palletPlanItems) {
        final pL = pLine.lengthCm > 0 ? pLine.lengthCm : 120.0;
        final pW = pLine.widthCm > 0 ? pLine.widthCm : 80.0;
        final pH = pLine.heightCm > 0 ? pLine.heightCm : 150.0;
        final pWt = pLine.grossWeightPerPalletKg > 0 ? pLine.grossWeightPerPalletKg : defaultPalletWeight;

        for (int i = 0; i < pLine.palletCount; i++) {
          cargoItems.add(CargoItem(
            itemId: 'PLT-$globalIdx',
            length: pL,
            width: pW,
            height: pH,
            weight: pWt,
            isStackable: pLine.isStackable,
            rotate: true,
            packageType: pLine.palletType,
            description: 'بالتة #$globalIdx (${pLine.palletType})${pLine.isStackable ? "" : " [Floor Only]"}',
          ));
          globalIdx++;
        }
      }
    } else if (hasSinglePallet) {
      final double pWt = po.totalGrossWeightKg > 0 ? (po.totalGrossWeightKg / po.palletCount) : 137.5;
      for (int i = 0; i < po.palletCount; i++) {
        cargoItems.add(CargoItem(
          itemId: 'PLT-${i + 1}',
          length: po.palletLengthCm,
          width: po.palletWidthCm,
          height: po.palletHeightCm,
          weight: pWt,
          isStackable: po.isPalletStackable,
          rotate: true,
          packageType: po.palletType,
          description: 'بالتة #${i + 1} (${po.palletType})${po.isPalletStackable ? "" : " [Floor Only]"}',
        ));
      }
    } else if (po.packingListItems.isNotEmpty) {
      int globalIdx = 1;
      for (final p in po.packingListItems) {
        final lCm = p.unit == 'mm' ? p.lengthCm / 10.0 : (p.unit == 'm' ? p.lengthCm * 100.0 : p.lengthCm);
        final wCm = p.unit == 'mm' ? p.widthCm / 10.0 : (p.unit == 'm' ? p.widthCm * 100.0 : p.widthCm);
        final hCm = p.unit == 'mm' ? p.heightCm / 10.0 : (p.unit == 'm' ? p.heightCm * 100.0 : p.heightCm);
        final int count = p.qtyPkg > 0 ? p.qtyPkg.toInt() : 1;
        final double unitGrossWt = p.grossWeightUnitKg > 0
            ? p.grossWeightUnitKg
            : (p.totalGrossWeightKg > 0 ? (p.totalGrossWeightKg / count) : 10.0);

        for (int i = 0; i < count; i++) {
          cargoItems.add(CargoItem(
            itemId: '$globalIdx',
            length: lCm > 0 ? lCm : 100.0,
            width: wCm > 0 ? wCm : 80.0,
            height: hCm > 0 ? hCm : 60.0,
            weight: unitGrossWt,
            isStackable: p.isStackable,
            rotate: true,
            packageType: p.packageType,
            description: count > 1 ? '${p.itemCode} (طرد ${i + 1}/$count)' : p.itemCode,
          ));
          globalIdx++;
        }
      }
    }
    return cargoItems;
  }

  Widget _buildPo3dLoadPlannerTab(
    BuildContext context,
    PurchaseOrderModel po,
    bool isDark,
    bool isArabic,
    AppLocalizations l,
  ) {
    final cargoItems = _extractCargoItemsFromPo(po);

    if (cargoItems.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.view_in_ar_rounded, size: 48, color: Colors.orange),
              ),
              const SizedBox(height: 16),
              Text(
                isArabic ? 'لا توجد بيانات تعبئة أو بالتات متاحة للمحاكاة' : 'No packing list or pallet data available for simulation',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isArabic
                    ? 'يرجى استكمال بنود بيان التعبئة أو البالتات في أمر الشراء لتشغيل مخطط ومحاكاة رص الحاويات 3D'
                    : 'Please add packing list or pallet items in the purchase order to run 3D container packing simulation.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.edit, size: 16),
                label: Text(
                  isArabic ? 'تعديل أمر الشراء وإضافة بيان التعبئة' : 'Edit PO & Add Packing List',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _showPODialog(context, po);
                },
              ),
            ],
          ),
        ),
      );
    }

    String viewProjection = 'both';
    bool showDetailedCoordinates = false;
    bool? activeStackingMode = cargoItems.any((i) => !i.isStackable) ? null : true;
    CargoOrientationPreference activeOrientationMode = CargoOrientationPreference.smartHybrid;
    final GlobalKey tab3dRepaintKey = GlobalKey();

    return StatefulBuilder(
      builder: (ctx, setTabState) {
        final plan = ContainerRequirementEngine.planShipment(
          cargoItems,
          forceStackable: activeStackingMode,
          forceOrientation: activeOrientationMode,
        );

        final totalPkgs = cargoItems.length;
        final stackableInActive = activeStackingMode == true
            ? totalPkgs
            : (activeStackingMode == false ? 0 : cargoItems.where((c) => c.isStackable).length);
        final nonStackableInActive = totalPkgs - stackableInActive;

        final totalPlanWeight = plan.fold(0.0, (s, p) => s + p.totalWeight);
        final totalPlanVolume = plan.fold(0.0, (s, p) => s + p.totalVolume);

        final Map<String, int> containerCounts = {};
        for (final p in plan) {
          if (p.containerCode != 'FAILED') {
            containerCounts[p.containerCode] = (containerCounts[p.containerCode] ?? 0) + 1;
          }
        }
        final fleetSummary = containerCounts.isEmpty
            ? (isArabic ? 'لا توجد حاويات مناسبة' : 'No suitable containers')
            : containerCounts.entries.map((e) => '${e.value} x ${e.key}').join(' + ');

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Export Actions Bar (PNG & PDF)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.image_outlined, size: 16),
                    label: Text(
                      isArabic ? 'تنزيل صور المحاكاة (PNG)' : 'Download Simulation Views (PNG)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      await ContainerLoadPlanExportService.exportSimulationImage(
                        context: context,
                        repaintKey: tab3dRepaintKey,
                        displayName: '${po.displayName} - 3D Simulation',
                        isArabic: isArabic,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.crimson,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: Text(
                      isArabic ? 'تنزيل مخطط التحميل (PDF)' : 'Download Loading Plan (PDF)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      await ContainerLoadPlanExportService.exportLoadingPlanPdf(
                        context: context,
                        repaintKey: tab3dRepaintKey,
                        displayName: po.displayName,
                        poNumber: po.poNumber,
                        companyName: po.companyName,
                        supplierName: po.supplierName,
                        plan: plan,
                        fleetSummary: fleetSummary,
                        totalPlanWeight: totalPlanWeight,
                        totalPlanVolume: totalPlanVolume,
                        totalPkgs: totalPkgs,
                        isArabic: isArabic,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Controls & Stacking Filter Row (Responsive Wrap)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardBackground : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '🔄 ${l.stackingSimulationModeLabel}:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        ),
                        ChoiceChip(
                          label: Text('✨ ${l.smartHybridOption}'),
                          selected: activeOrientationMode == CargoOrientationPreference.smartHybrid && activeStackingMode == true,
                          selectedColor: AppTheme.emerald,
                          labelStyle: TextStyle(
                            color: (activeOrientationMode == CargoOrientationPreference.smartHybrid && activeStackingMode == true) ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setTabState(() {
                                activeOrientationMode = CargoOrientationPreference.smartHybrid;
                                activeStackingMode = true;
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: Text('📐 ${l.flatOnlyOption}'),
                          selected: activeOrientationMode == CargoOrientationPreference.flatOnly && activeStackingMode == true,
                          selectedColor: AppTheme.cobalt,
                          labelStyle: TextStyle(
                            color: (activeOrientationMode == CargoOrientationPreference.flatOnly && activeStackingMode == true) ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setTabState(() {
                                activeOrientationMode = CargoOrientationPreference.flatOnly;
                                activeStackingMode = true;
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: Text('🚫 ${l.simulationModeFloorOnly}'),
                          selected: activeStackingMode == false,
                          selectedColor: Colors.orange.shade800,
                          labelStyle: TextStyle(
                            color: activeStackingMode == false ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setTabState(() {
                                activeStackingMode = false;
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: Text('🔀 ${l.simulationModeActualMixed}'),
                          selected: activeStackingMode == null,
                          selectedColor: AppTheme.charcoal,
                          labelStyle: TextStyle(
                            color: activeStackingMode == null ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setTabState(() {
                                activeStackingMode = null;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '👁️ ${l.projectionLabel}:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        ),
                        ChoiceChip(
                          label: Text(isArabic ? '🖼️ كلاهما (Both Views)' : '🖼️ Both Views'),
                          selected: viewProjection == 'both',
                          selectedColor: AppTheme.cobalt,
                          labelStyle: TextStyle(
                            color: viewProjection == 'both' ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            if (val) setTabState(() => viewProjection = 'both');
                          },
                        ),
                        ChoiceChip(
                          label: Text('📐 ${l.sideViewProjection}'),
                          selected: viewProjection == 'side',
                          selectedColor: AppTheme.cobalt,
                          labelStyle: TextStyle(
                            color: viewProjection == 'side' ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            if (val) setTabState(() => viewProjection = 'side');
                          },
                        ),
                        ChoiceChip(
                          label: Text('🔝 ${l.topViewProjection}'),
                          selected: viewProjection == 'top',
                          selectedColor: AppTheme.cobalt,
                          labelStyle: TextStyle(
                            color: viewProjection == 'top' ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            if (val) setTabState(() => viewProjection = 'top');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Fleet KPI Summary Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.charcoal.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.charcoal.withOpacity(0.12)),
                ),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceAround,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_boat_rounded, color: AppTheme.cobalt, size: 20),
                        const SizedBox(width: 6),
                        Text(l.requiredContainersSummary(fleetSummary), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal, size: 18),
                        const SizedBox(width: 6),
                        Text(l.totalPackagesSummary(totalPkgs, stackableInActive, nonStackableInActive), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : null)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.scale_outlined, color: AppTheme.emerald, size: 18),
                        const SizedBox(width: 6),
                        Text(l.totalWeightSummary(_formatWeight(totalPlanWeight)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.view_in_ar, color: AppTheme.orange, size: 18),
                        const SizedBox(width: 6),
                        Text(l.totalVolumeSummary(totalPlanVolume.toStringAsFixed(3)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.orange)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Plan Containers List (Wrapped in RepaintBoundary for PNG/PDF Export)
              RepaintBoundary(
                key: tab3dRepaintKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: plan.asMap().entries.map((pEntry) {
                    final pIdx = pEntry.key;
                    final res = pEntry.value;
                    if (res.containerCode == 'FAILED') {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF381414) : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.red.shade700 : Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppTheme.crimson, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                res.failureReason ?? l.packingFailureTitle,
                                style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final spacePct = (res.totalVolume / res.spec.internalVolumeCbm * 100);
                    final weightPct = (res.totalWeight / res.spec.maxPayloadKg * 100);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      color: isDark ? AppTheme.darkCardBackground : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    l.containerCardHeader(pIdx + 1, res.spec.code, res.placedItems.length, spacePct.toStringAsFixed(1), weightPct.toStringAsFixed(1)),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cobalt.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    l.internalDimensionsLabel(res.spec.internalLength.toStringAsFixed(0), res.spec.internalWidth.toStringAsFixed(0), res.spec.internalHeight.toStringAsFixed(0)),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (viewProjection == 'both') ...[
                              // Side View (Left Wall Removed)
                              Container(
                                height: 190,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: CustomPaint(
                                  painter: ContainerLoadPlanPainter(plan: res, isTopView: false),
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Top View (Roof Removed)
                              Container(
                                height: 150,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: CustomPaint(
                                  painter: ContainerLoadPlanPainter(plan: res, isTopView: true),
                                ),
                              ),
                            ] else ...[
                              Container(
                                height: 320,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: CustomPaint(
                                  painter: ContainerLoadPlanPainter(plan: res, isTopView: viewProjection == 'top'),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),

                            // Placed Items Details Table (Aggregated by Item Rule)
                            Theme(
                              data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                initiallyExpanded: true,
                                tilePadding: EdgeInsets.zero,
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      showDetailedCoordinates
                                          ? (isArabic ? '📐 تفاصيل الرص الإحداثي (${res.placedItems.length} طرد)' : '📐 Detailed Placement Coordinates (${res.placedItems.length} pkgs)')
                                          : (isArabic ? '📊 الأصناف المرصوصة مجمعة (${res.groupedItems.length} صنف | إجمالي ${res.placedItems.length} طرد)' : '📊 Grouped Items (${res.groupedItems.length} items | Total ${res.placedItems.length} pkgs)'),
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        foregroundColor: AppTheme.cobalt,
                                        side: const BorderSide(color: AppTheme.cobalt),
                                      ),
                                      icon: Icon(showDetailedCoordinates ? Icons.table_chart_outlined : Icons.format_list_numbered, size: 14),
                                      label: Text(
                                        showDetailedCoordinates ? (isArabic ? 'عرض مجمع حسب الأصناف' : 'Group by Items') : (isArabic ? 'عرض تفصيلي بالإحداثيات' : 'Detailed Coordinates'),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      onPressed: () => setTabState(() => showDetailedCoordinates = !showDetailedCoordinates),
                                    ),
                                  ],
                                ),
                                children: [
                                  if (!showDetailedCoordinates)
                                    Table(
                                      border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                                      columnWidths: const {
                                        0: FlexColumnWidth(0.6),
                                        1: FlexColumnWidth(2.5),
                                        2: FlexColumnWidth(1.2),
                                        3: FlexColumnWidth(1.6),
                                        4: FlexColumnWidth(1.2),
                                        5: FlexColumnWidth(1.8),
                                        6: FlexColumnWidth(1.2),
                                        7: FlexColumnWidth(1.2),
                                      },
                                      children: [
                                        TableRow(
                                          decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : Colors.grey.shade200),
                                          children: [
                                            const Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'الصنف / البند' : 'Item / Code', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'نوع الطرد' : 'Pkg Type', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'الأبعاد (سم)' : 'Dims (cm)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'العدد' : 'Qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'إجمالي الوزن' : 'Gross Wt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'الحجم' : 'CBM', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'الرص' : 'Stack', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                          ],
                                        ),
                                        ...res.groupedItems.asMap().entries.map((entry) {
                                          final idx = entry.key + 1;
                                          final g = entry.value;
                                          return TableRow(
                                            children: [
                                              Padding(padding: const EdgeInsets.all(6), child: Text('$idx', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                              Padding(padding: const EdgeInsets.all(6), child: Text(g.itemCodeOrDesc, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                              Padding(padding: const EdgeInsets.all(6), child: Text(g.packageType, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${g.length.toStringAsFixed(0)} × ${g.width.toStringAsFixed(0)} × ${g.height.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                              Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.cobalt.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text('${g.count}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt), textAlign: TextAlign.center),
                                                ),
                                              ),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${g.totalWeight.toStringAsFixed(1)} kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${g.volumeM3.toStringAsFixed(3)} m³', style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                              Padding(padding: const EdgeInsets.all(6), child: Text(g.isStackable ? (isArabic ? '📦 نعم' : 'Yes') : (isArabic ? '🚫 أرضي' : 'Floor'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: g.isStackable ? AppTheme.emerald : AppTheme.crimson), textAlign: TextAlign.center)),
                                            ],
                                          );
                                        }),
                                      ],
                                    )
                                  else
                                    Table(
                                      border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                                      columnWidths: const {
                                        0: FlexColumnWidth(0.8),
                                        1: FlexColumnWidth(2.2),
                                        2: FlexColumnWidth(1.8),
                                        3: FlexColumnWidth(1.2),
                                        4: FlexColumnWidth(2.0),
                                        5: FlexColumnWidth(1.2),
                                      },
                                      children: [
                                        TableRow(
                                          decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : Colors.grey.shade200),
                                          children: [
                                            const Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.thPackageCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.thDimensions, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.thWeight, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.thCoordinates, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.thStacking, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                          ],
                                        ),
                                        ...res.placedItems.asMap().entries.map((entry) {
                                          final idx = entry.key + 1;
                                          final item = entry.value;
                                          return TableRow(
                                            children: [
                                              Padding(padding: const EdgeInsets.all(6), child: Text('$idx', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                              Padding(padding: const EdgeInsets.all(6), child: Text(item.item.description ?? item.item.itemId, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${item.length.toStringAsFixed(0)} × ${item.width.toStringAsFixed(0)} × ${item.height.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                              Padding(padding: const EdgeInsets.all(6), child: Text(item.item.weight.toStringAsFixed(1), style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('X: ${item.x.toStringAsFixed(0)} | Y: ${item.y.toStringAsFixed(0)} | Z: ${item.z.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), textAlign: TextAlign.center)),
                                              Padding(padding: const EdgeInsets.all(6), child: Text(item.item.isStackable ? (isArabic ? '📦 نعم' : 'Yes') : (isArabic ? '🚫 أرضي' : 'Floor'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: item.item.isStackable ? AppTheme.emerald : AppTheme.crimson), textAlign: TextAlign.center)),
                                            ],
                                          );
                                        }),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVisualLoadPlannerDialog(BuildContext context, PurchaseOrderModel po) {
    final cargoItems = _extractCargoItemsFromPo(po);

    if (cargoItems.isEmpty) {
      final l = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.noCargoOrPalletToSimulate)),
      );
      return;
    }

    String viewProjection = 'both';
    bool showDetailedCoordinates = false;
    bool? activeStackingMode = cargoItems.any((i) => !i.isStackable) ? null : true;
    CargoOrientationPreference activeOrientationMode = CargoOrientationPreference.smartHybrid;
    final GlobalKey dialogRepaintKey = GlobalKey();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final l = dialogCtx.l10n;
        final isArabic = Localizations.localeOf(dialogCtx).languageCode == 'ar';
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final plan = ContainerRequirementEngine.planShipment(
              cargoItems,
              forceStackable: activeStackingMode,
              forceOrientation: activeOrientationMode,
            );

            final totalPkgs = cargoItems.length;
            final stackableInActive = activeStackingMode == true
                ? totalPkgs
                : (activeStackingMode == false ? 0 : cargoItems.where((c) => c.isStackable).length);
            final nonStackableInActive = totalPkgs - stackableInActive;

            final totalPlanWeight = plan.fold(0.0, (s, p) => s + p.totalWeight);
            final totalPlanVolume = plan.fold(0.0, (s, p) => s + p.totalVolume);

            final Map<String, int> containerCounts = {};
            for (final p in plan) {
              if (p.containerCode != 'FAILED') {
                containerCounts[p.containerCode] = (containerCounts[p.containerCode] ?? 0) + 1;
              }
            }
            final fleetSummary = containerCounts.isEmpty
                ? l.noSuitableContainers
                : containerCounts.entries.map((e) => '${e.value} x ${e.key}').join(' + ');

            return Dialog(
              backgroundColor: isDark ? AppTheme.darkSurface : null,
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                width: math.min(1180.0, MediaQuery.of(dialogCtx).size.width - 32),
                height: math.min(780.0, MediaQuery.of(dialogCtx).size.height - 48),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.cobalt.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.view_in_ar_rounded, color: AppTheme.cobalt, size: 24),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.containerLoadPlanTitle(po.displayName, po.poNumber),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              ),
                              Text(
                                l.containerLoadPlanMetrics(totalPlanVolume.toStringAsFixed(3), _formatWeight(totalPlanWeight), fleetSummary),
                                style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.image_outlined, color: AppTheme.cobalt),
                          tooltip: isArabic ? 'تنزيل صور المحاكاة (PNG)' : 'Download Simulation Image (PNG)',
                          onPressed: () async {
                            await ContainerLoadPlanExportService.exportSimulationImage(
                              context: dialogCtx,
                              repaintKey: dialogRepaintKey,
                              displayName: '${po.displayName} - 3D Simulation',
                              isArabic: isArabic,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson),
                          tooltip: isArabic ? 'تنزيل مخطط التحميل (PDF)' : 'Download Loading Plan (PDF)',
                          onPressed: () async {
                            await ContainerLoadPlanExportService.exportLoadingPlanPdf(
                              context: dialogCtx,
                              repaintKey: dialogRepaintKey,
                              displayName: po.displayName,
                              poNumber: po.poNumber,
                              companyName: po.companyName,
                              supplierName: po.supplierName,
                              plan: plan,
                              fleetSummary: fleetSummary,
                              totalPlanWeight: totalPlanWeight,
                              totalPlanVolume: totalPlanVolume,
                              totalPkgs: totalPkgs,
                              isArabic: isArabic,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Controls & Stacking Filter Row (Responsive Wrap)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCardBackground : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                      ),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '🔄 ${l.stackingSimulationModeLabel}:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              ),
                              ChoiceChip(
                                label: Text('✨ ${l.smartHybridOption}'),
                                selected: activeOrientationMode == CargoOrientationPreference.smartHybrid && activeStackingMode == true,
                                selectedColor: AppTheme.emerald,
                                labelStyle: TextStyle(
                                  color: (activeOrientationMode == CargoOrientationPreference.smartHybrid && activeStackingMode == true) ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setDialogState(() {
                                      activeOrientationMode = CargoOrientationPreference.smartHybrid;
                                      activeStackingMode = true;
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: Text('📐 ${l.flatOnlyOption}'),
                                selected: activeOrientationMode == CargoOrientationPreference.flatOnly && activeStackingMode == true,
                                selectedColor: AppTheme.cobalt,
                                labelStyle: TextStyle(
                                  color: (activeOrientationMode == CargoOrientationPreference.flatOnly && activeStackingMode == true) ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setDialogState(() {
                                      activeOrientationMode = CargoOrientationPreference.flatOnly;
                                      activeStackingMode = true;
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: Text('🚫 ${l.simulationModeFloorOnly}'),
                                selected: activeStackingMode == false,
                                selectedColor: Colors.orange.shade800,
                                labelStyle: TextStyle(
                                  color: activeStackingMode == false ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setDialogState(() {
                                      activeStackingMode = false;
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: Text('🔀 ${l.simulationModeActualMixed}'),
                                selected: activeStackingMode == null,
                                selectedColor: AppTheme.charcoal,
                                labelStyle: TextStyle(
                                  color: activeStackingMode == null ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setDialogState(() {
                                      activeStackingMode = null;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '👁️ ${l.projectionLabel}:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              ),
                              ChoiceChip(
                                label: Text(isArabic ? '🖼️ كلاهما (Both Views)' : '🖼️ Both Views'),
                                selected: viewProjection == 'both',
                                selectedColor: AppTheme.cobalt,
                                labelStyle: TextStyle(
                                  color: viewProjection == 'both' ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) setDialogState(() => viewProjection = 'both');
                                },
                              ),
                              ChoiceChip(
                                label: Text('📐 ${l.sideViewProjection}'),
                                selected: viewProjection == 'side',
                                selectedColor: AppTheme.cobalt,
                                labelStyle: TextStyle(
                                  color: viewProjection == 'side' ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) setDialogState(() => viewProjection = 'side');
                                },
                              ),
                              ChoiceChip(
                                label: Text('🔝 ${l.topViewProjection}'),
                                selected: viewProjection == 'top',
                                selectedColor: AppTheme.cobalt,
                                labelStyle: TextStyle(
                                  color: viewProjection == 'top' ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) setDialogState(() => viewProjection = 'top');
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Fleet KPI Summary Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.charcoal.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.charcoal.withOpacity(0.12)),
                      ),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceAround,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.directions_boat_rounded, color: AppTheme.cobalt, size: 20),
                              const SizedBox(width: 6),
                              Text(l.requiredContainersSummary(fleetSummary), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal, size: 18),
                              const SizedBox(width: 6),
                              Text(l.totalPackagesSummary(totalPkgs, stackableInActive, nonStackableInActive), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : null)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.scale_outlined, color: AppTheme.emerald, size: 18),
                              const SizedBox(width: 6),
                              Text(l.totalWeightSummary(_formatWeight(totalPlanWeight)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.view_in_ar, color: AppTheme.orange, size: 18),
                              const SizedBox(width: 6),
                              Text(l.totalVolumeSummary(totalPlanVolume.toStringAsFixed(3)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.orange)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Plan Containers List (Wrapped in RepaintBoundary for PNG/PDF Export)
                    Expanded(
                      child: RepaintBoundary(
                        key: dialogRepaintKey,
                        child: ListView.builder(
                        itemCount: plan.length,
                        itemBuilder: (ctx, pIdx) {
                          final res = plan[pIdx];
                          if (res.containerCode == 'FAILED') {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF381414) : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? Colors.red.shade700 : Colors.red.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppTheme.crimson, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      res.failureReason ?? l.packingFailureTitle,
                                      style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final spacePct = (res.totalVolume / res.spec.internalVolumeCbm * 100);
                          final weightPct = (res.totalWeight / res.spec.maxPayloadKg * 100);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            color: isDark ? AppTheme.darkCardBackground : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          l.containerCardHeader(pIdx + 1, res.spec.code, res.placedItems.length, spacePct.toStringAsFixed(1), weightPct.toStringAsFixed(1)),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.cobalt.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          l.internalDimensionsLabel(res.spec.internalLength.toStringAsFixed(0), res.spec.internalWidth.toStringAsFixed(0), res.spec.internalHeight.toStringAsFixed(0)),
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (viewProjection == 'both') ...[
                                    // Side View (Left Wall Removed)
                                    Container(
                                      height: 190,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade900,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: CustomPaint(
                                        painter: ContainerLoadPlanPainter(plan: res, isTopView: false),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // Top View (Roof Removed)
                                    Container(
                                      height: 150,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade900,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: CustomPaint(
                                        painter: ContainerLoadPlanPainter(plan: res, isTopView: true),
                                      ),
                                    ),
                                  ] else ...[
                                    Container(
                                      height: 320,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade900,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: CustomPaint(
                                        painter: ContainerLoadPlanPainter(plan: res, isTopView: viewProjection == 'top'),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),

                                  // Placed Items Details Table (Aggregated by Item Rule)
                                  Theme(
                                    data: Theme.of(dialogCtx).copyWith(dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                      initiallyExpanded: true,
                                      tilePadding: EdgeInsets.zero,
                                      title: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            showDetailedCoordinates
                                                ? (isArabic ? '📐 تفاصيل الرص الإحداثي (${res.placedItems.length} طرد)' : '📐 Detailed Placement Coordinates (${res.placedItems.length} pkgs)')
                                                : (isArabic ? '📊 الأصناف المرصوصة مجمعة (${res.groupedItems.length} صنف | إجمالي ${res.placedItems.length} طرد)' : '📊 Grouped Items (${res.groupedItems.length} items | Total ${res.placedItems.length} pkgs)'),
                                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                          ),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              foregroundColor: AppTheme.cobalt,
                                              side: const BorderSide(color: AppTheme.cobalt),
                                            ),
                                            icon: Icon(showDetailedCoordinates ? Icons.table_chart_outlined : Icons.format_list_numbered, size: 14),
                                            label: Text(
                                              showDetailedCoordinates ? (isArabic ? 'عرض مجمع حسب الأصناف' : 'Group by Items') : (isArabic ? 'عرض تفصيلي بالإحداثيات' : 'Detailed Coordinates'),
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                            onPressed: () => setDialogState(() => showDetailedCoordinates = !showDetailedCoordinates),
                                          ),
                                        ],
                                      ),
                                      children: [
                                        if (!showDetailedCoordinates)
                                          Table(
                                            border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                                            columnWidths: const {
                                              0: FlexColumnWidth(0.6),
                                              1: FlexColumnWidth(2.5),
                                              2: FlexColumnWidth(1.2),
                                              3: FlexColumnWidth(1.6),
                                              4: FlexColumnWidth(1.2),
                                              5: FlexColumnWidth(1.8),
                                              6: FlexColumnWidth(1.2),
                                              7: FlexColumnWidth(1.2),
                                            },
                                            children: [
                                              TableRow(
                                                decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : Colors.grey.shade200),
                                                children: [
                                                  const Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'الصنف / البند' : 'Item / Code', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'نوع الطرد' : 'Pkg Type', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'الأبعاد (سم)' : 'Dims (cm)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'العدد' : 'Qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'إجمالي الوزن' : 'Gross Wt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'الحجم' : 'CBM', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(isArabic ? 'الرص' : 'Stack', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                ],
                                              ),
                                              ...res.groupedItems.asMap().entries.map((entry) {
                                                final idx = entry.key + 1;
                                                final g = entry.value;
                                                return TableRow(
                                                  children: [
                                                    Padding(padding: const EdgeInsets.all(6), child: Text('$idx', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                                    Padding(padding: const EdgeInsets.all(6), child: Text(g.itemCodeOrDesc, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                                    Padding(padding: const EdgeInsets.all(6), child: Text(g.packageType, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                                    Padding(padding: const EdgeInsets.all(6), child: Text('${g.length.toStringAsFixed(0)} × ${g.width.toStringAsFixed(0)} × ${g.height.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                                    Padding(
                                                      padding: const EdgeInsets.all(6),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.cobalt.withOpacity(0.12),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text('${g.count}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt), textAlign: TextAlign.center),
                                                      ),
                                                    ),
                                                    Padding(padding: const EdgeInsets.all(6), child: Text('${_formatWeight(g.totalWeight)} kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                                    Padding(padding: const EdgeInsets.all(6), child: Text('${g.volumeM3.toStringAsFixed(3)} m³', style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                                    Padding(padding: const EdgeInsets.all(6), child: Text(g.isStackable ? (isArabic ? '📦 نعم' : 'Yes') : (isArabic ? '🚫 أرضي' : 'Floor'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: g.isStackable ? AppTheme.emerald : AppTheme.crimson), textAlign: TextAlign.center)),
                                                  ],
                                                );
                                              }),
                                            ],
                                          )
                                        else
                                          Table(
                                            border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                                            columnWidths: const {
                                              0: FlexColumnWidth(0.8),
                                              1: FlexColumnWidth(2.2),
                                              2: FlexColumnWidth(1.8),
                                              3: FlexColumnWidth(1.2),
                                              4: FlexColumnWidth(2.0),
                                              5: FlexColumnWidth(1.2),
                                            },
                                            children: [
                                              TableRow(
                                                decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : Colors.grey.shade200),
                                                children: [
                                                  const Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(l.thPackageCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(l.thDimensions, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(l.thWeight, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(l.thCoordinates, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(l.thStacking, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                ],
                                              ),
                                              ...res.placedItems.asMap().entries.map((entry) {
                                                final idx = entry.key + 1;
                                                final item = entry.value;
                                                return TableRow(
                                                  children: [
                                                    Padding(padding: const EdgeInsets.all(6), child: Text('$idx', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                                    Padding(padding: const EdgeInsets.all(6), child: Text(item.item.description ?? item.item.itemId, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                                    Padding(padding: const EdgeInsets.all(6), child: Text('${item.length.toStringAsFixed(0)} × ${item.width.toStringAsFixed(0)} × ${item.height.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                                    Padding(padding: const EdgeInsets.all(6), child: Text(_formatWeight(item.item.weight), style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                                    Padding(padding: const EdgeInsets.all(6), child: Text('X: ${item.x.toStringAsFixed(0)} | Y: ${item.y.toStringAsFixed(0)} | Z: ${item.z.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), textAlign: TextAlign.center)),
                                                    Padding(padding: const EdgeInsets.all(6), child: Text(item.item.isStackable ? (isArabic ? '📦 نعم' : 'Yes') : (isArabic ? '🚫 أرضي' : 'Floor'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: item.item.isStackable ? AppTheme.emerald : AppTheme.crimson), textAlign: TextAlign.center)),
                                                  ],
                                                );
                                              }),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPODialog(BuildContext context, PurchaseOrderModel? po, {Map<String, dynamic>? initialExtractedFields}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => POFormDialog(po: po, initialExtractedFields: initialExtractedFields),
    );
  }

  void _openSearchAndCloneDialog() {
    final state = ref.read(purchaseOrdersProvider);
    final locale = ref.read(localeProvider);
    final textDir = locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;
    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: locale,
        child: Directionality(
          textDirection: textDir,
          child: _SearchAndClonePODialog(
            orders: state.purchaseOrders,
            onSelectPO: (po) {
              Navigator.of(ctx).pop();
              _showCloneDialog(po);
            },
          ),
        ),
      ),
    );
  }

  void _showCloneDialog(PurchaseOrderModel po) {
    final l = context.l10n;
    final isAr = Directionality.of(context) == TextDirection.rtl || Localizations.localeOf(context).languageCode == 'ar';
    CloneEntityReviewDialog.show(
      context,
      entityType: isAr ? 'أمر شراء' : 'Purchase Order',
      sourceCode: po.poNumber,
      suggestedNewCode: '${po.poNumber}${TableRowCloneHelper.copyCodeSuffix}',
      sourceTitle: po.displayName,
      copiedFieldsSummary: {
        isAr ? 'الشركة المستوردة' : 'Importer': po.companyName ?? '-',
        isAr ? 'المورد الأجنبي' : 'Supplier': po.supplierName ?? '-',
        isAr ? 'المشروع' : 'Project': po.projectName ?? '-',
        isAr ? 'العملة والشرط' : 'Currency / Incoterm': '${po.currencyCode ?? "USD"} (${po.incotermCode ?? "-"})',
      },
      mandatorilyResetFields: [
        l.cloneFieldStatusDraftBadge,
        l.cloneFieldShipmentUnlinked,
        l.cloneFieldAllocationsReset,
        isAr ? 'تصفير تواريخ الشحن والاستلام' : 'Reset delivery and order dates',
      ],
      allowCopyLineItems: true,
      allowCopyAttachments: true,
      initialCopyLineItems: true,
      initialCopyAttachments: true,
      onConfirm: ({
        required String newCode,
        required String newTitle,
        required bool copyLineItems,
        required bool copyAttachments,
        String? notes,
      }) async {
        try {
          await ref.read(purchaseOrdersProvider.notifier).clonePurchaseOrder(
            po.poId!,
            {
              'new_po_number': newCode,
              'new_po_reference': newTitle.isNotEmpty ? newTitle : null,
              'copy_items': copyLineItems,
              'copy_packing_list': copyLineItems,
              'copy_pallet_plan': copyAttachments,
              if (notes != null) 'notes': notes,
            },
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l.clonePoSuccess(newCode)),
                backgroundColor: AppTheme.emerald,
                duration: const Duration(seconds: 3),
              ),
            );
            ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l.clonePoError(e.toString())),
                backgroundColor: AppTheme.crimson,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildMobilePOCardsList(
    BuildContext context,
    List<PurchaseOrderModel> orders, {
    bool shrinkWrap = false,
    ScrollPhysics? physics,
  }) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: const EdgeInsets.all(8),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final po = orders[index];
        final statusColor = po.status == 'Approved'
            ? AppTheme.wcagEmerald
            : po.status == 'In Transit'
                ? AppTheme.wcagCobalt
                : po.status == 'Closed'
                    ? (isDark ? const Color(0xFF64748B) : Colors.grey.shade600)
                    : AppTheme.wcagOrange;

        final invoiceDateStr = po.orderDate != null
            ? '${po.orderDate!.year}-${po.orderDate!.month.toString().padLeft(2, '0')}-${po.orderDate!.day.toString().padLeft(2, '0')}'
            : '-';
        final amountStr = '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}';
        final cbmWeightStr = '${po.totalCbm.toStringAsFixed(2)} m³ / ${_formatWeight(po.totalGrossWeightKg)} kg';
        final localizedStatus = _getStatusLabel(po.status, l);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: PO Number / Title & Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showPODetailsDialog(context, po),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            po.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          if (po.displayName != po.poNumber) ...[
                            const SizedBox(height: 2),
                            LtrText(
                              po.poNumber,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      localizedStatus,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Details grid
              Text(
                '${l.importingCompany}: ${po.companyName ?? "COMP-#${po.companyId}"}',
                style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800),
              ),
              const SizedBox(height: 2),
              Text(
                '${l.foreignSupplier}: ${po.supplierName ?? "SUP-#${po.supplierId}"}${po.countryOfOrigin != null ? " (${po.countryOfOrigin})" : ""}',
                style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${l.totalFobMetric}: $amountStr',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.wcagEmerald : Colors.green.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cbmWeightStr,
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                  ),
                ],
              ),
              const Divider(height: 16),

              // Bottom Actions Row (Responsive)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${l.invoiceDateCol}: $invoiceDateStr',
                      style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (po.poId != null)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.cobalt, size: 18),
                      tooltip: l.poBalanceLedgerTooltip,
                      onPressed: () => showPOBalanceLedgerDialog(
                        context,
                        ref,
                        poId: po.poId!,
                        poCode: po.poNumber,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: RowActionsPill(
                  onView: () => _showPODetailsDialog(context, po),
                  onEdit: () => _showPODialog(context, po),
                  onClone: () => _showCloneDialog(po),
                  cloneTooltip: l.cloneRowTooltip,
                  onPrint: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l.printPoAndPackingList(po.displayName, po.poNumber)),
                        backgroundColor: AppTheme.charcoal,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  onDelete: () async {
                    final isActive = po.isActive;
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l.confirmActionTitle),
                        content: Text(isActive
                            ? l.confirmDeactivatePo(po.displayName)
                            : l.confirmRestorePo(po.displayName)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: isActive ? AppTheme.crimson : AppTheme.cobalt),
                            child: Text(isActive ? l.deactivateBtn : l.restore, style: const TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      if (po.isActive) {
                        await ref.read(purchaseOrdersProvider.notifier).deletePurchaseOrder(po.poId!);
                      } else {
                        await ref.read(purchaseOrdersProvider.notifier).restorePurchaseOrder(po.poId!);
                      }
                    }
                  },
                  deleteTooltip: po.isActive ? l.deactivatePoTooltip : l.restorePoTooltip,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==================================================
// PO & Packing List Reconciliation Helper & Dialog
// ==================================================


// ==================================================
// Dedicated Search & Clone Dialog for Purchase Orders (UX-CLONE-011)
// ==================================================
class _SearchAndClonePODialog extends StatefulWidget {
  final List<PurchaseOrderModel> orders;
  final ValueChanged<PurchaseOrderModel> onSelectPO;

  const _SearchAndClonePODialog({
    required this.orders,
    required this.onSelectPO,
  });

  @override
  State<_SearchAndClonePODialog> createState() => _SearchAndClonePODialogState();
}

class _SearchAndClonePODialogState extends State<_SearchAndClonePODialog> {
  final TextEditingController _queryController = TextEditingController();
  late List<PurchaseOrderModel> _filteredOrders;

  @override
  void initState() {
    super.initState();
    _filteredOrders = widget.orders;
    _queryController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _queryController.removeListener(_onSearchChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _queryController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredOrders = widget.orders;
      } else {
        _filteredOrders = widget.orders.where((po) {
          final num = po.poNumber.toLowerCase();
          final ref = (po.poReference ?? '').toLowerCase();
          final pi = (po.proformaInvoiceNumber ?? '').toLowerCase();
          final comp = (po.companyName ?? '').toLowerCase();
          final supp = (po.supplierName ?? '').toLowerCase();
          final prj = (po.projectName ?? '').toLowerCase();
          return num.contains(query) ||
              ref.contains(query) ||
              pi.contains(query) ||
              comp.contains(query) ||
              supp.contains(query) ||
              prj.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl || Localizations.localeOf(context).languageCode == 'ar';
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDark ? AppTheme.darkCardBackground : Colors.white,
      child: Container(
        width: math.min(720.0, screenWidth - 32),
        height: math.min(600.0, screenHeight - 64),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.wcagCobalt.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.control_point_duplicate_rounded, color: AppTheme.wcagCobalt, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.searchAndClonePoDialogTitle,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.searchAndClonePoSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                hintText: l.searchByPoOrSupplierOrItemHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _queryController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _queryController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            // List of matching POs
            Expanded(
              child: _filteredOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            l.noMatchingPosFound,
                            style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filteredOrders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final po = _filteredOrders[idx];
                        final amountStr = '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          po.displayName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
                                          ),
                                        ),
                                        if (po.displayName != po.poNumber) ...[
                                          const SizedBox(width: 8),
                                          LtrText(
                                            po.poNumber,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${po.companyName ?? "-"} │ ${po.supplierName ?? "-"} │ $amountStr',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.wcagCobalt,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                icon: const Icon(Icons.control_point_duplicate_rounded, size: 16, color: Colors.white),
                                label: Text(
                                  isAr ? 'استنساخ' : 'Clone',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                onPressed: () => widget.onSelectPO(po),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
