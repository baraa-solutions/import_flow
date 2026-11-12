import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../import_files/providers/payment_pathway_provider.dart';
import '../models/lifecycle_board_model.dart';
import '../providers/lifecycle_board_provider.dart';
import '../providers/live_polling_provider.dart';
import 'kanban_shipments_table.dart';
import 'kanban_table_top_bar.dart';
import 'lifecycle_board_helpers.dart';
import 'matrix/lifecycle_matrix_layout.dart';
import 'matrix/lifecycle_phase_matrix.dart';

/// 6-Phase Kanban Board view of the Lifecycle Board (capped 3-step matrix + execution table).
class KanbanPhasesView extends ConsumerStatefulWidget {
  final VoidCallback onRefresh;

  const KanbanPhasesView({
    super.key,
    required this.onRefresh,
  });

  @override
  ConsumerState<KanbanPhasesView> createState() => _KanbanPhasesViewState();
}

class _KanbanPhasesViewState extends ConsumerState<KanbanPhasesView> {
  String _searchQuery = '';
  String? _selectedStepCode;
  int? _selectedPhaseId;

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final boardAsync = ref.watch(lifecycleBoardSummaryProvider);

    return SelectionArea(
      child: boardAsync.when(
        loading: () => const KanbanBoardShimmerSkeleton(),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.crimson, size: 40),
              const SizedBox(height: 12),
              Text(
                l10n.lifecycleBoardError(err.toString()),
                style: const TextStyle(color: AppTheme.crimson),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (boardData) {
          final allShipments = boardData.allShipments;
          final isAr = Directionality.of(context) == TextDirection.rtl;
          final allImportFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

          final filteredShipments = allShipments.where((s) {
            final matchesStep = _selectedStepCode == null || s.stepCode == _selectedStepCode;
            final matchesPhase = _selectedPhaseId == null ||
                isStepInPhase(s.stepCode, _selectedPhaseId!, boardData.phases);
            final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
              s.importFileCode,
              shipments: allImportFiles,
              isArabic: isAr,
            );

            final matchesSearch = _searchQuery.isEmpty ||
                s.importFileCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                shipmentName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                s.companyName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                s.supplierName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (s.poNumber != null && s.poNumber!.toLowerCase().contains(_searchQuery.toLowerCase())) ||
                (s.notes != null && s.notes!.toLowerCase().contains(_searchQuery.toLowerCase()));

            if (_selectedStepCode != null) {
              return matchesStep && matchesSearch;
            } else if (_selectedPhaseId != null) {
              return matchesPhase && matchesSearch;
            }
            return matchesSearch;
          }).toList();

          final radarData = ref.watch(livePollingProvider).valueOrNull ??
              ref.watch(liveLogisticsTrackingProvider).valueOrNull;
          final trackingMap = {
            for (final item in radarData?.items ?? <LiveLogisticsTrackingItemModel>[])
              item.importFileCode: item,
          };

          return Column(
            children: [
              // UPPER STRIP: capped 3-step symmetrical phase matrix (no horizontal scroll at 1366px)
              Container(
                color: AppTheme.surfaceOf(context),
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6),
                child: LifecyclePhaseMatrix(
                  phases: boardData.phases,
                  totalActiveFiles: boardData.totalActiveFiles,
                  selectedPhaseId: _selectedPhaseId,
                  selectedStepCode: _selectedStepCode,
                  gateState: _focusedGateState(filteredShipments, allImportFiles),
                  onSelectPhase: (phaseId) => setState(() {
                    _selectedPhaseId = phaseId;
                    _selectedStepCode = null;
                  }),
                  onSelectStep: (phaseId, stepCode) => setState(() {
                    _selectedPhaseId = phaseId;
                    _selectedStepCode = stepCode;
                  }),
                  onShowAll: () => setState(() {
                    _selectedPhaseId = null;
                    _selectedStepCode = null;
                  }),
                ),
              ),

              Divider(height: 1, color: AppTheme.borderOf(context)),

              // LOWER 2/3: Shipment Stage Execution Table
              Expanded(
                child: Column(
                  children: [
                    KanbanTableTopBar(
                      filteredShipments: filteredShipments,
                      phases: boardData.phases,
                      allImportFiles: allImportFiles,
                      selectedPhaseId: _selectedPhaseId,
                      selectedStepCode: _selectedStepCode,
                      searchController: _searchController,
                      onSearchChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    Expanded(
                      child: filteredShipments.isEmpty
                          ? _buildEmptyState(l10n)
                          : KanbanShipmentsTable(
                              shipments: filteredShipments,
                              phases: boardData.phases,
                              allImportFiles: allImportFiles,
                              trackingMap: trackingMap,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Payment gates / waived stages of the single shipment in focus (the filter
  /// narrowed to one file); empty otherwise. The pathway provider is autoDispose,
  /// so it refetches live whenever a file comes into focus.
  LifecycleMatrixGateState _focusedGateState(
    List<ShipmentStageCardModel> filteredShipments,
    List<ImportFileModel> allImportFiles,
  ) {
    if (filteredShipments.length != 1) return LifecycleMatrixGateState.empty;
    final shipment = filteredShipments.single;
    final file = allImportFiles.where((f) => f.importFileCode == shipment.importFileCode).firstOrNull;
    final pathway = file == null ? null : ref.watch(paymentPathwayStatusProvider(file.importFileId)).valueOrNull;
    return LifecycleMatrixGateState(
      importFileCode: shipment.importFileCode,
      pathway: pathway,
      skippedStepCodes: shipment.skippedStepCodes.toSet(),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined, size: 44, color: AppTheme.textMutedOf(context)),
            const SizedBox(height: 8),
            Text(
              l10n.noShipmentsInStage,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryOf(context)),
            ),
            const SizedBox(height: 3),
            Text(
              l10n.noShipmentsInStageDesc,
              style: TextStyle(fontSize: 11, color: AppTheme.textMutedOf(context)),
            ),
          ],
        ),
      ),
    );
  }
}
