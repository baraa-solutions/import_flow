import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/inland_transport/models/inland_transport_model.dart';
import 'package:frontend/features/inland_transport/widgets/inland_transport_dialog.dart';

class _MockAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, ResponseBody Function(RequestOptions)> routes = {};

  static ResponseBody jsonBody(Object? body, [int status = 200]) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  _MockAdapter on(String key, ResponseBody Function(RequestOptions) f) {
    routes[key] = f;
    return this;
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    for (final e in routes.entries) {
      final sp = e.key.indexOf(' ');
      final method = e.key.substring(0, sp);
      final pathPart = e.key.substring(sp + 1);
      if (options.method == method && options.uri.path.contains(pathPart)) {
        return e.value(options);
      }
    }
    return jsonBody(null, 200);
  }

  @override
  void close({bool force = false}) {}
}

Dio _mockDio(_MockAdapter a) => Dio(BaseOptions(validateStatus: (s) => s != null && s >= 200 && s < 300))..httpClientAdapter = a;

List<Override> _mockOverrides(_MockAdapter a) {
  final d = _mockDio(a);
  return [
    dioProvider.overrideWithValue(d),
    uploadDioProvider.overrideWithValue(d),
  ];
}

ImportFileModel _sampleFile({int id = 77, String? port = 'Alexandria Port'}) {
  return ImportFileModel(
    importFileId: id,
    importFileCode: 'IMP-2026-$id',
    companyName: 'Al-Rowad Logistics',
    supplierName: 'Global Cargo Supplies',
    portOfDischarge: port,
    inlandTransportStatus: 'Booking Confirmed',
    currentModule: 'Inland Transport',
    currentStage: 'Coordination',
    progressPercent: 50.0,
    nextAction: 'تنسيق النقل الداخلي',
    createdAt: '2026-10-01T08:00:00Z',
    updatedAt: '2026-10-01T08:00:00Z',
  );
}

