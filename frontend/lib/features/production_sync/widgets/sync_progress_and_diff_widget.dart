import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../services/local_process_sync_service.dart';
import '../services/production_sync_export_service.dart';

class SyncProgressAndDiffWidget extends StatefulWidget {
  final SyncProgressEvent? progress;
  final SyncDiffSummary? diffSummary;
  final bool isRunning;
  final VoidCallback onCheckDiff;

  const SyncProgressAndDiffWidget({
    super.key,
    required this.progress,
    required this.diffSummary,
    required this.isRunning,
    required this.onCheckDiff,
  });

  @override
  State<SyncProgressAndDiffWidget> createState() => _SyncProgressAndDiffWidgetState();
}

class _SyncProgressAndDiffWidgetState extends State<SyncProgressAndDiffWidget> {
  String _filter = 'MODIFIED'; // 'ALL', 'MODIFIED', 'MATCHED'
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hasDiff = widget.diffSummary != null && widget.diffSummary!.tables.isNotEmpty;
    final tables = widget.diffSummary?.tables ?? [];

    final filteredTables = tables.where((t) {
      if (_searchQuery.isNotEmpty && !t.tableName.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_filter == 'MODIFIED') {
        return t.hasChanges;
      } else if (_filter == 'MATCHED') {
        return t.isMatch;
      }
      return true;
    }).toList();

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Live Progress Bar Card ──────────────────────────────────────
          if (widget.isRunning || widget.progress != null) ...[
            _buildLiveProgressCard(widget.progress, l),
            const SizedBox(height: 10),
          ],

