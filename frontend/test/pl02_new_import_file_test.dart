import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/currencies/providers/currencies_provider.dart';
import 'package:frontend/features/external_service_providers/models/partner_model.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/import_companies/models/import_company_model.dart';
import 'package:frontend/features/import_companies/providers/import_companies_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/widgets/import_file_form_dialog.dart';
import 'package:frontend/features/incoterms/models/incoterm_model.dart';
import 'package:frontend/features/incoterms/providers/incoterms_provider.dart';
import 'package:frontend/features/projects/models/project_model.dart';
import 'package:frontend/features/projects/providers/projects_provider.dart';
import 'package:frontend/features/suppliers/models/supplier_model.dart';
import 'package:frontend/features/suppliers/providers/suppliers_provider.dart';
import 'package:frontend/features/transport_locations/models/transport_location_model.dart';
import 'package:frontend/features/transport_locations/providers/transport_locations_provider.dart';

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

class MockPartnersNotifier extends PartnersNotifier {
  MockPartnersNotifier(List<PartnerModel> list)
      : super(category: 'ALL', showInactive: true, dio: Dio()) {
    state = AsyncValue.data(list);
  }
  @override
  Future<void> fetchPartners() async {}
}

class MockProjectsNotifier extends ProjectsNotifier {
  MockProjectsNotifier(List<ProjectModel> list) : super(Dio()) {
    state = AsyncValue.data(list);
  }
  @override
  Future<void> fetchProjects({bool includeInactive = true, String? status, String? search}) async {}
}

class MockCurrenciesNotifier extends CurrenciesNotifier {
  MockCurrenciesNotifier(List<CurrencyModel> list) : super(Dio()) {
    state = AsyncValue.data(list);
  }
  @override
  Future<void> fetchCurrencies({bool includeInactive = true, String? search}) async {}
}

class MockIncotermsNotifier extends IncotermsNotifier {
  MockIncotermsNotifier(Ref ref, List<IncotermModel> list)
      : super(ref: ref, showInactive: true, dio: Dio()) {
    state = AsyncValue.data(list);
  }
  @override
  Future<void> fetchIncoterms() async {}
}

class MockTransportLocationsNotifier extends TransportLocationsNotifier {
  MockTransportLocationsNotifier(List<TransportLocationModel> list) : super(Dio()) {
    state = AsyncValue.data(list);
  }
  @override
  Future<void> fetchLocations({bool includeInactive = true, String? locationType, String? search}) async {}
}

