@Tags(['perf'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/features/external_service_providers/models/partner_model.dart';
import 'package:frontend/features/external_service_providers/widgets/partner_details_dialog.dart';

PartnerModel _createMockPartner() {
  return PartnerModel(
    providerId: 303,
    partnerCode: 'PRT-000303',
    partnerName: 'Maersk Line Egypt & Middle East',
    partnerType: 'Shipping Line, Freight Forwarder',
    taxId: '998-112-334',
    commercialRegister: 'CR-987654321',
    scacCode: 'MAEU',
    trackingUrl: 'https://www.maersk.com/tracking/',
    swiftCode: 'MAERSKEGCXX',
    contactPerson: 'Eng. Tarek Mostafa',
    phone: '+20 2 2456 7890',
    mobile: '+20 122 345 6789',
    email: 'egypt.import@maersk.com',
    website: 'https://www.maersk.com',
    address: 'Building 12, Smart Village, Cairo-Alexandria Desert Road, Giza',
    country: 'Egypt',
    paymentType: 'Credit',
    creditLimit: 500000.0,
    rating: 4.9,
    notes: 'شريك شحن متميز معتمد بخطوط ملاحية مباشرة إلى موانئ الإسكندرية ودمياط وبورسعيد والسخنة.',
    isActive: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Modal Dialog: PartnerDetailsDialog Performance Diagnostics', () {
    testWidgets('Measure Dimension A and Dimension B across 3 runs', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<int> navInFirstFrameTimes = [];
      final List<int> navInSettledTimes = [];
      final List<int> navOutTimes = [];

      final mockPartner = _createMockPartner();

      // Warm-up run to eliminate cold JIT compilation overhead
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) {
              final n = LocaleNotifier();
              n.setLocale(const Locale('ar'));
              return n;
            }),
          ],
          child: MaterialApp(
            home: AppLocalizationsProvider(
              locale: const Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: PartnerDetailsDialog(partner: mockPartner),
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
            ],
            child: MaterialApp(
              home: AppLocalizationsProvider(
                locale: const Locale('ar'),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: PartnerDetailsDialog(partner: mockPartner),
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
      debugPrint('MODAL (PartnerDetailsDialog) BENCHMARK RESULTS:');
      debugPrint('Average Nav-IN First Frame: ${avgFirstFrame}ms');
      debugPrint('Average Nav-IN Settled:     ${avgSettled}ms');
      debugPrint('Average Nav-OUT (Disposal): ${avgNavOut}ms');
      debugPrint('==================================================');

      expect(avgFirstFrame, lessThanOrEqualTo(600));
      expect(avgSettled, lessThanOrEqualTo(800));
      expect(avgNavOut, lessThanOrEqualTo(250));
    });
  });
}
