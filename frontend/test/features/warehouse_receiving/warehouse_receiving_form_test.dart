import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/warehouse_receiving/models/warehouse_receiving_model.dart';
import 'package:frontend/features/warehouse_receiving/providers/warehouse_receiving_provider.dart';
import 'package:frontend/features/warehouse_receiving/widgets/warehouse_receiving_form_dialog.dart';

import '../../helpers/localized_app.dart';

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, ResponseBody Function(RequestOptions)> routes = {};

  static ResponseBody json(Object body, [int status = 200]) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  _Adapter on(String key, ResponseBody Function(RequestOptions) f) {
    routes[key] = f;
    return this;
  }

  List<RequestOptions> of(String method, String part) =>
      requests.where((r) => r.method == method && r.uri.path.contains(part)).toList();

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    for (final e in routes.entries) {
      final sp = e.key.indexOf(' ');
      if (options.method == e.key.substring(0, sp) && options.uri.path.contains(e.key.substring(sp + 1))) {
        return e.value(options);
      }
    }
    return json(<dynamic>[]);
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _recordJson({int shortage = 0, int accepted = 100}) => {
      'receiving_id': 7,
      'grn_code': 'GRN-2026-0007',
      'import_file_id': 3,
      'warehouse_name': 'WH-A',
      'arrival_datetime': '2026-10-05T10:00:00',
      'created_at': '',
      'updated_at': '',
      'grn_items': [
        {
          'item_code': 'ITM-1',
          'item_name': 'Pump',
          'invoiced_qty': 100,
          'accepted_qty': accepted,
          'shortage_qty': shortage,
          'damaged_qty': 0,
        },
      ],
    };

const _en = AppLocalizationsEn();

Future<_Adapter> _open(
  WidgetTester tester, {
  WarehouseReceivingModel? record,
  bool clone = false,
}) async {
  tester.view.physicalSize = const Size(1500, 1100);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final adapter = _Adapter()..on('PUT /warehouse-receiving/7', (_) => _Adapter.json(_recordJson()));
  adapter.on('POST /warehouse-receiving', (_) => _Adapter.json(_recordJson()));
  final dio = Dio(BaseOptions(validateStatus: (s) => s != null && s >= 200 && s < 300))..httpClientAdapter = adapter;

  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      uploadDioProvider.overrideWithValue(dio),
    ],
    child: localizedApp(
      locale: AppLocales.english,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open'),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => WarehouseReceivingFormDialog(recordToEdit: record, isCloneDraft: clone),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return adapter;
}

