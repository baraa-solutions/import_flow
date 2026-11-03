import 'package:flutter/material.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../models/import_documentation_model.dart';
import '../../idoc_ui.dart';
import 'draft_bl_registry_export_helper.dart';

class DraftBlRegistryToolbar extends StatelessWidget {
  final int totalCount;
  final int certifiedCount;
  final int draftCount;
  final String selectedStatusFilter;
  final ValueChanged<String> onStatusFilterChanged;
  final List<dynamic> importFiles;
  final int? filterImportFileId;
  final ValueChanged<int?> onImportFileIdChanged;
  final String registrySearchQuery;
  final ValueChanged<String> onSearchQueryChanged;
  final VoidCallback onClearSearch;
  final List<DraftBLReviewModel> filteredReviews;
  final VoidCallback onOpenSearchAndClone;
  final VoidCallback onRefreshRegistry;

  const DraftBlRegistryToolbar({
    super.key,
    required this.totalCount,
    required this.certifiedCount,
    required this.draftCount,
    required this.selectedStatusFilter,
    required this.onStatusFilterChanged,
    required this.importFiles,
    required this.filterImportFileId,
    required this.onImportFileIdChanged,
    required this.registrySearchQuery,
    required this.onSearchQueryChanged,
    required this.onClearSearch,
    required this.filteredReviews,
    required this.onOpenSearchAndClone,
    required this.onRefreshRegistry,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Toolbar
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, color: AppTheme.emerald, size: 24),
                const SizedBox(width: 8),
                Text(
                  l.idocABillOfLadingBLReview,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton(
                  key: const Key('stage5SearchAndCloneBtn'),
                  label: l.searchAndCloneDraftBlBtn,
                  icon: Icons.copy_all,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: onOpenSearchAndClone,
                ),
                AppButton(
                  key: const Key('stage5RefreshRegistryBtn'),
                  label: l.draftBlRefreshRegistry,
                  icon: Icons.refresh,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  onPressed: onRefreshRegistry,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l.idocAComprehensiveRegistryOfTemporaryAndFinally,
          style: TextStyle(color: AppTheme.textMutedOf(context), fontSize: 13),
        ),
        const SizedBox(height: 16),

        // 1. KPI Metric Banner
        IdocUi.metrics([
          MetricCardData(
            title: l.idocATotalBLSessions,
            shortTitle: l.idocATotalBLSessions,
            value: '$totalCount',
            icon: Icons.assignment_turned_in,
            color: AppTheme.cobalt,
          ),
          MetricCardData(
            title: l.idocAFinallyApprovedSessions,
            shortTitle: l.idocAFinallyApprovedSessions,
            value: '$certifiedCount',
            icon: Icons.verified_rounded,
            color: AppTheme.emerald,
          ),
          MetricCardData(
            title: l.idocATemporaryDraftsBeingEdited,
            shortTitle: l.idocATemporaryDraftsBeingEdited,
            value: '$draftCount',
            icon: Icons.bookmark_added_outlined,
            color: AppTheme.orange,
          ),
        ]),
        const SizedBox(height: 16),

        // 2. Status Chips & Filter Toolbar
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: Text(l.idocAAllCount(totalCount)),
              selected: selectedStatusFilter == 'ALL',
              onSelected: (_) => onStatusFilterChanged('ALL'),
              selectedColor: AppTheme.cobalt,
              labelStyle: TextStyle(
                color: selectedStatusFilter == 'ALL' ? AppTheme.white : (AppTheme.textPrimaryOf(context)),
                fontWeight: selectedStatusFilter == 'ALL' ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
            ChoiceChip(
              label: Text(l.idocAFinalApprovedCount(certifiedCount)),
              selected: selectedStatusFilter == 'CERTIFIED',
              onSelected: (_) => onStatusFilterChanged('CERTIFIED'),
              selectedColor: AppTheme.emerald,
              labelStyle: TextStyle(
                color: selectedStatusFilter == 'CERTIFIED' ? AppTheme.white : (AppTheme.textPrimaryOf(context)),
                fontWeight: selectedStatusFilter == 'CERTIFIED' ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
            ChoiceChip(
              label: Text(l.idocATemporaryDraftsCount(draftCount)),
              selected: selectedStatusFilter == 'DRAFT',
              onSelected: (_) => onStatusFilterChanged('DRAFT'),
              selectedColor: AppTheme.orange,
              labelStyle: TextStyle(
                color: selectedStatusFilter == 'DRAFT' ? AppTheme.white : (AppTheme.textPrimaryOf(context)),
                fontWeight: selectedStatusFilter == 'DRAFT' ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
            if (importFiles.isNotEmpty)
              SizedBox(
                width: 280,
                child: SearchableDropdownField<int?>(
                  labelText: l.idocAFilterByImportFile,
                  value: filterImportFileId,
                  items: [
                    SearchableDropdownItem<int?>(value: null, label: l.idocAAllShipmentsAndFiles),
                    ...importFiles.map((f) => SearchableDropdownItem<int?>(
                          value: f.importFileId,
                          label: '${f.primaryNameWithCode} - ${f.supplierName}',
                        )),
                  ],
                  onChanged: onImportFileIdChanged,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Search Bar & Export Action Buttons
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768;
            final searchBar = Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAltOf(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderOf(context)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppTheme.cobalt, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const Key('draftBlRegistrySearchInput'),
                      decoration: InputDecoration(
                        hintText: l.draftBlSearchRegistryHint,
                        hintStyle: TextStyle(color: isDark ? AppTheme.textMutedOf(context) : null),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: TextStyle(color: isDark ? AppTheme.white : null),
                      onChanged: onSearchQueryChanged,
                    ),
                  ),
                  if (registrySearchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: onClearSearch,
                    ),
                ],
              ),
            );

            final actionButtons = [
              AppButton(
                key: const Key('draftBlRegistryCopyBtn'),
                label: l.idocACopyTSV,
                icon: Icons.copy,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => DraftBlRegistryExportHelper.copyAsTsv(context, filteredReviews),
              ),
              AppButton(
                key: const Key('draftBlRegistryExcelBtn'),
                label: l.exportExcel,
                icon: Icons.table_chart,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => DraftBlRegistryExportHelper.exportToExcel(context, filteredReviews),
              ),
              AppButton(
                key: const Key('draftBlRegistryPdfBtn'),
                label: l.exportPdf,
                icon: Icons.picture_as_pdf,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => DraftBlRegistryExportHelper.exportToPdf(context, filteredReviews),
              ),
            ];

            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchBar,
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: actionButtons),
                  const SizedBox(height: 16),
                ],
              );
            } else {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(child: searchBar),
                    const SizedBox(width: 10),
                    ...actionButtons.map((btn) => Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: btn,
                        )),
                  ],
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
