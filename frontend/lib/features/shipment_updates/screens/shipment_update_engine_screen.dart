import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_consultation/models/customs_consultation_model.dart';
import '../../customs_consultation/providers/customs_consultation_provider.dart';
import '../../customs_consultation/services/customs_consultation_pdf_service.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/shipment_update_model.dart';
import '../providers/shipment_updates_provider.dart';
import '../widgets/engine/su_logs_table_card.dart';
import '../widgets/engine/su_metrics_strip.dart';
import '../widgets/engine/su_pipeline_card.dart';
import '../widgets/engine/su_selector_card.dart';
import '../widgets/shipment_update_dialog.dart';
import '../widgets/su_consultation_dialog.dart';
import '../widgets/su_customs_section.dart';

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

  Future<void> _confirmDeleteLog(ShipmentUpdateLogModel log) async {
    final l = context.l10n;
    final confirm = await AppConfirmDialog.showDelete(
      context,
      title: l.shipmentUpdateDeleteConfirmTitle,
      message: l.shipmentUpdateDeleteConfirmMsg(log.updateCode),
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

  void _printConsultation(CustomsConsultationModel c) {
    Printing.layoutPdf(
      onLayout: (format) => CustomsConsultationPdfService.generateConsultationPdf(c),
      name: 'Customs_Consultation_${c.consultationCode}',
    );
  }

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
                SuMetricsStrip(l10n: l, updatesState: updatesState, totalPhases: _phaseCodes.length),
                const SizedBox(height: 12),
              ],
              SuSelectorCard(
                l10n: l,
                isAr: _isAr,
                importFilesState: importFilesState,
                updatesState: updatesState,
                selectedFileId: _selectedFileId,
                selectedFile: _selectedFile,
                onShipmentSelected: (val) {
                  final files = importFilesState.value ?? [];
                  _onShipmentSelected(val, files);
                },
                onReload: _reload,
                onOpenDailyCheckin: () => _openDailyCheckin(),
                onCopyTsv: _copyShipmentUpdatesTsv,
              ),
              const SizedBox(height: 16),
              if (_selectedFile != null) ...[
                SuPipelineCard(
                  l10n: l,
                  isAr: _isAr,
                  file: _selectedFile!,
                  selectedFileCode: _selectedFileCode,
                  updatesState: updatesState,
                  phaseCodes: _phaseCodes,
                  getPhaseName: _getPhaseName,
                  getStatusName: _getStatusName,
                ),
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
              SuLogsTableCard(
                l10n: l,
                isAr: _isAr,
                updatesState: updatesState,
                onReload: _reload,
                onDeleteLog: _confirmDeleteLog,
                getPhaseName: _getPhaseName,
                getStatusName: _getStatusName,
                getCategoryLabel: _getCategoryLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
