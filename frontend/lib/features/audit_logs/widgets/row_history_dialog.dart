import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/audit_log_model.dart';
import '../providers/audit_logs_provider.dart';

class RowHistoryDialog extends ConsumerStatefulWidget {
  final String entityType;
  final int entityId;
  final String entityTitle;

  const RowHistoryDialog({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.entityTitle,
  });

  static void show(BuildContext context, {required String entityType, required int entityId, required String entityTitle}) {
    showDialog(
      context: context,
      builder: (ctx) => RowHistoryDialog(
        entityType: entityType,
        entityId: entityId,
        entityTitle: entityTitle,
      ),
    );
  }

  @override
  ConsumerState<RowHistoryDialog> createState() => _RowHistoryDialogState();
}

class _RowHistoryDialogState extends ConsumerState<RowHistoryDialog> {
  @override
  void initState() {
    super.initState();
    // Force instant live refetch from API when dialog opens!
    Future.microtask(() {
      ref.invalidate(entityAuditTimelineProvider((entityType: widget.entityType, entityId: widget.entityId)));
    });
  }

  void _copyTimelineTsv(BuildContext context, List<AuditLogModel> logs) {
    final l10n = context.l10n;
    final buffer = StringBuffer();
    buffer.writeln(
      '${l10n.auditLogsTsvHeaderLogId}\t'
      '${l10n.auditLogsTsvHeaderAction}\t'
      '${l10n.auditLogsTsvHeaderEntityType}\t'
      '${l10n.auditLogsTsvHeaderEntityCode}\t'
      '${l10n.auditLogsTsvHeaderSummary}\t'
      '${l10n.auditLogsTsvHeaderPerformedBy}\t'
      '${l10n.auditLogsTsvHeaderTimestamp}',
    );

    for (final l in logs) {
      buffer.writeln(
        '${l.logId}\t'
        '${l10n.auditActionLabel(l.action)}\t'
        '${l10n.auditEntityLabel(l.entityType)}\t'
        '${l.entityCode ?? l.entityId}\t'
        '${(l.changesSummary ?? l10n.systemMutationFallback).replaceAll('\t', ' ').replaceAll('\n', ' ')}\t'
        '${l.performedBy}\t'
        '${l.performedAt.toLocal().toString().split('.').first}',
      );
    }

    CopyHelper.copy(
      context,
      buffer.toString().trimRight(),
      customMessage: l10n.rowHistoryExportTsvSuccess,
    );
  }

  String _buildLogSummary(BuildContext context, AuditLogModel log) {
    final l10n = context.l10n;
    final b = StringBuffer();
    b.writeln('📋 #${log.logId} — ${l10n.auditActionLabel(log.action)}');
    b.writeln('📦 ${l10n.auditEntityLabel(log.entityType)}: ${log.entityCode ?? log.entityId}');
    b.writeln('📝 ${log.changesSummary ?? l10n.systemMutationFallback}');
    b.writeln('👤 ${l10n.performedByUser(log.performedBy)}');
    b.writeln('⏰ ${log.performedAt.toLocal().toString().split('.').first}');
    return b.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final timelineAsync = ref.watch(entityAuditTimelineProvider((entityType: widget.entityType, entityId: widget.entityId)));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: SizedBox(
          width: 640,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              // Banner Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: const BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadiusDirectional.only(topStart: Radius.circular(16), topEnd: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.rowHistoryDialogTitle,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            l10n.rowHistoryDialogSubtitle(l10n.auditEntityLabel(widget.entityType), widget.entityTitle),
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    timelineAsync.maybeWhen(
                      data: (logs) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.table_view_rounded, color: Colors.white),
                            tooltip: l10n.rowHistoryExportTsvBtn,
                            onPressed: () => _copyTimelineTsv(context, logs),
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
                            tooltip: l10n.rowHistoryExportPdfBtn,
                            onPressed: () => MasterDataExportService.printOrSaveAuditLogsListPdf(
                              logs,
                              title: '${l10n.auditEntityLabel(widget.entityType)}: ${widget.entityTitle}',
                            ),
                          ),
                        ],
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      tooltip: l10n.rowHistoryRefreshTooltip,
                      onPressed: () {
                        ref.invalidate(entityAuditTimelineProvider((entityType: widget.entityType, entityId: widget.entityId)));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Timeline Body
              Expanded(
                child: timelineAsync.when(
                  loading: () => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: AppTheme.cobalt),
                        const SizedBox(height: 12),
                        Text(l10n.rowHistoryLoading, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  error: (err, stack) => Center(
                    child: Text(l10n.auditLogsFetchError(err.toString()), style: const TextStyle(color: AppTheme.crimson)),
                  ),
                  data: (logs) {
                    if (logs.isEmpty) {
                      return Center(
                        child: Text(l10n.rowHistoryEmpty, style: const TextStyle(color: Colors.grey, fontSize: 15)),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return _buildTimelineItem(log, isLatest: index == 0);
                      },
                    );
                  },
                ),
              ),

              // Bottom Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadiusDirectional.only(bottomStart: Radius.circular(16), bottomEnd: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.rowHistoryCloseBtn),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(AuditLogModel log, {required bool isLatest}) {
    final l10n = context.l10n;
    Color actionColor;
    IconData actionIcon;

    switch (log.action.toUpperCase()) {
      case 'CREATE':
        actionColor = AppTheme.emerald;
        actionIcon = Icons.add_circle;
        break;
      case 'UPDATE':
        actionColor = AppTheme.cobalt;
        actionIcon = Icons.edit_note;
        break;
      case 'DELETE':
        actionColor = AppTheme.crimson;
        actionIcon = Icons.remove_circle;
        break;
      case 'RESTORE':
        actionColor = AppTheme.orange;
        actionIcon = Icons.settings_backup_restore;
        break;
      default:
        actionColor = AppTheme.charcoal;
        actionIcon = Icons.info;
    }

    final formattedDate = log.performedAt.toLocal().toString().split('.').first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLatest ? actionColor.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLatest ? actionColor.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: isLatest ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(actionIcon, color: actionColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: actionColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l10n.auditActionLabel(log.action),
                        style: TextStyle(color: actionColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formattedDate,
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.copy_all_rounded, size: 18, color: Colors.grey),
                          tooltip: l10n.rowHistoryCopySummaryBtn,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => CopyHelper.copy(
                            context,
                            _buildLogSummary(context, log),
                            customMessage: l10n.rowHistoryCopySummarySuccess,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  log.changesSummary ?? l10n.systemMutationFallback,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.performedByUser(log.performedBy),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
