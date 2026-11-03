import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/split_shipments/split_shipments_provider.dart';
import 'package:frontend/features/split_shipments/widgets/prorated_cost_preview_card.dart';
import 'package:frontend/features/split_shipments/widgets/unallocated_po_items_table.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  group('Split Shipments Widgets Tests', () {
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(1366, 768);
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    final samplePoItem = UnallocatedPoItem(
      poItemId: 1,
      poId: 10,
      poNumber: 'PO-2026-900',
      itemSku: 'SKU-SOLAR-300',
      itemName: 'ألواح شمسية 300 واط',
      totalQuantity: 100,
      allocatedQuantity: 40,
    );

    final sampleAllocation = SplitAllocationData(
      id: 1,
      shipmentId: 101,
      parentBlNumber: 'MEDU12345678',
      splitBlNumber: 'MEDU12345678-A',
      itemSku: 'SKU-SOLAR-300',
      allocatedQuantity: 40.0,
      totalItemQuantity: 100.0,
      allocationRatio: 0.4,
      proratedCustomsCost: 12000.0,
      proratedFreightCost: 6000.0,
      currency: 'EGP',
    );

    testWidgets('UnallocatedPoItemsTable displays remaining quantity and allocation trigger', (tester) async {
      UnallocatedPoItem? selected;

      await tester.pumpWidget(
        _wrap(
          UnallocatedPoItemsTable(
            items: [samplePoItem],
            onAllocate: (item) => selected = item,
          ),
        ),
      );

      expect(find.text('PO-2026-900'), findsOneWidget);
      expect(find.text('SKU-SOLAR-300'), findsOneWidget);
      expect(find.text('60'), findsOneWidget); // remaining = 100 - 40

      await tester.ensureVisible(find.text('تخصيص لبوليصة'));
      await tester.tap(find.text('تخصيص لبوليصة'));
      expect(selected?.itemSku, equals('SKU-SOLAR-300'));
    });

    testWidgets('ProratedCostPreviewCard displays fair prorated costs and ratio', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProratedCostPreviewCard(
            allocations: [sampleAllocation],
            onRecalculatePool: () {},
          ),
        ),
      );

      expect(find.text('MEDU12345678-A'), findsOneWidget);
      expect(find.text('40.0%'), findsOneWidget);
      expect(find.text('12000.00 EGP'), findsOneWidget);
      expect(find.text('6000.00 EGP'), findsOneWidget);
      expect(find.text('18000.00 EGP'), findsOneWidget); // total landed
    });
  });
}
