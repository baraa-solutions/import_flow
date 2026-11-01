import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/change_diff_dialog.dart';
import '../../../../core/widgets/concurrency_conflict_dialog.dart';
import '../../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../models/purchase_order_model.dart';
import '../../providers/purchase_orders_provider.dart';
import '../../services/po_draft_manager.dart';
import '../../utils/po_row_list.dart';
import '../po_reconciliation_warning_dialog.dart';

/// Handles validation, change diff reviews, concurrency conflicts, and submitting POs.
class PoFormSubmitter {
  static Future<bool> submit({
    required BuildContext context,
    required WidgetRef ref,
    required GlobalKey<FormState> formKey,
    required PurchaseOrderModel? existingPo,
    required String poReference,
    required String piNumber,
    required String? countryOfOrigin,
    required int? importFileId,
    required int? projectId,
    required int? companyId,
    required int? supplierId,
    required int? incotermId,
    required int? currencyId,
    required DateTime orderDate,
    required double rate,
    required String? paymentTerms,
    required String status,
    required String rawNotes,
    required List<PalletPlanItemModel> palletPlanItems,
    required bool isDirectVolumeMode,
    required PoRowList<POLineItemModel> items,
    required PoRowList<PackingListItemModel> packingItems,
    required ValueChanged<bool> onSubmittingChanged,
    required VoidCallback onSuccess,
  }) async {
    final l = context.l10n;
    final isAr = l.isArabic;

    if (!formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          isAr ? 'الرجاء استكمال الحقول الإلزامية المطلوبة' : 'Please fill all required fields',
          severity: AppSeverity.danger,
        ),
      );
      return false;
    }

    if (projectId == null ||
        companyId == null ||
        supplierId == null ||
        incotermId == null ||
        currencyId == null ||
        paymentTerms == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          isAr
              ? 'الرجاء التأكد من اختيار المشروع والشركة والمورد وشروط الشحن والعملة وطريقة الدفع'
              : 'Please select project, company, supplier, incoterm, currency, and payment terms',
          severity: AppSeverity.danger,
        ),
      );
      return false;
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          isAr ? 'الرجاء إضافة بند استيرادي واحد على الأقل' : 'Please add at least one line item',
          severity: AppSeverity.danger,
        ),
      );
      return false;
    }

    final tariffs = ref.read(customsTariffProvider).value ?? [];
    final reconciliation = evaluatePOReconciliation(
      invoiceItems: items,
      packingItems: packingItems,
      tariffs: tariffs,
    );

    String? discrepancyJustification;
    if (reconciliation.hasDiscrepancy) {
      discrepancyJustification = await showDialog<String?>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => POReconciliationWarningDialog(report: reconciliation),
      );
      if (discrepancyJustification == null || !context.mounted) return false;
    }

    onSubmittingChanged(true);
    String? effectiveNotes = rawNotes.trim().isEmpty ? null : rawNotes.trim();
    if (discrepancyJustification != null && discrepancyJustification.isNotEmpty) {
      final header = '[مبررات اختلاف الفاتورة والباكينج]: $discrepancyJustification';
      effectiveNotes = effectiveNotes == null ? header : '$effectiveNotes\n$header';
    }

    final messenger = ScaffoldMessenger.of(context);

    if (existingPo == null) {
      // Create New PO
      final newPO = PurchaseOrderModel(
        poNumber: '',
        poReference: poReference.trim().isEmpty ? null : poReference.trim(),
        proformaInvoiceNumber: piNumber.trim().isEmpty ? null : piNumber.trim(),
        countryOfOrigin: countryOfOrigin,
        importFileId: importFileId,
        projectId: projectId,
        companyId: companyId,
        supplierId: supplierId,
        incotermId: incotermId,
        currencyId: currencyId,
        orderDate: orderDate,
        exchangeRate: rate,
        paymentTerms: paymentTerms,
        palletPlanItems: isDirectVolumeMode ? palletPlanItems : <PalletPlanItemModel>[],
        status: status,
        notes: effectiveNotes,
        items: items,
        packingListItems: packingItems,
      );

      final createError = await ref.read(purchaseOrdersProvider.notifier).createPurchaseOrder(newPO);
      if (!context.mounted) return false;

      if (createError != null) {
        onSubmittingChanged(false);
        messenger.showSnackBar(
          AppTheme.snackBar(
            context,
            '${l.poCreateErrorPrefix}:\n${ApiErrorText.of(l, createError)}',
            severity: AppSeverity.danger,
          ),
        );
        return false;
      } else {
        ref.invalidate(purchaseOrdersProvider);
        await PODraftManager.clearDraft(null);
        if (!context.mounted) return false;
        messenger.showSnackBar(
          AppTheme.snackBar(
            context,
            isAr ? 'تم حفظ أمر الشراء بنجاح' : 'Purchase order saved successfully',
            severity: AppSeverity.success,
          ),
        );
        onSuccess();
        return true;
      }
    } else {
      // Edit Existing PO with Diff Review
      final List<FieldChangeItem> changes = [];
      if (FieldChangeItem.isDifferent(existingPo.poReference, poReference.trim())) {
        changes.add(FieldChangeItem(
          section: isAr ? 'الترويسة' : 'Header',
          fieldName: isAr ? 'مرجع أمر الشراء' : 'PO Reference',
          oldValue: existingPo.poReference,
          newValue: poReference.trim(),
        ));
      }
      if (FieldChangeItem.isDifferent(existingPo.proformaInvoiceNumber, piNumber.trim())) {
        changes.add(FieldChangeItem(
          section: isAr ? 'الترويسة' : 'Header',
          fieldName: isAr ? 'رقم الفاتورة المبدئية' : 'PI #',
          oldValue: existingPo.proformaInvoiceNumber,
          newValue: piNumber.trim(),
        ));
      }

      if (changes.isNotEmpty) {
        final confirmed = await showChangeDiffConfirmationDialog(
          context,
          title: isAr ? 'مراجعة وتأكيد التعديلات' : 'Confirm PO Edits',
          itemReference: existingPo.displayName,
          changes: changes,
        );
        if (!confirmed) {
          onSubmittingChanged(false);
          return false;
        }
      }

      final updateData = {
        'po_reference': poReference.trim().isEmpty ? null : poReference.trim(),
        'proforma_invoice_number': piNumber.trim().isEmpty ? null : piNumber.trim(),
        'country_of_origin': countryOfOrigin,
        'import_file_id': importFileId,
        'project_id': projectId,
        'company_id': companyId,
        'supplier_id': supplierId,
        'incoterm_id': incotermId,
        'currency_id': currencyId,
        'order_date': orderDate.toIso8601String(),
        'exchange_rate': rate,
        'payment_terms': paymentTerms,
        'pallet_plan': isDirectVolumeMode ? palletPlanItems.map((p) => p.toJson()).toList() : <Map<String, dynamic>>[],
        'status': status,
        'notes': effectiveNotes,
        'version': existingPo.version,
        'items': items.map((i) => i.toJson()).toList(),
        'packing_list_items': packingItems.map((p) => p.toJson()).toList(),
      };

      final result = await ref.read(purchaseOrdersProvider.notifier).updatePurchaseOrder(existingPo.poId!, updateData);
      if (!context.mounted) return false;

      if (result.isConflict) {
        onSubmittingChanged(false);
        final conflict = result.conflictDetails ?? {};
        final res = await ConcurrencyConflictDialog.show(
          context,
          entityName: conflict['entity'] as String? ?? 'PurchaseOrder',
          recordId: conflict['record_id'] ?? existingPo.poId!,
          currentVersion: (conflict['current_version'] as num?)?.toInt() ?? (existingPo.version + 1),
          submittedVersion: (conflict['submitted_version'] as num?)?.toInt() ?? existingPo.version,
          updatedAt: conflict['updated_at'] as String?,
          updatedBy: conflict['updated_by'] as String?,
          serverMessage: conflict['message'] as String?,
          currentDraftData: updateData,
        );
        if (res == ConcurrencyResolution.discardAndReload && context.mounted) {
          await ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
          onSuccess();
        }
        return false;
      }

      if (!result.isSuccess) {
        onSubmittingChanged(false);
        messenger.showSnackBar(
          AppTheme.snackBar(
            context,
            '${l.poUpdateErrorPrefix}:\n${ApiErrorText.of(l, result.error)}',
            severity: AppSeverity.danger,
          ),
        );
        return false;
      } else {
        ref.invalidate(purchaseOrdersProvider);
        await PODraftManager.clearDraft(existingPo.poId);
        if (!context.mounted) return false;
        messenger.showSnackBar(
          AppTheme.snackBar(
            context,
            isAr ? 'تم حفظ التعديلات بنجاح' : 'Changes saved successfully',
            severity: AppSeverity.success,
          ),
        );
        onSuccess();
        return true;
      }
    }
  }
}