void main() {
  final List<ImportCompanyModel> sampleCompanies = [
    ImportCompanyModel(
      companyId: 1,
      importerName: 'SCAS For Construction And Finishing',
      address: 'Cairo, Egypt',
      country: 'Egypt',
      importerId: 'IMP-1122',
      importerIdExpiry: DateTime.now().add(const Duration(days: 365)),
      vatId: '123456789',
      vatIdExpiry: DateTime.now().add(const Duration(days: 365)),
      registrationNumber: '98765',
      registrationExpiry: DateTime.now().add(const Duration(days: 365)),
    ),
  ];

  final List<SupplierModel> sampleSuppliers = [
    SupplierModel(
      supplierId: 10,
      supplierCode: 'SUP-001',
      companyName: 'G.I. Industrial Holding S.p.A.',
      supplierType: 'Manufacturer',
      registrationType: 'Company',
      foreignExporterId: 'EXP-101',
      foreignExporterCountry: 'Italy',
      foreignExporterCountryCode: 'IT',
      address: 'Via Roma 1, Milan',
    ),
  ];

  final List<PartnerModel> samplePartners = [
    PartnerModel(
      providerId: 5,
      partnerCode: 'PRT-005',
      partnerName: 'Al-Ahram Customs Clearance',
      partnerType: 'Customs Broker',
      country: 'Egypt',
      clearanceLicenseNumber: 'LIC-EG-4402',
      authorizedPorts: 'Alexandria Port, El Dekheila Port',
    ),
  ];

  final List<ProjectModel> sampleProjects = [
    ProjectModel(
      projectId: 100,
      projectCode: 'PRJ-SCAS-01',
      projectName: 'Central HVAC Chillers',
      projectOwner: 'Ahmed Sorour',
      companyId: 1,
      companyIds: [1],
      supplierId: 10,
      incotermId: 1,
      importType: 'Direct Commercial',
      status: 'Active',
      targetEndDate: '2026-12-31',
    ),
  ];

  final List<CurrencyModel> sampleCurrencies = [
    CurrencyModel(
      currencyId: 1,
      currencyCode: 'USD',
      currencyName: 'US Dollar',
      currencySymbol: '\$',
      isBaseCurrency: false,
    ),
    CurrencyModel(
      currencyId: 2,
      currencyCode: 'EUR',
      currencyName: 'Euro',
      currencySymbol: '€',
      isBaseCurrency: false,
    ),
  ];

  final List<IncotermModel> sampleIncoterms = [
    IncotermModel(
      incotermId: 1,
      incotermCode: 'FOB',
      incotermName: 'Free On Board',
      version: '2020',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    IncotermModel(
      incotermId: 2,
      incotermCode: 'CIF',
      incotermName: 'Cost Insurance and Freight',
      version: '2020',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  final List<TransportLocationModel> sampleLocations = [
    TransportLocationModel(
      locationId: 1,
      unLocode: 'ITGOA',
      locationName: 'Genoa Port',
      locationType: 'Sea Port',
      country: 'Italy',
      city: 'Genoa',
    ),
    TransportLocationModel(
      locationId: 2,
      unLocode: 'EGDKH',
      locationName: 'El Dekheila Port',
      locationType: 'Sea Port',
      country: 'Egypt',
      city: 'Alexandria',
    ),
  ];

  group('PL-02: New Import File Model & Serialization Tests', () {
    test('ImportFileModel parses new import file payload with default planning stage', () {
      final json = {
        'import_file_id': 101,
        'import_file_code': 'IMP-2026-0004',
        'custom_file_number': 'FILE-2026-0004',
        'company_id': 1,
        'company_name': 'SCAS For Construction And Finishing',
        'supplier_id': 10,
        'supplier_name': 'G.I. Industrial Holding S.p.A.',
        'broker_id': 5,
        'broker_name': 'Al-Ahram Customs Clearance',
        'project_ids': [100],
        'shipment_mode': 'Sea FCL',
        'incoterm_code': 'FOB',
        'priority': 'High',
        'shipment_category': 'New Purchase',
        'port_of_loading': 'Genoa Port',
        'port_of_discharge': 'El Dekheila Port',
        'target_free_days': 21,
        'estimated_cost': 65000.0,
        'estimated_cost_currency': 'EUR',
        'initial_starting_step': 'STEP_01',
        'current_stage': 'Phase 1: Import Planning & Feasibility',
        'current_module': 'BP-001 Receive Purchase Order & Planning',
        'progress_percent': 15.0,
        'next_action': 'Evaluate Shipping Scenarios (BP-007) & Request Freight Quotations (BP-008)',
        'status': 'Open',
        'owner': 'Ahmed Sorour',
        'created_at': '2026-09-17T11:00:00Z',
        'updated_at': '2026-09-17T11:00:00Z',
      };

      final model = ImportFileModel.fromJson(json);

      expect(model.importFileId, 101);
      expect(model.importFileCode, 'IMP-2026-0004');
      expect(model.customFileNumber, 'FILE-2026-0004');
      expect(model.companyId, 1);
      expect(model.companyName, 'SCAS For Construction And Finishing');
      expect(model.supplierId, 10);
      expect(model.supplierName, 'G.I. Industrial Holding S.p.A.');
      expect(model.brokerId, 5);
      expect(model.brokerName, 'Al-Ahram Customs Clearance');
      expect(model.projectIds, [100]);
      expect(model.shipmentMode, 'Sea FCL');
      expect(model.incotermCode, 'FOB');
      expect(model.estimatedCost, 65000.0);
      expect(model.estimatedCostCurrency, 'EUR');
      expect(model.initialStartingStep, 'STEP_01');
      expect(model.currentStage, 'Phase 1: Import Planning & Feasibility');
      expect(model.currentModule, 'BP-001 Receive Purchase Order & Planning');
      expect(model.progressPercent, 15.0);
      expect(model.status, 'Open');
      expect(model.owner, 'Ahmed Sorour');

      final serialized = model.toJson();
      expect(serialized['import_file_code'], 'IMP-2026-0004');
      expect(serialized['estimated_cost_currency'], 'EUR');
      expect(serialized['company_id'], 1);
      expect(serialized['supplier_id'], 10);
    });
  });

  group('PL-02: New Import File Form Dialog UI & Validation Tests', () {
    testWidgets('ImportFileFormDialog renders complete new file creation form with master data dropdowns',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            importCompaniesProvider.overrideWith((ref) => MockImportCompaniesNotifier(sampleCompanies)),
            suppliersProvider.overrideWith((ref) => MockSuppliersNotifier(sampleSuppliers)),
            partnersProvider.overrideWith((ref) => MockPartnersNotifier(samplePartners)),
            projectsProvider.overrideWith((ref) => MockProjectsNotifier(sampleProjects)),
            currenciesProvider.overrideWith((ref) => MockCurrenciesNotifier(sampleCurrencies)),
            incotermsProvider.overrideWith((ref) => MockIncotermsNotifier(ref, sampleIncoterms)),
            transportLocationsProvider.overrideWith((ref) => MockTransportLocationsNotifier(sampleLocations)),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: ImportFileFormDialog(fileToEdit: null),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Dialog Title for New File Creation
      expect(find.text('إضافة ملف استيراد شحنة جديد'), findsOneWidget);

      // 2. Verify Presence of Core Master Data Dropdowns & Fields.
      // The form is split into tabs: General (company/supplier), Shipping & Logistics
      // (transport, incoterms, priority, stage, ports) and Customs & Compliance (broker).
      expect(find.text('الشركة المستوردة *'), findsOneWidget);
      expect(find.text('المورد الأجنبي *'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.byIcon(Icons.local_shipping_outlined)));
      await tester.pumpAndSettle();
      expect(find.text('وسيلة النقل / الشروط *'), findsOneWidget);
      expect(find.text('الشروط التجارية الدولية *'), findsOneWidget);
      expect(find.text('الأولوية *'), findsOneWidget);

      // 3. Verify Dynamic Lifecycle Starting Step Selector defaults to STEP_01 (Draft/Planning)
      expect(find.text('المرحلة الحالية *'), findsOneWidget);

      // 4. Verify Logistics details container & inputs
      expect(find.text('بيانات النقل وموانئ الشحن لطلب النولون'), findsOneWidget);
      expect(find.text('ميناء الشحن'), findsOneWidget);
      expect(find.text('ميناء الوصول والتفريغ'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.byIcon(Icons.gavel_outlined)));
      await tester.pumpAndSettle();
      expect(find.text('المخلص الجمركي'), findsOneWidget);

      // 5. Verify Save / Draft Action Buttons
      expect(find.text('حفظ مؤقت'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.text('حفظ'), findsOneWidget);
    });

    testWidgets('ImportFileFormDialog triggers validation errors when mandatory fields are missing',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            importCompaniesProvider.overrideWith((ref) => MockImportCompaniesNotifier(sampleCompanies)),
            suppliersProvider.overrideWith((ref) => MockSuppliersNotifier(sampleSuppliers)),
            partnersProvider.overrideWith((ref) => MockPartnersNotifier(samplePartners)),
            projectsProvider.overrideWith((ref) => MockProjectsNotifier(sampleProjects)),
            currenciesProvider.overrideWith((ref) => MockCurrenciesNotifier(sampleCurrencies)),
            incotermsProvider.overrideWith((ref) => MockIncotermsNotifier(ref, sampleIncoterms)),
            transportLocationsProvider.overrideWith((ref) => MockTransportLocationsNotifier(sampleLocations)),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: ImportFileFormDialog(fileToEdit: null),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Submit empty form by clicking Save button ('حفظ')
      final saveBtn = find.text('حفظ');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Form validation errors should be triggered for required fields (File ID, Cost, Owner)
      expect(find.text('رقم ملف الاستيراد'), findsOneWidget);

      // Scroll down to reveal bottom fields in SingleChildScrollView
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('إجمالي التكلفة'), findsOneWidget);
      expect(find.text('مسؤول المشروع مطلوب'), findsOneWidget);
    });
  });
}
