import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/master_data_toolbar.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';

import 'package:printing/printing.dart';

import '../../customs_consultation/models/customs_consultation_model.dart';
import '../../customs_consultation/providers/customs_consultation_provider.dart';
import '../../customs_consultation/services/customs_consultation_pdf_service.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/shipment_update_model.dart';
import '../providers/shipment_updates_provider.dart';
import '../widgets/shipment_update_dialog.dart';
import '../../../core/services/display_name_resolver.dart';

class ShipmentUpdateEngineScreen extends ConsumerStatefulWidget {
  const ShipmentUpdateEngineScreen({super.key});

  @override
  ConsumerState<ShipmentUpdateEngineScreen> createState() => _ShipmentUpdateEngineScreenState();
}

class _ShipmentUpdateEngineScreenState extends ConsumerState<ShipmentUpdateEngineScreen> {
  int? _selectedFileId;
  ImportFileModel? _selectedFile;

  static const List<String> _phaseCodes = [
    'Phase 1',
    'Phase 2',
    'Phase 3',
    'Phase 4',
    'Phase 5',
    'Phase 6',
    'Phase 7',
    'Phase 8',
    'Phase 9',
    'Phase 10',
  ];

  String _getPhaseName(AppLocalizations l, String phaseCode) {
    return DisplayNameResolver.resolvePhaseName(
      phaseCode,
      isArabic: Localizations.localeOf(context).languageCode == 'ar',
    );
  }

  String _getStatusName(AppLocalizations l, String status) {
    switch (status) {
      case 'Completed': return l.shipmentUpdateStatusCompleted;
      case 'Current': return l.shipmentUpdateStatusCurrent;
      case 'Future': return l.shipmentUpdateStatusFuture;
      default: return status;
    }
  }

  String _getCategoryLabel(AppLocalizations l, String category) {
    switch (category) {
      case 'Daily Check-in':
        return l.shipmentUpdateBadgeDaily;
      case 'Phase Cost Adjustment':
        return l.shipmentUpdateBadgeCostAdj;
      case 'Future Phase Alert':
        return l.shipmentUpdateBadgeFutureAlert;
      case 'Follow-up & Notes':
        return l.shipmentUpdateBadgeFollowUp;
      default:
        return category;
    }
  }

  String _buildRowSummary(ShipmentUpdateLogModel log) {
    final l = context.l10n;
    final b = StringBuffer();
    b.writeln('${l.shipmentUpdatesTsvHeaderCode}: ${log.updateCode}');
    b.writeln('${l.shipmentUpdatesTsvHeaderDate}: ${log.logDate}');
    b.writeln('${l.shipmentUpdatesTsvHeaderCategory}: ${_getCategoryLabel(l, log.updateCategory)}');
    b.writeln('${l.shipmentUpdatesTsvHeaderPhase}: ${_getPhaseName(l, log.targetPhase)}');
    if (log.updateCategory == 'Phase Cost Adjustment') {
      b.writeln('${l.shipmentUpdatesTsvHeaderCostItem}: ${log.adjustedCostItem ?? l.shipmentUpdateCostLabel}');
      b.writeln('${l.shipmentUpdatesTsvHeaderPrevCost}: ${log.previousCost.toStringAsFixed(2)}');
      b.writeln('${l.shipmentUpdatesTsvHeaderNewCost}: ${log.newCost.toStringAsFixed(2)}');
    }
    b.writeln('${l.shipmentUpdatesTsvHeaderPriority}: ${log.alertPriority}');
    b.writeln('${l.shipmentUpdatesTsvHeaderAssignedUser}: ${log.assignedUser}');
    b.writeln('${l.shipmentUpdatesTsvHeaderNotes}: ${log.note}');
    return b.toString().trim();
  }

