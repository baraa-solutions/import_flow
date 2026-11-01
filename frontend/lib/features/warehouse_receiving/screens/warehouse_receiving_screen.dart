import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/warehouse_receiving_model.dart';
import '../providers/warehouse_receiving_provider.dart';
import '../widgets/grn_discrepancy_dialog.dart';
import '../widgets/grn_record_card.dart';
import '../widgets/ops_ui_kit.dart';
import '../widgets/screen/warehouse_receiving_actions_helper.dart';
import '../widgets/screen/warehouse_receiving_metrics.dart';
import '../widgets/screen/warehouse_receiving_toolbar.dart';
import '../widgets/search_and_clone_warehouse_receiving_dialog.dart';
import '../widgets/warehouse_inspection_dialog.dart';
import '../widgets/warehouse_receiving_form_dialog.dart';

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
          WarehouseReceivingActionsHelper.onCloneGrnRecord(context, selectedRec);
        },
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
                    WarehouseReceivingMetrics(records: currentRecords),
                    const SizedBox(height: 12),
                  ],
                  WarehouseReceivingToolbar(
                    records: currentRecords,
                    searchController: _searchController,
                    selectedStatusFilter: _selectedStatusFilter,
                    onAddRecord: () => _showAddEditDialog(),
                    onSearchAndClone: () => _openSearchAndCloneDialog(currentRecords),
                    onSearchChanged: (val) {
                      ref.read(warehouseReceivingProvider.notifier).fetchRecords(
                            search: val,
                            status: _selectedStatusFilter,
                          );
                    },
                    onStatusFilterChanged: (val) {
                      setState(() => _selectedStatusFilter = val);
                      ref.read(warehouseReceivingProvider.notifier).fetchRecords(
                            search: _searchController.text,
                            status: val,
                          );
                    },
                    onCopyTsv: () => WarehouseReceivingActionsHelper.copyGrnTableTsv(
                      context,
                      currentRecords,
                      l,
                    ),
                    onExportExcel: () => WarehouseReceivingActionsHelper.exportGrnExcel(
                      context,
                      currentRecords,
                      l,
                    ),
                    onExportPdf: () => WarehouseReceivingActionsHelper.exportGrnPdf(
                      context,
                      currentRecords,
                      l,
                    ),
                  ),
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
                        onPrint: () => WarehouseReceivingActionsHelper.printGrn(context, r),
                        onDelete: () => WarehouseReceivingActionsHelper.deleteGrn(context, ref, r),
                        onConfirmReceipt: () => WarehouseReceivingActionsHelper.confirmFinalReceipt(context, ref, r),
                        onRecordDiscrepancy: () => showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => GrnDiscrepancyReportDialog(record: r),
                        ),
                        onOpenInspection: () => WarehouseInspectionDialog.show(context, record: r),
                        onQuarantine: () => WarehouseReceivingActionsHelper.showQuarantineState(context, r),
                        onCopyRow: () => WarehouseReceivingActionsHelper.copyGrnRowTsv(context, r, context.l10n),
                        onClone: () => WarehouseReceivingActionsHelper.onCloneGrnRecord(context, r),
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
