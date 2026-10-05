import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/financial_settlement/widgets/settlement_form_dialog.dart';

class _EmptyAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(<dynamic>[]),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  testWidgets('empty form blocks save: no POST, no fabricated defaults in the fields', (tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final adapter = _EmptyAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://stub'))..httpClientAdapter = adapter;

    await tester.pumpWidget(ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: const MaterialApp(home: Scaffold(body: SettlementFormDialog())),
    ));
    await tester.pumpAndSettle();

    // No sample values pre-filled (previously 1000 / 50.0 / 100 / 500).
    for (final key in const [
      'settlementAmountFxField',
      'settlementRateField',
      'settlementQtyField',
      'settlementFobUnitField',
      'settlementWeightField',
      'settlementCbmField',
    ]) {
      final field = tester.widget<TextFormField>(find.byKey(Key(key)));
      expect(field.controller!.text, isEmpty, reason: key);
    }

    adapter.requests.clear();
    final saveButton = find.byKey(const Key('settlementSaveButton'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(adapter.requests.where((r) => r.method == 'POST'), isEmpty);
    // Validators ran: at least one error is rendered.
    expect(find.byType(Form), findsOneWidget);
    final formState = tester.state<FormState>(find.byType(Form));
    expect(formState.validate(), isFalse);
  });
}
