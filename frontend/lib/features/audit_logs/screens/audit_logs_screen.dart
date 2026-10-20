import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/action_toolbar.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/audit_log_model.dart';
import '../providers/audit_logs_provider.dart';
import '../widgets/row_history_dialog.dart';

class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedEntityType = 'All';
  String _selectedAction = 'All';

  final List<String> _entityTypes = [
    'All',
    'ImportCompany',
    'Supplier',
    'ExternalServiceProvider',
    'User',
  ];

  final List<String> _actions = [
    'All',
    'CREATE',
    'UPDATE',
    'DELETE',
    'RESTORE',
  ];

  @override
  void initState() {
    super.initState();
    if (!ref.read(systemAuditLogsProvider).isLoading) {
      Future.microtask(() {
        ref.invalidate(systemAuditLogsProvider);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AuditLogModel> _getFilteredLogs(List<AuditLogModel> logs) {
    return logs.where((log) {
      final matchesEntity = _selectedEntityType == 'All' || log.entityType == _selectedEntityType;
      final matchesAction = _selectedAction == 'All' || log.action.toUpperCase() == _selectedAction.toUpperCase();
      final matchesSearch = _searchQuery.isEmpty ||
          (log.entityCode ?? '').toLowerCase().contains(_searchQuery) ||
          log.performedBy.toLowerCase().contains(_searchQuery) ||
          (log.changesSummary ?? '').toLowerCase().contains(_searchQuery);

      return matchesEntity && matchesAction && matchesSearch;
    }).toList();
  }

  void _copyAuditLogsTsv(List<AuditLogModel> logs) {
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
      customMessage: l10n.auditLogsExportTsvSuccess,
    );
  }

  String _buildAuditLogRowSummary(AuditLogModel log) {
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
    final logsAsync = ref.watch(systemAuditLogsProvider);
    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffoldBackground : AppTheme.cloudWhite,
      appBar: PageHeader(
        title: l10n.auditLogsScreenTitle,
        subtitle: l10n.auditLogsScreenSubtitle,
        actions: const [
          BackToDashboardButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ActionToolbar(
                moreActionItems: [
                  PopupMenuItem<String>(
                    value: 'export_excel',
                    child: Row(
                      children: [
                        const Icon(Icons.file_download_outlined, size: 16, color: AppTheme.emerald),
                        const SizedBox(width: 8),
                        Text(l10n.exportAuditLogExcelBtn),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'export_pdf',
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppTheme.cobalt),
                        const SizedBox(width: 8),
                        Text(l10n.exportAuditLogPdfBtn),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'copy_tsv',
                    child: Row(
                      children: [
                        const Icon(Icons.copy_rounded, size: 16, color: AppTheme.charcoal),
                        const SizedBox(width: 8),
                        Text(l10n.auditLogsExportTsvBtn),
                      ],
                    ),
                  ),
                ],
                onMoreActionSelected: (val) {
                  final logs = logsAsync.valueOrNull ?? [];
                  final filtered = _getFilteredLogs(logs);
                  switch (val) {
                    case 'export_excel':
                      MasterDataExportService.exportAuditLogsToExcel(context, filtered);
                      break;
                    case 'export_pdf':
                      MasterDataExportService.printOrSaveAuditLogsListPdf(filtered);
                      break;
                    case 'copy_tsv':
                      _copyAuditLogsTsv(filtered);
                      break;
                  }
                },
                searchController: _searchController,
                searchHint: l10n.searchAuditLogsHint,
                onSearchChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
                filters: [
                  // Entity Type Filter Dropdown
                  Container(
                    height: density.buttonHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCardBackground : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.black12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedEntityType,
                        isDense: true,
                        style: TextStyle(
                          fontSize: density.buttonFontSize,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: _entityTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(
                              type == 'All' ? '${l10n.filterEntityLabel}: ${l10n.auditEntityLabel("All")}' : l10n.auditEntityLabel(type),
                              style: TextStyle(fontSize: density.buttonFontSize),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedEntityType = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Action Filter Dropdown
                  Container(
                    height: density.buttonHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCardBackground : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.black12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedAction,
                        isDense: true,
                        style: TextStyle(
                          fontSize: density.buttonFontSize,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: _actions.map((act) {
                          return DropdownMenuItem<String>(
                            value: act,
                            child: Text(
                              act == 'All' ? '${l10n.filterActionLabel}: ${l10n.auditActionLabel("All")}' : l10n.auditActionLabel(act),
                              style: TextStyle(fontSize: density.buttonFontSize),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedAction = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
                quickDataActions: [
                  IconButton(
                    icon: Icon(Icons.refresh, size: density.buttonIconSize + 2),
                    tooltip: l10n.liveRefreshBtn,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: density.buttonHeight,
                      minHeight: density.buttonHeight,
                    ),
                    onPressed: () => ref.invalidate(systemAuditLogsProvider),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy_rounded, size: density.buttonIconSize + 2, color: AppTheme.cobalt),
                    tooltip: l10n.auditLogsExportTsvBtn,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: density.buttonHeight,
                      minHeight: density.buttonHeight,
                    ),
                    onPressed: () {
                      final logs = logsAsync.valueOrNull ?? [];
                      _copyAuditLogsTsv(_getFilteredLogs(logs));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

            // Data Table Content
            Expanded(
              child: logsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.cobalt)),
                error: (err, stack) => Center(
                  child: Text(l10n.auditLogsFetchError(err.toString()), style: const TextStyle(color: AppTheme.crimson)),
                ),
                data: (logs) {
                  final filtered = logs.where((log) {
                    final matchesEntity = _selectedEntityType == 'All' || log.entityType == _selectedEntityType;
                    final matchesAction = _selectedAction == 'All' || log.action.toUpperCase() == _selectedAction.toUpperCase();
                    final matchesSearch = _searchQuery.isEmpty ||
                        (log.entityCode ?? '').toLowerCase().contains(_searchQuery) ||
                        log.performedBy.toLowerCase().contains(_searchQuery) ||
                        (log.changesSummary ?? '').toLowerCase().contains(_searchQuery);

                    return matchesEntity && matchesAction && matchesSearch;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(l10n.noAuditLogsFound, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final log = filtered[index];
                        return _buildAuditLogCard(log);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildAuditLogCard(AuditLogModel log) {
    final l10n = context.l10n;
    final actionColor = _getActionColor(log.action);
    final formattedDate = log.performedAt.toLocal().toString().split('.').first;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Icon Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getActionIcon(log.action), color: actionColor, size: 22),
          ),
          const SizedBox(width: 14),

          // Log Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Action Badge
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
                    const SizedBox(width: 8),

                    // Entity Type & Code (Clickable Copy Badge)
                    InkWell(
                      onTap: () => CopyHelper.copy(
                        context,
                        log.entityCode ?? log.entityId.toString(),
                        customMessage: l10n.auditLogCopyFieldTooltip,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.charcoal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.auditEntityWithCode(
                                l10n.auditEntityLabel(log.entityType),
                                log.entityCode ?? log.entityId.toString(),
                              ),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy_rounded, size: 12, color: AppTheme.charcoal),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Timestamp & Action Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy_all_rounded, size: 18, color: Colors.grey),
                          tooltip: l10n.auditLogCopySummaryBtn,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => CopyHelper.copy(
                            context,
                            _buildAuditLogRowSummary(log),
                            customMessage: l10n.auditLogCopySummarySuccess,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.grey),
                          tooltip: l10n.exportAuditLogPdfBtn,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => MasterDataExportService.printOrSaveAuditLogPdf(log),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.history_rounded, size: 18, color: AppTheme.cobalt),
                          tooltip: l10n.viewEntityHistoryBtn,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => RowHistoryDialog.show(
                            context,
                            entityType: log.entityType,
                            entityId: log.entityId,
                            entityTitle: log.entityCode ?? log.entityId.toString(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Changes Summary
                Text(
                  log.changesSummary ?? l10n.systemMutationFallback,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                ),
                const SizedBox(height: 4),

                // User Info (Clickable Copy)
                InkWell(
                  onTap: () => CopyHelper.copy(
                    context,
                    log.performedBy,
                    customMessage: l10n.auditLogCopyFieldTooltip,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(l10n.performedByUser(log.performedBy), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded, size: 11, color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE':
        return AppTheme.emerald;
      case 'UPDATE':
        return AppTheme.cobalt;
      case 'DELETE':
        return AppTheme.crimson;
      case 'RESTORE':
        return AppTheme.orange;
      default:
        return AppTheme.charcoal;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE':
        return Icons.add_circle;
      case 'UPDATE':
        return Icons.edit_note;
      case 'DELETE':
        return Icons.remove_circle;
      case 'RESTORE':
        return Icons.settings_backup_restore;
      default:
        return Icons.history;
    }
  }
}
