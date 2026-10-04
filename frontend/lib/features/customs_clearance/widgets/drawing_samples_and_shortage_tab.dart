import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/customs_clearance_model.dart';
import '../services/drawing_samples_export_service.dart';

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

  void _showAddSampleDialog(AppLocalizations l) {
    final formKey = GlobalKey<FormState>();
    final authCtrl = TextEditingController(text: 'الهيئة العامة للرقابة على الصادرات والواردات');
    final receiptCtrl = TextEditingController();
    final testTypeCtrl = TextEditingController(text: 'فحص ظاهري ومطابقة معملية');
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.science, color: AppTheme.cobalt),
            const SizedBox(width: 8),
            Expanded(child: Text(l.customsClearanceAddSampleDialogTitle)),
          ],
        ),
        content: SelectionArea(
          child: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: authCtrl,
                      decoration: InputDecoration(
                        labelText: l.customsClearanceSampleAuthLabel,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l.drawingSamplesCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, authCtrl.text),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? l.drawingSamplesValidationRequired : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: receiptCtrl,
                      decoration: InputDecoration(
                        labelText: l.customsClearanceSampleReceiptLabel,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l.drawingSamplesCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, receiptCtrl.text),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? l.drawingSamplesValidationRequired : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: testTypeCtrl,
                      decoration: InputDecoration(
                        labelText: l.customsClearanceSampleTestTypeLabel,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l.drawingSamplesCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, testTypeCtrl.text),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? l.drawingSamplesValidationRequired : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: l.customsClearanceSampleNotesLabel,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l.drawingSamplesCopyFieldTooltip,
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, foregroundColor: Colors.white),
            icon: const Icon(Icons.save, size: 16),
            label: Text(l.customsClearanceSampleSaveButton),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newSample = {
                  'sample_id': 'SMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                  'authority': authCtrl.text.trim(),
                  'drawing_date': DateTime.now().toString().substring(0, 10),
                  'receipt_no': receiptCtrl.text.trim(),
                  'test_type': testTypeCtrl.text.trim(),
                  'status': 'PENDING',
                  'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : '-',
                };
                if (widget.onAddSample != null) {
                  widget.onAddSample!(newSample);
                } else {
                  setState(() => widget.drawnSamples.insert(0, newSample));
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.customsClearanceSampleSaveSuccess), backgroundColor: AppTheme.emerald),
                );
              }
            },
          ),
        ],
      ),
    ).then((_) {
      authCtrl.dispose();
      receiptCtrl.dispose();
      testTypeCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  void _showAddShortageDialog(AppLocalizations l) {
    final formKey = GlobalKey<FormState>();
    final containerCtrl = TextEditingController();
    final itemDescCtrl = TextEditingController();
    final manifestQtyCtrl = TextEditingController();
    final landedQtyCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String actionVal = 'DEDUCT_DUTY';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: AppTheme.crimson),
              const SizedBox(width: 8),
              Expanded(child: Text(l.drawingSamplesAddShortageDialogTitle)),
            ],
          ),
          content: SelectionArea(
            child: SizedBox(
              width: 540,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: containerCtrl,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: l.drawingSamplesFieldContainerNo,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: l.drawingSamplesCopyFieldTooltip,
                            onPressed: () => CopyHelper.copy(context, containerCtrl.text),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? l.drawingSamplesValidationRequired : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: itemDescCtrl,
                        decoration: InputDecoration(
                          labelText: l.drawingSamplesFieldItemDesc,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: l.drawingSamplesCopyFieldTooltip,
                            onPressed: () => CopyHelper.copy(context, itemDescCtrl.text),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? l.drawingSamplesValidationRequired : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: manifestQtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l.drawingSamplesFieldManifestQty,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l.drawingSamplesCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, manifestQtyCtrl.text),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return l.drawingSamplesValidationRequired;
                                final n = double.tryParse(v);
                                if (n == null || n <= 0) return l.drawingSamplesValidationPositiveNumber;
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: landedQtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l.drawingSamplesFieldLandedQty,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l.drawingSamplesCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, landedQtyCtrl.text),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return l.drawingSamplesValidationRequired;
                                final landed = double.tryParse(v);
                                if (landed == null || landed < 0) return l.drawingSamplesValidationPositiveNumber;
                                final manifest = double.tryParse(manifestQtyCtrl.text);
                                if (manifest != null && landed > manifest) {
                                  return l.drawingSamplesValidationLandedExceeds;
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: actionVal,
                        decoration: InputDecoration(
                          labelText: l.drawingSamplesColShortageAction,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'DEDUCT_DUTY',
                            child: Text(l.drawingSamplesShortageActionDeductDuty),
                          ),
                          DropdownMenuItem(
                            value: 'CARRIER_CLAIM',
                            child: Text(l.drawingSamplesShortageActionCarrierClaim),
                          ),
                          DropdownMenuItem(
                            value: 'SURVEY_ENDORSED',
                            child: Text(l.drawingSamplesShortageActionSurveyEndorsement),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => actionVal = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: l.drawingSamplesColShortageNotes,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: l.drawingSamplesCopyFieldTooltip,
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
              icon: const Icon(Icons.save, size: 16),
              label: Text(l.save),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final manifest = double.tryParse(manifestQtyCtrl.text) ?? 0;
                  final landed = double.tryParse(landedQtyCtrl.text) ?? 0;
                  final shortage = (manifest - landed).clamp(0, double.infinity);
                  final pct = manifest > 0 ? ((shortage / manifest) * 100).toStringAsFixed(1) : '0.0';

                  final newShortage = {
                    'shortage_id': 'SHR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                    'container_no': containerCtrl.text.trim(),
                    'item_desc': itemDescCtrl.text.trim(),
                    'manifest_qty': manifest.toStringAsFixed(0),
                    'landed_qty': landed.toStringAsFixed(0),
                    'shortage_qty': shortage.toStringAsFixed(0),
                    'shortage_pct': pct,
                    'action': actionVal,
                    'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : '-',
                  };
                  if (widget.onAddShortage != null) {
                    widget.onAddShortage!(newShortage);
                  } else {
                    setState(() => widget.shortageProtocols.insert(0, newShortage));
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.drawingSamplesShortageSaveSuccess), backgroundColor: AppTheme.emerald),
                  );
                }
              },
            ),
          ],
        ),
      ),
    ).then((_) {
      containerCtrl.dispose();
      itemDescCtrl.dispose();
      manifestQtyCtrl.dispose();
      landedQtyCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyableBadge({
    required String text,
    required String tooltip,
    required Color color,
    required Color bgColor,
    bool isMonospace = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => CopyHelper.copy(context, text, customMessage: tooltip),
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withAlpha(70)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontFamily: isMonospace ? 'monospace' : null,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.copy_rounded, size: 12, color: color.withAlpha(180)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final totalSamples = widget.drawnSamples.length;
    final passedSamples = widget.drawnSamples.where((s) => s['status'] == 'PASSED').length;
    final pendingSamples = totalSamples - passedSamples;
    final totalShortages = widget.shortageProtocols.length;
    final filteredSamples = _filteredSamples;

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card with 4-Action Linked Outputs Toolbar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.science, color: AppTheme.cobalt, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.drawingSamplesScreenTitle,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l.drawingSamplesScreenSubtitle,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // 4-Action Export Toolbar
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.copy_all_outlined, size: 15),
                        label: Text(l.drawingSamplesExportTsvBtn, style: const TextStyle(fontSize: 12)),
                        onPressed: () => DrawingSamplesExportService.saveSamplesTsvToFile(context, widget.drawnSamples),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.file_download_outlined, size: 15),
                        label: Text(l.drawingSamplesExportExcelBtn, style: const TextStyle(fontSize: 12)),
                        onPressed: () => DrawingSamplesExportService.saveSamplesCsvToFile(context, widget.drawnSamples),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                        label: Text(l.drawingSamplesPrintPdfBtn, style: const TextStyle(fontSize: 12)),
                        onPressed: () => DrawingSamplesExportService.printOrSaveDrawingSamplesPdf(
                          context: context,
                          samples: widget.drawnSamples,
                          shortages: widget.shortageProtocols,
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.cobalt,
                          side: const BorderSide(color: AppTheme.cobalt),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.assignment_outlined, size: 15),
                        label: Text(l.drawingSamplesCopyDossierBtn, style: const TextStyle(fontSize: 12)),
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
            ),
            const SizedBox(height: 16),

            // 4 KPI Cards
            Row(
              children: [
                _buildKpiCard(
                  title: l.drawingSamplesKpiTotalSamples,
                  value: '$totalSamples',
                  icon: Icons.science_outlined,
                  color: AppTheme.cobalt,
                ),
                const SizedBox(width: 12),
                _buildKpiCard(
                  title: l.drawingSamplesKpiPassedSamples,
                  value: '$passedSamples',
                  icon: Icons.check_circle_outline,
                  color: AppTheme.emerald,
                ),
                const SizedBox(width: 12),
                _buildKpiCard(
                  title: l.drawingSamplesKpiPendingSamples,
                  value: '$pendingSamples',
                  icon: Icons.hourglass_top_outlined,
                  color: AppTheme.orange,
                ),
                const SizedBox(width: 12),
                _buildKpiCard(
                  title: l.drawingSamplesKpiShortageCount,
                  value: '$totalShortages',
                  icon: Icons.warning_amber_rounded,
                  color: AppTheme.crimson,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // SECTION 1: Laboratory Drawn Samples Registry
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
                        const Icon(Icons.biotech, color: AppTheme.cobalt, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.drawingSamplesTabDrawnSamples,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, foregroundColor: Colors.white),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(l.customsClearanceAddSampleButton),
                          onPressed: () => _showAddSampleDialog(l),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search and Filter Bar
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _samplesSearchController,
                            decoration: InputDecoration(
                              hintText: l.drawingSamplesSearchHint,
                              prefixIcon: const Icon(Icons.search, size: 18),
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(value: 'ALL', label: Text(l.drawingSamplesFilterAll, style: const TextStyle(fontSize: 11))),
                            ButtonSegment(value: 'PASSED', label: Text(l.drawingSamplesFilterPassed, style: const TextStyle(fontSize: 11))),
                            ButtonSegment(value: 'PENDING', label: Text(l.drawingSamplesFilterPending, style: const TextStyle(fontSize: 11))),
                          ],
                          selected: {_sampleStatusFilter},
                          onSelectionChanged: (set) {
                            setState(() => _sampleStatusFilter = set.first);
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    if (filteredSamples.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.science_outlined, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                l.drawingSamplesEmptySamples,
                                style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                          columns: [
                            DataColumn(label: Text(l.drawingSamplesColSampleCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.drawingSamplesFieldAuthority, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.drawingSamplesFieldDrawingDate, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.drawingSamplesFieldReceiptNo, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.drawingSamplesFieldTestType, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.drawingSamplesFieldStatus, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.drawingSamplesFieldNotes, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.drawingSamplesCopyRowSummaryBtn, style: const TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: filteredSamples.map((s) {
                            final isPassed = s['status'] == 'PASSED';
                            final statusStr = isPassed ? l.customsClearanceSamplePassed : l.customsClearanceSamplePending;
                            final rowSummary = "${s['sample_id']}\t${s['authority']}\t${s['drawing_date']}\t${s['receipt_no']}\t${s['test_type']}\t$statusStr\t${s['notes'] ?? '-'}";
                            return DataRow(cells: [
                              DataCell(
                                CopyableTableCell(
                                  value: s['sample_id'] ?? '',
                                  rowSummary: rowSummary,
                                  child: _buildCopyableBadge(
                                    text: s['sample_id'] ?? '',
                                    tooltip: l.drawingSamplesCopyFieldTooltip,
                                    color: AppTheme.cobalt,
                                    bgColor: Colors.blue.shade50,
                                  ),
                                ),
                              ),
                              DataCell(CopyableTableCell(value: s['authority'] ?? '', rowSummary: rowSummary, child: Text(s['authority'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)))),
                              DataCell(CopyableTableCell(value: s['drawing_date'] ?? '', rowSummary: rowSummary, child: Text(s['drawing_date'] ?? ''))),
                              DataCell(
                                CopyableTableCell(
                                  value: s['receipt_no'] ?? '',
                                  rowSummary: rowSummary,
                                  child: _buildCopyableBadge(
                                    text: s['receipt_no'] ?? '',
                                    tooltip: l.drawingSamplesCopyFieldTooltip,
                                    color: Colors.purple.shade700,
                                    bgColor: Colors.purple.shade50,
                                    isMonospace: true,
                                  ),
                                ),
                              ),
                              DataCell(CopyableTableCell(value: s['test_type'] ?? '', rowSummary: rowSummary, child: Text(s['test_type'] ?? ''))),
                              DataCell(
                                CopyableTableCell(
                                  value: statusStr,
                                  rowSummary: rowSummary,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (isPassed ? Colors.green : Colors.orange).shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: (isPassed ? Colors.green : Colors.orange).shade300),
                                    ),
                                    child: Text(
                                      isPassed ? '✅ $statusStr' : '⏳ $statusStr',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isPassed ? Colors.green.shade900 : Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(CopyableTableCell(value: s['notes'] ?? '-', rowSummary: rowSummary, child: Text(s['notes'] ?? '-'))),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                                  tooltip: l.drawingSamplesCopyRowSummaryBtn,
                                  onPressed: () => CopyHelper.copy(context, rowSummary, customMessage: l.drawingSamplesCopyRowSummarySuccess),
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // SECTION 2: Cargo Examination Shortage Reconciliation
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
                        const Icon(Icons.inventory_2_outlined, color: AppTheme.crimson, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.drawingSamplesShortageSectionTitle,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l.drawingSamplesShortageSectionDesc,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(l.drawingSamplesAddShortageBtn),
                          onPressed: () => _showAddShortageDialog(l),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    if (widget.shortageProtocols.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fact_check_outlined, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                l.drawingSamplesEmptyShortage,
                                style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                          columns: [
                            DataColumn(label: Text(l.drawingSamplesCopyRowSummaryBtn, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.drawingSamplesColShortageCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.drawingSamplesColContainerPkg, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.drawingSamplesColItemDesc, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.drawingSamplesColManifestQty, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.drawingSamplesColLandedQty, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.drawingSamplesColShortageQty, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.drawingSamplesColShortagePct, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.drawingSamplesColShortageAction, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.drawingSamplesColShortageNotes, style: const TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: widget.shortageProtocols.map((item) {
                            final actionLabel = DrawingSamplesExportService.getShortageActionLabel(context, item['action'] as String?);
                            final rowSummary = "${item['shortage_id']}\t${item['container_no']}\t${item['item_desc']}\t${item['manifest_qty']}\t${item['landed_qty']}\t${item['shortage_qty']}\t${item['shortage_pct']}%\t$actionLabel\t${item['notes'] ?? '-'}";
                            return DataRow(cells: [
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.crimson),
                                  tooltip: l.drawingSamplesCopyRowSummaryBtn,
                                  onPressed: () => CopyHelper.copy(context, rowSummary, customMessage: l.drawingSamplesCopyRowSummarySuccess),
                                ),
                              ),
                              DataCell(
                                CopyableTableCell(
                                  value: item['shortage_id'] ?? '',
                                  rowSummary: rowSummary,
                                  child: _buildCopyableBadge(
                                    text: item['shortage_id'] ?? '',
                                    tooltip: l.drawingSamplesCopyFieldTooltip,
                                    color: AppTheme.crimson,
                                    bgColor: Colors.red.shade50,
                                  ),
                                ),
                              ),
                              DataCell(
                                CopyableTableCell(
                                  value: item['container_no'] ?? '',
                                  rowSummary: rowSummary,
                                  child: _buildCopyableBadge(
                                    text: item['container_no'] ?? '',
                                    tooltip: l.drawingSamplesCopyFieldTooltip,
                                    color: Colors.blueGrey.shade800,
                                    bgColor: Colors.blueGrey.shade50,
                                    isMonospace: true,
                                  ),
                                ),
                              ),
                              DataCell(CopyableTableCell(value: item['item_desc'] ?? '', rowSummary: rowSummary, child: Text(item['item_desc'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)))),
                              DataCell(CopyableTableCell(value: (item['manifest_qty'] ?? '0').toString(), rowSummary: rowSummary, child: Text((item['manifest_qty'] ?? '0').toString()))),
                              DataCell(CopyableTableCell(value: (item['landed_qty'] ?? '0').toString(), rowSummary: rowSummary, child: Text((item['landed_qty'] ?? '0').toString()))),
                              DataCell(
                                CopyableTableCell(
                                  value: (item['shortage_qty'] ?? '0').toString(),
                                  rowSummary: rowSummary,
                                  child: Text(
                                    (item['shortage_qty'] ?? '0').toString(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson),
                                  ),
                                ),
                              ),
                              DataCell(
                                CopyableTableCell(
                                  value: '${item['shortage_pct'] ?? '0'}%',
                                  rowSummary: rowSummary,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade200)),
                                    child: Text(
                                      '${item['shortage_pct'] ?? '0'}%',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                CopyableTableCell(
                                  value: actionLabel,
                                  rowSummary: rowSummary,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.blueGrey.shade200),
                                    ),
                                    child: Text(
                                      actionLabel,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(CopyableTableCell(value: item['notes'] ?? '-', rowSummary: rowSummary, child: Text(item['notes'] ?? '-'))),
                            ]);
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
