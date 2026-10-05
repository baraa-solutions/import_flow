import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/financial_approval/widgets/supplier_advance_payment_dialog.dart';

import '../../helpers/localized_app.dart';

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> posts = [];

  ResponseBody _json(Object body, int status) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.method == 'POST' &&
        options.uri.path.contains('payment-requests')) {
      posts.add(options);
      return _json({
        'payment_id': 1,
        'payment_code': 'PAY-1',
        'title': 'x',
        'supplier_name': 'ACME',
        'payment_type': 'ADVANCE_PAYMENT',
        'requested_amount': 1,
        'currency_code': 'USD',
        'exchange_rate': 50,
        'requested_amount_egp': 50,
        'due_date': '2026-10-17',
        'request_date': '2026-10-05',
        'status': 'Draft',
        'created_at': '',
        'updated_at': '',
      }, 201);
    }
    return _json(<dynamic>[], 200);
  }

  @override
  void close({bool force = false}) {}
}

Future<_Adapter> _pumpDialog(WidgetTester tester, {int? supplierId}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final adapter = _Adapter();
  final dio =
      Dio(BaseOptions(validateStatus: (s) => s != null && s >= 200 && s < 300))
        ..httpClientAdapter = adapter;

  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      uploadDioProvider.overrideWithValue(dio),
    ],
    child: localizedApp(
      locale: AppLocales.english,
      home: Scaffold(
        body: SupplierAdvancePaymentDialog(
          importFileId: 4,
          importFileCode: 'IMP-2026-0004',
          supplierId: supplierId,
          supplierName: 'Sinopec',
          totalAmountForeign: 80000,
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  return adapter;
}

void main() {
  testWidgets('advance payment dialog sends the PaymentRequestCreate keys',
      (tester) async {
    final adapter = await _pumpDialog(tester, supplierId: 8);

    await tester.enterText(
        find.byKey(const ValueKey('advanceExchangeRateField')), '50');
    // Fill the remaining empty required fields (bank, SWIFT, IBAN).
    final fields = find.byType(TextFormField);
    for (var i = 0; i < fields.evaluate().length; i++) {
      final f = tester.widget<TextFormField>(fields.at(i));
      if ((f.controller?.text ?? '').isEmpty && f.validator != null) {
        await tester.enterText(fields.at(i), 'ABCDEFGH1');
      }
    }
    await tester.pump();

    await tester.tap(find.text('Issue Payment Request & Notify Finance'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(adapter.posts, hasLength(1));
    final body = adapter.posts.single.data as Map<String, dynamic>;
    expect(body['payment_type'], 'ADVANCE_PAYMENT');
    expect(body['exchange_rate'], 50.0);
    expect((body['title'] as String).length, greaterThanOrEqualTo(3));
    expect(body['due_date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(body['requested_amount'], 24000.0);
    expect(body['currency_code'], 'USD');
    expect(body['iban_account_no'], isNotEmpty);
  });

  testWidgets('submit is blocked without an exchange rate (no fallback)',
      (tester) async {
    final adapter = await _pumpDialog(tester);

    await tester.tap(find.text('Issue Payment Request & Notify Finance'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(adapter.posts, isEmpty);
    expect(find.text('Enter an exchange rate greater than zero'), findsWidgets);
  });
}
