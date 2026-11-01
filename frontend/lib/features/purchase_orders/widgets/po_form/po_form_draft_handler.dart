import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../models/purchase_order_model.dart';
import '../../services/po_draft_manager.dart';
import '../../utils/po_payment_terms.dart';
import '../po_form_dialog.dart';

/// Helper to handle PO autosave draft creation, inspection, and restoring.
class PoFormDraftHandler {
  static Future<void> performAutosave({
    required int? poId,
    required Map<String, dynamic> draftData,
    required ValueChanged<DateTime> onDraftSaved,
  }) async {
    try {
      await PODraftManager.saveDraft(
        poId: poId,
        draftData: draftData,
      );
      onDraftSaved(DateTime.now());
    } catch (_) {}
  }

  static Map<String, dynamic> collectDraftData({required POFormDialogState dialog}) => {
        'po_reference': dialog.poReferenceCtrl.text,
        'pi_number': dialog.piCtrl.text,
        'exchange_rate': dialog.rateCtrl.text,
        'notes': dialog.notesCtrl.text,
        'order_date': dialog.selectedOrderDate.toIso8601String(),
        'import_file_id': dialog.selectedImportFileId,
        'project_id': dialog.selectedProjectId,
        'company_id': dialog.selectedCompanyId,
        'supplier_id': dialog.selectedSupplierId,
        'incoterm_id': dialog.selectedIncotermId,
        'currency_id': dialog.selectedCurrencyId,
        'country_of_origin': dialog.selectedCountryOfOrigin,
        'status': dialog.selectedStatus,
        'payment_terms': dialog.selectedPaymentTerms,
        'items': dialog.dialogItems.map((i) => i.toJson()).toList(),
        'packing_items': dialog.dialogPackingItems.map((p) => p.toJson()).toList(),
      };

  static void applyDraft({
    required POFormDialogState dialog,
    required Map<String, dynamic> draft,
  }) {
    if (draft['po_reference'] != null) dialog.poReferenceCtrl.text = draft['po_reference'];
    if (draft['pi_number'] != null) dialog.piCtrl.text = draft['pi_number'];
    if (draft['exchange_rate'] != null) dialog.rateCtrl.text = draft['exchange_rate'].toString();
    if (draft['notes'] != null) dialog.notesCtrl.text = draft['notes'];
    if (draft['order_date'] != null) dialog.selectedOrderDate = DateTime.tryParse(draft['order_date']) ?? dialog.selectedOrderDate;
    if (draft['import_file_id'] != null) dialog.selectedImportFileId = draft['import_file_id'];
    if (draft['project_id'] != null) dialog.selectedProjectId = draft['project_id'];
    if (draft['company_id'] != null) dialog.selectedCompanyId = draft['company_id'];
    if (draft['supplier_id'] != null) dialog.selectedSupplierId = draft['supplier_id'];
    if (draft['incoterm_id'] != null) dialog.selectedIncotermId = draft['incoterm_id'];
    if (draft['currency_id'] != null) dialog.selectedCurrencyId = draft['currency_id'];
    if (draft['country_of_origin'] != null) dialog.selectedCountryOfOrigin = draft['country_of_origin'];
    if (draft['status'] != null) dialog.selectedStatus = DomainEnums.legacyToCode(DomainEnumType.poStatus, draft['status'].toString()) ?? dialog.selectedStatus;
    if (draft['payment_terms'] != null) dialog.selectedPaymentTerms = PoPaymentTerms.fromText(draft['payment_terms'].toString()) ?? draft['payment_terms'].toString();
    if (draft['items'] is List) dialog.dialogItems = (draft['items'] as List).map((i) => POLineItemModel.fromJson(Map<String, dynamic>.from(i))).toList();
    if (draft['packing_items'] is List) dialog.dialogPackingItems = (draft['packing_items'] as List).map((p) => PackingListItemModel.fromJson(Map<String, dynamic>.from(p))).toList();
  }

  static Future<Map<String, dynamic>?> checkAndPromptDraft({
    required BuildContext context,
    required int? poId,
  }) async {
    final draft = await PODraftManager.loadDraft(poId);
    if (draft == null || !context.mounted) return null;
    final savedAt = draft['saved_at']?.toString() ?? '';

    final restore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.history_edu_rounded, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Text(context.l10n.poRestoreUnsavedDraft),
            ],
          ),
          content: Text(context.l10n.poAnAutosavedDraftExistsForThis(savedAt)),
          actions: [
            AppButton(
              label: context.l10n.poDiscardDraft,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () {
                PODraftManager.clearDraft(poId);
                Navigator.of(ctx).pop(false);
              },
            ),
            AppButton(
              label: context.l10n.poRestoreDraft,
              variant: AppButtonVariant.success,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );

    if (restore == true) {
      return draft;
    }
    return null;
  }
}
