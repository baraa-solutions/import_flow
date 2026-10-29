import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/master_items/models/item_price_history_model.dart';
import 'package:frontend/features/master_items/models/item_price_trends_model.dart';
import 'package:frontend/features/master_items/models/item_supplier_catalog_model.dart';
import 'package:frontend/features/master_items/models/master_item_model.dart';
import 'package:frontend/features/master_items/providers/master_items_provider.dart';
import 'package:frontend/features/master_items/repositories/master_items_repository.dart';

void main() {
  group('MasterItemModel JSON Serialization', () {
    test('Correctly deserializes from backend JSON response', () {
      final json = {
        'item_id': 101,
        'item_code': 'RAW-ALUM-001',
        'description_ar': 'سبائك ألومنيوم 6063',
        'description_en': 'Aluminum Ingot 6063',
        'tariff_id': 12,
        'hs_code': '7601.10.00',
        'default_uom': 'KG',
        'default_pkg_type': 'Bundle',
        'cbm_per_unit': 0.05,
        'gross_weight_kg': 25.0,
        'net_weight_kg': 24.8,
        'last_customs_duty_pct': 5.0,
        'last_vat_pct': 14.0,
        'last_schedule_tax_pct': 0.0,
        'product_category': 'Raw Materials',
        'product_subcategory': 'Metals',
        'notes': 'Grade A purity',
        'is_active': true,
        'created_at': '2026-10-28T10:00:00Z',
        'created_by': 'admin',
        'updated_at': '2026-10-28T12:00:00Z',
        'updated_by': 'editor',
      };

      final model = MasterItemModel.fromJson(json);

      expect(model.itemId, 101);
      expect(model.itemCode, 'RAW-ALUM-001');
      expect(model.descriptionAr, 'سبائك ألومنيوم 6063');
      expect(model.descriptionEn, 'Aluminum Ingot 6063');
      expect(model.tariffId, 12);
      expect(model.hsCode, '7601.10.00');
      expect(model.defaultUom, 'KG');
      expect(model.cbmPerUnit, 0.05);
      expect(model.grossWeightKg, 25.0);
      expect(model.lastCustomsDutyPct, 5.0);
      expect(model.lastVatPct, 14.0);
      expect(model.isActive, isTrue);
      expect(model.createdBy, 'admin');

      final serialized = model.toJson();
      expect(serialized['item_code'], 'RAW-ALUM-001');
      expect(serialized['tariff_id'], 12);
    });

    test('MasterItemListModel parses total and item elements', () {
      final listJson = {
        'total': 2,
        'items': [
          {
            'item_id': 1,
            'item_code': 'ITEM-01',
            'description_ar': 'صنف تجريبي 1',
            'is_active': true,
          },
          {
            'item_id': 2,
            'item_code': 'ITEM-02',
            'description_ar': 'صنف تجريبي 2',
            'is_active': true,
          },
        ],
      };

      final listModel = MasterItemListModel.fromJson(listJson);
      expect(listModel.total, 2);
      expect(listModel.items.length, 2);
      expect(listModel.items[0].itemCode, 'ITEM-01');
      expect(listModel.items[1].itemCode, 'ITEM-02');
    });
  });

  group('ItemSupplierCatalogModel JSON Serialization', () {
    test('Parses supplier catalog mapping accurately', () {
      final json = {
        'catalog_id': 45,
        'item_id': 101,
        'item_code': 'RAW-ALUM-001',
        'supplier_id': 8,
        'supplier_name': 'Shanghai Metal Corp',
        'supplier_item_code': 'SH-6063-X',
        'supplier_description': 'Prime aluminum billets',
        'last_confirmed_price': 2450.50,
        'last_confirmed_currency': 'USD',
        'last_confirmed_date': '2026-10-15',
        'last_po_id': 88,
        'min_order_qty': 1000.0,
        'lead_time_days': 25,
        'preferred_incoterm': 'FOB',
        'is_preferred_supplier': true,
        'notes': 'Contract discount applicable',
        'is_active': true,
        'created_at': '2026-10-10T08:00:00Z',
      };

      final catalog = ItemSupplierCatalogModel.fromJson(json);

      expect(catalog.catalogId, 45);
      expect(catalog.itemId, 101);
      expect(catalog.supplierName, 'Shanghai Metal Corp');
      expect(catalog.supplierItemCode, 'SH-6063-X');
      expect(catalog.lastConfirmedPrice, 2450.50);
      expect(catalog.lastConfirmedCurrency, 'USD');
      expect(catalog.isPreferredSupplier, isTrue);
      expect(catalog.leadTimeDays, 25);
    });
  });

  group('ItemPriceHistoryModel & Trends JSON Serialization', () {
    test('Parses history and trends calculation models', () {
      final historyJson = {
        'history_id': 301,
        'item_id': 101,
        'supplier_id': 8,
        'supplier_name': 'Shanghai Metal Corp',
        'po_id': 88,
        'po_number': 'PO-2026-088',
        'import_file_id': 14,
        'import_file_code': 'FILE-2026-014',
        'unit_price_fx': 2400.0,
        'currency': 'USD',
        'exchange_rate': 48.50,
        'unit_price_egp': 116400.0,
        'landed_cost_egp': 135000.0,
        'landed_cost_markup': 15.98,
        'quantity': 500.0,
        'po_date': '2026-09-01',
        'recorded_at': '2026-09-01T14:30:00Z',
      };

      final historyModel = ItemPriceHistoryModel.fromJson(historyJson);
      expect(historyModel.historyId, 301);
      expect(historyModel.unitPriceFx, 2400.0);
      expect(historyModel.unitPriceEgp, 116400.0);
      expect(historyModel.landedCostMarkup, 15.98);

      final trendsJson = {
        'item_id': 101,
        'item_code': 'RAW-ALUM-001',
        'description_ar': 'سبائك ألومنيوم 6063',
        'total_purchases_count': 1,
        'average_unit_price_fx': 2400.0,
        'min_unit_price_fx': 2400.0,
        'max_unit_price_fx': 2400.0,
        'average_landed_cost_egp': 135000.0,
        'average_markup_percent': 15.98,
        'history': [historyJson],
      };

      final trendsModel = ItemPriceTrendsModel.fromJson(trendsJson);
      expect(trendsModel.itemId, 101);
      expect(trendsModel.totalPurchasesCount, 1);
      expect(trendsModel.averageUnitPriceFx, 2400.0);
      expect(trendsModel.history.length, 1);
      expect(trendsModel.history.first.poNumber, 'PO-2026-088');
    });
  });

  group('MasterItemsState & NetworkException tests', () {
    test('MasterItemsState copyWith and pagination helpers', () {
      const state = MasterItemsState(
        items: [],
        total: 150,
        searchQuery: 'Alum',
        skip: 0,
        limit: 50,
      );

      expect(state.hasMore, isTrue);

      final nextState = state.copyWith(skip: 50);
      expect(nextState.skip, 50);
      expect(nextState.searchQuery, 'Alum');
      expect(nextState.total, 150);
    });

    test('NetworkException produces readable string message', () {
      const ex = NetworkException(
        message: 'الصنف رقم 999 غير مسجل',
        statusCode: 404,
      );

      expect(ex.toString(), 'الصنف رقم 999 غير مسجل');
      expect(ex.statusCode, 404);
    });
  });
}
