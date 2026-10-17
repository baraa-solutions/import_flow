import '../models/import_documentation_model.dart';

/// Helper for constructing PO reconciliation final adjustment payloads.
/// Enforces the requirement (BE03-T01) that line items and packing items are strictly
/// separated, and each PO line appears exactly once in the adjustment payload.
class POReconciliationPayloadBuilder {
  /// Builds the submission items list for POST /api/v1/import-documentation/po-reconciliation.
  ///
  /// CRITICAL (BE03-T01):
  /// - Line items come from [invoiceItems] (where packingItemId is null).
  /// - Packing items come only from [packingItems] with a non-null [packingItemId].
  /// - Items without [packingItemId] are never duplicated from the packing items list.
  static List<POReconciliationItemModel> buildSubmissionItems({
    required List<POReconciliationItemModel> invoiceItems,
    required List<POReconciliationItemModel> packingItems,
  }) {
    final validPackingItems = packingItems.where((p) => p.packingItemId != null).toList();
    return [
      ...invoiceItems,
      ...validPackingItems,
    ];
  }

  /// Builds the complete request payload dictionary.
  static Map<String, dynamic> buildPayload({
    required int importFileId,
    required String finalInvoiceNumber,
    required String finalPackingListNumber,
    required List<POReconciliationItemModel> invoiceItems,
    required List<POReconciliationItemModel> packingItems,
  }) {
    final combined = buildSubmissionItems(
      invoiceItems: invoiceItems,
      packingItems: packingItems,
    );
    return {
      'import_file_id': importFileId,
      'final_invoice_number': finalInvoiceNumber.trim(),
      'final_packing_list_number': finalPackingListNumber.trim(),
      'items': combined.map((i) => i.toJson()).toList(),
    };
  }
}
