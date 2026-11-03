import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/customs_consultation_model.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../services/customs_consultation_pdf_service.dart';
import '../../services/customs_export_service.dart';
import '../consultation_metric_badge.dart';

class ConsultationsToolbarStrip extends StatelessWidget {
  final List<CustomsConsultationModel> sessions;
  final List<CustomsConsultationModel> filteredSessions;
  final List<ImportFileModel> importFiles;
  final TextEditingController searchController;
  final String statusFilter;
  final bool showInactive;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<bool> onToggleInactive;
  final VoidCallback onClonePressed;

  const ConsultationsToolbarStrip({
    super.key,
    required this.sessions,
    required this.filteredSessions,
    required this.importFiles,
    required this.searchController,
    required this.statusFilter,
    required this.showInactive,
    required this.onSearchChanged,
    required this.onStatusFilterChanged,
    required this.onToggleInactive,
    required this.onClonePressed,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalCount = sessions.length;
    final readyCount = sessions.where((s) => s.overallStatus == 'Clearance Ready').length;
    final blockedCount = sessions.where((s) => s.overallStatus == 'Blocked' || s.hasBlockingIssues).length;
    final avgReadiness = sessions.isEmpty
        ? 0.0
        : sessions.fold(0.0, (s, c) => s + c.readinessPercentage) / sessions.length;

    final metricBadges = [
      ConsultationMetricBadge(
        title: l.totalStudiesMetric,
        value: '$totalCount',
        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
      ),
      ConsultationMetricBadge(
        title: l.clearanceReadyStatus,
        value: '$readyCount',
        color: AppTheme.emerald,
      ),
      ConsultationMetricBadge(
        title: l.openBlockingIssues,
        value: '$blockedCount',
        color: blockedCount > 0 ? AppTheme.crimson : AppTheme.textMuted,
      ),
      ConsultationMetricBadge(
        title: l.avgReadinessMetric,
        value: '${avgReadiness.toStringAsFixed(0)}%',
        color: AppTheme.cobalt,
      ),
    ];

    final searchWidget = TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: l.searchConsultationsHint,
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: searchController,
          builder: (context, val, _) {
            return val.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                  )
                : const SizedBox.shrink();
          },
        ),
        filled: true,
        fillColor: isDark ? AppTheme.darkInputBackground : AppTheme.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.cobalt, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      onChanged: onSearchChanged,
    );

    final statusWidget = SearchableDropdownField<String>(
      value: statusFilter,
      labelText: l.statusFilterLabel,
      items: [
        SearchableDropdownItem(value: 'All', label: l.allStatuses),
        SearchableDropdownItem(value: 'Pending Review', label: l.statusPendingReview),
        SearchableDropdownItem(value: 'In Progress', label: l.statusInProgress),
        SearchableDropdownItem(value: 'Action Required', label: l.statusActionRequired),
        SearchableDropdownItem(value: 'Clearance Ready', label: l.statusClearanceReady),
        SearchableDropdownItem(value: 'Blocked', label: l.statusBlocked),
      ],
      onChanged: (v) => onStatusFilterChanged(v!),
    );

    final cloneButton = Tooltip(
      message: l.searchAndCloneConsultationTooltip,
      child: AppButton(
        key: const ValueKey('searchAndCloneConsultationBtnTab1'),
        label: l.searchAndCloneConsultationBtn,
        icon: Icons.control_point_duplicate_rounded,
        variant: AppButtonVariant.primary,
        size: AppButtonSize.small,
        onPressed: onClonePressed,
      ),
    );

    final filterChipWidget = FilterChip(
      avatar: Icon(showInactive ? Icons.visibility_off : Icons.visibility, size: 16),
      label: Text(showInactive ? l.hideArchivedChip : l.showArchivedChip),
      selected: showInactive,
      selectedColor: isDark ? AppTheme.crimson.withValues(alpha: 0.5) : AppTheme.crimsonBorder,
      onSelected: onToggleInactive,
    );

    final countBadgeWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cobalt.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${filteredSessions.length}',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
      ),
    );

    final exportButtons = [
      AppButton(
        label: l.customsTaxExportTsvBtn,
        icon: Icons.table_view_outlined,
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.small,
        onPressed: () => CustomsExportService.exportConsultationsLogTsv(
          context: context,
          sessions: filteredSessions,
          shipments: importFiles,
        ),
      ),
      AppButton(
        label: l.customsTaxExportExcelBtn,
        icon: Icons.description_outlined,
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.small,
        onPressed: () => CustomsExportService.exportConsultationsLogExcel(
          context: context,
          sessions: filteredSessions,
          shipments: importFiles,
        ),
      ),
      AppButton(
        label: l.customsTaxPrintPdfBtn,
        icon: Icons.picture_as_pdf_outlined,
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.small,
        onPressed: () => CustomsConsultationPdfService.printOrPreviewConsultationsLogPdf(context, filteredSessions),
      ),
      AppButton(
        label: l.customsTaxCopyDossierBtn,
        icon: Icons.copy_all_outlined,
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.small,
        onPressed: () => CustomsExportService.copyConsultationsLogDossier(
          context: context,
          sessions: filteredSessions,
          shipments: importFiles,
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal.withValues(alpha: 0.03),
        border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite)),
      ),
      child: LayoutBuilder(
        builder: (context, tbConstraints) {
          final isMobile = tbConstraints.maxWidth < 700;

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: metricBadges.map((b) => Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: b)).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(flex: 3, child: searchWidget),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: statusWidget),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      cloneButton,
                      const SizedBox(width: 8),
                      filterChipWidget,
                      const SizedBox(width: 8),
                      countBadgeWidget,
                      const SizedBox(width: 8),
                      ...exportButtons.map((b) => Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: b)),
                    ],
                  ),
                ),
              ],
            );
          }

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: metricBadges,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  cloneButton,
                  SizedBox(width: 220, child: searchWidget),
                  SizedBox(width: 160, child: statusWidget),
                  filterChipWidget,
                  countBadgeWidget,
                  ...exportButtons,
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
