import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/inland_transport/providers/inland_transport_provider.dart';
import 'package:frontend/features/inland_transport/widgets/inland_transport_dialog.dart';

import '../../helpers/localized_app.dart';

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, ResponseBody Function(RequestOptions)> routes = {};

  static ResponseBody json(Object? body, [int status = 200]) => ResponseBody.fromString(
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

Dio _dio(_Adapter a) => Dio(BaseOptions(validateStatus: (s) => s != null && s >= 200 && s < 300))..httpClientAdapter = a;

ProviderContainer _container(_Adapter a) {
  final c = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(_dio(a)),
    uploadDioProvider.overrideWithValue(_dio(a)),
  ]);
  addTearDown(c.dispose);
  return c;
}

Map<String, dynamic> _bookingJson({String status = 'Booking Confirmed'}) => {
      'transport_id': 4,
      'transport_code': 'TR-2026-0004',
      'import_file_id': 3,
      'waybill_number': 'WB-77',
      'booking_date': '2026-10-05',
      'carrier_name': 'Carrier Co',
      'truck_plate_number': 'ABC 123',
      'driver_name': 'Driver One',
      'driver_phone': '01000000000',
      'pickup_port_location': 'Port',
      'destination_warehouse': 'WH',
      'planned_departure_at': '2026-10-06T10:00:00',
      'expected_arrival_at': '2026-10-06T16:00:00',
      'transport_fare_egp': 4500,
      'status': status,
      'created_at': '',
      'updated_at': '',
    };

ImportFileModel _file() => ImportFileModel.fromJson({
      'import_file_id': 3,
      'import_file_code': 'IMP-2026-003',
      'company_name': 'ACME Co',
      'supplier_name': 'Supplier',
      'current_module': 'Phase 8',
      'current_stage': 'Stage',
      'next_action': 'Next',
      'created_at': '',
      'updated_at': '',
    });

const _en = AppLocalizationsEn();

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 100));

void main() {
  group('InlandTransportNotifier.fetchBookingByFile (FE-06)', () {
    test('a 200 with a null body is "no booking"', () async {
      final a = _Adapter()..on('GET /by-file/3', (_) => _Adapter.json(null));
      final c = _container(a);
      await _settle();
      expect(await c.read(inlandTransportProvider.notifier).fetchBookingByFile(3), isNull);
    });

    test('a booking is parsed', () async {
      final a = _Adapter()..on('GET /by-file/3', (_) => _Adapter.json(_bookingJson()));
      final c = _container(a);
      await _settle();
      final b = await c.read(inlandTransportProvider.notifier).fetchBookingByFile(3);
      expect(b?.transportCode, 'TR-2026-0004');
    });

    test('a server error is rethrown, never turned into "no booking"', () async {
      final a = _Adapter()..on('GET /by-file/3', (_) => _Adapter.json({'detail': 'boom'}, 500));
      final c = _container(a);
      await _settle();
      await expectLater(c.read(inlandTransportProvider.notifier).fetchBookingByFile(3), throwsA(isA<DioException>()));
    });

    test('a 403 is rethrown too', () async {
      final a = _Adapter()..on('GET /by-file/3', (_) => _Adapter.json({'detail': 'forbidden'}, 403));
      final c = _container(a);
      await _settle();
      await expectLater(c.read(inlandTransportProvider.notifier).fetchBookingByFile(3), throwsA(isA<DioException>()));
    });
  });

  group('event payloads (FE-04)', () {
    test('notes are sent as `notes`, and only when typed', () {
      final at = DateTime(2026, 10, 5, 9, 30);
      final empty = inlandEventPayload(timeKey: 'actual_departure_at', at: at, notesText: '   ');
      expect(empty.containsKey('notes'), isFalse);
      expect(empty.containsKey('tracking_notes'), isFalse);
      expect(empty['actual_departure_at'], at.toIso8601String());

      final typed = inlandEventPayload(timeKey: 'actual_arrival_at', at: at, notesText: ' dock 4 ');
      expect(typed['notes'], 'dock 4');
      expect(typed.containsKey('tracking_notes'), isFalse);
    });

    test('inlandNotesOrNull trims and nulls empty text', () {
      expect(inlandNotesOrNull(''), isNull);
      expect(inlandNotesOrNull('  x '), 'x');
    });
  });

  group('dialog', () {
    Future<_Adapter> open(WidgetTester tester, _Adapter adapter) async {
      tester.view.physicalSize = const Size(1500, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(_dio(adapter)),
          uploadDioProvider.overrideWithValue(_dio(adapter)),
        ],
        child: localizedApp(
          locale: AppLocales.english,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open'),
                onPressed: () => InlandTransportDialog.show(context, _file()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      return adapter;
    }

    testWidgets('a network error shows the error and a retry, NOT the create-booking form', (tester) async {
      final a = _Adapter()..on('GET /by-file/3', (_) => _Adapter.json({'detail': 'down'}, 500));
      await open(tester, a);

      expect(find.byKey(const Key('inlandLoadErrorText')), findsOneWidget);
      expect(find.byKey(const Key('inlandRetryBtn')), findsOneWidget);
      expect(find.byKey(const Key('inlandSubmitBookingBtn')), findsNothing);
      expect(find.byKey(const Key('inlandWaybillNoField')), findsNothing);
    });

    testWidgets('retry loads the booking after the error', (tester) async {
      var calls = 0;
      final a = _Adapter()
        ..on('GET /by-file/3', (_) {
          calls++;
          return calls == 1 ? _Adapter.json({'detail': 'down'}, 500) : _Adapter.json(_bookingJson());
        });
      await open(tester, a);

      await tester.tap(find.byKey(const Key('inlandRetryBtn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inlandLoadErrorText')), findsNothing);
      expect(find.text(_en.inlandCurrentBookingTitle('TR-2026-0004')), findsOneWidget);
    });

    testWidgets('with no booking the form opens with no invented waybill, fare or warehouse', (tester) async {
      final a = _Adapter()..on('GET /by-file/3', (_) => _Adapter.json(null));
      await open(tester, a);

      expect(find.byKey(const Key('inlandSubmitBookingBtn')), findsOneWidget);
      // The auto-generate waybill button is gone (FE-12).
      expect(find.byKey(const Key('inlandAutoWaybillBtn')), findsNothing);
      final waybill = tester.widget<TextFormField>(find.byKey(const Key('inlandWaybillNoField')));
      expect(waybill.controller!.text, isEmpty);
      final fare = tester.widget<TextFormField>(find.byKey(const Key('inlandFareEgpField')));
      expect(fare.controller!.text, isEmpty);
      expect(find.textContaining('4500'), findsNothing);
    });

    testWidgets('gate-out sends `notes` only when typed and the server error is shown', (tester) async {
      final a = _Adapter()
        ..on('GET /by-file/3', (_) => _Adapter.json(_bookingJson()))
        ..on('POST /gate-out', (_) => _Adapter.json({
              'detail': {'code': 'IT_OUT_OF_ORDER', 'message': 'Gate-out is not allowed in this state'}
            }, 409));
      await open(tester, a);

      await tester.tap(find.byKey(const Key('inlandGateOutBtn')));
      await tester.pumpAndSettle();

      final posts = a.of('POST', 'gate-out');
      expect(posts, hasLength(1));
      final body = posts.single.data as Map;
      expect(body.containsKey('tracking_notes'), isFalse);
      expect(body.containsKey('notes'), isFalse);
      expect(body.containsKey('actual_departure_at'), isTrue);
      expect(find.text('Gate-out is not allowed in this state'), findsOneWidget);
    });
  });
}
