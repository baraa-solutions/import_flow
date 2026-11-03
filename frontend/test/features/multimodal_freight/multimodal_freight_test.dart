import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/multimodal_freight/multimodal_freight_provider.dart';
import 'package:frontend/features/multimodal_freight/widgets/air_freight_details_card.dart';
import 'package:frontend/features/multimodal_freight/widgets/lcl_consolidation_card.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  group('Multimodal Freight Widgets Tests', () {
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

    testWidgets('AirFreightDetailsCard displays AWB and THC fields', (tester) async {
      final sampleAir = MultimodalFreightRecord(
        id: 1,
        shipmentId: 101,
        transportMode: 'AIR',
        awbNumber: '077-99887766',
        airlineCode: 'MS',
        flightNumber: 'MS777',
        terminalHandlingCharges: 4500.0,
        lclCbm: 0.0,
        lclRatePerCbm: 0.0,
        lclCfsFee: 0.0,
        roroDimensionsCbm: 0.0,
        bulkTonnage: 0.0,
        calculatedSubtotal: 4500.0,
      );

      await tester.pumpWidget(
        _wrap(
          AirFreightDetailsCard(
            record: sampleAir,
            onSave: (_) {},
          ),
        ),
      );

      expect(find.text('بيانات الشحن الجوي ومناولة المطار'), findsOneWidget);
      expect(find.text('077-99887766'), findsOneWidget);
      expect(find.text('MS'), findsOneWidget);
      expect(find.text('MS777'), findsOneWidget);
    });

    testWidgets('LclConsolidationCard computes instant subtotal dynamically', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LclConsolidationCard(
            onSave: (_) {},
          ),
        ),
      );

      expect(find.text('شحن الحاويات المشترك (LCL) ورسوم محطة الفرز'), findsOneWidget);

      // Enter 10 CBM, rate 80, cfs 200 -> total = 1000
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '10');
      await tester.enterText(textFields.at(1), '80');
      await tester.enterText(textFields.at(2), '200');
      await tester.pump();

      expect(find.text('1000.00 دولار'), findsOneWidget);
    });
  });
}
