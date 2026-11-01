import '../../models/customs_consultation_model.dart';
import 'price_list_match_helper.dart';

/// Helper methods for initializing items, matching brokers, and constructing API payloads for price lists.
class PriceListPayloadHelper {
  /// Builds the initial items list from existing price list items or master catalog.
  static List<Map<String, dynamic>> initializeItems({
    required BrokerPriceListModel? existingPriceList,
    required List<ClearanceExpenseTypeModel> catalog,
    Map<String, dynamic>? initialExtractedData,
  }) {
    final List<Map<String, dynamic>> itemsState = [];

    if (existingPriceList != null) {
      for (final itm in existingPriceList.items) {
        itemsState.add({
          'item_id': itm.itemId,
          'expense_type_id': itm.expenseTypeId,
          'code': itm.code,
          'is_uncoded': itm.isUncoded,
          'price_type': itm.priceType,
          'expense_name': itm.expenseName,
          'category': itm.category,
          'unit_type': itm.unitType,
          'standard_price': itm.standardPrice,
          'currency': itm.currency,
          'min_price': itm.minPrice,
          'max_price': itm.maxPrice,
          'notes': itm.notes ?? '',
          'is_active': itm.isActive,
          'confidence': itm.confidence,
          'raw_extracted_text': itm.rawExtractedText,
        });
      }
    } else {
      for (final exp in catalog) {
        itemsState.add({
          'expense_type_id': exp.expenseId,
          'code': exp.expenseCode,
          'is_uncoded': false,
          'price_type': 'fixed',
          'expense_name': exp.nameAr,
          'category': exp.category,
          'unit_type': exp.defaultUnit,
          'standard_price': 0.0,
          'currency': exp.defaultCurrency,
          'min_price': null,
          'max_price': null,
          'notes': '',
          'is_active': true,
        });
      }

      if (initialExtractedData != null) {
        applyExtractedExpenses(initialExtractedData, itemsState, isInitial: true);
      } else {
        for (var itm in itemsState) {
          final name = itm['expense_name'] as String;
          for (var entry in standardRatesMap.entries) {
            if (name.contains(entry.key) || entry.key.contains(name)) {
              itm['standard_price'] = entry.value;
              break;
            }
          }
        }
      }
    }

    for (var itm in itemsState) {
      if (itm['price_type'] == null) {
        final stdP = (itm['standard_price'] as num?)?.toDouble() ?? 0.0;
        final minP = (itm['min_price'] as num?)?.toDouble();
        final maxP = (itm['max_price'] as num?)?.toDouble();
        if (minP != null || maxP != null) {
          itm['price_type'] = 'range';
        } else if (stdP == 0.0) {
          itm['price_type'] = 'negotiable';
        } else {
          itm['price_type'] = 'fixed';
        }
      }
    }

    return itemsState;
  }

  /// Attempts to fuzzy match broker from extracted document text.
  static int? matchBroker(String? brokerName, List<dynamic> brokersList) {
    final bName = (brokerName ?? '').toLowerCase().trim();
    if (bName.isEmpty) return null;
    for (final b in brokersList) {
      final pName = (b.partnerName as String).toLowerCase();
      if (bName.contains(pName) ||
          pName.contains(bName) ||
          (bName.contains('acc') && pName.contains('acc')) ||
          (bName.contains('اسكندرية') && pName.contains('اسكندرية')) ||
          (bName.contains('أهرام') && pName.contains('أهرام')) ||
          (bName.contains('اهرام') && pName.contains('اهرام'))) {
        return b.providerId as int?;
      }
    }
    return null;
  }

  /// Fills benchmark standard rates for items.
  static void fillStandardRates(List<Map<String, dynamic>> itemsState) {
    for (var itm in itemsState) {
      final name = itm['expense_name'] as String;
      for (var entry in standardRatesMap.entries) {
        if (name.contains(entry.key) || entry.key.contains(name)) {
          itm['standard_price'] = entry.value;
          itm['price_type'] = 'fixed';
          break;
        }
      }
    }
  }

  /// Clears prices for all items setting them to negotiable.
  static void zeroOutRates(List<Map<String, dynamic>> itemsState) {
    for (var itm in itemsState) {
      itm['standard_price'] = 0.0;
      itm['min_price'] = null;
      itm['max_price'] = null;
      itm['price_type'] = 'negotiable';
    }
  }

  /// Builds the serialized payload for API create/update calls.
  static Map<String, dynamic> buildPayload({
    required String title,
    required int selectedBroker,
    required String brokerName,
    String? portName,
    required String effectiveFrom,
    required int version,
    required bool isActive,
    String? notes,
    required List<Map<String, dynamic>> itemsState,
    required bool isEditing,
  }) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    double? parseNullableDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    final List<Map<String, dynamic>> itemsPayload = [];
    for (var itm in itemsState) {
      final expName = (itm['expense_name']?.toString() ?? '').trim();
      if (expName.isEmpty) continue;

      var cat = (itm['category']?.toString() ?? 'Other Fees').trim().split('(').first.trim();
      if (cat.isEmpty) cat = 'Other Fees';

      var unit = (itm['unit_type']?.toString() ?? 'Per Shipment').trim().split('(').first.trim();
      if (unit.isEmpty) unit = 'Per Shipment';

      final stdPrice = parseDouble(itm['standard_price']);

      itemsPayload.add({
        if (isEditing && itm['item_id'] != null) 'item_id': itm['item_id'],
        'expense_type_id': itm['expense_type_id'],
        if (itm['code'] != null && itm['code'].toString().isNotEmpty) 'code': itm['code'].toString(),
        'is_uncoded': itm['is_uncoded'] == true,
        'price_type': itm['price_type']?.toString() ?? (stdPrice == 0 ? 'negotiable' : 'fixed'),
        'expense_name': expName,
        'category': cat,
        'unit_type': unit,
        'standard_price': stdPrice,
        'currency': itm['currency']?.toString() ?? 'EGP',
        'min_price': parseNullableDouble(itm['min_price']),
        'max_price': parseNullableDouble(itm['max_price']),
        'notes': itm['notes']?.toString() ?? '',
        'is_active': itm['is_active'] ?? true,
        if (itm['confidence'] != null) 'confidence': parseNullableDouble(itm['confidence']),
        if (itm['raw_extracted_text'] != null && itm['raw_extracted_text'].toString().isNotEmpty)
          'raw_extracted_text': itm['raw_extracted_text'].toString(),
      });
    }

    return {
      'title': title,
      'broker_id': selectedBroker,
      'broker_name': brokerName,
      'port_name': portName?.trim().isNotEmpty == true ? portName!.trim() : null,
      'effective_from': effectiveFrom,
      'version': isEditing ? version : 1,
      'is_active': isActive,
      'notes': notes?.trim().isNotEmpty == true ? notes!.trim() : null,
      'items': itemsPayload,
    };
  }
}
