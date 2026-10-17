import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/action_toolbar.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/helpers/master_data_action_helper.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../audit_logs/widgets/row_history_dialog.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../incoterms/providers/incoterms_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../models/project_model.dart';
import '../providers/projects_provider.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  String _selectedStatus = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _statuses = ['All', 'Open', 'Closed', 'On Hold'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projectsState = ref.read(projectsProvider);
      if (!projectsState.isLoading) {
        ref.read(projectsProvider.notifier).fetchProjects();
      }
      final companiesState = ref.read(importCompaniesProvider);
      if (!companiesState.isLoading) {
        ref.read(importCompaniesProvider.notifier).fetchCompanies();
      }
      final suppliersState = ref.read(suppliersProvider);
      if (!suppliersState.isLoading) {
        ref.read(suppliersProvider.notifier).fetchSuppliers();
      }
      final incotermsState = ref.read(incotermsProvider);
      if (!incotermsState.isLoading) {
        ref.read(incotermsProvider.notifier).fetchIncoterms();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getStatusLabel(BuildContext context, String status) {
    final l10n = context.l10n;
    switch (status) {
      case 'All':
        return l10n.statusAll;
      case 'Open':
        return l10n.statusOpen;
      case 'Closed':
        return l10n.statusClosed;
      case 'On Hold':
        return l10n.statusOnHold;
      default:
        return status;
    }
  }

  String _getImportTypeLabel(BuildContext context, String importType) {
    final l10n = context.l10n;
    if (importType.contains('Direct Commercial') || importType == 'Direct Commercial') {
      return l10n.importTypeDirectCommercial;
    }
    if (importType.contains('Free Zone') || importType == 'Free Zone') {
      return l10n.importTypeFreeZone;
    }
    if (importType.contains('Temporary Release') || importType.contains('السماح المؤقت')) {
      return l10n.importTypeTemporaryRelease;
    }
    if (importType.contains('Drawback') || importType == 'Drawback') {
      return l10n.importTypeDrawback;
    }
    if (importType.contains('Project Equipment') || importType.contains('معدات مشروعات')) {
      return l10n.importTypeProjectEquipment;
    }
    return importType;
  }

  String _getCategoryLabel(BuildContext context, String category) {
    final l10n = context.l10n;
    switch (category.trim()) {
      case 'FCL Container':
        return l10n.categoryFclContainer;
      case 'LCL Breakbulk':
        return l10n.categoryLclBreakbulk;
      case 'Air Freight':
        return l10n.categoryAirFreight;
      case 'Bulk Cargo':
        return l10n.categoryBulkCargo;
      case 'Multimodal':
        return l10n.categoryMultimodal;
      case 'Courier':
        return l10n.categoryCourier;
      default:
        return category;
    }
  }

  String _formatBudget(BuildContext context, ProjectModel p) {
    if (p.totalBudgetUsd == null) return context.l10n.projectBudgetNotSet;
    return '${p.budgetCurrency} ${p.totalBudgetUsd!.toStringAsFixed(2)}';
  }

  String _getPriorityLabel(BuildContext context, String priority) {
    final l10n = context.l10n;
    switch (priority) {
      case 'Low':
        return l10n.priorityLow;
      case 'Medium':
        return l10n.priorityMedium;
      case 'High':
        return l10n.priorityHigh;
      case 'Urgent':
      case 'Urgent / حرج':
        return l10n.priorityUrgent;
      default:
        return priority;
    }
  }

  void _copyProjectsTsv(List<ProjectModel> projects) {
    final l10n = context.l10n;
    final headers = [
      l10n.projectCodeCol,
      l10n.projectNameAndOwnerCol,
      l10n.projectOwnerLabelField.replaceAll('*', '').trim(),
      l10n.companyAndSupplierCol,
      l10n.primarySupplierLabel.replaceAll('*', '').trim(),
      l10n.importTypeLabel.replaceAll('*', '').trim(),
      l10n.projectColShipmentCategories,
      l10n.defaultIncotermLabel.replaceAll('*', '').trim(),
      l10n.budgetUsdCol,
      l10n.targetEndDateCol,
      l10n.capMultiShipment,
      l10n.capMultiCompany,
      l10n.statusCol,
      l10n.projectColActive,
      l10n.projectNotesLabel,
    ];

    final rows = projects.map((p) {
      final categoriesText = p.shipmentCategory
          .split(',')
          .map((c) => _getCategoryLabel(context, c))
          .join(', ');
      final incotermText = p.incotermCode ?? l10n.projectIncotermFallback;
      final budgetText = _formatBudget(context, p);
      final targetDateText = p.targetEndDate ?? '';
      final activeText = p.isActive ? l10n.projectActiveYes : l10n.projectActiveNo;
      final multiShipmentText = p.allowMultiShipment ? l10n.projectMultiShipmentYes : l10n.projectMultiShipmentNo;
      final multiCompanyText = p.allowMultiCompany ? l10n.projectMultiCompanyYes : l10n.projectMultiCompanyNo;
      final notesText = (p.notes != null && p.notes!.trim().isNotEmpty) ? p.notes!.trim() : l10n.projectNotesFallback;

      return [
        p.projectCode,
        p.projectName,
        p.projectOwner,
        p.companyName ?? l10n.projectCompanyFallback(p.companyId),
        p.supplierName ?? '#${p.supplierId}',
        _getImportTypeLabel(context, p.importType),
        categoriesText,
        incotermText,
        budgetText,
        targetDateText,
        multiShipmentText,
        multiCompanyText,
        _getStatusLabel(context, p.status),
        activeText,
        notesText,
      ].join('\t');
    }).join('\n');

    final tsv = '${headers.join('\t')}\n$rows';
    CopyHelper.copy(context, tsv, customMessage: l10n.projectsExportTsvSuccess);
  }

  String _buildProjectSummary(BuildContext context, ProjectModel p) {
    final l10n = context.l10n;
    final categoriesText = p.shipmentCategory
        .split(',')
        .map((c) => _getCategoryLabel(context, c))
        .join(', ');
    final incotermText = p.incotermCode ?? l10n.projectIncotermFallback;
    final budgetText = _formatBudget(context, p);
    final targetDateText = p.targetEndDate ?? '-';
    final activeText = p.isActive ? l10n.projectActiveYes : l10n.projectActiveNo;
    final multiShipmentText = p.allowMultiShipment ? l10n.projectMultiShipmentYes : l10n.projectMultiShipmentNo;
    final multiCompanyText = p.allowMultiCompany ? l10n.projectMultiCompanyYes : l10n.projectMultiCompanyNo;
    final notesText = (p.notes != null && p.notes!.trim().isNotEmpty) ? p.notes!.trim() : l10n.projectNotesFallback;

    return '''
[${p.projectCode}] ${p.projectName}
- ${l10n.projectOwnerLabelField.replaceAll('*', '').trim()}: ${p.projectOwner}
- ${l10n.importingCompaniesFieldLabel.replaceAll('*', '').trim()}: ${p.companyName ?? l10n.projectCompanyFallback(p.companyId)}
- ${l10n.primarySupplierLabel.replaceAll('*', '').trim()}: ${p.supplierName ?? '#${p.supplierId}'}
- ${l10n.importTypeLabel.replaceAll('*', '').trim()}: ${_getImportTypeLabel(context, p.importType)}
- ${l10n.projectColShipmentCategories}: $categoriesText
- ${l10n.defaultIncotermLabel.replaceAll('*', '').trim()}: $incotermText
- ${l10n.budgetUsdCol}: $budgetText
- ${l10n.targetEndDateLabel}: $targetDateText
- ${l10n.capMultiShipment}: $multiShipmentText
- ${l10n.capMultiCompany}: $multiCompanyText
- ${l10n.statusCol}: ${_getStatusLabel(context, p.status)}
- ${l10n.projectColActive}: $activeText
- ${l10n.projectNotesLabel}: $notesText
'''.trim();
  }

  String _buildProjectRowSummary(BuildContext context, ProjectModel p) {
    final l10n = context.l10n;
    final categoriesText = p.shipmentCategory
        .split(',')
        .map((c) => _getCategoryLabel(context, c))
        .join(', ');
    final incotermText = p.incotermCode ?? l10n.projectIncotermFallback;
    final budgetText = _formatBudget(context, p);
    final targetDateText = p.targetEndDate ?? '';
    final activeText = p.isActive ? l10n.projectActiveYes : l10n.projectActiveNo;
    final multiShipmentText = p.allowMultiShipment ? l10n.projectMultiShipmentYes : l10n.projectMultiShipmentNo;
    final multiCompanyText = p.allowMultiCompany ? l10n.projectMultiCompanyYes : l10n.projectMultiCompanyNo;

    return [
      p.projectCode,
      p.projectName,
      p.projectOwner,
      p.companyName ?? l10n.projectCompanyFallback(p.companyId),
      p.supplierName ?? '#${p.supplierId}',
      _getImportTypeLabel(context, p.importType),
      categoriesText,
      incotermText,
      budgetText,
      targetDateText,
      multiShipmentText,
      multiCompanyText,
      _getStatusLabel(context, p.status),
      activeText,
    ].join('\t');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final projectsAsync = ref.watch(projectsProvider);

    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey.shade100,
      appBar: PageHeader(
        icon: Icons.folder_special_outlined,
        title: l10n.projectsScreenTitle,
        subtitle: l10n.projectsScreenSubtitle,
        actions: const [
          BackToDashboardButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ActionToolbar(
                primaryActions: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt,
                      foregroundColor: Colors.white,
                      minimumSize: Size(0, density.buttonHeight),
                      padding: density.buttonPadding,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: Icon(Icons.add, size: density.buttonIconSize),
                    label: Text(
                      l10n.createNewProjectBtn,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
                    ),
                    onPressed: () => _showProjectDialog(context),
                  ),
                ],
                moreActionItems: MasterDataActionHelper.buildStandardMoreActionItems(
                  context: context,
                  includeTsv: projectsAsync.valueOrNull != null && projectsAsync.valueOrNull!.isNotEmpty,
                ),
                onMoreActionSelected: (val) {
                  switch (val) {
                    case 'export_excel':
                      MasterDataActionHelper.downloadFile(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'projects',
                        actionEndpoint: 'export-excel',
                        defaultFileName: 'Projects_CostCenters_Report.xlsx',
                        dialogTitle: 'تصدير المشاريع ومراكز التكلفة إكسيل',
                      );
                      break;
                    case 'export_pdf':
                      MasterDataActionHelper.downloadFile(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'projects',
                        actionEndpoint: 'export-pdf',
                        defaultFileName: 'Projects_CostCenters_Report.pdf',
                        dialogTitle: 'تصدير المشاريع ومراكز التكلفة PDF',
                      );
                      break;
                    case 'copy_tsv':
                      if (projectsAsync.valueOrNull != null) {
                        _copyProjectsTsv(projectsAsync.valueOrNull!);
                      }
                      break;
                    case 'download_template':
                      MasterDataActionHelper.downloadFile(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'projects',
                        actionEndpoint: 'excel-template',
                        defaultFileName: 'Projects_CostCenters_Template.xlsx',
                        dialogTitle: 'تنزيل نموذج المشاريع ومراكز التكلفة',
                      );
                      break;
                    case 'import_excel':
                      MasterDataActionHelper.importExcel(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'projects',
                        onImportSuccess: () => ref.read(projectsProvider.notifier).fetchProjects(),
                      );
                      break;
                  }
                },
                searchController: _searchController,
                searchHint: l10n.projectsSearchHint,
                onSearchChanged: (val) {
                  _searchQuery = val;
                  ref.read(projectsProvider.notifier).fetchProjects(
                        status: _selectedStatus,
                        search: val,
                      );
                },
                filters: [
                  SizedBox(
                    width: 140,
                    height: density.buttonHeight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkElevatedSurface : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.black26, width: 0.8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          isExpanded: true,
                          style: TextStyle(
                            fontSize: density.buttonFontSize - 1,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          ),
                          items: _statuses.map((st) => DropdownMenuItem(
                            value: st,
                            child: Text(_getStatusLabel(context, st)),
                          )).toList(),
                          onChanged: (st) {
                            if (st != null) {
                              setState(() {
                                _selectedStatus = st;
                              });
                              ref.read(projectsProvider.notifier).fetchProjects(
                                    status: st,
                                    search: _searchQuery,
                                  );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
                quickDataActions: [
                  IconButton(
                    icon: Icon(Icons.refresh, size: density.buttonIconSize + 2),
                    tooltip: l10n.liveRefresh,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: density.buttonHeight,
                      minHeight: density.buttonHeight,
                    ),
                    onPressed: () => ref.read(projectsProvider.notifier).fetchProjects(
                          status: _selectedStatus,
                          search: _searchQuery,
                        ),
                  ),
                  if (projectsAsync.valueOrNull != null && projectsAsync.valueOrNull!.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.copy_rounded, size: density.buttonIconSize + 2, color: AppTheme.cobalt),
                      tooltip: l10n.projectsExportTsvBtn,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: density.buttonHeight,
                        minHeight: density.buttonHeight,
                      ),
                      onPressed: () => _copyProjectsTsv(projectsAsync.valueOrNull!),
                    ),
                ],
              ),
              const SizedBox(height: 8),

            // Table Content
            Expanded(
              child: projectsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.cobalt)),
                error: (err, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.crimson),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          l10n.projectsFetchError(err.toString()),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cobalt,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(l10n.retryConnection, style: const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          ref.read(projectsProvider.notifier).fetchProjects(status: _selectedStatus, search: _searchQuery);
                        },
                      ),
                    ],
                  ),
                ),
                data: (projects) {
                  if (projects.isEmpty) {
                    return Center(
                      child: Text(l10n.noProjectsFound, style: const TextStyle(color: Colors.grey, fontSize: 15)),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: MediaQuery.of(context).size.width > 1100
                                  ? MediaQuery.of(context).size.width - 300
                                  : 1050,
                            ),
                            child: Table(
                              columnWidths: const {
                                0: FixedColumnWidth(170),
                                1: FixedColumnWidth(120),
                                2: FlexColumnWidth(3),
                                3: FlexColumnWidth(2.5),
                                4: FlexColumnWidth(2),
                                5: FixedColumnWidth(190),
                                6: FixedColumnWidth(130),
                                7: FixedColumnWidth(95),
                              },
                              children: [
                                // Header
                                TableRow(
                                  decoration: const BoxDecoration(color: AppTheme.charcoal),
                                  children: [
                                    l10n.actionsCol,
                                    l10n.projectCodeCol,
                                    l10n.projectNameAndOwnerCol,
                                    l10n.companyAndSupplierCol,
                                    l10n.typeAndCategoryCol,
                                    l10n.budgetUsdCol,
                                    l10n.capabilitiesCol,
                                    l10n.statusCol,
                                  ]
                                      .map((h) => Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            child: Text(
                                              h,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),

                                // Data Rows
                                ...projects.asMap().entries.map((entry) {
                                  final p = entry.value;
                                  final isEven = entry.key % 2 == 0;
                                  final isActive = p.isActive;

                                  final categoriesText = p.shipmentCategory
                                      .split(',')
                                      .map((c) => _getCategoryLabel(context, c))
                                      .join(', ');
                                  final rowSummary = _buildProjectRowSummary(context, p);
                                  final budgetText = _formatBudget(context, p);
                                  final incotermText = p.incotermCode ?? l10n.projectIncotermFallback;

                                  return TableRow(
                                    decoration: BoxDecoration(
                                      color: isEven ? Colors.white : Colors.grey.shade50,
                                    ),
                                    children: [
                                      // Actions
                                      _cell(
                                        value: p.projectCode,
                                        rowSummary: rowSummary,
                                        child: RowActionsPill(
                                          onView: () {
                                            if (p.projectId != null) {
                                              RowHistoryDialog.show(
                                                context,
                                                entityType: 'Project',
                                                entityId: p.projectId!,
                                                entityTitle: p.projectName,
                                              );
                                            }
                                          },
                                          onEdit: () => _showProjectDialog(context, project: p),
                                          onPrint: () {
                                            final summary = _buildProjectSummary(context, p);
                                            CopyHelper.copy(context, summary, customMessage: l10n.projectCopySummarySuccess);
                                          },
                                          printTooltip: l10n.projectCopySummaryBtn,
                                          onDelete: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => SelectionArea(
                                                child: AlertDialog(
                                                  title: Text(l10n.confirmActionTitle),
                                                  content: Text(isActive
                                                      ? l10n.confirmDeactivateProject(p.projectName)
                                                      : l10n.confirmActivateProject(p.projectName)),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(ctx, false),
                                                      child: Text(l10n.cancel),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.pop(ctx, true),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: isActive ? AppTheme.crimson : AppTheme.emerald,
                                                      ),
                                                      child: Text(
                                                        isActive ? l10n.deactivateBtn : l10n.activateBtn,
                                                        style: const TextStyle(color: Colors.white),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                            if (confirm == true && p.projectId != null) {
                                              ref.read(projectsProvider.notifier).toggleActive(p.projectId!, isActive);
                                            }
                                          },
                                          deleteTooltip: isActive ? l10n.deactivateProjectTooltip : l10n.activateProjectTooltip,
                                        ),
                                      ),
                                      // Code
                                      _cell(
                                        value: p.projectCode,
                                        rowSummary: rowSummary,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cobalt.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: CopyableText(
                                            p.projectCode,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: AppTheme.cobalt,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Project Name & Owner
                                      _cell(
                                        value: '${p.projectName} (${p.projectOwner})',
                                        rowSummary: rowSummary,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CopyableText(
                                              p.projectName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isActive ? AppTheme.charcoal : Colors.grey.shade700,
                                                decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              l10n.projectOwnerLabel(p.projectOwner),
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Import Company & Supplier
                                      _cell(
                                        value: '${p.companyName ?? l10n.projectCompanyFallback(p.companyId)} - ${p.supplierName ?? '#${p.supplierId}'}',
                                        rowSummary: rowSummary,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.companyName ?? l10n.projectCompanyFallback(p.companyId),
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              l10n.projectSupplierLabel(p.supplierName ?? '#${p.supplierId}'),
                                              style: const TextStyle(fontSize: 11, color: AppTheme.cobalt),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Type & Category
                                      _cell(
                                        value: '${_getImportTypeLabel(context, p.importType)} - $categoriesText ($incotermText)',
                                        rowSummary: rowSummary,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _getImportTypeLabel(context, p.importType),
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$categoriesText ($incotermText)',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Budget USD & Target End Date
                                      _cell(
                                        value: '$budgetText ${p.targetEndDate ?? ""}'.trim(),
                                        rowSummary: rowSummary,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              budgetText,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: p.totalBudgetUsd != null ? AppTheme.emerald : Colors.grey,
                                              ),
                                            ),
                                            if (p.totalCommittedUsd != null && (p.totalCommittedUsd! > 0 || (p.poCount ?? 0) > 0)) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                '${l10n.projectCommitmentsLabel}: \$${p.totalCommittedUsd!.toStringAsFixed(2)}',
                                                style: const TextStyle(fontSize: 10.5, color: AppTheme.cobalt, fontWeight: FontWeight.w600),
                                              ),
                                              if (p.remainingBudgetUsd != null)
                                                Text(
                                                  '${l10n.projectRemainingBudgetLabel}: \$${p.remainingBudgetUsd!.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: p.remainingBudgetUsd! >= 0 ? AppTheme.emerald : AppTheme.crimson,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              if (p.budgetUtilizationPercent != null && p.budgetUtilizationPercent! > 0)
                                                Text(
                                                  '${l10n.projectUtilizationLabel}: ${p.budgetUtilizationPercent!.toStringAsFixed(1)}%',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    color: AppTheme.textSecondaryOf(context),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                            ] else if ((p.poCount ?? 0) > 0 && p.totalCommittedUsd == null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                '${l10n.projectCommitmentsLabel}: —',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: AppTheme.severityForegroundOf(context, AppSeverity.warning),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                '${l10n.projectRemainingBudgetLabel}: —',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppTheme.textSecondaryOf(context),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (p.missingRateCurrencies.isNotEmpty) ...[
                                                const SizedBox(height: 1),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.warning_amber_rounded,
                                                      size: 12,
                                                      color: AppTheme.severityForegroundOf(context, AppSeverity.warning),
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Flexible(
                                                      child: Text(
                                                        l10n.projectMissingRateCurrencies(p.missingRateCurrencies.join(', ')),
                                                        style: TextStyle(
                                                          fontSize: 9.5,
                                                          color: AppTheme.severityForegroundOf(context, AppSeverity.warning),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                              if (p.committedByCurrency.isNotEmpty) ...[
                                                const SizedBox(height: 1),
                                                Text(
                                                  p.committedByCurrency.entries
                                                      .map((e) => '${e.value.toStringAsFixed(2)} ${e.key}')
                                                      .join(' + '),
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    color: AppTheme.textSecondaryOf(context),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                            if (p.targetEndDate != null && p.targetEndDate!.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.event_outlined, size: 12, color: Colors.grey),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    p.targetEndDate!,
                                                    style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      // Capabilities Badges (Multi-Shipment / Multi-Company)
                                      _cell(
                                        value: '${p.allowMultiShipment ? l10n.capMultiShipment : ""} ${p.allowMultiCompany ? l10n.capMultiCompany : ""}'.trim(),
                                        rowSummary: rowSummary,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (p.allowMultiShipment)
                                              _capBadge(l10n.capMultiShipment, AppTheme.cobalt),
                                            if (p.allowMultiCompany) ...[
                                              const SizedBox(height: 3),
                                              _capBadge(l10n.capMultiCompany, AppTheme.orange),
                                            ],
                                          ],
                                        ),
                                      ),

                                      // Status
                                      _cell(
                                        value: _getStatusLabel(context, p.status),
                                        rowSummary: rowSummary,
                                        child: _statusBadge(context, p.status),
                                      ),


                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _capBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _statusBadge(BuildContext context, String status) {
    Color bg;
    Color fg;

    switch (status) {
      case 'Open':
        bg = AppTheme.emerald.withOpacity(0.1);
        fg = AppTheme.emerald;
        break;
      case 'Closed':
        bg = Colors.grey.withOpacity(0.1);
        fg = Colors.grey.shade700;
        break;
      case 'On Hold':
        bg = AppTheme.orange.withOpacity(0.1);
        fg = AppTheme.orange;
        break;
      default:
        bg = AppTheme.cobalt.withOpacity(0.1);
        fg = AppTheme.cobalt;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        _getStatusLabel(context, status),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _cell({
    required Widget child,
    required String value,
    String? rowSummary,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: CopyableTableCell(
            value: value,
            rowSummary: rowSummary,
            child: child,
          ),
        ),
      );

  void _showProjectDialog(BuildContext context, {ProjectModel? project}) {
    final l10n = context.l10n;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: project?.projectName ?? '');
    final ownerCtrl = TextEditingController(text: project?.projectOwner ?? '');
    final budgetCtrl = TextEditingController(text: project?.totalBudgetUsd?.toString() ?? '');
    final targetEndDateCtrl = TextEditingController(text: project?.targetEndDate ?? '');
    final notesCtrl = TextEditingController(text: project?.notes ?? '');

    final companies = ref.read(importCompaniesProvider).valueOrNull ?? [];
    final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
    final incoterms = ref.read(incotermsProvider).valueOrNull ?? [];

    if (companies.isEmpty || suppliers.isEmpty || incoterms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.projectPrerequisitesMissing)),
      );
      nameCtrl.dispose();
      ownerCtrl.dispose();
      budgetCtrl.dispose();
      targetEndDateCtrl.dispose();
      notesCtrl.dispose();
      return;
    }

    final Set<int> selectedCompanyIds = project != null && project.companyIds.isNotEmpty
        ? project.companyIds.toSet()
        : (companies.isNotEmpty && companies.first.companyId != null ? {companies.first.companyId!} : <int>{});

    int selectedSupplierId = project?.supplierId ?? (suppliers.isNotEmpty ? suppliers.first.supplierId! : 0);
    int selectedIncotermId = project?.incotermId ?? (incoterms.isNotEmpty ? incoterms.first.incotermId : 0);
    String selectedImportType = project?.importType ?? 'Direct Commercial';
    String selectedPriority = project?.priority ?? 'Medium';
    String selectedStatus = project?.status ?? 'Open';
    bool allowMultiShipment = project?.allowMultiShipment ?? true;
    bool allowMultiCompany = project?.allowMultiCompany ?? true;
    bool isSubmitting = false;

    final List<String> availableCategories = [
      'FCL Container',
      'LCL Breakbulk',
      'Air Freight',
      'Bulk Cargo',
      'Multimodal',
      'Courier',
    ];

    String selectedCurrency = project?.budgetCurrency ?? 'USD';
    final List<String> availableCurrencies = ['USD', 'EUR', 'EGP', 'GBP', 'CNY', 'AED', 'SAR', 'JPY'];
    if (!availableCurrencies.contains(selectedCurrency)) {
      availableCurrencies.insert(0, selectedCurrency);
    }

    final Set<String> selectedCategories = project != null && project.shipmentCategory.isNotEmpty
        ? project.shipmentCategory.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet()
        : {'FCL Container'};

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(project == null ? l10n.createProjectDialogTitle : l10n.editProjectDialogTitle(project.projectCode)),
          content: SelectionArea(
            child: SizedBox(
              width: 650,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.projectNameLabel,
                          hintText: l10n.projectNameHint,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            tooltip: l10n.projectsCopyFieldTooltip,
                            onPressed: () => CopyHelper.copy(context, nameCtrl.text),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? l10n.requiredField : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ownerCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.projectOwnerLabelField,
                          hintText: l10n.projectOwnerHint,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            tooltip: l10n.projectsCopyFieldTooltip,
                            onPressed: () => CopyHelper.copy(context, ownerCtrl.text),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? l10n.requiredField : null,
                      ),
                    const SizedBox(height: 14),

                    // Multi-Select Importing Companies
                    Text(
                      l10n.importingCompaniesFieldLabel,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: companies.map((c) {
                          final isSelected = c.companyId != null && selectedCompanyIds.contains(c.companyId);
                          return FilterChip(
                            label: Text(c.importerName),
                            selected: isSelected,
                            selectedColor: AppTheme.cobalt.withOpacity(0.2),
                            checkmarkColor: AppTheme.cobalt,
                            labelStyle: TextStyle(
                              color: isSelected ? AppTheme.cobalt : AppTheme.charcoal,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (bool selected) {
                              if (c.companyId == null) return;
                              setDialogState(() {
                                if (selected) {
                                  selectedCompanyIds.add(c.companyId!);
                                } else {
                                  if (selectedCompanyIds.length > 1) {
                                    selectedCompanyIds.remove(c.companyId);
                                  }
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Supplier & Incoterm
                    Row(
                      children: [
                        Expanded(
                          child: SearchableDropdownField<int?>(
                            value: selectedSupplierId,
                            labelText: l10n.primarySupplierLabel,
                            items: suppliers
                                .map((s) => SearchableDropdownItem<int?>(
                                      value: s.supplierId,
                                      label: s.companyName,
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setDialogState(() => selectedSupplierId = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SearchableDropdownField<int?>(
                            value: selectedIncotermId,
                            labelText: l10n.defaultIncotermLabel,
                            items: incoterms
                                .map((i) => SearchableDropdownItem<int?>(
                                      value: i.incotermId,
                                      label: '${i.incotermCode} (${i.incotermName})',
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setDialogState(() => selectedIncotermId = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: SearchableDropdownField<String>(
                            value: selectedImportType,
                            labelText: l10n.importTypeLabel,
                            items: [
                              'Direct Commercial',
                              'Free Zone',
                              'Temporary Release',
                              'Drawback',
                              'Project Equipment'
                            ].map((t) => SearchableDropdownItem<String>(
                                  value: t,
                                  label: _getImportTypeLabel(context, t),
                                )).toList(),
                            onChanged: (v) => setDialogState(() => selectedImportType = v ?? 'Direct Commercial'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SearchableDropdownField<String>(
                            value: selectedPriority,
                            labelText: l10n.priorityLabel,
                            items: ['Low', 'Medium', 'High', 'Urgent']
                                .map((p) => SearchableDropdownItem<String>(
                                      value: p,
                                      label: _getPriorityLabel(context, p),
                                    ))
                                .toList(),
                            onChanged: (v) => setDialogState(() => selectedPriority = v ?? 'Medium'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    SearchableDropdownField<String>(
                      value: selectedStatus,
                      labelText: l10n.projectStatusLabel,
                      items: ['Open', 'Closed', 'On Hold']
                          .map((s) => SearchableDropdownItem<String>(
                                value: s,
                                label: _getStatusLabel(context, s),
                              ))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedStatus = v ?? 'Open'),
                    ),
                    const SizedBox(height: 14),

                    // Multi-Select Shipment Categories
                    Text(
                      l10n.allowedShipmentCategoriesLabel,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: availableCategories.map((cat) {
                          final isSelected = selectedCategories.contains(cat);
                          return FilterChip(
                            label: Text(_getCategoryLabel(context, cat)),
                            selected: isSelected,
                            selectedColor: AppTheme.cobalt.withOpacity(0.2),
                            checkmarkColor: AppTheme.cobalt,
                            labelStyle: TextStyle(
                              color: isSelected ? AppTheme.cobalt : AppTheme.charcoal,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (bool selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedCategories.add(cat);
                                } else {
                                  if (selectedCategories.length > 1) {
                                    selectedCategories.remove(cat);
                                  }
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: budgetCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: l10n.estTotalBudgetUsdLabel,
                              hintText: l10n.estTotalBudgetUsdHint,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                tooltip: l10n.projectsCopyFieldTooltip,
                                onPressed: () => CopyHelper.copy(context, budgetCtrl.text),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 120,
                          child: SearchableDropdownField<String>(
                            value: selectedCurrency,
                            labelText: l10n.budgetCurrencyLabel,
                            items: availableCurrencies
                                .map((c) => SearchableDropdownItem<String>(
                                      value: c,
                                      label: c,
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setDialogState(() => selectedCurrency = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: targetEndDateCtrl,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: l10n.targetEndDateLabel,
                              hintText: l10n.targetEndDateHint,
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (targetEndDateCtrl.text.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () => setDialogState(() => targetEndDateCtrl.clear()),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                                    onPressed: () async {
                                      final initial = DateTime.tryParse(targetEndDateCtrl.text) ??
                                          DateTime.now().add(const Duration(days: 90));
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: initial,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2040),
                                      );
                                      if (picked != null) {
                                        final formatted =
                                            "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                        setDialogState(() => targetEndDateCtrl.text = formatted);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Capabilities Checkboxes (Multi-Shipment & Multi-Company)
                    CheckboxListTile(
                      title: Text(l10n.allowMultiShipmentTitle),
                      subtitle: Text(l10n.allowMultiShipmentSubtitle),
                      value: allowMultiShipment,
                      activeColor: AppTheme.cobalt,
                      onChanged: (val) => setDialogState(() => allowMultiShipment = val ?? true),
                    ),
                    CheckboxListTile(
                      title: Text(l10n.allowMultiCompanyTitle),
                      subtitle: Text(l10n.allowMultiCompanySubtitle),
                      value: allowMultiCompany,
                      activeColor: AppTheme.cobalt,
                      onChanged: (val) => setDialogState(() => allowMultiCompany = val ?? true),
                    ),
                    const SizedBox(height: 8),

                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: l10n.projectNotesLabel,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: l10n.projectsCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, notesCtrl.text),
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
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, foregroundColor: Colors.white),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        if (selectedCompanyIds.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.selectAtLeastOneCompanyError)),
                          );
                          return;
                        }
                        if (selectedCategories.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.selectAtLeastOneCategoryError)),
                          );
                          return;
                        }

                        setDialogState(() => isSubmitting = true);
                        try {
                          final budget = double.tryParse(budgetCtrl.text.trim());
                          final categoryString = selectedCategories.join(', ');
                          final companyIdsList = selectedCompanyIds.toList();

                          if (project == null) {
                            final newModel = ProjectModel(
                              projectCode: '',
                              projectName: nameCtrl.text.trim(),
                              projectOwner: ownerCtrl.text.trim(),
                              companyId: companyIdsList.first,
                              companyIds: companyIdsList,
                              supplierId: selectedSupplierId,
                              incotermId: selectedIncotermId,
                              importType: selectedImportType,
                              priority: selectedPriority,
                              shipmentCategory: categoryString,
                              allowMultiShipment: allowMultiShipment,
                              allowMultiCompany: allowMultiCompany,
                              totalBudgetUsd: budget,
                              budgetCurrency: selectedCurrency,
                              targetEndDate: targetEndDateCtrl.text.trim().isEmpty ? null : targetEndDateCtrl.text.trim(),
                              notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                            );
                            final ok = await ref.read(projectsProvider.notifier).createProject(newModel);
                            if (ok && context.mounted) Navigator.pop(dialogCtx);
                          } else {
                            final updateData = {
                              'project_name': nameCtrl.text.trim(),
                              'project_owner': ownerCtrl.text.trim(),
                              'company_id': companyIdsList.first,
                              'company_ids': companyIdsList,
                              'supplier_id': selectedSupplierId,
                              'incoterm_id': selectedIncotermId,
                              'import_type': selectedImportType,
                              'priority': selectedPriority,
                              'shipment_category': categoryString,
                              'allow_multi_shipment': allowMultiShipment,
                              'allow_multi_company': allowMultiCompany,
                              'total_budget_usd': budget,
                              'budget_currency': selectedCurrency,
                              'target_end_date': targetEndDateCtrl.text.trim().isEmpty ? null : targetEndDateCtrl.text.trim(),
                              'status': selectedStatus,
                              'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                            };
                            final ok = await ref
                                .read(projectsProvider.notifier)
                                .updateProject(project.projectId!, updateData);
                            if (ok && context.mounted) Navigator.pop(dialogCtx);
                          }
                        } finally {
                          setDialogState(() => isSubmitting = false);
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(project == null ? l10n.createProjectSubmitBtn : l10n.saveChangesSubmitBtn),
            ),
          ],
        ),
      ),
    ).then((_) {
      nameCtrl.dispose();
      ownerCtrl.dispose();
      budgetCtrl.dispose();
      targetEndDateCtrl.dispose();
      notesCtrl.dispose();
    });
  }
}
