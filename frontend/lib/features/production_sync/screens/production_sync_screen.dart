import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/production_sync_provider.dart';
import '../services/local_process_sync_service.dart';
import '../services/production_sync_export_service.dart';
import '../widgets/production_sync_backups_tab.dart';
import '../widgets/production_sync_dev_operations_tab.dart';
import '../widgets/production_sync_version_card.dart';
import '../widgets/sync_console_widget.dart';

/// Screen coordinating production synchronization, database comparisons, and safety backups.
class ProductionSyncScreen extends ConsumerStatefulWidget {
  final LocalProcessSyncService? service;
  const ProductionSyncScreen({super.key, this.service});

  @override
  ConsumerState<ProductionSyncScreen> createState() => _ProductionSyncScreenState();
}

class _ProductionSyncScreenState extends ConsumerState<ProductionSyncScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final LocalProcessSyncService _service;

  final List<ConsoleLogLine> _consoleLogs = [];
  bool _isRunning = false;
  SyncProgressEvent? _progress;
  SyncDiffSummary? _diffSummary;

  late LocalDbStats _devStats;
  late LocalDbStats _prodStats;
  late List<LocalBackupEntry> _backups;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? LocalProcessSyncService(ref.read(productionSyncServiceProvider));
    _tabController = TabController(length: 2, vsync: this);
    _initLocalStats();
    Future.microtask(() {
      if (mounted) {
        ref.invalidate(systemVersionInfoProvider);
        ref.invalidate(backupsListProvider);
        _checkDiffsSilently();
        ref
            .read(productionSyncNotifierProvider.notifier)
            .checkForUpdates()
            .then<void>((_) {})
            .catchError((_) {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initLocalStats() {
    _devStats = _service.getDbStats(_service.devDbPath);
    _prodStats = _service.getDbStats(_service.prodDbPath);
    _backups = _service.listBackups();
  }

  void _refreshLocalData() {
    if (!mounted) return;
    setState(() {
      _initLocalStats();
    });
    ref.invalidate(systemVersionInfoProvider);
    ref.invalidate(backupsListProvider);
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
      await _executeAction(l.prodSyncRestoreActionBtn, () async {
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
      _progress = SyncProgressEvent(
        percent: 5,
        stage: 'init',
        message: l.prodSyncActionStarting(actionName),
      );
      _consoleLogs.add(ConsoleLogLine('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'));
      _consoleLogs.add(ConsoleLogLine('🚀 ${l.prodSyncActionStarting(actionName)}'));
    });

    try {
      final code = await task();
      _refreshLocalData();
      if (mounted) {
        if (code == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              '✅ ${l.prodSyncActionSuccess(actionName)}',
              severity: AppSeverity.success,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              '⚠️ ${l.prodSyncActionFailed(actionName)}',
              severity: AppSeverity.danger,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      _appendLog('❌ ${l.prodSyncActionUnexpectedErr(e)}', isError: true);
      _refreshLocalData();
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final versionInfo = ref.watch(systemVersionInfoProvider);
    final currentVer = versionInfo.whenOrNull(data: (i) => i.version) ?? ApiConstants.clientVersion;
    final currentBuild = versionInfo.whenOrNull(data: (i) => i.buildNumber) ?? ApiConstants.clientBuildNumber;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PageHeader(
        icon: Icons.system_update_alt_rounded,
        title: l.prodSyncScreenHeaderTitle,
        subtitle: l.prodSyncScreenHeaderSubtitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view_rounded, color: Colors.white),
            tooltip: l.prodSyncExportTsvBtn,
            onPressed: () {
              if (_diffSummary != null && _diffSummary!.tables.isNotEmpty) {
                ProductionSyncExportService.saveTableDiffTsvToFile(
                  context: context,
                  tables: _diffSummary!.tables,
                );
              } else {
                ProductionSyncExportService.saveBackupsTsvToFile(
                  context: context,
                  backups: _backups,
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            tooltip: l.prodSyncExportExcelBtn,
            onPressed: () {
              if (_diffSummary != null && _diffSummary!.tables.isNotEmpty) {
                ProductionSyncExportService.saveTableDiffCsvToFile(
                  context: context,
                  tables: _diffSummary!.tables,
                );
              } else {
                ProductionSyncExportService.saveBackupsCsvToFile(
                  context: context,
                  backups: _backups,
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            tooltip: l.prodSyncExportPdfBtn,
            onPressed: () => ProductionSyncExportService.printOrSaveSyncDiagnosticsPdf(
              context: context,
              version: currentVer,
              buildNumber: currentBuild,
              devStats: _devStats,
              prodStats: _prodStats,
              diffSummary: _diffSummary,
              backups: _backups,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.assignment_outlined, color: Colors.white),
            tooltip: l.prodSyncCopyDossierBtn,
            onPressed: () {
              final dossier = ProductionSyncExportService.buildSystemSyncDossier(
                context: context,
                version: currentVer,
                buildNumber: currentBuild,
                devStats: _devStats,
                prodStats: _prodStats,
                diffSummary: _diffSummary,
                backups: _backups,
              );
              CopyHelper.copy(context, dossier, customMessage: l.prodSyncCopyDossierSuccess);
            },
          ),
          const VerticalDivider(width: 16, color: Colors.white24, indent: 12, endIndent: 12),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: l.prodSyncRefreshSystemStatusTooltip,
            onPressed: _refreshLocalData,
          ),
          const SizedBox(width: 8),
          const BackToDashboardButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Version & Update Status Top Banner
              const ProductionSyncVersionCard(),
              const SizedBox(height: 10),

              // Tabs Bar
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E2631)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkBorder
                        : Colors.grey.shade300,
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.cobalt,
                  unselectedLabelColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white60
                      : Colors.grey.shade700,
                  indicatorColor: AppTheme.cobalt,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.security_rounded, size: 18),
                      text: l.prodSyncTabUpdatesAndBackups,
                    ),
                    Tab(
                      icon: const Icon(Icons.code_rounded, size: 18),
                      text: l.prodSyncTabDevToolsAndDiff,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    ProductionSyncBackupsTab(
                      backups: _backups,
                      isRunning: _isRunning,
                      l: l,
                      onCreateInstantBackup: () => _executeAction(
                        l.prodSyncCreateInstantBackupBtn,
                        () => _service.createManualBackup(
                          onOutput: (line) => _appendLog(line),
                          onError: (line) => _appendLog(line, isError: true),
                        ),
                      ),
                      onRefresh: _refreshLocalData,
                      onRestoreBackup: _confirmAndRestoreBackup,
                    ),
                    ProductionSyncDevOperationsTab(
                      service: _service,
                      devStats: _devStats,
                      prodStats: _prodStats,
                      isRunning: _isRunning,
                      progress: _progress,
                      diffSummary: _diffSummary,
                      consoleLogs: _consoleLogs,
                      l: l,
                      onCompareDatabases: () => _executeAction(
                        l.prodSyncCompareTablesBtn,
                        () => _service.compareDatabases(
                          onOutput: (line) => _appendLog(line),
                          onError: (line) => _appendLog(line, isError: true),
                          onDiffSummary: (d) {
                            if (mounted) setState(() => _diffSummary = d);
                          },
                        ),
                      ),
                      onClearLogs: () => setState(() => _consoleLogs.clear()),
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
}
