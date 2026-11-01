import 'package:flutter/material.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/buttons/app_button.dart';
import '../../../../../core/widgets/metric_card.dart';
import '../../../../../core/widgets/searchable_dropdown_field.dart';
import '../../idoc_ui.dart';

class InvoiceBlSessionsToolbar extends StatelessWidget {
  final int totalCount;
  final int certifiedCount;
  final int draftCount;
  final double avgScore;
  final VoidCallback onNewSession;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final List<dynamic> importFiles;
  final int? filterImportFileId;
  final ValueChanged<int?> onFilterImportFileChanged;
  final String selectedStatusFilter;
  final ValueChanged<String> onStatusFilterChanged;
  final VoidCallback onCopyTsv;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final VoidCallback onRefresh;
  final bool hasFilteredSessions;

  const InvoiceBlSessionsToolbar({
    super.key,
    required this.totalCount,
    required this.certifiedCount,
    required this.draftCount,
    required this.avgScore,
    required this.onNewSession,
    required this.searchController,
    required this.onSearchChanged,
    required this.importFiles,
    required this.filterImportFileId,
    required this.onFilterImportFileChanged,
    required this.selectedStatusFilter,
    required this.onStatusFilterChanged,
    required this.onCopyTsv,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.onRefresh,
    required this.hasFilteredSessions,
  });

  Widget _buildStatusFilterChip(String value, String label) {
    final isSelected = selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onStatusFilterChanged(value),
      selectedColor: AppTheme.cobalt,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.white : AppTheme.charcoal,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. KPI Stats Bar
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IdocUi.metrics([
              MetricCardData(
                title: context.l10n.idocATotalSessions,
                shortTitle: context.l10n.idocATotalSessions,
                value: '$totalCount',
                icon: Icons.all_inbox_rounded,
                color: AppTheme.cobalt,
              ),
              MetricCardData(
                title: context.l10n.idocAApprovedSessions,
                shortTitle: context.l10n.idocAApprovedSessions,
                value: '$certifiedCount',
                icon: Icons.verified_rounded,
                color: AppTheme.emerald,
              ),
              MetricCardData(
                title: context.l10n.idocATemporaryDrafts,
                shortTitle: context.l10n.idocATemporaryDrafts,
                value: '$draftCount',
                icon: Icons.bookmark_added_rounded,
                color: AppTheme.orange,
              ),
              MetricCardData(
                title: context.l10n.idocAAverageMatch,
                shortTitle: context.l10n.idocAAverageMatch,
                value: '${avgScore.toStringAsFixed(1)}%',
                icon: Icons.percent_rounded,
                color: AppTheme.wcagEmerald,
              ),
            ]),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IdocUi.fit(AppButton(
                label: context.l10n.idocANewInspectionSession,
                icon: Icons.add_rounded,
                variant: AppButtonVariant.primary,
                onPressed: onNewSession,
              )),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Search & Filter Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderOf(context)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final searchField = TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: context.l10n.idocASearchBySessionCodeImportFile,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged();
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (_) => onSearchChanged(),
              );

              final filterDropdown = SearchableDropdownField<int?>(
                labelText: context.l10n.idocAFilterByImportFile,
                hintText: context.l10n.idocAAllImportFiles,
                value: filterImportFileId,
                items: [
                  SearchableDropdownItem<int?>(value: null, label: context.l10n.idocAAllImportFiles),
                  ...importFiles.map(
                    (f) => SearchableDropdownItem<int?>(
                      value: f.importFileId,
                      label: '${f.primaryNameWithCode} - ${f.supplierName}',
                    ),
                  ),
                ],
                onChanged: onFilterImportFileChanged,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isNarrow) ...[
                    searchField,
                    const SizedBox(height: 10),
                    filterDropdown,
                  ] else ...[
                    Row(
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: 12),
                        SizedBox(width: 260, child: filterDropdown),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildStatusFilterChip('ALL', context.l10n.idocAAllCount(totalCount)),
                          _buildStatusFilterChip('CERTIFIED', context.l10n.idocAApprovedCount(certifiedCount)),
                          _buildStatusFilterChip('DRAFT', context.l10n.idocATemporaryDraftsCount3(draftCount)),
                        ],
                      ),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy_all, color: AppTheme.cobalt),
                            tooltip: context.l10n.idocACopyTableTSV,
                            onPressed: hasFilteredSessions ? onCopyTsv : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.table_view_outlined, color: AppTheme.emerald),
                            tooltip: context.l10n.idocAExportExcel,
                            onPressed: hasFilteredSessions ? onExportExcel : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson),
                            tooltip: context.l10n.idocAPrintPDFReport,
                            onPressed: hasFilteredSessions ? onExportPdf : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: AppTheme.charcoal),
                            tooltip: context.l10n.refresh,
                            onPressed: onRefresh,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
