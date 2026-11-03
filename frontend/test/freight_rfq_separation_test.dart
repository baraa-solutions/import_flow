import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/providers/navigation_provider.dart';
import 'package:frontend/core/widgets/page_header.dart';
import 'package:frontend/features/freight_quotations/screens/freight_quotations_screen.dart';
import 'package:frontend/features/shipping_scenarios/screens/shipping_scenarios_screen.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/transport_locations/providers/transport_locations_provider.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

import 'package:frontend/features/projects/providers/projects_provider.dart';
import 'package:frontend/features/currencies/providers/currencies_provider.dart';
import 'package:frontend/features/shipping_scenarios/providers/shipping_scenarios_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/freight_quotations/providers/freight_quotations_provider.dart';

class MockPartnersNotifier extends AllPartnersNotifier {
  MockPartnersNotifier() : super(dio: Dio()) {
    state = const AsyncValue.data([]);
  }
  @override
  Future<void> fetchPartners() async {
    state = const AsyncValue.data([]);
  }
}

class MockCategoryPartnersNotifier extends PartnersNotifier {
  MockCategoryPartnersNotifier() : super(category: 'All', showInactive: true, dio: Dio()) {
    state = const AsyncValue.data([]);
  }
  @override
  Future<void> fetchPartners() async {
    state = const AsyncValue.data([]);
  }
}

class MockTransportNotifier extends TransportLocationsNotifier {
  MockTransportNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }
  @override
  Future<void> fetchLocations({bool includeInactive = true, String? locationType, String? search}) async {
    state = const AsyncValue.data([]);
  }
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
  }) async {
    state = const AsyncValue.data([]);
  }
}

class MockProjectsNotifier extends ProjectsNotifier {
  MockProjectsNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }
  @override
  Future<void> fetchProjects({bool includeInactive = true, String? status, String? search}) async {
    state = const AsyncValue.data([]);
  }
}

class MockCurrenciesNotifier extends CurrenciesNotifier {
  MockCurrenciesNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }
  @override
  Future<void> fetchCurrencies({bool includeInactive = true, String? search}) async {
    state = const AsyncValue.data([]);
  }
}

class MockShippingScenariosNotifier extends ShippingScenariosNotifier {
  MockShippingScenariosNotifier() : super(Dio()) {
    state = ShippingScenariosState();
  }
  @override
  Future<void> fetchSessions() async {
    state = ShippingScenariosState();
  }
}

class MockPurchaseOrdersNotifier extends PurchaseOrdersNotifier {
  MockPurchaseOrdersNotifier(Ref ref) : super(Dio(), ref) {
    state = PurchaseOrdersState();
  }
  @override
  Future<void> fetchPurchaseOrders() async {
    state = PurchaseOrdersState();
  }
}

class MockFreightQuotationsNotifier extends FreightQuotationsNotifier {
  MockFreightQuotationsNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }
  @override
  Future<void> fetchRFQs({
    bool includeInactive = false,
    String? search,
    String? shippingMethod,
    int? poId,
    int? projectId,
    String? status, int? skip, int? limit}) async {
    state = const AsyncValue.data([]);
  }
}

List<Override> get _testOverrides => [
  allPartnersProvider.overrideWith((ref) => MockPartnersNotifier()),
  partnersProvider.overrideWith((ref) => MockCategoryPartnersNotifier()),
  transportLocationsProvider.overrideWith((ref) => MockTransportNotifier()),
  importFilesProvider.overrideWith((ref) => MockImportFilesNotifier()),
  projectsProvider.overrideWith((ref) => MockProjectsNotifier()),
  currenciesProvider.overrideWith((ref) => MockCurrenciesNotifier()),
  shippingScenariosProvider.overrideWith((ref) => MockShippingScenariosNotifier()),
  purchaseOrdersProvider.overrideWith((ref) => MockPurchaseOrdersNotifier(ref)),
  freightQuotationsProvider.overrideWith((ref) => MockFreightQuotationsNotifier()),
];

void main() {
  group('Decoupling of Freight RFQ & Studies Architecture Tests', () {
    test('Navigation provider distinguishes Freight Studies (4, 5) and Freight RFQ (49)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(navigationIndexProvider.notifier).state = 4;
      expect(container.read(navigationIndexProvider), 4);

      container.read(navigationIndexProvider.notifier).state = 49;
      expect(container.read(navigationIndexProvider), 49);
    });

    testWidgets('FreightQuotationsScreen renders as dedicated operational workspace without TabBar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: _testOverrides,
          child: const MaterialApp(
            home: FreightQuotationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no TabBar exists on the operational RFQ screen
      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(TabBarView), findsNothing);

      // Verify operational actions exist in the page header (the metric card
      // strip also uses Icons.analytics_outlined, so scope to the header).
      final header = find.byType(PageHeader);
      expect(header, findsOneWidget);
      expect(find.descendant(of: header, matching: find.byIcon(Icons.folder_open_outlined)), findsOneWidget);
      expect(find.descendant(of: header, matching: find.byIcon(Icons.add_circle_outline)), findsOneWidget);
      expect(find.descendant(of: header, matching: find.byIcon(Icons.analytics_outlined)), findsOneWidget);

      // Verify Save RFQ button exists
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('ShippingScenariosScreen renders as dedicated studies hub', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: _testOverrides,
          child: const MaterialApp(
            home: ShippingScenariosScreen(initialIndex: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ShippingScenariosScreen), findsOneWidget);
    });
  });
}
