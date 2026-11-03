import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/customs_regimes/customs_regimes_provider.dart';
import 'package:frontend/features/customs_regimes/widgets/guarantee_bond_tracking_table.dart';
import 'package:frontend/features/customs_regimes/widgets/re_export_reconciliation_card.dart';
import 'package:frontend/features/customs_regimes/widgets/regime_selection_stepper.dart';
import 'package:frontend/features/legal_claims/legal_claims_provider.dart';
import 'package:frontend/features/legal_claims/widgets/reservation_letter_generator_card.dart';
import 'package:frontend/features/legal_claims/widgets/surveyor_report_manager.dart';
import 'package:frontend/features/legal_claims/widgets/time_bar_countdown_banner.dart';
import 'package:frontend/features/trade_agreements/trade_agreements_provider.dart';
import 'package:frontend/features/trade_agreements/widgets/certificate_authenticity_checklist.dart';
import 'package:frontend/features/trade_agreements/widgets/provisional_escrow_calculator_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('ar'),
    home: Scaffold(body: SelectionArea(child: child)),
  );
}

void main() {
  group('Wave 3 Customs Regimes Widgets Tests', () {
    testWidgets('RegimeSelectionStepper renders all 5 regimes and fires tap', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String selected = 'TEMPORARY_ADMISSION';
      bool addPressed = false;

      await tester.pumpWidget(_wrap(
        RegimeSelectionStepper(
          selectedType: selected,
          onTypeChanged: (v) => selected = v,
          onAddNew: () => addPressed = true,
        ),
      ));

      expect(find.text('اختيار وتصنيف النظام الجمركي المعلق للرسوم'), findsOneWidget);
      expect(find.text('السماح المؤقت'), findsOneWidget);
      expect(find.text('الدروباك'), findsOneWidget);
      expect(find.text('المناطق الحرة'), findsOneWidget);
      expect(find.text('المستودعات الجمركية'), findsOneWidget);
      expect(find.text('الترانزيت المباشر'), findsOneWidget);

      await tester.tap(find.text('الدروباك'));
      await tester.pump();
      expect(selected, 'DRAWBACK');

      await tester.tap(find.text('تسجيل نظام جديد'));
      await tester.pump();
      expect(addPressed, isTrue);
    });

    testWidgets('GuaranteeBondTrackingTable renders items correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final sampleItem = CustomsRegimeItem(
        id: 1,
        regimeCode: 'REG-2026-00001',
        importFileId: 10,
        regimeType: 'TEMPORARY_ADMISSION',
        status: 'ACTIVE',
        guaranteeType: 'LETTER_OF_GUARANTEE',
        guaranteeReference: 'LG-12345',
        guaranteeBank: 'البنك الأهلي المصري',
        guaranteeAmount: 150000.0,
        guaranteeCurrency: 'EGP',
        guaranteeExpiryDate: DateTime(2027, 1, 1),
        drawbackRefundAmount: 0.0,
        isSettled: false,
        isExpired: false,
        guaranteeActive: true,
      );

      await tester.pumpWidget(_wrap(
        GuaranteeBondTrackingTable(
          items: [sampleItem],
          onSelect: (_) {},
          onSettle: (_) {},
        ),
      ));

      expect(find.text('REG-2026-00001'), findsOneWidget);
      expect(find.text('السماح المؤقت'), findsOneWidget);
      expect(find.text('خطاب ضمان بنكي'), findsOneWidget);
      expect(find.text('البنك الأهلي المصري'), findsOneWidget);
      expect(find.text('150000.00 EGP'), findsOneWidget);
    });

    testWidgets('ReExportReconciliationCard renders remaining countdown and details', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final sampleItem = CustomsRegimeItem(
        id: 1,
        regimeCode: 'REG-2026-00002',
        importFileId: 10,
        regimeType: 'TEMPORARY_ADMISSION',
        status: 'ACTIVE',
        guaranteeAmount: 0.0,
        guaranteeCurrency: 'EGP',
        reExportDeadline: DateTime(2026, 12, 31),
        drawbackRefundAmount: 0.0,
        isSettled: false,
        daysUntilReExport: 60,
        isExpired: false,
        guaranteeActive: false,
      );

      await tester.pumpWidget(_wrap(
        ReExportReconciliationCard(
          item: sampleItem,
          onSettlePressed: () {},
        ),
      ));

      expect(find.textContaining('المهلة القانونية سارية'), findsOneWidget);
      expect(find.text('تسوية وإغلاق النظام'), findsOneWidget);
    });
  });

  group('Wave 3 Trade Agreements Widgets Tests', () {
    testWidgets('CertificateAuthenticityChecklist renders rules checklist', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final item = TradeAgreementItem(
        id: 1,
        verificationCode: 'POV-2026-00001',
        importFileId: 5,
        agreementName: 'EUR1',
        certificateType: 'EUR.1',
        certificateNumber: 'EUR1-8899',
        issuingCountry: 'ألمانيا',
        issuingDate: DateTime(2026, 1, 1),
        validityMonths: 4,
        submissionStatus: 'COPY_SUBMITTED',
        hasOriginalReceived: false,
        provisionalEscrowRequired: true,
        provisionalEscrowAmount: 50000.0,
        provisionalEscrowRefunded: false,
        directTransportCompliant: true,
        rulesOfOriginCriterion: 'SUFFICIENT_PROCESSING',
        isCertExpired: false,
        isEscrowAtRisk: false,
      );

      await tester.pumpWidget(_wrap(
        CertificateAuthenticityChecklist(
          item: item,
          onVerifyOriginal: () {},
        ),
      ));

      expect(find.textContaining('التحقق من صحة واشتراطات شهادة المنشأ'), findsOneWidget);
      expect(find.text('اتفاقية الشراكة المصرية الأوروبية'), findsOneWidget);
      expect(find.text('إثبات استلام الأصل'), findsOneWidget);
      expect(find.text('استيفاء شرط الشحن المباشر'), findsOneWidget);
    });

    testWidgets('ProvisionalEscrowCalculatorCard renders escrow details', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final item = TradeAgreementItem(
        id: 1,
        verificationCode: 'POV-2026-00002',
        importFileId: 5,
        agreementName: 'GAFTA',
        certificateType: 'ARAB_LEAGUE',
        certificateNumber: 'GFT-123',
        issuingCountry: 'السعودية',
        issuingDate: DateTime(2026, 1, 1),
        validityMonths: 6,
        submissionStatus: 'COPY_SUBMITTED',
        hasOriginalReceived: false,
        provisionalEscrowRequired: true,
        provisionalEscrowAmount: 75000.0,
        provisionalEscrowReceipt: 'RCP-778',
        provisionalEscrowRefunded: false,
        directTransportCompliant: true,
        isCertExpired: false,
        isEscrowAtRisk: true,
        daysUntilEscrowDeadline: 10,
      );

      await tester.pumpWidget(_wrap(
        ProvisionalEscrowCalculatorCard(
          item: item,
          onRecordRefund: () {},
        ),
      ));

      expect(find.textContaining('تنبيه عاجل: اقتراب انقضاء مهلة استرداد الأمانة'), findsOneWidget);
      expect(find.text('75000.00 جنيه'), findsOneWidget);
      expect(find.text('RCP-778'), findsOneWidget);
    });
  });

  group('Wave 3 Legal Claims Widgets Tests', () {
    testWidgets('TimeBarCountdownBanner renders urgency radar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final claim = LegalClaimItem(
        id: 1,
        claimCode: 'CLM-2026-00001',
        importFileId: 3,
        claimType: 'CARRIER_DAMAGE',
        damageNature: 'LATENT',
        timeBarStatuteOfLimitationsDate: DateTime(2027, 5, 1),
        status: 'RESERVATION_ISSUED',
        targetParty: 'ميرسك مصر',
        surveyRequested: false,
        claimedAmount: 20000.0,
        claimedCurrency: 'USD',
        settledAmount: 0.0,
        daysUntilTimeBar: 300,
        isLatentNoticeExpired: false,
        isTimeBarred: false,
        urgencyLevel: 'NORMAL',
      );

      await tester.pumpWidget(_wrap(
        TimeBarCountdownBanner(claim: claim),
      ));

      expect(find.text('مواعيد الدعوى والمطالبة القانونية سارية ومحمية'), findsOneWidget);
      expect(find.text('300 يوم متبقي'), findsOneWidget);
    });

    testWidgets('ReservationLetterGeneratorCard and SurveyorReportManager render actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final claim = LegalClaimItem(
        id: 2,
        claimCode: 'CLM-2026-00002',
        importFileId: 3,
        claimType: 'PORT_DAMAGE',
        damageNature: 'APPARENT',
        timeBarStatuteOfLimitationsDate: DateTime(2027, 5, 1),
        status: 'RESERVATION_ISSUED',
        targetParty: 'محطة حاويات الدخيلة',
        surveyRequested: false,
        claimedAmount: 15000.0,
        claimedCurrency: 'USD',
        settledAmount: 0.0,
        daysUntilTimeBar: 180,
        isLatentNoticeExpired: false,
        isTimeBarred: false,
        urgencyLevel: 'NORMAL',
      );

      await tester.pumpWidget(_wrap(
        Column(
          children: [
            ReservationLetterGeneratorCard(claim: claim),
            SurveyorReportManager(
              claim: claim,
              onScheduleSurvey: () {},
              onSettleClaim: () {},
            ),
          ],
        ),
      ));

      expect(find.text('خطاب التحفظ الرسمي وتحميل المسؤولية للناقل'), findsOneWidget);
      expect(find.text('محطة حاويات الدخيلة'), findsOneWidget);
      expect(find.text('نسخ نص الخطاب'), findsOneWidget);
      expect(find.text('تصدير الخطاب'), findsOneWidget);

      expect(find.text('محضر وتقرير المعاينة المشتركة وحصر الأضرار'), findsOneWidget);
      expect(find.text('جدولة معاينة مشتركة'), findsOneWidget);
      expect(find.text('تسوية المطالبة'), findsOneWidget);
    });
  });
}
