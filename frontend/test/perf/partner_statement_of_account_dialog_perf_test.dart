@Tags(['perf'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/features/external_service_providers/models/partner_model.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/external_service_providers/widgets/partner_statement_of_account_dialog.dart';

PartnerModel _createMockPartner() {
  return PartnerModel(
    providerId: 303,
    partnerCode: 'PRT-000303',
    partnerName: 'Maersk Line Egypt',
    partnerType: 'Shipping Line',
    taxId: '998-112-334',
    country: 'Egypt',
    paymentType: 'Credit',
    creditLimit: 500000.0,
    rating: 5.0,
    isActive: true,
  );
}

PartnerStatementOfAccountModel _createMockSoa() {
  return PartnerStatementOfAccountModel(
    providerId: 303,
    partnerCode: 'PRT-000303',
    partnerName: 'Maersk Line Egypt',
    partnerType: 'Shipping Line',
    totalInvoicesCount: 4,
    totalPaymentsCount: 2,
    currencyBalances: [
      PartnerCurrencyBalanceModel(
        currency: 'USD',
        totalInvoiced: 45000.0,
        totalPaid: 30000.0,
        balanceDue: 15000.0,
      ),
      PartnerCurrencyBalanceModel(
        currency: 'EGP',
        totalInvoiced: 125000.0,
        totalPaid: 125000.0,
        balanceDue: 0.0,
      ),
    ],
    ledgerEntries: [
      PartnerLedgerEntryModel(
        entryId: 'ENT-001',
        entryDate: '2026-08-01',
        entryType: 'Invoice',
        referenceNo: 'INV-MSK-2026-001',
        description: 'نولون بحري لشحنة قطع غيار - بوليصة MSK-BL-8899',
        importFileCode: 'IMP-2026-001',
        currency: 'USD',
        debitAmount: 25000.0,
        creditAmount: 0.0,
        runningBalance: 25000.0,
        status: 'Approved',
      ),
      PartnerLedgerEntryModel(
        entryId: 'ENT-002',
        entryDate: '2026-08-10',
        entryType: 'Payment',
        referenceNo: 'PAY-MSK-001',
        description: 'سداد دفعة نولون بحري تحويل بنكي',
        importFileCode: 'IMP-2026-001',
        currency: 'USD',
        debitAmount: 0.0,
        creditAmount: 25000.0,
        runningBalance: 0.0,
        status: 'Reconciled',
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Modal Dialog: PartnerStatementOfAccountDialog Performance Diagnostics', () {
    testWidgets('Measure Dimension A and Dimension B across 3 runs', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<int> navInFirstFrameTimes = [];
      final List<int> navInSettledTimes = [];
      final List<int> navOutTimes = [];

      final mockPartner = _createMockPartner();
      final mockSoa = _createMockSoa();

      // Warm-up run to eliminate cold JIT compilation overhead
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) {
              final n = LocaleNotifier();
              n.setLocale(const Locale('ar'));
              return n;
            }),
            partnerStatementOfAccountProvider(303).overrideWith((ref) async => mockSoa),
          ],
          child: MaterialApp(
            home: AppLocalizationsProvider(
              locale: const Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: PartnerStatementOfAccountDialog(partner: mockPartner),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Empty Destination')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 1; i <= 3; i++) {
        final navWatch = Stopwatch()..start();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localeProvider.overrideWith((ref) {
                final n = LocaleNotifier();
                n.setLocale(const Locale('ar'));
                return n;
              }),
              partnerStatementOfAccountProvider(303).overrideWith((ref) async => mockSoa),
            ],
            child: MaterialApp(
              home: AppLocalizationsProvider(
                locale: const Locale('ar'),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: PartnerStatementOfAccountDialog(partner: mockPartner),
                ),
              ),
            ),
          ),
        );

        final firstFrameMs = navWatch.elapsedMilliseconds;
        navInFirstFrameTimes.add(firstFrameMs);

        await tester.pumpAndSettle();
        navWatch.stop();
        final settledMs = navWatch.elapsedMilliseconds;
        navInSettledTimes.add(settledMs);

        final outWatch = Stopwatch()..start();

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(child: Text('Empty Destination')),
            ),
          ),
        );

        await tester.pumpAndSettle();
        outWatch.stop();
        final navOutMs = outWatch.elapsedMilliseconds;
        navOutTimes.add(navOutMs);

        debugPrint('Run #$i: Nav-IN (First Frame): ${firstFrameMs}ms | Nav-IN (Settled): ${settledMs}ms | Nav-OUT: ${navOutMs}ms');
      }

      final avgFirstFrame = navInFirstFrameTimes.reduce((a, b) => a + b) ~/ navInFirstFrameTimes.length;
      final avgSettled = navInSettledTimes.reduce((a, b) => a + b) ~/ navInSettledTimes.length;
      final avgNavOut = navOutTimes.reduce((a, b) => a + b) ~/ navOutTimes.length;

      debugPrint('==================================================');
      debugPrint('MODAL (PartnerStatementOfAccountDialog) BENCHMARK RESULTS:');
      debugPrint('Average Nav-IN First Frame: ${avgFirstFrame}ms');
      debugPrint('Average Nav-IN Settled:     ${avgSettled}ms');
      debugPrint('Average Nav-OUT (Disposal): ${avgNavOut}ms');
      debugPrint('==================================================');

      expect(avgFirstFrame, lessThanOrEqualTo(300));
      expect(avgSettled, lessThanOrEqualTo(350));
      expect(avgNavOut, lessThanOrEqualTo(150));
    });
  });
}
