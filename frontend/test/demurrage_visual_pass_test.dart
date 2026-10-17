import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/live_pulse_badge.dart';
import 'package:frontend/core/widgets/states/app_error_state.dart';
import 'package:frontend/features/demurrage_detention/models/demurrage_model.dart';
import 'package:frontend/features/demurrage_detention/providers/demurrage_provider.dart';
import 'package:frontend/features/demurrage_detention/screens/demurrage_detention_screen.dart';
import 'package:frontend/features/demurrage_detention/widgets/demurrage_form_dialogs.dart';
import 'package:frontend/features/demurrage_detention/widgets/demurrage_status.dart';

import 'helpers/localized_app.dart';

class _FakeDemurrage extends DemurrageNotifier {
  _FakeDemurrage(DemurrageState initial) : super(Dio()) {
    state = initial;
  }

  @override
  Future<void> loadInitialData() async {}

  @override
  Future<void> fetchTrackings({int? importFileId, String? carrierName, String? status, int skip = 0, int limit = 200}) async {}

  @override
  Future<DemurrageSimulationResultModel?> simulateCalculation(Map<String, dynamic> requestPayload) async =>
      state.simulationResult;

  @override
  Future<FreeDaysAgreementModel?> fetchFreeDaysAgreement(int importFileId) async => null;
}

DemurrageTrackingModel _tracking({String status = 'Demurrage Incurred', double cost = 12500.5, String? gateOut}) {
  return DemurrageTrackingModel.fromJson({
    'tracking_id': 7,
    'tracking_code': 'DEM-2026-0007',
    'carrier_name': 'MSC',
    'bill_of_lading_no': 'MEDUXX123456',
    'port_name': 'Alexandria Port',
    'discharge_date': '2026-09-01',
    'gate_out_date': gateOut,
    'containers': [
      {'container_number': 'MSCU1234567'}
    ],
    'total_demurrage_fx': 410.0,
    'total_detention_fx': 120.0,
    'total_storage_egp': 800.0,
    'currency': 'USD',
    'exchange_rate': 48.0,
    'total_cost_egp': cost,
    'status': status,
  });
}