void main() {
  group('FE08-T13: Helper & Model Tests', () {
    test('inlandEventPayload builds gate-out payload with optional gate_pass_no', () {
      final now = DateTime(2026, 10, 9, 14, 30);
      final payloadWithPass = inlandEventPayload(
        timeKey: 'actual_departure_at',
        at: now,
        notesText: 'Leaving terminal',
        gatePassNo: 'GP-9922-PORT',
      );

      expect(payloadWithPass['actual_departure_at'], now.toIso8601String());
      expect(payloadWithPass['notes'], 'Leaving terminal');
      expect(payloadWithPass['gate_pass_no'], 'GP-9922-PORT');

      final payloadWithoutPass = inlandEventPayload(
        timeKey: 'actual_departure_at',
        at: now,
        notesText: '',
        gatePassNo: '',
      );

      expect(payloadWithoutPass.containsKey('gate_pass_no'), isFalse);
      expect(payloadWithoutPass.containsKey('notes'), isFalse);
    });

    test('inlandEventPayload builds warehouse arrival payload with seal verification', () {
      final now = DateTime(2026, 10, 9, 18, 45);

      // Seal intact
      final payloadIntact = inlandEventPayload(
        timeKey: 'actual_arrival_at',
        at: now,
        notesText: 'Arrived smoothly',
        sealIntact: true,
        sealNumber: 'SEAL-112233',
      );
      expect(payloadIntact['actual_arrival_at'], now.toIso8601String());
      expect(payloadIntact['seal_intact'], isTrue);
      expect(payloadIntact['seal_number'], 'SEAL-112233');

      // Seal broken
      final payloadBroken = inlandEventPayload(
        timeKey: 'actual_arrival_at',
        at: now,
        notesText: 'Discrepancy at inspection',
        sealIntact: false,
        sealNumber: 'SEAL-BROKEN-99',
      );
      expect(payloadBroken['seal_intact'], isFalse);
      expect(payloadBroken['seal_number'], 'SEAL-BROKEN-99');
      expect(payloadBroken['notes'], 'Discrepancy at inspection');
    });

    test('InlandTransportModel destinationWarehouse defaults to empty string (no hardcoded Cairo fallback)', () {
      final model = InlandTransportModel(
        transportId: 1,
        transportCode: 'TR-01',
        importFileId: 5,
        waybillNumber: 'WB-01',
        bookingDate: '2026-10-09',
        carrierName: 'Carrier 1',
        truckPlateNumber: '123 ABC',
        driverName: 'Driver 1',
        driverPhone: '01011112222',
        pickupPortLocation: 'Dekheila',
        plannedDepartureAt: '2026-10-09T10:00:00Z',
        expectedArrivalAt: '2026-10-09T16:00:00Z',
        createdAt: '2026-10-09T08:00:00Z',
        updatedAt: '2026-10-09T08:00:00Z',
      );
      expect(model.destinationWarehouse, '');

      final fromJson = InlandTransportModel.fromJson({
        'transport_id': 2,
        'transport_code': 'TR-02',
        'import_file_id': 6,
        'waybill_number': 'WB-02',
        'carrier_name': 'Carrier 2',
        'truck_plate_number': '456 XYZ',
        'driver_name': 'Driver 2',
        'driver_phone': '01022223333',
        'pickup_port_location': 'Dekheila',
        'planned_departure_at': '2026-10-09T10:00:00Z',
        'expected_arrival_at': '2026-10-09T16:00:00Z',
        'created_at': '2026-10-09T08:00:00Z',
        'updated_at': '2026-10-09T08:00:00Z',
      });
      expect(fromJson.destinationWarehouse, '');
    });
  });

  // ---------------------------------------------------------------------------
  // AC: "the create payload contains carrier_id and the chosen hour"
  // ---------------------------------------------------------------------------
  group('FE08-T13: Submit Payload Integration', () {
    testWidgets(
        'Submit booking sends carrier_id and chosen departure hour in POST body',
        (tester) async {
      // Captures the POST body for assertion
      RequestOptions? capturedPost;

      final createdBookingJson = {
        'transport_id': 201,
        'transport_code': 'TR-2026-0201',
        'import_file_id': 55,
        'waybill_number': 'WB-TEST-01',
        'booking_date': '2026-10-09',
        'carrier_id': 10,
        'carrier_name': 'Nile Transport Co',
        'truck_plate_number': '123 ABC',
        'truck_type': 'FLATBED',
        'driver_name': 'Test Driver',
        'driver_phone': '01011112222',
        'pickup_port_location': 'Dekheila Sea Port',
        'destination_warehouse': 'Main Warehouse',
        'planned_departure_at': '2026-10-09T10:00:00.000',
        'expected_arrival_at': '2026-10-09T16:00:00.000',
        'transport_fare_egp': 3500.0,
        'status': 'Booking Confirmed',
        'is_active': true,
        'created_at': '2026-10-09T08:00:00Z',
        'updated_at': '2026-10-09T08:00:00Z',
      };

      final adapter = _MockAdapter()
        // No existing booking → dialog opens create form
        ..on('GET /inland-transport/bookings/by-file/55',
            (r) => _MockAdapter.jsonBody(null, 200))
        ..on(
            'GET /external-service-providers',
            (r) => _MockAdapter.jsonBody([
                  {
                    'provider_id': 10,
                    'partner_code': 'PR-10',
                    'partner_name': 'Nile Transport Co',
                    'partner_type': 'Inland Transport',
                    'is_active': true,
                  },
                ]))
        ..on(
            'GET /transport-locations',
            (r) => _MockAdapter.jsonBody([
                  {
                    'location_id': 101,
                    'location_name': 'Dekheila Sea Port',
                    'un_locode': 'EGEDK',
                    'location_type': 'Sea Port',
                    'country': 'Egypt',
                    'city': 'Alexandria',
                    'is_active': true,
                  },
                ]));

      // Intercept POST: capture body and return the created booking
      adapter.routes['POST /inland-transport/bookings'] = (r) {
        capturedPost = r;
        return _MockAdapter.jsonBody(createdBookingJson);
      };
      // fetchBookings() called after create succeeds
      adapter.routes['GET /inland-transport/bookings'] =
          (r) => _MockAdapter.jsonBody([]);

      // 2400px tall surface: entire form is visible without clipping.
      // This avoids hit-test misses on the Submit button.
      await tester.binding.setSurfaceSize(const Size(1200, 2400));

      await tester.pumpWidget(
        ProviderScope(
          overrides: _mockOverrides(adapter),
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Scaffold(
                body: InlandTransportDialog(
                    file: _sampleFile(id: 55, port: 'Dekheila Sea Port')),
              ),
            ),
          ),
        ),
      );

      // Wait for GET by-file → null response → create form renders
      await tester.pumpAndSettle();

      // ── 1. Fill required text fields ─────────────────────────────────────
      await tester.enterText(
          find.byKey(const Key('inlandWaybillNoField')), 'WB-TEST-01');
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('inlandTruckPlateField')), '123 ABC');
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('inlandDriverNameField')), 'Test Driver');
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('inlandDriverPhoneField')), '01011112222');
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('inlandFareEgpField')), '3500');
      await tester.pumpAndSettle();

      // ── 2. Pick carrier ───────────────────────────────────────────────────
      // The dialog wraps content in a SingleChildScrollView. Scroll until the
      // carrier dropdown is visible before tapping it.
      await tester.scrollUntilVisible(
        find.byKey(const Key('inlandCarrierDropdown')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const Key('inlandCarrierDropdown')));
      await tester.pumpAndSettle();

      // The search dialog opens with the partner list
      expect(find.text('Nile Transport Co'), findsWidgets);
      await tester.tap(find.text('Nile Transport Co').last);
      await tester.pumpAndSettle();

      // ── 3. Pick pickup location ───────────────────────────────────────────
      await tester.scrollUntilVisible(
        find.byKey(const Key('inlandPickupLocationDropdown')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const Key('inlandPickupLocationDropdown')));
      await tester.pumpAndSettle();

      expect(find.text('Dekheila Sea Port (EGEDK)'), findsWidgets);
      await tester.tap(find.text('Dekheila Sea Port (EGEDK)').last);
      await tester.pumpAndSettle();

      // ── 4. Fill destination warehouse ────────────────────────────────────
      final warehouseField = find.ancestor(
        of: find.byIcon(Icons.warehouse),
        matching: find.byType(TextFormField),
      );
      await tester.scrollUntilVisible(
        warehouseField.first,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.enterText(warehouseField.first, 'Main Warehouse');
      await tester.pumpAndSettle();

      // ── 5. Tap Submit ────────────────────────────────────────────────────
      await tester.scrollUntilVisible(
        find.byKey(const Key('inlandSubmitBookingBtn')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const Key('inlandSubmitBookingBtn')));
      await tester.pumpAndSettle();

      // ── 6. Assert POST body ───────────────────────────────────────────────
      expect(capturedPost, isNotNull,
          reason: 'POST /inland-transport/bookings should have been called');

      final body = capturedPost!.data as Map<String, dynamic>;

      // AC: carrier_id must be 10 (Nile Transport Co)
      expect(body['carrier_id'], equals(10),
          reason: 'carrier_id must be 10 for "Nile Transport Co"');

      // carrier_name must also be present
      expect(body['carrier_name'], equals('Nile Transport Co'));

      // AC: planned_departure_at must encode the hour the user chose (default 10:00)
      final departureIso = body['planned_departure_at'] as String;
      final departureDt = DateTime.parse(departureIso);
      expect(departureDt.hour, equals(10),
          reason: 'planned_departure_at should encode hour=10 (the default)');
    });
  });


  // ---------------------------------------------------------------------------

  group('FE08-T13: Dialog UI & Master Data Integration Tests', () {
    testWidgets('Renders real master data carrier and location dropdowns in booking form', (tester) async {
      final adapter = _MockAdapter()
        ..on('GET /inland-transport/bookings/by-file/77', (r) => _MockAdapter.jsonBody(null, 200))
        ..on('GET /external-service-providers', (r) => _MockAdapter.jsonBody([
              {
                'provider_id': 10,
                'partner_code': 'PR-10',
                'partner_name': 'Nile Transport Co',
                'partner_type': 'Inland Transport',
                'is_active': true,
              },
              {
                'provider_id': 11,
                'partner_code': 'PR-11',
                'partner_name': 'Alexandria Express Trucking',
                'partner_type': 'Inland Transport',
                'is_active': true,
              },
            ]))
        ..on('GET /transport-locations', (r) => _MockAdapter.jsonBody([
              {
                'location_id': 101,
                'location_name': 'Dekheila Sea Port',
                'un_locode': 'EGEDK',
                'location_type': 'Sea Port',
                'country': 'Egypt',
                'city': 'Alexandria',
                'is_active': true,
              },
              {
                'location_id': 102,
                'location_name': 'Ain Sokhna Port',
                'un_locode': 'EGAIS',
                'location_type': 'Sea Port',
                'country': 'Egypt',
                'city': 'Suez',
                'is_active': true,
              },
            ]));

      await tester.binding.setSurfaceSize(const Size(1200, 950));

      await tester.pumpWidget(
        ProviderScope(
          overrides: _mockOverrides(adapter),
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Scaffold(
                body: InlandTransportDialog(file: _sampleFile(id: 77)),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Form header and dropdowns exist
      expect(find.byKey(const Key('inlandCarrierDropdown')), findsOneWidget);
      expect(find.byKey(const Key('inlandPickupLocationDropdown')), findsOneWidget);
      expect(find.byKey(const Key('inlandWaybillNoField')), findsOneWidget);
      expect(find.byKey(const Key('inlandTruckPlateField')), findsOneWidget);
      expect(find.byKey(const Key('inlandDriverNameField')), findsOneWidget);
      expect(find.byKey(const Key('inlandFareEgpField')), findsOneWidget);
    });

    testWidgets('Gate-out panel includes gate_pass_no field', (tester) async {
      final bookingJson = {
        'transport_id': 88,
        'transport_code': 'TR-2026-0088',
        'import_file_id': 77,
        'waybill_number': 'WB-8811',
        'booking_date': '2026-10-09',
        'carrier_id': 10,
        'carrier_name': 'Nile Transport Co',
        'truck_plate_number': '123 ط د ر',
        'truck_type': 'FLATBED',
        'driver_name': 'Ahmed Mahmoud',
        'driver_phone': '01012345678',
        'pickup_port_location': 'Dekheila Sea Port',
        'destination_warehouse': 'Warehouse 10th of Ramadan',
        'planned_departure_at': '2026-10-09T10:00:00Z',
        'expected_arrival_at': '2026-10-09T16:00:00Z',
        'transport_fare_egp': 4500.0,
        'status': 'Booking Confirmed',
        'is_active': true,
        'created_at': '2026-10-09T08:00:00Z',
        'updated_at': '2026-10-09T08:00:00Z',
      };

      final adapter = _MockAdapter()
        ..on('GET /inland-transport/bookings/by-file/77', (r) => _MockAdapter.jsonBody(bookingJson))
        ..on('GET /external-service-providers', (r) => _MockAdapter.jsonBody([]))
        ..on('GET /transport-locations', (r) => _MockAdapter.jsonBody([]));

      await tester.binding.setSurfaceSize(const Size(1200, 950));

      await tester.pumpWidget(
        ProviderScope(
          overrides: _mockOverrides(adapter),
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Scaffold(
                body: InlandTransportDialog(file: _sampleFile(id: 77)),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Gate-out panel and its gate pass field are visible
      expect(find.byKey(const Key('inlandGateOutBtn')), findsOneWidget);
      expect(find.byKey(const Key('inlandGatePassNoField')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('inlandGatePassNoField')), 'PASS-2026-DKH-001');
      await tester.pumpAndSettle();
      expect(find.text('PASS-2026-DKH-001'), findsOneWidget);
    });

    testWidgets('Warehouse arrival panel renders seal check switch and requires seal number when broken', (tester) async {
      final bookingJson = {
        'transport_id': 99,
        'transport_code': 'TR-2026-0099',
        'import_file_id': 77,
        'waybill_number': 'WB-9922',
        'booking_date': '2026-10-09',
        'carrier_id': 10,
        'carrier_name': 'Nile Transport Co',
        'truck_plate_number': '456 ع س م',
        'truck_type': 'FLATBED',
        'driver_name': 'Sami Hassan',
        'driver_phone': '01099887766',
        'pickup_port_location': 'Dekheila Sea Port',
        'destination_warehouse': 'Warehouse 10th of Ramadan',
        'planned_departure_at': '2026-10-09T10:00:00Z',
        'actual_departure_at': '2026-10-09T11:00:00Z',
        'expected_arrival_at': '2026-10-09T16:00:00Z',
        'transport_fare_egp': 4800.0,
        'status': 'In Transit (Gate-Out)',
        'is_active': true,
        'created_at': '2026-10-09T08:00:00Z',
        'updated_at': '2026-10-09T08:00:00Z',
      };

      final adapter = _MockAdapter()
        ..on('GET /inland-transport/bookings/by-file/77', (r) => _MockAdapter.jsonBody(bookingJson))
        ..on('GET /external-service-providers', (r) => _MockAdapter.jsonBody([]))
        ..on('GET /transport-locations', (r) => _MockAdapter.jsonBody([]));

      await tester.binding.setSurfaceSize(const Size(1200, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: _mockOverrides(adapter),
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Scaffold(
                body: InlandTransportDialog(file: _sampleFile(id: 77)),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Warehouse arrival panel and seal intact switch exist
      expect(find.byKey(const Key('inlandWarehouseArrivalBtn')), findsOneWidget);
      expect(find.byKey(const Key('inlandSealIntactSwitch')), findsOneWidget);
      expect(find.byKey(const Key('inlandSealNumberField')), findsOneWidget);

      // Toggle switch to false (broken seal)
      await tester.ensureVisible(find.byKey(const Key('inlandSealIntactSwitch')));
      await tester.tap(find.byKey(const Key('inlandSealIntactSwitch')));
      await tester.pumpAndSettle();

      // Attempting to submit arrival without entering seal number triggers validation toast
      await tester.ensureVisible(find.byKey(const Key('inlandWarehouseArrivalBtn')));
      await tester.tap(find.byKey(const Key('inlandWarehouseArrivalBtn')));
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال رقم السيل الجمركي عند عدم سلامة السيل أو تلفه'), findsOneWidget);

      // Now enter the seal number
      await tester.ensureVisible(find.byKey(const Key('inlandSealNumberField')));
      await tester.enterText(find.byKey(const Key('inlandSealNumberField')), 'SEAL-REPL-5544');
      await tester.pumpAndSettle();
      expect(find.text('SEAL-REPL-5544'), findsOneWidget);
    });
  });
}
