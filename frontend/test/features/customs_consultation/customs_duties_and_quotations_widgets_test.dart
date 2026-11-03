import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/customs_clearance_quotations/models/customs_clearance_quotation_model.dart';
import 'package:frontend/features/customs_consultation/models/customs_consultation_model.dart';
import 'package:frontend/features/customs_consultation/widgets/widgets.dart';

import '../../helpers/localized_app.dart';

Widget wrapWithLocalization(Widget child, [Locale locale = AppLocales.arabic]) {
  return localizedApp(
    locale: locale,
    home: Scaffold(body: child),
  );
}

void main() {
  group('BrokerQuotationComparisonTable Tests', () {
    final sampleQuote1 = CustomsClearanceQuotationItemModel(
      quotationId: 101,
      providerId: 1,
      providerName: 'مكتب الأهرام للتخليص الجمركي',
      licenseNumber: 'LIC-1001',
      clearanceFee: 3000.0,
      inlandTransportFee: 2000.0,
      inspectionFee: 500.0,
      portExpenses: 1500.0,
      miscellaneousFee: 200.0,
      totalCost: 7200.0,
      currency: 'EGP',
      estimatedTurnaroundDays: 4,
      isAwarded: false,
    );

    final sampleQuote2 = CustomsClearanceQuotationItemModel(
      quotationId: 102,
      providerId: 2,
      providerName: 'شركة النيل للخدمات اللوجستية',
      licenseNumber: 'LIC-2002',
      clearanceFee: 2500.0,
      inlandTransportFee: 1800.0,
      inspectionFee: 400.0,
      portExpenses: 1200.0,
      miscellaneousFee: 100.0,
      totalCost: 6000.0,
      currency: 'EGP',
      estimatedTurnaroundDays: 2,
      isAwarded: true,
    );

    testWidgets('Renders empty state when quotations list is empty', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(wrapWithLocalization(
        const BrokerQuotationComparisonTable(quotations: []),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(BrokerQuotationComparisonTable), findsOneWidget);
      expect(find.byType(SelectionArea), findsWidgets);
    });

    testWidgets('Renders comparison KPIs and quotes correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      int? awardedId;

      await tester.pumpWidget(wrapWithLocalization(
        BrokerQuotationComparisonTable(
          quotations: [sampleQuote1, sampleQuote2],
          rfqTitle: 'مناقصة شحنة قطع الغيار - ميناء الإسكندرية',
          onAward: (id) => awardedId = id,
        ),
      ));
      await tester.pumpAndSettle();

      // Check broker names are displayed
      expect(find.text('مكتب الأهرام للتخليص الجمركي'), findsOneWidget);
      expect(find.text('شركة النيل للخدمات اللوجستية'), findsWidgets);

      // Verify Award button or badge
      expect(find.byType(SelectionArea), findsWidgets);

      // Tap on non-awarded quote's award button
      final awardButtons = find.widgetWithText(ElevatedButton, 'ترسية واعتماد');
      if (awardButtons.evaluate().isNotEmpty) {
        await tester.tap(awardButtons.first);
        await tester.pumpAndSettle();
        expect(awardedId, 101);
      }
    });

    testWidgets('Filters quotations by search query', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(wrapWithLocalization(
        BrokerQuotationComparisonTable(
          quotations: [sampleQuote1, sampleQuote2],
        ),
      ));
      await tester.pumpAndSettle();

      // Find text field and search
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'النيل');
      await tester.pumpAndSettle();

      expect(find.text('شركة النيل للخدمات اللوجستية'), findsWidgets);
      expect(find.text('مكتب الأهرام للتخليص الجمركي'), findsNothing);
    });
  });

  group('CustomsDutiesCalculatorTab Tests', () {
    testWidgets('Renders calculation engine header, FX rate, and CIF declared base', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      final exchangeRateCtrl = TextEditingController(text: '48.50');
      final freightForeignCtrl = TextEditingController(text: '1200.00');
      final freightFxCtrl = TextEditingController(text: '48.50');
      final freightEgpCtrl = TextEditingController(text: '58200.00');
      final insuranceEgpCtrl = TextEditingController(text: '2500.00');

      final sampleCalcLine = CustomsItemCalcRow(
        hsCode: '8471.30.00',
        description: 'أجهزة حاسب آلي محمول',
        qty: 10,
        unit: 'PCS',
        foreignPrice: 5000.0,
        fobEgp: 242500.0,
        freightEgp: 5820.0,
        insuranceEgp: 1250.0,
        cifEgp: 250000.0,
        dutyRate: 5.0,
        baseDutyRate: 5.0,
        dutyAmountEgp: 12500.0,
        vatRate: 14.0,
        vatBaseEgp: 262500.0,
        vatAmountEgp: 36750.0,
        scheduleTaxRate: 0.0,
        scheduleTaxAmountEgp: 0.0,
        developmentFeeRate: 0.0,
        developmentFeeAmountEgp: 0.0,
        customsServiceFeeRate: 0.0,
        customsServiceFeeAmountEgp: 0.0,
        totalTaxesAndDutiesEgp: 49250.0,
        requiresCoo: false,
        requiresInspection: false,
        requiresAcid: true,
        status: 'CALCULATED',
      );

      await tester.pumpWidget(wrapWithLocalization(
        SingleChildScrollView(
          child: CustomsDutiesCalculatorTab(
            isTaxReviewMode: false,
            customsCurrency: 'USD',
            onCustomsCurrencyChanged: (_) {},
            exchangeRateController: exchangeRateCtrl,
            onExchangeRateChanged: () {},
            studyDate: DateTime(2026, 10, 29),
            onStudyDateChanged: (_) {},
            currenciesList: [
              CurrencyModel(
                currencyId: 1,
                currencyCode: 'USD',
                currencyName: 'US Dollar',
                currencySymbol: '\$',
                isActive: true,
              ),
            ],
            freightForeignController: freightForeignCtrl,
            freightCurrency: 'USD',
            onFreightCurrencyChanged: (_) {},
            freightExchangeRateController: freightFxCtrl,
            freightEgpController: freightEgpCtrl,
            onRecalculateFreightEgp: () {},
            insuranceOption: '0.5%',
            onInsuranceOptionChanged: (_) {},
            insuranceEgpController: insuranceEgpCtrl,
            totalFobForeign: 5000.0,
            totalFobEgp: 242500.0,
            totalCandFEgp: 300700.0,
            totalFreightEgp: 58200.0,
            totalInsuranceEgp: 2500.0,
            totalCifEgp: 303200.0,
            totalCifForeign: 6251.55,
            exchangeRate: 48.50,
            calcLines: [sampleCalcLine],
            groupByHsCode: false,
            onGroupByHsCodeChanged: (_) {},
            hasInvoicesWithoutPoLines: false,
            isCustomsCalculatorExpanded: true,
            onToggleCustomsCalculatorExpanded: () {},
            onSyncHsRequirementsToChecklist: () {},
            totalDutyEgp: 12500.0,
            totalVatEgp: 36750.0,
            totalTaxesAndDutiesEgp: 49250.0,
            onApplyAndLinkFinancialEstimate: () {},
            selectedBrokerName: 'مكتب الأهرام',
            title: 'دراسة جمركية تجريبية',
            checklist: const [],
            brokerQuoteItems: const [],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CustomsDutiesCalculatorTab), findsOneWidget);
      expect(find.byType(SelectionArea), findsWidgets);
      expect(find.text('8471.30.00'), findsOneWidget);
    });
  });
}
