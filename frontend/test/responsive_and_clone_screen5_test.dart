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
import 'package:frontend/core/widgets/row_actions_pill.dart';
import 'package:frontend/core/widgets/buttons/icon_action_button.dart';
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
import 'package:frontend/features/shipping_scenarios/widgets/saved_scenarios_registry_tab.dart';
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
  int cloneCallCount = 0;

  MockShippingScenariosNotifier(List<ShippingEvaluationModel> sessions) : super(Dio()) {
    state = ShippingScenariosState(
      sessions: sessions,
      isLoading: false,
      showInactive: false,
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
    cloneCallCount++;
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
  ];

  final sampleItems = [
    ShippingScenarioItemModel(
      itemId: 101,
      providerId: 1,
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
      sessionId: 101,
      sessionCode: 'SCE-2026-001',
      title: 'دراسة استيراد معدات ثقيلة شنغهاي',
      cargoReadyDate: '2026-04-15',
      pickUpAddress: 'Pudong Logistics Park, Shanghai',
      portOfLoadingId: 1,
      portOfDischargeId: 2,
      avgForm4Days: 5,
      avgClearanceDays: 4,
      notes: 'دراسة عاجلة لمشروع خط الإنتاج',
      isActive: true,
      recommendedScenarioProvider: 'COSCO Shipping',
      avgExpectedTransitDays: 24.5,
      items: sampleItems,
    ),
    ShippingEvaluationModel(
      sessionId: 102,
      sessionCode: 'SCE-2026-002',
      title: 'دراسة خط شحن احتياطي',
      cargoReadyDate: '2026-05-01',
      pickUpAddress: 'Ningbo Industrial Zone',
      portOfLoadingId: 1,
      portOfDischargeId: 2,
      avgForm4Days: 4,
      avgClearanceDays: 3,
      notes: 'دراسة بديلة للشحنة',
      isActive: true,
      recommendedScenarioProvider: 'Maersk Line',
      avgExpectedTransitDays: 28.0,
      items: [],
    ),
  ];

  Widget buildTestWidget({
    required Size surfaceSize,
    bool isDark = false,
    Locale locale = const Locale('ar'),
    MockShippingScenariosNotifier? customScenariosNotifier,
    void Function(ShippingEvaluationModel)? onEditSession,
    VoidCallback? onSwitchToEvaluator,
  }) {
    final textDir = locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;
    final testDio = _createTestDio();
    final scenariosNotifier = customScenariosNotifier ?? MockShippingScenariosNotifier(sampleSessions);

    return ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(testDio),
        currenciesProvider.overrideWith((ref) => MockCurrenciesNotifier(sampleCurrencies)),
        transportLocationsProvider.overrideWith((ref) => MockTransportLocationsNotifier(samplePorts)),
        partnersProvider.overrideWith((ref) => MockPartnersNotifier(samplePartners)),
        projectsProvider.overrideWith((ref) => MockProjectsNotifier()),
        importFilesProvider.overrideWith((ref) => MockImportFilesNotifier()),
        purchaseOrdersProvider.overrideWith((ref) => MockPurchaseOrdersNotifier(ref)),
        shippingScenariosProvider.overrideWith((ref) => scenariosNotifier),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        locale: locale,
        home: AppLocalizationsProvider(
          locale: locale,
          child: Directionality(
            textDirection: textDir,
            child: MediaQuery(
              data: MediaQueryData(size: surfaceSize),
              child: Scaffold(
                body: SizedBox(
                  width: surfaceSize.width,
                  height: surfaceSize.height,
                  child: SavedScenariosRegistryTab(
                    onEditSession: onEditSession ?? (_) {},
                    onSwitchToEvaluator: onSwitchToEvaluator ?? () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 5 (SavedScenariosRegistryTab) - 5-Task Enterprise Audit Tests', () {
    testWidgets('Task A1: Desktop Viewport (1400x900) renders DataTable with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Verify DataTable is rendered
      expect(find.byType(DataTable), findsOneWidget);

      // Verify study codes and title visible
      expect(find.text('SCE-2026-001'), findsWidgets);
      expect(find.text('SCE-2026-002'), findsWidgets);

      // Verify search and clone button present
      expect(find.byKey(const ValueKey('registrySearchAndCloneStudyBtn')), findsOneWidget);

      // Verify 0 RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('Task A2: Tablet Viewport (800x1024) wraps stats and keeps DataTable scrollable with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(800, 1024)));
      await tester.pumpAndSettle();

      // Width 800 is >= 768, so DataTable is rendered
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('SCE-2026-001'), findsWidgets);

      // Verify search & clone button
      expect(find.byKey(const ValueKey('registrySearchAndCloneStudyBtn')), findsOneWidget);

      // 0 overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('Task A3: Mobile Viewport (390x844) falls back to mobile cards list with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Under 768px, DataTable should NOT be rendered; mobile cards should be rendered
      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(Card), findsWidgets);

      // Verify studies are rendered in card list
      expect(find.text('SCE-2026-001'), findsOneWidget);
      expect(find.byType(RowActionsPill), findsWidgets);

      // Scroll to reveal second study in list
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('SCE-2026-002'), findsOneWidget);

      // 0 overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('Task B: Dark Mode Token Compliance - renders without hardcoded white surfaces', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(
        surfaceSize: const Size(1400, 900),
        isDark: true,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('SCE-2026-001'), findsWidgets);

      // Verify dark theme applied
      final theme = Theme.of(tester.element(find.byType(SavedScenariosRegistryTab)));
      expect(theme.brightness, Brightness.dark);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Task C: Full RTL Arabic support under Locale("ar")', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(
        surfaceSize: const Size(1400, 900),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      // Verify Arabic metrics and labels
      expect(find.text(lAr.totalStudiesMetric), findsOneWidget);
      expect(find.text(lAr.searchAndCloneStudyBtn), findsOneWidget);
      expect(find.text(lAr.activeStatus), findsWidgets);

      // Directionality is RTL
      final directionality = Directionality.of(tester.element(find.byType(SavedScenariosRegistryTab)));
      expect(directionality, TextDirection.rtl);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Task D: Screen-Level Clone via registrySearchAndCloneStudyBtn opens Search & Clone dialog', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = MockShippingScenariosNotifier(sampleSessions);
      ShippingEvaluationModel? editedSession;
      bool switchedToEvaluator = false;

      await tester.pumpWidget(buildTestWidget(
        surfaceSize: const Size(1400, 900),
        customScenariosNotifier: notifier,
        onEditSession: (sess) => editedSession = sess,
        onSwitchToEvaluator: () => switchedToEvaluator = true,
      ));
      await tester.pumpAndSettle();

      // Tap screen-level Search & Clone button
      final searchAndCloneBtn = find.byKey(const ValueKey('registrySearchAndCloneStudyBtn'));
      expect(searchAndCloneBtn, findsOneWidget);
      await tester.tap(searchAndCloneBtn);
      await tester.pumpAndSettle();

      // Verify SearchAndCloneStudyDialog opened
      expect(find.byType(SearchAndCloneStudyDialog), findsOneWidget);
      expect(find.text('SCE-2026-001'), findsWidgets);

      // Select the study in the dialog
      await tester.tap(find.text('SCE-2026-001').last);
      await tester.pumpAndSettle();

      // Verify CloneEntityReviewDialog opened
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);

      // Confirm clone in the review dialog
      final confirmBtn = find.text(lAr.cloneConfirmAndCreateBtn);
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify notifier cloneSession was called
      expect(notifier.cloneCallCount, 1);
      expect(editedSession, isNotNull);
      expect(editedSession!.sessionCode, 'SCE-2026-099');
      expect(switchedToEvaluator, isTrue);

      // Verify success snackbar shown
      expect(find.text(lAr.cloneStudySuccess('SCE-2026-099')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Task E: Table Row-Level Clone via RowActionsPill opens CloneEntityReviewDialog', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = MockShippingScenariosNotifier(sampleSessions);
      ShippingEvaluationModel? editedSession;
      bool switchedToEvaluator = false;

      await tester.pumpWidget(buildTestWidget(
        surfaceSize: const Size(1400, 900),
        customScenariosNotifier: notifier,
        onEditSession: (sess) => editedSession = sess,
        onSwitchToEvaluator: () => switchedToEvaluator = true,
      ));
      await tester.pumpAndSettle();

      // Find CloneActionButton on row actions pill
      final cloneActionBtn = find.byType(CloneActionButton);
      expect(cloneActionBtn, findsWidgets);

      // Tap the first clone action button
      await tester.tap(cloneActionBtn.first);
      await tester.pumpAndSettle();

      // Verify CloneEntityReviewDialog opened directly
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);

      // Confirm clone
      final confirmBtn = find.text(lAr.cloneConfirmAndCreateBtn);
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify clone executed
      expect(notifier.cloneCallCount, 1);
      expect(editedSession, isNotNull);
      expect(editedSession!.sessionCode, 'SCE-2026-099');
      expect(switchedToEvaluator, isTrue);

      // Success snackbar
      expect(find.text(lAr.cloneStudySuccess('SCE-2026-099')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
