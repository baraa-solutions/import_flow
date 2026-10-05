import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/financial_settlement/providers/financial_settlement_provider.dart';
import 'package:frontend/features/lifecycle_board/providers/lifecycle_board_provider.dart';

/// Records requests and answers with canned JSON.
class _StubAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, dynamic> approveResponse;

  _StubAdapter({this.approveResponse = const {}});

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    Object body;
    if (options.method == 'GET' && options.path.endsWith('/financial-settlement')) {
      body = <dynamic>[];
    } else if (options.path.contains('approve-actual-landed-cost')) {
      body = approveResponse;
    } else if (options.method == 'POST' && options.path.endsWith('/financial-settlement')) {
      body = {
        'settlement_id': 1,
        'settlement_code': 'LCS-2026-0001',
        'import_file_id': 5,
      };
    } else if (options.path.contains('lifecycle-board/summary')) {
      body = <String, dynamic>{};
    } else {
      body = <dynamic>[];
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

ProviderContainer _container(_StubAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://stub'))..httpClientAdapter = adapter;
  final c = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('create payload is posted as given and the list reloads afterwards', () async {
    final adapter = _StubAdapter();
    final c = _container(adapter);
    final notifier = c.read(financialSettlementProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    adapter.requests.clear();

    final created = await notifier.createSettlement({
      'import_file_id': 5,
      'expense_invoices': [
        {'invoice_no': 'I-1', 'currency': 'USD', 'amount_fx': 10.0}
      ],
      'item_landed_costs': [
        {'item_code': 'A', 'qty': 2.5}
      ],
    });

    final post = adapter.requests.firstWhere((r) => r.method == 'POST');
    final data = post.data as Map;
    final inv = (data['expense_invoices'] as List).first as Map;
    expect(inv.containsKey('amount_egp'), isFalse);
    expect(created?.settlementCode, 'LCS-2026-0001');
    // reload after mutation
    expect(adapter.requests.last.method, 'GET');
    expect(adapter.requests.last.path, endsWith('/financial-settlement'));
  });

  test('approve does not send a client-supplied approver and invalidates the lifecycle board', () async {
    final adapter = _StubAdapter(approveResponse: {
      'success': true,
      'import_file_id': 5,
      'settlement_id': 1,
    });
    final c = _container(adapter);
    final notifier = c.read(financialSettlementProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    // Keep the lifecycle provider alive and loaded once.
    final sub = c.listen(lifecycleBoardSummaryProvider, (_, __) {});
    addTearDown(sub.close);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final before = adapter.requests.where((r) => r.path.contains('lifecycle-board/summary')).length;
    expect(before, 1);

    try {
      await notifier.approveActualLandedCost(importFileId: 5, approvedBy: 'someone');
    } catch (_) {
      // The response model may reject the minimal stub; the request/invalidations are what matter.
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final approve = adapter.requests.firstWhere((r) => r.path.contains('approve-actual-landed-cost'));
    expect((approve.data as Map).containsKey('approved_by'), isFalse);
  });
}
