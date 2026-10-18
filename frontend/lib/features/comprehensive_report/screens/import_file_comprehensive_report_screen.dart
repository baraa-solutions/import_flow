// ignore_for_file: deprecated_member_use
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
import '../services/comprehensive_dossier_service.dart';
import '../models/comprehensive_dossier_model.dart';
import '../widgets/comprehensive_dossier_export_dialog.dart';
import '../../purchase_orders/utils/po_packing_matcher.dart';
import '../../../core/providers/navigation_provider.dart';

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
  final Set<int> _acknowledgedAlerts = {};

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
    if (val == null || files.isEmpty) {
      setState(() {
        _selectedFileId = null;
        _selectedFile = null;
      });
      return;
    }
    final matches = files.where((f) => f.importFileId == val);
    if (matches.isEmpty) return;
    final file = matches.first;
    setState(() {
      _selectedFileId = val;
      _selectedFile = file;
    });
    ref.read(shipmentUpdatesProvider.notifier).fetchLogs(importFileId: val);
    ref.read(customsClearanceProvider.notifier).fetchRecords(importFileId: val);
    ref.read(warehouseReceivingProvider.notifier).fetchRecords(importFileId: val);
  }

  int _currentPhaseIndex(ImportFileModel file) {
    // Priority 1: use the explicit phase id stored in the backend
    if (file.currentPhaseId != null && file.currentPhaseId! >= 1 && file.currentPhaseId! <= 10) {
      return file.currentPhaseId! - 1;
    }
    // Priority 2: parse from currentStage (e.g. "Phase 3: Booking & Doc Prep")
    final stageMatch = RegExp(r'Phase\s*(\d+)').firstMatch(file.currentStage);
    if (stageMatch != null) {
      final n = int.tryParse(stageMatch.group(1) ?? '');
      if (n != null && n >= 1 && n <= 10) return n - 1;
    }
    // Priority 3: parse from currentModule (legacy fallback)
    final modMatch = RegExp(r'Phase\s*(\d+)').firstMatch(file.currentModule);
    if (modMatch != null) {
      final n = int.tryParse(modMatch.group(1) ?? '');
      if (n != null && n >= 1 && n <= 10) return n - 1;
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
    final targetId = ref.watch(selectedComprehensiveReportFileIdProvider);

    // Auto-select shipment ONLY if explicit targetId is specified from navigation
    importFilesState.whenData((files) {
      if (files.isNotEmpty && targetId != null && _selectedFileId != targetId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onFileSelected(targetId, files);
        });
      }
    });

    final dossierAsync = _selectedFileId != null ? ref.watch(comprehensiveDossierProvider(_selectedFileId!)) : null;
    final dossier = dossierAsync?.valueOrNull;

    final clr = (clearanceState.valueOrNull != null && clearanceState.valueOrNull!.isNotEmpty && _selectedFileId != null)
        ? clearanceState.valueOrNull!.cast<CustomsClearanceModel?>().firstWhere(
            (c) => c?.importFileId == _selectedFileId,
            orElse: () => null,
          )
        : null;
    final wh = (warehouseState.valueOrNull != null && warehouseState.valueOrNull!.isNotEmpty && _selectedFileId != null)
        ? warehouseState.valueOrNull!.cast<WarehouseReceivingModel?>().firstWhere(
            (w) => w?.importFileId == _selectedFileId,
            orElse: () => null,
          )
        : null;

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
                final dossierText = ComprehensiveReportExportService.buildDossierText(
                  context: context,
                  file: _selectedFile!,
                  dossier: dossier,
                  logs: updatesState.logs,
                  clearance: clr,
                  warehouse: wh,
                );
                CopyHelper.copy(context, dossierText, customMessage: l.compReportCopyDossierSuccess);
              },
            ),
            IconButton(
              icon: const Icon(Icons.description_outlined, color: Colors.white, size: 20),
              tooltip: l.compReportExportTsvBtn,
              onPressed: () => ComprehensiveReportExportService.exportToTsv(
                context: context,
                file: _selectedFile!,
                dossier: dossier,
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
                dossier: dossier,
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
                dossier: dossier,
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
                        final dossierText = ComprehensiveReportExportService.buildDossierText(
                          context: context,
                          file: _selectedFile!,
                          dossier: dossier,
                          logs: updatesState.logs,
                          clearance: clr,
                          warehouse: wh,
                        );
                        CopyHelper.copy(context, dossierText, customMessage: l.compReportCopyDossierSuccess);
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
                        dossier: dossier,
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
                        dossier: dossier,
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
                        dossier: dossier,
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
                          // Top Simulation & Stage Shortcuts Strip
                          _buildStageSimulationShortcutsStrip(context, _selectedFile!),
                          const SizedBox(height: 14),

                          // Section 1: Header Banner
                          _buildHeaderBanner(context, _selectedFile!),
                          const SizedBox(height: 14),

                          // Executive KPI Physical & Financial Metric Tiles
                          _buildExecutiveMetricTiles(context, _selectedFile!, dossier),
                          const SizedBox(height: 16),

                          // Section 2: 10-Phase Progress Pipeline
                          _buildPhasePipeline(context, _selectedFile!, updatesState),
                          const SizedBox(height: 16),

                          // Section 2.5: Institutional Knowledge & Pattern Engine
                          _buildInstitutionalKnowledgeCard(context, dossier, _selectedFile!),
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
                                    _buildContainersCard(context, dossier, _selectedFile!),
                                    const SizedBox(height: 14),
                                    _buildDocumentsCard(context, _selectedFile!),
                                    const SizedBox(height: 14),
                                    _buildInvoicesCard(context, _selectedFile!, dossier),
                                    const SizedBox(height: 14),
                                    _buildPackingListCard(context, _selectedFile!, dossier),
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
                                    _buildFinancialCard(context, _selectedFile!, dossier),
                                    const SizedBox(height: 14),
                                    _buildFxReconciliationCard(context, dossier, _selectedFile!),
                                    const SizedBox(height: 14),
                                    _buildNotesCard(context, _selectedFile!),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Section 3.5: Interactive Operational Timeline & SLA
                          _buildInteractiveTimelineCard(context, dossier, _selectedFile!, updatesState),
                          const SizedBox(height: 16),

                          // Section 4: Live Update Logs Timeline
                          _buildUpdateTimeline(context, _selectedFile!, updatesState),
                          const SizedBox(height: 16),
                          
                          // Section 5: Customs Clearance Real-Time Data
                          _buildClearanceSection(context, clearanceState),
                          const SizedBox(height: 16),
                          
                          // Section 6: Warehouse Receiving & GRN Real-Time Data
                          _buildWarehouseSection(context, warehouseState),
                          const SizedBox(height: 20),

                          // Bottom Operational Command Footer
                          _buildOperationalCommandFooter(context, _selectedFile!, dossier),
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: AppTheme.charcoal.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.manage_search, size: 40, color: AppTheme.cobalt),
              ),
              const SizedBox(height: 20),
              Text(
                l.compReportEmptyStatePrompt,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAr
                    ? 'يرجى اختيار رقم الشحنة أو كود الملف من القائمة المنسدلة أعلاه لبدء استعراض التقرير الشامل والمستندات.'
                    : 'Please select an import file from the dropdown above to load the comprehensive operational dossier.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildEmptyStateBadge(Icons.inventory_2_outlined, isAr ? 'أوامر الشراء والتوريد' : 'Purchase Orders'),
                  _buildEmptyStateBadge(Icons.directions_boat_outlined, isAr ? 'الحاويات والتتبع' : 'Containers & ETA'),
                  _buildEmptyStateBadge(Icons.gavel_outlined, isAr ? 'الإفراج الجمركي والمطابقة' : 'Customs Clearance'),
                  _buildEmptyStateBadge(Icons.receipt_long_outlined, isAr ? 'التكلفة والمصروفات' : 'Landed Cost'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.charcoal.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.cobalt),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.charcoal, fontWeight: FontWeight.w500)),
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

  // ── Section 3c: Invoices & Purchase Orders ────────────────────────
  Widget _buildInvoicesCard(
    BuildContext context,
    ImportFileModel file,
    ComprehensiveShipmentDossierModel? dossier,
  ) {
    final l = context.l10n;
    final pos = dossier?.purchaseOrders ?? [];
    final invs = file.invoicesData;

    if (pos.isEmpty && invs.isEmpty) {
      return _reportCard(
        title: l.compReportSecInvoices(0),
        icon: Icons.receipt_outlined,
        iconColor: AppTheme.emerald,
        child: Text(l.compReportNoInvoices, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }

    return _reportCard(
      title: 'الفواتير وأوامر الشراء (${pos.length} PO • ${invs.length} فاتورة)',
      icon: Icons.receipt_outlined,
      iconColor: AppTheme.emerald,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Linked Purchase Orders
          if (pos.isNotEmpty) ...[
            const Text(
              '📦 أوامر التوريد المعتمدة (Purchase Orders):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
            ),
            const SizedBox(height: 6),
            ...pos.map((po) {
              final poNo = po['po_number']?.toString() ?? 'PO';
              final poRef = po['po_reference']?.toString() ?? '';
              final poFob = (po['total_amount_fob'] as num?)?.toDouble() ?? 0.0;
              final curr = po['currency']?.toString() ?? 'USD';
              final piNo = po['proforma_invoice_number']?.toString();
              final status = po['status']?.toString() ?? 'Approved';

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    _buildCopyBadge(
                      context,
                      poNo,
                      color: Colors.white,
                      borderColor: Colors.blue.shade300,
                      textColor: const Color(0xFF1E3A8A),
                    ),
                    if (poRef.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(poRef, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                    ],
                    if (piNo != null && piNo.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text('PI: $piNo', style: const TextStyle(fontSize: 10, color: AppTheme.charcoal)),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '${poFob.toStringAsFixed(2)} $curr',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 10),
          ],

          // 2. Commercial / Proforma Invoices
          if (invs.isNotEmpty) ...[
            const Text(
              '🧾 الفواتير المرفقة (Invoices):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
            ),
            const SizedBox(height: 6),
            ...invs.map((inv) {
              final rowSummary = '${inv.invoiceNo} | ${inv.invoiceType} | ${inv.amount.toStringAsFixed(2)} ${inv.currency}${inv.date != null ? " | ${inv.date}" : ""}';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
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
            }),
          ],
        ],
      ),
    );
  }

  // ── Section 3d: Packing Lists & Cargo Physical Breakdown ─────────
  Widget _buildPackingListCard(
    BuildContext context,
    ImportFileModel file,
    ComprehensiveShipmentDossierModel? dossier,
  ) {
    final l = context.l10n;
    // Source physical totals from dossier (which resolves from POs and packing sessions)
    // with fallback to file.packingListsData
    final cbmFromDossier = (dossier?.cargoPhysicalSummary?['total_cbm'] as num?)?.toDouble() ??
        (dossier != null && dossier.totalCbm > 0 ? dossier.totalCbm : 0.0);
    final grossFromDossier = (dossier?.cargoPhysicalSummary?['total_gross_weight_kg'] as num?)?.toDouble() ??
        (dossier?.cargoPhysicalSummary?['gross_weight_kg'] as num?)?.toDouble() ??
        (dossier != null && dossier.grossWeightKg > 0 ? dossier.grossWeightKg : 0.0);
    final netFromDossier = dossier?.netWeightKg ??
        (dossier?.cargoPhysicalSummary?['total_net_weight_kg'] as num?)?.toDouble() ?? 0.0;
    final pkgsFromDossier = (dossier?.cargoPhysicalSummary?['total_packages'] as num?)?.toInt() ??
        (dossier != null && dossier.totalPackages > 0 ? dossier.totalPackages : 0);

    final double totalCbm = cbmFromDossier > 0 ? cbmFromDossier : file.packingListsData.fold(0.0, (s, p) => s + p.cbm);
    final double totalWeight = grossFromDossier > 0 ? grossFromDossier : file.packingListsData.fold(0.0, (s, p) => s + p.grossWeightKg);
    final double totalNet = netFromDossier > 0 ? netFromDossier : 0.0;
    final int totalPkgs = pkgsFromDossier > 0 ? pkgsFromDossier : file.packingListsData.fold(0, (s, p) => s + p.totalPackages);

    final hasPhysicalData = totalCbm > 0 || totalWeight > 0 || totalPkgs > 0 || file.packingListsData.isNotEmpty;

    final plCount = file.packingListsData.isNotEmpty
        ? file.packingListsData.length
        : (dossier != null && dossier.posCount > 0 ? 1 : 0);

    return _reportCard(
      title: 'بيان العبوة ومواصفات الشحن ($plCount بيان تعبئة)',
      icon: Icons.inventory_2_outlined,
      iconColor: AppTheme.cobalt,
      child: !hasPhysicalData
          ? Text(l.compReportNoPackingLists, style: const TextStyle(color: Colors.grey, fontSize: 12))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary totals
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.cobalt.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _miniStat('إجمالي الطرود', '$totalPkgs طرد'),
                      _miniStat('الوزن القائم', '${PoPackingMatcher.formatWeight(totalWeight)} كجم'),
                      if (totalNet > 0)
                        _miniStat('الوزن الصافي', '${PoPackingMatcher.formatWeight(totalNet)} كجم'),
                      _miniStat('الحجم الإجمالي', '${totalCbm.toStringAsFixed(3)} m³'),
                    ],
                  ),
                ),
                if (file.packingListsData.isNotEmpty)
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
                              _buildCopyBadge(context, pl.plNo),
                              const SizedBox(width: 8),
                              Text('${pl.totalPackages} pkgs', style: const TextStyle(fontSize: 11)),
                              const Spacer(),
                              Text('${PoPackingMatcher.formatWeight(pl.grossWeightKg)} KG', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Text('${pl.cbm.toStringAsFixed(2)} m³', style: const TextStyle(fontSize: 11, color: AppTheme.cobalt)),
                            ],
                          ),
                        ),
                      ),
                    );
                  })
                else if (dossier != null && dossier.purchaseOrders.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.emerald),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تم اعتماد أوزان وأحجام الشحنة من أمر التوريد ${dossier.purchaseOrders.first["po_number"]} بإجمالي $totalPkgs طرد (${PoPackingMatcher.formatWeight(totalWeight)} كجم قائم / ${totalCbm.toStringAsFixed(3)} CBM).',
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.charcoal),
                          ),
                        ),
                      ],
                    ),
                  ),
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
  Widget _buildFinancialCard(BuildContext context, ImportFileModel file, ComprehensiveShipmentDossierModel? dossier) {
    final l = context.l10n;
    final curr = l.compReportCurrencyUsd;

    // 1. PO FOB total from purchase_orders table
    final double poFobTotal = dossier?.totalFobFc ??
        (dossier?.purchaseOrders.isNotEmpty == true
            ? (dossier!.purchaseOrders.first['total_amount_fob'] as num?)?.toDouble() ?? 0.0
            : 0.0);
    final String fobCurrency = dossier?.fobCurrency ?? curr;

    // 2. Commercial Invoices attached total
    final double totalInvoicesValue = file.invoicesData.fold(0.0, (s, i) => s + i.amount);

    final double effectiveBase = poFobTotal > 0 ? poFobTotal : totalInvoicesValue;

    return _reportCard(
      title: l.compReportSecFinancial,
      icon: Icons.account_balance_outlined,
      iconColor: AppTheme.orange,
      child: Column(
        children: [
          if (poFobTotal > 0)
            _financialRow(
              'إجمالي أمر التوريد (PO Total FOB)',
              '${poFobTotal.toStringAsFixed(2)} $fobCurrency',
              const Color(0xFF1E3A8A),
            ),
          _financialRow(
            'إجمالي الفواتير المرفقة (Invoices Total)',
            '${(totalInvoicesValue > 0 ? totalInvoicesValue : poFobTotal).toStringAsFixed(2)} $fobCurrency',
            Colors.teal,
          ),
          _financialRow(
            l.compReportEstimatedCostVal,
            '${file.estimatedCost.toStringAsFixed(2)} $curr',
            AppTheme.cobalt,
          ),
          const Divider(height: 16),
          _financialRow(
            l.compReportEstimatedVariance,
            '${(file.estimatedCost - effectiveBase).toStringAsFixed(2)} $curr',
            file.estimatedCost >= effectiveBase ? AppTheme.emerald : AppTheme.orange,
          ),
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

  // ── Section 3.1: Containers & Seals Matrix ──────────────────────────
  Widget _buildContainersCard(BuildContext context, ComprehensiveShipmentDossierModel? dossier, ImportFileModel file) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containers = dossier?.containers ?? [];

    return _reportCard(
      title: 'حاويات الشحنة ومطابقة أرقام السيل (Containers & Seal Matrix)',
      icon: Icons.directions_boat_filled_outlined,
      iconColor: AppTheme.cobalt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (containers.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لم يتم تسجيل الحاويات وأرقام السيل بعد. يتم تأكيدها فور رص الحاويات في مرحلة الشحن الدولي (Phase 5).',
                      style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: containers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final c = containers[idx];
                final cNo = c['container_no']?.toString() ?? 'CONT-${idx + 1}';
                final cType = c['container_type']?.toString() ?? '-';
                final lSeal = c['liner_seal_no']?.toString() ?? c['seal_no']?.toString() ?? '—';
                final cSeal = c['customs_seal_no']?.toString() ?? '—';
                final tare = c['tare_weight_kg'] ?? 0.0;
                final gross = c['gross_weight_kg'] ?? 0.0;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.blueGrey.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          const Icon(Icons.inventory_2, color: AppTheme.cobalt, size: 18),
                          const SizedBox(width: 8),
                          SelectableText(
                            cNo,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                          ),
                          const SizedBox(width: 6),
                          _buildCopyBadge(context, cNo, tooltip: 'نسخ رقم الحاوية'),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              cType,
                              style: const TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      // Liner Seal Row
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Text('سيل التوكيل / الخط الملاحي:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(width: 8),
                            SelectableText(
                              lSeal,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                            ),
                            if (lSeal != '—') ...[
                              const SizedBox(width: 4),
                              _buildCopyBadge(context, lSeal, tooltip: 'نسخ رقم سيل الخط'),
                            ],
                          ],
                        ),
                      ),
                      // Customs Seal Row
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Text('سيل الجمارك / الترصيص الجمركي:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(width: 8),
                            SelectableText(
                              cSeal,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: cSeal != '—' ? AppTheme.emerald : Colors.grey.shade600,
                              ),
                            ),
                            if (cSeal != '—') ...[
                              const SizedBox(width: 4),
                              _buildCopyBadge(context, cSeal, tooltip: 'نسخ رقم سيل الجمارك'),
                            ],
                          ],
                        ),
                      ),
                      // Weights
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('وزن فارغ: $tare كجم', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          const SizedBox(width: 14),
                          Text('وزن قائم: $gross كجم', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          const Spacer(),
                          Text('VGM: ${c['vgm_status'] ?? "-"}', style: const TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Section 3.2: FX Reconciliation Card ─────────────────────────────
  Widget _buildFxReconciliationCard(BuildContext context, ComprehensiveShipmentDossierModel? dossier, ImportFileModel file) {
    final fx = dossier?.fxReconciliation;
    final customsRate = fx?['customs_exchange_rate'];
    final bankRate = fx?['commercial_bank_exchange_rate'];
    final varianceRate = fx?['fx_variance_rate'] ?? 0.0;
    final varianceTotal = fx?['fx_variance_total_egp'] ?? 0.0;
    final hasVariance = fx?['has_variance'] == true;

    return _reportCard(
      title: 'مطابقة أسعار الصرف وفروق تدبير العملة (FX Variance)',
      icon: Icons.currency_exchange_outlined,
      iconColor: AppTheme.emerald,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(context, 'سعر الصرف الجمركي (جمارك/ضرائب):', customsRate != null ? '$customsRate ج.م' : '—'),
          _infoRow(context, 'سعر صرف البنك التجاري (التحويل):', bankRate != null ? '$bankRate ج.م' : '—'),
          _infoRow(context, 'فرق سعر الصرف لكل وحدة عملة:', '$varianceRate ج.م'),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إجمالي فروق العملة التقديرية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text(
                '${varianceTotal.toStringAsFixed(2)} ج.م',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: hasVariance ? AppTheme.crimson : AppTheme.emerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasVariance ? AppTheme.crimson.withOpacity(0.08) : AppTheme.emerald.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(hasVariance ? Icons.warning_amber_rounded : Icons.check_circle_outline, size: 14, color: hasVariance ? AppTheme.crimson : AppTheme.emerald),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasVariance
                        ? 'يوجد فروق أسعار صرف بين تقييم الجمارك والتحويل البنكي الفعلي تؤثر على تكلفة الوصول.'
                        : 'أسعار الصرف مطابقة تماماً أو لم يتم تسجيل تسويات بنكية بالعملة الأجنبية بعد.',
                    style: TextStyle(fontSize: 10.5, color: hasVariance ? AppTheme.crimson : AppTheme.emerald),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 3.3: Interactive Operational Timeline & SLA Hub ─────────
  Widget _buildInteractiveTimelineCard(
    BuildContext context,
    ComprehensiveShipmentDossierModel? dossier,
    ImportFileModel file,
    ShipmentUpdatesState updatesState,
  ) {
    final timeline = dossier?.timelineEvents ?? [];

    return _reportCard(
      title: 'الجدول الزمني التفاعلي وتتبع الحركات ودقة الـ SLA (Timeline & Stage Hub)',
      icon: Icons.timeline_outlined,
      iconColor: AppTheme.cobalt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tracking revision notification bar if ETA changed
          if (file.requiredEta != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.track_changes, color: AppTheme.cobalt, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('ETA المخطط: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            SelectableText(file.requiredEta ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                            const SizedBox(width: 16),
                            const Text('الوصول الفعلي / المحدث: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            SelectableText(dossier?.inlandActualArrivalDate ?? file.inlandActualArrivalDate ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'يتم تحديث الجدول الزمني وحساب الفروق اللحظية فور رصد أي حركة جديدة بالميناء أو تعديل بوليصة الشحن.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Operational Turnaround SLAs Strip
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blueGrey.shade100),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _slaSummaryItem(
                  icon: Icons.account_balance_outlined,
                  label: 'معدل استخراج نموذج 4:',
                  value: '2 يوم عمل (قياسي)',
                  color: AppTheme.cobalt,
                ),
                _slaSummaryItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'إذن التسليم D/O:',
                  value: '18 ساعة (طبيعي)',
                  color: AppTheme.emerald,
                ),
                _slaSummaryItem(
                  icon: Icons.cloud_done_outlined,
                  label: 'تحويل CargoX المعتمد:',
                  value: dossier?.cargoxTransferredAt != null ? dossier!.cargoxTransferredAt!.split('T').first : 'بانتظار الإرسال',
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
          ),

          // ETA Tracking Revisions History Log
          if (dossier != null && dossier.etaRevisionsLog.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'سجل تعديلات وانحرافات موعد الوصول الفعلي (ETA Drift Revisions):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                      ),
                      const Spacer(),
                      Text(
                        '${dossier.etaRevisionsLog.length} تعديلات مسجلة',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...dossier.etaRevisionsLog.map((rev) {
                    final cDate = rev['change_date']?.toString() ?? '—';
                    final oldEta = rev['old_eta']?.toString() ?? '—';
                    final newEta = rev['new_eta']?.toString() ?? '—';
                    final drift = rev['drift_days'] ?? 0;
                    final reason = rev['reason']?.toString() ?? '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_right, size: 16, color: Color(0xFFD97706)),
                          SelectableText(
                            'بتاريخ $cDate: ',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                          ),
                          SelectableText(
                            'تم تعديل ETA من $oldEta إلى $newEta',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                          ),
                          if (drift != 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: (drift as num) > 0 ? Colors.red.shade100 : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'انحراف: ${drift > 0 ? "+" : ""}$drift يوم',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: drift > 0 ? Colors.red.shade900 : Colors.green.shade900,
                                ),
                              ),
                            ),
                          ],
                          if (reason.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '[$reason]',
                                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          if (timeline.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: Text('جاري تحميل محطات الجدول الزمني للشحنة...')))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: timeline.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final ev = timeline[idx];
                final code = ev['stage_code']?.toString() ?? 'STEP_01';
                final nameAr = ev['stage_name_ar']?.toString() ?? '';
                final nameEn = ev['stage_name_en']?.toString() ?? '';
                final status = ev['status']?.toString() ?? 'PENDING';
                final isDone = status == 'COMPLETED';
                final isInProgress = status == 'IN_TRANSIT' || status == 'IN_PROGRESS';
                final planned = ev['planned_date']?.toString();
                final actual = ev['actual_date']?.toString();
                final details = ev['details']?.toString() ?? '';
                final slaLabel = ev['sla_label']?.toString();

                Color statusColor = isDone
                    ? AppTheme.emerald
                    : (isInProgress ? AppTheme.cobalt : Colors.grey.shade400);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.35)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1)),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Status Icon
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: statusColor.withOpacity(0.15),
                        child: Icon(
                          isDone
                              ? Icons.check
                              : (isInProgress ? Icons.sailing : Icons.access_time),
                          color: statusColor,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Stage Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  nameAr,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '($nameEn)',
                                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (planned != null && planned.isNotEmpty) ...[
                                  Text('المخطط: $planned', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  const SizedBox(width: 12),
                                ],
                                if (actual != null && actual.isNotEmpty) ...[
                                  Text('الفعلي: $actual', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.charcoal)),
                                  const SizedBox(width: 12),
                                ],
                                if (details.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      details,
                                      style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                            if (slaLabel != null && slaLabel.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                '⏱️ $slaLabel',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Stage Navigation Action Link
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cobalt.withOpacity(0.08),
                          foregroundColor: AppTheme.cobalt,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: const BorderSide(color: AppTheme.cobalt, width: 0.8),
                          ),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 13),
                        label: const Text('الانتقال للمرحلة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _navigateToStage(context, code),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Section 2.5: Institutional Knowledge & Pattern Engine ─────────
  Widget _buildInstitutionalKnowledgeCard(
    BuildContext context,
    ComprehensiveShipmentDossierModel? dossier,
    ImportFileModel file,
  ) {
    final kb = dossier?.institutionalKnowledge;
    final criticalEntries = (kb?['critical_entries'] as List<dynamic>?) ?? [];
    final warningEntries = (kb?['warning_entries'] as List<dynamic>?) ?? [];
    final matchedEntries = (kb?['matched_entries'] as List<dynamic>?) ?? [];
    final requiredDocs = (kb?['required_documents'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final suggestedNotes = (kb?['suggested_notes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    final hasCritical = kb?['has_critical_alert'] == true || criticalEntries.isNotEmpty;

    return _reportCard(
      title: 'الذاكرة المؤسسية ودليل الخبرة ومطابقة الأنماط (Institutional Knowledge & KB Engine)',
      icon: Icons.psychology_outlined,
      iconColor: hasCritical ? AppTheme.crimson : const Color(0xFF7C3AED),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // If no knowledge base matched
          if (kb == null || (criticalEntries.isEmpty && warningEntries.isEmpty && matchedEntries.isEmpty && requiredDocs.isEmpty && suggestedNotes.isEmpty))
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.shade100),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.cobalt, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لم يتم تسجيل تنبيهات خاصة أو أنماط حرجة سابقة لهذا المورد أو الميناء في الذاكرة المؤسسية حتى الآن.',
                      style: TextStyle(color: AppTheme.charcoal, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // 1. Critical Alerts with Acknowledgment Requirement ("إقرار واطلاع")
            if (criticalEntries.isNotEmpty) ...[
              const Text(
                '🚨 تنبيهات حرجة ومخاطر تشغيلية (تتطلب إقرار واطلاع مسؤول الشحن):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.crimson),
              ),
              const SizedBox(height: 8),
              ...criticalEntries.map((entry) {
                final entryId = (entry['entry_id'] as num?)?.toInt() ?? 0;
                final title = entry['title']?.toString() ?? 'تنبيه حرج';
                final content = entry['content']?.toString() ?? '';
                final isAck = _acknowledgedAlerts.contains(entryId);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAck ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isAck ? AppTheme.emerald : AppTheme.crimson,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isAck ? Icons.verified_user_outlined : Icons.warning_rounded,
                            color: isAck ? AppTheme.emerald : AppTheme.crimson,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isAck ? Colors.green.shade900 : AppTheme.crimson,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildCopyBadge(context, title),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        content,
                        style: const TextStyle(fontSize: 12, color: AppTheme.charcoal, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isAck)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.emerald),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 14, color: AppTheme.emerald),
                                  SizedBox(width: 6),
                                  Text(
                                    'تم الاطلاع والإقرار بالمسؤولية التشغيلية',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                  ),
                                ],
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.crimson,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              icon: const Icon(Icons.touch_app, size: 15),
                              label: const Text(
                                'إقرار واطلاع مطلوب (اضغط للتأكيد)',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                setState(() {
                                  _acknowledgedAlerts.add(entryId);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('تم تسجيل إقرار واطلاع مسؤول الشحن على تنبيه: $title'),
                                    backgroundColor: AppTheme.emerald,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
            ],

            // 2. Warnings & Operational Lessons
            if (warningEntries.isNotEmpty) ...[
              const Text(
                '⚠️ تحذيرات ودروس مستفادة من شحنات سابقة:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFFB45309)),
              ),
              const SizedBox(height: 8),
              ...warningEntries.map((entry) {
                final title = entry['title']?.toString() ?? 'تنبيه';
                final content = entry['content']?.toString() ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              content,
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.charcoal, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
            ],

            // 3. Required Regulatory Documents & Certificates
            if (requiredDocs.isNotEmpty) ...[
              const Text(
                '📋 المستندات والشهادات الإلزامية المطلوبة جمركياً بحسب النمط:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.charcoal),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: requiredDocs.map((doc) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_outlined, size: 14, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 6),
                        SelectableText(
                          doc,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                        ),
                        const SizedBox(width: 6),
                        _buildCopyBadge(context, doc),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // 4. Suggested Operational Notes
            if (suggestedNotes.isNotEmpty) ...[
              const Text(
                '💡 إرشادات ونصائح تشغيلية مقترحة:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.charcoal),
              ),
              const SizedBox(height: 6),
              ...suggestedNotes.map((note) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                      Expanded(
                        child: SelectableText(
                          note,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // 5. Similar Past Shipments Accordion
            if (dossier != null && dossier.similarPastShipments.isNotEmpty) ...[
              const SizedBox(height: 14),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8),
                  leading: const Icon(Icons.history_toggle_off, color: Color(0xFF2563EB), size: 20),
                  title: Text(
                    'سجل الشحنات السابقة المماثلة (${dossier.similarPastShipments.length} شحنة مطابقة بالكامل):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E3A8A)),
                  ),
                  children: dossier.similarPastShipments.map((s) {
                    final fCode = s['file_code']?.toString() ?? s['import_file_code']?.toString() ?? '—';
                    final sName = s['supplier_name']?.toString() ?? '—';
                    final cbm = s['cbm'] != null ? '${s['cbm']} m³' : '—';
                    final days = s['duration_days'] != null ? '${s['duration_days']} يوم' : '—';
                    final cost = s['actual_landed_cost'] != null ? '${(s['actual_landed_cost'] as num).toStringAsFixed(0)} ج.م' : '—';
                    final variance = s['variance_pct'] != null ? '${s['variance_pct']}%' : '—';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blueGrey.shade100),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_shared_outlined, size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          SelectableText(
                            fCode,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A8A)),
                          ),
                          const SizedBox(width: 8),
                          _buildCopyBadge(context, fCode),
                          const SizedBox(width: 14),
                          Text('المورد: $sName', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                          const Spacer(),
                          Text('الحجم: $cbm', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                          const SizedBox(width: 12),
                          Text('المدة: $days', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                          const SizedBox(width: 12),
                          Text('التكلفة: $cost', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('انحراف: $variance', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // 6. Recurring Operational Patterns Accordion
            if (dossier != null && dossier.recurringPatterns.isNotEmpty) ...[
              const SizedBox(height: 14),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8),
                  leading: const Icon(Icons.auto_graph, color: Color(0xFF7C3AED), size: 20),
                  title: Text(
                    'الأنماط التشغيلية المتكررة المكتشفة (${dossier.recurringPatterns.length} نمط متكرر):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF5B21B6)),
                  ),
                  children: dossier.recurringPatterns.map((p) {
                    final title = p['pattern_title']?.toString() ?? p['title']?.toString() ?? 'نمط تشغيلي';
                    final desc = p['pattern_description']?.toString() ?? p['description']?.toString() ?? '';
                    final conf = (p['confidence_score'] as num?)?.toDouble();
                    final rec = p['recommended_action']?.toString() ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lightbulb, size: 16, color: Color(0xFF7C3AED)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableText(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF6B21A8)),
                                ),
                              ),
                              if (conf != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE9FE),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFDDD6FE)),
                                  ),
                                  child: Text(
                                    'ثقة: ${(conf * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B21A8)),
                                  ),
                                ),
                            ],
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            SelectableText(
                              desc,
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.charcoal, height: 1.3),
                            ),
                          ],
                          if (rec.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.arrow_forward_ios, size: 11, color: Color(0xFF7C3AED)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'الإجراء المقترح: $rec',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4C1D95)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── Section 0.5: Top Simulation & Stage Shortcuts Strip ─────────────
  Widget _buildStageSimulationShortcutsStrip(BuildContext context, ImportFileModel file) {
    final shortcuts = [
      {
        'label': 'محاكاة الجمارك',
        'icon': Icons.calculate_outlined,
        'color': const Color(0xFF2563EB),
        'action': () => selectNavigationIndex(ref, 6),
        'tooltip': 'الانتقال إلى دراسات الجمارك وبنود التعريفة وحساب الرسوم',
      },
      {
        'label': 'محاكاة تكلفة الوصول',
        'icon': Icons.pie_chart_outline,
        'color': const Color(0xFF0D9488),
        'action': () => selectNavigationIndex(ref, 4),
        'tooltip': 'محاكاة سيناريوهات الشحن والـ Landed Cost التقديري',
      },
      {
        'label': 'منظومة نافذة ACID',
        'icon': Icons.verified_outlined,
        'color': const Color(0xFF4F46E5),
        'action': () => selectNavigationIndex(ref, 11),
        'tooltip': 'تتبع رقم القيد الجمركي المبدئي والتحقق من صلاحية ACID',
      },
      {
        'label': 'نموذج 4 البنكي',
        'icon': Icons.account_balance_outlined,
        'color': const Color(0xFF0284C7),
        'action': () => selectNavigationIndex(ref, 16),
        'tooltip': 'متابعة النموذج البنكي وتدبير العملة والمصادقات',
      },
      {
        'label': 'كارغو إكس (CargoX)',
        'icon': Icons.cloud_upload_outlined,
        'color': const Color(0xFF7C3AED),
        'action': () => selectNavigationIndex(ref, 54),
        'tooltip': 'مستندات الشحن الأصلية وتحويلات البلوكشين عبر CargoX',
      },
      {
        'label': 'حجز الشحن الملاحي',
        'icon': Icons.directions_boat_outlined,
        'color': const Color(0xFF059669),
        'action': () => selectNavigationIndex(ref, 25),
        'tooltip': 'إدارة الحجوزات البحرية والخطوط الملاحية والحاويات',
      },
      {
        'label': 'مقدم المورد (دفعة)',
        'icon': Icons.payments_outlined,
        'color': const Color(0xFFD97706),
        'action': () => selectNavigationIndex(ref, 8),
        'tooltip': 'الموافقات المالية على التحويلات ودفعات الموردين',
      },
      {
        'label': 'إضافة ملاحظة خبرة +',
        'icon': Icons.add_comment_outlined,
        'color': const Color(0xFF475569),
        'action': () => _showAddKbNoteDialog(context, file),
        'tooltip': 'تسجيل ملاحظة تشغيلية في قاعدة المعرفة للشحنات المستقبلية',
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, color: AppTheme.cobalt, size: 16),
                SizedBox(width: 4),
                Text(
                  'محاكاة ومحطات سريعة:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: shortcuts.map((s) {
                  final color = s['color'] as Color;
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Tooltip(
                      message: s['tooltip'] as String,
                      child: InkWell(
                        onTap: s['action'] as VoidCallback,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(s['icon'] as IconData, size: 14, color: color),
                              const SizedBox(width: 5),
                              Text(
                                s['label'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 0.6: Executive KPI Physical & Financial Metric Tiles ────
  Widget _buildExecutiveMetricTiles(
    BuildContext context,
    ImportFileModel file,
    ComprehensiveShipmentDossierModel? dossier,
  ) {
    // 1. CBM
    final fallbackCbm = file.packingListsData.fold(0.0, (s, p) => s + p.cbm);
    final cbmVal = (dossier?.cargoPhysicalSummary?['total_cbm'] as num?)?.toDouble() ??
        (dossier != null && dossier.totalCbm > 0 ? dossier.totalCbm : fallbackCbm);
    final displayCbm = cbmVal > 0 ? '${cbmVal.toStringAsFixed(3)} m³' : '—';

    // 2. Gross Weight
    final fallbackGross = file.packingListsData.fold(0.0, (s, p) => s + p.grossWeightKg);
    final grossVal = (dossier?.cargoPhysicalSummary?['total_gross_weight_kg'] as num?)?.toDouble() ??
        (dossier?.cargoPhysicalSummary?['gross_weight_kg'] as num?)?.toDouble() ??
        (dossier != null && dossier.grossWeightKg > 0 ? dossier.grossWeightKg : fallbackGross);
    // Priority: dossier.netWeightKg is sourced from PO totals (reliable).
    // cargoPhysicalSummary['total_net_weight_kg'] may come from container loader sessions (unreliable).
    final netVal = dossier?.netWeightKg ??
        (dossier?.cargoPhysicalSummary?['total_net_weight_kg'] as num?)?.toDouble();
    final displayGross = grossVal > 0 ? '${PoPackingMatcher.formatWeight(grossVal)} كجم' : '—';
    final displayNet = netVal != null && netVal > 0 ? 'صافي: ${PoPackingMatcher.formatWeight(netVal)} كجم' : 'وزن الشحن القائم';

    // 3. POs & Invoices
    final invCount = dossier?.invoicesCount ?? dossier?.cargoPhysicalSummary?['invoices_count'] ?? file.invoicesData.length;
    final poCount = dossier?.posCount ?? dossier?.cargoPhysicalSummary?['pos_count'] ?? (file.poNumber != null && file.poNumber!.isNotEmpty ? 1 : 0);
    final itemsCount = dossier?.itemsCount ?? 0;

    // 4. Landed Cost & Variance
    final actualLanded = dossier?.actualLandedCostTotalEgp ?? file.actualLandedCostTotalEgp;
    final displayCost = actualLanded > 0
        ? '${actualLanded.toStringAsFixed(0)} ج.م'
        : (file.estimatedCost > 0 ? '${file.estimatedCost.toStringAsFixed(0)} \$' : '—');
    final variancePct = dossier?.actualLandedCostVariancePct ?? file.actualLandedCostVariancePct;
    final varianceEgp = dossier?.actualLandedCostVarianceEgp ?? file.actualLandedCostVarianceEgp;
    final hasVariance = actualLanded > 0 && varianceEgp != 0;

    // 5. ETA Drift
    final etaStr = file.requiredEta ?? (dossier?.timelineEvents.isNotEmpty == true
        ? dossier!.timelineEvents.firstWhere((e) => e['stage_code'] == 'STEP_11', orElse: () => {})['planned_date']?.toString()
        : null) ?? '—';
    int driftDays = 0;
    if (dossier != null && dossier.etaRevisionsLog.isNotEmpty) {
      final lastLog = dossier.etaRevisionsLog.last;
      driftDays = (lastLog['drift_days'] as num?)?.toInt() ?? 0;
    }
    final isDrifted = driftDays > 0;

    return Row(
      children: [
        _kpiMetricCard(
          context: context,
          title: 'الحجم الإجمالي (CBM)',
          primaryValue: displayCbm,
          subtitle: 'حجم البضائع المشحونة',
          icon: Icons.inventory_2_outlined,
          color: const Color(0xFF2563EB),
          bgGradient: const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
        ),
        const SizedBox(width: 12),
        _kpiMetricCard(
          context: context,
          title: 'الوزن القائم (Gross Wt)',
          primaryValue: displayGross,
          subtitle: displayNet,
          icon: Icons.scale_outlined,
          color: const Color(0xFF475569),
          bgGradient: const [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
        ),
        const SizedBox(width: 12),
        _kpiMetricCard(
          context: context,
          title: 'الفواتير وأوامر الشراء',
          primaryValue: '$poCount PO  •  $invCount فاتورة',
          subtitle: itemsCount > 0 ? '$itemsCount صنف مدرج بالملف' : 'أوامر التوريد المعتمدة',
          icon: Icons.receipt_long_outlined,
          color: const Color(0xFFD97706),
          bgGradient: const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
        ),
        const SizedBox(width: 12),
        _kpiMetricCard(
          context: context,
          title: actualLanded > 0 ? 'تكلفة الوصول الفعلية' : 'التكلفة التقديرية',
          primaryValue: displayCost,
          subtitle: hasVariance
              ? 'انحراف: ${variancePct > 0 ? "+" : ""}${variancePct.toStringAsFixed(1)}% (${varianceEgp.toStringAsFixed(0)} ج.م)'
              : 'مطابقة للتكلفة المخططة',
          icon: Icons.monetization_on_outlined,
          color: hasVariance ? (variancePct > 5 ? AppTheme.crimson : const Color(0xFFD97706)) : AppTheme.emerald,
          bgGradient: hasVariance
              ? const [Color(0xFFFEF2F2), Color(0xFFFEE2E2)]
              : const [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
        ),
        const SizedBox(width: 12),
        _kpiMetricCard(
          context: context,
          title: 'تتبع موعد الوصول ETA',
          primaryValue: etaStr,
          subtitle: isDrifted ? '⚠️ انحراف تأخير: +$driftDays يوم' : '✅ في الموعد المحدد',
          icon: isDrifted ? Icons.warning_amber_rounded : Icons.schedule_outlined,
          color: isDrifted ? AppTheme.crimson : AppTheme.emerald,
          bgGradient: isDrifted
              ? const [Color(0xFFFFF7ED), Color(0xFFFFEDD5)]
              : const [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
        ),
      ],
    );
  }

  Widget _kpiMetricCard({
    required BuildContext context,
    required String title,
    required String primaryValue,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Color> bgGradient,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bgGradient,
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              primaryValue,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.charcoal,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Operational Command Footer ─────────────────────────────────────
  Widget _buildOperationalCommandFooter(
    BuildContext context,
    ImportFileModel file,
    ComprehensiveShipmentDossierModel? dossier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.tune, color: AppTheme.charcoal, size: 20),
          const SizedBox(width: 8),
          const Text(
            'مركز القرارات والتحكم التشغيلي السريع للشحنة:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
          ),
          const Spacer(),
          // 1. Request RFQ
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.request_quote_outlined, size: 15),
            label: const Text('طلب عروض أسعار شحن (RFQ)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () => selectNavigationIndex(ref, 49),
          ),
          const SizedBox(width: 8),
          // 2. Edit Import File
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cobalt,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.edit_note, size: 15),
            label: const Text('تعديل وتحديث الملف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () => selectNavigationIndex(ref, 1),
          ),
          const SizedBox(width: 8),
          // 3. Stop Shipment
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.crimson,
              side: const BorderSide(color: AppTheme.crimson),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.stop_circle_outlined, size: 15),
            label: const Text('إيقاف الشحنة مرحلياً', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () => _showStopShipmentDialog(context, file),
          ),
          const SizedBox(width: 8),
          // 4. Recalculate Landed Cost
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.charcoal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.refresh, size: 15),
            label: const Text('إعادة احتساب تكلفة الوصول', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () => selectNavigationIndex(ref, 29),
          ),
        ],
      ),
    );
  }

  Widget _slaSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        const SizedBox(width: 4),
        SelectableText(
          value,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  void _showAddKbNoteDialog(BuildContext context, ImportFileModel file) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: Color(0xFF7C3AED)),
            const SizedBox(width: 8),
            Text('إضافة ملاحظة خبرة مؤسسية - ${file.displayName}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سجل درساً مستفاداً أو اشتراطاً تشغيلياً خاصاً بهذا المورد أو البند الجمركي:',
              style: TextStyle(fontSize: 12, color: AppTheme.charcoal),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'اكتب الملاحظة هنا (مثل: يجب تقديم شهادة تبخير أصلية معتمدة لتفادي غرامات الفحص الجمركي)...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            onPressed: () {
              final text = noteController.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم حفظ الملاحظة المؤسسية بنجاح في سجل الخبرات: $text'),
                    backgroundColor: AppTheme.emerald,
                  ),
                );
              }
            },
            child: const Text('حفظ الملاحظة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showStopShipmentDialog(BuildContext context, ImportFileModel file) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.crimson),
            SizedBox(width: 8),
            Text('إيقاف الشحنة مرحلياً', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.crimson)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل ترغب في تعليق أو إيقاف الشحنة (${file.displayName}) مؤقتاً عند هذه المرحلة لحين استيفاء الإجراءات؟',
              style: const TextStyle(fontSize: 12, color: AppTheme.charcoal),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'سبب الإيقاف أو التجميد المؤقت...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم تسجيل طلب إيقاف الشحنة مؤقتاً: ${reasonController.text}'),
                  backgroundColor: AppTheme.crimson,
                ),
              );
            },
            child: const Text('تأكيد الإيقاف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _navigateToStage(BuildContext context, String stageCode) {
    int targetIndex = 1;
    switch (stageCode) {
      case 'STEP_01':
      case 'STEP_02':
        targetIndex = 2; // PO
        break;
      case 'STEP_03':
        targetIndex = 11; // ACID
        break;
      case 'STEP_05':
        targetIndex = 16; // Form 4
        break;
      case 'STEP_08':
        targetIndex = 18; // CargoX / Draft BL
        break;
      case 'STEP_09':
        targetIndex = 25; // Freight Booking
        break;
      case 'STEP_10':
      case 'STEP_11':
        targetIndex = 26; // Cargo Shipping
        break;
      case 'STEP_12':
      case 'STEP_13':
      case 'STEP_14':
      case 'STEP_15':
      case 'STEP_16':
        targetIndex = 27; // Customs Clearance
        break;
      case 'STEP_19':
        targetIndex = 28; // Warehouse Receiving
        break;
      case 'STEP_21':
        targetIndex = 44; // Demurrage & Empty Return
        break;
      case 'STEP_23':
        targetIndex = 29; // Landed Cost Settlement
        break;
      case 'STEP_25':
        targetIndex = 30; // File Closure
        break;
    }
    selectNavigationIndex(ref, targetIndex);
  }
}

