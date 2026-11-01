import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/production_sync_provider.dart';
import '../services/local_process_sync_service.dart';
import 'hub/sync_backups_tab.dart';
import 'hub/sync_db_status_cards.dart';
import 'hub/sync_operations_tab.dart';
import 'sync_console_widget.dart';

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
  final SyncProgressEvent? _progress = null;
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
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l.prodSyncConfirmRestoreTitleDialog,
      message: '${l.prodSyncConfirmRestoreMsgDialog(b.filename)}\n\n${l.prodSyncConfirmRestoreSafeNotice}',
      confirmLabel: l.prodSyncRestoreNowAction,
      confirmVariant: AppButtonVariant.warning,
      icon: Icons.history_rounded,
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
            AppTheme.snackBar(
              context,
              l.prodSyncActionSuccess(actionName),
              severity: AppSeverity.success,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l.prodSyncActionFailed(actionName),
              severity: AppSeverity.danger,
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
              // Header Bar
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

              // DB Status Header Cards
              SyncDbStatusCards(
                service: _service,
                devStats: _devStats,
                prodStats: _prodStats,
              ),

              // Tab Bar
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

              // Tab Views
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      SyncOperationsTab(
                        isRunning: _isRunning,
                        currentAction: _currentAction,
                        progress: _progress,
                        diffSummary: _diffSummary,
                        consoleLogs: _consoleLogs,
                        onCompareDatabases: () => _executeAction(
                          l.prodSyncCompareTablesBtn,
                          () => _service.compareDatabases(
                            onOutput: (msg) => _appendLog(msg),
                            onError: (msg) => _appendLog(msg, isError: true),
                            onDiffSummary: (d) {
                              if (mounted) setState(() => _diffSummary = d);
                            },
                          ),
                        ),
                        onClearLogs: () => setState(() => _consoleLogs.clear()),
                      ),
                      SyncBackupsTab(
                        backups: _backups,
                        devStats: _devStats,
                        prodStats: _prodStats,
                        diffSummary: _diffSummary,
                        isRunning: _isRunning,
                        onCreateManualBackup: () => _executeAction(
                          l.prodSyncCreateInstantBackupBtn,
                          () => _service.createManualBackup(
                            onOutput: (msg) => _appendLog(msg),
                            onError: (msg) => _appendLog(msg, isError: true),
                          ),
                        ),
                        onRestoreBackup: _confirmAndRestoreBackup,
                      ),
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
}
