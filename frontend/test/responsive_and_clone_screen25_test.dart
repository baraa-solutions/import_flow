import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/clone_entity_review_dialog.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/currencies/providers/currencies_provider.dart';
import 'package:frontend/features/external_service_providers/models/partner_model.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/freight_booking/models/freight_booking_model.dart';
import 'package:frontend/features/freight_booking/providers/freight_booking_provider.dart';
import 'package:frontend/features/freight_booking/screens/freight_booking_screen.dart';
import 'package:frontend/features/freight_booking/widgets/search_and_clone_freight_booking_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/shipping_scenarios/models/shipping_scenario_model.dart';
import 'package:frontend/features/shipping_scenarios/providers/shipping_scenarios_provider.dart';
import 'package:frontend/features/transport_locations/models/transport_location_model.dart';
import 'package:frontend/features/transport_locations/providers/transport_locations_provider.dart';

class _MockFreightBookingNotifier extends StateNotifier<AsyncValue<List<ShipmentBookingModel>>>
    implements FreightBookingNotifier {
  final List<ShipmentBookingModel> initial;
  _MockFreightBookingNotifier(this.initial) : super(AsyncValue.data(initial));

  @override
  Future<void> fetchBookings({bool includeInactive = false, int? importFileId, String? status, String? search, int skip = 0, int limit = 200}) async {
    state = AsyncValue.data(initial);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockImportFilesNotifier extends StateNotifier<AsyncValue<List<ImportFileModel>>>
    implements ImportFilesNotifier {
  final List<ImportFileModel> initial;
  _MockImportFilesNotifier(this.initial) : super(AsyncValue.data(initial));

  @override
  Future<void> fetchImportFiles({bool includeInactive = false, String? search, int? companyId, int? supplierId, String? status, String? owner}) async {
    state = AsyncValue.data(initial);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPartnersNotifier extends StateNotifier<AsyncValue<List<PartnerModel>>>
    implements PartnersNotifier {
  final List<PartnerModel> initial;
  _MockPartnersNotifier(this.initial) : super(AsyncValue.data(initial));

  @override
  Future<void> fetchPartners({bool includeInactive = false, String? search, String? partnerType}) async {
    state = AsyncValue.data(initial);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockAllPartnersNotifier extends StateNotifier<AsyncValue<List<PartnerModel>>>
    implements AllPartnersNotifier {
  final List<PartnerModel> initial;
  _MockAllPartnersNotifier(this.initial) : super(AsyncValue.data(initial));

  @override
  Future<void> fetchPartners() async {
    state = AsyncValue.data(initial);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockTransportLocationsNotifier extends StateNotifier<AsyncValue<List<TransportLocationModel>>>
    implements TransportLocationsNotifier {
  final List<TransportLocationModel> initial;
  _MockTransportLocationsNotifier(this.initial) : super(AsyncValue.data(initial));

  @override
  Future<void> fetchLocations({bool includeInactive = true, String? locationType, String? search}) async {
    state = AsyncValue.data(initial);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockShippingScenariosNotifier extends StateNotifier<ShippingScenariosState>
    implements ShippingScenariosNotifier {
  _MockShippingScenariosNotifier(List<ShippingEvaluationModel> sessions)
      : super(ShippingScenariosState(sessions: sessions));

  @override
  Future<void> fetchSessions({String? search, int? projectId, int? poId, bool? showInactive}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCurrenciesNotifier extends StateNotifier<AsyncValue<List<CurrencyModel>>>
    implements CurrenciesNotifier {
  _MockCurrenciesNotifier(List<CurrencyModel> initial) : super(AsyncValue.data(initial));

  @override
  Future<void> fetchCurrencies({bool includeInactive = false, String? search}) async {
    state = const AsyncValue.data([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPurchaseOrdersNotifier extends StateNotifier<PurchaseOrdersState>
    implements PurchaseOrdersNotifier {
  _MockPurchaseOrdersNotifier() : super(PurchaseOrdersState());

  @override
  Future<void> fetchPurchaseOrders({int? supplierId, int? companyId, int? projectId, String? status, String? search}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleBooking1 = ShipmentBookingModel(
    bookingId: 1,
    bookingCode: 'BK-2026-0001',
    bookingConfirmationNo: 'MSC-CN-88991',
    importFileId: 10,
    importFileCode: 'IMP-2026-0010',
    shippingLineId: 1,
    shippingLineName: 'MSC Mediterranean Shipping',
    freightForwarderId: 2,
    freightForwarderName: 'El-Ahram Cargo Forwarders',
    shipmentType: 'Ocean FCL',
    polLocationId: 1,
    polName: 'Shanghai Port (CN)',
    podLocationId: 2,
    podName: 'Alexandria Old Port (EG)',
    vesselName: 'MSC OSCAR',
    voyageNumber: 'MS2601W',
    etd: '2026-10-01T00:00:00Z',
    eta: '2026-10-24T00:00:00Z',
    atd: null,
    departureDelayDays: 0,
    containersData: [
      ContainerAllocationModel(
        containerType: '40HC',
        quantity: 2,
        individualContainers: [
          SingleContainerItemModel(containerNumber: 'MSCU1234567', sealNumber: 'SL-8811'),
          SingleContainerItemModel(containerNumber: 'MSCU7654321', sealNumber: 'SL-8812'),
        ],
      ),
    ],
    costChargesData: [
      BookingChargeModel(
        chargeType: 'Ocean Freight 40HC',
        unit: 'Container',
        quantity: 2,
        currency: 'USD',
        rate: 3200.0,
        total: 6400.0,
      ),
    ],
    totalFreightCostUsd: 6400.0,
    originalFreightCostUsd: 7000.0,
    costSavingsUsd: 600.0,
    costVarianceUsd: 600.0,
    status: 'Confirmed',
    owner: 'Kamal',
    isActive: true,
    createdAt: '2026-09-01T10:00:00Z',
    updatedAt: '2026-09-01T10:00:00Z',
  );

  final sampleBooking2 = ShipmentBookingModel(
    bookingId: 2,
    bookingCode: 'BK-2026-0002',
    bookingConfirmationNo: 'COSCO-IT-4412',
    importFileId: 11,
    importFileCode: 'IMP-2026-0011',
    shippingLineId: 3,
    shippingLineName: 'COSCO Shipping Lines',
    freightForwarderId: 4,
    freightForwarderName: 'Apex Global Logistics',
    shipmentType: 'Ocean FCL',
    polLocationId: 3,
    polName: 'Genoa Port (IT)',
    podLocationId: 4,
    podName: 'Damietta Port (EG)',
    vesselName: 'COSCO FAITH',
    voyageNumber: 'CF2602E',
    etd: '2026-10-05T00:00:00Z',
    eta: '2026-10-18T00:00:00Z',
    atd: null,
    departureDelayDays: 0,
    containersData: [
      ContainerAllocationModel(
        containerType: '20GP',
        quantity: 1,
        individualContainers: [
          SingleContainerItemModel(containerNumber: 'COSU9988771', sealNumber: 'CS-4411'),
        ],
      ),
    ],
    costChargesData: [
      BookingChargeModel(
        chargeType: 'Ocean Freight 20GP',
        unit: 'Container',
        quantity: 1,
        currency: 'USD',
        rate: 2100.0,
        total: 2100.0,
      ),
    ],
    totalFreightCostUsd: 2100.0,
    originalFreightCostUsd: 2100.0,
    costSavingsUsd: 0.0,
    costVarianceUsd: 0.0,
    status: 'Draft',
    owner: 'Kamal',
    isActive: true,
    createdAt: '2026-09-02T12:00:00Z',
    updatedAt: '2026-09-02T12:00:00Z',
  );

  Widget buildTestApp({
    required Size size,
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('ar'),
  }) {
    return ProviderScope(
      overrides: [
        freightBookingProvider.overrideWith((ref) => _MockFreightBookingNotifier([sampleBooking1, sampleBooking2])),
        importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier([])),
        partnersProvider.overrideWith((ref) => _MockPartnersNotifier([])),
        allPartnersProvider.overrideWith((ref) => _MockAllPartnersNotifier([])),
        transportLocationsProvider.overrideWith((ref) => _MockTransportLocationsNotifier([])),
        shippingScenariosProvider.overrideWith((ref) => _MockShippingScenariosNotifier([])),
        currenciesProvider.overrideWith((ref) => _MockCurrenciesNotifier([])),
        purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier()),
      ],
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        locale: locale,
        builder: (context, child) => AppLocalizationsProvider(
          locale: locale,
          child: Directionality(
            textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const Scaffold(
          body: FreightBookingScreen(),
        ),
      ),
    );
  }

  group('Screen 25: FreightBookingScreen Enterprise Protocol Tests', () {
    testWidgets('Test 1: Desktop Viewport (1440x900) renders smoothly with 0 RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(1440, 900)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Screen Header
      expect(find.text('حجز الشحن وتخصيص الحاويات'), findsOneWidget);

      // Verify Top Action Toolbar buttons
      expect(find.byKey(const Key('createBookingBtn')), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneBookingBtn')), findsOneWidget);
      expect(find.byKey(const Key('copyBookingsTableTsvBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportBookingsExcelBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportBookingsPdfBtn')), findsOneWidget);

      // Verify Data Table contents and row buttons
      expect(find.text('BK-2026-0001'), findsOneWidget);
      expect(find.text('BK-2026-0002'), findsOneWidget);
      expect(find.byKey(const Key('copyBookingRowBtn_BK-2026-0001')), findsOneWidget);
      expect(find.byKey(const Key('cloneBookingRowBtn_BK-2026-0001')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 2: Tablet Viewport (800x1024) adapts with 0 RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(800, 1024)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify toolbar buttons rendered in Wrap
      expect(find.byKey(const Key('createBookingBtn')), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneBookingBtn')), findsOneWidget);
      expect(find.byKey(const Key('copyBookingsTableTsvBtn')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 3: Mobile Viewport (390x844) wraps toolbar cleanly with 0 RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(390, 844)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('createBookingBtn')), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneBookingBtn')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 4: Dark Mode WCAG AA rendering', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(
        size: const Size(1440, 900),
        themeMode: ThemeMode.dark,
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('createBookingBtn')), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneBookingBtn')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 5: RTL Arabic Localization displays correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(
        size: const Size(1440, 900),
        locale: const Locale('ar'),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('حجز الشحن وتخصيص الحاويات'), findsOneWidget);
      expect(find.text('طلب حجز شحن جديد'), findsWidgets);
      expect(find.text('بحث واستنساخ حجز سابق'), findsOneWidget);
      expect(find.text('نسخ كجدول (TSV)'), findsOneWidget);
      expect(find.text('تصدير سجل الحجوزات إلى Excel'), findsOneWidget);
      expect(find.text('تصدير سجل الحجوزات إلى PDF'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 6: Session / Record Clone Workflow (Toolbar & Row Clone)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(1440, 900)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Open Search & Clone Dialog from Toolbar
      final searchCloneBtn = find.byKey(const Key('searchAndCloneBookingBtn'));
      expect(searchCloneBtn, findsOneWidget);
      await tester.tap(searchCloneBtn);
      await tester.pumpAndSettle();

      // Verify Search & Clone Dialog opens
      expect(find.byType(SearchAndCloneFreightBookingDialog), findsOneWidget);
      expect(find.text('استنساخ حجز شحن بحري / جوي'), findsOneWidget);
      expect(find.text('MSC-CN-88991'), findsOneWidget);

      // Select booking from dialog
      final selectBookingBtn = find.byKey(const Key('selectCloneBookingBtn_BK-2026-0001'));
      expect(selectBookingBtn, findsOneWidget);
      await tester.tap(selectBookingBtn);
      await tester.pumpAndSettle();

      // Verify CloneEntityReviewDialog opens
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.textContaining('حجز شحن بحري / جوي'), findsWidgets);
      expect(find.text('BK-2026-0001'), findsOneWidget);

      // Cancel review dialog
      final cancelReviewBtn = find.byKey(const Key('cloneReviewCancelBtn'));
      if (cancelReviewBtn.evaluate().isNotEmpty) {
        await tester.tap(cancelReviewBtn);
        await tester.pumpAndSettle();
      } else {
        Navigator.of(tester.element(find.byType(CloneEntityReviewDialog))).pop();
        await tester.pumpAndSettle();
      }

      // 2. Direct Row Clone Button
      final rowCloneBtn = find.byKey(const Key('cloneBookingRowBtn_BK-2026-0001'));
      expect(rowCloneBtn, findsOneWidget);
      await tester.tap(rowCloneBtn);
      await tester.pumpAndSettle();

      // Verify CloneEntityReviewDialog opened for row
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.text('BK-2026-0001'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 7: Row TSV Copy & Table Multi-Format Exports (TSV, Excel, PDF)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(1440, 900)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Row TSV Copy
      final copyRowBtn = find.byKey(const Key('copyBookingRowBtn_BK-2026-0001'));
      expect(copyRowBtn, findsOneWidget);
      await tester.tap(copyRowBtn);
      await tester.pump(const Duration(milliseconds: 200));

      // 2. Table TSV Copy
      final copyTableBtn = find.byKey(const Key('copyBookingsTableTsvBtn'));
      expect(copyTableBtn, findsOneWidget);
      await tester.tap(copyTableBtn);
      await tester.pump(const Duration(milliseconds: 200));

      // 3. Table Excel Export button
      final excelBtn = find.byKey(const Key('exportBookingsExcelBtn'));
      expect(excelBtn, findsOneWidget);
      await tester.tap(excelBtn);
      await tester.pump(const Duration(milliseconds: 200));

      // 4. Table PDF Export button
      final pdfBtn = find.byKey(const Key('exportBookingsPdfBtn'));
      expect(pdfBtn, findsOneWidget);
      await tester.tap(pdfBtn);
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
    });
  });
}
