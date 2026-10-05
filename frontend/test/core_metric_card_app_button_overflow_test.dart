import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/density_provider.dart';
import 'package:frontend/core/widgets/buttons/app_button.dart';
import 'package:frontend/core/widgets/metric_card.dart';

Widget _host(Widget child, {double width = 400}) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: width, child: child)),
        ),
      ),
    );

void main() {
  testWidgets('MetricCard with a very long value never overflows', (t) async {
    await t.pumpWidget(_host(
      const MetricCard(
        data: MetricCardData(
          title: 'Total Landed Cost Amount',
          value: '12,345,678,901.55 EGP',
          icon: Icons.attach_money,
          color: Colors.teal,
        ),
      ),
      width: 160,
    ));
    expect(tester(t), isNull);
  });

  testWidgets('MetricCardStrip with 4 long values never overflows', (t) async {
    await t.pumpWidget(_host(
      const MetricCardStrip(
        metrics: [
          MetricCardData(
              title: 'Total POs',
              value: '123,456,789',
              icon: Icons.list,
              color: Colors.teal),
          MetricCardData(
              title: 'Total Amount',
              value: '9,999,999,999.99',
              icon: Icons.money,
              color: Colors.teal),
          MetricCardData(
              title: 'CBM',
              value: '1,234,567.891',
              icon: Icons.inventory,
              color: Colors.teal),
          MetricCardData(
              title: 'Gross Weight',
              value: '888,888,888 kg',
              icon: Icons.scale,
              color: Colors.teal),
        ],
      ),
      width: 700,
    ));
    expect(tester(t), isNull);
  });

  testWidgets('AppButton(fit: true) ellipsizes instead of overflowing',
      (t) async {
    await t.pumpWidget(_host(
      AppButton(
        label: 'A very long button label that cannot fit',
        icon: Icons.save,
        fit: true,
        onPressed: () {},
      ),
      width: 120,
    ));
    expect(tester(t), isNull);
  });

  testWidgets('AppButton (default) squeezed below its natural width does not overflow',
      (t) async {
    await t.pumpWidget(_host(
      Row(children: [
        Expanded(
          child: AppButton(
            label: 'Search & Clone Customs Declaration',
            icon: Icons.copy_all,
            onPressed: () {},
          ),
        ),
      ]),
      width: 110,
    ));
    expect(tester(t), isNull);
    expect(find.text('Search & Clone Customs Declaration'), findsOneWidget);
  });

  testWidgets('AppButton (default) keeps its natural size when unconstrained',
      (t) async {
    await t.pumpWidget(_host(
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: AppButton(label: 'Save', icon: Icons.save, onPressed: () {}),
      ),
    ));
    expect(tester(t), isNull);
    final label = t.getSize(find.text('Save'));
    final unscaled = t.getSize(find.byType(ElevatedButton));
    expect(unscaled.width, greaterThan(label.width));
  });

  const stripMetrics = [
    MetricCardData(title: 'Total POs', value: '12', icon: Icons.list, color: Colors.teal),
    MetricCardData(title: 'Total Amount', value: '1,000.00', icon: Icons.money, color: Colors.teal),
  ];

  testWidgets('MetricCardStrip renders without a ProviderScope (comfortable density)',
      (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: SizedBox(width: 900, child: MetricCardStrip(metrics: stripMetrics))),
    ));
    expect(tester(t), isNull);
    expect(find.text('Total POs'), findsOneWidget);
    expect(find.text('1,000.00'), findsOneWidget);
    final strip = t.getSize(find.descendant(
        of: find.byType(MetricCardStrip), matching: find.byType(Container)).first);
    expect(strip.height, DisplayDensityMode.comfortable.metricCardHeight);
  });

  testWidgets('MetricCardStrip still follows displayDensityProvider inside a ProviderScope',
      (t) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // setDensity sets state synchronously; its secure-storage write never
    // completes under the test binding, so it is deliberately not awaited.
    // ignore: discarded_futures
    container.read(displayDensityProvider.notifier).setDensity(DisplayDensityMode.ultraCompact);
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: SizedBox(width: 900, child: MetricCardStrip(metrics: stripMetrics))),
      ),
    ));
    expect(tester(t), isNull);
    final strip = t.getSize(find.descendant(
        of: find.byType(MetricCardStrip), matching: find.byType(Container)).first);
    expect(strip.height, DisplayDensityMode.ultraCompact.metricCardHeight);
  });
}

Object? tester(WidgetTester t) => t.takeException();
