import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/metric_card.dart';
import '../models/customs_clearance_model.dart';
import '../services/drawing_samples_export_service.dart';
import 'customs_ui.dart';
import 'drawing_samples_dialogs.dart';

/// Screen 60: Customs Clearance - Drawing Samples & Shortage Tracking SubTab.
class DrawingSamplesAndShortageTab extends ConsumerStatefulWidget {
  final List<CustomsClearanceModel> records;
  final List<Map<String, dynamic>> drawnSamples;
  final List<Map<String, dynamic>> shortageProtocols;
  final VoidCallback? onRefresh;
  final ValueChanged<Map<String, dynamic>>? onAddSample;
  final ValueChanged<Map<String, dynamic>>? onAddShortage;

  const DrawingSamplesAndShortageTab({
    super.key,
    required this.records,
    required this.drawnSamples,
    required this.shortageProtocols,
    this.onRefresh,
    this.onAddSample,
    this.onAddShortage,
  });

  @override
  ConsumerState<DrawingSamplesAndShortageTab> createState() => _DrawingSamplesAndShortageTabState();
}

class _DrawingSamplesAndShortageTabState extends ConsumerState<DrawingSamplesAndShortageTab> {
  final TextEditingController _samplesSearchController = TextEditingController();
  String _sampleStatusFilter = 'ALL'; // ALL, PASSED, PENDING

  @override
  void dispose() {
    _samplesSearchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredSamples {
    return widget.drawnSamples.where((s) {
      if (_sampleStatusFilter != 'ALL' && s['status'] != _sampleStatusFilter) {
        return false;
      }
      final q = _samplesSearchController.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      final id = (s['sample_id'] ?? '').toString().toLowerCase();
      final auth = (s['authority'] ?? '').toString().toLowerCase();
      final receipt = (s['receipt_no'] ?? '').toString().toLowerCase();
      final test = (s['test_type'] ?? '').toString().toLowerCase();
      final notes = (s['notes'] ?? '').toString().toLowerCase();
      return id.contains(q) || auth.contains(q) || receipt.contains(q) || test.contains(q) || notes.contains(q);
    }).toList();
  }

  Future<void> _addSample() async {
    final l = context.l10n;
    final sample = await showAddSampleDialog(context);
    if (sample == null || !mounted) return;
    if (widget.onAddSample != null) {
      widget.onAddSample!(sample);
    } else {
      setState(() => widget.drawnSamples.insert(0, sample));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, l.customsClearanceSampleSaveSuccess, severity: AppSeverity.success),
    );
  }

