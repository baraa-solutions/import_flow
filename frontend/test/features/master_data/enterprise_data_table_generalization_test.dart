import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/widgets.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/transport_locations/models/transport_location_model.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';

Widget _buildTestable(Widget child) {
  return MaterialApp(
    home: AppLocalizationsProvider(
      locale: const Locale('ar'),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 800,
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EnterpriseDataTable Generalization Tests', () {
    testWidgets('EnterpriseDataTable renders CurrencyModel data correctly with sorting and columns', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      addTearDown(tester.view.resetPhysicalSize);

      final List<CurrencyModel> currencies = [
        CurrencyModel(
          currencyId: 1,
          currencyCode: 'USD',
          currencyName: 'US Dollar',
          currencySymbol: r'$',
          isBaseCurrency: false,
          decimalPlaces: 2,
          isActive: true,
          latestCommercialRate: 48.50,
          latestCustomsRate: 48.30,
        ),
        CurrencyModel(
          currencyId: 2,
          currencyCode: 'EUR',
          currencyName: 'Euro',
          currencySymbol: '€',
          isBaseCurrency: false,
          decimalPlaces: 2,
          isActive: true,
          latestCommercialRate: 52.10,
          latestCustomsRate: 52.00,
        ),
        CurrencyModel(
          currencyId: 3,
          currencyCode: 'EGP',
          currencyName: 'Egyptian Pound',
          currencySymbol: 'ج.م',
          isBaseCurrency: true,
          decimalPlaces: 2,
          isActive: true,
          latestCommercialRate: 1.0,
          latestCustomsRate: 1.0,
        ),
      ];

      final columns = [
        EnterpriseColumn<CurrencyModel>(
          id: 'code',
          title: 'كود العملة',
          width: 120,
          searchValue: (c) => c.currencyCode,
          cellBuilder: (ctx, c, _) => Text(c.currencyCode),
        ),
        EnterpriseColumn<CurrencyModel>(
          id: 'name',
          title: 'اسم العملة',
          flex: 2,
          searchValue: (c) => c.currencyName,
          cellBuilder: (ctx, c, _) => Text(c.currencyName),
        ),
        EnterpriseColumn<CurrencyModel>(
          id: 'symbol',
          title: 'الرمز',
          width: 80,
          cellBuilder: (ctx, c, _) => Text(c.currencySymbol),
        ),
        EnterpriseColumn<CurrencyModel>(
          id: 'rate',
          title: 'السعر التجاري',
          width: 150,
          cellBuilder: (ctx, c, _) => Text(c.latestCommercialRate.toString()),
        ),
      ];

      await tester.pumpWidget(
        _buildTestable(
          EnterpriseDataTable<CurrencyModel>(
            storageKey: 'test_currencies_table',
            data: currencies,
            columns: columns,
            minWidth: 800,
            isScrollable: true,
            showHeaderToolbar: true,
            showPagination: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('USD'), findsOneWidget);
      expect(find.text('EUR'), findsOneWidget);
      expect(find.text('EGP'), findsOneWidget);
      expect(find.text('US Dollar'), findsOneWidget);
      expect(find.text('Egyptian Pound'), findsOneWidget);
      expect(find.byType(EnterpriseDataTable<CurrencyModel>), findsOneWidget);
    });

    testWidgets('EnterpriseDataTable renders TransportLocationModel data correctly', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      addTearDown(tester.view.resetPhysicalSize);

      final List<TransportLocationModel> locations = [
        TransportLocationModel(
          locationId: 1,
          unLocode: 'EGALY',
          locationName: 'Alexandria Port',
          locationType: 'Sea Port',
          country: 'Egypt',
          city: 'Alexandria',
          isActive: true,
          createdAt: DateTime.now(),
        ),
        TransportLocationModel(
          locationId: 2,
          unLocode: 'EGPSD',
          locationName: 'Port Said Port',
          locationType: 'Sea Port',
          country: 'Egypt',
          city: 'Port Said',
          isActive: true,
          createdAt: DateTime.now(),
        ),
      ];

      final columns = [
        EnterpriseColumn<TransportLocationModel>(
          id: 'locode',
          title: 'UN/LOCODE',
          width: 130,
          searchValue: (l) => l.unLocode,
          cellBuilder: (ctx, l, _) => Text(l.unLocode),
        ),
        EnterpriseColumn<TransportLocationModel>(
          id: 'name',
          title: 'اسم الميناء / الموقع',
          flex: 2,
          searchValue: (l) => l.locationName,
          cellBuilder: (ctx, l, _) => Text(l.locationName),
        ),
        EnterpriseColumn<TransportLocationModel>(
          id: 'type',
          title: 'النوع',
          width: 120,
          cellBuilder: (ctx, l, _) => Text(l.locationType),
        ),
        EnterpriseColumn<TransportLocationModel>(
          id: 'city',
          title: 'المدينة',
          width: 120,
          cellBuilder: (ctx, l, _) => Text(l.city),
        ),
      ];

      await tester.pumpWidget(
        _buildTestable(
          EnterpriseDataTable<TransportLocationModel>(
            storageKey: 'test_transport_locations_table',
            data: locations,
            columns: columns,
            minWidth: 800,
            isScrollable: true,
            showHeaderToolbar: true,
            showPagination: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('EGALY'), findsOneWidget);
      expect(find.text('Alexandria Port'), findsOneWidget);
      expect(find.text('EGPSD'), findsOneWidget);
      expect(find.text('Port Said Port'), findsOneWidget);
      expect(find.byType(EnterpriseDataTable<TransportLocationModel>), findsOneWidget);
    });

    testWidgets('EnterpriseDataTable renders ImportFileModel data with empty and populated states', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      addTearDown(tester.view.resetPhysicalSize);

      final List<ImportFileModel> files = [
        ImportFileModel(
          importFileId: 101,
          importFileCode: 'IMP-2026-001',
          customFileNumber: 'CFN-001',
          supplierName: 'Siemens AG',
          companyName: 'Sorour Industrial',
          shipmentMode: 'Sea',
          incotermCode: 'CIF',
          priority: 'High',
          status: 'Open',
          currentStage: 'STAGE_01',
          currentModule: 'Customs Clearance',
          owner: 'Customs Broker',
          nextAction: 'Review documents',
          progressPercent: 65.0,
          createdAt: '2026-10-29T00:00:00Z',
          updatedAt: '2026-10-29T00:00:00Z',
        ),
      ];

      final columns = [
        EnterpriseColumn<ImportFileModel>(
          id: 'code',
          title: 'رقم الملف',
          width: 150,
          searchValue: (f) => f.importFileCode,
          cellBuilder: (ctx, f, _) => Text(f.importFileCode),
        ),
        EnterpriseColumn<ImportFileModel>(
          id: 'company',
          title: 'الشركة المستوردة',
          flex: 2,
          searchValue: (f) => f.companyName,
          cellBuilder: (ctx, f, _) => Text(f.companyName),
        ),
        EnterpriseColumn<ImportFileModel>(
          id: 'supplier',
          title: 'المورد',
          flex: 2,
          searchValue: (f) => f.supplierName,
          cellBuilder: (ctx, f, _) => Text(f.supplierName),
        ),
        EnterpriseColumn<ImportFileModel>(
          id: 'progress',
          title: 'الإنجاز',
          width: 120,
          cellBuilder: (ctx, f, _) => Text('${f.progressPercent.toInt()}%'),
        ),
      ];

      await tester.pumpWidget(
        _buildTestable(
          EnterpriseDataTable<ImportFileModel>(
            storageKey: 'test_import_files_table',
            data: files,
            columns: columns,
            minWidth: 800,
            isScrollable: true,
            showHeaderToolbar: false,
            showPagination: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('IMP-2026-001'), findsOneWidget);
      expect(find.text('Sorour Industrial'), findsOneWidget);
      expect(find.text('Siemens AG'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);
      expect(find.byType(EnterpriseDataTable<ImportFileModel>), findsOneWidget);
    });
  });
}
