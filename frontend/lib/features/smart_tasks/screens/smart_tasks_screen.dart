// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/app_localizations_ar.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/action_toolbar.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/enterprise_data_table/enterprise_data_table.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/smart_task_model.dart';
import '../providers/smart_tasks_provider.dart';
import '../widgets/smart_task_dialog.dart';
import '../widgets/smart_email_listener_dialog.dart';
import '../widgets/email_settings_dialog.dart';
import '../../../core/providers/navigation_provider.dart';

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

  int _priorityWeight(String p) {
    switch (p.toLowerCase()) {
      case 'critical':
        return 4;
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  int _resolveRouteIndexForTask(SmartTaskModel task) {
    final phase = task.phaseName ?? '';
    final step = task.stepCode ?? '';
    if (step.contains('STEP_01') || step.contains('STEP_02') || phase.contains('Phase 1')) return 2; // PO
    if (step.contains('STEP_03') || phase.contains('Phase 3')) return 11; // Nafeza ACID
    if (step.contains('STEP_05') || phase.contains('Phase 2')) return 16; // Bank Form 4
    if (step.contains('STEP_08') || phase.contains('Phase 4')) return 18; // CargoX / Draft BL
    if (step.contains('STEP_09') || step.contains('STEP_10') || phase.contains('Phase 5')) return 26; // Cargo Shipping
    if (step.contains('STEP_12') || step.contains('STEP_13') || step.contains('STEP_14') || step.contains('STEP_15') || step.contains('STEP_16') || phase.contains('Phase 6') || phase.contains('Phase 7')) return 27; // Customs Clearance
    if (step.contains('STEP_19') || phase.contains('Phase 8')) return 28; // Warehouse Receiving
    if (step.contains('STEP_21')) return 44; // Demurrage / Empty Return
    if (step.contains('STEP_23') || phase.contains('Phase 9')) return 29; // Landed Cost Settlement
    if (step.contains('STEP_25') || phase.contains('Phase 10')) return 30; // File Closure
    return 1; // Default Import Files
  }

  String _buildSmartTaskRowSummary(SmartTaskModel task) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final shipments = ref.read(importFilesProvider).value ?? [];
    final cleanTitle = task.displayTitle(context.l10n);
    final cleanDesc = task.displayDescription(context.l10n, shipments: shipments);
    final shipmentTitle = task.importFileCode != null
        ? DisplayNameResolver.resolveShipmentTitleByCode(task.importFileCode, shipments: shipments, isArabic: isAr)
        : null;

    final b = StringBuffer();
    b.writeln('📋 ${task.taskCode} — $cleanTitle');
    b.writeln('🏷️ ${l.smartTasksColType}: ${DisplayNameResolver.resolveTaskType(task.taskType, isArabic: isAr)}');
    if (cleanDesc.isNotEmpty) {
      b.writeln('📝 ${l.smartTaskFieldDescription}: $cleanDesc');
    }
    if (shipmentTitle != null) {
      b.writeln('📦 ${l.smartTasksColShipment}: $shipmentTitle');
    }
    b.writeln('⚡ ${l.smartTasksColPriority}: ${l.smartTaskPriorityLabel(task.priority)}');
    b.writeln('🔔 ${l.smartTasksColReminder}: ${l.smartTaskReminderTypeLabel(task.reminderType)}');
    if (task.dueDate != null) {
      b.writeln('📅 ${l.smartTasksColDueDate}: ${task.dueDate}');
    }
    b.writeln('🚦 ${l.smartTasksColStatus}: ${DisplayNameResolver.resolveTaskStatus(task.status, isArabic: isAr)}');
    b.writeln('👤 ${l.smartTasksTsvHeaderAssignedUser}: ${task.assignedUser}');
    final notes = task.localizedNotes(l);
    if (notes != null && notes.isNotEmpty) {
      b.writeln('🗒️ ${l.smartTaskFieldNotes}: $notes');
    }
    return b.toString().trim();
  }

  void _copySmartTasksTsv(List<SmartTaskModel> tasks) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final shipments = ref.read(importFilesProvider).value ?? [];
    final buffer = StringBuffer();
    buffer.writeln(
      '${l.smartTasksTsvHeaderCode}\t'
      '${l.smartTasksTsvHeaderType}\t'
      '${l.smartTasksTsvHeaderTitle}\t'
      '${l.smartTasksTsvHeaderShipment}\t'
      '${l.smartTasksTsvHeaderPriority}\t'
      '${l.smartTasksTsvHeaderReminder}\t'
      '${l.smartTasksTsvHeaderDueDate}\t'
      '${l.smartTasksTsvHeaderStatus}\t'
      '${l.smartTasksTsvHeaderAssignedUser}\t'
      '${l.smartTasksTsvHeaderDescription}',
    );

    for (final t in tasks) {
      final typeLabel = DisplayNameResolver.resolveTaskType(t.taskType, isArabic: isAr);
      final cleanTitle = t.displayTitle(context.l10n);
      final shipment = t.importFileCode != null
          ? DisplayNameResolver.resolveShipmentTitleByCode(t.importFileCode, shipments: shipments, isArabic: isAr)
          : l.smartTasksGeneralBadge;
      final priority = l.smartTaskPriorityLabel(t.priority);
      final reminder = l.smartTaskReminderTypeLabel(t.reminderType);
      final status = DisplayNameResolver.resolveTaskStatus(t.status, isArabic: isAr);
      final desc = t.displayDescription(context.l10n, shipments: shipments).replaceAll('\t', ' ').replaceAll('\n', ' ');

      buffer.writeln(
        '${t.taskCode}\t'
        '$typeLabel\t'
        '${cleanTitle.replaceAll('\t', ' ')}\t'
        '$shipment\t'
        '$priority\t'
        '$reminder\t'
        '${t.dueDate ?? "-"}\t'
        '$status\t'
        '${t.assignedUser}\t'
        '$desc',
      );
    }

    CopyHelper.copy(
      context,
      buffer.toString().trimRight(),
      customMessage: l.smartTasksExportTsvSuccess,
    );
  }

  Widget _wrapCell({
    required Widget child,
    required String value,
    String? rowSummary,
  }) =>
      CopyableTableCell(
        value: value,
        rowSummary: rowSummary,
        child: child,
      );

  List<EnterpriseColumn<SmartTaskModel>> _buildColumns(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      EnterpriseColumn<SmartTaskModel>(
        id: 'code',
        title: l.smartTasksColCode,
        isLocked: true,
        searchValue: (t) => t.taskCode,
        exportValue: (t) => t.taskCode,
        cellBuilder: (ctx, t, idx) {
          final rowSummary = _buildSmartTaskRowSummary(t);
          return _wrapCell(
            value: t.taskCode,
            rowSummary: rowSummary,
            child: InkWell(
              onTap: () => CopyHelper.copy(
                context,
                t.taskCode,
                customMessage: l.smartTaskCodeBadgeLabel,
              ),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.cobalt.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.copy_rounded, size: 12, color: AppTheme.cobalt),
                    const SizedBox(width: 4),
                    Text(
                      t.taskCode,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      EnterpriseColumn<SmartTaskModel>(
        id: 'type',
        title: l.smartTasksColType,
        searchValue: (t) => t.taskType,
        exportValue: (t) => t.taskType,
        cellBuilder: (ctx, t, idx) {
          final isSys = t.taskType == 'System Generated';
          final typeLabel = isSys ? l.smartTasksTypeSystem : l.smartTasksTypeManual;
          final rowSummary = _buildSmartTaskRowSummary(t);
          return _wrapCell(
            value: typeLabel,
            rowSummary: rowSummary,
            child: Chip(
              visualDensity: VisualDensity.compact,
              label: Text(
                typeLabel,
                style: TextStyle(fontSize: 10, color: isSys ? (isDark ? Colors.purple.shade200 : Colors.purple.shade900) : (isDark ? Colors.blue.shade200 : Colors.blue.shade900)),
              ),
              backgroundColor: isSys ? (isDark ? Colors.purple.shade900.withOpacity(0.3) : Colors.purple.shade50) : (isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50),
            ),
          );
        },
      ),
      EnterpriseColumn<SmartTaskModel>(
        id: 'title',
        title: l.smartTasksColTitle,
        flex: 2,
        searchValue: (t) => '${t.displayTitle(context.l10n)} ${t.title} ${t.description ?? ""}',
        exportValue: (t) => t.displayTitle(context.l10n),
        cellBuilder: (ctx, t, idx) {
          final shipments = ref.watch(importFilesProvider).value ?? [];
          final cleanTitle = t.displayTitle(context.l10n);
          final cleanDesc = t.displayDescription(context.l10n, shipments: shipments);
          final rowSummary = _buildSmartTaskRowSummary(t);
          return _wrapCell(
            value: '$cleanTitle $cleanDesc'.trim(),
            rowSummary: rowSummary,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cleanTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                if (cleanDesc.isNotEmpty)
                  Text(
                    cleanDesc,
                    style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          );
        },
      ),
      EnterpriseColumn<SmartTaskModel>(
        id: 'shipment',
        title: l.smartTasksColShipment,
        searchValue: (t) {
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          final shipments = ref.watch(importFilesProvider).value ?? [];
          return DisplayNameResolver.resolveShipmentTitleByCode(t.importFileCode, shipments: shipments, isArabic: isAr);
        },
        exportValue: (t) {
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          final shipments = ref.watch(importFilesProvider).value ?? [];
          return t.importFileCode != null
              ? DisplayNameResolver.resolveShipmentTitleByCode(t.importFileCode, shipments: shipments, isArabic: isAr)
              : l.smartTasksGeneralBadge;
        },
        cellBuilder: (ctx, t, idx) {
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          final shipments = ref.watch(importFilesProvider).value ?? [];
          final rowSummary = _buildSmartTaskRowSummary(t);
          if (t.importFileCode == null) {
            return _wrapCell(
              value: l.smartTasksGeneralBadge,
              rowSummary: rowSummary,
              child: Text(
                l.smartTasksGeneralBadge,
                style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
              ),
            );
          }
          final commercialName = DisplayNameResolver.resolveShipmentNameByCode(t.importFileCode, shipments: shipments, isArabic: isAr);
          return _wrapCell(
            value: '$commercialName (${t.importFileCode})',
            rowSummary: rowSummary,
            child: InkWell(
              onTap: () => CopyHelper.copy(
                context,
                t.importFileCode!,
                customMessage: l.smartTaskImportFileBadgeLabel,
              ),
              borderRadius: BorderRadius.circular(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    commercialName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkBorder : AppTheme.charcoal.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.copy_rounded, size: 10, color: AppTheme.cobalt),
                        const SizedBox(width: 3),
                        Text(
                          t.importFileCode!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.cobalt,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      EnterpriseColumn<SmartTaskModel>(
        id: 'priority',
        title: l.smartTasksColPriority,
        sortComparator: (a, b) => _priorityWeight(b.priority).compareTo(_priorityWeight(a.priority)),
        searchValue: (t) => t.priority,
        exportValue: (t) => t.priority,
        cellBuilder: (ctx, t, idx) {
          final rowSummary = _buildSmartTaskRowSummary(t);
          Color bg;
          switch (t.priority.toLowerCase()) {
            case 'critical':
            case 'high':
              bg = Colors.red.shade700;
              break;
            case 'medium':
              bg = Colors.orange.shade800;
              break;
            default:
              bg = Colors.green.shade700;
          }
          final priorityLabel = l.smartTaskPriorityLabel(t.priority);
          return _wrapCell(
            value: priorityLabel,
            rowSummary: rowSummary,
            child: Chip(
              visualDensity: VisualDensity.compact,
              label: Text(priorityLabel, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: bg,
            ),
          );
        },
      ),
      EnterpriseColumn<SmartTaskModel>(
        id: 'reminder',
        title: l.smartTasksColReminder,
        searchValue: (t) => t.reminderType,
        exportValue: (t) => t.reminderType,
        cellBuilder: (ctx, t, idx) {
          final rowSummary = _buildSmartTaskRowSummary(t);
          final reminderLabel = l.smartTaskReminderTypeLabel(t.reminderType);
          return _wrapCell(
            value: reminderLabel,
            rowSummary: rowSummary,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications_active, size: 14, color: AppTheme.orange),
                const SizedBox(width: 4),
                Text(reminderLabel, style: const TextStyle(fontSize: 11)),
              ],
            ),
          );
        },
      ),
      EnterpriseColumn<SmartTaskModel>(
        id: 'dueDate',
        title: l.smartTasksColDueDate,
        searchValue: (t) => t.dueDate ?? '',
        exportValue: (t) => t.dueDate ?? '-',
        cellBuilder: (ctx, t, idx) {
          final rowSummary = _buildSmartTaskRowSummary(t);
          return _wrapCell(
            value: t.dueDate ?? '-',
            rowSummary: rowSummary,
            child: Text(t.dueDate ?? '-', style: const TextStyle(fontSize: 11)),
          );
        },
      ),
      EnterpriseColumn<SmartTaskModel>(
        id: 'status',
        title: l.smartTasksColStatus,
        searchValue: (t) => t.status,
        exportValue: (t) => t.status,
        cellBuilder: (ctx, t, idx) {
          final rowSummary = _buildSmartTaskRowSummary(t);
          Color bg;
          switch (t.status.toLowerCase()) {
            case 'completed':
              bg = AppTheme.emerald;
              break;
            case 'in progress':
              bg = AppTheme.cobalt;
              break;
            default:
              bg = Colors.grey.shade600;
          }
          final statusLabel = l.smartTaskStatusLabel(t.status);
          return _wrapCell(
            value: statusLabel,
            rowSummary: rowSummary,
            child: Chip(
              visualDensity: VisualDensity.compact,
              label: Text(statusLabel, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: bg,
            ),
          );
        },
      ),
      EnterpriseColumn<SmartTaskModel>(
        id: 'actions',
        title: l.smartTasksColActions,
        isSortable: false,
        isSearchable: false,
        isLocked: true,
        cellBuilder: (ctx, t, idx) {
          final rowSummary = _buildSmartTaskRowSummary(t);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded, color: AppTheme.cobalt, size: 16),
                tooltip: Localizations.localeOf(context).languageCode == 'ar'
                    ? 'الانتقال للمرحلة لتنفيذها أو تعديلها'
                    : 'Navigate to stage to execute or edit',
                onPressed: () {
                  final routeIdx = _resolveRouteIndexForTask(t);
                  selectNavigationIndex(ref, routeIdx);
                },
              ),
              if (t.status != 'Completed')
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 18),
                  tooltip: l.smartTasksActionCompleteTooltip,
                  onPressed: () {
                    ref.read(smartTasksProvider.notifier).updateTask(t.taskId, {'status': 'Completed'});
                  },
                ),
              IconButton(
                icon: Icon(Icons.copy_rounded, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal, size: 16),
                tooltip: l.smartTaskCopySummaryBtn,
                onPressed: () {
                  CopyHelper.copy(
                    context,
                    rowSummary,
                    customMessage: l.smartTaskCopySummarySuccess,
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.print_outlined, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal, size: 16),
                tooltip: l.smartTaskPrintPdfTooltip,
                onPressed: () => MasterDataExportService.printOrSaveSmartTaskPdf(t),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: AppTheme.cobalt, size: 16),
                tooltip: l.smartTasksActionEditTooltip,
                onPressed: () => SmartTaskDialog.show(context, taskToEdit: t),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                tooltip: l.smartTasksActionDeleteTooltip,
                onPressed: () => ref.read(smartTasksProvider.notifier).deleteTask(t.taskId),
              ),
            ],
          );
        },
      ),
    ];
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
        SnackBar(
          content: Text(l.smartTasksBulkCompleteSuccess(pendingSelected.length)),
          backgroundColor: AppTheme.emerald,
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
    final density = ref.watch(displayDensityProvider);

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
              ActionToolbar(
                primaryActions: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt,
                      foregroundColor: Colors.white,
                      minimumSize: Size(0, density.buttonHeight),
                      padding: density.buttonPadding,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: Icon(Icons.add_task, size: density.buttonIconSize),
                    label: Text(
                      l.smartTasksNewTaskBtn,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
                    ),
                    onPressed: () => SmartTaskDialog.show(context),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.charcoal,
                      foregroundColor: Colors.white,
                      minimumSize: Size(0, density.buttonHeight),
                      padding: density.buttonPadding,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: Icon(Icons.mark_email_read_outlined, size: density.buttonIconSize),
                    label: Text(
                      l.smartEmailListenerDialogTitle,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
                    ),
                    onPressed: () => SmartEmailListenerDialog.show(context),
                  ),
                ],
                moreActionItems: [
                  PopupMenuItem<String>(
                    value: 'email_settings',
                    child: Row(
                      children: [
                        const Icon(Icons.settings_suggest_rounded, size: 16, color: Colors.teal),
                        const SizedBox(width: 8),
                        Text(isArabic ? 'إعدادات البريد (IMAP/SMTP)' : 'Email Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'export_excel',
                    child: Row(
                      children: [
                        const Icon(Icons.table_view, size: 16, color: AppTheme.emerald),
                        const SizedBox(width: 8),
                        Text(l.smartTasksExportExcelBtn),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'export_pdf',
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppTheme.cobalt),
                        const SizedBox(width: 8),
                        Text(l.smartTasksExportPdfBtn),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'copy_tsv',
                    child: Row(
                      children: [
                        const Icon(Icons.copy_rounded, size: 16, color: AppTheme.charcoal),
                        const SizedBox(width: 8),
                        Text(l.smartTasksExportTsvBtn),
                      ],
                    ),
                  ),
                ],
                onMoreActionSelected: (val) {
                  switch (val) {
                    case 'email_settings':
                      EmailSettingsDialog.show(context);
                      break;
                    case 'export_excel':
                      MasterDataExportService.exportSmartTasksToExcel(context, state.tasks);
                      break;
                    case 'export_pdf':
                      MasterDataExportService.printOrSaveSmartTasksListPdf(state.tasks);
                      break;
                    case 'copy_tsv':
                      _copySmartTasksTsv(state.tasks);
                      break;
                  }
                },
                searchController: _searchController,
                searchHint: isArabic ? 'بحث في المهام...' : 'Search tasks...',
                onSearchChanged: (v) => _onFilterChanged(),
                filters: [
                  // Filter Type
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
                        value: _selectedTaskType,
                        isDense: true,
                        style: TextStyle(
                          fontSize: density.buttonFontSize,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: [
                          DropdownMenuItem(value: 'All', child: Text(l.smartTasksTypeAll)),
                          DropdownMenuItem(value: 'System Generated', child: Text(l.smartTasksTypeSystem)),
                          DropdownMenuItem(value: 'Manual To-Do', child: Text(l.smartTasksTypeManual)),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedTaskType = v);
                            _onFilterChanged();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Filter Priority
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
                        value: _selectedPriority,
                        isDense: true,
                        style: TextStyle(
                          fontSize: density.buttonFontSize,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: [
                          DropdownMenuItem(value: 'All', child: Text(l.smartTasksPriorityAll)),
                          DropdownMenuItem(value: 'Low', child: Text(l.smartTasksPriorityLow)),
                          DropdownMenuItem(value: 'Medium', child: Text(l.smartTasksPriorityMedium)),
                          DropdownMenuItem(value: 'High', child: Text(l.smartTasksPriorityHigh)),
                          DropdownMenuItem(value: 'Critical', child: Text(l.smartTasksPriorityCritical)),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedPriority = v);
                            _onFilterChanged();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Filter Status
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
                        value: _selectedStatus,
                        isDense: true,
                        style: TextStyle(
                          fontSize: density.buttonFontSize,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: [
                          DropdownMenuItem(value: 'All', child: Text(l.smartTasksStatusAll)),
                          DropdownMenuItem(value: 'Pending', child: Text(l.smartTasksStatusPending)),
                          DropdownMenuItem(value: 'In Progress', child: Text(l.smartTasksStatusInProgress)),
                          DropdownMenuItem(value: 'Completed', child: Text(l.smartTasksStatusCompleted)),
                          DropdownMenuItem(value: 'Cancelled', child: Text(l.smartTasksStatusCancelled)),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedStatus = v);
                            _onFilterChanged();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(Icons.filter_alt_off, size: density.buttonIconSize + 2, color: Colors.grey),
                    tooltip: l.smartTasksResetFiltersTooltip,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: density.buttonHeight,
                      minHeight: density.buttonHeight,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedTaskType = 'All';
                        _selectedPriority = 'All';
                        _selectedStatus = 'All';
                        _searchController.clear();
                      });
                      _onFilterChanged();
                    },
                  ),
                ],
                quickDataActions: [
                  IconButton(
                    icon: Icon(Icons.refresh, size: density.buttonIconSize + 2),
                    tooltip: l.liveRefreshBtn,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: density.buttonHeight,
                      minHeight: density.buttonHeight,
                    ),
                    onPressed: () => ref.read(smartTasksProvider.notifier).fetchTasks(),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy_rounded, size: density.buttonIconSize + 2, color: AppTheme.cobalt),
                    tooltip: l.smartTasksExportTsvBtn,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: density.buttonHeight,
                      minHeight: density.buttonHeight,
                    ),
                    onPressed: () => _copySmartTasksTsv(state.tasks),
                  ),
                ],
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
                          data: [...state.tasks]..sort((a, b) => _priorityWeight(b.priority).compareTo(_priorityWeight(a.priority))),
                          columns: _buildColumns(context),
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
