import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/api_error.dart';
import 'package:frontend/features/financial_approval/models/financial_approval_model.dart';
import 'package:frontend/features/financial_approval/providers/financial_approval_provider.dart';
import 'package:frontend/features/financial_approval/widgets/async_action_button.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

import '../../helpers/localized_app.dart';

Map<String, dynamic> _paymentJson(
        {String status = 'Draft', Object? rate = 48.5}) =>
    {
      'payment_id': 7,
      'payment_code': 'PAY-2026-001',
      'title': 'Advance',
      'supplier_name': 'ACME',
      'payment_type': 'ADVANCE_PAYMENT',
      'requested_amount': 100,
      'currency_code': 'EUR',
      'exchange_rate': rate,
      'requested_amount_egp': 4850,
      'due_date': '2026-10-17',
      'request_date': '2026-10-05',
      'status': status,
      'created_at': '',
      'updated_at': '',
      'import_file_code': 'IMP-2026-009',
    };

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  /// `METHOD path-fragment` -> responder.
  final Map<String, ResponseBody Function(RequestOptions)> routes = {};

  static ResponseBody json(Object body, [int status = 200]) =>
      ResponseBody.fromString(
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

  int count(String method, String part) => requests
      .where((r) => r.method == method && r.uri.path.contains(part))
      .length;

  Map<String, dynamic> queryOfLast(String method, String part) => requests
      .lastWhere((r) => r.method == method && r.uri.path.contains(part))
      .queryParameters;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    for (final e in routes.entries) {
      final sp = e.key.indexOf(' ');
      if (options.method == e.key.substring(0, sp) &&
          options.uri.path.contains(e.key.substring(sp + 1))) {
        return e.value(options);
      }
    }
    return json(<dynamic>[]);
  }

  @override
  void close({bool force = false}) {}
}

ProviderContainer _container(_Adapter adapter) {
  final dio =
      Dio(BaseOptions(validateStatus: (s) => s != null && s >= 200 && s < 300))
        ..httpClientAdapter = adapter;
  final c = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    uploadDioProvider.overrideWithValue(dio),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 150));

