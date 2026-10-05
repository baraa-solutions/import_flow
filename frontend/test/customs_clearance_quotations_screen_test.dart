import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/buttons/app_button.dart';
import 'package:frontend/features/customs_clearance_quotations/models/customs_clearance_quotation_model.dart';
import 'package:frontend/features/customs_clearance_quotations/providers/customs_clearance_quotations_provider.dart';
import 'package:frontend/features/customs_clearance_quotations/screens/customs_clearance_quotations_screen.dart';
import 'package:frontend/features/customs_clearance_quotations/widgets/rfq_card.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/transport_locations/providers/transport_locations_provider.dart';

import 'helpers/localized_app.dart';

class _RfqNotifier extends CustomsClearanceQuotationsNotifier {
  _RfqNotifier(this.rfqs) : super(Dio()) {
    state = AsyncValue.data(rfqs);
  }
  final List<CustomsClearanceRFQModel> rfqs;

  @override
  Future<void> fetchRFQs({String? status, String? portName, int? importFileId}) async {
    state = AsyncValue.data(rfqs);
  }
}

class _PriceNotifier extends ClearancePriceListNotifier {
  _PriceNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchPriceList({int? providerId, String? portName, String? serviceCategory}) async {
    state = const AsyncValue.data([]);
  }
}

class _FilesNotifier extends ImportFilesNotifier {
  _FilesNotifier() : super(Dio()) {
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
  }) async {
    state = const AsyncValue.data([]);
  }
}

class _PartnersNotifier extends PartnersNotifier {
  _PartnersNotifier() : super(category: 'All', showInactive: true, dio: Dio()) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchPartners({String? category, bool includeInactive = false, String? search}) async {
    state = const AsyncValue.data([]);
  }
}

class _LocationsNotifier extends TransportLocationsNotifier {
  _LocationsNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchLocations({bool includeInactive = true, String? locationType, String? search}) async {
    state = const AsyncValue.data([]);
  }
}

CustomsClearanceRFQModel _rfq({String status = 'Quotations Received'}) => CustomsClearanceRFQModel(
      rfqId: 5,
      rfqCode: 'CRFQ-000005',
      title: 'RFQ line one',
      portName: 'Alexandria Port',
      shipmentType: 'Ocean FCL (40HQ)',
      containersCount: 2,
      packagesCount: 0,
      grossWeightKg: 18500,
      cbm: 55,
      status: status,
      lowestClearanceCost: 15000,
      fastestTurnaroundDays: 3,
      awardedProviderName: status == 'Awarded' ? 'Broker A' : null,
      createdAt: '2026-08-20T10:00:00Z',
      quotations: [
        CustomsClearanceQuotationItemModel(
          quotationId: 1,
          rfqId: 5,
          providerId: 1,
          providerName: 'Broker A',
          clearanceFee: 3000,
          totalCost: 15000,
          isAwarded: status == 'Awarded',
        ),
        CustomsClearanceQuotationItemModel(
          quotationId: 2,
          rfqId: 5,
          providerId: 2,
          providerName: 'Broker B',
          clearanceFee: 3500,
          totalCost: 17250.5,
        ),
      ],
    );

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('RfqCard formats money, offers award on open quotes and reports taps', (tester) async {
    _size(tester, const Size(1366, 768));
    int? awarded;
    int? deleted;
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RfqCard(
              rfq: _rfq(),
              onSmartExtract: () {},
              onAddQuote: () {},
              onAward: (id) => awarded = id,
              onDeleteQuote: (id) => deleted = id,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CRFQ-000005'), findsOneWidget);
    expect(find.textContaining('17,250.50'), findsOneWidget);
    expect(find.textContaining('15,000.00'), findsWidgets);

    // Two open quotations -> two award buttons; the first one reports its id.
    final awardButtons = find.byType(AppButton);
    expect(awardButtons, findsWidgets);
    await tester.tap(find.byIcon(Icons.delete_outline).last);
    expect(deleted, 2);
    expect(awarded, isNull);
  });

  testWidgets('RfqCard shows the awarded banner and no award button for the awarded quote', (tester) async {
    _size(tester, const Size(1366, 768));
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RfqCard(
              rfq: _rfq(status: 'Awarded'),
              onSmartExtract: () {},
              onAddQuote: () {},
              onAward: (_) {},
              onDeleteQuote: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  for (final embedded in [false, true]) {
    testWidgets('screen renders metric strip + card without overflow (embedded: $embedded)', (tester) async {
      _size(tester, const Size(1366, 768));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customsClearanceQuotationsProvider.overrideWith((ref) => _RfqNotifier([_rfq(), _rfq(status: 'Awarded')])),
            clearancePriceListProvider.overrideWith((ref) => _PriceNotifier()),
            importFilesProvider.overrideWith((ref) => _FilesNotifier()),
            partnersProvider.overrideWith((ref) => _PartnersNotifier()),
            transportLocationsProvider.overrideWith((ref) => _LocationsNotifier()),
          ],
          child: localizedApp(home: embedded
              ? Scaffold(body: CustomsClearanceQuotationsScreen(embedded: embedded))
              : CustomsClearanceQuotationsScreen(embedded: embedded)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quotationStatusFilter')), findsOneWidget);
      expect(find.byType(RfqCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      // Price-list tab shows its empty state.
      await tester.tap(find.byIcon(Icons.price_change_rounded).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.price_change_outlined), findsOneWidget);
    });
  }
}
