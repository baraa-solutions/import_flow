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
      'pickup_port_location': 'Alexandria Port',
      'destination_warehouse': 'Cairo WH',
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

void main() {
  group('InlandStatus mappings (FE08-T02)', () {
    test('codeOf resolves legacy and canonical status strings properly', () {
      expect(InlandStatus.codeOf('Booking Confirmed'), 'BOOKING_CONFIRMED');
      expect(InlandStatus.codeOf('BOOKING_CONFIRMED'), 'BOOKING_CONFIRMED');
      expect(InlandStatus.codeOf('In Transit (Gate-Out)'), 'IN_TRANSIT');
      expect(InlandStatus.codeOf('IN_TRANSIT'), 'IN_TRANSIT');
      expect(InlandStatus.codeOf('Arrived Warehouse'), 'ARRIVED_AT_WAREHOUSE');
      expect(InlandStatus.codeOf('ARRIVED_AT_WAREHOUSE'), 'ARRIVED_AT_WAREHOUSE');
      expect(InlandStatus.codeOf('Delivered'), 'DELIVERED');
      expect(InlandStatus.codeOf('DELIVERED'), 'DELIVERED');
      expect(InlandStatus.codeOf('Cancelled'), 'CANCELLED');
      expect(InlandStatus.codeOf('CANCELLED'), 'CANCELLED');
      expect(InlandStatus.codeOf(''), '');
      expect(InlandStatus.codeOf(null), '');
    });

    test('predicates match correctly', () {
      expect(InlandStatus.isBookingConfirmedOrDispatched('Booking Confirmed'), isTrue);
      expect(InlandStatus.isBookingConfirmedOrDispatched('DISPATCHED'), isTrue);
      expect(InlandStatus.isBookingConfirmedOrDispatched('IN_TRANSIT'), isFalse);

      expect(InlandStatus.isInTransit('In Transit (Gate-Out)'), isTrue);
      expect(InlandStatus.isInTransit('IN_TRANSIT'), isTrue);
      expect(InlandStatus.isInTransit('Booking Confirmed'), isFalse);

      expect(InlandStatus.isArrivedOrDelivered('Arrived Warehouse'), isTrue);
      expect(InlandStatus.isArrivedOrDelivered('ARRIVED_AT_WAREHOUSE'), isTrue);
      expect(InlandStatus.isArrivedOrDelivered('Delivered'), isTrue);
      expect(InlandStatus.isArrivedOrDelivered('DELIVERED'), isTrue);
      expect(InlandStatus.isArrivedOrDelivered('IN_TRANSIT'), isFalse);
    });
  });

  group('InlandTransportDialog UI status buttons & edit mode (FE08-T02, FE08-T03)', () {
    Future<void> openDialog(WidgetTester tester, _Adapter a) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dio = _dio(a);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(dio),
            uploadDioProvider.overrideWithValue(dio),
          ],
          child: MaterialApp(
            locale: AppLocales.en,
            localizationsDelegates: AppLocales.delegates,
            supportedLocales: AppLocales.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => InlandTransportDialog.show(ctx, _file()),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows arrival panel and arrival button when status is IN_TRANSIT', (tester) async {
      final a = _Adapter()..on('GET /by-file/3', (_) => _Adapter.json(_bookingJson(status: 'IN_TRANSIT')));
      await openDialog(tester, a);

      expect(find.byKey(const Key('inlandWarehouseArrivalBtn')), findsOneWidget);
      expect(find.byKey(const Key('inlandGateOutBtn')), findsNothing);
    });

    testWidgets('shows arrival panel and arrival button when status is legacy "In Transit (Gate-Out)"', (tester) async {
      final a = _Adapter()..on('GET /by-file/3', (_) => _Adapter.json(_bookingJson(status: 'In Transit (Gate-Out)')));
      await openDialog(tester, a);

      expect(find.byKey(const Key('inlandWarehouseArrivalBtn')), findsOneWidget);
      expect(find.byKey(const Key('inlandGateOutBtn')), findsNothing);
    });

    testWidgets('hides edit button when status is ARRIVED_AT_WAREHOUSE', (tester) async {
      final a = _Adapter()..on('GET /by-file/3', (_) => _Adapter.json(_bookingJson(status: 'ARRIVED_AT_WAREHOUSE')));
      await openDialog(tester, a);

      expect(find.byKey(const Key('inlandEditBookingBtn')), findsNothing);
      expect(find.text('Goods have arrived at warehouse'), findsOneWidget);
    });

    testWidgets('edit booking toggles edit form and submits PUT to update booking', (tester) async {
      final a = _Adapter()
        ..on('GET /by-file/3', (_) => _Adapter.json(_bookingJson(status: 'BOOKING_CONFIRMED')))
        ..on('PUT /bookings/4', (req) => _Adapter.json(_bookingJson(status: 'BOOKING_CONFIRMED')));
      await openDialog(tester, a);

      // Verify Edit button is present
      expect(find.byKey(const Key('inlandEditBookingBtn')), findsOneWidget);

      // Tap Edit button to expand form in edit mode
      await tester.tap(find.byKey(const Key('inlandEditBookingBtn')));
      await tester.pumpAndSettle();

      // Submit button should say Save Changes
      expect(find.text('Save Changes'), findsOneWidget);

      // Tap Save Changes
      await tester.tap(find.byKey(const Key('inlandSubmitBookingBtn')));
      await tester.pumpAndSettle();

      // Verify that PUT /inland-transport/bookings/4 was executed (NOT POST /bookings)
      final puts = a.of('PUT', 'bookings/4');
      expect(puts, hasLength(1));
      final posts = a.of('POST', 'bookings');
      expect(posts, isEmpty);
    });
  });
}