          // ── 2. Database Changes & Diff Summary Panel ───────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Panel Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9), // Slate 100
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.table_chart_outlined, size: 17, color: AppTheme.cobalt),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.prodSyncDiffPanelTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: AppTheme.charcoal,
                              ),
                            ),
                            Text(
                              l.prodSyncDiffPanelSubtitle,
                              style: const TextStyle(color: Colors.black54, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                      if (widget.diffSummary != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.diffSummary!.totalNewRecords > 0
                                ? AppTheme.emerald.withOpacity(0.15)
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: widget.diffSummary!.totalNewRecords > 0
                                  ? AppTheme.emerald
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.diffSummary!.totalNewRecords > 0
                                    ? Icons.add_circle_outline_rounded
                                    : Icons.check_circle_outline_rounded,
                                size: 13,
                                color: widget.diffSummary!.totalNewRecords > 0
                                    ? AppTheme.emerald
                                    : Colors.grey.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.diffSummary!.totalNewRecords > 0
                                    ? l.prodSyncDiffStatusNewRecords(widget.diffSummary!.totalNewRecords)
                                    : l.prodSyncDiffStatusMatched,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: widget.diffSummary!.totalNewRecords > 0
                                      ? AppTheme.emerald
                                      : Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Quick TSV & Excel export buttons for table diff
                        IconButton(
                          icon: const Icon(Icons.table_view_rounded, size: 16, color: AppTheme.cobalt),
                          tooltip: l.prodSyncExportTsvBtn,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => ProductionSyncExportService.saveTableDiffTsvToFile(
                            context: context,
                            tables: widget.diffSummary!.tables,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.file_download_outlined, size: 16, color: AppTheme.emerald),
                          tooltip: l.prodSyncExportExcelBtn,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => ProductionSyncExportService.saveTableDiffCsvToFile(
                            context: context,
                            tables: widget.diffSummary!.tables,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.cobalt,
                          side: const BorderSide(color: AppTheme.cobalt),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: widget.isRunning
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cobalt),
                              )
                            : const Icon(Icons.compare_arrows_rounded, size: 14),
                        label: Text(l.prodSyncDiffCheckBtn, style: const TextStyle(fontSize: 11)),
                        onPressed: widget.isRunning ? null : widget.onCheckDiff,
                      ),
                    ],
                  ),
                ),

              // Filter & Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    // Filter Chips
                    Wrap(
                      spacing: 6,
                      children: [
                        _buildFilterChip('MODIFIED', l.prodSyncDiffFilterModified, Icons.difference_rounded),
                        _buildFilterChip('ALL', l.prodSyncDiffFilterAll(tables.length), Icons.list_alt_rounded),
                        _buildFilterChip('MATCHED', l.prodSyncDiffFilterMatched, Icons.done_all_rounded),
                      ],
                    ),
                    const SizedBox(width: 10),
                    // Search Input
                    Expanded(
                      child: SizedBox(
                        height: 30,
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(fontSize: 11),
                          decoration: InputDecoration(
                            hintText: l.prodSyncSearchTablesHint,
                            hintStyle: const TextStyle(fontSize: 10.5, color: Colors.grey),
                            prefixIcon: const Icon(Icons.search, size: 13, color: Colors.grey),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, size: 13, color: AppTheme.cobalt),
                                        tooltip: l.prodSyncCopyFieldTooltip,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                        onPressed: () => CopyHelper.copy(context, _searchQuery),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.clear, size: 13, color: Colors.grey),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      ),
                                    ],
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Tables List
              if (!hasDiff)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rule_folder_outlined, size: 20, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l.prodSyncDiffEmptyInstruction,
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                )
              else if (filteredTables.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  alignment: Alignment.center,
                  child: Text(
                    _filter == 'MODIFIED'
                        ? l.prodSyncDiffAllMatchedSuccess
                        : l.prodSyncDiffNoSearchResults,
                    style: TextStyle(
                      color: _filter == 'MODIFIED' ? AppTheme.emerald : Colors.grey,
                      fontWeight: _filter == 'MODIFIED' ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11.5,
                    ),
                  ),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    itemCount: filteredTables.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final item = filteredTables[index];
                      final isCurrentlySyncing = widget.progress != null &&
                          widget.progress!.table == item.tableName &&
                          widget.isRunning;

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 4.5, horizontal: 6),
                        decoration: BoxDecoration(
                          color: isCurrentlySyncing
                              ? AppTheme.cobalt.withOpacity(0.08)
                              : item.hasChanges
                                  ? AppTheme.emerald.withOpacity(0.04)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            if (isCurrentlySyncing)
                              const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cobalt),
                              )
                            else
                              Icon(
                                item.hasChanges
                                    ? Icons.add_circle_rounded
                                    : Icons.check_circle_rounded,
                                size: 14,
                                color: item.hasChanges ? AppTheme.emerald : Colors.grey.shade400,
                              ),
                            const SizedBox(width: 8),
                            // Table Name with Copy Trigger
                            Expanded(
                              flex: 3,
                              child: InkWell(
                                onTap: () => CopyHelper.copy(
                                  context,
                                  item.tableName,
                                  customMessage: l.prodSyncCopyRowSummarySuccess,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.tableName,
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            fontWeight: item.hasChanges ? FontWeight.bold : FontWeight.w500,
                                            color: isCurrentlySyncing
                                                ? AppTheme.cobalt
                                                : item.hasChanges
                                                    ? AppTheme.charcoal
                                                    : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 11,
                                        color: Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Counts: Dev -> Prod
                            Expanded(
                              flex: 2,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cobalt.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Dev: ${item.devCount}',
                                        style: const TextStyle(fontSize: 10, color: AppTheme.cobalt, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_forward_rounded, size: 10, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.emerald.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Prod: ${item.prodCount}',
                                        style: const TextStyle(fontSize: 10, color: AppTheme.emerald, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Diff Status Badge
                            _buildDiffBadge(item, l),
                            const SizedBox(width: 6),
                            // Quick Copy Row Summary Action
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 13, color: Colors.grey),
                              tooltip: l.prodSyncCopyRowSummaryBtn,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              onPressed: () {
                                final summary = '${item.tableName} | Dev: ${item.devCount} | Prod: ${item.prodCount} | Diff: ${item.diff > 0 ? "+${item.diff}" : item.diff}';
                                CopyHelper.copy(context, summary, customMessage: l.prodSyncCopyRowSummarySuccess);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon) {
    final isSelected = _filter == key;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 12,
        color: isSelected ? Colors.white : Colors.grey.shade700,
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.cobalt,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        fontSize: 10.5,
        color: isSelected ? Colors.white : Colors.grey.shade800,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _filter = key),
    );
  }

  Widget _buildDiffBadge(SyncTableDiff item, AppLocalizations l) {
    if (item.status == 'NEW_DATA' || item.diff > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.emerald,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          l.prodSyncDiffStatusNewRecords(item.diff),
          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
        ),
      );
    } else if (item.status == 'NEW_TABLE') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.orange,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          l.prodSyncDiffStatusNewTable,
          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
        ),
      );
    } else if (item.diff < 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.shade700,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          l.prodSyncDiffStatusProdSurplus(item.diff),
          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          l.prodSyncDiffStatusMatched,
          style: const TextStyle(color: Colors.black54, fontSize: 9.5, fontWeight: FontWeight.w600),
        ),
      );
    }
  }

  Widget _buildLiveProgressCard(SyncProgressEvent? event, AppLocalizations l) {
    final percent = event?.percent ?? (widget.isRunning ? 10 : 100);
    final isComplete = percent >= 100;
    final defaultAction = l.prodSyncCompareTablesBtn;
    final message = event?.message.isNotEmpty == true
        ? event!.message
        : (widget.isRunning ? l.prodSyncActionStarting(defaultAction) : l.prodSyncActionSuccess(defaultAction));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isComplete ? AppTheme.emerald.withOpacity(0.5) : AppTheme.cobalt.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isComplete ? AppTheme.emerald : AppTheme.cobalt).withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Percentage Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isComplete ? AppTheme.emerald : AppTheme.cobalt,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '$percent%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Message / Stage Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                        color: isComplete ? AppTheme.emerald : AppTheme.charcoal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (event != null && event.totalTables > 0)
                      Text(
                        l.prodSyncProgressTablesCount(event.currentIndex, event.totalTables, event.totalSynced),
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                  ],
                ),
              ),
              if (widget.isRunning)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cobalt),
                )
              else if (isComplete)
                const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          // Horizontal Smooth Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100.0,
              minHeight: 7,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? AppTheme.emerald : AppTheme.cobalt,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
