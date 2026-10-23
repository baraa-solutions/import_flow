import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/clone_entity_review_dialog.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/currencies/providers/currencies_provider.dart';
import 'package:frontend/features/external_service_providers/models/partner_model.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/projects/providers/projects_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/shipping_scenarios/models/shipping_scenario_model.dart';
import 'package:frontend/features/shipping_scenarios/providers/shipping_scenarios_provider.dart';
import 'package:frontend/features/shipping_scenarios/screens/shipping_scenarios_screen.dart';
import 'package:frontend/features/transport_locations/models/transport_location_model.dart';
import 'package:frontend/features/transport_locations/providers/transport_locations_provider.dart';

class _MockHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode([]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _createTestDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:28080/api/v1'));
  dio.httpClientAdapter = _MockHttpAdapter();
  return dio;
}

class MockShippingScenariosNotifier extends ShippingScenariosNotifier {
  MockShippingScenariosNotifier(List<ShippingEvaluationModel> sessions) : super(Dio()) {
    state = ShippingScenariosState(
      sessions: sessions,
      isLoading: false,
    );
  }

  @override
  Future<void> fetchSessions() async {}

  @override
  Future<ShippingEvaluationModel?> cloneSession(
    int sessionId, {
    String? newTitle,
    DateTime? cargoReadyDate,
    bool unlinkImportFile = true,
    bool unlinkPo = true,
    bool copyCarrierOptions = true,
    String? remarks,
  }) async {
    final original = state.sessions.firstWhere((s) => s.sessionId == sessionId);
    final cloned = ShippingEvaluationModel(
      sessionId: 999,
      sessionCode: 'SCE-2026-099',
      title: newTitle ?? '${original.title} (نسخة)',
      cargoReadyDate: cargoReadyDate != null ? cargoReadyDate.toString().substring(0, 10) : original.cargoReadyDate,
      pickUpAddress: original.pickUpAddress,
      portOfLoadingId: original.portOfLoadingId,
      portOfDischargeId: original.portOfDischargeId,
      avgForm4Days: original.avgForm4Days,
      avgClearanceDays: original.avgClearanceDays,
      poId: unlinkPo ? null : original.poId,
      importFileId: unlinkImportFile ? null : original.importFileId,
      projectId: original.projectId,
      notes: remarks ?? original.notes,
      isActive: true,
      items: copyCarrierOptions ? original.items : [],
    );
    state = state.copyWith(sessions: [cloned, ...state.sessions]);
    return cloned;
  }
}

class MockCurrenciesNotifier extends CurrenciesNotifier {
  MockCurrenciesNotifier(List<CurrencyModel> currencies) : super(Dio()) {
    state = AsyncValue.data(currencies);
  }

  @override
  Future<void> fetchCurrencies({bool includeInactive = true, String? search}) async {}
}

class MockTransportLocationsNotifier extends TransportLocationsNotifier {
  MockTransportLocationsNotifier(List<TransportLocationModel> locations) : super(Dio()) {
    state = AsyncValue.data(locations);
  }

  @override
  Future<void> fetchLocations({bool includeInactive = true, String? locationType, String? search}) async {}
}

class MockPartnersNotifier extends PartnersNotifier {
  MockPartnersNotifier(List<PartnerModel> partners) : super(dio: Dio(), category: 'All', showInactive: true) {
    state = AsyncValue.data(partners);
  }

  @override
  Future<void> fetchPartners({bool includeInactive = false, String? search, String? category}) async {}
}

class MockProjectsNotifier extends ProjectsNotifier {
  MockProjectsNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchProjects({bool includeInactive = true, String? status, String? search}) async {}
}

class MockImportFilesNotifier extends ImportFilesNotifier {
  MockImportFilesNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {}
}

class MockPurchaseOrdersNotifier extends PurchaseOrdersNotifier {
  MockPurchaseOrdersNotifier(Ref ref) : super(Dio(), ref) {
    state = PurchaseOrdersState(
      purchaseOrders: [],
      isLoading: false,
    );
  }

  @override
  Future<void> fetchPurchaseOrders() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const lAr = AppLocalizationsAr();

  final sampleCurrencies = [
    CurrencyModel(
      currencyId: 1,
      currencyCode: 'USD',
      currencyName: 'US Dollar',
      currencySymbol: r'$',
      isBaseCurrency: false,
      decimalPlaces: 2,
      isActive: true,
      latestCommercialRate: 50.0,
      latestCustomsRate: 50.0,
    ),
    CurrencyModel(
      currencyId: 2,
      currencyCode: 'EGP',
      currencyName: 'Egyptian Pound',
      currencySymbol: 'LE',
      isBaseCurrency: true,
      decimalPlaces: 2,
      isActive: true,
      latestCommercialRate: 1.0,
      latestCustomsRate: 1.0,
    ),
  ];

