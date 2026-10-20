import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/import_files/screens/import_files_screen.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/shipping_scenarios/providers/shipping_scenarios_provider.dart';

import 'package:frontend/features/import_companies/models/import_company_model.dart';
import 'package:frontend/features/import_companies/providers/import_companies_provider.dart';

class MockImportCompaniesNotifier extends ImportCompaniesNotifier {
  MockImportCompaniesNotifier(List<ImportCompanyModel> list)
      : super(showInactive: true, dio: Dio()) {
    state = AsyncValue.data(list);
  }

  @override
  Future<void> fetchCompanies() async {}
}

class MockPaginatedNotifier extends PaginatedImportFilesNotifier {
  MockPaginatedNotifier(List<ImportFileModel> files) : super(Dio()) {
    state = PaginatedImportFilesState(
      items: files,
      total: files.length,
      page: 1,
      pageSize: 50,
      totalPages: 1,
      isLoading: false,
    );
  }

  @override
  Future<void> fetchPage(int page, {
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {}
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
  MockPurchaseOrdersNotifier(Ref ref) : super(Dio(), ref) {
    state = PurchaseOrdersState(purchaseOrders: []);
  }

  @override
  Future<void> fetchPurchaseOrders() async {}
}

class MockShippingScenariosNotifier extends ShippingScenariosNotifier {
  MockShippingScenariosNotifier() : super(Dio()) {
    state = ShippingScenariosState(sessions: []);
  }

  @override
  Future<void> fetchSessions() async {}
}

void main() {
  final sampleCompanies = [
    ImportCompanyModel(
      companyId: 10,
      importerName: 'ECO ASSOCIATES for Trading and Contracting',
      address: 'Cairo, Egypt',
      country: 'Egypt',
      importerId: 'IMP-10',
      importerIdExpiry: DateTime.now().add(const Duration(days: 365)),
      vatId: '123456789',
      vatIdExpiry: DateTime.now().add(const Duration(days: 365)),
      registrationNumber: '98765',
      registrationExpiry: DateTime.now().add(const Duration(days: 365)),
    ),
  ];

  final sampleFiles = [
    ImportFileModel(
      importFileId: 1,
      importFileCode: 'IMP-2026-0001',
      customFileNumber: '6701068100',
      companyId: 10,
      companyName: 'ECO ASSOCIATES for Trading and Contracting',
      supplierId: 20,
      supplierName: 'G.I. Industrial Holding S.p.A.',
      poNumber: 'PO-2026-001',
      poIds: [101],
      piNumber: 'PI-889',
      currentModule: 'Phase 1',
      currentStage: 'Phase 1',
      nextAction: 'Review',
      createdAt: '2026-08-22T00:00:00Z',
      updatedAt: '2026-08-22T00:00:00Z',
      estimatedCost: 15000.0,
      estimatedCostCurrency: 'USD',
    ),
  ];

  group('ImportFiles Localization & Anti-Stacked Tests (Screen 1)', () {
    test('Arabic AppLocalizationsAr returns pure Arabic for Import Files keys', () {
      const lAr = AppLocalizationsAr();
      expect(lAr.importFilesManagementTitle, equals('إدارة وملفات استيراد الشحنات'));
      expect(lAr.addNewImportFile, equals('إضافة ملف استيراد شحنة جديد'));
      expect(lAr.searchByShipmentOrCompany, equals('بحث بكود الشحنة أو الشركة...'));
      expect(lAr.importFileIdLabel, equals('رقم ملف الاستيراد'));
      expect(lAr.importingCompany, equals('الشركة المستوردة'));
      expect(lAr.foreignSupplier, equals('المورد الأجنبي'));
      expect(lAr.logisticsAndPortsDetails, equals('بيانات النقل وموانئ الشحن لطلب النولون'));
      expect(lAr.liveReload, equals('إعادة تحميل حية'));
      expect(lAr.clearAndReset, equals('تفريغ وبدء تسجيل جديد'));
      expect(lAr.freightRfqTitle, equals('طلب أسعار نولون الشحن الدولي'));
      expect(lAr.closeShipmentTitle, equals('إيقاف وإغلاق الشحنة'));
      expect(lAr.smartInvoiceBlExtractorButton, equals('استخلاص الفواتير والبوالص الذكي'));
      expect(lAr.whatIfSimulatorButton, equals('محاكي الأزمات وتحوط الصرف'));

      // Check NO slash separated bilingual strings
      expect(lAr.importFilesManagementTitle.contains('/'), isFalse);
      expect(lAr.addNewImportFile.contains('/'), isFalse);
      expect(lAr.importFileIdLabel.contains('/'), isFalse);
      expect(lAr.smartInvoiceBlExtractorButton.contains('/'), isFalse);
      expect(lAr.whatIfSimulatorButton.contains('/'), isFalse);
    });

    test('English AppLocalizationsEn returns pure English for Import Files keys', () {
      const lEn = AppLocalizationsEn();

      expect(lEn.importFilesManagementTitle, equals('Import Files & Shipments Management'));
      expect(lEn.addNewImportFile, equals('Add New Import File'));
      expect(lEn.searchByShipmentOrCompany, equals('Search by shipment code or company...'));
      expect(lEn.importFileIdLabel, equals('Import File No'));
      expect(lEn.importingCompany, equals('Importing Company'));
      expect(lEn.foreignSupplier, equals('Foreign Supplier'));
      expect(lEn.logisticsAndPortsDetails, equals('Logistics & Freight RFQ Details'));
      expect(lEn.liveReload, equals('Live Reload'));
      expect(lEn.clearAndReset, equals('Clear & Reset'));
      expect(lEn.freightRfqTitle, equals('Freight RFQ Generator'));
      expect(lEn.closeShipmentTitle, equals('Stop & Close Shipment'));
      expect(lEn.smartInvoiceBlExtractorButton, equals('Smart Invoice & B/L Extractor'));
      expect(lEn.whatIfSimulatorButton, equals('What-If & Hedging Simulator'));

      // Check NO slash separated bilingual strings
      expect(lEn.importFilesManagementTitle.contains('/'), isFalse);
      expect(lEn.addNewImportFile.contains('/'), isFalse);
      expect(lEn.importFileIdLabel.contains('/'), isFalse);
      expect(lEn.smartInvoiceBlExtractorButton.contains(' / '), isFalse);
      expect(lEn.smartInvoiceBlExtractorButton.contains('الفواتير'), isFalse);
      expect(lEn.whatIfSimulatorButton.contains('/'), isFalse);
    });

    testWidgets('Renders ImportFilesScreen in Arabic without stacked English text', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) {
              final n = LocaleNotifier();
              n.setLocale(const Locale('ar'));
              return n;
            }),
            importCompaniesProvider.overrideWith(
              (ref) => MockImportCompaniesNotifier(sampleCompanies),
            ),
            paginatedImportFilesProvider.overrideWith(
              (ref) => MockPaginatedNotifier(sampleFiles),
            ),
            importFilesProvider.overrideWith(
              (ref) => MockImportFilesNotifier(sampleFiles),
            ),
            purchaseOrdersProvider.overrideWith(
              (ref) => MockPurchaseOrdersNotifier(ref),
            ),
            shippingScenariosProvider.overrideWith(
              (ref) => MockShippingScenariosNotifier(),
            ),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: ImportFilesScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('إدارة وملفات استيراد الشحنات'), findsOneWidget);
      expect(find.text('إضافة ملف استيراد شحنة جديد'), findsOneWidget);
      expect(find.text('إجراءات إضافية'), findsOneWidget);
      // Open More Actions menu
      await tester.tap(find.text('إجراءات إضافية'));
      await tester.pumpAndSettle();
      expect(find.text('استخلاص الفواتير والبوالص الذكي'), findsOneWidget);
      expect(find.text('محاكي الأزمات وتحوط الصرف'), findsOneWidget);
      expect(find.text('Import Files & Shipments Management'), findsNothing);
      expect(find.text('Add New Import File'), findsNothing);
      expect(find.text('Smart Invoice & B/L Extractor'), findsNothing);
      expect(find.text('What-If & Hedging Simulator'), findsNothing);
    });

