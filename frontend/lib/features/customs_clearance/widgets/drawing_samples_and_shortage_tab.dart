import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/import_file_picker_dialog.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/metric_card.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/customs_clearance_model.dart';
import '../services/drawing_samples_export_service.dart';
import 'customs_inspection_sampling_dialog.dart';
import 'customs_ui.dart';

/// Screen 60: Customs Clearance - Drawing Samples & Shortage Tracking SubTab.
class DrawingSamplesAndShortageTab extends ConsumerStatefulWidget {
  final List<CustomsClearanceModel> records;
  final VoidCallback? onRefresh;

  const DrawingSamplesAndShortageTab({
    super.key,
    required this.records,
    this.onRefresh,
  });

  @override
  ConsumerState<DrawingSamplesAndShortageTab> createState() => _DrawingSamplesAndShortageTabState();
}

class _DrawingSamplesAndShortageTabState extends ConsumerState<DrawingSamplesAndShortageTab> {
  final TextEditingController _samplesSearchController = TextEditingController();
  String _sampleStatusFilter = 'ALL'; // ALL, PASSED, PENDING, REJECTED

  @override
  void dispose() {
    _samplesSearchController.dispose();
    super.dispose();
  }

  String _resolveFileCode(List<ImportFileModel> allFiles, int importFileId) {
    final match = allFiles.cast<ImportFileModel?>().firstWhere(
          (f) => f?.importFileId == importFileId,
          orElse: () => null,
        );
    return match?.importFileCode ?? '—';
  }

  List<CustomsClearanceModel> _getFilteredSamples(List<ImportFileModel> allFiles, AppLocalizations l) {
    final drawn = widget.records.where((r) => r.hasActuallyDrawnSample).toList();

    return drawn.where((s) {
      if (_sampleStatusFilter == 'PASSED') {
        final isPassed = s.sampleTestStatus == 'Approved' || s.labTestResult == 'CONFORMING';
        if (!isPassed) return false;
      } else if (_sampleStatusFilter == 'PENDING') {
        final isPending = s.sampleTestStatus == 'Samples Under Testing' || s.labTestResult == 'PENDING';
        if (!isPending) return false;
      } else if (_sampleStatusFilter == 'REJECTED') {
        final isRejected = s.sampleTestStatus == 'Rejected' || s.labTestResult == 'NON_CONFORMING';
        if (!isRejected) return false;
      }

      final q = _samplesSearchController.text.trim().toLowerCase();
      if (q.isEmpty) return true;

      final recordNo = (s.samplingRecordNo ?? '').toLowerCase();
      final fileCode = _resolveFileCode(allFiles, s.importFileId).toLowerCase();
      final certNo = (s.goeicCertificateNo ?? '').toLowerCase();
      final status = s.sampleTestStatus.toLowerCase();
      final labResult = s.labTestResult.toLowerCase();
      final notes = (s.inspectionNotes ?? '').toLowerCase();
      final bodies = s.sampledRegulatoryBodies
          .map((b) => DomainEnums.label(l, DomainEnumType.regulatoryBody, b).toLowerCase())
          .join(' ');

      return recordNo.contains(q) ||
          fileCode.contains(q) ||
          certNo.contains(q) ||
          status.contains(q) ||
          labResult.contains(q) ||
          notes.contains(q) ||
          bodies.contains(q);
    }).toList();
  }

  Future<void> _addSample() async {
    final l = context.l10n;
    final pickedFile = await showImportFilePickerDialog(
      context,
      ref,
      title: l.customsClearanceAddSampleDialogTitle,
    );
    if (pickedFile == null || !mounted) return;

    final activeRecord = widget.records.cast<CustomsClearanceModel?>().firstWhere(
          (r) => r?.importFileId == pickedFile.importFileId,
          orElse: () => null,
        );

    final saved = await CustomsInspectionSamplingDialog.show(
      context,
      pickedFile,
      clearanceRecord: activeRecord,
    );

    if (saved == true && mounted && widget.onRefresh != null) {
      widget.onRefresh!();
    }
  }