void main() {
  testWidgets('a new GRN starts with no invented lines and no draft button (FE-01 / FE-03)', (tester) async {
    await _open(tester);

    expect(find.text(_en.wrNoLinesHint), findsOneWidget);
    expect(find.textContaining('ITM-'), findsNothing);
    expect(find.textContaining('Enterprise Servers'), findsNothing);
    // The only save action issues a real GRN: there is no "save draft".
    expect(find.text(_en.warehouseReceivingSaveDraftBtn), findsNothing);
    expect(find.text(_en.warehouseReceivingSaveFinalBtn), findsOneWidget);
  });

  testWidgets('saving a new GRN without a file / lines sends nothing', (tester) async {
    final adapter = await _open(tester);

    await tester.tap(find.text(_en.warehouseReceivingSaveFinalBtn));
    await tester.pumpAndSettle();

    expect(adapter.of('POST', 'warehouse-receiving'), isEmpty);
    expect(find.text(_en.warehouseReceivingSelectFileValidator), findsOneWidget);
  });

  testWidgets('add line starts empty: the user must type the code and quantities', (tester) async {
    await _open(tester);

    await tester.tap(find.text(_en.warehouseReceivingAddItemBtn));
    await tester.pumpAndSettle();

    expect(find.text(_en.wrNoLinesHint), findsNothing);
    final codeField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, _en.wrItemCodeLabel));
    expect(codeField.controller!.text, isEmpty);
    final inv = tester.widget<TextFormField>(find.widgetWithText(TextFormField, _en.warehouseReceivingInvoicedQtyLabel));
    expect(inv.controller!.text, isEmpty);
  });

  testWidgets('an unbalanced line shows the live check and blocks the save (WR-04)', (tester) async {
    final adapter = await _open(tester, record: WarehouseReceivingModel.fromJson(_recordJson(shortage: 2)));

    // accepted 100 + shortage 2 != invoiced 100
    expect(find.text(_en.wrLineUnbalanced(102, 100)), findsOneWidget);

    await tester.tap(find.text(_en.warehouseReceivingSaveFinalBtn));
    await tester.pumpAndSettle();

    expect(adapter.of('PUT', 'warehouse-receiving/7'), isEmpty);
  });

  testWidgets('editing a balanced GRN sends the lines and never a status', (tester) async {
    final adapter = await _open(tester, record: WarehouseReceivingModel.fromJson(_recordJson()));

    expect(find.text(_en.wrLineUnbalanced(100, 100)), findsNothing);
    await tester.tap(find.text(_en.warehouseReceivingSaveFinalBtn));
    await tester.pumpAndSettle();

    final puts = adapter.of('PUT', 'warehouse-receiving/7');
    expect(puts, hasLength(1));
    final body = puts.single.data as Map;
    expect(body.containsKey('status'), isFalse);
    final item = (body['grn_items'] as List).single as Map;
    expect(item['item_code'], 'ITM-1');
    expect(item['invoiced_qty'], 100);
    expect(item['accepted_qty'], 100);
    expect(item['shortage_qty'], 0);
    expect(item['damaged_qty'], 0);
  });

  testWidgets('a clone copies header data only: no lines, no file, nothing is sent until a file is picked', (tester) async {
    final adapter = await _open(tester, record: WarehouseReceivingModel.fromJson(_recordJson()), clone: true);

    // Header data is kept, the source lines and the source file are not.
    expect(find.text('WH-A'), findsWidgets);
    expect(find.text(_en.wrNoLinesHint), findsOneWidget);
    expect(find.textContaining('Enterprise Servers'), findsNothing);

    // Saving needs a file (its PO lines fill the form): the source file is never reused (WR_GRN_EXISTS).
    await tester.tap(find.text(_en.warehouseReceivingSaveFinalBtn));
    await tester.pumpAndSettle();

    expect(adapter.of('POST', 'warehouse-receiving'), isEmpty);
    expect(find.text(_en.warehouseReceivingSelectFileValidator), findsOneWidget);
  });

  testWidgets('a backend detail dict is shown as its message', (tester) async {
    final adapter = await _open(tester, record: WarehouseReceivingModel.fromJson(_recordJson()));
    adapter.on(
      'PUT /warehouse-receiving/7',
      (_) => _Adapter.json({
        'detail': {'code': 'WR_GRN_EXISTS_UNKNOWN_TO_CATALOG', 'message': 'A GRN already exists for this file'}
      }, 409),
    );

    await tester.tap(find.text(_en.warehouseReceivingSaveFinalBtn));
    await tester.pumpAndSettle();

    expect(find.text('A GRN already exists for this file'), findsOneWidget);
  });

  test('last list filters are re-applied after a mutation (FE-15)', () async {
    final adapter = _Adapter()..on('DELETE /warehouse-receiving/7', (_) => _Adapter.json({'ok': true}));
    final dio = Dio(BaseOptions(validateStatus: (s) => s != null && s >= 200 && s < 300))..httpClientAdapter = adapter;
    final c = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
    addTearDown(c.dispose);
    c.listen(importFilesProvider, (_, __) {});
    final notifier = c.read(warehouseReceivingProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    await notifier.fetchRecords(search: 'abc', status: 'Goods Received');
    await notifier.softDeleteRecord(7);

    final last = adapter.of('GET', 'warehouse-receiving').last;
    expect(last.queryParameters['search'], 'abc');
    expect(last.queryParameters['status'], 'Goods Received');
  });
}
