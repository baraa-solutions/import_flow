import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/widgets/smart_upload_button.dart';
import 'package:frontend/features/import_documentation/services/customs_declaration46_calculator.dart';
import 'package:frontend/features/import_documentation/widgets/form46_three_column_panel.dart';
import 'package:frontend/features/import_documentation/widgets/form46_variance_bar.dart';

Widget _wrapWithLocalizations(Widget child) {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      _TestLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

class _TestLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _TestLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) async => const AppLocalizationsAr();

  @override
  bool shouldReload(_TestLocalizationsDelegate old) => false;
}

void main() {
  group('Form46VarianceResult — Mathematical & Threshold Calculations', () {
    test('Calculates compliant status for variance < 2%', () {
      final res = Form46VarianceResult.compute(100000.0, 101500.0);
      expect(res.diffAmount, 1500.0);
      expect(res.diffPercentage, closeTo(1.5, 0.001));
      expect(res.severity, Form46VarianceSeverity.compliant);
    });

    test('Calculates moderate status for variance between 2% and 10%', () {
      final res = Form46VarianceResult.compute(100000.0, 106500.0);
      expect(res.diffAmount, 6500.0);
      expect(res.diffPercentage, closeTo(6.5, 0.001));
      expect(res.severity, Form46VarianceSeverity.moderate);
    });

    test('Calculates high status for variance > 10%', () {
      final res = Form46VarianceResult.compute(100000.0, 114000.0);
      expect(res.diffAmount, 14000.0);
      expect(res.diffPercentage, closeTo(14.0, 0.001));
      expect(res.severity, Form46VarianceSeverity.high);
    });

    test('Handles negative variance exceeding 10%', () {
      final res = Form46VarianceResult.compute(100000.0, 85000.0);
      expect(res.diffAmount, -15000.0);
      expect(res.diffPercentage, closeTo(-15.0, 0.001));
      expect(res.severity, Form46VarianceSeverity.high);
    });

    test('Gracefully handles null baseline or compared value', () {
      final res = Form46VarianceResult.compute(null, 100000.0);
      expect(res.diffAmount, isNull);
      expect(res.diffPercentage, isNull);
      expect(res.severity, Form46VarianceSeverity.compliant);
    });
  });

  group('Form46VarianceBar — UI Rendering', () {
    testWidgets('Renders all three variance comparison cards', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _wrapWithLocalizations(
          const SingleChildScrollView(
            child: Form46VarianceBar(
              studyTotal: 100000.0,
              revisedTotal: 105000.0,
              actualTotal: 115000.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bar header
      expect(find.text('مؤشرات وفروقات التقييم الجمركي'), findsOneWidget);
      // Three cards: B vs A, C vs A, C vs B
      expect(find.text('المحدث مقابل التقديري'), findsOneWidget);
      expect(find.text('الفعلي مقابل التقديري'), findsOneWidget);
      expect(find.text('الفعلي مقابل المحدث'), findsOneWidget);

      // Verify SelectionArea exists
      expect(find.byType(SelectionArea), findsOneWidget);
    });
  });

  group('Form46ThreeColumnPanel — UI & Callback Interactions', () {
    testWidgets('Renders three columns with input fields and callbacks', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final revisedFxCtrl = TextEditingController(text: '48.50');
      final freightCtrl = TextEditingController(text: '50000');
      final insuranceCtrl = TextEditingController(text: '5000');
      final dischargeCtrl = TextEditingController(text: '2000');
      final newFeesCtrl = TextEditingController(text: '1000');
      final revCifCtrl = TextEditingController(text: '500000');
      final revDutyCtrl = TextEditingController(text: '50000');
      final revVatCtrl = TextEditingController(text: '77000');
      final revOtherCtrl = TextEditingController(text: '15000');
      final revTotalCtrl = TextEditingController(text: '142000');

      final actCifCtrl = TextEditingController(text: '520000');
      final actDutyCtrl = TextEditingController(text: '52000');
      final actVatCtrl = TextEditingController(text: '80000');
      final actOtherCtrl = TextEditingController(text: '16000');
      final actTotalCtrl = TextEditingController(text: '148000');
      final claimNoCtrl = TextEditingController(text: 'CLM-2026-99');
      final claimDateCtrl = TextEditingController(text: '2026-11-01');

      bool revisedChanged = false;
      bool actualChanged = false;

      const studyFigures = Form46Figures(
        fobForeign: 10000,
        exchangeRate: 48.0,
        fobEgp: 480000,
        cifEgp: 480000,
        dutyRate: 10.0,
        importDutyEgp: 48000,
        vatRate: 14.0,
        vatEgp: 73920,
        otherFeesEgp: 10000,
        totalDutiesEgp: 131920,
      );

      await tester.pumpWidget(
        _wrapWithLocalizations(
          SingleChildScrollView(
            child: Form46ThreeColumnPanel(
              studyFigures: studyFigures,
              appliedTariff: null,
              revisedFxRateCtrl: revisedFxCtrl,
              approvedFreightCtrl: freightCtrl,
              actualInsuranceCtrl: insuranceCtrl,
              dischargeExpensesCtrl: dischargeCtrl,
              newCustomsFeesCtrl: newFeesCtrl,
              revisedCifCtrl: revCifCtrl,
              revisedDutyCtrl: revDutyCtrl,
              revisedVatCtrl: revVatCtrl,
              revisedOtherFeesCtrl: revOtherCtrl,
              revisedTotalDutiesCtrl: revTotalCtrl,
              onRevisedVariableChanged: () => revisedChanged = true,
              actualCifCtrl: actCifCtrl,
              actualDutyCtrl: actDutyCtrl,
              actualVatCtrl: actVatCtrl,
              actualOtherFeesCtrl: actOtherCtrl,
              actualTotalDutiesCtrl: actTotalCtrl,
              nafezaClaimNoCtrl: claimNoCtrl,
              nafezaClaimDateCtrl: claimDateCtrl,
              onActualComponentChanged: () => actualChanged = true,
              onNafezaDataExtracted: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check column headers
      expect(find.text('التقدير المبدئي للدراسة'), findsOneWidget);
      expect(find.text('التقدير التقريبي المحدّث'), findsOneWidget);
      expect(find.text('الفعلي من منظومة نافذة'), findsOneWidget);

      // Check smart extract button exists
      expect(find.byType(SmartUploadButton), findsOneWidget);

      // Edit a revised input
      await tester.enterText(find.byKey(const Key('form46RevisedFxRateField')), '49.00');
      expect(revisedChanged, isTrue);

      // Edit an actual input
      await tester.enterText(find.byKey(const Key('form46ActualDutyField')), '55000');
      expect(actualChanged, isTrue);

      // Check SelectionArea is wrapping panel
      expect(find.byType(SelectionArea), findsOneWidget);
    });
  });
}
