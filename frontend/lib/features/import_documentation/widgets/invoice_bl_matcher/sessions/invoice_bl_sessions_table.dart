import 'package:flutter/material.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/copyable_data_helper.dart';
import '../../../models/invoice_bl_match_session_model.dart';
import '../../idoc_ui.dart';

class InvoiceBlSessionsTable extends StatelessWidget {
  final List<InvoiceBLMatchSessionModel> sessions;
  final int? activeSessionId;
  final ValueChanged<InvoiceBLMatchSessionModel> onCloneSession;
  final ValueChanged<InvoiceBLMatchSessionModel> onViewSessionDetails;
  final ValueChanged<InvoiceBLMatchSessionModel> onLoadSession;
  final ValueChanged<InvoiceBLMatchSessionModel> onDeleteSession;

  const InvoiceBlSessionsTable({
    super.key,
    required this.sessions,
    required this.activeSessionId,
    required this.onCloneSession,
    required this.onViewSessionDetails,
    required this.onLoadSession,
    required this.onDeleteSession,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderOf(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppTheme.charcoal),
            headingTextStyle: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 12),
            dataRowMinHeight: 52,
            dataRowMaxHeight: 64,
            horizontalMargin: 16,
            columnSpacing: 20,
            columns: [
              DataColumn(label: Text(context.l10n.idocASessionCode)),
              DataColumn(label: Text(context.l10n.idocAImportFile)),
              DataColumn(label: Text(context.l10n.idocASessionTitleAndNotes)),
              DataColumn(label: Text(context.l10n.status)),
              DataColumn(label: Text(context.l10n.idocAMatchScore)),
              DataColumn(label: Text(context.l10n.idocADiscrepancies)),
              DataColumn(label: Text(context.l10n.idocASessionDate)),
              DataColumn(label: Text(context.l10n.actions)),
            ],
            rows: sessions.map((session) {
              final isDraft = session.isDraft;
              return DataRow(
                color: WidgetStateProperty.resolveWith((states) {
                  if (session.sessionId == activeSessionId) {
                    return AppTheme.cobalt.withValues(alpha: 0.08);
                  }
                  return null;
                }),
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(session.sessionCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 14, color: AppTheme.cobalt),
                          tooltip: context.l10n.idocACopyCode,
                          onPressed: () {
                            CopyHelper.copy(
                              context,
                              session.sessionCode,
                              customMessage: context.l10n.idocASessionCodeCopiedToTheClipboard,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      session.importFileCode ?? 'IMP-${session.importFileId}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.charcoal),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            session.sessionTitle ?? context.l10n.idocADefaultSessionTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (session.sessionNotes != null && session.sessionNotes!.isNotEmpty)
                            Text(
                              session.sessionNotes!,
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    IdocStatusChip(
                      label: isDraft ? context.l10n.idocADraft : context.l10n.idocACertified,
                      severity: isDraft ? AppSeverity.warning : AppSeverity.success,
                      icon: isDraft ? Icons.edit_document : Icons.check_circle,
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 50,
                          child: LinearProgressIndicator(
                            value: session.matchScore / 100.0,
                            backgroundColor: AppTheme.borderOf(context),
                            color: session.matchScore >= 90
                                ? AppTheme.emerald
                                : (session.matchScore >= 70 ? AppTheme.orange : AppTheme.crimson),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${session.matchScore.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: session.matchScore >= 90
                                ? AppTheme.emerald
                                : (session.matchScore >= 70 ? AppTheme.orange : AppTheme.crimson),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: session.discrepancyCount > 0
                            ? AppTheme.crimson.withValues(alpha: 0.1)
                            : AppTheme.emerald.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        session.discrepancyCount > 0
                            ? context.l10n.idocADiscrepancyCount(session.discrepancyCount)
                            : context.l10n.idocAFullyMatched,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: session.discrepancyCount > 0 ? AppTheme.crimson : AppTheme.emerald,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      session.createdAt.contains('T') ? session.createdAt.split('T').first : session.createdAt,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: Key('cloneSessionBtn_${session.sessionId}'),
                          icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                          tooltip: context.l10n.idocACloneSessionAsANewDraft,
                          onPressed: () => onCloneSession(session),
                        ),
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18, color: AppTheme.cobalt),
                          tooltip: context.l10n.idocAViewSessionDetailsAndMatrix,
                          onPressed: () => onViewSessionDetails(session),
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_circle_outline, size: 18, color: AppTheme.emerald),
                          tooltip: context.l10n.idocARestoreAndLoadTheSessionIn,
                          onPressed: () => onLoadSession(session),
                        ),
                        if (isDraft)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.crimson),
                            tooltip: context.l10n.idocADeleteDraft,
                            onPressed: () => onDeleteSession(session),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