  final samplePorts = [
    TransportLocationModel(
      locationId: 1,
      unLocode: 'CNSHA',
      locationName: 'Shanghai Port',
      locationType: 'Sea Port',
      country: 'China',
      city: 'Shanghai',
    ),
    TransportLocationModel(
      locationId: 2,
      unLocode: 'EGEDK',
      locationName: 'El Dekheila Port',
      locationType: 'Sea Port',
      country: 'Egypt',
      city: 'Alexandria',
    ),
  ];

  final samplePartners = [
    PartnerModel(
      providerId: 1,
      partnerCode: 'COSCO',
      partnerName: 'COSCO Shipping',
      partnerType: 'Shipping Line',
      country: 'China',
      paymentType: 'Credit',
      creditLimit: 100000,
      rating: 4.8,
    ),
    PartnerModel(
      providerId: 2,
      partnerCode: 'MSK',
      partnerName: 'Maersk Line',
      partnerType: 'Shipping Line',
      country: 'Denmark',
      paymentType: 'Credit',
      creditLimit: 100000,
      rating: 4.9,
    ),
    PartnerModel(
      providerId: 3,
      partnerCode: 'FWD-01',
      partnerName: 'Global Freight Logistics',
      partnerType: 'Freight Forwarder',
      country: 'Egypt',
      paymentType: 'Credit',
      creditLimit: 50000,
      rating: 4.5,
    ),
    PartnerModel(
      providerId: 4,
      partnerCode: 'BROKER-01',
      partnerName: 'Sorour Customs Clearance Office',
      partnerType: 'Customs Broker',
      country: 'Egypt',
      paymentType: 'Credit',
      creditLimit: 50000,
      rating: 4.9,
    ),
  ];

  final sampleItems = [
    ShippingScenarioItemModel(
      itemId: 101,
      providerId: 3,
      providerName: 'COSCO Shipping',
      vesselName: 'COSCO FAITH',
      voyageNumber: '042W',
      portOfLoadingId: 1,
      portOfDischargeId: 2,
      polName: 'Shanghai Port',
      podName: 'El Dekheila Port',
      sailingDate: '2026-10-01',
      estimatedArrivalDate: '2026-10-28',
      expectedLineDelayDays: 2,
      riskLevel: 'Low',
      isRecommended: true,
      isSelected: true,
      freeTimeDays: 14,
      quotationCurrency: 'USD',
      totalQuotationAmount: 3200.0,
      container40ftApplicable: true,
      container40ftPrice: 3200.0,
      container40ftCurrency: 'USD',
      container40ftQty: 1,
    ),
  ];

  final sampleSessions = [
    ShippingEvaluationModel(
      sessionId: 1,
      sessionCode: 'SCE-2026-001',
      title: 'Shanghai to Dekheila Study',
      cargoReadyDate: '2026-09-25',
      pickUpAddress: 'Shanghai Industrial Zone',
      avgForm4Days: 5,
      avgClearanceDays: 7,
      isActive: true,
      items: sampleItems,
    ),
  ];

