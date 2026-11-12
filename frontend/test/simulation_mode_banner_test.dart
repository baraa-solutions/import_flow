import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/cargox/models/cargox_model.dart';
import 'package:frontend/features/integrations/models/integration_status_model.dart';
import 'package:frontend/features/integrations/providers/integration_status_provider.dart';
import 'package:frontend/features/integrations/widgets/simulation_mode_banner.dart';

IntegrationStatus _status({required bool simulated, bool available = true}) => IntegrationStatus.fromJson({
      'is_production_build': false,
      'any_simulated': simulated,
      'providers': [
        for (final p in ['NAFEZA', 'CARGOX', 'PKI', 'GOEIC'])
          {
            'provider': p,
            'integration_mode': simulated ? 'MOCK' : 'LIVE',
            'is_simulated': simulated,
            'is_available': available,
            'message': 'msg',
          },
      ],
    });

Widget _host(Widget child, {IntegrationStatus? status, Object? error}) {
  return ProviderScope(
    overrides: [
      integrationStatusProvider.overrideWith((ref) async {
        if (error != null) throw error;
        return status!;
      }),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('Production Mock Guard - SimulationModeBanner', () {
    testWidgets('shows banner when providers are simulated', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SimulationModeBanner(simulatedProviders: ['NAFEZA', 'CARGOX'])),
      ));
      expect(find.byKey(const Key('simulation_mode_banner')), findsOneWidget);
      expect(find.text(SimulationModeBanner.titleAr), findsOneWidget);
      expect(find.textContaining('NAFEZA, CARGOX'), findsOneWidget);
    });

    testWidgets('hidden when nothing is simulated', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SimulationModeBanner(simulatedProviders: [])),
      ));
      expect(find.byKey(const Key('simulation_mode_banner')), findsNothing);
    });

    testWidgets('consumer shows banner for MOCK backend', (tester) async {
      await tester.pumpWidget(_host(const IntegrationSimulationBanner(), status: _status(simulated: true)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('simulation_mode_banner')), findsOneWidget);
    });

    testWidgets('consumer hides banner for LIVE backend', (tester) async {
      await tester.pumpWidget(_host(const IntegrationSimulationBanner(), status: _status(simulated: false)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('simulation_mode_banner')), findsNothing);
    });

    testWidgets('consumer assumes simulation when status cannot be loaded', (tester) async {
      await tester.pumpWidget(_host(const IntegrationSimulationBanner(), error: Exception('offline')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('simulation_mode_banner')), findsOneWidget);
    });

    testWidgets('status table marks blocked providers', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: IntegrationStatusTable(status: _status(simulated: true, available: false))),
      ));
      expect(find.text('MOCK - BLOCKED'), findsNWidgets(4));
    });
  });

  group('Integration status models', () {
    test('missing is_simulated defaults to simulated', () {
      final p = IntegrationProviderStatus.fromJson({'provider': 'NAFEZA'});
      expect(p.isSimulated, isTrue);
      expect(p.integrationMode, 'MOCK');
    });

    test('envelope model reads simulation flag', () {
      final env = CargoXEnvelopeModel.fromJson({'integration_mode': 'MOCK', 'is_simulated': true});
      expect(env.isSimulated, isTrue);
      final legacy = CargoXEnvelopeModel.fromJson({});
      expect(legacy.isSimulated, isFalse);
    });
  });
}
