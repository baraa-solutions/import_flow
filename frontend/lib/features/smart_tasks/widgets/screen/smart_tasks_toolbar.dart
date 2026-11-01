import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_localizations_ar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/density_provider.dart';
import '../../../../core/widgets/action_toolbar.dart';

class SmartTasksToolbar extends ConsumerWidget {
  final TextEditingController searchController;
  final String selectedTaskType;
  final String selectedPriority;
  final String selectedStatus;
  final ValueChanged<String> onTaskTypeChanged;
  final ValueChanged<String> onPriorityChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onSearchChanged;
  final VoidCallback onResetFilters;
  final VoidCallback onRefresh;
  final VoidCallback onCopyTsv;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final VoidCallback onOpenEmailSettings;
  final VoidCallback onNewTask;
  final VoidCallback onOpenEmailListener;

  const SmartTasksToolbar({
    super.key,
    required this.searchController,
    required this.selectedTaskType,
    required this.selectedPriority,
    required this.selectedStatus,
    required this.onTaskTypeChanged,
    required this.onPriorityChanged,
    required this.onStatusChanged,
    required this.onSearchChanged,
    required this.onResetFilters,
    required this.onRefresh,
    required this.onCopyTsv,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.onOpenEmailSettings,
    required this.onNewTask,
    required this.onOpenEmailListener,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = l is AppLocalizationsAr;
    final density = ref.watch(displayDensityProvider);

    return ActionToolbar(
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
          onPressed: onNewTask,
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
          onPressed: onOpenEmailListener,
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
            onOpenEmailSettings();
            break;
          case 'export_excel':
            onExportExcel();
            break;
          case 'export_pdf':
            onExportPdf();
            break;
          case 'copy_tsv':
            onCopyTsv();
            break;
        }
      },
      searchController: searchController,
      searchHint: isArabic ? 'بحث في المهام...' : 'Search tasks...',
      onSearchChanged: (v) => onSearchChanged(),
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
              value: selectedTaskType,
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
                if (v != null) onTaskTypeChanged(v);
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
              value: selectedPriority,
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
                if (v != null) onPriorityChanged(v);
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
              value: selectedStatus,
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
                if (v != null) onStatusChanged(v);
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
          onPressed: onResetFilters,
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
          onPressed: onRefresh,
        ),
        IconButton(
          icon: Icon(Icons.copy_rounded, size: density.buttonIconSize + 2, color: AppTheme.cobalt),
          tooltip: l.smartTasksExportTsvBtn,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: density.buttonHeight,
            minHeight: density.buttonHeight,
          ),
          onPressed: onCopyTsv,
        ),
      ],
    );
  }
}
