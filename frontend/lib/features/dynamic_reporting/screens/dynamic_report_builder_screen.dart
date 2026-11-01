import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/projects/providers/projects_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/dynamic_reporting/models/dynamic_report_models.dart';
import 'package:frontend/features/dynamic_reporting/widgets/builder/dynamic_report_builder_actions.dart';
import 'package:frontend/features/dynamic_reporting/widgets/builder/dynamic_report_builder_constants.dart';
import 'package:frontend/features/dynamic_reporting/widgets/builder/dynamic_report_cell_resolver.dart';
import 'package:frontend/features/dynamic_reporting/widgets/builder/dynamic_report_summary_bar.dart';
import 'package:frontend/features/dynamic_reporting/widgets/builder/dynamic_report_table_view.dart';
import 'package:frontend/features/dynamic_reporting/widgets/dynamic_report_column_picker_sheet.dart';
import 'package:frontend/features/dynamic_reporting/widgets/dynamic_report_filter_toolbar.dart';

/// Dynamic Report Builder Screen Coordinator.
/// Provides dynamic custom reports and presets for ECO Radar & SCAS Tracker.
class DynamicReportBuilderScreen extends ConsumerStatefulWidget {
  const DynamicReportBuilderScreen({super.key});

  /// 15 milestone & document tracking columns from ECO preset.
  static const List<String> kEcoPresetColumnIds =
      DynamicReportBuilderConstants.kEcoPresetColumnIds;

  /// 16 operational tracking columns from SCAS preset.
  static const List<String> kScasPresetColumnIds =
      DynamicReportBuilderConstants.kScasPresetColumnIds;

  @override
  ConsumerState<DynamicReportBuilderScreen> createState() =>
      _DynamicReportBuilderScreenState();
}

class _DynamicReportBuilderScreenState
    extends ConsumerState<DynamicReportBuilderScreen> {
  ReportTemplateMode _templateMode = ReportTemplateMode.eco;
  DateTime _lastUpdatedAt = DateTime.now();

  late final List<DynamicReportColumn> _masterColumns;

  String _filterMode = 'All';
  String _filterPriority = 'All';
  final String _filterStatus = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _masterColumns = DynamicReportBuilderConstants.buildMasterColumnCatalog();
    _refreshData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshData() {
    setState(() {
      _lastUpdatedAt = DateTime.now();
    });
    Future.microtask(() {
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
      if (!ref.read(projectsProvider).isLoading) {
        ref.read(projectsProvider.notifier).fetchProjects();
      }
      if (!ref.read(purchaseOrdersProvider).isLoading) {
        ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      }
    });
  }

  List<DynamicReportColumn> _getActiveColumns() {
    switch (_templateMode) {
      case ReportTemplateMode.eco:
        return DynamicReportBuilderConstants.kEcoPresetColumnIds
            .map((id) =>
                DynamicReportColumn(id: id, categoryId: 'eco_radar', isVisible: true))
            .toList();
      case ReportTemplateMode.scas:
        return DynamicReportBuilderConstants.kScasPresetColumnIds
            .map((id) =>
                DynamicReportColumn(id: id, categoryId: 'scas_tracker', isVisible: true))
            .toList();
      case ReportTemplateMode.custom:
        return _masterColumns.where((c) => c.isVisible).toList();
    }
  }

  void _showColumnPicker() {
    DynamicReportColumnPickerSheet.show(
      context: context,
      masterColumns: _masterColumns,
      getColumnLabel: DynamicReportBuilderConstants.getColumnLabel,
      getCategoryTitle: DynamicReportBuilderConstants.getCategoryTitle,
      onApply: () => setState(() => _templateMode = ReportTemplateMode.custom),
      onStateChanged: () => setState(() {}),
    );
  }

  Future<void> _exportToCSV(
    List<ImportFileModel> files,
    List<DynamicReportColumn> activeCols,
  ) async {
    await DynamicReportBuilderActions.exportToExcel(
      context: context,
      ref: ref,
      files: files,
      activeCols: activeCols,
      templateMode: _templateMode,
      lastUpdatedAt: _lastUpdatedAt,
    );
  }

  Future<void> _exportToPDF(
    List<ImportFileModel> files,
    List<DynamicReportColumn> activeCols,
  ) async {
    await DynamicReportBuilderActions.exportToPdf(
      context: context,
      ref: ref,
      files: files,
      activeCols: activeCols,
      templateMode: _templateMode,
      lastUpdatedAt: _lastUpdatedAt,
    );
  }

  Future<void> _copyDataToClipboard(
    List<ImportFileModel> files,
    List<DynamicReportColumn> activeCols,
  ) async {
    await DynamicReportBuilderActions.copyDataToClipboard(
      context: context,
      ref: ref,
      files: files,
      activeCols: activeCols,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final importFilesState = ref.watch(importFilesProvider);
    ref.watch(purchaseOrdersProvider);
    final activeCols = _getActiveColumns();
    final timestampFormatted =
        DynamicReportBuilderConstants.formatDateTime(_lastUpdatedAt);

    final allFiles = importFilesState.value ?? [];
    final filtered = DynamicReportCellResolver.filterFiles(
      files: allFiles,
      templateMode: _templateMode,
      filterMode: _filterMode,
      filterPriority: _filterPriority,
      filterStatus: _filterStatus,
      searchQuery: _searchQuery,
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: PageHeader(
        icon: Icons.assessment,
        iconColor: AppTheme.cobalt,
        title: l.dynReportBuilderTitle,
        subtitle: l.dynLastUpdatedLabel(timestampFormatted),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: l.dynRefreshTooltip,
            onPressed: _refreshData,
          ),
          const BackToDashboardButton(),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DynamicReportFilterToolbar(
                templateMode: _templateMode,
                onTemplateModeChanged: (mode) =>
                    setState(() => _templateMode = mode),
                onCustomizeColumns: _showColumnPicker,
                activeColumnCount: activeCols.length,
                masterColumnCount: _masterColumns.length,
                searchController: _searchController,
                onSearchChanged: (v) => setState(() => _searchQuery = v.trim()),
                filterMode: _filterMode,
                onFilterModeChanged: (v) => setState(() => _filterMode = v),
                filterPriority: _filterPriority,
                onFilterPriorityChanged: (v) =>
                    setState(() => _filterPriority = v),
                onExportCsv: () => _exportToCSV(filtered, activeCols),
                onExportPdf: () => _exportToPDF(filtered, activeCols),
                onCopyTsv: () => _copyDataToClipboard(filtered, activeCols),
                filteredCount: filtered.length,
              ),
              const SizedBox(height: 10),
              DynamicReportSummaryBar(
                totalCount: allFiles.length,
                filteredCount: filtered.length,
                activeColumnCount: activeCols.length,
                masterColumnCount: _masterColumns.length,
                templateMode: _templateMode,
                filteredFiles: filtered,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: DynamicReportTableView(
                  files: filtered,
                  activeColumns: activeCols,
                  templateMode: _templateMode,
                  isLoading: importFilesState.isLoading,
                  error: importFilesState.error,
                  onRetry: _refreshData,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
