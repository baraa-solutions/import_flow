import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/system_messages/coded_item_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_documentation_model.dart';
import '../idoc_ui_b.dart';
import '../search_and_clone_coo_dialog.dart';
import '../visual_draft_coo_sheet.dart';
import 'coo_review_localizer.dart';

class CooReviewDialogs {
  static void openSearchAndCloneCooDialog({
    required BuildContext context,
    required List<CertificateOfOriginReviewModel> reviews,
    required void Function(CertificateOfOriginReviewModel) onSelectReview,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => SelectionArea(
        child: SearchAndCloneCooDialog(
          reviews: reviews,
          onSelectReview: onSelectReview,
        ),
      ),
    );
  }

  static void cloneCOOReview({
    required BuildContext context,
    required CertificateOfOriginReviewModel session,
    required void Function(String newCode, String suggestedCode) onConfirmClone,
  }) {
    final expName = session.draftInputData?['exporter_name'] ??
        session.draftInputData?['box_1_exporter'] ??
        session.systemSnapshotData?['supplier_name'] ??
        '—';
    final impName = session.draftInputData?['importer_name'] ??
        session.draftInputData?['box_2_consignee'] ??
        session.systemSnapshotData?['company_name'] ??
        '—';
    final originCountry = session.draftInputData?['country_of_origin'] ??
        session.draftInputData?['box_3_country_of_origin'] ??
        '—';
    final destCountry = session.draftInputData?['destination_country'] ??
        session.draftInputData?['box_4_country_of_destination'] ??
        '—';
    final invNo = session.draftInputData?['invoice_number'] ??
        session.draftInputData?['box_10_invoice_number_and_date'] ??
        '—';

    final suggestedCode = session.certificateType.contains('EUR')
        ? 'DRAFT-EUR1-2026-'
        : 'DRAFT-COO-2026-';

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: SelectionArea(
            child: CloneEntityReviewDialog(
              entityType: context.l10n.idocBCooCloneEntity,
              sourceCode: session.cooReviewCode,
              sourceTitle: '${session.certificateType} - ${session.certificateNumber}',
              suggestedNewCode: suggestedCode,
              copiedFieldsSummary: {
                context.l10n.idocBCooCloneFieldType: session.certificateType,
                context.l10n.idocBCooCloneFieldExporter: expName,
                context.l10n.idocBCooCloneFieldImporter: impName,
                context.l10n.idocBCooCloneFieldOrigin: originCountry,
                context.l10n.idocBCooCloneFieldDestination: destCountry,
                context.l10n.idocBCooCloneFieldInvoice: invNo,
              },
              mandatorilyResetFields: [
                context.l10n.idocBCooCloneReset1,
                context.l10n.idocBCooCloneReset2,
                context.l10n.idocBCooCloneReset3,
                context.l10n.idocBCooCloneReset4,
              ],
              allowCopyLineItems: false,
              allowCopyAttachments: false,
              onConfirm: ({
                required String newCode,
                required String newTitle,
                required bool copyLineItems,
                required bool copyAttachments,
                String? notes,
              }) async {
                onConfirmClone(newCode, suggestedCode);
              },
            ),
          ),
        ),
      ),
    );
  }

  static void showOfficialDraftPreviewDialog({
    required BuildContext context,
    required Map<String, dynamic> template,
    required String certType,
    required String acidNo,
    required String exemption,
    required String preview,
    required VoidCallback onRefresh,
    required void Function({
      String? certNumber,
      String? originCountry,
      String? destCountry,
      String? exporter,
      String? importer,
      String? rawText,
    }) onAutoFill,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified, color: AppTheme.cobalt),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.cooVisualPreviewTitle(certType),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textMuted),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          content: SizedBox(
            width: 860,
            child: SingleChildScrollView(
              child: VisualDraftCOOSheet(
                templateData: template,
                certificateType: certType,
                acidNumber: acidNo,
                exemptionNotes: exemption,
                onRefresh: onRefresh,
              ),
            ),
          ),
          actions: [
            IdocBUi.fit(
              AppButton(
                label: context.l10n.cancel,
                onPressed: () => Navigator.pop(ctx),
                variant: AppButtonVariant.secondary,
              ),
            ),
            IdocBUi.fit(
              AppButton(
                label: context.l10n.cooAutoFillFieldsButton,
                onPressed: () {
                  Navigator.pop(ctx);
                  onAutoFill(
                    certNumber: template['certificate_number']?.toString(),
                    originCountry: template['country_of_origin']?.toString(),
                    destCountry: template['destination_country']?.toString(),
                    exporter: template['box_1_exporter']?.toString(),
                    importer: template['box_2_consignee']?.toString(),
                    rawText: preview,
                  );
                },
                variant: AppButtonVariant.success,
                icon: Icons.check,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showCOOReviewDetailsDialog({
    required BuildContext context,
    required CertificateOfOriginReviewModel r,
    required void Function(CertificateOfOriginReviewModel) onRestore,
  }) {
    final expName = r.draftInputData?['exporter_name'] ?? r.draftInputData?['box_1_exporter'] ?? '—';
    final impName = r.draftInputData?['importer_name'] ?? r.draftInputData?['box_2_consignee'] ?? '—';
    final originCountry = r.draftInputData?['country_of_origin'] ?? '—';
    final destCountry = r.draftInputData?['destination_country'] ?? r.draftInputData?['box_4_country_of_destination'] ?? '—';
    final overrideReason = r.notes ?? r.draftInputData?['override_reason'] ?? '';
    final isDraft = r.isDraft;

    showDialog(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDraft ? AppTheme.orange : AppTheme.emerald).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isDraft ? Icons.bookmark_added_rounded : Icons.verified_rounded,
                  color: isDraft ? AppTheme.orange : AppTheme.emerald,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.cooDetailsDialogTitle(r.cooReviewCode),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.idocBCooCertLine(r.certificateNumber, r.createdAt),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDraft ? AppTheme.orange : AppTheme.emerald).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDraft ? AppTheme.orange : AppTheme.emerald),
                ),
                child: Text(
                  isDraft ? context.l10n.idocBSessionDraft : context.l10n.idocBSessionCertified,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDraft ? AppTheme.orange : AppTheme.emerald,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(context.l10n.cooDetailsCertTypeAndNumber),
                    subtitle: CopyableText('${r.certificateType} — #${r.certificateNumber}'),
                    dense: true,
                  ),
                  ListTile(
                    title: Text(context.l10n.cooDetailsExporterAndImporter),
                    subtitle: CopyableText('${context.l10n.cooDetailsExporterLabel}: $expName\n${context.l10n.cooDetailsImporterLabel}: $impName'),
                    dense: true,
                  ),
                  ListTile(
                    title: Text(context.l10n.cooDetailsOriginAndDestination),
                    subtitle: CopyableText('$originCountry ➔ $destCountry'),
                    dense: true,
                  ),
                  if (overrideReason.isNotEmpty)
                    ListTile(
                      title: Text(context.l10n.cooDetailsOverrideReason),
                      subtitle: CopyableText(overrideReason, style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold)),
                      dense: true,
                    ),
                  if (r.comparisonMatrix.isNotEmpty) ...[
                    const Divider(),
                    Text(context.l10n.cooDetailsMatrixTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...r.comparisonMatrix.map((m) {
                      final item = m is Map ? CodedItemText.localizeRow(m, context.l10n) : {};
                      final fieldKey = item['field']?.toString() ?? '';
                      final fieldLabel = CooReviewLocalizer.getFieldLabel(fieldKey, item['field_label_ar']?.toString(), context.l10n);
                      final dText = '$fieldLabel: [${item['draft_value']}] vs [${item['system_value']}]';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(
                              item['match_status'] == 'MATCH' ? Icons.check_circle : Icons.warning,
                              color: item['match_status'] == 'MATCH' ? AppTheme.emerald : AppTheme.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: CopyableText(
                                dText,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            IdocBUi.fit(
              AppButton(
                label: context.l10n.idocBCooRestoreBtn,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onRestore(r);
                },
                variant: AppButtonVariant.secondary,
                icon: Icons.play_circle_outline,
              ),
            ),
            IdocBUi.fit(
              AppButton(
                label: context.l10n.close,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool> confirmDeleteCOODraft({
    required BuildContext context,
    required String reviewCode,
  }) async {
    final confirmed = await AppConfirmDialog.showDelete(
      context,
      title: context.l10n.idocBCooDeleteTitle,
      message: context.l10n.idocBCooDeleteConfirm(reviewCode),
    );
    return confirmed == true;
  }
}
