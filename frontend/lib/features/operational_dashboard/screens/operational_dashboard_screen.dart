import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/performance/dispose_tracker.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/app_shimmer_skeleton.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_layout_builder.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/widgets/close_shipment_dialog.dart';
import '../../lifecycle_board/providers/lifecycle_board_provider.dart';
import '../../lifecycle_board/widgets/skip_step_dialog_helper.dart';
import '../../shipment_updates/providers/shipment_updates_provider.dart';
import '../../shipment_updates/widgets/shipment_update_dialog.dart';
import '../../smart_tasks/models/smart_task_model.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';
import '../providers/operational_dashboard_provider.dart';
import '../widgets/operational_dashboard_widgets.dart';

/// Coordinator screen for the Sorour Logistics Operational Dashboard.
class OperationalDashboardScreen extends ConsumerStatefulWidget {
  const OperationalDashboardScreen({super.key});

  @override
  ConsumerState<OperationalDashboardScreen> createState() =>
      _OperationalDashboardScreenState();
}

class _OperationalDashboardScreenState
    extends ConsumerState<OperationalDashboardScreen>
    with DisposeTrackerMixin<OperationalDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.invalidate(operationalDashboardProvider);
      ref.invalidate(lifecycleBoardSummaryProvider);
      ref.invalidate(smartTasksProvider);
      ref.invalidate(shipmentUpdatesProvider);
      ref.read(operationalDashboardProvider.notifier).fetchDashboard();
      ref.read(smartTasksProvider.notifier).fetchTasks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(operationalDashboardProvider);
    final boardAsync = ref.watch(lifecycleBoardSummaryProvider);
    final notifier = ref.read(operationalDashboardProvider.notifier);
    final density = ref.watch(displayDensityProvider);
    final l = context.l10n;
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final tasksState = ref.watch(smartTasksProvider);
    final updatesState = ref.watch(shipmentUpdatesProvider);

    // Memoize / pre-group open tasks by importFileId once per build (O(N) instead of O(N*M))
    final Map<int, List<SmartTaskModel>> openTasksByFileId = {};
    for (final t in tasksState.tasks) {
      if (t.importFileId != null && t.status != 'Completed') {
        (openTasksByFileId[t.importFileId!] ??= []).add(t);
      }
    }

    final regTasks = tasksState.tasks
        .where((t) =>
            (t.taskType == 'Regulatory Compliance' ||
                (t.phaseName != null && t.phaseName!.contains('STEP_03'))) &&
            t.status != 'Completed')
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PageHeader(
        icon: Icons.dashboard_outlined,
        iconColor: AppTheme.cobalt,
        title: l.operationalDashboardTitle,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white, size: density.buttonIconSize),
            tooltip: l.refresh,
            onPressed: () {
              ref.invalidate(operationalDashboardProvider);
              ref.invalidate(lifecycleBoardSummaryProvider);
              ref.invalidate(smartTasksProvider);
              ref.invalidate(shipmentUpdatesProvider);
              notifier.fetchDashboard();
              ref.read(smartTasksProvider.notifier).fetchTasks();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  context.isMobile ? 12.0 : 20.0,
                  context.isMobile ? 12.0 : 20.0,
                  context.isMobile ? 12.0 : 20.0,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 0. Executive KPI Summary Cards & Risk Alerts
                    dashboardState.data.when(
                      loading: () => const DashboardKpiShimmerSkeleton(),
                      error: (_, __) => const SizedBox(),
                      data: (data) => Column(
                        children: [
                          OperationalKpiBarSection(
                            data: data,
                            density: density,
                            onFocusShipment: (shipmentCode) {
                              _searchController.text = shipmentCode;
                              notifier.setSearchQuery(shipmentCode);
                            },
                          ),
                          const SizedBox(height: 16),
                          const ContainerDemurrageRadarCard(),
                          const SizedBox(height: 16),
                          OperationalInteractiveBoardBanner(
                            onOpenBoard: () => selectNavigationIndex(ref, 48),
                          ),
                          const SizedBox(height: 16),
                          OperationalQuickActionsBar(
                            onNavigate: (index) => selectNavigationIndex(ref, index),
                          ),
                          const SizedBox(height: 16),
                          OperationalRiskAlertsBanner(
                            shipments: data.shipments,
                            regTasks: regTasks,
                            isArabic: isArabic,
                          ),
                          const SizedBox(height: 16),
                          OperationalDailyCheckinsCard(
                            shipments: data.shipments,
                            logs: updatesState.logs,
                            isArabic: isArabic,
                            onAddDailyUpdate: () => ShipmentUpdateDialog.show(context),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    // 1. Shipment Lifecycle Operations Board Summary (6 Phases / 25 Steps)
                    OperationalLifecycleBoardSummaryCard(
                      boardData: boardAsync.valueOrNull,
                      isLoading: boardAsync.isLoading,
                      selectedPhase: dashboardState.selectedPhase,
                      isArabic: isArabic,
                      onTogglePhase: (phase) => notifier.togglePhase(phase),
                      onClearFilter: dashboardState.selectedPhase != null
                          ? () => notifier.togglePhase(dashboardState.selectedPhase!)
                          : null,
                      onOpenFullBoard: () => selectNavigationIndex(ref, 48),
                    ),
                    const SizedBox(height: 16),

                    // 2. Control Bar (Priority Group, Customs Broker Dropdown & Search)
                    OperationalControlBar(
                      dashboardState: dashboardState,
                      notifier: notifier,
                      density: density,
                      searchController: _searchController,
                    ),
                    const SizedBox(height: 16),

                    // 3. Results Header & Count
                    OperationalResultsHeader(
                      dashboardState: dashboardState,
                      density: density,
                      isArabic: isArabic,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // 4. Virtualized Shipment Cards List / Loading / Error / Empty States
            dashboardState.data.when(
              loading: () => ShipmentListShimmerSkeleton.sliver(count: 3),
              error: (err, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: OperationalErrorCard(notifier: notifier),
                ),
              ),
              data: (dashboardData) {
                final shipments = dashboardData.shipments;
                if (shipments.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 40),
                      child: OperationalEmptyStateCard(
                        notifier: notifier,
                        searchController: _searchController,
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final s = shipments[idx];
                        final fileTasks = openTasksByFileId[s.importFileId] ?? const [];
                        return _buildShipmentCard(s, isArabic, fileTasks, l);
                      },
                      childCount: shipments.length,
                    ),
                  ),
                );
              },
            ),

            // 5. Mandatory Anti-Overlap Clearance (+72px buffer for floating AI Assistant / launcher)
            const SliverToBoxAdapter(
              child: SizedBox(height: 72),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShipmentCard(
    ImportFileModel s,
    bool isArabic,
    List<SmartTaskModel> linkedTasks,
    AppLocalizations l,
  ) {
    return OperationalShipmentCard(
      shipment: s,
      isArabic: isArabic,
      linkedTasks: linkedTasks,
      onRecordDailyUpdate: () => ShipmentUpdateDialog.show(
        context,
        initialFileId: s.importFileId,
        initialFileCode: DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic),
        initialTargetPhase: s.currentModule,
      ),
      onSkipStep: s.status != 'Closed'
          ? () => SkipStepDialogHelper.show(
                context: context,
                ref: ref,
                importFileCode: s.importFileCode,
                currentStepCode: s.currentStepCode ?? s.currentStage,
                currentStepName: OperationalFormatHelper.formatStageName(
                  s.displayStepKey,
                  isArabic: isArabic,
                ),
                onSuccess: () => ref.read(operationalDashboardProvider.notifier).fetchDashboard(),
              )
          : null,
      onCloseShipment: s.status != 'Closed'
          ? () async {
              final closed = await showDialog<bool>(
                context: context,
                builder: (c) => CloseShipmentDialog(
                  importFileId: s.importFileId,
                  importFileCode: DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic),
                  currentPhaseName: s.codedStageLabel(l) ??
                      DisplayNameResolver.resolvePhaseName(s.currentModule, isArabic: isArabic),
                ),
              );
              if (closed == true) {
                ref.read(operationalDashboardProvider.notifier).fetchDashboard();
              }
            }
          : null,
      onTaskStatusChanged: (task, isCompleted) async {
        if (isCompleted) {
          try {
            await ref.read(smartTasksProvider.notifier).updateTask(task.taskId, {'status': 'Completed'});
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                AppTheme.snackBar(
                  context,
                  '${l.taskCompletedSuccessfully}: ${task.displayTitle(context.l10n)}',
                  severity: AppSeverity.success,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                AppTheme.snackBar(context, e.toString(), severity: AppSeverity.danger),
              );
            }
          }
        }
      },
      onNavigate: (index) => selectNavigationIndex(ref, index),
      onManageAllTasks: () => selectNavigationIndex(ref, 40),
    );
  }
}
