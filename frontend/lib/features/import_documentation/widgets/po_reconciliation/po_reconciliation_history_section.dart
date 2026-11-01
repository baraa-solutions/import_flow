import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../purchase_orders/utils/po_packing_matcher.dart';
import '../../models/po_reconciliation_session_model.dart';
import '../idoc_ui.dart';
import 'po_reconciliation_dialogs.dart';
import 'po_reconciliation_localizer.dart';
import 'po_reconciliation_table_exporter.dart';

/// Registry of historical and saved PO Reconciliation sessions.
/// Includes KPI stats, full text search, status filters, EnterpriseDataTable,
/// and row-level operations (View details, Load in editor, Clone, Print, Delete).
class PoReconciliationHistorySection extends StatefulWidget {
  final List<POReconciliationSessionModel> allSessions;
  final List<ImportFileModel> importFiles;
  final ValueChanged<POReconciliationSessionModel> onLoadIntoEditor;
  final ValueChanged<POReconciliationSessionModel> onCloneSession;
  final void Function(POReconciliationSessionModel session)? onShowDetails;
  final void Function(POReconciliationSessionModel session)? onPrintReport;
  final void Function(POReconciliationSessionModel session) onDeleteSession;
  final void Function(List<POReconciliationSessionModel> sessions)? onCopySessions;
  final void Function(List<POReconciliationSessionModel> sessions)? onExportExcel;
  final void Function(List<POReconciliationSessionModel> sessions)? onExportPdf;
  final VoidCallback onRefresh;
  final VoidCallback onNewSession;
  final String Function(BuildContext context, String status)? getLocalizedSessionStatus;

  const PoReconciliationHistorySection({
    super.key,
    required this.allSessions,
    required this.importFiles,
    required this.onLoadIntoEditor,
    required this.onCloneSession,
    this.onShowDetails,
    this.onPrintReport,
    required this.onDeleteSession,
    this.onCopySessions,
    this.onExportExcel,
    this.onExportPdf,
    required this.onRefresh,
    required this.onNewSession,
    this.getLocalizedSessionStatus,
  });

  @override
  State<PoReconciliationHistorySection> createState() => _PoReconciliationHistorySectionState();
}

class _PoReconciliationHistorySectionState extends State<PoReconciliationHistorySection> {
  final TextEditingController _searchHistoryCtrl = TextEditingController();
  String _statusFilter = 'All';

  static String _formatWeight(double val) => PoPackingMatcher.formatWeight(val);

  String _getLocalizedStatus(BuildContext context, String status) {
    return widget.getLocalizedSessionStatus?.call(context, status) ??
        PoReconciliationLocalizer.getLocalizedSessionStatus(context, status);
  }

  void _handleCopySessions(List<POReconciliationSessionModel> sessions) {
    if (widget.onCopySessions != null) {
      widget.onCopySessions!(sessions);
    } else {
      PoReconciliationTableExporter.copySessionsTable(context, sessions, _getLocalizedStatus);
    }
  }

  void _handleExportExcel(List<POReconciliationSessionModel> sessions) {
    if (widget.onExportExcel != null) {
      widget.onExportExcel!(sessions);
    } else {
      PoReconciliationTableExporter.exportSessionsToExcel(context, sessions, null, _getLocalizedStatus);
    }
  }

  void _handleExportPdf(List<POReconciliationSessionModel> sessions) {
    if (widget.onExportPdf != null) {
      widget.onExportPdf!(sessions);
    } else {
      PoReconciliationTableExporter.exportSessionsToPdf(context, sessions, null, _getLocalizedStatus);
    }
  }

  void _handleShowDetails(POReconciliationSessionModel sess) {
    if (widget.onShowDetails != null) {
      widget.onShowDetails!(sess);
    } else {
      PoReconciliationDialogs.showSessionDetailsModal(context, sess, importFiles: widget.importFiles, onLoadIntoEditor: widget.onLoadIntoEditor);
    }
  }

  void _handlePrintReport(POReconciliationSessionModel sess) {
    if (widget.onPrintReport != null) {
      widget.onPrintReport!(sess);
    } else {
      PoReconciliationDialogs.showPrintReportDialog(context, sess, importFiles: widget.importFiles, getLocalizedSessionStatus: _getLocalizedStatus);
    }
  }

  @override
  void dispose() {
    _searchHistoryCtrl.dispose();
    super.dispose();
  }

