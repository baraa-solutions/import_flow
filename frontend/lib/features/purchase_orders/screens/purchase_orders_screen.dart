import '../widgets/po_details_dialog.dart';
import 'dart:math' as math;
import '../widgets/po_form_dialog.dart';
import '../widgets/po_balance_ledger_dialog.dart';
import '../utils/po_packing_matcher.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';

import '../../../core/widgets/widgets.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/services/container_load_plan_export_service.dart';

import '../../../core/theme/density_provider.dart';
import '../../import_files/models/import_file_model.dart' show ImportFileModel;
import '../../import_files/providers/import_files_provider.dart';
import '../../../core/performance/dispose_tracker.dart';
import '../../projects/providers/projects_provider.dart';
import '../../projects/models/project_model.dart';
import '../../../core/localization/locale_provider.dart';
import '../models/purchase_order_model.dart';
import '../providers/purchase_orders_provider.dart';
import '../services/po_export_helper.dart';
import '../widgets/po_table_cells.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/domain_enum_labels.dart';
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
                            AppTheme.snackBar(
                              context,
                              '${fields['po_number'] ?? '-'}',
                              severity: AppSeverity.success,
                              duration: const Duration(seconds: 4),
                            );
                            _showPODialog(context, null, initialExtractedFields: fields);
                          },
                        ),
                      if (!isNarrow) const SizedBox(width: 8),
                      if (!isNarrow) const BackToDashboardButton(),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppTheme.white),
                        onPressed: () => ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders(),
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
                        const AppLoadingState()
                      else if (state.error != null)
                        _buildErrorView(l, ApiErrorText.of(l, state.error, fallback: l.operationFailed))
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
                        ? const AppLoadingState()
                        : state.error != null
                            ? _buildErrorView(l, ApiErrorText.of(l, state.error, fallback: l.operationFailed))
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
          color: AppTheme.cobalt,
        ),
      ],
    );
  }

  void _copyPOTableTsv(List<PurchaseOrderModel> orders) {
    final l = context.l10n;
    final headers = buildPoExportHeaders(l);
    final rows = buildPoExportRows(orders, l);

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: context.l10n.poPOTableCopiedToClipboard,
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

    return ActionToolbar(
      primaryActions: [
        AppButton(
          label: l.newPurchaseOrder,
          icon: Icons.add_shopping_cart,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.small,
          onPressed: () => _showPODialog(context, null),
        ),
        AppButton(
          label: l.searchAndClonePoBtn,
          icon: Icons.control_point_duplicate_rounded,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
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
              Text(context.l10n.poCopyTableTSV, style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
      ],
      onMoreActionSelected: (val) {
        final headers = buildPoExportHeaders(l);
        final rows = buildPoExportRows(state.purchaseOrders, l);
        final selectedProject = state.projectFilter == null
            ? null
            : projectsList.where((p) => p.projectId == state.projectFilter).firstOrNull;
        final projectCodeOrAll = selectedProject?.projectCode ?? l.allProjects;

        switch (val) {
          case 'export_excel':
            TableExportService.exportTableToExcel(
              context: context,
              headers: headers,
              rows: rows,
              stageName: l.purchaseOrdersTitle,
              importFileNameOrCode: projectCodeOrAll,
            );
            break;
          case 'export_pdf':
            TableExportService.exportTableToPdf(
              context: context,
              headers: headers,
              rows: rows,
              stageName: l.purchaseOrdersTitle,
              importFileNameOrCode: projectCodeOrAll,
            );
            break;
          case 'copy_tsv':
            _copyPOTableTsv(state.purchaseOrders);
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
              fillColor: isDark ? AppTheme.darkInputBackground : AppTheme.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
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
              fillColor: isDark ? AppTheme.darkInputBackground : AppTheme.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
              ),
            ),
            items: [
              SearchableDropdownItem<String?>(value: null, label: l.allStatuses),
              // The ?status= filter sends the PO_STATUS code.
              for (final code in DomainEnums.codesOf(DomainEnumType.poStatus))
                SearchableDropdownItem<String?>(value: code, label: DomainEnums.label(l, DomainEnumType.poStatus, code)),
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
    return AppErrorState(
      message: errorMessage,
      onRetry: () => ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders(),
    );
  }

  Widget _buildEmptyView(AppLocalizations l) {
    return AppEmptyState(
      message: l.noDataFound,
      icon: Icons.inventory_2_outlined,
    );
  }

  /// PO_STATUS code (or a legacy label) -> label in the user's language.
  String _getStatusLabel(String status, AppLocalizations l) =>
      DomainEnums.label(l, DomainEnumType.poStatus, status, fallback: '-');

  Widget _buildPOTable(BuildContext context, List<PurchaseOrderModel> orders) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    final Map<int, ImportFileModel> filesById = {};
    final Map<String, ImportFileModel> filesByCode = {};
    for (final f in importFiles) {
      filesById[f.importFileId] = f;
      filesByCode[f.importFileCode] = f;
    }

    return EnterpriseDataTable<PurchaseOrderModel>(
      storageKey: 'purchase_orders_enterprise_table',
      isScrollable: true,
      minWidth: 1650,
      data: orders,
      columns: _buildPOColumns(context, isDark, l, filesById, filesByCode),
      onRowTap: (po) => _showPODetailsDialog(context, po),
      enableExport: true,
      exportFileName: 'Purchase_Orders_Registry_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }

  List<EnterpriseColumn<PurchaseOrderModel>> _buildPOColumns(
    BuildContext context,
    bool isDark,
    AppLocalizations l,
    Map<int, ImportFileModel> filesById,
    Map<String, ImportFileModel> filesByCode,
  ) {
    return [
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'actions',
        title: l.actionsCol,
        width: 220,
        isLocked: true,
        isSortable: false,
        isSearchable: false,
        cellBuilder: (ctx, po, _) {
          return Row(
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
                  AppTheme.snackBar(
                    context,
                    l.printPoAndPackingList(po.displayName, po.poNumber),
                    duration: const Duration(seconds: 2),
                  );
                },
                onDelete: () async {
                  final isActive = po.isActive;
                  final confirm = await AppConfirmDialog.showToggleActive(
                    context,
                    isCurrentlyActive: isActive,
                    entityName: po.displayName,
                    message: isActive
                        ? l.confirmDeactivatePo(po.displayName)
                        : l.confirmRestorePo(po.displayName),
                    confirmLabel: isActive ? l.deactivateBtn : l.restore,
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
          );
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'po_reference',
        title: l.poReferenceCol,
        width: 170,
        exportValue: (po) => po.displayName,
        searchValue: (po) => '${po.displayName} ${po.poNumber}',
        cellBuilder: (ctx, po, _) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return CopyableTableCell(
            value: po.displayName,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _showPODetailsDialog(context, po),
                  child: LtrText(
                    po.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.cobalt,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                if (po.poReference != null && po.poReference!.isNotEmpty && po.poReference != po.poNumber)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: LtrText(
                      po.poNumber,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'invoice_date',
        title: l.invoiceDateCol,
        width: 120,
        sortComparator: (a, b) {
          if (a.orderDate == null && b.orderDate == null) return 0;
          if (a.orderDate == null) return -1;
          if (b.orderDate == null) return 1;
          return a.orderDate!.compareTo(b.orderDate!);
        },
        exportValue: (po) => po.orderDate != null
            ? '${po.orderDate!.year}-${po.orderDate!.month.toString().padLeft(2, '0')}-${po.orderDate!.day.toString().padLeft(2, '0')}'
            : '-',
        cellBuilder: (ctx, po, _) {
          final invoiceDateStr = po.orderDate != null
              ? '${po.orderDate!.year}-${po.orderDate!.month.toString().padLeft(2, '0')}-${po.orderDate!.day.toString().padLeft(2, '0')}'
              : '-';
          return CopyableTableCell(value: invoiceDateStr, child: LtrText(invoiceDateStr));
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'import_file',
        title: l.importFileCol,
        width: 180,
        exportValue: (po) {
          final matchedFile = (po.importFileId != null ? filesById[po.importFileId] : null) ??
              (po.importFileCode != null ? filesByCode[po.importFileCode] : null);
          return matchedFile?.displayName ?? po.importFileCode ?? (po.importFileId != null ? 'IMP-${po.importFileId}' : '-');
        },
        cellBuilder: (ctx, po, _) {
          final matchedFile = (po.importFileId != null ? filesById[po.importFileId] : null) ??
              (po.importFileCode != null ? filesByCode[po.importFileCode] : null);
          final fileName = matchedFile?.displayName ?? po.importFileCode ?? (po.importFileId != null ? 'IMP-${po.importFileId}' : '-');
          final fileCode = (matchedFile != null && matchedFile.displayName != matchedFile.importFileCode)
              ? matchedFile.importFileCode
              : (po.importFileCode ?? (po.importFileId != null ? 'IMP-${po.importFileId}' : ''));
          return CopyableTableCell(
            value: fileName,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(fileName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (fileCode.isNotEmpty)
                  LtrText(fileCode, style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          );
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'pi_number',
        title: l.piNumberCol,
        width: 140,
        exportValue: (po) => po.proformaInvoiceNumber ?? '-',
        cellBuilder: (ctx, po, _) => CopyableTableCell(
          value: po.proformaInvoiceNumber ?? '-',
          child: LtrText(po.proformaInvoiceNumber ?? '-'),
        ),
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'projects',
        title: l.projectsAndCostCenters,
        width: 170,
        exportValue: (po) => po.projectName ?? 'PRJ-#${po.projectId}',
        cellBuilder: (ctx, po, _) {
          final pName = po.projectName ?? 'PRJ-#${po.projectId}';
          return CopyableTableCell(
            value: pName,
            child: Text(pName, overflow: TextOverflow.ellipsis),
          );
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'company',
        title: l.importingCompany,
        width: 170,
        exportValue: (po) => po.companyName ?? 'COMP-#${po.companyId}',
        cellBuilder: (ctx, po, _) {
          final cName = po.companyName ?? 'COMP-#${po.companyId}';
          return CopyableTableCell(
            value: cName,
            child: Text(cName, overflow: TextOverflow.ellipsis),
          );
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'supplier',
        title: l.foreignSupplier,
        width: 180,
        exportValue: (po) => po.supplierName ?? 'SUP-#${po.supplierId}',
        cellBuilder: (ctx, po, _) {
          final sName = po.supplierName ?? 'SUP-#${po.supplierId}';
          return CopyableTableCell(
            value: sName,
            child: Text(sName, overflow: TextOverflow.ellipsis),
          );
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'total_fob',
        title: l.totalFobMetric,
        width: 140,
        isNumeric: true,
        sortComparator: (a, b) => a.totalAmountFob.compareTo(b.totalAmountFob),
        exportValue: (po) => '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}',
        cellBuilder: (ctx, po, _) {
          final amountStr = '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}';
          return CopyableTableCell(
            value: amountStr,
            child: LtrText(
              amountStr,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
            ),
          );
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'cbm_weight',
        title: l.cbmAndGrossWeightCol,
        width: 180,
        isNumeric: true,
        sortComparator: (a, b) => a.totalCbm.compareTo(b.totalCbm),
        exportValue: (po) => '${po.totalCbm.toStringAsFixed(2)} m³ / ${_formatWeight(po.totalGrossWeightKg)} kg',
        cellBuilder: (ctx, po, _) {
          final cbmWeightStr = '${po.totalCbm.toStringAsFixed(2)} m³ / ${_formatWeight(po.totalGrossWeightKg)} kg';
          return CopyableTableCell(
            value: cbmWeightStr,
            child: LtrText(cbmWeightStr),
          );
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'status',
        title: l.lifecycleBoard,
        width: 130,
        exportValue: (po) => _getStatusLabel(po.status, l),
        cellBuilder: (ctx, po, _) {
          final localizedStatus = _getStatusLabel(po.status, l);
          final severity = po.status == 'Approved'
              ? AppSeverity.success
              : (po.status == 'Draft' ? AppSeverity.warning : AppSeverity.info);
          return AppStatusBadge(
            label: localizedStatus,
            severity: severity,
          );
        },
      ),
    ];
  }

  void _showPODetailsDialog(BuildContext context, PurchaseOrderModel po) {
    PoDetailsDialog.show(
      context,
      po,
      onEdit: () => _showPODialog(context, po),
      onOpen3dPlanner: () => _showVisualLoadPlannerDialog(context, po),
    );
  }

  void _showVisualLoadPlannerDialog(BuildContext context, PurchaseOrderModel po) {
    final cargoItems = PoDetailsDialog.extractCargoItems(po);

    if (cargoItems.isEmpty) {
      final l = context.l10n;
      AppTheme.snackBar(
        context,
        l.noCargoOrPalletToSimulate,
        severity: AppSeverity.warning,
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
                            color: AppTheme.cobalt.withValues(alpha: 0.12),
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
                                style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.image_outlined, color: AppTheme.cobalt),
                          tooltip: context.l10n.poDownloadSimulationImagePNG,
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
                          tooltip: context.l10n.poDownloadLoadingPlanPDF,
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
                        color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoalSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
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
                                  color: (activeOrientationMode == CargoOrientationPreference.smartHybrid && activeStackingMode == true) ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
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
                                  color: (activeOrientationMode == CargoOrientationPreference.flatOnly && activeStackingMode == true) ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
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
                                selectedColor: AppTheme.wcagOrange,
                                labelStyle: TextStyle(
                                  color: activeStackingMode == false ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
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
                                  color: activeStackingMode == null ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
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
                                label: Text(context.l10n.poBothViews),
                                selected: viewProjection == 'both',
                                selectedColor: AppTheme.cobalt,
                                labelStyle: TextStyle(
                                  color: viewProjection == 'both' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
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
                                  color: viewProjection == 'side' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
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
                                  color: viewProjection == 'top' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
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
                        color: isDark ? AppTheme.darkSurface : AppTheme.charcoal.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.charcoal.withValues(alpha: 0.12)),
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
                                color: AppTheme.crimsonLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? AppTheme.crimson : AppTheme.crimsonBorder),
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
                            color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
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
                                          color: AppTheme.cobalt.withValues(alpha: 0.1),
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
                                        color: AppTheme.charcoal,
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
                                        color: AppTheme.charcoal,
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
                                        color: AppTheme.charcoal,
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
                                                ? (context.l10n.poDetailedPlacementCoordinatesPkgs(res.placedItems.length))
                                                : (context.l10n.poGroupedItemsItemsTotalPkgs(res.groupedItems.length, res.placedItems.length)),
                                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                          ),
                                          AppButton(
                                            label: showDetailedCoordinates ? (context.l10n.poGroupByItems) : (context.l10n.poDetailedCoordinates),
                                            icon: showDetailedCoordinates ? Icons.table_chart_outlined : Icons.format_list_numbered,
                                            variant: AppButtonVariant.secondary,
                                            size: AppButtonSize.small,
                                            onPressed: () => setDialogState(() => showDetailedCoordinates = !showDetailedCoordinates),
                                          ),
                                        ],
                                      ),
                                      children: [
                                        if (!showDetailedCoordinates)
                                          Table(
                                            border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
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
                                                decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                                                children: [
                                                  const Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                  PoHeaderCell(context.l10n.poItemCode, fontSize: 11),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.poPkgType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.poDimsCm, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.qtyCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.poGrossWt2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.poCBM2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.poStack, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
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
                                                          color: AppTheme.cobalt.withValues(alpha: 0.12),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text('${g.count}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt), textAlign: TextAlign.center),
                                                      ),
                                                    ),
                                                    Padding(padding: const EdgeInsets.all(6), child: Text('${_formatWeight(g.totalWeight)} kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                                    Padding(padding: const EdgeInsets.all(6), child: Text('${g.volumeM3.toStringAsFixed(3)} m³', style: const TextStyle(fontSize: 11, color: AppTheme.orange, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                                    Padding(padding: const EdgeInsets.all(6), child: Text(g.isStackable ? (context.l10n.poYes) : (context.l10n.poFloor), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: g.isStackable ? AppTheme.emerald : AppTheme.crimson), textAlign: TextAlign.center)),
                                                  ],
                                                );
                                              }),
                                            ],
                                          )
                                        else
                                          Table(
                                            border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
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
                                                decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                                                children: [
                                                  const Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                  PoHeaderCell(l.thPackageCode, fontSize: 11),
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
                                                    Padding(padding: const EdgeInsets.all(6), child: Text(item.item.isStackable ? (context.l10n.poYes) : (context.l10n.poFloor), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: item.item.isStackable ? AppTheme.emerald : AppTheme.crimson), textAlign: TextAlign.center)),
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
    CloneEntityReviewDialog.show(
      context,
      entityType: context.l10n.poPurchaseOrder,
      sourceCode: po.poNumber,
      suggestedNewCode: '${po.poNumber}${TableRowCloneHelper.copyCodeSuffix}',
      sourceTitle: po.displayName,
      copiedFieldsSummary: {
        context.l10n.auditEntityImportCompany: po.companyName ?? '-',
        context.l10n.draftBlPartySupplier: po.supplierName ?? '-',
        context.l10n.poProject: po.projectName ?? '-',
        context.l10n.poCurrencyIncoterm: '${po.currencyCode ?? "USD"} (${po.incotermCode ?? "-"})',
      },
      mandatorilyResetFields: [
        l.cloneFieldStatusDraftBadge,
        l.cloneFieldShipmentUnlinked,
        l.cloneFieldAllocationsReset,
        context.l10n.poResetDeliveryAndOrderDates,
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
            AppTheme.snackBar(
              context,
              l.clonePoSuccess(newCode),
              severity: AppSeverity.success,
              duration: const Duration(seconds: 3),
            );
            ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
          }
        } catch (e) {
          if (mounted) {
            AppTheme.snackBar(
              context,
              l.clonePoError(ApiErrorText.of(l, e)),
              severity: AppSeverity.danger,
              duration: const Duration(seconds: 4),
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
        final invoiceDateStr = po.orderDate != null
            ? '${po.orderDate!.year}-${po.orderDate!.month.toString().padLeft(2, '0')}-${po.orderDate!.day.toString().padLeft(2, '0')}'
            : '-';
        final amountStr = '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}';
        final cbmWeightStr = '${po.totalCbm.toStringAsFixed(2)} m³ / ${_formatWeight(po.totalGrossWeightKg)} kg';
        final localizedStatus = _getStatusLabel(po.status, l);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
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
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  AppStatusBadge.fromStatus(
                    status: po.status,
                    label: localizedStatus,
                    size: AppStatusBadgeSize.small,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Details grid
              Text(
                '${l.importingCompany}: ${po.companyName ?? "COMP-#${po.companyId}"}',
                style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
              ),
              const SizedBox(height: 2),
              Text(
                '${l.foreignSupplier}: ${po.supplierName ?? "SUP-#${po.supplierId}"}${po.countryOfOrigin != null ? " (${po.countryOfOrigin})" : ""}',
                style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${l.totalFobMetric}: $amountStr',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.wcagEmerald,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cbmWeightStr,
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
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
                      style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
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
                    AppTheme.snackBar(
                      context,
                      l.printPoAndPackingList(po.displayName, po.poNumber),
                      duration: const Duration(seconds: 2),
                    );
                  },
                  onDelete: () async {
                    final isActive = po.isActive;
                    final confirm = await AppConfirmDialog.showToggleActive(
                      context,
                      isCurrentlyActive: isActive,
                      entityName: po.displayName,
                      message: isActive
                          ? l.confirmDeactivatePo(po.displayName)
                          : l.confirmRestorePo(po.displayName),
                      confirmLabel: isActive ? l.deactivateBtn : l.restore,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.white,
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
                    color: AppTheme.wcagCobalt.withValues(alpha: 0.12),
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
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
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
                          Icon(Icons.search_off_rounded, size: 48, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                          const SizedBox(height: 8),
                          Text(
                            l.noMatchingPosFound,
                            style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
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
                            color: isDark ? AppTheme.darkSurface : AppTheme.charcoalSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
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
                                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
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
                                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              AppButton(
                                label: context.l10n.cloneBtn,
                                icon: Icons.control_point_duplicate_rounded,
                                variant: AppButtonVariant.primary,
                                size: AppButtonSize.small,
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
