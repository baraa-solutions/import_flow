import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/widgets/copyable_data_helper.dart';
import 'package:frontend/features/import_companies/models/import_company_model.dart';
import 'package:frontend/features/import_companies/providers/import_companies_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/shipment_inquiry/screens/shipment_inquiry_screen.dart';
import 'package:frontend/features/suppliers/models/supplier_model.dart';
import 'package:frontend/features/suppliers/providers/suppliers_provider.dart';

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

class _MockSuppliersNotifier extends SuppliersNotifier {
  final List<SupplierModel> initialSuppliers;
  _MockSuppliersNotifier(this.initialSuppliers) : super(showInactive: true, dio: Dio()) {
    state = AsyncValue.data(initialSuppliers);
  }

  @override
  Future<void> fetchSuppliers({
    bool includeInactive = false,
    String? search,
    String? country,
    String? currency,
    String? productCategory,
  }) async {
    state = AsyncValue.data(initialSuppliers);
  }
}

class _MockImportCompaniesNotifier extends ImportCompaniesNotifier {
  final List<ImportCompanyModel> initialCompanies;
  _MockImportCompaniesNotifier(this.initialCompanies) : super(showInactive: true, dio: Dio()) {
    state = AsyncValue.data(initialCompanies);
  }

  @override
  Future<void> fetchCompanies({
    bool includeInactive = false,
    String? search,
    String? country,
    String? city,
  }) async {
    state = AsyncValue.data(initialCompanies);
  }
}

void main() {
  final sampleFile = ImportFileModel(
    importFileId: 1,
    importFileCode: 'IMP-2026-0001',
    supplierId: 10,
    supplierName: 'Siemens Healthineers',
    companyId: 20,
    companyName: 'المتحدة للأجهزة الطبية',
    shipmentMode: 'FCL',
    incotermCode: 'CIF',
    status: 'Shipment',
    estimatedCost: 12500.0,
    estimatedCostCurrency: 'USD',
    fileOpeningDate: '2026-01-10',
    portOfLoading: 'Hamburg',
    portOfDischarge: 'Alexandria',
    hsCode: '9018.90.00',
    productCategory: 'Medical Devices',
    customFileNumber: 'CFN-1001',
    notes: 'Primary Medical Shipment\nUrgent priority',
    currentModule: 'Phase 1',
    currentStage: 'Phase 1',
    nextAction: 'None',
    createdAt: '2026-01-10',
    updatedAt: '2026-01-10',
  );

  Widget createTestWidget({
    required Locale locale,
    List<ImportFileModel> files = const [],
  }) {
    return ProviderScope(
      overrides: [
        importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier(files)),
        suppliersProvider.overrideWith((ref) => _MockSuppliersNotifier([])),
        importCompaniesProvider.overrideWith((ref) => _MockImportCompaniesNotifier([])),
      ],
      child: MaterialApp(
        locale: locale,
        home: AppLocalizationsProvider(
          locale: locale,
          child: Directionality(
            textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: const ShipmentInquiryScreen(),
          ),
        ),
      ),
    );
  }

  group('Screen 68: ShipmentInquiryScreen Widget Tests', () {
    testWidgets('Renders Arabic UI with Task A pure Arabic, Task B SelectionArea and CopyableTableCell', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const ar = AppLocalizationsAr();

      await tester.pumpWidget(createTestWidget(
        locale: const Locale('ar'),
        files: [sampleFile],
      ));
      await tester.pumpAndSettle();

      // Task B: one screen-level SelectionArea wraps the header (the data table
      // nests its own SelectionArea for its rows, so scope to the header title).
      expect(
        find.ancestor(of: find.text(ar.inqScreenTitle), matching: find.byType(SelectionArea)),
        findsOneWidget,
      );

      // Task A: Screen Title & Subtitle in Arabic
      expect(find.text(ar.inqScreenTitle), findsOneWidget);
      expect(find.text(ar.inqSubtitle), findsOneWidget);

      // Smart Insight Bar items (UX-SEARCH-013 Section 3.1)
      expect(find.text(ar.inqInsightBarTitle), findsOneWidget);
      expect(find.text(ar.inqInsightMatchingCount), findsOneWidget);
      expect(find.text(ar.inqInsightModeRoute), findsOneWidget);
      expect(find.text(ar.inqInsightModeShippingMode), findsOneWidget);
      expect(find.text(ar.inqInsightLatestFreight), findsOneWidget);
      expect(find.text(ar.inqInsightAvgLandedCost), findsOneWidget);

      // 4 Export Toolbar Actions
      expect(find.text(ar.inqExportPdfBtn), findsOneWidget);
      expect(find.text(ar.inqExportExcelBtn), findsOneWidget);
      expect(find.text(ar.inqExportTsvBtn), findsOneWidget);
      expect(find.byIcon(Icons.copy_all_outlined), findsOneWidget);

      // Table columns and cell data
      expect(find.text(ar.inqColShipmentName), findsOneWidget);
      expect(find.text(ar.inqColDate), findsOneWidget);
      expect(find.text(ar.inqColSupplier), findsOneWidget);
      expect(find.text(ar.inqColImporter), findsOneWidget);
      expect(find.text(ar.inqColFinalCost), findsOneWidget);
      expect(find.text(ar.inqColStatus), findsOneWidget);
      expect(find.text('Primary Medical Shipment'), findsOneWidget);
      expect(find.text('IMP-2026-0001'), findsOneWidget);
      expect(find.text('Siemens Healthineers'), findsOneWidget);

      // Task B: CopyableTableCell present in table
      expect(find.byType(CopyableTableCell), findsWidgets);

      // Quick row copy button present
      expect(find.byIcon(Icons.copy_rounded), findsWidgets);
    });

    testWidgets('Renders English UI when English locale is selected', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const en = AppLocalizationsEn();

      await tester.pumpWidget(createTestWidget(
        locale: const Locale('en'),
        files: [sampleFile],
      ));
      await tester.pumpAndSettle();

      expect(
        find.ancestor(of: find.text(en.inqScreenTitle), matching: find.byType(SelectionArea)),
        findsOneWidget,
      );
      expect(find.text(en.inqScreenTitle), findsOneWidget);
      expect(find.text(en.inqSubtitle), findsOneWidget);
      expect(find.text(en.inqExportPdfBtn), findsOneWidget);
      expect(find.text(en.inqExportExcelBtn), findsOneWidget);
      expect(find.text(en.inqExportTsvBtn), findsOneWidget);
      expect(find.text(en.inqColShipmentName), findsOneWidget);
    });

    testWidgets('Renders Empty State message when zero shipments match', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const ar = AppLocalizationsAr();

      await tester.pumpWidget(createTestWidget(
        locale: const Locale('ar'),
        files: [],
      ));
      await tester.pumpAndSettle();

      expect(find.text(ar.inqEmptyShipmentsTitle), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    });
  });
}