DemurrageSimulationResultModel _simulation({String badge = 'DEMURRAGE_INCURRED'}) {
  return DemurrageSimulationResultModel.fromJson({
    'demurrage_days_consumed': 20,
    'demurrage_free_days': 14,
    'demurrage_days_overdue': 6,
    'demurrage_fee_fx': 300.0,
    'demurrage_expiry_date': '2026-09-15',
    'detention_days_consumed': 0,
    'detention_free_days': 7,
    'detention_days_overdue': 0,
    'detention_fee_fx': 0.0,
    'storage_days_consumed': 9,
    'storage_free_days': 5,
    'storage_days_overdue': 4,
    'storage_fee_egp': 1200.0,
    'total_fee_fx': 300.0,
    'total_cost_egp': 15600.0,
    'status_badge': badge,
    'breakdown_details': [
      {
        'category': 'DEMURRAGE',
        'days_consumed': 20,
        'free_days': 14,
        'days_overdue': 6,
        'currency': 'USD',
        'fee_fx': 300.0,
      },
    ],
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required DemurrageState state,
  Locale locale = AppLocales.english,
  Size size = const Size(1366, 768),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [demurrageProvider.overrideWith((ref) => _FakeDemurrage(state))],
      child: localizedApp(home: const DemurrageDetentionScreen(), locale: locale),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DemurrageStatusStyle', () {
    test('maps tracking statuses to severities', () {
      expect(DemurrageStatusStyle.ofTracking('Demurrage Incurred'), AppSeverity.danger);
      expect(DemurrageStatusStyle.ofTracking('Detention Incurred'), AppSeverity.danger);
      expect(DemurrageStatusStyle.ofTracking('Free Time Active'), AppSeverity.success);
      expect(DemurrageStatusStyle.ofTracking('Pushed to Settlement'), AppSeverity.info);
      expect(DemurrageStatusStyle.ofTracking('RETURNED_SAFE'), AppSeverity.success);
      expect(DemurrageStatusStyle.ofTracking('something else'), AppSeverity.info);
    });

    test('maps simulation badges to severities', () {
      expect(DemurrageStatusStyle.ofBadge('SAFE'), AppSeverity.success);
      expect(DemurrageStatusStyle.ofBadge('WARNING'), AppSeverity.warning);
      expect(DemurrageStatusStyle.ofBadge('DEMURRAGE_AND_DETENTION_INCURRED'), AppSeverity.danger);
    });

    test('daysSinceDischarge stops at gate-out and never goes negative', () {
      expect(
        DemurrageStatusStyle.daysSinceDischarge('2026-09-01', '2026-09-11'),
        10,
      );
      expect(
        DemurrageStatusStyle.daysSinceDischarge('2026-09-01', null, now: DateTime(2026, 9, 4)),
        3,
      );
      expect(DemurrageStatusStyle.daysSinceDischarge('2026-09-10', '2026-09-01'), 0);
      expect(DemurrageStatusStyle.daysSinceDischarge('not-a-date', null), 0);
    });
  });

  group('DemurrageDetentionScreen visual pass', () {
    setUp(() => LivePulseBadge.enableAnimation = false);
    tearDown(() => LivePulseBadge.enableAnimation = true);

    testWidgets('renders trackings with exposure in English at 1366x768', (tester) async {
      await _pumpScreen(
        tester,
        state: DemurrageState(trackings: [_tracking(), _tracking(status: 'Free Time Active', cost: 0)]),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('DEM-2026-0007'), findsWidgets);
      expect(find.textContaining('12,500.50'), findsWidgets);
    });

    testWidgets('renders trackings in Arabic RTL without layout errors', (tester) async {
      await _pumpScreen(
        tester,
        state: DemurrageState(trackings: [_tracking(gateOut: '2026-09-10')]),
        locale: AppLocales.arabic,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('DEM-2026-0007'), findsWidgets);
    });

    testWidgets('narrow window (900 wide) does not overflow', (tester) async {
      await _pumpScreen(
        tester,
        state: DemurrageState(trackings: [_tracking()]),
        size: const Size(900, 700),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty list shows the empty state', (tester) async {
      await _pumpScreen(tester, state: const DemurrageState());
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('failed load with no data shows a retry error state', (tester) async {
      await _pumpScreen(
        tester,
        state: const DemurrageState(error: 'boom', errorObject: 'boom'),
      );
      expect(tester.takeException(), isNull);
      // CcStateView.error renders the shared AppErrorState (its own icon) with a retry action.
      expect(find.byType(AppErrorState), findsOneWidget);
      expect(find.text('Retry'), findsWidgets);
    });

    testWidgets('simulator tab shows the severity banner and the cost summary', (tester) async {
      await _pumpScreen(
        tester,
        state: DemurrageState(simulationResult: _simulation()),
      );
      await tester.tap(find.byIcon(Icons.calculate_outlined).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
      expect(find.textContaining('15,600.00'), findsWidgets);
    });

    testWidgets('simulator tab asks for the exchange rate while no result exists', (tester) async {
      await _pumpScreen(tester, state: const DemurrageState());
      await tester.tap(find.byIcon(Icons.calculate_outlined).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Enter the exchange rate to run the simulation'), findsOneWidget);
    });

    testWidgets('policies tab renders policy cards in Arabic', (tester) async {
      await _pumpScreen(
        tester,
        state: DemurrageState(policies: [
          DemurragePolicyModel.fromJson({
            'policy_id': 1,
            'carrier_name': 'MSC',
            'container_type': '40ft High Cube',
            'demurrage_free_days': 14,
            'detention_free_days': 7,
            'port_storage_free_days': 5,
            'currency': 'USD',
            'port_storage_daily_rate_egp': 20.0,
          }),
        ]),
        locale: AppLocales.arabic,
      );
      await tester.tap(find.byIcon(Icons.policy_outlined).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('MSC - 40ft High Cube'), findsOneWidget);
    });
  });

  group('Demurrage form dialogs', () {
    Future<void> pumpDialog(WidgetTester tester, Widget dialog, {Locale locale = AppLocales.english, Size size = const Size(1366, 768)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [demurrageProvider.overrideWith((ref) => _FakeDemurrage(const DemurrageState()))],
          child: localizedApp(home: Scaffold(body: dialog), locale: locale),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('AddTrackingDialog renders its form (en and ar)', (tester) async {
      await pumpDialog(tester, const AddTrackingDialog());
      expect(tester.takeException(), isNull);
      expect(find.text('Save & Start Tracking'), findsOneWidget);
      await pumpDialog(tester, const AddTrackingDialog(), locale: AppLocales.arabic, size: const Size(700, 600));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AddTrackingDialog requires B/L and container numbers', (tester) async {
      await pumpDialog(tester, const AddTrackingDialog());
      await tester.tap(find.text('Save & Start Tracking'));
      await tester.pumpAndSettle();
      expect(find.text('Required field'), findsNWidgets(2));
    });

    testWidgets('UpdateTrackingDatesDialog renders existing dates', (tester) async {
      await pumpDialog(tester, UpdateTrackingDatesDialog(item: _tracking(gateOut: '2026-09-10')));
      expect(tester.takeException(), isNull);
      expect(find.text('2026-09-10'), findsOneWidget);
    });

    testWidgets('AddPolicyDialog requires the daily storage rate', (tester) async {
      await pumpDialog(tester, const AddPolicyDialog());
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Save Policy'));
      await tester.pumpAndSettle();
      expect(find.text('Required field'), findsOneWidget);
    });
  });
}
