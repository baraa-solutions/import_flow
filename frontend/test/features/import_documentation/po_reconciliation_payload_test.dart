import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/import_documentation/models/import_documentation_model.dart';
import 'package:frontend/features/import_documentation/utils/po_reconciliation_payload_builder.dart';

void main() {
  group('POReconciliationPayloadBuilder Tests', () {
    final invItem1 = POReconciliationItemModel(
      poItemId: 101,
      packingItemId: null,
      itemCode: 'ITEM-01',
      description: 'First item description',
      unitPrice: 10.0,
      initialQuantity: 100,
      finalQuantity: 95,
      finalGrossWeightKg: 50.0,
      finalNetWeightKg: 45.0,
      finalCbm: 1.5,
    );

    final invItem2 = POReconciliationItemModel(
      poItemId: 102,
      packingItemId: null,
      itemCode: 'ITEM-02',
      description: 'Second item description',
      unitPrice: 20.0,
      initialQuantity: 50,
      finalQuantity: 50,
      finalGrossWeightKg: 30.0,
      finalNetWeightKg: 28.0,
      finalCbm: 0.8,
    );

    final packItem1 = POReconciliationItemModel(
      poItemId: 101,
      packingItemId: 501,
      itemCode: 'ITEM-01',
      description: 'First item packing row',
      packageType: 'Pallet',
      unitPrice: 10.0,
      initialQuantity: 100,
      finalQuantity: 95,
      initialPackagesCount: 2,
      finalPackagesCount: 2,
      finalGrossWeightKg: 52.0,
      finalNetWeightKg: 45.0,
      finalCbm: 1.6,
    );

    test('Test 1: With no packing list, each po_item_id appears exactly once in payload', () {
      final payload = POReconciliationPayloadBuilder.buildPayload(
        importFileId: 10,
        finalInvoiceNumber: 'INV-2026-001',
        finalPackingListNumber: 'PL-2026-001',
        invoiceItems: [invItem1, invItem2],
        packingItems: [],
      );

      expect(payload['import_file_id'], 10);
      expect(payload['final_invoice_number'], 'INV-2026-001');
      expect(payload['final_packing_list_number'], 'PL-2026-001');

      final items = payload['items'] as List<dynamic>;
      expect(items.length, 2);

      // Verify each po_item_id appears exactly once
      final poItemIds = items.map((i) => i['po_item_id']).toList();
      expect(poItemIds, [101, 102]);
      expect(poItemIds.toSet().length, 2);

      // All items are line items without packing_item_id
      for (final item in items) {
        expect(item['packing_item_id'], isNull);
      }
    });

    test('Test 2: Packing items without packingItemId are excluded from payload to prevent duplicate po lines', () {
      // Duplicate of invItem1 mistakenly placed in packingItems (legacy behavior)
      final legacyCopiedPackingItem = POReconciliationItemModel(
        poItemId: 101,
        packingItemId: null,
        itemCode: 'ITEM-01',
        description: 'First item copied into packing list',
        unitPrice: 10.0,
        initialQuantity: 100,
        finalQuantity: 95,
        finalGrossWeightKg: 50.0,
        finalNetWeightKg: 45.0,
        finalCbm: 1.5,
      );

      final payload = POReconciliationPayloadBuilder.buildPayload(
        importFileId: 10,
        finalInvoiceNumber: 'INV-2026-001',
        finalPackingListNumber: 'PL-2026-001',
        invoiceItems: [invItem1, invItem2],
        packingItems: [legacyCopiedPackingItem],
      );

      final items = payload['items'] as List<dynamic>;
      expect(items.length, 2);

      final poItemIds = items.map((i) => i['po_item_id']).toList();
      expect(poItemIds, [101, 102]);
      expect(poItemIds.toSet().length, 2, reason: 'Duplicate po_item_id must be completely prevented');
    });

    test('Test 3: Real packing items (with packingItemId) are included alongside line items', () {
      final payload = POReconciliationPayloadBuilder.buildPayload(
        importFileId: 10,
        finalInvoiceNumber: 'INV-2026-001',
        finalPackingListNumber: 'PL-2026-001',
        invoiceItems: [invItem1, invItem2],
        packingItems: [packItem1],
      );

      final items = payload['items'] as List<dynamic>;
      expect(items.length, 3);

      final lineItems = items.where((i) => i['packing_item_id'] == null).toList();
      final packingItems = items.where((i) => i['packing_item_id'] != null).toList();

      expect(lineItems.length, 2);
      expect(packingItems.length, 1);
      expect(packingItems.first['packing_item_id'], 501);
      expect(packingItems.first['po_item_id'], 101);
    });

    test('Test 4: POReconciliationResultModel deserializes total_final_amount_by_currency correctly', () {
      final json = <String, dynamic>{
        'status': 'success',
        'message': 'Reconciled successfully',
        'import_file_id': 10,
        'final_invoice_number': 'INV-2026-001',
        'final_packing_list_number': 'PL-2026-001',
        'total_items_count': 2,
        'total_net_weight_kg': 73.0,
        'total_gross_weight_kg': 80.0,
        'total_cbm': 2.3,
        'total_final_amount': 1950.0,
        'total_final_amount_by_currency': {
          'USD': 950.0,
          'EUR': 1000.0,
        },
        'items': [],
      };

      final result = POReconciliationResultModel.fromJson(json);
      expect(result.totalFinalAmount, 1950.0);
      expect(result.totalFinalAmountByCurrency, isNotNull);
      expect(result.totalFinalAmountByCurrency!['USD'], 950.0);
      expect(result.totalFinalAmountByCurrency!['EUR'], 1000.0);
    });
  });
}
