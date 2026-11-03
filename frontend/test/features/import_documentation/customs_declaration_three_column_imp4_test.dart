import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/customs_tariff/models/customs_tariff_model.dart';
import 'package:frontend/features/freight_booking/models/freight_booking_model.dart';
import 'package:frontend/features/import_documentation/models/customs_declaration_assessment.dart';
import 'package:frontend/features/import_documentation/services/customs_declaration46_calculator.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';

CustomsTariffModel _petTariff() {
  return CustomsTariffModel.fromJson({
    'tariff_id': 55,
    'hs_code': '5602.29.00',
    'hs_description': 'لباد آخر ، غير مشرب ولامطلي ولامغطي ولا منضد ، من مواد نسجية أخر.',
    'customs_duty_rate': 5.0,
    'vat_rate': 14.0,
    'schedule_tax_rate': 0.0,
    'development_fee_rate': 0.0,
    'import_fee_rate': 0.0,
    'customs_service_fee_rate': 1.0,
    'effective_from': '2026-01-01',
    'is_active': true,
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
  });
}

ShipmentBookingModel _mockBooking({
  int bookingId = 1,
  int importFileId = 4,
  double totalFreightCostUsd = 7750.0,
}) {
  return ShipmentBookingModel(
    bookingId: bookingId,
    bookingCode: 'BKG-2026-0001',
    bookingConfirmationNo: 'THXJ2608090',
    importFileId: importFileId,
    totalFreightCostUsd: totalFreightCostUsd,
    originalFreightCostUsd: 8280.0,
    costSavingsUsd: 530.0,
    costVarianceUsd: 530.0,
    status: 'Confirmed',
    owner: 'AI_Agent',
    isActive: true,
    createdAt: '2026-09-06T00:00:00Z',
    updatedAt: '2026-10-14T00:00:00Z',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Form46Calculator.calculateRevisedFigures — Mathematical Precision for Shipment IMP-4', () {
    test('Calculates Revised Figures for IMP-4 with exact penny precision (EXW/FOB 43,704 USD, Freight 7,750 USD, FX 48.70)', () {
      final booking = _mockBooking();
      final tariff = _petTariff();

      final revised = Form46Calculator.calculateRevisedFigures(
        fobUsd: 43704.0,
        exchangeRate: 48.70,
        booking: booking,
        tariff: tariff,
        estimateDate: '2026-10-20',
        notes: 'IMP-4 Wan Hai Lines execution',
      );

      expect(revised.isComplete, isTrue);
      expect(revised.missing, isEmpty);

      // 1. Freight & FOB in EGP
      // FOB EGP = 43,704 * 48.70 = 2,128,384.80
      expect(revised.fobEgp, 2128384.80);
      // Freight EGP = 7,750 * 48.70 = 377,425.00
      expect(revised.freightUsd, 7750.0);
      expect(revised.freightEgp, 377425.00);

      // 2. Revised CIF EGP
      // Revised_CIF = (FOB USD + Booking Freight USD) * Exchange Rate + Insurance EGP + Unloading EGP
      // (43,704 + 7,750) * 48.70 = 51,454 * 48.70 = 2,505,809.80 EGP
      expect(revised.cifEgp, 2505809.80);

      // 3. Import Duty (5%)
      // 2,505,809.80 * 0.05 = 125,290.49 EGP
      expect(revised.importDutyEgp, 125290.49);

      // 4. أ.ت.ص (1%)
      // 2,505,809.80 * 0.01 = 25,058.10 EGP
      expect(revised.atsEgp, 25058.10);
      expect(revised.devFeeEgp, 25058.10);

      // 5. VAT Base & VAT (14%)
      // VAT Base = CIF + Import Duty + أ.ت.ص
      // 2,505,809.80 + 125,290.49 + 25,058.10 = 2,656,158.39 EGP
      expect(revised.vatBaseEgp, 2656158.39);
      // VAT = 2,656,158.39 * 0.14 = 371,862.1746 -> 371,862.17 EGP
      expect(revised.vatEgp, 371862.17);

      // 6. Total Duties EGP
      // 125,290.49 + 371,862.17 + 25,058.10 = 522,210.76 EGP
      expect(revised.totalDutiesEgp, 522210.76);
    });

    test('Calculates Revised Figures with explicit insurance, unloading, and extra fees', () {
      final tariff = _petTariff();

      final revised = Form46Calculator.calculateRevisedFigures(
        fobUsd: 43704.0,
        exchangeRate: 48.70,
        bookingFreightUsd: 7750.0,
        insuranceEgp: 1500.50,
        unloadingEgp: 2000.00,
        extraFeesEgp: 500.00,
        tariff: tariff,
      );

      // Revised_CIF = (43,704 + 7,750) * 48.70 + 1500.50 + 2000.00 = 2,505,809.80 + 3500.50 = 2,509,310.30
      expect(revised.cifEgp, 2509310.30);

      // Duty (5%) = 2,509,310.30 * 0.05 = 125,465.515 -> 125,465.52
      expect(revised.importDutyEgp, 125465.52);

      // أ.ت.ص (1%) = 2,509,310.30 * 0.01 = 25,093.103 -> 25,093.10
      expect(revised.atsEgp, 25093.10);

      // VAT Base = 2,509,310.30 + 125,465.52 + 25,093.10 = 2,659,868.92
      expect(revised.vatBaseEgp, 2659868.92);

      // VAT (14%) = 2,659,868.92 * 0.14 = 372,381.6488 -> 372,381.65
      expect(revised.vatEgp, 372381.65);

      // Total duties = 125,465.52 + 372,381.65 + 25,093.10 + 500.00 = 523,440.27
      expect(revised.totalDutiesEgp, 523440.27);
    });

    test('Calculates Revised Figures with official customs exchange rate (48.50 EGP/USD)', () {
      final tariff = _petTariff();

      final revised = Form46Calculator.calculateRevisedFigures(
        fobUsd: 43704.0,
        exchangeRate: 48.50,
        bookingFreightUsd: 7750.0,
        tariff: tariff,
      );

      // Revised_CIF = 51,454 * 48.50 = 2,495,519.00 EGP
      expect(revised.cifEgp, 2495519.00);

      // Duty (5%) = 2,495,519.00 * 0.05 = 124,775.95
      expect(revised.importDutyEgp, 124775.95);

      // أ.ت.ص (1%) = 2,495,519.00 * 0.01 = 24,955.19
      expect(revised.atsEgp, 24955.19);

      // VAT Base = 2,495,519.00 + 124,775.95 + 24,955.19 = 2,645,250.14
      expect(revised.vatBaseEgp, 2645250.14);

      // VAT (14%) = 2,645,250.14 * 0.14 = 370,335.0196 -> 370,335.02
      expect(revised.vatEgp, 370335.02);

      // Total = 124,775.95 + 370,335.02 + 24,955.19 = 520,066.16
      expect(revised.totalDutiesEgp, 520066.16);
    });

    test('Flags missing inputs gracefully without throwing', () {
      final missingFob = Form46Calculator.calculateRevisedFigures(
        fobUsd: null,
        exchangeRate: 48.70,
        tariff: _petTariff(),
      );
      expect(missingFob.isComplete, isFalse);
      expect(missingFob.missing, contains('fob_usd'));
      expect(missingFob.cifEgp, isNull);

      final missingFx = Form46Calculator.calculateRevisedFigures(
        fobUsd: 43704.0,
        exchangeRate: 0.0,
        tariff: _petTariff(),
      );
      expect(missingFx.isComplete, isFalse);
      expect(missingFx.missing, contains('fx_rate'));

      final missingTariff = Form46Calculator.calculateRevisedFigures(
        fobUsd: 43704.0,
        exchangeRate: 48.70,
        tariff: null,
      );
      expect(missingTariff.isComplete, isFalse);
      expect(missingTariff.missing, contains('tariff'));
    });
  });

  group('CustomsDeclarationAssessment — Three-Column System & Variance Thresholds', () {
    test('Calculates (B vs A), (C vs A), and (C vs B) variances with exact thresholds', () {
      // Column A (Study):
      // CIF = 2,119,644.00, Duties = 438,766.31
      // Column B (Revised):
      // CIF = 2,505,809.80, Duties = 522,210.76
      // Column C (Actual):
      // CIF = 2,510,000.00, Duties = 524,000.00

      const assessment = CustomsDeclarationAssessment(
        declarationNo: 'DECL-2026-004',
        importFileCode: 'IMP-2026-0004',
        primaryNameWithCode: 'PET Acoustic Panels',
        supplierName: 'Suzhou Yuheng Textile Co.,Ltd',
        companyName: 'SCAS For Construction And Finishing',
        acidNumber: '5281534391023010013',
        form4Number: 'F4-BNK-99881',
        blNumber: 'THXJ2608090',
        hsCode: '5602.29.00',
        hsDescription: 'PET Acoustic Panels',
        currency: 'USD',
        hasExemption: false,
        exemptionTitle: 'MFN 5%',
        registrationDate: '2026-08-30',
        status: 'In-Progress',
        // Column A
        exchangeRate: 48.50,
        cifEgp: 2119644.00,
        dutyRate: 5.0,
        importDutyEgp: 105982.20,
        vatRate: 14.0,
        vatEgp: 311587.67,
        devFeeEgp: 0.0,
        serviceFeeEgp: 21196.44,
        totalDutiesEgp: 438766.31,
        // Column B
        revisedExchangeRate: 48.70,
        revisedFreightUsd: 7750.0,
        revisedFreightEgp: 377425.00,
        revisedInsuranceEgp: 0.0,
        revisedUnloadingEgp: 0.0,
        revisedDutyRate: 5.0,
        revisedExtraFeesEgp: 0.0,
        revisedCifEgp: 2505809.80,
        revisedImportDutyEgp: 125290.49,
        revisedVatEgp: 371862.17,
        revisedDevFeeEgp: 25058.10,
        revisedTotalDutiesEgp: 522210.76,
        revisedEstimateDate: '2026-10-20',
        revisedEstimateNotes: 'Revised using confirmed freight BKG-2026-0001',
        // Column C
        actualCifEgp: 2510000.00,
        actualExchangeRate: 48.70,
        actualDutyTotal: 524000.00,
        nafezaClaimNumber: 'NAF-2026-99120',
        nafezaClaimDate: '2026-10-28',
        dutyVarianceReason: 'Minor port fees adjustments',
      );

      // --- 1. Total Duties Variances ---
      // B vs A (Revised vs Study):
      // Delta = 522,210.76 - 438,766.31 = 83,444.45
      // % = (83,444.45 / 438,766.31) * 100 = 19.02% -> DANGER (> 10%)
      expect(assessment.dutyDiffBvsA, 83444.45);
      expect(assessment.dutyDiffPctBvsA, 19.02);
      expect(assessment.dutyVarianceLevelBvsA, AssessmentVarianceSeverity.danger);
      expect(assessment.dutyVarianceBvsA.isDanger, isTrue);

      // C vs A (Actual vs Study):
      // Delta = 524,000.00 - 438,766.31 = 85,233.69
      // % = (85,233.69 / 438,766.31) * 100 = 19.43% -> DANGER (> 10%)
      expect(assessment.dutyDiffCvsA, 85233.69);
      expect(assessment.dutyDiffPctCvsA, 19.43);
      expect(assessment.dutyVarianceLevelCvsA, AssessmentVarianceSeverity.danger);

      // C vs B (Actual vs Revised):
      // Delta = 524,000.00 - 522,210.76 = 1,789.24
      // % = (1,789.24 / 522,210.76) * 100 = 0.34% -> SAFE (< 2%)
      expect(assessment.dutyDiffCvsB, 1789.24);
      expect(assessment.dutyDiffPctCvsB, 0.34);
      expect(assessment.dutyVarianceLevelCvsB, AssessmentVarianceSeverity.safe);
      expect(assessment.dutyVarianceCvsB.isSafe, isTrue);

      // --- 2. CIF Variances ---
      // B vs A:
      // Delta = 2,505,809.80 - 2,119,644.00 = 386,165.80
      // % = (386,165.80 / 2,119,644.00) * 100 = 18.22% -> DANGER
      expect(assessment.cifDiffBvsA, 386165.80);
      expect(assessment.cifDiffPctBvsA, 18.22);
      expect(assessment.cifVarianceLevelBvsA, AssessmentVarianceSeverity.danger);

      // C vs B:
      // Delta = 2,510,000.00 - 2,505,809.80 = 4,190.20
      // % = (4,190.20 / 2,505,809.80) * 100 = 0.17% -> SAFE
      expect(assessment.cifDiffCvsB, 4190.20);
      expect(assessment.cifDiffPctCvsB, 0.17);
      expect(assessment.cifVarianceLevelCvsB, AssessmentVarianceSeverity.safe);

      // --- 3. Exchange Rate Variances ---
      // B vs A: 48.70 vs 48.50 -> diff = 0.20, % = (0.20 / 48.50) * 100 = 0.41% -> SAFE
      expect(assessment.fxDiffBvsA, 0.20);
      expect(assessment.fxDiffPctBvsA, 0.41);
      expect(assessment.fxVarianceLevelBvsA, AssessmentVarianceSeverity.safe);
      // C vs B: 48.70 vs 48.70 -> diff = 0.00, % = 0.0% -> SAFE
      expect(assessment.fxDiffCvsB, 0.00);
      expect(assessment.fxDiffPctCvsB, 0.00);
      expect(assessment.fxVarianceLevelCvsB, AssessmentVarianceSeverity.safe);
    });

    test('Evaluates Warning severity tier for variance between 2.0% and 10.0%', () {
      final safeResult = CustomsDeclarationAssessment.calculateVariance(101.5, 100.0);
      expect(safeResult.difference, 1.5);
      expect(safeResult.percentage, 1.5);
      expect(safeResult.severity, AssessmentVarianceSeverity.safe);
      expect(safeResult.severity.labelAr, 'آمن / عادي');

      final warningResult = CustomsDeclarationAssessment.calculateVariance(105.0, 100.0);
      expect(warningResult.difference, 5.0);
      expect(warningResult.percentage, 5.0);
      expect(warningResult.severity, AssessmentVarianceSeverity.warning);
      expect(warningResult.severity.labelAr, 'تحذيري');

      final dangerResult = CustomsDeclarationAssessment.calculateVariance(115.0, 100.0);
      expect(dangerResult.difference, 15.0);
      expect(dangerResult.percentage, 15.0);
      expect(dangerResult.severity, AssessmentVarianceSeverity.danger);
      expect(dangerResult.severity.labelAr, 'خطر');
    });

    test('copyWith updates Column B and Column C cleanly', () {
      const initial = CustomsDeclarationAssessment(
        declarationNo: 'D-1',
        importFileCode: 'IMP-2026-0004',
        primaryNameWithCode: 'PET Panels',
        supplierName: 'Yuheng',
        companyName: 'SCAS',
        acidNumber: '123',
        form4Number: 'F4',
        blNumber: 'BL',
        hsCode: '5602.29.00',
        hsDescription: 'PET',
        currency: 'USD',
        hasExemption: false,
        exemptionTitle: '',
        registrationDate: '2026-08-30',
        status: 'Open',
        totalDutiesEgp: 400000.0,
      );

      final updated = initial.copyWith(
        revisedTotalDutiesEgp: 420000.0,
        actualDutyTotal: 422000.0,
        nafezaClaimNumber: 'CLAIM-778',
      );

      expect(updated.revisedTotalDutiesEgp, 420000.0);
      expect(updated.actualDutyTotal, 422000.0);
      expect(updated.nafezaClaimNumber, 'CLAIM-778');
      expect(updated.dutyDiffBvsA, 20000.0);
      expect(updated.dutyDiffPctBvsA, 5.0); // 5% -> Warning
      expect(updated.dutyVarianceLevelBvsA, AssessmentVarianceSeverity.warning);
    });
  });

  group('CustomsDeclarationAssessmentHelper.calculateAssessment — Automated Column B Integration', () {
    test('Automatically populates Column B when linked booking is present', () {
      final mockFile = ImportFileModel(
        importFileId: 4,
        importFileCode: 'IMP-2026-0004',
        companyId: 2,
        companyName: 'SCAS For Construction And Finishing',
        supplierId: 2,
        supplierName: 'Suzhou Yuheng Textile Co.,Ltd',
        currentModule: 'Customs Clearance',
        currentStage: 'Declaration 46',
        nextAction: 'Submit Form 46',
        invoicesData: [
          InvoiceItemModel(invoiceNo: 'YH20260730-6', amount: 43704.0, currency: 'USD'),
        ],
        packingListsData: [],
        projectIds: [],
        skippedStages: [],
        createdAt: '2026-08-30T00:00:00Z',
        updatedAt: '2026-08-30T00:00:00Z',
      );

      final booking = _mockBooking(importFileId: 4, totalFreightCostUsd: 7750.0);
      final tariff = _petTariff();
      final usdCurrency = CurrencyModel(
        currencyCode: 'USD',
        currencyName: 'US Dollar',
        currencySymbol: '\$',
        latestCustomsRate: 48.70,
      );

      final po = PurchaseOrderModel.fromJson({
        'po_id': 3,
        'po_number': 'PO-2026-003',
        'import_file_id': 4,
        'items': [
          {'item_id': 137, 'po_id': 3, 'hs_code': '5602.29.00', 'quantity': 100, 'unit_price': 60.7},
        ],
      });

      final l = AppLocalizationsEn();

      final assessment = CustomsDeclarationAssessmentHelper.calculateAssessment(
        mockFile,
        l,
        cachedBookings: [booking],
        cachedTariffs: [tariff],
        cachedCurrencies: [usdCurrency],
        cachedPos: [po],
      );

      expect(assessment.importFileCode, 'IMP-2026-0004');
      // Column A computed
      expect(assessment.cifEgp, 2128384.80); // 43,704 * 48.70

      // Column B automatically computed with booking freight
      expect(assessment.revisedFreightUsd, 7750.0);
      expect(assessment.revisedFreightEgp, 377425.00);
      expect(assessment.revisedCifEgp, 2505809.80);
      expect(assessment.revisedImportDutyEgp, 125290.49);
      expect(assessment.revisedDevFeeEgp, 25058.10); // أ.ت.ص
      expect(assessment.revisedVatEgp, 371862.17);
      expect(assessment.revisedTotalDutiesEgp, 522210.76);

      // Variance B vs A
      expect(assessment.dutyDiffBvsA, isNotNull);
      expect(assessment.dutyVarianceBvsA.isDanger, isTrue); // Since booking freight was added, >10%
    });
  });
}