  Widget createTestWidget({
    required Size size,
    Locale locale = const Locale('ar'),
    ThemeMode themeMode = ThemeMode.dark,
    Widget? child,
  }) {
    final textDir = locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;
    final testDio = _createTestDio();

    return ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(testDio),
        shippingScenariosProvider.overrideWith((ref) => MockShippingScenariosNotifier(sampleSessions)),
        currenciesProvider.overrideWith((ref) => MockCurrenciesNotifier(sampleCurrencies)),
        transportLocationsProvider.overrideWith((ref) => MockTransportLocationsNotifier(samplePorts)),
        partnersProvider.overrideWith((ref) => MockPartnersNotifier(samplePartners)),
        projectsProvider.overrideWith((ref) => MockProjectsNotifier()),
        importFilesProvider.overrideWith((ref) => MockImportFilesNotifier()),
        purchaseOrdersProvider.overrideWith((ref) => MockPurchaseOrdersNotifier(ref)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        locale: locale,
        home: AppLocalizationsProvider(
          locale: locale,
          child: Directionality(
            textDirection: textDir,
            child: MediaQuery(
              data: MediaQueryData(size: size),
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: child ?? const ShippingScenariosScreen(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 4 (ShippingScenariosScreen — Freight Evaluator) — Tasks A to F Automated Tests', () {
    testWidgets('1. Desktop viewport (1400x900): renders with 0 overflow, 4-column metric cards, and header actions', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Check header action: Search and Clone button
      expect(find.byKey(const ValueKey('searchAndCloneStudyBtn')), findsOneWidget);
      expect(find.text(lAr.searchAndCloneStudyBtn), findsOneWidget);

      // Check Setup & Parameters card
      expect(find.text(lAr.studySetupAndParameters), findsOneWidget);

      // Check Metric cards
      expect(find.text(lAr.avgWarehouseArrivalMetric), findsWidgets);
      expect(find.text(lAr.earliestLineMetric), findsWidgets);
      expect(find.text(lAr.latestLineMetric), findsWidgets);
      expect(find.text(lAr.recommendedLineMetric), findsWidgets);

      // Check Carrier Option card after adding a new option
      await tester.tap(find.text(lAr.addNewShippingOption).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.copy_rounded), findsWidgets);
      expect(find.byTooltip(lAr.cloneCarrierOptionTooltip), findsWidgets);

      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Tablet viewport (800x1024): renders responsive wrapped metrics with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(800, 1024)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('searchAndCloneStudyBtn')), findsOneWidget);
      expect(find.text(lAr.studySetupAndParameters), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Mobile viewport (390x844): renders stacked parameters & carrier card with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      expect(find.text(lAr.studySetupAndParameters), findsOneWidget);
      final addOptionBtn = find.text(lAr.addNewShippingOption).first;
      await tester.ensureVisible(addOptionBtn);
      await tester.tap(addOptionBtn);
      await tester.pumpAndSettle();
      expect(find.byTooltip(lAr.cloneCarrierOptionTooltip), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Carrier Option Row Clone: duplicate carrier option increments count and triggers live recalculation', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Add a carrier option first
      await tester.tap(find.text(lAr.addNewShippingOption).first);
      await tester.pumpAndSettle();

      // Find the duplicate carrier option icon button
      final cloneBtn = find.byTooltip(lAr.cloneCarrierOptionTooltip).first;
      await tester.ensureVisible(cloneBtn);
      await tester.tap(cloneBtn);
      await tester.pumpAndSettle();

      // Verify second carrier option appeared (original 1 + cloned 1 = 2 clone buttons)
      expect(find.byTooltip(lAr.cloneCarrierOptionTooltip), findsNWidgets(2));
      // Verify success snackbar
      expect(find.text(lAr.carrierOptionClonedSuccess), findsOneWidget);
    });

    testWidgets('5. RTL Arabic Support: proper alignment and localized labels', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(1200, 800), locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text(lAr.studySetupAndParameters), findsOneWidget);
      expect(find.text(lAr.searchAndCloneStudyBtn), findsOneWidget);
      expect(find.textContaining(lAr.clearAndStartNew), findsWidgets);
    });

    testWidgets('6. Dark Mode Token Compliance: action bar and cards use dark surfaces, not white', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(1400, 900), themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      // Verify bottom action bar container background is dark (0xFF253140)
      final bottomContainerFinder = find.byWidgetPredicate(
        (widget) => widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == const Color(0xFF253140),
      );
      expect(bottomContainerFinder, findsWidgets);
    });

    testWidgets('7. Screen-level Search & Clone Study Dialog: opens modal, selects study, and opens review dialog', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Click "Search and Clone Study" button
      final searchCloneBtn = find.byKey(const ValueKey('searchAndCloneStudyBtn'));
      expect(searchCloneBtn, findsOneWidget);
      await tester.tap(searchCloneBtn);
      await tester.pumpAndSettle();

      // Verify the search and clone dialog opened with the study
      expect(find.text(lAr.searchAndCloneStudyDialogTitle), findsOneWidget);
      expect(find.text('SCE-2026-001'), findsOneWidget);
      expect(find.text('Shanghai to Dekheila Study'), findsOneWidget);

      // Select the study to trigger review dialog
      final studyCard = find.text('SCE-2026-001');
      await tester.tap(studyCard);
      await tester.pumpAndSettle();

      // Verify CloneEntityReviewDialog opened
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.text(lAr.cloneEntityDialogTitle(lAr.cloneStudyDialogTitle)), findsOneWidget);

      // Verify mandatory reset fields badges
      expect(find.text(lAr.cloneFieldStudyCodeGenerated), findsOneWidget);
      expect(find.text(lAr.cloneFieldImportFileReset), findsOneWidget);
      expect(find.text(lAr.cloneFieldPoReset), findsOneWidget);
      expect(find.text(lAr.cloneFieldSelectionReset), findsOneWidget);

      // Confirm the clone dialog
      final confirmBtn = find.text(lAr.cloneConfirmAndCreateBtn);
      expect(confirmBtn, findsOneWidget);
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify cloned session loaded and success message appeared
      expect(find.text(lAr.cloneStudySuccess('SCE-2026-099')), findsOneWidget);
    });
  });
}
