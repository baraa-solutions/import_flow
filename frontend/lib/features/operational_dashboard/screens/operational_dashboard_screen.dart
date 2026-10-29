import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../../core/performance/dispose_tracker.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/app_shimmer_skeleton.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_layout_builder.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/widgets/close_shipment_dialog.dart';
import '../../lifecycle_board/models/lifecycle_board_model.dart';
import '../../lifecycle_board/providers/lifecycle_board_provider.dart';
import '../../lifecycle_board/widgets/skip_step_dialog_helper.dart';
import '../../shipment_updates/providers/shipment_updates_provider.dart';
import '../../shipment_updates/widgets/shipment_update_dialog.dart';
import '../../smart_tasks/models/smart_task_model.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';
import '../providers/operational_dashboard_provider.dart';
import '../services/operational_dashboard_export_service.dart';
import '../widgets/operational_dashboard_widgets.dart';

class OperationalDashboardScreen extends ConsumerStatefulWidget {
  const OperationalDashboardScreen({super.key});

  @override
  ConsumerState<OperationalDashboardScreen> createState() => _OperationalDashboardScreenState();
}

class _OperationalDashboardScreenState extends ConsumerState<OperationalDashboardScreen> with DisposeTrackerMixin<OperationalDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();


  static const List<String> _priorities = ['All', 'Low', 'Medium', 'High', 'Critical'];


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

  String _getPriorityLabel(String p, AppLocalizations l) {
    switch (p) {
      case 'All':
        return l.priorityAll;
      case 'Low':
        return l.priorityLow;
      case 'Medium':
        return l.priorityMedium;
      case 'High':
        return l.priorityHigh;
      case 'Critical':
        return l.priorityCritical;
      default:
        return p;
    }
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

    // Memoize / pre-group open tasks by importFileId once per build (O(N) instead of O(N*M))
    final Map<int, List<SmartTaskModel>> openTasksByFileId = {};
    for (final t in tasksState.tasks) {
      if (t.importFileId != null && t.status != 'Completed') {
        (openTasksByFileId[t.importFileId!] ??= []).add(t);
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PageHeader(
        title: l.operationalDashboardTitle,
        icon: Icons.dashboard_customize,
        iconColor: AppTheme.cobalt,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white, size: density.buttonIconSize),
            tooltip: l.refresh,
            onPressed: () {
              ref.invalidate(operationalDashboardProvider);
              ref.invalidate(lifecycleBoardSummaryProvider);
              ref.invalidate(smartTasksProvider);
              ref.invalidate(shipmentUpdatesProvider);
              ref.read(operationalDashboardProvider.notifier).fetchDashboard();
              ref.read(smartTasksProvider.notifier).fetchTasks();
            },
          ),
          const SizedBox(width: 6),
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
                          _buildKpiCardsBar(data, density),
                          const SizedBox(height: 16),
                          const ContainerDemurrageRadarCard(),
                          const SizedBox(height: 16),
                          _buildStreamlitLauncherBanner(),
                          const SizedBox(height: 16),
                          _buildQuickActionsBar(),
                          const SizedBox(height: 16),
                          _buildRiskAlertsBanner(data.shipments),
                          const SizedBox(height: 16),
                          _buildDailyCheckinsCard(data.shipments),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    // 1. Shipment Lifecycle Operations Board Summary (6 Phases / 25 Steps)
                    _buildLifecycleOperationsBoardSummary(context, ref, boardAsync, dashboardState, notifier),
                    const SizedBox(height: 16),

                    // 2. Control Bar (Priority Button Group, Customs Broker Dropdown & Debounced Search)
                    _buildControlBar(l, dashboardState, notifier, density),
                    const SizedBox(height: 16),

                    // 3. Results Header & Count
                    _buildResultsHeader(l, dashboardState, density),
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
                  child: _buildErrorCard(l, notifier),
                ),
              ),
              data: (dashboardData) {
                final shipments = dashboardData.shipments;
                if (shipments.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 40),
                      child: _buildEmptyStateCard(l, notifier),
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

  Widget _buildControlBar(AppLocalizations l, OperationalDashboardState dashboardState, OperationalDashboardNotifier notifier, DisplayDensityMode density) {
    final isDark = AppTheme.isDark(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: density.cardPadding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 600;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Priority Button Group (Scrollable if constrained on mobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.priority, style: TextStyle(fontWeight: FontWeight.bold, fontSize: DisplayDensityMode.clampFontSize(density.tableHeaderFontSize), color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ToggleButtons(
                        isSelected: _priorities.map((p) => dashboardState.selectedPriority == p).toList(),
                        onPressed: (index) => notifier.setPriority(_priorities[index]),
                        borderRadius: BorderRadius.circular(6),
                        selectedColor: Colors.white,
                        fillColor: AppTheme.wcagCobalt,
                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                        borderColor: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                        selectedBorderColor: AppTheme.wcagCobalt,
                        constraints: BoxConstraints(
                          minHeight: density.isUltraCompact ? 28 : (density.isCompact ? 32 : 36),
                          minWidth: density.isUltraCompact ? 48 : (density.isCompact ? 54 : 60),
                        ),
                        children: _priorities.map((p) => Text(_getPriorityLabel(p, l), style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize), fontWeight: FontWeight.bold))).toList(),
                      ),
                    ),
                  ],
                ),

                // Customs Broker Dynamic Select Dropdown
                dashboardState.data.when(
                  loading: () => SizedBox(
                    width: isCompact ? constraints.maxWidth : 240,
                    child: ShimmerBox(width: 240, height: density.isUltraCompact ? 32 : (density.isCompact ? 36 : 40), borderRadius: 6),
                  ),
                  error: (_, __) => const SizedBox(),
                  data: (data) {
                    final brokers = data.availableBrokers;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.customsBrokerLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: DisplayDensityMode.clampFontSize(density.tableHeaderFontSize), color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: isCompact ? constraints.maxWidth : 240,
                          child: SearchableDropdownField<String>(
                            value: dashboardState.selectedBrokerName ?? 'All',
                            labelText: '',
                            items: [
                              SearchableDropdownItem(value: 'All', label: l.allBrokers),
                              ...brokers.map((b) => SearchableDropdownItem(value: b.brokerName, label: b.brokerName)),
                            ],
                            onChanged: (val) => notifier.setBroker(val),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Debounced Search Input (200-300ms)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.quickSearchLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: DisplayDensityMode.clampFontSize(density.tableHeaderFontSize), color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: isCompact ? constraints.maxWidth : 260,
                      height: density.isUltraCompact ? 30 : (density.isCompact ? 34 : 38),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontSize: density.inputFontSize),
                        decoration: InputDecoration(
                          hintText: l.dashboardSearchHint,
                          hintStyle: TextStyle(fontSize: density.inputFontSize),
                          prefixIcon: Icon(Icons.search, size: density.buttonIconSize),
                          isDense: true,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: (val) => notifier.setSearchQuery(val),
                      ),
                    ),
                  ],
                ),

                // Reset Filters Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade700,
                    padding: density.buttonPadding,
                    visualDensity: density.visualDensity,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    notifier.resetFilters();
                  },
                  icon: Icon(Icons.restart_alt, size: density.buttonIconSize, color: Colors.white),
                  label: Text(l.resetFilters, style: TextStyle(color: Colors.white, fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize))),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildResultsHeader(AppLocalizations l, OperationalDashboardState dashboardState, DisplayDensityMode density) {
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    return dashboardState.data.maybeWhen(
      data: (dashboardData) {
        final count = dashboardData.shipmentCount;
        final shipments = dashboardData.shipments;
        final dt = DateTime.tryParse(dashboardData.lastUpdatedAt) ?? DateTime.now();
        final lastUpdated = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

        final List<String> activeFilters = [];
        if (dashboardState.selectedPriority != 'All') {
          activeFilters.add('${l.priority} ${_getPriorityLabel(dashboardState.selectedPriority, l)}');
        }
        if (dashboardState.selectedBrokerName != null && dashboardState.selectedBrokerName != 'All') {
          activeFilters.add('${l.customsBrokerLabel} ${dashboardState.selectedBrokerName}');
        }
        if (dashboardState.searchQuery.isNotEmpty) {
          activeFilters.add('${l.quickSearchLabel} "${dashboardState.searchQuery}"');
        }
        if (dashboardState.selectedPhase != null) {
          activeFilters.add('${l.currentPhase}: ${_formatStageName(dashboardState.selectedPhase, isArabic)}');
        }
        final filterSummary = activeFilters.join(' | ');

        final isDark = AppTheme.isDark(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CopyableText(
                  '${l.matchingShipments}: $count ${l.shipmentCountUnit}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.tableHeaderFontSize, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                ),
                Text(
                  '${l.lastUpdated}: $lastUpdated',
                  style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(density.tableCellSecondaryFontSize), color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 4 Linked Output Actions (TSV, Excel, PDF, Dossier)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: density.visualDensity,
                    foregroundColor: AppTheme.cobalt,
                    side: BorderSide(color: AppTheme.cobalt.withValues(alpha: 0.4)),
                  ),
                  icon: Icon(Icons.table_view_outlined, size: density.buttonIconSize, color: AppTheme.cobalt),
                  label: Text(l.operationalExportTsvBtn, style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize), fontWeight: FontWeight.bold)),
                  onPressed: shipments.isEmpty
                      ? null
                      : () async {
                          await OperationalDashboardExportService.exportTsv(
                            context: context,
                            shipments: shipments,
                            filterSummary: filterSummary,
                          );
                        },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: density.visualDensity,
                    foregroundColor: AppTheme.emerald,
                    side: BorderSide(color: AppTheme.emerald.withValues(alpha: 0.4)),
                  ),
                  icon: Icon(Icons.file_present_outlined, size: density.buttonIconSize, color: AppTheme.emerald),
                  label: Text(l.operationalExportExcelBtn, style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize), fontWeight: FontWeight.bold)),
                  onPressed: shipments.isEmpty
                      ? null
                      : () async {
                          await OperationalDashboardExportService.exportCsv(
                            context: context,
                            shipments: shipments,
                            filterSummary: filterSummary,
                          );
                        },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: density.visualDensity,
                    foregroundColor: AppTheme.crimson,
                    side: BorderSide(color: AppTheme.crimson.withValues(alpha: 0.4)),
                  ),
                  icon: Icon(Icons.print_outlined, size: density.buttonIconSize, color: AppTheme.crimson),
                  label: Text(l.operationalExportPdfBtn, style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize), fontWeight: FontWeight.bold)),
                  onPressed: shipments.isEmpty
                      ? null
                      : () async {
                          await OperationalDashboardExportService.printPdf(
                            context: context,
                            shipments: shipments,
                            filterSummary: filterSummary,
                            username: 'Sorour Admin',
                          );
                        },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: density.visualDensity,
                    foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    side: BorderSide(color: isDark ? AppTheme.darkBorderLight : Colors.grey.shade400),
                  ),
                  icon: Icon(Icons.copy_all_outlined, size: density.buttonIconSize, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  label: Text(l.operationalCopyDossierBtn, style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize), fontWeight: FontWeight.bold)),
                  onPressed: shipments.isEmpty
                      ? null
                      : () {
                          OperationalDashboardExportService.copyDossier(
                            context: context,
                            shipments: shipments,
                            filterSummary: filterSummary,
                          );
                        },
                ),
              ],
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildErrorCard(AppLocalizations l, OperationalDashboardNotifier notifier) {
    return Card(
      elevation: 1,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.red.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.wifi_off, color: AppTheme.crimson, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${l.serverConnectionError} (${ApiConstants.serverUrl})', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(l.serverConnectionHint, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
              onPressed: () => notifier.fetchDashboard(),
              icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
              label: Text(l.retry, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(AppLocalizations l, OperationalDashboardNotifier notifier) {
    final isDark = AppTheme.isDark(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 56, color: isDark ? AppTheme.darkTextMuted : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(l.noMatchingShipments, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
            const SizedBox(height: 6),
            Text(l.noMatchingShipmentsDesc, style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
              onPressed: () {
                _searchController.clear();
                notifier.resetFilters();
              },
              child: Text(l.clearFiltersShowAll, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }  Widget _buildShipmentCard(ImportFileModel s, bool isArabic, List<SmartTaskModel> linkedTasks, AppLocalizations l) {
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
                currentStepName: OperationalFormatHelper.formatStageName(s.displayStepKey, isArabic: isArabic),
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
                  currentPhaseName: s.codedStageLabel(l) ?? DisplayNameResolver.resolvePhaseName(s.currentModule, isArabic: isArabic),
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
                AppTheme.snackBar(context, '${l.taskCompletedSuccessfully}: ${task.displayTitle(context.l10n)}', severity: AppSeverity.success),
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

  Widget _buildKpiCardsBar(dynamic data, DisplayDensityMode density) {
    final l = context.l10n;
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final tasksState = ref.watch(smartTasksProvider);
    final shipments = (data.shipments as List<dynamic>).cast<ImportFileModel>();
    final tasks = tasksState.tasks;

    void onFocusShipment(String shipmentCode) {
      _searchController.text = shipmentCode;
      ref.read(operationalDashboardProvider.notifier).setSearchQuery(shipmentCode);
    }

    void onCompleteTask(int taskId) async {
      try {
        await ref.read(smartTasksProvider.notifier).updateTask(taskId, {'status': 'Completed'});
        ref.read(operationalDashboardProvider.notifier).fetchDashboard();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, e.toString(), severity: AppSeverity.danger),
          );
        }
      }
    }

    void onDailyUpdate(ImportFileModel shipment) {
      ShipmentUpdateDialog.show(
        context,
        initialFileId: shipment.importFileId,
        initialFileCode: DisplayNameResolver.resolveShipmentTitle(shipment, isArabic: isArabic),
        initialTargetPhase: shipment.currentModule,
      );
    }

    final todaysTasksRecords = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.todaysTasks,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    final pendingTasksRecords = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.pendingTasks,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    final upcomingShipmentsRecords = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.upcomingShipments,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    final arrivingThisWeekRecords = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.arrivingThisWeek,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    final etaChangesRecords = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.etaChanges,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    final waitingForPaymentRecords = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.waitingForPayment,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    final waitingForForm4Records = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.waitingForForm4,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    final pendingRequirementsRecords = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.pendingRequirements,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    final highPriorityAlertsRecords = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.highPriorityAlerts,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final double cardWidth;
        if (screenWidth < 480) {
          cardWidth = screenWidth; // 1 column on mobile (<480px)
        } else if (screenWidth < 768) {
          cardWidth = (screenWidth - 12) / 2; // 2 columns on large phone / small tablet
        } else if (screenWidth < 1050) {
          cardWidth = (screenWidth - 24) / 3; // 3 columns on tablet
        } else if (screenWidth < 1350) {
          cardWidth = (screenWidth - 36) / 4; // 4 columns on compact desktop
        } else {
          cardWidth = (screenWidth - 48) / 5; // 5 columns on wide desktop
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiTodaysTasks,
              mainValue: '${todaysTasksRecords.length} ${l.tasksCountUnit}',
              subtitle: l.kpiTodaysTasksSub,
              icon: Icons.today,
              color: AppTheme.wcagCobalt,
              records: todaysTasksRecords,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiTodaysTasks,
                icon: Icons.today,
                themeColor: AppTheme.wcagCobalt,
                records: todaysTasksRecords,
                isArabic: isArabic,
              ),
            ),
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiPendingTasks,
              mainValue: '${pendingTasksRecords.length} ${l.tasksCountUnit}',
              subtitle: l.kpiPendingTasksSub,
              icon: Icons.pending_actions,
              color: AppTheme.wcagOrange,
              records: pendingTasksRecords,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiPendingTasks,
                icon: Icons.pending_actions,
                themeColor: AppTheme.wcagOrange,
                records: pendingTasksRecords,
                isArabic: isArabic,
              ),
            ),
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiUpcomingShipments,
              mainValue: '${upcomingShipmentsRecords.length} ${l.shipmentCountUnit}',
              subtitle: l.kpiUpcomingShipmentsSub,
              icon: Icons.near_me,
              color: AppTheme.wcagEmerald,
              records: upcomingShipmentsRecords,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiUpcomingShipments,
                icon: Icons.near_me,
                themeColor: AppTheme.wcagEmerald,
                records: upcomingShipmentsRecords,
                isArabic: isArabic,
              ),
            ),
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiArrivingThisWeek,
              mainValue: '${arrivingThisWeekRecords.length} ${l.shipmentCountUnit}',
              subtitle: l.kpiArrivingThisWeekSub,
              icon: Icons.directions_boat,
              color: AppTheme.wcagCobalt,
              records: arrivingThisWeekRecords,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiArrivingThisWeek,
                icon: Icons.directions_boat,
                themeColor: AppTheme.wcagCobalt,
                records: arrivingThisWeekRecords,
                isArabic: isArabic,
              ),
            ),
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiEtaChanges,
              mainValue: '${etaChangesRecords.length}',
              subtitle: l.kpiEtaChangesSub,
              icon: Icons.edit_calendar,
              color: Colors.purple.shade600,
              records: etaChangesRecords,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiEtaChanges,
                icon: Icons.edit_calendar,
                themeColor: Colors.purple.shade600,
                records: etaChangesRecords,
                isArabic: isArabic,
              ),
            ),
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiWaitingPayment,
              mainValue: '${waitingForPaymentRecords.length}',
              subtitle: l.kpiWaitingPaymentSub,
              icon: Icons.monetization_on,
              color: AppTheme.wcagCrimson,
              records: waitingForPaymentRecords,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiWaitingPayment,
                icon: Icons.monetization_on,
                themeColor: AppTheme.wcagCrimson,
                records: waitingForPaymentRecords,
                isArabic: isArabic,
              ),
            ),
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiWaitingForm4,
              mainValue: '${waitingForForm4Records.length} ${l.shipmentCountUnit}',
              subtitle: l.kpiWaitingForm4Sub,
              icon: Icons.account_balance,
              color: AppTheme.wcagOrange,
              records: waitingForForm4Records,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiWaitingForm4,
                icon: Icons.account_balance,
                themeColor: AppTheme.wcagOrange,
                records: waitingForForm4Records,
                isArabic: isArabic,
              ),
            ),
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiPendingRequirements,
              mainValue: '${pendingRequirementsRecords.length} ${l.shipmentCountUnit}',
              subtitle: l.kpiPendingRequirementsSub,
              icon: Icons.rule,
              color: AppTheme.wcagCrimson,
              records: pendingRequirementsRecords,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiPendingRequirements,
                icon: Icons.rule,
                themeColor: AppTheme.wcagCrimson,
                records: pendingRequirementsRecords,
                isArabic: isArabic,
              ),
            ),
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiHighPriorityAlerts,
              mainValue: '${highPriorityAlertsRecords.length}',
              subtitle: l.kpiHighPriorityAlertsSub,
              icon: Icons.warning_amber,
              color: AppTheme.isDark(context) ? Colors.red.shade400 : AppTheme.wcagCrimson,
              records: highPriorityAlertsRecords,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiHighPriorityAlerts,
                icon: Icons.warning_amber,
                themeColor: AppTheme.isDark(context) ? Colors.red.shade400 : AppTheme.wcagCrimson,
                records: highPriorityAlertsRecords,
                isArabic: isArabic,
              ),
            ),
          ],
        );
      },
    );
  }  Widget _buildKpiCard({
    required DisplayDensityMode density,
    required String title,
    required String mainValue,
    required String subtitle,
    required IconData icon,
    required Color color,
    List<DrillDownItem> records = const [],
    required VoidCallback onTap,
    required String clickHint,
    double cardWidth = 220,
  }) {
    return OperationalKpiCard(
      density: density,
      title: title,
      mainValue: mainValue,
      subtitle: subtitle,
      icon: icon,
      color: color,
      records: records,
      onTap: onTap,
      clickHint: clickHint,
      cardWidth: cardWidth,
    );
  }  Widget _buildRiskAlertsBanner(List<dynamic> shipments) {
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final tasksState = ref.watch(smartTasksProvider);
    final regTasks = tasksState.tasks.where((t) => (t.taskType == 'Regulatory Compliance' || (t.phaseName != null && t.phaseName!.contains('STEP_03'))) && t.status != 'Completed').toList();
    return OperationalRiskAlertsBanner(
      shipments: shipments.cast<ImportFileModel>(),
      regTasks: regTasks,
      isArabic: isArabic,
    );
  }

  String _formatStageName(String? stage, bool isArabic) {
    if (stage == null || stage.trim().isEmpty) return '';
    final s = stage.trim();

    if (s.toUpperCase().startsWith('STEP_') || s.toLowerCase().startsWith('step')) {
      return DisplayNameResolver.resolveStepName(s, isArabic: isArabic);
    }
    if (s.toLowerCase().contains('phase') || s.contains('المرحلة') || s.toUpperCase().startsWith('P')) {
      return DisplayNameResolver.resolvePhaseName(s, isArabic: isArabic);
    }

    final step = DisplayNameResolver.resolveStepName(s, isArabic: isArabic);
    if (step != s && step != '-') return step;

    final phase = DisplayNameResolver.resolvePhaseName(s, isArabic: isArabic);
    if (phase != s && phase != '-') return phase;

    return s;
  }

  Widget _buildDailyCheckinsCard(List<ImportFileModel> shipments) {
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final updatesState = ref.watch(shipmentUpdatesProvider);
    return OperationalDailyCheckinsCard(
      shipments: shipments,
      logs: updatesState.logs,
      isArabic: isArabic,
      onAddDailyUpdate: () => ShipmentUpdateDialog.show(context),
    );
  }

  // ─── Quick Actions & Registration Shortcuts Bar ───────────────────────────
  Widget _buildQuickActionsBar() {
    return OperationalQuickActionsBar(
      onNavigate: (index) => selectNavigationIndex(ref, index),
    );
  }

  // ─── Operations Board Interactive Banner ────────────────────────
  Widget _buildStreamlitLauncherBanner() {
    final l = context.l10n;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 600;
            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.wcagCobalt.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.wcagCobalt.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.dashboard_customize_outlined, color: AppTheme.wcagCobalt, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l.interactiveOperationsBoardTitle,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l.badgeNew,
                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11.0),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.interactiveOperationsBoardDesc,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.wcagCobalt,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => selectNavigationIndex(ref, 48),
                      icon: const Icon(Icons.launch, size: 16, color: Colors.white),
                      label: Text(
                        l.openInteractiveBoard,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.wcagCobalt.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.wcagCobalt.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.dashboard_customize_outlined, color: AppTheme.wcagCobalt, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            l.interactiveOperationsBoardTitle,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            l.badgeNew,
                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11.0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l.interactiveOperationsBoardDesc,
                        style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.wcagCobalt,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => selectNavigationIndex(ref, 48), // Native Lifecycle Board Screen
                  icon: const Icon(Icons.launch, size: 16, color: Colors.white),
                  label: Text(
                    l.openInteractiveBoard,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // =========================================================================
  // Shipment Lifecycle Operations Board Summary (6 Phases / 25 Steps)
  // =========================================================================
  Widget _buildLifecycleOperationsBoardSummary(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<LifecycleBoardSummaryModel> boardAsync,
    OperationalDashboardState dashboardState,
    OperationalDashboardNotifier notifier,
  ) {
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    return OperationalLifecycleBoardSummaryCard(
      boardData: boardAsync.valueOrNull,
      isLoading: boardAsync.isLoading,
      selectedPhase: dashboardState.selectedPhase,
      isArabic: isArabic,
      onTogglePhase: (phase) => notifier.togglePhase(phase),
      onClearFilter: dashboardState.selectedPhase != null
          ? () => notifier.togglePhase(dashboardState.selectedPhase!)
          : null,
      onOpenFullBoard: () => selectNavigationIndex(ref, 48),
    );
  }

}

