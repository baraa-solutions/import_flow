// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/services/master_data_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/enterprise_data_table/enterprise_data_table.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/smart_task_model.dart';
import '../../providers/smart_tasks_provider.dart';
import '../smart_task_dialog.dart';
import 'smart_tasks_export_helper.dart';

class SmartTasksTableColumns {
  const SmartTasksTableColumns._();

  static Widget _wrapCell({
    required Widget child,
    required String value,
    String? rowSummary,
  }) =>
      CopyableTableCell(
        value: value,
        rowSummary: rowSummary,
        child: child,
      );

  static List<EnterpriseColumn<SmartTaskModel>> build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return [
      EnterpriseColumn<SmartTaskModel>(
        id: 'code',
        title: l.smartTasksColCode,
        isLocked: true,
        searchValue: (t) => t.taskCode,
        exportValue: (t) => t.taskCode,
        cellBuilder: (ctx, t, idx) {
          final rowSummary = SmartTasksExportHelper.buildSmartTaskRowSummary(context, ref, t);
          return _wrapCell(
            value: t.taskCode,
            rowSummary: rowSummary,
            child: InkWell(
              onTap: () => CopyHelper.copy(
                context,
                t.taskCode,
                customMessage: l.smartTaskCodeBadgeLabel,
              ),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.cobalt.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.copy_rounded, size: 12, color: AppTheme.cobalt),
                    const SizedBox(width: 4),
                    Text(
                      t.taskCode,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      EnterpriseColumn<SmartTaskModel>(
        id: 'type',
        title: l.smartTasksColType,
        searchValue: (t) => t.taskType,
        exportValue: (t) => t.taskType,
        cellBuilder: (ctx, t, idx) {
          final isSys = t.taskType == 'System Generated';
          final typeLabel = isSys ? l.smartTasksTypeSystem : l.smartTasksTypeManual;
          final rowSummary = SmartTasksExportHelper.buildSmartTaskRowSummary(context, ref, t);
          return _wrapCell(
            value: typeLabel,
            rowSummary: rowSummary,
            child: Chip(
              visualDensity: VisualDensity.compact,
              label: Text(
                typeLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: isSys
                      ? (isDark ? Colors.purple.shade200 : Colors.purple.shade900)
                      : (isDark ? Colors.blue.shade200 : Colors.blue.shade900),
                ),
              ),
              backgroundColor: isSys
                  ? (isDark ? Colors.purple.shade900.withOpacity(0.3) : Colors.purple.shade50)
                  : (isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50),
            ),
          );
        },
      ),
      EnterpriseColumn<SmartTaskModel>(
        id: 'title',
        title: l.smartTasksColTitle,
        flex: 2,
        searchValue: (t) => '${t.displayTitle(context.l10n)} ${t.title} ${t.description ?? ""}',
        exportValue: (t) => t.displayTitle(context.l10n),
        cellBuilder: (ctx, t, idx) {
          final shipments = ref.watch(importFilesProvider).value ?? <ImportFileModel>[];
          final cleanTitle = t.displayTitle(context.l10n);
          final cleanDesc = t.displayDescription(context.l10n, shipments: shipments);
          final rowSummary = SmartTasksExportHelper.buildSmartTaskRowSummary(context, ref, t);
          return _wrapCell(
            value: '$cleanTitle $cleanDesc'.trim(),
            rowSummary: rowSummary,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cleanTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                if (cleanDesc.isNotEmpty)
                  Text(
                    cleanDesc,
                    style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          );
        },
      ),
      EnterpriseColumn<SmartTaskModel>(
        id: 'shipment',
        title: l.smartTasksColShipment,
        searchValue: (t) {
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          final shipments = ref.watch(importFilesProvider).value ?? <ImportFileModel>[];
          return DisplayNameResolver.resolveShipmentTitleByCode(t.importFileCode, shipments: shipments, isArabic: isAr);
        },
        exportValue: (t) {
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          final shipments = ref.watch(importFilesProvider).value ?? <ImportFileModel>[];
          return t.importFileCode != null
              ? DisplayNameResolver.resolveShipmentTitleByCode(t.importFileCode, shipments: shipments, isArabic: isAr)
              : l.smartTasksGeneralBadge;
        },
        cellBuilder: (ctx, t, idx) {
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          final shipments = ref.watch(importFilesProvider).value ?? <ImportFileModel>[];
          final rowSummary = SmartTasksExportHelper.buildSmartTaskRowSummary(context, ref, t);
          if (t.importFileCode == null) {
            return _wrapCell(
              value: l.smartTasksGeneralBadge,
              rowSummary: rowSummary,
              child: Text(
                l.smartTasksGeneralBadge,
                style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
              ),
            );
          }
          final commercialName = DisplayNameResolver.resolveShipmentNameByCode(t.importFileCode, shipments: shipments, isArabic: isAr);
          return _wrapCell(
            value: '$commercialName (${t.importFileCode})',
            rowSummary: rowSummary,
            child: InkWell(
              onTap: () => CopyHelper.copy(
                context,
                t.importFileCode!,
                customMessage: l.smartTaskImportFileBadgeLabel,
              ),
              borderRadius: BorderRadius.circular(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    commercialName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkBorder : AppTheme.charcoal.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.copy_rounded, size: 10, color: AppTheme.cobalt),
                        const SizedBox(width: 3),
                        Text(
                          t.importFileCode!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.cobalt,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      EnterpriseColumn<SmartTaskModel>(
        id: 'priority',
        title: l.smartTasksColPriority,
        sortComparator: (a, b) => SmartTasksExportHelper.priorityWeight(b.priority).compareTo(SmartTasksExportHelper.priorityWeight(a.priority)),
        searchValue: (t) => t.priority,
        exportValue: (t) => t.priority,
        cellBuilder: (ctx, t, idx) {
          final rowSummary = SmartTasksExportHelper.buildSmartTaskRowSummary(context, ref, t);
          Color bg;
          switch (t.priority.toLowerCase()) {
            case 'critical':
            case 'high':
              bg = Colors.red.shade700;
              break;
            case 'medium':
              bg = Colors.orange.shade800;
              break;
            default:
              bg = Colors.green.shade700;
          }
          final priorityLabel = l.smartTaskPriorityLabel(t.priority);
          return _wrapCell(
            value: priorityLabel,
            rowSummary: rowSummary,
            child: Chip(
              visualDensity: VisualDensity.compact,
              label: Text(priorityLabel, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: bg,
            ),
          );
        },
      ),
      EnterpriseColumn<SmartTaskModel>(
        id: 'reminder',
        title: l.smartTasksColReminder,
        searchValue: (t) => t.reminderType,
        exportValue: (t) => t.reminderType,
        cellBuilder: (ctx, t, idx) {
          final rowSummary = SmartTasksExportHelper.buildSmartTaskRowSummary(context, ref, t);
          final reminderLabel = l.smartTaskReminderTypeLabel(t.reminderType);
          return _wrapCell(
            value: reminderLabel,
            rowSummary: rowSummary,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications_active, size: 14, color: AppTheme.orange),
                const SizedBox(width: 4),
                Text(reminderLabel, style: const TextStyle(fontSize: 11)),
              ],
            ),
          );
        },
      ),
      EnterpriseColumn<SmartTaskModel>(
        id: 'dueDate',
        title: l.smartTasksColDueDate,
        searchValue: (t) => t.dueDate ?? '',
        exportValue: (t) => t.dueDate ?? '-',
        cellBuilder: (ctx, t, idx) {
          final rowSummary = SmartTasksExportHelper.buildSmartTaskRowSummary(context, ref, t);
          return _wrapCell(
            value: t.dueDate ?? '-',
            rowSummary: rowSummary,
            child: Text(t.dueDate ?? '-', style: const TextStyle(fontSize: 11)),
          );
        },
      ),
      EnterpriseColumn<SmartTaskModel>(
        id: 'status',
        title: l.smartTasksColStatus,
        searchValue: (t) => t.status,
        exportValue: (t) => t.status,
        cellBuilder: (ctx, t, idx) {
          final rowSummary = SmartTasksExportHelper.buildSmartTaskRowSummary(context, ref, t);
          Color bg;
          switch (t.status.toLowerCase()) {
            case 'completed':
              bg = AppTheme.emerald;
              break;
            case 'in progress':
              bg = AppTheme.cobalt;
              break;
            default:
              bg = Colors.grey.shade600;
          }
          final statusLabel = l.smartTaskStatusLabel(t.status);
          return _wrapCell(
            value: statusLabel,
            rowSummary: rowSummary,
            child: Chip(
              visualDensity: VisualDensity.compact,
              label: Text(statusLabel, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: bg,
            ),
          );
        },
      ),
      EnterpriseColumn<SmartTaskModel>(
        id: 'actions',
        title: l.smartTasksColActions,
        isSortable: false,
        isSearchable: false,
        isLocked: true,
        cellBuilder: (ctx, t, idx) {
          final rowSummary = SmartTasksExportHelper.buildSmartTaskRowSummary(context, ref, t);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded, color: AppTheme.cobalt, size: 16),
                tooltip: Localizations.localeOf(context).languageCode == 'ar'
                    ? 'الانتقال للمرحلة لتنفيذها أو تعديلها'
                    : 'Navigate to stage to execute or edit',
                onPressed: () {
                  final routeIdx = SmartTasksExportHelper.resolveRouteIndexForTask(t);
                  selectNavigationIndex(ref, routeIdx);
                },
              ),
              if (t.status != 'Completed')
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 18),
                  tooltip: l.smartTasksActionCompleteTooltip,
                  onPressed: () {
                    ref.read(smartTasksProvider.notifier).updateTask(t.taskId, {'status': 'Completed'});
                  },
                ),
              IconButton(
                icon: Icon(Icons.copy_rounded, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal, size: 16),
                tooltip: l.smartTaskCopySummaryBtn,
                onPressed: () {
                  CopyHelper.copy(
                    context,
                    rowSummary,
                    customMessage: l.smartTaskCopySummarySuccess,
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.print_outlined, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal, size: 16),
                tooltip: l.smartTaskPrintPdfTooltip,
                onPressed: () => MasterDataExportService.printOrSaveSmartTaskPdf(t),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: AppTheme.cobalt, size: 16),
                tooltip: l.smartTasksActionEditTooltip,
                onPressed: () => SmartTaskDialog.show(context, taskToEdit: t),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                tooltip: l.smartTasksActionDeleteTooltip,
                onPressed: () => ref.read(smartTasksProvider.notifier).deleteTask(t.taskId),
              ),
            ],
          );
        },
      ),
    ];
  }
}
