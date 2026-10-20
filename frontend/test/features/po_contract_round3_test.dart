import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/localization/api_error_text.dart';
import 'package:frontend/core/utils/container_requirement_engine.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/localization/domain_enum_labels.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/cbm_calculator/models/cbm_calculator_model.dart';
import 'package:frontend/features/purchase_orders/models/po_system_message.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/purchase_orders/utils/po_row_id_matcher.dart';
import 'package:frontend/features/purchase_orders/widgets/po_message_snackbar.dart';

import '../helpers/localized_app.dart';

const AppLocalizations _en = AppLocalizationsEn();
const AppLocalizations _ar = AppLocalizationsAr();

Map<String, dynamic> _poJson({String status = 'APPROVED'}) => {
      'po_id': 5,
      'po_number': 'PO-5',
      'status': status,
      'created_by': 'amira',
      'updated_by': 'kamal',
      'items': [
        {'item_id': 11, 'description_ar': 'a', 'quantity': 2, 'unit_price': 3},
        {'item_id': 12, 'description_ar': 'b', 'quantity': 1, 'unit_price': 1},
      ],
      'packing_list_items': [
        {'packing_item_id': 21, 'hs_code': '8501', 'item_code': 'X', 'unit': 'mm', 'weight_unit': 'GRM'},
      ],
    };

class _Adapter implements HttpClientAdapter {
  final List<String> requests = [];
  Object? lastBody;
  Object? responseBody = <String, dynamic>{};

