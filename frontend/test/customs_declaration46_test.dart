import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/currencies/providers/currencies_provider.dart';
import 'package:frontend/features/customs_tariff/models/customs_tariff_model.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/customs_tariff/providers/customs_tariff_provider.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/providers/customs_clearance_provider.dart';
import 'package:frontend/features/import_documentation/screens/customs_declaration46_screen.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

class _MockImportFilesNotifier extends ImportFilesNotifier {
  final List<ImportFileModel> initialFiles;
  _MockImportFilesNotifier(this.initialFiles) : super(Dio()) {
    state = AsyncValue.data(initialFiles);
  }

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {
    state = AsyncValue.data(initialFiles);
  }
}

class _MockCustomsTariffNotifier extends CustomsTariffNotifier {
  final List<CustomsTariffModel> initialTariffs;
  _MockCustomsTariffNotifier(this.initialTariffs)
      : super(ref: _FakeRef(), showInactive: false, search: '', dio: Dio()) {
    state = AsyncValue.data(initialTariffs);
  }

  @override
  Future<void> fetchTariffs() async {
    state = AsyncValue.data(initialTariffs);
  }
}

class _MockPurchaseOrdersNotifier extends StateNotifier<PurchaseOrdersState> implements PurchaseOrdersNotifier {
  final List<PurchaseOrderModel> initialPOs;
  _MockPurchaseOrdersNotifier(this.initialPOs) : super(PurchaseOrdersState(purchaseOrders: initialPOs));

