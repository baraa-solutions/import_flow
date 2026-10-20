import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/financial_settlement/services/landed_cost_comparison_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Screen 50: Landed Cost Comparison Localization Tests', () {
    const ar = AppLocalizationsAr();
    const en = AppLocalizationsEn();

    test('All Screen 50 getters should return non-empty strings in Arabic and English', () {
      final gettersAr = [
        ar.landedCostExportTsvBtn,
        ar.landedCostExportExcelBtn,
        ar.landedCostPrintPdfBtn,
        ar.landedCostCopyDossierBtn,
        ar.landedCostCopyDossierSuccess,
        ar.landedCostDossierHeader,
        ar.landedCostExportTsvDialogTitle,
        ar.landedCostExportExcelDialogTitle,
        ar.incoRuleExporterCoversLabel,
        ar.incoRuleImporterCoversLabel,
        ar.incoCifRuleTitle,
        ar.incoCifRuleDesc,
        ar.incoCifExporterCovers,
        ar.incoCifImporterCovers,
        ar.incoCfrRuleTitle,
        ar.incoCfrRuleDesc,
        ar.incoCfrExporterCovers,
        ar.incoCfrImporterCovers,
        ar.incoExwRuleTitle,
        ar.incoExwRuleDesc,
        ar.incoExwExporterCovers,
        ar.incoExwImporterCovers,
        ar.incoDdpRuleTitle,
        ar.incoDdpRuleDesc,
        ar.incoDdpExporterCovers,
        ar.incoDdpImporterCovers,
        ar.incoFobRuleTitle,
        ar.incoFobRuleDesc,
        ar.incoFobExporterCovers,
        ar.incoFobImporterCovers,
        ar.landedCostTsvHeaderSection,
        ar.landedCostTsvHeaderCodeOrCategory,
        ar.landedCostTsvHeaderNameOrProvider,
        ar.landedCostTsvHeaderQtyOrCurrency,
        ar.landedCostTsvHeaderUnitPriceOrFx,
        ar.landedCostTsvHeaderExchangeRate,
        ar.landedCostTsvHeaderTotalCostEgp,
        ar.landedCostTsvHeaderMarkupOrVariance,
        ar.noLandedCostDataRegistered,
        ar.expenseBreakdownHeader,
        ar.itemLandedCostHeader,
        ar.estimatedCostHeader,
        ar.actualCostHeader,
        ar.fobValueCardTitle,
        ar.totalExpensesCardTitle,
        ar.totalLandedCostCardTitle,
        ar.estAbbreviation,
        ar.actAbbreviation,
        ar.colExpenseCategory,
        ar.colExpenseProvider,
        ar.colExpenseCurrency,
        ar.colExpenseAmountFx,
        ar.colExpenseExchangeRate,
        ar.colExpenseAmountEgp,
        ar.colItemCode,
        ar.colItemName,
        ar.colItemQty,
        ar.colFobUnitPrice,
        ar.colLandedUnitPrice,
        ar.colCostMarkupFactor,
      ];

      final gettersEn = [
        en.landedCostExportTsvBtn,
        en.landedCostExportExcelBtn,
        en.landedCostPrintPdfBtn,
        en.landedCostCopyDossierBtn,
        en.landedCostCopyDossierSuccess,
        en.landedCostDossierHeader,
        en.landedCostExportTsvDialogTitle,
        en.landedCostExportExcelDialogTitle,
        en.incoRuleExporterCoversLabel,
        en.incoRuleImporterCoversLabel,
        en.incoCifRuleTitle,
        en.incoCifRuleDesc,
        en.incoCifExporterCovers,
        en.incoCifImporterCovers,
        en.incoCfrRuleTitle,
        en.incoCfrRuleDesc,
        en.incoCfrExporterCovers,
        en.incoCfrImporterCovers,
        en.incoExwRuleTitle,
        en.incoExwRuleDesc,
        en.incoExwExporterCovers,
        en.incoExwImporterCovers,
        en.incoDdpRuleTitle,
        en.incoDdpRuleDesc,
        en.incoDdpExporterCovers,
        en.incoDdpImporterCovers,
        en.incoFobRuleTitle,
        en.incoFobRuleDesc,
        en.incoFobExporterCovers,
        en.incoFobImporterCovers,
        en.landedCostTsvHeaderSection,
        en.landedCostTsvHeaderCodeOrCategory,
        en.landedCostTsvHeaderNameOrProvider,
        en.landedCostTsvHeaderQtyOrCurrency,
        en.landedCostTsvHeaderUnitPriceOrFx,
        en.landedCostTsvHeaderExchangeRate,
        en.landedCostTsvHeaderTotalCostEgp,
        en.landedCostTsvHeaderMarkupOrVariance,
        en.noLandedCostDataRegistered,
        en.expenseBreakdownHeader,
        en.itemLandedCostHeader,
        en.estimatedCostHeader,
        en.actualCostHeader,
        en.fobValueCardTitle,
        en.totalExpensesCardTitle,
        en.totalLandedCostCardTitle,
        en.estAbbreviation,
        en.actAbbreviation,
        en.colExpenseCategory,
        en.colExpenseProvider,
        en.colExpenseCurrency,
        en.colExpenseAmountFx,
        en.colExpenseExchangeRate,
        en.colExpenseAmountEgp,
        en.colItemCode,
        en.colItemName,
        en.colItemQty,
        en.colFobUnitPrice,
        en.colLandedUnitPrice,
        en.colCostMarkupFactor,
      ];

      for (final val in gettersAr) {
        expect(val, isNotEmpty);
      }
      for (final val in gettersEn) {
        expect(val, isNotEmpty);
      }
    });

    test('Zero Latin characters rule: Arabic strings must contain ZERO [a-zA-Z]', () {
      final latinPattern = RegExp(r'[a-zA-Z]');

      final arabicStrings = [
        ar.landedCostExportTsvBtn,
        ar.landedCostExportExcelBtn,
        ar.landedCostPrintPdfBtn,
        ar.landedCostCopyDossierBtn,
        ar.landedCostCopyDossierSuccess,
        ar.landedCostDossierHeader,
        ar.landedCostExportTsvDialogTitle,
        ar.landedCostExportExcelDialogTitle,
        ar.incoRuleExporterCoversLabel,
        ar.incoRuleImporterCoversLabel,
        ar.incoCifRuleTitle,
        ar.incoCifRuleDesc,
        ar.incoCifExporterCovers,
        ar.incoCifImporterCovers,
        ar.incoCfrRuleTitle,
        ar.incoCfrRuleDesc,
        ar.incoCfrExporterCovers,
        ar.incoCfrImporterCovers,
        ar.incoExwRuleTitle,
        ar.incoExwRuleDesc,
        ar.incoExwExporterCovers,
        ar.incoExwImporterCovers,
        ar.incoDdpRuleTitle,
        ar.incoDdpRuleDesc,
        ar.incoDdpExporterCovers,
        ar.incoDdpImporterCovers,
        ar.incoFobRuleTitle,
        ar.incoFobRuleDesc,
        ar.incoFobExporterCovers,
        ar.incoFobImporterCovers,
        ar.landedCostTsvHeaderSection,
        ar.landedCostTsvHeaderCodeOrCategory,
        ar.landedCostTsvHeaderNameOrProvider,
        ar.landedCostTsvHeaderQtyOrCurrency,
        ar.landedCostTsvHeaderUnitPriceOrFx,
        ar.landedCostTsvHeaderExchangeRate,
        ar.landedCostTsvHeaderTotalCostEgp,
        ar.landedCostTsvHeaderMarkupOrVariance,
        ar.noLandedCostDataRegistered,
        ar.expenseBreakdownHeader,
        ar.itemLandedCostHeader,
        ar.estimatedCostHeader,
        ar.actualCostHeader,
        ar.fobValueCardTitle,
        ar.totalExpensesCardTitle,
        ar.totalLandedCostCardTitle,
        ar.estAbbreviation,
        ar.actAbbreviation,
        ar.colExpenseCategory,
        ar.colExpenseProvider,
        ar.colExpenseCurrency,
        ar.colExpenseAmountFx,
        ar.colExpenseExchangeRate,
        ar.colExpenseAmountEgp,
        ar.colItemCode,
        ar.colItemName,
        ar.colItemQty,
        ar.colFobUnitPrice,
        ar.colLandedUnitPrice,
        ar.colCostMarkupFactor,
      ];

      for (final str in arabicStrings) {
        expect(
          latinPattern.hasMatch(str),
          isFalse,
          reason: 'String "$str" contains Latin characters, violating zero-Latin rule',
        );
      }
    });

    test('Zero bilingual slash rule: Arabic strings must contain ZERO slashes [/]', () {
      final arabicStrings = [
        ar.landedCostExportTsvBtn,
        ar.landedCostExportExcelBtn,
        ar.landedCostPrintPdfBtn,
        ar.landedCostCopyDossierBtn,
        ar.landedCostCopyDossierSuccess,
        ar.landedCostDossierHeader,
        ar.landedCostExportTsvDialogTitle,
        ar.landedCostExportExcelDialogTitle,
        ar.incoRuleExporterCoversLabel,
        ar.incoRuleImporterCoversLabel,
        ar.incoCifRuleTitle,
        ar.incoCifRuleDesc,
        ar.incoCifExporterCovers,
        ar.incoCifImporterCovers,
        ar.incoCfrRuleTitle,
        ar.incoCfrRuleDesc,
        ar.incoCfrExporterCovers,
        ar.incoCfrImporterCovers,
        ar.incoExwRuleTitle,
        ar.incoExwRuleDesc,
        ar.incoExwExporterCovers,
        ar.incoExwImporterCovers,
        ar.incoDdpRuleTitle,
        ar.incoDdpRuleDesc,
        ar.incoDdpExporterCovers,
        ar.incoDdpImporterCovers,
        ar.incoFobRuleTitle,
        ar.incoFobRuleDesc,
        ar.incoFobExporterCovers,
        ar.incoFobImporterCovers,
        ar.landedCostTsvHeaderSection,
        ar.landedCostTsvHeaderCodeOrCategory,
        ar.landedCostTsvHeaderNameOrProvider,
        ar.landedCostTsvHeaderQtyOrCurrency,
        ar.landedCostTsvHeaderUnitPriceOrFx,
        ar.landedCostTsvHeaderExchangeRate,
        ar.landedCostTsvHeaderTotalCostEgp,
        ar.landedCostTsvHeaderMarkupOrVariance,
        ar.colExpenseProvider,
      ];

      for (final str in arabicStrings) {
        expect(
          str.contains('/'),
          isFalse,
          reason: 'String "$str" contains bilingual slash [/]',
        );
      }
    });

    testWidgets('LandedCostComparisonExportService buildDossierText builds structured dossier', (tester) async {
      late BuildContext testContext;

      await tester.pumpWidget(
        MaterialApp(
          home: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Builder(
                builder: (ctx) {
                  testContext = ctx;
                  return const Scaffold(body: Text('OK'));
                },
              ),
            ),
          ),
        ),
      );

      final service = LandedCostComparisonExportService(
        context: testContext,
        fileCode: 'IMP-2026-001',
        incoterm: 'FOB',
        estimatedCost: 500000.0,
        settlementRecord: {
          'total_fob_egp': 480000.0,
          'total_expenses_egp': 65000.0,
          'total_landed_cost_egp': 545000.0,
          'expense_invoices': [
            {
              'category': 'freight',
              'provider_name': 'Maersk Line',
              'currency': 'USD',
              'amount_fx': 1200.0,
              'exchange_rate': 50.0,
              'amount_egp': 60000.0,
            }
          ],
          'item_landed_costs': [
            {
              'item_code': 'RAW-001',
              'item_name': 'Industrial Steel Bars',
              'qty': 100,
              'fob_unit_egp': 4800.0,
              'unit_landed_cost_egp': 5450.0,
              'markup_factor': 1.135,
            }
          ],
        },
      );

      final dossier = service.buildDossierText();
      expect(dossier, contains('IMP-2026-001'));
      expect(dossier, contains('FOB'));
      expect(dossier, contains('545000.00 EGP'));
      expect(dossier, contains('Maersk Line'));
      expect(dossier, contains('RAW-001'));
    });
  });
}
