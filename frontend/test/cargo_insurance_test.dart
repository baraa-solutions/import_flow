import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/features/cargo_insurance/models/cargo_insurance_model.dart';
import 'package:frontend/features/cargo_insurance/providers/cargo_insurance_provider.dart';
import 'package:frontend/features/cargo_insurance/screens/cargo_insurance_screen.dart';
import 'package:frontend/features/cargo_shipping/models/cargo_shipping_model.dart';
import 'package:frontend/features/cargo_shipping/providers/cargo_shipping_provider.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/currencies/providers/currencies_provider.dart';
import 'package:frontend/features/external_service_providers/models/partner_model.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/freight_booking/models/freight_booking_model.dart';
import 'package:frontend/features/freight_booking/providers/freight_booking_provider.dart';
import 'package:frontend/features/import_companies/models/import_company_model.dart';
import 'package:frontend/features/import_companies/providers/import_companies_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';

void main() {
  group('Cargo Insurance Frontend Model & Valuation Tests', () {
    test('CargoInsuranceModel serialization and default values', () {
      final json = {
        'certificate_id': 101,
        'certificate_code': 'INS-2026-00001',
        'policy_number': 'POL-EGY-99120',
        'policy_type': 'SPECIFIC',
        'insured_entity_name': 'Sorour International Trading',
        'transport_mode': 'OCEAN',
        'carrier_name': 'Hapag-Lloyd',
        'vessel_or_flight_no': 'AL JASRAH',
        'voyage_number': 'V.2026W',
        'tracking_reference': 'HLCU1298401',
        'port_of_loading': 'Hamburg, Germany',
        'port_of_discharge': 'Alexandria Port, Egypt',
        'currency': 'EUR',
        'exchange_rate': 52.80,
        'invoice_value': 120000.0,
        'freight_cost': 6000.0,
        'other_logistics_costs': 1500.0,
        'cif_value': 127500.0,
        'markup_percentage': 0.10,
        'insured_value': 140250.0,
        'coverage_clause': 'ICC_A',
        'include_war_and_strikes': true,
        'base_rate': 0.0025,
        'war_rate': 0.0005,
        'base_premium': 350.63,
        'war_strikes_premium': 70.13,
        'minimum_premium': 30.0,
        'net_premium': 420.76,
        'issuance_fee': 15.0,
        'tax_rate': 0.05,
        'tax_amount': 21.79,
        'total_payable_premium': 457.55,
        'goods_description': 'Electrical Transformers & Distribution Panels',
        'package_count': 32,
        'package_type': 'Wooden Crates',
        'gross_weight_kg': 18500.0,
        'status': 'ISSUED',
        'created_at': '2026-08-25T10:00:00Z',
        'updated_at': '2026-08-25T10:30:00Z',
      };

      final model = CargoInsuranceModel.fromJson(json);

      expect(model.certificateId, 101);
      expect(model.certificateCode, 'INS-2026-00001');
      expect(model.insuredEntityName, 'Sorour International Trading');
      expect(model.cifValue, 127500.0);
      expect(model.insuredValue, 140250.0);
      expect(model.coverageClause, 'ICC_A');
      expect(model.totalPayablePremium, 457.55);
      expect(model.status, 'ISSUED');

      final serialized = model.toJson();
      expect(serialized['certificate_code'], 'INS-2026-00001');
      expect(serialized['insured_value'], 140250.0);
    });

    test('InsuranceCalculationResultModel parsing', () {
      final json = {
        'cif_value': 50000.0,
        'markup_percentage': 0.10,
        'insured_value': 55000.0,
        'coverage_clause': 'AIR_ALL_RISKS',
        'base_rate': 0.0020,
        'base_premium': 110.0,
        'war_rate': 0.0005,
        'war_strikes_premium': 27.5,
        'net_premium': 137.5,
        'issuance_fee': 15.0,
        'tax_rate': 0.05,
        'tax_amount': 7.63,
        'total_payable_premium': 160.13,
        'currency': 'USD',
      };

      final calc = InsuranceCalculationResultModel.fromJson(json);
      expect(calc.cifValue, 50000.0);
      expect(calc.insuredValue, 55000.0);
      expect(calc.coverageClause, 'AIR_ALL_RISKS');
      expect(calc.totalPayablePremium, 160.13);
      expect(calc.currency, 'USD');
    });

    testWidgets('CargoInsuranceScreen should render cleanly with search and tabs', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer(
        overrides: [
          cargoInsuranceProvider.overrideWith((ref) => _MockCargoInsuranceNotifier([])),
          importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier([])),
          partnersProvider.overrideWith((ref) => _MockPartnersNotifier([])),
          importCompaniesProvider.overrideWith((ref) => _MockCompaniesNotifier([])),
          currenciesProvider.overrideWith((ref) => _MockCurrenciesNotifier([])),
          freightBookingProvider.overrideWith((ref) => _MockFreightBookingNotifier([])),
          cargoShippingProvider.overrideWith((ref) => _MockCargoShippingNotifier([])),
          purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier([])),
          localeProvider.overrideWith((ref) => _MockLocaleNotifier(const Locale('ar'))),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('ar'),
            home: Scaffold(
              body: Directionality(
                textDirection: TextDirection.rtl,
                child: AppLocalizationsProvider(
                  locale: Locale('ar'),
                  child: CargoInsuranceScreen(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title & toolbar render
      expect(find.textContaining('شهادات التأمين على البضائع المشحونة'), findsOneWidget);
      expect(find.textContaining('سجل شهادات التأمين'), findsOneWidget);
      expect(find.text('إصدار وثيقة تأمين جديدة'), findsWidgets);

      // Tap on "New Certificate" button
      await tester.tap(find.text('إصدار وثيقة تأمين جديدة').first);
      await tester.pumpAndSettle();

      // Verify modal dialog opened
      expect(find.textContaining('إصدار شهادة تأمين البضائع المشحونة'), findsWidgets);
      expect(find.textContaining('حساب القيمة المؤمنة'), findsOneWidget);
    });
  });
}

class _MockCargoInsuranceNotifier extends StateNotifier<AsyncValue<List<CargoInsuranceModel>>> implements CargoInsuranceNotifier {
  _MockCargoInsuranceNotifier(List<CargoInsuranceModel> initial) : super(AsyncValue.data(initial));

  @override
  Future<void> fetchCertificates({int? importFileId, String? status, String? search}) async {
    state = const AsyncValue.data([]);
  }

  @override
  bool get hasMore => false;

  @override
  int get total => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockImportFilesNotifier extends StateNotifier<AsyncValue<List<ImportFileModel>>> implements ImportFilesNotifier {
  _MockImportFilesNotifier(List<ImportFileModel> initial) : super(AsyncValue.data(initial));

  @override
  Future<void> fetchImportFiles({bool includeInactive = false, String? search, int? companyId, int? supplierId, String? status, String? owner}) async {
    state = const AsyncValue.data([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPartnersNotifier extends StateNotifier<AsyncValue<List<PartnerModel>>> implements PartnersNotifier {
  _MockPartnersNotifier(List<PartnerModel> initial) : super(AsyncValue.data(initial));

  @override
  Future<void> fetchPartners({bool includeInactive = false, String? search, String? partnerType}) async {
    state = const AsyncValue.data([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCompaniesNotifier extends StateNotifier<AsyncValue<List<ImportCompanyModel>>> implements ImportCompaniesNotifier {
  _MockCompaniesNotifier(List<ImportCompanyModel> initial) : super(AsyncValue.data(initial));

  @override
  Future<void> fetchCompanies({bool includeInactive = false, String? search}) async {
    state = const AsyncValue.data([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCurrenciesNotifier extends StateNotifier<AsyncValue<List<CurrencyModel>>> implements CurrenciesNotifier {
  _MockCurrenciesNotifier(List<CurrencyModel> initial) : super(AsyncValue.data(initial));

  @override
  Future<void> fetchCurrencies({bool includeInactive = false, String? search}) async {
    state = const AsyncValue.data([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCargoShippingNotifier extends StateNotifier<AsyncValue<List<CargoShippingModel>>> implements CargoShippingNotifier {
  _MockCargoShippingNotifier(List<CargoShippingModel> initial) : super(AsyncValue.data(initial));

  @override
  Future<void> fetchRecords({bool includeInactive = true, int? importFileId, String? status, String? search}) async {
    state = const AsyncValue.data([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockFreightBookingNotifier extends StateNotifier<AsyncValue<List<ShipmentBookingModel>>> implements FreightBookingNotifier {
  _MockFreightBookingNotifier(List<ShipmentBookingModel> initial) : super(AsyncValue.data(initial));

  @override
  Future<void> fetchBookings({bool includeInactive = false, int? importFileId, String? status, String? search}) async {
    state = const AsyncValue.data([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPurchaseOrdersNotifier extends StateNotifier<PurchaseOrdersState> implements PurchaseOrdersNotifier {
  _MockPurchaseOrdersNotifier(List<PurchaseOrderModel> initial) : super(PurchaseOrdersState(purchaseOrders: initial));

  @override
  Future<void> fetchPurchaseOrders({bool includeInactive = false, String? search, int? importFileId, int? supplierId, String? status}) async {
    state = state.copyWith(purchaseOrders: [], isLoading: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockLocaleNotifier extends LocaleNotifier {
  _MockLocaleNotifier(Locale initial) {
    state = initial;
  }
}
