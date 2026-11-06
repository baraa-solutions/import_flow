import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/paged_data_table/paged_data_table.dart';
import '../models/audit_log_model.dart';
import '../providers/audit_logs_provider.dart';
import '../widgets/row_history_dialog.dart';
import '../widgets/screen/audit_logs_table_columns.dart';

class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  final TextEditingController _searchController = TextEditingController();
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pagedState = ref.watch(auditLogsPagedProvider);
    final notifier = ref.read(auditLogsPagedProvider.notifier);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffoldBackground : const Color(0xFFF8FAFC),
      appBar: PageHeader(
        title: l10n.auditLogsScreenTitle,
        icon: Icons.history_edu_rounded,
        actions: const [
          BackToDashboardButton(),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Standard Type B Compact Toolbar (Max 40px height)
              Container(
                height: 40,
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    // Debounced Search Field
                    SizedBox(
                      width: 220,
                      height: 36,
                      child: AppSearchField(
                        controller: _searchController,
                        hint: l10n.searchAuditLogsHint,
                        onChanged: (val) {
                          notifier.setSearch(val.trim());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Entity Type Filter Dropdown
                    Container(
                      height: 36,
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
                              setState(() => _selectedEntityType = val);
                              notifier.setFilter('entity_type', val == 'All' ? null : val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Action Filter Dropdown
                    Container(
                      height: 36,
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
                              setState(() => _selectedAction = val);
                              notifier.setFilter('action', val == 'All' ? null : val);
                            }
                          },
                        ),
                      ),
                    ),
                    const Spacer(),

                    // TSV Export Button
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                      tooltip: l10n.auditLogsExportTsvBtn,
                      onPressed: () {
                        final items = pagedState.data?.items ?? [];
                        _copyAuditLogsTsv(items);
                      },
                    ),

                    // Live Refresh Button
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: l10n.liveRefreshBtn,
                      onPressed: () => notifier.refresh(),
                    ),
                  ],
                ),
              ),

              // Enterprise Virtualized Paged Data Table (Server-Side Paged)
              Expanded(
                child: Card(
                  color: isDark ? AppTheme.darkCardBackground : Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: PagedDataTable<AuditLogModel>(
                    storageKey: 'audit_logs_master_table',
                    columns: AuditLogsTableColumns.build(context),
                    state: pagedState,
                    onQueryChanged: (query) => notifier.setQuery(query),
                    rowActions: (log) => AuditLogsTableColumns.buildRowActions(context),
                    onOpen: (log) {
                      RowHistoryDialog.show(
                        context,
                        entityType: log.entityType,
                        entityId: log.entityId,
                        entityTitle: log.entityCode ?? '#${log.entityId}',
                      );
                    },
                    exportStageName: 'Audit_Logs',
                    emptyMessage: l10n.noAuditLogsFound,
                    onRefresh: () => notifier.refresh(),
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
