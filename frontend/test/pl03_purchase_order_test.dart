import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/widgets/searchable_dropdown_field.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/currencies/providers/currencies_provider.dart';
import 'package:frontend/features/customs_tariff/models/customs_tariff_model.dart';
import 'package:frontend/features/customs_tariff/providers/customs_tariff_provider.dart';
import 'package:frontend/features/import_companies/models/import_company_model.dart';
import 'package:frontend/features/import_companies/providers/import_companies_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart' hide PackingListItemModel;
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/incoterms/models/incoterm_model.dart';
import 'package:frontend/features/incoterms/providers/incoterms_provider.dart';
import 'package:frontend/features/projects/models/project_model.dart';
import 'package:frontend/features/projects/providers/projects_provider.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/purchase_orders/screens/purchase_orders_screen.dart';
import 'package:frontend/features/purchase_orders/widgets/po_form_dialog.dart';
import 'package:frontend/features/suppliers/models/supplier_model.dart';
import 'package:frontend/features/suppliers/providers/suppliers_provider.dart';

class MockImportCompaniesNotifier extends ImportCompaniesNotifier {
  MockImportCompaniesNotifier(List<ImportCompanyModel> list)
      : super(showInactive: true, dio: Dio()) {
    state = AsyncValue.data(list);
  }
  @override
  Future<void> fetchCompanies() async {}
}

class MockSuppliersNotifier extends SuppliersNotifier {
  MockSuppliersNotifier(List<SupplierModel> list)
      : super(showInactive: true, dio: Dio()) {
    state = AsyncValue.data(list);
  }
  @override
  Future<void> fetchSuppliers() async {}
}

class MockProjectsNotifier extends ProjectsNotifier {
  MockProjectsNotifier(List<ProjectModel> list) : super(Dio()) {
    state = AsyncValue.data(list);
  }
  @override
  Future<void> fetchProjects({bool includeInactive = true, String? status, String? search}) async {}
}

class MockIncotermsNotifier extends IncotermsNotifier {
  MockIncotermsNotifier(Ref ref, List<IncotermModel> list)
      : super(ref: ref, showInactive: true, dio: Dio()) {
    state = AsyncValue.data(list);
  }
  @override
  Future<void> fetchIncoterms() async {}
}

class MockCurrenciesNotifier extends CurrenciesNotifier {
  MockCurrenciesNotifier(List<CurrencyModel> list) : super(Dio()) {
    state = AsyncValue.data(list);
  }
  @override
  Future<void> fetchCurrencies({bool includeInactive = true, String? search}) async {}
}

class MockCustomsTariffNotifier extends CustomsTariffNotifier {
  MockCustomsTariffNotifier(Ref ref, List<CustomsTariffModel> list)
      : super(ref: ref, showInactive: true, search: '', dio: Dio()) {
    state = AsyncValue.data(list);
  }
  @override
  Future<void> fetchTariffs() async {}
}

