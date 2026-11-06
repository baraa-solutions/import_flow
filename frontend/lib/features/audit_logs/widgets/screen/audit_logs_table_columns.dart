import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/paged_data_table/paged_table_column.dart';
import '../../../../core/widgets/paged_data_table/row_action.dart';
import '../../models/audit_log_model.dart';
import '../row_history_dialog.dart';

class AuditLogsTableColumns {
  static List<PagedTableColumn<AuditLogModel>> build(BuildContext context) {
    final l10n = context.l10n;

    return [
      PagedTableColumn<AuditLogModel>(
        id: 'log_id',
        label: (l) => l.auditLogsTsvHeaderLogId,
        width: 100,
        pinned: true,
        numeric: true,
        sortKey: 'log_id',
        cell: (ctx, log) => Text(
          '#${log.logId}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: AppTheme.cobalt,
          ),
        ),
        exportValue: (log) => log.logId.toString(),
      ),
      PagedTableColumn<AuditLogModel>(
        id: 'action',
        label: (l) => l.auditLogsTsvHeaderAction,
        width: 120,
        pinned: true,
        cell: (ctx, log) {
          final act = log.action.toUpperCase();
          AppSeverity severity = AppSeverity.info;
          if (act == 'CREATE') {
            severity = AppSeverity.success;
          } else if (act == 'UPDATE') {
            severity = AppSeverity.info;
          } else if (act == 'DELETE') {
            severity = AppSeverity.danger;
          } else if (act == 'RESTORE') {
            severity = AppSeverity.warning;
          }
          return AppStatusBadge(
            label: l10n.auditActionLabel(log.action),
            severity: severity,
          );
        },
        exportValue: (log) => l10n.auditActionLabel(log.action),
      ),
      PagedTableColumn<AuditLogModel>(
        id: 'entity_type',
        label: (l) => l.auditLogsTsvHeaderEntityType,
        width: 150,
        sortKey: 'entity_type',
        cell: (ctx, log) => Text(
          l10n.auditEntityLabel(log.entityType),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        exportValue: (log) => l10n.auditEntityLabel(log.entityType),
      ),
      PagedTableColumn<AuditLogModel>(
        id: 'entity_code',
        label: (l) => l.auditLogsTsvHeaderEntityCode,
        width: 140,
        cell: (ctx, log) {
          final displayCode = log.entityCode ?? '#${log.entityId}';
          return InkWell(
            onTap: () => CopyHelper.copy(ctx, displayCode),
            borderRadius: BorderRadius.circular(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    displayCode,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.copy_rounded, size: 12, color: Colors.grey),
              ],
            ),
          );
        },
        exportValue: (log) => log.entityCode ?? log.entityId.toString(),
      ),
      PagedTableColumn<AuditLogModel>(
        id: 'changes_summary',
        label: (l) => l.auditLogsTsvHeaderSummary,
        width: 320,
        cell: (ctx, log) {
          final summary = log.changesSummary ?? l10n.systemMutationFallback;
          return Text(
            summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          );
        },
        exportValue: (log) => log.changesSummary ?? '',
      ),
      PagedTableColumn<AuditLogModel>(
        id: 'performed_by',
        label: (l) => l.auditLogsTsvHeaderPerformedBy,
        width: 150,
        sortKey: 'performed_by',
        cell: (ctx, log) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline, size: 14, color: AppTheme.cobalt),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                log.performedBy,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        exportValue: (log) => log.performedBy,
      ),
      PagedTableColumn<AuditLogModel>(
        id: 'performed_at',
        label: (l) => l.auditLogsTsvHeaderTimestamp,
        width: 170,
        numeric: true,
        sortKey: 'created_at',
        cell: (ctx, log) {
          final formatted = log.performedAt.toLocal().toString().split('.').first;
          return Text(
            formatted,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Colors.black87,
            ),
          );
        },
        exportValue: (log) => log.performedAt.toIso8601String(),
      ),
    ];
  }

  static List<RowAction<AuditLogModel>> buildRowActions(BuildContext context) {
    return [
      RowAction<AuditLogModel>(
        kind: RowActionKind.view,
        icon: Icons.history_rounded,
        label: (l) => l.isArabic ? 'عرض الجدول الزمني' : 'View Timeline',
        color: AppTheme.cobalt,
        run: (log) {
          RowHistoryDialog.show(
            context,
            entityType: log.entityType,
            entityId: log.entityId,
            entityTitle: log.entityCode ?? '#${log.entityId}',
          );
        },
      ),
    ];
  }
}
