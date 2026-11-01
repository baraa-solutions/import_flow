import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/clone_entity_review_dialog.dart';
import '../../../../core/widgets/table_row_clone_helper.dart';
import '../../../purchase_orders/utils/po_packing_matcher.dart';
import '../../models/import_documentation_model.dart';
import '../../models/po_reconciliation_session_model.dart';
import '../../providers/import_documentation_provider.dart';
import '../search_and_clone_po_reconciliation_dialog.dart';

/// Helper handling session search, clone confirmation dialog,
/// and line item cloning logic for PO Reconciliation.
class PoReconciliationCloneHelper {
  static void openSearchAndCloneDialog({
    required BuildContext context,
    required WidgetRef ref,
    required ValueChanged<POReconciliationSessionModel> onSelectSession,
  }) {
    final sessions = ref.read(poReconciliationSessionsProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      builder: (dialogCtx) => SearchAndClonePoReconciliationDialog(
        sessions: sessions,
        onSelectSession: onSelectSession,
      ),
    );
  }

  static void showCloneReviewDialog({
    required BuildContext context,
    required POReconciliationSessionModel sourceSession,
    required void Function(POReconciliationSessionModel session, {required String newCode, bool copyLineItems}) onConfirm,
  }) {
    final l = context.l10n;
    final suggestedCode = 'REC-2026-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    showDialog(
      context: context,
      builder: (dialogCtx) => CloneEntityReviewDialog(
        entityType: l.searchAndClonePoReconDialogTitle,
        sourceCode: sourceSession.sessionCode,
        sourceTitle: '${sourceSession.finalInvoiceNumber ?? "INV"} / ${sourceSession.finalPackingListNumber ?? "PL"}',
        suggestedNewCode: suggestedCode,
        copiedFieldsSummary: {
          l.idocAInvoiceNumber: sourceSession.finalInvoiceNumber ?? '—',
          l.idocAPackingListNumber: sourceSession.finalPackingListNumber ?? '—',
          l.idocATotalValue: '${sourceSession.totalInvoiceAmount.toStringAsFixed(2)} ${sourceSession.currency}',
          l.idocATotalPackages: '${sourceSession.totalPackages.toStringAsFixed(0)} ${l.poRecPackagesUnit}',
          l.idocATotalWeight: '${PoPackingMatcher.formatWeight(sourceSession.totalGrossWeightKg)} ${l.poRecKgUnit}',
          l.idocATotalVolume: '${sourceSession.totalCbm.toStringAsFixed(2)} ${l.poRecCbmUnit}',
        },
        mandatorilyResetFields: [
          l.poReconClonedResetNotice,
          l.idocADraft3,
          l.idocACloneNoteSignature,
        ],
        allowCopyLineItems: true,
        allowCopyAttachments: false,
        onConfirm: ({
          required String newCode,
          required String newTitle,
          required bool copyLineItems,
          required bool copyAttachments,
          String? notes,
        }) async {
          onConfirm(sourceSession, newCode: newCode, copyLineItems: copyLineItems);
        },
      ),
    );
  }

  static List<POReconciliationItemModel> cloneItemInList(
    List<POReconciliationItemModel> list,
    POReconciliationItemModel item,
  ) {
    final idx = list.indexOf(item);
    final cloned = item.copyWith(
      itemCode: '${item.itemCode}${TableRowCloneHelper.copyCodeSuffix}',
      description: '${item.description}${TableRowCloneHelper.copySuffix}',
    );
    final copy = List<POReconciliationItemModel>.from(list);
    if (idx >= 0) {
      copy.insert(idx + 1, cloned);
    } else {
      copy.add(cloned);
    }
    return copy;
  }

  static POReconciliationItemModel updateItemQty(POReconciliationItemModel cur, double parsed) {
    final qPct = cur.initialQuantity > 0 ? ((parsed - cur.initialQuantity) / cur.initialQuantity) * 100.0 : 0.0;
    final curP = cur.finalUnitPrice > 0 ? cur.finalUnitPrice : cur.unitPrice;
    final pPct = cur.initialUnitPrice > 0 ? ((curP - cur.initialUnitPrice) / cur.initialUnitPrice) * 100.0 : 0.0;
    return cur.copyWith(finalQuantity: parsed, variancePercentage: qPct, priceVariancePercentage: pPct);
  }

  static POReconciliationItemModel updateItemPrice(POReconciliationItemModel cur, double parsed) {
    final qPct = cur.initialQuantity > 0 ? ((cur.finalQuantity - cur.initialQuantity) / cur.initialQuantity) * 100.0 : 0.0;
    final pPct = cur.initialUnitPrice > 0 ? ((parsed - cur.initialUnitPrice) / cur.initialUnitPrice) * 100.0 : 0.0;
    return cur.copyWith(finalUnitPrice: parsed, unitPrice: parsed, variancePercentage: qPct, priceVariancePercentage: pPct);
  }
}
