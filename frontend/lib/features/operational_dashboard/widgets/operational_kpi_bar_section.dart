import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../../shipment_updates/widgets/shipment_update_dialog.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';
import '../providers/operational_dashboard_provider.dart';
import 'dashboard_card_drilldown_dialog.dart';
import 'operational_kpi_card.dart';

/// Responsive KPI Cards section with full drill-down modal integrations.
class OperationalKpiBarSection extends ConsumerWidget {
  final dynamic data;
  final DisplayDensityMode density;
  final void Function(String shipmentCode) onFocusShipment;

  const OperationalKpiBarSection({
    super.key,
    required this.data,
    required this.density,
    required this.onFocusShipment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final tasksState = ref.watch(smartTasksProvider);
    final shipments = (data.shipments as List<dynamic>).cast<ImportFileModel>();
    final tasks = tasksState.tasks;

    void onCompleteTask(int taskId) async {
      try {
        await ref.read(smartTasksProvider.notifier).updateTask(taskId, {'status': 'Completed'});
        ref.read(operationalDashboardProvider.notifier).fetchDashboard();
      } catch (e) {
        if (context.mounted) {
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

    return SelectionArea(
      child: LayoutBuilder(
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
              OperationalKpiCard(
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
              OperationalKpiCard(
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
              OperationalKpiCard(
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
              OperationalKpiCard(
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
              OperationalKpiCard(
                density: density,
                cardWidth: cardWidth,
                title: l.kpiEtaChanges,
                mainValue: '${etaChangesRecords.length} ${l.shipmentCountUnit}',
                subtitle: l.kpiEtaChangesSub,
                icon: Icons.edit_calendar,
                color: AppTheme.wcagOrange,
                records: etaChangesRecords,
                clickHint: l.drillDownCardClickHint,
                onTap: () => DashboardCardDrillDownDialog.show(
                  context: context,
                  title: l.kpiEtaChanges,
                  icon: Icons.edit_calendar,
                  themeColor: AppTheme.wcagOrange,
                  records: etaChangesRecords,
                  isArabic: isArabic,
                ),
              ),
              OperationalKpiCard(
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
              OperationalKpiCard(
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
              OperationalKpiCard(
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
              OperationalKpiCard(
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
      ),
    );
  }
}
