// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/paged_data_table/paged_table_column.dart';
import '../../../../core/widgets/paged_data_table/row_action.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/smart_task_model.dart';
import '../../providers/smart_tasks_provider.dart';
import '../smart_task_dialog.dart';
import 'smart_tasks_export_helper.dart';

class SmartTasksTableColumns {
  const SmartTasksTableColumns._();

  static List<PagedTableColumn<SmartTaskModel>> build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return [
      PagedTableColumn<SmartTaskModel>(
        id: 'code',
        label: (loc) => loc.smartTasksColCode,
        width: 140,
        pinned: true,
        numeric: true,
        sortKey: 'task_code',
        cell: (ctx, t) => InkWell(
          onTap: () => CopyHelper.copy(
            context,
            t.taskCode,
            customMessage: l.smartTaskCodeBadgeLabel,
          ),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.cobalt.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.copy_rounded, size: 11, color: AppTheme.cobalt),
                const SizedBox(width: 3),
                Text(
                  t.taskCode,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        exportValue: (t) => t.taskCode,
      ),
      PagedTableColumn<SmartTaskModel>(
        id: 'type',
        label: (loc) => loc.smartTasksColType,
        width: 140,
        cell: (ctx, t) {
          final isSys = t.taskType == 'System Generated';
          final typeLabel = isSys ? l.smartTasksTypeSystem : l.smartTasksTypeManual;
          return Chip(
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
          );
        },
        exportValue: (t) => t.taskType,
      ),
      PagedTableColumn<SmartTaskModel>(
        id: 'title',
        label: (loc) => loc.smartTasksColTitle,
        width: 280,
        cell: (ctx, t) {
          final shipments = ref.watch(importFilesProvider).value ?? <ImportFileModel>[];
          final cleanTitle = t.displayTitle(context.l10n);
          final cleanDesc = t.displayDescription(context.l10n, shipments: shipments);
          return Column(
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
          );
        },
        exportValue: (t) => t.displayTitle(context.l10n),
      ),
      PagedTableColumn<SmartTaskModel>(
        id: 'shipment',
        label: (loc) => loc.smartTasksColShipment,
        width: 180,
        cell: (ctx, t) {
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          final shipments = ref.watch(importFilesProvider).value ?? <ImportFileModel>[];
          if (t.importFileCode == null) {
            return Text(
              l.smartTasksGeneralBadge,
              style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
            );
          }
          final commercialName = DisplayNameResolver.resolveShipmentNameByCode(t.importFileCode, shipments: shipments, isArabic: isAr);
          return InkWell(
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
          );
        },
        exportValue: (t) => t.importFileCode ?? '',
      ),
      PagedTableColumn<SmartTaskModel>(
        id: 'priority',
        label: (loc) => loc.smartTasksColPriority,
        width: 110,
        sortKey: 'priority',
        cell: (ctx, t) {
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
          return Chip(
            visualDensity: VisualDensity.compact,
            label: Text(priorityLabel, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: bg,
          );
        },
        exportValue: (t) => t.priority,
      ),
      PagedTableColumn<SmartTaskModel>(
        id: 'reminder',
        label: (loc) => loc.smartTasksColReminder,
        width: 130,
        cell: (ctx, t) {
          final reminderLabel = l.smartTaskReminderTypeLabel(t.reminderType);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_active, size: 14, color: AppTheme.orange),
              const SizedBox(width: 4),
              Flexible(child: Text(reminderLabel, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
            ],
          );
        },
        exportValue: (t) => t.reminderType,
      ),
      PagedTableColumn<SmartTaskModel>(
        id: 'dueDate',
        label: (loc) => loc.smartTasksColDueDate,
        width: 120,
        numeric: true,
        sortKey: 'due_date',
        cell: (ctx, t) => Text(t.dueDate ?? '-', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
        exportValue: (t) => t.dueDate ?? '-',
      ),
      PagedTableColumn<SmartTaskModel>(
        id: 'status',
        label: (loc) => loc.smartTasksColStatus,
        width: 120,
        sortKey: 'status',
        cell: (ctx, t) {
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
          return Chip(
            visualDensity: VisualDensity.compact,
            label: Text(statusLabel, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: bg,
          );
        },
        exportValue: (t) => t.status,
      ),
    ];
  }

  static List<RowAction<SmartTaskModel>> buildRowActions(
    BuildContext context,
    WidgetRef ref,
  ) {
    return [
      RowAction<SmartTaskModel>(
        kind: RowActionKind.view,
        icon: Icons.open_in_new_rounded,
        label: (loc) => loc.isArabic ? 'الانتقال للمرحلة' : 'Go to Stage',
        color: AppTheme.cobalt,
        run: (t) {
          final routeIdx = SmartTasksExportHelper.resolveRouteIndexForTask(t);
          selectNavigationIndex(ref, routeIdx);
        },
      ),
      RowAction<SmartTaskModel>(
        kind: RowActionKind.edit,
        icon: Icons.edit,
        label: (loc) => loc.smartTasksActionEditTooltip,
        color: AppTheme.cobalt,
        run: (t) {
          SmartTaskDialog.show(context, taskToEdit: t);
        },
      ),
      RowAction<SmartTaskModel>(
        kind: RowActionKind.delete,
        icon: Icons.delete_outline,
        label: (loc) => loc.smartTasksActionDeleteTooltip,
        color: AppTheme.crimson,
        isDestructive: true,
        run: (t) async {
          final confirm = await AppConfirmDialog.showDelete(
            context,
            entityName: t.taskCode,
          );
          if (confirm == true) {
            await ref.read(smartTasksProvider.notifier).deleteTask(t.taskId);
            ref.read(smartTasksPagedProvider.notifier).refresh();
          }
        },
      ),
    ];
  }
}
