import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/universal_entity_extractor_dialog.dart';

void main() {
  group('UniversalEntityExtractorDialog Tests', () {
    test('EntityTarget enum covers all logistics parties', () {
      expect(EntityTarget.values.length, 10);
      expect(EntityTarget.values, contains(EntityTarget.supplier));
      expect(EntityTarget.values, contains(EntityTarget.company));
      expect(EntityTarget.values, contains(EntityTarget.customsBroker));
      expect(EntityTarget.values, contains(EntityTarget.shippingLine));
      expect(EntityTarget.values, contains(EntityTarget.freightForwarder));
      expect(EntityTarget.values, contains(EntityTarget.inlandTransport));
      expect(EntityTarget.values, contains(EntityTarget.inspectionAgency));
      expect(EntityTarget.values, contains(EntityTarget.insuranceCompany));
      expect(EntityTarget.values, contains(EntityTarget.bank));
      expect(EntityTarget.values, contains(EntityTarget.partner));
    });

    testWidgets(
        'renders dialog with SelectionArea and pure localized Arabic strings',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: UniversalEntityExtractorDialog(
                    initialTarget: EntityTarget.supplier,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Verify SelectionArea exists
      expect(find.byType(SelectionArea), findsOneWidget);

      // Verify Target selector button is rendered
      expect(find.text('مورد أجنبي'), findsOneWidget);

      // Verify tabs are rendered without slashes
      expect(find.text('لصق نص حر'), findsOneWidget);
      expect(find.text('مستند أو صورة أو ملف'), findsOneWidget);

      // Verify title containing target name
      expect(find.textContaining('المورد الأجنبي'), findsWidgets);
    });

    testWidgets('renders dialog with English strings when in LTR mode',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('en'),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Scaffold(
                  body: UniversalEntityExtractorDialog(
                    initialTarget: EntityTarget.company,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.text('Paste Free Text'), findsOneWidget);
      expect(find.text('Document or Image File'), findsOneWidget);
      expect(find.textContaining('Importing Company'), findsWidgets);
    });
  });
}
