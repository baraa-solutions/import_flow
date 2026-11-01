import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/invoice_bl_match_session_model.dart';
import '../../providers/import_documentation_provider.dart';
import '../idoc_ui.dart';
import 'sessions/invoice_bl_session_details_dialog.dart';
import 'sessions/invoice_bl_sessions_export_helper.dart';
import 'sessions/invoice_bl_sessions_table.dart';
import 'sessions/invoice_bl_sessions_toolbar.dart';

/// Sessions registry tab view for Screen 22: Invoice vs B/L Matcher.
///
/// Provides historical matching sessions, KPI stats, filtering, and session restoration.
class InvoiceBlMatcherSessionsView extends ConsumerStatefulWidget {
  final List<dynamic> importFiles;
  final int? activeFileId;
  final int? activeSessionId;
  final VoidCallback onNewSession;
  final ValueChanged<InvoiceBLMatchSessionModel> onLoadSession;
  final ValueChanged<InvoiceBLMatchSessionModel> onCloneSession;
  final ValueChanged<InvoiceBLMatchSessionModel> onDeleteSession;

  const InvoiceBlMatcherSessionsView({
    super.key,
    required this.importFiles,
    required this.activeFileId,
    required this.activeSessionId,
    required this.onNewSession,
    required this.onLoadSession,
    required this.onCloneSession,
    required this.onDeleteSession,
  });

  @override
  ConsumerState<InvoiceBlMatcherSessionsView> createState() => _InvoiceBlMatcherSessionsViewState();
}

class _InvoiceBlMatcherSessionsViewState extends ConsumerState<InvoiceBlMatcherSessionsView> {
  final TextEditingController _searchSessionsCtrl = TextEditingController();
  String _selectedStatusFilter = 'ALL'; // ALL, DRAFT, CERTIFIED
  int? _filterImportFileId;

  @override
  void initState() {
    super.initState();
    _filterImportFileId = widget.activeFileId;
  }

  @override
  void dispose() {
    _searchSessionsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(invoiceBLMatchSessionsProvider);

    return sessionsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsetsDirectional.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              context.l10n.idocALoadingMatchingSessionsRegistry,
              style: IdocUi.sectionTitle(context),
            ),
          ],
        ),
      ),
      error: (e, st) => IdocStateView.error(
        message: context.l10n.idocAFailedToLoadTheSessionsRegistry(e),
        actionLabel: context.l10n.retry,
        onAction: () => ref
            .read(invoiceBLMatchSessionsProvider.notifier)
            .fetchSessions(importFileId: widget.activeFileId),
      ),
      data: (sessions) {
        final filtered = sessions.where((s) {
          if (_selectedStatusFilter == 'DRAFT' && !s.isDraft) return false;
          if (_selectedStatusFilter == 'CERTIFIED' && s.isDraft) return false;
          if (_filterImportFileId != null && s.importFileId != _filterImportFileId) return false;

          final query = _searchSessionsCtrl.text.trim().toLowerCase();
          if (query.isNotEmpty) {
            final codeMatch = s.sessionCode.toLowerCase().contains(query);
            final titleMatch = (s.sessionTitle ?? '').toLowerCase().contains(query);
            final notesMatch = (s.sessionNotes ?? '').toLowerCase().contains(query);
            final fileMatch = (s.importFileCode ?? '').toLowerCase().contains(query);
            if (!codeMatch && !titleMatch && !notesMatch && !fileMatch) return false;
          }
          return true;
        }).toList();

        final totalCount = sessions.length;
        final certifiedCount = sessions.where((s) => !s.isDraft).length;
        final draftCount = sessions.where((s) => s.isDraft).length;
        final avgScore = sessions.isEmpty
            ? 0.0
            : (sessions.map((s) => s.matchScore).reduce((a, b) => a + b) / sessions.length);

        return SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InvoiceBlSessionsToolbar(
                totalCount: totalCount,
                certifiedCount: certifiedCount,
                draftCount: draftCount,
                avgScore: avgScore,
                onNewSession: widget.onNewSession,
                searchController: _searchSessionsCtrl,
                onSearchChanged: () => setState(() {}),
                importFiles: widget.importFiles,
                filterImportFileId: _filterImportFileId,
                onFilterImportFileChanged: (val) => setState(() => _filterImportFileId = val),
                selectedStatusFilter: _selectedStatusFilter,
                onStatusFilterChanged: (val) => setState(() => _selectedStatusFilter = val),
                onCopyTsv: () => InvoiceBlSessionsExportHelper.copySessionsTable(context, filtered),
                onExportExcel: () => InvoiceBlSessionsExportHelper.exportSessionsToExcel(
                  context,
                  filtered,
                  activeFileId: widget.activeFileId,
                ),
                onExportPdf: () => InvoiceBlSessionsExportHelper.exportSessionsToPdf(
                  context,
                  filtered,
                  activeFileId: widget.activeFileId,
                ),
                onRefresh: () => ref
                    .read(invoiceBLMatchSessionsProvider.notifier)
                    .fetchSessions(importFileId: widget.activeFileId),
                hasFilteredSessions: filtered.isNotEmpty,
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                Container(
                  decoration: AppTheme.cardDecorationOf(context),
                  child: IdocStateView.empty(
                    message: context.l10n.idocANoMatchingSessionsFoundForThe,
                    icon: Icons.inventory_2_outlined,
                    actionLabel: context.l10n.invoiceBlMatchNewSessionBtn,
                    onAction: widget.onNewSession,
                  ),
                )
              else
                InvoiceBlSessionsTable(
                  sessions: filtered,
                  activeSessionId: widget.activeSessionId,
                  onCloneSession: widget.onCloneSession,
                  onViewSessionDetails: (s) => InvoiceBlSessionDetailsDialog.show(
                    context: context,
                    session: s,
                    onCloneSession: widget.onCloneSession,
                    onLoadSession: widget.onLoadSession,
                  ),
                  onLoadSession: widget.onLoadSession,
                  onDeleteSession: widget.onDeleteSession,
                ),
            ],
          ),
        );
      },
    );
  }
}