  void _copyShipmentUpdatesTsv(List<ShipmentUpdateLogModel> logs) {
    final l = context.l10n;
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.shipmentUpdateLogsEmptyMessage), backgroundColor: AppTheme.charcoal),
      );
      return;
    }
    final headers = [
      l.shipmentUpdatesTsvHeaderCode,
      l.shipmentUpdatesTsvHeaderDate,
      l.shipmentUpdatesTsvHeaderCategory,
      l.shipmentUpdatesTsvHeaderPhase,
      l.shipmentUpdatesTsvHeaderNotes,
      l.shipmentUpdatesTsvHeaderCostItem,
      l.shipmentUpdatesTsvHeaderPrevCost,
      l.shipmentUpdatesTsvHeaderNewCost,
      l.shipmentUpdatesTsvHeaderPriority,
      l.shipmentUpdatesTsvHeaderAssignedUser,
      l.shipmentUpdatesTsvHeaderStatus,
    ];
    final rows = logs.map((log) {
      final categoryLabel = _getCategoryLabel(l, log.updateCategory);
      final phaseName = _getPhaseName(l, log.targetPhase);
      return [
        log.updateCode,
        log.logDate,
        categoryLabel,
        phaseName,
        log.note.replaceAll('\t', ' ').replaceAll('\n', ' / '),
        log.adjustedCostItem ?? '-',
        log.previousCost.toStringAsFixed(2),
        log.newCost.toStringAsFixed(2),
        log.alertPriority,
        log.assignedUser,
        _getStatusName(l, log.phaseStatus),
      ].join('\t');
    }).toList();

    final tsv = [headers.join('\t'), ...rows].join('\n');
    CopyHelper.copy(
      context,
      tsv,
      customMessage: l.shipmentUpdatesExportTsvSuccess,
    );
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles().then((_) {
          if (!mounted) return;
          final files = ref.read(importFilesProvider).value ?? [];
          if (files.isNotEmpty && _selectedFileId == null) {
            setState(() {
              _selectedFileId = files.first.importFileId;
              _selectedFile = files.first;
            });
            if (!ref.read(shipmentUpdatesProvider).isLoading) {
              ref.read(shipmentUpdatesProvider.notifier).fetchLogs(importFileId: files.first.importFileId);
            }
          }
        });
      }
    });
  }

  void _onShipmentSelected(int? val, List<ImportFileModel> files) {
    if (val == null) return;
    final file = files.firstWhere((f) => f.importFileId == val);
    setState(() {
      _selectedFileId = val;
      _selectedFile = file;
    });
    ref.read(shipmentUpdatesProvider.notifier).fetchLogs(importFileId: val);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final importFilesState = ref.watch(importFilesProvider);
    final updatesState = ref.watch(shipmentUpdatesProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppTheme.charcoal,
        title: Row(
          children: [
            const Icon(Icons.published_with_changes, color: AppTheme.cobalt),
            const SizedBox(width: 10),
            Text(l.shipmentUpdateEngineTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          const BackToDashboardButton(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: l.shipmentUpdateRefreshTooltip,
            onPressed: () {
              ref.read(importFilesProvider.notifier).fetchImportFiles();
              if (_selectedFileId != null) {
                ref.read(shipmentUpdatesProvider.notifier).fetchLogs(importFileId: _selectedFileId);
              }
            },
          ),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Top Toolbar: Shipment Selector Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: importFilesState.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (err, _) => Text(l.shipmentUpdateErrorLoadingShipments(err.toString()), style: const TextStyle(color: AppTheme.crimson)),
                  data: (files) {
                    if (files.isEmpty) {
                      return Text(l.shipmentUpdateNoShipmentsRegistered);
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: SearchableDropdownField<int>(
                            value: _selectedFileId,
                            labelText: l.shipmentUpdateSelectShipmentPrompt,
                            items: files.map((f) {
                              final isAr = Localizations.localeOf(context).languageCode == 'ar';
                              final sTitle = DisplayNameResolver.resolveShipmentTitle(f, isArabic: isAr);
                              final pTitle = DisplayNameResolver.resolvePhaseName(f.currentModule, isArabic: isAr);
                              return SearchableDropdownItem<int>(
                                value: f.importFileId,
                                label: '$sTitle - ${f.supplierName} ($pTitle)',
                              );
                            }).toList(),
                            onChanged: (val) => _onShipmentSelected(val, files),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                          onPressed: _selectedFile == null
                              ? null
                              : () {
                                  ShipmentUpdateDialog.show(
                                    context,
                                    initialFileId: _selectedFile!.importFileId,
                                    initialFileCode: _selectedFile!.customFileNumber ?? _selectedFile!.importFileCode,
                                    initialTargetPhase: _selectedFile!.currentModule,
                                    defaultCategory: 'Daily Check-in',
                                  );
                                },
                          icon: const Icon(Icons.today, color: Colors.white),
                          label: Text(l.shipmentUpdateComprehensiveDailyCheckinBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.charcoal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                          onPressed: updatesState.logs.isEmpty ? null : () => _copyShipmentUpdatesTsv(updatesState.logs),
                          icon: const Icon(Icons.copy_all_rounded, size: 16, color: AppTheme.cobalt),
                          label: Text(l.shipmentUpdatesExportTsvBtn),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.charcoal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                          onPressed: updatesState.logs.isEmpty
                              ? null
                              : () => MasterDataExportService.exportShipmentUpdatesToExcel(
                                    context,
                                    updatesState.logs,
                                    shipmentCode: _selectedFile?.customFileNumber ?? _selectedFile?.importFileCode,
                                    isAr: Localizations.localeOf(context).languageCode == 'ar',
                                  ),
                          icon: const Icon(Icons.table_view_rounded, size: 16, color: AppTheme.emerald),
                          label: Text(l.shipmentUpdatesExportExcelBtn),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.charcoal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                          onPressed: updatesState.logs.isEmpty
                              ? null
                              : () => MasterDataExportService.printOrSaveShipmentUpdatesListPdf(
                                    context,
                                    updatesState.logs,
                                    shipmentCode: _selectedFile?.customFileNumber ?? _selectedFile?.importFileCode,
                                    isAr: Localizations.localeOf(context).languageCode == 'ar',
                                  ),
                          icon: const Icon(Icons.print_rounded, size: 16, color: AppTheme.charcoal),
                          label: Text(l.shipmentUpdatesExportPdfBtn),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Visual 10-Phase Pipeline Inspector Component
            if (_selectedFile != null) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.hub, color: AppTheme.cobalt, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    DisplayNameResolver.resolveShipmentName(
                                      _selectedFile!,
                                      isArabic: Localizations.localeOf(context).languageCode == 'ar',
                                    ),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cobalt.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    _selectedFile!.customFileNumber ?? _selectedFile!.importFileCode,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DisplayNameResolver.resolvePhaseName(
                              _selectedFile!.currentModule,
                              isArabic: Localizations.localeOf(context).languageCode == 'ar',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Inspected Phases Stepper
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _phaseCodes.map((pCode) {
                            final pName = _getPhaseName(l, pCode);

                            // Find inspection data
                            final insp = updatesState.inspectedPhases.firstWhere(
                              (ip) => ip.phaseCode == pCode,
                              orElse: () => PhaseInspectionModel(phaseCode: pCode, phaseName: pName, phaseNumber: 1, status: 'Future', updateCount: 0),
                            );

                            Color tileBg = Colors.grey.shade100;
                            Color borderCol = Colors.grey.shade300;
                            Color textCol = Colors.grey.shade700;
                            IconData statusIcon = Icons.hourglass_empty;

                            if (insp.status == 'Completed') {
                              tileBg = Colors.green.shade50;
                              borderCol = AppTheme.emerald;
                              textCol = Colors.green.shade900;
                              statusIcon = Icons.check_circle;
                            } else if (insp.status == 'Current') {
                              tileBg = Colors.blue.shade50;
                              borderCol = AppTheme.cobalt;
                              textCol = AppTheme.cobalt;
                              statusIcon = Icons.play_circle_fill;
                            } else {
                              tileBg = Colors.orange.shade50;
                              borderCol = Colors.orange.shade300;
                              textCol = Colors.orange.shade900;
                              statusIcon = Icons.upcoming;
                            }

                            return Container(
                              margin: const EdgeInsetsDirectional.only(end: 10),
                              width: 140,
                              child: InkWell(
                                onTap: () {
                                  ShipmentUpdateDialog.show(
                                    context,
                                    initialFileId: _selectedFile!.importFileId,
                                    initialFileCode: _selectedFile!.customFileNumber ?? _selectedFile!.importFileCode,
                                    initialTargetPhase: pCode,
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: tileBg, border: Border.all(color: borderCol), borderRadius: BorderRadius.circular(8)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(statusIcon, size: 16, color: borderCol),
                                          const SizedBox(width: 6),
                                          Text(_getStatusName(l, insp.status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: borderCol)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(pName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textCol), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                      Text(l.shipmentUpdateCountBadge(insp.updateCount), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── CUSTOMS CONSULTATION & INSPECTION RESULTS CARD ──────────────
            if (_selectedFile != null) ...[
              _buildCustomsConsultationSection(
                (ref.watch(customsConsultationsProvider).value ?? []).where((c) =>
                    (c.importFileId != null && c.importFileId == _selectedFileId) ||
                    (c.importFileCode != null && c.importFileCode == (_selectedFile!.customFileNumber ?? _selectedFile!.importFileCode)) ||
                    (c.importFileCode != null && c.importFileCode == _selectedFile!.importFileCode)
                ).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Master Data Toolbar (Data Actions & Export/Import)
            MasterDataToolbarWidget(
              moduleEndpoint: 'shipment-updates',
              title: 'Shipment_Updates',
              onRefreshNeeded: () {
                if (_selectedFileId != null) {
                  if (!ref.read(shipmentUpdatesProvider).isLoading) {
                    ref.read(shipmentUpdatesProvider.notifier).fetchLogs(importFileId: _selectedFileId);
                  }
                  if (!ref.read(customsConsultationsProvider).isLoading) {
                    ref.read(customsConsultationsProvider.notifier).fetchConsultations();
                  }
                }
              },
            ),
            const SizedBox(height: 12),

            // Live Update Logs Table
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: updatesState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : updatesState.error != null
                        ? Center(child: Text(l.shipmentUpdateLogsFetchError(updatesState.error.toString()), style: const TextStyle(color: AppTheme.crimson)))
                        : updatesState.logs.isEmpty
                            ? Center(child: Text(l.shipmentUpdateLogsEmptyMessage))
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(AppTheme.charcoal.withOpacity(0.05)),
                                    columns: [
                                      DataColumn(label: Text(l.shipmentUpdateColActions, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text(l.shipmentUpdateColCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text(l.shipmentUpdateColDate, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text(l.shipmentUpdateColType, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text(l.shipmentUpdateColTargetStage, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text(l.shipmentUpdateColNotes, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text(l.shipmentUpdateColCostAdjustment, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text(l.shipmentUpdateColAssignedUser, style: const TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: updatesState.logs.map((log) {
                                      final isCostAdj = log.updateCategory == 'Phase Cost Adjustment';
                                      final isDaily = log.updateCategory == 'Daily Check-in';
                                      final rowSummary = _buildRowSummary(log);

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                RowActionsPill(
                                                  onView: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (c) => SelectionArea(
                                                        child: AlertDialog(
                                                          title: Text(l.shipmentUpdateViewDialogTitle(log.updateCode)),
                                                          content: Column(
                                                            mainAxisSize: MainAxisSize.min,
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(l.shipmentUpdateViewStage(_getPhaseName(l, log.targetPhase)), style: const TextStyle(fontWeight: FontWeight.bold)),
                                                              Text(l.shipmentUpdateViewDate(log.logDate)),
                                                              Text(l.shipmentUpdateViewUser(log.assignedUser)),
                                                              const SizedBox(height: 8),
                                                              Text('${l.shipmentUpdateViewNotes}\n${log.note}'),
                                                            ],
                                                          ),
                                                          actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(l.shipmentUpdateViewCloseBtn))],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  onEdit: () {
                                                    ShipmentUpdateDialog.show(
                                                      context,
                                                      initialFileId: log.importFileId,
                                                      initialTargetPhase: log.targetPhase,
                                                      defaultCategory: log.updateCategory,
                                                    );
                                                  },
                                                  onPrint: () => MasterDataExportService.printOrSaveShipmentUpdateSlipPdf(
                                                    log,
                                                    isAr: Localizations.localeOf(context).languageCode == 'ar',
                                                  ),
                                                  onDelete: () async {
                                                    final confirm = await showDialog<bool>(
                                                      context: context,
                                                      builder: (c) => SelectionArea(
                                                        child: AlertDialog(
                                                          title: Text(l.shipmentUpdateDeleteConfirmTitle),
                                                          content: Text(l.shipmentUpdateDeleteConfirmMsg(log.updateCode)),
                                                          actions: [
                                                            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.shipmentUpdateDeleteCancelBtn)),
                                                            ElevatedButton(
                                                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
                                                              onPressed: () => Navigator.pop(c, true),
                                                              child: Text(l.shipmentUpdateDeleteConfirmBtn, style: const TextStyle(color: Colors.white)),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                    if (confirm == true) {
                                                      ref.read(shipmentUpdatesProvider.notifier).deleteLog(log.updateId);
                                                    }
                                                  },
                                                  viewTooltip: l.shipmentUpdateActionViewTooltip,
                                                  editTooltip: l.shipmentUpdateActionEditTooltip,
                                                  printTooltip: l.shipmentUpdateActionPrintTooltip,
                                                  deleteTooltip: l.shipmentUpdateActionDeleteTooltip,
                                                ),
                                                const SizedBox(width: 4),
                                                IconButton(
                                                  icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                                                  tooltip: l.shipmentUpdateCopySummaryBtn,
                                                  onPressed: () => CopyHelper.copy(
                                                    context,
                                                    rowSummary,
                                                    customMessage: l.shipmentUpdateCopySummarySuccess,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            CopyableTableCell(
                                              value: log.updateCode,
                                              rowSummary: rowSummary,
                                              child: InkWell(
                                                onTap: () => CopyHelper.copy(
                                                  context,
                                                  log.updateCode,
                                                  customMessage: l.shipmentUpdateCodeBadgeLabel,
                                                ),
                                                borderRadius: BorderRadius.circular(4),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.cobalt.withOpacity(0.08),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.copy_rounded, size: 12, color: AppTheme.cobalt),
                                                      const SizedBox(width: 4),
                                                      Text(log.updateCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            CopyableTableCell(
                                              value: log.logDate,
                                              rowSummary: rowSummary,
                                              child: Text(log.logDate),
                                            ),
                                          ),
                                          DataCell(
                                            CopyableTableCell(
                                              value: isDaily
                                                  ? l.shipmentUpdateBadgeDaily
                                                  : (isCostAdj ? l.shipmentUpdateBadgeCostAdj : _getCategoryLabel(l, log.updateCategory)),
                                              rowSummary: rowSummary,
                                              child: Chip(
                                                label: Text(
                                                  isDaily
                                                      ? l.shipmentUpdateBadgeDaily
                                                      : (isCostAdj ? l.shipmentUpdateBadgeCostAdj : _getCategoryLabel(l, log.updateCategory)),
                                                  style: const TextStyle(fontSize: 10, color: Colors.white),
                                                ),
                                                backgroundColor: isDaily ? AppTheme.emerald : (isCostAdj ? AppTheme.orange : AppTheme.cobalt),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            CopyableTableCell(
                                              value: _getPhaseName(l, log.targetPhase),
                                              rowSummary: rowSummary,
                                              child: Text(_getPhaseName(l, log.targetPhase), style: const TextStyle(fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                          DataCell(
                                            CopyableTableCell(
                                              value: log.note,
                                              rowSummary: rowSummary,
                                              child: SizedBox(
                                                width: 320,
                                                child: Text(log.note, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            CopyableTableCell(
                                              value: isCostAdj
                                                  ? '${log.adjustedCostItem ?? l.shipmentUpdateCostLabel}: ${log.previousCost} -> ${log.newCost} ${l.shipmentUpdateCostCurrencyUsd}'
                                                  : '-',
                                              rowSummary: rowSummary,
                                              child: isCostAdj
                                                  ? Text(
                                                      '${log.adjustedCostItem ?? l.shipmentUpdateCostLabel}: ${log.previousCost} ➔ ${log.newCost} ${l.shipmentUpdateCostCurrencyUsd}',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson, fontSize: 11),
                                                    )
                                                  : const Text('-'),
                                            ),
                                          ),
                                          DataCell(
                                            CopyableTableCell(
                                              value: log.assignedUser,
                                              rowSummary: rowSummary,
                                              child: Text(log.assignedUser),
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
  );
  }

  Widget _buildCustomsConsultationSection(List<CustomsConsultationModel> consultations) {
    final l = context.l10n;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gavel_rounded, color: AppTheme.cobalt, size: 22),
                const SizedBox(width: 8),
                Text(
                  l.shipmentUpdateCustomsSecTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: consultations.isNotEmpty ? AppTheme.emerald.withOpacity(0.12) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: consultations.isNotEmpty ? AppTheme.emerald.withOpacity(0.4) : Colors.grey.shade300),
                  ),
                  child: Text(
                    consultations.isNotEmpty
                        ? l.shipmentUpdateCustomsStudiesCount(consultations.length)
                        : l.shipmentUpdateCustomsNoStudies,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: consultations.isNotEmpty ? AppTheme.emerald : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (consultations.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.cobalt, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.shipmentUpdateCustomsEmptyPrompt,
                        style: const TextStyle(fontSize: 12, color: AppTheme.charcoal, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...consultations.map((c) {
                final readinessPct = c.readinessPercentage;
                final hasBlocking = c.hasBlockingIssues || c.blockingIssuesCount > 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.cobalt.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Code, Title, Broker, Status
                       Row(
                        children: [
                          InkWell(
                            onTap: () => CopyHelper.copy(
                              context,
                              c.consultationCode,
                              customMessage: l.shipmentUpdateConsultCodeBadgeLabel,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.copy_rounded, size: 12, color: AppTheme.cobalt),
                                  const SizedBox(width: 4),
                                  Text(
                                    c.consultationCode,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              c.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(l.shipmentUpdateBrokerPrefix(c.brokerName), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(width: 10),
                          _buildCustomsStatusBadge(l, c.overallStatus),
                        ],
                      ),
                      const Divider(height: 18),

                      // Metrics & Quick Status Bar
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildMetricBadge(
                            l.shipmentUpdateMetricEstDuties,
                            '${c.estimatedDutiesEgp.toStringAsFixed(0)} EGP',
                            AppTheme.crimson,
                          ),
                          _buildMetricBadge(
                            l.shipmentUpdateMetricApprovedDocs,
                            l.shipmentUpdateMetricDocsRatio(c.approvedDocumentsCount, c.totalDocumentsCount),
                            Colors.green.shade800,
                          ),
                          _buildMetricBadge(
                            l.shipmentUpdateMetricBlockingIssues,
                            hasBlocking
                                ? l.shipmentUpdateMetricBlockingCount(c.blockingIssuesCount)
                                : l.shipmentUpdateMetricZeroBlocking,
                            hasBlocking ? AppTheme.crimson : AppTheme.emerald,
                          ),
                          // Progress Bar
                          Container(
                            width: 160,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(l.shipmentUpdateMetricReadinessRate, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    Text(
                                      '${readinessPct.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: readinessPct >= 80 ? AppTheme.emerald : (readinessPct >= 50 ? Colors.orange : AppTheme.crimson),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (readinessPct / 100).clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      readinessPct >= 80 ? AppTheme.emerald : (readinessPct >= 50 ? Colors.orange : AppTheme.crimson),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Actions Row: View, Edit, Print & Daily Update
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.charcoal,
                              side: BorderSide(color: Colors.grey.shade400),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () {
                              Printing.layoutPdf(
                                onLayout: (format) =>
                                    CustomsConsultationPdfService.generateConsultationPdf(c),
                                name: 'Customs_Consultation_${c.consultationCode}',
                              );
                            },
                            icon: const Icon(Icons.print_rounded, size: 16),
                            label: Text(l.shipmentUpdateBtnPrintPdf, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.cobalt,
                              side: const BorderSide(color: AppTheme.cobalt),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => _showConsultationDetailsDialog(c, initialEditMode: false),
                            icon: const Icon(Icons.visibility_rounded, size: 16),
                            label: Text(l.shipmentUpdateBtnViewChecklist, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.orange,
                              side: const BorderSide(color: AppTheme.orange),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => _showConsultationDetailsDialog(c, initialEditMode: true),
                            icon: const Icon(Icons.edit_note_rounded, size: 16),
                            label: Text(l.shipmentUpdateBtnEditDocs, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.emerald,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () {
                              ShipmentUpdateDialog.show(
                                context,
                                initialFileId: _selectedFile!.importFileId,
                                initialFileCode: _selectedFile!.customFileNumber ?? _selectedFile!.importFileCode,
                                initialTargetPhase: 'Phase 6',
                                defaultCategory: 'Daily Check-in',
                              );
                            },
                            icon: const Icon(Icons.post_add_rounded, color: Colors.white, size: 16),
                            label: Text(l.shipmentUpdateBtnRecordDailyUpdate, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _showConsultationDetailsDialog(CustomsConsultationModel session, {bool initialEditMode = false}) {
    final l = context.l10n;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isEditing = initialEditMode;
        bool isSaving = false;
        String selectedStatus = session.overallStatus;
        final List<CustomsChecklistItemModel> editableItems = session.checklistItems
            .map((item) => CustomsChecklistItemModel(
                  itemId: item.itemId,
                  consultationId: item.consultationId,
                  documentType: item.documentType,
                  hsCode: item.hsCode,
                  isRequired: item.isRequired,
                  isBlockingShipment: item.isBlockingShipment,
                  responsibleParty: item.responsibleParty,
                  regulatoryAgency: item.regulatoryAgency,
                  status: item.status,
                  remarks: item.remarks,
                ))
            .toList();

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final approvedCount = editableItems.where((i) => i.status == 'Approved' || i.status == 'Verified').length;
            final totalCount = editableItems.length;
            final blockingCount = editableItems.where((i) => i.isBlockingShipment && i.status != 'Approved' && i.status != 'Verified').length;
            final readinessPct = totalCount > 0 ? (approvedCount / totalCount * 100) : 0.0;

            return SelectionArea(
              child: AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.assignment_turned_in, color: AppTheme.cobalt),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEditing
                            ? l.shipmentUpdateConsultDialogEditTitle(session.consultationCode)
                            : l.shipmentUpdateConsultDialogViewTitle(session.consultationCode),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.print_rounded, color: AppTheme.charcoal),
                      tooltip: l.shipmentUpdateConsultPrintTooltip,
                      onPressed: () {
                        Printing.layoutPdf(
                          onLayout: (format) =>
                              CustomsConsultationPdfService.generateConsultationPdf(session),
                          name: 'Customs_Consultation_${session.consultationCode}',
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(isEditing ? Icons.visibility_rounded : Icons.edit_rounded,
                          color: isEditing ? AppTheme.cobalt : AppTheme.orange),
                      tooltip: isEditing ? l.shipmentUpdateConsultSwitchViewTooltip : l.shipmentUpdateConsultSwitchEditTooltip,
                      onPressed: () => setDialogState(() => isEditing = !isEditing),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 850,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(session.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isEditing ? Colors.amber.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isEditing ? Colors.orange.shade300 : Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l.shipmentUpdateConsultBrokerPrefix(session.brokerName), style: const TextStyle(fontSize: 12)),
                              Text(l.shipmentUpdateConsultEstDuties(session.estimatedDutiesEgp.toStringAsFixed(2)),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson, fontSize: 12)),
                              if (isEditing)
                                Row(
                                  children: [
                                    Text(l.shipmentUpdateConsultOverallStatusLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    DropdownButton<String>(
                                      value: selectedStatus,
                                      isDense: true,
                                      items: [
                                        DropdownMenuItem(value: 'In Progress', child: Text(l.shipmentUpdateConsultStatusInProgress)),
                                        DropdownMenuItem(value: 'Clearance Ready', child: Text(l.shipmentUpdateConsultStatusClearanceReady)),
                                        DropdownMenuItem(value: 'Blocked', child: Text(l.shipmentUpdateConsultStatusBlocked)),
                                        DropdownMenuItem(value: 'Action Required', child: Text(l.shipmentUpdateConsultStatusActionRequired)),
                                        DropdownMenuItem(value: 'Completed', child: Text(l.shipmentUpdateConsultStatusCompleted)),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() => selectedStatus = val);
                                        }
                                      },
                                    ),
                                  ],
                                )
                              else
                                Text(l.shipmentUpdateConsultStatus(_getCustomsStatusLabel(l, session.overallStatus)), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Metrics Summary
                        Row(
                          children: [
                            _buildMetricBadge(l.shipmentUpdateConsultReadinessRateLabel, '${readinessPct.toStringAsFixed(0)}%', readinessPct >= 80 ? Colors.green : Colors.blue),
                            const SizedBox(width: 8),
                            _buildMetricBadge(l.shipmentUpdateConsultTotalDocsLabel, '$totalCount', Colors.grey),
                            const SizedBox(width: 8),
                            _buildMetricBadge(l.shipmentUpdateConsultApprovedLabel, '$approvedCount', Colors.green),
                            const SizedBox(width: 8),
                            _buildMetricBadge(l.shipmentUpdateConsultBlockingLabel, '$blockingCount', blockingCount > 0 ? Colors.red : Colors.green),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Text(l.shipmentUpdateConsultChecklistSectionTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const Spacer(),
                            if (isEditing)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(l.shipmentUpdateConsultEditModeBanner,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Checklist Table
                        Table(
                          border: TableBorder.all(color: Colors.grey.shade300),
                          columnWidths: const {
                            0: FlexColumnWidth(2.8),
                            1: FlexColumnWidth(1.2),
                            2: FlexColumnWidth(1.4),
                            3: FlexColumnWidth(2.2),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: AppTheme.charcoal.withOpacity(0.08)),
                              children: [
                                Padding(padding: const EdgeInsets.all(8), child: Text(l.shipmentUpdateConsultColDocType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Padding(padding: const EdgeInsets.all(8), child: Text(l.shipmentUpdateConsultColResponsibleParty, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Padding(padding: const EdgeInsets.all(8), child: Text(l.shipmentUpdateConsultColStatus, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Padding(padding: const EdgeInsets.all(8), child: Text(l.shipmentUpdateConsultColRemarks, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              ],
                            ),
                            ...editableItems.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final doc = entry.value;

                              return TableRow(
                                decoration: BoxDecoration(
                                  color: idx % 2 == 1 ? Colors.grey.shade50 : Colors.white,
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Builder(
                                          builder: (context) {
                                            final statusLower = doc.status.toLowerCase();
                                            final isApproved = statusLower == 'approved' ||
                                                statusLower == 'verified' ||
                                                statusLower == 'completed' ||
                                                statusLower == 'received' ||
                                                statusLower == 'obtained' ||
                                                statusLower.contains('معتمد') ||
                                                statusLower.contains('مستوفى');
                                            final isRejected = statusLower == 'rejected' ||
                                                statusLower.contains('مرفوض');
                                            final isBlocking = doc.isBlockingShipment && !isApproved;

                                            return Row(
                                              children: [
                                                if (isApproved)
                                                  const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 14)
                                                else if (isRejected)
                                                  const Icon(Icons.cancel_rounded, color: AppTheme.crimson, size: 14)
                                                else if (isBlocking)
                                                  Tooltip(
                                                    message: l.shipmentUpdateConsultBlockingTooltip,
                                                    child: const Icon(Icons.block, color: Colors.red, size: 14),
                                                  )
                                                else
                                                  const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 14),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    doc.documentType,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 11.5,
                                                      color: isBlocking ? Colors.red.shade900 : AppTheme.charcoal,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        if (doc.hsCode != null && doc.hsCode!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(l.shipmentUpdateConsultHsCodesPrefix(doc.hsCode!),
                                                style: const TextStyle(fontSize: 10, color: AppTheme.cobalt, fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(doc.responsibleParty, style: const TextStyle(fontSize: 11)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: isEditing
                                        ? DropdownButton<String>(
                                            value: doc.status,
                                            isDense: true,
                                            style: const TextStyle(fontSize: 11, color: AppTheme.charcoal, fontWeight: FontWeight.bold),
                                            items: [
                                              DropdownMenuItem(value: 'Approved', child: Text('🟢 ${l.shipmentUpdateDocStatusApproved}')),
                                              DropdownMenuItem(value: 'Pending', child: Text('🟠 ${l.shipmentUpdateDocStatusPending}')),
                                              DropdownMenuItem(value: 'Received', child: Text('🔵 ${l.shipmentUpdateDocStatusReceived}')),
                                              DropdownMenuItem(value: 'Verified', child: Text('🟣 ${l.shipmentUpdateDocStatusVerified}')),
                                              DropdownMenuItem(value: 'Rejected', child: Text('🔴 ${l.shipmentUpdateDocStatusRejected}')),
                                            ],
                                            onChanged: (newSt) {
                                              if (newSt != null) {
                                                setDialogState(() {
                                                  editableItems[idx] = CustomsChecklistItemModel(
                                                    itemId: doc.itemId,
                                                    consultationId: doc.consultationId,
                                                    documentType: doc.documentType,
                                                    hsCode: doc.hsCode,
                                                    isRequired: doc.isRequired,
                                                    isBlockingShipment: doc.isBlockingShipment,
                                                    responsibleParty: doc.responsibleParty,
                                                    regulatoryAgency: doc.regulatoryAgency,
                                                    status: newSt,
                                                    remarks: doc.remarks,
                                                  );
                                                });
                                              }
                                            },
                                          )
                                        : _buildDocItemStatusBadge(l, doc.status),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(doc.remarks ?? '-', style: const TextStyle(fontSize: 11)),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.charcoal),
                    onPressed: () {
                      Printing.layoutPdf(
                        onLayout: (format) =>
                            CustomsConsultationPdfService.generateConsultationPdf(session),
                        name: 'Customs_Consultation_${session.consultationCode}',
                      );
                    },
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: Text(l.shipmentUpdateBtnPrintPdf),
                  ),
                  if (isEditing)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                      onPressed: isSaving
                          ? null
                          : () async {
                              setDialogState(() => isSaving = true);
                              try {
                                final payload = {
                                  'overall_status': selectedStatus,
                                  'checklist_items': editableItems.map((item) => item.toJson()).toList(),
                                };
                                await ref
                                    .read(customsConsultationsProvider.notifier)
                                    .updateConsultation(session.consultationId, payload);
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l.shipmentUpdateConsultSaveSuccess(session.consultationCode)),
                                      backgroundColor: AppTheme.emerald,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setDialogState(() => isSaving = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(l.shipmentUpdateConsultSaveError(e.toString())), backgroundColor: AppTheme.crimson),
                                  );
                                }
                              }
                            },
                      icon: isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save, color: Colors.white, size: 16),
                      label: Text(
                        isSaving ? l.shipmentUpdateConsultSavingBtn : l.shipmentUpdateConsultSaveBtn,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(l.shipmentUpdateConsultCloseBtn),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetricBadge(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _getCustomsStatusLabel(AppLocalizations l, String status) {
    switch (status) {
      case 'In Progress':
        return l.shipmentUpdateConsultStatusInProgress;
      case 'Clearance Ready':
        return l.shipmentUpdateConsultStatusClearanceReady;
      case 'Blocked':
        return l.shipmentUpdateConsultStatusBlocked;
      case 'Action Required':
        return l.shipmentUpdateConsultStatusActionRequired;
      case 'Completed':
        return l.shipmentUpdateConsultStatusCompleted;
      default:
        return status;
    }
  }

  String _getDocItemStatusLabel(AppLocalizations l, String status) {
    switch (status) {
      case 'Approved':
        return l.shipmentUpdateDocStatusApproved;
      case 'Pending':
        return l.shipmentUpdateDocStatusPending;
      case 'Received':
        return l.shipmentUpdateDocStatusReceived;
      case 'Verified':
        return l.shipmentUpdateDocStatusVerified;
      case 'Rejected':
        return l.shipmentUpdateDocStatusRejected;
      default:
        return status;
    }
  }

  Widget _buildCustomsStatusBadge(AppLocalizations l, String status) {
    Color bg = Colors.grey;
    if (status == 'Clearance Ready') bg = Colors.green;
    if (status == 'Blocked') bg = Colors.red;
    if (status == 'Action Required') bg = Colors.orange;
    if (status == 'In Progress') bg = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(_getCustomsStatusLabel(l, status), style: TextStyle(color: bg, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _buildDocItemStatusBadge(AppLocalizations l, String status) {
    Color bg = Colors.grey;
    if (status == 'Approved') bg = Colors.green;
    if (status == 'Rejected') bg = Colors.red;
    if (status == 'Verified') bg = Colors.blue;
    if (status == 'Received') bg = Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(_getDocItemStatusLabel(l, status), style: TextStyle(color: bg, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}
