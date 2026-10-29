// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../core/localization/app_localizations.dart';

import '../../../core/services/display_name_resolver.dart';

import '../../../core/theme/app_theme.dart';

import '../../../core/widgets/widgets.dart';





import '../../import_files/models/import_file_model.dart';

import '../../import_files/providers/import_files_provider.dart';

import '../../shipment_updates/providers/shipment_updates_provider.dart';

import '../../shipment_updates/widgets/shipment_update_dialog.dart';

import '../../customs_clearance/providers/customs_clearance_provider.dart';

import '../../customs_clearance/models/customs_clearance_model.dart';

import '../../warehouse_receiving/providers/warehouse_receiving_provider.dart';

import '../../warehouse_receiving/models/warehouse_receiving_model.dart';

import '../services/comprehensive_report_export_service.dart';

import '../services/comprehensive_dossier_service.dart';

import '../widgets/report_widgets.dart';

import '../models/comprehensive_dossier_model.dart';

import '../widgets/comprehensive_dossier_export_dialog.dart';

import '../widgets/shipment_audit_timeline_dialog.dart';

import '../../../core/providers/navigation_provider.dart';

import '../../smart_checklists/providers/smart_checklists_provider.dart';

import '../../smart_checklists/widgets/smart_checklist_dialog.dart';

import '../../purchase_orders/providers/purchase_orders_provider.dart';

import '../../purchase_orders/models/purchase_order_model.dart' hide PackingListItemModel;



// ============================================================

// Comprehensive Import File Report Screen

// تقرير ملخص ملفات الاستيراد المدمج والشامل

// ============================================================



class ImportFileComprehensiveReportScreen extends ConsumerStatefulWidget {

  final int? initialFileId;

  const ImportFileComprehensiveReportScreen({super.key, this.initialFileId});



  @override

  ConsumerState<ImportFileComprehensiveReportScreen> createState() =>

      _ImportFileComprehensiveReportScreenState();

}



