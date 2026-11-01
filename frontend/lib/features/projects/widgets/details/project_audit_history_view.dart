import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../audit_logs/providers/audit_logs_provider.dart';
import '../../models/project_model.dart';

class ProjectAuditHistoryView extends ConsumerWidget {
  final ProjectModel project;

  const ProjectAuditHistoryView({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    if (project.projectId == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(l10n.rowHistoryEmpty, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      );
    }

    final timelineAsync = ref.watch(
      entityAuditTimelineProvider((entityType: 'Project', entityId: project.projectId!)),
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isArabic ? 'حركات وسجل التغييرات المدققة' : 'Audited Change Log',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: l10n.rowHistoryRefreshTooltip,
                  onPressed: () {
                    ref.invalidate(entityAuditTimelineProvider((entityType: 'Project', entityId: project.projectId!)));
                  },
                ),
              ],
            ),
          ),
          timelineAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cobalt)),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                l10n.auditLogsFetchError(err.toString()),
                style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
              ),
            ),
            data: (logs) {
              if (logs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          l10n.rowHistoryEmpty,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  Color actionColor;
                  IconData actionIcon;
                  switch (log.action.toUpperCase()) {
                    case 'CREATE':
                      actionColor = AppTheme.emerald;
                      actionIcon = Icons.add_circle_outline;
                      break;
                    case 'UPDATE':
                      actionColor = AppTheme.cobalt;
                      actionIcon = Icons.edit_outlined;
                      break;
                    case 'DELETE':
                      actionColor = AppTheme.crimson;
                      actionIcon = Icons.remove_circle_outline;
                      break;
                    default:
                      actionColor = AppTheme.charcoal;
                      actionIcon = Icons.info_outline;
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: actionColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(actionIcon, size: 16, color: actionColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.auditActionLabel(log.action),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: actionColor,
                                  ),
                                ),
                                Text(
                                  log.performedAt.toLocal().toString().split('.').first,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              log.changesSummary ?? l10n.systemMutationFallback,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.performedByUser(log.performedBy),
                              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
