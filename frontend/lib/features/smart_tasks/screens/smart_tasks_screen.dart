// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/app_localizations_ar.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/enterprise_data_table/enterprise_data_table.dart';
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
  Set<SmartTaskModel> _selectedTasks = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!ref.read(smartTasksProvider).isLoading) {
        ref.read(smartTasksProvider.notifier).fetchTasks();
      }
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    ref.read(smartTasksProvider.notifier).fetchTasks(
      taskType: _selectedTaskType,
      priority: _selectedPriority,
      status: _selectedStatus,
      search: _searchController.text.trim(),
    );
  }

  void _bulkCompleteTasks() async {
    final pendingSelected = _selectedTasks.where((t) => t.status != 'Completed').toList();
    if (pendingSelected.isEmpty) return;

    for (final t in pendingSelected) {
      await ref.read(smartTasksProvider.notifier).updateTask(t.taskId, {'status': 'Completed'});
    }

    if (mounted) {
      final l = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.smartTasksBulkCompleteSuccess(pendingSelected.length),
          severity: AppSeverity.success,
        ),
      );
      setState(() => _selectedTasks.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartTasksProvider);
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = l is AppLocalizationsAr;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PageHeader(
        title: l.smartTasksTitle,
        subtitle: isArabic ? 'متابعة المهام الذكية وتنبيهات الشحنات والبريد الإلكتروني' : 'Smart tasks tracking, shipment alerts, and email sync',
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
              SmartTasksToolbar(
                searchController: _searchController,
                selectedTaskType: _selectedTaskType,
                selectedPriority: _selectedPriority,
                selectedStatus: _selectedStatus,
                onTaskTypeChanged: (v) {
                  setState(() => _selectedTaskType = v);
                  _onFilterChanged();
                },
                onPriorityChanged: (v) {
                  setState(() => _selectedPriority = v);
                  _onFilterChanged();
                },
                onStatusChanged: (v) {
                  setState(() => _selectedStatus = v);
                  _onFilterChanged();
                },
                onSearchChanged: _onFilterChanged,
                onResetFilters: () {
                  setState(() {
                    _selectedTaskType = 'All';
                    _selectedPriority = 'All';
                    _selectedStatus = 'All';
                    _searchController.clear();
                  });
                  _onFilterChanged();
                },
                onRefresh: () => ref.read(smartTasksProvider.notifier).fetchTasks(),
                onCopyTsv: () => SmartTasksExportHelper.copySmartTasksTsv(context, ref, state.tasks),
                onExportExcel: () => MasterDataExportService.exportSmartTasksToExcel(context, state.tasks),
                onExportPdf: () => MasterDataExportService.printOrSaveSmartTasksListPdf(state.tasks),
                onOpenEmailSettings: () => EmailSettingsDialog.show(context),
                onNewTask: () => SmartTaskDialog.show(context),
                onOpenEmailListener: () => SmartEmailListenerDialog.show(context),
              ),
              const SizedBox(height: 8),

              // Unified Enterprise Data Table
              Expanded(
                child: Card(
                  color: isDark ? AppTheme.darkCardBackground : Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                  ),
                  child: state.error != null
                      ? Center(
                          child: Text(
                            l.smartTasksFetchError(state.error!),
                            style: const TextStyle(color: AppTheme.crimson),
                          ),
                        )
                      : EnterpriseDataTable<SmartTaskModel>(
                          storageKey: 'smart_tasks_master_table',
                          title: l.smartTasksTableTitle,
                          titleLeading: const Icon(Icons.table_chart, color: AppTheme.cobalt, size: 20),
                          data: [...state.tasks]..sort((a, b) => SmartTasksExportHelper.priorityWeight(b.priority).compareTo(SmartTasksExportHelper.priorityWeight(a.priority))),
                          columns: SmartTasksTableColumns.build(context, ref),
                          isLoading: state.isLoading,
                          enableSelection: true,
                          selectedItems: _selectedTasks,
                          onSelectionChanged: (selected) {
                            setState(() => _selectedTasks = selected);
                          },
                          bulkActions: _selectedTasks.any((t) => t.status != 'Completed')
                              ? ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.emerald,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  onPressed: _bulkCompleteTasks,
                                  icon: const Icon(Icons.done_all, size: 16),
                                  label: Text(
                                    l.smartTasksBulkCompleteBtn(_selectedTasks.where((t) => t.status != "Completed").length),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                )
                              : null,
                          exportFileName: 'Smart_Tasks_Report_${DateTime.now().millisecondsSinceEpoch}.csv',
                          emptyMessage: l.smartTasksEmptyMessage,
                          emptyIcon: Icons.task_outlined,
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