    testWidgets('Renders ImportFilesScreen in English without stacked Arabic text', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) {
              final n = LocaleNotifier();
              n.setLocale(const Locale('en'));
              return n;
            }),
            importCompaniesProvider.overrideWith(
              (ref) => MockImportCompaniesNotifier(sampleCompanies),
            ),
            paginatedImportFilesProvider.overrideWith(
              (ref) => MockPaginatedNotifier(sampleFiles),
            ),
            importFilesProvider.overrideWith(
              (ref) => MockImportFilesNotifier(sampleFiles),
            ),
            purchaseOrdersProvider.overrideWith(
              (ref) => MockPurchaseOrdersNotifier(ref),
            ),
            shippingScenariosProvider.overrideWith(
              (ref) => MockShippingScenariosNotifier(),
            ),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('en'),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: ImportFilesScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Import Files & Shipments Management'), findsOneWidget);
      expect(find.text('Add New Import File'), findsOneWidget);
      expect(find.text('More actions'), findsOneWidget);
      // Open More Actions menu
      await tester.tap(find.text('More actions'));
      await tester.pumpAndSettle();
      expect(find.text('Smart Invoice & B/L Extractor'), findsOneWidget);
      expect(find.text('What-If & Hedging Simulator'), findsOneWidget);
      expect(find.text('إدارة وملفات استيراد الشحنات'), findsNothing);
      expect(find.text('إضافة ملف استيراد شحنة جديد'), findsNothing);
      expect(find.text('استخلاص الفواتير والبوالص الذكي'), findsNothing);
      expect(find.text('محاكي الأزمات وتحوط الصرف'), findsNothing);
    });
  });
}
