import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/production_sync_model.dart';
import '../providers/production_sync_provider.dart';
import '../../app_update/widgets/app_update_panel.dart';
import '../services/local_process_sync_service.dart';
import '../services/production_sync_export_service.dart';
import '../widgets/sync_console_widget.dart';
import '../widgets/sync_progress_and_diff_widget.dart';

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
    _service = widget.service ??
        LocalProcessSyncService(ref.read(productionSyncServiceProvider));
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
            SnackBar(
              content: Text('✅ ${l.prodSyncActionSuccess(actionName)}'),
              backgroundColor: AppTheme.emerald,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${l.prodSyncActionFailed(actionName)}'),
              backgroundColor: AppTheme.crimson,
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
    final updateState = ref.watch(updateCheckStateProvider);
    final l = context.l10n;
    final versionInfo = ref.watch(systemVersionInfoProvider);
    final currentVer = versionInfo.whenOrNull(data: (i) => i.version) ?? ApiConstants.clientVersion;
    final currentBuild = versionInfo.whenOrNull(data: (i) => i.buildNumber) ?? ApiConstants.clientBuildNumber;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.charcoal,
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.cobalt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.system_update_alt_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.prodSyncScreenHeaderTitle,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    l.prodSyncScreenHeaderSubtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // ── Linked Output Actions (Task C) ──────────────────────────────
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
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
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
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ─── Version & Update Status Top Banner ────────────────────────
              _buildUpdateStatusBanner(updateState, l),
              const SizedBox(height: 10),

              // ─── Tab Views ────────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBackupsAndUpdatesTab(l),
                    _buildDevOperationsTab(l),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Top Banner: Version & Update Status
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildUpdateStatusBanner(AsyncValue<RemoteUpdateCheckResultModel?> updateState, AppLocalizations l) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    return updateState.when(
      data: (result) {
        if (result == null) {
          final versionInfo = ref.watch(systemVersionInfoProvider);
          return _buildVersionInfoCard(
            version: versionInfo.whenOrNull(data: (i) => i.version) ?? ApiConstants.clientVersion,
            buildNumber: versionInfo.whenOrNull(data: (i) => i.buildNumber) ?? ApiConstants.clientBuildNumber,
            hasUpdate: false,
            message: l.prodSyncSystemUpToDateMsg,
            l: l,
          );
        }
        final versionInfo = ref.watch(systemVersionInfoProvider);
        final bannerMsg = !result.hasUpdate
            ? l.prodSyncSystemUpToDateMsg
            : (isArabic
                ? result.message
                : (result.latestVersion.isNotEmpty
                    ? 'New update v${result.latestVersion} is available.'
                    : 'A new system update is available.'));
        return _buildVersionInfoCard(
          version: result.currentVersion,
          buildNumber: versionInfo.whenOrNull(data: (i) => i.buildNumber) ?? ApiConstants.clientBuildNumber,
          hasUpdate: result.hasUpdate,
          latestVersion: result.latestVersion,
          message: bannerMsg,
          releaseNotes: result.releaseNotes,
          downloadUrl: result.downloadUrl,
          l: l,
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cobalt)),
            const SizedBox(width: 12),
            Text(l.prodSyncCheckingCloudUpdates, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      error: (e, _) => _buildVersionInfoCard(
        version: ApiConstants.clientVersion,
        buildNumber: ApiConstants.clientBuildNumber,
        hasUpdate: false,
        message: l.prodSyncOfflineModeMsg,
        l: l,
      ),
    );
  }

  Widget _buildVersionInfoCard({
    required String version,
    required int buildNumber,
    required bool hasUpdate,
    String? latestVersion,
    required String message,
    List<String> releaseNotes = const [],
    String? downloadUrl,
    required AppLocalizations l,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasUpdate ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hasUpdate ? AppTheme.cobalt : Colors.grey.shade300, width: hasUpdate ? 1.5 : 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Clickable Version Badge with Copy Trigger
              InkWell(
                onTap: () => CopyHelper.copy(
                  context,
                  'v$version (Build $buildNumber)',
                  customMessage: l.prodSyncCopyFieldTooltip,
                ),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasUpdate ? AppTheme.cobalt : AppTheme.charcoal,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'v$version (Build $buildNumber)',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded, size: 12, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      hasUpdate ? Icons.system_update_rounded : Icons.check_circle_rounded,
                      color: hasUpdate ? AppTheme.cobalt : AppTheme.emerald,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: hasUpdate ? AppTheme.cobalt : AppTheme.charcoal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ── In-app updates (verified download/install by the backend) ──
              AppButton(
                label: l.updateSectionTitle,
                size: AppButtonSize.small,
                variant: hasUpdate ? AppButtonVariant.success : AppButtonVariant.ghost,
                icon: Icons.system_update_rounded,
                onPressed: () => showAppUpdatePanelDialog(context),
              ),
              const SizedBox(width: 8),
              // ── Check for Updates Button ───────────────────────────────────
              ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cobalt,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: Text(l.prodSyncCheckUpdatesBtn, style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    ref.read(productionSyncNotifierProvider.notifier).checkForUpdates();
                  },
                ),
            ],
          ),

          // ── Release Notes ────────────────────────────────────────────────
          if (hasUpdate && releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.prodSyncWhatsNewInVersion(latestVersion ?? ''),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                  ),
                  const SizedBox(height: 4),
                  ...releaseNotes.map((note) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(' • ', style: TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold)),
                            Expanded(child: Text(note, style: const TextStyle(fontSize: 11.5, color: Colors.black87))),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tab 1: System Updates & Safety Backups
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildBackupsAndUpdatesTab(AppLocalizations l) {
    return Column(
      children: [
        // Top Info & Quick Backup Actions
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_user_rounded, color: AppTheme.emerald, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.prodSyncSchemaEngineTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.prodSyncSchemaEngineDesc,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.add_to_photos_rounded, size: 16),
                label: Text(l.prodSyncCreateInstantBackupBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: _isRunning
                    ? null
                    : () => _executeAction(
                          l.prodSyncCreateInstantBackupBtn,
                          () => _service.createManualBackup(
                            onOutput: (l) => _appendLog(l),
                            onError: (l) => _appendLog(l, isError: true),
                          ),
                        ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Backups List View
        Expanded(
          child: Container(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l.prodSyncBackupsArchiveHeader(_backups.length),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.charcoal),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.table_view_rounded, size: 18, color: AppTheme.cobalt),
                          tooltip: l.prodSyncExportTsvBtn,
                          onPressed: () => ProductionSyncExportService.saveBackupsTsvToFile(
                            context: context,
                            backups: _backups,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.file_download_outlined, size: 18, color: AppTheme.emerald),
                          tooltip: l.prodSyncExportExcelBtn,
                          onPressed: () => ProductionSyncExportService.saveBackupsCsvToFile(
                            context: context,
                            backups: _backups,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.grey),
                          onPressed: _refreshLocalData,
                          tooltip: l.prodSyncRefreshListTooltip,
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: _backups.isEmpty
                      ? Center(
                          child: Text(l.prodSyncNoBackupsInFolder),
                        )
                      : ListView.separated(
                          itemCount: _backups.length,
                          separatorBuilder: (ctx, i) => Divider(height: 1, color: Colors.grey.shade200),
                          itemBuilder: (ctx, idx) {
                            final b = _backups[idx];
                            final isAuto = b.filename.startsWith('auto_pre_upgrade');
                            final tagColor = isAuto
                                ? AppTheme.cobalt
                                : b.tag.contains('prod')
                                    ? AppTheme.emerald
                                    : AppTheme.orange;
                            final tagLabel = isAuto
                                ? l.prodSyncAutoPreUpgradeTag
                                : (b.tag.contains('prod')
                                    ? l.prodSyncTargetProdLabel
                                    : (b.tag.contains('dev') ? l.prodSyncTargetDevLabel : b.tag));

                            return ListTile(
                              dense: true,
                              leading: Icon(
                                isAuto ? Icons.auto_awesome_rounded : Icons.inventory_2_outlined,
                                color: tagColor,
                                size: 22,
                              ),
                              title: InkWell(
                                onTap: () => CopyHelper.copy(
                                  context,
                                  b.filename,
                                  customMessage: l.prodSyncCopyFieldTooltip,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        b.filename,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace'),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.copy_rounded, size: 11, color: Colors.grey.shade400),
                                  ],
                                ),
                              ),
                              subtitle: Text(
                                '${l.prodSyncBackupCreatedAt(b.mtime)} • ${l.prodSyncBackupSize(b.sizeKb)} • ${isAuto ? l.prodSyncAutoPreUpgradeTag : l.prodSyncManualBackupTag}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: tagColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      tagLabel,
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: tagColor),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
                                    tooltip: l.prodSyncCopyRowSummaryBtn,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                    onPressed: () {
                                      final summary = '${b.filename} | ${b.sizeKb} KB | ${b.mtime} | ${b.tag}';
                                      CopyHelper.copy(context, summary, customMessage: l.prodSyncCopyRowSummarySuccess);
                                    },
                                  ),
                                  const SizedBox(width: 6),
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
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tab 2: Developer Operations & Diff
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildDevOperationsTab(AppLocalizations l) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // DB Status Cards
                  Row(
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
                  const SizedBox(height: 10),

                  // Action Buttons Row
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cobalt,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.compare_arrows_rounded, size: 16),
                          label: Text(l.prodSyncCompareTablesBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: _isRunning
                              ? null
                              : () => _executeAction(
                                    l.prodSyncCompareTablesBtn,
                                    () => _service.compareDatabases(
                                      onOutput: (l) => _appendLog(l),
                                      onError: (l) => _appendLog(l, isError: true),
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

                  // Visual Progress & Diff Inspector
                  SyncProgressAndDiffWidget(
                    progress: _progress,
                    diffSummary: _diffSummary,
                    isRunning: _isRunning,
                    onCheckDiff: () => _executeAction(
                      l.prodSyncCompareTablesBtn,
                      () => _service.compareDatabases(
                        onOutput: (l) => _appendLog(l),
                        onError: (l) => _appendLog(l, isError: true),
                        onDiffSummary: (d) {
                          if (mounted) setState(() => _diffSummary = d);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Live Console Terminal Output
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 180),
                      child: SyncConsoleWidget(
                        logs: _consoleLogs,
                        isRunning: _isRunning,
                        onClear: () => setState(() => _consoleLogs.clear()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 2),
                InkWell(
                  onTap: () => CopyHelper.copy(context, path, customMessage: l.prodSyncCopyFieldTooltip),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            path,
                            style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.copy_rounded, size: 10, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
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
