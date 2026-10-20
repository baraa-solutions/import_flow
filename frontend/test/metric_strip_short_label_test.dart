import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/density_provider.dart';
import 'package:frontend/core/widgets/metric_card.dart';

class TestDensityNotifier extends DisplayDensityNotifier {
  TestDensityNotifier(DisplayDensityMode initial) : super() {
    state = initial;
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('MetricCardData Short Label & Value Preservation Unit Tests', () {
    test('defaultShortLabel dictionary maps standard metrics correctly', () {
      expect(MetricCardData.defaultShortLabel('Total POs'), 'POs');
      expect(MetricCardData.defaultShortLabel('Total PI/PO Amount'), 'PI/PO Amt');
      expect(MetricCardData.defaultShortLabel('Total Cargo CBM'), 'CBM');
      expect(MetricCardData.defaultShortLabel('Total Gross Weight'), 'Gross Wt');
      expect(MetricCardData.defaultShortLabel('Total Shipments'), 'Shipments');
      expect(MetricCardData.defaultShortLabel('Total FOB Value'), 'FOB Val');
      expect(MetricCardData.defaultShortLabel('Custom Unknown Metric'), 'Custom Unknown Metric');
    });

    test('effectiveTitle respects explicit shortTitle', () {
      const data = MetricCardData(
        title: 'Total Purchase Orders',
        shortTitle: 'POs',
        value: '42',
        icon: Icons.receipt_long,
        color: Colors.blue,
      );

      // Comfortable density with forceShort = false -> Full title
      expect(data.effectiveTitle(DisplayDensityMode.comfortable), 'Total Purchase Orders');

      // Compact density -> short title
      expect(data.effectiveTitle(DisplayDensityMode.compact), 'POs');

      // Ultra-Compact density -> short title
      expect(data.effectiveTitle(DisplayDensityMode.ultraCompact), 'POs');

      // forceShort: true -> short title even in Comfortable density
      expect(data.effectiveTitle(DisplayDensityMode.comfortable, forceShort: true), 'POs');
    });

    test('effectiveTitle falls back to defaultShortLabel when shortTitle is null', () {
      const data = MetricCardData(
        title: 'Total PI/PO Amount',
        value: r',294.00',
        icon: Icons.monetization_on,
        color: Colors.green,
      );

      expect(data.effectiveTitle(DisplayDensityMode.comfortable), 'Total PI/PO Amount');
      expect(data.effectiveTitle(DisplayDensityMode.compact), 'PI/PO Amt');
      expect(data.effectiveTitle(DisplayDensityMode.ultraCompact), 'PI/PO Amt');
      expect(data.effectiveTitle(DisplayDensityMode.comfortable, forceShort: true), 'PI/PO Amt');
    });

    test('Numeric value is strictly preserved and never truncated or modified', () {
      const testValues = [
        r',294.00',
        '3,450.50 CBM',
        '85,200.00 KG',
        'EGP 4,500,230.75',
      ];

      for (final val in testValues) {
        final data = MetricCardData(
          title: 'Total PI/PO Amount',
          shortTitle: 'PI/PO Amt',
          value: val,
          icon: Icons.attach_money,
          color: Colors.green,
        );

        // Regardless of density, the value property is untouched
        expect(data.value, val);
      }
    });
  });

  group('MetricCard & MetricCardStrip Widget Tests', () {
    testWidgets('MetricCard displays short title when compact density is active', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                displayDensityProvider.overrideWith((ref) => TestDensityNotifier(DisplayDensityMode.compact)),
              ],
              child: const MetricCard(
                data: MetricCardData(
                  title: 'Total Gross Weight',
                  shortTitle: 'Gross Wt',
                  value: '12,500 KG',
                  icon: Icons.scale_outlined,
                  color: Colors.orange,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gross Wt'), findsOneWidget);
      expect(find.text('12,500 KG'), findsOneWidget);
    });

    testWidgets('MetricCardStrip wraps into 2 rows when width is narrow (< 660px)', (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              child: MetricCardStrip(
                metrics: [
                  MetricCardData(title: 'Total POs', shortTitle: 'POs', value: '14', icon: Icons.receipt, color: Colors.blue),
                  MetricCardData(title: 'Total PI/PO Amount', shortTitle: 'PI/PO Amt', value: r',294.00', icon: Icons.attach_money, color: Colors.green),
                  MetricCardData(title: 'Total Cargo CBM', shortTitle: 'CBM', value: '124.50 CBM', icon: Icons.view_in_ar, color: Colors.purple),
                  MetricCardData(title: 'Total Gross Weight', shortTitle: 'Gross Wt', value: '45,200 KG', icon: Icons.scale, color: Colors.orange),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All 4 metric values are displayed cleanly without any overflow error
      expect(find.text('14'), findsOneWidget);
      expect(find.text(r',294.00'), findsOneWidget);
      expect(find.text('124.50 CBM'), findsOneWidget);
      expect(find.text('45,200 KG'), findsOneWidget);

      // Short titles are forced because space is constrained
      expect(find.text('POs'), findsOneWidget);
      expect(find.text('PI/PO Amt'), findsOneWidget);
      expect(find.text('CBM'), findsOneWidget);
      expect(find.text('Gross Wt'), findsOneWidget);
    });
  });
}
