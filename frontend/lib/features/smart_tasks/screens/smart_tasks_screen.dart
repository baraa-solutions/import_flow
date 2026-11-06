// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/paged_data_table/paged_data_table.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/smart_task_model.dart';
import '../providers/smart_tasks_provider.dart';
import '../widgets/smart_task_dialog.dart';
import '../widgets/smart_email_listener_dialog.dart';
import '../widgets/email_settings_dialog.dart';
import '../widgets/screen/smart_tasks_export_helper.dart';
import '../widgets/screen/smart_tasks_table_columns.dart';
import '../widgets/screen/smart_tasks_toolbar.dart';

class SmartTasksScreen extends ConsumerStatefulWidget {
  const SmartTasksScreen({super.key});

  @override
  ConsumerState<SmartTasksScreen> createState() => _SmartTasksScreenState();
}

class _SmartTasksScreenState extends ConsumerState<SmartTasksScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTaskType = 'All';
  String _selectedPriority = 'All';
  String _selectedStatus = 'All';
  Set<Object> _selectedTaskIds = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _bulkCompleteTasks() async {
    if (_selectedTaskIds.isEmpty) return;

    for (final id in _selectedTaskIds) {
      if (id is int) {
        await ref.read(smartTasksProvider.notifier).updateTask(id, {'status': 'Completed'});
      }
    }

    ref.read(smartTasksPagedProvider.notifier).refresh();
    setState(() => _selectedTaskIds = {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pagedState = ref.watch(smartTasksPagedProvider);
    final notifier = ref.read(smartTasksPagedProvider.notifier);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffoldBackground : const Color(0xFFF8FAFC),
      appBar: PageHeader(
        title: l.smartTasksTitle,
        icon: Icons.task_alt_rounded,
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
              // Toolbar
              SmartTasksToolbar(
                searchController: _searchController,
                selectedTaskType: _selectedTaskType,
                selectedPriority: _selectedPriority,
                selectedStatus: _selectedStatus,
                onTaskTypeChanged: (v) {
                  setState(() => _selectedTaskType = v);
                  notifier.setFilter('task_type', v == 'All' ? null : v);
                },
                onPriorityChanged: (v) {
                  setState(() => _selectedPriority = v);
                  notifier.setFilter('priority', v == 'All' ? null : v);
                },
                onStatusChanged: (v) {
                  setState(() => _selectedStatus = v);
                  notifier.setFilter('status', v == 'All' ? null : v);
                },
                onSearchChanged: () {
                  notifier.setSearch(_searchController.text.trim());
                },
                onResetFilters: () {
                  setState(() {
                    _selectedTaskType = 'All';
                    _selectedPriority = 'All';
                    _selectedStatus = 'All';
                    _searchController.clear();
                  });
                  notifier.setSearch('');
                  notifier.setFilter('task_type', null);
                  notifier.setFilter('priority', null);
                  notifier.setFilter('status', null);
                },
                onRefresh: () => notifier.refresh(),
                onCopyTsv: () {
                  final items = pagedState.data?.items ?? [];
                  SmartTasksExportHelper.copySmartTasksTsv(context, ref, items);
                },
                onExportExcel: () {
                  final items = pagedState.data?.items ?? [];
                  MasterDataExportService.exportSmartTasksToExcel(context, items);
                },
                onExportPdf: () {
                  final items = pagedState.data?.items ?? [];
                  MasterDataExportService.printOrSaveSmartTasksListPdf(items);
                },
                onOpenEmailSettings: () => EmailSettingsDialog.show(context),
                onNewTask: () => SmartTaskDialog.show(context),
                onOpenEmailListener: () => SmartEmailListenerDialog.show(context),
              ),
              const SizedBox(height: 8),

              // Server-Paged Virtualized Paged Data Table
              Expanded(
                child: Card(
                  color: isDark ? AppTheme.darkCardBackground : Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: PagedDataTable<SmartTaskModel>(
                    storageKey: 'smart_tasks_master_table',
                    columns: SmartTasksTableColumns.build(context, ref),
                    state: pagedState,
                    onQueryChanged: (query) => notifier.setQuery(query),
                    rowKey: (task) => task.taskId,
                    selectable: true,
                    selectedKeys: _selectedTaskIds,
                    onSelectionChanged: (keys) {
                      setState(() => _selectedTaskIds = keys);
                    },
                    bulkActions: (keys) => ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: _bulkCompleteTasks,
                      icon: const Icon(Icons.done_all, size: 16),
                      label: Text(
                        l.smartTasksBulkCompleteBtn(keys.length),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    rowActions: (task) => SmartTasksTableColumns.buildRowActions(context, ref),
                    onOpen: (task) => SmartTaskDialog.show(context, taskToEdit: task),
                    exportStageName: 'Smart_Tasks',
                    emptyMessage: l.smartTasksEmptyMessage,
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
