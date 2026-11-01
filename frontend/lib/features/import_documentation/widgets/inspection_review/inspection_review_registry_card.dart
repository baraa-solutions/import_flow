import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_documentation_model.dart';
import '../idoc_ui_b.dart';

class InspectionReviewRegistryCard extends StatelessWidget {
  final List<InspectionCertificateReviewModel> reviews;
  final VoidCallback onStartNewReview;
  final void Function(InspectionCertificateReviewModel review) onEdit;
  final void Function(InspectionCertificateReviewModel review) onViewDetails;
  final void Function(InspectionCertificateReviewModel review) onDownloadPdf;
  final void Function(InspectionCertificateReviewModel review) onDelete;

  const InspectionReviewRegistryCard({
    super.key,
    required this.reviews,
    required this.onStartNewReview,
    required this.onEdit,
    required this.onViewDetails,
    required this.onDownloadPdf,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_edu, color: AppTheme.cobalt, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      l10n.inspReviewsRegistryTitle(reviews.length),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IdocBUi.fit(
                  AppButton(
                    label: l10n.startNewInspReviewBtn,
                    onPressed: onStartNewReview,
                    icon: Icons.add,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (reviews.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text(l10n.noInspReviewsYet)),
              )
            else
              EnterpriseDataTable<InspectionCertificateReviewModel>(
                data: reviews,
                storageKey: 'inspection_reviews_registry_table',
                columns: [
                  EnterpriseColumn<InspectionCertificateReviewModel>(
                    id: 'actions',
                    title: l10n.colInspActions,
                    width: 170,
                    isSortable: false,
                    isSearchable: false,
                    cellBuilder: (context, r, index) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: AppTheme.cobalt, size: 18),
                            tooltip: l10n.editInspSessionTooltip,
                            onPressed: () => onEdit(r),
                          ),
                          IconButton(
                            icon: const Icon(Icons.visibility, color: AppTheme.charcoal, size: 18),
                            tooltip: l10n.viewInspDetailsTooltip,
                            onPressed: () => onViewDetails(r),
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: AppTheme.crimson, size: 18),
                            tooltip: l10n.downloadInspPdfTooltip,
                            onPressed: () => onDownloadPdf(r),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 18),
                            tooltip: l10n.deleteInspSessionTooltip,
                            onPressed: () => onDelete(r),
                          ),
                        ],
                      );
                    },
                  ),
                  EnterpriseColumn<InspectionCertificateReviewModel>(
                    id: 'session_code',
                    title: l10n.colInspSessionCode,
                    width: 130,
                    isSortable: true,
                    searchValue: (r) => r.inspectionReviewCode,
                    exportValue: (r) => r.inspectionReviewCode,
                    cellBuilder: (context, r, index) => Text(
                      r.inspectionReviewCode,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                    ),
                  ),
                  EnterpriseColumn<InspectionCertificateReviewModel>(
                    id: 'cert_type',
                    title: l10n.colInspCertType,
                    width: 140,
                    isSortable: true,
                    searchValue: (r) => r.inspectionType,
                    exportValue: (r) => r.inspectionType,
                    cellBuilder: (context, r, index) => Text(r.inspectionType),
                  ),
                  EnterpriseColumn<InspectionCertificateReviewModel>(
                    id: 'agency',
                    title: l10n.colInspAgency,
                    width: 140,
                    isSortable: true,
                    searchValue: (r) => r.inspectionAgency,
                    exportValue: (r) => r.inspectionAgency,
                    cellBuilder: (context, r, index) => Text(r.inspectionAgency),
                  ),
                  EnterpriseColumn<InspectionCertificateReviewModel>(
                    id: 'cert_no',
                    title: l10n.colInspCertNo,
                    width: 140,
                    isSortable: true,
                    searchValue: (r) => r.certificateNumber,
                    exportValue: (r) => r.certificateNumber,
                    cellBuilder: (context, r, index) => Text(r.certificateNumber),
                  ),
                  EnterpriseColumn<InspectionCertificateReviewModel>(
                    id: 'status',
                    title: l10n.colInspStatus,
                    width: 120,
                    isSortable: true,
                    searchValue: (r) => r.status,
                    exportValue: (r) => r.status,
                    cellBuilder: (context, r, index) {
                      final isVerified = r.status == 'Verified';
                      return AppStatusBadge(
                        label: r.status,
                        severity: isVerified ? AppSeverity.success : AppSeverity.warning,
                        size: AppStatusBadgeSize.small,
                      );
                    },
                  ),
                  EnterpriseColumn<InspectionCertificateReviewModel>(
                    id: 'created_at',
                    title: l10n.colInspCreatedAt,
                    width: 120,
                    isSortable: true,
                    searchValue: (r) => r.createdAt.length >= 10 ? r.createdAt.substring(0, 10) : r.createdAt,
                    exportValue: (r) => r.createdAt.length >= 10 ? r.createdAt.substring(0, 10) : r.createdAt,
                    cellBuilder: (context, r, index) {
                      final createdStr = r.createdAt.length >= 10 ? r.createdAt.substring(0, 10) : r.createdAt;
                      return Text(createdStr);
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
