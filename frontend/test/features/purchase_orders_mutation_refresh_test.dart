import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/projects/providers/projects_provider.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/shipping_scenarios/providers/shipping_scenarios_provider.dart';

/// Records every request and answers lists with `[]` and writes with `{}`.
class _RecordingAdapter implements HttpClientAdapter {
  final List<String> requests = [];

  int gets(String pathPart) =>
      requests.where((r) => r.startsWith('GET ') && r.contains(pathPart)).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    final isList = options.method == 'GET';
    return ResponseBody.fromString(
      isList ? '[]' : jsonEncode(<String, dynamic>{}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  late _RecordingAdapter adapter;
  late ProviderContainer container;

  setUp(() async {
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = adapter;
    container = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
    // Instantiate every dependent provider so their own initial fetches are done
    // before the mutation under test runs.
    container.read(purchaseOrdersProvider);
    container.read(projectsProvider);
    container.read(importFilesProvider);
    container.read(shippingScenariosProvider);
    await _settle();
  });

  tearDown(() => container.dispose());

  Map<String, int> snapshot() => {
        'po': adapter.gets(ApiConstants.purchaseOrders),
        'projects': adapter.gets('/projects'),
        'files': adapter.gets('/import-files'),
        'scenarios': adapter.gets('/shipping-scenarios'),
      };

  void expectEveryListReloaded(Map<String, int> before) {
    final after = snapshot();
    for (final key in before.keys) {
      expect(after[key]!, greaterThan(before[key]!), reason: '$key list was not reloaded after the mutation');
    }
  }

  PurchaseOrderModel samplePo() => PurchaseOrderModel.fromJson(<String, dynamic>{'po_number': 'PO-1'});

  test('create reloads PO, project, import file and scenario lists', () async {
    final before = snapshot();
    final error = await container.read(purchaseOrdersProvider.notifier).createPurchaseOrder(samplePo());
    await _settle();
    expect(error, isNull);
    expectEveryListReloaded(before);
  });

  test('update reloads PO, project, import file and scenario lists', () async {
    final before = snapshot();
    final result = await container.read(purchaseOrdersProvider.notifier).updatePurchaseOrder(7, {'notes': 'x'});
    await _settle();
    expect(result.isSuccess, isTrue);
    expectEveryListReloaded(before);
  });

  test('delete reloads PO, project, import file and scenario lists', () async {
    final before = snapshot();
    final ok = await container.read(purchaseOrdersProvider.notifier).deletePurchaseOrder(7);
    await _settle();
    expect(ok, isTrue);
    expectEveryListReloaded(before);
  });

  test('restore reloads PO, project, import file and scenario lists', () async {
    final before = snapshot();
    final ok = await container.read(purchaseOrdersProvider.notifier).restorePurchaseOrder(7);
    await _settle();
    expect(ok, isTrue);
    expectEveryListReloaded(before);
  });

  test('clone reloads PO, project, import file and scenario lists', () async {
    final before = snapshot();
    final cloned = await container.read(purchaseOrdersProvider.notifier).clonePurchaseOrder(7, {'new_po_number': 'PO-2'});
    await _settle();
    expect(cloned, isNotNull);
    expectEveryListReloaded(before);
  });

  test('refreshAfterMutation (used after Excel import) reloads every dependent list', () async {
    final before = snapshot();
    await container.read(purchaseOrdersProvider.notifier).refreshAfterMutation();
    await _settle();
    expectEveryListReloaded(before);
  });
}
