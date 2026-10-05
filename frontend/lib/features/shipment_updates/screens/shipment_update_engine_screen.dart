import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/master_data_toolbar.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../customs_consultation/models/customs_consultation_model.dart';
import '../../customs_consultation/providers/customs_consultation_provider.dart';
import '../../customs_consultation/services/customs_consultation_pdf_service.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/shipment_update_model.dart';
import '../providers/shipment_updates_provider.dart';
import '../widgets/shipment_update_dialog.dart';
import '../widgets/su_consultation_dialog.dart';
import '../widgets/su_customs_section.dart';
import '../widgets/su_ui.dart';

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

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  String get _selectedFileCode => _selectedFile?.customFileNumber ?? _selectedFile?.importFileCode ?? '';

  String _getPhaseName(AppLocalizations l, String phaseCode) {
    return DisplayNameResolver.resolvePhaseName(phaseCode, isArabic: _isAr);
  }

  String _getStatusName(AppLocalizations l, String status) {
    switch (status) {
      case 'Completed':
        return l.shipmentUpdateStatusCompleted;
      case 'Current':
        return l.shipmentUpdateStatusCurrent;
      case 'Future':
        return l.shipmentUpdateStatusFuture;
      default:
        return status;
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
        AppTheme.snackBar(context, l.shipmentUpdateLogsEmptyMessage, severity: AppSeverity.info),
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

  void _reload() {
    ref.read(importFilesProvider.notifier).fetchImportFiles();
    if (_selectedFileId != null) {
      ref.read(shipmentUpdatesProvider.notifier).fetchLogs(importFileId: _selectedFileId);
    }
  }

  void _openDailyCheckin({String? phase}) {
    final file = _selectedFile;
    if (file == null) return;
    ShipmentUpdateDialog.show(
      context,
      initialFileId: file.importFileId,
      initialFileCode: _selectedFileCode,
      initialTargetPhase: phase ?? file.currentModule,
      defaultCategory: 'Daily Check-in',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final importFilesState = ref.watch(importFilesProvider);
    final updatesState = ref.watch(shipmentUpdatesProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceAltOf(context),
      appBar: PageHeader(
        icon: Icons.published_with_changes,
        iconColor: AppTheme.cobalt,
        title: l.shipmentUpdateEngineTitle,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.white, size: density.buttonIconSize),
            tooltip: l.shipmentUpdateRefreshTooltip,
            onPressed: _reload,
          ),
          const BackToDashboardButton(),
          const SizedBox(width: 12),
        ],
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_selectedFile != null && !updatesState.isLoading && updatesState.error == null) ...[
                _buildMetrics(l, updatesState),
                const SizedBox(height: 12),
              ],
              _buildSelectorCard(l, importFilesState, updatesState),
              const SizedBox(height: 16),
              if (_selectedFile != null) ...[
                _buildPipelineCard(l, updatesState),
                const SizedBox(height: 16),
                SuCustomsSection(
                  consultations: (ref.watch(customsConsultationsProvider).value ?? [])
                      .where((c) =>
                          (c.importFileId != null && c.importFileId == _selectedFileId) ||
                          (c.importFileCode != null && c.importFileCode == _selectedFileCode) ||
                          (c.importFileCode != null && c.importFileCode == _selectedFile!.importFileCode))
                      .toList(),
                  onPrint: _printConsultation,
                  onSavePdf: _saveConsultationPdf,
                  onView: (c) => _showConsultationDetailsDialog(c, initialEditMode: false),
                  onEdit: (c) => _showConsultationDetailsDialog(c, initialEditMode: true),
                  onRecordDaily: () => _openDailyCheckin(phase: 'Phase 6'),
                ),
                const SizedBox(height: 16),
              ],
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
              _buildLogsCard(l, updatesState),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Metric strip (loaded values only)
  // ---------------------------------------------------------------------------
  Widget _buildMetrics(AppLocalizations l, ShipmentUpdatesState state) {
    final logs = state.logs;
    final daily = logs.where((x) => x.updateCategory == 'Daily Check-in').length;
    final costAdj = logs.where((x) => x.updateCategory == 'Phase Cost Adjustment').length;
    final completed = state.inspectedPhases.where((p) => p.status == 'Completed').length;
    return CcUi.metrics([
      MetricCardData(
        title: l.suMetricTotalUpdates,
        value: '${logs.length}',
        icon: Icons.history_rounded,
        color: AppTheme.cobalt,
      ),
      MetricCardData(
        title: l.shipmentUpdateBadgeDaily,
        value: '$daily',
        icon: Icons.today,
        color: AppTheme.emerald,
      ),
      MetricCardData(
        title: l.shipmentUpdateBadgeCostAdj,
        value: '$costAdj',
        icon: Icons.price_change_outlined,
        color: AppTheme.orange,
      ),
      MetricCardData(
        title: l.suMetricCompletedPhases,
        value: '$completed/${_phaseCodes.length}',
        icon: Icons.check_circle_outline,
        color: AppTheme.charcoal,
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Shipment selector + actions
  // ---------------------------------------------------------------------------
  Widget _buildSelectorCard(
    AppLocalizations l,
    AsyncValue<List<ImportFileModel>> importFilesState,
    ShipmentUpdatesState updatesState,
  ) {
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: AppTheme.cardDecorationOf(context),
      child: importFilesState.when(
        loading: () => const LinearProgressIndicator(),
        error: (err, _) => CcStateView.error(
          message: l.shipmentUpdateErrorLoadingShipments(ApiErrorText.of(l, err)),
          actionLabel: l.retry,
          onAction: _reload,
        ),
        data: (files) {
          if (files.isEmpty) {
            return CcStateView.empty(
              message: l.shipmentUpdateNoShipmentsRegistered,
              icon: Icons.local_shipping_outlined,
            );
          }
          final logs = updatesState.logs;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchableDropdownField<int>(
                value: _selectedFileId,
                labelText: l.shipmentUpdateSelectShipmentPrompt,
                items: files.map((f) {
                  final sTitle = DisplayNameResolver.resolveShipmentTitle(f, isArabic: _isAr);
                  final pTitle = DisplayNameResolver.resolvePhaseName(f.currentModule, isArabic: _isAr);
                  return SearchableDropdownItem<int>(
                    value: f.importFileId,
                    label: '$sTitle - ${f.supplierName} ($pTitle)',
                  );
                }).toList(),
                onChanged: (val) => _onShipmentSelected(val, files),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CcUi.fit(AppButton(
                    label: l.shipmentUpdateComprehensiveDailyCheckinBtn,
                    icon: Icons.today,
                    onPressed: _selectedFile == null ? null : () => _openDailyCheckin(),
                  )),
                  CcUi.fit(AppButton(
                    label: l.shipmentUpdatesExportTsvBtn,
                    icon: Icons.copy_all_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: logs.isEmpty ? null : () => _copyShipmentUpdatesTsv(logs),
                  )),
                  CcUi.fit(AppButton(
                    label: l.shipmentUpdatesExportExcelBtn,
                    icon: Icons.table_view_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: logs.isEmpty
                        ? null
                        : () => MasterDataExportService.exportShipmentUpdatesToExcel(
                              context,
                              logs,
                              shipmentCode: _selectedFile?.customFileNumber ?? _selectedFile?.importFileCode,
                              isAr: _isAr,
                            ),
                  )),
                  CcUi.fit(AppButton(
                    label: l.shipmentUpdatesExportPdfBtn,
                    icon: Icons.print_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: logs.isEmpty
                        ? null
                        : () => MasterDataExportService.printOrSaveShipmentUpdatesListPdf(
                              context,
                              logs,
                              shipmentCode: _selectedFile?.customFileNumber ?? _selectedFile?.importFileCode,
                              isAr: _isAr,
                            ),
                  )),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 10-phase pipeline
  // ---------------------------------------------------------------------------
  Widget _buildPipelineCard(AppLocalizations l, ShipmentUpdatesState updatesState) {
    final file = _selectedFile!;
    return CcSectionCard(
      title: DisplayNameResolver.resolveShipmentName(file, isArabic: _isAr),
      icon: Icons.hub,
      margin: EdgeInsets.zero,
      trailing: CcStatusChip(
        label: DisplayNameResolver.resolvePhaseName(file.currentModule, isArabic: _isAr),
        severity: AppSeverity.success,
        icon: Icons.flag_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SuCodeBadge(code: _selectedFileCode, copiedMessage: l.shipmentUpdateCodeBadgeLabel, fontSize: 11),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _phaseCodes.map((pCode) {
                final pName = _getPhaseName(l, pCode);
                final insp = updatesState.inspectedPhases.firstWhere(
                  (ip) => ip.phaseCode == pCode,
                  orElse: () => PhaseInspectionModel(
                    phaseCode: pCode,
                    phaseName: pName,
                    phaseNumber: 1,
                    status: 'Future',
                    updateCount: 0,
                  ),
                );
                return SuPhaseTile(
                  name: pName,
                  status: insp.status,
                  statusLabel: _getStatusName(l, insp.status),
                  countLabel: l.shipmentUpdateCountBadge(insp.updateCount),
                  onTap: () => ShipmentUpdateDialog.show(
                    context,
                    initialFileId: file.importFileId,
                    initialFileCode: _selectedFileCode,
                    initialTargetPhase: pCode,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Update logs table
  // ---------------------------------------------------------------------------
  Widget _buildLogsCard(AppLocalizations l, ShipmentUpdatesState updatesState) {
    final Widget content;
    if (updatesState.isLoading) {
      content = const SizedBox(height: 160, child: CcStateView.loading());
    } else if (updatesState.error != null) {
      content = CcStateView.error(
        message: l.shipmentUpdateLogsFetchError(updatesState.error.toString()),
        actionLabel: l.retry,
        onAction: _reload,
      );
    } else if (updatesState.logs.isEmpty) {
      content = CcStateView.empty(message: l.shipmentUpdateLogsEmptyMessage, icon: Icons.history_toggle_off_rounded);
    } else {
      content = _buildLogsTable(l, updatesState.logs);
    }
    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _buildLogsTable(AppLocalizations l, List<ShipmentUpdateLogModel> logs) {
    TextStyle head() => const TextStyle(fontWeight: FontWeight.bold);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: const WidgetStatePropertyAll(AppTheme.charcoalSurface),
        columns: [
          DataColumn(label: Text(l.shipmentUpdateColActions, style: head())),
          DataColumn(label: Text(l.shipmentUpdateColCode, style: head())),
          DataColumn(label: Text(l.shipmentUpdateColDate, style: head())),
          DataColumn(label: Text(l.shipmentUpdateColType, style: head())),
          DataColumn(label: Text(l.shipmentUpdateColTargetStage, style: head())),
          DataColumn(label: Text(l.shipmentUpdateColNotes, style: head())),
          DataColumn(label: Text(l.shipmentUpdateColCostAdjustment, style: head())),
          DataColumn(label: Text(l.shipmentUpdateColAssignedUser, style: head())),
        ],
        rows: logs.map((log) => _buildLogRow(l, log)).toList(),
      ),
    );
  }

  DataRow _buildLogRow(AppLocalizations l, ShipmentUpdateLogModel log) {
    final isCostAdj = log.updateCategory == 'Phase Cost Adjustment';
    final rowSummary = _buildRowSummary(log);
    final categoryLabel = _getCategoryLabel(l, log.updateCategory);
    final costText =
        '${log.adjustedCostItem ?? l.shipmentUpdateCostLabel}: ${log.previousCost} -> ${log.newCost} ${l.shipmentUpdateCostCurrencyUsd}';

    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RowActionsPill(
                onView: () => _showLogViewDialog(l, log),
                onEdit: () {
                  ShipmentUpdateDialog.show(
                    context,
                    initialFileId: log.importFileId,
                    initialTargetPhase: log.targetPhase,
                    defaultCategory: log.updateCategory,
                  );
                },
                onPrint: () => MasterDataExportService.printOrSaveShipmentUpdateSlipPdf(log, isAr: _isAr),
                onDelete: () => _confirmDelete(l, log),
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
            child: SuCodeBadge(code: log.updateCode, copiedMessage: l.shipmentUpdateCodeBadgeLabel, fontSize: 12),
          ),
        ),
        DataCell(
          CopyableTableCell(
            value: log.logDate,
            rowSummary: rowSummary,
            child: LtrText(log.logDate),
          ),
        ),
        DataCell(
          CopyableTableCell(
            value: categoryLabel,
            rowSummary: rowSummary,
            child: CcStatusChip(label: categoryLabel, severity: SuUi.categorySeverity(log.updateCategory)),
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
            value: isCostAdj ? costText : '-',
            rowSummary: rowSummary,
            child: isCostAdj
                ? Text(
                    costText,
                    textDirection: TextDirection.ltr,
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
  }

  void _showLogViewDialog(AppLocalizations l, ShipmentUpdateLogModel log) {
    showDialog(
      context: context,
      builder: (c) => SelectionArea(
        child: CcStageDialogShell(
          title: l.shipmentUpdateViewDialogTitle(log.updateCode),
          icon: Icons.visibility_rounded,
          maxWidth: 560,
          chips: [CcHeaderChip(Icons.confirmation_number_outlined, log.updateCode, ltr: true)],
          showCancel: false,
          confirmLabel: l.shipmentUpdateViewCloseBtn,
          confirmIcon: Icons.close,
          confirmVariant: AppButtonVariant.secondary,
          isSubmitting: false,
          onConfirm: () => Navigator.pop(c),
          body: CcFormSection(
            title: l.shipmentUpdateViewDialogTitle(log.updateCode),
            icon: Icons.notes_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.shipmentUpdateViewStage(_getPhaseName(l, log.targetPhase)),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(l.shipmentUpdateViewDate(log.logDate)),
                const SizedBox(height: 4),
                Text(l.shipmentUpdateViewUser(log.assignedUser)),
                const SizedBox(height: 10),
                Text('${l.shipmentUpdateViewNotes}\n${log.note}'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(AppLocalizations l, ShipmentUpdateLogModel log) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => SelectionArea(
        child: AlertDialog(
          title: Text(l.shipmentUpdateDeleteConfirmTitle),
          content: Text(l.shipmentUpdateDeleteConfirmMsg(log.updateCode)),
          actions: [
            AppButton(
              label: l.shipmentUpdateDeleteCancelBtn,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(c, false),
            ),
            AppButton(
              label: l.shipmentUpdateDeleteConfirmBtn,
              icon: Icons.delete_outline,
              variant: AppButtonVariant.danger,
              onPressed: () => Navigator.pop(c, true),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(shipmentUpdatesProvider.notifier).deleteLog(log.updateId);
      ref.invalidate(importFilesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, ApiErrorText.of(l, e), severity: AppSeverity.danger),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Customs consultation actions
  // ---------------------------------------------------------------------------
  void _printConsultation(CustomsConsultationModel c) {
    Printing.layoutPdf(
      onLayout: (format) => CustomsConsultationPdfService.generateConsultationPdf(c),
      name: 'Customs_Consultation_${c.consultationCode}',
    );
  }

  /// Saves the consultation PDF through the shared Save-As flow
  /// (`[Stage Name] - [File code].pdf`). Printing stays a separate action.
  Future<void> _saveConsultationPdf(CustomsConsultationModel c) async {
    final l = context.l10n;
    try {
      final bytes = await CustomsConsultationPdfService.generateConsultationPdf(c);
      if (!mounted) return;
      await FileSaveHelper.exportAndSaveFile(
        context: context,
        bytes: bytes,
        stageName: l.shipmentUpdateStageNameCustomsConsultation,
        importFileNameOrCode: _selectedFile?.customFileNumber ?? _selectedFile?.importFileCode ?? c.consultationCode,
        extension: 'pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, ApiErrorText.of(l, e), severity: AppSeverity.danger),
      );
    }
  }

  void _showConsultationDetailsDialog(CustomsConsultationModel session, {bool initialEditMode = false}) {
    SuConsultationDetailsDialog.show(
      context,
      session: session,
      initialEditMode: initialEditMode,
      onPrint: () => _printConsultation(session),
      onSavePdf: () => _saveConsultationPdf(session),
    );
  }
}
