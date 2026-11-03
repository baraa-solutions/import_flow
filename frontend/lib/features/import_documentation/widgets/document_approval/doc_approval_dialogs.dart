import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/clone_entity_review_dialog.dart';
import '../../models/docs_customs_approval_model.dart';
import '../search_and_clone_customs_approval_dialog.dart';
import 'dialogs/commercial_review_dialog.dart';
import 'dialogs/customs_broker_review_dialog.dart';
import 'dialogs/raise_ticket_dialog.dart';
import 'dialogs/resolve_ticket_dialog.dart';
import 'doc_approval_helpers.dart';

export 'dialogs/commercial_review_dialog.dart';
export 'dialogs/customs_broker_review_dialog.dart';
export 'dialogs/raise_ticket_dialog.dart';
export 'dialogs/resolve_ticket_dialog.dart';

class DocApprovalDialogs {
  const DocApprovalDialogs._();

  static void showCommercialReview(
    BuildContext context, {
    required CustomsDocumentApprovalModel item,
    int? importFileId,
  }) {
    showDialog(
      context: context,
      builder: (c) => SelectionArea(
        child: CommercialReviewDialog(item: item, importFileId: importFileId),
      ),
    );
  }

  static void showCustomsBrokerReview(
    BuildContext context, {
    required CustomsDocumentApprovalModel item,
    int? importFileId,
  }) {
    showDialog(
      context: context,
      builder: (c) => SelectionArea(
        child: CustomsBrokerReviewDialog(item: item, importFileId: importFileId),
      ),
    );
  }

  static void showRaiseTicket(
    BuildContext context, {
    required int importFileId,
    CustomsDocumentApprovalModel? approvalItem,
    DiscrepancyRectificationTicketModel? initialTicket,
  }) {
    showDialog(
      context: context,
      builder: (c) => SelectionArea(
        child: RaiseTicketDialog(
          importFileId: importFileId,
          approvalItem: approvalItem,
          initialTicket: initialTicket,
        ),
      ),
    );
  }

  static void showResolveTicket(
    BuildContext context, {
    required DiscrepancyRectificationTicketModel ticket,
    int? importFileId,
  }) {
    showDialog(
      context: context,
      builder: (c) => SelectionArea(
        child: ResolveTicketDialog(ticket: ticket, importFileId: importFileId),
      ),
    );
  }

  static void openSearchAndClone(
    BuildContext context, {
    required List<CustomsDocumentApprovalModel> items,
    required ValueChanged<CustomsDocumentApprovalModel> onSelectItem,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => SearchAndCloneCustomsApprovalDialog(
        items: items,
        onSelectItem: onSelectItem,
      ),
    );
  }

  static void cloneApprovalItem(
    BuildContext context, {
    required CustomsDocumentApprovalModel sourceItem,
    required VoidCallback onCloned,
  }) {
    final l = context.l10n;
    final suggestedCode = 'DOCAPPR-2026-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final docType = DocApprovalHelpers.getLocalizedDocType(sourceItem.documentType, l);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    showDialog(
      context: context,
      builder: (dialogCtx) => CloneEntityReviewDialog(
        entityType: l.searchAndCloneCustomsApprovalDialogTitle,
        sourceCode: sourceItem.approvalCode,
        sourceTitle: '$docType - ${sourceItem.documentReferenceNo ?? "REF"}',
        suggestedNewCode: suggestedCode,
        copiedFieldsSummary: isAr
            ? {
                context.l10n.idocADocumentType: docType,
                context.l10n.idocARefNumber:
                    sourceItem.documentReferenceNo != null ? '${sourceItem.documentReferenceNo}-COPY' : '—',
                context.l10n.idocAFile: sourceItem.importFileCode ?? '—',
              }
            : {
                'Document Type': docType,
                'Reference No':
                    sourceItem.documentReferenceNo != null ? '${sourceItem.documentReferenceNo}-COPY' : '—',
                'Import File': sourceItem.importFileCode ?? '—',
              },
        mandatorilyResetFields: isAr
            ? [
                l.customsApprovalClonedResetNotice,
                context.l10n.idocACloneNoteCommercial,
                context.l10n.idocACloneNoteBrokerStatus,
                context.l10n.idocACloneNoteOverall,
                context.l10n.idocACloneNoteSignatures,
              ]
            : [
                l.customsApprovalClonedResetNotice,
                'Commercial Approval Status: Reset to Pending',
                'Customs Broker Approval Status: Reset to Pending',
                'Overall Status: Reset to Draft',
                'Reviewer signatures and notes fully cleared for independent review',
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
          onCloned();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l.cloneCustomsApprovalSuccess),
                backgroundColor: AppTheme.emerald,
              ),
            );
          }
        },
      ),
    );
  }
}
