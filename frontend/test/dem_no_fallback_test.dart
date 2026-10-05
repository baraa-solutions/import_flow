import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/widgets/buttons/app_button.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/demurrage_detention/models/demurrage_model.dart';
import 'package:frontend/features/demurrage_detention/widgets/free_days_agreement_dialog.dart';
import 'package:frontend/features/demurrage_detention/widgets/freight_data_monitor_dialog.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.currencies = const []});

  final List<Map<String, dynamic>> currencies;
  final List<RequestOptions> posts = [];

  ResponseBody _json(Object body) => ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = options.path;
    if (path.contains('/currencies')) return _json(currencies);
    if (path.contains('/freight-data/status')) return _json(<String, dynamic>{});
    if (path.contains('/calculate-dual-demurrage')) {
      posts.add(options);
      return _json(<String, dynamic>{
        'days_in_port': 18,
        'detention': {'total_detention_usd': 0, 'chargeable_days': 0},
        'port_storage': {'total_storage_egp': 0, 'tariff_version_applied': 'x'},
        'consolidated_total_egp': 0,
        'consolidated_total_usd': 0,
        'exchange_rate_applied': 50,
        'exchange_rate_source': 'user',
      });
    }
    return _json(<dynamic>[]);
  }

  @override
  void close({bool force = false}) {}
}

Future<_RecordingAdapter> _pumpMonitor(WidgetTester tester, List<Map<String, dynamic>> currencies) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  final adapter = _RecordingAdapter(currencies: currencies);
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:28080/api/v1'))..httpClientAdapter = adapter;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: const MaterialApp(
        home: AppLocalizationsProvider(
          locale: Locale('en'),
          child: Scaffold(body: FreightDataMonitorDialog()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(const AppLocalizationsEn().freightDataTabSimulator));
  await tester.pumpAndSettle();
  return adapter;
}

void main() {
  const en = AppLocalizationsEn();

  group('freight data simulator FX rate (no fallback)', () {
    test('usdCommercialRate reads the latest USD commercial rate only', () {
      final list = [
        CurrencyModel(currencyCode: 'EUR', currencyName: 'Euro', currencySymbol: 'E', latestCommercialRate: 55),
        CurrencyModel(currencyCode: 'USD', currencyName: 'Dollar', currencySymbol: r'$', latestCommercialRate: 50.25),
      ];
      expect(usdCommercialRate(list), 50.25);
      expect(
        usdCommercialRate([CurrencyModel(currencyCode: 'USD', currencyName: 'D', currencySymbol: r'$')]),
        isNull,
      );
      expect(usdCommercialRate(const []), isNull);
    });

    test('parsedFxRate rejects empty, invalid and non-positive input', () {
      expect(parsedFxRate(''), isNull);
      expect(parsedFxRate(null), isNull);
      expect(parsedFxRate('abc'), isNull);
      expect(parsedFxRate('0'), isNull);
      expect(parsedFxRate('-3'), isNull);
      expect(parsedFxRate(' 49.5 '), 49.5);
    });

    testWidgets('no recorded rate: field is empty and calculation is blocked', (tester) async {
      final adapter = await _pumpMonitor(tester, const []);
      final field = tester.widget<TextFormField>(find.byKey(const Key('freightDataFxRateField')));
      expect(field.controller!.text, isEmpty);
      expect(find.text(en.demFxRateMissingHint), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, en.freightDataSimCalculateBtn));
      await tester.pumpAndSettle();
      expect(find.text(en.demFxRateRequired), findsOneWidget);
      expect(adapter.posts, isEmpty);
    });

    testWidgets('recorded USD rate prefills the field and is sent in the payload', (tester) async {
      final adapter = await _pumpMonitor(tester, [
        {
          'currency_code': 'USD',
          'currency_name': 'Dollar',
          'currency_symbol': r'$',
          'latest_commercial_rate': 50.25,
        },
      ]);
      final field = tester.widget<TextFormField>(find.byKey(const Key('freightDataFxRateField')));
      expect(field.controller!.text, '50.25');
      expect(find.text(en.demFxRateFromCurrencies), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, en.freightDataSimCalculateBtn));
      await tester.pumpAndSettle();
      expect(adapter.posts, hasLength(1));
      expect((adapter.posts.single.data as Map)['exchange_rate_usd_egp'], 50.25);
    });

    testWidgets('a typed rate is sent when Currencies has none', (tester) async {
      final adapter = await _pumpMonitor(tester, const []);
      await tester.enterText(find.byKey(const Key('freightDataFxRateField')), '51.5');
      await tester.tap(find.widgetWithText(AppButton, en.freightDataSimCalculateBtn));
      await tester.pumpAndSettle();
      expect((adapter.posts.single.data as Map)['exchange_rate_usd_egp'], 51.5);
    });
  });

  group('tracking model / agreement defaults', () {
    test('missing exchange_rate stays null (no 50.0 fallback)', () {
      final t = DemurrageTrackingModel.fromJson({'tracking_id': 1, 'tracking_code': 'T', 'exchange_rate': null});
      expect(t.exchangeRate, isNull);
      final t2 = DemurrageTrackingModel.fromJson({'tracking_id': 1, 'tracking_code': 'T', 'exchange_rate': 49.5});
      expect(t2.exchangeRate, 49.5);
    });

    testWidgets('agreement dialog does not prefill 21/14/5 days', (tester) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:28080/api/v1'))..httpClientAdapter = _RecordingAdapter();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dioProvider.overrideWithValue(dio)],
          child: const MaterialApp(
            home: AppLocalizationsProvider(locale: Locale('en'), child: Scaffold(body: FreeDaysAgreementDialog())),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).map((f) => f.controller?.text).toList();
      expect(fields.where((t) => t == '21' || t == '14' || t == '5'), isEmpty);
    });
  });

  group('free days agreement savings (no invented tariff)', () {
    test('extraFreeDaysOverBaseline only uses a recorded baseline', () {
      expect(extraFreeDaysOverBaseline(28, 21), 7);
      expect(extraFreeDaysOverBaseline(14, 21), 0);
      expect(extraFreeDaysOverBaseline(28, null), isNull);
    });

    testWidgets('dialog shows no dollar savings figure and no 14/7-day tariff text', (tester) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final adapter = _RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:28080/api/v1'))..httpClientAdapter = adapter;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dioProvider.overrideWithValue(dio)],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('en'),
              child: Scaffold(body: FreeDaysAgreementDialog()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(en.demFdaNoBaseline), findsWidgets);
      expect(find.textContaining(r'$'), findsNothing);
      expect(find.text(en.fdaAboveTariff(14)), findsNothing);
      expect(find.text(en.fdaAboveTariff(7)), findsNothing);
    });
  });
}
