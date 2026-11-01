import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/navigation_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../customs_clearance/models/customs_clearance_model.dart';
import '../../customs_clearance/providers/customs_clearance_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../shipment_updates/providers/shipment_updates_provider.dart';
import '../../smart_checklists/providers/smart_checklists_provider.dart';
import '../../warehouse_receiving/models/warehouse_receiving_model.dart';
import '../../warehouse_receiving/providers/warehouse_receiving_provider.dart';
import '../services/comprehensive_dossier_service.dart';
import '../widgets/report_empty_state_view.dart';
import '../widgets/report_screen/report_screen.dart';

/// Screen 47: Import File Comprehensive Report Coordinator.
/// Modular screen coordinator orchestrating Summary, Financials, Stages, and Actions.
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

  @override
  Widget build(BuildContext context) {
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

    final dossierAsync = _selectedFileId != null
        ? ref.watch(comprehensiveDossierProvider(_selectedFileId!))
        : null;
    final dossier = dossierAsync?.valueOrNull;

    final clr = (clearanceState.valueOrNull != null &&
            clearanceState.valueOrNull!.isNotEmpty &&
            _selectedFileId != null)
        ? clearanceState.valueOrNull!.cast<CustomsClearanceModel?>().firstWhere(
              (c) => c?.importFileId == _selectedFileId,
              orElse: () => null,
            )
        : null;
    final wh = (warehouseState.valueOrNull != null &&
            warehouseState.valueOrNull!.isNotEmpty &&
            _selectedFileId != null)
        ? warehouseState.valueOrNull!.cast<WarehouseReceivingModel?>().firstWhere(
              (w) => w?.importFileId == _selectedFileId,
              orElse: () => null,
            )
        : null;

    return SelectionArea(
      child: Scaffold(
        backgroundColor: AppTheme.surfaceAlt,
        appBar: ComprehensiveReportHeader(
          selectedFile: _selectedFile,
          dossier: dossier,
          updatesState: updatesState,
          clearance: clr,
          warehouse: wh,
          onBackPressed: () {
            if (_selectedFileId != null) {
              openOperationalDetailsForFile(ref, _selectedFileId!);
            } else {
              selectNavigationIndex(ref, 1);
            }
          },
        ),
        body: Column(
          children: [
            // Top Action Toolbar & Shipment Selector Bar
            ComprehensiveReportActionsBar(
              importFilesState: importFilesState,
              selectedFileId: _selectedFileId,
              selectedFile: _selectedFile,
              dossier: dossier,
              updatesState: updatesState,
              checklistState: checklistState,
              clearance: clr,
              warehouse: wh,
              onFileSelected: _onFileSelected,
            ),

            // Report View Body
            Expanded(
              child: _selectedFile == null
                  ? const ReportEmptyState()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section 1: Executive KPI Summary Cards
                          ComprehensiveReportSummaryCards(
                            file: _selectedFile!,
                            dossier: dossier,
                            allPOs: allPOs,
                            isLoading: dossierAsync?.isLoading ?? false,
                            acknowledgedAlerts: _acknowledgedAlerts,
                            onOpenOperationalDetails: () =>
                                openOperationalDetailsForFile(
                              ref,
                              _selectedFile!.importFileId,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Section 2: Commercial & Financial Intelligence View
                          ComprehensiveReportFinancialsView(
                            file: _selectedFile!,
                            dossier: dossier,
                            allPOs: allPOs,
                          ),
                          const SizedBox(height: 16),

                          // Section 3: Operational Stages, Pipelines & Audit Timelines
                          ComprehensiveReportStagesView(
                            file: _selectedFile!,
                            dossier: dossier,
                            updatesState: updatesState,
                            checklistState: checklistState,
                            clearanceState: clearanceState,
                            warehouseState: warehouseState,
                            onNavigate: (index) =>
                                selectNavigationIndex(ref, index),
                            onNavigateToStage: (stageCode) =>
                                _navigateToStage(context, stageCode),
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
