import 'package:flutter/material.dart';
import '../../../../../core/localization/api_error_text.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../models/import_documentation_model.dart';
import '../../../services/draft_bl_export_service.dart';
import 'draft_bl_session_details_dialog.dart';

class DraftBlRegistryTable extends StatelessWidget {
  final List<DraftBLReviewModel> filteredReviews;
  final String registrySearchQuery;
  final ValueChanged<DraftBLReviewModel> onCloneSession;
  final ValueChanged<DraftBLReviewModel> onLoadSessionIntoEditor;
  final Future<void> Function(DraftBLReviewModel) onDeleteSession;

  const DraftBlRegistryTable({
    super.key,
    required this.filteredReviews,
    required this.registrySearchQuery,
    required this.onCloneSession,
    required this.onLoadSessionIntoEditor,
    required this.onDeleteSession,
  });

  Future<void> _confirmDelete(BuildContext context, DraftBLReviewModel session) async {
    final l = context.l10n;
    final confirmed = await AppConfirmDialog.showDelete(
      context,
      title: l.idocAConfirmDraftSessionDeletion,
      message: l.idocAAreYouSureYouWantToAlt(session.blReviewCode),
    );
    if (confirmed == true) {
      try {
        await onDeleteSession(session);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, l.idocADraftSessionDeletedSuccessfully, severity: AppSeverity.info),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, ApiErrorText.of(l, e), severity: AppSeverity.danger),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (filteredReviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.textMutedOf(context)),
              const SizedBox(height: 10),
              Text(
                registrySearchQuery.isNotEmpty ? l.draftBlNoRegistriesFound : l.draftBlNoRegistriesYet,
                style: TextStyle(color: AppTheme.textMutedOf(context), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                registrySearchQuery.isNotEmpty ? l.draftBlTryDifferentSearch : l.draftBlExtractNewDraftHint,
                style: TextStyle(
                  color: isDark ? AppTheme.textMutedOf(context) : AppTheme.textSecondaryOf(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return EnterpriseDataTable<DraftBLReviewModel>(
      data: filteredReviews,
      storageKey: 'draft_bl_reviews_registry_table',
      columns: [
        EnterpriseColumn<DraftBLReviewModel>(
          id: 'actions',
          title: l.draftBlRegistryColActions,
          width: 260,
          isSortable: false,
          isSearchable: false,
          cellBuilder: (context, r, index) {
            final blNumber = (r.draftExtractedData?['draft_bl_number'] ??
                    r.draftExtractedData?['bl_number'] ??
                    r.systemDataSnapshot?['draft_bl_number'] ??
                    r.draftBlNumber)
                .toString();
            final isDraft = r.isDraft;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: l.cloneDraftBlRecordTooltip,
                  child: IconButton(
                    key: Key('cloneDraftBlRowBtn_${r.blReviewId}'),
                    icon: const Icon(Icons.copy_all, size: 18, color: AppTheme.emerald),
                    onPressed: () => onCloneSession(r),
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: EdgeInsets.zero,
                  ),
                ),
                Tooltip(
                  message: l.idocARestoreAndLoadTheSessionInAlt,
                  child: IconButton(
                    icon: const Icon(Icons.play_circle_outline, size: 18, color: AppTheme.cobalt),
                    onPressed: () => onLoadSessionIntoEditor(r),
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: EdgeInsets.zero,
                  ),
                ),
                Tooltip(
                  message: l.idocAViewSessionDetailsAndMatrix,
                  child: IconButton(
                    icon: Icon(Icons.info_outline, size: 18, color: AppTheme.textMutedOf(context)),
                    onPressed: () => DraftBlSessionDetailsDialog.show(
                      context,
                      session: r,
                      onLoadSessionIntoEditor: onLoadSessionIntoEditor,
                    ),
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: EdgeInsets.zero,
                  ),
                ),
                Tooltip(
                  message: l.draftBlPrintBlTooltip,
                  child: IconButton(
                    icon: Icon(Icons.print, size: 18, color: AppTheme.textPrimaryOf(context)),
                    onPressed: () async {
                      try {
                        final sysData = r.systemDataSnapshot ?? {};
                        final draftData = r.draftExtractedData ?? {};
                        await DraftBLExportService.printDraftBL(
                          systemData: sysData,
                          draftData: draftData,
                          draftBlNumber: blNumber,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            AppTheme.snackBar(
                              context,
                              l.draftBlPrintError(ApiErrorText.of(l, e)),
                              severity: AppSeverity.danger,
                            ),
                          );
                        }
                      }
                    },
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: EdgeInsets.zero,
                  ),
                ),
                Tooltip(
                  message: l.draftBlDownloadPdfTooltip,
                  child: IconButton(
                    icon: const Icon(Icons.picture_as_pdf, size: 18, color: AppTheme.crimson),
                    onPressed: () async {
                      try {
                        final sysData = r.systemDataSnapshot ?? {};
                        final draftData = r.draftExtractedData ?? {};
                        await DraftBLExportService.exportDraftBLToPdf(
                          systemData: sysData,
                          draftData: draftData,
                          draftBlNumber: blNumber,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            AppTheme.snackBar(
                              context,
                              l.draftBlPdfExportError(ApiErrorText.of(l, e)),
                              severity: AppSeverity.danger,
                            ),
                          );
                        }
                      }
                    },
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: EdgeInsets.zero,
                  ),
                ),
                if (isDraft)
                  Tooltip(
                    message: l.idocADeleteDraft,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.crimson),
                      onPressed: () => _confirmDelete(context, r),
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                    ),
                  ),
              ],
            );
          },
        ),
        EnterpriseColumn<DraftBLReviewModel>(
          id: 'session_type',
          title: l.idocASessionType,
          width: 110,
          isSortable: true,
          searchValue: (r) => r.isDraft ? l.idocADraft : l.idocACertified,
          exportValue: (r) => r.isDraft ? l.idocADraft : l.idocACertified,
          cellBuilder: (context, r, index) {
            final isDraft = r.isDraft;
            return AppStatusBadge(
              label: isDraft ? l.idocADraft : l.idocACertified,
              severity: isDraft ? AppSeverity.warning : AppSeverity.success,
              size: AppStatusBadgeSize.small,
            );
          },
        ),
        EnterpriseColumn<DraftBLReviewModel>(
          id: 'session_id',
          title: l.draftBlRegistryColSessionId,
          width: 90,
          isSortable: true,
          searchValue: (r) => '#${r.blReviewId}',
          exportValue: (r) => '#${r.blReviewId}',
          cellBuilder: (context, r, index) => Text('#${r.blReviewId}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        EnterpriseColumn<DraftBLReviewModel>(
          id: 'bl_number',
          title: l.draftBlRegistryColBlNumber,
          width: 150,
          isSortable: true,
          searchValue: (r) => (r.draftExtractedData?['draft_bl_number'] ??
                  r.draftExtractedData?['bl_number'] ??
                  r.systemDataSnapshot?['draft_bl_number'] ??
                  r.draftBlNumber)
              .toString(),
          exportValue: (r) => (r.draftExtractedData?['draft_bl_number'] ??
                  r.draftExtractedData?['bl_number'] ??
                  r.systemDataSnapshot?['draft_bl_number'] ??
                  r.draftBlNumber)
              .toString(),
          cellBuilder: (context, r, index) {
            final blNumber = (r.draftExtractedData?['draft_bl_number'] ??
                    r.draftExtractedData?['bl_number'] ??
                    r.systemDataSnapshot?['draft_bl_number'] ??
                    r.draftBlNumber)
                .toString();
            return Text(blNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt));
          },
        ),
        EnterpriseColumn<DraftBLReviewModel>(
          id: 'shipping_line',
          title: l.draftBlRegistryColShippingLine,
          width: 140,
          isSortable: true,
          searchValue: (r) => r.shippingLine ?? '-',
          exportValue: (r) => r.shippingLine ?? '-',
          cellBuilder: (context, r, index) => Text(r.shippingLine ?? '-'),
        ),
        EnterpriseColumn<DraftBLReviewModel>(
          id: 'vessel_voyage',
          title: l.draftBlRegistryColVesselVoyage,
          width: 150,
          isSortable: true,
          searchValue: (r) => '${r.vesselName ?? "-"} / ${r.voyageNumber ?? "-"}',
          exportValue: (r) => '${r.vesselName ?? "-"} / ${r.voyageNumber ?? "-"}',
          cellBuilder: (context, r, index) => Text('${r.vesselName ?? "-"} / ${r.voyageNumber ?? "-"}'),
        ),
        EnterpriseColumn<DraftBLReviewModel>(
          id: 'stage',
          title: l.draftBlRegistryColStage,
          width: 110,
          isSortable: true,
          searchValue: (r) => r.stage,
          exportValue: (r) => r.stage,
          cellBuilder: (context, r, index) => Text(r.stage),
        ),
        EnterpriseColumn<DraftBLReviewModel>(
          id: 'importer_approval',
          title: l.draftBlRegistryColImporterApproval,
          width: 130,
          isSortable: true,
          searchValue: (r) => r.importerApprovalStatus == 'Approved' ? l.approved : r.importerApprovalStatus,
          exportValue: (r) => r.importerApprovalStatus == 'Approved' ? l.approved : r.importerApprovalStatus,
          cellBuilder: (context, r, index) {
            final isApproved = r.importerApprovalStatus == 'Approved';
            return AppStatusBadge(
              label: isApproved ? l.approved : r.importerApprovalStatus,
              severity: isApproved ? AppSeverity.success : AppSeverity.warning,
              size: AppStatusBadgeSize.small,
            );
          },
        ),
        EnterpriseColumn<DraftBLReviewModel>(
          id: 'broker_approval',
          title: l.draftBlRegistryColBrokerApproval,
          width: 130,
          isSortable: true,
          searchValue: (r) => r.brokerApprovalStatus == 'Approved' ? l.approved : r.brokerApprovalStatus,
          exportValue: (r) => r.brokerApprovalStatus == 'Approved' ? l.approved : r.brokerApprovalStatus,
          cellBuilder: (context, r, index) {
            final isApproved = r.brokerApprovalStatus == 'Approved';
            return AppStatusBadge(
              label: isApproved ? l.approved : r.brokerApprovalStatus,
              severity: isApproved ? AppSeverity.success : AppSeverity.warning,
              size: AppStatusBadgeSize.small,
            );
          },
        ),
        EnterpriseColumn<DraftBLReviewModel>(
          id: 'status',
          title: l.draftBlRegistryColStatus,
          width: 120,
          isSortable: true,
          searchValue: (r) => r.status == 'Final Approved' || r.status == 'Approved' ? l.approved : r.status,
          exportValue: (r) => r.status == 'Final Approved' || r.status == 'Approved' ? l.approved : r.status,
          cellBuilder: (context, r, index) {
            final isApproved = r.status == 'Final Approved' || r.status == 'Approved';
            return AppStatusBadge(
              label: isApproved ? l.approved : r.status,
              severity: isApproved ? AppSeverity.success : AppSeverity.info,
              size: AppStatusBadgeSize.small,
            );
          },
        ),
      ],
    );
  }
}
