import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/docs_customs_approval_model.dart';
import 'doc_approval_helpers.dart';

class DocApprovalDocumentsTable extends StatelessWidget {
  final AsyncValue<List<CustomsDocumentApprovalModel>> approvalsState;
  final VoidCallback onRefresh;
  final VoidCallback onCopyTsv;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final ValueChanged<CustomsDocumentApprovalModel> onCommercialReview;
  final ValueChanged<CustomsDocumentApprovalModel> onCustomsBrokerReview;
  final ValueChanged<CustomsDocumentApprovalModel> onCloneItem;

  const DocApprovalDocumentsTable({
    super.key,
    required this.approvalsState,
    required this.onRefresh,
    required this.onCopyTsv,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.onCommercialReview,
    required this.onCustomsBrokerReview,
    required this.onCloneItem,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final approvals = approvalsState.valueOrNull ?? const [];
    final hasItems = approvals.isNotEmpty;

    return Card(
      elevation: 2,
      color: isDark ? AppTheme.darkCardBackground : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user, color: AppTheme.cobalt),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.customsApprovalDualTierHeader,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    key: const Key('copyApprovalsBtn'),
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    onPressed: hasItems ? onCopyTsv : null,
                    tooltip: context.l10n.idocACopyTableAsTSV,
                  ),
                  IconButton(
                    key: const Key('exportApprovalsExcelBtn'),
                    icon: const Icon(Icons.table_chart_outlined, size: 18),
                    onPressed: hasItems ? onExportExcel : null,
                    tooltip: context.l10n.exportExcel,
                  ),
                  IconButton(
                    key: const Key('exportApprovalsPdfBtn'),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    onPressed: hasItems ? onExportPdf : null,
                    tooltip: context.l10n.exportPdf,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: onRefresh,
                    tooltip: context.l10n.refresh,
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: approvalsState.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      context.l10n.customsApprovalError(ApiErrorText.of(context.l10n, e)),
                      style: const TextStyle(color: AppTheme.crimson),
                    ),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          context.l10n.customsApprovalNoDocuments,
                          style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return DocApprovalRow(
                          item: item,
                          onCommercialReview: () => onCommercialReview(item),
                          onCustomsBrokerReview: () => onCustomsBrokerReview(item),
                          onCloneItem: () => onCloneItem(item),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DocApprovalRow extends StatelessWidget {
  final CustomsDocumentApprovalModel item;
  final VoidCallback onCommercialReview;
  final VoidCallback onCustomsBrokerReview;
  final VoidCallback onCloneItem;

  const DocApprovalRow({
    super.key,
    required this.item,
    required this.onCommercialReview,
    required this.onCustomsBrokerReview,
    required this.onCloneItem,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Color overallColor = AppTheme.orange;
    if (item.overallStatus == 'Approved for Clearance') overallColor = AppTheme.emerald;
    if (item.overallStatus == 'Rectification Required' || item.overallStatus == 'Rejected') {
      overallColor = AppTheme.crimson;
    }

    final localizedDocType = DocApprovalHelpers.getLocalizedDocType(item.documentType, l);
    final localizedOverallStatus = DocApprovalHelpers.getLocalizedOverallStatus(item.overallStatus, l);
    final localizedCommercialStatus = DocApprovalHelpers.getLocalizedCommercialStatus(item.commercialStatus, l);
    final localizedBrokerStatus = DocApprovalHelpers.getLocalizedBrokerStatus(item.customsStatus, l);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: CopyableText(
                  localizedDocType,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                  overflow: TextOverflow.ellipsis,
                  isSelectable: false,
                ),
              ),
              if (item.documentReferenceNo != null)
                CopyableText(
                  l.customsApprovalDocRef(item.documentReferenceNo!),
                  style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryOf(context)),
                  overflow: TextOverflow.ellipsis,
                  isSelectable: false,
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: overallColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: overallColor.withValues(alpha: 0.5)),
                    ),
                    child: CopyableText(
                      localizedOverallStatus,
                      style: TextStyle(color: overallColor, fontWeight: FontWeight.bold, fontSize: 11),
                      isSelectable: false,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: Key('cloneApprovalRowBtn_${item.approvalId}'),
                    icon: const Icon(Icons.copy_all, size: 16, color: AppTheme.wcagCobalt),
                    tooltip: l.cloneApprovalRecordTooltip,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onCloneItem,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // Tier 1: Commercial Review
              InkWell(
                onTap: onCommercialReview,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: item.commercialStatus == 'Approved'
                        ? AppTheme.emerald.withValues(alpha: 0.08)
                        : (AppTheme.surfaceAltOf(context)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: item.commercialStatus == 'Approved'
                          ? AppTheme.emerald
                          : (AppTheme.borderOf(context)),
                    ),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      Icon(
                        item.commercialStatus == 'Approved' ? Icons.check_circle : Icons.person_outline,
                        size: 16,
                        color: item.commercialStatus == 'Approved'
                            ? AppTheme.emerald
                            : (AppTheme.textMutedOf(context)),
                      ),
                      Text(
                        l.customsApprovalCommercialReviewStatus(localizedCommercialStatus),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: item.commercialStatus == 'Approved'
                              ? AppTheme.emerald
                              : (AppTheme.textPrimaryOf(context)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tier 2: Customs Broker Sign-off
              InkWell(
                onTap: onCustomsBrokerReview,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: item.customsStatus == 'Approved'
                        ? AppTheme.emerald.withValues(alpha: 0.08)
                        : (AppTheme.surfaceAltOf(context)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: item.customsStatus == 'Approved'
                          ? AppTheme.emerald
                          : (AppTheme.borderOf(context)),
                    ),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      Icon(
                        item.customsStatus == 'Approved' ? Icons.verified : Icons.gavel,
                        size: 16,
                        color: item.customsStatus == 'Approved'
                            ? AppTheme.emerald
                            : (AppTheme.textMutedOf(context)),
                      ),
                      Text(
                        l.customsApprovalBrokerReviewStatus(localizedBrokerStatus),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: item.customsStatus == 'Approved'
                              ? AppTheme.emerald
                              : (AppTheme.textPrimaryOf(context)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
