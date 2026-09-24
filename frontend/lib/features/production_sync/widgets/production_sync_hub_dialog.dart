import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../providers/production_sync_provider.dart';
import '../services/local_process_sync_service.dart';
import '../services/production_sync_export_service.dart';
import 'sync_console_widget.dart';
import 'sync_progress_and_diff_widget.dart';

class ProductionSyncHubDialog extends ConsumerStatefulWidget {
  final LocalProcessSyncService? service;
  const ProductionSyncHubDialog({super.key, this.service});

  static Future<void> show(BuildContext context, {LocalProcessSyncService? service}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ProductionSyncHubDialog(service: service),
    );
  }

  @override
  ConsumerState<ProductionSyncHubDialog> createState() => _ProductionSyncHubDialogState();
}

class _ProductionSyncHubDialogState extends ConsumerState<ProductionSyncHubDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final LocalProcessSyncService _service;

  final List<ConsoleLogLine> _consoleLogs = [];
  bool _isRunning = false;
  String _currentAction = '';
  SyncProgressEvent? _progress;
  SyncDiffSummary? _diffSummary;

  late LocalDbStats _devStats;
  late LocalDbStats _prodStats;
  late List<LocalBackupEntry> _backups;

  @override
  void initState() {
    super.initState();
    _service = widget.service ??
        LocalProcessSyncService(ref.read(productionSyncServiceProvider));
    _tabController = TabController(length: 2, vsync: this);
    _refreshLocalData();
    Future.microtask(() => _checkDiffsSilently());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshLocalData() {
    setState(() {
      _devStats = _service.getDbStats(_service.devDbPath);
      _prodStats = _service.getDbStats(_service.prodDbPath);
      _backups = _service.listBackups();
    });
  }

  Future<void> _checkDiffsSilently() async {
    try {
      await _service.compareDatabases(
        onOutput: (l) => _appendLog(l),
        onError: (l) => _appendLog(l, isError: true),
        onDiffSummary: (d) {
          if (mounted) setState(() => _diffSummary = d);
        },
      );
    } catch (_) {}
  }

  void _appendLog(String text, {bool isError = false}) {
    if (mounted) {
      setState(() {
        _consoleLogs.add(ConsoleLogLine(text, isError: isError));
      });
    }
  }

  Future<void> _confirmAndRestoreBackup(LocalBackupEntry b) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.history_rounded, color: AppTheme.orange),
            const SizedBox(width: 8),
            Text(l.prodSyncConfirmRestoreTitleDialog, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.prodSyncConfirmRestoreMsgDialog(b.filename)),
            const SizedBox(height: 10),
            Text(
              l.prodSyncConfirmRestoreSafeNotice,
              style: const TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.prodSyncCancelAction)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.prodSyncRestoreNowAction),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final restoreActionLabel = '${l.prodSyncRestoreActionBtn} ${b.filename}';
      await _executeAction(restoreActionLabel, () async {
        try {
          final api = ref.read(productionSyncServiceProvider);
          final target = b.tag.contains('dev') ? 'dev' : 'prod';
          final res = await api.restoreBackup(filename: b.filename, target: target);
          _appendLog('✅ ${res.message}');
          return 0;
        } catch (e) {
          _appendLog('❌ ${l.prodSyncActionFailed(e.toString())}', isError: true);
          return 1;
        }
      });
    }
  }

  Future<void> _executeAction(String actionName, Future<int> Function() task) async {
    if (_isRunning) return;

    final l = context.l10n;
    setState(() {
      _isRunning = true;
      _currentAction = actionName;
      _consoleLogs.add(ConsoleLogLine('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'));
      _consoleLogs.add(ConsoleLogLine(l.prodSyncActionStarting(actionName)));
    });

    try {
      final code = await task();
      _refreshLocalData();
      if (mounted) {
        if (code == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.prodSyncActionSuccess(actionName)),
              backgroundColor: AppTheme.emerald,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.prodSyncActionFailed(actionName)),
              backgroundColor: AppTheme.crimson,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      _appendLog('❌ ${l.prodSyncActionUnexpectedErr(e.toString())}', isError: true);
      _refreshLocalData();
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
          _currentAction = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SelectionArea(
        child: Container(
          width: 1060,
          height: 820,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // ─── Header Bar ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.sync_alt_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.prodSyncHubDialogTitle,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            l.prodSyncHubDialogSubtitle,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                      tooltip: l.prodSyncRefreshSystemStatusTooltip,
                      onPressed: _refreshLocalData,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // ─── DB Status Header Cards ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildDbCard(
                        title: l.prodSyncDevDbTitle,
                        path: _service.devDbPath,
                        stats: _devStats,
                        color: AppTheme.cobalt,
                        icon: Icons.code_rounded,
                        l: l,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDbCard(
                        title: l.prodSyncProdDbTitle,
                        path: _service.prodDbPath,
                        stats: _prodStats,
                        color: AppTheme.emerald,
                        icon: Icons.desktop_windows_rounded,
                        l: l,
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Tab Bar ──────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.cobalt,
                  unselectedLabelColor: Colors.grey.shade700,
                  indicatorColor: AppTheme.cobalt,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on_rounded, size: 17),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              l.prodSyncTabCompareTables,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history_rounded, size: 17),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              l.prodSyncTabSafetyBackups,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // ─── Tab Views ────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOperationsTab(l),
                      _buildBackupsTab(l),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tab 1: Direct Operations + Live Console
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildOperationsTab(AppLocalizations l) {
    return Column(
      children: [
        // Action Buttons Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              // Compare DBs (read-only). Sync / pull / full build / launch were retired:
              // the product never syncs a dev DB into production.
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                ),
                icon: _isRunning && _currentAction == l.prodSyncCompareTablesBtn
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.compare_arrows_rounded, size: 17),
                label: Text(
                  l.prodSyncCompareTablesBtn,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: _isRunning
                    ? null
                    : () => _executeAction(
                          l.prodSyncCompareTablesBtn,
                          () => _service.compareDatabases(
                            onOutput: (msg) => _appendLog(msg),
                            onError: (msg) => _appendLog(msg, isError: true),
                            onDiffSummary: (d) {
                              if (mounted) setState(() => _diffSummary = d);
                            },
                          ),
                        ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Visual Progress & Database Changes Diff Inspector ────────────
        SyncProgressAndDiffWidget(
          progress: _progress,
          diffSummary: _diffSummary,
          isRunning: _isRunning,
          onCheckDiff: () => _executeAction(
            l.prodSyncCompareTablesBtn,
            () => _service.compareDatabases(
              onOutput: (msg) => _appendLog(msg),
              onError: (msg) => _appendLog(msg, isError: true),
              onDiffSummary: (d) {
                if (mounted) setState(() => _diffSummary = d);
              },
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Live Console Terminal Output
        Expanded(
          child: SyncConsoleWidget(
            logs: _consoleLogs,
            isRunning: _isRunning,
            onClear: () => setState(() => _consoleLogs.clear()),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tab 2: Backups Archive
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildBackupsTab(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.prodSyncBackupsArchiveHeader(_backups.length),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.charcoal),
                    ),
                    Text(
                      l.prodSyncBackupsDialogSub,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.charcoal,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    label: Text(l.prodSyncCopyDossierBtn, style: const TextStyle(fontSize: 11.5)),
                    onPressed: _backups.isEmpty
                        ? null
                        : () => ProductionSyncExportService.copyDossierToClipboard(
                              context: context,
                              devStats: _devStats,
                              prodStats: _prodStats,
                              diffSummary: _diffSummary,
                              backups: _backups,
                            ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add_to_photos_rounded, size: 16),
                    label: Text(l.prodSyncCreateInstantBackupBtn, style: const TextStyle(fontSize: 11.5)),
                    onPressed: _isRunning
                        ? null
                        : () => _executeAction(
                              l.prodSyncCreateInstantBackupBtn,
                              () => _service.createManualBackup(
                                onOutput: (msg) => _appendLog(msg),
                                onError: (msg) => _appendLog(msg, isError: true),
                              ),
                            ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _backups.isEmpty
                ? Center(
                    child: Text(l.prodSyncNoBackupsDialogSub),
                  )
                : ListView.separated(
                    itemCount: _backups.length,
                    separatorBuilder: (ctx, i) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (ctx, idx) {
                      final b = _backups[idx];
                      final tagColor = b.tag.contains('prod')
                          ? AppTheme.emerald
                          : b.tag.contains('dev')
                              ? AppTheme.cobalt
                              : AppTheme.orange;
                      final tagText = b.tag.contains('prod')
                          ? l.prodSyncTargetProdLabel
                          : (b.tag.contains('dev') ? l.prodSyncTargetDevLabel : b.tag);

                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.inventory_2_outlined, color: AppTheme.cobalt, size: 20),
                        title: Row(
                          children: [
                            Tooltip(
                              message: l.prodSyncCopyFieldTooltip,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () => CopyHelper.copy(
                                  context,
                                  b.filename,
                                  customMessage: l.prodSyncCopyFieldTooltip,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        b.filename,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace'),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.copy_rounded, size: 12, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${l.prodSyncBackupCreatedAt(b.mtime)} • ${l.prodSyncBackupSize(b.sizeKb)}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Quick copy row summary action
                            Tooltip(
                              message: l.prodSyncCopyRowSummaryBtn,
                              child: IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                onPressed: () {
                                  final summary = '${b.filename} | $tagText | ${b.sizeKb} KB | ${b.mtime}';
                                  CopyHelper.copy(context, summary, customMessage: l.prodSyncCopyRowSummarySuccess);
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tagColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tagText,
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: tagColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.orange,
                                side: const BorderSide(color: AppTheme.orange),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.restore_rounded, size: 14),
                              label: Text(l.prodSyncRestoreActionBtn, style: const TextStyle(fontSize: 10.5)),
                              onPressed: _isRunning ? null : () => _confirmAndRestoreBackup(b),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helper: DB Card
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildDbCard({
    required String title,
    required String path,
    required LocalDbStats stats,
    required Color color,
    required IconData icon,
    required AppLocalizations l,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: l.prodSyncCopyFieldTooltip,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => CopyHelper.copy(context, path, customMessage: l.prodSyncCopyFieldTooltip),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                path.length > 18 ? '...${path.substring(path.length - 15)}' : path,
                                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.charcoal),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.copy_rounded, size: 10, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  stats.exists
                      ? '${l.prodSyncDbSizeLabel(stats.sizeKb)} • ${l.prodSyncDbLastModified(stats.mtime ?? "—")}'
                      : l.prodSyncDbNotFoundNotice,
                  style: TextStyle(
                    fontSize: 11,
                    color: stats.exists ? Colors.black87 : AppTheme.crimson,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