  @override
  Future<void> fetchPurchaseOrders() async {
    state = state.copyWith(purchaseOrders: initialPOs, isLoading: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCurrenciesNotifier extends CurrenciesNotifier {
  final List<CurrencyModel> initial;
  _MockCurrenciesNotifier(this.initial) : super(Dio()) {
    state = AsyncValue.data(initial);
  }

  @override
  Future<void> fetchCurrencies({bool includeInactive = true, String? search}) async {
    state = AsyncValue.data(initial);
  }
}

/// A PO linked to [fileId] whose single line carries [hsCode].
PurchaseOrderModel _poWithHs(int fileId, String hsCode) => PurchaseOrderModel.fromJson({
      'po_id': 1,
      'po_number': 'PO-1',
      'import_file_id': fileId,
      'items': [
        {'item_id': 1, 'po_id': 1, 'hs_code': hsCode, 'quantity': 1, 'unit_price': 1},
      ],
    });

CurrencyModel _currency(String code, double? customsRate) => CurrencyModel(
      currencyCode: code,
      currencyName: code,
      currencySymbol: code,
      latestCustomsRate: customsRate,
    );

class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCustomsClearanceNotifier extends CustomsClearanceNotifier {
  final List<Map<String, dynamic>> registeredCalls = [];
  bool shouldThrow = false;
  String? errorMessage;

  _MockCustomsClearanceNotifier({List<CustomsClearanceModel> initial = const []})
      : super(Dio(), ref: _FakeRef()) {
    state = AsyncValue.data(initial);
  }

  @override
  Future<void> fetchRecords({
    bool includeInactive = false,
    int? importFileId,
    String? status,
    String? search,
  }) async {
    // no-op
  }

  @override
  Future<CustomsClearanceModel?> registerDeclaration46(Map<String, dynamic> payload) async {
    registeredCalls.add(payload);
    if (shouldThrow) {
      throw DioException(
        requestOptions: RequestOptions(path: '/customs-clearance/register-declaration-46'),
        response: Response(
          requestOptions: RequestOptions(path: '/customs-clearance/register-declaration-46'),
          statusCode: 400,
          data: {'detail': errorMessage ?? 'صلاحية رقم القيد المسبق منتهية'},
        ),
      );
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CustomsDeclaration46Screen Auto-Population & Compliance Tests', () {
    testWidgets('Renders and auto-populates ACID, Form 4, B/L, Duties, Exemption, and Approvals on file selection', (tester) async {
      final mockFile = ImportFileModel(
        importFileId: 5,
        importFileCode: 'IMP-2026-0005',
        companyId: 1,
        companyName: 'Al-Sorour Logistics',
        supplierId: 2,
        supplierName: 'Milano Industrial SpA',
        shipmentMode: 'Sea FCL',
        incotermCode: 'FOB',
        priority: 'Normal',
        shipmentCategory: 'Commercial',
        portOfLoading: 'Genoa Port (IT)',
        acidNumber: '8912345678901234567',
        form4No: 'F4-BNK-99881',
        customFileNumber: 'MEDUST-IT-0099',
        estimatedCost: 10000.0,
        estimatedCostCurrency: 'USD',
        status: 'Active',
        owner: 'Admin',
        progressPercent: 60.0,
        currentModule: 'Customs Clearance',
        currentStage: 'Declaration 46',
        nextAction: 'Submit Form 46',
        invoicesData: [
          InvoiceItemModel(invoiceNo: 'INV-IT-01', amount: 10000.0, currency: 'USD'),
        ],
        packingListsData: [],
        projectIds: [],
        skippedStages: [],
        createdAt: '2026-08-23T00:00:00Z',
        updatedAt: '2026-08-23T00:00:00Z',
      );

      final mockTariff = CustomsTariffModel(
        tariffId: 1,
        hsCode: '8471.30.00',
        hsDescription: 'آلات معالجة البيانات المحمولة الرقمية',
        customsDutyRate: 0.0, // 0% European Exemption
        vatRate: 14.0,
        scheduleTaxRate: 0.0,
        developmentFeeRate: 0.0,
        importFeeRate: 0.0,
        customsServiceFeeRate: 1.0,
        requiresCoo: true,
        requiresInspection: true,
        requiresAcid: true,
        regulatoryAuthority: 'الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)',
        priorApprovalNote: 'مطابقة قياسية وفحص مستندي',
        effectiveFrom: DateTime(2026, 1, 1),
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier([mockFile])),
            customsTariffProvider.overrideWith((ref) => _MockCustomsTariffNotifier([mockTariff])),
            purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier([_poWithHs(5, '8471.30.00')])),
            currenciesProvider.overrideWith((ref) => _MockCurrenciesNotifier([_currency('USD', 48.5)])),
          ],
          child: const MaterialApp(
          locale: Locale('ar'),
          home: AppLocalizationsProvider(
            locale: Locale('ar'),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: CustomsDeclaration46Screen(
                  initialSubTab: 0,
                  initialImportFileId: 5,
                ),
              ),
            ),
          ),
        ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // 1. Verify Declaration 46 Screen header and attributes
      expect(find.textContaining('الإقرار الجمركي المبدئي وشهادة 46 ك.م'), findsOneWidget);
      expect(find.text('8912345678901234567'), findsOneWidget); // ACID
      expect(find.text('F4-BNK-99881'), findsOneWidget); // Form 4
      expect(find.text('MEDUST-IT-0099'), findsOneWidget); // B/L Number

      // 2. Verify Exemption & Trade Agreement Card
      expect(find.textContaining('اتفاقية الشراكة المصرية الأوروبية'), findsOneWidget);
      expect(find.textContaining('تقديم شهادة المنشأ الأوروبية'), findsOneWidget);

      // 3. Verify Regulatory Approvals & Inspections Board
      expect(find.textContaining('الهيئة العامة للرقابة على الصادرات والواردات'), findsOneWidget);
      expect(find.textContaining('العروض والموافقات المطلوبة والاشتراطات الرقابية'), findsOneWidget);
    });

    testWidgets('Screen 24: Renders SubTab 1 Registry, KPI cards, and opens Tariff Assessment dialog', (tester) async {
      final mockFile = ImportFileModel(
        importFileId: 7,
        importFileCode: 'FILE-2026-007',
        companyId: 1,
        companyName: 'الشركة الهندسية للصناعات المتطورة',
        supplierId: 10,
        supplierName: 'Siemens Industrial Automation AG',
        shipmentMode: 'FCL',
        incotermCode: 'CIF',
        priority: 'Normal',
        shipmentCategory: 'Industrial Machinery',
        estimatedCost: 20000.0,
        estimatedCostCurrency: 'EUR',
        portOfLoading: 'IT-GOA',
        portOfDischarge: 'EG-ALX',
        acidNumber: '8912345678901234567',
        form4No: 'F4-BNK-99881',
        customFileNumber: 'MEDUST-IT-0099',
        status: 'Active',
        owner: 'Admin',
        progressPercent: 60.0,
        currentModule: 'Customs Clearance',
        currentStage: 'Declaration 46',
        nextAction: 'Submit Form 46',
        invoicesData: [
          InvoiceItemModel(
            invoiceNo: 'INV-2026-007',
            amount: 20000.0,
            currency: 'EUR',
            date: '2026-02-15',
          ),
        ],
        packingListsData: [],
        projectIds: [],
        skippedStages: [],
        createdAt: '2026-08-23T00:00:00Z',
        updatedAt: '2026-08-23T00:00:00Z',
      );

      final mockTariff = CustomsTariffModel(
        tariffId: 1,
        hsCode: '8471.30.00',
        hsDescription: 'آلات معالجة معلومات ذاتية محمولة',
        customsDutyRate: 5.0,
        vatRate: 14.0,
        developmentFeeRate: 0.0,
        scheduleTaxRate: 0.0,
        importFeeRate: 0.0,
        customsServiceFeeRate: 1.0,
        requiresInspection: true,
        requiresCoo: true,
        requiresAcid: true,
        regulatoryAuthority: 'الهيئة العامة للرقابة على الصادرات والواردات',
        priorApprovalNote: 'مطابقة قياسية وفحص مستندي',
        effectiveFrom: DateTime(2026, 1, 1),
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      tester.view.physicalSize = const Size(1400, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier([mockFile])),
            customsTariffProvider.overrideWith((ref) => _MockCustomsTariffNotifier([mockTariff])),
            purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier([_poWithHs(7, '8471.30.00')])),
            currenciesProvider.overrideWith((ref) => _MockCurrenciesNotifier([_currency('EUR', 55.0)])),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: CustomsDeclaration46Screen(
                    initialSubTab: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // 1. Verify SubTab 1 KPI Metrics Cards
      expect(find.text('إجمالي الإقرارات'), findsOneWidget);
      expect(find.text('إجمالي القيمة الجمركية (سيف)'), findsOneWidget);
      expect(find.text('إجمالي الضرائب والرسوم'), findsOneWidget);
      expect(find.text('إعفاءات الشراكة الأوروبية'), findsOneWidget);

      // 2. Verify Registry Table Columns and Data
      expect(find.text('46-ALX-FILE-2026-007'), findsOneWidget);
      expect(find.text('Siemens Industrial Automation AG'), findsOneWidget);
      expect(find.text('8471.30.00'), findsOneWidget);

      // 3. Verify Assessment Action Button and Tap to Open Dialog
      final assessmentBtn = find.byTooltip('معاينة التقييم الجمركي وبنود التعريفة');
      expect(assessmentBtn, findsOneWidget);
      await tester.ensureVisible(assessmentBtn);
      await tester.pumpAndSettle();
      await tester.tap(assessmentBtn);
      await tester.pumpAndSettle();

      // 4. Verify Assessment Dialog Content
      expect(find.text('التقييم الجمركي وبنود التعريفة — شهادة 46 ك.م'), findsOneWidget);
      expect(find.text('تفصيل وعاء القيمة للأغراض الجمركية (سيف)'), findsOneWidget);
      expect(find.text('جدول الضرائب والرسوم الجمركية المقررة'), findsOneWidget);
      expect(find.text('بيانات الشحنة والإقرار الجمركي'), findsOneWidget);
    });

    testWidgets('Missing tariff and customs FX rate show the missing banner and no computed duties', (tester) async {
      final mockFile = ImportFileModel(
        importFileId: 9,
        importFileCode: 'IMP-2026-0009',
        companyId: 1,
        companyName: 'Co',
        supplierId: 2,
        supplierName: 'Sup',
        shipmentMode: 'Sea FCL',
        incotermCode: 'FOB',
        priority: 'Normal',
        shipmentCategory: 'Commercial',
        acidNumber: '8912345678901234567',
        estimatedCost: 10000.0,
        estimatedCostCurrency: 'USD',
        status: 'Active',
        owner: 'Admin',
        progressPercent: 10.0,
        currentModule: 'Customs Clearance',
        currentStage: 'Declaration 46',
        nextAction: 'Submit Form 46',
        invoicesData: [],
        packingListsData: [],
        projectIds: [],
        skippedStages: [],
        createdAt: '2026-08-23T00:00:00Z',
        updatedAt: '2026-08-23T00:00:00Z',
      );

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier([mockFile])),
            customsTariffProvider.overrideWith((ref) => _MockCustomsTariffNotifier([])),
            purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier([])),
            currenciesProvider.overrideWith((ref) => _MockCurrenciesNotifier([_currency('USD', null)])),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            home: AppLocalizationsProvider(
              locale: Locale('en'),
              child: Scaffold(
                body: CustomsDeclaration46Screen(initialSubTab: 0, initialImportFileId: 9),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('decl46FiguresBanner')), findsOneWidget);
      expect(find.textContaining('Missing:'), findsOneWidget);
      final cif = tester.widget<TextFormField>(find.byKey(const Key('decl46CifField')));
      expect(cif.controller!.text, isEmpty, reason: 'no fake CIF/duty number may be shown');
    });

    testWidgets('FE06-T01: Selecting file with no form46No leaves field empty; submitting empty triggers required validation and makes no API call', (tester) async {
      final mockClearance = _MockCustomsClearanceNotifier();
      final mockFile = ImportFileModel(
        importFileId: 5,
        importFileCode: 'IMP-2026-0005',
        companyId: 1,
        companyName: 'Al-Sorour Logistics',
        supplierId: 2,
        supplierName: 'Milano Industrial SpA',
        shipmentMode: 'Sea FCL',
        incotermCode: 'FOB',
        priority: 'Normal',
        shipmentCategory: 'Commercial',
        acidNumber: '8912345678901234567',
        status: 'Active',
        owner: 'Admin',
        currentModule: 'Customs Clearance',
        currentStage: 'Declaration 46',
        nextAction: 'Submit Form 46',
        invoicesData: [],
        packingListsData: [],
        projectIds: [],
        skippedStages: [],
        createdAt: '2026-08-23T00:00:00Z',
        updatedAt: '2026-08-23T00:00:00Z',
      );

      tester.view.physicalSize = const Size(1400, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier([mockFile])),
            customsClearanceProvider.overrideWith((ref) => mockClearance),
            customsTariffProvider.overrideWith((ref) => _MockCustomsTariffNotifier([])),
            purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier([])),
            currenciesProvider.overrideWith((ref) => _MockCurrenciesNotifier([])),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: CustomsDeclaration46Screen(
                    initialSubTab: 0,
                    initialImportFileId: 5,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      final noField = find.byKey(const Key('decl46NoField'));
      expect(tester.widget<TextFormField>(noField).controller!.text, isEmpty);

      final saveBtn = find.byKey(const Key('saveDeclaration46Btn'));
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(mockClearance.registeredCalls, isEmpty);
      expect(find.text('هذا الحقل إلزامي'), findsOneWidget);
    });

    testWidgets('FE06-T01: Saving declaration 46 submits real payload to registerDeclaration46 and shows success', (tester) async {
      final mockClearance = _MockCustomsClearanceNotifier();
      final mockFile = ImportFileModel(
        importFileId: 5,
        importFileCode: 'IMP-2026-0005',
        companyId: 1,
        companyName: 'Al-Sorour Logistics',
        supplierId: 2,
        supplierName: 'Milano Industrial SpA',
        shipmentMode: 'Sea FCL',
        incotermCode: 'FOB',
        priority: 'Normal',
        shipmentCategory: 'Commercial',
        portOfDischarge: 'Alexandria Port',
        acidNumber: '8912345678901234567',
        status: 'Active',
        owner: 'Admin',
        currentModule: 'Customs Clearance',
        currentStage: 'Declaration 46',
        nextAction: 'Submit Form 46',
        invoicesData: [],
        packingListsData: [],
        projectIds: [],
        skippedStages: [],
        createdAt: '2026-08-23T00:00:00Z',
        updatedAt: '2026-08-23T00:00:00Z',
      );

      tester.view.physicalSize = const Size(1400, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier([mockFile])),
            customsClearanceProvider.overrideWith((ref) => mockClearance),
            customsTariffProvider.overrideWith((ref) => _MockCustomsTariffNotifier([])),
            purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier([])),
            currenciesProvider.overrideWith((ref) => _MockCurrenciesNotifier([])),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: CustomsDeclaration46Screen(
                    initialSubTab: 0,
                    initialImportFileId: 5,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      final noField = find.byKey(const Key('decl46NoField'));
      expect(noField, findsOneWidget);
      await tester.enterText(noField, '46-ALX-2026-8888');
      await tester.pump();

      final saveBtn = find.byKey(const Key('saveDeclaration46Btn'));
      expect(saveBtn, findsOneWidget);
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(mockClearance.registeredCalls.length, 1);
      final payload = mockClearance.registeredCalls.first;
      expect(payload['import_file_id'], 5);
      expect(payload['declaration_46_no'], '46-ALX-2026-8888');
      expect(payload['customs_office_name'], 'Alexandria Port Customs');
      expect(payload['channel_type'], 'Red Channel');
      expect(payload['customs_tariff_items_count'], 1);

      expect(find.text('تم قيد وحفظ مسودة الإقرار الجمركي (46 ك.م) بنجاح'), findsOneWidget);
    });

    testWidgets('FE06-T01: Backend error displays Arabic error SnackBar and preserves form inputs', (tester) async {
      final mockClearance = _MockCustomsClearanceNotifier()
        ..shouldThrow = true
        ..errorMessage = 'صلاحية رقم القيد المسبق منتهية';
      final mockFile = ImportFileModel(
        importFileId: 5,
        importFileCode: 'IMP-2026-0005',
        companyId: 1,
        companyName: 'Al-Sorour Logistics',
        supplierId: 2,
        supplierName: 'Milano Industrial SpA',
        shipmentMode: 'Sea FCL',
        incotermCode: 'FOB',
        priority: 'Normal',
        shipmentCategory: 'Commercial',
        acidNumber: '8912345678901234567',
        status: 'Active',
        owner: 'Admin',
        currentModule: 'Customs Clearance',
        currentStage: 'Declaration 46',
        nextAction: 'Submit Form 46',
        invoicesData: [],
        packingListsData: [],
        projectIds: [],
        skippedStages: [],
        createdAt: '2026-08-23T00:00:00Z',
        updatedAt: '2026-08-23T00:00:00Z',
      );

      tester.view.physicalSize = const Size(1400, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier([mockFile])),
            customsClearanceProvider.overrideWith((ref) => mockClearance),
            customsTariffProvider.overrideWith((ref) => _MockCustomsTariffNotifier([])),
            purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier([])),
            currenciesProvider.overrideWith((ref) => _MockCurrenciesNotifier([])),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: CustomsDeclaration46Screen(
                    initialSubTab: 0,
                    initialImportFileId: 5,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      final noField = find.byKey(const Key('decl46NoField'));
      await tester.enterText(noField, '46-ALX-2026-9999');
      await tester.pump();

      final saveBtn = find.byKey(const Key('saveDeclaration46Btn'));
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(mockClearance.registeredCalls.length, 1);
      expect(find.textContaining('صلاحية رقم القيد المسبق منتهية'), findsOneWidget);
      expect(tester.widget<TextFormField>(noField).controller!.text, '46-ALX-2026-9999');
    });

    testWidgets('FE06-T01: Date field is read-only and opens DatePickerDialog on tap', (tester) async {
      final mockFile = ImportFileModel(
        importFileId: 5,
        importFileCode: 'IMP-2026-0005',
        companyId: 1,
        companyName: 'Al-Sorour Logistics',
        supplierId: 2,
        supplierName: 'Milano Industrial SpA',
        shipmentMode: 'Sea FCL',
        incotermCode: 'FOB',
        priority: 'Normal',
        shipmentCategory: 'Commercial',
        acidNumber: '8912345678901234567',
        status: 'Active',
        owner: 'Admin',
        currentModule: 'Customs Clearance',
        currentStage: 'Declaration 46',
        nextAction: 'Submit Form 46',
        invoicesData: [],
        packingListsData: [],
        projectIds: [],
        skippedStages: [],
        createdAt: '2026-08-23T00:00:00Z',
        updatedAt: '2026-08-23T00:00:00Z',
      );

      tester.view.physicalSize = const Size(1400, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier([mockFile])),
            customsClearanceProvider.overrideWith((ref) => _MockCustomsClearanceNotifier()),
            customsTariffProvider.overrideWith((ref) => _MockCustomsTariffNotifier([])),
            purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier([])),
            currenciesProvider.overrideWith((ref) => _MockCurrenciesNotifier([])),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: CustomsDeclaration46Screen(
                    initialSubTab: 0,
                    initialImportFileId: 5,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      final dateField = find.byKey(const Key('decl46DateField'));
      expect(dateField, findsOneWidget);
      final editable = tester.widget<EditableText>(find.descendant(of: dateField, matching: find.byType(EditableText)));
      expect(editable.readOnly, isTrue);

      await tester.tap(dateField);
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('FE06-T01: Selecting file with form46Date then file without one resets declaration date and matches payload', (tester) async {
      final mockClearance = _MockCustomsClearanceNotifier();
      final fileWithDate = ImportFileModel(
        importFileId: 5,
        importFileCode: 'IMP-2026-0005',
        companyId: 1,
        companyName: 'Al-Sorour Logistics',
        supplierId: 2,
        supplierName: 'Milano Industrial SpA',
        shipmentMode: 'Sea FCL',
        incotermCode: 'FOB',
        priority: 'Normal',
        shipmentCategory: 'Commercial',
        acidNumber: '8912345678901234567',
        status: 'Active',
        owner: 'Admin',
        currentModule: 'Customs Clearance',
        currentStage: 'Declaration 46',
        nextAction: 'Submit Form 46',
        form46No: '46-ALX-2026-1111',
        form46Date: '2026-05-10',
        invoicesData: [],
        packingListsData: [],
        projectIds: [],
        skippedStages: [],
        createdAt: '2026-08-23T00:00:00Z',
        updatedAt: '2026-08-23T00:00:00Z',
      );

      final fileWithoutDate = ImportFileModel(
        importFileId: 6,
        importFileCode: 'IMP-2026-0006',
        companyId: 1,
        companyName: 'Al-Sorour Logistics',
        supplierId: 2,
        supplierName: 'Milano Industrial SpA',
        shipmentMode: 'Sea FCL',
        incotermCode: 'FOB',
        priority: 'Normal',
        shipmentCategory: 'Commercial',
        acidNumber: '8912345678901234568',
        status: 'Active',
        owner: 'Admin',
        currentModule: 'Customs Clearance',
        currentStage: 'Declaration 46',
        nextAction: 'Submit Form 46',
        form46No: '46-ALX-2026-2222',
        form46Date: null,
        invoicesData: [],
        packingListsData: [],
        projectIds: [],
        skippedStages: [],
        createdAt: '2026-08-23T00:00:00Z',
        updatedAt: '2026-08-23T00:00:00Z',
      );

      tester.view.physicalSize = const Size(1400, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier([fileWithDate, fileWithoutDate])),
            customsClearanceProvider.overrideWith((ref) => mockClearance),
            customsTariffProvider.overrideWith((ref) => _MockCustomsTariffNotifier([])),
            purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier([])),
            currenciesProvider.overrideWith((ref) => _MockCurrenciesNotifier([])),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: CustomsDeclaration46Screen(
                    initialSubTab: 0,
                    initialImportFileId: 5,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      final dateField = find.byKey(const Key('decl46DateField'));
      expect(dateField, findsOneWidget);
      expect(tester.widget<TextFormField>(dateField).controller!.text, '2026-05-10');

      final dropdown = find.byKey(const Key('decl46FileDropdown'));
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      final itemFile6 = find.textContaining('IMP-2026-0006');
      expect(itemFile6, findsWidgets);
      await tester.tap(itemFile6.first);
      await tester.pumpAndSettle();

      final todayIso = DateTime.now().toIso8601String().substring(0, 10);
      final visibleDate = tester.widget<TextFormField>(dateField).controller!.text;
      expect(visibleDate, todayIso);

      final saveBtn = find.byKey(const Key('saveDeclaration46Btn'));
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(mockClearance.registeredCalls.length, 1);
      final payload = mockClearance.registeredCalls.first;
      expect(payload['import_file_id'], 6);
      expect((payload['declaration_46_date'] as String).startsWith(visibleDate), isTrue);
    });
  });
}
