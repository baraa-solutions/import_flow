import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';

import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../shipment_updates/providers/shipment_updates_provider.dart';
import '../../shipment_updates/widgets/shipment_update_dialog.dart';
import '../../customs_clearance/providers/customs_clearance_provider.dart';
import '../../customs_clearance/models/customs_clearance_model.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../warehouse_receiving/providers/warehouse_receiving_provider.dart';
import '../../warehouse_receiving/models/warehouse_receiving_model.dart';
import '../services/comprehensive_report_export_service.dart';
import '../widgets/comprehensive_dossier_export_dialog.dart';
import '../../purchase_orders/utils/po_packing_matcher.dart';

// ============================================================
// Comprehensive Import File Report Screen
// تقرير ملخص ملفات الاستيراد المدمج والشامل
// ============================================================

class ImportFileComprehensiveReportScreen extends ConsumerStatefulWidget {
  const ImportFileComprehensiveReportScreen({super.key});

  @override
  ConsumerState<ImportFileComprehensiveReportScreen> createState() =>
      _ImportFileComprehensiveReportScreenState();
}

class _ImportFileComprehensiveReportScreenState
    extends ConsumerState<ImportFileComprehensiveReportScreen> {
  int? _selectedFileId;
  ImportFileModel? _selectedFile;

  List<Map<String, dynamic>> _getPhases(BuildContext context) {
    final l = context.l10n;
    return [
      {'code': 'Phase 1', 'name': l.compReportPhase1Name, 'icon': Icons.analytics_outlined, 'bp': 'BP-001 → BP-011'},
      {'code': 'Phase 2', 'name': l.compReportPhase2Name, 'icon': Icons.account_balance_outlined, 'bp': 'BP-012 → BP-013'},
      {'code': 'Phase 3', 'name': l.compReportPhase3Name, 'icon': Icons.description_outlined, 'bp': 'BP-014 → BP-016'},
      {'code': 'Phase 4', 'name': l.compReportPhase4Name, 'icon': Icons.directions_boat_outlined, 'bp': 'BP-017 → BP-019'},
      {'code': 'Phase 5', 'name': l.compReportPhase5Name, 'icon': Icons.local_shipping_outlined, 'bp': 'BP-020 → BP-025'},
      {'code': 'Phase 6', 'name': l.compReportPhase6Name, 'icon': Icons.account_balance_wallet_outlined, 'bp': 'BP-026 → BP-028'},
      {'code': 'Phase 7', 'name': l.compReportPhase7Name, 'icon': Icons.receipt_long_outlined, 'bp': 'BP-029 → BP-032'},
      {'code': 'Phase 8', 'name': l.compReportPhase8Name, 'icon': Icons.warehouse_outlined, 'bp': 'BP-033 → BP-035'},
      {'code': 'Phase 9', 'name': l.compReportPhase9Name, 'icon': Icons.calculate_outlined, 'bp': 'BP-036 → BP-039'},
      {'code': 'Phase 10', 'name': l.compReportPhase10Name, 'icon': Icons.archive_outlined, 'bp': 'BP-040'},
    ];
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
    });
  }

  void _onFileSelected(int? val, List<ImportFileModel> files) {
    if (val == null || files.isEmpty) return;
    final file = files.firstWhere((f) => f.importFileId == val, orElse: () => files.first);
    setState(() {
      _selectedFileId = val;
      _selectedFile = file;
    });
    ref.read(shipmentUpdatesProvider.notifier).fetchLogs(importFileId: val);
    ref.read(customsClearanceProvider.notifier).fetchRecords(importFileId: val);
    ref.read(warehouseReceivingProvider.notifier).fetchRecords(importFileId: val);
  }

  int _currentPhaseIndex(ImportFileModel file) {
    final mod = file.currentModule;
    for (int i = 1; i <= 10; i++) {
      if (mod.contains('Phase $i')) return i - 1;
    }
    return 0;
  }

  String _formatPhaseLabel(BuildContext context, String rawPhase) {
    final l = context.l10n;
    final match = RegExp(r'Phase\s*(\d+)').firstMatch(rawPhase);
    if (match != null) {
      final num = int.tryParse(match.group(1) ?? '');
      if (num != null) {
        return l.compReportPhaseLabel(num);
      }
    }
    return rawPhase;
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical': return AppTheme.crimson;
      case 'high': return AppTheme.orange;
      case 'medium': return AppTheme.cobalt;
      default: return AppTheme.emerald;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final importFilesState = ref.watch(importFilesProvider);
    final updatesState = ref.watch(shipmentUpdatesProvider);
    final clearanceState = ref.watch(customsClearanceProvider);
    final warehouseState = ref.watch(warehouseReceivingProvider);

    final clr = (clearanceState.valueOrNull != null && clearanceState.valueOrNull!.isNotEmpty) ? clearanceState.valueOrNull!.first : null;
    final wh = (warehouseState.valueOrNull != null && warehouseState.valueOrNull!.isNotEmpty) ? warehouseState.valueOrNull!.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: AppTheme.charcoal,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.summarize_outlined, color: AppTheme.cobalt, size: 24),
            const SizedBox(width: 10),
            Text(
              l.compReportScreenTitle,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        actions: [
          if (_selectedFile != null) ...[
            IconButton(
              icon: const Icon(Icons.copy_all, color: Colors.white, size: 20),
              tooltip: l.compReportCopyDossierBtn,
              onPressed: () {
                final dossier = ComprehensiveReportExportService.buildDossierText(
                  context: context,
                  file: _selectedFile!,
                  logs: updatesState.logs,
                  clearance: clr,
                  warehouse: wh,
                );
                CopyHelper.copy(context, dossier, customMessage: l.compReportCopyDossierSuccess);
              },
            ),
            IconButton(
              icon: const Icon(Icons.description_outlined, color: Colors.white, size: 20),
              tooltip: l.compReportExportTsvBtn,
              onPressed: () => ComprehensiveReportExportService.exportToTsv(
                context: context,
                file: _selectedFile!,
                logs: updatesState.logs,
                clearance: clr,
                warehouse: wh,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.table_chart_outlined, color: Colors.white, size: 20),
              tooltip: l.compReportExportExcelBtn,
              onPressed: () => ComprehensiveReportExportService.exportToExcel(
                context: context,
                file: _selectedFile!,
                logs: updatesState.logs,
                clearance: clr,
                warehouse: wh,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 20),
              tooltip: l.compReportPrintPdfBtn,
              onPressed: () => ComprehensiveReportExportService.printOrSavePdf(
                context: context,
                file: _selectedFile!,
                logs: updatesState.logs,
                clearance: clr,
                warehouse: wh,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.cobalt.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                icon: const Icon(Icons.published_with_changes, color: Colors.white, size: 16),
                label: Text(l.compReportAddUpdateBtn, style: const TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: () => ShipmentUpdateDialog.show(
                  context,
                  initialFileId: _selectedFile!.importFileId,
                  initialFileCode: _selectedFile!.displayName,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          const BackToDashboardButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: Column(
          children: [
            // ── Shipment Selector Bar ──────────────────────────────────
            Container(
              color: AppTheme.charcoal.withOpacity(0.04),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: importFilesState.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('${l.errorPrefix} $e', style: const TextStyle(color: AppTheme.crimson)),
                data: (files) => Row(
                  children: [
                    const Icon(Icons.folder_open, color: AppTheme.cobalt, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SearchableDropdownField<int>(
                        value: _selectedFileId,
                        labelText: l.compReportSelectFileLabel,
                        items: files.map((f) {
                          final isAr = Localizations.localeOf(context).languageCode == 'ar';
                          final stageName = DisplayNameResolver.resolveStepName(f.displayStepKey, isArabic: isAr);
                          return SearchableDropdownItem<int>(
                            value: f.importFileId,
                            label: '${f.primaryNameWithCode}  |  ${f.supplierName}  |  $stageName  |  ${f.status}',
                          );
                        }).toList(),
                        onChanged: (val) => _onFileSelected(val, files),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Action Toolbar Strip when file is selected ─────────────
            if (_selectedFile != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedFile!.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                    ),
                    const SizedBox(width: 8),
                    _buildCopyBadge(context, _selectedFile!.displayName),
                    const Spacer(),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      icon: const Icon(Icons.copy_all, size: 15, color: AppTheme.charcoal),
                      label: Text(l.compReportCopyDossierBtn, style: const TextStyle(fontSize: 11, color: AppTheme.charcoal)),
                      onPressed: () {
                        final dossier = ComprehensiveReportExportService.buildDossierText(
                          context: context,
                          file: _selectedFile!,
                          logs: updatesState.logs,
                          clearance: clr,
                          warehouse: wh,
                        );
                        CopyHelper.copy(context, dossier, customMessage: l.compReportCopyDossierSuccess);
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: BorderSide(color: AppTheme.cobalt.withOpacity(0.4)),
                      ),
                      icon: const Icon(Icons.description_outlined, size: 15, color: AppTheme.cobalt),
                      label: Text(l.compReportExportTsvBtn, style: const TextStyle(fontSize: 11, color: AppTheme.cobalt)),
                      onPressed: () => ComprehensiveReportExportService.exportToTsv(
                        context: context,
                        file: _selectedFile!,
                        logs: updatesState.logs,
                        clearance: clr,
                        warehouse: wh,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: BorderSide(color: AppTheme.emerald.withOpacity(0.4)),
                      ),
                      icon: const Icon(Icons.table_chart_outlined, size: 15, color: AppTheme.emerald),
                      label: Text(l.compReportExportExcelBtn, style: const TextStyle(fontSize: 11, color: AppTheme.emerald)),
                      onPressed: () => ComprehensiveReportExportService.exportToExcel(
                        context: context,
                        file: _selectedFile!,
                        logs: updatesState.logs,
                        clearance: clr,
                        warehouse: wh,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.charcoal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 15, color: Colors.white),
                      label: Text(l.compReportPrintPdfBtn, style: const TextStyle(fontSize: 11, color: Colors.white)),
                      onPressed: () => ComprehensiveReportExportService.printOrSavePdf(
                        context: context,
                        file: _selectedFile!,
                        logs: updatesState.logs,
                        clearance: clr,
                        warehouse: wh,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      key: const Key('comprehensiveDossierModalBtn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED), // Royal Purple
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      icon: const Icon(Icons.inventory_2_outlined, size: 15, color: Colors.white),
                      label: const Text('تصدير الملف الشامل (CLO-03)', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () => ComprehensiveDossierExportDialog.show(
                        context,
                        file: _selectedFile!,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Report Body ───────────────────────────────────────────
            Expanded(
              child: _selectedFile == null
                  ? _buildEmptyState(context)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section 1: Header Banner
                          _buildHeaderBanner(context, _selectedFile!),
                          const SizedBox(height: 16),

                          // Section 2: 10-Phase Progress Pipeline
                          _buildPhasePipeline(context, _selectedFile!, updatesState),
                          const SizedBox(height: 16),

                          // Section 3: Two-Column Detail Cards
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // LEFT COL
                              Expanded(
                                flex: 3,
                                child: Column(
                                  children: [
                                    _buildBasicInfoCard(context, _selectedFile!),
                                    const SizedBox(height: 14),
                                    _buildDocumentsCard(context, _selectedFile!),
                                    const SizedBox(height: 14),
                                    _buildInvoicesCard(context, _selectedFile!),
                                    const SizedBox(height: 14),
                                    _buildPackingListCard(context, _selectedFile!),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              // RIGHT COL
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    _buildStatusCard(context, _selectedFile!),
                                    const SizedBox(height: 14),
                                    _buildFinancialCard(context, _selectedFile!),
                                    const SizedBox(height: 14),
                                    _buildNotesCard(context, _selectedFile!),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Section 4: Live Update Logs Timeline
                          _buildUpdateTimeline(context, _selectedFile!, updatesState),
                          const SizedBox(height: 16),
                          
                          // Section 5: Customs Clearance Real-Time Data
                          _buildClearanceSection(context, clearanceState),
                          const SizedBox(height: 16),
                          
                          // Section 6: Warehouse Receiving & GRN Real-Time Data
                          _buildWarehouseSection(context, warehouseState),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.summarize_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            l.compReportEmptyStatePrompt,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ── Section 1: Header Banner ──────────────────────────────────────
  Widget _buildHeaderBanner(BuildContext context, ImportFileModel file) {
    final l = context.l10n;
    final isClosed = file.status == 'Closed';
    final phaseIdx = _currentPhaseIndex(file);
    final completedCount = isClosed ? 10 : phaseIdx;
    final remainingCount = isClosed ? 0 : (10 - phaseIdx - 1);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isClosed
              ? [Colors.grey.shade700, Colors.grey.shade500]
              : [AppTheme.charcoal, const Color(0xFF34495E)],
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isClosed ? Icons.archive : Icons.folder_open,
              color: isClosed ? Colors.grey.shade300 : AppTheme.cobalt,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),

          // Main Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        file.displayName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildCopyBadge(
                      context,
                      file.displayName,
                      color: Colors.white.withOpacity(0.15),
                      borderColor: Colors.white.withOpacity(0.3),
                      textColor: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    _statusPill(context, file.status),
                    const SizedBox(width: 8),
                    _priorityPill(context, file.priority),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${file.supplierName}  •  ${file.companyName}',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  DisplayNameResolver.resolveStepName(file.displayStepKey, isArabic: Localizations.localeOf(context).languageCode == 'ar'),
                  style: const TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 10),

                // Progress Bar
                Row(
                  children: [
                    Text(
                      l.compReportPercentCompleted(file.progressPercent.toStringAsFixed(0)),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: file.progressPercent / 100,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isClosed ? Colors.grey.shade400 : AppTheme.emerald,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stats Counters
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _counterBadge('$completedCount', l.compReportCompletedPhases, AppTheme.emerald),
              const SizedBox(height: 8),
              _counterBadge('$remainingCount', l.compReportRemainingPhases, AppTheme.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _counterBadge(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _statusPill(BuildContext context, String status) {
    final l = context.l10n;
    Color bg;
    String label;
    switch (status.toLowerCase()) {
      case 'open':
      case 'draft':
        bg = AppTheme.cobalt;
        label = l.filterStatusDraft;
        break;
      case 'in progress':
        bg = AppTheme.emerald;
        label = l.statusInProgress;
        break;
      case 'closed':
        bg = Colors.grey;
        label = l.statusClosed;
        break;
      default:
        bg = AppTheme.orange;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _priorityPill(BuildContext context, String priority) {
    final l = context.l10n;
    String label;
    switch (priority.toLowerCase()) {
      case 'critical':
        label = l.priorityCritical;
        break;
      case 'high':
        label = l.priorityHigh;
        break;
      case 'medium':
        label = l.priorityMedium;
        break;
      case 'low':
        label = l.priorityLow;
        break;
      default:
        label = priority;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _priorityColor(priority).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _priorityColor(priority).withOpacity(0.5)),
      ),
      child: Text(label, style: TextStyle(color: _priorityColor(priority), fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // ── Section 2: 10-Phase Pipeline ──────────────────────────────────
  Widget _buildPhasePipeline(BuildContext context, ImportFileModel file, ShipmentUpdatesState updatesState) {
    final l = context.l10n;
    final phases = _getPhases(context);
    final currentIdx = _currentPhaseIndex(file);
    final isClosed = file.status == 'Closed';

    return _reportCard(
      title: l.compReportPipelineTitle,
      icon: Icons.linear_scale,
      iconColor: AppTheme.cobalt,
      child: Column(
        children: [
          // Phase Stepper Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(phases.length, (idx) {
                final phase = phases[idx];
                final pCode = phase['code'] as String;
                final phaseLogs = updatesState.logs.where((log) => log.targetPhase.contains(pCode)).toList();

                bool isCompleted = isClosed || idx < currentIdx;
                bool isCurrent = !isClosed && idx == currentIdx;

                Color dotColor = isCompleted
                    ? AppTheme.emerald
                    : isCurrent
                        ? AppTheme.cobalt
                        : Colors.grey.shade300;

                Color borderColor = isCompleted
                    ? AppTheme.emerald
                    : isCurrent
                        ? AppTheme.cobalt
                        : Colors.grey.shade300;

                Color textColor = isCompleted
                    ? Colors.green.shade800
                    : isCurrent
                        ? AppTheme.cobalt
                        : Colors.grey.shade500;

                return Row(
                  children: [
                    Container(
                      width: 130,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green.shade50
                            : isCurrent
                                ? Colors.blue.shade50
                                : Colors.grey.shade50,
                        border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCompleted
                                    ? Icons.check_circle
                                    : isCurrent
                                        ? Icons.play_circle_fill
                                        : Icons.radio_button_unchecked,
                                size: 16,
                                color: dotColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l.compReportPhaseLabel(idx + 1),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
                              ),
                              if (phaseLogs.isNotEmpty) ...[
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${phaseLogs.length}',
                                    style: const TextStyle(fontSize: 9, color: AppTheme.orange, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phase['name'] as String,
                            style: TextStyle(fontSize: 9, color: textColor, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (phaseLogs.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              phaseLogs.first.note,
                              style: TextStyle(fontSize: 8, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (idx < phases.length - 1)
                      Container(
                        width: 16,
                        height: 2,
                        color: idx < currentIdx ? AppTheme.emerald : Colors.grey.shade300,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                      ),
                  ],
                );
              }),
            ),
          ),

          if (isClosed && file.closedAtPhase != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outlined, color: AppTheme.crimson, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    l.compReportStoppedAtPhase(_formatPhaseLabel(context, file.closedAtPhase!)),
                    style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  if (file.closureReason != null) ...[
                    const SizedBox(width: 8),
                    Text(' — ${file.closureReason}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Section 3a: Basic Info ────────────────────────────────────────
  Widget _buildBasicInfoCard(BuildContext context, ImportFileModel file) {
    final l = context.l10n;
    return _reportCard(
      title: l.compReportSecBasicInfo,
      icon: Icons.info_outline,
      iconColor: AppTheme.cobalt,
      child: Column(
        children: [
          _infoRow(context, l.compReportColFileCode, file.importFileCode, showCopyBadge: true),
          _infoRow(context, l.compReportColCustomsFileNo, file.customFileNumber ?? '—', showCopyBadge: file.customFileNumber != null && file.customFileNumber!.isNotEmpty),
          _infoRow(context, l.compReportColImportCompany, file.companyName),
          _infoRow(context, l.compReportColSupplier, file.supplierName),
          _infoRow(context, l.compReportColBroker, file.brokerName ?? '—'),
          _infoRow(context, l.compReportColPoNumber, file.poNumber ?? '—', showCopyBadge: file.poNumber != null && file.poNumber!.isNotEmpty),
          _infoRow(context, l.compReportColPiNumber, file.piNumber ?? '—', showCopyBadge: file.piNumber != null && file.piNumber!.isNotEmpty),
          _infoRow(context, l.compReportColShipmentMode, file.shipmentMode),
          _infoRow(context, l.compReportColIncoterm, file.incotermCode),
          _infoRow(context, l.compReportColCategory, file.shipmentCategory),
          _infoRow(context, l.compReportColScenario, file.selectedScenario ?? '—'),
          _infoRow(context, l.compReportColRequiredEta, file.requiredEta ?? '—'),
          _infoRow(context, l.compReportColOwner, file.owner),
          _infoRow(context, l.compReportColCreatedAt, file.createdAt.split('T').first),
          _infoRow(context, l.compReportColUpdatedAt, file.updatedAt.split('T').first),
        ],
      ),
    );
  }

  // ── Section 3b: Documents ─────────────────────────────────────────
  Widget _buildDocumentsCard(BuildContext context, ImportFileModel file) {
    final l = context.l10n;
    final docs = <Map<String, String>>[
      {'label': l.compReportAcidNumber, 'value': file.acidNumber ?? '—'},
      {'label': l.compReportBankForm4, 'value': file.form4No ?? '—'},
      {'label': l.compReportSwiftNumber, 'value': file.swiftNo ?? '—'},
      {'label': l.compReportForm46Number, 'value': file.form46No ?? '—'},
    ];

    return _reportCard(
      title: l.compReportSecDocs,
      icon: Icons.description_outlined,
      iconColor: AppTheme.orange,
      child: Column(
        children: docs.map((d) {
          final val = d['value']!;
          final hasValue = val != '—' && val.trim().isNotEmpty;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Icon(
                  hasValue ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                  size: 16,
                  color: hasValue ? AppTheme.emerald : Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(d['label']!, style: const TextStyle(fontSize: 12, color: Colors.black87))),
                if (hasValue)
                  _buildCopyBadge(
                    context,
                    val,
                    color: Colors.green.shade50,
                    borderColor: Colors.green.shade200,
                    textColor: Colors.green.shade800,
                    customMessage: l.compReportCopyValueTooltip(d['label']!),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      val,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Section 3c: Invoices ──────────────────────────────────────────
  Widget _buildInvoicesCard(BuildContext context, ImportFileModel file) {
    final l = context.l10n;
    return _reportCard(
      title: l.compReportSecInvoices(file.invoicesData.length),
      icon: Icons.receipt_outlined,
      iconColor: AppTheme.emerald,
      child: file.invoicesData.isEmpty
          ? Text(l.compReportNoInvoices, style: const TextStyle(color: Colors.grey, fontSize: 12))
          : Column(
              children: file.invoicesData.map((inv) {
                final rowSummary = '${inv.invoiceNo} | ${inv.invoiceType} | ${inv.amount.toStringAsFixed(2)} ${inv.currency}${inv.date != null ? " | ${inv.date}" : ""}';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: CopyableTableCell(
                    value: inv.invoiceNo,
                    rowSummary: rowSummary,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.teal.shade100),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt, size: 16, color: Colors.teal),
                          const SizedBox(width: 8),
                          _buildCopyBadge(
                            context,
                            inv.invoiceNo,
                            color: Colors.white,
                            borderColor: Colors.teal.shade200,
                            textColor: Colors.teal.shade900,
                          ),
                          const SizedBox(width: 8),
                          Text(inv.invoiceType, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          const Spacer(),
                          Text(
                            '${inv.amount.toStringAsFixed(2)} ${inv.currency}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal, fontSize: 12),
                          ),
                          if (inv.date != null) ...[
                            const SizedBox(width: 8),
                            Text(inv.date!, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ── Section 3d: Packing Lists ─────────────────────────────────────
  Widget _buildPackingListCard(BuildContext context, ImportFileModel file) {
    final l = context.l10n;
    double totalCbm = file.packingListsData.fold(0.0, (s, p) => s + p.cbm);
    double totalWeight = file.packingListsData.fold(0.0, (s, p) => s + p.grossWeightKg);
    int totalPkgs = file.packingListsData.fold(0, (s, p) => s + p.totalPackages);

    return _reportCard(
      title: l.compReportSecPackingLists(file.packingListsData.length),
      icon: Icons.inventory_2_outlined,
      iconColor: AppTheme.cobalt,
      child: file.packingListsData.isEmpty
          ? Text(l.compReportNoPackingLists, style: const TextStyle(color: Colors.grey, fontSize: 12))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary totals
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _miniStat(l.compReportTotalPackages, l.compReportPiecesUnit(totalPkgs)),
                      _miniStat(l.compReportTotalWeight, '${PoPackingMatcher.formatWeight(totalWeight)} KG'),
                      _miniStat(l.compReportTotalCbm, '${totalCbm.toStringAsFixed(2)} m³'),
                    ],
                  ),
                ),
                ...file.packingListsData.map((pl) {
                  final rowSummary = '${pl.plNo} | ${pl.totalPackages} pkgs | ${PoPackingMatcher.formatWeight(pl.grossWeightKg)} KG | ${pl.cbm.toStringAsFixed(2)} CBM';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: CopyableTableCell(
                      value: pl.plNo,
                      rowSummary: rowSummary,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.indigo.shade100),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2, size: 14, color: Colors.indigo),
                            const SizedBox(width: 6),
                            _buildCopyBadge(
                              context,
                              pl.plNo,
                              color: Colors.white,
                              borderColor: Colors.indigo.shade200,
                              textColor: Colors.indigo.shade900,
                            ),
                            const Spacer(),
                            Text(l.compReportPackagesUnit(pl.totalPackages), style: const TextStyle(fontSize: 11)),
                            const SizedBox(width: 10),
                            Text('${pl.grossWeightKg.toStringAsFixed(1)} KG', style: const TextStyle(fontSize: 11)),
                            const SizedBox(width: 10),
                            Text('${pl.cbm.toStringAsFixed(2)} CBM', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  // ── Section 3e: Status Card ───────────────────────────────────────
  Widget _buildStatusCard(BuildContext context, ImportFileModel file) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return _reportCard(
      title: l.compReportSecStatus,
      icon: Icons.timeline_outlined,
      iconColor: AppTheme.emerald,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: _priorityColor(file.priority)),
              const SizedBox(width: 6),
              Text(l.compReportPriorityPrefix(file.priority), style: TextStyle(fontWeight: FontWeight.bold, color: _priorityColor(file.priority), fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          _infoRow(context, l.compReportStatusLabel, file.status),
          _infoRow(context, l.compReportCurrentStageLabel, DisplayNameResolver.resolveStepName(file.displayStepKey, isArabic: isAr)),
          _infoRow(context, l.compReportCurrentModuleLabel, (file.codedStageLabel(l) ?? DisplayNameResolver.resolvePhaseName(file.currentModule, isArabic: isAr))),
          _infoRow(context, l.compReportNextActionLabel, file.displayNextAction(context.l10n)),
          const SizedBox(height: 10),
          Text(l.compReportTotalProgressLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: file.progressPercent / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      file.progressPercent >= 80 ? AppTheme.emerald : AppTheme.cobalt,
                    ),
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${file.progressPercent.toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section 3f: Financial Card ─────────────────────────────────────
  Widget _buildFinancialCard(BuildContext context, ImportFileModel file) {
    final l = context.l10n;
    final curr = l.compReportCurrencyUsd;
    double totalInvoicesValue = file.invoicesData.fold(0.0, (s, i) => s + i.amount);

    return _reportCard(
      title: l.compReportSecFinancial,
      icon: Icons.account_balance_outlined,
      iconColor: AppTheme.orange,
      child: Column(
        children: [
          _financialRow(l.compReportTotalInvoicesVal, '${totalInvoicesValue.toStringAsFixed(2)} $curr', Colors.teal),
          _financialRow(l.compReportEstimatedCostVal, '${file.estimatedCost.toStringAsFixed(2)} $curr', AppTheme.cobalt),
          const Divider(height: 16),
          _financialRow(l.compReportEstimatedVariance, '${(file.estimatedCost - totalInvoicesValue).toStringAsFixed(2)} $curr',
              file.estimatedCost > totalInvoicesValue ? AppTheme.orange : AppTheme.emerald),
        ],
      ),
    );
  }

  // ── Section 3g: Notes Card ─────────────────────────────────────────
  Widget _buildNotesCard(BuildContext context, ImportFileModel file) {
    final l = context.l10n;
    return _reportCard(
      title: l.compReportSecNotes,
      icon: Icons.notes_outlined,
      iconColor: AppTheme.charcoal,
      child: file.notes == null || file.notes!.isEmpty
          ? Text(l.compReportNoNotes, style: const TextStyle(color: Colors.grey, fontSize: 12))
          : Text(file.notes!, style: const TextStyle(fontSize: 12, height: 1.5)),
    );
  }

  // ── Section 4: Update Timeline ────────────────────────────────────
  Widget _buildUpdateTimeline(BuildContext context, ImportFileModel file, ShipmentUpdatesState updatesState) {
    final l = context.l10n;
    final logs = updatesState.logs;

    return _reportCard(
      title: l.compReportSecTimeline(logs.length),
      icon: Icons.history_outlined,
      iconColor: AppTheme.cobalt,
      child: logs.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text(l.compReportNoTimelineLogs, style: const TextStyle(color: Colors.grey))),
            )
          : Column(
              children: logs.map((log) {
                Color catColor;
                IconData catIcon;
                String catLabel;
                switch (log.updateCategory) {
                  case 'Phase Cost Adjustment':
                    catColor = AppTheme.orange;
                    catIcon = Icons.edit_note;
                    catLabel = l.compReportCategoryCostAdjustment;
                    break;
                  case 'Future Phase Alert':
                    catColor = AppTheme.crimson;
                    catIcon = Icons.notification_important;
                    catLabel = l.compReportCategoryFutureAlert;
                    break;
                  case 'Daily Check-in':
                    catColor = AppTheme.emerald;
                    catIcon = Icons.today;
                    catLabel = l.compReportCategoryDailyCheckIn;
                    break;
                  default:
                    catColor = AppTheme.cobalt;
                    catIcon = Icons.sticky_note_2_outlined;
                    catLabel = log.updateCategory.isEmpty ? l.compReportCategoryGeneralUpdate : log.updateCategory;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline dot
                      Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: catColor.withOpacity(0.12), shape: BoxShape.circle),
                            child: Icon(catIcon, size: 16, color: catColor),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Log Content
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: catColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(catLabel, style: TextStyle(fontSize: 10, color: catColor, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.charcoal.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _formatPhaseLabel(context, log.targetPhase),
                                      style: const TextStyle(fontSize: 10, color: AppTheme.charcoal, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(log.logDate, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  const SizedBox(width: 8),
                                  Text(l.compReportByPrefix(log.assignedUser), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(log.note, style: const TextStyle(fontSize: 12, height: 1.5, color: Colors.black87)),
                              if (log.updateCategory == 'Phase Cost Adjustment' && log.adjustedCostItem != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.orange.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.orange.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.swap_horiz, size: 14, color: AppTheme.orange),
                                      const SizedBox(width: 6),
                                      Text('${log.adjustedCostItem}: ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      Text(log.previousCost.toStringAsFixed(2), style: const TextStyle(fontSize: 11, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                                      const Text(' → ', style: TextStyle(fontSize: 11, color: AppTheme.orange)),
                                      Text('${log.newCost.toStringAsFixed(2)} ${l.compReportCurrencyUsd}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orange)),
                                    ],
                                  ),
                                ),
                              ],
                              if (log.updateCategory == 'Future Phase Alert') ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.flag, size: 13, color: AppTheme.crimson),
                                    const SizedBox(width: 4),
                                    Text(l.compReportAlertPriorityPrefix(log.alertPriority),
                                        style: const TextStyle(fontSize: 11, color: AppTheme.crimson, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────
  Widget _buildCopyBadge(
    BuildContext context,
    String text, {
    String? tooltip,
    String? customMessage,
    Color? color,
    Color? textColor,
    Color? borderColor,
  }) {
    final l = context.l10n;
    final tip = tooltip ?? l.compReportCopyValueTooltip(text);

    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => CopyHelper.copy(context, text, customMessage: customMessage),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color ?? Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor ?? Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textColor ?? AppTheme.charcoal,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.copy_rounded,
                size: 11,
                color: textColor ?? Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportCard({required String title, required IconData icon, required Color iconColor, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.06),
              borderRadius: const BorderRadiusDirectional.only(topStart: Radius.circular(10), topEnd: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: iconColor.withOpacity(0.15))),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: iconColor)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value, {bool showCopyBadge = false}) {
    final l = context.l10n;
    final hasVal = value != '—' && value.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          const Text(': ', style: TextStyle(color: Colors.grey)),
          Expanded(
            child: hasVal
                ? (showCopyBadge
                    ? Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _buildCopyBadge(context, value),
                      )
                    : CopyableTableCell(
                        value: value,
                        rowSummary: '$label: $value',
                        customMessage: l.compReportCopyValueTooltip(label),
                        child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
                      ))
                : Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _financialRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87))),
          CopyableTableCell(
            value: value,
            rowSummary: '$label: $value',
            child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildClearanceSection(BuildContext context, AsyncValue<List<CustomsClearanceModel>> state) {
    final l = context.l10n;
    return _reportCard(
      title: l.compReportSecClearance,
      icon: Icons.receipt_long_outlined,
      iconColor: AppTheme.cobalt,
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Text('${l.errorPrefix} $err', style: const TextStyle(color: AppTheme.crimson)),
        data: (list) {
          if (list.isEmpty) return Text(l.compReportNoClearanceData, style: const TextStyle(color: Colors.grey));
          final clr = list.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (clr.declaration46No != null)
                    _buildCopyBadge(
                      context,
                      clr.declaration46No!,
                      tooltip: l.compReportDeclarationChip(clr.declaration46No!),
                      color: Colors.blue.shade50,
                      borderColor: Colors.blue.shade200,
                      textColor: AppTheme.cobalt,
                    ),
                  Chip(
                    label: Text(clr.channelType, style: const TextStyle(fontSize: 12)),
                    backgroundColor: clr.channelType.toLowerCase().contains('green')
                        ? Colors.green.shade50
                        : (clr.channelType.toLowerCase().contains('red') ? Colors.red.shade50 : Colors.orange.shade50),
                  ),
                  Chip(label: Text(clr.customsOfficeName, style: const TextStyle(fontSize: 12)), backgroundColor: Colors.grey.shade100),
                ],
              ),
              const SizedBox(height: 8),
              if (clr.releasePermitNo != null)
                _buildCopyBadge(
                  context,
                  clr.releasePermitNo!,
                  tooltip: l.compReportReleasePermitChip(clr.releasePermitNo!),
                  color: AppTheme.emerald.withOpacity(0.1),
                  borderColor: AppTheme.emerald.withOpacity(0.3),
                  textColor: AppTheme.emerald,
                ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _miniStat(l.compReportDutyImport, CcFormat.fixed(clr.importDutyAmount)),
                  _miniStat(l.compReportDutyVat, CcFormat.fixed(clr.vatAmount)),
                  _miniStat(l.compReportDutySchedule, CcFormat.fixed(clr.scheduleTaxAmount)),
                  _miniStat(l.compReportDutyInspection, CcFormat.fixed(clr.labServiceFees)),
                  _miniStat(l.compReportDutyTotal, CcFormat.fixed(clr.totalDutyPayable)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (clr.paymentDate != null) Text(l.compReportPaymentDate(clr.paymentDate!), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(width: 16),
                  if (clr.releaseDate != null) Text(l.compReportReleaseDate(clr.releaseDate!), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildWarehouseSection(BuildContext context, AsyncValue<List<WarehouseReceivingModel>> state) {
    final l = context.l10n;
    return _reportCard(
      title: l.compReportSecWarehouse,
      icon: Icons.warehouse_outlined,
      iconColor: AppTheme.emerald,
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Text('${l.errorPrefix} $err', style: const TextStyle(color: AppTheme.crimson)),
        data: (list) {
          if (list.isEmpty) return Text(l.compReportNoWarehouseData, style: const TextStyle(color: Colors.grey));
          final wh = list.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildCopyBadge(
                    context,
                    wh.grnCode,
                    tooltip: l.compReportGrnChip(wh.grnCode),
                    color: AppTheme.charcoal.withOpacity(0.1),
                    borderColor: AppTheme.charcoal.withOpacity(0.3),
                    textColor: AppTheme.charcoal,
                  ),
                  const SizedBox(width: 16),
                  Text(wh.warehouseName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(l.compReportArrivalDatetime(wh.arrivalDatetime), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(width: 16),
                  Text(l.compReportInspectorPrefix(wh.inspectorName), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _miniStat(l.compReportQtyInvoiced, wh.totalInvoicedQty.toString()),
                  _miniStat(l.compReportQtyAccepted, wh.totalAcceptedQty.toString()),
                  _miniStat(l.compReportQtyShortage, wh.totalShortageQty.toString()),
                  _miniStat(l.compReportQtyDamaged, wh.totalDamagedQty.toString()),
                ],
              ),
              const SizedBox(height: 12),
              if (wh.grnItems.isNotEmpty)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 32,
                    dataRowMaxHeight: 32,
                    columnSpacing: 16,
                    columns: [
                      DataColumn(label: Text(l.compReportTableColCode, style: const TextStyle(fontSize: 11))),
                      DataColumn(label: Text(l.compReportTableColItem, style: const TextStyle(fontSize: 11))),
                      DataColumn(label: Text(l.compReportTableColInvoiced, style: const TextStyle(fontSize: 11))),
                      DataColumn(label: Text(l.compReportTableColAccepted, style: const TextStyle(fontSize: 11))),
                      DataColumn(label: Text(l.compReportTableColShortage, style: const TextStyle(fontSize: 11))),
                      DataColumn(label: Text(l.compReportTableColDamaged, style: const TextStyle(fontSize: 11))),
                    ],
                    rows: wh.grnItems.map((item) {
                      final rowSummary = '${item.itemCode} | ${item.itemName} | Invoiced: ${item.invoicedQty} | Accepted: ${item.acceptedQty} | Shortage: ${item.shortageQty} | Damaged: ${item.damagedQty}';
                      return DataRow(cells: [
                        DataCell(CopyableTableCell(
                          value: item.itemCode,
                          rowSummary: rowSummary,
                          child: Text(item.itemCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        )),
                        DataCell(CopyableTableCell(
                          value: item.itemName,
                          rowSummary: rowSummary,
                          child: Text(item.itemName, style: const TextStyle(fontSize: 11)),
                        )),
                        DataCell(CopyableTableCell(
                          value: item.invoicedQty.toString(),
                          rowSummary: rowSummary,
                          child: Text(item.invoicedQty.toString(), style: const TextStyle(fontSize: 11)),
                        )),
                        DataCell(CopyableTableCell(
                          value: item.acceptedQty.toString(),
                          rowSummary: rowSummary,
                          child: Text(item.acceptedQty.toString(), style: const TextStyle(fontSize: 11)),
                        )),
                        DataCell(CopyableTableCell(
                          value: item.shortageQty.toString(),
                          rowSummary: rowSummary,
                          child: Text(item.shortageQty.toString(), style: const TextStyle(fontSize: 11)),
                        )),
                        DataCell(CopyableTableCell(
                          value: item.damagedQty.toString(),
                          rowSummary: rowSummary,
                          child: Text(item.damagedQty.toString(), style: const TextStyle(fontSize: 11)),
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
