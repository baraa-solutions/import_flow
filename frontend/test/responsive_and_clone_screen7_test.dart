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
import 'package:frontend/core/widgets/buttons/icon_action_button.dart';
import 'package:frontend/core/widgets/clone_entity_review_dialog.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/currencies/providers/currencies_provider.dart';
import 'package:frontend/features/customs_consultation/models/customs_consultation_model.dart';
import 'package:frontend/features/customs_consultation/providers/customs_consultation_provider.dart';
import 'package:frontend/features/customs_consultation/screens/customs_consultation_screen.dart';
import 'package:frontend/features/customs_tariff/providers/customs_tariff_provider.dart';
import 'package:frontend/features/external_service_providers/models/partner_model.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/projects/providers/projects_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/shipping_scenarios/providers/shipping_scenarios_provider.dart';

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

class MockCustomsConsultationNotifier extends CustomsConsultationNotifier {
  int cloneCallCount = 0;

  MockCustomsConsultationNotifier(List<CustomsConsultationModel> initialList) : super(Dio()) {
    state = AsyncValue.data(initialList);
  }

  @override
  Future<void> fetchConsultations({
    bool includeInactive = false,
    String? search,
    int? brokerId,
    int? poId,
    int? projectId,
    String? status,
  }) async {}

  @override
  Future<CustomsConsultationModel?> cloneConsultation(int consultationId, Map<String, dynamic> payload) async {
    cloneCallCount++;
    final currentList = state.value ?? [];
    final original = currentList.firstWhere((c) => c.consultationId == consultationId);
    final cloned = CustomsConsultationModel(
      consultationId: 999,
      consultationCode: payload['new_consultation_code'] ?? '${original.consultationCode}-CLONE',
      title: payload['new_title'] ?? '${original.title} (نسخة)',
      brokerId: original.brokerId,
      brokerName: original.brokerName,
      overallStatus: 'Draft',
      hasBlockingIssues: false,
      readinessPercentage: 0.0,
      estimatedDutiesEgp: original.estimatedDutiesEgp,
      totalBrokerFeesEgp: original.totalBrokerFeesEgp,
      notes: payload['notes'] ?? original.notes,
      isActive: true,
      clonedFromId: original.consultationId,
      clonedFromCode: original.consultationCode,
      createdAt: '2026-09-14T02:00:00Z',
      updatedAt: '2026-09-14T02:00:00Z',
      checklistItems: (payload['copy_checklist_items'] == true)
          ? original.checklistItems.map((item) => item.copyWith(itemId: null, status: 'Pending')).toList()
          : [],
      brokerQuoteItems: (payload['copy_broker_quote_items'] == true)
          ? original.brokerQuoteItems.map((item) => item.copyWith(quoteItemId: null)).toList()
          : [],
    );
    state = AsyncValue.data([cloned, ...currentList]);
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

class MockShippingScenariosNotifier extends ShippingScenariosNotifier {
  MockShippingScenariosNotifier() : super(Dio()) {
    state = ShippingScenariosState(
      sessions: [],
      isLoading: false,
      showInactive: false,
    );
  }

  @override
  Future<void> fetchSessions() async {}
}

class MockCustomsTariffNotifier extends CustomsTariffNotifier {
  MockCustomsTariffNotifier({required super.ref, required super.showInactive, required super.search, required super.dio}) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchTariffs() async {}
}

class MockClearanceExpenseTypesNotifier extends ClearanceExpenseTypesNotifier {
  MockClearanceExpenseTypesNotifier(List<ClearanceExpenseTypeModel> items) : super(Dio()) {
    state = AsyncValue.data(items);
  }

  @override
  Future<void> fetchExpenseTypes({bool includeInactive = false, String? category, String? search}) async {}
}

class MockBrokerPriceListsNotifier extends BrokerPriceListsNotifier {
  MockBrokerPriceListsNotifier(List<BrokerPriceListModel> items) : super(Dio()) {
    state = AsyncValue.data(items);
  }

  @override
  Future<void> fetchPriceLists({bool includeInactive = false, int? brokerId, String? search}) async {}
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

  final sampleBrokers = [
    PartnerModel(
      providerId: 1,
      partnerCode: 'BRK-001',
      partnerName: 'الأهرام للتخليص الجمركي',
      partnerType: 'Customs Broker',
      country: 'Egypt',
      paymentType: 'Credit',
      creditLimit: 50000,
      rating: 4.9,
    ),
  ];

  final sampleConsultations = [
    CustomsConsultationModel(
      consultationId: 101,
      consultationCode: 'CST-2026-001',
      title: 'استشارة جمركية لشحنة خط إنتاج',
      brokerId: 1,
      brokerName: 'الأهرام للتخليص الجمركي',
      overallStatus: 'Clearance Ready',
      hasBlockingIssues: false,
      readinessPercentage: 90.0,
      estimatedDutiesEgp: 65000.0,
      totalBrokerFeesEgp: 8500.0,
      notes: 'دراسة استشارية مكتملة وجاهزة للإفراج',
      isActive: true,
      createdAt: '2026-09-01T10:00:00Z',
      updatedAt: '2026-09-02T12:00:00Z',
      checklistItems: [
        CustomsChecklistItemModel(
          itemId: 1,
          documentType: 'Proforma Invoice',
          isRequired: true,
          isBlockingShipment: true,
          responsibleParty: 'Supplier / Exporter',
          status: 'Approved',
          remarks: 'الفاتورة المبدئية معتمدة',
        ),
      ],
      brokerQuoteItems: [],
    ),
    CustomsConsultationModel(
      consultationId: 102,
      consultationCode: 'CST-2026-002',
      title: 'استشارة جمركية لقطع غيار',
      brokerId: 1,
      brokerName: 'الأهرام للتخليص الجمركي',
      overallStatus: 'Draft',
      hasBlockingIssues: true,
      readinessPercentage: 40.0,
      estimatedDutiesEgp: 18000.0,
      totalBrokerFeesEgp: 3500.0,
      notes: 'دراسة سريعة للرسوم التقديرية',
      isActive: true,
      createdAt: '2026-09-05T10:00:00Z',
      updatedAt: '2026-09-05T10:00:00Z',
      checklistItems: [],
      brokerQuoteItems: [],
    ),
  ];

  Widget buildTestWidget({
    required Size surfaceSize,
    bool isDark = false,
    Locale locale = const Locale('ar'),
    MockCustomsConsultationNotifier? customConsultationsNotifier,
    int initialIndex = 1,
  }) {
    final textDir = locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;
    final testDio = _createTestDio();
    final consultNotifier = customConsultationsNotifier ?? MockCustomsConsultationNotifier(sampleConsultations);

    return ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(testDio),
        customsConsultationsProvider.overrideWith((ref) => consultNotifier),
        currenciesProvider.overrideWith((ref) => MockCurrenciesNotifier(sampleCurrencies)),
        partnersProvider.overrideWith((ref) => MockPartnersNotifier(sampleBrokers)),
        projectsProvider.overrideWith((ref) => MockProjectsNotifier()),
        importFilesProvider.overrideWith((ref) => MockImportFilesNotifier()),
        purchaseOrdersProvider.overrideWith((ref) => MockPurchaseOrdersNotifier(ref)),
        shippingScenariosProvider.overrideWith((ref) => MockShippingScenariosNotifier()),
        customsTariffProvider.overrideWith((ref) => MockCustomsTariffNotifier(
          ref: ref,
          showInactive: false,
          search: '',
          dio: testDio,
        )),
        clearanceExpenseTypesProvider.overrideWith((ref) => MockClearanceExpenseTypesNotifier([])),
        brokerPriceListsProvider.overrideWith((ref) => MockBrokerPriceListsNotifier([])),
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
                  child: CustomsConsultationScreen(
                    initialIndex: initialIndex,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 7 (CustomsConsultationScreen Tab 1: SavedConsultationsTab) - 5-Task Enterprise Tests', () {
    testWidgets('Task A1: Desktop Viewport (1400x900) renders DataTable with 0 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(1400, 900)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SavedConsultationsTab), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('CST-2026-001'), findsOneWidget);
      expect(find.text('CST-2026-002'), findsOneWidget);
      expect(find.byKey(const ValueKey('searchAndCloneConsultationBtnTab1')), findsOneWidget);
    });

    testWidgets('Task A2: Tablet Viewport (800x1024) renders with 0 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(800, 1024)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SavedConsultationsTab), findsOneWidget);
      expect(find.text('CST-2026-001'), findsOneWidget);
    });

    testWidgets('Task A3: Mobile Viewport (390x844) renders stacked cards with 0 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SavedConsultationsTab), findsOneWidget);
      // On narrow viewport (< 768px), DataTable is replaced by mobile cards
      expect(find.byType(DataTable), findsNothing);
      expect(find.text('CST-2026-001'), findsOneWidget);

      // Verify list can scroll and shows second consultation
      await tester.drag(find.byType(ListView).last, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('CST-2026-002'), findsOneWidget);
    });

    testWidgets('Task B: Dark Mode Color & Contrast Audit - ThemeMode.dark renders legibly', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(1400, 900), isDark: true));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final cards = tester.widgetList<Card>(find.byType(Card));
      expect(cards.isNotEmpty, isTrue);
      for (final card in cards) {
        if (card.color != null) {
          expect(card.color, isNot(Colors.white));
        }
      }
    });

    testWidgets('Task C: RTL Arabic Support - Proper layout direction and localized text', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(1400, 900), locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final directionality = Directionality.of(tester.element(find.byType(SavedConsultationsTab)));
      expect(directionality, TextDirection.rtl);
      expect(find.text(lAr.totalStudiesMetric), findsOneWidget);
      expect(find.text(lAr.searchAndCloneConsultationBtn), findsOneWidget);
    });

    testWidgets('Task D: Screen-Level Clone via toolbar button -> Search dialog -> Review dialog -> Confirmation', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockNotifier = MockCustomsConsultationNotifier(sampleConsultations);

      await tester.pumpWidget(buildTestWidget(
        surfaceSize: const Size(1400, 900),
        customConsultationsNotifier: mockNotifier,
      ));
      await tester.pumpAndSettle();

      // Tap toolbar search & clone button
      final cloneBtn = find.byKey(const ValueKey('searchAndCloneConsultationBtnTab1'));
      expect(cloneBtn, findsOneWidget);
      await tester.tap(cloneBtn);
      await tester.pumpAndSettle();

      // Verify SearchAndCloneConsultationDialog is displayed
      expect(find.byType(SearchAndCloneConsultationDialog), findsOneWidget);
      expect(find.text(lAr.searchAndCloneConsultationDialogTitle), findsOneWidget);

      // Select first consultation specifically in the dialog
      final dialogItem = find.descendant(
        of: find.byType(SearchAndCloneConsultationDialog),
        matching: find.text('CST-2026-001'),
      );
      expect(dialogItem, findsOneWidget);
      await tester.tap(dialogItem);
      await tester.pumpAndSettle();

      // Verify CloneEntityReviewDialog is open
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);

      // Verify mandatorily reset fields are shown
      expect(find.text(lAr.cloneFieldConsultationCodeGenerated), findsOneWidget);
      expect(find.text(lAr.cloneFieldImportFileReset), findsOneWidget);
      expect(find.text(lAr.cloneFieldChecklistReset), findsOneWidget);
      expect(find.text(lAr.cloneFieldStatusDraftBadge), findsOneWidget);

      // Submit clone review dialog
      final confirmBtn = find.text(lAr.cloneConfirmAndCreateBtn);
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify notifier was called and clone completed
      expect(mockNotifier.cloneCallCount, 1);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Task E: Table Row-Level Clone via RowActionsPill onClone -> Review dialog', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockNotifier = MockCustomsConsultationNotifier(sampleConsultations);

      await tester.pumpWidget(buildTestWidget(
        surfaceSize: const Size(1400, 900),
        customConsultationsNotifier: mockNotifier,
      ));
      await tester.pumpAndSettle();

      // Find clone action button in RowActionsPill on the data table
      final rowCloneButtons = find.byType(CloneActionButton);
      expect(rowCloneButtons, findsWidgets);

      // Tap first row clone button
      await tester.tap(rowCloneButtons.first);
      await tester.pumpAndSettle();

      // Verify CloneEntityReviewDialog opened directly for CST-2026-001
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.text('CST-2026-001-CLONE'), findsOneWidget);

      // Confirm clone
      final confirmBtn = find.text(lAr.cloneConfirmAndCreateBtn);
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(mockNotifier.cloneCallCount, 1);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
