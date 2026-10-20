import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/cargo_shipping/models/cargo_container_defaults.dart';
import 'package:frontend/features/cargo_shipping/providers/cargo_shipping_provider.dart';
import 'package:frontend/features/cargo_shipping/screens/cargo_shipping_screen.dart';
import 'package:frontend/features/freight_booking/models/freight_booking_model.dart';
import 'package:frontend/features/freight_booking/providers/freight_booking_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';

void main() {
  group('cargo defaults never invent values', () {
    test('blankContainer has no numbers and zero weights', () {
      final c = blankContainer(assignmentDateIso: '2026-01-01T00:00:00');
      expect(c.containerNo, isEmpty);
      expect(c.sealNo, isEmpty);
      expect(c.vgmRefNo, isNull);
      expect(c.grossWeightKg, 0);
      expect(c.tareWeightKg, 0);
      expect(c.netWeightKg, 0);
      expect(c.individualUnits, [
        {'container_no': '', 'seal_no': ''},
      ]);
    });

    test('blankUnits creates the requested count of empty slots', () {
      expect(blankUnits(3), hasLength(3));
      expect(blankUnits(0), isEmpty);
    });

    test('dualRecommendationOrNull is null without real metrics', () {
      expect(dualRecommendationOrNull(totalCbm: 0, totalWeightKg: 0), isNull);
    });

    test('dualRecommendationOrNull computes from the given numbers only', () {
      final r = dualRecommendationOrNull(totalCbm: 12.5, totalWeightKg: 4000);
      expect(r, isNotNull);
      expect(r!.stackableResult.requiredContainersCount, greaterThan(0));
    });
  });

  testWidgets('screen without cargo metrics shows "missing" and no sample container data', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    const en = AppLocalizationsEn();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cargoShippingProvider.overrideWith((ref) => _CargoNotifier()),
          importFilesProvider.overrideWith((ref) => _FilesNotifier()),
          freightBookingProvider.overrideWith((ref) => _BookingNotifier()),
          purchaseOrdersProvider.overrideWith((ref) => _PoNotifier()),
        ],
        child: const MaterialApp(
          home: AppLocalizationsProvider(
            locale: Locale('en'),
            child: Scaffold(body: CargoShippingScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cargoMetricsMissing')), findsOneWidget);
    expect(find.text(en.cshCargoMetricsMissing), findsOneWidget);
    expect(find.textContaining('MSCU'), findsNothing);
    expect(find.textContaining('SL-99001'), findsNothing);
    expect(find.textContaining('Shanghai'), findsNothing);
    expect(find.textContaining('2274'), findsNothing);
  });
}

class _CargoNotifier extends CargoShippingNotifier {
  _CargoNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }
}

class _FilesNotifier extends ImportFilesNotifier {
  _FilesNotifier() : super(Dio()) {
    state = const AsyncValue.data(<ImportFileModel>[]);
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

class _BookingNotifier extends FreightBookingNotifier {
  _BookingNotifier() : super(Dio()) {
    state = const AsyncValue.data(<ShipmentBookingModel>[]);
  }

  @override
  Future<void> fetchBookings({bool includeInactive = false, int? importFileId, String? status, String? search, int skip = 0, int limit = 200}) async {}
}

class _PoNotifier extends StateNotifier<PurchaseOrdersState> implements PurchaseOrdersNotifier {
  _PoNotifier() : super(PurchaseOrdersState(purchaseOrders: const <PurchaseOrderModel>[]));

  @override
  Future<void> fetchPurchaseOrders({
    bool includeInactive = false,
    String? search,
    int? importFileId,
    int? supplierId,
    String? status,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
