import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/widgets/smart_upload_button.dart';
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
      foreignExporterId: 'DE129274202',
      foreignExporterCountry: 'Germany',
      foreignExporterCountryCode: 'DE',
      address: 'Munich, Germany',
    ),
  ];

  final sampleProjects = [
    ProjectModel(
      projectId: 100,
      projectCode: 'PRJ-2026-PL04',
      projectName: 'مشروع محطة تبريد وتكييف مصنع الدلتا',
      projectOwner: 'م. أحمد الشناوي',
      companyId: 1,
      supplierId: 10,
      incotermId: 1,
      totalBudgetUsd: 100000.0,
      totalCommittedUsd: 60000.0,
      poCount: 1,
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
  ];

  final sampleCurrencies = [
    CurrencyModel(currencyId: 1, currencyCode: 'EUR', currencyName: 'Euro', currencySymbol: '€'),
    CurrencyModel(currencyId: 2, currencyCode: 'USD', currencyName: 'US Dollar', currencySymbol: '\$'),
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

  final sampleExtractedFields = {
    'po_number': 'PI-2026-DE-8890',
    'po_reference': 'Delta Factory Cooling Units Order',
    'supplier_name': 'Siemens Industrial Solutions GmbH',
    'importer_name': 'المتحدة للتوريدات الصناعية',
    'country_of_origin': 'DE - ألمانيا (Germany)',
    'currency': 'EUR',
    'incoterms': 'FOB',
    'payment_terms': 'Letter of Credit / LC',
    'acid_number': '1987654321098765432',
    'total_amount': 60000.0,
    'pallet_count': 2,
    'pallet_type': 'Euro Pallet (120x80)',
    'items': [
      {
        'item_code': 'CHILLER-500',
        'main_description': 'Industrial Water Chiller 500kW High Eff',
        'description': 'وحدة تبريد مياه صناعية 500 كيلوواط',
        'quantity': 2.0,
        'unit_price': 25000.0,
        'hs_code': '8415820010',
        'cbm_per_unit': 12.5,
        'gross_weight_kg': 4500.0,
        'net_weight_kg': 4200.0,
      },
      {
        'item_code': 'PUMP-CIRC-50',
        'main_description': 'Primary Circulation Pump 50m3/h',
        'description': 'طلمبات تدوير مياه التبريد الأولية',
        'quantity': 4.0,
        'unit_price': 2500.0,
        'hs_code': '8415820010',
        'cbm_per_unit': 1.25,
        'gross_weight_kg': 350.0,
        'net_weight_kg': 320.0,
      }
    ],
    'packing_list_items': [
      {
        'item_code': 'CHILLER-500',
        'package_type': 'Wooden Crate',
        'qty_pkg': 2.0,
        'qty_pcs': 2.0,
        'length_cm': 350.0,
        'width_cm': 200.0,
        'height_cm': 220.0,
        'net_weight_unit_kg': 4200.0,
        'gross_weight_unit_kg': 4500.0,
        'total_net_weight_kg': 8400.0,
        'total_gross_weight_kg': 9000.0,
        'total_cbm': 30.8,
        'is_stackable': false,
      }
    ]
  };

  group('PL-04: Smart Doc Extraction Test Suite', () {
    test('SmartUploadResult model parses and formats extraction payload correctly', () {
      final uploadResult = SmartUploadResult(
        sessionId: 88,
        sessionRef: 'SES-PL04-0088',
        moduleName: 'purchase-order',
        filename: 'proforma_invoice_8890.pdf',
        fileType: 'pdf',
        extractionStatus: 'SUCCESS',
        confidenceScore: 0.96,
        extractedFields: sampleExtractedFields,
        missingFields: [],
        supplierVerified: true,
        supplierId: 10,
        importerVerified: true,
        importerDbId: 1,
      );

      expect(uploadResult.isSuccess, isTrue);
      expect(uploadResult.confidencePercent, 96);
      expect(uploadResult.extractedFields['po_number'], 'PI-2026-DE-8890');
      expect(uploadResult.extractedFields['currency'], 'EUR');
      expect(uploadResult.extractedFields['total_amount'], 60000.0);

      final copy = uploadResult.copyWith(confidenceScore: 0.99);
      expect(copy.confidencePercent, 99);
      expect(copy.sessionId, 88);
    });

    testWidgets('PurchaseOrdersScreen renders SmartUploadButton in toolbar actions', (tester) async {
      tester.view.physicalSize = const Size(1400, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) => MockLocaleNotifier()),
            purchaseOrdersProvider.overrideWith((ref) => MockPurchaseOrdersNotifier(ref, [])),
            projectsProvider.overrideWith((ref) => MockProjectsNotifier(sampleProjects)),
            importFilesProvider.overrideWith((ref) => MockImportFilesNotifier([])),
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

      // Verify SmartUploadButton is present in PageHeader
      expect(find.byType(SmartUploadButton), findsOneWidget);
      expect(find.textContaining('استخراج الفاتورة والتعبئة الذكي'), findsOneWidget);
    });

    testWidgets('POFormDialog header renders SmartUploadButton and auto-fills from extracted data', (tester) async {
      tester.view.physicalSize = const Size(1400, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sampleExtractedFields = <String, dynamic>{
        'pi_number': 'PI-2026-DE-8890',
        'po_reference': 'Delta Factory Cooling Units Order',
        'order_date': '2026-09-17',
        'country_of_origin': 'Germany',
        'currency_code': 'USD',
        'incoterm_code': 'FOB',
        'line_items': [
          {
            'item_code': 'CHILLER-500',
            'commercial_name': 'وحدة تبريد مياه صناعية 500 كيلوواط',
            'quantity': 2.0,
            'unit_price': 30000.0,
            'uom': 'UNIT',
          },
          {
            'item_code': 'PUMP-CIRC-50',
            'commercial_name': 'طلمبات تدوير مياه التبريد الأولية',
            'quantity': 4.0,
            'unit_price': 6000.0,
            'uom': 'UNIT',
          },
        ],
        'packing_list': [
          {
            'package_type': 'CRATE',
            'package_count': 2,
            'length_cm': 320.0,
            'width_cm': 200.0,
            'height_cm': 240.0,
            'gross_weight_kg': 8400.0,
            'net_weight_kg': 7800.0,
            'cbm': 30.72,
          },
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) => MockLocaleNotifier()),
            purchaseOrdersProvider.overrideWith((ref) => MockPurchaseOrdersNotifier(ref, [])),
            importCompaniesProvider.overrideWith((ref) => MockImportCompaniesNotifier(sampleCompanies)),
            suppliersProvider.overrideWith((ref) => MockSuppliersNotifier(sampleSuppliers)),
            projectsProvider.overrideWith((ref) => MockProjectsNotifier(sampleProjects)),
            incotermsProvider.overrideWith((ref) => MockIncotermsNotifier(ref, sampleIncoterms)),
            currenciesProvider.overrideWith((ref) => MockCurrenciesNotifier(sampleCurrencies)),
            customsTariffProvider.overrideWith((ref) => MockCustomsTariffNotifier(ref, sampleTariffs)),
            importFilesProvider.overrideWith((ref) => MockImportFilesNotifier([])),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            home: Scaffold(
              body: Directionality(
                textDirection: TextDirection.rtl,
                child: AppLocalizationsProvider(
                  locale: const Locale('ar'),
                  child: POFormDialog(
                    po: null,
                    initialExtractedFields: sampleExtractedFields,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify SmartUploadButton exists in dialog (both header and tabs)
      expect(find.byType(SmartUploadButton), findsWidgets);
      expect(find.text('🚀 استخلاص ذكي للمستندات'), findsOneWidget);

      // 2. Verify prefilled Proforma Invoice Number & PO Reference
      expect(find.text('PI-2026-DE-8890'), findsOneWidget);
      expect(find.text('Delta Factory Cooling Units Order'), findsOneWidget);

      // 3. Verify extracted items count reflected on Tabs
      expect(find.textContaining('بنود الفاتورة المبدئية (2)'), findsOneWidget);
      expect(find.textContaining('بيان التعبئة والوزن (1)'), findsOneWidget);

      // 4. Verify line item details are rendered
      expect(find.text('CHILLER-500'), findsOneWidget);
      expect(find.text('PUMP-CIRC-50'), findsOneWidget);
      expect(find.text('وحدة تبريد مياه صناعية 500 كيلوواط'), findsOneWidget);
      expect(find.text('طلمبات تدوير مياه التبريد الأولية'), findsOneWidget);

      // 5. Verify prices and totals are reflected
      expect(find.textContaining('60000.00'), findsWidgets);
      expect(find.textContaining('24000.00'), findsWidgets);
    });
  });
}
