import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../warehouse_receiving/widgets/ops_ui_kit.dart';
import '../models/cargo_container_defaults.dart';
import '../models/cargo_shipping_model.dart';
import '../providers/cargo_shipping_provider.dart';
import 'search_and_clone_cargo_shipping_dialog.dart';

class SavedCargoShippingRegistryTab extends ConsumerStatefulWidget {
  final void Function(CargoShippingModel rec) onEditRecord;
  final VoidCallback onCreateNewRecord;
  final VoidCallback onRefreshNeeded;
  final void Function(
    CargoShippingModel sourceRec,
    String newCode,
    List<ContainerLoadingModel> clonedContainers,
  )? onCloneRecordToForm;

  const SavedCargoShippingRegistryTab({
    super.key,
    required this.onEditRecord,
    required this.onCreateNewRecord,
    required this.onRefreshNeeded,
    this.onCloneRecordToForm,
  });

  @override
  ConsumerState<SavedCargoShippingRegistryTab> createState() => _SavedCargoShippingRegistryTabState();
}

class _SavedCargoShippingRegistryTabState extends ConsumerState<SavedCargoShippingRegistryTab> {
  final TextEditingController _searchController = TextEditingController();
  String _registryStatusFilter = 'All';
  String _registrySlaFilter = 'All'; // 'All', 'OnTime', 'Breached'
  String _registryActiveFilter = 'Active'; // 'All', 'Active', 'Deleted'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openSearchAndCloneShippingDialog(List<CargoShippingModel> records) {
    final l = context.l10n;
    final isAr = l.isArabic;
    showDialog(
      context: context,
      builder: (dialogCtx) => SelectionArea(
        child: AppLocalizationsProvider(
          locale: isAr ? const Locale('ar') : const Locale('en'),
          child: Directionality(
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            child: SearchAndCloneCargoShippingDialog(
              records: records,
              onSelectRecord: (selected) => _onCloneCargoShipping(selected),
            ),
          ),
        ),
      ),
    );
  }

  void _onCloneCargoShipping(CargoShippingModel rec) {
    final l = context.l10n;
    final isAr = l.isArabic;
    final newDraftCode = 'SHP-DRAFT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final containerSummary = rec.containersLoadingData.isNotEmpty
        ? rec.containersLoadingData.map((c) => '${c.quantity}x ${c.containerType}').join(', ')
        : (rec.shipmentType == 'LCL' ? l.cshLclConsolidation : l.cshStandard40hc);

    showDialog(
      context: context,
      builder: (dialogCtx) => SelectionArea(
        child: AppLocalizationsProvider(
          locale: isAr ? const Locale('ar') : const Locale('en'),
          child: Directionality(
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            child: CloneEntityReviewDialog(
              entityType: l.cshCloneEntityType,
              sourceCode: rec.cargoShippingCode,
              suggestedNewCode: newDraftCode,
              sourceTitle: '${rec.importFileCode ?? "IMP-${rec.importFileId}"} - ${rec.companyName ?? ""}',
              copiedFieldsSummary: {
                l.cshCloneFieldShipmentType: rec.shipmentType,
                l.cshCloneFieldContainers: containerSummary,
                l.cshCloneFieldVgm: l.cshWeightKg(rec.containersLoadingData.fold<double>(0.0, (acc, c) => acc + c.grossWeightKg).toStringAsFixed(0)),
                if (rec.shipmentType == 'LCL' && rec.lclTrackingData?.cfsWarehouseName != null)
                  l.cshCloneFieldCfs: rec.lclTrackingData!.cfsWarehouseName ?? '',
              },
              mandatorilyResetFields: [
                l.cshCloneReset1,
                l.cshCloneReset2,
                l.cshCloneReset3,
                l.cshCloneReset4,
                l.cshCloneReset5,
              ],
              allowCopyLineItems: true,
              allowCopyAttachments: false,
              onConfirm: ({
                required String newCode,
                required String newTitle,
                required bool copyLineItems,
                required bool copyAttachments,
                String? notes,
              }) async {
                final nowIso = DateTime.now().toIso8601String();
                final List<ContainerLoadingModel> clonedContainers = [];

                if (copyLineItems && rec.containersLoadingData.isNotEmpty) {
                  for (final c in rec.containersLoadingData) {
                    final dupUnits = blankUnits(c.individualUnits.length);
                    clonedContainers.add(
                      ContainerLoadingModel(
                        containerType: c.containerType,
                        quantity: c.quantity,
                        containerNo: '',
                        sealNo: '',
                        tareWeightKg: c.tareWeightKg,
                        netWeightKg: c.netWeightKg,
                        grossWeightKg: c.grossWeightKg,
                        vgmStatus: 'Pending',
                        containerAssignmentDate: nowIso,
                        trackingStatus: 'ASSIGNED',
                        individualUnits: dupUnits,
                      ),
                    );
                  }
                }

                if (widget.onCloneRecordToForm != null) {
                  widget.onCloneRecordToForm!(rec, newCode, clonedContainers);
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    AppTheme.snackBar(context, '${l.cloneCargoShippingTooltip}: $newCode', severity: AppSeverity.info),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  void _copyShippingRowTsv(CargoShippingModel rec, AppLocalizations l) {
    final containerSummary = rec.containersLoadingData
        .map((c) => '${c.containerNo} (${c.containerType})')
        .join(', ');
    final gatedCount = rec.containersLoadingData.where((c) => c.trackingStatus == 'GATED_IN_AT_PORT').length;
    final hasBreach = rec.containersLoadingData.any((c) => c.isSlaBreached) || (rec.lclTrackingData?.isSlaBreached ?? false);

    final rowData = [
      rec.cargoShippingCode,
      rec.importFileCode ?? 'IMP-${rec.importFileId}',
      rec.companyName ?? '',
      rec.shipmentType,
      containerSummary,
      rec.status,
      '$gatedCount/${rec.containersLoadingData.length}',
      hasBreach ? l.cargoShippingSlaBreached : l.cargoShippingSlaOnTime,
      rec.isActive ? l.cshStateActive : l.cshStateDeleted,
    ];

    final headers = [
      l.cshColCode,
      l.cshColImportFile,
      l.cshColCompany,
      l.cshColShipType,
      l.cshColContainersSeals,
      l.cshColStatus,
      l.cshColGateIn,
      l.cshColSla,
      l.cshColOp,
    ];

    TableCopyHelper.copyRow(
      context,
      rowData,
      headers: headers,
      includeHeaders: true,
      customMessage: l.copyCargoShippingRowSuccess,
    );
  }

  void _copyShippingTableTsv(List<CargoShippingModel> records, AppLocalizations l) {
    final headers = [
      l.cshColCode,
      l.cshColImportFile,
      l.cshColCompany,
      l.cshColShipType,
      l.cshColContainers,
      l.cshColTotalVgm,
      l.cshColStatus,
      l.cshColGateIn,
      l.cshColSla,
      l.cshColOp,
    ];

    final rows = records.map((r) {
      final containerSummary = r.containersLoadingData
          .map((c) => '${c.containerNo} (${c.containerType})')
          .join(', ');
      final totalVgm = r.containersLoadingData.fold<double>(0.0, (acc, c) => acc + c.grossWeightKg);
      final gatedCount = r.containersLoadingData.where((c) => c.trackingStatus == 'GATED_IN_AT_PORT').length;
      final hasBreach = r.containersLoadingData.any((c) => c.isSlaBreached) || (r.lclTrackingData?.isSlaBreached ?? false);

      return [
        r.cargoShippingCode,
        r.importFileCode ?? 'IMP-${r.importFileId}',
        r.companyName ?? '',
        r.shipmentType,
        containerSummary,
        l.cshWeightKg(totalVgm.toStringAsFixed(0)),
        r.status,
        '$gatedCount/${r.containersLoadingData.length}',
        hasBreach ? l.cargoShippingSlaBreached : l.cargoShippingSlaOnTime,
        r.isActive ? l.cshStateActive : l.cshStateDeleted,
      ];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: l.copyCargoShippingTableSuccess,
    );
  }

  Future<void> _exportShippingExcel(List<CargoShippingModel> records, AppLocalizations l) async {
    final headers = [
      l.cshColCode,
      l.cshColImportFile,
      l.cshColCompany,
      l.cshColShipType,
      l.cshColContainers,
      l.cshColTotalVgm,
      l.cshColStatus,
      l.cshColGateIn,
      l.cshColSla,
      l.cshColOp,
    ];

    final rows = records.map((r) {
      final containerSummary = r.containersLoadingData
          .map((c) => '${c.containerNo} (${c.containerType})')
          .join(', ');
      final totalVgm = r.containersLoadingData.fold<double>(0.0, (acc, c) => acc + c.grossWeightKg);
      final gatedCount = r.containersLoadingData.where((c) => c.trackingStatus == 'GATED_IN_AT_PORT').length;
      final hasBreach = r.containersLoadingData.any((c) => c.isSlaBreached) || (r.lclTrackingData?.isSlaBreached ?? false);

      return [
        r.cargoShippingCode,
        r.importFileCode ?? 'IMP-${r.importFileId}',
        r.companyName ?? '',
        r.shipmentType,
        containerSummary,
        l.cshWeightKg(totalVgm.toStringAsFixed(0)),
        r.status,
        '$gatedCount/${r.containersLoadingData.length}',
        hasBreach ? l.cargoShippingSlaBreached : l.cargoShippingSlaOnTime,
        r.isActive ? l.cshStateActive : l.cshStateDeleted,
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      stageName: 'Cargo Shipping',
      importFileNameOrCode: 'Registry',
      headers: headers,
      rows: rows,
    );
  }

  Future<void> _exportShippingPdf(List<CargoShippingModel> records, AppLocalizations l) async {
    final headers = [
      l.cshColCode,
      l.cshColImportFile,
      l.cshColCompany,
      l.cshColShipType,
      l.cshColContainersShort,
      l.cshColWeightShort,
      l.cshColStatus,
      l.cshColGateInShort,
      l.cshColSlaShort,
    ];

    final rows = records.map((r) {
      final containerSummary = r.containersLoadingData
          .map((c) => '${c.containerNo} (${c.containerType})')
          .join(', ');
      final totalVgm = r.containersLoadingData.fold<double>(0.0, (acc, c) => acc + c.grossWeightKg);
      final gatedCount = r.containersLoadingData.where((c) => c.trackingStatus == 'GATED_IN_AT_PORT').length;
      final hasBreach = r.containersLoadingData.any((c) => c.isSlaBreached) || (r.lclTrackingData?.isSlaBreached ?? false);

      return [
        r.cargoShippingCode,
        r.importFileCode ?? 'IMP-${r.importFileId}',
        r.companyName ?? '—',
        r.shipmentType,
        containerSummary.isNotEmpty ? containerSummary : '—',
        l.cshWeightKg(totalVgm.toStringAsFixed(0)),
        r.status,
        '$gatedCount/${r.containersLoadingData.length}',
        hasBreach ? l.cargoShippingSlaBreached : l.cargoShippingSlaOnTime,
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      stageName: 'Cargo Shipping',
      importFileNameOrCode: 'Registry',
      headers: headers,
      rows: rows,
      headerContext: TableExportHeaderContext(
        title: l.cshPdfTitle,
        subtitle: l.cshPdfSubtitle,
        metadata: {
          l.cshPdfMetaTotal: records.length.toString(),
          l.cshPdfMetaFcl: records.where((r) => r.shipmentType == 'FCL').length.toString(),
          l.cshPdfMetaLcl: records.where((r) => r.shipmentType == 'LCL').length.toString(),
        },
      ),
    );
  }

  Future<void> _confirmDeleteRecord(CargoShippingModel rec) async {
    final l = context.l10n;
    final confirm = await AppConfirmDialog.show(
      context,
      title: l.cargoShippingDeleteConfirmTitle,
      message: l.cargoShippingDeleteConfirmMessage(rec.cargoShippingCode, rec.importFileCode ?? ''),
      confirmLabel: l.cargoShippingConfirmDeleteBtn,
      cancelLabel: l.cancel,
      confirmVariant: AppButtonVariant.danger,
      icon: Icons.delete_outline,
    );
    if (confirm) {
      await ref.read(cargoShippingProvider.notifier).softDeleteRecord(rec.cargoShippingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l.cargoShippingDeleteSuccess(rec.cargoShippingCode), severity: AppSeverity.danger),
        );
      }
    }
  }

  List<EnterpriseColumn<CargoShippingModel>> _buildCargoShippingColumns(
    BuildContext context,
    AppLocalizations l,
    Map<int, dynamic> importFilesMap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      EnterpriseColumn<CargoShippingModel>(
        id: 'actions',
        title: l.actions,
        width: 210,
        cellBuilder: (ctx, rec, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.cobalt),
              tooltip: l.edit,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: const EdgeInsets.all(4),
              onPressed: () => widget.onEditRecord(rec),
            ),
            IconButton(
              key: Key('cloneShippingRowBtn_${rec.cargoShippingCode}'),
              icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
              tooltip: l.cshCloneBtn,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: const EdgeInsets.all(4),
              onPressed: () => _onCloneCargoShipping(rec),
            ),
            IconButton(
              icon: Icon(
                rec.isActive ? Icons.delete_outline : Icons.restore,
                size: 16,
                color: rec.isActive ? AppTheme.crimson : AppTheme.emerald,
              ),
              tooltip: rec.isActive ? l.delete : l.restore,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: const EdgeInsets.all(4),
              onPressed: () async {
                if (rec.isActive) {
                  _confirmDeleteRecord(rec);
                } else {
                  final messenger = ScaffoldMessenger.of(ctx);
                  final snack = AppTheme.snackBar(
                    ctx,
                    l.cargoShippingRestoreSuccess(rec.cargoShippingCode),
                    severity: AppSeverity.success,
                  );
                  await ref.read(cargoShippingProvider.notifier).restoreRecord(rec.cargoShippingId);
                  if (mounted) {
                    messenger.showSnackBar(snack);
                  }
                }
              },
            ),
            IconButton(
              key: Key('copyShippingRowBtn_${rec.cargoShippingCode}'),
              icon: const Icon(Icons.content_copy_outlined, size: 16, color: AppTheme.charcoal),
              tooltip: l.copy,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: const EdgeInsets.all(4),
              onPressed: () => _copyShippingRowTsv(rec, l),
            ),
          ],
        ),
      ),
      EnterpriseColumn<CargoShippingModel>(
        id: 'shipping_code',
        title: l.cshColCode,
        width: 170,
        exportValue: (rec) => rec.cargoShippingCode,
        sortComparator: (a, b) => a.cargoShippingCode.compareTo(b.cargoShippingCode),
        cellBuilder: (ctx, rec, _) => InkWell(
          onTap: () => widget.onEditRecord(rec),
          child: LtrText(
            rec.cargoShippingCode,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.cobalt,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
      EnterpriseColumn<CargoShippingModel>(
        id: 'import_file',
        title: l.cshColImportFile,
        width: 220,
        exportValue: (rec) {
          final matchingFile = importFilesMap[rec.importFileId];
          final fileCode = matchingFile?.primaryNameWithCode ?? rec.importFileCode ?? 'IMP-${rec.importFileId}';
          final companyName = (matchingFile?.companyName.isNotEmpty == true && matchingFile?.companyName != 'N/A')
              ? matchingFile!.companyName
              : (rec.companyName != null && rec.companyName!.isNotEmpty && rec.companyName != 'N/A' ? rec.companyName! : l.importCompanies);
          return fileCode.isNotEmpty ? '$fileCode - $companyName' : companyName;
        },
        cellBuilder: (ctx, rec, _) {
          final matchingFile = importFilesMap[rec.importFileId];
          final fileCode = matchingFile?.primaryNameWithCode ?? rec.importFileCode ?? 'IMP-${rec.importFileId}';
          final companyName = (matchingFile?.companyName.isNotEmpty == true && matchingFile?.companyName != 'N/A')
              ? matchingFile!.companyName
              : (rec.companyName != null && rec.companyName!.isNotEmpty && rec.companyName != 'N/A' ? rec.companyName! : l.importCompanies);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                fileCode,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  fontSize: 12.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (companyName.isNotEmpty)
                Text(
                  companyName,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          );
        },
      ),
      EnterpriseColumn<CargoShippingModel>(
        id: 'supplier',
        title: l.foreignSupplier,
        width: 180,
        exportValue: (rec) {
          final matchingFile = importFilesMap[rec.importFileId];
          return (matchingFile?.supplierName.isNotEmpty == true && matchingFile?.supplierName != 'N/A') ? matchingFile!.supplierName : '';
        },
        cellBuilder: (ctx, rec, _) {
          final matchingFile = importFilesMap[rec.importFileId];
          final supplierName = (matchingFile?.supplierName.isNotEmpty == true && matchingFile?.supplierName != 'N/A') ? matchingFile!.supplierName : '—';
          return Text(
            supplierName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          );
        },
      ),
      EnterpriseColumn<CargoShippingModel>(
        id: 'shipment_type',
        title: l.cshColShipType,
        width: 110,
        exportValue: (rec) => rec.shipmentType,
        cellBuilder: (ctx, rec, _) => Chip(
          label: Text(rec.shipmentType, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          backgroundColor: rec.shipmentType == 'FCL' ? AppTheme.emerald.withValues(alpha: 0.15) : AppTheme.orange.withValues(alpha: 0.15),
          side: BorderSide.none,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
      EnterpriseColumn<CargoShippingModel>(
        id: 'containers_summary',
        title: l.cshColContainers,
        width: 180,
        cellBuilder: (ctx, rec, _) {
          if (rec.shipmentType == 'FCL') {
            final count = rec.containersLoadingData.length;
            final gated = rec.containersLoadingData.where((c) => c.trackingStatus == 'GATED_IN_AT_PORT').length;
            return Text('$count ${l.cshColContainers} ($gated ${l.cshColGateIn})', style: const TextStyle(fontSize: 11.5));
          } else {
            final wh = rec.lclTrackingData?.cfsWarehouseName ?? '—';
            return Text(wh, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5));
          }
        },
      ),
      EnterpriseColumn<CargoShippingModel>(
        id: 'status',
        title: l.cshColStatus,
        width: 150,
        exportValue: (rec) => rec.status,
        cellBuilder: (ctx, rec, _) {
          final statusLabel = rec.status == 'Completed'
              ? l.cargoShippingStatusCompleted
              : (rec.status == 'Cargo Ready' ? l.cargoShippingStatusCargoReady : rec.status);
          final isCompleted = rec.status == 'Completed';
          return OpsStatusChip(
            label: statusLabel,
            severity: isCompleted ? AppSeverity.success : AppSeverity.info,
            icon: isCompleted ? Icons.check_circle_outline : Icons.local_shipping_outlined,
          );
        },
      ),
      EnterpriseColumn<CargoShippingModel>(
        id: 'sla_status',
        title: l.cshColSla,
        width: 140,
        cellBuilder: (ctx, rec, _) {
          final hasBreach = rec.containersLoadingData.any((c) => c.isSlaBreached) || (rec.lclTrackingData?.isSlaBreached ?? false);
          return OpsStatusChip(
            label: hasBreach ? l.cargoShippingSlaBreachedFilter : l.cargoShippingSlaOnTimeFilter,
            severity: hasBreach ? AppSeverity.danger : AppSeverity.success,
            icon: hasBreach ? Icons.alarm_off : Icons.timer_outlined,
          );
        },
      ),
      EnterpriseColumn<CargoShippingModel>(
        id: 'date',
        title: l.invoiceDateCol,
        width: 130,
        exportValue: (rec) => rec.createdAt.split('T').first,
        cellBuilder: (ctx, rec, _) => LtrText(
          rec.createdAt.isNotEmpty ? rec.createdAt.split('T').first : '—',
          style: const TextStyle(fontSize: 11.5),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(cargoShippingProvider);
    final l = context.l10n;
    final allRecords = recordsAsync.valueOrNull ?? const <CargoShippingModel>[];
    final breachedCount = allRecords
        .where((r) => r.containersLoadingData.any((c) => c.isSlaBreached) || (r.lclTrackingData?.isSlaBreached ?? false))
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MasterDataToolbarWidget(
            moduleEndpoint: 'cargo-shipping',
            title: 'Cargo_Shipping_Registry',
            onRefreshNeeded: widget.onRefreshNeeded,
          ),
          const SizedBox(height: 12),

          // Registry metrics (values already loaded)
          MetricCardStrip(
            padding: EdgeInsets.zero,
            metrics: [
              MetricCardData(
                title: l.cshMetricRecords,
                value: '${allRecords.length}',
                icon: Icons.local_shipping_outlined,
                color: AppTheme.cobalt,
              ),
              MetricCardData(
                title: l.cshPdfMetaFcl,
                value: '${allRecords.where((r) => r.shipmentType == 'FCL').length}',
                icon: Icons.view_in_ar_outlined,
                color: AppTheme.emerald,
              ),
              MetricCardData(
                title: l.cshPdfMetaLcl,
                value: '${allRecords.where((r) => r.shipmentType == 'LCL').length}',
                icon: Icons.warehouse_outlined,
                color: AppTheme.orange,
              ),
              MetricCardData(
                title: l.cargoShippingMetricSlaBreached,
                value: '$breachedCount',
                icon: Icons.alarm_off,
                color: breachedCount > 0 ? AppTheme.crimson : AppTheme.textMutedOf(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Top Actions Toolbar
          Container(
            padding: const EdgeInsetsDirectional.all(12),
            decoration: AppTheme.toolbarDecorationOf(context),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CcUi.fit(AppButton(
                  key: const Key('createShippingBtn'),
                  label: l.cargoShippingCreateNewRecord,
                  icon: Icons.add_task,
                  size: AppButtonSize.small,
                  onPressed: widget.onCreateNewRecord,
                )),
                CcUi.fit(AppButton(
                  key: const Key('searchAndCloneShippingBtn'),
                  label: l.searchAndCloneCargoShippingBtn,
                  icon: Icons.copy_all_rounded,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () => _openSearchAndCloneShippingDialog(allRecords),
                )),
                CcUi.fit(AppButton(
                  key: const Key('copyShippingTableTsvBtn'),
                  label: l.customsDeclExportTsvButton,
                  icon: Icons.copy,
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.small,
                  onPressed: () => _copyShippingTableTsv(allRecords, l),
                )),
                CcUi.fit(AppButton(
                  key: const Key('exportShippingExcelBtn'),
                  label: l.exportCargoShippingExcelTooltip,
                  icon: Icons.table_chart,
                  variant: AppButtonVariant.success,
                  size: AppButtonSize.small,
                  onPressed: () => _exportShippingExcel(allRecords, l),
                )),
                CcUi.fit(AppButton(
                  key: const Key('exportShippingPdfBtn'),
                  label: l.exportCargoShippingPdfTooltip,
                  icon: Icons.picture_as_pdf,
                  variant: AppButtonVariant.danger,
                  size: AppButtonSize.small,
                  onPressed: () => _exportShippingPdf(allRecords, l),
                )),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Filters Bar
          Container(
            padding: const EdgeInsetsDirectional.all(12),
            decoration: AppTheme.cardDecorationOf(context),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final searchField = AppSearchField(
                  controller: _searchController,
                  hint: context.l10n.cargoShippingRegistrySearchHint,
                  onChanged: (_) => setState(() {}),
                );

                final statusDropdown = SearchableDropdownField<String>(
                  labelText: context.l10n.cargoShippingStatusFilterLabel,
                  value: _registryStatusFilter,
                  items: [
                    SearchableDropdownItem(value: 'All', label: context.l10n.cargoShippingStatusAll),
                    SearchableDropdownItem(value: 'Cargo Ready', label: context.l10n.cargoShippingStatusCargoReady),
                    SearchableDropdownItem(value: 'Completed', label: context.l10n.cargoShippingStatusCompleted),
                  ],
                  onChanged: (v) => setState(() => _registryStatusFilter = v ?? 'All'),
                );

                final slaDropdown = SearchableDropdownField<String>(
                  labelText: context.l10n.cargoShippingSlaFilterLabel,
                  value: _registrySlaFilter,
                  items: [
                    SearchableDropdownItem(value: 'All', label: context.l10n.cargoShippingSlaAll),
                    SearchableDropdownItem(value: 'OnTime', label: context.l10n.cargoShippingSlaOnTimeFilter),
                    SearchableDropdownItem(value: 'Breached', label: context.l10n.cargoShippingSlaBreachedFilter),
                  ],
                  onChanged: (v) => setState(() => _registrySlaFilter = v ?? 'All'),
                );

                final activeDropdown = SearchableDropdownField<String>(
                  labelText: context.l10n.cargoShippingActiveFilterLabel,
                  value: _registryActiveFilter,
                  items: [
                    SearchableDropdownItem(value: 'All', label: context.l10n.cargoShippingActiveAll),
                    SearchableDropdownItem(value: 'Active', label: context.l10n.cargoShippingActiveOnly),
                    SearchableDropdownItem(value: 'Deleted', label: context.l10n.cargoShippingDeletedOnly),
                  ],
                  onChanged: (v) => setState(() => _registryActiveFilter = v ?? 'Active'),
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(flex: 3, child: searchField),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: statusDropdown),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: slaDropdown),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: activeDropdown),
                    ],
                  );
                } else {
                  final halfWidth = (constraints.maxWidth - 10) / 2;
                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(width: halfWidth.clamp(140.0, 300.0), child: statusDropdown),
                          SizedBox(width: halfWidth.clamp(140.0, 300.0), child: slaDropdown),
                          SizedBox(width: constraints.maxWidth, child: activeDropdown),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),

          // Registry list
          recordsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: AppLoadingState(),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: AppErrorState(
                message: '${context.l10n.error}: $err',
                onRetry: widget.onRefreshNeeded,
              ),
            ),
            data: (list) {
              final filtered = list.where((item) {
                final query = _searchController.text.trim().toLowerCase();
                if (query.isNotEmpty) {
                  final matchCode = item.cargoShippingCode.toLowerCase().contains(query);
                  final matchFile = (item.importFileCode ?? '').toLowerCase().contains(query);
                  final matchCompany = (item.companyName ?? '').toLowerCase().contains(query);
                  final matchContainer = item.containersLoadingData.any((c) => c.containerNo.toLowerCase().contains(query) || c.sealNo.toLowerCase().contains(query));
                  if (!matchCode && !matchFile && !matchCompany && !matchContainer) return false;
                }

                if (_registryStatusFilter != 'All' && item.status != _registryStatusFilter) return false;

                final hasBreach = item.containersLoadingData.any((c) => c.isSlaBreached) || (item.lclTrackingData?.isSlaBreached ?? false);
                if (_registrySlaFilter == 'Breached' && !hasBreach) return false;
                if (_registrySlaFilter == 'OnTime' && hasBreach) return false;

                if (_registryActiveFilter == 'Active' && !item.isActive) return false;
                if (_registryActiveFilter == 'Deleted' && item.isActive) return false;

                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: AppEmptyState(
                    message: context.l10n.cargoShippingNoMatchingRecords,
                    icon: Icons.folder_open,
                    actionLabel: context.l10n.cargoShippingCreateNewRecord,
                    onAction: widget.onCreateNewRecord,
                  ),
                );
              }

              final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
              final importFilesMap = {for (final f in importFiles) f.importFileId: f};

              final shippingNotifier = ref.read(cargoShippingProvider.notifier);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: AppTheme.cardDecorationOf(context),
                    clipBehavior: Clip.antiAlias,
                    child: EnterpriseDataTable<CargoShippingModel>(
                      storageKey: 'cargo_shipping_enterprise_table',
                      data: filtered,
                      minWidth: 1400,
                      showHeaderToolbar: false,
                      showPagination: false,
                      columns: _buildCargoShippingColumns(context, l, importFilesMap),
                    ),
                  ),
                  ListLoadMoreFooter(
                    loaded: list.length,
                    total: shippingNotifier.totalCount,
                    hasMore: shippingNotifier.hasMore,
                    onLoadMore: shippingNotifier.loadMore,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
