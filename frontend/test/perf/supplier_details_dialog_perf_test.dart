@Tags(['perf'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/features/suppliers/models/supplier_model.dart';
import 'package:frontend/features/suppliers/widgets/supplier_details_dialog.dart';

SupplierModel _createMockSupplier() {
  return SupplierModel(
    supplierId: 202,
    supplierCode: 'SUP-000202',
    companyName: 'Global Logistics & Manufacturing Corp.',
    supplierType: 'MANUFACTURER',
    registrationType: 'VAT_REGISTERED',
    foreignExporterId: 'EXP-DE-88776655',
    cargoxPlatformId: 'CX-GLOBAL-99887',
    foreignExporterCountry: 'ألمانيا (Germany)',
    foreignExporterCountryCode: 'DE',
    address: 'Industriestrasse 42, 70565 Stuttgart, Germany',
    phone: '+49 711 123456',
    mobile: '+49 170 9876543',
    email: 'export@global-corp.de',
    website: 'https://www.global-corp.de',
    bankName: 'Deutsche Bank AG',
    swiftCode: 'DEUTDEDDXXX',
    accountNumber: '1234567890',
    iban: 'DE89370400440532013000',
    hasIso: true,
    registeredDecree43: true,
    whiteListRegistered: true,
    brands: 'PowerTools, ProMachinery',
    notes: 'مورد معتمد مسجل في القائمة البيضاء بالهيئة العامة للرقابة على الصادرات والواردات (GOEIC) بموجب القرار 43.',
    isActive: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Modal Dialog: SupplierDetailsDialog Performance Diagnostics', () {
    testWidgets('Measure Dimension A and Dimension B across 3 runs', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<int> navInFirstFrameTimes = [];
      final List<int> navInSettledTimes = [];
      final List<int> navOutTimes = [];

      final mockSupplier = _createMockSupplier();

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
                child: SupplierDetailsDialog(supplier: mockSupplier),
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
                  child: SupplierDetailsDialog(supplier: mockSupplier),
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
      debugPrint('MODAL (SupplierDetailsDialog) BENCHMARK RESULTS:');
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