  int gets(String part) => requests.where((r) => r.startsWith('GET ') && r.contains(part)).length;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add('${options.method} ${options.path}');
    if (options.method != 'GET') lastBody = options.data;
    final isList = options.method == 'GET' && !options.path.contains('packing-list-report') && !options.path.contains('/balance');
    return ResponseBody.fromString(
      jsonEncode(isList ? <dynamic>[] : responseBody),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  _matcherTests();
  test('one shared air volumetric factor: 1 CBM = 167 kg in the engine and the CBM feature', () {
    expect(kAirVolumetricKgPerCbm, 167.0);
    // 1 CBM, 167 kg gross: heavy enough to be air-suggested only when gross >= 1 * factor.
    final heavy = ContainerRequirementEngine.recommendShipmentMode(totalCbm: 1, totalWeightKg: 167.0);
    final light = ContainerRequirementEngine.recommendShipmentMode(totalCbm: 1, totalWeightKg: 166.9);
    expect(heavy.isAirSuggested, isTrue);
    expect(light.isAirSuggested, isFalse);
    expect(heavy.reasonAr, contains('167.0 kg'));
  });

  group('PO model: item_id / packing_item_id round-trip', () {
    test('existing rows keep their ids through fromJson -> toJson', () {
      final po = PurchaseOrderModel.fromJson(_poJson());
      expect(po.items.map((i) => i.itemId), [11, 12]);
      expect(po.packingListItems.single.packingItemId, 21);
      final json = po.toJson();
      expect((json['items'] as List).map((i) => i['item_id']), [11, 12]);
      expect((json['packing_list_items'] as List).single['packing_item_id'], 21);
    });

    test('new rows omit the ids (null, not 0)', () {
      final item = POLineItemModel.fromJson({'description_ar': 'new', 'quantity': 1, 'unit_price': 1});
      expect(item.itemId, isNull);
      expect(item.toJson().containsKey('item_id'), isFalse);
      final packing = PackingListItemModel.fromJson({'hs_code': '8501', 'item_code': 'X'});
      expect(packing.packingItemId, isNull);
      expect(packing.toJson().containsKey('packing_item_id'), isFalse);
    });

    test('a duplicated row does not copy the id; an edited row keeps it', () {
      final po = PurchaseOrderModel.fromJson(_poJson());
      final dupItem = po.items.first.copyWith(clearId: true, itemCode: 'A-COPY');
      final dupPack = po.packingListItems.first.copyWith(clearId: true);
      expect(dupItem.itemId, isNull);
      expect(dupPack.packingItemId, isNull);
      expect(dupItem.toJson().containsKey('item_id'), isFalse);
      expect(po.items.first.copyWith(quantity: 9).itemId, 11);
      expect(po.packingListItems.first.copyWith(qtyPcs: 3).packingItemId, 21);
    });

    test('created_by / updated_by are parsed', () {
      final po = PurchaseOrderModel.fromJson(_poJson());
      expect(po.createdBy, 'amira');
      expect(po.updatedBy, 'kamal');
    });
  });

  group('Packing units', () {
    test('length unit is only mm / cm / m', () {
      expect(PackingListItemModel.lengthUnits, ['mm', 'cm', 'm']);
      expect(PackingListItemModel.normalizeLengthUnit('MM'), 'mm');
      expect(PackingListItemModel.normalizeLengthUnit('PCS'), 'cm');
      expect(PackingListItemModel.normalizeLengthUnit(null), 'cm');
    });

    test('weight unit is KGM / GRM / STN / SET; legacy spellings are mapped', () {
      expect(PackingListItemModel.weightUnits, ['KG', 'GRM', 'STN', 'SET']);
      expect(PackingListItemModel.normalizeWeightUnit('GRM'), 'GRM');
      expect(PackingListItemModel.normalizeWeightUnit('KGM'), 'KG');
      expect(PackingListItemModel.normalizeWeightUnit('TON'), 'STN');
      expect(PackingListItemModel.normalizeWeightUnit('weird'), 'KG');
      expect(PackingListItemModel.normalizeWeightUnit(null), 'KG');
      for (final code in PackingListItemModel.weightUnits) {
        expect(_en.domainEnumLabel('measure_unit', code), isNotNull, reason: code);
        expect(_ar.domainEnumLabel('measure_unit', code), isNotNull, reason: code);
      }
    });
  });

  group('PO status codes', () {
    test('codes and legacy labels both end up as a code', () {
      expect(PurchaseOrderModel.fromJson(_poJson(status: 'PARTIALLY_SHIPPED')).status, 'PARTIALLY_SHIPPED');
      expect(PurchaseOrderModel.fromJson(_poJson(status: 'In Transit')).status, 'PARTIALLY_SHIPPED');
      expect(PurchaseOrderModel.fromJson(_poJson(status: 'معتمد')).status, 'APPROVED');
      expect(PurchaseOrderModel.fromJson(_poJson(status: 'Canceled')).status, 'CANCELLED');
      expect(PurchaseOrderModel.fromJson(_poJson()).toJson()['status'], 'APPROVED');
    });

    test('every code has a label in both languages and none is shown raw', () {
      for (final code in DomainEnums.codesOf(DomainEnumType.poStatus)) {
        final po = PurchaseOrderModel.fromJson(_poJson(status: code));
        expect(po.statusLabel(_en), isNot(code), reason: code);
        expect(po.statusLabel(_ar), isNot(code), reason: code);
        expect(po.statusLabel(_ar), isNot(po.statusLabel(_en)), reason: code);
      }
      expect(PurchaseOrderModel.fromJson(_poJson(status: 'FULLY_SHIPPED')).statusLabel(_en), 'Fully Shipped');
    });
  });

  group('CBM shipment_mode', () {
    test('code is parsed, rendered and sent; legacy null shows "-"', () {
      final air = CBMCalculationModel.fromJson({'calc_code': 'C', 'shipment_mode': 'AIR'});
      expect(air.shipmentMode, 'AIR');
      expect(air.shipmentModeLabel(_en), 'Air Freight');
      expect(air.shipmentModeLabel(_ar), 'شحن جوي');
      expect(air.toCreateJson()['shipment_mode'], 'AIR');
      final legacy = CBMCalculationModel.fromJson({'calc_code': 'C'});
      expect(legacy.shipmentModeLabel(_en), '-');
      expect(legacy.toCreateJson().containsKey('shipment_mode'), isFalse);
    });
  });

  group('Allocation messages (OVER_SHIPPED)', () {
    final json = {
      'allocation_id': 3,
      'shipment_ref': 'BL-1',
      'shipped_quantity': 120,
      'messages': [
        {
          'code': 'OVER_SHIPPED',
          'severity': 'warning',
          'params': {'shipped_qty': 120, 'ordered_qty': 100, 'po_number': 'PO-5', 'item_code': 'X1'},
        },
      ],
    };

    test('parsed and rendered from the code in both languages', () {
      final r = POAllocationResult.fromJson(json);
      expect(r.isOverShipped, isTrue);
      expect(r.messages.single.isError, isFalse);
      final en = r.messages.single.text(_en);
      expect(en, allOf(contains('PO-5'), contains('X1'), contains('120'), contains('100')));
      expect(r.messages.single.text(_ar), allOf(contains('PO-5'), contains('X1')));
      expect(r.messages.single.text(_ar), isNot(en));
    });

    test('response without messages is fine', () {
      expect(POAllocationResult.fromJson({'allocation_id': 1}).messages, isEmpty);
      expect(POAllocationResult.fromJson({'allocation_id': 1}).isOverShipped, isFalse);
    });

    testWidgets('a warning SnackBar shows the rendered text', (tester) async {
      final r = POAllocationResult.fromJson(json);
      await tester.pumpWidget(localizedApp(
        locale: AppLocales.english,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPoMessagesSnack(context, r.messages),
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(find.textContaining('PO-5'), findsOneWidget);
    });

    test('provider posts the allocation, reloads the lists and returns the warning', () async {
      final adapter = _Adapter()..responseBody = json;
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = adapter;
      final container = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
      addTearDown(container.dispose);
      container.read(purchaseOrdersProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final before = adapter.gets(ApiConstants.purchaseOrders);
      final result = await container.read(purchaseOrdersProvider.notifier).allocateShipment(5, {'shipment_ref': 'BL-1'});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(result.isOverShipped, isTrue);
      expect(adapter.requests, contains('POST ${ApiConstants.purchaseOrders}/5/allocations'));
      expect(adapter.gets(ApiConstants.purchaseOrders), greaterThan(before));
    });
  });

  group('Packing-list report messages', () {
    test('rendered from the code (errors then warnings), English text as fallback', () {
      final report = POPackingListReport.fromJson({
        'is_valid': false,
        'errors': ['Item #1 (X): Gross weight less than net'],
        'warnings': ['Brand new English-only warning'],
        'messages': [
          {
            'code': 'PO_PL_GROSS_BELOW_NET',
            'severity': 'error',
            'params': {'line_num': 1, 'item_code': 'X', 'gross_qty': 1, 'net_qty': 2},
          },
          {'code': 'SOME_FUTURE_CODE', 'severity': 'warning', 'params': {}},
        ],
      });
      final en = report.lines(_en);
      expect(en.length, 2);
      expect(en[0], contains('Gross weight'));
      expect(en[1], 'Brand new English-only warning');
      expect(report.lines(_ar)[0], contains('الوزن القائم'));
    });

    test('older backend without messages falls back to the English lines', () {
      final report = POPackingListReport.fromJson({
        'errors': ['e1'],
        'warnings': ['w1'],
      });
      expect(report.lines(_ar), ['e1', 'w1']);
    });

    test('provider fetches the report', () async {
      final adapter = _Adapter()..responseBody = {'is_valid': true, 'errors': [], 'warnings': ['w'], 'messages': []};
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = adapter;
      final container = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
      addTearDown(container.dispose);
      final report = await container.read(purchaseOrdersProvider.notifier).fetchPackingListReport(5);
      expect(report.warnings, ['w']);
    });
  });

  group('Errors: 409 on removing a shipped line, 403', () {
    DioException err(int status, Object? data) {
      final req = RequestOptions(path: '/x');
      return DioException(requestOptions: req, response: Response(requestOptions: req, statusCode: status, data: data));
    }

    test('the Arabic backend detail is shown as is', () {
      const detail = 'لا يمكن حذف بنود أمر الشراء (11) لأنها مرتبطة بشحنات مسجلة.';
      expect(ApiErrorText.of(_ar, err(409, {'detail': detail})), detail);
    });

    test('409 PO_ITEMS_ALLOCATED is rendered from the code in both languages', () {
      final e = err(409, {
        'detail': {'code': 'PO_ITEMS_ALLOCATED', 'message': 'عربي قديم', 'item_ids': '11, 12'},
      });
      expect(ApiErrorText.of(_en, e), allOf(contains('11, 12'), contains('cannot be removed')));
      expect(ApiErrorText.of(_ar, e), allOf(contains('11, 12'), isNot(contains('عربي قديم'))));
    });

    test('a coded 409 is a plain error, not a concurrent-edit conflict', () async {
      final adapter = _ThrowingAdapter(DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 409,
          data: {'detail': {'code': 'PO_ITEMS_ALLOCATED', 'message': 'm', 'item_ids': '11'}},
        ),
      ));
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = adapter;
      final container = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
      addTearDown(container.dispose);
      final result = await container.read(purchaseOrdersProvider.notifier).updatePurchaseOrder(5, {'x': 1});
      expect(result.isConflict, isFalse);
      expect(result.isSuccess, isFalse);
      expect(ApiErrorText.code(result.error), 'PO_ITEMS_ALLOCATED');
    });

    test('update keeps the raw failure so the screen can localize it', () async {
      final adapter = _ThrowingAdapter(err403());
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = adapter;
      final container = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
      addTearDown(container.dispose);
      final result = await container.read(purchaseOrdersProvider.notifier).updatePurchaseOrder(5, {'x': 1});
      expect(result.isSuccess, isFalse);
      expect(ApiErrorText.of(_en, result.error), _en.apiNoPermission);
      // The failure goes to the caller only: `state.error` is the list-load error and would
      // replace the PO table behind the open dialog with an error page.
      expect(container.read(purchaseOrdersProvider).error, isNull);
    });
  });
}


POLineItemModel _line({int? id, String? code, String? hs, String desc = 'd'}) =>
    POLineItemModel(itemId: id, itemCode: code, hsCode: hs, descriptionAr: desc, quantity: 1, unitPrice: 1);

void _matcherTests() {
  group('AI extraction in edit mode: row ids', () {
    test('matches on item_code first (case/space-insensitive) and carries the id', () {
      final r = carryLineItemIds(
        existing: [_line(id: 1, code: 'A-1'), _line(id: 2, code: 'B-2')],
        extracted: [_line(code: ' b-2 '), _line(code: 'a-1')],
      );
      expect(r.items.map((i) => i.itemId), [2, 1]);
      expect(r.keptUnmatched, isEmpty);
    });

    test('falls back to HS code + description; an id is never used twice', () {
      final r = carryLineItemIds(
        existing: [_line(id: 5, code: 'OLD', hs: '8501', desc: 'Motor')],
        extracted: [_line(code: 'NEW1', hs: '8501', desc: 'motor'), _line(code: 'NEW2', hs: '8501', desc: 'Motor')],
      );
      expect(r.items.map((i) => i.itemId), [5, null]);
    });

    test('unmatched existing line WITH shipments is kept; without shipments it is dropped', () {
      final r = carryLineItemIds(
        existing: [_line(id: 1, code: 'A'), _line(id: 2, code: 'SHIPPED'), _line(id: 3, code: 'FREE')],
        extracted: [_line(code: 'A')],
        allocatedItemIds: {2},
      );
      expect(r.keptUnmatched.map((i) => i.itemId), [2]);
      expect(r.items.map((i) => i.itemId), [1, 2]);
    });

    test('new lines stay without id', () {
      final r = carryLineItemIds(existing: [_line(id: 1, code: 'A')], extracted: [_line(code: 'Z')]);
      expect(r.items.single.itemId, isNull);
    });

    test('packing rows carry ids on item_code, then HS + description', () {
      PackingListItemModel p({int? id, String code = '', String hs = '', String? d}) =>
          PackingListItemModel(packingItemId: id, itemCode: code, hsCode: hs, description: d);
      final r = carryPackingItemIds(
        existing: [p(id: 10, code: 'X'), p(id: 11, code: 'Y', hs: '85', d: 'cable')],
        extracted: [p(code: 'x'), p(code: 'Q', hs: '85', d: 'Cable'), p(code: 'NEW')],
      );
      expect(r.map((e) => e.packingItemId), [10, 11, null]);
    });

    test('allocated line ids are read from the balance (best effort)', () async {
      final adapter = _Adapter()
        ..responseBody = {
          'line_items_balance': [
            {'item_id': 1, 'shipped_qty': 5},
            {'item_id': 2, 'shipped_qty': 0},
          ],
        };
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = adapter;
      final container = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
      addTearDown(container.dispose);
      expect(await container.read(purchaseOrdersProvider.notifier).fetchAllocatedItemIds(5), {1});
    });
  });
}

DioException err403() {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    response: Response(requestOptions: req, statusCode: 403, data: {'detail': 'Forbidden'}),
    type: DioExceptionType.badResponse,
  );
}

/// Answers GET lists normally and fails every write with [error].
class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this.error);
  final DioException error;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.method != 'GET') {
      throw DioException(requestOptions: options, response: error.response, type: DioExceptionType.badResponse);
    }
    return ResponseBody.fromString(jsonEncode(<dynamic>[]), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
