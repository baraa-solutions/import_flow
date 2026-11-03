import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/container_tracking/container_tracking_provider.dart';
import 'package:frontend/features/container_tracking/widgets/container_tracker_table.dart';
import 'package:frontend/features/container_tracking/widgets/demurrage_per_container_card.dart';

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
  group('Container Tracking Widgets Tests', () {
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

    final sampleContainer = ContainerUnitData(
      id: 1,
      containerNumber: 'MSKU1234567',
      sealNumber: 'SEAL-001',
      isoType: '40HC',
      grossWeight: 24500.0,
      dischargeDate: DateTime(2026, 10, 1),
      emptyReturnedDate: DateTime(2026, 10, 20),
      status: 'RETURNED_EMPTY',
      shipmentId: 101,
      demurrageCharges: [
        ContainerDemurrageData(
          id: 1,
          containerId: 1,
          freeTimeDays: 14,
          freeTimeEndDate: DateTime(2026, 10, 15),
          dailyDemurrageRate: 50.0,
          actualReturnDate: DateTime(2026, 10, 20),
          daysOverdue: 5,
          totalDemurrageAmount: 250.0,
          currency: 'USD',
        ),
      ],
    );

    testWidgets('ContainerTrackerTable displays container number and demurrage amount', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContainerTrackerTable(
            containers: [sampleContainer],
            onRefresh: () {},
            onSelectTimeline: (_) {},
            onSelectDemurrage: (_) {},
          ),
        ),
      );

      expect(find.text('MSKU1234567'), findsOneWidget);
      expect(find.text('40HC'), findsOneWidget);
      expect(find.text('250.00 دولار'), findsOneWidget);
      expect(find.text('تم إرجاع الحاوية الفارغة'), findsOneWidget);
    });

    testWidgets('DemurragePerContainerCard displays free time countdown and total fine', (tester) async {
      bool recalculated = false;

      await tester.pumpWidget(
        _wrap(
          DemurragePerContainerCard(
            container: sampleContainer,
            onRecalculate: () => recalculated = true,
            onClose: () {},
          ),
        ),
      );

      expect(find.text('غرامات تأخير الحاوية: MSKU1234567'), findsOneWidget);
      expect(find.text('5 يوم'), findsOneWidget);
      expect(find.text('250.00 USD'), findsOneWidget);
      expect(find.text('14 يوماً'), findsOneWidget);

      await tester.tap(find.text('إعادة احتساب الغرامة'));
      expect(recalculated, isTrue);
    });
  });
}