class MockImportFilesNotifier extends ImportFilesNotifier {
  MockImportFilesNotifier(List<ImportFileModel> files) : super(Dio()) {
    state = AsyncValue.data(files);
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
  MockPurchaseOrdersNotifier(Ref ref, List<PurchaseOrderModel> orders) : super(Dio(), ref) {
    state = PurchaseOrdersState(
      purchaseOrders: orders,
      isLoading: false,
    );
  }
  @override
  Future<void> fetchPurchaseOrders() async {}
  @override
  Future<String?> createPurchaseOrder(PurchaseOrderModel po) async => null;
}

class MockLocaleNotifier extends LocaleNotifier {
  MockLocaleNotifier() : super() {
    state = const Locale('ar');
  }
  @override
  Future<void> toggleLocale() async {}
}

void main() {
  final sampleCompanies = [
    ImportCompanyModel(
      companyId: 1,
      importerName: 'المتحدة للتوريدات الصناعية',
      address: 'العاشر من رمضان',
      country: 'Egypt',
      importerId: 'IMP-1122',
      importerIdExpiry: DateTime.now().add(const Duration(days: 365)),
      vatId: '123456789',
      vatIdExpiry: DateTime.now().add(const Duration(days: 365)),
      registrationNumber: '98765',
      registrationExpiry: DateTime.now().add(const Duration(days: 365)),
    ),
  ];

  final sampleSuppliers = [
    SupplierModel(
      supplierId: 10,
      supplierCode: 'SUP-010',
      companyName: 'Siemens Industrial Solutions GmbH',
      supplierType: 'Manufacturer',
      registrationType: 'CargoX',
      foreignExporterId: 'EXP-9900',
      foreignExporterCountry: 'Germany',
      foreignExporterCountryCode: 'DE',
      address: 'Munich, Germany',
    ),
  ];

  final sampleProjects = [
    ProjectModel(
      projectId: 100,
      projectCode: 'PRJ-2026-PL03',
      projectName: 'مشروع محطة تبريد وتكييف مصنع الدلتا',
      projectOwner: 'م. أحمد الشناوي',
      companyId: 1,
      supplierId: 10,
      incotermId: 1,
      totalBudgetUsd: 100000.0,
      totalCommittedUsd: 60000.0,
      poCount: 2,
      remainingBudgetUsd: 40000.0,
    ),
  ];

  final sampleIncoterms = [
    IncotermModel.fromJson({
      'incoterm_id': 1,
      'incoterm_code': 'FOB',
      'incoterm_name': 'Free On Board',
      'version': '2020',
      'is_active': true,
    }),
    IncotermModel.fromJson({
      'incoterm_id': 2,
      'incoterm_code': 'CIF',
      'incoterm_name': 'Cost, Insurance, and Freight',
      'version': '2020',
      'is_active': true,
    }),
  ];

  final sampleCurrencies = [
    CurrencyModel(currencyId: 1, currencyCode: 'USD', currencyName: 'US Dollar', currencySymbol: '\$'),
    CurrencyModel(currencyId: 2, currencyCode: 'EUR', currencyName: 'Euro', currencySymbol: '€'),
  ];

  final sampleTariffs = [
    CustomsTariffModel.fromJson({
      'tariff_id': 1,
      'hs_code': '8415820010',
      'hs_description': 'وحدات تكييف وتبريد صناعية مركزية',
      'customs_duty_rate': 5.0,
      'vat_rate': 14.0,
      'schedule_tax_rate': 0.0,
      'development_fee_rate': 0.0,
      'import_fee_rate': 0.0,
      'customs_service_fee_rate': 1.0,
      'is_active': true,
    }),
  ];

  final List<ImportFileModel> sampleImportFiles = [
    ImportFileModel.fromJson({
      'import_file_id': 50,
      'import_file_code': 'IMP-2026-0050',
      'company_name': 'المتحدة للتوريدات الصناعية',
      'supplier_name': 'Siemens Industrial Solutions GmbH',
      'shipment_mode': 'Sea FCL',
      'status': 'Phase 1: Import Planning & Feasibility',
      'current_module': 'BP-001',
      'current_stage': 'Draft',
      'next_action': 'Create PO',
      'created_at': '2026-01-01T00:00:00',
      'updated_at': '2026-01-01T00:00:00',
    }),
  ];

  final samplePOs = [
    PurchaseOrderModel(
      poId: 1,
      poNumber: 'PO-2026-0001',
      poReference: 'Delta Factory Cooling Units Order',
      proformaInvoiceNumber: 'PI-DE-2026-8801',
      countryOfOrigin: 'DE - Germany',
      projectId: 100,
      projectName: 'مشروع محطة تبريد وتكييف مصنع الدلتا',
      companyId: 1,
      companyName: 'المتحدة للتوريدات الصناعية',
      supplierId: 10,
      supplierName: 'Siemens Industrial Solutions GmbH',
      incotermId: 1,
      incotermCode: 'FOB',
      currencyId: 1,
      currencyCode: 'USD',
      exchangeRate: 50.0,
      paymentTerms: 'LC at Sight / اعتماد مستندي',
      status: 'Draft',
      totalAmountFob: 60000.0,
      totalCbm: 30.8,
      totalGrossWeightKg: 9000.0,
      totalNetWeightKg: 8400.0,
      totalPackagesCount: 2,
      palletCount: 0,
      items: [
        POLineItemModel(
          itemId: 1,
          poId: 1,
          itemCode: 'CHILLER-500KW',
          mainDescription: 'Industrial Water Chiller 500kW',
          descriptionAr: 'وحدة تبريد مياه صناعية 500 كيلوواط',
          quantity: 2.0,
          unitPrice: 25000.0,
          totalPrice: 50000.0,
          cbmPerUnit: 12.5,
          totalCbm: 25.0,
          grossWeightKg: 4500.0,
          netWeightKg: 4200.0,
          hsCode: '8415820010',
          dutyRate: 5.0,
          vatRate: 14.0,
        ),
        POLineItemModel(
          itemId: 2,
          poId: 1,
          itemCode: 'PUMP-CIRC-50',
          mainDescription: 'Primary Circulation Pumps',
          descriptionAr: 'طلمبات تدوير مياه التبريد الأولية',
          quantity: 4.0,
          unitPrice: 2500.0,
          totalPrice: 10000.0,
          cbmPerUnit: 1.25,
          totalCbm: 5.0,
          grossWeightKg: 350.0,
          netWeightKg: 320.0,
          hsCode: '8415820010',
          dutyRate: 5.0,
          vatRate: 14.0,
        ),
      ],
      packingListItems: [
        PackingListItemModel(
          packingItemId: 1,
          poId: 1,
          hsCode: '8415820010',
          itemCode: 'CHILLER-500KW',
          mainDescription: 'Industrial Water Chiller 500kW',
          description: '2 Heavy Duty Wooden Crates',
          qtyPcs: 2.0,
          qtyPkg: 2.0,
          packageType: 'Crate',
          lengthCm: 350.0,
          widthCm: 200.0,
          heightCm: 220.0,
          netWeightUnitKg: 4200.0,
          grossWeightUnitKg: 4500.0,
          totalNetWeightKg: 8400.0,
          totalGrossWeightKg: 9000.0,
          totalCbm: 30.8,
          isStackable: false,
        ),
      ],
    ),
  ];

  group('PL-03: Purchase Order Registration & Commitments Test Suite', () {
    test('PurchaseOrderModel & ProjectModel serialization and commitment fields', () {
      final po = samplePOs.first;
      expect(po.poNumber, 'PO-2026-0001');
      expect(po.totalAmountFob, 60000.0);
      expect(po.totalCbm, 30.8);
      expect(po.totalGrossWeightKg, 9000.0);
      expect(po.items.length, 2);
      expect(po.packingListItems.length, 1);
      expect(po.packingListItems.first.isStackable, false);

      final poJson = po.toJson();
      expect(poJson['po_reference'], 'Delta Factory Cooling Units Order');
      expect(poJson['proforma_invoice_number'], 'PI-DE-2026-8801');
      expect(poJson['items'], isA<List>());

      final project = sampleProjects.first;
      expect(project.totalBudgetUsd, 100000.0);
      expect(project.totalCommittedUsd, 60000.0);
      expect(project.poCount, 2);
      expect(project.remainingBudgetUsd, 40000.0);
    });

    testWidgets('POFormDialog renders SearchableDropdown fields and protects with form validation', (tester) async {
      tester.view.physicalSize = const Size(1400, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) => MockLocaleNotifier()),
            purchaseOrdersProvider.overrideWith((ref) => MockPurchaseOrdersNotifier(ref, samplePOs)),
            importCompaniesProvider.overrideWith((ref) => MockImportCompaniesNotifier(sampleCompanies)),
            suppliersProvider.overrideWith((ref) => MockSuppliersNotifier(sampleSuppliers)),
            projectsProvider.overrideWith((ref) => MockProjectsNotifier([])),
            incotermsProvider.overrideWith((ref) => MockIncotermsNotifier(ref, sampleIncoterms)),
            currenciesProvider.overrideWith((ref) => MockCurrenciesNotifier(sampleCurrencies)),
            customsTariffProvider.overrideWith((ref) => MockCustomsTariffNotifier(ref, sampleTariffs)),
            importFilesProvider.overrideWith((ref) => MockImportFilesNotifier(sampleImportFiles)),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            home: Scaffold(
              body: Directionality(
                textDirection: TextDirection.rtl,
                child: AppLocalizationsProvider(
                  locale: Locale('ar'),
                  child: POFormDialog(po: null),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Title & Header
      expect(find.text('أمر شراء جديد'), findsWidgets);

      // Verify Mandatory Master Data Dropdowns are present
      expect(find.byType(SearchableDropdownField<int?>), findsWidgets);

      // Verify Save button exists
      final saveBtnFinder = find.text('حفظ أمر الشراء');
      expect(saveBtnFinder, findsOneWidget);

      // Attempt submit without filling required fields
      await tester.tap(saveBtnFinder);
      await tester.pumpAndSettle();

      // Form validation error should prevent submission and show snackbar notification
      expect(
        find.text('الرجاء التأكد من اختيار كافة الحقول الإلزامية (المشروع، الشركة المستوردة، المورد، الـ Incoterm والعملة).'),
        findsOneWidget,
      );
    });

    testWidgets('PurchaseOrdersScreen displays metric strip and project commitments', (tester) async {
      tester.view.physicalSize = const Size(1400, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) => MockLocaleNotifier()),
            purchaseOrdersProvider.overrideWith((ref) => MockPurchaseOrdersNotifier(ref, samplePOs)),
            projectsProvider.overrideWith((ref) => MockProjectsNotifier(sampleProjects)),
            importFilesProvider.overrideWith((ref) => MockImportFilesNotifier(sampleImportFiles)),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            home: Scaffold(
              body: Directionality(
                textDirection: TextDirection.rtl,
                child: AppLocalizationsProvider(
                  locale: Locale('ar'),
                  child: PurchaseOrdersScreen(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Metrics Strip
      expect(find.text('أوامر الشراء والفواتير المبدئية'), findsOneWidget);
      expect(find.text('أمر شراء جديد'), findsOneWidget);

      // Check Metric cards values
      expect(find.text('1'), findsWidgets); // 1 PO
      expect(find.text('\$60000.00'), findsOneWidget); // Total FOB Amount
      expect(find.text('30.80 m³'), findsOneWidget); // Total CBM
      expect(find.text('9000 kg'), findsOneWidget); // Total Gross Weight (PoPackingMatcher.formatWeight trims .0)

      // Check PO Table row
      expect(find.text('PO-2026-0001'), findsOneWidget);
      expect(find.text('Siemens Industrial Solutions GmbH'), findsOneWidget);
    });
  });
}
