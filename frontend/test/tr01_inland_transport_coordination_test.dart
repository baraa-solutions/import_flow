import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/inland_transport/models/inland_transport_model.dart';
import 'package:frontend/features/inland_transport/widgets/inland_transport_dialog.dart';

/// No booking exists for the file: the by-file lookup answers 200 with an empty body, so the
/// dialog offers the create form. (Without a backend the lookup fails and the dialog shows the
/// error + retry instead of the form, FE-06.)
class _NoBookingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString('null', 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

List<Override> _noBookingOverrides() {
  final dio = Dio(BaseOptions(validateStatus: (s) => s != null && s >= 200 && s < 300))
    ..httpClientAdapter = _NoBookingAdapter();
  return [dioProvider.overrideWithValue(dio), uploadDioProvider.overrideWithValue(dio)];
}

void main() {
  group('TR-01: Inland Transport Coordination Model Tests', () {
    test('InlandTransportModel parses from JSON and serializes to JSON correctly', () {
      final json = {
        'transport_id': 15,
        'transport_code': 'TR-2026-0015',
        'import_file_id': 95,
        'waybill_number': 'WB-2026-EDK-5511',
        'booking_date': '2026-09-18',
        'carrier_id': 14,
        'carrier_name': 'شركة النيل لنقل البضائع واللوجستيات',
        'truck_plate_number': 'ط د ر 7541 / د س 128',
        'truck_type': 'Flatbed Trailer (تريلا مسطح)',
        'driver_name': 'محمد أحمد السيد إبراهيم',
        'driver_phone': '01012345678',
        'driver_national_id': '28910150102345',
        'container_numbers': 'MSKU9876543, MEDU1234567',
        'pickup_port_location': 'El Dekheila Port - Alexandria',
        'destination_warehouse': 'Main Warehouse - Cairo (6th of October)',
        'planned_departure_at': '2026-09-18T10:00:00Z',
        'actual_departure_at': '2026-09-18T11:30:00Z',
        'expected_arrival_at': '2026-09-18T16:00:00Z',
        'actual_arrival_at': '2026-09-18T17:15:00Z',
        'transport_fare_egp': 4500.00,
        'status': 'Arrived Warehouse',
        'tracking_notes': 'تم التحميل والخروج بسلام ووصول رصيف التعتيق بالمخزن',
        'is_active': true,
        'created_at': '2026-09-18T08:00:00Z',
        'updated_at': '2026-09-18T17:20:00Z',
      };

      final model = InlandTransportModel.fromJson(json);

      expect(model.transportId, 15);
      expect(model.transportCode, 'TR-2026-0015');
      expect(model.importFileId, 95);
      expect(model.waybillNumber, 'WB-2026-EDK-5511');
      expect(model.bookingDate, '2026-09-18');
      expect(model.carrierId, 14);
      expect(model.carrierName, 'شركة النيل لنقل البضائع واللوجستيات');
      expect(model.truckPlateNumber, 'ط د ر 7541 / د س 128');
      expect(model.truckType, 'Flatbed Trailer (تريلا مسطح)');
      expect(model.driverName, 'محمد أحمد السيد إبراهيم');
      expect(model.driverPhone, '01012345678');
      expect(model.driverNationalId, '28910150102345');
      expect(model.containerNumbers, 'MSKU9876543, MEDU1234567');
      expect(model.pickupPortLocation, 'El Dekheila Port - Alexandria');
      expect(model.destinationWarehouse, 'Main Warehouse - Cairo (6th of October)');
      expect(model.transportFareEgp, 4500.00);
      expect(model.status, 'Arrived Warehouse');
      expect(model.trackingNotes, 'تم التحميل والخروج بسلام ووصول رصيف التعتيق بالمخزن');
      expect(model.isActive, true);

      final serialized = model.toJson();
      expect(serialized['transport_code'], 'TR-2026-0015');
      expect(serialized['waybill_number'], 'WB-2026-EDK-5511');
      expect(serialized['carrier_name'], 'شركة النيل لنقل البضائع واللوجستيات');
      expect(serialized['truck_plate_number'], 'ط د ر 7541 / د س 128');
      expect(serialized['driver_name'], 'محمد أحمد السيد إبراهيم');
      expect(serialized['transport_fare_egp'], 4500.00);
      expect(serialized['status'], 'Arrived Warehouse');

      final updated = model.copyWith(status: 'In Transit (Gate-Out)', transportFareEgp: 5000.00);
      expect(updated.status, 'In Transit (Gate-Out)');
      expect(updated.transportFareEgp, 5000.00);
      expect(updated.transportCode, 'TR-2026-0015');
    });

    test('ImportFileModel correctly integrates inland transport fields', () {
      final fileJson = {
        'import_file_id': 95,
        'import_file_code': 'IMP-2026-0095',
        'company_name': 'Delta Industrial Machinery LLC',
        'supplier_name': 'Bavaria Tech GmbH',
        'current_module': 'Phase 8 - Inland Transport & Receiving',
        'current_stage': 'Inland Transport Coordination (تنسيق وحجز النقل الداخلي)',
        'progress_percent': 98.0,
        'next_action': 'تأكيد خروج الشاحنة من بوابة الميناء (Gate-Out)',
        'inland_transport_status': 'Booking Confirmed',
        'inland_transport_booking_no': 'WB-2026-EDK-5511',
        'inland_carrier_name': 'شركة النيل للنقل البري',
        'inland_truck_plate_no': 'ط د ر 7541',
        'inland_driver_name': 'محمد أحمد إبراهيم',
        'inland_driver_phone': '01012345678',
        'inland_transport_cost_egp': 4500.00,
        'inland_departure_date': '2026-09-18T10:00:00Z',
        'inland_expected_arrival_date': '2026-09-18T16:00:00Z',
        'created_at': '2026-09-18T08:00:00Z',
        'updated_at': '2026-09-18T14:00:00Z',
      };

      final file = ImportFileModel.fromJson(fileJson);
      expect(file.inlandTransportStatus, 'Booking Confirmed');
      expect(file.inlandTransportBookingNo, 'WB-2026-EDK-5511');
      expect(file.inlandCarrierName, 'شركة النيل للنقل البري');
      expect(file.inlandTruckPlateNo, 'ط د ر 7541');
      expect(file.inlandDriverName, 'محمد أحمد إبراهيم');
      expect(file.inlandDriverPhone, '01012345678');
      expect(file.inlandTransportCostEgp, 4500.00);

      final serialized = file.toJson();
      expect(serialized['inland_transport_status'], 'Booking Confirmed');
      expect(serialized['inland_transport_booking_no'], 'WB-2026-EDK-5511');
      expect(serialized['inland_carrier_name'], 'شركة النيل للنقل البري');
      expect(serialized['inland_truck_plate_no'], 'ط د ر 7541');
      expect(serialized['inland_transport_cost_egp'], 4500.00);
    });
  });

  group('TR-01: InlandTransportDialog Widget Tests', () {
    testWidgets('Renders InlandTransportDialog with header, KPIs, form and auto waybill button', (tester) async {
      final sampleFile = ImportFileModel(
        importFileId: 95,
        importFileCode: 'IMP-2026-0095',
        customFileNumber: 'Industrial Machinery',
        companyName: 'Delta Industrial Machinery LLC',
        supplierName: 'Bavaria Tech GmbH',
        portOfDischarge: 'El Dekheila Port (non TMT)',
        inlandTransportStatus: 'Booking Confirmed',
        inlandTransportBookingNo: 'WB-2026-EDK-5511',
        inlandCarrierName: 'شركة النيل للنقل البري',
        inlandTruckPlateNo: 'ط د ر 7541 / د س 128',
        inlandDriverName: 'محمد أحمد السيد إبراهيم',
        inlandDriverPhone: '01012345678',
        inlandTransportCostEgp: 4500.00,
        currentModule: 'Phase 8 - Inland Transport & Warehouse Receiving',
        currentStage: 'Inland Transport Coordination (تنسيق وحجز سيارات النقل الداخلي)',
        progressPercent: 97.0,
        nextAction: 'تنسيق وحجز سيارات وسائقي النقل الداخلي (TR-01)',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T14:00:00Z',
      );

      await tester.binding.setSurfaceSize(const Size(1200, 950));

      await tester.pumpWidget(
        ProviderScope(
          overrides: _noBookingOverrides(),
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Scaffold(
                body: InlandTransportDialog(
                  file: sampleFile,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Header & Badges
      expect(find.text('تنسيق وحجز سيارات وسائقي النقل الداخلي (TR-01)'), findsOneWidget);
      expect(find.textContaining('IMP-2026-0095'), findsWidgets);

      // 2. KPI Cards
      expect(find.text('حالة النقل الداخلي'), findsOneWidget);
      expect(find.text('بوليصة النقل الداخلي'), findsOneWidget);
      expect(find.text('الشاحنة والسائق'), findsOneWidget);
      expect(find.text('نولون النقل بالجنيه المصري'), findsOneWidget);

      // 3. Form Section & Elements
      expect(find.text('نموذج حجز وتنسيق النقل الداخلي'), findsOneWidget);
      // The fabricated "auto waybill" button was removed: the user types the real waybill.
      expect(find.byKey(const Key('inlandAutoWaybillBtn')), findsNothing);
      expect(find.byKey(const Key('inlandWaybillNoField')), findsOneWidget);
      expect(find.byKey(const Key('inlandCarrierNameField')), findsOneWidget);
      expect(find.byKey(const Key('inlandTruckPlateField')), findsOneWidget);
      expect(find.byKey(const Key('inlandTruckTypeDropdown')), findsOneWidget);
      expect(find.byKey(const Key('inlandDriverNameField')), findsOneWidget);
      expect(find.byKey(const Key('inlandDriverPhoneField')), findsOneWidget);
      expect(find.byKey(const Key('inlandFareEgpField')), findsOneWidget);
      expect(find.byKey(const Key('inlandSubmitBookingBtn')), findsOneWidget);

      // 4. Fill and edit form inputs
      await tester.enterText(find.byKey(const Key('inlandCarrierNameField')), 'شركة الأهرام للنقل السريع');
      await tester.enterText(find.byKey(const Key('inlandTruckPlateField')), 'س ف ج 9123 / ق ر 45');
      await tester.enterText(find.byKey(const Key('inlandDriverNameField')), 'محمود علي الشاذلي');
      await tester.enterText(find.byKey(const Key('inlandDriverPhoneField')), '01223344556');
      await tester.enterText(find.byKey(const Key('inlandFareEgpField')), '5200.00');
      await tester.pumpAndSettle();

      expect(find.text('شركة الأهرام للنقل السريع'), findsOneWidget);
      expect(find.text('س ف ج 9123 / ق ر 45'), findsOneWidget);
      expect(find.text('محمود علي الشاذلي'), findsOneWidget);
      expect(find.text('01223344556'), findsOneWidget);
      expect(find.text('5200.00'), findsOneWidget);

      // 6. Verify Footer Note
      expect(
        find.text('تحديث فوري لنسبة إنجاز الملف ومزامنة شاشة تتبع الشحنات والمخزن'),
        findsOneWidget,
      );
    });

    testWidgets('Renders existing booking Gate-Out and Warehouse Arrival actions when booking exists', (tester) async {
      final sampleFile = ImportFileModel(
        importFileId: 96,
        importFileCode: 'IMP-2026-0096',
        companyName: 'Al-Amal Medical Supplies',
        supplierName: 'Siemens Healthineers',
        inlandTransportStatus: 'Booking Confirmed',
        inlandTransportBookingNo: 'WB-2026-ALX-8822',
        inlandCarrierName: 'شركة النيل للنقل',
        inlandTruckPlateNo: 'د س ق 8841',
        inlandDriverName: 'علي حسن إبراهيم',
        inlandDriverPhone: '01122334455',
        inlandTransportCostEgp: 6000.0,
        currentModule: 'Phase 8',
        currentStage: 'Inland Transport',
        progressPercent: 97.0,
        nextAction: 'Gate-Out',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T14:00:00Z',
      );

      await tester.binding.setSurfaceSize(const Size(1200, 950));

      await tester.pumpWidget(
        ProviderScope(
          overrides: _noBookingOverrides(),
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Scaffold(
                body: InlandTransportDialog(
                  file: sampleFile,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inlandAutoWaybillBtn')), findsNothing);
      expect(find.byKey(const Key('inlandSubmitBookingBtn')), findsOneWidget);
    });
  });
}