class _ImportFileComprehensiveReportScreenState

    extends ConsumerState<ImportFileComprehensiveReportScreen> {

  int? _selectedFileId;

  ImportFileModel? _selectedFile;

  final Set<int> _acknowledgedAlerts = {};



  @override

  void initState() {

    super.initState();

    if (widget.initialFileId != null) {

      _selectedFileId = widget.initialFileId;

    }

    Future.microtask(() {

      final navFileId = ref.read(selectedComprehensiveReportFileIdProvider);

      final target = navFileId ?? widget.initialFileId;

      if (target != null && _selectedFileId != target) {

        _selectedFileId = target;

      }

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

    ref.invalidate(comprehensiveDossierProvider(val));

    ref.read(smartChecklistProvider.notifier).fetchChecklist(val);

  }



  @override

  Widget build(BuildContext context) {

    final l = context.l10n;

    final importFilesState = ref.watch(importFilesProvider);

    final navTargetId = ref.watch(selectedComprehensiveReportFileIdProvider);

    final targetId = navTargetId ?? widget.initialFileId;



    // Auto-select shipment ONLY if explicit targetId is specified from navigation or initialFileId

    importFilesState.whenData((files) {

      if (files.isNotEmpty && targetId != null) {

        final found = files.any((f) => f.importFileId == targetId);

        if (found && _selectedFile?.importFileId != targetId) {

          WidgetsBinding.instance.addPostFrameCallback((_) {

            if (mounted) _onFileSelected(targetId, files);

          });

        }

      }

    });

    final updatesState = ref.watch(shipmentUpdatesProvider);

    final clearanceState = ref.watch(customsClearanceProvider);

    final warehouseState = ref.watch(warehouseReceivingProvider);

    final checklistState = ref.watch(smartChecklistProvider);

    final allPOs = ref.watch(purchaseOrdersProvider).purchaseOrders;



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

      appBar: PageHeader(

        leading: IconButton(

          key: const Key('backToOperationsBtn'),

          icon: const Icon(Icons.arrow_back, color: Colors.white),

          tooltip: 'العودة إلى العمليات التشغيلية (Screen 1)',

          onPressed: () {

            if (_selectedFileId != null) {

              openOperationalDetailsForFile(ref, _selectedFileId!);

            } else {

              selectNavigationIndex(ref, 1);

            }

          },

        ),

        icon: Icons.summarize_outlined,

        iconColor: AppTheme.cobalt,

        title: l.compReportScreenTitle,

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

                child: SingleChildScrollView(

                  scrollDirection: Axis.horizontal,

                  child: Row(

                  children: [

                    Text(

                      _selectedFile!.displayName,

                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),

                    ),

                    const SizedBox(width: 8),

                    _buildCopyBadge(context, _selectedFile!.displayName),

                    const SizedBox(width: 16),

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

                    const SizedBox(width: 8),

                    ElevatedButton.icon(

                      key: const Key('smartChecklistToolbarBtn'),

                      style: ElevatedButton.styleFrom(

                        backgroundColor: checklistState.summary?.isGateBlocked == true

                            ? AppTheme.crimson

                            : const Color(0xFF0D9488), // Teal

                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

                      ),

                      icon: Icon(

                        checklistState.summary?.isGateBlocked == true

                            ? Icons.warning_amber_rounded

                            : Icons.checklist_rtl_outlined,

                        size: 15,

                        color: Colors.white,

                      ),

                      label: Text(

                        checklistState.summary != null

                            ? 'قائمة التحقق (${checklistState.summary!.readinessScorePct}%)'

                            : 'قائمة التحقق',

                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),

                      ),

                      onPressed: () => SmartChecklistDialog.show(context, _selectedFile!),

                    ),

                    const SizedBox(width: 8),

                    ElevatedButton.icon(

                      key: const Key('shipmentAuditTimelineToolbarBtn'),

                      style: ElevatedButton.styleFrom(

                        backgroundColor: const Color(0xFF0F766E), // Deep Teal

                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

                      ),

                      icon: const Icon(Icons.history_toggle_off_rounded, size: 15, color: Colors.white),

                      label: const Text(

                        '⏱️ رادار ومحضر التتبع الزمني (36 محطة)',

                        style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),

                      ),

                      onPressed: () => showShipmentAuditTimelineDialog(

                        context,

                        importFileId: _selectedFile!.importFileId,

                      ),

                    ),

                  ],

                ),

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

                          _buildExecutiveMetricTiles(

                            context,

                            _selectedFile!,

                            dossier,

                            allPOs: allPOs,

                            isLoading: dossierAsync?.isLoading ?? false,

                          ),

                          const SizedBox(height: 16),



                          // Smart Shipment Reference Card (KB-GUIDE-012 Part 2)

                          _buildSmartShipmentReferenceCard(

                            context,

                            _selectedFile!,

                            dossier,

                            allPOs,

                          ),

                          const SizedBox(height: 16),



                          // Section 2: 10-Phase Progress Pipeline

                          _buildPhasePipeline(context, _selectedFile!, updatesState, checklistState),

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

                                    const SizedBox(height: 14),

                                    _buildTradeAgreementsSection(context, _selectedFile!, allPOs),

                                    const SizedBox(height: 14),

                                    _buildCargoStackingSection(context, _selectedFile!, allPOs, dossier),

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



  Widget _buildEmptyState(BuildContext context) => const ReportEmptyState();



  Widget _buildHeaderBanner(BuildContext context, ImportFileModel file, [ComprehensiveShipmentDossierModel? dossier]) =>

      ReportHeaderBanner(

        file: file,

        dossier: dossier,

        onOpenOperationalDetails: () => openOperationalDetailsForFile(ref, file.importFileId),

      );



  Widget _buildPhasePipeline(

    BuildContext context,

    ImportFileModel file,

    ShipmentUpdatesState updatesState,

    SmartChecklistState checklistState,

  ) =>

      ReportPhasePipeline(

        file: file,

        updatesState: updatesState,

        checklistState: checklistState,

      );



  Widget _buildStageSimulationShortcutsStrip(BuildContext context, ImportFileModel file) =>

      ReportSimulationShortcutsStrip(

        file: file,

        onNavigate: (index) => selectNavigationIndex(ref, index),

      );



  Widget _buildExecutiveMetricTiles(

    BuildContext context,

    ImportFileModel file,

    ComprehensiveShipmentDossierModel? dossier, {

    List<PurchaseOrderModel> allPOs = const [],

    bool isLoading = false,

  }) =>

      ReportExecutiveMetricTiles(

        file: file,

        dossier: dossier,

        allPOs: allPOs,

        isLoading: isLoading,

      );



  Widget _buildSmartShipmentReferenceCard(

    BuildContext context,

    ImportFileModel file,

    ComprehensiveShipmentDossierModel? dossier,

    List<PurchaseOrderModel> allPOs,

  ) =>

      ReportSmartShipmentReferenceCard(

        file: file,

        dossier: dossier,

        allPOs: allPOs,

      );



  Widget _buildInstitutionalKnowledgeCard(

    BuildContext context,

    ComprehensiveShipmentDossierModel? dossier,

    ImportFileModel file,

  ) =>

      ReportInstitutionalKnowledgeCard(

        file: file,

        dossier: dossier,

        initialAcknowledgedAlerts: _acknowledgedAlerts,

      );



  Widget _buildBasicInfoCard(BuildContext context, ImportFileModel file, [ComprehensiveShipmentDossierModel? dossier]) =>

      ReportBasicInfoCard(file: file, dossier: dossier);



  Widget _buildContainersCard(

    BuildContext context,

    ComprehensiveShipmentDossierModel? dossier,

    ImportFileModel file,

  ) =>

      ReportContainersCard(file: file, dossier: dossier);



  Widget _buildDocumentsCard(BuildContext context, ImportFileModel file) =>

      ReportDocumentsCard(file: file);



  Widget _buildInvoicesCard(

    BuildContext context,

    ImportFileModel file,

    ComprehensiveShipmentDossierModel? dossier,

  ) =>

      ReportInvoicesCard(file: file, dossier: dossier);



  Widget _buildPackingListCard(

    BuildContext context,

    ImportFileModel file,

    ComprehensiveShipmentDossierModel? dossier,

  ) =>

      ReportPackingListCard(file: file, dossier: dossier);



  Widget _buildTradeAgreementsSection(

    BuildContext context,

    ImportFileModel file,

    List<PurchaseOrderModel> allPOs,

  ) =>

      ReportTradeAgreementsSection(file: file, allPOs: allPOs);



  Widget _buildCargoStackingSection(

    BuildContext context,

    ImportFileModel file,

    List<PurchaseOrderModel> allPOs,

    ComprehensiveShipmentDossierModel? dossier,

  ) =>

      ReportCargoStackingSection(file: file, allPOs: allPOs, dossier: dossier);



  Widget _buildStatusCard(BuildContext context, ImportFileModel file) =>

      ReportStatusCard(file: file);



  Widget _buildFinancialCard(

    BuildContext context,

    ImportFileModel file,

    ComprehensiveShipmentDossierModel? dossier,

  ) =>

      ReportFinancialCard(file: file, dossier: dossier);



  Widget _buildFxReconciliationCard(

    BuildContext context,

    ComprehensiveShipmentDossierModel? dossier,

    ImportFileModel file,

  ) =>

      ReportFxReconciliationCard(file: file, dossier: dossier);



  Widget _buildNotesCard(BuildContext context, ImportFileModel file) =>

      ReportNotesCard(file: file);



  Widget _buildInteractiveTimelineCard(

    BuildContext context,

    ComprehensiveShipmentDossierModel? dossier,

    ImportFileModel file,

    ShipmentUpdatesState updatesState,

  ) =>

      ReportInteractiveTimelineCard(

        file: file,

        dossier: dossier,

        updatesState: updatesState,

        onNavigateToStage: (stageCode) => _navigateToStage(context, stageCode),

      );



  Widget _buildUpdateTimeline(

    BuildContext context,

    ImportFileModel file,

    ShipmentUpdatesState updatesState,

  ) =>

      ReportUpdatesTimelineCard(file: file, updatesState: updatesState);



  Widget _buildClearanceSection(

    BuildContext context,

    AsyncValue<List<CustomsClearanceModel>> state,

  ) =>

      ReportClearanceSection(state: state);



  Widget _buildWarehouseSection(

    BuildContext context,

    AsyncValue<List<WarehouseReceivingModel>> state,

  ) =>

      ReportWarehouseSection(state: state);



  Widget _buildOperationalCommandFooter(

    BuildContext context,

    ImportFileModel file,

    ComprehensiveShipmentDossierModel? dossier,

  ) =>

      ReportOperationalCommandFooter(file: file, dossier: dossier);



  Widget _buildCopyBadge(

    BuildContext context,

    String text, {

    String? tooltip,

    Color? color,

    Color? textColor,

    Color? borderColor,

  }) =>

      ReportCopyBadge(

        textToCopy: text,

        label: tooltip,

        color: color,

        textColor: textColor,

        borderColor: borderColor,

      );

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