  Widget _buildStatusFilterChip(String value, String label) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _statusFilter = value);
      },
      selectedColor: AppTheme.cobalt.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.cobalt : AppTheme.charcoal,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    // Apply filters
    final filtered = widget.allSessions.where((s) {
      if (_statusFilter != 'All' && s.overallStatus != _statusFilter) return false;
      if (_searchHistoryCtrl.text.isNotEmpty) {
        final q = _searchHistoryCtrl.text.trim().toLowerCase();
        final code = s.sessionCode.toLowerCase();
        final fCode = (s.importFileCode ?? '').toLowerCase();
        final rawFileCode = s.importFileCode ?? 'IMP-${s.importFileId}';
        final shipmentTitle = rawFileCode.isNotEmpty
            ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: widget.importFiles, isArabic: isAr).toLowerCase()
            : '';
        final imp = (s.importerName ?? '').toLowerCase();
        final inv = (s.finalInvoiceNumber ?? '').toLowerCase();
        final pl = (s.finalPackingListNumber ?? '').toLowerCase();
        final acid = (s.acidNumber ?? '').toLowerCase();
        return code.contains(q) ||
            fCode.contains(q) ||
            shipmentTitle.contains(q) ||
            imp.contains(q) ||
            inv.contains(q) ||
            pl.contains(q) ||
            acid.contains(q);
      }
      return true;
    }).toList();

    final matchedSessions = widget.allSessions.where((s) => s.overallStatus == 'FULLY_MATCHED').length;
    final varianceSessions = widget.allSessions.where((s) => s.overallStatus != 'FULLY_MATCHED').length;
    final totalVal = widget.allSessions.fold(0.0, (sum, s) => sum + s.totalInvoiceAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. SECTION HEADER CARD
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.borderOf(context)),
          ),
          color: isDark ? AppTheme.darkCardBackground : AppTheme.cloudWhite,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.charcoal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder_shared_rounded, color: AppTheme.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.poRecHistorySectionTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.poRecHistorySectionSubtitle,
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryOf(context)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l.poRecHistoryTotalSessionsBadge(widget.allSessions.length),
                    style: const TextStyle(color: AppTheme.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. STATS BAR
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IdocUi.metrics([
              MetricCardData(
                title: l.poRecHistoryKpiTotalSessions,
                shortTitle: l.poRecHistoryKpiTotalSessions,
                value: '${widget.allSessions.length}',
                icon: Icons.all_inbox_rounded,
                color: AppTheme.cobalt,
              ),
              MetricCardData(
                title: l.poRecHistoryKpiFullMatch,
                shortTitle: l.poRecHistoryKpiFullMatch,
                value: '$matchedSessions',
                icon: Icons.check_circle_rounded,
                color: AppTheme.emerald,
              ),
              MetricCardData(
                title: l.poRecHistoryKpiWithVariances,
                shortTitle: l.poRecHistoryKpiWithVariances,
                value: '$varianceSessions',
                icon: Icons.warning_amber_rounded,
                color: AppTheme.orange,
              ),
              MetricCardData(
                title: l.poRecHistoryKpiTotalCertifiedValue,
                shortTitle: l.poRecHistoryKpiTotalCertifiedValue,
                value: totalVal.toStringAsFixed(0),
                icon: Icons.monetization_on_rounded,
                color: AppTheme.wcagEmerald,
              ),
            ]),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IdocUi.fit(AppButton(
                label: l.poRecHistoryNewSessionButton,
                icon: Icons.add_rounded,
                variant: AppButtonVariant.primary,
                onPressed: widget.onNewSession,
              )),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. SEARCH & FILTER TOOLBAR
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 950;
            final searchField = TextField(
              key: const Key('historySearchField'),
              controller: _searchHistoryCtrl,
              decoration: InputDecoration(
                hintText: l.poRecHistorySearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchHistoryCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() => _searchHistoryCtrl.clear());
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (_) => setState(() {}),
            );

            final chipsAndActions = Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildStatusFilterChip('All', l.poRecHistoryFilterAll(widget.allSessions.length)),
                _buildStatusFilterChip('FULLY_MATCHED', l.poRecHistoryFilterMatched),
                _buildStatusFilterChip('ACCEPTED_WITH_WARNINGS', l.poRecHistoryFilterWarnings),
                _buildStatusFilterChip('CRITICAL_DISCREPANCY', l.poRecHistoryFilterCritical),
                IconButton(
                  key: const Key('copySessionsBtn'),
                  icon: const Icon(Icons.copy_all, color: AppTheme.cobalt),
                  tooltip: l.copyPoReconBtn,
                  onPressed: filtered.isEmpty ? null : () => _handleCopySessions(filtered),
                ),
                IconButton(
                  key: const Key('exportSessionsExcelBtn'),
                  icon: const Icon(Icons.table_view_outlined, color: AppTheme.emerald),
                  tooltip: l.exportPoReconExcelBtn,
                  onPressed: filtered.isEmpty ? null : () => _handleExportExcel(filtered),
                ),
                IconButton(
                  key: const Key('exportSessionsPdfBtn'),
                  icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson),
                  tooltip: l.exportPoReconPdfBtn,
                  onPressed: filtered.isEmpty ? null : () => _handleExportPdf(filtered),
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: AppTheme.textPrimaryOf(context)),
                  tooltip: l.poRecHistoryRefreshTooltip,
                  onPressed: widget.onRefresh,
                ),
              ],
            );

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderOf(context)),
              ),
              child: isCompact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 10),
                        chipsAndActions,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(flex: 3, child: searchField),
                        const SizedBox(width: 16),
                        Expanded(flex: 5, child: chipsAndActions),
                      ],
                    ),
            );
          },
        ),
        const SizedBox(height: 16),

        // 4. DATA TABLE OR EMPTY STATE
        filtered.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open_rounded, size: 64, color: AppTheme.textMutedOf(context)),
                      const SizedBox(height: 16),
                      Text(
                        widget.allSessions.isEmpty ? l.poRecHistoryEmptyTitle : l.poRecHistoryNoMatchFilter,
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryOf(context)),
                      ),
                      const SizedBox(height: 12),
                      IdocUi.fit(AppButton(
                        label: l.poRecHistoryCreateFirstSessionButton,
                        icon: Icons.add,
                        variant: AppButtonVariant.primary,
                        onPressed: widget.onNewSession,
                      )),
                    ],
                  ),
                ),
              )
            : EnterpriseDataTable<POReconciliationSessionModel>(
                data: filtered,
                storageKey: 'po_reconciliation_sessions_table',
                columns: [
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'actions',
                    title: l.poRecHistoryColActions,
                    width: 245,
                    isSortable: false,
                    isSearchable: false,
                    cellBuilder: (context, sess, index) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_rounded, size: 18, color: AppTheme.cobalt),
                            tooltip: l.poRecHistoryViewDetailsTooltip,
                            onPressed: () => _handleShowDetails(sess),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded, size: 20, color: AppTheme.emerald),
                            tooltip: l.poRecHistoryLoadIntoEditorTooltip,
                            onPressed: () => widget.onLoadIntoEditor(sess),
                          ),
                          IconButton(
                            key: Key('cloneSessionRowBtn_${sess.sessionId}'),
                            icon: const Icon(Icons.copy_all_rounded, size: 18, color: AppTheme.cobalt),
                            tooltip: l.clonePoReconRecordTooltip,
                            onPressed: () => widget.onCloneSession(sess),
                          ),
                          IconButton(
                            icon: Icon(Icons.print_rounded, size: 18, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                            tooltip: l.poRecHistoryPrintTooltip,
                            onPressed: () => _handlePrintReport(sess),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.crimson),
                            tooltip: l.poRecHistoryDeleteTooltip,
                            onPressed: () => widget.onDeleteSession(sess),
                          ),
                        ],
                      );
                    },
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'index',
                    title: l.poRecHistoryColIndex,
                    width: 60,
                    isSortable: false,
                    searchValue: (sess) => '${filtered.indexOf(sess) + 1}',
                    cellBuilder: (context, sess, index) => Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'session_code',
                    title: l.poRecHistoryColSessionCode,
                    width: 230,
                    isSortable: true,
                    searchValue: (sess) => sess.sessionCode,
                    exportValue: (sess) => sess.sessionCode,
                    cellBuilder: (context, sess, index) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                sess.sessionCode,
                                style: const TextStyle(
                                  color: AppTheme.cobalt,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.cobalt),
                            tooltip: l.copy,
                            onPressed: () => CopyHelper.copy(context, sess.sessionCode),
                          ),
                        ],
                      );
                    },
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'import_file',
                    title: l.poRecHistoryColImportFileImporter,
                    width: 250,
                    isSortable: true,
                    searchValue: (sess) => '${sess.importFileCode ?? ""} ${sess.importerName ?? ""}',
                    exportValue: (sess) => '${sess.importFileCode ?? ""} - ${sess.importerName ?? ""}',
                    cellBuilder: (context, sess, index) {
                      final rawFileCode = sess.importFileCode ?? 'IMP-${sess.importFileId}';
                      final shipmentTitle = rawFileCode.isNotEmpty
                          ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: widget.importFiles, isArabic: isAr)
                          : '';
                      final fileDisplay = shipmentTitle.isNotEmpty && shipmentTitle != rawFileCode
                          ? '$shipmentTitle ($rawFileCode)'
                          : (rawFileCode.isNotEmpty ? rawFileCode : '—');

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(fileDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5), overflow: TextOverflow.ellipsis),
                          if (sess.importerName != null && sess.importerName!.isNotEmpty)
                            Text(sess.importerName!, style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)), overflow: TextOverflow.ellipsis),
                        ],
                      );
                    },
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'invoice_and_packing',
                    title: l.poRecHistoryColInvoicePacking,
                    width: 200,
                    isSortable: false,
                    searchValue: (sess) => '${sess.finalInvoiceNumber ?? ""} ${sess.finalPackingListNumber ?? ""}',
                    exportValue: (sess) => '${sess.finalInvoiceNumber ?? ""} | ${sess.finalPackingListNumber ?? ""}',
                    cellBuilder: (context, sess, index) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_rounded, size: 13, color: AppTheme.cobalt),
                              const SizedBox(width: 4),
                              Expanded(child: Text(sess.finalInvoiceNumber ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_rounded, size: 13, color: AppTheme.orange),
                              const SizedBox(width: 4),
                              Expanded(child: Text(sess.finalPackingListNumber ?? '—', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'total_amount',
                    title: l.poRecHistoryColTotalValue,
                    width: 140,
                    isSortable: true,
                    searchValue: (sess) => '${sess.totalInvoiceAmount} ${sess.currency}',
                    exportValue: (sess) => '${sess.totalInvoiceAmount.toStringAsFixed(2)} ${sess.currency}',
                    cellBuilder: (context, sess, index) => Text(
                      '${sess.totalInvoiceAmount.toStringAsFixed(2)} ${sess.currency}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.cobalt),
                    ),
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'packages_weight',
                    title: l.poRecHistoryColPackagesWeight,
                    width: 170,
                    isSortable: false,
                    searchValue: (sess) => '${sess.totalPackages} ${sess.totalGrossWeightKg}',
                    exportValue: (sess) => '${sess.totalPackages.toStringAsFixed(0)} pkgs | ${_formatWeight(sess.totalGrossWeightKg)} kg',
                    cellBuilder: (context, sess, index) => Text(
                      '${sess.totalPackages.toStringAsFixed(0)} ${l.poRecPackagesUnit} | ${_formatWeight(sess.totalGrossWeightKg)} ${l.poRecKgUnit}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'cbm',
                    title: l.poRecHistoryColCbm,
                    width: 110,
                    isSortable: true,
                    searchValue: (sess) => '${sess.totalCbm}',
                    exportValue: (sess) => '${sess.totalCbm.toStringAsFixed(3)} m³',
                    cellBuilder: (context, sess, index) => Text(
                      '${sess.totalCbm.toStringAsFixed(3)} ${l.poRecCbmUnit}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.orange),
                    ),
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'status',
                    title: l.poRecHistoryColStatus,
                    width: 170,
                    isSortable: true,
                    searchValue: (sess) => sess.overallStatus,
                    exportValue: (sess) => _getLocalizedStatus(context, sess.overallStatus),
                    cellBuilder: (context, sess, index) => PoReconciliationDialogs.buildSessionStatusBadge(context, sess.overallStatus),
                  ),
                  EnterpriseColumn<POReconciliationSessionModel>(
                    id: 'created_at',
                    title: l.poRecHistoryColSavedDate,
                    width: 120,
                    isSortable: true,
                    searchValue: (sess) => sess.createdAt ?? '',
                    exportValue: (sess) => (sess.createdAt != null && sess.createdAt!.length >= 10) ? sess.createdAt!.substring(0, 10) : '—',
                    cellBuilder: (context, sess, index) {
                      final dateStr = (sess.createdAt != null && sess.createdAt!.length >= 10) ? sess.createdAt!.substring(0, 10) : '—';
                      return Text(dateStr, style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)));
                    },
                  ),
                ],
              ),
      ],
    );
  }
}