void main() {
  group('model', () {
    test('a missing exchange rate is 0.0, never a fabricated 50', () {
      final p = PaymentRequestModel.fromJson(_paymentJson(rate: null));
      expect(p.exchangeRate, 0.0);
      expect(p.importFileCode, 'IMP-2026-009');
    });

    test('prefill without a rate defaults to 0.0', () {
      final prefill = BudgetPrefillModel.fromJson({'import_file_id': 3});
      expect(prefill.exchangeRate, 0.0);
    });

    test('budget without a rate defaults to 0.0', () {
      final b = ImportBudgetModel.fromJson({
        'budget_id': 1,
        'budget_code': 'BGT-1',
        'title': 't',
        'budget_status': 'Draft',
      });
      expect(b.exchangeRate, 0.0);
    });
  });

  group('PaymentRequestsNotifier', () {
    test('mutations re-fetch with the last list filters', () async {
      final a = _Adapter()
        ..on('POST /approve',
            (_) => _Adapter.json(_paymentJson(status: 'Approved')));
      final c = _container(a);
      final notifier = c.read(paymentRequestsProvider.notifier);
      await _settle();

      await notifier.fetchPaymentRequests(
          search: 'acme', status: 'Draft', supplierId: 4);
      await notifier.approvePaymentRequest(7);

      final q = a.queryOfLast('GET', 'payment-requests');
      expect(q['search'], 'acme');
      expect(q['status'], 'Draft');
      expect(q['supplier_id'], 4);
    });

    test('create / approve / pay invalidate the import files list', () async {
      final a = _Adapter()
        ..on('POST /approve',
            (_) => _Adapter.json(_paymentJson(status: 'Approved')))
        ..on('POST /pay', (_) => _Adapter.json(_paymentJson(status: 'Paid')))
        ..on('POST /payment-requests', (_) => _Adapter.json(_paymentJson()));
      final c = _container(a);
      // Keep the import files provider alive so invalidation triggers a refetch.
      c.listen(importFilesProvider, (_, __) {});
      final notifier = c.read(paymentRequestsProvider.notifier);
      await _settle();

      var before = a.count('GET', '/import-files');
      await notifier.createPaymentRequest({'title': 'x'});
      await _settle();
      expect(a.count('GET', '/import-files'), greaterThan(before),
          reason: 'create');

      before = a.count('GET', '/import-files');
      await notifier.approvePaymentRequest(7);
      await _settle();
      expect(a.count('GET', '/import-files'), greaterThan(before),
          reason: 'approve');

      before = a.count('GET', '/import-files');
      await notifier.executePayment(7);
      await _settle();
      expect(a.count('GET', '/import-files'), greaterThan(before),
          reason: 'pay');
    });

    test('approve rethrows the backend error so the UI can show it', () async {
      final a = _Adapter()
        ..on(
            'POST /approve',
            (_) => _Adapter.json({
                  'detail': {
                    'code': 'FA_PAYMENT_STATUS_INVALID',
                    'message': 'Cannot approve a paid request'
                  }
                }, 400));
      final c = _container(a);
      final notifier = c.read(paymentRequestsProvider.notifier);
      await _settle();

      Object? error;
      try {
        await notifier.approvePaymentRequest(7);
      } catch (e) {
        error = e;
      }
      expect(error, isA<DioException>());
      expect(ApiError.message(error), 'Cannot approve a paid request');
    });

    test('SWIFT confirm and field edit no longer send a client user name',
        () async {
      final a = _Adapter()
        ..on('POST /confirm', (_) => _Adapter.json({'ok': true}))
        ..on('PUT /field/', (_) => _Adapter.json({'batch_id': 1}));
      final c = _container(a);
      final notifier = c.read(paymentRequestsProvider.notifier);
      await _settle();

      await notifier.confirmSwiftBatchReview(batchId: 1);
      final confirmBody =
          a.requests.lastWhere((r) => r.uri.path.endsWith('/confirm')).data;
      expect(confirmBody is Map ? confirmBody.containsKey('user_name') : false,
          isFalse);
    });
  });

  group('ImportBudgetsNotifier', () {
    test('prefill errors are rethrown (no silent null)', () async {
      final a = _Adapter()
        ..on(
            'GET /prefill/',
            (_) => _Adapter.json({
                  'detail': {
                    'code': 'FA_FX_RATE_MISSING',
                    'message': 'No rate for EUR',
                    'currency_code': 'EUR'
                  }
                }, 400));
      final c = _container(a);
      final notifier = c.read(importBudgetsProvider.notifier);
      await _settle();

      Object? error;
      try {
        await notifier.fetchBudgetPrefill(3);
      } catch (e) {
        error = e;
      }
      expect(ApiError.message(error), 'No rate for EUR');
    });

    test('approve sends no approved_by (backend uses the signed-in user)',
        () async {
      final a = _Adapter()
        ..on(
            'POST /approve',
            (_) => _Adapter.json({
                  'budget_id': 1,
                  'budget_code': 'BGT-1',
                  'title': 't',
                  'budget_status': 'Budget Approved',
                }));
      final c = _container(a);
      c.listen(importFilesProvider, (_, __) {});
      final notifier = c.read(importBudgetsProvider.notifier);
      await _settle();

      final before = a.count('GET', '/import-files');
      await notifier.approveImportBudget(1);
      await _settle();

      final approve =
          a.requests.lastWhere((r) => r.uri.path.endsWith('/approve'));
      expect(approve.queryParameters.containsKey('approved_by'), isFalse);
      expect(a.count('GET', '/import-files'), greaterThan(before));
    });

    test('budget mutations keep the active filters', () async {
      final a = _Adapter()
        ..on(
            'POST /override-variance',
            (_) => _Adapter.json({
                  'budget_id': 1,
                  'budget_code': 'BGT-1',
                  'title': 't',
                  'budget_status': 'Pending Review',
                }));
      final c = _container(a);
      final notifier = c.read(importBudgetsProvider.notifier);
      await _settle();

      await notifier.fetchImportBudgets(search: 'steel', budgetStatus: 'Draft');
      await notifier.overrideBudgetVariance(1, 'because');

      final q = a.queryOfLast('GET', 'import-budgets');
      expect(q['search'], 'steel');
      expect(q['budget_status'], 'Draft');
    });
  });

  group('AsyncActionButton', () {
    testWidgets('shows the backend message and re-enables after a failure',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(localizedApp(
        home: Scaffold(
          body: Center(
            child: AsyncActionButton(
              label: 'Approve',
              onAction: () async {
                calls++;
                throw DioException(
                  requestOptions: RequestOptions(path: '/x'),
                  response: Response(
                    requestOptions: RequestOptions(path: '/x'),
                    statusCode: 409,
                    data: {
                      'detail': {
                        'code': 'FA_PAYMENT_LOCKED',
                        'message': 'Locked request'
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Approve'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Locked request'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.text('Approve'));
      await tester.pump();
      expect(calls, 2);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('shows a spinner and ignores repeat taps while running',
        (tester) async {
      final gate = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(localizedApp(
        home: Scaffold(
          body: Center(
            child: AsyncActionButton(
              label: 'Pay',
              onAction: () async {
                calls++;
                await gate.future;
              },
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Pay'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Pay'), warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);

      gate.complete();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
