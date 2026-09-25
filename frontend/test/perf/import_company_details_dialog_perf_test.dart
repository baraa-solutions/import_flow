@Tags(['perf'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/features/import_companies/models/import_company_model.dart';
import 'package:frontend/features/import_companies/widgets/import_company_details_dialog.dart';

ImportCompanyModel _createMockCompany() {
  final now = DateTime.now();
  return ImportCompanyModel(
    companyId: 101,
    importerName: 'شركة سرور للاستيراد والتصدير والتخليص الجمركي',
    address: '15 شارع النصر، الدور الرابع، مصر الجديدة، القاهرة',
    country: 'مصر',
    importerId: 'IMP-EG-2026-8899',
    importerIdExpiry: now.add(const Duration(days: 120)),
    vatId: 'TAX-998877665',
    vatIdExpiry: now.add(const Duration(days: 240)),
    registrationNumber: 'CR-1234567890',
    registrationExpiry: now.add(const Duration(days: 400)),
    phone: '+20 100 123 4567',
    email: 'info@sorourlogistics.com',
    isActive: true,
    notes: 'شركة معتمدة وذات أولوية خاصة في التخليص الجمركي وعمليات الإفراج تحت التحفظ.',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Modal Dialog: ImportCompanyDetailsDialog Performance Diagnostics', () {
    testWidgets('Measure Dimension A and Dimension B across 3 runs', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<int> navInFirstFrameTimes = [];
      final List<int> navInSettledTimes = [];
      final List<int> navOutTimes = [];

      final mockCompany = _createMockCompany();

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
                child: ImportCompanyDetailsDialog(company: mockCompany),
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
                  child: ImportCompanyDetailsDialog(company: mockCompany),
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
      debugPrint('MODAL (ImportCompanyDetailsDialog) BENCHMARK RESULTS:');
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