  /// Copyable code pill (LTR) used for sample / receipt / container codes.
  Widget _codeBadge(String text, AppSeverity severity, {bool isMonospace = false}) {
    final l = context.l10n;
    final fg = AppTheme.severityForegroundOf(context, severity);
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      onTap: () => CopyHelper.copy(context, text, customMessage: l.drawingSamplesCopyFieldTooltip),
      child: Tooltip(
        message: l.drawingSamplesCopyFieldTooltip,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.severityBackgroundOf(context, severity),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: fg.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LtrText(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: fg,
                  fontFamily: isMonospace ? 'monospace' : null,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.copy_rounded, size: 12, color: fg.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }

  DataColumn _col(String label, {bool numeric = false}) => DataColumn(
        numeric: numeric,
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final allFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final allDrawnSamples = widget.records.where((r) => r.hasActuallyDrawnSample).toList();

    final totalSamples = allDrawnSamples.length;
    final passedSamples = allDrawnSamples
        .where((s) => s.sampleTestStatus == 'Approved' || s.labTestResult == 'CONFORMING')
        .length;
    final pendingSamples = allDrawnSamples
        .where((s) => s.sampleTestStatus == 'Samples Under Testing' || s.labTestResult == 'PENDING')
        .length;

    final metrics = [
      MetricCardData(
        title: l.drawingSamplesKpiTotalSamples,
        value: '$totalSamples',
        icon: Icons.science_outlined,
        color: AppTheme.cobalt,
      ),
      MetricCardData(
        title: l.drawingSamplesKpiPassedSamples,
        value: '$passedSamples',
        icon: Icons.check_circle_outline,
        color: AppTheme.emerald,
      ),
      MetricCardData(
        title: l.drawingSamplesKpiPendingSamples,
        value: '$pendingSamples',
        icon: Icons.hourglass_top_outlined,
        color: AppTheme.orange,
      ),
    ];

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(l, allFiles, allDrawnSamples),
            CcUi.metrics(metrics),
            const SizedBox(height: 16),
            _buildSamplesCard(l, allFiles),
            const SizedBox(height: 16),
            _buildShortageCard(l),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    AppLocalizations l,
    List<ImportFileModel> allFiles,
    List<CustomsClearanceModel> drawnSamples,
  ) {
    return CcSectionCard(
      title: l.drawingSamplesScreenTitle,
      icon: Icons.science,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.drawingSamplesScreenSubtitle,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppButton(
                label: l.drawingSamplesExportTsvBtn,
                icon: Icons.copy_all_outlined,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => DrawingSamplesExportService.saveSamplesTsvToFile(
                  context,
                  drawnSamples,
                  fileCodeResolver: (id) => _resolveFileCode(allFiles, id),
                ),
              ),
              AppButton(
                label: l.drawingSamplesExportExcelBtn,
                icon: Icons.file_download_outlined,
                variant: AppButtonVariant.success,
                size: AppButtonSize.small,
                onPressed: () => DrawingSamplesExportService.saveSamplesCsvToFile(
                  context,
                  drawnSamples,
                  fileCodeResolver: (id) => _resolveFileCode(allFiles, id),
                ),
              ),
              AppButton(
                label: l.drawingSamplesPrintPdfBtn,
                icon: Icons.picture_as_pdf_outlined,
                variant: AppButtonVariant.danger,
                size: AppButtonSize.small,
                onPressed: () => DrawingSamplesExportService.printOrSaveDrawingSamplesPdf(
                  context: context,
                  samples: drawnSamples,
                  shortages: const [],
                  fileCodeResolver: (id) => _resolveFileCode(allFiles, id),
                ),
              ),
              AppButton(
                label: l.drawingSamplesCopyDossierBtn,
                icon: Icons.assignment_outlined,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
                onPressed: () => DrawingSamplesExportService.copyDossierToClipboard(
                  context: context,
                  samples: drawnSamples,
                  shortages: const [],
                  fileCodeResolver: (id) => _resolveFileCode(allFiles, id),
                ),
              ),
              if (widget.onRefresh != null)
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.cobalt, size: 20),
                  tooltip: l.customsDeclRefreshTooltip,
                  onPressed: widget.onRefresh,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSamplesCard(AppLocalizations l, List<ImportFileModel> allFiles) {
    final filteredSamples = _getFilteredSamples(allFiles, l);

    return CcSectionCard(
      title: l.drawingSamplesTabDrawnSamples,
      icon: Icons.biotech,
      margin: EdgeInsets.zero,
      trailing: AppButton(
        label: l.customsClearanceAddSampleButton,
        icon: Icons.add,
        size: AppButtonSize.small,
        onPressed: _addSample,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 340,
                child: TextField(
                  controller: _samplesSearchController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: l.drawingSamplesSearchHint,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    suffixIconConstraints: const BoxConstraints(minWidth: 64, maxHeight: 36),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_samplesSearchController.text.isNotEmpty)
                          IconButton(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _samplesSearchController.clear();
                              setState(() {});
                            },
                          ),
                        IconButton(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l.drawingSamplesCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, _samplesSearchController.text),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ),
                    contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'ALL',
                    label: Text(l.drawingSamplesFilterAll, style: const TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: 'PASSED',
                    label: Text(l.drawingSamplesFilterPassed, style: const TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: 'PENDING',
                    label: Text(l.drawingSamplesFilterPending, style: const TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: 'REJECTED',
                    label: Text(l.sampleFilterRejected, style: const TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {_sampleStatusFilter},
                onSelectionChanged: (set) => setState(() => _sampleStatusFilter = set.first),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (filteredSamples.isEmpty)
            SizedBox(
              height: 150,
              child: CcStateView.empty(message: l.drawingSamplesEmptySamples, icon: Icons.science_outlined),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAltOf(context)),
                columns: [
                  _col(l.drawingSamplesColSampleCode),
                  _col(l.drawingSamplesColFileCode),
                  _col(l.drawingSamplesColSampledBodies),
                  _col(l.drawingSamplesColSamplingDate),
                  _col(l.drawingSamplesColGoeicCert),
                  _col(l.drawingSamplesColTestStatus),
                  _col(l.drawingSamplesColLabResult),
                  _col(l.drawingSamplesFieldNotes),
                  _col(l.drawingSamplesCopyRowSummaryBtn),
                ],
                rows: filteredSamples.map((s) {
                  final isPassed = s.sampleTestStatus == 'Approved' || s.labTestResult == 'CONFORMING';
                  final isPending = s.sampleTestStatus == 'Samples Under Testing' || s.labTestResult == 'PENDING';
                  final fileCode = _resolveFileCode(allFiles, s.importFileId);
                  final recordNo = s.samplingRecordNo ?? '—';
                  final bodies = s.sampledRegulatoryBodies.isEmpty
                      ? '—'
                      : s.sampledRegulatoryBodies
                          .map((b) => DomainEnums.label(l, DomainEnumType.regulatoryBody, b))
                          .join(', ');
                  final statusStr = DrawingSamplesExportService.getSampleStatusLabel(context, s.sampleTestStatus);
                  final rowSummary =
                      "$recordNo\t$fileCode\t$bodies\t${s.samplingDate ?? '—'}\t${s.goeicCertificateNo ?? '—'}\t$statusStr\t${s.labTestResult}\t${s.inspectionNotes ?? '—'}";

                  DataCell cell(String value, Widget child) =>
                      DataCell(CopyableTableCell(value: value, rowSummary: rowSummary, child: child));

                  return DataRow(cells: [
                    cell(recordNo, _codeBadge(recordNo, AppSeverity.info)),
                    cell(fileCode, _codeBadge(fileCode, AppSeverity.info)),
                    cell(bodies, Text(bodies, style: const TextStyle(fontWeight: FontWeight.w600))),
                    cell(s.samplingDate ?? '—', LtrText(s.samplingDate ?? '—')),
                    cell(
                      s.goeicCertificateNo ?? '—',
                      _codeBadge(s.goeicCertificateNo ?? '—', AppSeverity.info, isMonospace: true),
                    ),
                    cell(
                      statusStr,
                      CcStatusChip(
                        label: statusStr,
                        severity: isPassed
                            ? AppSeverity.success
                            : (isPending ? AppSeverity.warning : AppSeverity.danger),
                        icon: isPassed
                            ? Icons.check_circle_outline
                            : (isPending ? Icons.hourglass_top_outlined : Icons.cancel_outlined),
                      ),
                    ),
                    cell(
                      s.labTestResult,
                      Text(s.labTestResult, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    cell(s.inspectionNotes ?? '—', Text(s.inspectionNotes ?? '—')),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                        tooltip: l.drawingSamplesCopyRowSummaryBtn,
                        onPressed: () => CopyHelper.copy(
                          context,
                          rowSummary,
                          customMessage: l.drawingSamplesCopyRowSummarySuccess,
                        ),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShortageCard(AppLocalizations l) {
    return CcSectionCard(
      title: l.drawingSamplesShortageSectionTitle,
      icon: Icons.inventory_2_outlined,
      accent: AppTheme.crimson,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.drawingSamplesShortageSectionDesc,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: CcStateView.empty(
              message: l.ccShortageNotAvailable,
              icon: Icons.inventory_2_outlined,
            ),
          ),
        ],
      ),
    );
  }
}
