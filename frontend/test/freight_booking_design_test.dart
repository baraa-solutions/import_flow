import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/searchable_dropdown_field.dart';
import 'package:frontend/features/external_service_providers/models/partner_model.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/freight_booking/models/freight_booking_model.dart';
import 'package:frontend/features/freight_booking/providers/freight_booking_provider.dart';
import 'package:frontend/features/freight_booking/widgets/departure_confirmation_dialog.dart';
import 'package:frontend/features/freight_booking/widgets/freight_booking_form_dialog.dart';
import 'package:frontend/features/freight_booking/widgets/freight_booking_print_dialog.dart';
import 'package:frontend/features/freight_booking/widgets/freight_booking_ui.dart';
import 'package:frontend/features/freight_booking/widgets/freight_booking_view_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/shipping_scenarios/models/shipping_scenario_model.dart';
import 'package:frontend/features/shipping_scenarios/providers/shipping_scenarios_provider.dart';
import 'package:frontend/features/transport_locations/models/transport_location_model.dart';
import 'package:frontend/features/transport_locations/providers/transport_locations_provider.dart';

import 'helpers/localized_app.dart';

class _RecordingBookingNotifier extends StateNotifier<AsyncValue<List<ShipmentBookingModel>>>
    implements FreightBookingNotifier {
  _RecordingBookingNotifier() : super(const AsyncValue.data([]));
  final List<Map<String, dynamic>> created = [];
  final List<Map<String, dynamic>> updated = [];

  @override
  Future<void> fetchBookings({bool includeInactive = false, int? importFileId, String? status, String? search}) async {}

  @override
  Future<ShipmentBookingModel?> createBooking(Map<String, dynamic> payload) async {
    created.add(payload);
    return null;
  }

  @override
  Future<ShipmentBookingModel?> updateBooking(int id, Map<String, dynamic> payload) async {
    updated.add(payload);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImportFilesStub extends StateNotifier<AsyncValue<List<ImportFileModel>>> implements ImportFilesNotifier {
  _ImportFilesStub() : super(const AsyncValue.data([]));
  @override
  Future<void> fetchImportFiles({bool includeInactive = false, String? search, int? companyId, int? supplierId, String? status, String? owner}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PartnersStub extends StateNotifier<AsyncValue<List<PartnerModel>>> implements PartnersNotifier {
  _PartnersStub() : super(const AsyncValue.data([]));
  @override
  Future<void> fetchPartners({bool includeInactive = false, String? search, String? partnerType}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AllPartnersStub extends StateNotifier<AsyncValue<List<PartnerModel>>> implements AllPartnersNotifier {
  _AllPartnersStub() : super(const AsyncValue.data([]));
  @override
  Future<void> fetchPartners() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LocationsStub extends StateNotifier<AsyncValue<List<TransportLocationModel>>>
    implements TransportLocationsNotifier {
  _LocationsStub() : super(const AsyncValue.data([]));
  @override
  Future<void> fetchLocations({bool includeInactive = true, String? locationType, String? search}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScenariosStub extends StateNotifier<ShippingScenariosState> implements ShippingScenariosNotifier {
  _ScenariosStub() : super(ShippingScenariosState(sessions: <ShippingEvaluationModel>[]));
  @override
  Future<void> fetchSessions({String? search, int? projectId, int? poId, bool? showInactive}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PurchaseOrdersStub extends StateNotifier<PurchaseOrdersState> implements PurchaseOrdersNotifier {
  _PurchaseOrdersStub() : super(PurchaseOrdersState());
  @override
  Future<void> fetchPurchaseOrders({int? supplierId, int? companyId, int? projectId, String? status, String? search}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ShipmentBookingModel _booking({String status = 'Draft', String? line}) => ShipmentBookingModel(
      bookingId: 7,
      bookingCode: 'BK-2026-0007',
      shippingLineName: line,
      etd: '2026-10-01T00:00:00Z',
      eta: '2026-10-20T00:00:00Z',
      containersData: [ContainerAllocationModel(containerType: '40HC', quantity: 2)],
      costChargesData: [
        BookingChargeModel(chargeType: 'Sea Freight 40ft', quantity: 2, rate: 3000, total: 6000),
      ],
      totalFreightCostUsd: 6000,
      originalFreightCostUsd: 6500,
      costSavingsUsd: 500,
      costVarianceUsd: 500,
      status: status,
      isActive: true,
      createdAt: '2026-09-01T00:00:00Z',
      updatedAt: '2026-09-01T00:00:00Z',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FbkFormat / FbkUi helpers', () {
    test('isoDate cuts ISO strings and falls back to an em dash', () {
      expect(FbkFormat.isoDate('2026-10-01T00:00:00Z'), '2026-10-01');
      expect(FbkFormat.isoDate(null), '—');
      expect(FbkFormat.isoDate('2026'), '—');
    });

    test('containers joins quantity x type and shows a dash when empty', () {
      expect(FbkFormat.containers(_booking()), '2x 40HC');
      final empty = ShipmentBookingModel(
        bookingId: 1,
        bookingCode: 'BK-1',
        status: 'Draft',
        isActive: true,
        createdAt: '',
        updatedAt: '',
      );
      expect(FbkFormat.containers(empty), '—');
    });

    test('orDash replaces missing and blank values', () {
      expect(FbkFormat.orDash(null), '—');
      expect(FbkFormat.orDash('  '), '—');
      expect(FbkFormat.orDash('MSC'), 'MSC');
    });

    test('a booking without an owner no longer invents one', () {
      final m = ShipmentBookingModel.fromJson({
        'booking_id': 1,
        'booking_code': 'BK-1',
        'status': 'Draft',
        'is_active': true,
        'created_at': '',
        'updated_at': '',
      });
      expect(m.owner, '');
    });
  });

  Widget host(Widget child, {Locale locale = AppLocales.english, _RecordingBookingNotifier? notifier}) {
    return ProviderScope(
      overrides: [
        freightBookingProvider.overrideWith((ref) => notifier ?? _RecordingBookingNotifier()),
        importFilesProvider.overrideWith((ref) => _ImportFilesStub()),
        partnersProvider.overrideWith((ref) => _PartnersStub()),
        allPartnersProvider.overrideWith((ref) => _AllPartnersStub()),
        transportLocationsProvider.overrideWith((ref) => _LocationsStub()),
        shippingScenariosProvider.overrideWith((ref) => _ScenariosStub()),
        purchaseOrdersProvider.overrideWith((ref) => _PurchaseOrdersStub()),
      ],
      child: localizedApp(home: Scaffold(body: child), locale: locale),
    );
  }

  group('FreightBookingFormDialog - no fabricated defaults', () {
    testWidgets('a new booking opens empty and blocks saving with validators', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final notifier = _RecordingBookingNotifier();

      await tester.pumpWidget(host(const FreightBookingFormDialog(), notifier: notifier));
      await tester.pump(const Duration(milliseconds: 200));

      // None of the old sample values may be prefilled.
      for (final sample in ['MSC-CN-889001', 'MSC Oscar', 'VY-2026-X8', 'RO-MSC-9912', 'Kamal', 'Shanghai Port', 'El-Ahram']) {
        expect(find.textContaining(sample), findsNothing, reason: sample);
      }
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('fbkFormSaveBtn')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Select the import file'), findsOneWidget);
      expect(find.text('Select the shipping line'), findsOneWidget);
      expect(find.text('Select the port of loading'), findsOneWidget);
      expect(find.text('Select the port of discharge'), findsOneWidget);
      expect(find.text('Pick the estimated departure date'), findsOneWidget);
      expect(find.text('Pick the estimated arrival date'), findsOneWidget);
      expect(find.text('Enter a whole number of days (0 or more)'), findsOneWidget);
      expect(notifier.created, isEmpty, reason: 'invalid form must not reach the API');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a clone opens as a NEW booking: create path, no source status / numbers', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final notifier = _RecordingBookingNotifier();
      final source = ShipmentBookingModel(
        bookingId: 0,
        bookingCode: 'BK-DRAFT-1',
        bookingConfirmationNo: 'OLD-CONF',
        billOfLadingNo: 'OLD-BL',
        importFileId: 5,
        shippingLineName: 'Test Line',
        polName: 'Port A',
        podName: 'Port B',
        vesselName: 'OLD VESSEL',
        voyageNumber: 'OLD-VOY',
        etd: '2026-10-01T00:00:00Z',
        eta: '2026-10-20T00:00:00Z',
        atd: '2026-10-02T00:00:00Z',
        status: 'Confirmed',
        freeDemurrageDays: 14,
        isActive: true,
        createdAt: '',
        updatedAt: '',
      );

      await tester.pumpWidget(host(FreightBookingFormDialog(bookingToEdit: source, isClone: true), notifier: notifier));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('OLD-CONF'), findsNothing);
      expect(find.textContaining('OLD VESSEL'), findsNothing);

      await tester.enterText(find.byType(TextFormField).first, 'NEW-1');
      await tester.tap(find.byKey(const Key('fbkFormSaveBtn')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(notifier.created, hasLength(1));
      final p = notifier.created.single;
      expect(p['status'], 'Draft');
      expect(p['booking_confirmation_no'], 'NEW-1');
      expect(p['atd'], isNull);
      expect(p['vessel_name'], '');
      expect(p.containsKey('bill_of_lading_no'), isFalse);
      expect(p.containsKey('booking_id'), isFalse);
    });

    testWidgets('renders the cost tab with the 16 booking items (no insurance row) without overflow on a compact window (800x900)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(host(const FreightBookingFormDialog(), locale: AppLocales.arabic));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      final l = AppLocalizations.of(tester.element(find.byType(FreightBookingFormDialog)));
      await tester.tap(find.text(l.freightBookingTabCostBreakdown));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(Switch), findsNWidgets(16)); // insurance has no row (ACC3-T02)
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing container type from 40HC to 40GP keeps line tagged as 40GP and allows save', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final notifier = _RecordingBookingNotifier();
      final source = ShipmentBookingModel(
        bookingId: 1,
        bookingCode: 'BK-2026-0001',
        bookingConfirmationNo: 'CONF-1',
        importFileId: 5,
        shippingLineName: 'Test Line',
        polName: 'Port A',
        podName: 'Port B',
        etd: '2026-10-01T00:00:00Z',
        eta: '2026-10-20T00:00:00Z',
        status: 'Draft',
        freeDemurrageDays: 14,
        isActive: true,
        quotationDetailsData: {
          'container_40ft_app': true,
          'container_40ft_price': 2000.0,
          'container_40ft_qty': 2,
          'container_40ft_cur': 'USD',
          'original_quote_total_usd': 4000.0,
        },
        containersData: [
          ContainerAllocationModel(containerType: '40HC', quantity: 2),
        ],
        costChargesData: [
          BookingChargeModel(
            chargeType: 'Sea Freight 40ft',
            quantity: 2,
            rate: 2000,
            total: 4000,
            containerType: '40HC',
          ),
        ],
        createdAt: '2026-09-01T00:00:00Z',
        updatedAt: '2026-09-01T00:00:00Z',
      );

      await tester.pumpWidget(host(FreightBookingFormDialog(bookingToEdit: source), notifier: notifier));
      await tester.pump(const Duration(milliseconds: 200));

      final dropdownFinder = find.byWidgetPredicate(
        (w) => w is SearchableDropdownField<String> && w.items.any((item) => item.value == '40GP'),
      );
      expect(dropdownFinder, findsOneWidget);
      final dd = tester.widget<SearchableDropdownField<String>>(dropdownFinder);
      dd.onChanged!('40GP');
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('fbkQuoteEquipmentMismatchNotice')), findsNothing);

      await tester.tap(find.byKey(const Key('fbkFormSaveBtn')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(notifier.updated, hasLength(1));
      final payload = notifier.updated.single;
      final charges = (payload['cost_charges_data'] as List).cast<Map<String, dynamic>>();
      final c40 = charges.firstWhere((c) => c['charge_type'] == 'Sea Freight 40ft');
      expect(c40['container_type'], '40GP');
      expect(c40['total'], 4000.0);
    });

    testWidgets('changing container type from 40HC to 20GP blocks save with mismatch notice', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final notifier = _RecordingBookingNotifier();
      final source = ShipmentBookingModel(
        bookingId: 1,
        bookingCode: 'BK-2026-0001',
        bookingConfirmationNo: 'CONF-1',
        importFileId: 5,
        shippingLineName: 'Test Line',
        polName: 'Port A',
        podName: 'Port B',
        etd: '2026-10-01T00:00:00Z',
        eta: '2026-10-20T00:00:00Z',
        status: 'Draft',
        freeDemurrageDays: 14,
        isActive: true,
        quotationDetailsData: {
          'container_40ft_app': true,
          'container_40ft_price': 2000.0,
          'container_40ft_qty': 2,
          'container_40ft_cur': 'USD',
          'original_quote_total_usd': 4000.0,
        },
        containersData: [
          ContainerAllocationModel(containerType: '40HC', quantity: 2),
        ],
        costChargesData: [
          BookingChargeModel(
            chargeType: 'Sea Freight 40ft',
            quantity: 2,
            rate: 2000,
            total: 4000,
            containerType: '40HC',
          ),
        ],
        createdAt: '2026-09-01T00:00:00Z',
        updatedAt: '2026-09-01T00:00:00Z',
      );

      await tester.pumpWidget(host(FreightBookingFormDialog(bookingToEdit: source), notifier: notifier));
      await tester.pump(const Duration(milliseconds: 200));

      final dropdownFinder = find.byWidgetPredicate(
        (w) => w is SearchableDropdownField<String> && w.items.any((item) => item.value == '20GP'),
      );
      expect(dropdownFinder, findsOneWidget);
      final dd = tester.widget<SearchableDropdownField<String>>(dropdownFinder);
      dd.onChanged!('20GP');
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('fbkQuoteEquipmentMismatchNotice')), findsOneWidget);

      await tester.tap(find.byKey(const Key('fbkFormSaveBtn')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(notifier.created, isEmpty, reason: 'save must be blocked when equipment does not match quoted sizes');
      expect(notifier.updated, isEmpty, reason: 'update must be blocked when equipment does not match quoted sizes');
    });
  });

  group('read-only dialogs and SH-01', () {
    testWidgets('view dialog shows the saved booking and the savings comparison', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(FreightBookingViewDialog(booking: _booking(status: 'Confirmed', line: 'Test Line'))));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('BK-2026-0007'), findsWidgets);
      expect(find.text('Test Line'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('print dialog renders the manifest on a compact window (800x900)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(FreightBookingPrintDialog(booking: _booking(line: 'Test Line'))));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('departure dialog never invents a carrier or route', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(DepartureConfirmationDialog(booking: _booking(status: 'Confirmed'))));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Shipping line: —'), findsOneWidget);
      expect(find.text('Route: — ➔ —'), findsOneWidget);
      expect(find.textContaining('MSC'), findsNothing);

      // B/L number is required.
      await tester.tap(find.byKey(const Key('fbkDepartureConfirmBtn')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Please enter the bill of lading number'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

}
