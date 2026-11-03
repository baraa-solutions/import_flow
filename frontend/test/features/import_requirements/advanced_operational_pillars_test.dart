import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/import_requirements/widgets/advanced/advanced_pillars.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('ar'),
    localizationsDelegates: AppLocales.localizationsDelegates,
    supportedLocales: AppLocales.supportedLocales,
    home: AppLocalizationsProvider(
      locale: const Locale('ar'),
      child: Scaffold(
        body: SingleChildScrollView(
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('Session 3: Advanced Operational Pillars Cards Tests', () {
    testWidgets('1. CargoXPreAcidCheckCard renders, has SelectionArea, and toggles data', (tester) async {
      CargoXPreAcidData? receivedData;

      await tester.pumpWidget(
        _buildTestApp(
          CargoXPreAcidCheckCard(
            supplierName: 'Suzhou Petrochem Corp',
            supplierCountry: 'China',
            initialCargoxId: 'CX-99201-EX',
            initialStatus: 'PENDING',
            onChanged: (data) => receivedData = data,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify SelectionArea exists
      expect(find.byType(SelectionArea), findsWidgets);

      // Verify Supplier information
      expect(find.textContaining('Suzhou Petrochem Corp'), findsOneWidget);

      // Verify Initial CargoX ID
      expect(find.text('CX-99201-EX'), findsOneWidget);

      // Verify Warning is present for unverified supplier
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      // Verify Copy Button exists
      final copyBtn = find.byTooltip('نسخ معرف منصة كارجو إكس');
      expect(copyBtn, findsOneWidget);

      // Tap verify checkbox to trigger callback
      final checkboxes = find.byType(Checkbox);
      if (checkboxes.evaluate().isNotEmpty) {
        await tester.tap(checkboxes.first);
        await tester.pumpAndSettle();
        expect(receivedData, isNotNull);
      }
    });

    testWidgets('2. ShelfLifeEosInspectionCard calculates remaining shelf life percentage', (tester) async {
      ShelfLifeEosData? lastData;

      final now = DateTime(2026, 6, 1);
      final prodDate = now.subtract(const Duration(days: 100));
      final expDate = now.add(const Duration(days: 120)); // > 50%
      final etaDate = now;

      await tester.pumpWidget(
        _buildTestApp(
          ShelfLifeEosInspectionCard(
            initialSubjectToShelfLife: true,
            initialEosSpecNumber: 'EOS 2613',
            initialProductionDate: prodDate,
            initialExpiryDate: expDate,
            initialEtaDate: etaDate,
            initialBatchNumber: 'LOT-2026-X1',
            initialArabicLabelingCompliant: true,
            onChanged: (data) => lastData = data,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SelectionArea is present
      expect(find.byType(SelectionArea), findsWidgets);

      // Verify EOS Spec text
      expect(find.text('EOS 2613'), findsOneWidget);

      // Verify Batch text
      expect(find.text('LOT-2026-X1'), findsOneWidget);

      // Verify percentage is displayed
      expect(find.textContaining('%'), findsOneWidget);

      // Verify compliant badge is displayed
      expect(find.text('مستوفٍ لنسبة الصلاحية القانونية'), findsOneWidget);

      // Tap arabic labeling checkbox to trigger callback
      final checkboxes = find.byType(Checkbox);
      if (checkboxes.evaluate().isNotEmpty) {
        await tester.tap(checkboxes.last);
        await tester.pumpAndSettle();
        expect(lastData, isNotNull);
      }
    });

    testWidgets('3. TestingLaboratoriesTrackCard handles lab test protocols and under-bond release', (tester) async {
      TestingLabTrackData? trackData;

      await tester.pumpWidget(
        _buildTestApp(
          TestingLaboratoriesTrackCard(
            initialLaboratory: 'GOEIC_LAB',
            initialSamplingRecordNo: 'SMP-2026-8812',
            initialSamplesCount: 3,
            initialLabFees: 4500.0,
            initialTestResult: 'CONFORMING',
            initialUnderBondRelease: true,
            onChanged: (data) => trackData = data,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SelectionArea is present
      expect(find.byType(SelectionArea), findsWidgets);

      // Verify Sampling record number
      expect(find.text('SMP-2026-8812'), findsOneWidget);

      // Verify fees
      expect(find.text('4500.00'), findsOneWidget);

      // Verify Conforming badge
      expect(find.text('مطابق للمواصفات القياسية'), findsWidgets);

      // Tap under-bond release checkbox to trigger callback
      final checkbox = find.byType(Checkbox);
      if (checkbox.evaluate().isNotEmpty) {
        await tester.tap(checkbox.first);
        await tester.pumpAndSettle();
        expect(trackData, isNotNull);
      }
    });

    testWidgets('4. HazardousMaterialsCard displays IMDG class and emergency handling warning', (tester) async {
      HazardousMaterialsData? hazData;

      await tester.pumpWidget(
        _buildTestApp(
          HazardousMaterialsCard(
            initialIsHazardous: true,
            initialUnNumber: 'UN 1993',
            initialImdgClass: 'CLASS_3',
            initialFlashPoint: 23.5,
            initialCivilProtectionNo: 'CP-FIRE-990',
            initialPortHandlingMode: 'DIRECT_DISCHARGE',
            onChanged: (data) => hazData = data,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SelectionArea is present
      expect(find.byType(SelectionArea), findsWidgets);

      // Verify UN number
      expect(find.text('UN 1993'), findsOneWidget);

      // Verify Civil Protection No
      expect(find.text('CP-FIRE-990'), findsOneWidget);

      // Verify High Risk Alert is displayed
      expect(find.byIcon(Icons.report_problem_outlined), findsOneWidget);

      // Tap hazardous checkbox to trigger callback
      final checkbox = find.byType(Checkbox);
      if (checkbox.evaluate().isNotEmpty) {
        await tester.tap(checkbox.first);
        await tester.pumpAndSettle();
        expect(hazData, isNotNull);
      }
    });
  });
}
