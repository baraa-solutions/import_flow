import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_documentation_model.dart';
import '../../providers/import_documentation_provider.dart';
import 'coo_review_actions_bar.dart';
import 'coo_review_dialogs.dart';
import 'coo_review_service.dart';
import 'coo_review_table_exporter.dart';

class CooReviewRegistryCard extends ConsumerWidget {
  final List<dynamic> importFiles;
  final String selectedStatusFilter;
  final int? filterImportFileId;
  final TextEditingController registrySearchCtrl;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<int?> onFileFilterChanged;
  final VoidCallback onSearchChanged;
  final VoidCallback onSearchAndClone;
  final VoidCallback onNewDraft;
  final ValueChanged<CertificateOfOriginReviewModel> onCloneReview;
  final ValueChanged<CertificateOfOriginReviewModel> onLoadSessionIntoEditor;
  final ValueChanged<CertificateOfOriginReviewModel> onDeleteDraft;

  const CooReviewRegistryCard({
    super.key,
    required this.importFiles,
    required this.selectedStatusFilter,
    required this.filterImportFileId,
    required this.registrySearchCtrl,
    required this.onStatusFilterChanged,
    required this.onFileFilterChanged,
    required this.onSearchChanged,
    required this.onSearchAndClone,
    required this.onNewDraft,
    required this.onCloneReview,
    required this.onLoadSessionIntoEditor,
    required this.onDeleteDraft,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cooReviews = ref.watch(cooReviewsProvider);

    return cooReviews.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(ApiErrorText.of(context.l10n, e)),
      data: (reviews) {
        final totalSessions = reviews.length;
        final certifiedSessions = reviews.where((r) => !r.isDraft).length;
        final draftSessions = reviews.where((r) => r.isDraft).length;

        final query = registrySearchCtrl.text.trim().toLowerCase();
        final filteredReviews = reviews.where((r) {
          if (selectedStatusFilter == 'CERTIFIED' && r.isDraft) return false;
          if (selectedStatusFilter == 'DRAFT' && !r.isDraft) return false;
          if (filterImportFileId != null && r.importFileId != filterImportFileId) return false;
          if (query.isNotEmpty) {
            final certNum = r.certificateNumber.toLowerCase();
            final code = r.cooReviewCode.toLowerCase();
            final type = r.certificateType.toLowerCase();
            final status = r.status.toLowerCase();
            final expName = (r.draftInputData?['exporter_name'] ??
                    r.draftInputData?['box_1_exporter'] ??
                    r.systemSnapshotData?['supplier_name'] ??
                    '')
                .toString()
                .toLowerCase();
            final impName = (r.draftInputData?['importer_name'] ??
                    r.draftInputData?['box_2_consignee'] ??
                    r.systemSnapshotData?['company_name'] ??
                    '')
                .toString()
                .toLowerCase();
            return certNum.contains(query) ||
                code.contains(query) ||
                type.contains(query) ||
                status.contains(query) ||
                expName.contains(query) ||
                impName.contains(query);
          }
          return true;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // KPI & Metrics Header Banner
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.charcoal, AppTheme.charcoal.withValues(alpha: 0.92)],
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.history_edu, color: AppTheme.darkHyperlink, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.cooRegistryTitle,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.l10n.idocBCooRegistrySubtitle,
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.cloudWhite),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _buildKpiCard(
                            icon: Icons.list_alt,
                            label: context.l10n.idocBCooKpiTotal,
                            value: '$totalSessions',
                            color: AppTheme.white,
                          ),
                          _buildKpiCard(
                            icon: Icons.verified,
                            label: context.l10n.idocBCooKpiCertified,
                            value: '$certifiedSessions',
                            color: AppTheme.emerald,
                          ),
                          _buildKpiCard(
                            icon: Icons.bookmark_added,
                            label: context.l10n.idocBCooKpiDrafts,
                            value: '$draftSessions',
                            color: AppTheme.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        context.l10n.idocBCooFilterStatus,
                        style: const TextStyle(color: AppTheme.cloudWhite, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      ChoiceChip(
                        label: Text(
                          context.l10n.idocBCooFilterAll(totalSessions),
                          style: TextStyle(
                            fontSize: 11,
                            color: selectedStatusFilter == 'ALL' ? AppTheme.white : AppTheme.textPrimary,
                          ),
                        ),
                        selected: selectedStatusFilter == 'ALL',
                        selectedColor: AppTheme.cobalt,
                        onSelected: (v) => onStatusFilterChanged('ALL'),
                      ),
                      ChoiceChip(
                        label: Text(
                          context.l10n.idocBCooFilterCertified(certifiedSessions),
                          style: TextStyle(
                            fontSize: 11,
                            color: selectedStatusFilter == 'CERTIFIED' ? AppTheme.white : AppTheme.textPrimary,
                          ),
                        ),
                        selected: selectedStatusFilter == 'CERTIFIED',
                        selectedColor: AppTheme.emerald,
                        onSelected: (v) => onStatusFilterChanged('CERTIFIED'),
                      ),
                      ChoiceChip(
                        label: Text(
                          context.l10n.idocBCooFilterDrafts(draftSessions),
                          style: TextStyle(
                            fontSize: 11,
                            color: selectedStatusFilter == 'DRAFT' ? AppTheme.white : AppTheme.textPrimary,
                          ),
                        ),
                        selected: selectedStatusFilter == 'DRAFT',
                        selectedColor: AppTheme.orange,
                        onSelected: (v) => onStatusFilterChanged('DRAFT'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 768;
                        final searchBar = TextField(
                          key: const Key('cooRegistrySearchField'),
                          controller: registrySearchCtrl,
                          decoration: InputDecoration(
                            hintText: context.l10n.cooRegistrySearchHint,
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: registrySearchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      registrySearchCtrl.clear();
                                      onSearchChanged();
                                    },
                                  )
                                : null,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (_) => onSearchChanged(),
                        );

                        final fileFilter = SizedBox(
                          width: isMobile ? double.infinity : 280,
                          child: SearchableDropdownField<int?>(
                            value: filterImportFileId,
                            labelText: context.l10n.idocBFilterByFile,
                            searchHintText: context.l10n.idocBSearchFileHint,
                            items: [
                              SearchableDropdownItem<int?>(value: null, label: context.l10n.idocBAllFiles),
                              ...importFiles.map((f) => SearchableDropdownItem<int?>(
                                    value: f.importFileId,
                                    label: '${f.primaryNameWithCode} - ${f.companyName}',
                                  )),
                            ],
                            onChanged: onFileFilterChanged,
                          ),
                        );

                        final actionsBar = CooReviewRegistryActionsBar(
                          onSearchAndClone: onSearchAndClone,
                          onCopyTable: () => CooReviewTableExporter.copyAsTsv(context, filteredReviews),
                          onExportExcel: () => CooReviewTableExporter.exportToExcel(context, filteredReviews),
                          onExportPdf: () => CooReviewTableExporter.exportToPdf(context, filteredReviews),
                          onNewDraft: onNewDraft,
                        );

                        if (isMobile) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              searchBar,
                              const SizedBox(height: 10),
                              fileFilter,
                              const SizedBox(height: 10),
                              actionsBar,
                            ],
                          );
                        }

                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: searchBar),
                                const SizedBox(width: 12),
                                fileFilter,
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: actionsBar,
                            ),
                          ],
                        );
                      },
                    ),
                    const Divider(height: 20),
                    if (filteredReviews.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Text(
                            reviews.isEmpty ? context.l10n.cooNoReviewsYet : context.l10n.noCooReviewsFound,
                          ),
                        ),
                      )
                    else
                      EnterpriseDataTable<CertificateOfOriginReviewModel>(
                        data: filteredReviews,
                        storageKey: 'coo_reviews_registry_table',
                        columns: [
                          EnterpriseColumn<CertificateOfOriginReviewModel>(
                            id: 'actions',
                            title: context.l10n.cooRegistryColActions,
                            width: 220,
                            isSortable: false,
                            isSearchable: false,
                            cellBuilder: (context, r, index) {
                              final isDraft = r.isDraft;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    key: Key('cloneCooRowBtn_${r.cooReviewId}'),
                                    icon: const Icon(Icons.copy_all, color: AppTheme.wcagCobalt, size: 18),
                                    tooltip: context.l10n.cloneCooRecordTooltip,
                                    onPressed: () => onCloneReview(r),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.play_circle_outline, color: AppTheme.cobalt, size: 18),
                                    tooltip: context.l10n.idocBCooRestoreTooltip,
                                    onPressed: () => onLoadSessionIntoEditor(r),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.visibility, color: AppTheme.charcoal, size: 18),
                                    tooltip: context.l10n.cooViewDetailsTooltip,
                                    onPressed: () => CooReviewDialogs.showCOOReviewDetailsDialog(
                                      context: context,
                                      r: r,
                                      onRestore: (session) => onLoadSessionIntoEditor(session),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.picture_as_pdf, color: AppTheme.crimson, size: 18),
                                    tooltip: context.l10n.cooDownloadPdfTooltip,
                                    onPressed: () => CooReviewService.exportRegistryRowPdf(
                                      context: context,
                                      ref: ref,
                                      review: r,
                                    ),
                                  ),
                                  if (isDraft)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 18),
                                      tooltip: context.l10n.idocBCooDeleteDraftTooltip,
                                      onPressed: () => onDeleteDraft(r),
                                    ),
                                ],
                              );
                            },
                          ),
                          EnterpriseColumn<CertificateOfOriginReviewModel>(
                            id: 'session_type',
                            title: context.l10n.idocBSessionTypeCol,
                            width: 120,
                            isSortable: true,
                            searchValue: (r) => r.isDraft ? context.l10n.idocBSessionDraft : context.l10n.idocBSessionCertified,
                            exportValue: (r) => r.isDraft ? context.l10n.idocBSessionDraft : context.l10n.idocBSessionCertified,
                            cellBuilder: (context, r, index) {
                              final isDraft = r.isDraft;
                              return AppStatusBadge(
                                label: isDraft ? context.l10n.idocBSessionDraft : context.l10n.idocBSessionCertified,
                                severity: isDraft ? AppSeverity.warning : AppSeverity.success,
                                size: AppStatusBadgeSize.small,
                              );
                            },
                          ),
                          EnterpriseColumn<CertificateOfOriginReviewModel>(
                            id: 'code',
                            title: context.l10n.cooRegistryColCode,
                            width: 130,
                            isSortable: true,
                            searchValue: (r) => r.cooReviewCode,
                            exportValue: (r) => r.cooReviewCode,
                            cellBuilder: (context, r, index) => Text(
                              r.cooReviewCode,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                            ),
                          ),
                          EnterpriseColumn<CertificateOfOriginReviewModel>(
                            id: 'type',
                            title: context.l10n.cooRegistryColType,
                            width: 140,
                            isSortable: true,
                            searchValue: (r) => r.certificateType,
                            exportValue: (r) => r.certificateType,
                            cellBuilder: (context, r, index) => Text(r.certificateType),
                          ),
                          EnterpriseColumn<CertificateOfOriginReviewModel>(
                            id: 'number',
                            title: context.l10n.cooRegistryColNumber,
                            width: 140,
                            isSortable: true,
                            searchValue: (r) => r.certificateNumber,
                            exportValue: (r) => r.certificateNumber,
                            cellBuilder: (context, r, index) => Text(r.certificateNumber),
                          ),
                          EnterpriseColumn<CertificateOfOriginReviewModel>(
                            id: 'exporter',
                            title: context.l10n.cooRegistryColExporter,
                            width: 160,
                            isSortable: true,
                            searchValue: (r) => (r.draftInputData?['exporter_name'] ?? r.draftInputData?['box_1_exporter'] ?? '—').toString(),
                            exportValue: (r) => (r.draftInputData?['exporter_name'] ?? r.draftInputData?['box_1_exporter'] ?? '—').toString(),
                            cellBuilder: (context, r, index) {
                              final expName = (r.draftInputData?['exporter_name'] ?? r.draftInputData?['box_1_exporter'] ?? '—').toString();
                              return Text(expName);
                            },
                          ),
                          EnterpriseColumn<CertificateOfOriginReviewModel>(
                            id: 'status',
                            title: context.l10n.cooRegistryColStatus,
                            width: 120,
                            isSortable: true,
                            searchValue: (r) => r.status,
                            exportValue: (r) => r.status,
                            cellBuilder: (context, r, index) {
                              final isVerified = r.status == 'Verified' || r.status == 'Approved';
                              return AppStatusBadge(
                                label: r.status,
                                severity: isVerified ? AppSeverity.success : (r.isDraft ? AppSeverity.warning : AppSeverity.info),
                                size: AppStatusBadgeSize.small,
                              );
                            },
                          ),
                          EnterpriseColumn<CertificateOfOriginReviewModel>(
                            id: 'date',
                            title: context.l10n.cooRegistryColDate,
                            width: 120,
                            isSortable: true,
                            searchValue: (r) => r.createdAt.length >= 10 ? r.createdAt.substring(0, 10) : r.createdAt,
                            exportValue: (r) => r.createdAt.length >= 10 ? r.createdAt.substring(0, 10) : r.createdAt,
                            cellBuilder: (context, r, index) {
                              final dateStr = r.createdAt.length >= 10 ? r.createdAt.substring(0, 10) : r.createdAt;
                              return Text(dateStr);
                            },
                          ),
                        ],
                      )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.cloudWhite, fontSize: 11)),
              Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
