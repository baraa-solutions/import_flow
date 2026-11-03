import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/lifecycle_board_model.dart';
import '../providers/lifecycle_board_provider.dart';
import '../providers/live_polling_provider.dart';
import 'kanban_shipments_table.dart';
import 'kanban_table_top_bar.dart';
import 'lifecycle_board_helpers.dart';
import 'lifecycle_phase_card.dart';

/// 6-Phase Kanban Board view of the Lifecycle Board.
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
  final ScrollController _topPhasesScrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _topPhasesScrollController.dispose();
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
          final isDark = Theme.of(context).brightness == Brightness.dark;
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
              // UPPER 1/3: Compact 6 Phase Overview Cards
              Container(
                color: isDark ? AppTheme.darkCardBackground : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      controller: _topPhasesScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...boardData.phases.map(
                            (phase) => LifecyclePhaseCard(
                              phase: phase,
                              width: 195,
                              isPhaseSelected: _selectedPhaseId == phase.phaseId && _selectedStepCode == null,
                              selectedStepCode: _selectedPhaseId == phase.phaseId ? _selectedStepCode : null,
                              onSelectPhase: (phaseId) {
                                setState(() {
                                  _selectedPhaseId = phaseId;
                                  _selectedStepCode = null;
                                });
                              },
                              onSelectStep: (phaseId, stepCode) {
                                setState(() {
                                  _selectedPhaseId = phaseId;
                                  _selectedStepCode = stepCode;
                                });
                              },
                            ),
                          ),
                          // "All Shipments" Reset Card
                          Container(
                            width: 130,
                            margin: const EdgeInsetsDirectional.only(end: 8),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                side: BorderSide(
                                  color: (_selectedPhaseId == null && _selectedStepCode == null)
                                      ? AppTheme.cobalt
                                      : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                                  width: (_selectedPhaseId == null && _selectedStepCode == null) ? 2 : 1,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                backgroundColor: (_selectedPhaseId == null && _selectedStepCode == null)
                                    ? AppTheme.cobalt.withValues(alpha: 0.08)
                                    : (isDark ? AppTheme.darkSurface : Colors.white),
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedPhaseId = null;
                                  _selectedStepCode = null;
                                });
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.all_inclusive,
                                    size: 20,
                                    color: (_selectedPhaseId == null && _selectedStepCode == null)
                                        ? AppTheme.cobalt
                                        : Colors.grey,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.allShipmentsAllPhases,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: (_selectedPhaseId == null && _selectedStepCode == null)
                                          ? AppTheme.cobalt
                                          : (isDark ? AppTheme.darkTextPrimary : Colors.black87),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 2),
                                  AppStatusBadge(
                                    label: '${boardData.totalActiveFiles}',
                                    severity: AppSeverity.info,
                                    size: AppStatusBadgeSize.small,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Colors.black12),

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

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined, size: 44, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              l10n.noShipmentsInStage,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 3),
            Text(
              l10n.noShipmentsInStageDesc,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