  Future<void> _addShortage() async {
    final l = context.l10n;
    final shortage = await showAddShortageDialog(context);
    if (shortage == null || !mounted) return;
    if (widget.onAddShortage != null) {
      widget.onAddShortage!(shortage);
    } else {
      setState(() => widget.shortageProtocols.insert(0, shortage));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, l.drawingSamplesShortageSaveSuccess, severity: AppSeverity.success),
    );
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
    final totalSamples = widget.drawnSamples.length;
    final passedSamples = widget.drawnSamples.where((s) => s['status'] == 'PASSED').length;
    final pendingSamples = totalSamples - passedSamples;
    final totalShortages = widget.shortageProtocols.length;

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
      MetricCardData(
        title: l.drawingSamplesKpiShortageCount,
        value: '$totalShortages',
        icon: Icons.warning_amber_rounded,
        color: AppTheme.crimson,
      ),
    ];

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(l),
            CcUi.metrics(metrics),
            const SizedBox(height: 16),
            _buildSamplesCard(l),
            const SizedBox(height: 16),
            _buildShortageCard(l),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(AppLocalizations l) {
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
                onPressed: () => DrawingSamplesExportService.saveSamplesTsvToFile(context, widget.drawnSamples),
              ),
              AppButton(
                label: l.drawingSamplesExportExcelBtn,
                icon: Icons.file_download_outlined,
                variant: AppButtonVariant.success,
                size: AppButtonSize.small,
                onPressed: () => DrawingSamplesExportService.saveSamplesCsvToFile(context, widget.drawnSamples),
              ),
              AppButton(
                label: l.drawingSamplesPrintPdfBtn,
                icon: Icons.picture_as_pdf_outlined,
                variant: AppButtonVariant.danger,
                size: AppButtonSize.small,
                onPressed: () => DrawingSamplesExportService.printOrSaveDrawingSamplesPdf(
                  context: context,
                  samples: widget.drawnSamples,
                  shortages: widget.shortageProtocols,
                ),
              ),
              AppButton(
                label: l.drawingSamplesCopyDossierBtn,
                icon: Icons.assignment_outlined,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
                onPressed: () => DrawingSamplesExportService.copyDossierToClipboard(
                  context: context,
                  samples: widget.drawnSamples,
                  shortages: widget.shortageProtocols,
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

  Widget _buildSamplesCard(AppLocalizations l) {
    final filteredSamples = _filteredSamples;
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
                      value: 'ALL', label: Text(l.drawingSamplesFilterAll, style: const TextStyle(fontSize: 11))),
                  ButtonSegment(
                      value: 'PASSED',
                      label: Text(l.drawingSamplesFilterPassed, style: const TextStyle(fontSize: 11))),
                  ButtonSegment(
                      value: 'PENDING',
                      label: Text(l.drawingSamplesFilterPending, style: const TextStyle(fontSize: 11))),
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
                  _col(l.drawingSamplesFieldAuthority),
                  _col(l.drawingSamplesFieldDrawingDate),
                  _col(l.drawingSamplesFieldReceiptNo),
                  _col(l.drawingSamplesFieldTestType),
                  _col(l.drawingSamplesFieldStatus),
                  _col(l.drawingSamplesFieldNotes),
                  _col(l.drawingSamplesCopyRowSummaryBtn),
                ],
                rows: filteredSamples.map((s) {
                  final isPassed = s['status'] == 'PASSED';
                  final statusStr = isPassed ? l.customsClearanceSamplePassed : l.customsClearanceSamplePending;
                  final rowSummary =
                      "${s['sample_id']}\t${s['authority']}\t${s['drawing_date']}\t${s['receipt_no']}\t${s['test_type']}\t$statusStr\t${s['notes'] ?? '-'}";
                  DataCell cell(String value, Widget child) =>
                      DataCell(CopyableTableCell(value: value, rowSummary: rowSummary, child: child));
                  return DataRow(cells: [
                    cell(s['sample_id'] ?? '', _codeBadge(s['sample_id'] ?? '', AppSeverity.info)),
                    cell(
                      s['authority'] ?? '',
                      Text(s['authority'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    cell(s['drawing_date'] ?? '', LtrText(s['drawing_date'] ?? '')),
                    cell(
                      s['receipt_no'] ?? '',
                      _codeBadge(s['receipt_no'] ?? '', AppSeverity.info, isMonospace: true),
                    ),
                    cell(s['test_type'] ?? '', Text(s['test_type'] ?? '')),
                    cell(
                      statusStr,
                      CcStatusChip(
                        label: statusStr,
                        severity: isPassed ? AppSeverity.success : AppSeverity.warning,
                        icon: isPassed ? Icons.check_circle_outline : Icons.hourglass_top_outlined,
                      ),
                    ),
                    cell(s['notes'] ?? '-', Text(s['notes'] ?? '-')),
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
      trailing: AppButton(
        label: l.drawingSamplesAddShortageBtn,
        icon: Icons.add,
        variant: AppButtonVariant.danger,
        size: AppButtonSize.small,
        onPressed: _addShortage,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.drawingSamplesShortageSectionDesc,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
          ),
          const SizedBox(height: 10),
          if (widget.shortageProtocols.isEmpty)
            SizedBox(
              height: 150,
              child: CcStateView.empty(message: l.drawingSamplesEmptyShortage, icon: Icons.fact_check_outlined),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAltOf(context)),
                columns: [
                  _col(l.drawingSamplesCopyRowSummaryBtn),
                  _col(l.drawingSamplesColShortageCode),
                  _col(l.drawingSamplesColContainerPkg),
                  _col(l.drawingSamplesColItemDesc),
                  _col(l.drawingSamplesColManifestQty, numeric: true),
                  _col(l.drawingSamplesColLandedQty, numeric: true),
                  _col(l.drawingSamplesColShortageQty, numeric: true),
                  _col(l.drawingSamplesColShortagePct, numeric: true),
                  _col(l.drawingSamplesColShortageAction),
                  _col(l.drawingSamplesColShortageNotes),
                ],
                rows: widget.shortageProtocols.map((item) {
                  final actionLabel =
                      DrawingSamplesExportService.getShortageActionLabel(context, item['action'] as String?);
                  final rowSummary =
                      "${item['shortage_id']}\t${item['container_no']}\t${item['item_desc']}\t${item['manifest_qty']}\t${item['landed_qty']}\t${item['shortage_qty']}\t${item['shortage_pct']}%\t$actionLabel\t${item['notes'] ?? '-'}";
                  DataCell cell(String value, Widget child) =>
                      DataCell(CopyableTableCell(value: value, rowSummary: rowSummary, child: child));
                  final manifest = (item['manifest_qty'] ?? '0').toString();
                  final landed = (item['landed_qty'] ?? '0').toString();
                  final shortage = (item['shortage_qty'] ?? '0').toString();
                  final pct = '${item['shortage_pct'] ?? '0'}%';
                  return DataRow(cells: [
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.crimson),
                        tooltip: l.drawingSamplesCopyRowSummaryBtn,
                        onPressed: () => CopyHelper.copy(
                          context,
                          rowSummary,
                          customMessage: l.drawingSamplesCopyRowSummarySuccess,
                        ),
                      ),
                    ),
                    cell(item['shortage_id'] ?? '', _codeBadge(item['shortage_id'] ?? '', AppSeverity.danger)),
                    cell(
                      item['container_no'] ?? '',
                      _codeBadge(item['container_no'] ?? '', AppSeverity.info, isMonospace: true),
                    ),
                    cell(
                      item['item_desc'] ?? '',
                      Text(item['item_desc'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    cell(manifest, LtrText(manifest)),
                    cell(landed, LtrText(landed)),
                    cell(
                      shortage,
                      LtrText(
                        shortage,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson),
                      ),
                    ),
                    cell(pct, CcStatusChip(label: pct, severity: AppSeverity.danger)),
                    cell(actionLabel, CcStatusChip(label: actionLabel, severity: AppSeverity.info)),
                    cell(item['notes'] ?? '-', Text(item['notes'] ?? '-')),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
