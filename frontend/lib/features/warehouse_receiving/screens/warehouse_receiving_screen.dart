import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/master_data_toolbar.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/warehouse_receiving_model.dart';
import '../providers/goods_in_transit_provider.dart';
import '../providers/warehouse_receiving_provider.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../widgets/grn_discrepancy_dialog.dart';
import '../widgets/grn_record_card.dart';
import '../widgets/ops_ui_kit.dart';
import '../widgets/search_and_clone_warehouse_receiving_dialog.dart';
import '../widgets/warehouse_inspection_dialog.dart';
import '../widgets/warehouse_receiving_form_dialog.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/localization/stored_text.dart';

class WarehouseReceivingScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const WarehouseReceivingScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<WarehouseReceivingScreen> createState() => _WarehouseReceivingScreenState();
}

class _WarehouseReceivingScreenState extends ConsumerState<WarehouseReceivingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'All';

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
      if (!ref.read(purchaseOrdersProvider).isLoading) {
        ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditDialog([WarehouseReceivingModel? recordToEdit, bool isCloneDraft = false]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WarehouseReceivingFormDialog(
        recordToEdit: recordToEdit,
        isCloneDraft: isCloneDraft,
      ),
    );
  }

  void _openSearchAndCloneDialog(List<WarehouseReceivingModel> records) {
    showDialog(
      context: context,
      builder: (ctx) => SearchAndCloneWarehouseReceivingDialog(
        records: records,
        onSelectRecord: (selectedRec) {
          Navigator.of(ctx).pop();
          _onCloneGrnRecord(selectedRec);
        },
      ),
    );
  }

  void _onCloneGrnRecord(WarehouseReceivingModel rec) {
    final l = context.l10n;
    final isAr = l.isArabic;

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isAr ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: CloneEntityReviewDialog(
            entityType: l.wrCloneEntityType,
            sourceCode: rec.grnCode,
            // Header data only: the server issues the GRN code, the user picks the file.
            suggestedNewCode: '',
            sourceTitle: '${rec.warehouseName} (${rec.grnCode})',
            copiedFieldsSummary: {
              l.warehouseReceivingColWarehouse: rec.warehouseName,
              l.warehouseReceivingColTruckDriver: '${rec.driverName ?? "-"} (${rec.truckPlateNumber ?? "-"})',
              l.warehouseReceivingSealNumberLabel: rec.sealNumber ?? '-',
              l.warehouseReceivingSealIntactSwitch: rec.sealIntact ? l.warehouseReceivingSealIntact : l.warehouseReceivingSealBroken,
            },
            mandatorilyResetFields: [
              l.wrCloneResetReceivingId,
              l.wrCloneResetGrnCode,
              l.wrCloneResetArrival,
              l.wrCloneResetStatus,
              l.wrCloneResetQuarantine,
              l.wrCloneResetDiscrepancy,
              l.wrCloneResetInsuranceClaim,
            ],
            allowCopyLineItems: false,
            allowCopyAttachments: false,
            onConfirm: ({
              required String newCode,
              required String newTitle,
              required bool copyLineItems,
              required bool copyAttachments,
              String? notes,
            }) async {
              final clonedDraft = WarehouseReceivingModel(
                receivingId: 0,
                grnCode: '',
                importFileId: 0,
                warehouseName: rec.warehouseName,
                arrivalDatetime: DateTime.now().toIso8601String(),
                truckPlateNumber: rec.truckPlateNumber,
                driverName: rec.driverName,
                driverPhone: rec.driverPhone,
                sealNumber: rec.sealNumber,
                sealIntact: rec.sealIntact,
                grnItems: const [],
                totalInvoicedQty: 0,
                totalAcceptedQty: 0,
                totalShortageQty: 0,
                totalDamagedQty: 0,
                discrepancyType: 'None',
                discrepancyNotes: null,
                quarantineZoneAssigned: false,
                insuranceClaimFiled: false,
                insuranceClaimRef: null,
                status: '',
                inspectorName: rec.inspectorName,
                notes: notes,
                createdAt: DateTime.now().toIso8601String(),
                updatedAt: DateTime.now().toIso8601String(),
              );

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _showAddEditDialog(clonedDraft, true);
                }
              });
            },
          ),
        ),
      ),
    );
  }

  void _showDiscrepancyDialog(WarehouseReceivingModel record) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GrnDiscrepancyReportDialog(record: record),
    );
  }

  void _copyGrnRowTsv(WarehouseReceivingModel r, AppLocalizations l) {
    final quarantineText = r.quarantineZoneAssigned ? l.warehouseReceivingQuarantineStatusBlocked : '-';
    final driverTruck = '${r.driverName ?? "-"} (${r.truckPlateNumber ?? "-"})';
    final arrival = r.arrivalDatetime.replaceFirst('T', ' ').split('.').first;

    final rowData = [
      r.grnCode,
      r.warehouseName,
      r.status,
      quarantineText,
      driverTruck,
      arrival,
      r.inspectorName,
      r.discrepancyType,
      r.totalInvoicedQty.toString(),
      r.totalAcceptedQty.toString(),
      r.totalShortageQty.toString(),
      r.totalDamagedQty.toString(),
    ];

    final headers = [
      l.warehouseReceivingColGrnCode,
      l.warehouseReceivingColWarehouse,
      l.warehouseReceivingColStatus,
      l.warehouseReceivingColQuarantine,
      l.warehouseReceivingColTruckDriver,
      l.warehouseReceivingColArrivalDate,
      l.warehouseReceivingColInspector,
      l.warehouseReceivingColDiscrepancy,
      l.warehouseReceivingColInvoicedQty,
      l.warehouseReceivingColAcceptedQty,
      l.warehouseReceivingColShortageQty,
      l.warehouseReceivingColDamagedQty,
    ];

    TableCopyHelper.copyRow(
      context,
      rowData,
      headers: headers,
      includeHeaders: true,
      customMessage: l.copyWarehouseReceivingRowSuccess,
    );
  }

  void _copyGrnTableTsv(List<WarehouseReceivingModel> records, AppLocalizations l) {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.warehouseReceivingEmptyRecords), backgroundColor: AppTheme.orange),
      );
      return;
    }

    final headers = [
      l.warehouseReceivingColGrnCode,
      l.warehouseReceivingColWarehouse,
      l.warehouseReceivingColStatus,
      l.warehouseReceivingColQuarantine,
      l.warehouseReceivingColTruckDriver,
      l.warehouseReceivingColArrivalDate,
      l.warehouseReceivingColInspector,
      l.warehouseReceivingColDiscrepancy,
      l.warehouseReceivingColInvoicedQty,
      l.warehouseReceivingColAcceptedQty,
      l.warehouseReceivingColShortageQty,
      l.warehouseReceivingColDamagedQty,
    ];

    final rows = records.map((r) {
      final quarantineText = r.quarantineZoneAssigned ? l.warehouseReceivingQuarantineStatusBlocked : '-';
      final driverTruck = '${r.driverName ?? "-"} (${r.truckPlateNumber ?? "-"})';
      final arrival = r.arrivalDatetime.replaceFirst('T', ' ').split('.').first;
      return [
        r.grnCode,
        r.warehouseName,
        r.status,
        quarantineText,
        driverTruck,
        arrival,
        r.inspectorName,
        r.discrepancyType,
        r.totalInvoicedQty.toString(),
        r.totalAcceptedQty.toString(),
        r.totalShortageQty.toString(),
        r.totalDamagedQty.toString(),
      ];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: l.copyWarehouseReceivingTableSuccess,
    );
  }

  Future<void> _exportGrnExcel(List<WarehouseReceivingModel> records, AppLocalizations l) async {
    if (records.isEmpty) return;
    final headers = [
      l.warehouseReceivingColGrnCode,
      l.warehouseReceivingColWarehouse,
      l.warehouseReceivingColStatus,
      l.warehouseReceivingColQuarantine,
      l.warehouseReceivingColTruckDriver,
      l.warehouseReceivingColArrivalDate,
      l.warehouseReceivingColInspector,
      l.warehouseReceivingColDiscrepancy,
      l.warehouseReceivingColInvoicedQty,
      l.warehouseReceivingColAcceptedQty,
      l.warehouseReceivingColShortageQty,
      l.warehouseReceivingColDamagedQty,
    ];

    final rows = records.map((r) {
      final quarantineText = r.quarantineZoneAssigned ? l.warehouseReceivingQuarantineStatusBlocked : '-';
      final driverTruck = '${r.driverName ?? "-"} (${r.truckPlateNumber ?? "-"})';
      final arrival = r.arrivalDatetime.replaceFirst('T', ' ').split('.').first;
      return [
        r.grnCode,
        r.warehouseName,
        r.status,
        quarantineText,
        driverTruck,
        arrival,
        r.inspectorName,
        r.discrepancyType,
        r.totalInvoicedQty.toString(),
        r.totalAcceptedQty.toString(),
        r.totalShortageQty.toString(),
        r.totalDamagedQty.toString(),
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      stageName: 'Warehouse Receiving',
      importFileNameOrCode: 'GRN_Registry',
      headers: headers,
      rows: rows,
    );
  }

  Future<void> _exportGrnPdf(List<WarehouseReceivingModel> records, AppLocalizations l) async {
    if (records.isEmpty) return;
    final headers = [
      l.warehouseReceivingColGrnCode,
      l.warehouseReceivingColWarehouse,
      l.warehouseReceivingColStatus,
      l.warehouseReceivingColTruckDriver,
      l.warehouseReceivingColArrivalDate,
      l.warehouseReceivingColInspector,
      l.warehouseReceivingColAcceptedQty,
      l.warehouseReceivingColShortageQty,
      l.warehouseReceivingColDamagedQty,
    ];

    final rows = records.map((r) {
      final driverTruck = '${r.driverName ?? "-"} (${r.truckPlateNumber ?? "-"})';
      final arrival = r.arrivalDatetime.replaceFirst('T', ' ').split('.').first;
      return [
        r.grnCode,
        r.warehouseName,
        r.status,
        driverTruck,
        arrival,
        r.inspectorName,
        r.totalAcceptedQty.toString(),
        r.totalShortageQty.toString(),
        r.totalDamagedQty.toString(),
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      stageName: 'Warehouse Receiving',
      importFileNameOrCode: 'GRN_Registry',
      headers: headers,
      rows: rows,
      headerContext: TableExportHeaderContext(
        title: l.wrPdfRegistryTitle,
        subtitle: l.wrPdfRegistrySubtitle,
      ),
    );
  }

  Future<void> _confirmFinalReceipt(WarehouseReceivingModel record) async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.emerald),
            const SizedBox(width: 8),
            Text(l10n.warehouseReceivingConfirmReceiptTitle),
          ],
        ),
        content: Text(
          l10n.warehouseReceivingConfirmReceiptMessage(record.grnCode),
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          AppButton(label: l10n.cancel, variant: AppButtonVariant.secondary, onPressed: () => Navigator.pop(c, false)),
          AppButton(
            label: l10n.warehouseReceivingConfirmReceiptBtn,
            variant: AppButtonVariant.success,
            icon: Icons.verified,
            onPressed: () => Navigator.pop(c, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final payload = {
          'status': 'Goods Received',
          'discrepancy_notes': storedText.warehouseReceivingStatusGoodsReceived,
        };
        await ref.read(warehouseReceivingProvider.notifier).updateRecord(record.receivingId, payload);
        ref.read(goodsInTransitProvider.notifier).confirmWarehouseReceipt(record.importFileId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.warehouseReceivingConfirmReceiptSuccess(record.grnCode)),
              backgroundColor: AppTheme.emerald,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ApiErrorText.of(l10n, e)), backgroundColor: AppTheme.crimson),
          );
        }
      }
    }
  }

  void _printGrn(WarehouseReceivingModel r) {
    final l = context.l10n;
    final buffer = StringBuffer();
    buffer.writeln('${l.warehouseReceivingColGrnCode}: ${r.grnCode}');
    buffer.writeln('${l.warehouseReceivingColWarehouse}: ${r.warehouseName}');
    buffer.writeln('${l.warehouseReceivingColStatus}: ${r.status}');
    buffer.writeln('${l.warehouseReceivingTruckAndDriver}: ${r.driverName ?? "-"} (${r.truckPlateNumber ?? "-"})');
    buffer.writeln('${l.warehouseReceivingArrivalDatetime}: ${r.arrivalDatetime.replaceFirst("T", " ").split(".")[0]}');
    buffer.writeln('${l.warehouseReceivingInspector}: ${r.inspectorName}');
    buffer.writeln('${l.warehouseReceivingDiscrepancyStatus}: ${r.discrepancyType}');
    buffer.writeln('${l.warehouseReceivingMetricInvoiced}: ${r.totalInvoicedQty}');
    buffer.writeln('${l.warehouseReceivingMetricAccepted}: ${r.totalAcceptedQty}');
    buffer.writeln('${l.warehouseReceivingMetricShortage}: ${r.totalShortageQty}');
    buffer.writeln('${l.warehouseReceivingMetricDamaged}: ${r.totalDamagedQty}');
    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l.warehouseReceivingPrintReceiptSuccess(r.grnCode),
    );
  }

  Future<void> _deleteGrn(WarehouseReceivingModel r) async {
    final l = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.warehouseReceivingDeleteTitle),
        content: Text(l.warehouseReceivingDeleteConfirmMessage),
        actionsPadding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 16),
        actions: [
          AppButton(label: l.cancel, variant: AppButtonVariant.secondary, onPressed: () => Navigator.pop(c, false)),
          AppButton(
            label: l.delete,
            variant: AppButtonVariant.danger,
            icon: Icons.delete_outline,
            onPressed: () => Navigator.pop(c, true),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(warehouseReceivingProvider.notifier).softDeleteRecord(r.receivingId);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(ApiErrorText.of(l, e)), backgroundColor: AppTheme.crimson),
        );
      }
    }
  }

  void _showQuarantineState(WarehouseReceivingModel r) {
    final l = context.l10n;
    final blocked = r.quarantineZoneAssigned;
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        blocked ? l.warehouseReceivingQuarantineAlertBlocked : l.warehouseReceivingQuarantineAlertCleared,
        severity: blocked ? AppSeverity.danger : AppSeverity.success,
      ),
    );
  }

  Widget _buildMetrics(List<WarehouseReceivingModel> records, AppLocalizations l) {
    final pending = records.where((r) => GrnStatusView.isDraftStatus(r.status)).length;
    final received = records.where((r) => r.status == 'Goods Received' || r.status == 'Closed').length;
    final discrepancy = records.where((r) => r.status == 'Discrepancy Reported' || r.discrepancyType != 'None').length;
    return MetricCardStrip(
      metrics: [
        MetricCardData(
          title: l.wrGrnMetricTotal,
          shortTitle: l.wrGrnMetricTotal,
          value: '${records.length}',
          icon: Icons.inventory_outlined,
          color: AppTheme.cobalt,
        ),
        MetricCardData(
          title: l.wrGrnMetricPending,
          shortTitle: l.wrGrnMetricPending,
          value: '$pending',
          icon: Icons.hourglass_top_rounded,
          color: AppTheme.orange,
        ),
        MetricCardData(
          title: l.wrGrnMetricReceived,
          shortTitle: l.wrGrnMetricReceived,
          value: '$received',
          icon: Icons.check_circle_outline,
          color: AppTheme.emerald,
        ),
        MetricCardData(
          title: l.wrGrnMetricDiscrepancy,
          shortTitle: l.wrGrnMetricDiscrepancy,
          value: '$discrepancy',
          icon: Icons.report_problem_outlined,
          color: AppTheme.crimson,
        ),
      ],
    );
  }

  Widget _buildToolbar(List<WarehouseReceivingModel> records, AppLocalizations l) {
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
            onPressed: () => _showAddEditDialog(),
          ),
          AppButton(
            key: const Key('searchAndCloneGrnBtn'),
            label: l.searchAndCloneWarehouseReceivingBtn,
            icon: Icons.difference_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => _openSearchAndCloneDialog(records),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l.warehouseReceivingSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) {
                    return value.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(warehouseReceivingProvider.notifier).fetchRecords(
                                    search: '',
                                    status: _selectedStatusFilter,
                                  );
                            },
                          )
                        : const SizedBox.shrink();
                  },
                ),
                isDense: true,
                contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 10),
                border: const OutlineInputBorder(),
              ),
              onChanged: (val) {
                ref.read(warehouseReceivingProvider.notifier).fetchRecords(search: val, status: _selectedStatusFilter);
              },
            ),
          ),
          SizedBox(
            width: 220,
            child: SearchableDropdownField<String>(
              value: _selectedStatusFilter,
              items: [
                SearchableDropdownItem(value: 'All', label: l.warehouseReceivingStatusAll),
                SearchableDropdownItem(value: 'Draft / Pending Warehouse Count', label: l.warehouseReceivingStatusDraft),
                SearchableDropdownItem(value: 'Goods Received', label: l.warehouseReceivingStatusGoodsReceived),
                SearchableDropdownItem(value: 'Discrepancy Reported', label: l.warehouseReceivingStatusDiscrepancy),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedStatusFilter = val);
                  ref.read(warehouseReceivingProvider.notifier).fetchRecords(search: _searchController.text, status: val);
                }
              },
            ),
          ),
          AppButton(
            key: const Key('copyGrnTableTsvBtn'),
            label: l.warehouseReceivingExportTsvBtn,
            icon: Icons.table_chart_outlined,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.small,
            onPressed: () => _copyGrnTableTsv(records, l),
          ),
          IconButton(
            key: const Key('exportGrnExcelBtn'),
            icon: const Icon(Icons.description_outlined, color: AppTheme.emerald, size: 20),
            tooltip: l.exportWarehouseReceivingExcelTooltip,
            onPressed: () => _exportGrnExcel(records, l),
          ),
          IconButton(
            key: const Key('exportGrnPdfBtn'),
            icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson, size: 20),
            tooltip: l.exportWarehouseReceivingPdfTooltip,
            onPressed: () => _exportGrnPdf(records, l),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final recordsState = ref.watch(warehouseReceivingProvider);
    final currentRecords = recordsState.valueOrNull ?? <WarehouseReceivingModel>[];

    final tabs = [
      VerticalNavTabItem(
        icon: Icons.inventory_outlined,
        titleEn: l.warehouseReceivingTabRegistry,
        titleAr: l.warehouseReceivingTabRegistry,
      ),
      VerticalNavTabItem(
        icon: Icons.add_business_outlined,
        titleEn: l.warehouseReceivingTabNewEntry,
        titleAr: l.warehouseReceivingTabNewEntry,
      ),
    ];

    final bodyContent = SelectionArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 32),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MasterDataToolbarWidget(
                    moduleEndpoint: 'warehouse-receiving',
                    title: 'Warehouse_Receiving',
                    onRefreshNeeded: () => ref.read(warehouseReceivingProvider.notifier).fetchRecords(),
                  ),
                  const SizedBox(height: 12),
                  if (currentRecords.isNotEmpty) ...[
                    _buildMetrics(currentRecords, l),
                    const SizedBox(height: 12),
                  ],
                  _buildToolbar(currentRecords, l),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            recordsState.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: OpsLoadingView(),
              ),
              error: (err, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: OpsStateView.error(
                  title: l.error,
                  message: ApiErrorText.of(l, err),
                  actionLabel: l.retry,
                  onAction: () => ref.read(warehouseReceivingProvider.notifier).fetchRecords(
                        search: _searchController.text,
                        status: _selectedStatusFilter,
                      ),
                ),
              ),
              data: (records) {
                if (records.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: OpsStateView.empty(
                      icon: Icons.inventory_2_outlined,
                      message: l.warehouseReceivingEmptyRecords,
                      actionLabel: l.warehouseReceivingNewGrnBtn,
                      actionIcon: Icons.local_shipping,
                      onAction: () => _showAddEditDialog(),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, idx) {
                      final r = records[idx];
                      return GrnRecordCard(
                        record: r,
                        onView: () => _showAddEditDialog(r),
                        onEdit: () => _showAddEditDialog(r),
                        onPrint: () => _printGrn(r),
                        onDelete: () => _deleteGrn(r),
                        onConfirmReceipt: () => _confirmFinalReceipt(r),
                        onRecordDiscrepancy: () => _showDiscrepancyDialog(r),
                        onOpenInspection: () => WarehouseInspectionDialog.show(context, record: r),
                        onQuarantine: () => _showQuarantineState(r),
                        onCopyRow: () => _copyGrnRowTsv(r, context.l10n),
                        onClone: () => _onCloneGrnRecord(r),
                      );
                    },
                    childCount: records.length,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return VerticalStageScaffold(
      stageCode: 'PHASE-6: STEP_19',
      titleEn: l.warehouseReceivingStageTitle,
      titleAr: l.warehouseReceivingStageTitle,
      headerIcon: Icons.inventory,
      headerColor: AppTheme.cobalt,
      tabs: tabs,
      selectedIndex: 0,
      onTabSelected: (index) {
        if (index == 1) {
          _showAddEditDialog();
        }
      },
      headerActions: [
        IconButton(
          icon: Icon(Icons.refresh, color: AppTheme.white.withValues(alpha: 0.7), size: density.buttonIconSize),
          tooltip: l.warehouseReceivingRefreshTooltip,
          onPressed: () => ref.read(warehouseReceivingProvider.notifier).fetchRecords(),
        ),
      ],
      body: bodyContent,
    );
  }
}
