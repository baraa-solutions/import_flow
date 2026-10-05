import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/demurrage_detention/models/demurrage_model.dart';
import 'package:frontend/features/demurrage_detention/providers/demurrage_provider.dart';
import 'package:frontend/features/demurrage_detention/widgets/free_days_agreement_dialog.dart';

void main() {
  group('BK-02: Free Days Agreement Registration Unit Tests', () {
    test('FreeDaysAgreementModel correctly parses JSON payload', () {
      final json = {
        'import_file_id': 99,
        'import_file_code': 'IMP-2026-0099',
        'carrier_name': 'MSC',
        'booking_code': 'BK-2026-0042',
        'booking_confirmation_no': 'MSC-EGY-998822',
        'standard_policy_demurrage_days': 14,
        'agreed_demurrage_free_days': 21,
        'agreed_detention_free_days': 14,
        'port_storage_free_days': 5,
        'additional_free_days_gained': 7,
        'estimated_cost_avoidance_usd': 980.0,
        'agreement_reference': 'MSC-FREE-AGR-2026-01',
        'agreement_date': '2026-04-15',
        'radar_status': 'Safe',
        'notes': '21 days agreed on booking note addendum',
      };

      final model = FreeDaysAgreementModel.fromJson(json);

      expect(model.importFileId, 99);
      expect(model.importFileCode, 'IMP-2026-0099');
      expect(model.carrierName, 'MSC');
      expect(model.bookingConfirmationNo, 'MSC-EGY-998822');
      expect(model.standardPolicyDemurrageDays, 14);
      expect(model.agreedDemurrageFreeDays, 21);
      expect(model.agreedDetentionFreeDays, 14);
      expect(model.additionalFreeDaysGained, 7);
      expect(model.estimatedCostAvoidanceUsd, 980.0);
      expect(model.agreementReference, 'MSC-FREE-AGR-2026-01');
      expect(model.radarStatus, 'Safe');
    });

    test('DemurrageState copyWith handles activeAgreement correctly', () {
      const state = DemurrageState();
      expect(state.activeAgreement, isNull);

      final agreement = FreeDaysAgreementModel(
        importFileId: 1,
        importFileCode: 'IMP-01',
        carrierName: 'Maersk',
        standardPolicyDemurrageDays: 14,
        agreedDemurrageFreeDays: 28,
        agreedDetentionFreeDays: 14,
        portStorageFreeDays: 7,
        additionalFreeDaysGained: 14,
        estimatedCostAvoidanceUsd: 1960.0,
        radarStatus: 'Safe',
      );

      final updated = state.copyWith(activeAgreement: agreement);
      expect(updated.activeAgreement, isNotNull);
      expect(updated.activeAgreement!.agreedDemurrageFreeDays, 28);
      expect(updated.activeAgreement!.additionalFreeDaysGained, 14);
    });

    testWidgets('FreeDaysAgreementDialog renders inputs and live savings breakdown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        const ProviderScope(
          child: AppLocalizationsProvider(
            locale: Locale('en'),
            child: MaterialApp(
              home: Scaffold(
                body: FreeDaysAgreementDialog(
                  initialCarrierName: 'MSC',
                  initialDemurrageDays: 21,
                  initialDetentionDays: 14,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header titles (English via AppLocalizationsProvider)
      expect(find.text('Free Days Agreement (BK-02)'), findsOneWidget);
      expect(find.textContaining('Document the free days agreed with the carrier'), findsOneWidget);

      // Verify inputs present
      expect(find.text('21'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);

      // Verify live savings and benefit card
      expect(find.textContaining('Financial Savings & Radar Analysis'), findsOneWidget);
      expect(find.textContaining('Confirm Free Days (BK-02)'), findsOneWidget);
    });
  });
}
